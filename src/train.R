library(tidymodels)
library(themis)
library(glmnet)
library(ranger)
library(lightgbm)
library(bonsai)

# Resampling category -------------------------------------------------------

resampling_category <- function(resampling) {
  switch(resampling,
    none        = "none",
    upsample    = "oversample",
    smote       = "oversample",
    adasyn      = "oversample",
    downsample  = "undersample",
    tomek       = "undersample",
    nearmiss    = "undersample",
    smote_tomek = "hybrid",
    smote_enn   = "hybrid"
  )
}

# Model specs ---------------------------------------------------------------

spec_logreg <- function(penalty, cfg = NULL) {
  m <- if (!is.null(cfg)) cfg$models$logreg else list(mixture = 0.5)
  logistic_reg(penalty = penalty, mixture = m$mixture) |>
    set_engine("glmnet") |>
    set_mode("classification")
}

spec_rf <- function(cfg = NULL) {
  m <- if (!is.null(cfg)) cfg$models$rf else list(trees = 500, min_n = 5)
  rand_forest(trees = m$trees, mtry = NULL, min_n = m$min_n) |>
    set_engine("ranger", probability = TRUE) |>
    set_mode("classification")
}

spec_lgbm <- function(cfg = NULL) {
  m <- if (!is.null(cfg)) cfg$models$lgbm else list(trees = 300, learn_rate = 0.05, num_leaves = 31)
  boost_tree(trees = m$trees, learn_rate = m$learn_rate) |>
    set_engine("lightgbm", num_leaves = m$num_leaves) |>
    set_mode("classification")
}

# Recipe builders -----------------------------------------------------------

#' Build the base recipe (NZV → dummy → normalize)
#'
#' @param train  Training partition tibble with `y` as factor.
base_recipe <- function(train, cfg = NULL) {
  threshold <- if (!is.null(cfg)) cfg$recipe$step_other_threshold else 0.01
  recipe(y ~ ., data = train) |>
    step_nzv(all_predictors()) |>
    step_other(all_nominal_predictors(), threshold = threshold, other = ".other") |>
    step_dummy(all_nominal_predictors()) |>
    step_normalize(all_numeric_predictors())
}

#' Build the full recipe for a given resampling condition
#'
#' @param train       Training partition tibble.
#' @param resampling  One of the 9 condition keys (see pipeline.md).
build_recipe <- function(train, resampling, cfg = NULL) {
  rec <- base_recipe(train, cfg)
  p   <- if (!is.null(cfg)) cfg$resampling_params else list(
    upsample   = list(over_ratio  = 0.5),
    smote      = list(over_ratio  = 0.5, neighbors = 5),
    adasyn     = list(over_ratio  = 0.5, neighbors = 5),
    downsample = list(under_ratio = 1.0),
    nearmiss   = list(under_ratio = 1.0, neighbors = 3),
    enn        = list(neighbors   = 5)
  )

  switch(resampling,
    none        = rec,
    upsample    = rec |> step_upsample(y, over_ratio = p$upsample$over_ratio),
    smote       = rec |> step_smote(y, over_ratio = p$smote$over_ratio, neighbors = p$smote$neighbors),
    adasyn      = rec |> step_adasyn(y, over_ratio = p$adasyn$over_ratio, neighbors = p$adasyn$neighbors),
    downsample  = rec |> step_downsample(y, under_ratio = p$downsample$under_ratio),
    tomek       = rec |> step_tomek(y),
    nearmiss    = rec |> step_nearmiss(y, under_ratio = p$nearmiss$under_ratio, neighbors = p$nearmiss$neighbors),
    smote_tomek = rec |> step_smote(y, over_ratio = p$smote$over_ratio, neighbors = p$smote$neighbors) |> step_tomek(y),
    smote_enn   = rec |> step_smote(y, over_ratio = p$smote$over_ratio, neighbors = p$smote$neighbors) |> step_enn(y, neighbors = p$enn$neighbors),
    stop("Unknown resampling condition: ", resampling)
  )
}

# Custom ENN recipe step ----------------------------------------------------
# themis does not include step_enn(); implemented here using FNN::get.knn().
# Follows the themis prep-stores / bake-returns pattern so skip = TRUE works
# correctly in workflows: ENN is applied to training data during prep(), then
# bypassed when predict() bakes calibration and test partitions.

step_enn <- function(recipe, var, neighbors = 5, role = NA, skip = TRUE,
                     id = recipes::rand_id("enn")) {
  recipes::add_step(
    recipe,
    new_step_enn(
      var       = rlang::as_name(rlang::enquo(var)),
      neighbors = neighbors,
      role      = role,
      skip      = skip,
      id        = id
    )
  )
}

new_step_enn <- function(var, neighbors, role, skip, id, trained = FALSE, retain = NULL) {
  recipes::step(
    subclass  = "enn",
    var       = var,
    neighbors = neighbors,
    role      = role,
    skip      = skip,
    id        = id,
    trained   = trained,
    retain    = retain
  )
}

prep.step_enn <- function(x, training, info = NULL, ...) {
  y_col    <- x$var
  k        <- x$neighbors
  y_vals   <- as.integer(as.character(training[[y_col]]))
  x_mat    <- as.matrix(dplyr::select(training, -dplyr::all_of(y_col)))
  nn_idx   <- FNN::get.knn(x_mat, k = k)$nn.index
  votes    <- matrix(y_vals[nn_idx], nrow = nrow(x_mat))
  majority <- as.integer(rowSums(votes) > k / 2)
  new_step_enn(var = x$var, neighbors = x$neighbors, role = x$role,
               skip = x$skip, id = x$id, trained = TRUE,
               retain = training[majority == y_vals, , drop = FALSE])
}

bake.step_enn <- function(object, new_data, ...) {
  if (is.null(new_data)) object$retain else new_data
}

print.step_enn <- function(x, ...) {
  cat("ENN undersampling on", x$var, "\n")
  invisible(x)
}

# Lambda selection ----------------------------------------------------------

#' Select glmnet penalty via internal 5-fold CV on the training set
#'
#' Uses base_recipe (no resampling) so lambda is resampling-condition-agnostic.
#' Call once per dataset before the resampling loop. Returns lambda.1se.
#'
#' @param train  Training partition tibble with `y` as factor.
select_lambda <- function(train, cfg = NULL) {
  m       <- if (!is.null(cfg)) cfg$models$logreg else list(mixture = 0.5, cv_folds = 5)
  prepped <- base_recipe(train, cfg) |> prep(training = train)
  baked   <- bake(prepped, new_data = NULL)
  x <- as.matrix(dplyr::select(baked, -y))
  y <- as.integer(as.character(baked$y))
  cv <- glmnet::cv.glmnet(x, y, alpha = m$mixture, nfolds = m$cv_folds, family = "binomial")
  cv$lambda.1se
}

# Fit helpers ---------------------------------------------------------------

#' Fit one workflow and return predictions on calibration and test partitions
#'
#' @param splits      Named list with `train`, `calibration`, `test` tibbles.
#' @param classifier  One of "logreg", "rf", "lgbm".
#' @param resampling  One of the 9 condition keys.
#' @param penalty     Resolved glmnet lambda (required when classifier = "logreg").
#' @return Named list: `workflow`, `pred_calibration`, `pred_test`.
fit_condition <- function(splits, classifier, resampling, penalty = NULL, cfg = NULL) {
  train <- splits$train |> mutate(y = factor(y, levels = c(0, 1)))
  cal   <- splits$calibration |> mutate(y = factor(y, levels = c(0, 1)))
  test  <- splits$test  |> mutate(y = factor(y, levels = c(0, 1)))

  spec <- if (classifier == "logreg") {
    if (is.null(penalty)) stop("penalty required for logreg")
    spec_logreg(penalty, cfg)
  } else {
    switch(classifier,
      rf   = spec_rf(cfg),
      lgbm = spec_lgbm(cfg),
      stop("Unknown classifier: ", classifier)
    )
  }

  rec <- build_recipe(train, resampling, cfg)

  wf <- workflow() |>
    add_recipe(rec) |>
    add_model(spec) |>
    fit(data = train)

  predict_probs <- function(partition) {
    predict(wf, new_data = partition, type = "prob") |>
      bind_cols(tibble(y = partition$y)) |>
      select(y, .pred_1)
  }

  list(
    workflow         = wf,
    pred_calibration = predict_probs(cal),
    pred_test        = predict_probs(test)
  )
}

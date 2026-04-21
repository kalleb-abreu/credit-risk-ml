library(tidymodels)
library(themis)
library(glmnet)
library(ranger)
library(lightgbm)
library(bonsai)

# Model specs ---------------------------------------------------------------

spec_logreg <- function() {
  logistic_reg(penalty = tune(), mixture = 0.5) |>
    set_engine("glmnet") |>
    set_mode("classification")
}

spec_rf <- function() {
  rand_forest(trees = 500, mtry = NULL, min_n = 5) |>
    set_engine("ranger", probability = TRUE) |>
    set_mode("classification")
}

spec_lgbm <- function() {
  boost_tree(trees = 300) |>
    set_engine("lightgbm",
               num_leaves    = 31,
               learning_rate = 0.05) |>
    set_mode("classification")
}

# Recipe builders -----------------------------------------------------------

#' Build the base recipe (NZV → dummy → normalize)
#'
#' The resampling step is added on top by `build_recipe()`.
#'
#' @param train  Training partition tibble with `y` as factor.
base_recipe <- function(train) {
  recipe(y ~ ., data = train) |>
    step_nzv(all_predictors()) |>
    step_dummy(all_nominal_predictors()) |>
    step_normalize(all_numeric_predictors())
}

#' Build the full recipe for a given resampling condition
#'
#' @param train       Training partition tibble.
#' @param resampling  One of the 9 condition keys (see pipeline.md).
build_recipe <- function(train, resampling) {
  rec <- base_recipe(train)

  switch(resampling,
    none          = rec,
    upsample      = rec |> step_upsample(y, over_ratio = 0.5),
    smote         = rec |> step_smote(y, over_ratio = 0.5, neighbors = 5),
    adasyn        = rec |> step_adasyn(y, over_ratio = 0.5, neighbors = 5),
    downsample    = rec |> step_downsample(y, under_ratio = 1),
    tomek         = rec |> step_tomek(y),
    nearmiss      = rec |> step_nearmiss(y, under_ratio = 1, neighbors = 3),
    smote_tomek   = rec |> step_smote(y, over_ratio = 0.5, neighbors = 5) |> step_tomek(y),
    smote_enn     = rec |> step_smote(y, over_ratio = 0.5, neighbors = 5),  # TODO: add ENN step
    stop("Unknown resampling condition: ", resampling)
  )
}

# Fit helpers ---------------------------------------------------------------

#' Fit one workflow and return predictions on calibration and test partitions
#'
#' @param splits      Named list with `train`, `calibration`, `test` tibbles.
#' @param classifier  One of "logreg", "rf", "lgbm".
#' @param resampling  One of the 9 condition keys.
#' @return Named list: `workflow`, `pred_calibration`, `pred_test`.
fit_condition <- function(splits, classifier, resampling) {
  train <- splits$train |> mutate(y = factor(y, levels = c(0, 1)))
  cal   <- splits$calibration |> mutate(y = factor(y, levels = c(0, 1)))
  test  <- splits$test  |> mutate(y = factor(y, levels = c(0, 1)))

  spec <- switch(classifier,
    logreg = spec_logreg(),
    rf     = spec_rf(),
    lgbm   = spec_lgbm(),
    stop("Unknown classifier: ", classifier)
  )

  rec <- build_recipe(train, resampling)

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
    workflow        = wf,
    pred_calibration = predict_probs(cal),
    pred_test        = predict_probs(test)
  )
}

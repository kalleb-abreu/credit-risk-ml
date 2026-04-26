library(here)
library(dplyr)
library(arrow)
library(purrr)

source(here("src/preprocess.R"))
source(here("src/train.R"))

datasets <- c(
  "ulb", "ieee", "bank_marketing", "taiwan", "south_german", "australian"
)

classifiers  <- c("logreg", "rf", "lgbm")
resamplings  <- c(
  "none", "upsample", "smote", "adasyn",
  "downsample", "tomek", "nearmiss", "smote_tomek", "smote_enn"
)

sample_n <- suppressWarnings(as.integer(Sys.getenv("SAMPLE_SIZE", unset = NA_character_)))
if (!is.na(sample_n)) message("SAMPLE_SIZE=", sample_n, " — training on subsamples only")

for (dataset in datasets) {
  splits <- load_splits(dataset, dir = "data/processed")

  if (!is.na(sample_n)) {
    n_each <- ceiling(sample_n / 2)
    splits$train <- splits$train |>
      group_by(y) |>
      group_modify(~ slice_sample(.x, n = min(n_each, nrow(.x)))) |>
      ungroup()
  }

  train  <- splits$train |> mutate(y = factor(y, levels = c(0, 1)))

  message("Selecting lambda for: ", dataset)
  lambda <- select_lambda(train)

  for (classifier in classifiers) {
    for (resampling in resamplings) {
      key      <- paste(dataset, classifier, resampling, sep = "_")
      pred_key <- paste(classifier, resampling, sep = "_")
      message("Fitting: ", key)

      result <- fit_condition(splits, classifier, resampling,
                              penalty = if (classifier == "logreg") lambda else NULL)

      saveRDS(
        result$workflow,
        here("models", paste0(key, ".rds"))
      )

      dir.create(here("predictions", "calibration", dataset), showWarnings = FALSE, recursive = TRUE)
      write_parquet(
        result$pred_calibration,
        here("predictions", "calibration", dataset, paste0(pred_key, ".parquet"))
      )

      dir.create(here("predictions", "test", dataset), showWarnings = FALSE, recursive = TRUE)
      write_parquet(
        result$pred_test,
        here("predictions", "test", dataset, paste0(pred_key, ".parquet"))
      )
    }
  }
}

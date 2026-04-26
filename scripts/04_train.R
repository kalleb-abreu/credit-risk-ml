library(here)
library(dplyr)
library(arrow)
library(purrr)

source(here("src/preprocess.R"))
source(here("src/train.R"))
source(here("src/config.R"))

cfg         <- load_config()
datasets    <- cfg$datasets
classifiers <- cfg$classifiers
resamplings <- all_resamplings(cfg)
sample_n    <- cfg$sample_size

if (!is.null(sample_n)) message("sample_size=", sample_n, " — training on subsamples only")

for (dataset in datasets) {
  splits <- load_splits(dataset, dir = "data/processed")

  if (!is.null(sample_n)) {
    n_each <- ceiling(sample_n / 2)
    splits$train <- splits$train |>
      group_by(y) |>
      group_modify(~ slice_sample(.x, n = min(n_each, nrow(.x)))) |>
      ungroup()
  }

  train  <- splits$train |> mutate(y = factor(y, levels = c(0, 1)))

  message("Selecting lambda for: ", dataset)
  lambda <- select_lambda(train, cfg)

  for (classifier in classifiers) {
    for (resampling in resamplings) {
      category <- resampling_category(resampling)
      pred_key <- paste(classifier, resampling, sep = "_")
      key      <- paste(dataset, classifier, resampling, sep = "_")
      message("Fitting: ", key)

      result <- fit_condition(splits, classifier, resampling,
                              penalty = if (classifier == "logreg") lambda else NULL,
                              cfg = cfg)

      dir.create(here("models", dataset, category), showWarnings = FALSE, recursive = TRUE)
      saveRDS(
        result$workflow,
        here("models", dataset, category, paste0(pred_key, ".rds"))
      )

      dir.create(here("predictions", "calibration", dataset, category), showWarnings = FALSE, recursive = TRUE)
      write_parquet(
        result$pred_calibration,
        here("predictions", "calibration", dataset, category, paste0(pred_key, ".parquet"))
      )

      dir.create(here("predictions", "test", dataset, category), showWarnings = FALSE, recursive = TRUE)
      write_parquet(
        result$pred_test,
        here("predictions", "test", dataset, category, paste0(pred_key, ".parquet"))
      )
    }
  }
}

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

for (dataset in datasets) {
  splits <- load_splits(dataset, dir = "data/processed")
  train  <- splits$train |> mutate(y = factor(y, levels = c(0, 1)))

  message("Selecting lambda for: ", dataset)
  lambda <- select_lambda(train)

  for (classifier in classifiers) {
    for (resampling in resamplings) {
      key <- paste(dataset, classifier, resampling, sep = "_")
      message("Fitting: ", key)

      result <- fit_condition(splits, classifier, resampling,
                              penalty = if (classifier == "logreg") lambda else NULL)

      saveRDS(
        result$workflow,
        here("models", paste0(key, ".rds"))
      )

      write_parquet(
        result$pred_calibration,
        here("predictions", "calibration", paste0(key, ".parquet"))
      )

      write_parquet(
        result$pred_test,
        here("predictions", "test", paste0(key, ".parquet"))
      )
    }
  }
}

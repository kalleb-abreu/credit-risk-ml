library(here)
library(dplyr)
library(arrow)
library(purrr)
library(tidyr)

source(here("src/calibrate.R"))
source(here("src/evaluate.R"))

test_files <- list.files(here("predictions", "test"), pattern = "\\.parquet$", full.names = TRUE, recursive = TRUE)

results <- map_dfr(test_files, function(path) {
  dataset    <- basename(dirname(path))
  pred_key   <- tools::file_path_sans_ext(basename(path))
  key        <- paste(dataset, pred_key, sep = "_")
  parts      <- strsplit(pred_key, "_")[[1]]

  classifier_idx <- which(parts %in% c("logreg", "rf", "lgbm"))
  classifier     <- parts[classifier_idx]
  resampling     <- paste(parts[seq(classifier_idx + 1, length(parts))], collapse = "_")

  preds <- read_parquet(path)

  calibration_variants <- list(
    none     = NULL,
    platt    = tryCatch(readRDS(here("models", "calibrators", paste0(key, "_platt.rds"))),    error = function(e) NULL),
    isotonic = tryCatch(readRDS(here("models", "calibrators", paste0(key, "_isotonic.rds"))), error = function(e) NULL)
  )

  map_dfr(names(calibration_variants), function(cal_name) {
    calibrated <- apply_calibrator(preds, calibration_variants[[cal_name]])
    metrics    <- compute_metrics(calibrated)

    bind_cols(
      tibble(
        dataset     = dataset,
        classifier  = classifier,
        resampling  = resampling,
        calibration = cal_name
      ),
      metrics
    )
  })
})

dir.create(here("output"), showWarnings = FALSE)
write_parquet(results, here("output", "test_metrics.parquet"))
message("Saved output/test_metrics.parquet — ", nrow(results), " rows")

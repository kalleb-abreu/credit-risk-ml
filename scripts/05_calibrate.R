suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(arrow)
  library(purrr)
})

source(here("src/calibrate.R"))

cal_files <- list.files(
  here("predictions", "calibration"),
  pattern = "\\.parquet$", full.names = TRUE, recursive = TRUE
)

for (path in cal_files) {
  category <- basename(dirname(path))
  dataset <- basename(dirname(dirname(path)))
  pred_key <- tools::file_path_sans_ext(basename(path))
  message("Calibrating: ", dataset, "/", category, "/", pred_key)

  preds <- read_parquet(path)
  cals <- fit_calibrators(preds)

  dir.create(
    here("models", "calibrators", dataset, category),
    showWarnings = FALSE, recursive = TRUE
  )
  saveRDS(
    cals$platt,
    here(
      "models", "calibrators", dataset, category,
      paste0(pred_key, "_platt.rds")
    )
  )
  saveRDS(
    cals$isotonic,
    here(
      "models", "calibrators", dataset, category,
      paste0(pred_key, "_isotonic.rds")
    )
  )
}

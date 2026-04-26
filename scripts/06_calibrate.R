library(here)
library(dplyr)
library(arrow)
library(purrr)

source(here("src/calibrate.R"))

cal_files <- list.files(here("predictions", "calibration"), pattern = "\\.parquet$", full.names = TRUE, recursive = TRUE)

for (path in cal_files) {
  dataset <- basename(dirname(path))
  key     <- paste(dataset, tools::file_path_sans_ext(basename(path)), sep = "_")
  message("Calibrating: ", key)

  preds <- read_parquet(path)
  cals  <- fit_calibrators(preds)

  saveRDS(cals$platt,    here("models", "calibrators", paste0(key, "_platt.rds")))
  saveRDS(cals$isotonic, here("models", "calibrators", paste0(key, "_isotonic.rds")))
}

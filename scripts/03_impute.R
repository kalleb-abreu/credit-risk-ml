suppressPackageStartupMessages(library(here))
source(here::here("src/preprocess.R"))
source(here::here("src/config.R"))

cfg <- load_config()
datasets <- cfg$datasets

for (name in datasets) {
  message("=== ", name, " ===")
  load_splits(name) |>
    impute_splits() |>
    save_splits(name, dir = "data/processed")
}

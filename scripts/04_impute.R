library(here)
source(here::here("src/preprocess.R"))

dir.create(here::here("data/processed"), recursive = TRUE, showWarnings = FALSE)

datasets <- c("ulb", "ieee", "bank_marketing", "taiwan", "south_german", "australian")

for (name in datasets) {
  message("=== ", name, " ===")
  load_splits(name) |>
    impute_splits() |>
    save_splits(name, dir = "data/processed")
}

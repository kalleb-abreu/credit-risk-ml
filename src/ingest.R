library(here)
library(readr)

#' Load a CSV dataset and return a tibble
load_csv <- function(path) {
  read_csv(here::here(path), show_col_types = FALSE)
}

#' Compute class distribution for a binary target column
class_distribution <- function(df, target_col) {
  target_col <- rlang::sym(target_col)

  counts <- df |>
    dplyr::count({{ target_col }}) |>
    dplyr::mutate(
      pct = n / sum(n) * 100
    )

  counts
}

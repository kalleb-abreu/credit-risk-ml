library(here)
library(readr)
library(readxl)

#' Load a CSV dataset and return a tibble
load_csv <- function(path) {
  read_csv(here::here(path), show_col_types = FALSE)
}

#' Load the UCI Australian Credit Approval dataset
#' Space-separated, no header; assigns standard column names A1-A14 + Class
load_australian <- function(path) {
  col_names <- c(paste0("A", 1:14), "Class")
  read_table(
    here::here(path),
    col_names = col_names,
    col_types = cols(.default = col_double()),
    show_col_types = FALSE
  )
}

#' Load the UCI South German Credit dataset
#' Space-separated with a header row in German variable names
load_south_german <- function(path) {
  read_table(here::here(path), show_col_types = FALSE)
}

#' Load the UCI Taiwan Credit Card Default dataset
#' XLS file; first row is a secondary header that must be skipped
load_taiwan <- function(path) {
  read_excel(here::here(path), skip = 1)
}

#' Load the UCI Portuguese Bank Marketing dataset
#' Semicolon-separated with header; uses the full bank-additional dataset
load_bank_marketing <- function(path) {
  read_delim(here::here(path), delim = ";", show_col_types = FALSE)
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

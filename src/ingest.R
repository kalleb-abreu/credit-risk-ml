suppressPackageStartupMessages({
  library(here)
  library(readr)
  library(dplyr)
})

#' Load a generic CSV dataset
load_csv <- function(path) {
  read_csv(here::here(path), show_col_types = FALSE)
}

#' Load a dataset downloaded via ucimlrepo
#' Reads features.csv + targets.csv and binds them into one tibble
load_ucimlrepo <- function(dir) {
  features <- read_csv(here::here(dir, "features.csv"), show_col_types = FALSE)
  targets  <- read_csv(here::here(dir, "targets.csv"),  show_col_types = FALSE)
  bind_cols(features, targets)
}

#' Load the UCI South German Credit dataset
#' Space-separated with a header row in German variable names
load_south_german <- function(path) {
  read_table(here::here(path), show_col_types = FALSE)
}

#' Load the IEEE-CIS Fraud Detection dataset
#' Joins train_transaction and train_identity on TransactionID (left join);
#' drops TransactionID afterwards. The test files have no labels and are ignored.
load_ieee <- function(base_path) {
  transactions <- load_csv(file.path(base_path, "train_transaction.csv"))
  identity     <- load_csv(file.path(base_path, "train_identity.csv"))
  left_join(transactions, identity, by = "TransactionID") |>
    select(-TransactionID)
}

#' Compute class distribution for a binary target column
class_distribution <- function(df, target_col) {
  target_col <- rlang::sym(target_col)
  df |>
    count({{ target_col }}) |>
    mutate(pct = n / sum(n) * 100)
}

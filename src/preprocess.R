library(here)
library(dplyr)
library(readr)
library(arrow)

#' Enforce column types using a ucimlrepo variables.csv file
#'
#' Applies to Feature rows only; the target column is left as-is for
#' standardize_columns() to handle. Type mapping:
#'   Integer            -> integer
#'   Continuous         -> double
#'   Categorical / Binary / Date -> factor
#'
#' @param df   A tibble.
#' @param path Path to variables.csv (relative to project root).
cast_types_from_variables <- function(df, path) {
  vars <- read_csv(here::here(path), show_col_types = FALSE) |>
    filter(role == "Feature")

  for (i in seq_len(nrow(vars))) {
    col  <- vars$name[i]
    type <- vars$type[i]
    if (!col %in% names(df)) next
    df[[col]] <- switch(type,
      Integer    = as.integer(df[[col]]),
      Continuous = as.double(df[[col]]),
      factor(df[[col]])          # Categorical, Binary, Date
    )
  }
  df
}

#' Enforce column types from a named character vector
#'
#' Used for datasets without a variables.csv (ULB, IEEE-CIS, South German).
#' Columns not present in `df` are silently skipped.
#'
#' @param df        A tibble.
#' @param col_types Named character vector: c(col_name = "integer"|"double"|"factor").
cast_types <- function(df, col_types) {
  for (col in names(col_types)) {
    if (!col %in% names(df)) next
    df[[col]] <- switch(col_types[[col]],
      integer = as.integer(df[[col]]),
      double  = as.double(df[[col]]),
      factor  = factor(df[[col]])
    )
  }
  df
}

#' Impute missing values in train / calibration / test splits
#'
#' Parameters are estimated on the training partition only to prevent leakage,
#' then applied uniformly to all three partitions:
#'   - Numeric (integer / double) NA -> median of the training partition
#'   - Factor / character NA         -> new level "unknown"
#'
#' @param splits Named list returned by `stratified_split()`.
impute_splits <- function(splits) {
  train <- splits$train
  feat  <- setdiff(names(train), "y")

  num_cols <- feat[sapply(train[feat], is.numeric)]
  cat_cols <- feat[sapply(train[feat], function(x) is.factor(x) || is.character(x))]

  # Compute medians from training data only
  medians <- sapply(train[num_cols], median, na.rm = TRUE)

  apply_imputation <- function(df) {
    for (col in num_cols) {
      nas <- is.na(df[[col]])
      if (any(nas)) df[[col]][nas] <- medians[[col]]
    }
    for (col in cat_cols) {
      nas <- is.na(df[[col]])
      if (any(nas)) {
        if (is.factor(df[[col]])) {
          levels(df[[col]]) <- c(levels(df[[col]]), "unknown")
        } else {
          df[[col]] <- as.character(df[[col]])
        }
        df[[col]][nas] <- "unknown"
        if (!is.factor(df[[col]])) df[[col]] <- factor(df[[col]])
      }
    }
    df
  }

  lapply(splits, apply_imputation)
}

#' Rename target to `y` (0/1) and all features to `x1 ... xn`
#'
#' @param df          A tibble.
#' @param target_col  Name of the target column in `df`.
#' @param positive_class  Value in the original target that maps to y = 1.
#'                        If NULL, the column is coerced to integer as-is.
standardize_columns <- function(df, target_col, positive_class = NULL) {
  df <- dplyr::rename(df, y = !!rlang::sym(target_col))

  if (!is.null(positive_class)) {
    df <- dplyr::mutate(df, y = as.integer(y == positive_class))
  } else {
    df <- dplyr::mutate(df, y = as.integer(y))
  }

  dplyr::rename_with(df, ~ paste0("x", seq_along(.x)), .cols = -y)
}

#' Split a standardized dataset into train / calibration / test
#'
#' Stratification is done on `y` so class proportions are preserved in every
#' partition. The same seed is used for all datasets so splits are reproducible.
#'
#' @param df         A tibble with a column named `y`.
#' @param train_prop Proportion for the training partition (default 0.60).
#' @param cal_prop   Proportion for the calibration partition (default 0.20).
#' @param seed       Random seed (default 42).
#' @return Named list with elements `train`, `calibration`, `test`.
stratified_split <- function(df, train_prop = 0.60, cal_prop = 0.20, seed = 42) {
  set.seed(seed)

  split_idx <- function(idx) {
    n       <- length(idx)
    s       <- sample(idx)
    n_train <- round(n * train_prop)
    n_cal   <- round(n * cal_prop)
    list(
      train       = s[seq_len(n_train)],
      calibration = s[seq(n_train + 1, n_train + n_cal)],
      test        = s[seq(n_train + n_cal + 1, n)]
    )
  }

  s0 <- split_idx(which(df$y == 0))
  s1 <- split_idx(which(df$y == 1))

  list(
    train       = df[sort(c(s0$train,       s1$train)),       ],
    calibration = df[sort(c(s0$calibration, s1$calibration)), ],
    test        = df[sort(c(s0$test,        s1$test)),        ]
  )
}

#' Write train / calibration / test splits to Parquet files
#'
#' @param splits Named list returned by `stratified_split()` or `impute_splits()`.
#' @param name   Dataset identifier used in the output filenames.
#' @param dir    Output directory relative to project root (default `"data/interim"`).
save_splits <- function(splits, name, dir = "data/interim") {
  out_dir <- here::here(dir, name)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  for (partition in names(splits)) {
    path <- file.path(out_dir, paste0(partition, ".parquet"))
    arrow::write_parquet(splits[[partition]], path)
    message("Saved ", path,
            " (", nrow(splits[[partition]]), " rows | y=1: ",
            sum(splits[[partition]]$y), ")")
  }
}

#' Load train / calibration / test splits from Parquet files
#'
#' @param name Dataset identifier used in the filenames.
#' @param dir  Directory to read from relative to project root (default `"data/interim"`).
#' @return Named list with elements `train`, `calibration`, `test`.
load_splits <- function(name, dir = "data/interim") {
  partitions <- c("train", "calibration", "test")
  splits <- lapply(partitions, function(pt) {
    arrow::read_parquet(here::here(dir, name, paste0(pt, ".parquet")))
  })
  setNames(splits, partitions)
}

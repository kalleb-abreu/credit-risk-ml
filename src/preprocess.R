library(here)
library(dplyr)
library(arrow)

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

#' Write train / calibration / test splits to `data/interim/` as Parquet files
#'
#' @param splits Named list returned by `stratified_split()`.
#' @param name   Dataset identifier used in the output filenames.
save_splits <- function(splits, name) {
  for (partition in names(splits)) {
    path <- here::here("data/interim", paste0(name, "_", partition, ".parquet"))
    arrow::write_parquet(splits[[partition]], path)
    message("Saved ", path,
            " (", nrow(splits[[partition]]), " rows | y=1: ",
            sum(splits[[partition]]$y), ")")
  }
}

library(probably)
library(dplyr)

# probably's cal_estimate_* and cal_apply require both .pred_0 and .pred_1.
# Since we only store .pred_1, derive .pred_0 = 1 - .pred_1 at the boundary.
add_pred_0 <- function(preds) {
  preds |>
    mutate(.pred_0 = 1 - .pred_1) |>
    select(any_of("y"), .pred_0, .pred_1)
}

#' Fit Platt and isotonic calibrators from calibration-partition predictions
#'
#' @param preds Tibble with columns `y` and `.pred_1` (as written by 05_train.R).
#' @return Named list: `platt`, `isotonic`.
fit_calibrators <- function(preds) {
  preds <- preds |>
    mutate(y = factor(as.character(y), levels = c("0", "1"))) |>
    add_pred_0()

  list(
    platt    = cal_estimate_logistic(preds, truth = y),
    isotonic = cal_estimate_isotonic(preds, truth = y)
  )
}

#' Apply a fitted calibrator to a prediction tibble
#'
#' @param preds       Tibble with `y` and `.pred_1` columns.
#' @param calibrator  A calibration object from `fit_calibrators()`, or NULL for uncalibrated.
#' @return Tibble (same columns as input) with `.pred_1` replaced by calibrated probabilities.
apply_calibrator <- function(preds, calibrator = NULL) {
  if (is.null(calibrator)) return(preds)
  preds |>
    add_pred_0() |>
    cal_apply(calibrator) |>
    select(any_of("y"), .pred_1)
}

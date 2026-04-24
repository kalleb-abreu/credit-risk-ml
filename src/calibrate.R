library(probably)
library(dplyr)

#' Fit Platt and isotonic calibrators from calibration-partition predictions
#'
#' @param preds Tibble with columns `y` and `.pred_1` (as written by 05_train.R).
#' @return Named list: `platt`, `isotonic`.
fit_calibrators <- function(preds) {
  preds <- preds |>
    mutate(y = factor(as.character(y), levels = c("0", "1")))

  list(
    platt    = cal_estimate_logistic(preds, truth = y, estimate = .pred_1,
                                     event_level = "second"),
    isotonic = cal_estimate_isotonic(preds, truth = y, estimate = .pred_1,
                                     event_level = "second")
  )
}

#' Apply a fitted calibrator to a prediction tibble
#'
#' @param preds       Tibble with `.pred_1` column.
#' @param calibrator  A calibration object from `fit_calibrators()`, or NULL for uncalibrated.
#' @return Tibble with `.pred_1` replaced by calibrated probabilities.
apply_calibrator <- function(preds, calibrator = NULL) {
  if (is.null(calibrator)) return(preds)
  cal_apply(preds, calibrator)
}

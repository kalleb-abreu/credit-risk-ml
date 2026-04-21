library(probably)

#' Fit Platt and isotonic calibrators from calibration-set predictions
#'
#' @param preds  Tibble with columns `y` (factor 0/1) and `.pred_1` (numeric).
#' @return Named list: `platt`, `isotonic` — calibration model objects.
fit_calibrators <- function(preds) {
  preds <- preds |> mutate(y = factor(y, levels = c(0, 1)))
  list(
    platt    = cal_estimate_logistic(preds, truth = y, estimate = .pred_1),
    isotonic = cal_estimate_isotonic(preds, truth = y, estimate = .pred_1)
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

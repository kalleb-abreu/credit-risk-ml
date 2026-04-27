suppressPackageStartupMessages({
  library(yardstick)
  library(CalibrationCurves)
  library(dplyr)
})

#' Compute full metric set for one prediction tibble
#'
#' @param preds  Tibble with columns `y` and `.pred_1`.
#' @return Single-row tibble with all metric columns.
compute_metrics <- function(preds) {
  preds <- preds |>
    mutate(
      y           = factor(as.character(y), levels = c("0", "1")),
      .pred_class = factor(
        ifelse(.pred_1 >= 0.5, "1", "0"), levels = c("0", "1")
      )
    )

  y_int <- as.integer(as.character(preds$y))

  p1     <- pmin(pmax(preds$.pred_1, 1e-6), 1 - 1e-6)
  ece    <- unname(val.prob.ci.2(p1, y_int, pl = FALSE)$stats[["Eavg"]])

  tibble(
    pr_auc = pr_auc(
      preds, truth = y, .pred_1, event_level = "second"
    )$.estimate,
    roc_auc = roc_auc(
      preds, truth = y, .pred_1, event_level = "second"
    )$.estimate,
    mcc         = mcc(preds, truth = y, estimate = .pred_class)$.estimate,
    brier_score = mean((preds$.pred_1 - y_int)^2),
    ece         = ece,
    log_loss    = mn_log_loss(
      preds, truth = y, .pred_1, event_level = "second"
    )$.estimate,
    sensitivity = sens(
      preds, truth = y, estimate = .pred_class, event_level = "second"
    )$.estimate,
    specificity = spec(
      preds, truth = y, estimate = .pred_class, event_level = "second"
    )$.estimate
  )
}

library(yardstick)

#' Compute full metric set for one prediction tibble
#'
#' @param preds  Tibble with columns `y` (factor 0/1) and `.pred_1` (numeric).
#' @return Single-row tibble with all metric columns.
compute_metrics <- function(preds) {
  preds <- preds |> mutate(
    y        = factor(y, levels = c(0, 1)),
    .pred_class = factor(as.integer(.pred_1 >= 0.5), levels = c(0, 1))
  )

  prob_metrics  <- metric_set(pr_auc, roc_auc, brier_class, mn_log_loss)
  class_metrics <- metric_set(mcc, sens, spec)

  bind_rows(
    prob_metrics(preds,  truth = y, estimate = .pred_1,    event_level = "second"),
    class_metrics(preds, truth = y, estimate = .pred_class, event_level = "second")
  ) |>
    select(.metric, .estimate) |>
    pivot_wider(names_from = .metric, values_from = .estimate) |>
    rename(
      brier_score  = brier_class,
      log_loss     = mn_log_loss,
      sensitivity  = sens,
      specificity  = spec
    )
}

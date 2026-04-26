suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(probably)
})

DATASET_ORDER <- c(
  "ulb", "ieee", "bank_marketing", "taiwan", "south_german", "australian"
)

RESAMPLING_ORDER <- c(
  "none", "upsample", "smote", "adasyn",
  "downsample", "tomek", "nearmiss",
  "smote_tomek", "smote_enn"
)

CALIBRATION_ORDER <- c("none", "platt", "isotonic")

#' Heatmap of a discrimination metric: resampling × dataset, uncalibrated only
#'
#' @param metrics   The test_metrics tibble.
#' @param metric    Column name (string) to plot.
#' @param title     Plot title.
plot_heatmap <- function(metrics, metric, title) {
  metrics |>
    filter(calibration == "none") |>
    mutate(
      dataset    = factor(dataset,    levels = DATASET_ORDER),
      resampling = factor(resampling, levels = RESAMPLING_ORDER)
    ) |>
    ggplot(aes(x = dataset, y = resampling, fill = .data[[metric]])) +
    geom_tile(color = "white") +
    facet_wrap(~classifier) +
    scale_fill_viridis_c() +
    labs(title = title, x = NULL, y = NULL, fill = metric) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}

#' Heatmap of a calibration metric: calibration method × resampling, averaged over datasets
#'
#' @param metrics   The test_metrics tibble.
#' @param metric    Column name (string) to plot.
#' @param title     Plot title.
plot_calibration_heatmap <- function(metrics, metric, title) {
  metrics |>
    mutate(
      resampling  = factor(resampling,  levels = RESAMPLING_ORDER),
      calibration = factor(calibration, levels = CALIBRATION_ORDER)
    ) |>
    group_by(resampling, calibration, classifier) |>
    summarise(value = mean(.data[[metric]], na.rm = TRUE), .groups = "drop") |>
    ggplot(aes(x = calibration, y = resampling, fill = value)) +
    geom_tile(color = "white") +
    facet_wrap(~classifier) +
    scale_fill_viridis_c() +
    labs(title = title, x = NULL, y = NULL, fill = metric) +
    theme_minimal()
}

#' Reliability diagram overlaying uncalibrated, Platt, and isotonic for one config
#'
#' @param preds_list  Named list ("none", "platt", "isotonic"), each a tibble(y, .pred_1).
#' @param title       Plot title.
#' @param n_bins      Number of equal-width bins (default 10).
plot_reliability_triple <- function(preds_list, title, n_bins = 10) {
  breaks <- seq(0, 1, length.out = n_bins + 1)

  bins <- map_dfr(names(preds_list), function(cal) {
    p <- preds_list[[cal]] |>
      mutate(
        y_int = as.integer(as.character(factor(as.character(y), levels = c("0", "1")))),
        bin   = cut(.pred_1, breaks = breaks, include.lowest = TRUE)
      )
    p |>
      group_by(bin) |>
      summarise(
        mean_pred   = mean(.pred_1),
        mean_actual = mean(y_int),
        n           = n(),
        .groups     = "drop"
      ) |>
      filter(n > 0) |>
      mutate(calibration = cal)
  }) |>
    mutate(calibration = factor(calibration, levels = CALIBRATION_ORDER))

  ggplot(bins, aes(x = mean_pred, y = mean_actual, color = calibration)) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "gray60") +
    geom_line() +
    geom_point(aes(size = n)) +
    scale_color_manual(
      values = c(none = "#E41A1C", platt = "#377EB8", isotonic = "#4DAF4A")
    ) +
    scale_size_continuous(range = c(1, 4), guide = "none") +
    labs(
      title = title,
      x = "Mean predicted probability",
      y = "Observed fraction positive",
      color = "Calibration"
    ) +
    xlim(0, 1) + ylim(0, 1) +
    theme_minimal()
}

#' Reliability diagram for one prediction tibble (single curve, uses probably)
#'
#' @param preds  Tibble with `y` and `.pred_1` columns.
#' @param title  Plot title.
plot_reliability <- function(preds, title) {
  preds <- preds |>
    mutate(y = factor(as.character(y), levels = c("0", "1")))
  cal_plot_breaks(preds, truth = y, estimate = .pred_1, event_level = "second") +
    labs(title = title) +
    theme_minimal()
}

#' Main results table: mean PR-AUC and Brier Score by resampling × classifier (uncalibrated)
#'
#' @param metrics  The test_metrics tibble.
#' @return Tibble averaged over datasets, sorted by resampling then classifier.
main_results_table <- function(metrics) {
  metrics |>
    filter(calibration == "none") |>
    group_by(resampling, classifier) |>
    summarise(
      mean_pr_auc      = mean(pr_auc,      na.rm = TRUE),
      mean_brier_score = mean(brier_score, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(
      resampling = factor(resampling, levels = RESAMPLING_ORDER),
      classifier = factor(classifier, levels = c("logreg", "rf", "lgbm"))
    ) |>
    arrange(resampling, classifier)
}

#' Calibration delta table: ECE and Brier Score before vs. after calibration
#'
#' @param metrics  The test_metrics tibble.
#' @return Wide tibble with per-method deltas (positive = improvement).
calibration_delta <- function(metrics) {
  metrics |>
    select(dataset, classifier, resampling, calibration, brier_score, ece) |>
    pivot_wider(
      names_from  = calibration,
      values_from = c(brier_score, ece)
    ) |>
    mutate(
      brier_delta_platt    = brier_score_none - brier_score_platt,
      brier_delta_isotonic = brier_score_none - brier_score_isotonic,
      ece_delta_platt      = ece_none - ece_platt,
      ece_delta_isotonic   = ece_none - ece_isotonic
    )
}

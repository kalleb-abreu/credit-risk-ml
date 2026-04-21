library(ggplot2)
library(dplyr)
library(tidyr)
library(probably)

DATASET_ORDER <- c(
  "ulb", "ieee_cis", "bank_marketing", "taiwan", "south_german", "australian"
)

RESAMPLING_ORDER <- c(
  "none", "upsample", "smote", "adasyn",
  "downsample", "tomek", "nearmiss",
  "smote_tomek", "smote_enn"
)

CALIBRATION_ORDER <- c("none", "platt", "isotonic")

#' Heatmap of a single metric across resampling conditions × datasets
#'
#' @param metrics   The test_metrics tibble.
#' @param metric    Column name (string) to plot.
#' @param title     Plot title.
plot_heatmap <- function(metrics, metric, title) {
  metrics |>
    filter(calibration == "none") |>
    mutate(
      dataset   = factor(dataset,   levels = DATASET_ORDER),
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

#' Reliability diagram for one classifier × dataset combination
#'
#' @param preds  Tibble with `y` (factor) and `.pred_1` columns.
#' @param title  Plot title.
plot_reliability <- function(preds, title) {
  preds <- preds |> mutate(y = factor(y, levels = c(0, 1)))
  cal_plot_breaks(preds, truth = y, estimate = .pred_1, event_level = "second") +
    labs(title = title) +
    theme_minimal()
}

#' Calibration delta table: ECE and Brier Score before vs. after calibration
#'
#' @param metrics  The test_metrics tibble.
#' @return Wide tibble with columns for uncalibrated, Platt, isotonic per metric.
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

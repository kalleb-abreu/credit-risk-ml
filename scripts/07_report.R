suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(arrow)
  library(ggplot2)
  library(tidyr)
  library(readr)
})

source(here("src/report.R"))
source(here("src/calibrate.R"))

metrics <- read_parquet(here("output", "test_metrics.parquet"))

datasets <- c(
  "ulb", "ieee", "bank_marketing", "taiwan", "south_german", "australian"
)
classifiers <- c("logreg", "rf", "lgbm")

dir.create(here("figures", "results"), recursive = TRUE, showWarnings = FALSE)
dir.create(
  here("figures", "results", "reliability_diagrams"), showWarnings = FALSE
)

# Main results table --------------------------------------------------------

main_tbl <- main_results_table(metrics)
write_csv(main_tbl, here("output", "main_results.csv"))

# PR-AUC heatmap ------------------------------------------------------------

p_pr <- plot_heatmap(metrics, "pr_auc", "PR-AUC by resampling condition")
ggsave(
  here("figures", "results", "pr_auc_heatmap.png"),
  p_pr, width = 12, height = 6
)

# Brier Score heatmap: calibration method × resampling ---------------------

p_brier <- plot_calibration_heatmap(
  metrics, "brier_score", "Brier Score by calibration method × resampling"
)
ggsave(
  here("figures", "results", "brier_score_heatmap.png"),
  p_brier, width = 10, height = 6
)

# Calibration delta table ---------------------------------------------------

delta <- calibration_delta(metrics)
write_csv(delta, here("output", "calibration_delta.csv"))

# Calibration delta plot ----------------------------------------------------

p_delta <- delta |>
  select(
    dataset, classifier, resampling, ece_delta_platt, ece_delta_isotonic
  ) |>
  pivot_longer(
    starts_with("ece_delta"), names_to = "method", values_to = "ece_reduction"
  ) |>
  mutate(method = sub("ece_delta_", "", method)) |>
  ggplot(aes(x = resampling, y = ece_reduction, fill = method)) +
  geom_col(position = "dodge") +
  facet_grid(classifier ~ dataset) +
  labs(
    title = "ECE reduction from post-hoc calibration",
    x = NULL, y = "ECE reduction"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(
  here("figures", "results", "calibration_delta.png"),
  p_delta, width = 16, height = 8
)

# Reliability diagrams: uncalibrated vs. Platt vs. isotonic ----------------
# One plot per classifier × dataset using the "none" (no resampling) base model.

for (dataset in datasets) {
  for (classifier in classifiers) {
    test_path <- here(
      "predictions", "test", dataset, "none",
      paste0(classifier, "_none.parquet")
    )

    if (!file.exists(test_path)) {
      message(
        "Skipping reliability diagram (missing): ", dataset, "/", classifier
      )
      next
    }

    preds_base <- read_parquet(test_path)

    load_cal <- function(suffix) {
      path <- here(
        "models", "calibrators", dataset, "none",
        paste0(classifier, "_none_", suffix, ".rds")
      )
      if (file.exists(path)) apply_calibrator(preds_base, readRDS(path)) else
        preds_base
    }

    preds_list <- list(
      none     = preds_base,
      platt    = load_cal("platt"),
      isotonic = load_cal("isotonic")
    )

    p <- plot_reliability_triple(preds_list, paste(dataset, classifier))
    dir.create(
      here("figures", "results", "reliability_diagrams", dataset),
      showWarnings = FALSE, recursive = TRUE
    )
    ggsave(
      here(
        "figures", "results", "reliability_diagrams", dataset,
        paste0(classifier, ".png")
      ),
      p,
      width = 6, height = 6
    )
  }
}

message("Report complete. Figures written to figures/results/")

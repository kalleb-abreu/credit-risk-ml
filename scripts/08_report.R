library(here)
library(dplyr)
library(arrow)
library(ggplot2)
library(tidyr)

source(here("src/report.R"))

metrics <- read_parquet(here("output", "test_metrics.parquet"))

dir.create(here("figures", "results"), recursive = TRUE, showWarnings = FALSE)
dir.create(here("figures", "results", "reliability_diagrams"), showWarnings = FALSE)

# PR-AUC heatmap ------------------------------------------------------------

p_pr <- plot_heatmap(metrics, "pr_auc", "PR-AUC by resampling condition")
ggsave(here("figures", "results", "pr_auc_heatmap.png"), p_pr, width = 12, height = 6)

# Brier Score heatmap -------------------------------------------------------

p_brier <- plot_heatmap(
  metrics |> filter(calibration != "none"),
  "brier_score",
  "Brier Score by calibration method × resampling"
)
ggsave(here("figures", "results", "brier_score_heatmap.png"), p_brier, width = 12, height = 6)

# Calibration delta table ---------------------------------------------------

delta <- calibration_delta(metrics)
write_csv(delta, here("output", "calibration_delta.csv"))

# Calibration delta plot ----------------------------------------------------

p_delta <- delta |>
  select(dataset, classifier, resampling, ece_delta_platt, ece_delta_isotonic) |>
  pivot_longer(starts_with("ece_delta"), names_to = "method", values_to = "ece_reduction") |>
  mutate(method = sub("ece_delta_", "", method)) |>
  ggplot(aes(x = resampling, y = ece_reduction, fill = method)) +
  geom_col(position = "dodge") +
  facet_grid(classifier ~ dataset) +
  labs(title = "ECE reduction from post-hoc calibration", x = NULL, y = "ECE reduction") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(here("figures", "results", "calibration_delta.png"), p_delta, width = 16, height = 8)

message("Report complete. Figures written to figures/results/")

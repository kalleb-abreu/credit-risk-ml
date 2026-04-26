suppressPackageStartupMessages(library(here))
source(here::here("src/eda.R"))

dir.create(here::here("output"),  recursive = TRUE, showWarnings = FALSE)
dir.create(here::here("figures"), recursive = TRUE, showWarnings = FALSE)

# --- Structural summary ------------------------------------------------------
message("=== EDA summary ===")
summary_tbl <- eda_summary()
print(summary_tbl)
out_path <- here::here("output/eda_summary.csv")
write.csv(summary_tbl, out_path, row.names = FALSE)
message("Saved ", out_path)

# --- Imbalance spectrum ------------------------------------------------------
p <- plot_imbalance_spectrum()
ggsave(here::here("figures/imbalance_spectrum.png"), p,
       width = 10, height = 4, dpi = 150)
message("Saved figures/imbalance_spectrum.png")

# --- Class distribution bar chart --------------------------------------------
p <- plot_class_distribution()
ggsave(here::here("figures/class_distribution.png"), p,
       width = 7, height = 5, dpi = 150)
message("Saved figures/class_distribution.png")

# --- IEEE-CIS missing value detail -------------------------------------------
p <- plot_missing_detail(top_n = 20)
ggsave(here::here("figures/ieee_missing_cols.png"), p,
       width = 8, height = 7, dpi = 150)
message("Saved figures/ieee_missing_cols.png")

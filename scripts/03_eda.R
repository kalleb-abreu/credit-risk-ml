library(here)
source(here::here("src/eda.R"))

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

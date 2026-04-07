library(here)
source(here::here("src/eda.R"))

# --- Imbalance spectrum ------------------------------------------------------
p <- plot_imbalance_spectrum()
ggsave(here::here("figures/imbalance_spectrum.png"), p,
       width = 10, height = 4, dpi = 150)
message("Saved figures/imbalance_spectrum.png")

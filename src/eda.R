library(here)
library(ggplot2)

#' Plot dataset positions along the imbalance spectrum (0–50%)
plot_imbalance_spectrum <- function() {
  # Okabe-Ito colorblind-safe palette
  scenario_colors <- c(
    "Heavily imbalanced"    = "#D55E00",
    "Moderately imbalanced" = "#0072B2",
    "Near-balanced"         = "#009E73"
  )

  datasets <- data.frame(
    name = c(
      "ULB Credit Card Fraud",
      "IEEE-CIS Fraud Detection",
      "UCI Portuguese Bank Marketing",
      "UCI Taiwan Credit Card Default",
      "UCI South German Credit",
      "UCI Australian Credit Approval"
    ),
    minority_pct = c(0.17, 3.50, 11.3, 22.1, 30.0, 44.5),
    scenario = factor(
      c("Heavily imbalanced", "Heavily imbalanced",
        "Moderately imbalanced", "Moderately imbalanced",
        "Near-balanced", "Near-balanced"),
      levels = c("Heavily imbalanced", "Moderately imbalanced", "Near-balanced")
    ),
    side  = c(1, -1, 1, -1, 1, -1),   # 1 = above, -1 = below
    vjust = c(0,  1, 0,  1, 0,  1),
    hjust = c(0.5, 0.5, 0.5, 0.5, 0, 0.5)
  )

  stem_height <- 0.32

  ggplot(datasets, aes(x = minority_pct, color = scenario)) +
    annotate("rect", xmin =  0, xmax = 10, ymin = -Inf, ymax = Inf,
             fill = "#D55E00", alpha = 0.18) +
    annotate("rect", xmin = 10, xmax = 25, ymin = -Inf, ymax = Inf,
             fill = "#0072B2", alpha = 0.18) +
    annotate("rect", xmin = 25, xmax = 50, ymin = -Inf, ymax = Inf,
             fill = "#009E73", alpha = 0.18) +
    annotate("text", x =  5,    y =  0.88, label = "Heavily\nimbalanced",
             color = "#D55E00", size = 3, fontface = "bold", lineheight = 0.9) +
    annotate("text", x = 17.5,  y =  0.88, label = "Moderately\nimbalanced",
             color = "#0072B2", size = 3, fontface = "bold", lineheight = 0.9) +
    annotate("text", x = 37.5,  y =  0.88, label = "Near-balanced",
             color = "#009E73", size = 3, fontface = "bold", lineheight = 0.9) +
    geom_hline(yintercept = 0, color = "grey60", linewidth = 0.5) +
    geom_segment(
      aes(y = 0, xend = minority_pct, yend = side * stem_height),
      linewidth = 0.4, color = "grey50"
    ) +
    geom_point(aes(y = 0), size = 4) +
    geom_label(
      aes(y = side * (stem_height + 0.04), label = name, vjust = vjust,
          hjust = hjust, fill = scenario),
      size = 2.9,
      color = "white",
      fontface = "bold",
      linewidth = 0,
      label.padding = unit(0.3, "lines"),
      label.r = unit(0.15, "lines"),
      show.legend = FALSE
    ) +
    scale_fill_manual(values = scenario_colors) +
    scale_x_continuous(
      limits = c(-12, 58),
      breaks = c(0, 10, 25, 50),
      labels = c("0%", "10%", "25%", "50%")
    ) +
    scale_color_manual(values = scenario_colors) +
    scale_y_continuous(limits = c(-0.65, 1.05)) +
    labs(x = "Minority class (%)") +
    theme_minimal(base_size = 12) +
    theme(
      axis.title.y  = element_blank(),
      axis.text.y   = element_blank(),
      axis.ticks.y  = element_blank(),
      panel.grid    = element_blank(),
      axis.line.x   = element_line(color = "grey60"),
      legend.position = "none"
    )
}

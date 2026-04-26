suppressPackageStartupMessages({
  library(here)
  library(ggplot2)
  library(dplyr)
  library(arrow)
})

#' Compute structural EDA summary across all six datasets
#'
#' Reads the full data (train + calibration + test combined) from interim
#' Parquet files and returns one summary row per dataset covering feature
#' types, missing values, and numeric scale range.
eda_summary <- function() {
  ids <- c("ulb", "ieee", "bank_marketing", "taiwan", "south_german", "australian")
  names_full <- c(
    "ULB Credit Card Fraud",
    "IEEE-CIS Fraud Detection",
    "UCI Portuguese Bank Marketing",
    "UCI Taiwan Credit Card Default",
    "UCI South German Credit",
    "UCI Australian Credit Approval"
  )

  rows <- lapply(seq_along(ids), function(i) {
    df <- bind_rows(lapply(c("train", "calibration", "test"), function(pt) {
      read_parquet(here::here("data/interim", ids[i], paste0(pt, ".parquet")))
    }))

    feat_cols  <- setdiff(names(df), "y")
    is_num     <- sapply(df[feat_cols], is.numeric)
    n_num      <- sum(is_num)
    n_cat      <- sum(!is_num)

    miss_per_col   <- colSums(is.na(df[feat_cols]))
    n_miss_cols    <- sum(miss_per_col > 0)
    pct_rows_miss  <- round(mean(rowSums(is.na(df[feat_cols])) > 0) * 100, 1)

    if (n_num > 0) {
      ranges    <- sapply(df[feat_cols[is_num]], function(x) diff(range(x, na.rm = TRUE)))
      range_min <- round(min(ranges), 1)
      range_max <- round(max(ranges), 1)
    } else {
      range_min <- NA_real_
      range_max <- NA_real_
    }

    data.frame(
      dataset           = names_full[i],
      n_rows            = nrow(df),
      n_features        = length(feat_cols),
      n_numeric         = n_num,
      n_categorical     = n_cat,
      n_missing_cols    = n_miss_cols,
      pct_rows_missing  = pct_rows_miss,
      numeric_range_min = range_min,
      numeric_range_max = range_max,
      stringsAsFactors  = FALSE
    )
  })

  bind_rows(rows)
}

#' Plot minority class percentage as a bar chart for all six datasets
plot_class_distribution <- function() {
  scenario_colors <- c(
    "Heavily imbalanced"    = "#D55E00",
    "Moderately imbalanced" = "#0072B2",
    "Near-balanced"         = "#009E73"
  )

  datasets <- data.frame(
    name = c(
      "ULB Credit Card Fraud",
      "IEEE-CIS Fraud Detection",
      "UCI Portuguese\nBank Marketing",
      "UCI Taiwan\nCredit Card Default",
      "UCI South\nGerman Credit",
      "UCI Australian\nCredit Approval"
    ),
    minority_pct = c(0.17, 3.50, 11.7, 22.1, 30.0, 44.5),
    scenario = factor(
      c("Heavily imbalanced", "Heavily imbalanced",
        "Moderately imbalanced", "Moderately imbalanced",
        "Near-balanced", "Near-balanced"),
      levels = c("Heavily imbalanced", "Moderately imbalanced", "Near-balanced")
    )
  )

  datasets$name <- factor(datasets$name, levels = datasets$name)

  ggplot(datasets, aes(x = name, y = minority_pct, fill = scenario)) +
    geom_col(width = 0.6) +
    geom_text(
      aes(label = paste0(minority_pct, "%")),
      hjust = -0.15, size = 3.2, color = "grey30"
    ) +
    scale_fill_manual(values = scenario_colors, name = NULL) +
    scale_y_continuous(
      limits = c(0, 55),
      labels = function(x) paste0(x, "%")
    ) +
    coord_flip() +
    labs(x = NULL, y = "Minority class (%)") +
    theme_minimal(base_size = 12) +
    theme(
      legend.position  = "bottom",
      panel.grid.major.y = element_blank(),
      panel.grid.minor   = element_blank()
    )
}

#' Plot top missing columns for IEEE-CIS Fraud Detection
#'
#' Reads the full IEEE-CIS dataset (all partitions combined) from interim
#' Parquet files and ranks feature columns by missingness rate.
#'
#' @param top_n Number of columns to show (default 20).
plot_missing_detail <- function(top_n = 20) {
  df <- bind_rows(lapply(c("train", "calibration", "test"), function(pt) {
    read_parquet(here::here("data/interim", "ieee", paste0(pt, ".parquet")))
  }))

  feat_cols <- setdiff(names(df), "y")
  miss_rate <- sort(
    colMeans(is.na(df[feat_cols])) * 100,
    decreasing = TRUE
  )
  miss_rate <- miss_rate[miss_rate > 0]

  top <- data.frame(
    column   = factor(names(miss_rate)[seq_len(min(top_n, length(miss_rate)))],
                      levels = rev(names(miss_rate)[seq_len(min(top_n, length(miss_rate)))])),
    miss_pct = miss_rate[seq_len(min(top_n, length(miss_rate)))]
  )

  ggplot(top, aes(x = column, y = miss_pct)) +
    geom_col(fill = "#0072B2", width = 0.7) +
    geom_text(
      aes(label = paste0(round(miss_pct, 1), "%")),
      hjust = -0.1, size = 3, color = "grey30"
    ) +
    scale_y_continuous(
      limits = c(0, 105),
      labels = function(x) paste0(x, "%")
    ) +
    coord_flip() +
    labs(
      x = NULL,
      y = "Missing (%)",
      title = paste0("IEEE-CIS: top ", top_n, " columns by missingness rate")
    ) +
    theme_minimal(base_size = 12) +
    theme(
      panel.grid.major.y = element_blank(),
      panel.grid.minor   = element_blank()
    )
}

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

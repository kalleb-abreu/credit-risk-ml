suppressPackageStartupMessages(library(here))
source(here::here("src/report.R"))

# Shared fixture: small metrics tibble covering all calibration methods
make_metrics <- function() {
  classifiers  <- c("logreg", "rf")
  resamplings  <- c("none", "smote")
  calibrations <- c("none", "platt", "isotonic")
  datasets     <- c("australian", "south_german")

  rows <- expand.grid(
    dataset     = datasets,
    classifier  = classifiers,
    resampling  = resamplings,
    calibration = calibrations,
    stringsAsFactors = FALSE
  )
  set.seed(1)
  rows$pr_auc      <- runif(nrow(rows), 0.5, 0.9)
  rows$brier_score <- runif(nrow(rows), 0.05, 0.25)
  rows$ece         <- runif(nrow(rows), 0.01, 0.1)
  rows
}

# main_results_table() --------------------------------------------------------

describe("main_results_table()", {
  metrics <- make_metrics()
  out     <- main_results_table(metrics)

  it("drops the calibration column after filtering to none", {
    expect_false("calibration" %in% names(out))
  })

  it("groups by resampling and classifier", {
    expect_true(all(c("resampling", "classifier") %in% names(out)))
  })

  it("returns mean_pr_auc and mean_brier_score columns", {
    expect_true(all(c("mean_pr_auc", "mean_brier_score") %in% names(out)))
  })

  it("has one row per resampling-classifier combination", {
    n_expected <- length(unique(metrics$resampling)) *
      length(unique(metrics$classifier))
    expect_equal(nrow(out), n_expected)
  })

  it("mean_pr_auc is within the range of inputs", {
    expect_true(all(out$mean_pr_auc >= 0.5 & out$mean_pr_auc <= 0.9))
  })
})

# calibration_delta() ---------------------------------------------------------

describe("calibration_delta()", {
  metrics <- make_metrics()
  out     <- calibration_delta(metrics)

  it("returns delta columns for brier_score", {
    expect_true(all(c(
      "brier_delta_platt", "brier_delta_isotonic"
    ) %in% names(out)))
  })

  it("returns delta columns for ece", {
    expect_true(all(c(
      "ece_delta_platt", "ece_delta_isotonic"
    ) %in% names(out)))
  })

  it("brier_delta_platt equals none minus platt", {
    expect_equal(
      out$brier_delta_platt,
      out$brier_score_none - out$brier_score_platt
    )
  })

  it("ece_delta_isotonic equals none minus isotonic", {
    expect_equal(
      out$ece_delta_isotonic,
      out$ece_none - out$ece_isotonic
    )
  })
})

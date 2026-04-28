suppressPackageStartupMessages(library(here))
source(here::here("src/evaluate.R"))

# compute_metrics() -----------------------------------------------------------

describe("compute_metrics()", {
  set.seed(42)
  n <- 200
  y_true <- rep(c(0L, 1L), each = n / 2)

  # Non-extreme predictions so val.prob.ci.2 GLM fitting is well-conditioned
  good_preds <- data.frame(
    y       = y_true,
    .pred_1 = c(runif(n / 2, 0.15, 0.45), runif(n / 2, 0.55, 0.85))
  )
  random_preds <- data.frame(
    y       = y_true,
    .pred_1 = runif(n, 0.1, 0.9)
  )

  # Compute once; val.prob.ci.2 emits expected GLM warnings for any
  # well-separated data — suppress them here, not in assertions.
  good_m   <- suppressWarnings(compute_metrics(good_preds))
  random_m <- suppressWarnings(compute_metrics(random_preds))

  it("returns a single-row tibble", {
    expect_equal(nrow(good_m), 1)
  })

  it("contains all expected metric columns", {
    expected_cols <- c(
      "pr_auc", "roc_auc", "mcc", "brier_score", "ece",
      "log_loss", "sensitivity", "specificity"
    )
    expect_true(all(expected_cols %in% names(good_m)))
  })

  it("roc_auc is in [0, 1]", {
    expect_true(good_m$roc_auc >= 0 && good_m$roc_auc <= 1)
  })

  it("pr_auc is in [0, 1]", {
    expect_true(good_m$pr_auc >= 0 && good_m$pr_auc <= 1)
  })

  it("brier_score is in [0, 1]", {
    expect_true(good_m$brier_score >= 0 && good_m$brier_score <= 1)
  })

  it("good predictions yield higher roc_auc than random", {
    expect_gt(good_m$roc_auc, random_m$roc_auc)
  })

  it("good predictions yield lower brier_score than random", {
    expect_lt(good_m$brier_score, random_m$brier_score)
  })
})

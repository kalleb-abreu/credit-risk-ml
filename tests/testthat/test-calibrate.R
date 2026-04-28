suppressPackageStartupMessages(library(here))
source(here::here("src/calibrate.R"))

# add_pred_0() ----------------------------------------------------------------

describe("add_pred_0()", {
  preds <- data.frame(y = c(0L, 1L), .pred_1 = c(0.3, 0.7))

  it("adds .pred_0 column equal to 1 - .pred_1", {
    out <- add_pred_0(preds)
    expect_equal(out$.pred_0, c(0.7, 0.3))
  })

  it("returns both .pred_0 and .pred_1 columns", {
    out <- add_pred_0(preds)
    expect_true(all(c(".pred_0", ".pred_1") %in% names(out)))
  })

  it("pred_0 + pred_1 sums to 1 for every row", {
    out <- add_pred_0(preds)
    expect_equal(out$.pred_0 + out$.pred_1, rep(1.0, nrow(preds)))
  })
})

# apply_calibrator() ----------------------------------------------------------

describe("apply_calibrator()", {
  preds <- data.frame(y = c(0L, 1L, 0L), .pred_1 = c(0.2, 0.8, 0.4))

  it("returns preds unchanged when calibrator is NULL", {
    out <- apply_calibrator(preds, calibrator = NULL)
    expect_equal(out$.pred_1, preds$.pred_1)
  })

  it("preserves y column when calibrator is NULL", {
    out <- apply_calibrator(preds, calibrator = NULL)
    expect_equal(out$y, preds$y)
  })

  it("returns the same object when calibrator is NULL", {
    out <- apply_calibrator(preds, calibrator = NULL)
    expect_equal(out, preds)
  })
})

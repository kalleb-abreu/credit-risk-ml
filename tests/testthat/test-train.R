suppressPackageStartupMessages(library(here))
source(here::here("src/train.R"))

# resampling_category() -------------------------------------------------------

describe("resampling_category()", {
  it("returns 'none' for none", {
    expect_equal(resampling_category("none"), "none")
  })

  it("returns 'oversample' for upsample, smote, adasyn", {
    expect_equal(resampling_category("upsample"), "oversample")
    expect_equal(resampling_category("smote"),    "oversample")
    expect_equal(resampling_category("adasyn"),   "oversample")
  })

  it("returns 'undersample' for downsample, tomek, nearmiss", {
    expect_equal(resampling_category("downsample"), "undersample")
    expect_equal(resampling_category("tomek"),      "undersample")
    expect_equal(resampling_category("nearmiss"),   "undersample")
  })

  it("returns 'hybrid' for smote_tomek and smote_enn", {
    expect_equal(resampling_category("smote_tomek"), "hybrid")
    expect_equal(resampling_category("smote_enn"),   "hybrid")
  })

  it("errors on unknown resampling key", {
    expect_error(resampling_category("unknown_key"))
  })
})

# spec_logreg() ---------------------------------------------------------------

describe("spec_logreg()", {
  it("returns a model spec with glmnet engine", {
    spec <- spec_logreg(penalty = 0.01)
    expect_equal(spec$engine, "glmnet")
  })

  it("sets the provided penalty", {
    spec <- spec_logreg(penalty = 0.05)
    expect_equal(rlang::eval_tidy(spec$args$penalty), 0.05)
  })

  it("uses mixture from cfg when provided", {
    cfg <- list(models = list(logreg = list(mixture = 0.8)))
    spec <- spec_logreg(penalty = 0.01, cfg = cfg)
    expect_equal(rlang::eval_tidy(spec$args$mixture), 0.8)
  })
})

# spec_rf() -------------------------------------------------------------------

describe("spec_rf()", {
  it("returns a model spec with ranger engine", {
    spec <- spec_rf()
    expect_equal(spec$engine, "ranger")
  })

  it("uses trees and min_n from cfg when provided", {
    cfg <- list(models = list(rf = list(trees = 200, min_n = 10)))
    spec <- spec_rf(cfg = cfg)
    expect_equal(rlang::eval_tidy(spec$args$trees), 200)
    expect_equal(rlang::eval_tidy(spec$args$min_n), 10)
  })
})

# spec_lgbm() -----------------------------------------------------------------

describe("spec_lgbm()", {
  it("returns a model spec with lightgbm engine", {
    spec <- spec_lgbm()
    expect_equal(spec$engine, "lightgbm")
  })

  it("uses trees and learn_rate from cfg when provided", {
    cfg <- list(models = list(lgbm = list(
      trees = 100, learn_rate = 0.1, num_leaves = 15
    )))
    spec <- spec_lgbm(cfg = cfg)
    expect_equal(rlang::eval_tidy(spec$args$trees), 100)
    expect_equal(rlang::eval_tidy(spec$args$learn_rate), 0.1)
  })
})

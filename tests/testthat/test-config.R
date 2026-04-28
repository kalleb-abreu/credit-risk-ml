suppressPackageStartupMessages(library(here))
source(here::here("src/config.R"))

# all_resamplings() -----------------------------------------------------------

describe("all_resamplings()", {
  cfg <- list(
    resamplings = list(
      none        = list("none"),
      oversample  = list("upsample", "smote"),
      undersample = list("downsample")
    )
  )

  it("returns a character vector", {
    out <- all_resamplings(cfg)
    expect_true(is.character(out))
  })

  it("flattens all groups into one vector", {
    out <- all_resamplings(cfg)
    expect_equal(length(out), 4)
  })

  it("contains all resampling keys", {
    out <- all_resamplings(cfg)
    expect_setequal(out, c("none", "upsample", "smote", "downsample"))
  })

  it("returns empty character vector when resamplings is empty", {
    out <- all_resamplings(list(resamplings = list()))
    expect_equal(length(out), 0)
  })
})

# load_config() ---------------------------------------------------------------

describe("load_config()", {
  it("returns a list", {
    out <- load_config()
    expect_true(is.list(out))
  })

  it("contains expected top-level keys", {
    out <- load_config()
    expect_true(all(c("splits", "datasets", "resamplings") %in% names(out)))
  })

  it("splits has train, calibration, and seed", {
    out <- load_config()
    expect_true(all(c("train", "calibration", "seed") %in% names(out$splits)))
  })

  it("train + calibration proportions are in (0, 1) and sum < 1", {
    out <- load_config()
    expect_true(out$splits$train > 0 && out$splits$train < 1)
    expect_true(out$splits$calibration > 0 && out$splits$calibration < 1)
    expect_true(out$splits$train + out$splits$calibration < 1)
  })
})

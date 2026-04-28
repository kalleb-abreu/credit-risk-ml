suppressPackageStartupMessages({
  library(here)
  library(readr)
  library(dplyr)
  library(withr)
})
source(here::here("src/ingest.R"))

# Shared mock: here::here becomes file.path so absolute paths pass through
identity_here <- function(...) file.path(...)

# class_distribution() --------------------------------------------------------

describe("class_distribution()", {
  df <- data.frame(y = c(0L, 0L, 0L, 1L))

  it("returns one row per class value", {
    out <- class_distribution(df, "y")
    expect_equal(nrow(out), 2)
  })

  it("counts are correct", {
    out <- class_distribution(df, "y")
    expect_equal(out$n[out$y == 0], 3)
    expect_equal(out$n[out$y == 1], 1)
  })

  it("percentages sum to 100", {
    out <- class_distribution(df, "y")
    expect_equal(sum(out$pct), 100)
  })

  it("minority class percentage is correct", {
    out <- class_distribution(df, "y")
    expect_equal(out$pct[out$y == 1], 25)
  })
})

# load_csv() ------------------------------------------------------------------

describe("load_csv()", {
  it("reads a CSV and returns a tibble", {
    tmp <- withr::local_tempfile(fileext = ".csv")
    write_csv(data.frame(a = 1:3, b = c("x", "y", "z")), tmp)
    local_mocked_bindings(here = identity_here, .package = "here")
    out <- load_csv(tmp)
    expect_equal(nrow(out), 3)
    expect_equal(names(out), c("a", "b"))
  })

  it("returns correct values", {
    tmp <- withr::local_tempfile(fileext = ".csv")
    write_csv(data.frame(val = c(10, 20)), tmp)
    local_mocked_bindings(here = identity_here, .package = "here")
    out <- load_csv(tmp)
    expect_equal(out$val, c(10, 20))
  })
})

# load_ucimlrepo() ------------------------------------------------------------

describe("load_ucimlrepo()", {
  it("binds features.csv and targets.csv into one tibble", {
    tmp_dir <- withr::local_tempdir()
    write_csv(
      data.frame(x1 = 1:3, x2 = 4:6),
      file.path(tmp_dir, "features.csv")
    )
    write_csv(data.frame(y = c(0, 1, 0)), file.path(tmp_dir, "targets.csv"))
    local_mocked_bindings(here = identity_here, .package = "here")
    out <- load_ucimlrepo(tmp_dir)
    expect_equal(ncol(out), 3)
    expect_equal(nrow(out), 3)
    expect_equal(names(out), c("x1", "x2", "y"))
  })
})

# load_ieee() -----------------------------------------------------------------

describe("load_ieee()", {
  it("left-joins transactions and identity on TransactionID and drops it", {
    tmp_dir <- withr::local_tempdir()
    write_csv(
      data.frame(TransactionID = 1:3, amount = c(10.0, 20.0, 30.0)),
      file.path(tmp_dir, "train_transaction.csv")
    )
    write_csv(
      data.frame(TransactionID = c(1L, 3L), device = c("mobile", "desktop")),
      file.path(tmp_dir, "train_identity.csv")
    )
    local_mocked_bindings(here = identity_here, .package = "here")
    out <- load_ieee(tmp_dir)
    expect_false("TransactionID" %in% names(out))
    expect_equal(nrow(out), 3)
    expect_equal(out$amount, c(10.0, 20.0, 30.0))
  })

  it("keeps all transaction rows even when identity is missing (left join)", {
    tmp_dir <- withr::local_tempdir()
    write_csv(
      data.frame(TransactionID = 1:3, amount = c(5.0, 6.0, 7.0)),
      file.path(tmp_dir, "train_transaction.csv")
    )
    write_csv(
      data.frame(TransactionID = 1L, device = "mobile"),
      file.path(tmp_dir, "train_identity.csv")
    )
    local_mocked_bindings(here = identity_here, .package = "here")
    out <- load_ieee(tmp_dir)
    expect_equal(nrow(out), 3)
    expect_true(any(is.na(out$device)))
  })
})

suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(readr)
  library(withr)
})
source(here::here("src/preprocess.R"))

# cast_types() ---------------------------------------------------------------

describe("cast_types()", {
  df <- data.frame(
    a = c("1", "2", "3"),
    b = c("1.5", "2.5", "3.5"),
    c = c("x", "y", "z"),
    stringsAsFactors = FALSE
  )

  it("casts column to integer", {
    out <- cast_types(df, c(a = "integer"))
    expect_true(is.integer(out$a))
    expect_equal(out$a, c(1L, 2L, 3L))
  })

  it("casts column to double", {
    out <- cast_types(df, c(b = "double"))
    expect_true(is.double(out$b))
    expect_equal(out$b, c(1.5, 2.5, 3.5))
  })

  it("casts column to factor", {
    out <- cast_types(df, c(c = "factor"))
    expect_true(is.factor(out$c))
    expect_equal(levels(out$c), c("x", "y", "z"))
  })

  it("silently skips columns not present in df", {
    expect_no_error(cast_types(df, c(z = "integer")))
    out <- cast_types(df, c(z = "integer"))
    expect_equal(names(out), names(df))
  })

  it("leaves untouched columns unchanged", {
    out <- cast_types(df, c(a = "integer"))
    expect_identical(out$b, df$b)
    expect_identical(out$c, df$c)
  })
})

# cast_types_from_variables() ------------------------------------------------

describe("cast_types_from_variables()", {
  df <- data.frame(
    age    = c("25", "30"),
    income = c("50000.5", "60000.0"),
    job    = c("admin", "tech"),
    target = c("0", "1"),
    stringsAsFactors = FALSE
  )

  make_vars_csv <- function(path) {
    write_csv(
      data.frame(
        name = c("age", "income", "job", "target"),
        role = c("Feature", "Feature", "Feature", "Target"),
        type = c("Integer", "Continuous", "Categorical", "Categorical"),
        stringsAsFactors = FALSE
      ),
      path
    )
  }

  it("casts Feature columns to correct types", {
    tmp <- withr::local_tempfile(fileext = ".csv")
    make_vars_csv(tmp)
    local_mocked_bindings(here = function(...) tmp, .package = "here")
    out <- cast_types_from_variables(df, "ignored")
    expect_true(is.integer(out$age))
    expect_true(is.double(out$income))
    expect_true(is.factor(out$job))
  })

  it("does not modify Target role columns", {
    tmp <- withr::local_tempfile(fileext = ".csv")
    make_vars_csv(tmp)
    local_mocked_bindings(here = function(...) tmp, .package = "here")
    out <- cast_types_from_variables(df, "ignored")
    expect_identical(out$target, df$target)
  })
})

# standardize_columns() -------------------------------------------------------

describe("standardize_columns()", {
  df <- data.frame(
    label = c("good", "bad", "good", "bad"),
    feat1 = 1:4,
    feat2 = c(10.0, 20.0, 30.0, 40.0)
  )

  it("renames target column to y", {
    out <- standardize_columns(df, "label", positive_class = "good")
    expect_true("y" %in% names(out))
    expect_false("label" %in% names(out))
  })

  it("encodes positive_class as y = 1 and others as y = 0", {
    out <- standardize_columns(df, "label", positive_class = "good")
    expect_equal(out$y, c(1L, 0L, 1L, 0L))
  })

  it("renames all feature columns to x1, x2, ...", {
    out <- standardize_columns(df, "label", positive_class = "good")
    feat_names <- sort(setdiff(names(out), "y"))
    expect_equal(feat_names, c("x1", "x2"))
  })

  it("coerces y to integer as-is when positive_class is NULL", {
    df2 <- data.frame(target = c(1, 0, 1), feat = 1:3)
    out <- standardize_columns(df2, "target")
    expect_equal(out$y, c(1L, 0L, 1L))
    expect_true(is.integer(out$y))
  })
})

# stratified_split() ----------------------------------------------------------

describe("stratified_split()", {
  set.seed(7)
  df <- data.frame(
    y  = c(rep(0L, 100), rep(1L, 50)),
    x1 = rnorm(150)
  )

  splits <- stratified_split(df, train_prop = 0.6, cal_prop = 0.2, seed = 42)

  it("returns a named list with train, calibration, test", {
    expect_setequal(names(splits), c("train", "calibration", "test"))
  })

  it("all rows appear exactly once across splits", {
    total <- nrow(splits$train) + nrow(splits$calibration) + nrow(splits$test)
    expect_equal(total, nrow(df))
  })

  it("train size is approximately 60% of total", {
    expect_equal(nrow(splits$train) / nrow(df), 0.6, tolerance = 0.05)
  })

  it("preserves class-1 proportion in the training split", {
    orig_rate  <- mean(df$y == 1)
    train_rate <- mean(splits$train$y == 1)
    expect_equal(train_rate, orig_rate, tolerance = 0.05)
  })

  it("produces identical results given the same seed", {
    splits2 <- stratified_split(df, train_prop = 0.6, cal_prop = 0.2, seed = 42)
    expect_equal(splits$train, splits2$train)
    expect_equal(splits$test,  splits2$test)
  })
})

# impute_splits() -------------------------------------------------------------

describe("impute_splits()", {
  train_df <- data.frame(
    y   = c(0L, 1L, 0L, 1L),
    num = c(1.0, 2.0, NA_real_, 4.0),
    cat = factor(c("a", "b", NA_character_, "a"))
  )
  # train median of num (ignoring NA): median(c(1, 2, 4)) = 2
  train_median <- 2.0

  other_df <- data.frame(
    y   = c(0L, 1L),
    num = c(NA_real_, 5.0),
    cat = factor(c(NA_character_, "b"), levels = c("a", "b"))
  )

  splits <- list(train = train_df, calibration = other_df, test = other_df)
  out    <- impute_splits(splits)

  it("fills numeric NA in train with training median", {
    expect_equal(out$train$num[3], train_median)
  })

  it("fills factor NA in train with 'unknown' level", {
    expect_equal(as.character(out$train$cat[3]), "unknown")
  })

  it("leaves non-NA numeric values unchanged", {
    expect_equal(out$train$num[c(1, 2, 4)], c(1.0, 2.0, 4.0))
  })

  it("uses training median for calibration NAs (no leakage)", {
    expect_equal(out$calibration$num[1], train_median)
  })

  it("fills factor NA in non-train partitions with 'unknown'", {
    expect_equal(as.character(out$test$cat[1]), "unknown")
  })
})

# save_splits() + load_splits() -----------------------------------------------

test_that("save_splits and load_splits round-trip parquet data correctly", {
  splits <- list(
    train       = data.frame(y = c(0L, 1L), x1 = c(1.0, 2.0)),
    calibration = data.frame(y = 0L,         x1 = 3.0),
    test        = data.frame(y = 1L,         x1 = 4.0)
  )

  tmp <- withr::local_tempdir()
  local_mocked_bindings(
    here = function(...) file.path(tmp, ...),
    .package = "here"
  )

  suppressMessages(save_splits(splits, "mydata"))
  recovered <- load_splits("mydata")

  expect_equal(nrow(recovered$train),       nrow(splits$train))
  expect_equal(nrow(recovered$calibration), nrow(splits$calibration))
  expect_equal(nrow(recovered$test),        nrow(splits$test))
  expect_equal(recovered$train$y,  splits$train$y)
  expect_equal(recovered$train$x1, splits$train$x1)
})

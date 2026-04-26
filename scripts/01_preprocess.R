library(here)
library(dplyr)
source(here::here("src/ingest.R"))
source(here::here("src/preprocess.R"))
source(here::here("src/config.R"))

cfg   <- load_config()
split <- function(df) stratified_split(df, cfg$splits$train, cfg$splits$calibration, cfg$splits$seed)

diagnose <- function(df, target) {
  message("Rows: ", nrow(df), " | Cols: ", ncol(df))
  print(class_distribution(df, target))
  df
}

# --- ULB Credit Card Fraud ---------------------------------------------------
# All-numeric: V1-V28 + Amount are double; Time is integer. No missing values.
ulb_types <- c(
  setNames(rep("double",  28), paste0("V", 1:28)),
  Amount = "double",
  Time   = "integer"
)

message("=== ULB Credit Card Fraud ===")
load_csv("data/raw/ulb-credit-card-fraud-detection/creditcard.csv") |>
  cast_types(ulb_types) |>
  diagnose("Class") |>
  standardize_columns("Class") |>
  split() |>
  save_splits("ulb")

# --- IEEE-CIS Fraud Detection ------------------------------------------------
# Named categoricals -> factor; all other columns stay as read.
# 414 of 432 feature columns have missing values due to the identity left join.
ieee_cat_cols <- c(
  "ProductCD",
  paste0("card", 1:6),
  "addr1", "addr2",
  "P_emaildomain", "R_emaildomain",
  paste0("M", 1:9),
  "DeviceType", "DeviceInfo",
  paste0("id_", 12:38)
)
ieee_types <- setNames(rep("factor", length(ieee_cat_cols)), ieee_cat_cols)

message("\n=== IEEE-CIS Fraud Detection ===")
load_ieee("data/raw/ieee-cis-fraud-detection") |>
  cast_types(ieee_types) |>
  diagnose("isFraud") |>
  standardize_columns("isFraud") |>
  split() |>
  save_splits("ieee")

# --- UCI Portuguese Bank Marketing -------------------------------------------
# Types from variables.csv: Integer -> integer, Categorical/Binary/Date -> factor.
# pdays special case: NA means "never previously contacted" (originally -1 in the
# raw data, encoded as NA by ucimlrepo). Derive a binary contacted_before flag
# and set pdays NA -> 0 before the split so impute_splits() sees no NA there.
# Target `y`: "yes" maps to 1.
message("\n=== UCI Portuguese Bank Marketing ===")
load_ucimlrepo("data/raw/uci-portuguese-bank-marketing") |>
  cast_types_from_variables("data/raw/uci-portuguese-bank-marketing/variables.csv") |>
  mutate(
    contacted_before = as.integer(!is.na(pdays)),
    pdays            = if_else(is.na(pdays), 0L, pdays)
  ) |>
  diagnose("y") |>
  standardize_columns("y", positive_class = "yes") |>
  split() |>
  save_splits("bank_marketing")

# --- UCI Taiwan Credit Card Default ------------------------------------------
# Types from variables.csv: all features are Integer. No missing values.
# Target `Y`: 0/1 integer.
message("\n=== UCI Taiwan Credit Card Default ===")
load_ucimlrepo("data/raw/uci-taiwan-credit-card") |>
  cast_types_from_variables("data/raw/uci-taiwan-credit-card/variables.csv") |>
  diagnose("Y") |>
  standardize_columns("Y") |>
  split() |>
  save_splits("taiwan")

# --- UCI South German Credit -------------------------------------------------
# Numeric: laufzeit (duration), hoehe (amount), alter (age).
# Categorical (integer-coded): all other features per codetable.txt.
# No missing values.
sg_types <- c(
  laufkont = "factor", laufzeit = "integer",  moral    = "factor",
  verw     = "factor", hoehe    = "integer",  sparkont = "factor",
  beszeit  = "factor", rate     = "factor",   famges   = "factor",
  buerge   = "factor", wohnzeit = "factor",   verm     = "factor",
  alter    = "integer", weitkred = "factor",  wohn     = "factor",
  bishkred = "factor", beruf    = "factor",   pers     = "factor",
  telef    = "factor", gastarb  = "factor"
)

message("\n=== UCI South German Credit ===")
load_south_german("data/raw/uci-south-german-credit/SouthGermanCredit.asc") |>
  cast_types(sg_types) |>
  diagnose("kredit") |>
  standardize_columns("kredit", positive_class = 0) |>
  split() |>
  save_splits("south_german")

# --- UCI Australian Credit Approval ------------------------------------------
# Types from variables.csv: Categorical -> factor, Continuous -> double.
# No missing values. Target `A15`: 0/1 integer.
message("\n=== UCI Australian Credit Approval ===")
load_ucimlrepo("data/raw/uci-australian-credit-approval") |>
  cast_types_from_variables("data/raw/uci-australian-credit-approval/variables.csv") |>
  diagnose("A15") |>
  standardize_columns("A15") |>
  split() |>
  save_splits("australian")

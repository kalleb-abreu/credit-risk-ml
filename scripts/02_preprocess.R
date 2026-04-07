library(here)
library(dplyr)
source(here::here("src/ingest.R"))
source(here::here("src/preprocess.R"))

# --- ULB Credit Card Fraud ---------------------------------------------------
message("=== ULB Credit Card Fraud ===")
load_csv("data/raw/ulb-credit-card-fraud-detection/creditcard.csv") |>
  standardize_columns("Class") |>
  stratified_split() |>
  save_splits("ulb")

# --- IEEE-CIS Fraud Detection ------------------------------------------------
message("\n=== IEEE-CIS Fraud Detection ===")
load_ieee("data/raw/ieee-cis-fraud-detection") |>
  standardize_columns("isFraud") |>
  stratified_split() |>
  save_splits("ieee")

# --- UCI Portuguese Bank Marketing -------------------------------------------
message("\n=== UCI Portuguese Bank Marketing ===")
load_bank_marketing(
  "data/raw/uci-portuguese-bank-marketing/bank-additional/bank-additional/bank-additional-full.csv"
) |>
  standardize_columns("y", positive_class = "yes") |>
  stratified_split() |>
  save_splits("bank_marketing")

# --- UCI Taiwan Credit Card Default ------------------------------------------
message("\n=== UCI Taiwan Credit Card Default ===")
load_taiwan("data/raw/uci-taiwan-credit-card/default of credit card clients.xls") |>
  dplyr::select(-ID) |>
  standardize_columns("default payment next month") |>
  stratified_split() |>
  save_splits("taiwan")

# --- UCI South German Credit -------------------------------------------------
message("\n=== UCI South German Credit ===")
load_south_german("data/raw/uci-south-german-credit/SouthGermanCredit.asc") |>
  standardize_columns("kredit", positive_class = 0) |>
  stratified_split() |>
  save_splits("south_german")

# --- UCI Australian Credit Approval ------------------------------------------
message("\n=== UCI Australian Credit Approval ===")
load_australian("data/raw/uci-australian-credit-approval/australian.dat") |>
  standardize_columns("Class") |>
  stratified_split() |>
  save_splits("australian")

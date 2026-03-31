library(here)
library(dplyr)
source(here::here("src/ingest.R"))

# --- ULB Credit Card Fraud ---------------------------------------------------
message("=== ULB Credit Card Fraud ===")
ulb <- load_csv("data/raw/ulb-credit-card-fraud-detection/creditcard.csv")
message("Rows: ", nrow(ulb), " | Cols: ", ncol(ulb))
print(class_distribution(ulb, "Class"))

# --- IEEE-CIS Fraud Detection ------------------------------------------------
message("\n=== IEEE-CIS Fraud Detection (train_transaction) ===")
ieee <- load_csv("data/raw/ieee-cis-fraud-detection/train_transaction.csv")
message("Rows: ", nrow(ieee), " | Cols: ", ncol(ieee))
print(class_distribution(ieee, "isFraud"))

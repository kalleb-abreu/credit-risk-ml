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

# --- UCI Australian Credit Approval ------------------------------------------
message("\n=== UCI Australian Credit Approval ===")
australian <- load_australian("data/raw/uci-australian-credit-approval/australian.dat")
message("Rows: ", nrow(australian), " | Cols: ", ncol(australian))
print(class_distribution(australian, "Class"))

# --- UCI South German Credit -------------------------------------------------
message("\n=== UCI South German Credit ===")
south_german <- load_south_german("data/raw/uci-south-german-credit/SouthGermanCredit.asc")
message("Rows: ", nrow(south_german), " | Cols: ", ncol(south_german))
print(class_distribution(south_german, "kredit"))

# --- UCI Portuguese Bank Marketing -------------------------------------------
message("\n=== UCI Portuguese Bank Marketing ===")
bank <- load_bank_marketing("data/raw/uci-portuguese-bank-marketing/bank-additional/bank-additional/bank-additional-full.csv")
message("Rows: ", nrow(bank), " | Cols: ", ncol(bank))
print(class_distribution(bank, "y"))

# --- UCI Taiwan Credit Card Default ------------------------------------------
message("\n=== UCI Taiwan Credit Card Default ===")
taiwan <- load_taiwan("data/raw/uci-taiwan-credit-card/default of credit card clients.xls")
message("Rows: ", nrow(taiwan), " | Cols: ", ncol(taiwan))
print(class_distribution(taiwan, "default payment next month"))

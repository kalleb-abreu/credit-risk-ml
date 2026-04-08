library(here)
library(dplyr)
source(here::here("src/ingest.R"))

# --- ULB Credit Card Fraud ---------------------------------------------------
message("=== ULB Credit Card Fraud ===")
ulb <- load_csv("data/raw/ulb-credit-card-fraud-detection/creditcard.csv")
message("Rows: ", nrow(ulb), " | Cols: ", ncol(ulb))
print(class_distribution(ulb, "Class"))

# --- IEEE-CIS Fraud Detection ------------------------------------------------
message("\n=== IEEE-CIS Fraud Detection ===")
ieee <- load_ieee("data/raw/ieee-cis-fraud-detection")
message("Rows: ", nrow(ieee), " | Cols: ", ncol(ieee))
print(class_distribution(ieee, "isFraud"))

# --- UCI Portuguese Bank Marketing -------------------------------------------
message("\n=== UCI Portuguese Bank Marketing ===")
bank <- load_ucimlrepo("data/raw/uci-portuguese-bank-marketing")
message("Rows: ", nrow(bank), " | Cols: ", ncol(bank))
print(class_distribution(bank, "y"))

# --- UCI Taiwan Credit Card Default ------------------------------------------
message("\n=== UCI Taiwan Credit Card Default ===")
taiwan <- load_ucimlrepo("data/raw/uci-taiwan-credit-card")
message("Rows: ", nrow(taiwan), " | Cols: ", ncol(taiwan))
print(class_distribution(taiwan, "Y"))

# --- UCI South German Credit -------------------------------------------------
message("\n=== UCI South German Credit ===")
south_german <- load_south_german("data/raw/uci-south-german-credit/SouthGermanCredit.asc")
message("Rows: ", nrow(south_german), " | Cols: ", ncol(south_german))
print(class_distribution(south_german, "kredit"))

# --- UCI Australian Credit Approval ------------------------------------------
message("\n=== UCI Australian Credit Approval ===")
australian <- load_ucimlrepo("data/raw/uci-australian-credit-approval")
message("Rows: ", nrow(australian), " | Cols: ", ncol(australian))
print(class_distribution(australian, "A15"))

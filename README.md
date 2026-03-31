# credit-risk-ml

## Data

Large data files are not tracked in git. Download them manually and place under `data/raw/`.

The experiment compares resampling techniques across three imbalance scenarios:

- **Heavily imbalanced** (minority 0–10%)
- **Moderately imbalanced** (minority 10–20%)
- **Near-balanced** (minority 20–50%)

| Dataset | Scenario | Rows | Features | Minority % | Imbalance ratio | Source | Path |
|---|---|---|---|---|---|---|---|
| ULB Credit Card Fraud | Heavily imbalanced | 284,807 | 30 | 0.17% | 1:578 | https://www.kaggle.com/datasets/mlg-ulb/creditcardfraud | `data/raw/ulb-credit-card-fraud-detection/` |
| IEEE-CIS Fraud Detection | Heavily imbalanced | 590,540 | 393 | 3.50% | 1:28 | https://www.kaggle.com/competitions/ieee-fraud-detection/data | `data/raw/ieee-cis-fraud-detection/` — requires accepting competition rules |
| UCI Australian Credit Approval | Near-balanced | 690 | 14 | 44.5% | 1:1.2 | https://archive.ics.uci.edu/dataset/143/statlog+australian+credit+approval | `data/raw/uci-australian-credit-approval/` |
| UCI South German Credit | Near-balanced | 1,000 | 20 | 30.0% | 1:2.3 | https://archive.ics.uci.edu/dataset/573/south+german+credit | `data/raw/uci-south-german-credit/` |
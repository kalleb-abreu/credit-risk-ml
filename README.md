# credit-risk-ml

## Data

Large data files are not tracked in git. Download them manually and place under `data/raw/`.

The experiment compares resampling techniques across three imbalance scenarios:

- **Heavily imbalanced** (minority 0–10%)
- **Moderately imbalanced** (minority 10–25%)
- **Near-balanced** (minority 25–50%)

| Dataset | Scenario | Rows | Features | Target variable | Minority % | Imbalance ratio | Source | Path |
|---|---|---|---|---|---|---|---|---|
| ULB Credit Card Fraud | Heavily imbalanced | 284,807 | 30 | `Class` (0/1) | 0.17% | 1:578 | https://www.kaggle.com/datasets/mlg-ulb/creditcardfraud | `data/raw/ulb-credit-card-fraud-detection/` |
| IEEE-CIS Fraud Detection | Heavily imbalanced | 590,540 | 393 | `isFraud` (0/1) | 3.50% | 1:28 | https://www.kaggle.com/competitions/ieee-fraud-detection/data | `data/raw/ieee-cis-fraud-detection/` — requires accepting competition rules |
| UCI Portuguese Bank Marketing | Moderately imbalanced | 41,188 | 20 | `y` (no/yes) | 11.3% | 1:7.9 | https://archive.ics.uci.edu/dataset/222/bank+marketing | `data/raw/uci-portuguese-bank-marketing/` |
| UCI Taiwan Credit Card Default | Moderately imbalanced | 30,000 | 24 | `default payment next month` (0/1) | 22.1% | 1:3.5 | https://archive.ics.uci.edu/dataset/350/default+of+credit+card+clients | `data/raw/uci-taiwan-credit-card/` |
| UCI South German Credit | Near-balanced | 1,000 | 20 | `kredit` (0=bad/1=good) | 30.0% | 1:2.3 | https://archive.ics.uci.edu/dataset/573/south+german+credit | `data/raw/uci-south-german-credit/` |
| UCI Australian Credit Approval | Near-balanced | 690 | 14 | `Class` (0/1) | 44.5% | 1:1.2 | https://archive.ics.uci.edu/dataset/143/statlog+australian+credit+approval | `data/raw/uci-australian-credit-approval/` |
# credit-risk-ml

**Research question:** How do resampling techniques affect the calibration and discrimination of credit risk models under class imbalance, and can post-hoc calibration methods recover probability reliability?

---

## Datasets

Large data files are not tracked in git. Download them manually and place under `data/raw/`.

The experiment covers three levels of class imbalance:

- **Heavily imbalanced** (minority 0–10%)
- **Moderately imbalanced** (minority 10–25%)
- **Near-balanced** (minority 25–50%)

| Dataset | Scenario | Rows | Features | Target variable | Minority % | Imbalance ratio | Source | Path |
|---|---|---|---|---|---|---|---|---|
| ULB Credit Card Fraud | Heavily imbalanced | 284,807 | 30 | `Class` (0/1) | 0.17% | 1:578 | https://www.kaggle.com/datasets/mlg-ulb/creditcardfraud | `data/raw/ulb-credit-card-fraud-detection/` |
| IEEE-CIS Fraud Detection | Heavily imbalanced | 590,540 | 432 | `isFraud` (0/1) | 3.50% | 1:28 | https://www.kaggle.com/competitions/ieee-fraud-detection/data | `data/raw/ieee-cis-fraud-detection/` |
| UCI Portuguese Bank Marketing | Moderately imbalanced | 45,211 | 16 | `y` (no/yes) | 11.7% | 1:7.5 | https://archive.ics.uci.edu/dataset/222/bank+marketing | `data/raw/uci-portuguese-bank-marketing/` |
| UCI Taiwan Credit Card Default | Moderately imbalanced | 30,000 | 23 | `Y` (0/1) | 22.1% | 1:3.5 | https://archive.ics.uci.edu/dataset/350/default+of+credit+card+clients | `data/raw/uci-taiwan-credit-card/` |
| UCI South German Credit | Near-balanced | 1,000 | 20 | `kredit` (0=bad/1=good) | 30.0% | 1:2.3 | https://archive.ics.uci.edu/dataset/573/south+german+credit | `data/raw/uci-south-german-credit/` |
| UCI Australian Credit Approval | Near-balanced | 690 | 14 | `A15` (0/1) | 44.5% | 1:1.2 | https://archive.ics.uci.edu/dataset/143/statlog+australian+credit+approval | `data/raw/uci-australian-credit-approval/` |

---

## Pipeline

### 1. Ingest — `scripts/01_ingest.R`

Loads each raw dataset and prints the class distribution. No data is written — this script is used to verify the raw files are present and correctly formatted.

Loader functions live in `src/ingest.R`. Each dataset requires its own loader due to format differences:

| Dataset | Format | Notes |
|---|---|---|
| ULB Credit Card Fraud | CSV | Single file |
| IEEE-CIS Fraud Detection | CSV | Two tables joined on `TransactionID` (left join): `train_transaction.csv` + `train_identity.csv`. The `test_*` files have no labels and are ignored. |
| UCI Portuguese Bank Marketing | CSV (`features.csv` + `targets.csv`) | Downloaded via `ucimlrepo` (id=222); target column `y` |
| UCI Taiwan Credit Card Default | CSV (`features.csv` + `targets.csv`) | Downloaded via `ucimlrepo` (id=350); features named `X1–X23`, target `Y` |
| UCI South German Credit | Space-separated with header | Downloaded via direct zip URL; German variable names |
| UCI Australian Credit Approval | CSV (`features.csv` + `targets.csv`) | Downloaded via `ucimlrepo` (id=143); features named `A1–A14`, target `A15` |

---

### 2. Preprocess — `scripts/02_preprocess.R`

Reads raw data, enforces column types, applies a uniform schema, splits into three partitions, and writes Parquet files to `data/interim/`. Raw files are never modified.

Functions live in `src/preprocess.R`.

**Type enforcement:** applied before column standardization so types are preserved in Parquet. Two strategies:

- `cast_types_from_variables(df, path)` — reads `variables.csv` (ucimlrepo) and maps UCI types to R types: `Integer` → `integer`, `Continuous` → `double`, `Categorical` / `Binary` / `Date` → `factor`. Used by Bank Marketing, Taiwan, and Australian.
- `cast_types(df, col_types)` — takes a named character vector and coerces each column. Used by South German (from `codetable.txt`), ULB, and IEEE-CIS.

**Column standardization:** the target is renamed to `y` (1 = minority / event of interest) and all features are renamed to `x1 … xn`. This makes all downstream code dataset-agnostic. For datasets where the minority class is not encoded as 1 in the raw file, a `positive_class` argument handles the inversion (South German: `kredit = 0` → `y = 1`; Bank Marketing: `y = "yes"` → `y = 1`).

**Train / calibration / test split:** each dataset is split once using stratified sampling (stratified on `y`) into three fixed partitions. The same proportions and seed are used across all datasets.

| Partition | Size | Purpose | Resampling applied? |
|---|---|---|---|
| Train | 60% | Fit the model | Yes |
| Calibration | 20% | Fit post-hoc calibrator (Platt / isotonic) | No |
| Test | 20% | Final evaluation — held out until reporting | No |

**Split sizes:**

| Dataset | Train | Calibration | Test | Minority % | Imbalance ratio |
|---|---|---|---|---|---|
| ULB Credit Card Fraud | 170,884 (60%) | 56,961 (20%) | 56,962 (20%) | 0.17% | 1:578 |
| IEEE-CIS Fraud Detection | 354,324 (60%) | 118,108 (20%) | 118,108 (20%) | 3.50% | 1:28 |
| UCI Portuguese Bank Marketing | 27,126 (60%) | 9,042 (20%) | 9,043 (20%) | 11.7% | 1:7.5 |
| UCI Taiwan Credit Card Default | 18,000 (60%) | 6,000 (20%) | 6,000 (20%) | 22.1% | 1:3.5 |
| UCI South German Credit | 600 (60%) | 200 (20%) | 200 (20%) | 30.0% | 1:2.3 |
| UCI Australian Credit Approval | 414 (60%) | 138 (20%) | 138 (20%) | 44.5% | 1:1.2 |

**Output:** `data/interim/{dataset}_{partition}.parquet`

---

### 3. EDA — `scripts/03_eda.R`

Operates on the standardized interim files. The goal is to characterize each dataset structurally — not to interpret individual features — to justify preprocessing decisions and describe the experimental setup in the paper.

Functions live in `src/eda.R`.

**Figures** are written to `figures/`. The structural summary table is written to `output/eda_summary.csv`.

#### Structural summary

| Dataset | Rows | Features | Numeric | Categorical | Missing cols | % rows with missing | Numeric range |
|---|---|---|---|---|---|---|---|
| ULB Credit Card Fraud | 284,807 | 30 | 30 | 0 | 0 | 0% | 6.1 – 172,792 |
| IEEE-CIS Fraud Detection | 590,540 | 432 | 401 | 31 | 414 | 100% | 1.0 – 15,724,731 |
| UCI Portuguese Bank Marketing | 45,211 | 16 | 6 | 10 | 3 | — | — |
| UCI Taiwan Credit Card Default | 30,000 | 23 | 23 | 0 | 0 | 0% | — |
| UCI South German Credit | 1,000 | 20 | 3 | 17 | 0 | 0% | — |
| UCI Australian Credit Approval | 690 | 14 | 6 | 8 | 0 | 0% | — |

> IEEE-CIS: 100% of rows have at least one missing value because identity records exist for only a subset of transactions (left join). 414 of 432 feature columns are affected. Missing values are expected and will be handled by imputation in preprocessing.

**Figures:**

| Figure | Description |
|---|---|
| `imbalance_spectrum.png` | All six datasets plotted on a minority-class axis, grouped by imbalance scenario |

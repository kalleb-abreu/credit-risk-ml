# Experiment Pipeline

**Research question:** How do resampling techniques affect the calibration and discrimination of credit risk models under class imbalance, and can post-hoc calibration methods recover probability reliability?

---

## Directory Structure

```
credit-risk-ml/
├── data/
│   ├── raw/                    # original downloads — not tracked in git
│   │   ├── ulb-credit-card-fraud-detection/
│   │   ├── ieee-cis-fraud-detection/
│   │   ├── uci-portuguese-bank-marketing/
│   │   ├── uci-taiwan-credit-card/
│   │   ├── uci-south-german-credit/
│   │   └── uci-australian-credit-approval/
│   ├── interim/                # post-preprocess, pre-imputation parquet files
│   │   └── {dataset}_{partition}.parquet
│   └── processed/              # post-imputation, model-ready parquet files
│       └── {dataset}_{partition}.parquet
│
├── models/                     # fitted model objects
│   ├── {dataset}_{classifier}_{resampling}.rds         # 162 files
│   └── calibrators/
│       └── {dataset}_{classifier}_{resampling}_{cal}.rds  # 324 files (Platt + isotonic)
│
├── predictions/                # predicted probabilities saved after each fit
│   ├── calibration/
│   │   └── {dataset}_{classifier}_{resampling}.parquet
│   └── test/
│       └── {dataset}_{classifier}_{resampling}.parquet
│
├── output/
│   └── test_metrics.parquet    # main results table — one row per configuration
│
├── figures/
│   ├── eda/                    # structural EDA figures
│   └── results/                # paper figures (reliability diagrams, comparison plots)
│
├── src/                        # helper functions sourced by scripts
│   ├── ingest.R
│   ├── preprocess.R
│   ├── eda.R
│   ├── train.R
│   ├── calibrate.R
│   ├── evaluate.R
│   └── report.R
│
├── scripts/                    # numbered pipeline — run in order
│   ├── 00_download.py
│   ├── 01_ingest.R
│   ├── 02_preprocess.R
│   ├── 03_eda.R
│   ├── 04_impute.R
│   ├── 05_train.R
│   ├── 06_calibrate.R
│   ├── 07_evaluate.R
│   └── 08_report.R
│
└── reports/
    ├── pipeline.md             # this document
    ├── evaluation.md
    ├── resampling.md
    └── classification.md
```

---

## Datasets

Six datasets spanning three imbalance levels. All downloaded to `data/raw/` and never modified.

| Dataset | Imbalance level | Rows | Features | Minority % | Train | Calibration | Test |
|---|---|---|---|---|---|---|---|
| ULB Credit Card Fraud | Heavily imbalanced | 284,807 | 30 | 0.17% | 170,884 | 56,961 | 56,962 |
| IEEE-CIS Fraud Detection | Heavily imbalanced | 590,540 | 432 | 3.50% | 354,324 | 118,108 | 118,108 |
| UCI Portuguese Bank Marketing | Moderately imbalanced | 45,211 | 17 | 11.7% | 27,126 | 9,042 | 9,043 |
| UCI Taiwan Credit Card Default | Moderately imbalanced | 30,000 | 23 | 22.1% | 18,000 | 6,000 | 6,000 |
| UCI South German Credit | Near-balanced | 1,000 | 20 | 30.0% | 600 | 200 | 200 |
| UCI Australian Credit Approval | Near-balanced | 690 | 14 | 44.5% | 414 | 138 | 138 |

Target encoding after `standardize_columns()`: `y = 1` is always the minority / event of interest.

---

## Data Flow

```
raw files
    │
    ▼ 01_ingest.R          verify files, print class distributions
    │
    ▼ 02_preprocess.R      type enforcement → column standardization → stratified split
    │                      → data/interim/{dataset}_{train|calibration|test}.parquet
    │
    ▼ 03_eda.R             structural summaries + figures → figures/eda/, output/eda_summary.csv
    │
    ▼ 04_impute.R          median imputation (numeric) + "unknown" level (categorical)
    │                      fitted on train partition only, applied to all three
    │                      → data/processed/{dataset}_{train|calibration|test}.parquet
    │
    ▼ 05_train.R           recipe + model fit for each of 162 conditions
    │                      → models/{dataset}_{classifier}_{resampling}.rds
    │                      → predictions/calibration/{dataset}_{classifier}_{resampling}.parquet
    │                      → predictions/test/{dataset}_{classifier}_{resampling}.parquet
    │
    ▼ 06_calibrate.R       fit Platt + isotonic on calibration predictions
    │                      → models/calibrators/{dataset}_{classifier}_{resampling}_{cal}.rds
    │
    ▼ 07_evaluate.R        apply calibrators to test predictions, compute all metrics
    │                      → output/test_metrics.parquet
    │
    ▼ 08_report.R          paper tables + figures → figures/results/
```

---

## Pipeline Steps

### `00_download.py`

Downloads all datasets that can be fetched programmatically. Datasets from Kaggle must be downloaded manually. See README for paths.

---

### `01_ingest.R` — verify

Loads each raw dataset using dataset-specific loaders in `src/ingest.R` and prints class distribution. No files written. Run this to confirm raw files are present and correctly formatted before the pipeline starts.

---

### `02_preprocess.R` — type enforcement, schema, split

1. Enforce column types (`cast_types` / `cast_types_from_variables`)
2. Apply Bank Marketing `pdays → contacted_before` derivation
3. `standardize_columns()`: rename target to `y`, features to `x1…xn`
4. `stratified_split()`: 60/20/20 stratified on `y`, seed = 42

**Output:** `data/interim/{dataset}_{partition}.parquet` (pre-imputation)

---

### `03_eda.R` — structural analysis

Operates on interim files. Goal: justify preprocessing decisions, not interpret features.

**Output:**
- `output/eda_summary.csv` — rows/features/missing/ranges per dataset
- `figures/eda/imbalance_spectrum.png`
- `figures/eda/class_distribution.png`
- `figures/eda/ieee_missing_cols.png`

---

### `04_impute.R` — missing value imputation

Imputation parameters estimated on training partition only, applied to all three partitions.

| Column type | Strategy |
|---|---|
| Numeric | Median of training partition |
| Categorical | New factor level `"unknown"` |

**Output:** `data/processed/{dataset}_{partition}.parquet` (model-ready)

---

### `05_train.R` — model fitting (162 fits)

For each combination of dataset × classifier × resampling condition:

1. Load `data/processed/{dataset}_train.parquet`
2. Build recipe (see Feature Engineering below)
3. Fit model on full training partition (no cross-validation)
4. Predict probabilities on calibration partition and test partition
5. Save model object and predictions

**Output:**
- `models/{dataset}_{classifier}_{resampling}.rds`
- `predictions/calibration/{dataset}_{classifier}_{resampling}.parquet` — columns: `y`, `.pred_1`
- `predictions/test/{dataset}_{classifier}_{resampling}.parquet` — columns: `y`, `.pred_1`

#### Feature Engineering (recipe — identical across all 9 conditions)

```r
recipe(y ~ ., data = train) |>
  step_nzv(all_predictors()) |>              # remove near-zero variance
  step_dummy(all_nominal_predictors()) |>    # one-hot encode factors
  step_normalize(all_numeric_predictors()) | # center + scale
  <resampling_step>                          # only line that changes per condition
```

`step_nzv`, `step_dummy`, and `step_normalize` are fitted on the training data only (recipe prep).

#### Experiment Matrix

**3 classifiers × 9 resampling conditions × 6 datasets = 162 model fits**

**Classifiers:**

| Classifier | Package | Fixed hyperparameters |
|---|---|---|
| Logistic Regression (Elastic Net) | `glmnet` | `alpha = 0.5`, `lambda` via internal CV (`cv.glmnet`) |
| Random Forest | `ranger` | `num.trees = 500`, `mtry = floor(sqrt(p))`, `min.node.size = 5` |
| LightGBM | `lightgbm` | `num_leaves = 31`, `learning_rate = 0.05`, `n_iter = 300` |

**Resampling conditions:**

| # | Family | Method | `themis` step | Fixed parameters |
|---|---|---|---|---|
| 1 | Baseline | No resampling | — | — |
| 2 | Oversampling | Random oversampling | `step_upsample()` | `over_ratio = 0.5` |
| 3 | Oversampling | SMOTE | `step_smote()` | `over_ratio = 0.5`, `neighbors = 5` |
| 4 | Oversampling | ADASYN | `step_adasyn()` | `over_ratio = 0.5`, `neighbors = 5` |
| 5 | Undersampling | Random undersampling | `step_downsample()` | `under_ratio = 1` |
| 6 | Undersampling | Tomek Links | `step_tomek()` | — |
| 7 | Undersampling | NearMiss | `step_nearmiss()` | `under_ratio = 1`, `neighbors = 3` |
| 8 | Hybrid | SMOTE + Tomek Links | `step_smote()` → `step_tomek()` | `over_ratio = 0.5`, `neighbors = 5` |
| 9 | Hybrid | SMOTE + ENN | `step_smote()` → ENN step | `over_ratio = 0.5`, `neighbors = 5` |

All resampling parameters are fixed. No per-condition tuning — isolates the resampling method as the sole variable.

---

### `06_calibrate.R` — post-hoc calibration (324 calibrators)

For each of the 162 prediction files in `predictions/calibration/`:

1. Load calibration predictions (`.pred_1`, `y`)
2. Fit Platt scaling (`cal_estimate_logistic`)
3. Fit isotonic regression (`cal_estimate_isotonic`)
4. Save both calibrators

**Output:** `models/calibrators/{dataset}_{classifier}_{resampling}_{platt|isotonic}.rds`

This gives **3 variants per base fit**: uncalibrated, Platt, isotonic → **486 evaluated models total**.

---

### `07_evaluate.R` — metrics on test set

For each of the 162 test prediction files × 3 calibration variants:

1. Load test predictions
2. Apply calibrator (skip for uncalibrated variant)
3. Compute full metric set

**Output:** `output/test_metrics.parquet`

#### Schema

| Column | Type | Description |
|---|---|---|
| `dataset` | chr | Dataset identifier |
| `classifier` | chr | `logreg`, `rf`, `lgbm` |
| `resampling` | chr | `none`, `upsample`, `smote`, `adasyn`, `downsample`, `tomek`, `nearmiss`, `smote_tomek`, `smote_enn` |
| `calibration` | chr | `none`, `platt`, `isotonic` |
| `pr_auc` | dbl | Primary discrimination metric |
| `roc_auc` | dbl | Secondary discrimination metric |
| `mcc` | dbl | Threshold-free summary |
| `brier_score` | dbl | Primary calibration metric |
| `ece` | dbl | Expected calibration error |
| `sensitivity` | dbl | Recall at default 0.5 threshold |
| `specificity` | dbl | TNR at default 0.5 threshold |
| `log_loss` | dbl | Proper scoring rule |

One row per unique (dataset, classifier, resampling, calibration) combination = **486 rows**.

---

### `08_report.R` — paper tables and figures

Reads `output/test_metrics.parquet` and produces all paper-ready outputs.

**Tables:**
- Main results: PR-AUC and Brier Score by resampling condition (averaged across classifiers and datasets)
- Per-classifier breakdown
- Calibration delta table: Brier Score and ECE before vs. after calibration

**Figures:**
- `figures/results/pr_auc_heatmap.png` — PR-AUC per resampling × dataset
- `figures/results/brier_score_heatmap.png` — Brier Score per calibration method × resampling
- `figures/results/reliability_diagrams/` — one diagram per classifier × dataset (uncalibrated vs. Platt vs. isotonic, for baseline and best resampling condition)
- `figures/results/calibration_delta.png` — ECE reduction from pre to post calibration across conditions

---

## Fixed Parameters Summary

| Parameter | Value | Scope |
|---|---|---|
| Train/calibration/test split | 60/20/20 | All datasets |
| Stratification | On `y` | All splits |
| Random seed | 42 | All splits |
| `over_ratio` | 0.5 | All oversampling methods |
| `under_ratio` | 1 | All undersampling methods |
| `neighbors` (k) | 5 | SMOTE, ADASYN, SMOTE+Tomek, SMOTE+ENN |
| `neighbors` (NearMiss) | 3 | NearMiss only |
| LR `alpha` | 0.5 (Elastic Net) | All datasets |
| RF `num.trees` | 500 | All datasets |
| LightGBM `n_iter` | 300 | All datasets |
| Calibration methods | Platt + isotonic | All 162 base fits |

No parameter is tuned per resampling condition. The resampling method is the sole variable in the comparison.

---

## Scale Summary

| Stage | Count |
|---|---|
| Datasets | 6 |
| Classifiers | 3 |
| Resampling conditions | 9 |
| Base model fits (`05_train.R`) | 162 |
| Calibrators fitted (`06_calibrate.R`) | 324 |
| Evaluated configurations (`07_evaluate.R`) | 486 |
| Rows in `test_metrics.parquet` | 486 |

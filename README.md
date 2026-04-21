# credit-risk-ml

**Research question:** How do resampling techniques affect the calibration and discrimination of credit risk models under class imbalance, and can post-hoc calibration methods recover probability reliability?

---

## Directory Structure

```
credit-risk-ml/
├── data/
│   ├── raw/           # original downloads — not tracked in git
│   ├── interim/       # post-preprocess, pre-imputation → {dataset}_{partition}.parquet
│   └── processed/     # post-imputation, model-ready  → {dataset}_{partition}.parquet
├── models/            # fitted model objects (.rds) + calibrators/
├── predictions/       # predicted probabilities → calibration/ and test/
├── output/            # test_metrics.parquet (main results table)
├── figures/           # eda/ and results/
├── src/               # helper functions sourced by scripts
├── scripts/           # 00_download.py … 08_report.R — run in order
└── reports/           # pipeline.md, evaluation.md, resampling.md, classification.md
```

See `reports/pipeline.md` for the full directory tree, data flow diagram, and output file schemas.

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

**Bank Marketing — `pdays` transformation:** `pdays` (days since last contact) is NA when a client was never previously contacted. Before column renaming, a binary feature `contacted_before` (1/0) is derived from `pdays`, and `pdays` NA values are set to 0. This must happen before `standardize_columns()` renames all columns to `x1 … xn`.

**Column standardization:** the target is renamed to `y` (1 = minority / event of interest) and all features are renamed to `x1 … xn`. This makes all downstream code dataset-agnostic. For datasets where the minority class is not encoded as 1 in the raw file, a `positive_class` argument handles the inversion (South German: `kredit = 0` → `y = 1`; Bank Marketing: `y = "yes"` → `y = 1`).

| Dataset | y = 1 | y = 0 |
|---|---|---|
| ULB Credit Card Fraud | fraud | legitimate |
| IEEE-CIS Fraud Detection | fraud | legitimate |
| UCI Portuguese Bank Marketing | subscribed | not subscribed |
| UCI Taiwan Credit Card Default | defaulted | no default |
| UCI South German Credit | bad credit | good credit |
| UCI Australian Credit Approval | rejected | approved |

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

**Output:** `data/interim/{dataset}_{partition}.parquet` (pre-imputation)

---

### 3. EDA — `scripts/03_eda.R`

Operates on the standardized pre-imputation interim files. The goal is to characterize each dataset structurally — not to interpret individual features — to justify preprocessing decisions and describe the experimental setup in the paper.

Functions live in `src/eda.R`.

**Figures** are written to `figures/`. The structural summary table is written to `output/eda_summary.csv`.

| Figure | Description |
|---|---|
| `imbalance_spectrum.png` | All six datasets plotted on a minority-class axis, grouped by imbalance scenario |
| `class_distribution.png` | Bar chart of minority class percentage per dataset |
| `ieee_missing_cols.png` | Top 20 IEEE-CIS columns ranked by missingness rate |

#### Structural summary

| Dataset | Rows | Features | Numeric | Categorical | Missing cols | % rows with missing | Numeric range |
|---|---|---|---|---|---|---|---|
| ULB Credit Card Fraud | 284,807 | 30 | 30 | 0 | 0 | 0% | 6.1 – 172,792 |
| IEEE-CIS Fraud Detection | 590,540 | 432 | 383 | 49 | 414 | 100% | 1.0 – 15,724,731 |
| UCI Portuguese Bank Marketing | 45,211 | 17 | 7 | 10 | 4 | 82.7% | 0.0 – 110,146 |
| UCI Taiwan Credit Card Default | 30,000 | 23 | 23 | 0 | 0 | 0% | 1.0 – 1,821,353 |
| UCI South German Credit | 1,000 | 20 | 3 | 17 | 0 | 0% | 56.0 – 18,174 |
| UCI Australian Credit Approval | 690 | 14 | 6 | 8 | 0 | 0% | 28.0 – 100,000 |

> IEEE-CIS: 100% of rows have at least one missing value because identity records exist for only a subset of transactions (left join). 414 of 432 feature columns are affected.
> Bank Marketing: 82.7% of rows have at least one missing value across 4 columns (`education`, `contact`, `pdays`, `poutcome`). The ucimlrepo version encodes unknown/not-contacted values as NA rather than sentinel strings. Feature count is 17 because `contacted_before` was derived from `pdays` before column renaming.

---

### 4. Impute — `scripts/04_impute.R`

Loads the pre-imputation splits from `data/interim/`, applies missing value imputation, and writes model-ready files to `data/processed/`. Imputation parameters are estimated on the training partition only to prevent data leakage, then applied to calibration and test.

**Strategy:**

- **Numeric NA** → median of the training partition
- **Categorical NA** → new factor level `"unknown"` (preserves the informative nature of missingness rather than collapsing it into an existing category)

This strategy is intentionally simple — the focus of the paper is on resampling and calibration, not imputation methodology. It is fully reproducible and can be described in one sentence in the methods section.

**Output:** `data/processed/{dataset}_{partition}.parquet` (model-ready)

---

### 5. Feature Engineering — recipe inside every workflow

All feature engineering is defined as a `tidymodels` recipe and executed inside each workflow. Because it is part of the recipe, every step is fitted on the analysis fold only and applied to the assessment fold — no leakage.

The recipe is **identical across all 9 resampling conditions**; only the final resampling step changes. This isolation is deliberate: the research question is about resampling, not preprocessing.

**Step order:**

```r
recipe(y ~ ., data = train) |>
  step_nzv(all_predictors()) |>                  # remove near-zero variance columns
  step_dummy(all_nominal_predictors()) |>         # one-hot encode factor columns
  step_normalize(all_numeric_predictors()) |>     # center + scale
  step_smote(y, over_ratio = 0.5)                 # ← swap per resampling condition
```

| Step | Rationale |
|---|---|
| `step_nzv` | IEEE-CIS has 414 columns with heavy missingness post-imputation; near-constant columns add noise to SMOTE distance calculations and inflate model complexity. No-op for the other datasets. |
| `step_dummy` | `glmnet` requires numeric input and cannot accept factor columns. Four of six datasets contain categorical features: IEEE-CIS (49), Bank Marketing (10), South German (17), Australian (8). ULB and Taiwan are all-numeric — `step_dummy` is a no-op there. One-hot encoding is used (drop = `"unused"` default) with no target encoding to avoid leakage. |
| `step_normalize` | Mandatory for `glmnet`: the elastic net penalty is scale-sensitive — features with large ranges dominate the regularization path without normalization. Neutral for `ranger` and `lightgbm` (tree splits are scale-invariant), but applied uniformly so that all three classifiers operate on the same preprocessed feature space. |
| Resampling step | Applied after encoding and normalization so that SMOTE distance calculations operate on the final numeric feature space. `themis` steps default to `skip = TRUE`, so resampling never applies to the assessment fold, calibration set, or test set. |

**What is deliberately excluded:**

- No PCA or dimensionality reduction — would obscure the resampling comparison
- No feature selection beyond NZV — keeps the feature space constant across conditions
- No target encoding — leakage risk; one-hot is sufficient
- No outlier removal — alters the class boundary that resampling methods are trying to learn

---

### 6. Calibrate — `scripts/06_calibrate.R`

For each of the 162 fitted models, loads the predicted probabilities on the calibration partition and fits two post-hoc calibrators using the `probably` package:

- **Platt scaling** (`cal_estimate_logistic`) — parametric sigmoid fit
- **Isotonic regression** (`cal_estimate_isotonic`) — non-parametric monotone fit

Both calibrators are fitted for every base model, giving three variants per fit: uncalibrated, Platt, isotonic.

**Output:** `models/calibrators/{dataset}_{classifier}_{resampling}_{platt|isotonic}.rds`

---

### 7. Evaluate — `scripts/07_evaluate.R`

Loads the 162 test prediction files, applies each calibrator (skip for uncalibrated variant), and computes the full metric set. One row per unique (dataset, classifier, resampling, calibration) combination.

**Output:** `output/test_metrics.parquet` — **486 rows**, schema:

| Column | Description |
|---|---|
| `dataset`, `classifier`, `resampling`, `calibration` | Configuration keys |
| `pr_auc` | Primary discrimination metric |
| `roc_auc`, `mcc` | Secondary discrimination metrics |
| `brier_score`, `ece`, `log_loss` | Calibration metrics |
| `sensitivity`, `specificity` | Operating-point diagnostics |

---

### 8. Report — `scripts/08_report.R`

Reads `output/test_metrics.parquet` and produces all paper-ready outputs.

**Tables:** main PR-AUC / Brier Score results by resampling condition; per-classifier breakdown; calibration delta (ECE before vs. after).

**Figures:**

| Figure | Description |
|---|---|
| `figures/results/pr_auc_heatmap.png` | PR-AUC per resampling condition × dataset |
| `figures/results/brier_score_heatmap.png` | Brier Score per calibration method × resampling |
| `figures/results/reliability_diagrams/` | Uncalibrated vs. Platt vs. isotonic per classifier × dataset |
| `figures/results/calibration_delta.png` | ECE reduction across resampling conditions |

---

## Classifier Selection

The experiment uses **3 classifiers**, chosen to represent distinct model families and calibration behaviors:

| Classifier | R package | Calibration tendency | Role |
|---|---|---|---|
| Logistic Regression | `glmnet` (Elastic Net) | Well-calibrated by design | Linear baseline; anchors calibration comparison |
| Random Forest | `ranger` | Overconfident (probabilities cluster toward 0.5) | Ensemble baseline; exposes calibration degradation |
| LightGBM | `lightgbm` | Moderate miscalibration | State-of-the-art for tabular data; practical credit/fraud benchmark |

**Why these three:** The research question requires models that produce probabilities (all three do) and that differ in their out-of-the-box calibration — so that post-hoc calibration methods have something to recover. A purely well-calibrated set would produce a flat result. LR is chosen over plain `glm` to handle regularization on high-dimensional datasets (IEEE-CIS, 432 features). LightGBM is preferred over XGBoost for this experiment because two datasets exceed 250k rows (ULB, IEEE-CIS) and LightGBM trains substantially faster at that scale without sacrificing accuracy.

**Fixed hyperparameters:**

| Classifier | Parameter | Value |
|---|---|---|
| Logistic Regression | `alpha` | 0.5 (Elastic Net) |
| Logistic Regression | `lambda` | selected via internal `cv.glmnet` (not per resampling condition) |
| Random Forest | `num.trees` | 500 |
| Random Forest | `mtry` | `floor(sqrt(p))` |
| Random Forest | `min.node.size` | 5 |
| LightGBM | `num_leaves` | 31 |
| LightGBM | `learning_rate` | 0.05 |
| LightGBM | `n_iter` | 300 (no early stopping) |

**Scale:** 3 classifiers × 9 resampling conditions × 6 datasets = **162 base model fits**. With Platt and isotonic calibration applied to each: **486 evaluated configurations**.

**Hyperparameter strategy:** Classifier hyperparameters are **not tuned per resampling condition**. All models use fixed defaults across all 9 conditions. This is a deliberate isolation strategy: the research question is about the effect of resampling, not about optimal model configuration. Tuning per condition would confound the comparison — any observed difference in PR-AUC or calibration could be attributed to the tuning rather than the resampling method itself. The same logic applies to the `over_ratio` parameter, which is treated as a fixed starting point (0.5) rather than a tuned variable in the main experiment.

This choice is consistent with benchmark methodology in the imbalanced learning literature (Branco et al., 2016; He & Garcia, 2009), where fixed hyperparameters are used precisely to isolate the resampling variable. It is acknowledged as a limitation in the paper: rankings could shift under per-condition tuning, and the results reflect resampling performance under a common model configuration rather than best achievable performance per method.

> **If reviewers require tuning:** the fallback is a single shared grid search per classifier × dataset, optimized on the no-resampling baseline training set, with those hyperparameters frozen across all 9 conditions. This is defensible (hyperparameters are not cherry-picked per resampling method), adds one tuning run per classifier × dataset (18 runs total), and supports the methods sentence: *"Classifier hyperparameters were selected via 5-fold cross-validation on the unmodified training set and held fixed across all resampling conditions."*

---

## Resampling Experiment Design

Resampling is applied only to the **training partition**. Calibration and test sets are never resampled. All methods are implemented via the `themis` package as recipe steps inside a `tidymodels` workflow. `themis` steps default to `skip = TRUE` on new data, so resampling never touches the calibration or test partitions.

The experiment covers **9 conditions** (1 baseline + 8 resampling methods) across three families:

### Baseline

| Condition | Description |
|---|---|
| No resampling | Model trained on the raw imbalanced training set; serves as the reference for all comparisons |

### Oversampling (3)

| Method | `themis` step | Fixed parameters | Mechanism |
|---|---|---|---|
| Random oversampling | `step_upsample()` | `over_ratio = 0.5` | Duplicates minority samples at random; no synthesis |
| SMOTE | `step_smote()` | `over_ratio = 0.5`, `neighbors = 5` | Generates synthetic samples by interpolating between a minority sample and its k-nearest neighbors |
| ADASYN | `step_adasyn()` | `over_ratio = 0.5`, `neighbors = 5` | Adaptive variant of SMOTE; generates more samples in regions where the minority class is harder to learn |

### Undersampling (3)

| Method | `themis` step | Fixed parameters | Mechanism |
|---|---|---|---|
| Random undersampling | `step_downsample()` | `under_ratio = 1` | Removes majority samples at random |
| Tomek Links | `step_tomek()` | — | Removes majority samples that are nearest neighbors of minority samples; mild boundary cleaning only |
| NearMiss | `step_nearmiss()` | `under_ratio = 1`, `neighbors = 3` | Selects majority samples closest to minority samples; more aggressive than Tomek Links |

### Hybrid (2)

| Method | `themis` steps | Fixed parameters | Mechanism |
|---|---|---|---|
| SMOTE + Tomek Links | `step_smote()` → `step_tomek()` | `over_ratio = 0.5`, `neighbors = 5` | Oversample minority class then clean noisy majority samples near the boundary |
| SMOTE + ENN | `step_smote()` → ENN step | `over_ratio = 0.5`, `neighbors = 5` | Oversample then remove samples misclassified by their k-nearest neighbors; stronger cleaning than Tomek Links |

### Design rationale

- **ROSE excluded**: generates samples via kernel density estimation rather than interpolation — a fourth mechanism that would make the oversampling section unwieldy without adding a new narrative thread. Also less suited to the mostly-numeric datasets in this experiment.
- **Tomek Links as standalone undersampling**: its mild effect at extreme imbalance ratios (e.g. ULB 1:578) is itself a finding — light boundary cleaning alone is insufficient under severe imbalance.
- **Fixed resampling parameters**: all parameters (`over_ratio`, `under_ratio`, `neighbors`) are fixed and identical across all datasets. No per-condition tuning — the resampling method is the sole variable in the comparison. See `reports/pipeline.md` for the complete parameter table.
- **Metric**: accuracy is not used. The same metric set is applied across all six datasets to enable cross-dataset comparison — see `reports/evaluation.md` for the full rationale. Discrimination: PR-AUC (primary), ROC-AUC + MCC (secondary). Calibration: Brier Score, ECE, reliability diagrams.

---

## Scale Summary

| Stage | Count |
|---|---|
| Datasets | 6 |
| Classifiers | 3 |
| Resampling conditions | 9 |
| Base model fits (`05_train.R`) | 162 |
| Calibrators fitted (`06_calibrate.R`) | 324 (Platt + isotonic per base fit) |
| Evaluated configurations (`07_evaluate.R`) | 486 |
| Rows in `output/test_metrics.parquet` | 486 |

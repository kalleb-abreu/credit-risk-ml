# Research Paper Plan — Resampling, Risk Modeling & Calibration

**Domain:**  

**Research Question:** How do resampling techniques affect the calibration and discrimination of credit risk models under class imbalance, and can post-hoc calibration methods recover probability reliability?

**Target:** [KDMiLe](https://bracis.sbc.org.br/2026/kdmile/) (8 pages) or [ENIAC](https://bracis.sbc.org.br/2026/eniac/) (12 pages)

**Submission**: June 8th, 2026

**Language:** R 

---

## Week 1: Foundation & Data

### Literature & Scoping
- [x] Define the specific research question.
- [x] Review Brazilian journals/conferences for submission target.
- [x] Read submission guidelines and formatting requirements of top 2–3 target venues.
- [ ] Search for 15–20 key papers.
- [ ] Write a 1-page research outline: problem → gap → contribution → proposed method

### Data Acquisition
- [x] Identify and document six datasets across three imbalance levels (heavily / moderately / near-balanced).
- [x] Download and verify class distributions for all six datasets.
- [x] Document all datasets: source, size, features, target variable, imbalance ratio.

### R Project Structure
- [x] Document chosen structure: `data/raw/`, `data/interim/`, `data/processed/`, `models/`, `predictions/`, `output/`, `figures/`, `src/`, `scripts/`, `reports/`.

### Preprocessing — `scripts/02_preprocess.R`, `src/preprocess.R`
- [x] Enforce column types (`cast_types_from_variables` for UCI datasets, `cast_types` for ULB / IEEE-CIS / South German).
- [x] Apply Bank Marketing `pdays → contacted_before` derivation before column renaming.
- [x] `standardize_columns()`: rename target to `y` (minority = 1), features to `x1…xn`.
- [x] `stratified_split()`: 60/20/20 stratified on `y`, seed = 42 — outputs to `data/interim/`.

### Download — `scripts/00_download.py`
- [x] Programmatic download for UCI datasets and South German Credit. Kaggle datasets print manual instructions.

### EDA — `scripts/03_eda.R`, `src/eda.R`
- [x] Structural summary table: rows, features, numeric/categorical split, missing values, numeric range.
- [x] Imbalance spectrum plot and class distribution bar chart.
- [x] IEEE-CIS missing column detail plot.
- [x] Verify y=1/y=0 encoding is consistent across all six datasets.

### Imputation — `scripts/04_impute.R`, `src/preprocess.R::impute_splits()`
- [x] `impute_splits()`: median imputation for numeric NA, `"unknown"` level for categorical NA.
- [x] Parameters estimated on training partition only; applied to all three partitions.
- [x] Output to `data/processed/{dataset}_{partition}.parquet`.

---

## Week 2: Experiment Design & Training

### Experiment Grid (decided — see `reports/pipeline.md`)
- [x] Resampling: 9 conditions — baseline + 3 oversampling (upsample, SMOTE, ADASYN) + 3 undersampling (downsample, Tomek, NearMiss) + 2 hybrid (SMOTE+Tomek, SMOTE+ENN). All parameters fixed: `over_ratio = 0.5`, `under_ratio = 1`, `neighbors = 5`.
- [x] Classifiers: Logistic Regression (`glmnet`, Elastic Net), Random Forest (`ranger`), LightGBM (`lightgbm`). Hyperparameters fixed across all conditions.
- [x] Calibration: Platt scaling + isotonic regression (`probably` package) applied to all 162 base fits.
- [x] Scale: 6 datasets × 9 conditions × 3 classifiers = 162 base fits → 486 evaluated configurations.

### Training — `scripts/05_train.R`, `src/train.R`
- [x] Create `src/train.R` with model spec helpers for glmnet, ranger, lightgbm.
- [x] Build recipe: `step_nzv()` → `step_dummy()` → `step_normalize()` → resampling step (identical preprocessing across all 9 conditions; only resampling step swapped).
- [x] Loop over all 162 dataset × classifier × resampling combinations.
- [x] Save fitted model objects to `models/{dataset}_{classifier}_{resampling}.rds`.
- [x] Save predicted probabilities on calibration partition to `predictions/calibration/{dataset}_{classifier}_{resampling}.parquet` (columns: `y`, `.pred_1`).
- [x] Save predicted probabilities on test partition to `predictions/test/{dataset}_{classifier}_{resampling}.parquet` (columns: `y`, `.pred_1`).

### Calibration — `scripts/06_calibrate.R`, `src/calibrate.R`
- [ ] Create `src/calibrate.R` with helpers wrapping `probably::cal_estimate_logistic` and `probably::cal_estimate_isotonic`.
- [ ] For each of 162 calibration prediction files: fit Platt calibrator, fit isotonic calibrator.
- [ ] Save calibrators to `models/calibrators/{dataset}_{classifier}_{resampling}_{platt|isotonic}.rds`.

---

## Week 3: Evaluation

### Evaluate — `scripts/07_evaluate.R`, `src/evaluate.R`
- [ ] Create `src/evaluate.R` with a function that takes a prediction tibble and returns all metrics.
- [ ] For each of 486 configurations (162 base × 3 calibration variants): load test predictions, apply calibrator, compute metrics.
- [ ] Metrics: `pr_auc`, `roc_auc`, `mcc`, `brier_score`, `ece`, `log_loss`, `sensitivity`, `specificity`.
- [ ] Save to `output/test_metrics.parquet` — one row per (dataset, classifier, resampling, calibration).

---

## Week 4: Writing & Reporting

### Report — `scripts/08_report.R`, `src/report.R`
- [ ] Create `src/report.R` with reusable plotting helpers.
- [ ] Main results table: PR-AUC and Brier Score by resampling condition, per-classifier breakdown.
- [ ] Calibration delta table: ECE and Brier Score before vs. after calibration.
- [ ] `figures/results/pr_auc_heatmap.png` — PR-AUC per resampling condition × dataset.
- [ ] `figures/results/brier_score_heatmap.png` — Brier Score per calibration method × resampling.
- [ ] `figures/results/reliability_diagrams/` — uncalibrated vs. Platt vs. isotonic per classifier × dataset.
- [ ] `figures/results/calibration_delta.png` — ECE reduction across resampling conditions.

### Paper
- [ ] Write methods section: datasets, preprocessing pipeline, experiment grid, fixed parameters, evaluation protocol.
- [ ] Write results and discussion.
- [ ] Format for target venue (KDMiLe 8-page or ENIAC 12-page).
- [ ] Proofread and submit by June 8th, 2026.

---

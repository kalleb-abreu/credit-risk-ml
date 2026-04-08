# Research Paper Plan — Resampling, Risk Modeling & Calibration

**Domain:**  

**Resarch Question:** How do resampling techniques affect the calibration and discrimination of credit risk models under class imbalance, and can post-hoc calibration methods recover probability reliability?

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

### Data Acquisition - Three Imbalance Scenarios
The core of your experimental design: compare resampling techniques across **three levels of class imbalance** to show how performance and calibration degrade (or hold) as imbalance increases.

**Heavily imbalanced dataset (minority class: 0–10%)**
- [x] Identify a severely imbalanced dataset.
- [x] Download and verify class distribution.
- [x] Perform EDA: summary stats, missing values, feature types.

**Moderately imbalanced dataset (minority class: 10–25%)**
- [x] Identify a moderately imbalanced dataset.
- [x] Download and verify class distribution.
- [x] Perform EDA: summary stats, missing values, feature types.

**Near-balanced dataset (minority class: 25–50%)**
- [x] Identify a near-balanced dataset.
- [x] Download and verify class distribution.
- [x] Perform EDA: summary stats, missing values, feature types.

**R Project Structure** 
- [x] Search GitHub repos for ML project structures in R, look for patterns in `data/`, `R/`, `models/`, `output/`.
- [x] Read Posit/tidyverse guidelines on project-oriented workflows.
- [x] Search blogs for R project structure conventions. Keywords: *"R project structure machine learning"*, *"targets pipeline R"*.
- [x] Check academic papers for how R ML studies organize scripts, data, and results.
- [x] Document the chosen structure: raw vs. processed data, model saving, script naming conventions.

**Cross-cutting data tasks**
- [x] Document all three datasets in a comparison table: source, size, features, target variable, imbalance ratio.
- [x] Standardize preprocessing across datasets: column types enforced, `pdays` transformed, missing values imputed (categorical → `"unknown"` level; numeric → training median). Encoding and scaling deferred to training pipeline.
- [x] Enforce column types in `02_preprocess.R` based on dataset documentation. Implemented via `cast_types_from_variables()` (reads `variables.csv`) for Bank Marketing / Taiwan / Australian, and `cast_types()` (manual spec) for South German / ULB / IEEE-CIS. Types are preserved in Parquet.
- [x] Create `scripts/00_download.py` to programmatically download datasets where a public URL is available (UCI datasets via `ucimlrepo`; South German Credit via direct zip URL). Kaggle datasets require manual download (API key or browser) and should print instructions instead.

**EDA**
- [x] Structural summary table: rows, features, numeric/categorical split, missing values, numeric range (`scripts/03_eda.R`).
- [x] Imbalance spectrum plot and class distribution bar chart.
- [x] IEEE-CIS missing column detail plot.
- [x] Verify y=1/y=0 encoding is consistent across all six datasets.

---

## Week 2: Experiment Design & Training

### Experiment Grid
- [ ] Define resampling techniques to compare (suggested: none, random oversampling, random undersampling, SMOTE, ROSE).
- [ ] Define models (suggested: logistic regression as baseline + one tree-based model, e.g. random forest or XGBoost).
- [ ] Define post-hoc calibration methods (suggested: Platt scaling, isotonic regression).
- [ ] Document the full experiment grid: 6 datasets × resampling × models × calibration.

### Training Pipeline — `scripts/05_train.R`
- [ ] Build a `{tidymodels}` recipe per dataset: dummy encoding for categoricals, z-score normalization for numerics.
- [ ] Integrate resampling via `{themis}` (applied to training partition only — never calibration or test).
- [ ] Fit each model × resampling combination; save fitted workflows to `models/`.
- [ ] Generate and save out-of-sample predictions on calibration and test sets to `output/predictions/`.

### Calibration — `scripts/06_calibrate.R`
- [ ] Fit Platt scaling (logistic regression on calibration set predicted probabilities).
- [ ] Fit isotonic regression on calibration set.
- [ ] Apply calibrators to test set predictions; save calibrated probabilities to `output/predictions/`.

---

## Week 3: Evaluation

### Metrics — `scripts/07_evaluate.R`
- [ ] Discrimination: AUROC, AUPRC per experiment.
- [ ] Calibration: Brier score, Expected Calibration Error (ECE), reliability diagrams.
- [ ] Aggregate results into a single `output/results.csv`: one row per dataset × resampling × model × calibration.

---

## Week 4: Writing & Reporting

### Report — `scripts/08_report.R` / `reports/`
- [ ] Main results table: discrimination and calibration metrics across all conditions.
- [ ] Figures: AUROC/AUPRC vs. imbalance ratio; calibration curves before/after post-hoc calibration.
- [ ] Write methods section: datasets, preprocessing, experiment grid, evaluation protocol.
- [ ] Write results and discussion.
- [ ] Format for target venue (KDMiLe 8-page or ENIAC 12-page).
- [ ] Proofread and submit by June 8th, 2026.

---

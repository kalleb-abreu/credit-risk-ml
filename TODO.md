# Research Paper Plan — Resampling, Risk Modeling & Calibration

**Domain:**  

**Resarch Question:** How do resampling techniques affect the calibration and discrimination of credit risk models under class imbalance, and can post-hoc calibration methods recover probability reliability?

**Target:** [KDMiLe](https://bracis.sbc.org.br/2026/kdmile/) (8 pages) or [ENIAC](https://bracis.sbc.org.br/2026/eniac/) (12 pages)

**Submission**: June 8th, 2026

**Language:** R 

---

## Week 1: Foundation & Data (Days 1-7)

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
- [ ] Perform EDA: summary stats, missing values, feature types, correlations.

**Moderately imbalanced dataset (minority class: 10–25%)**
- [x] Identify a moderately imbalanced dataset.
- [x] Download and verify class distribution.
- [ ] Perform EDA: summary stats, missing values, feature types, correlations.

**Near-balanced dataset (minority class: 25–50%)**
- [x] Identify a near-balanced dataset.
- [x] Download and verify class distribution.
- [ ] Perform EDA: summary stats, missing values, feature types, correlations.

**R Project Structure** 
- [x] Search GitHub repos for ML project structures in R, look for patterns in `data/`, `R/`, `models/`, `output/`.
- [x] Read Posit/tidyverse guidelines on project-oriented workflows.
- [x] Search blogs for R project structure conventions. Keywords: *"R project structure machine learning"*, *"targets pipeline R"*.
- [x] Check academic papers for how R ML studies organize scripts, data, and results.
- [x] Document the chosen structure: raw vs. processed data, model saving, script naming conventions.

**Cross-cutting data tasks**
- [x] Document all three datasets in a comparison table: source, size, features, target variable, imbalance ratio.
- [ ] Standardize preprocessing across datasets (missing value handling, encoding, scaling).
- [ ] Enforce column types in `02_preprocess.R` based on dataset documentation. Bank Marketing (`bank-additional-names.txt`) and South German (`codetable.txt`) have explicit type info; ULB, IEEE-CIS, Taiwan, and Australian have no description files — types must be defined manually.
- [ ] Create `scripts/00_download.R` to programmatically download datasets where a public URL is available (UCI datasets). Kaggle datasets require manual download (API key or browser) and should print instructions instead.

---

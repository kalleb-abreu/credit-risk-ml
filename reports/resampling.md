# Resampling Techniques for Imbalanced Datasets

Reference summary for the credit-risk-ml project. All techniques below address the class imbalance problem where the minority class (default/fraud) is far less frequent than the majority class.

---

## 1. Technique Overview

### Oversampling

| Technique | How it works | Strengths | Weaknesses |
|---|---|---|---|
| **Random Oversampling** | Duplicates minority samples at random | Simple, no information loss | Overfitting to duplicated examples |
| **SMOTE** | Generates synthetic points by interpolating between a minority sample and its k-nearest neighbors | Avoids duplicates, reduces overfitting vs random oversampling | Can amplify noise; struggles in high dimensions |
| **Borderline-SMOTE** | Applies SMOTE only to minority samples near the decision boundary | More targeted than SMOTE | Sensitive to boundary definition |
| **ADASYN** | Like SMOTE but generates more samples where the minority class is harder to learn (density-based) | Adaptive; focuses on difficult regions | Can over-generate in noisy areas |
| **ROSE** | Bootstraps synthetic samples from a conditional kernel density estimate of each class | Handles both continuous and categorical; smooths decision boundary | Less interpretable; may blur real patterns |

### Undersampling

| Technique | How it works | Strengths | Weaknesses |
|---|---|---|---|
| **Random Undersampling** | Removes majority samples at random | Fast; reduces training time | Discards potentially useful majority information |
| **Tomek Links** | Removes majority samples that are too close to minority samples (boundary cleaning) | Cleans noise near boundary; often used as post-processing | Only removes borderline majority samples — mild effect alone |
| **NearMiss** | Selects majority samples closest to minority samples | Principled selection strategy | Can remove informative majority samples |
| **ENN (Edited Nearest Neighbors)** | Removes samples (from any class) misclassified by their k-nearest neighbors | Cleans noisy samples from both classes | May remove too many samples |

### Hybrid Methods

| Technique | Composition | When to prefer |
|---|---|---|
| **SMOTE + Tomek Links** | SMOTE oversampling then Tomek boundary cleaning | Standard go-to hybrid; robust in most cases |
| **SMOTE + ENN** | SMOTE oversampling then ENN noise cleaning | When dataset has significant noise in minority class |
| **SMOTE + XGBoost** | SMOTE preprocessing + gradient boosting | Strong baseline for tabular credit/fraud data |

---

## 2. Best R Package: `themis`

**Recommendation: use `themis`** — it integrates natively with `tidymodels` / `recipes`, is actively maintained (v1.0.3, Jan 2025), and covers the full range of techniques.

### Available steps in `themis`

```r
# Oversampling
step_smote(var, over_ratio = 1, neighbors = 5)
step_bsmote(var, over_ratio = 1, neighbors = 5, all_neighbors = FALSE)
step_adasyn(var, over_ratio = 1, neighbors = 5)
step_rose(var, over_ratio = 1)
step_upsample(var, over_ratio = 1)

# Undersampling
step_downsample(var, under_ratio = 1)
step_nearmiss(var, under_ratio = 1, neighbors = 3)
step_tomek(var)
```

`over_ratio` = target ratio of minority to majority frequency (e.g., `0.5` means minority will be 50% of majority count).

### Other packages

| Package | Notes |
|---|---|
| `ROSE` | Standalone package for ROSE method; useful outside tidymodels |
| `smotefamily` | Exposes many SMOTE variants (SMOTE, ADASYN, SLS, etc.) |
| `imbalance` | Research-oriented; more exotic variants |
| `caret` | Has basic sampling via `trainControl(sampling = ...)` but less flexible than themis |

---

## 3. How to Apply Correctly

### Golden rule: resample only the training fold

Applying resampling before splitting causes **data leakage** — the model implicitly sees test distribution information during training. Synthetic samples generated from test data inflate evaluation metrics.

```r
library(tidymodels)
library(themis)

rec <- recipe(default ~ ., data = train_data) |>
  step_impute_median(all_numeric_predictors()) |>
  step_dummy(all_nominal_predictors()) |>
  step_smote(default, over_ratio = 0.5, neighbors = 5)  # applied only inside resampling folds

wf <- workflow() |>
  add_recipe(rec) |>
  add_model(logistic_reg())

# themis step_* are skip = TRUE by default on new data,
# so resampling is never applied to the assessment/test set.
cv_results <- fit_resamples(wf, vfold_cv(train_data, strata = default))
```

### Pipeline checklist

1. **Split** raw data into train / test first (stratified).
2. **Define recipe** with resampling as one of the steps.
3. **Fit resamples** (cross-validation) using the workflow — themis only applies the step to the analysis fold, never the assessment fold.
4. **Tune** `over_ratio` and `neighbors` if needed via `tune_grid()`.
5. **Final fit** on full training set and evaluate once on held-out test set.
6. **Metrics**: use ROC-AUC, PR-AUC, F1, or precision at fixed recall — not accuracy.

### Hyperparameter guidance

| Parameter | Default | Typical range | Effect |
|---|---|---|---|
| `over_ratio` | 1 (full balance) | 0.25 – 1.0 | Higher = more synthetic samples = more balance but more risk of overfitting |
| `neighbors` (k) | 5 | 3 – 10 | Lower k = more local/noisy synthetic samples |

Full balance (`over_ratio = 1`) is rarely optimal. Start with `0.25`–`0.5` and tune.

---

## 4. Scenario Guide

| Scenario | Recommended approach | Rationale |
|---|---|---|
| Large dataset, mild imbalance (10:1) | Random undersampling or SMOTE | Fast; enough majority samples remain |
| Large dataset, severe imbalance (100:1+) | SMOTE + Tomek Links or SMOTE + ENN | Hybrid cleans noise introduced by SMOTE |
| Small dataset, severe imbalance | ROSE or ADASYN (avoid aggressive undersampling) | Undersampling discards too much; ROSE/ADASYN generate diverse samples |
| High-dimensional features (many cols) | Class weights instead of SMOTE | SMOTE degrades in high dimensions; distance metrics become unreliable |
| Noisy minority class (outliers) | Borderline-SMOTE or SMOTE + ENN | Focuses on clean boundary samples; ENN removes noisy ones |
| Credit risk / fraud (tabular, moderate size) | SMOTE + Tomek Links with XGBoost or LightGBM | Strong empirical baseline in literature; pairs well with tree methods |
| Categorical-heavy features | ROSE or SMOTENC (via `smotefamily`) | Standard SMOTE uses Euclidean distance — not appropriate for pure categoricals |
| Ensemble methods (RF, XGBoost) | Try class weights first (`scale_pos_weight`) | Many boosting models handle imbalance internally without resampling |

---

## 5. Common Pitfalls

- **Resampling before splitting**: leaks test distribution into training — always split first.
- **Using accuracy as metric**: misleading for imbalanced data — prefer ROC-AUC, PR-AUC, or F1.
- **Over-balancing**: `over_ratio = 1` (perfect balance) often hurts — tune it.
- **SMOTE on test/validation set**: themis `skip = TRUE` prevents this by default; verify manually if using outside tidymodels.
- **Ignoring noise amplification**: SMOTE interpolates between all minority samples including outliers — consider BorderlineSMOTE or ENN cleaning.
- **High-dimensional trap**: SMOTE underperforms in high-dimensional spaces; prefer class weighting or dimensionality reduction first.

---

## Sources

- [Resampling approaches review — Springer Nature / Journal of Big Data (2025)](https://link.springer.com/article/10.1186/s40537-025-01119-4)
- [Handling Imbalanced Datasets: SMOTE to ENN and Beyond — Medium](https://medium.com/@dileeprawat830/handling-imbalanced-datasets-in-machine-learning-from-smote-to-enn-and-beyond-8ecc095c16c0)
- [Resampling strategies — Fraud Detection Handbook](https://fraud-detection-handbook.github.io/fraud-detection-handbook/Chapter_6_ImbalancedLearning/Resampling.html)
- [Subsampling for class imbalances — tidymodels official docs](https://www.tidymodels.org/learn/models/sub-sampling/)
- [themis package — CRAN (Jul 2025)](https://cran.r-project.org/web/packages/themis/themis.pdf)
- [themis official site](https://themis.tidymodels.org/)
- [ROSE package — CRAN (Jul 2025)](https://cran.r-project.org/web/packages/ROSE/ROSE.pdf)
- [Impact of Sampling Techniques and Data Leakage on XGBoost — arXiv](https://arxiv.org/html/2412.07437v1)
- [Comparative Analysis of Balancing Techniques for Credit Card Fraud — ScienceDirect](https://www.sciencedirect.com/science/article/pii/S1877050924031028)
- [SMOTE for Imbalanced Classification — MachineLearningMastery](https://machinelearningmastery.com/smote-oversampling-for-imbalanced-classification/)
- [SMOTE for high-dimensional imbalanced data — BMC Bioinformatics](https://link.springer.com/article/10.1186/1471-2105-14-106)

# Evaluation Metrics for Fraud Detection and Imbalanced Datasets

Reference summary for the credit-risk-ml project. All metrics below address the evaluation challenge of imbalanced classification, where standard accuracy becomes misleading.

---

## 1. Why Standard Metrics Fail Under Imbalance

**Accuracy** is useless for fraud: predicting "no fraud" for every observation on a 0.5% fraud rate gives 99.5% accuracy while catching zero frauds. Similarly, **ROC-AUC** shows ceiling effects under severe imbalance — it is dominated by true-negative comparisons and remains artificially high even when a classifier makes many costly errors on the minority class.

---

## 2. Metric Reference

### Discrimination Metrics (ranking / ordering)

| Metric | Formula / Intuition | `yardstick` function | Primary use |
|---|---|---|---|
| **PR-AUC** | Area under Precision–Recall curve; focuses exclusively on the minority class | `pr_auc(truth, estimate)` | **Primary metric for severe imbalance** |
| **ROC-AUC** | Area under TPR vs. FPR curve; treats both classes equally | `roc_auc(truth, estimate)` | Supplementary; misleading alone at extreme imbalance |
| **F1 Score** | 2 × (Precision × Recall) / (Precision + Recall) | `f_meas(truth, estimate)` | Moderate imbalance; equal cost of FP and FN |
| **F2 Score** | Fβ with β = 2; weights recall 2× over precision | `f_meas(truth, estimate, beta = 2)` | Fraud — missing a fraud is more costly than a false alarm |
| **MCC** | Correlation coefficient over all four confusion matrix cells; range −1 to +1 | `mcc(truth, estimate)` | **Robust summary for any imbalance level** |
| **Sensitivity (Recall)** | TP / (TP + FN); proportion of frauds caught | `sens(truth, estimate)` | Ensures frauds are not missed |
| **Specificity** | TN / (TN + FP); proportion of legit transactions cleared | `spec(truth, estimate)` | Controls false-alarm rate |
| **Balanced Accuracy** | (Sensitivity + Specificity) / 2 | `bal_accuracy(truth, estimate)` | Single-number summary when costs are symmetric |
| **G-Mean** | √(Sensitivity × Specificity) | custom: `sqrt(sens * spec)` | When both class errors are equally penalized |

### Calibration Metrics (probability reliability)

| Metric | Formula / Intuition | R approach | Primary use |
|---|---|---|---|
| **Brier Score** | Mean squared error of predicted probabilities: (1/n) Σ(p̂ − y)² | `brier_class(truth, estimate)` | Measures combined calibration + discrimination |
| **ECE** | Weighted mean \|predicted prob − actual rate\| across probability bins | custom or `CalibrationCurves` pkg | Measures calibration error for threshold-based decisions |
| **Log Loss** | −(1/n) Σ[y log(p̂) + (1−y) log(1−p̂)]; proper scoring rule | `mn_log_loss(truth, estimate)` | Penalizes confident wrong predictions |
| **Reliability diagram** | Visual: predicted probability (x) vs. actual positive rate (y) per bin | `cal_plot_breaks()` in `probably` pkg | Diagnose over/underconfidence by probability range |

---

## 3. Metric Interpretation Guide

### PR-AUC
- Random baseline = class prevalence (e.g., 0.17% for ULB, not 0.5). A model at 0.30 PR-AUC on a 0.17%-prevalence dataset is far above baseline.
- As imbalance worsens, the gap between PR-AUC and ROC-AUC grows — PR-AUC is the more discriminating signal.

### MCC
- Only metric that treats all four confusion matrix cells proportionally (TP, TN, FP, FN).
- Produces high values only when the model performs well across all cells — cannot be gamed by a class-biased predictor.
- Does not depend on which class is labeled "positive."

### Brier Score
- Decomposable into **resolution** (discrimination ability) + **reliability** (calibration) + **uncertainty** (irreducible noise).
- Imbalance baseline: p × (1 − p) where p = fraud rate. A model must beat this to be considered useful.

### ECE
- ECE = 0 means predicted probabilities perfectly match observed frequencies.
- Particularly important for this project: post-hoc calibration (Platt scaling, isotonic regression) is evaluated by how much ECE decreases relative to the uncalibrated model.

---

## 4. Recommended Package: `yardstick`

**Use `yardstick` as the primary package.** It is the metrics library of the `tidymodels` ecosystem, integrates natively with `tune` and `fit_resamples`, and covers all metrics in this project.

```r
library(yardstick)
library(probably)  # calibration: cal_plot_breaks(), cal_apply()

metric_set_discrimination <- metric_set(
  pr_auc, roc_auc, mcc,       # primary + supplementary discrimination
  sens, spec                  # operating-point diagnostics
)

metric_set_calibration <- metric_set(
  brier_class, mn_log_loss
)

# Usage inside tidymodels workflow
results <- fit_resamples(
  workflow,
  resamples = vfold_cv(train_data, strata = y),
  metrics   = metric_set_discrimination
)
collect_metrics(results)
```

### Other packages

| Package | Role | When to use |
|---|---|---|
| `probably` | Calibration curves, Platt/isotonic recalibration | Core calibration workflow for this project |
| `pROC` | Advanced ROC statistics, CI for AUC, curve comparison | Only when paired ROC tests are needed |
| `ROCR` | Legacy ROC; stable, mature | Compatibility with older code |
| `hmeasure` | H-measure (cost-sensitive AUC alternative) | When explicit FP/FN cost structure is available |
| `CalibrationCurves` | ECE and calibration diagnostics | Detailed calibration reporting |

---

## 5. Metric Set for This Project

**Use the same metric set across all six datasets.** The experiment compares 9 resampling conditions × 3 classifiers × 6 datasets. Changing metrics per dataset would break cross-dataset comparability — the metric behavior differences across imbalance levels are a *finding*, not a reason to use different metrics. PR-AUC and MCC both work at every imbalance level; only their interpretation of the baseline shifts.

### Unified metric set

| Role | Metric | `yardstick` / `probably` function |
|---|---|---|
| **Primary discrimination** | PR-AUC | `pr_auc(truth, .pred_1)` |
| **Secondary discrimination** | ROC-AUC | `roc_auc(truth, .pred_1)` |
| **Threshold-free summary** | MCC | `mcc(truth, .pred_class)` |
| **Primary calibration** | Brier Score | `brier_class(truth, .pred_1)` |
| **Primary calibration** | ECE | custom or `CalibrationCurves` |
| **Visual calibration** | Reliability diagram | `cal_plot_breaks(truth, .pred_1)` |
| **Operating-point diagnostics** | Sensitivity, Specificity | `sens()`, `spec()` |

F1/F2 are **not** primary metrics — they require a fixed classification threshold, which would introduce an arbitrary choice that varies across datasets and conditions. If a threshold-level summary is needed for the paper (e.g., to compare with prior literature that reports F1), compute F2 at the threshold that maximizes it and report it as supplementary.

### Scenario guide (general reference)

| Scenario | Primary metrics | Secondary metrics | Avoid |
|---|---|---|---|
| Extreme imbalance (< 2% minority) | PR-AUC, MCC | ROC-AUC, Sensitivity, Brier Score | Accuracy, ROC-AUC alone |
| Moderate imbalance (5–25% minority) | PR-AUC, MCC | ROC-AUC, Balanced Accuracy | Accuracy alone |
| Near-balanced (25–50% minority) | ROC-AUC, MCC | PR-AUC, Balanced Accuracy | — |
| Probability calibration evaluation | Brier Score, ECE, Reliability diagram | Log Loss | AUC metrics (measure ranking, not calibration) |
| Cost-sensitive (explicit FP/FN costs) | H-measure, F2 | PR-AUC, MCC | Unweighted accuracy, F1 |
| Threshold selection | PR curve, Sensitivity + Specificity at operating point | F2 at fixed recall | Single-threshold F1 |
| Comparing resampling methods | PR-AUC, MCC | Sensitivity | ROC-AUC (too stable to discriminate) |
| Comparing calibration methods | Brier Score, ECE | Reliability diagram | Discrimination-only metrics |

---

## 6. What NOT to Use (and Why)

| Metric | Problem | Use instead |
|---|---|---|
| **Accuracy** | Trivially maximized by predicting majority class | Balanced Accuracy, MCC |
| **ROC-AUC alone** | Ceiling effect under severe imbalance; dominated by TN comparisons | PR-AUC + MCC |
| **F1 alone for fraud** | Equal weight on precision and recall; fraud misses are costlier | F2 (β = 2) |
| **Hosmer–Lemeshow test** | Unstable, bin-dependent, low power, no correction for overfitting | Brier Score + reliability diagram + ECE |
| **Precision alone** | Trivially optimized with tiny recall | Always pair with recall/sensitivity |

---

## 7. Calibration Assessment Workflow

This project evaluates post-hoc calibration (Platt scaling, isotonic regression) applied after model training. The calibration pipeline:

1. **Fit model** on training partition (with resampling).
2. **Predict probabilities** on calibration partition (never used for training).
3. **Fit calibrator** (Platt / isotonic) on calibration partition predictions.
4. **Evaluate** on test partition using:
   - Reliability diagram before vs. after calibration.
   - Brier Score before vs. after.
   - ECE before vs. after.
5. **Discrimination metrics** (PR-AUC, MCC, F2) are computed on the test partition using the calibrated probabilities.

```r
library(probably)

# After fitting a model and predicting on calibration set
cal_fit <- cal_estimate_isotonic(calibration_preds, truth = y)

# Apply to test set
test_calibrated <- cal_apply(test_preds, cal_fit)

# Evaluate calibration
cal_plot_breaks(test_calibrated, truth = y, estimate = .pred_1)

# Evaluate discrimination on calibrated probabilities
test_calibrated |>
  pr_auc(truth = y, estimate = .pred_1) |>
  bind_rows(brier_class(test_calibrated, truth = y, estimate = .pred_1))
```

---

## Sources

- [Why ROC-AUC Is Misleading for Highly Imbalanced Data — MDPI Technologies (2026)](https://www.mdpi.com/2227-7090/14/1/54)
- [The advantages of MCC over F1 score and accuracy — BMC Genomics (2020)](https://link.springer.com/article/10.1186/s12864-019-6413-7)
- [Accuracy, precision, recall, F1, MCC: empirical evidence — J. Big Data (2025)](https://link.springer.com/article/10.1186/s40537-025-01313-4)
- [ROC AUC vs Precision-Recall for Imbalanced Data — MLM (2020)](https://machinelearningmastery.com/roc-auc-vs-precision-recall-for-imbalanced-data/)
- [Tour of Evaluation Metrics for Imbalanced Classification — MLM (2020)](https://machinelearningmastery.com/tour-of-evaluation-metrics-for-imbalanced-classification/)
- [Fraud Detection Handbook — Resampling (2022)](https://fraud-detection-handbook.github.io/fraud-detection-handbook/Chapter_6_ImbalancedLearning/Resampling.html)
- [yardstick — tidymodels (2025)](https://yardstick.tidymodels.org/)
- [probably — tidymodels calibration (2025)](https://probably.tidymodels.org/)
- [Understanding Model Calibration: ECE — arXiv (2025)](https://arxiv.org/html/2501.19047v2)
- [Tutorial on calibration for clinical prediction models — JAMIA (2020)](https://academic.oup.com/jamia/article/27/4/621/5762806)
- [Imbalanced class distribution and performance evaluation: systematic review — PMC (2023)](https://pmc.ncbi.nlm.nih.gov/articles/PMC10688675/)

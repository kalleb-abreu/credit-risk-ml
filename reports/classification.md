# Classification Techniques in R

## Quick Reference

| Algorithm | Data Size | Train Speed | Accuracy | Interpretability | Key Packages |
|---|---|---|---|---|---|
| Logistic Regression | Any | Very Fast | Low–Med | Excellent | `glm`, `glmnet` |
| Decision Trees | Medium | Fast | Medium | Excellent | `rpart` |
| Random Forest | Large | Fast | High | Low–Med | `ranger`, `randomForest` |
| Gradient Boosting | Large | Medium | Highest | Low | `lightgbm`, `xgboost` |
| SVM | Small–Med | Slow | High | Low | `e1071`, `kernlab` |
| KNN | Small–Med | None | Medium | Medium | `class`, `kknn` |
| Naive Bayes | Any | Very Fast | Medium | High | `e1071` |
| Neural Networks | Large | Slow | Highest | Very Low | `keras`, `torch` |
| LDA / QDA | Small–Med | Very Fast | Medium | High | `MASS` |

---

## 1. Logistic Regression

**When to use:** Linear or near-linear decision boundaries, small datasets, need probability outputs, interpretability required (medical, credit, legal).

**Best packages:** `glm()` (base R), `glmnet` (regularized), `caret`/`tidymodels` for pipelines.

**Key hyperparameters:**
- `alpha`: 0 = Ridge, 1 = Lasso, in-between = Elastic Net
- `lambda`: regularization strength (tune via CV)

**Strengths:** Fast, interpretable, probabilistic, handles well-separated classes.
**Weaknesses:** Assumes linear boundary; underfits complex relationships.

---

## 2. Decision Trees

**When to use:** Need white-box model, mixed feature types (numeric + categorical), hierarchical rules, business decision contexts.

**Best package:** `rpart` (CART), `partykit` for visualization.

**Key hyperparameters:**
- `cp`: complexity parameter — lower = larger tree
- `minsplit` / `minbucket`: min samples to split / in leaf
- `maxdepth`: prevents overfitting

**Strengths:** Highly interpretable, no scaling required, captures non-linear splits.
**Weaknesses:** High variance, prone to overfitting, biased toward high-cardinality features.

---

## 3. Random Forest

**When to use:** Medium–large datasets, complex non-linear relationships, feature importance needed, don't require strong interpretability.

**Best packages:** `ranger` (fast, recommended), `randomForest`.

**Key hyperparameters:**
- `mtry`: features sampled per split (default: √p for classification)
- `num.trees` / `ntree`: 500–1000 typical
- `min.node.size`: minimum leaf samples

**Strengths:** High accuracy, reduces overfitting vs. single trees, built-in feature importance, handles missing data.
**Weaknesses:** Less interpretable, slow on very large data, sensitive to class imbalance.

---

## 4. Gradient Boosting

**When to use:** Maximum predictive accuracy on tabular data, large datasets, feature interactions important, Kaggle/competition problems.

**Best packages:**
- `lightgbm` — faster and more memory-efficient for large datasets; **recommended default**
- `xgboost` — more stable and easier to tune; prefer in regulated environments or when reproducibility across platforms matters
- `catboost` — automatic categorical feature handling, but not on CRAN (breaks `renv`)

**Key hyperparameters:**
- `learning_rate`: 0.01–0.1
- `max_depth`: 3–10
- `num_rounds` / `n_estimators`: number of boosting rounds
- `subsample` / `colsample_bytree`: row and column sampling (0.5–0.9)
- `reg_lambda` / `reg_alpha`: L2 / L1 regularization

**Strengths:** Highest accuracy on structured data, built-in regularization, handles missing values, parallel training.
**Weaknesses:** Many hyperparameters, can overfit small datasets, harder to interpret.

**LightGBM vs XGBoost:** LightGBM uses leaf-wise tree growth — reaches the same accuracy with fewer splits, trains faster, and uses less memory. XGBoost uses depth-wise growth, which is more stable on small datasets. For large tabular datasets (>50k rows), LightGBM is the better default. Both reach similar accuracy with proper tuning.

---

## 5. Support Vector Machines (SVM)

**When to use:** High-dimensional data, small–medium datasets, non-linear boundaries with kernel trick, interpretability not critical.

**Best packages:** `e1071` (most common), `kernlab` (more flexible kernels).

**Key hyperparameters:**
- `kernel`: `linear`, `radial` (RBF, recommended default), `polynomial`
- `cost` (C): margin penalty — small C = wide margin, large C = narrow margin
- `gamma`: RBF spread — tune alongside C

**Strengths:** Effective in high dimensions, memory-efficient (only support vectors stored), robust to outliers.
**Weaknesses:** Slow on large datasets, requires feature scaling, many parameters to tune.

---

## 6. K-Nearest Neighbors (KNN)

**When to use:** Local patterns are important, non-parametric approach preferred, small–medium datasets, quick baseline.

**Best packages:** `class` (basic), `kknn` (weighted distances).

**Key hyperparameters:**
- `k`: number of neighbors — small k = high variance, large k = high bias; optimal usually 5–15
- `distance`: Euclidean (default), Manhattan, Minkowski
- `weights`: uniform vs. distance-weighted

**Strengths:** Simple, no training phase, naturally multiclass, captures local structure.
**Weaknesses:** Slow prediction (all-pairs distance), curse of dimensionality, must scale features, memory-heavy.

---

## 7. Naive Bayes

**When to use:** Text classification, spam detection, high-dimensional sparse data, need very fast training/prediction.

**Best package:** `e1071::naiveBayes()`.

**Key settings:**
- `laplace`: Laplace smoothing (set > 0 to avoid zero probabilities)
- Numeric features: assumed normally distributed
- Factor features: handled directly

**Strengths:** Extremely fast, works with sparse/text data, little training data needed, naturally multiclass.
**Weaknesses:** Strong independence assumption rarely holds; underperforms on dense numerical data.

---

## 8. Neural Networks / Deep Learning

**When to use:** Large datasets (thousands+ samples), unstructured data (images, text, sequences), need state-of-the-art performance, GPU available.

**Best packages:** `keras` + `tensorflow`, `torch` (newer).

**Key hyperparameters:**
- Architecture: number/size of layers
- `activation`: ReLU (hidden layers), softmax (output for multiclass)
- `learning_rate`: typically 0.001 with Adam
- `batch_size`: 32–256
- `dropout`: 0.2–0.5 (regularization)

**Strengths:** Best accuracy on complex unstructured data, automatic feature learning, scales to massive datasets.
**Weaknesses:** Requires large data, GPU-dependent for practical training, black-box, complex tuning.

---

## 9. LDA / QDA

**When to use:** Multiclass problems, assume roughly Gaussian features, need fast interpretable model with probability outputs.

**Best package:** `MASS::lda()`, `MASS::qda()`.

| | LDA | QDA |
|---|---|---|
| Covariance | Equal across classes | Per-class covariance |
| Boundary | Linear | Quadratic |
| Flexibility | Lower | Higher |
| Data need | Small–medium | Larger |

**Strengths:** Fast, interpretable, probabilistic, natural multiclass.
**Weaknesses:** Normality assumption, sensitive to outliers, QDA overfits on small data.

---

## Best Practices

### Data Splitting

- Use **stratified** train/test split to preserve class proportions (80/20 typical).
- Apply **10-fold stratified cross-validation** for model selection and hyperparameter tuning.
- Fit all preprocessing (scaling, imputation) **inside the fold** on training data only — never on the full dataset.

### Handling Class Imbalance

| Technique | When to use |
|---|---|
| `class.weights` / `scale_pos_weight` | Native class weighting in the model |
| Undersampling | Fast, acceptable information loss |
| Oversampling (duplication) | Small datasets |
| SMOTE | Creates synthetic minority samples — reduces overfitting vs. duplication |
| Threshold tuning | Adjust decision cutoff post-training |

R tools: `themis` package (SMOTE for tidymodels), `DMwR2::SMOTE()`, `caret` sampling options.

### Feature Preprocessing

Always required for: **SVM, KNN, Logistic Regression, Neural Networks, LDA/QDA**.
Not required for: **tree-based models** (Decision Trees, Random Forest, GBM, Naive Bayes).

Standard pipeline: imputation → near-zero variance filter → centering + scaling → (optional) PCA.

### Evaluation Metrics

| Scenario | Preferred Metrics |
|---|---|
| Balanced classes | Accuracy, ROC-AUC |
| Imbalanced classes | F1, PR-AUC, Kappa |
| Rare positive class | PR-AUC (more informative than ROC-AUC) |
| Cost-sensitive | Weighted F1, custom cost matrix |

### Hyperparameter Tuning

- **Grid search**: exhaustive, good for known ranges, expensive.
- **Random search**: more efficient exploration, recommended default.
- **Bayesian optimization**: most efficient for expensive models (`mlr3tuning`, `tune` in tidymodels).

### Framework Choice

| Framework | Best for |
|---|---|
| `caret` | Standard workflows, 200+ model catalog, mature |
| `tidymodels` | Modern tidy pipelines, composable recipes |
| `mlr3` | Advanced research, maximum flexibility, benchmarking |

---

## Recommended Workflow

1. Explore: distributions, missingness, class balance, feature types.
2. Baseline: logistic regression — sets a floor for accuracy.
3. Preprocess: impute → scale (if needed) → engineer features.
4. Compare: Logistic Regression (baseline), Random Forest (`ranger`), LightGBM (`lightgbm`) via stratified CV.
5. Tune: random/Bayesian search on best candidate(s).
6. Ensemble: stack/blend top models if marginal gains needed.
7. Evaluate: final metrics on held-out test set — do not tune after this step.
8. Interpret: feature importance, SHAP values, partial dependence plots.

# SMISHield ML pipeline

Trains the TF-IDF + Multinomial Naive Bayes model that classifies Filipino and
Taglish SMS messages as **Safe**, **Suspicious** or **High Risk**, writes the
evaluation reports for Chapter 4, and exports the model for the Android app.

> **The bundled model is trained on `data/placeholder_dataset.csv`, a small
> made-up dataset.** It exists only so the app can be built and tested. Its
> numbers must not be reported. Retrain with the collected dataset (below).

## Setup

```
pip install -r ml/requirements.txt
```

## Training with the collected dataset

Export the labelled responses as CSV or XLSX with one column for the message
and one for the label (`Safe`, `Suspicious`, `High Risk`; spelling and case are
flexible, e.g. `high risk`, `HIGH_RISK`). Then, from the repository root:

```
python ml/train.py --data path/to/smishield_dataset.csv
```

If the columns are not called `message`/`label` (or `text`, `sms`, `category`,
...), name them: `--text-col "SMS Message" --label-col "Classification"`.

The script:

1. Drops duplicates: messages identical after preprocessing are kept once,
   and near-duplicates (Jaccard similarity ≥ 0.9 of their words) are removed
   so the same message cannot appear in both training and testing. Copies
   with **conflicting labels** are all dropped and listed for you to resolve.
   Change with `--near-dup-threshold 0.8`, or `0` to only drop exact copies.
2. Splits 80:20, stratified by label, with a fixed seed (`--seed 42`).
3. Picks the n-gram range, sublinear TF and smoothing `alpha` with 5-fold
   cross-validation on the **training set only** (`--no-tune` to skip).
4. Fits the TF-IDF vectorizer on the training messages only and evaluates on
   the held-out 20%.
5. Exports `app/assets/model/smishield_model.json` and the Dart test fixture
   `app/test/fixtures/model_parity_cases.json`, after checking that the
   exported model reproduces scikit-learn's probabilities.

The app uses exactly the model that was evaluated (trained on the 80% split),
so the reported metrics describe the shipped model.

## Reports (`ml/reports/`, not committed)

| File | Contents |
|---|---|
| `summary.md` | Dataset counts, settings, confusion matrix, accuracy, per-class and averaged precision/recall/F1, and the Figure 19 TP/TN/FP/FN scheme |
| `metrics.json` | The same numbers, machine-readable |
| `confusion_matrix.csv` / `.png` | Confusion matrix table and figure |
| `test_predictions.csv` | Every test message with actual and predicted label and probabilities (for error analysis) |
| `train_test_split.csv` | Which message went to which split |
| `dropped_duplicates.csv` | Removed duplicates and label conflicts, with the reason |

### About the two sets of metrics

- **Per-class / macro / weighted**: the standard multi-class metrics
  (scikit-learn). Macro averages treat the three classes equally.
- **Figure 19 scheme**: the research plan's confusion matrix, which treats
  Safe→Safe as TN, a correct Suspicious or High Risk as TP, predicting a
  *higher* risk than the actual one as FP, and a *lower* risk as FN.
  Accuracy is the same under both.

## Preprocessing

Defined in `smishield_ml/preprocess.py` and mirrored in
`app/lib/ml/preprocessor.dart`:

1. lowercase; accents removed from vowels (ñ is kept)
2. links → `tokurl` + the words of the domain (`bpi-secure-login.com` →
   `tokurl bpi secure login com`); shortened links (bit.ly, tinyurl, ...) →
   `tokurl tokshorturl`
3. e-mail addresses → `tokemail`, PH mobile numbers → `tokphone`, peso amounts
   (₱500, P1,000, PHP 50, 50k, 100 pesos) → `tokmoney`, other numbers → `toknum`
4. apostrophes removed; letters repeated 3+ times shortened to 2 (`grabeee` → `grabee`)
5. everything else that is not a letter becomes a space; split into words

No stop-word removal and no translation, so Filipino and Taglish wording is
kept. If you change the preprocessing, change both files, bump
`PREPROCESSING_VERSION` in both, and retrain; the app refuses a model built
with a different version.

## Trying the model

```
python ml/predict.py "URGENT! I-verify ang GCash mo sa gcash-verify.xyz"
```

or, with the app's full explanation (warning signs, highlights, advice):

```
cd app
dart run tool/analyze.dart "URGENT! I-verify ang GCash mo sa gcash-verify.xyz"
dart run tool/analyze.dart --fil "..."
```

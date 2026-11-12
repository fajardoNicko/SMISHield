# SMISHield ML pipeline

Builds the dataset, trains the TF-IDF + Multinomial Naive Bayes model that
classifies Filipino and Taglish SMS messages as **Safe**, **Suspicious** or
**High Risk**, writes the evaluation reports for Chapter 4, and exports the
model for the Android app.

> **The bundled model is trained on INTERIM labels**: the researchers' manual
> labels for the Kaggle messages both annotators agreed on (the 176 still
> waiting for adjudication are left out) plus the first VCSMS submissions,
> labelled once. Its numbers must not be reported. Retrain once adjudication
> is finished (step 4 below).

How messages are labelled, and the published sources behind the method, are
in **[LABELING_GUIDE.md](LABELING_GUIDE.md)**. Where the data comes from and
what may be committed is in [data/README.md](data/README.md).

## Setup

```
pip install -r ml/requirements.txt
```

## Workflow

Run everything from the repository root.

**1. Download** the Kaggle files into `ml/data/raw/`: `tagalog-sms.xlsx` and
the Philippine Spam/Scam SMS file.

**2. Prepare** (combine, redact, de-duplicate, suggest labels, create the
annotation workbooks):

```
python ml/prepare_dataset.py
```

This writes `ml/data/prepared/public_sms_prepared.csv` and, in
`ml/annotation/`, `agreement_R1.xlsx`, `agreement_R2.xlsx` (the same 20%
sample for two researchers) and `main_annotation.xlsx` (the rest). Workbooks
that already contain labels are never overwritten.

**3. Label** the workbooks by following LABELING_GUIDE.md. R1 and R2 work
alone on the agreement sample; the rest of the team splits the main workbook.

**4. Finalize** (agreement check, adjudication, merge):

```
python ml/finalize_labels.py
```

The first run reports Cohen's kappa (and any labels whose criteria codes do
not fit them) in `ml/annotation/agreement_report.md`, and writes
`adjudication.xlsx` with the messages R1 and R2 labelled differently. After a
third researcher fills `final_label` there and the main workbook is complete,
the next run writes `ml/data/labeled/public_sms_labeled.csv`.

If the filled-in workbooks are elsewhere, point to them with `--r1` / `--r2`
and `--main`. When the main set was labelled twice too, give `--main` both
workbooks, in the same annotator order as `--r1` / `--r2`: its agreement is
reported as well and its disagreements join `adjudication.xlsx` (final labels
already entered there are kept). To train before every message is settled,
`--interim` writes just the settled ones, and train.py marks the result
INTERIM:

```
python ml/finalize_labels.py --r1 "Data/20%/<R1>.xlsx" --r2 "Data/20%/<R2>.xlsx" --main "Data/80%/<R1>.xlsx" "Data/80%/<R2>.xlsx" --interim
python ml/train.py --data ml/data/labeled/interim_labeled.csv --label-status interim
```

**VCSMS submissions** (private: student data never enters the repository).
Put the Google Form export in `Data/vcsms/` and run:

```
python ml/prepare_vcsms.py "Data/vcsms/<export>.xlsx"
```

This redacts the messages, gives them ids (`VC-00001`, ...), and writes the
labelled ones to `ml/data/private/vcsms_labeled.csv`. It also writes a blank
copy, `ml/annotation/vcsms_R2.xlsx`, for a second annotator.

**Synthetic messages (training only).** Synthetic messages fill gaps in the
collected data: everyday personal texts, and the same promo sent with an
official link and with a look-alike link. Pass them with `--train-only`. They
are added to the training set only, after removing any that repeat or nearly
repeat a real message. Validation and test stay 100% real, and the reports and
the model file record how many were used. Report them in Chapter 3, for
example:

> To cover message types missing from the collected data (everyday personal
> texts, and scams that differ from genuine promotions only in their link),
> N synthetic messages were written and labelled by the researchers with the
> same codebook. They were used for training only; the validation and test
> sets contain only real messages (Feng et al., 2021).

Feng, S. Y., Gangal, V., Wei, J., Chandar, S., Vosoughi, S., Mitamura, T., &
Hovy, E. (2021). A survey of data augmentation approaches for NLP. In
*Findings of the Association for Computational Linguistics: ACL-IJCNLP 2021*
(pp. 968–988). https://doi.org/10.18653/v1/2021.findings-acl.84

**5. Train and evaluate:**

```
python ml/train.py --data ml/data/labeled/public_sms_labeled.csv ml/data/private/vcsms_labeled.csv --train-only ml/data/private/synthetic_labeled.csv
```

Several `--data` files are combined before the split, which is stratified
by label and source. The reports show the test results for each source.

Until step 4 is done, a provisional model can be trained from the suggested
labels. Its reports are marked PROVISIONAL:

```
python ml/train.py --data ml/data/prepared/public_sms_prepared.csv --label-col provisional_label
```

## What train.py does

1. Loads the dataset (CSV or XLSX). Labels are `Safe`, `Suspicious`, `High Risk`
   (case and spacing are flexible); rows labelled `Exclude` or left empty are
   skipped. If the columns are not called `message`/`label` (or `text`, `sms`,
   `category`, ...), name them with `--text-col` / `--label-col`.
2. Drops duplicates: messages identical after preprocessing are kept once,
   and near-duplicates (Jaccard similarity ≥ 0.9 of their words) are removed,
   so the same message cannot be in both training and testing. Copies with
   **conflicting labels** are all dropped and listed for you to resolve.
3. Splits **70 : 10 : 20** into training, validation and test sets, stratified
   by label, with a fixed seed (`--seed 42`; change the shares with
   `--val-size` / `--test-size`).
4. Fits each candidate setting (n-gram range, sublinear TF, smoothing `alpha`,
   learned vs. equal class priors) on the training set and keeps the one with
   the best macro F1 on the **validation** set (`--no-tune` uses defaults).
   The TF-IDF vocabulary comes from the training messages only.
5. Evaluates that model once on the **test** set.
6. Exports `app/assets/model/smishield_model.json` and the Dart test fixture
   `app/test/fixtures/model_parity_cases.json`, after checking that the
   exported model reproduces scikit-learn's probabilities.

The app ships exactly the model that was evaluated (trained on the 70%
training split), so the reported metrics describe the shipped model.

## Reports (`ml/reports/`, not committed)

| File | Contents |
|---|---|
| `summary.md` | Dataset counts, chosen settings, confusion matrix, accuracy, per-class and averaged precision/recall/F1, the Figure 19 TP/TN/FP/FN scheme, and results per data source |
| `metrics.json` | The same numbers, machine-readable |
| `confusion_matrix.csv` / `.png` | Confusion matrix table and figure |
| `test_predictions.csv` | Every test message with its source, actual and predicted label, and probabilities (for error analysis) |
| `train_val_test_split.csv` | Which message went to which split |
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
2. redaction placeholders `[PHONE]`, `[EMAIL]`, `[NAME]`/`<NAME>`, `[ACCOUNT]`
   → the same markers as a real number, address or name; disguised dots
   (`site(.)com`) restored
3. links → `tokurl` + the words of the domain (`bpi-secure-login.com` →
   `tokurl bpi secure login com`); shortened links (bit.ly, tinyurl, ...) →
   `tokurl tokshorturl`
4. e-mail addresses → `tokemail`, PH mobile numbers → `tokphone`, peso amounts
   (₱500, P1,000, PHP 50, 50k, 100 pesos) → `tokmoney`, other numbers → `toknum`
5. apostrophes removed; letters repeated 3+ times shortened to 2 (`grabeee` → `grabee`)
6. everything else that is not a letter becomes a space; split into words

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

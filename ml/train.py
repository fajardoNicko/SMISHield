"""Train, evaluate and export the SMISHield classifier.

Run from the repository root:

    python ml/train.py --data path/to/dataset.csv

What it does:
  1. Loads the labelled dataset (CSV or XLSX; Safe / Suspicious / High Risk).
  2. Drops duplicate and near-duplicate messages (listed in the reports).
  3. Splits 70:10:20 into training, validation and test sets, stratified by
     label (fixed seed, so results are repeatable).
  4. Fits every candidate TF-IDF / Multinomial Naive Bayes setting on the
     training set and keeps the one with the best macro F1 on the validation
     set. The test set is not used for any choice.
  5. Evaluates that model once on the test set and writes the Chapter 4
     reports (confusion matrix, accuracy, precision, recall, F1) to ml/reports/.
  6. Exports the model to app/assets/model/smishield_model.json and writes the
     Dart parity fixture used by the app's tests.
"""

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics import accuracy_score, f1_score
from sklearn.model_selection import ParameterGrid, train_test_split
from sklearn.naive_bayes import MultinomialNB
from sklearn.pipeline import Pipeline

from smishield_ml import CLASSES
from smishield_ml.dataset import deduplicate, load_dataset
from smishield_ml.exported_model import ExportedModel, export_model
from smishield_ml.metrics import evaluate
from smishield_ml.preprocess import PREPROCESSING_VERSION, tokenize

REPO = Path(__file__).resolve().parent.parent
DEFAULT_MODEL_OUT = REPO / "app" / "assets" / "model" / "smishield_model.json"
DEFAULT_PARITY_OUT = REPO / "app" / "test" / "fixtures" / "model_parity_cases.json"
DEFAULT_REPORTS = REPO / "ml" / "reports"

DEFAULT_PARAMS = {"tfidf__ngram_range": (1, 2), "tfidf__sublinear_tf": True,
                  "nb__alpha": 0.1, "nb__fit_prior": True}
PARAM_GRID = {
    "tfidf__ngram_range": [(1, 1), (1, 2)],
    "tfidf__sublinear_tf": [False, True],
    "nb__alpha": [0.01, 0.05, 0.1, 0.25, 0.5, 1.0],
    # False gives every class the same prior, which helps a rare class.
    "nb__fit_prior": [True, False],
}

# What the labels in a dataset are; anything but "final" must not be reported.
STATUS_NOTES = {
    "placeholder": "PLACEHOLDER DATA. These numbers come from the made-up placeholder dataset "
                   "and must not be reported as study results.",
    "provisional": "PROVISIONAL LABELS. The labels are rule-based suggestions "
                   "(ml/smishield_ml/prelabel.py), not the researchers' manual labels, so these "
                   "numbers only show how well the model reproduces those rules. Do not report "
                   "them; retrain on the output of ml/finalize_labels.py.",
}

# Tricky inputs that must tokenise identically in Python and Dart.
PARITY_EDGE_CASES = [
    "URGENT!!! Your BPI account has been LOCKED. Verify now at https://bpi-secure-login.com/verify?id=123",
    "Click bit.ly/3xYz9Ab para i-claim ang ₱5,000 mo!",
    "Email us at support@gcash-help.com or call +63 917 123 4567",
    "Tumawag ka sa 0917-123-4567 o 09181234567 o +639201234567",
    "Nanalo ka ng P10,000.00 at 50k cash! PHP 1,500 lang ang fee",
    "Visit www.lazada.com.ph. Salamat po!",
    "Sobrang gandaaaa ng araw, pleaseeee reply",
    "Héllo, pañuelo at ÉXITO",
    "Mag-log-in sa 192.168.10.1:8080/admin para ma-verify",
    "Don’t share your OTP 123456 with anyone. ‘Wag ibigay.",
    "Hi po​mama,\tnasaan\nka?",
    "gcash.com.ph/promo and shorturl.at/abc12 and t.co/x",
    "\U0001F389\U0001F389 Congrats!!! \U0001F381",
    "12345",
    "salamat.at maraming salamat",
    "Ang presyo ay 1,250 pesos o 99 piso lang",
    "step 5 and top10 and p 500",
    "",
    "ÑANDU ñoño",
    "example.community is not a link but example.com is",
    "end with link gcash.com.",
    "Mixed CASE Http://Maya-Rewards.XYZ/claim",
    "Hi [NAME], text [PHONE] or <NAME> at [EMAIL] re account [ACCOUNT]",
]


def build_pipeline():
    return Pipeline([
        ("tfidf", TfidfVectorizer(
            tokenizer=tokenize, preprocessor=None, lowercase=False, token_pattern=None,
            norm="l2", use_idf=True, smooth_idf=True, min_df=1, dtype=np.float64,
        )),
        ("nb", MultinomialNB()),
    ])


def tune(x_train, y_train, x_val, y_val):
    """Fits each candidate setting on the training set; keeps the best on validation."""
    best = None
    for params in ParameterGrid(PARAM_GRID):
        model = build_pipeline().set_params(**params).fit(x_train, y_train)
        score = f1_score(y_val, model.predict(x_val), average="macro", zero_division=0)
        if best is None or score > best[0]:  # ties keep the earlier, simpler candidate
            best = (score, params, model)
    score, params, model = best
    return model, params, float(score)


def write_confusion_png(cm, path, title):
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        return False
    fig, ax = plt.subplots(figsize=(5.2, 4.4))
    ax.imshow(cm, cmap="Blues")
    ax.set_xticks(range(3), CLASSES)
    ax.set_yticks(range(3), CLASSES)
    ax.set_xlabel("Predicted")
    ax.set_ylabel("Actual")
    ax.set_title(title)
    peak = max(max(row) for row in cm) or 1
    for i in range(3):
        for j in range(3):
            ax.text(j, i, cm[i][j], ha="center", va="center",
                    color="white" if cm[i][j] > peak / 2 else "black", fontsize=13)
    fig.tight_layout()
    fig.savefig(path, dpi=200)
    plt.close(fig)
    return True


def pct(x):
    return f"{x * 100:.2f}%"


def write_summary(path, info, metrics, params, val_f1, by_source):
    cm = metrics["confusion_matrix"]
    scheme = metrics["manuscript_scheme"]
    lines = []
    if info["label_status"] in STATUS_NOTES:
        lines += [f"> **{STATUS_NOTES[info['label_status']]}**", ""]
    lines += [
        "# SMISHield model evaluation",
        "",
        f"- Dataset: `{info['source']}` (labels: {info['label_status']})",
        f"- Messages loaded: {info['messages_loaded']}; after removing duplicates: {info['messages_used']}",
        f"- Training / validation / test: {info['train_size']} / {info['val_size']} / {info['test_size']} "
        f"(70:10:20, stratified by label, seed {info['seed']})",
        "- Class counts (all / training / validation / test): "
        + "; ".join(f"{c}: {info['class_counts'][c]} / {info['train_counts'][c]} / "
                    f"{info['val_counts'][c]} / {info['test_counts'][c]}" for c in CLASSES),
        f"- Settings chosen on the validation set (macro F1 {val_f1:.4f}): n-grams "
        f"{tuple(params['tfidf__ngram_range'])}, sublinear TF {params['tfidf__sublinear_tf']}, "
        f"alpha {params['nb__alpha']}, learned class priors {params['nb__fit_prior']}",
    ]
    small = [c for c in CLASSES if info["test_counts"][c] < 30]
    if small:
        lines.append(f"- **Caution:** fewer than 30 test messages for {', '.join(small)}; "
                     "per-class figures for these are unstable.")
    lines += [
        "",
        "## Confusion matrix (test set)",
        "",
        "| Actual \\ Predicted | Safe | Suspicious | High Risk |",
        "|---|---|---|---|",
    ]
    for i, label in enumerate(CLASSES):
        lines.append(f"| **{label}** | {cm[i][0]} | {cm[i][1]} | {cm[i][2]} |")
    lines += [
        "",
        f"**Accuracy: {pct(metrics['accuracy'])}** (target: 85%)",
        "",
        "## Per-class metrics",
        "",
        "| Class | Precision | Recall | F1-score | Support |",
        "|---|---|---|---|---|",
    ]
    for label in CLASSES:
        m = metrics["per_class"][label]
        lines.append(f"| {label} | {pct(m['precision'])} | {pct(m['recall'])} | {pct(m['f1'])} | {m['support']} |")
    for key, name in (("macro_avg", "Macro average"), ("weighted_avg", "Weighted average")):
        m = metrics[key]
        lines.append(f"| {name} | {pct(m['precision'])} | {pct(m['recall'])} | {pct(m['f1'])} | |")
    lines += [
        "",
        "## Figure 19 scheme (research plan)",
        "",
        "Safe→Safe = TN; correct Suspicious/High Risk = TP; predicted risk higher than actual = FP;",
        "predicted risk lower than actual = FN.",
        "",
        f"TP = {scheme['TP']}, TN = {scheme['TN']}, FP = {scheme['FP']}, FN = {scheme['FN']}",
        "",
        "| Accuracy | Precision | Recall | F1-score |",
        "|---|---|---|---|",
        f"| {pct(scheme['accuracy'])} | {pct(scheme['precision'])} | {pct(scheme['recall'])} | {pct(scheme['f1'])} |",
        "",
    ]
    if by_source:
        lines += [
            "## Test results by data source",
            "",
            "| Source | Messages | Accuracy | Macro F1 |",
            "|---|---|---|---|",
            *[f"| {s} | {r['n']} | {pct(r['accuracy'])} | {r['macro_f1']:.4f} |" for s, r in by_source.items()],
            "",
        ]
    path.write_text("\n".join(lines), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--data", required=True, help="CSV or XLSX file with message and label columns")
    parser.add_argument("--text-col", help="name of the message column (auto-detected if omitted)")
    parser.add_argument("--label-col", help="name of the label column (auto-detected if omitted)")
    parser.add_argument("--val-size", type=float, default=0.1, help="share of all messages used for validation")
    parser.add_argument("--test-size", type=float, default=0.2, help="share of all messages used for testing")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--near-dup-threshold", type=float, default=0.9,
                        help="Jaccard similarity at which messages count as near-duplicates (0 disables)")
    parser.add_argument("--no-tune", action="store_true", help="skip validation tuning, use default settings")
    parser.add_argument("--label-status", choices=["placeholder", "provisional", "final"],
                        help="what the labels are (default: placeholder if the file name says so, "
                             "provisional for a provisional_* label column, otherwise final)")
    parser.add_argument("--model-out", type=Path, default=DEFAULT_MODEL_OUT)
    parser.add_argument("--parity-out", type=Path, default=DEFAULT_PARITY_OUT)
    parser.add_argument("--reports-dir", type=Path, default=DEFAULT_REPORTS)
    args = parser.parse_args()

    data_path = Path(args.data)
    status = args.label_status or (
        "placeholder" if "placeholder" in data_path.name.lower()
        else "provisional" if (args.label_col or "").lower().startswith("provisional")
        else "final"
    )

    print(f"Loading {data_path} ...")
    raw = load_dataset(data_path, args.text_col, args.label_col)
    clean, dropped = deduplicate(raw, args.near_dup_threshold)
    print(f"  {len(raw)} messages loaded, {len(dropped)} dropped as duplicates, {len(clean)} used")

    rest, test = train_test_split(clean, test_size=args.test_size,
                                  stratify=clean["label"], random_state=args.seed)
    train, val = train_test_split(rest, test_size=args.val_size / (1 - args.test_size),
                                  stratify=rest["label"], random_state=args.seed)
    x_train, y_train = train["message"], train["label"]
    x_test, y_test = test["message"], test["label"]

    print("Training TF-IDF + Multinomial Naive Bayes ...")
    if args.no_tune:
        params = DEFAULT_PARAMS
        model = build_pipeline().set_params(**params).fit(x_train, y_train)
        val_f1 = float(f1_score(val["label"], model.predict(val["message"]), average="macro", zero_division=0))
    else:
        model, params, val_f1 = tune(x_train, y_train, val["message"], val["label"])
    print(f"  settings: {params} (validation macro F1 {val_f1:.4f})")

    y_pred = model.predict(x_test)
    metrics = evaluate(list(y_test), list(y_pred))
    print(f"  test accuracy: {pct(metrics['accuracy'])}, macro F1: {metrics['macro_avg']['f1']:.4f}")

    by_source = {}
    if test["source"].nunique() > 1:
        for source, part in test.assign(predicted=y_pred).groupby("source"):
            by_source[source] = {
                "n": len(part),
                "accuracy": float(accuracy_score(part["label"], part["predicted"])),
                "macro_f1": float(f1_score(part["label"], part["predicted"], labels=list(CLASSES),
                                           average="macro", zero_division=0)),
            }

    counts = lambda s: {c: int((s == c).sum()) for c in CLASSES}  # noqa: E731
    info = {
        "source": data_path.name,
        "label_status": status,
        "seed": args.seed,
        "messages_loaded": len(raw),
        "messages_used": len(clean),
        "train_size": len(train),
        "val_size": len(val),
        "test_size": len(test),
        "class_counts": counts(clean["label"]),
        "train_counts": counts(y_train),
        "val_counts": counts(val["label"]),
        "test_counts": counts(y_test),
    }
    evaluation = {
        "accuracy": metrics["accuracy"],
        "macro_f1": metrics["macro_avg"]["f1"],
        "weighted_f1": metrics["weighted_avg"]["f1"],
        "validation_macro_f1": val_f1,
    }

    args.model_out.parent.mkdir(parents=True, exist_ok=True)
    exported = ExportedModel(export_model(model, info, evaluation, args.model_out))
    size_kb = args.model_out.stat().st_size / 1024
    print(f"Exported model -> {args.model_out} ({len(exported.index)} terms, {size_kb:.0f} KB)")

    # The exported JSON must reproduce scikit-learn's probabilities.
    sk_proba = model.predict_proba(x_test)
    sk_order = [list(model.classes_).index(c) for c in CLASSES]
    worst = max(
        abs(a - b)
        for text, row in zip(x_test, sk_proba)
        for a, b in zip(exported.predict_proba(text), row[sk_order])
    )
    if worst > 1e-6:
        sys.exit(f"Exported model differs from scikit-learn by {worst:.2e}")
    print(f"  export check vs scikit-learn: max difference {worst:.1e}")

    parity_texts = PARITY_EDGE_CASES + list(x_test.iloc[:40])
    parity = {
        "preprocessing_version": PREPROCESSING_VERSION,
        "model_created_at": exported.data["created_at"],
        "cases": [
            {"text": text, "tokens": tokenize(text),
             "probabilities": exported.predict_proba(text)}
            for text in parity_texts
        ],
    }
    args.parity_out.parent.mkdir(parents=True, exist_ok=True)
    args.parity_out.write_text(json.dumps(parity, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"Wrote Dart parity fixture -> {args.parity_out}")

    reports = args.reports_dir
    reports.mkdir(parents=True, exist_ok=True)
    (reports / "metrics.json").write_text(json.dumps(
        {"dataset": info, "settings": {k: list(v) if isinstance(v, tuple) else v for k, v in params.items()},
         "validation_macro_f1": val_f1, "test": metrics, "test_by_source": by_source}, indent=2),
        encoding="utf-8")
    pd.DataFrame(metrics["confusion_matrix"], index=[f"actual {c}" for c in CLASSES],
                 columns=[f"predicted {c}" for c in CLASSES]).to_csv(reports / "confusion_matrix.csv")
    title = "SMISHield confusion matrix" + ("" if status == "final" else f" ({status.upper()} LABELS)")
    write_confusion_png(metrics["confusion_matrix"], reports / "confusion_matrix.png", title)

    proba = pd.DataFrame(sk_proba[:, sk_order], columns=[f"p_{c}" for c in CLASSES])
    predictions = pd.DataFrame({"message": list(x_test), "source": list(test["source"]),
                                "actual": list(y_test), "predicted": list(y_pred)})
    predictions["correct"] = predictions["actual"] == predictions["predicted"]
    pd.concat([predictions, proba.round(4)], axis=1).to_csv(reports / "test_predictions.csv", index=False, encoding="utf-8-sig")
    split = pd.concat([train.assign(split="train"), val.assign(split="validation"), test.assign(split="test")])
    split.to_csv(reports / "train_val_test_split.csv", index=False, encoding="utf-8-sig")
    dropped.to_csv(reports / "dropped_duplicates.csv", index=False, encoding="utf-8-sig")
    write_summary(reports / "summary.md", info, metrics, params, val_f1, by_source)
    print(f"Reports -> {reports}")
    if status in STATUS_NOTES:
        print(f"\nNOTE: {STATUS_NOTES[status]}")


if __name__ == "__main__":
    main()

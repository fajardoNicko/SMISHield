"""Train, evaluate and export the SMISHield classifier.

Run from the repository root:

    python ml/train.py --data path/to/dataset.csv

What it does:
  1. Loads the labelled dataset (CSV or XLSX; Safe / Suspicious / High Risk).
  2. Drops duplicate and near-duplicate messages (listed in the reports).
  3. Splits 80:20 with stratification (fixed seed, so results are repeatable).
  4. Tunes TF-IDF / Multinomial Naive Bayes settings with 5-fold
     cross-validation on the training set only.
  5. Evaluates on the held-out 20% and writes the Chapter 4 reports
     (confusion matrix, accuracy, precision, recall, F1) to ml/reports/.
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
from sklearn.model_selection import GridSearchCV, StratifiedKFold, train_test_split
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

DEFAULT_PARAMS = {"tfidf__ngram_range": (1, 2), "tfidf__sublinear_tf": True, "nb__alpha": 0.1}
PARAM_GRID = {
    "tfidf__ngram_range": [(1, 1), (1, 2)],
    "tfidf__sublinear_tf": [False, True],
    "nb__alpha": [0.01, 0.05, 0.1, 0.25, 0.5, 1.0],
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
]


def build_pipeline():
    return Pipeline([
        ("tfidf", TfidfVectorizer(
            tokenizer=tokenize, preprocessor=None, lowercase=False, token_pattern=None,
            norm="l2", use_idf=True, smooth_idf=True, min_df=1, dtype=np.float64,
        )),
        ("nb", MultinomialNB()),
    ])


def tune(pipeline, x_train, y_train, seed):
    smallest_class = int(pd.Series(y_train).value_counts().min())
    folds = min(5, smallest_class)
    if folds < 2:
        print("  Too few messages per class for cross-validation; using default settings.")
        pipeline.set_params(**DEFAULT_PARAMS)
        return pipeline.fit(x_train, y_train), DEFAULT_PARAMS, None
    search = GridSearchCV(
        pipeline, PARAM_GRID, scoring="f1_macro",
        cv=StratifiedKFold(n_splits=folds, shuffle=True, random_state=seed),
    )
    search.fit(x_train, y_train)
    return search.best_estimator_, search.best_params_, {"folds": folds, "macro_f1": float(search.best_score_)}


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


def write_summary(path, info, metrics, params, cv, placeholder):
    cm = metrics["confusion_matrix"]
    scheme = metrics["manuscript_scheme"]
    lines = []
    if placeholder:
        lines += [
            "> **PLACEHOLDER DATA.** These numbers come from the made-up placeholder dataset",
            "> and must not be reported as study results. Retrain with the collected dataset.",
            "",
        ]
    lines += [
        "# SMISHield model evaluation",
        "",
        f"- Dataset: `{info['source']}`",
        f"- Messages loaded: {info['messages_loaded']}; after removing duplicates: {info['messages_used']}",
        f"- Train / test split: {info['train_size']} / {info['test_size']} (stratified, seed {info['seed']})",
        f"- Class counts (all / train / test): "
        + "; ".join(f"{c}: {info['class_counts'][c]} / {info['train_counts'][c]} / {info['test_counts'][c]}" for c in CLASSES),
        f"- Settings: n-grams {tuple(params['tfidf__ngram_range'])}, sublinear TF {params['tfidf__sublinear_tf']}, "
        f"alpha {params['nb__alpha']}",
    ]
    if cv:
        lines.append(f"- Cross-validation on training set: {cv['folds']} folds, macro F1 {cv['macro_f1']:.4f}")
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
    path.write_text("\n".join(lines), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--data", required=True, help="CSV or XLSX file with message and label columns")
    parser.add_argument("--text-col", help="name of the message column (auto-detected if omitted)")
    parser.add_argument("--label-col", help="name of the label column (auto-detected if omitted)")
    parser.add_argument("--test-size", type=float, default=0.2)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--near-dup-threshold", type=float, default=0.9,
                        help="Jaccard similarity at which messages count as near-duplicates (0 disables)")
    parser.add_argument("--no-tune", action="store_true", help="skip cross-validated tuning, use defaults")
    parser.add_argument("--placeholder", action="store_true",
                        help="mark the model as trained on placeholder data (automatic if the file name contains 'placeholder')")
    parser.add_argument("--model-out", type=Path, default=DEFAULT_MODEL_OUT)
    parser.add_argument("--parity-out", type=Path, default=DEFAULT_PARITY_OUT)
    parser.add_argument("--reports-dir", type=Path, default=DEFAULT_REPORTS)
    args = parser.parse_args()

    data_path = Path(args.data)
    placeholder = args.placeholder or "placeholder" in data_path.name.lower()

    print(f"Loading {data_path} ...")
    raw = load_dataset(data_path, args.text_col, args.label_col)
    clean, dropped = deduplicate(raw, args.near_dup_threshold)
    print(f"  {len(raw)} messages loaded, {len(dropped)} dropped as duplicates, {len(clean)} used")

    x_train, x_test, y_train, y_test = train_test_split(
        clean["message"], clean["label"], test_size=args.test_size,
        stratify=clean["label"], random_state=args.seed,
    )

    print("Training TF-IDF + Multinomial Naive Bayes ...")
    pipeline = build_pipeline()
    if args.no_tune:
        pipeline.set_params(**DEFAULT_PARAMS)
        model, params, cv = pipeline.fit(x_train, y_train), DEFAULT_PARAMS, None
    else:
        model, params, cv = tune(pipeline, x_train, y_train, args.seed)
    print(f"  settings: {params}")

    y_pred = model.predict(x_test)
    metrics = evaluate(list(y_test), list(y_pred))
    print(f"  test accuracy: {pct(metrics['accuracy'])}, macro F1: {metrics['macro_avg']['f1']:.4f}")

    counts = lambda s: {c: int((s == c).sum()) for c in CLASSES}  # noqa: E731
    info = {
        "source": data_path.name,
        "is_placeholder": placeholder,
        "seed": args.seed,
        "messages_loaded": len(raw),
        "messages_used": len(clean),
        "train_size": len(x_train),
        "test_size": len(x_test),
        "class_counts": counts(clean["label"]),
        "train_counts": counts(y_train),
        "test_counts": counts(y_test),
    }
    evaluation = {
        "accuracy": metrics["accuracy"],
        "macro_f1": metrics["macro_avg"]["f1"],
        "weighted_f1": metrics["weighted_avg"]["f1"],
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

    parity_texts = PARITY_EDGE_CASES + list(x_test[:40])
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
         "cross_validation": cv, "test": metrics}, indent=2), encoding="utf-8")
    pd.DataFrame(metrics["confusion_matrix"], index=[f"actual {c}" for c in CLASSES],
                 columns=[f"predicted {c}" for c in CLASSES]).to_csv(reports / "confusion_matrix.csv")
    title = "SMISHield confusion matrix" + (" (PLACEHOLDER DATA)" if placeholder else "")
    write_confusion_png(metrics["confusion_matrix"], reports / "confusion_matrix.png", title)

    proba = pd.DataFrame(sk_proba[:, sk_order], columns=[f"p_{c}" for c in CLASSES])
    predictions = pd.DataFrame({"message": list(x_test), "actual": list(y_test), "predicted": list(y_pred)})
    predictions["correct"] = predictions["actual"] == predictions["predicted"]
    pd.concat([predictions, proba.round(4)], axis=1).to_csv(reports / "test_predictions.csv", index=False, encoding="utf-8-sig")
    split = pd.concat([
        pd.DataFrame({"message": x_train, "label": y_train, "split": "train"}),
        pd.DataFrame({"message": x_test, "label": y_test, "split": "test"}),
    ])
    split.to_csv(reports / "train_test_split.csv", index=False, encoding="utf-8-sig")
    dropped.to_csv(reports / "dropped_duplicates.csv", index=False, encoding="utf-8-sig")
    write_summary(reports / "summary.md", info, metrics, params, cv, placeholder)
    print(f"Reports -> {reports}")
    if placeholder:
        print("\nNOTE: trained on PLACEHOLDER data. Do not report these numbers as results.")


if __name__ == "__main__":
    main()

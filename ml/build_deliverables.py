"""Combined dataset workbook and Chapter 4 results, classified by the app itself.

Run from the repository root after ml/train.py:

    python ml/build_deliverables.py --sources ml/data/labeled/interim_labeled.csv \\
        ml/data/private/vcsms_labeled.csv ml/data/private/synthetic_labeled.csv \\
        ml/data/private/synthetic_threats.csv

1. Data/SMISHield_all_datasets.xlsx: every message from every source with its
   label, where it went (training, validation, test, training only, or not
   used) and, on a second sheet, the messages still waiting for adjudication.
2. System testing: the test set is classified with the app's own analyzer
   (app/tool/evaluate.dart, the code and model the APK runs).
3. Data/results/SMISHield_results.xlsx and confusion_matrix.png: confusion
   matrix, accuracy, per-class precision/recall/F1, the research plan's
   Figure 19 scheme, results per source, every test prediction and the errors.

The outputs contain VCSMS submissions, so they stay in the gitignored Data/.
"""

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

import pandas as pd
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

from smishield_ml import CLASSES
from smishield_ml.annotation import read_sheet
from smishield_ml.metrics import evaluate
from train import STATUS_NOTES, write_confusion_png

REPO = Path(__file__).resolve().parent.parent
HEADER_FILL = PatternFill("solid", fgColor="1F3A68")
SPLIT_NAMES = {"train": "training", "validation": "validation", "test": "test",
               "train (training only)": "training only (synthetic)"}


def key(source, message):
    return (str(source), str(message).strip())


def load_sources(paths):
    rows = []
    for path in paths:
        df = pd.read_csv(path, keep_default_na=False)
        for col in ("id", "criteria", "label_origin", "annotator"):
            if col not in df.columns:
                df[col] = ""
        if "source" not in df.columns or (df["source"] == "").all():
            df["source"] = Path(path).stem
        rows.append(df[["id", "source", "message", "criteria", "label_origin", "annotator"]])
    info = pd.concat(rows, ignore_index=True)
    return {key(s, m): r for s, m, r in zip(info["source"], info["message"], info.to_dict("records"))}


def style(ws, widths):
    for cell in ws[1]:
        cell.font = Font(bold=True, color="FFFFFF")
        cell.fill = HEADER_FILL
        cell.alignment = Alignment(wrap_text=True, vertical="center")
    for i, width in enumerate(widths, start=1):
        ws.column_dimensions[get_column_letter(i)].width = width
    ws.freeze_panes = "A2"


def write_sheet(writer, name, df, widths=None):
    df.to_excel(writer, sheet_name=name, index=False)
    ws = writer.sheets[name]
    style(ws, widths or [max(10, min(60, len(str(c)) + 4)) for c in df.columns])
    if "message" in df.columns:
        col = get_column_letter(list(df.columns).index("message") + 1)
        ws.column_dimensions[col].width = 80
        for cell in ws[col][1:]:
            cell.alignment = Alignment(wrap_text=True, vertical="top")


def all_datasets(split, dropped, lookup, adjudication):
    split = split.assign(used_for=split["split"].map(SPLIT_NAMES))
    dropped = dropped.assign(used_for="not used: " + dropped["reason"].astype(str))
    rows = pd.concat([split, dropped], ignore_index=True)
    extra = [lookup.get(key(s, m), {}) for s, m in zip(rows["source"], rows["message"])]
    for col in ("id", "criteria", "label_origin", "annotator"):
        rows[col] = [e.get(col, "") for e in extra]
    rows = rows[["id", "source", "message", "label", "criteria", "label_origin", "annotator", "used_for"]]
    order = {"training": 0, "validation": 1, "test": 2, "training only (synthetic)": 3}
    rows = rows.assign(_o=rows["used_for"].map(order).fillna(9)).sort_values(["_o", "source", "id"]).drop(columns="_o")
    waiting = pd.DataFrame()
    if adjudication is not None and len(adjudication):
        waiting = adjudication[adjudication["final_label"].isna()][
            ["id", "set", "message", "label_R1", "label_R2", "criteria_R1", "criteria_R2"]]
    return rows, waiting


def run_app(test, out_dir):
    dart = shutil.which("dart")
    if dart is None:
        raise SystemExit("dart is not on PATH (it comes with Flutter).")
    test_json, pred_json = out_dir / "test_set.json", out_dir / "app_predictions.json"
    test_json.write_text(json.dumps(test[["id", "message", "label"]].to_dict("records"), ensure_ascii=False),
                         encoding="utf-8")
    subprocess.run([dart, "run", "tool/evaluate.dart", str(test_json.resolve()), str(pred_json.resolve())],
                   cwd=REPO / "app", check=True)
    return json.loads(pred_json.read_text(encoding="utf-8"))


def metric_tables(metrics):
    cm = pd.DataFrame(metrics["confusion_matrix"], index=[f"Actual {c}" for c in CLASSES],
                      columns=[f"Predicted {c}" for c in CLASSES])
    cm["Total"] = cm.sum(axis=1)
    cm.loc["Total"] = cm.sum(axis=0)
    per_class = pd.DataFrame([
        {"Class": c, **{k: round(metrics["per_class"][c][k] * 100, 2) for k in ("precision", "recall", "f1")},
         "Support": metrics["per_class"][c]["support"]} for c in CLASSES
    ] + [
        {"Class": name, **{k: round(metrics[avg][k] * 100, 2) for k in ("precision", "recall", "f1")}, "Support": ""}
        for avg, name in (("macro_avg", "Macro average"), ("weighted_avg", "Weighted average"))
    ]).rename(columns={"precision": "Precision (%)", "recall": "Recall (%)", "f1": "F1-score (%)"})
    s = metrics["manuscript_scheme"]
    scheme = pd.DataFrame([
        ("TP (correct Suspicious or High Risk)", s["TP"]),
        ("TN (Safe predicted as Safe)", s["TN"]),
        ("FP (predicted a higher risk than the actual)", s["FP"]),
        ("FN (predicted a lower risk than the actual)", s["FN"]),
        ("Accuracy (%)", round(s["accuracy"] * 100, 2)),
        ("Precision (%)", round(s["precision"] * 100, 2)),
        ("Recall (%)", round(s["recall"] * 100, 2)),
        ("F1-score (%)", round(s["f1"] * 100, 2)),
    ], columns=["Figure 19 scheme", "Value"])
    return cm, per_class, scheme


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sources", nargs="+", required=True, type=Path,
                        help="the CSV files given to train.py (--data and --train-only)")
    parser.add_argument("--reports", type=Path, default=REPO / "ml" / "reports")
    parser.add_argument("--adjudication", type=Path, default=REPO / "ml" / "annotation" / "adjudication.xlsx")
    parser.add_argument("--datasets-out", type=Path, default=REPO / "Data" / "SMISHield_all_datasets.xlsx")
    parser.add_argument("--out-dir", type=Path, default=REPO / "Data" / "results")
    args = parser.parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)

    split = pd.read_csv(args.reports / "train_val_test_split.csv", keep_default_na=False)
    dropped = pd.read_csv(args.reports / "dropped_duplicates.csv", keep_default_na=False)
    model_info = json.loads((REPO / "app" / "assets" / "model" / "smishield_model.json").read_text(encoding="utf-8"))
    dataset = model_info["dataset"]
    status = dataset["label_status"]
    lookup = load_sources(args.sources)
    adjudication = read_sheet(args.adjudication) if args.adjudication.exists() else None

    # 1. Every dataset in one workbook.
    rows, waiting = all_datasets(split, dropped, lookup, adjudication)
    composition = (rows.assign(n=1).pivot_table(index=["used_for", "source"], columns="label", values="n",
                                                aggfunc="sum", fill_value=0)
                   .reindex(columns=list(CLASSES), fill_value=0))
    composition["Total"] = composition.sum(axis=1)
    composition = composition.reset_index()
    with pd.ExcelWriter(args.datasets_out, engine="openpyxl") as writer:
        write_sheet(writer, "All messages", rows, [11, 14, 80, 11, 14, 30, 11, 34])
        write_sheet(writer, "Counts", composition)
        if len(waiting):
            write_sheet(writer, "Waiting for adjudication", waiting, [11, 16, 80, 12, 12, 14, 14])
    print(f"{len(rows)} messages -> {args.datasets_out}")

    # 2. Classify the test set with the app's analyzer.
    test = rows[rows["used_for"] == "test"].copy()
    test["id"] = [i or f"row-{n}" for n, i in enumerate(test["id"])]
    app = run_app(test, args.out_dir)
    predictions = pd.DataFrame(app["predictions"])
    test = test.merge(predictions.drop(columns="label"), on="id")
    unclassified = test[test["predicted"].isna()]
    scored = test[test["predicted"].notna()]

    python_pred = pd.read_csv(args.reports / "test_predictions.csv", keep_default_na=False)
    same = scored.merge(python_pred[["message", "predicted"]], on="message", suffixes=("", "_python"))
    agreement = float((same["predicted"] == same["predicted_python"]).mean()) if len(same) else float("nan")

    # 3. Results.
    metrics = evaluate(list(scored["label"]), list(scored["predicted"]))
    cm, per_class, scheme = metric_tables(metrics)
    by_source = []
    for source, part in scored.groupby("source"):
        m = evaluate(list(part["label"]), list(part["predicted"]))
        by_source.append({"Source": source, "Test messages": len(part), "Accuracy (%)": round(m["accuracy"] * 100, 2),
                          "Macro F1 (%)": round(m["macro_avg"]["f1"] * 100, 2),
                          **{f"{c} recall (%)": round(m["per_class"][c]["recall"] * 100, 2) for c in CLASSES}})
    preds = scored.assign(correct=scored["label"] == scored["predicted"],
                          confidence=[round(r[f"p_{r['predicted']}"] * 100, 1) for _, r in scored.iterrows()])
    preds = preds[["id", "source", "message", "label", "predicted", "confidence", "correct", "warning_signs"]]
    preds["warning_signs"] = preds["warning_signs"].map(lambda v: ", ".join(v) if isinstance(v, list) else "")
    preds = preds.rename(columns={"label": "actual", "predicted": "app prediction", "confidence": "confidence (%)"})

    summary = pd.DataFrame([
        ("Label status", status.upper() + (f" - {STATUS_NOTES[status]}" if status in STATUS_NOTES else "")),
        ("Model", "TF-IDF + Multinomial Naive Bayes, run by the app's on-device analyzer"),
        ("Model trained", model_info.get("created_at", "")),
        ("Settings (chosen on validation)", json.dumps(model_info.get("vectorizer", {})) + " " +
         json.dumps(model_info.get("classifier", {}))),
        ("Real messages (after removing duplicates)", dataset["messages_used"]),
        ("Training / validation / test (real, 70:10:20)",
         f"{dataset['train_size']} / {dataset['val_size']} / {dataset['test_size']}"),
        ("Synthetic messages (training only)", dataset.get("train_only_size", 0)),
        ("Test messages classified by the app", f"{len(scored)} of {len(test)}"
         + (f" ({len(unclassified)} could not be classified)" if len(unclassified) else "")),
        ("Same label as the Python model", f"{agreement:.2%}"),
        ("Accuracy (%)", round(metrics["accuracy"] * 100, 2)),
        ("Target accuracy (%)", 85),
        ("Macro precision / recall / F1 (%)", " / ".join(str(round(metrics["macro_avg"][k] * 100, 2))
                                                         for k in ("precision", "recall", "f1"))),
        ("App time for the whole test set (ms)", app.get("milliseconds_total", "")),
    ], columns=["Item", "Value"])

    results_path = args.out_dir / "SMISHield_results.xlsx"
    with pd.ExcelWriter(results_path, engine="openpyxl") as writer:
        write_sheet(writer, "Summary", summary, [46, 110])
        cm.reset_index(names="").to_excel(writer, sheet_name="Confusion matrix", index=False)
        style(writer.sheets["Confusion matrix"], [20, 20, 22, 20, 10])
        write_sheet(writer, "Per-class metrics", per_class, [20, 15, 15, 15, 10])
        write_sheet(writer, "Figure 19 scheme", scheme, [48, 12])
        write_sheet(writer, "By source", pd.DataFrame(by_source))
        write_sheet(writer, "Test predictions", preds, [11, 14, 80, 11, 15, 14, 9, 40])
        write_sheet(writer, "Errors", preds[~preds["correct"]], [11, 14, 80, 11, 15, 14, 9, 40])
        if len(unclassified):
            write_sheet(writer, "Not classified", unclassified[["id", "source", "message", "label", "error"]])
    title = "SMISHield confusion matrix (app)" + ("" if status == "final" else f" - {status.upper()} LABELS")
    write_confusion_png(metrics["confusion_matrix"], args.out_dir / "confusion_matrix.png", title)

    print(f"App classified {len(scored)}/{len(test)} test messages; same label as Python for {agreement:.2%}")
    print(f"Accuracy {metrics['accuracy']:.2%}, macro F1 {metrics['macro_avg']['f1']:.4f}")
    print(f"Results -> {results_path} and {args.out_dir / 'confusion_matrix.png'}")
    if status in STATUS_NOTES:
        print(f"NOTE: {STATUS_NOTES[status]}")


if __name__ == "__main__":
    sys.exit(main())

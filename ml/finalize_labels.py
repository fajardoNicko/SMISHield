"""Check inter-annotator agreement and build the final labelled dataset.

Run from the repository root once the annotation workbooks are filled in:

    python ml/finalize_labels.py

1. Compares ml/annotation/agreement_R1.xlsx and agreement_R2.xlsx (the same
   messages, labelled independently by two researchers) and writes
   ml/annotation/agreement_report.md: percent agreement, Cohen's kappa, and
   linearly weighted kappa (the labels are ordered Safe < Suspicious <
   High Risk), interpreted with the Landis & Koch (1977) bands.
2. Writes ml/annotation/adjudication.xlsx listing every message the two
   researchers labelled differently. A third researcher fills final_label.
3. When the adjudication and ml/annotation/main_annotation.xlsx are complete,
   writes the dataset used for training to ml/data/labeled/public_sms_labeled.csv.

Run it again after each step; it reports what is still missing.

Options:
  --r1 / --r2   read the two agreement workbooks from another folder, e.g.
                --r1 "Data/20%/agreement_sort(1).xlsx" --r2 "Data/20%/saiah-and-nina.xlsx"
  --interim     before the main annotation is done, write only the agreement
                sample's settled messages (both researchers agreed, or already
                adjudicated) to ml/data/labeled/interim_agreement_sample.csv
"""

import argparse
import re
from pathlib import Path

import pandas as pd
from sklearn.metrics import cohen_kappa_score

from smishield_ml import CLASSES
from smishield_ml.annotation import has_labels, read_sheet, write_sheet

ML = Path(__file__).resolve().parent
LABELS_ALLOWED = (*CLASSES, "Exclude")

# Landis & Koch (1977): upper limit of each band; below 0 is "poor".
BANDS = [(0.20, "slight"), (0.40, "fair"), (0.60, "moderate"),
         (0.80, "substantial"), (1.00, "almost perfect")]


def band(kappa):
    if kappa < 0:
        return "poor"
    return next((name for limit, name in BANDS if kappa <= limit), "almost perfect")


def criteria_mismatches(sheet):
    """Rows whose label is not backed by matching criterion codes (guide, section 3)."""
    found = []
    for r in sheet.itertuples():
        criteria = "" if pd.isna(r.criteria) else str(r.criteria)
        kinds = {code[0] for code in re.findall(r"[HSF][1-6]", criteria.upper())}
        if r.label == "High Risk" and "H" not in kinds:
            problem = "High Risk without an H code"
        elif r.label == "Suspicious" and "H" in kinds:
            problem = "Suspicious with an H code (High Risk?)"
        elif r.label == "Suspicious" and "S" not in kinds:
            problem = "Suspicious without an S code"
        elif r.label == "Safe" and kinds & {"H", "S"}:
            problem = "Safe with an H or S code"
        else:
            continue
        found.append((r.id, r.label, criteria or "(blank)", problem))
    return found


def agreement_report(pairs, names, mismatches):
    """pairs: DataFrame with columns label_R1, label_R2 (all filled)."""
    both = pairs[pairs["label_R1"].isin(CLASSES) & pairs["label_R2"].isin(CLASSES)]
    raw = float((pairs["label_R1"] == pairs["label_R2"]).mean())
    kappa = cohen_kappa_score(both["label_R1"], both["label_R2"], labels=list(CLASSES))
    weighted = cohen_kappa_score(both["label_R1"], both["label_R2"], labels=list(CLASSES), weights="linear")
    table = pd.crosstab(pairs["label_R1"], pairs["label_R2"], rownames=["R1"], colnames=["R2"])
    order = [c for c in LABELS_ALLOWED if c in table.index.union(table.columns)]
    table = table.reindex(index=order, columns=order, fill_value=0)
    lines = [
        "# Inter-annotator agreement",
        "",
        f"- R1: `{names[0]}`; R2: `{names[1]}`",
        f"- Messages labelled by both researchers: {len(pairs)}",
        f"- Percent agreement (including Exclude): {raw:.1%}",
        f"- Messages both placed in Safe/Suspicious/High Risk: {len(both)}",
        f"- Cohen's kappa: **{kappa:.3f}** ({band(kappa)})",
        f"- Linearly weighted kappa: **{weighted:.3f}** ({band(weighted)})",
        "",
        "Interpretation follows Landis & Koch (1977): 0.41-0.60 moderate, 0.61-0.80 substantial,",
        "0.81-1.00 almost perfect. The labelling guide's target is at least 0.61; if it is lower,",
        "revise the guide where the researchers disagreed and label a fresh sample.",
        "",
        "## R1 (rows) vs R2 (columns)",
        "",
        "| R1 \\ R2 | " + " | ".join(table.columns) + " |",
        "|---|" + "---|" * len(table.columns),
    ]
    for label, row in table.iterrows():
        lines.append(f"| **{label}** | " + " | ".join(str(v) for v in row) + " |")
    lines += ["", "## Label and criteria consistency", "",
              "Labels whose criterion codes do not match the guide's decision rules. "
              "Worth correcting before adjudication.", ""]
    for who, rows in zip(("R1", "R2"), mismatches):
        lines.append(f"**{who}: {len(rows)}**" + ("" if rows else " (none)"))
        lines += ["", "| id | label | criteria | problem |", "|---|---|---|---|"] if rows else []
        lines += [f"| {i} | {label} | {crit} | {problem} |" for i, label, crit, problem in rows]
        lines.append("")
    return "\n".join(lines) + "\n", kappa, weighted


def write_dataset(labeled, prepared_path, out):
    """Joins labels (id, label, label_origin) to the prepared messages and saves them."""
    prepared = pd.read_csv(prepared_path, keep_default_na=False)
    dataset = prepared[["id", "source", "source_category", "message"]].merge(labeled, on="id")
    kept = dataset[dataset["label"] != "Exclude"]
    out.parent.mkdir(parents=True, exist_ok=True)
    kept.to_csv(out, index=False, encoding="utf-8-sig")
    print(f"\n{len(kept)} labelled messages ({len(dataset) - len(kept)} excluded) -> {out}")
    print(kept["label"].value_counts().to_string())
    resolved = out.resolve()
    shown = resolved.relative_to(ML.parent) if resolved.is_relative_to(ML.parent) else resolved
    return shown


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--annotation-dir", type=Path, default=ML / "annotation")
    parser.add_argument("--prepared", type=Path, default=ML / "data" / "prepared" / "public_sms_prepared.csv")
    parser.add_argument("--out", type=Path, default=ML / "data" / "labeled" / "public_sms_labeled.csv")
    parser.add_argument("--r1", type=Path, help="R1's workbook (default: <annotation-dir>/agreement_R1.xlsx)")
    parser.add_argument("--r2", type=Path, help="R2's workbook (default: <annotation-dir>/agreement_R2.xlsx)")
    parser.add_argument("--interim", action="store_true",
                        help="before the main annotation is done, write the agreement sample's messages "
                             "that both researchers labelled the same (plus any already adjudicated)")
    parser.add_argument("--interim-out", type=Path,
                        default=ML / "data" / "labeled" / "interim_agreement_sample.csv")
    args = parser.parse_args()
    adir = args.annotation_dir
    r1_path = args.r1 or adir / "agreement_R1.xlsx"
    r2_path = args.r2 or adir / "agreement_R2.xlsx"

    r1, r2 = read_sheet(r1_path), read_sheet(r2_path)
    if set(r1["id"]) != set(r2["id"]):
        raise SystemExit("The two agreement workbooks do not contain the same messages.")
    pairs = r1[["id", "sender", "message", "label", "criteria"]].merge(
        r2[["id", "label", "criteria"]], on="id", suffixes=("_R1", "_R2"))
    missing = pairs["label_R1"].isna() | pairs["label_R2"].isna()
    if missing.any():
        print(f"Agreement sample: {int(missing.sum())} of {len(pairs)} messages still need a label from R1 and/or R2.")
        return
    bad = sorted(set(pairs["label_R1"]).union(pairs["label_R2"]) - set(LABELS_ALLOWED))
    if bad:
        raise SystemExit(f"Unknown labels in the agreement workbooks: {bad}")

    mismatches = (criteria_mismatches(r1), criteria_mismatches(r2))
    report, kappa, weighted = agreement_report(pairs, (r1_path.name, r2_path.name), mismatches)
    adir.mkdir(parents=True, exist_ok=True)
    (adir / "agreement_report.md").write_text(report, encoding="utf-8")
    print(f"Cohen's kappa {kappa:.3f} ({band(kappa)}), weighted {weighted:.3f} ({band(weighted)})")
    print(f"Label/criteria mismatches: R1 {len(mismatches[0])}, R2 {len(mismatches[1])}")
    print(f"Report -> {adir / 'agreement_report.md'}")

    disagreements = pairs[pairs["label_R1"] != pairs["label_R2"]].assign(final_label=None, notes=None)
    adjudication_path = adir / "adjudication.xlsx"
    if not has_labels(adjudication_path):
        write_sheet(adjudication_path, disagreements,
                    ["id", "sender", "message", "label_R1", "label_R2", "criteria_R1", "criteria_R2",
                     "final_label", "notes"],
                    label_column="final_label", title="Adjudication")
        print(f"{len(disagreements)} disagreements -> {adjudication_path} (fill final_label)")
    adjudicated = read_sheet(adjudication_path) if len(disagreements) else pd.DataFrame(columns=["id", "final_label"])
    if len(disagreements) and set(adjudicated["id"]) != set(disagreements["id"]):
        raise SystemExit("adjudication.xlsx does not match the current disagreements; "
                         "delete it and run again to regenerate it.")
    final = {i: label for i, label in zip(adjudicated["id"], adjudicated["final_label"]) if label}
    agreed = pairs.assign(
        label=[final.get(i, a) for i, a in zip(pairs["id"], pairs["label_R1"])],
        label_origin=["adjudicated" if i in final else "agreed by two researchers" for i in pairs["id"]],
    )
    settled = agreed[(agreed["label_R1"] == agreed["label_R2"]) | agreed["id"].isin(final)]

    if args.interim:
        shown = write_dataset(settled[["id", "label", "label_origin"]], args.prepared, args.interim_out)
        print(f"({len(pairs) - len(settled)} disagreements still waiting for adjudication are left out)")
        print(f"\nNext: python ml/train.py --data {shown} --label-status interim")
        return

    if len(settled) < len(pairs):
        print(f"Adjudication: {len(pairs) - len(settled)} messages still need a final_label.")
        return
    main_sheet = read_sheet(adir / "main_annotation.xlsx")
    if main_sheet["label"].isna().any():
        print(f"Main annotation: {int(main_sheet['label'].isna().sum())} of {len(main_sheet)} messages still need a label.")
        return

    single = main_sheet.assign(label_origin="single researcher")
    labeled = pd.concat([agreed[["id", "label", "label_origin"]], single[["id", "label", "label_origin"]]])
    shown = write_dataset(labeled, args.prepared, args.out)
    print(f"\nNext: python ml/train.py --data {shown}")


if __name__ == "__main__":
    main()

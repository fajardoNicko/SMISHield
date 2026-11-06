"""Check inter-annotator agreement and build the final labelled dataset.

Run from the repository root once the annotation workbooks are filled in:

    python ml/finalize_labels.py

1. Compares ml/annotation/agreement_R1.xlsx and agreement_R2.xlsx (the same
   messages, labelled independently by two annotators) and writes
   ml/annotation/agreement_report.md: percent agreement, Cohen's kappa, and
   linearly weighted kappa (the labels are ordered Safe < Suspicious <
   High Risk), interpreted with the Landis & Koch (1977) bands. If the main
   set was also labelled twice (two --main workbooks), it is compared the
   same way.
2. Writes ml/annotation/adjudication.xlsx listing every message the two
   annotators labelled differently (or only one of them labelled). A third
   researcher fills final_label.
3. When every message is settled, writes the dataset used for training to
   ml/data/labeled/public_sms_labeled.csv.

Run it again after each step; it reports what is still missing.

Options:
  --r1 / --r2   read the two agreement workbooks from another folder, e.g.
                --r1 "Data/20%/agreement_sort(1).xlsx" --r2 "Data/20%/saiah-and-nina.xlsx"
  --main        the main set's workbook, or two workbooks when the main set was
                also labelled by both annotators (give them in the same
                annotator order as --r1/--r2)
  --interim     before everything is settled, write just the settled messages
                (agreed, adjudicated, or single-annotated) to
                ml/data/labeled/interim_labeled.csv
"""

import argparse
import re
import shutil
from pathlib import Path

import pandas as pd
from sklearn.metrics import cohen_kappa_score

from smishield_ml import CLASSES
from smishield_ml.annotation import has_labels, read_sheet, write_sheet

ML = Path(__file__).resolve().parent
LABELS_ALLOWED = (*CLASSES, "Exclude")
SAMPLE, MAIN = "agreement sample", "main set"
ADJUDICATION_COLUMNS = ["id", "set", "sender", "message", "label_R1", "label_R2",
                        "criteria_R1", "criteria_R2", "final_label", "notes"]

# Landis & Koch (1977): upper limit of each band; below 0 is "poor".
BANDS = [(0.20, "slight"), (0.40, "fair"), (0.60, "moderate"),
         (0.80, "substantial"), (1.00, "almost perfect")]


def band(kappa):
    if pd.isna(kappa):
        return "not enough labels yet"
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


def check_sheet(path, sheet, prepared):
    """Problems in one workbook: unknown ids or labels (fatal), edited text, blanks."""
    unknown = sorted(set(sheet["id"]) - set(prepared.index))
    if unknown:
        raise SystemExit(f"{path.name}: ids not in the prepared dataset: {unknown[:10]}")
    bad = sorted(set(sheet["label"].dropna()) - set(LABELS_ALLOWED))
    if bad:
        raise SystemExit(f"{path.name}: unknown labels {bad}")
    original = prepared.loc[sheet["id"], "message"].to_numpy()
    edited = sheet.loc[sheet["message"].fillna("").to_numpy() != original, "id"].tolist()
    return {"name": path.name, "rows": len(sheet), "blank": sheet.loc[sheet["label"].isna(), "id"].tolist(),
            "edited": edited, "mismatches": criteria_mismatches(sheet)}


def read_pair(path_1, path_2, set_name, prepared):
    r1, r2 = read_sheet(path_1), read_sheet(path_2)
    if set(r1["id"]) != set(r2["id"]):
        raise SystemExit(f"{path_1.name} and {path_2.name} do not contain the same messages.")
    checks = [check_sheet(path_1, r1, prepared), check_sheet(path_2, r2, prepared)]
    pairs = r1[["id", "sender", "label", "criteria"]].merge(
        r2[["id", "label", "criteria"]], on="id", suffixes=("_R1", "_R2"))
    pairs.insert(1, "set", set_name)
    pairs.insert(3, "message", prepared.loc[pairs["id"], "message"].to_numpy())
    return pairs, checks


def agreement(pairs):
    """Agreement statistics over the messages both annotators labelled."""
    done = pairs[pairs["label_R1"].notna() & pairs["label_R2"].notna()]
    both = done[done["label_R1"].isin(CLASSES) & done["label_R2"].isin(CLASSES)]
    kappa = weighted = float("nan")
    if len(both):
        kappa = cohen_kappa_score(both["label_R1"], both["label_R2"], labels=list(CLASSES))
        weighted = cohen_kappa_score(both["label_R1"], both["label_R2"], labels=list(CLASSES), weights="linear")
    return {"messages": len(pairs), "done": len(done), "classes": len(both),
            "raw": float((done["label_R1"] == done["label_R2"]).mean()) if len(done) else float("nan"),
            "kappa": kappa, "weighted": weighted, "done_rows": done}


def crosstab_lines(done):
    table = pd.crosstab(done["label_R1"], done["label_R2"])
    order = [c for c in LABELS_ALLOWED if c in table.index.union(table.columns)]
    table = table.reindex(index=order, columns=order, fill_value=0)
    lines = ["| R1 \\ R2 | " + " | ".join(table.columns) + " |", "|---|" + "---|" * len(table.columns)]
    lines += [f"| **{label}** | " + " | ".join(str(v) for v in row) + " |" for label, row in table.iterrows()]
    return lines


def agreement_report(sets, checks):
    """sets: list of (title, names, stats); checks: check_sheet() results."""
    lines = [
        "# Inter-annotator agreement",
        "",
        "| Set | R1 | R2 | Messages | Labelled by both | Percent agreement | Cohen's kappa | Weighted kappa |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for title, (n1, n2), s in sets:
        lines.append(f"| {title} | `{n1}` | `{n2}` | {s['messages']} | {s['done']} | {s['raw']:.1%} | "
                     f"**{s['kappa']:.3f}** ({band(s['kappa'])}) | **{s['weighted']:.3f}** ({band(s['weighted'])}) |")
    lines += [
        "",
        "Percent agreement includes Exclude; the kappas use the messages both annotators placed in",
        "Safe/Suspicious/High Risk, with linear weights for the ordered labels. Interpretation follows",
        "Landis & Koch (1977): 0.41-0.60 moderate, 0.61-0.80 substantial, 0.81-1.00 almost perfect.",
        "The labelling guide's target is at least 0.61; if it is lower, revise the guide where the",
        "annotators disagreed and label a fresh sample.",
    ]
    for title, _, s in sets:
        lines += ["", f"## {title}: R1 (rows) vs R2 (columns)", "", *crosstab_lines(s["done_rows"])]

    lines += ["", "## Label and criteria consistency", "",
              "Labels whose criterion codes do not match the guide's decision rules. "
              "Worth correcting before adjudication.", ""]
    for c in checks:
        rows = c["mismatches"]
        lines.append(f"**`{c['name']}`: {len(rows)}**" + ("" if rows else " (none)"))
        lines += ["", "| id | label | criteria | problem |", "|---|---|---|---|"] if rows else []
        lines += [f"| {i} | {label} | {crit} | {problem} |" for i, label, crit, problem in rows]
        lines.append("")

    lines += ["## Missing labels and edited messages", "",
              "Messages left without a label are listed in adjudication.xlsx. Edits to a message's text in a",
              "workbook are ignored: the dataset always uses the original (prepared) text.", ""]
    def listed(ids):
        return ", ".join(ids) if 0 < len(ids) <= 20 else (f"{len(ids)} messages" if ids else "none")

    for c in checks:
        lines.append(f"- `{c['name']}`: no label: {listed(c['blank'])}; text edited: {listed(c['edited'])}")
    return "\n".join(lines) + "\n"


def update_adjudication(path, disagreements):
    """Writes the adjudication workbook, keeping any final labels already entered."""
    wanted = disagreements.assign(final_label=None, notes=None)
    if path.exists():
        existing = read_sheet(path)
        if set(existing["id"]) == set(wanted["id"]):
            return existing
        if has_labels(path):
            kept = existing.set_index("id")
            for col in ("final_label", "notes"):
                wanted[col] = wanted["id"].map(kept[col]) if col in kept else None
            backup = path.with_name(path.stem + ".previous.xlsx")
            shutil.copy2(path, backup)
            print(f"The disagreements changed; final labels already entered were kept "
                  f"(previous file -> {backup.name}).")
    write_sheet(path, wanted, ADJUDICATION_COLUMNS, label_column="final_label", title="Adjudication")
    print(f"{len(wanted)} messages to adjudicate -> {path} (fill final_label)")
    return read_sheet(path)


def settle(pairs, final):
    """Label for each pair that is settled: agreed by both, or adjudicated."""
    agreed = (pairs["label_R1"] == pairs["label_R2"]) & pairs["label_R1"].notna()
    adjudicated = pairs["id"].isin(final)
    settled = pairs[agreed | adjudicated].copy()
    settled["label"] = [final.get(i, a) for i, a in zip(settled["id"], settled["label_R1"])]
    settled["label_origin"] = ["adjudicated" if i in final else "agreed by both annotators" for i in settled["id"]]
    return settled[["id", "label", "label_origin"]], len(pairs) - len(settled)


def write_dataset(labeled, prepared, out):
    """Joins labels (id, label, label_origin) to the prepared messages and saves them."""
    dataset = prepared.reset_index()[["id", "source", "source_category", "message"]].merge(labeled, on="id")
    kept = dataset[dataset["label"] != "Exclude"]
    out.parent.mkdir(parents=True, exist_ok=True)
    kept.to_csv(out, index=False, encoding="utf-8-sig")
    print(f"\n{len(kept)} labelled messages ({len(dataset) - len(kept)} excluded) -> {out}")
    print(kept["label"].value_counts().to_string())
    print(kept["label_origin"].value_counts().to_string())
    resolved = out.resolve()
    return resolved.relative_to(ML.parent) if resolved.is_relative_to(ML.parent) else resolved


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--annotation-dir", type=Path, default=ML / "annotation")
    parser.add_argument("--prepared", type=Path, default=ML / "data" / "prepared" / "public_sms_prepared.csv")
    parser.add_argument("--out", type=Path, default=ML / "data" / "labeled" / "public_sms_labeled.csv")
    parser.add_argument("--r1", type=Path, help="R1's workbook (default: <annotation-dir>/agreement_R1.xlsx)")
    parser.add_argument("--r2", type=Path, help="R2's workbook (default: <annotation-dir>/agreement_R2.xlsx)")
    parser.add_argument("--main", type=Path, nargs="+", metavar="WORKBOOK",
                        help="the main set's workbook, or R1's and R2's when it was labelled twice "
                             "(default: <annotation-dir>/main_annotation.xlsx)")
    parser.add_argument("--interim", action="store_true",
                        help="write the messages that are already settled, before everything is done")
    parser.add_argument("--interim-out", type=Path, default=ML / "data" / "labeled" / "interim_labeled.csv")
    args = parser.parse_args()
    adir = args.annotation_dir
    main_paths = args.main or [adir / "main_annotation.xlsx"]
    if len(main_paths) > 2:
        parser.error("--main takes one workbook, or two for a double-annotated main set")
    prepared = pd.read_csv(args.prepared, keep_default_na=False).set_index("id")

    r1_path, r2_path = args.r1 or adir / "agreement_R1.xlsx", args.r2 or adir / "agreement_R2.xlsx"
    sample, checks = read_pair(r1_path, r2_path, SAMPLE, prepared)
    sets = [("Agreement sample (20%)", (r1_path.name, r2_path.name), agreement(sample))]
    all_pairs = [sample]
    single = None
    if len(main_paths) == 2:
        main_pairs, main_checks = read_pair(*main_paths, MAIN, prepared)
        if set(main_pairs["id"]) & set(sample["id"]):
            raise SystemExit("The main workbooks contain messages from the agreement sample.")
        checks += main_checks
        sets.append(("Main set (80%)", tuple(p.name for p in main_paths), agreement(main_pairs)))
        all_pairs.append(main_pairs)
        combined = pd.concat(all_pairs, ignore_index=True)
        sets.append(("All messages", ("R1", "R2"), agreement(combined)))
    else:
        single = read_sheet(main_paths[0])
        checks.append(check_sheet(main_paths[0], single, prepared))
    pairs = pd.concat(all_pairs, ignore_index=True)

    adir.mkdir(parents=True, exist_ok=True)
    (adir / "agreement_report.md").write_text(agreement_report(sets, checks), encoding="utf-8")
    for title, _, s in sets:
        print(f"{title}: {s['raw']:.1%} agreement, kappa {s['kappa']:.3f} ({band(s['kappa'])}), "
              f"weighted {s['weighted']:.3f} ({band(s['weighted'])}) over {s['done']} messages")
    for c in checks:
        print(f"  {c['name']}: {len(c['mismatches'])} label/criteria mismatches, "
              f"{len(c['blank'])} without a label, {len(c['edited'])} with edited text")
    print(f"Report -> {adir / 'agreement_report.md'}")

    unsettled = pairs[(pairs["label_R1"] != pairs["label_R2"]) | pairs["label_R1"].isna()]
    adjudicated = update_adjudication(adir / "adjudication.xlsx", unsettled) if len(unsettled) else None
    final = {} if adjudicated is None else {
        i: label for i, label in zip(adjudicated["id"], adjudicated["final_label"]) if label}
    bad = sorted(set(final.values()) - set(LABELS_ALLOWED))
    if bad:
        raise SystemExit(f"adjudication.xlsx: unknown labels {bad}")
    labeled, waiting = settle(pairs, final)
    if single is not None:
        done = single[single["label"].notna()].assign(label_origin="single annotator")
        labeled = pd.concat([labeled, done[["id", "label", "label_origin"]]])
        waiting += int(single["label"].isna().sum())

    if args.interim:
        shown = write_dataset(labeled, prepared, args.interim_out)
        print(f"({waiting} messages still waiting for a label or adjudication are left out)")
        print(f"\nNext: python ml/train.py --data {shown} --label-status interim")
        return
    if waiting:
        print(f"\n{waiting} messages still need a label or a final_label in adjudication.xlsx; "
              f"use --interim to train on the settled ones meanwhile.")
        return
    shown = write_dataset(labeled, prepared, args.out)
    print(f"\nNext: python ml/train.py --data {shown}")


if __name__ == "__main__":
    main()

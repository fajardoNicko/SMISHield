"""Prepare the VCSMS Google Form submissions for training.

Run from the repository root:

    python ml/prepare_vcsms.py "Data/vcsms/<form export>.xlsx"

The export holds one message per row (column "SMS Messages" or similar) and,
if the team already labelled it, label / criteria / notes / annotator columns.

Writes, all inside gitignored folders because this is student data and the
repository is public:
  ml/data/private/vcsms_labeled.csv   labelled messages (id VC-00001, ...),
                                       redacted, for ml/train.py --data
  ml/annotation/vcsms_R2.xlsx          the same messages without labels, for a
                                       second annotator (agreement check)
"""

import argparse
from pathlib import Path

import pandas as pd

from smishield_ml.annotation import has_labels, write_sheet
from smishield_ml.dataset import deduplicate, normalize_label
from smishield_ml.sources import redact

ML = Path(__file__).resolve().parent
MESSAGE_COLUMNS = ("sms messages", "sms message", "message", "messages", "sms", "text")


def find_column(df, candidates):
    by_lower = {str(c).strip().lower(): c for c in df.columns}
    return next((by_lower[c] for c in candidates if c in by_lower), None)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("export", type=Path, help="the Google Form export (XLSX or CSV)")
    parser.add_argument("--out", type=Path, default=ML / "data" / "private" / "vcsms_labeled.csv")
    parser.add_argument("--r2", type=Path, default=ML / "annotation" / "vcsms_R2.xlsx")
    args = parser.parse_args()

    raw = (pd.read_excel(args.export) if args.export.suffix.lower() in (".xlsx", ".xls")
           else pd.read_csv(args.export, encoding="utf-8-sig"))
    message_col = find_column(raw, MESSAGE_COLUMNS)
    if message_col is None:
        raise SystemExit(f"No message column found. Columns: {list(raw.columns)}")
    get = lambda name: raw[find_column(raw, (name,))] if find_column(raw, (name,)) else None  # noqa: E731

    df = pd.DataFrame({"message": raw[message_col]})
    for name in ("label", "criteria", "notes", "annotator"):
        column = get(name)
        df[name] = column if column is not None else None
    df = df[df["message"].notna() & (df["message"].astype(str).str.strip() != "")].reset_index(drop=True)
    df["id"] = [f"VC-{i + 1:05d}" for i in range(len(df))]
    df["source"] = "vcsms"
    df["message"] = df["message"].astype(str).str.strip().map(redact)

    excluded = df["label"].astype(str).str.strip().str.lower() == "exclude"
    df["label"] = df["label"].map(lambda v: None if pd.isna(v) else normalize_label(v))
    unlabelled = df["label"].isna() & ~excluded
    labelled = df[~excluded & ~unlabelled]
    clean, dropped = deduplicate(labelled, near_threshold=0.9, id_col="id")
    clean = clean.assign(label_origin="single annotator")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    columns = ["id", "source", "message", "label", "criteria", "notes", "label_origin"]
    clean[columns].to_csv(args.out, index=False, encoding="utf-8-sig")
    print(f"{len(df)} submissions: {int(excluded.sum())} excluded, {int(unlabelled.sum())} without a label, "
          f"{len(dropped)} duplicates dropped")
    print(f"{len(clean)} labelled messages -> {args.out}")
    print(clean["label"].value_counts().to_string())

    if has_labels(args.r2):
        print(f"{args.r2} already has labels; left unchanged.")
    else:
        blank = df[~excluded].assign(sender="", annotator=None, label=None, criteria=None, notes=None)
        write_sheet(args.r2, blank, ["id", "message", "annotator", "label", "criteria", "notes"])
        print(f"Blind workbook for a second annotator -> {args.r2}")


if __name__ == "__main__":
    main()

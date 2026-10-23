"""Prepare the public Kaggle SMS datasets for labelling and training.

Run from the repository root after putting the downloaded files in ml/data/raw/:

    python ml/prepare_dataset.py

Steps (see ml/LABELING_GUIDE.md for the reasoning):
  1. Read each source into one table and redact phone numbers and e-mails.
  2. Drop exact and near-duplicate messages across all sources, so the same
     message can never end up in both the training and the test set.
  3. Suggest a provisional label with the guide's criterion codes.
  4. Write the prepared table and the annotation workbooks:
       ml/data/prepared/public_sms_prepared.csv   all unique messages + provisional labels
       ml/data/prepared/dropped_duplicates.csv    what step 2 removed, and why
       ml/annotation/agreement_R1.xlsx            the same random sample (default 20%)
       ml/annotation/agreement_R2.xlsx              for two researchers, labelled blind
       ml/annotation/main_annotation.xlsx         the remaining messages

Existing workbooks that already contain labels are never overwritten.
"""

import argparse
from pathlib import Path

import pandas as pd
from sklearn.model_selection import train_test_split

from smishield_ml.annotation import has_labels, sender_display, write_sheet
from smishield_ml.dataset import deduplicate
from smishield_ml.prelabel import assess
from smishield_ml.sources import load_ph_spam, load_tagalog_sms

ML = Path(__file__).resolve().parent
RAW = ML / "data" / "raw"
PREPARED = ML / "data" / "prepared"
ANNOTATION = ML / "annotation"


def _default_ph_spam():
    candidates = [p for p in RAW.glob("*") if p.suffix.lower() in (".csv", ".xlsx", ".xls")
                  and not p.name.lower().startswith("tagalog-sms")]
    return candidates[0] if len(candidates) == 1 else None


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--tagalog-sms", type=Path, default=RAW / "tagalog-sms.xlsx",
                        help="onzero0 Tagalog-SMS file (Kaggle)")
    parser.add_argument("--ph-spam", type=Path, default=None,
                        help="bwandowando Philippine Spam/Scam SMS file (Kaggle); auto-detected in ml/data/raw/")
    parser.add_argument("--agreement-fraction", type=float, default=0.2,
                        help="share of messages labelled by two researchers for the agreement check")
    parser.add_argument("--near-dup-threshold", type=float, default=0.9)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    frames = []
    if args.tagalog_sms.exists():
        frames.append(load_tagalog_sms(args.tagalog_sms))
        print(f"Tagalog-SMS: {len(frames[-1])} messages")
    else:
        print(f"Tagalog-SMS not found at {args.tagalog_sms}")
    ph_spam = args.ph_spam or _default_ph_spam()
    if ph_spam and ph_spam.exists():
        frames.append(load_ph_spam(ph_spam))
        print(f"Philippine Spam/Scam SMS ({ph_spam.name}): {len(frames[-1])} messages")
    else:
        print("Philippine Spam/Scam SMS not found in ml/data/raw/ (skipped)")
    if not frames:
        raise SystemExit("No source files found. See ml/data/README.md.")

    data = pd.concat(frames, ignore_index=True)
    data = data[data["message"].str.strip() != ""]
    clean, dropped = deduplicate(data, args.near_dup_threshold, label_col=None, id_col="id")
    print(f"Unique messages after removing duplicates: {len(clean)} ({len(dropped)} dropped)")

    results = [assess(m, c, t) for m, c, t in
               zip(clean["message"], clean["source_category"], clean["sender_type"])]
    clean["provisional_label"] = [r.label for r in results]
    clean["provisional_criteria"] = ["; ".join(r.criteria) for r in results]
    clean["needs_review"] = [r.needs_review for r in results]
    clean["review_reason"] = [r.review_reason for r in results]
    clean["exclude_suggested"] = [r.exclude for r in results]

    PREPARED.mkdir(parents=True, exist_ok=True)
    clean.to_csv(PREPARED / "public_sms_prepared.csv", index=False, encoding="utf-8-sig")
    dropped.drop(columns=["normalized"]).to_csv(
        PREPARED / "dropped_duplicates.csv", index=False, encoding="utf-8-sig")

    print("\nProvisional labels by source category:")
    print(pd.crosstab(clean["source_category"], clean["provisional_label"].replace("", "(exclude?)"),
                      margins=True).to_string())
    print(f"\nFlagged for review: {int(clean['needs_review'].sum())}")

    # Annotation workbooks: a stratified sample for the agreement check, the rest for single labelling.
    sheet = clean.assign(sender=[sender_display(t, n) for t, n in zip(clean["sender_type"], clean["sender_name"])],
                         label=None, criteria=None, notes=None, annotator=None)
    strata = sheet["provisional_label"].replace("", "Exclude")
    agreement, main_part = train_test_split(sheet, train_size=args.agreement_fraction,
                                            stratify=strata, random_state=args.seed)
    agreement = agreement.sample(frac=1, random_state=args.seed)
    main_part = main_part.sample(frac=1, random_state=args.seed)

    blind = ["id", "sender", "message", "label", "criteria", "notes"]
    outputs = [
        (ANNOTATION / "agreement_R1.xlsx", agreement, blind),
        (ANNOTATION / "agreement_R2.xlsx", agreement, blind),
        (ANNOTATION / "main_annotation.xlsx", main_part, blind[:3] + ["annotator"] + blind[3:]),
    ]
    print()
    labelled = [p for p, _, _ in outputs if has_labels(p)]
    if labelled:
        # The three workbooks must come from the same run; never mix or overwrite labelling work.
        print("Annotation workbooks NOT rewritten because these already contain labels:")
        for path in labelled:
            print(f"  {path.relative_to(ML.parent)}")
    else:
        for path, rows, columns in outputs:
            write_sheet(path, rows, columns)
            print(f"Wrote {path.relative_to(ML.parent)} ({len(rows)} messages)")
    print(f"Wrote {(PREPARED / 'public_sms_prepared.csv').relative_to(ML.parent)}")


if __name__ == "__main__":
    main()

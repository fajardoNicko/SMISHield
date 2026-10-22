"""Loading, label cleanup and de-duplication of the SMS dataset."""

from pathlib import Path

import pandas as pd

from . import CLASSES
from .preprocess import normalize

TEXT_COLUMNS = ("message", "text", "sms", "sms message", "content", "body")
LABEL_COLUMNS = ("label", "category", "class", "classification")

# Accepted spellings of each label after lowercasing and removing spaces/_/-.
LABEL_ALIASES = {
    "safe": "Safe",
    "suspicious": "Suspicious",
    "highrisk": "High Risk",
    "high": "High Risk",
}


def _find_column(df, wanted, candidates):
    if wanted:
        if wanted not in df.columns:
            raise SystemExit(f"Column '{wanted}' not found. Columns: {list(df.columns)}")
        return wanted
    by_lower = {str(c).strip().lower(): c for c in df.columns}
    for name in candidates:
        if name in by_lower:
            return by_lower[name]
    raise SystemExit(
        f"Could not find a column named one of {candidates}. "
        f"Columns: {list(df.columns)}. Pass --text-col / --label-col."
    )


def _read_table(path):
    path = Path(path)
    if path.suffix.lower() in (".xlsx", ".xls"):
        return pd.read_excel(path)
    try:
        return pd.read_csv(path, encoding="utf-8-sig")
    except UnicodeDecodeError:
        return pd.read_csv(path, encoding="cp1252")


def normalize_label(value):
    key = "".join(ch for ch in str(value).lower() if ch not in " _-")
    return LABEL_ALIASES.get(key)


def load_dataset(path, text_col=None, label_col=None):
    """Returns a DataFrame with columns message, label (one of CLASSES)."""
    df = _read_table(path)
    text_col = _find_column(df, text_col, TEXT_COLUMNS)
    label_col = _find_column(df, label_col, LABEL_COLUMNS)

    df = df[[text_col, label_col]].rename(columns={text_col: "message", label_col: "label_raw"})
    df = df.dropna(subset=["message", "label_raw"])
    df["message"] = df["message"].astype(str).str.strip()
    df = df[df["message"] != ""]
    df["label"] = df["label_raw"].map(normalize_label)

    unknown = sorted(df.loc[df["label"].isna(), "label_raw"].astype(str).unique())
    if unknown:
        raise SystemExit(
            f"Unrecognised labels {unknown}. Use one of {list(CLASSES)}."
        )
    return df[["message", "label"]].reset_index(drop=True)


def _jaccard(a, b):
    if not a and not b:
        return 1.0
    return len(a & b) / len(a | b)


def deduplicate(df, near_threshold=0.9):
    """Drops repeated messages so the same text cannot be in both train and test.

    - Messages that are identical after preprocessing are kept once. If the
      copies were given different labels, all copies are dropped and reported
      so the researchers can settle the label.
    - If near_threshold > 0, a message whose token set overlaps an earlier
      kept message by at least that Jaccard similarity is also dropped.

    Returns (clean DataFrame, DataFrame of dropped rows with a reason).
    """
    df = df.copy()
    df["normalized"] = df["message"].map(normalize)
    dropped = []

    keep_rows = []
    for _, group in df.groupby("normalized", sort=False):
        labels = set(group["label"])
        if len(labels) > 1:
            for _, row in group.iterrows():
                dropped.append({**row, "reason": "same text, conflicting labels: " + ", ".join(sorted(labels))})
            continue
        keep_rows.append(group.index[0])
        for idx in group.index[1:]:
            dropped.append({**df.loc[idx], "reason": f"duplicate of row {group.index[0]}"})

    kept = df.loc[sorted(keep_rows)]

    if near_threshold > 0:
        token_sets = {i: set(text.split()) for i, text in kept["normalized"].items()}
        accepted = []
        for i in kept.index:
            match = next(
                (j for j in accepted if _jaccard(token_sets[i], token_sets[j]) >= near_threshold),
                None,
            )
            if match is None:
                accepted.append(i)
            else:
                dropped.append({**kept.loc[i], "reason": f"near-duplicate of row {match}"})
        kept = kept.loc[accepted]

    dropped_df = pd.DataFrame(dropped, columns=["message", "label", "normalized", "reason"])
    return kept.drop(columns=["normalized"]).reset_index(drop=True), dropped_df

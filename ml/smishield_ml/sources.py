"""Readers for the public SMS datasets, normalised to one table.

Every reader returns the columns in SOURCE_COLUMNS:

    id               stable ID: source prefix + row number in the original file
    source           short dataset name
    source_category  the dataset's own label, kept for reference only
    sender_type      alphanumeric (brand sender ID), shortcode, mobile, email, unknown
    sender_name      the sender ID when it is a brand/short code, else empty
    date             when the message was received, if known
    message          the message text with phone numbers and e-mails redacted

Personal mobile numbers and e-mail addresses (in the text and as senders) are
replaced with [PHONE] / [EMAIL]; preprocessing maps these placeholders to the
same tokens a real number or address gets, so nothing is lost for the model.
"""

import re
from pathlib import Path

import pandas as pd

SOURCE_COLUMNS = [
    "id", "source", "source_category", "sender_type", "sender_name", "date", "message",
]

PHONE_RE = re.compile(
    r"(?<![0-9])(?:\+?63[ -]?|0)9[0-9]{2}[ -]?[0-9]{3}[ -]?[0-9]{4}(?![0-9])"
)
EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+")

# A first name after a greeting ("Dear Christopher,") or a courier's name
# ("Rider: Juan Dela Cruz"). Generic greetings such as "Dear customer" stay.
_GENERIC = (
    "customer|user|valued|sir|madam|ma'am|maam|member|subscriber|client|all"
    "|po|fam|friend|friends|kapamilya|kabayan|everyone|there|player|players"
)
GREETING_NAME_RE = re.compile(
    r"\b((?i:dear|hi|hello|hey))\s+(?!(?i:" + _GENERIC + r")\b)[A-Z][a-z]{2,}\b"
)
COURIER_NAME_RE = re.compile(r"\b(Rider|Courier|Driver)(\s*:\s*|\s+)[A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2}")


def redact(text):
    text = EMAIL_RE.sub("[EMAIL]", text)
    text = PHONE_RE.sub("[PHONE]", text)
    text = GREETING_NAME_RE.sub(lambda m: f"{m.group(1)} [NAME]", text)
    return COURIER_NAME_RE.sub(lambda m: f"{m.group(1)}{m.group(2)}[NAME]", text)


def sender_type(sender):
    s = str(sender).strip()
    if not s or s.lower() == "nan":
        return "unknown"
    if "@" in s:
        return "email"
    # Digits, possibly masked by the dataset author ("+63969****493").
    if re.fullmatch(r"\+?[0-9*]+", s) and any(ch.isdigit() for ch in s):
        return "mobile" if len(s.lstrip("+")) >= 10 else "shortcode"
    return "alphanumeric"


def _finish(df, prefix, source):
    df = df.copy()
    df["id"] = [f"{prefix}-{i:05d}" for i in df.index]
    df["source"] = source
    df["sender_type"] = df["sender"].map(sender_type)
    # Keep brand IDs and short codes; never keep a personal number or address.
    df["sender_name"] = [
        str(s).strip() if t in ("alphanumeric", "shortcode") else ""
        for s, t in zip(df["sender"], df["sender_type"])
    ]
    df["message"] = df["message"].astype(str).str.strip().map(redact)
    return df[SOURCE_COLUMNS]


def load_tagalog_sms(path):
    """onzero0, "Tagalog-SMS" (Kaggle, CC0): Date, sender, text, category."""
    df = pd.read_excel(path)
    df = df.rename(columns={"Date": "date", "text": "message", "category": "source_category"})
    df["source_category"] = df["source_category"].astype(str).str.strip().str.lower()
    return _finish(df, "TS", "tagalog-sms")


def load_ph_spam(path):
    """bwandowando, "Philippine Spam/Scam SMS" (Kaggle, CC BY-NC-SA 4.0).

    SPAM_SMS.csv: masked_celphone_number, hashed_cellphone_number, date,
    text, carrier. Every message was received as spam or a scam, so the
    source category is "spam" for all rows. The hashed number and carrier
    are not kept.
    """
    path = Path(path)
    df = pd.read_excel(path) if path.suffix.lower() in (".xlsx", ".xls") else pd.read_csv(path)
    lower = {c.lower().strip(): c for c in df.columns}

    def column(*names):
        return next((lower[n] for n in names if n in lower), None)

    text = column("text", "message", "sms", "content", "body", "message_text")
    if text is None:
        raise SystemExit(f"No message column found in {path.name}: {list(df.columns)}")
    sender = column("masked_celphone_number", "masked_cellphone_number", "sender", "from",
                    "sender_number", "number", "phone_number")
    date = column("date", "date_received", "received", "timestamp", "datetime")
    df = pd.DataFrame({
        "message": df[text],
        "sender": df[sender] if sender else "",
        "date": df[date] if date else "",
        "source_category": "spam",
    })
    df = df.dropna(subset=["message"])
    return _finish(df, "PS", "ph-spam-scam")

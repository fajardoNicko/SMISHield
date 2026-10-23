"""Text preprocessing shared by training (Python) and the app (Dart).

app/lib/ml/preprocessor.dart mirrors this module step for step. If you change
anything here, make the same change there and bump PREPROCESSING_VERSION. The
Dart parity test (app/test/ml/model_parity_test.dart) compares the tokens of
both implementations and fails if they drift apart.

Steps (in order):
  1. Collapse every kind of whitespace into a single space.
  2. Lowercase, and strip accents from vowels (é -> e). The letter ñ is kept.
  3. Replace redaction placeholders ([PHONE], [EMAIL], [NAME], [ACCOUNT],
     also written <NAME>) with the same marker a real number, address or
     name would get, so redacted training data matches real input. Undo
     dots disguised as "(.)" or "[.]". Then replace e-mail addresses with a
     marker token.
  4. Replace links with a marker token followed by the words of the domain
     (bpi-secure-login.com -> "tokurl bpi secure login com"); known link
     shorteners (bit.ly, tinyurl.com, ...) get an extra marker instead.
  5. Replace PH mobile numbers, peso amounts and any other number with markers.
  6. Remove apostrophes, shorten letters repeated 3+ times ("pleaseee" -> "pleasee").
  7. Turn every remaining non-letter into a space and split into tokens.

Messages are never translated and no stop words are removed, so Filipino and
Taglish wording is kept as written.
"""

import re

PREPROCESSING_VERSION = 2

URL_TOKEN = "tokurl"
SHORT_URL_TOKEN = "tokshorturl"
EMAIL_TOKEN = "tokemail"
PHONE_TOKEN = "tokphone"
MONEY_TOKEN = "tokmoney"
NUMBER_TOKEN = "toknum"
NAME_TOKEN = "tokname"

# Placeholders used when personal details are removed from a message.
REDACTION_TOKENS = {
    "phone": PHONE_TOKEN,
    "email": EMAIL_TOKEN,
    "name": NAME_TOKEN,
    "account": NUMBER_TOKEN,
}

SHORTENER_DOMAINS = (
    "bit.ly", "bitly.com", "bit.do", "tinyurl.com", "tiny.cc", "t.co", "goo.gl",
    "ow.ly", "is.gd", "v.gd", "buff.ly", "cutt.ly", "rb.gy", "shorturl.at",
    "shorturl.asia", "s.id", "rebrand.ly", "t.ly", "lnkd.in", "u.to", "qr.ae",
    "surl.li", "short.gy", "tr.im", "x.co", "bl.ink", "clck.ru", "shrtco.de",
)

# Domain endings recognised in links written without "http://" or "www.":
# common ones plus those seen in Philippine spam and smishing.
LINK_TLDS = (
    "com", "net", "org", "ph", "info", "biz", "xyz", "top", "site", "online",
    "link", "live", "icu", "buzz", "click", "club", "vip", "shop", "store",
    "cc", "tk", "ml", "ga", "cf", "gq", "sbs", "cyou", "lol", "pw", "ws", "io",
    "app", "ly", "gl", "gd", "co", "me", "asia", "cloud", "mobi", "ru", "cn",
    "tv", "eu", "de", "ca", "uk", "nl", "fr", "es", "it", "pl", "us", "in",
    "is", "to", "la", "cx", "sh", "ms", "tw", "li", "fm", "su", "ai", "gg",
    "bid", "one", "pro", "fun", "win", "bet", "golf", "vegas", "auction",
    "games", "support", "news", "life", "world", "today", "space", "website",
    "tech", "work", "cfd", "rest", "bar", "lat", "mom", "monster", "quest",
    "best", "zone", "plus", "dev", "page", "vin", "st", "digital", "email",
    "ht", "my", "sg", "jp", "kr", "hk", "vn", "au", "nz", "br", "ac", "nu",
)
# Two-letter endings that are also everyday Filipino words (ng, sa, mo, ba,
# si, at, ...) are left out on purpose so "word.ng" is not mistaken for a link.

_WHITESPACE_RE = re.compile(
    "[\t\n\r\f\v \u0085\u00a0\u1680\u2000-\u200b\u2028\u2029\u202f\u205f\u3000\ufeff]+"
)

_ACCENTS = str.maketrans("áàâäãéèêëíìîïóòôöõúùûü", "aaaaaeeeeiiiiooooouuuu")


def _alternation(words):
    # Longest first so the order is deterministic and identical in Dart.
    ordered = sorted(words, key=lambda w: (-len(w), w))
    return "|".join(re.escape(w) for w in ordered)


REDACTION_RE = re.compile(r"[\[<](phone|email|name|account)[\]>]")
# "site(.)com" / "site[.]com": a dot written to dodge link filters.
OBFUSCATED_DOT_RE = re.compile(r"\(\.\)|\[\.\]")
EMAIL_RE = re.compile(r"[a-z0-9._%+-]+@[a-z0-9-]+(?:\.[a-z0-9-]+)+")

URL_RE = re.compile(
    r"(?:https?://|www\.)[^ ]+"
    r"|(?<![a-z0-9.@-])(?:" + _alternation(SHORTENER_DOMAINS) + r")(?:/[^ ]*)?"
    r"|(?<![a-z0-9.@-])(?:[a-z0-9-]+\.)+(?:" + _alternation(LINK_TLDS) + r")"
    r"(?![a-z0-9-])(?:[/?#][^ ]*)?"
    r"|(?<![0-9.])[0-9]{1,3}(?:\.[0-9]{1,3}){3}(?![0-9.])(?::[0-9]+)?(?:/[^ ]*)?"
)

PHONE_RE = re.compile(
    r"(?<![0-9])(?:\+?63[ -]?|0)9[0-9]{2}[ -]?[0-9]{3}[ -]?[0-9]{4}(?![0-9])"
)

MONEY_RE = re.compile(
    r"(?:₱|(?<![a-z])php|(?<![a-z])p)[ ]?[0-9][0-9,]*(?:\.[0-9]+)?(?:[ ]?k(?![a-z]))?"
    r"|(?<![a-z0-9])[0-9][0-9,]*(?:\.[0-9]+)?[ ]?(?:k|pesos|peso|piso|php)(?![a-z])"
)

NUMBER_RE = re.compile(r"[0-9]+")
APOSTROPHE_RE = re.compile("['\u2019\u2018`]")
ELONGATION_RE = re.compile(r"([a-z])\1{2,}")
NON_LETTER_RE = re.compile("[^a-zñ]+")

_SCHEME_RE = re.compile(r"^[a-z][a-z0-9+.-]*://")
_HOST_END_RE = re.compile(r"[/?#:]")
_HOST_SPLIT_RE = re.compile(r"[^a-z0-9]+")


def link_host(url):
    """Returns the lowercase host of a matched link, without "www."."""
    host = _SCHEME_RE.sub("", url, count=1)
    host = _HOST_END_RE.split(host, maxsplit=1)[0].strip(".")
    if host.startswith("www."):
        host = host[4:]
    return host


def _replace_link(match):
    host = link_host(match.group(0))
    if host in SHORTENER_DOMAINS:
        return f" {URL_TOKEN} {SHORT_URL_TOKEN} "
    words = " ".join(part for part in _HOST_SPLIT_RE.split(host) if part)
    return f" {URL_TOKEN} {words} "


def normalize(text):
    """Returns the cleaned message as one space-separated string of tokens."""
    return " ".join(tokenize(text))


def tokenize(text):
    """Splits a raw SMS message into the tokens the model is trained on."""
    text = _WHITESPACE_RE.sub(" ", text)
    text = text.lower().translate(_ACCENTS)
    text = REDACTION_RE.sub(lambda m: f" {REDACTION_TOKENS[m.group(1)]} ", text)
    text = OBFUSCATED_DOT_RE.sub(".", text)
    text = EMAIL_RE.sub(f" {EMAIL_TOKEN} ", text)
    text = URL_RE.sub(_replace_link, text)
    text = PHONE_RE.sub(f" {PHONE_TOKEN} ", text)
    text = MONEY_RE.sub(f" {MONEY_TOKEN} ", text)
    text = NUMBER_RE.sub(f" {NUMBER_TOKEN} ", text)
    text = APOSTROPHE_RE.sub("", text)
    text = ELONGATION_RE.sub(r"\1\1", text)
    text = NON_LETTER_RE.sub(" ", text)
    return [token for token in text.split(" ") if token]

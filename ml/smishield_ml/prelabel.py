"""Provisional (pre-annotation) labels following ml/LABELING_GUIDE.md.

These rules give every message a *suggested* label and the guide's criterion
codes so a model can be trained before the manual labelling is finished, and
so the researchers can see which messages need a closer look. They are NOT the
study's ground truth: the final labels come from the researchers' manual
annotation (see LABELING_GUIDE.md, section 4).

The keyword rules are deliberately simple and will make mistakes, which is why
anything uncertain is flagged with needs_review.
"""

import re
from dataclasses import dataclass, field

from .preprocess import SHORTENER_DOMAINS, URL_RE, link_host

LEGIT_CATEGORIES = {"otp", "notifs", "gov", "ads"}

# Websites (and their official short links) of organisations that smishing
# commonly imitates. Any *.gov.ph host also counts as official.
OFFICIAL_DOMAINS = {
    "gcash.com", "maya.ph", "paymaya.com", "bdo.com.ph", "bpi.com.ph",
    "metrobank.com.ph", "landbank.com", "pnb.com.ph", "unionbankph.com",
    "securitybank.com", "rcbc.com", "chinabank.ph", "eastwestbanker.com",
    "psbank.com.ph", "coins.ph", "shopee.ph", "shope.ee", "shp.ee", "lazada.com.ph",
    "grab.com", "lbcexpress.com", "jtexpress.ph", "ninjavan.co",
    "flashexpress.ph", "dhl.com", "globe.com.ph", "glbe.co", "smart.com.ph",
    "smrt.ph", "dito.ph", "gomo.ph", "meralco.com.ph", "mayniladwater.com.ph",
    "pldthome.com", "pldt.com", "convergeict.com", "netflix.com", "paypal.com",
    "apple.com", "icloud.com", "google.com", "facebook.com", "fb.com",
    "tiktok.com",
}

# Brand words that, inside a link's domain, refer to the brand.
BRAND_HOST_WORDS = [
    "gcash", "paymaya", "maya", "bdo", "bpi", "metrobank", "landbank", "pnb",
    "unionbank", "securitybank", "rcbc", "chinabank", "eastwest", "psbank",
    "coinsph", "shopee", "lazada", "grab", "lbc", "jnt", "jtexpress",
    "ninjavan", "phlpost", "dhl", "sss", "gsis", "philhealth", "pagibig",
    "bir", "lto", "dfa", "dswd", "dti", "pcso", "globe", "smart", "meralco",
    "netflix", "paypal", "apple", "icloud", "google", "facebook", "tiktok",
]


# Deep-link services that put an app's name in the domain for genuine and
# fake links alike, so a brand name there proves nothing.
APP_LINK_SUFFIXES = (".page.link", ".onelink.me", ".app.link")


def _re(pattern):
    return re.compile(pattern, re.IGNORECASE)


_BRANDS = (
    r"g-?cash|(?:pay)?maya|bdo|banco de oro|bpi|metrobank|land ?bank|pnb"
    r"|union ?bank|security ?bank|rcbc|china ?bank|east ?west|ps ?bank|coins\.?ph"
    r"|shopee(?:[- ]?(?:pay|info))?|lazada|grab|lbc|j ?& ?t|jnt|ninja ?van"
    r"|ph(?:l|il) ?post|dhl|sss|gsis|phil ?health|pag-?ibig|bir|lto|dfa|dswd"
    r"|dti|pcso|globe|smart|meralco|netflix|paypal|apple id|icloud|google"
    r"|facebook|tiktok"
)
# The message speaks as the brand ("GCASH: ...", "[ BDO ] ...", "From SSS office").
BRAND_SPEAKER = _re(
    r"^\W{0,3}(?:" + _BRANDS + r")\b|\bfrom (?:the )?(?:" + _BRANDS + r")\b"
)

CLAUSE_END = re.compile(r"[.!?;]+(?=\s|$)|\n+")

SENSITIVE = _re(
    r"\b(?:otp|one[- ]?time[- ]?(?:pin|password|code)|m-?pin|pin code|passwords?"
    r"|passcode|cvv|card (?:number|details)|account (?:number|details)"
    r"|bank (?:account|details|login)|log-?in details|username|valid id|selfie"
    r"|full name|birthday|personal (?:info|information|details)"
    r"|(?:verification|security|authentication|[0-9]-digit) code"
    r"|code (?:na |you )(?:just )?(?:natanggap|received))\b"
)
REQUEST_VERB = _re(
    r"\b(?:send|enter|provide|give|reply|submit|confirm|verify|update|log ?in"
    r"|i-?send|ipadala|ibigay|ilagay|i-?verify|i-?update|i-?reply|kailangan"
    r"|need(?:ed)?|gamit ang|using|with your)\b"
)
PROTECTIVE = _re(
    r"\b(?:do not|don'?t|dont|never|huwag|wag|hindi)\b[^.!?\n]{0,40}?"
    r"\b(?:share|give|send|enter|disclose|ask|ibigay|ibahagi|i-?share|sabihin|hihingi|hihingin)"
)
FEE_PRETEXT = _re(
    r"\b(?:fee|processing|release|redelivery|customs|tax|penalty|multa|advance"
    r"|piyansa|bail|fine|fines|overdue|violation)\b"
)
PAY_VERB = _re(
    r"\b(?:pay|magbayad|bayaran|send|magpadala|ipadala|padalhan|padala|transfer"
    r"|deposit|bilhan)\b"
)
EMERGENCY = _re(
    r"\b(?:emergency|naaksidente|aksidente|ospital|hospital|na-?hold ako"
    r"|nakakulong|nawala (?:ang )?phone|bagong number)\b"
)
GIFT_CARDS = _re(r"\b(?:google play (?:gift )?cards?|gift ?cards?|load codes?)\b")
ACCOUNT_PRETEXT = _re(
    r"\b(?:your|iyong|ang|their) account\b[^.!?\n]{0,60}?"
    r"\b(?:on-?hold|on hold|suspend\w*|block\w*|lock\w*|deactivat\w*|restrict\w*"
    r"|limited|deposit|credited|received|reward|refund|pending|frozen|compromised)"
)
# "Nakatanggap ang iyong number ng P7748", "May P2580 credit ka": money the
# recipient supposedly already has, to be claimed by registering or paying.
MONEY_CLAIM = _re(
    r"\b(?:your|iyong|ang) (?:number|account|gcash|wallet)\b[^.!?\n]{0,40}?"
    r"\b(?:received|credited|nakatanggap|natanggap)\b"
    r"|\b(?:nakatanggap|natanggap)\b[^.!?\n]{0,30}?\b(?:number na ito|this number|iyong number)\b"
    r"|\bmay p?[0-9][0-9,]* (?:credit|na natanggap)"
)
LOGIN = _re(r"\b(?:log ?in|sign ?in|verify|i-?verify|update|claim|i-?claim)\b")

GAMBLING = _re(
    r"\b(?:casino|slots?|jackpot|bets?|betting|taya|tumaya|spin|lucky wheel|sabong"
    r"|jili\w*|first deposit|welcome bonus|deposit bonus|fishing games?|lotto"
    r"|online games?|electronic games?|slot machines?)\b"
)
TOO_GOOD = _re(
    r"\b(?:free|libre\w*|bonus|rewards?|prizes?|premyo|win|won|wins|panalo|nanalo"
    r"|manalo|congrat\w*|claim|i-?claim|cashback|red envelope|giveaway|lucky"
    r"|maswerte|swerte)\b"
)
OFF_CHANNEL = _re(
    r"\b(?:telegram|whats ?app|viber|wechat|add me|dm me|contact (?:the )?"
    r"(?:tutor|manager|mentor|teacher|customer service|cs))\b|(?<![\w.])@[a-z0-9_]{4,}"
)
LOAN_INVEST_JOB = _re(
    r"\b(?:loans?|pautang|utang|invest\w*|trading|trade|crypto|forex|profit"
    r"|interest|tubo|part-?time|part time|job|earn\w*|kumita|kikita|income"
    r"|salary|sahod|tasks?|reviewer|work from home|daily (?:income|salary|pay))\b"
)
URGENCY = _re(
    r"\b(?:urgent\w*|immediately|asap|hurry|last chance|limited time|today only"
    r"|ngayon lang|ngayon din|agad|agapan|dali|bilisan|baka magsisi"
    r"|within [0-9]+ ?(?:hours?|hrs?|minutes?|mins?)"
    r"|in [0-9]+ ?(?:hours?|hrs?|minutes?|mins?)|sa loob ng [0-9]+ ?(?:oras|minuto))\b"
)
LETTERS = re.compile(r"[A-Za-zÑñ]{2,}")


@dataclass
class Assessment:
    label: str
    criteria: list = field(default_factory=list)
    needs_review: bool = False
    review_reason: str = ""
    exclude: bool = False


def _clauses(text):
    start = 0
    for m in CLAUSE_END.finditer(text):
        if m.start() > start:
            yield text[start:m.start()]
        start = m.end()
    if start < len(text):
        yield text[start:]


def _is_official(host):
    return host.endswith(".gov.ph") or any(
        host == d or host.endswith("." + d) for d in OFFICIAL_DOMAINS
    )


def _host_has_brand(host):
    """True for look-alike domains such as sssph.pw or gcash-verify.xyz."""
    if host.endswith(APP_LINK_SUFFIXES):
        return False
    parts = re.split(r"[.-]+", host)
    return any(
        (w in parts) if len(w) <= 3 else (w in host) for w in BRAND_HOST_WORDS
    )


def cues(message):
    """Returns the set of criterion codes found in a message."""
    found = set()
    hosts = [link_host(m.group(0)) for m in URL_RE.finditer(message.lower())]
    unofficial = [h for h in hosts if not _is_official(h)]

    # High Risk criteria
    for clause in _clauses(message):
        if SENSITIVE.search(clause) and REQUEST_VERB.search(clause) and not PROTECTIVE.search(clause):
            found.add("H1")
        if FEE_PRETEXT.search(clause) and PAY_VERB.search(clause):
            found.add("H3")
    # H2 means posing as the brand, not just naming it (a casino ad that
    # accepts GCash is S1, not H2): either the link imitates the brand's
    # website, or the message speaks as the brand and sends you elsewhere.
    if any(_host_has_brand(h) for h in unofficial):
        found.add("H2")
    elif BRAND_SPEAKER.search(message) and (unofficial or "[PHONE]" in message):
        found.add("H2")
    if EMERGENCY.search(message) and PAY_VERB.search(message):
        found.add("H3")
    if GIFT_CARDS.search(message):
        found.add("H3")
    if ACCOUNT_PRETEXT.search(message) and (hosts or LOGIN.search(message)):
        found.add("H4")
    if MONEY_CLAIM.search(message):
        found.add("H4")

    # Suspicious criteria
    if GAMBLING.search(message):
        found.add("S1")
    if TOO_GOOD.search(message):
        found.add("S2")
    if OFF_CHANNEL.search(message):
        found.add("S3")
    if unofficial or any(h in SHORTENER_DOMAINS for h in hosts):
        found.add("S4")
    if LOAN_INVEST_JOB.search(message):
        found.add("S5")
    if URGENCY.search(message):
        found.add("S6")
    return found


def assess(message, source_category, sender_type):
    """Suggested label for one message (see the module docstring)."""
    codes = cues(message)
    high = sorted(c for c in codes if c.startswith("H"))
    susp = sorted(c for c in codes if c.startswith("S"))

    if len(LETTERS.findall(message)) < 3:
        return Assessment("", high + susp, True, "too short to judge", exclude=True)

    if source_category in LEGIT_CATEGORIES:
        # Genuine notifications, OTPs, advisories and the provider's own
        # promotions (guide 3.3). A look-alike link from a sender that is not
        # a registered sender ID still overrides the source category.
        lookalike = any(_host_has_brand(h) for h in _unofficial_hosts(message))
        if lookalike and sender_type != "alphanumeric":
            return Assessment("High Risk", high + susp, True, "brand look-alike link in a legit-category message")
        if "S1" in susp and "S2" in susp:
            return Assessment("Suspicious", high + susp, True, "gambling promotion in a legit-category message")
        reasons = []
        if high:
            reasons.append(f"possible {'/'.join(high)} cue")
        if sender_type == "mobile":
            reasons.append("sent from a mobile number")
        return Assessment("Safe", high + susp, bool(reasons), "; ".join(reasons))

    # Spam/scam source categories: the content decides between the two risk levels.
    if high:
        review = "S1" in susp
        return Assessment("High Risk", high + susp, review,
                          "gambling promotion that also matched an H criterion" if review else "")
    if susp:
        return Assessment("Suspicious", susp)
    return Assessment("Suspicious", [], True, "no criterion matched; may be mislabelled by the source")


def _unofficial_hosts(message):
    hosts = [link_host(m.group(0)) for m in URL_RE.finditer(message.lower())]
    return [h for h in hosts if not _is_official(h)]

# SMISHield data

**This repository is public.** Only data derived from public datasets is
committed here. The VCSMS student submissions, and anything labelled from
them, go in `ml/data/private/`, which git ignores.

## Sources

| Dataset | Author | License | Where to get it |
|---|---|---|---|
| Tagalog-SMS | onzero0 (Kaggle) | CC0 1.0 (public domain) | https://www.kaggle.com/datasets/onzero0/tagalog-sms |
| Philippine Spam/Scam SMS | BwandoWando (Kaggle) | CC BY-NC-SA 4.0 | https://www.kaggle.com/datasets/bwandowando/philippine-spam-sms-messages |
| VCSMS submissions | VCSMS students (Google Form) | Research team only | `ml/data/private/` (not in git) |

CC BY-NC-SA 4.0 requires that anything derived from the Philippine Spam/Scam
SMS dataset **credit the author**, be used **non-commercially**, and be
shared under the **same license**. The prepared and labelled files below
contain messages from it, so they carry that license too.

## Folders

| Path | In git? | Contents |
|---|---|---|
| `raw/` | no | The downloaded Kaggle files, unchanged. Put `tagalog-sms.xlsx` and the Philippine Spam/Scam SMS file here. |
| `prepared/` | yes | Output of `python ml/prepare_dataset.py`: unique, redacted messages with provisional labels, plus the list of removed duplicates. |
| `labeled/` | yes | Output of `python ml/finalize_labels.py`: the researchers' final labels, used for training. |
| `private/` | no | VCSMS data at every stage (raw, prepared, labelled). |
| `placeholder_dataset.csv` | yes | Made-up messages used only to develop the pipeline. Never report results from it. |

## Redaction

Before anything is written to `prepared/`, personal mobile numbers become
`[PHONE]`, e-mail addresses become `[EMAIL]`, and first names after a
greeting or a courier label ("Dear …", "Rider: …") become `[NAME]`. Senders
that are personal numbers are stored only as "mobile". The preprocessing
turns these placeholders into the same tokens a real number, address or name
would produce, so the model is not affected.

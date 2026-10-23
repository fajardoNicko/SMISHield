# SMISHield Labeling Guide

Version 1.0 · applies to the public Kaggle datasets and the VCSMS submissions

This guide defines how every SMS message in the SMISHield dataset is assigned
one of three labels, **Safe**, **Suspicious** or **High Risk**, and the
procedure the researchers follow so the labels are consistent and their
reliability can be measured. Each rule names the published source it is
based on, so the method can be cited in Chapter 3.

---

## 1. Why three categories, and what they measure

**A published three-class scheme.** Mishra and Soni (2022, 2023) released an
SMS dataset with three classes: *ham* (legitimate), *spam* and *smishing*.
SMISHield adopts the same three-way structure. Its labels map onto those
classes:

| Mishra & Soni class | SMISHield label | Meaning in this study |
|---|---|---|
| Ham | **Safe** | Legitimate message; no attempt to deceive |
| Spam | **Suspicious** | Unsolicited or questionable; shows warning signs but does not itself try to take credentials or money |
| Smishing | **High Risk** | Tries to deceive the recipient into giving up sensitive information or money |

**Where the line between Suspicious and High Risk falls.** Timko and Rahman
(2024) separate the two by intent: phishing (smishing) is *inherently
malicious*, while spam *can be* unsolicited advertising. For the Philippine
setting, the line is drawn with the legal definition in **Republic Act
No. 12010** (Anti-Financial Account Scamming Act, 2024):

- **Sec. 4(b)** defines a *social engineering scheme* as obtaining another
  person's sensitive identifying information through deception or fraud, by
  (1) misrepresenting oneself as acting for an institution, or making false
  representations to solicit the information, or (2) using electronic
  communications to obtain it.
- **Sec. 3(i)** defines *sensitive identifying information* as information
  that can be used to access a financial account, such as usernames,
  passwords, bank account details, credit card and e-wallet information, and
  other confidential personal information.
- **Sec. 3(b)** names SMS among the *electronic communications* covered.

A message is therefore **High Risk** when it attempts what RA 12010 describes,
or the closely related fraud of obtaining money under a false pretext.

**Which warning signs count.** The individual criteria come from the cue list
of the **NIST Phish Scale** (Steves et al., 2020; Dawkins & Jacobs, 2023). Its
23 cues are grouped as errors, technical indicators, visual presentation,
language and content, and common tactics. Only cues that can occur in a plain
SMS are used. Email-only cues such as attachments, display names, logos and
page design are left out. The cues match the risk indicators already listed
in the research plan: suspicious URLs, credential requests, urgency, and
financial or prize keywords. Matching each criterion below to a NIST cue is
this study's adaptation of the Phish Scale (written for email) to SMS.

**What the labels do not measure.** The labels rate the *risk of being
defrauded by the message itself*, not whether the message was wanted. An
unwanted but harmless message, such as a political campaign text with no link
or request, is Safe. A label is the researchers' assessment of the message's
content, not proof of the sender's intent (research plan, Ch. 3).

---

## 2. Criteria

### High Risk: any one of these

| Code | Criterion | Basis |
|---|---|---|
| **H1** | Asks for sensitive identifying information (OTP, PIN/MPIN, password, username, card or account details, ID, selfie, full name with birthday), either directly ("reply with the code") or through a link or form ("log in here", "verify your account") | RA 12010 Sec. 3(i), 4(b)(2); NIST cue *requests for sensitive information* |
| **H2** | Poses as a bank, e-wallet, government agency, courier, telco, employer or a person known to the recipient, **and** asks the recipient to act (click, call, reply, pay). This includes look-alike web addresses such as `sssph.pw` and `gcash-verify.xyz` | RA 12010 Sec. 4(b)(1); NIST cues *poses as friend, colleague, supervisor, authority figure* and *domain spoofing* |
| **H3** | Asks for money, a fee, load or gift cards under a false or unverifiable pretext: to claim a prize, release a parcel, loan or refund, pay a fine, or handle a family "emergency" | Advance-fee fraud; NIST cues *too good to be true offers*, *humanitarian appeals* |
| **H4** | Makes a false claim about the recipient's account or money to push an action: "your account is on hold", "₱6,140 is waiting for your number", "a cash deposit was made, log in to receive" | NIST cues *threatening language* and *you're special*; RA 12010 Sec. 4(b)(1) false representations |

### Suspicious: any one of these, and no H criterion

| Code | Criterion | Basis |
|---|---|---|
| **S1** | Online gambling or betting promotion (casino, slots, "deposit ₱100 get ₱300") | Unsolicited advertising (Timko & Rahman, 2024); NIST *too good to be true* |
| **S2** | Too-good-to-be-true offer: prizes, free money, bonuses, "you were selected" | NIST *too good to be true offers*, *you're special* |
| **S3** | Moves contact to another channel or an unknown person: Telegram, WhatsApp, "contact the tutor", an e-mail address | NIST *lack of signer details* (the sender cannot be verified) |
| **S4** | Contains an unknown or shortened link, without asking for information or money | NIST *URL hyperlinking* |
| **S5** | Loan, investment, crypto, or easy-money job or task offer ("earn ₱500 a day watching videos") | NIST *too good to be true offers* |
| **S6** | Urgency or time pressure from a sender who cannot be verified ("valid only within 8 hrs") | NIST *sense of urgency*, *limited time offer* |

### Safe: everything else

| Code | Typical message |
|---|---|
| **F1** | Genuine transaction, OTP or account notice from the service itself (receipts, balances, delivery updates, OTPs) |
| **F2** | Official advisory, including the scam warnings that banks, telcos and agencies send |
| **F3** | The provider's own promotion to its customers (Smart, Globe, GOMO or bank promos, often with an official link or DTI permit number) |
| **F4** | Personal or everyday message |
| **F5** | Unwanted but harmless, with no H or S criterion (e.g. a political campaign text) |

### Exclude

The message is empty or unreadable, is not in Filipino, English or Taglish
(e.g. Cebuano or German), or is not an SMS (e.g. a developer test message).
Excluded messages are removed from the dataset and counted in the report.

---

## 3. Decision procedure

Ask the questions in this order and stop at the first "yes":

1. **Can it be labelled?** If not, **Exclude**.
2. **Does any H criterion apply?** If so, **High Risk**.
3. **Does any S criterion apply?** If so, **Suspicious**.
4. Otherwise, **Safe**.

Write the codes that applied in the *criteria* column (e.g. `H2; H4` or
`S1; S2`). Use `F1`–`F5` for Safe.

### Hard cases

| Situation | Label | Why |
|---|---|---|
| A genuine OTP: "123456 is your GCash code. Do not share it." | Safe (F1) | It gives a code and warns not to share it. It does not ask for one (no H1). |
| A casino ad that says "use GCash or Maya to deposit" | Suspicious (S1) | Naming a payment method is not posing as the brand (no H2). |
| "GCash: Your account is on hold. Verify here: sprl.in/AppGCash" | High Risk (H2, H4) | Speaks as GCash, makes a false account claim, and links elsewhere. |
| "Nakatanggap ang iyong number ng ₱7,748. Maglagay ng ₱50 para ma-claim." | High Risk (H3, H4) | False money claim plus a fee to collect it. |
| A legit sender ID (e.g. "GCash") but the content meets an H criterion | High Risk | Sender IDs can be spoofed, so the content decides. |
| A genuine Smart or Globe promo with an official link (smrt.ph, glbe.co) | Safe (F3) | The provider's own promotion. |
| A bank or telco message warning about scams | Safe (F2) | An advisory, even though it mentions OTPs and links. |
| A delivery notice from a rider's mobile number with no link or payment request | Safe (F1) | A normal courier message. |
| Unsure between Suspicious and High Risk | Choose High Risk **only** if you can name an H code | Keeps the higher label tied to a specific criterion. |

**Sender information.** The workbook shows the sender ID for brand senders and
short codes ("GCash (sender ID)") and only "mobile number" for personal
numbers. Use it **only** to judge whether a message really comes from the
company it names. The model never sees the sender; it learns from the text
alone.

---

## 4. Annotation procedure

The procedure follows the MATTER cycle of Pustejovsky and Stubbs (2012):
Model, Annotate, Train, Test, Evaluate, Revise. The guide (the model of the
categories) and a sample annotation are revised until two researchers agree
well enough. Only then is the rest annotated, the classifier trained and
tested, and the results evaluated.

1. **Preparation** (`python ml/prepare_dataset.py`)
   - The sources are combined into one table.
   - Personal mobile numbers, e-mail addresses, first names after greetings
     and courier names are replaced with `[PHONE]`, `[EMAIL]` and `[NAME]`
     (ethics section of Ch. 3). Preprocessing treats these placeholders like
     real numbers, addresses and names.
   - Exact and near-duplicate messages are removed **before** labelling, so
     no one labels the same template twice and no template can land in both
     the training and the test set.
2. **Provisional labels.** The script suggests a label and criterion codes
   for every message (`ml/smishield_ml/prelabel.py`).
   - These are **not** ground truth. They exist only so a first model can be
     trained while the manual labelling is under way.
   - Fort and Sagot (2010) found that pre-annotation makes manual labelling
     faster and more accurate, but also introduces biases towards the
     suggested labels. The suggestions are therefore **left out of the
     annotation workbooks**, as is the source dataset's own category.
     Researchers label *blind*.
3. **Reliability sample** (`agreement_R1.xlsx`, `agreement_R2.xlsx`)
   - A random 20% of the messages, stratified so every category is
     represented, is labelled **independently** by two researchers (R1 and
     R2). They do not discuss labels until both are done.
   - Agreement is measured with **Cohen's kappa** (Cohen, 1960) and, because
     the labels are ordered (Safe < Suspicious < High Risk), **linearly
     weighted kappa** (Cohen, 1968). A Safe-vs-High Risk disagreement counts
     as worse than a Safe-vs-Suspicious one.
   - The values are read with the Landis and Koch (1977) bands: 0.41–0.60
     moderate, 0.61–0.80 substantial, 0.81–1.00 almost perfect.
   - **Target: weighted kappa of at least 0.61.** Artstein and Poesio (2008)
     note that about 0.80 is needed before drawing strong conclusions, so
     report the value either way.
   - If the target is not met, revise the guide where R1 and R2 disagreed
     and label a fresh sample.
4. **Adjudication** (`adjudication.xlsx`). A third researcher decides every
   message R1 and R2 labelled differently, using this guide.
5. **Main annotation** (`main_annotation.xlsx`). The remaining 80% is
   labelled once, divided among the researchers. Each writes their initials
   in the *annotator* column.
6. **Final dataset** (`python ml/finalize_labels.py`). The script computes
   the agreement report, merges the agreed, adjudicated and single labels,
   drops excluded messages, and writes `ml/data/labeled/public_sms_labeled.csv`.

The VCSMS Google Form submissions go through the same steps. They are kept
in `ml/data/private/` and are never committed, because the repository is
public.

---

## 5. How the labelled data is used for training

`python ml/train.py --data ml/data/labeled/public_sms_labeled.csv`

- **Split 70 : 10 : 20** into training, validation and test sets, stratified
  by label, with a fixed random seed. Hastie et al. (2009, Sec. 7.2) describe
  this three-way split: the training set fits the model, the validation set
  chooses among candidate settings, and the test set, used only once at the
  end, estimates performance on unseen data.
- The candidate settings are the TF-IDF n-gram range, sublinear term
  frequency, the Naive Bayes smoothing `alpha`, and learned vs. equal class
  priors. The one with the best macro F1 on the validation set is kept.
- The TF-IDF vocabulary is fitted on the training messages only.
- Results are reported for the test set: the confusion matrix, accuracy,
  per-class precision, recall and F1, macro and weighted averages, the
  Figure 19 scheme, and results per data source (Kaggle vs. VCSMS).

---

## 6. Mapping of the source datasets' own categories

The source categories are a starting point only. Every message is still
labelled with the criteria above.

| Source | Its category | Usually becomes | Watch for |
|---|---|---|---|
| Tagalog-SMS (onzero0) | `otp` | Safe (F1) | A few casino ads filed as OTP |
| | `notifs` | Safe (F1/F3) | Phishing from a mobile number filed as a notification |
| | `gov` | Safe (F2) | — |
| | `ads` | Safe (F3) | Unknown brands, links to non-official sites |
| | `spam` | Suspicious, or High Risk if an H criterion applies | Harmless chat or political texts (Safe or Exclude) |
| Philippine Spam/Scam SMS (bwandowando) | all spam/scam | Suspicious or High Risk | Same as above |

In the Tagalog-SMS file, after duplicates are removed, the provisional rules
suggest 1,271 Safe, 496 Suspicious and **34 High Risk**. High Risk is far too
small to train on reliably. The second Kaggle file and the VCSMS form, which
should specifically ask for scam messages received, need to supply most of
the High Risk examples.

---

## References

Artstein, R., & Poesio, M. (2008). Inter-coder agreement for computational linguistics. *Computational Linguistics, 34*(4), 555–596. https://doi.org/10.1162/coli.07-034-R2

BwandoWando. (2026). *Philippine spam/scam SMS* [Data set]. Kaggle. https://www.kaggle.com/datasets/bwandowando/philippine-spam-sms-messages

Cohen, J. (1960). A coefficient of agreement for nominal scales. *Educational and Psychological Measurement, 20*(1), 37–46. https://doi.org/10.1177/001316446002000104

Cohen, J. (1968). Weighted kappa: Nominal scale agreement with provision for scaled disagreement or partial credit. *Psychological Bulletin, 70*(4), 213–220. https://doi.org/10.1037/h0026256

Dawkins, S., & Jacobs, J. (2023). *NIST Phish Scale user guide* (NIST Technical Note 2276). National Institute of Standards and Technology. https://doi.org/10.6028/NIST.TN.2276

Fort, K., & Sagot, B. (2010). Influence of pre-annotation on POS-tagged corpus development. In *Proceedings of the Fourth Linguistic Annotation Workshop* (pp. 56–63). Association for Computational Linguistics. https://aclanthology.org/W10-1807/

Hastie, T., Tibshirani, R., & Friedman, J. (2009). *The elements of statistical learning: Data mining, inference, and prediction* (2nd ed.). Springer.

Landis, J. R., & Koch, G. G. (1977). The measurement of observer agreement for categorical data. *Biometrics, 33*(1), 159–174. https://doi.org/10.2307/2529310

Mishra, S., & Soni, D. (2022). *SMS phishing dataset for machine learning and pattern recognition* (Version 1) [Data set]. Mendeley Data. https://doi.org/10.17632/f45bkkt8pr.1

Mishra, S., & Soni, D. (2023). SMS phishing dataset for machine learning and pattern recognition. In *Proceedings of the 14th International Conference on Soft Computing and Pattern Recognition (SoCPaR 2022)*. Springer. https://doi.org/10.1007/978-3-031-27524-1_57

onzero0. (2025). *Tagalog-SMS* [Data set]. Kaggle. https://www.kaggle.com/datasets/onzero0/tagalog-sms

Pustejovsky, J., & Stubbs, A. (2012). *Natural language annotation for machine learning*. O'Reilly Media.

Republic Act No. 12010. (2024, July 20). *Anti-Financial Account Scamming Act (AFASA)*. Congress of the Philippines. https://lawphil.net/statutes/repacts/ra2024/ra_12010_2024.html

Steves, M. P., Greene, K. K., & Theofanos, M. F. (2020). Categorizing human phishing difficulty: A Phish Scale. *Journal of Cybersecurity, 6*(1), tyaa009. https://doi.org/10.1093/cybsec/tyaa009

Timko, D., & Rahman, M. L. (2024). Smishing Dataset I: Phishing SMS dataset from Smishtank.com. In *Proceedings of the Fourteenth ACM Conference on Data and Application Security and Privacy (CODASPY '24)* (pp. 289–294). ACM. https://arxiv.org/abs/2402.18430

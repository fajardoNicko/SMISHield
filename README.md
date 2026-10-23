# SMISHield

A machine-learning-based Android app that detects smishing (SMS phishing) in
Filipino and Taglish text messages. The user pastes a message; the app
classifies it as **Safe**, **Suspicious** or **High Risk** on the device, explains
the warning signs it found, and recommends what to do. The app never reads the
SMS inbox and works offline.

## Repository layout

| Path | What it is |
|---|---|
| `ml/` | Python pipeline: preprocessing, TF-IDF + Multinomial Naive Bayes training, evaluation reports, model export. See [ml/README.md](ml/README.md). |
| `app/` | Flutter (Dart) Android app. |
| `app/lib/ml/` | On-device analysis: preprocessing and inference identical to the Python pipeline, rule-based warning signs, explanations in English and Filipino. |
| `app/assets/model/` | The exported model the app loads. |

## How a message is analysed

1. **Check input**: empty, too long, or unreadable messages get a notice
   instead of a classification.
2. **Preprocess**: the same cleaning used in training (lowercase, link/number
   markers, punctuation removed).
3. **Classify**: TF-IDF features → Multinomial Naive Bayes →
   Safe / Suspicious / High Risk. The label comes only from the model.
4. **Explain**: rules find warning signs (suspicious or shortened links,
   requests for OTP/PIN/passwords, urgency, threats, prizes, payment requests,
   impersonated banks/e-wallets/agencies, job and loan offers, gambling) and
   the words the model weighed most. These are listed and highlighted.
5. **Advise**: safety actions matched to the result.

## Development

```
pip install -r ml/requirements.txt
python ml/prepare_dataset.py                                   # Kaggle files in ml/data/raw/
python ml/train.py --data ml/data/prepared/public_sms_prepared.csv --label-col provisional_label

cd app
flutter test
dart run tool/analyze.dart "Your message here"
```

The bundled model is currently trained on **provisional (rule-suggested)
labels** for the Tagalog-SMS Kaggle dataset. It must be retrained on the
researchers' manual labels before evaluation; see
[ml/LABELING_GUIDE.md](ml/LABELING_GUIDE.md) and [ml/README.md](ml/README.md).

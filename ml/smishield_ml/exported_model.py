"""Export of the trained model to JSON, and a plain-Python reader for it.

The JSON file is what the Android app bundles (app/assets/model/). The
ExportedModel class below does inference exactly the way the Dart code in
app/lib/ml/smishield_model.dart does, so it serves as the reference used to
check the export against scikit-learn and to produce the parity fixtures.
"""

import json
import math
from collections import Counter
from datetime import datetime, timezone

from . import CLASSES
from .preprocess import PREPROCESSING_VERSION, tokenize

FORMAT_NAME = "smishield-mnb"
FORMAT_VERSION = 1


def _rounded(values, digits=10):
    return [round(float(v), digits) for v in values]


def export_model(pipeline, dataset_info, evaluation, path):
    """Writes the fitted TF-IDF + Multinomial NB pipeline to a JSON file."""
    vectorizer = pipeline.named_steps["tfidf"]
    classifier = pipeline.named_steps["nb"]

    # Store classes in the fixed Safe / Suspicious / High Risk order.
    order = [list(classifier.classes_).index(name) for name in CLASSES]
    vocabulary = vectorizer.vocabulary_
    terms = sorted(vocabulary, key=vocabulary.get)

    data = {
        "format": FORMAT_NAME,
        "format_version": FORMAT_VERSION,
        "preprocessing_version": PREPROCESSING_VERSION,
        "created_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "dataset": dataset_info,
        "evaluation": evaluation,
        "vectorizer": {
            "ngram_range": list(vectorizer.ngram_range),
            "sublinear_tf": bool(vectorizer.sublinear_tf),
            "norm": vectorizer.norm,
            "smooth_idf": bool(vectorizer.smooth_idf),
        },
        "classifier": {"alpha": float(classifier.alpha)},
        "classes": list(CLASSES),
        "class_log_prior": _rounded(classifier.class_log_prior_[order]),
        "terms": terms,
        "idf": _rounded(vectorizer.idf_),
        "feature_log_prob": [_rounded(classifier.feature_log_prob_[i]) for i in order],
    }
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    return data


def word_ngrams(tokens, ngram_min, ngram_max):
    """Same n-gram expansion as scikit-learn's CountVectorizer."""
    grams = []
    for n in range(ngram_min, ngram_max + 1):
        for i in range(len(tokens) - n + 1):
            grams.append(" ".join(tokens[i:i + n]))
    return grams


class ExportedModel:
    def __init__(self, data):
        if data.get("format") != FORMAT_NAME:
            raise ValueError("Not a SMISHield model file")
        self.data = data
        self.classes = data["classes"]
        self.index = {term: i for i, term in enumerate(data["terms"])}
        self.idf = data["idf"]
        self.feature_log_prob = data["feature_log_prob"]
        self.class_log_prior = data["class_log_prior"]
        vec = data["vectorizer"]
        self.ngram_min, self.ngram_max = vec["ngram_range"]
        self.sublinear_tf = vec["sublinear_tf"]
        self.normalize_l2 = vec["norm"] == "l2"

    @classmethod
    def load(cls, path):
        with open(path, encoding="utf-8") as f:
            return cls(json.load(f))

    def features(self, tokens):
        """Returns {feature index: TF-IDF weight} for the message tokens."""
        counts = Counter(
            self.index[g]
            for g in word_ngrams(tokens, self.ngram_min, self.ngram_max)
            if g in self.index
        )
        weights = {}
        for i, count in counts.items():
            tf = 1.0 + math.log(count) if self.sublinear_tf else float(count)
            weights[i] = tf * self.idf[i]
        if self.normalize_l2:
            norm = math.sqrt(sum(w * w for w in weights.values()))
            if norm > 0:
                weights = {i: w / norm for i, w in weights.items()}
        return weights

    def predict_proba(self, text):
        weights = self.features(tokenize(text))
        scores = []
        for c in range(len(self.classes)):
            log_prob = self.feature_log_prob[c]
            scores.append(
                self.class_log_prior[c] + sum(w * log_prob[i] for i, w in weights.items())
            )
        top = max(scores)
        exps = [math.exp(s - top) for s in scores]
        total = sum(exps)
        return [e / total for e in exps]

    def predict(self, text):
        probs = self.predict_proba(text)
        return self.classes[probs.index(max(probs))], probs

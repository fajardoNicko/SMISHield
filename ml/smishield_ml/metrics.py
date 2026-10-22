"""Evaluation metrics for Chapter 4 (confusion matrix, accuracy, P/R/F1)."""

from sklearn.metrics import accuracy_score, confusion_matrix, precision_recall_fscore_support

from . import CLASSES


def _safe_div(a, b):
    return a / b if b else 0.0


def manuscript_scheme(cm):
    """TP/TN/FP/FN exactly as laid out in Figure 19 of the research plan.

    Rows are actual and columns predicted, in Safe, Suspicious, High Risk order.
    Safe -> Safe is TN; a correct Suspicious or High Risk is TP; predicting a
    higher risk than the actual one is FP; predicting a lower risk is FN.
    """
    tn = cm[0][0]
    tp = cm[1][1] + cm[2][2]
    fp = cm[0][1] + cm[0][2] + cm[1][2]
    fn = cm[1][0] + cm[2][0] + cm[2][1]
    precision = _safe_div(tp, tp + fp)
    recall = _safe_div(tp, tp + fn)
    return {
        "TP": int(tp), "TN": int(tn), "FP": int(fp), "FN": int(fn),
        "accuracy": _safe_div(tp + tn, tp + tn + fp + fn),
        "precision": precision,
        "recall": recall,
        "f1": _safe_div(2 * precision * recall, precision + recall),
    }


def evaluate(y_true, y_pred):
    labels = list(CLASSES)
    cm = confusion_matrix(y_true, y_pred, labels=labels)
    p, r, f, s = precision_recall_fscore_support(y_true, y_pred, labels=labels, zero_division=0)
    per_class = {
        label: {"precision": float(p[i]), "recall": float(r[i]), "f1": float(f[i]), "support": int(s[i])}
        for i, label in enumerate(labels)
    }
    averages = {}
    for avg in ("macro", "weighted"):
        ap, ar, af, _ = precision_recall_fscore_support(
            y_true, y_pred, labels=labels, average=avg, zero_division=0
        )
        averages[avg] = {"precision": float(ap), "recall": float(ar), "f1": float(af)}

    return {
        "labels": labels,
        "confusion_matrix": cm.tolist(),
        "accuracy": float(accuracy_score(y_true, y_pred)),
        "per_class": per_class,
        "macro_avg": averages["macro"],
        "weighted_avg": averages["weighted"],
        "manuscript_scheme": manuscript_scheme(cm.tolist()),
    }

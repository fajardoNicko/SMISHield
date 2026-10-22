"""Classify messages with the exported model, the same way the app does.

    python ml/predict.py "URGENT! Your GCash account will be suspended. Verify at gcash-verify.xyz"
    python ml/predict.py            (then type messages, one per line; Ctrl+Z / Ctrl+D to stop)
"""

import argparse
import sys
from pathlib import Path

from smishield_ml.exported_model import ExportedModel
from smishield_ml.preprocess import tokenize

DEFAULT_MODEL = Path(__file__).resolve().parent.parent / "app" / "assets" / "model" / "smishield_model.json"


def show(model, text):
    label, probs = model.predict(text)
    print(f"\n{text}")
    print(f"  tokens: {' '.join(tokenize(text))}")
    print(f"  => {label}   " + "  ".join(f"{c}: {p:.1%}" for c, p in zip(model.classes, probs)))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("messages", nargs="*")
    parser.add_argument("--model", type=Path, default=DEFAULT_MODEL)
    args = parser.parse_args()

    model = ExportedModel.load(args.model)
    if model.data["dataset"].get("is_placeholder"):
        print("(model was trained on PLACEHOLDER data)")
    for text in args.messages or (line.strip() for line in sys.stdin if line.strip()):
        show(model, text)


if __name__ == "__main__":
    main()

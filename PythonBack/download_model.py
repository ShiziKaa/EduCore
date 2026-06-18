import argparse
import os
import sys

from sentence_transformers import SentenceTransformer


def main() -> int:
    parser = argparse.ArgumentParser(description="Download EduCore embedding model")
    parser.add_argument(
        "--target",
        required=True,
        help="Path to EduCore_DB folder",
    )
    args = parser.parse_args()

    target = os.path.abspath(args.target)
    models_path = os.path.join(target, "models")
    os.makedirs(models_path, exist_ok=True)

    os.environ["SENTENCE_TRANSFORMERS_HOME"] = models_path
    os.environ["HF_HOME"] = models_path
    os.environ.setdefault("HF_HUB_DISABLE_PROGRESS_BARS", "1")

    print(f"Downloading model into: {models_path}")
    SentenceTransformer("intfloat/multilingual-e5-base", device="cpu")

    total_bytes = 0
    for root, _, files in os.walk(models_path):
        for name in files:
            total_bytes += os.path.getsize(os.path.join(root, name))

    total_gb = total_bytes / (1024 ** 3)
    print(f"Model downloaded successfully. Total size: {total_gb:.2f} GB")
    if total_bytes < 500 * 1024 * 1024:
        print("WARNING: model looks incomplete (<500 MB). Check internet connection.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

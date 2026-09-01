import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pandas as pd
from sklearn.model_selection import train_test_split

ROOT = Path("data")
RAW_DIR = Path("raw_downloads")
VAL_SPLIT = 0.2
SEED = 42


def run(cmd):
    print(f"$ {' '.join(cmd)}")
    subprocess.run(cmd, check=True)


# ---------------------------------------------------------------------
# 1. HAM10000 (Kaggle)
# ---------------------------------------------------------------------
def fetch_ham10000():
    dest = RAW_DIR / "ham10000"
    dest.mkdir(parents=True, exist_ok=True)

    zip_path = dest / "skin-cancer-mnist-ham10000.zip"
    if not zip_path.exists():
        run([
            "kaggle", "datasets", "download",
            "-d", "kmader/skin-cancer-mnist-ham10000",
            "-p", str(dest),
        ])
    
    import zipfile
    print(f"Extracting {zip_path}...")
    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        zip_ref.extractall(dest)

    meta_csv = next(dest.glob("HAM10000_metadata.csv"))
    df = pd.read_csv(meta_csv)

    # image files are split across two folders in the original zip
    img_dirs = [dest / "HAM10000_images_part_1", dest / "HAM10000_images_part_2"]

    label_map = {
        "akiec": "actinic_keratosis",
        "bcc": "basal_cell_carcinoma",
        "bkl": "benign_keratosis",
        "df": "dermatofibroma",
        "mel": "melanoma",
        "nv": "melanocytic_nevus",
        "vasc": "vascular_lesion",
    }
    df["label"] = df["dx"].map(label_map)
    _organize(df, image_id_col="image_id", label_col="label",
              img_dirs=img_dirs, ext=".jpg")


# ---------------------------------------------------------------------
# 2. ISIC Archive (isic-cli)
# ---------------------------------------------------------------------
def fetch_isic(collection="ISIC 2020"):
    dest = RAW_DIR / "isic"
    dest.mkdir(parents=True, exist_ok=True)

    meta_csv = dest / "metadata.csv"
    if not meta_csv.exists():
        run(["isic", "metadata", "download",
             "--collections", collection, "-o", str(meta_csv)])

    img_dir = dest / "images"
    if not img_dir.exists() or not any(img_dir.iterdir()):
        run(["isic", "image", "download", "-o", str(img_dir),
             "--search", f'collections:"{collection}"'])

    df = pd.read_csv(meta_csv)
    # ISIC metadata usually has a 'diagnosis' column; fall back gracefully
    label_col = "diagnosis" if "diagnosis" in df.columns else df.columns[1]
    df = df.dropna(subset=[label_col])
    df["label"] = df[label_col].astype(str).str.replace(" ", "_").str.lower()
    _organize(df, image_id_col="isic_id" if "isic_id" in df.columns else df.columns[0],
              label_col="label", img_dirs=[img_dir], ext=".jpg")


# ---------------------------------------------------------------------
# Shared helper: sort images into data/train/<class>/ and data/val/<class>/
# ---------------------------------------------------------------------
def _organize(df, image_id_col, label_col, img_dirs, ext):
    train_df, val_df = train_test_split(
        df, test_size=VAL_SPLIT, stratify=df[label_col], random_state=SEED
    )

    for split_name, split_df in [("train", train_df), ("val", val_df)]:
        for _, row in split_df.iterrows():
            image_id = str(row[image_id_col])
            label = str(row[label_col])
            if not label or label == "nan":
                continue

            out_dir = ROOT / split_name / label
            out_dir.mkdir(parents=True, exist_ok=True)

            src = None
            for d in img_dirs:
                candidate = d / f"{image_id}{ext}"
                if candidate.exists():
                    src = candidate
                    break
            if src is None:
                continue

            dst = out_dir / f"{image_id}{ext}"
            if not dst.exists():
                shutil.copy2(src, dst)

    print(f"Done. Classes: {sorted(df[label_col].dropna().unique())}")
    print(f"Train images: {len(train_df)} | Val images: {len(val_df)}")


# ---------------------------------------------------------------------
# Datasets that require manual download (license/registration gated) -
# no public CLI or API to script around this legally.
# ---------------------------------------------------------------------
MANUAL_DATASETS = {
    "DermNet": {
        "url": "https://www.kaggle.com/datasets/shubhamgoel27/dermnet",
        "note": "Clinical (non-dermoscopic) images across ~23 disease classes. "
                "Download via Kaggle CLI same as HAM10000, dataset slug: "
                "shubhamgoel27/dermnet",
    },
    "Fitzpatrick17k": {
        "url": "https://github.com/mattgroh/fitzpatrick17k",
        "note": "Requires filling out a request form on the repo before "
                "the image URLs list is released.",
    },
    "PAD-UFES-20": {
        "url": "https://data.mendeley.com/datasets/zr7vgbcyr2/1",
        "note": "Smartphone-camera skin lesion images, direct download "
                "available on Mendeley Data, no login required.",
    },
}


def print_manual_datasets():
    print("\nDatasets not auto-fetched by this script (manual step required):")
    for name, info in MANUAL_DATASETS.items():
        print(f"  - {name}: {info['url']}\n      {info['note']}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--dataset", choices=["ham10000", "isic", "all"], default="all",
        help="which dataset to pull",
    )
    parser.add_argument(
        "--isic-collection", default="ISIC 2020",
        help="ISIC collection name to pull (only used with isic/all)",
    )
    args = parser.parse_args()

    ROOT.mkdir(exist_ok=True)
    RAW_DIR.mkdir(exist_ok=True)

    try:
        if args.dataset in ("ham10000", "all"):
            fetch_ham10000()
        if args.dataset in ("isic", "all"):
            fetch_isic(args.isic_collection)
    except subprocess.CalledProcessError as e:
        print(f"A download command failed: {e}", file=sys.stderr)
        sys.exit(1)

    print_manual_datasets()
    print(f"\nAll set. Your PyTorch-ready folders are under: {ROOT.resolve()}")
    print('Load with: torchvision.datasets.ImageFolder("data/train", ...)')

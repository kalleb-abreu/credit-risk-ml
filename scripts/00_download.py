"""Download datasets for the credit-risk-ml project.

UCI datasets are fetched via ucimlrepo. For each dataset the following files
are written to data/raw/<dest_dir>/:

    features.csv      — feature matrix (X)
    targets.csv       — target column(s) (y)
    metadata.json     — dataset-level metadata
    variables.csv     — per-variable info (name, role, type, description, …)

Kaggle datasets require manual download — instructions are printed.

Usage:
    uv run scripts/00_download.py
"""

import io
import json
import urllib.request
import zipfile
from pathlib import Path

from ucimlrepo import fetch_ucirepo

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"


def download_uci(name: str, uci_id: int, dest_dir: str) -> None:
    dest = RAW / dest_dir
    sentinel = dest / "features.csv"
    if sentinel.exists():
        print(f"[skip] {name} — already present")
        return

    print(f"[download] {name} ...")
    dataset = fetch_ucirepo(id=uci_id)
    dest.mkdir(parents=True, exist_ok=True)

    dataset.data.features.to_csv(dest / "features.csv", index=False)
    dataset.data.targets.to_csv(dest / "targets.csv", index=False)
    dataset.variables.to_csv(dest / "variables.csv", index=False)

    metadata = dataset.metadata.__dict__ if hasattr(dataset.metadata, "__dict__") else dict(dataset.metadata)
    with open(dest / "metadata.json", "w") as f:
        json.dump(metadata, f, indent=2, default=str)

    print(f"  {len(dataset.data.features):,} rows × {len(dataset.data.features.columns)} features → {dest.relative_to(ROOT)}/")


def download_zip(name: str, url: str, dest_dir: str, sentinel: str) -> None:
    dest = RAW / dest_dir
    if (dest / sentinel).exists():
        print(f"[skip] {name} — already present")
        return

    print(f"[download] {name} ...")
    with urllib.request.urlopen(url) as r:
        data = r.read()
    dest.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        names = z.namelist()
        z.extractall(dest)
    print(f"  extracted {len(names)} files → {dest.relative_to(ROOT)}/")


def print_kaggle_instructions(name: str, url: str, dest_dir: str, files: list[str]) -> None:
    dest = RAW / dest_dir
    if all((dest / f).exists() for f in files):
        print(f"[skip] {name} — already present")
        return

    slug = url.rstrip("/").split("/")[-1]
    kind = "competitions" if "competitions" in url else "datasets"
    cli = f"kaggle {kind} download -c {slug} -p data/raw/{dest_dir} --unzip"

    print(f"""
[manual] {name}
  Source : {url}
  Target : data/raw/{dest_dir}/
  Options:
    Browser   : visit the URL above and download manually
    Kaggle CLI: {cli}
  Expected files:""")
    for f in files:
        print(f"    data/raw/{dest_dir}/{f}")


if __name__ == "__main__":
    # --- UCI Portuguese Bank Marketing (id=222) -------------------------------
    download_uci(
        name="UCI Portuguese Bank Marketing",
        uci_id=222,
        dest_dir="uci-portuguese-bank-marketing",
    )

    # --- UCI Taiwan Credit Card Default (id=350) ------------------------------
    download_uci(
        name="UCI Taiwan Credit Card Default",
        uci_id=350,
        dest_dir="uci-taiwan-credit-card",
    )

    # --- UCI South German Credit (id=573) -------------------------------------
    download_zip(
        name="UCI South German Credit",
        url="https://archive.ics.uci.edu/static/public/573/south+german+credit+update.zip",
        dest_dir="uci-south-german-credit",
        sentinel="SouthGermanCredit.asc",
    )

    # --- UCI Australian Credit Approval (id=143) ------------------------------
    download_uci(
        name="UCI Australian Credit Approval",
        uci_id=143,
        dest_dir="uci-australian-credit-approval",
    )

    # --- Kaggle: ULB Credit Card Fraud ----------------------------------------
    print_kaggle_instructions(
        name="ULB Credit Card Fraud",
        url="https://www.kaggle.com/datasets/mlg-ulb/creditcardfraud",
        dest_dir="ulb-credit-card-fraud-detection",
        files=["creditcard.csv"],
    )

    # --- Kaggle: IEEE-CIS Fraud Detection -------------------------------------
    print_kaggle_instructions(
        name="IEEE-CIS Fraud Detection",
        url="https://www.kaggle.com/competitions/ieee-fraud-detection",
        dest_dir="ieee-cis-fraud-detection",
        files=["train_transaction.csv", "train_identity.csv"],
    )

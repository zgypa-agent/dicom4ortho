"""Export the reviewed Python terminology lock without fetching upstream sources.

The Swift port needs the same reviewed clinical mappings without a Python runtime.
JSON is a data boundary, not a shared executable implementation or a new resolver.
"""

import argparse
from dataclasses import asdict
import hashlib
import importlib
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]


def export_terminology() -> str:
    """Return deterministic JSON containing all reviewed codes, image types, and views."""
    sys.path.insert(0, str(ROOT / "python"))
    try:
        terminology = importlib.import_module("dicom4ortho._generated_codes")
    finally:
        sys.path.pop(0)

    lock_path = ROOT / "python/dicom4ortho/_generated_codes.py"
    payload = {
        "schema_version": 1,
        "source_lock_sha256": hashlib.sha256(lock_path.read_bytes()).hexdigest(),
        "source_provenance": terminology.SOURCE_PROVENANCE,
        "codes": {key: asdict(value) for key, value in terminology.CODES.items()},
        "image_types": {key: asdict(value) for key, value in terminology.IMAGE_TYPES.items()},
        "views": {key: asdict(value) for key, value in terminology.VIEWS.items()},
    }
    return json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def main() -> None:
    """Write an explicit destination, or check its committed contents without modifying it."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--check", action="store_true")
    arguments = parser.parse_args()
    rendered = export_terminology()
    if arguments.check:
        if not arguments.output.is_file() or arguments.output.read_text(encoding="utf-8") != rendered:
            parser.exit(1, f"Terminology export differs: {arguments.output}\n")
    else:
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        arguments.output.write_text(rendered, encoding="utf-8")


if __name__ == "__main__":
    main()

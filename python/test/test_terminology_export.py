"""Keep the Swift resource aligned with the reviewed terminology lock, offline."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
EXPORTER = ROOT / "tools/export_terminology.py"
RESOURCE = ROOT / "apple/Sources/DICOM4Ortho/Resources/terminology.json"


class TestTerminologyExport(unittest.TestCase):
    def test_committed_export_matches_lock(self):
        subprocess.run([sys.executable, str(EXPORTER), str(RESOURCE), "--check"], check=True)
        exported = json.loads(RESOURCE.read_text(encoding="utf-8"))
        self.assertEqual(len(exported["codes"]), 83)
        self.assertEqual(len(exported["image_types"]), 73)
        self.assertEqual(len(exported["views"]), 73)
        self.assertIsNone(exported["views"]["IV29"]["view_code"])

    def test_export_is_deterministic_and_check_does_not_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "terminology.json"
            command = [sys.executable, str(EXPORTER), str(output)]
            subprocess.run(command, check=True)
            self.assertEqual(output.read_bytes(), RESOURCE.read_bytes())
            output.write_text("changed", encoding="utf-8")
            result = subprocess.run(command + ["--check"], capture_output=True, check=False)
            self.assertEqual(result.returncode, 1)
            self.assertEqual(output.read_text(encoding="utf-8"), "changed")


if __name__ == "__main__":
    unittest.main()

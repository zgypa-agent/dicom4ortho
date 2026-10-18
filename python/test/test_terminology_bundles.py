"""One maintenance command renders both ports; normal tests remain offline."""

from dataclasses import asdict
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from dicom4ortho import _generated_codes as lock
from tools import generate_codes as generator


ROOT = Path(__file__).resolve().parents[2]


class TestTerminologyBundles(unittest.TestCase):
    """Guard shared clinical data without independently refreshing upstream terminology."""

    def test_bundled_json_matches_reviewed_python_artifact(self):
        payload = json.loads(generator.SWIFT_OUTPUT.read_text(encoding="utf-8"))
        self.assertEqual(payload["codes"], {key: asdict(code) for key, code in lock.CODES.items()})
        self.assertEqual(payload["image_types"],
                         {key: asdict(value) for key, value in lock.IMAGE_TYPES.items()})
        # JSON arrays represent the tuples in the Python runtime model.
        expected_views = json.loads(json.dumps({key: asdict(v) for key, v in lock.VIEWS.items()}))
        self.assertEqual(payload["views"], expected_views)
        self.assertEqual(payload["source_provenance"], lock.SOURCE_PROVENANCE)
        self.assertEqual(payload["source_lock_sha256"],
                         hashlib.sha256(generator.OUTPUT.read_bytes()).hexdigest())

    def test_command_generates_both_outputs_from_one_resolution(self):
        codes = {"Mouth": {"code": "123851003", "scheme": "SCT", "meaning": "Mouth"}}
        image_types = {"EV01": {"keyword": "EV01", "abbreviation": "EO.TEST",
                                  "meaning": "Example", "display": "Example", "scheme": "99ADA1100"}}
        views = [{"keyword": "EV01", "AnatomicRegionSequence": "Mouth"}]
        with tempfile.TemporaryDirectory() as directory:
            python = Path(directory) / "python.py"
            swift = Path(directory) / "Resources/terminology.json"
            with mock.patch.object(generator, "OUTPUT", python), \
                 mock.patch.object(generator, "SWIFT_OUTPUT", swift), \
                 mock.patch.object(generator, "load_terminology", return_value=(codes, image_types, {})) as load, \
                 mock.patch.object(generator, "load_views", return_value=(views, {"sha256": "fixture"})), \
                 mock.patch.object(generator.sys, "argv", ["generate_codes.py"]):
                generator.main()
                load.assert_called_once()
                payload = json.loads(swift.read_text(encoding="utf-8"))
                self.assertEqual(payload["views"]["EV01"]["anatomic_region"], payload["codes"]["Mouth"])
                self.assertEqual(payload["source_lock_sha256"], hashlib.sha256(python.read_bytes()).hexdigest())
                before = python.read_bytes()
                swift.write_text("stale", encoding="utf-8")
                with mock.patch.object(generator.sys, "argv", ["generate_codes.py", "--check"]):
                    with self.assertRaisesRegex(SystemExit, "differs"):
                        generator.main()
                self.assertEqual(python.read_bytes(), before)
                self.assertEqual(swift.read_text(encoding="utf-8"), "stale")

    def test_json_renderer_preserves_all_committed_mappings(self):
        codes = {key: {"code": code.value, "scheme": code.scheme, "meaning": code.meaning}
                 for key, code in lock.CODES.items()}
        image_types = {
            key: {"keyword": key, "abbreviation": value.abbreviation, "meaning": value.meaning,
                  "display": value.code.meaning, "scheme": value.code.scheme}
            for key, value in lock.IMAGE_TYPES.items()
        }
        views = generator._parse_views(  # pylint: disable=protected-access
            (ROOT / "python/dicom4ortho/resources/views.csv").read_bytes())
        # The packaged CSV predates the reviewed lock's upstream IV29 correction.
        # It is a fixture, never the generator's maintenance source (see TERMINOLOGY.md).
        next(row for row in views if row["keyword"] == "IV29")["ViewCodeSequence"] = ""
        rendered = generator.generate_json(codes, image_types, views, lock.SOURCE_PROVENANCE,
                                            generator.OUTPUT.read_text(encoding="utf-8"))
        self.assertEqual(rendered, generator.SWIFT_OUTPUT.read_text(encoding="utf-8"))

    def test_render_failure_does_not_modify_either_destination(self):
        with tempfile.TemporaryDirectory() as directory:
            python = Path(directory) / "python.py"
            swift = Path(directory) / "terminology.json"
            python.write_text("python", encoding="utf-8")
            swift.write_text("swift", encoding="utf-8")
            with mock.patch.object(generator, "OUTPUT", python), \
                 mock.patch.object(generator, "SWIFT_OUTPUT", swift), \
                 mock.patch.object(generator, "load_terminology", return_value=({}, {}, {})), \
                 mock.patch.object(generator, "load_views", return_value=([], {})), \
                 mock.patch.object(generator, "generate_json", side_effect=ValueError("bad mapping")), \
                 mock.patch.object(generator.sys, "argv", ["generate_codes.py"]):
                with self.assertRaisesRegex(ValueError, "bad mapping"):
                    generator.main()
            self.assertEqual(python.read_text(encoding="utf-8"), "python")
            self.assertEqual(swift.read_text(encoding="utf-8"), "swift")

    def test_check_accepts_both_current_outputs_and_rejects_a_missing_port(self):
        with tempfile.TemporaryDirectory() as directory:
            python = Path(directory) / "python.py"
            swift = Path(directory) / "terminology.json"
            python.write_text("python", encoding="utf-8")
            swift.write_text("swift", encoding="utf-8")
            with mock.patch.object(generator, "build_outputs",
                                   return_value={python: "python", swift: "swift"}), \
                 mock.patch.object(generator.sys, "argv", ["generate_codes.py", "--check"]):
                generator.main()
                swift.unlink()
                with self.assertRaisesRegex(SystemExit, "terminology.json.*differs"):
                    generator.main()
                self.assertFalse(swift.exists())
                self.assertEqual(python.read_text(encoding="utf-8"), "python")

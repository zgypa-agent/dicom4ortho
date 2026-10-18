"""Independently decode synthetic outputs from the Swift encoding tests.

Requires a separate validation environment with pydicom 3, NumPy, Pillow,
pylibjpeg-libjpeg, pylibjpeg-openjpeg, and pyjpegls. JPEG XL uses libjxl's djxl,
not DICOMKit or its Swift codec dependencies. This is not an IOD validator.
"""

import argparse
from io import BytesIO
import json
from pathlib import Path
import subprocess
import sys
import tempfile

import numpy as np
import pydicom
# This standalone oracle requires pydicom 3, independently of the Python library's environment.
from pydicom.encaps import generate_frames  # pylint: disable=no-name-in-module
from PIL import Image


# Suffixes of the standard 1.2.840.10008.1.2 transfer syntax root.
ENCODINGS = {
    "explicit-le": ".1",
    "implicit-le": "",
    "jpeg-baseline": ".4.50",
    "jpeg-lossless": ".4.70",
    "jpeg-ls-lossless": ".4.80",
    "jpeg2000-lossless": ".4.90",
    "jpeg2000-lossy": ".4.91",
    "htj2k-lossless": ".4.201",
    "htj2k-rpcl": ".4.202",
    "htj2k-lossy": ".4.203",
    "jpeg-xl-lossless": ".4.110",
    "jpeg-xl-lossy": ".4.112",
    "rle": ".5",
}


def validate(directory: Path, jpeg_xl_decoder: str) -> list[dict]:
    """Check the full fixture matrix, requiring exact lossless sample reconstruction."""
    dimensions = json.loads((directory / "source.json").read_text(encoding="utf-8"))
    source = np.frombuffer((directory / "source.rgb").read_bytes(), dtype=np.uint8)
    source = source.reshape(dimensions["height"], dimensions["width"], 3)
    reports = []
    for name, suffix in ENCODINGS.items():
        dataset = pydicom.dcmread(directory / f"{name}.dcm")
        assert str(dataset.file_meta.TransferSyntaxUID) == "1.2.840.10008.1.2" + suffix, name
        assert dataset.SOPClassUID == "1.2.840.10008.5.1.4.1.1.77.1.4", name
        assert dataset.SOPClassUID == dataset.file_meta.MediaStorageSOPClassUID, name
        assert dataset.SOPInstanceUID == dataset.file_meta.MediaStorageSOPInstanceUID, name
        assert dataset.SOPInstanceUID.startswith("1.3.6.1.4.1.61741.11.2.4."), name
        assert (dataset.Rows, dataset.Columns, dataset.SamplesPerPixel) == source.shape, name
        is_lossy = name.endswith("lossy") or name == "jpeg-baseline"
        assert dataset.LossyImageCompression == ("01" if is_lossy else "00"), name
        if is_lossy:
            assert float(dataset.LossyImageCompressionRatio) > 0, name
            assert dataset.LossyImageCompressionMethod, name
            assert dataset.ImageType[0] == "DERIVED", name

        if name.startswith("jpeg-xl"):
            with tempfile.TemporaryDirectory() as temporary:
                encoded = Path(temporary) / "frame.jxl"
                decoded = Path(temporary) / "frame.png"
                encoded.write_bytes(next(generate_frames(dataset.PixelData)))
                subprocess.run([jpeg_xl_decoder, str(encoded), str(decoded)], check=True,
                               capture_output=True)
                pixels = np.asarray(Image.open(decoded))
        elif name == "jpeg-baseline":
            # Pillow uses an independent JPEG implementation and handles color conversion.
            frame = next(generate_frames(dataset.PixelData))
            pixels = np.asarray(Image.open(BytesIO(frame)).convert("RGB"))
        else:
            pixels = dataset.pixel_array

        assert pixels.shape == source.shape, name
        error = np.abs(pixels.astype(np.int32) - source)
        if not is_lossy:
            assert np.array_equal(pixels, source), f"{name}: lossless samples differ"
        reports.append({
            "encoding": name,
            "transfer_syntax": str(dataset.file_meta.TransferSyntaxUID),
            "photometric_interpretation": str(dataset.PhotometricInterpretation),
            "width": dataset.Columns,
            "height": dataset.Rows,
            "maximum_sample_error": int(error.max()),
            "mean_absolute_sample_error": float(error.mean()),
            "lossless_exact": not is_lossy,
        })
    return reports


def main() -> None:
    """Print measured results; lossy metrics are not clinical acceptability thresholds."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--jpeg-xl-decoder", default="djxl")
    parser.add_argument("--python-root", type=Path,
                        help="Also compare all 73 view mappings against this checkout's Python code")
    arguments = parser.parse_args()
    reports = validate(arguments.directory, arguments.jpeg_xl_decoder)
    if arguments.python_root is not None:
        compare_python_views(arguments.directory, arguments.python_root)
    print(json.dumps(reports, indent=2))


def compare_python_views(directory: Path, repository: Path) -> None:
    """Compare clinical sequences semantically, excluding generated identity and pixels."""
    sys.path.insert(0, str(repository / "python"))
    try:
        from dicom4ortho._generated_codes import VIEWS  # pylint: disable=import-outside-toplevel
        from dicom4ortho.m_orthodontic_photograph import (  # pylint: disable=import-outside-toplevel
            OrthodonticPhotograph,
        )
    finally:
        sys.path.pop(0)
    keywords = [
        "ImageComments", "SeriesDescription", "PatientOrientation", "ImageLaterality",
        "DeviceSequence", "AnatomicRegionSequence", "PrimaryAnatomicStructureSequence",
        "ViewCodeSequence", "AcquisitionContextSequence",
    ]
    for keyword in sorted(VIEWS):
        parameters = {"image_type": keyword}
        if keyword in ("IV28", "IV30", "EV40"):
            parameters["view_code_keyword"] = "projection_right"
        expected = OrthodonticPhotograph(**parameters).to_dataset()
        actual = pydicom.dcmread(directory / "views" / f"{keyword}.dcm")
        for attribute in keywords:
            if keyword in ("IV28", "IV30") and attribute == "PatientOrientation":
                # Intentional conformance correction: Python omits this unknown Type 2C value.
                assert attribute not in expected, keyword
                assert attribute in actual and len(actual.PatientOrientation) == 0, keyword
                continue
            assert (attribute in expected) == (attribute in actual), (keyword, attribute)
            if attribute in expected:
                tag = expected.data_element(attribute).tag
                left = pydicom.Dataset()
                right = pydicom.Dataset()
                left.add(expected[tag])
                right.add(actual[tag])
                assert left.to_json_dict() == right.to_json_dict(), (keyword, attribute)


if __name__ == "__main__":
    main()

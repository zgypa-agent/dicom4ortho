# DICOM4Ortho (Swift)

An in-development Swift port of dicom4ortho's DICOM materialization, not networking.
Requires Swift tools 6.4, Swift 6 language mode, iOS 18 or macOS 15. DICOM writing
and codecs use DICOMKit v2.7.0. See [development status and validation](../docs/SWIFT_PORT.md)
for the tested toolchain and current limitations.

## Package and usage

The SwiftPM manifest is at the repository root, not in this directory. The single
public library product is `DICOM4Ortho`. Required terminology is bundled offline.

```swift
import Foundation
import DICOM4Ortho

let materializer = try OrthodonticPhotograph()
var metadata = PhotographMetadata(imageType: "EV01")
metadata.patientID = "synthetic-001"
metadata.patientFamilyName = "Example"
metadata.patientGivenName = "Alex"
metadata.acquisitionDateTime = Date()
metadata.acquisitionTimeZone = TimeZone(secondsFromGMT: 0)!

let dicom = try materializer.materializeRGB8(
    pixels: Data([255, 0, 0]), width: 1, height: 1, metadata: metadata)
try dicom.write(to: URL(fileURLWithPath: "example.dcm"))
```

RGB input is interleaved RGB8 with exactly three bytes per pixel, without row padding
or alpha. Compression can be requested explicitly with `encoding`, for example
`.jpeg2000Lossless`, `.htj2kLossless`, or `.jpegXLLossless`. Lossy cases require
`quality` strictly between zero and one; quality is codec-specific, not a clinical
fidelity guarantee. All compressed outputs are serialized as Part 10 DICOM, not
standalone image containers. See `PhotographEncoding` for the current choices.

For an existing baseline color JPEG, use
`materializeJPEG(imageData:metadata:)` to preserve the original compressed bytes.
This entry point currently accepts only 8-bit, three-component SOF0 JPEGs with
component identifiers 1/2/3, interpreted as YCbCr as in the existing Python path.
It does not accept progressive JPEG, grayscale JPEG, MPO, or JP2. Automatic EXIF
metadata import has not been implemented yet; supply acquisition metadata explicitly.

Use the same `studyInstanceUID` and `seriesInstanceUID` across metadata values to
group photographs; each photograph needs its own `sopInstanceUID`. Initializers
generate UIDs under the existing dicom4ortho roots. The supplied final SOP UID is
kept for lossless and lossy creation. File Meta Information identifies the DICOMKit
serializer. No transport, delivery queue, or UID manifest is introduced.

`patientBirthDate` currently takes a DICOM DA string (`YYYYMMDD`) or an empty value.
Treatment progress uses `TreatmentProgress(event:eventDate:)`, where `eventDate`
is a validated `ClinicalDate`. The day offset is calculated from the acquisition
calendar date in `acquisitionTimeZone`, not from content/editing timestamps.
IV28, IV30, and EV40 require a `directionKeyword` such as `projection_right`.
IV29 omits an unknown direction rather than inventing one.
For IV28/IV30 an unknown Patient Orientation is emitted as an empty Type 2C element;
Python currently omits it. This is a documented conformance correction, not a
guessed orientation.

## Development

Run from the repository root:

```sh
swift test
python tools/export_terminology.py apple/Sources/DICOM4Ortho/Resources/terminology.json --check
```

The terminology maintenance command requires the Python package's dependencies;
normal Swift builds and runtime require no Python. Do not regenerate terminology
from live sources merely to build this package.

The port is not complete and is not a diagnostic-device certification. Pixel layouts
other than RGB8, the remaining import paths, and complete metadata validation are
still pending. Tests on synthetic inputs do not guarantee every input/codec combination.

## Licensing

dicom4ortho is MIT-licensed. DICOMKit is MIT-licensed and its source dependencies
have their own notices, including the J2KSwift, JLISwift, JLSwift, and JXLSwift
codec licenses. Retain the applicable upstream notices when redistributing those
components; the root project license does not replace their licenses.

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
PYTHONPATH=python python -m unittest test.test_terminology_bundles
```

The second command is an offline cross-port consistency check and requires the
Python development dependencies. Normal Swift builds and runtime require no Python.
For an intentional terminology refresh, `make update_codes` fetches once and
generates **both** artifacts; `make check_codes` checks both against upstream
without writing. There is no separate Swift export step. Do not refresh live
terminology merely to build this package. See [the pipeline](../docs/TERMINOLOGY.md).

## Source organization and design rationale

The target is small enough for a flat source directory. Each main public type is
in a correspondingly named UpperCamelCase `.swift` file; this applies equally to
structs and enums. Swift has no rule that enums go in `Enums.swift` or constants
in `Constants.swift`. File names describe the type or responsibility, not the
language construct:

- `PhotographMetadata.swift`: patient/acquisition context and final instance identity.
- `OrthodonticPhotograph.swift`: profile mapping and materialization orchestration.
- `OrthodonticPhotograph+JPEG.swift`: an extension adding JPEG preservation to that
  same type, using the common `Type+Feature.swift` convention, not a separate type.
- `PhotographEncoding.swift`: an enum named `PhotographEncoding`, representing output
  **policy**, not miscellaneous constants. It makes lossy intent and quality explicit;
  DICOMKit owns transfer syntaxes, standard UIDs, and codecs.
- `ClinicalDate.swift`, `TreatmentEvent.swift`, `TreatmentProgress.swift`: separate
  public value types. Calendar dates are distinct from instants, preventing timezone
  or daylight-saving changes from corrupting treatment-day offsets.
- `MaterializationError.swift`: profile/input errors, not a wrapper hiding codec or
  I/O error details.
- `Tag+Dental.swift`: internal `Tag` extension for three standard convenience members
  absent from DICOMKit, not a duplicate dictionary or private tags.
- `Terminology.swift`: resource decoding. Properties use Swift `lowerCamelCase` with
  explicit `CodingKeys` for the shared JSON's `snake_case` schema.

### Why an encoding enum when DICOMKit already defines transfer syntaxes?

A transfer syntax identifies a representation; it is not always a loss policy.
The general JPEG 2000, HTJ2K, and JPEG XL syntaxes may carry reversible or irreversible
data. `PhotographEncoding` restricts the initial RGB8 API to intentional, tested
choices and carries explicit quality for lossy cases. It does **not** define its
own numeric UID constants: the internal typed mapping uses DICOMKit's standard
`TransferSyntax` values. Public `transferSyntaxUID` returns their strings, so callers
do not need dependency types in API signatures.

DICOMKit's `CompressionManager` selects codecs by public string aliases; internal
`codec` is the adapter to that API. String dispatch is not exposed to callers.
Tests compare the UID written by the codec with the typed mapping. Independent
validation deliberately retains standard numeric UIDs as an oracle to avoid
validating a dependency against itself.

### API reference

Public declarations have DocC documentation describing formats, defaults, errors,
and clinical meaning. `Sources/DICOM4Ortho/DICOM4Ortho.docc` adds a module overview
and usage examples. A compatible Xcode documentation build can render these with
the generated Swift symbol graphs; the Markdown and declaration comments remain
readable directly in the source without installing a documentation plugin.

The port is not complete and is not a diagnostic-device certification. Pixel layouts
other than RGB8, the remaining import paths, and complete metadata validation are
still pending. Tests on synthetic inputs do not guarantee every input/codec combination.

## Licensing

dicom4ortho is MIT-licensed. DICOMKit is MIT-licensed and its source dependencies
have their own notices, including the J2KSwift, JLISwift, JLSwift, and JXLSwift
codec licenses. Retain the applicable upstream notices when redistributing those
components; the root project license does not replace their licenses.

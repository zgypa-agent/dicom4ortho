# ``DICOM4Ortho``

Create orthodontic visible-light DICOM instances from photographs and clinical metadata.

## Overview

The library implements orthodontic profile mapping and validation. DICOMKit owns
the DICOM dataset writer, transfer-syntax definitions, and image codecs. There is
no networking, camera framework, UI framework, Python runtime, or live terminology
download in this target. The implementation is still a partial port; consult the
repository's `apple/README.md` and `docs/SWIFT_PORT.md` for tested coverage and limitations.

### Create an uncompressed photograph

```swift
import Foundation
import DICOM4Ortho

let materializer = try OrthodonticPhotograph()
var metadata = PhotographMetadata(imageType: "EV01")
metadata.patientID = "synthetic-001"
metadata.patientFamilyName = "Example"
metadata.patientGivenName = "Alex"

let bytes = try materializer.materializeRGB8(
    pixels: Data([255, 0, 0]), width: 1, height: 1, metadata: metadata)
```

The result is a complete DICOM Part 10 file. Writing it to a file is optional;
the library also supports in-memory use. Input samples are row-major RGB8 without
row padding or alpha. Materialization does not validate every possible DICOM VR
constraint yet, and should not be mistaken for a complete conformance validator.

### Choose a representation deliberately

``PhotographEncoding`` is an output policy, not a second DICOM dictionary. It uses
DICOMKit's typed transfer syntaxes. Its lossy cases carry quality explicitly because
a general JPEG 2000, HTJ2K, or JPEG XL UID alone does not establish whether the
codestream is reversible. Quality is codec-specific, not a diagnostic guarantee.

```swift
let compressed = try materializer.materializeRGB8(
    pixels: Data([255, 0, 0]), width: 1, height: 1,
    metadata: metadata, encoding: .jpeg2000Lossless)
```

Preserving an existing JPEG is a different operation from encoding pixels. Use
``OrthodonticPhotograph/materializeJPEG(imageData:metadata:)`` for the currently
supported baseline color JPEG subset. It preserves the compressed data rather
than decoding and recompressing it. EXIF fallback is not implemented yet.

### Preserve identity and clinical time

``PhotographMetadata`` generates independent study, series, and instance UIDs.
For multiple photographs in a study/series, supply shared study/series UIDs while
keeping distinct SOP Instance UIDs. The final SOP UID is retained during creation,
including when an internal codec uses an uncompressed intermediate representation.

``ClinicalDate`` is a Gregorian calendar date, not a timestamp. ``TreatmentProgress``
combines one with a ``TreatmentEvent``; materialization calculates the offset in days
from the acquisition calendar date in `acquisitionTimeZone`. Missing acquisition
dates and events after acquisition are rejected. Zero-day offsets remain valid.
Editing timestamps and content creation times cannot substitute for acquisition.

### Keep terminology synchronized without runtime coupling

One maintenance command, `make update_codes`, resolves terminology once and renders
the Python module and Swift resource together. ``Terminology`` decodes the committed
SwiftPM bundle offline. Each distributed package contains its own generated data,
but the clinical definitions are maintained only in the shared generator/upstream
profile sources. Neither implementation loads the other's runtime code.

## Topics

### Materialization

- ``OrthodonticPhotograph``
- ``PhotographMetadata``
- ``PhotographEncoding``
- ``MaterializationError``

### Clinical context

- ``ClinicalDate``
- ``TreatmentEvent``
- ``TreatmentProgress``

### Offline terminology

- ``Terminology``

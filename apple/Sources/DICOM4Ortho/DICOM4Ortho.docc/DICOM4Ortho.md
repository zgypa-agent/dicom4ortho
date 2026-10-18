# ``DICOM4Ortho``

Create orthodontic visible-light DICOM instances from photographs and clinical metadata.

## Overview

The library implements orthodontic profile mapping and validation. DICOMKit owns
the DICOM dataset writer, transfer-syntax definitions, and image codecs. There is
no networking, camera framework, UI framework, Python runtime, or live terminology
download in this target. This guide owns Swift API usage; see the repository's
[development record](https://github.com/open-ortho/dicom4ortho/blob/develop/apple/Documentation/Development.md)
for qualification results and outstanding work, and the
[project README](https://github.com/open-ortho/dicom4ortho#introduction)
for shared standards and clinical background. The port is incomplete.

### Create an uncompressed photograph

```swift
import Foundation
import DICOM4Ortho

var metadata = PhotographMetadata(imageType: "EV01")
metadata.patientID = "synthetic-001"
metadata.patientFamilyName = "Example"
metadata.patientGivenName = "Alex"

var photo = try OrthodonticPhotograph(
    rgb8: Data([255, 0, 0]), width: 1, height: 1, metadata: metadata)
let bytes = try photo.dicomData() // in-memory Part 10 serialization
try photo.save(to: URL(fileURLWithPath: "example.dcm"))
```

Construction creates a photograph object, not serialized output or a file.
``OrthodonticPhotograph/dicomData()`` returns complete Part 10 bytes;
``OrthodonticPhotograph/save(to:)`` serializes and writes a local file.
The `dataSet` property exposes the DICOMKit dataset for inspection and advanced
edits before serialization. Copies have Swift value semantics; dataset edits do
not edit another copy. Callers must maintain profile and pixel-layout consistency
when bypassing typed metadata. File Meta Information is regenerated at serialization
so edited SOP Instance identity remains synchronized. Input samples are row-major RGB8 without
row padding or alpha. Materialization does not validate every possible DICOM VR
constraint yet, and should not be mistaken for a complete conformance validator.

### Choose a representation deliberately

``PhotographEncoding`` is an output policy, not a second DICOM dictionary. It uses
DICOMKit's typed transfer syntaxes. Its lossy cases carry quality explicitly because
a general JPEG 2000, HTJ2K, or JPEG XL UID alone does not establish whether the
codestream is reversible. Quality is codec-specific, not a diagnostic guarantee.

```swift
let compressed = try OrthodonticPhotograph(
    rgb8: Data([255, 0, 0]), width: 1, height: 1,
    metadata: metadata, encoding: .jpeg2000Lossless)
```

Preserving an existing JPEG is a different operation from encoding pixels. Use
``OrthodonticPhotograph/init(jpeg:metadata:)`` for the currently
supported baseline color JPEG subset. It preserves the compressed data rather
than decoding and recompressing it. EXIF fallback is not implemented yet.
The accepted JPEG input is an 8-bit, three-component SOF0 stream with component
identifiers 1/2/3, interpreted as YCbCr. Progressive or grayscale JPEG, MPO, and JP2
are not supported by this entry point. Supply acquisition metadata explicitly.
Use ``OrthodonticPhotograph/init(contentsOf:metadata:)`` for a local file containing
the same supported JPEG subset. It checks content, not extensions, never fetches
remote URLs, and leaves output saving to a separate explicit operation.

### Preserve identity and clinical time

``PhotographMetadata`` generates independent study, series, and instance UIDs.
For multiple photographs in a study/series, supply shared study/series UIDs while
keeping distinct SOP Instance UIDs. The final SOP UID is retained during creation,
including when an internal codec uses an uncompressed intermediate representation.
Generated UIDs use dicom4ortho's registered roots, with DICOMKit providing suffixes.
File Meta Information identifies the DICOMKit serializer.

``ClinicalDate`` is a Gregorian calendar date, not a timestamp. ``TreatmentProgress``
combines one with a ``TreatmentEvent``; materialization calculates the offset in days
from the acquisition calendar date in `acquisitionTimeZone`. Missing acquisition
dates and events after acquisition are rejected. Zero-day offsets remain valid.
Editing timestamps and content creation times cannot substitute for acquisition.

`patientBirthDate` takes a DICOM DA string (`YYYYMMDD`) or an empty value.
IV28, IV30, and EV40 require a `directionKeyword`, for example `projection_right`.
IV29 omits an unknown direction. IV28/IV30 emit an empty Type 2C Patient Orientation
where Python currently omits it; this is a conformance correction, not an invented
orientation. Complete metadata validation and pixel layouts beyond RGB8 remain pending.

### Keep terminology synchronized without runtime coupling

``Terminology`` decodes the committed SwiftPM resource bundle offline. Source
ownership, provenance, and the single cross-port generation workflow are documented
in the [shared terminology instructions](https://github.com/open-ortho/dicom4ortho#shared-terminology),
not maintained separately in this Swift guide.

## Topics

### Implementation rationale

- <doc:Design>

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

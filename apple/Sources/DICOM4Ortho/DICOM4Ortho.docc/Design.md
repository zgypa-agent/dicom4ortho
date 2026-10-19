# Source organization and design

Why the Swift target separates clinical context, mapping, and codec policy.

## Overview

This article explains the current implementation. It is not the authority for the
shared API contract: logical shared-record ownership and partial construction need
further work before this Swift value-type model satisfies that draft contract.

The target is small enough for a flat source directory. Each main public type has
a same-named UpperCamelCase `.swift` file, whether it is a struct or enum. Extension
files use `Type+Feature.swift`. Names describe responsibilities, not language constructs:

Supplemental contributor guides live in `apple/Documentation/` with UpperCamelCase
filenames. `Sources/` and `Tests/` are SwiftPM conventions; `Documentation/` is this
project's organization choice, not a directory name enforced by SwiftPM. API guides
remain in the target's `.docc` catalog so DocC can combine them with symbol comments.

| File | Responsibility |
| --- | --- |
| `PhotographMetadata.swift` | Patient/acquisition context and final instance identity |
| `OrthodonticPhotograph.swift` | One editable dataset with constructors and separate serialization/save operations |
| `PhotographProfile.swift` | Internal clinical mapping and RGB8 codec adapter |
| `PhotographProfile+JPEG.swift` | Internal JPEG-preservation extension |
| `PhotographEncoding.swift` | Explicit output policy, not miscellaneous constants |
| `ClinicalDate.swift`, `TreatmentEvent.swift`, `TreatmentProgress.swift` | Separate clinical value types |
| `MaterializationError.swift` | Profile/input errors without hiding codec or I/O failures |
| `Tag+Dental.swift` | Three standard convenience members absent from upstream, not private tags |
| `Terminology.swift` | Bundled data decoding; lowerCamelCase properties and explicit snake_case CodingKeys |

## Why an encoding enum?

``PhotographEncoding`` expresses intent and associated quality. A general JPEG 2000,
HTJ2K, or JPEG XL transfer syntax may carry either reversible or irreversible data;
the UID alone is not a loss policy. This type restricts the RGB8 entry point to
explicit tested choices rather than accepting arbitrary unsupported UIDs.

DICOMKit owns standard `TransferSyntax` values and numeric UIDs. The enum's internal
mapping uses those typed values, while `transferSyntaxUID` returns a string.
The photograph model exposes DICOMKit's `DataSet` for advanced edits, analogous to
Python's pydicom dataset; it does not invent another dataset representation. DICOMKit's
`CompressionManager` selects codecs by string alias; the internal `codec` property
adapts to that API, without exposing string dispatch to callers. No codec or UID
registry is reimplemented here.

Tests compare the written UID with the typed mapping. Independent validation
intentionally retains numeric UIDs as a separate oracle rather than testing the
dependency against itself.

## Clinical values and dependencies

Calendar dates are separate from timestamp instants to prevent timezone or
daylight-saving changes from corrupting elapsed-day offsets. Metadata holds
explicit context, not capture-session or consuming-application state. DICOMKit
provides serialization and codecs; the Python runtime is not involved.

Construction and serialization are separate, matching Python's photograph lifecycle
rather than giving a reusable builder the same name as a photograph. The internal
profile helper is not public API. Compression can require a private serialized
intermediate during construction because of the upstream codec API; uncompressed
RGB8 and preserved JPEG construction do not perform a Part 10 write/read round-trip.
`dicomData()` and `save(to:)` do not re-encode the stored samples or change identity.

DICOMKit was selected instead of maintaining a separate DCMTK/GDCM bridge or custom
DICOM writer. Compiler/platform minimums follow the selected functionality rather
than an arbitrary earlier Swift 6.0 requirement. A pinned release and an active
upstream do not establish conformance: independent decoding, profile checks, and
regression tests remain necessary. Encoding new data, decoding data, and preserving
an existing compressed stream are distinct capabilities.

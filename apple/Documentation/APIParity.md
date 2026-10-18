# Python/Swift API comparison

The Swift implementation is a partial port, not yet an API-compatible replacement.
This comparison describes existing code; it does not introduce a new API contract.

## Construction versus serialization

Python does not call `materialize()`. Its main model is
`dicom4ortho.m_orthodontic_photograph.OrthodonticPhotograph(**metadata)`, inheriting
from `PhotographBase` and `DicomBase`. It owns a pydicom dataset and can be edited
before `save(filename)` serializes it. `OrthodonticController` adds convenience
conversion methods that return that photograph model.

Swift now constructs a photograph value with `init(rgb8:width:height:metadata:encoding:)`
or `init(jpeg:metadata:)`. The value owns an editable DICOMKit `dataSet`.
`dicomData()` serializes it in memory and `save(to:)` writes a local file separately.
The earlier public `materializeRGB8`/`materializeJPEG` builder design was removed
before release, rather than retained as a second, conflicting lifecycle.

## Current correspondence

| Operation | Python | Swift |
| --- | --- | --- |
| Construct one photograph | `OrthodonticPhotograph(**metadata)` | Throwing photograph initializers owning an editable dataset |
| Convenience conversion | `OrthodonticController.convert_image_to_dicom4orthograph(metadata)` | No controller equivalent |
| Save one photograph | `photo.save(filename)` | `photo.save(to: URL)`; an explicit local destination is required |
| In-memory serialization | `photo.to_byte()` returns a file-like object | `photo.dicomData()` returns Foundation `Data` |
| In-memory encoded input | `input_image_bytes` with filename `None` | Baseline-color JPEG only through `init(jpeg:metadata:)` |
| File-based encoded input | `input_image_filename` | `init(contentsOf:metadata:)`; local baseline-color JPEG only |
| RGB8 pixels and explicit encoding | Image ingestion through Pillow/model | `init(rgb8:width:height:metadata:encoding:)`; broader codecs are intentional extensions |
| Clinical context | Metadata keyword arguments and setters | Typed `PhotographMetadata` supplied at construction; advanced dataset edits afterward |
| Date-based treatment progress | `set_treatment_progress_from_date()` and constructor metadata | `TreatmentProgress`/`ClinicalDate` with acquisition context |
| Study/series grouping | `OrthodonticStudy`, `OrthodonticSeries` | Manual shared UIDs only; helpers missing |
| Template construction and image-type identification | Existing Python model operations | Missing |
| EXIF fallback, additional imports, MWL mapping | Existing Python paths | Not ported |
| Delivery | Controller DIMSE/DICOMweb send paths | Intentionally excluded from this port |

The [Swift API guide](../Sources/DICOM4Ortho/DICOM4Ortho.docc/DICOM4Ortho.md) owns
usage examples and input contracts. The [Python guide](../../python/README.md)
owns Python usage. No Python method is being renamed or deprecated for Swift's sake.

## What API parity requires

Preserve equivalent operations, object lifecycle, metadata meaning, identity,
validation, and output semantics. Swift can use throwing initializers, value types,
argument labels, and lowerCamelCase instead of mechanically copying Python syntax.
Construction, dataset access, and separate save/serialization now correspond in
both languages. Swift copies have value semantics rather than Python object aliasing.
Swift does not yet offer Python's typed post-construction setters, other file import formats,
default output paths, study/series helpers, or templates, so full API parity is
still not established. Raw dataset edits do not recalculate clinical context.

Existing clinical parity checks cover all 73 mappings, not all public operations.
IV28/IV30's empty Patient Orientation correction and broader codec support are
explicit differences, recorded in the [validation history](Development.md).

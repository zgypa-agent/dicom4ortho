# Python/Swift API comparison

The Swift implementation is a partial port, not yet an API-compatible replacement.
This comparison describes existing code; it does not introduce a new API contract.

## Construction versus serialization

Python does not call `materialize()`. Its main model is
`dicom4ortho.m_orthodontic_photograph.OrthodonticPhotograph(**metadata)`, inheriting
from `PhotographBase` and `DicomBase`. It owns a pydicom dataset and can be edited
before `save(filename)` serializes it. `OrthodonticController` adds convenience
conversion methods that return that photograph model.

Swift currently gives the same type name to a different role: a reusable,
stateless-with-respect-to-images builder holding terminology.
`OrthodonticPhotograph().materializeRGB8(...)` or `materializeJPEG(...)` returns
serialized `Data`, not a photograph model. There is no separate editable instance
and save operation. That lifecycle/result-type difference is substantive; renaming
the methods would not fix it.

## Current correspondence

| Operation | Python | Swift |
| --- | --- | --- |
| Construct one photograph | `OrthodonticPhotograph(**metadata)` | No equivalent instance model; builder returns serialized bytes |
| Convenience conversion | `OrthodonticController.convert_image_to_dicom4orthograph(metadata)` | No controller equivalent |
| Save one photograph | `photo.save(filename)` | Caller writes returned Foundation `Data` |
| In-memory encoded input | `input_image_bytes` with filename `None` | Baseline-color JPEG only through `materializeJPEG` |
| RGB8 pixels and explicit encoding | Image ingestion through Pillow/model | `materializeRGB8`; broader output codec choices are intentional extensions |
| Clinical context | Metadata keyword arguments and setters | Typed `PhotographMetadata` supplied per call |
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
But an editable photograph plus a separate serialization operation is not equivalent
to a service that returns only serialized bytes. The Swift public model/lifecycle
needs alignment before declaring API parity; this documentation change does not
pretend to complete that redesign.

Existing clinical parity checks cover all 73 mappings, not all public operations.
IV28/IV30's empty Patient Orientation correction and broader codec support are
explicit differences, recorded in the [validation history](Development.md).

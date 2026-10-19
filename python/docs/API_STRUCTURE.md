# Python API structure and compatibility binding

Analysis date: **2026-10-19**. The language-neutral draft contract is maintained
in [docs/API_CONTRACT.md](https://github.com/open-ortho/dicom4ortho/blob/develop/docs/API_CONTRACT.md), not duplicated
as a second Python specification. This pass changes no Python/Swift runtime behavior.

## Assessment: coherent model, unevenly expressed boundaries

The existing API is not an arbitrary collection of setters. It implements a
**mutable DICOM working record that can be progressively enriched**. That explains
otherwise disconnected-looking features: empty construction, image-type templates,
individual patient properties, direct dataset access, worklist copying, explicit
preparation, and study/series objects that affect existing photographs.

The structure is implicit across inheritance, retained fields, setters, and controller
wrappers. Several responsibilities overlap and some error/preparation paths are
inconsistent. Those are specific maintenance risks, not evidence that production
users need a differently shaped API. Refactoring solely to replace mutable objects
with builders, rename fields, or match the current Swift implementation has no
demonstrated benefit and would move work to the consuming products.

## The underlying structure

```text
DicomBase                       Dataset, identity, common clinical attributes, output
  PhotographBase                Image ingestion/preservation, image provenance, EXIF
    OrthodonticPhotograph       View profile, type identification, clinical acquisition context

OrthodonticStudy -> OrthodonticSeries -> existing OrthodonticPhotograph objects
OrthodonticController           Conversion/batch/worklist/output conveniences around the models
```

These are responsibility boundaries, not a requirement that every language expose
this inheritance. The Python hierarchy can stay where it is. Codecs, serialization,
and dataset representations remain replaceable internals within those boundaries.

### Evidence and consequences

| Observed structure | Source evidence | Why it matters / what breaks if discarded |
| --- | --- | --- |
| Partial record construction | `PhotographBase.set_image()` logs/returns False without an image; `set_dicom_attributes_by_type_keyword()` tolerates unresolved types | Requiring pixels and a known view up front eliminates template and staged-enrichment use; C01 |
| Constructor metadata is a convenience input, not the sole editing interface | `OrthodonticPhotograph.__init__()` applies many property setters; tests construct both empty and populated records | Mandatory immutable metadata snapshots would force consumers to replace objects for ordinary corrections; C02 |
| Dataset-first interoperability | `to_dataset()` returns the live `_ds`; public type-code functions operate on supplied datasets | A closed wrapper would require new library features for every uncommon DICOM field or existing dataset integration; C02/C03 |
| Profile-based clinical enrichment | The view mapping assigns anatomy, orientation, devices, modifiers, acquisition context and labels | Generic image encoding alone cannot replace the orthodontic library; C03 |
| Classification and profile application are separate | Type-code property/get/set helpers versus `set_dicom_attributes_by_type_keyword()` | Updating a proprietary identifier must not silently assert a different whole anatomical profile; C03 |
| Source-aware metadata | EXIF fallback is loaded first, explicit acquisition overrides it, and later `prepare()` preserves explicit acquisition | Treating editing timestamps as acquisition or making fallback overwrite explicit dates changes treatment offsets; C04 |
| Distinct personnel roles | Provider properties target PhysiciansOfRecord; operator properties target OperatorsName; supplied MWL uses genuine referring-physician data | Combining these names loses clinical meaning despite superficially simpler metadata; C04 |
| Preserve the source photograph | JPEG and JPEG 2000 helpers keep compressed data, with JP2 unwrapping | A decode/re-encode-only interface loses evidence and adds unwanted loss; C05 |
| Prepare before some output paths | Base `prepare()` completes identities; photograph `prepare()` adds EXIF fallback; `save()` invokes them | Requiring a path at creation or treating preparation as an immutable commit prevents memory-only workflows and later edits; C06/C08 |
| Shared clinical grouping | Series retains photo references, study retains series references; output propagates shared IDs onto those objects | Grouping hidden copies leaves caller-held objects with different relationships from saved files; C07 |
| Controller delegates rather than defines a second model | Conversion helpers create/store/return `OrthodonticPhotograph`, then optionally call save | A second authoritative conversion/service API would split metadata behavior between two implementations; C10 |

Relevant source: [model.py](../dicom4ortho/model.py),
[m_orthodontic_photograph.py](../dicom4ortho/m_orthodontic_photograph.py),
[controller.py](../dicom4ortho/controller.py), [m_dent_oip.py](../dicom4ortho/m_dent_oip.py).
The [class diagram](class_diagram.puml) describes the current Python types.

## Python's existing binding remains supported

These are compatibility obligations to Python consumers, not mandatory Swift spellings:

| Concern | Existing Python binding retained |
| --- | --- |
| Construction | `OrthodonticPhotograph(**metadata)`, including empty/no-image and unresolved-type records |
| Inputs | Filename or encoded bytes; optional metadata dict; established field formats and defaults |
| Edits | Existing properties/setters, profile/direction/progress methods, raw dataset access |
| Type codes | Standalone dataset get/set helpers and the photograph property, preserving unrelated code items |
| Output | `prepare()`, `to_dataset()`, `to_byte()`, save methods, stored output destination, and load |
| Identity | Existing generation/recovery policy and roots; no silent shift to reject-only semantics |
| Grouping | Existing `OrthodonticSeries`/`OrthodonticStudy`, ordered live children, deferred propagation and save behavior |
| Convenience | Controller return values/state/path handling, CSV CLI and existing Python networking entry points |
| Legacy support | Current deprecated aliases/day-offset APIs and warnings until their existing removal policy is revisited separately |

No consumer has to adopt a new `PhotographMetadata` object, a renamed `dicomData`
method, or new controller hierarchy to use contract-aligned future functionality.
A useful additive helper can be introduced when it solves a concrete problem, not
as a prerequisite for blessing the existing object model. Transport remains available
in Python but is outside the Swift materialization contract.

### Boundaries to document rather than redesign

- **Dataset and model state:** the dataset is accessible, but selected view and
  progress also have retained state. High-level remapping can replace generated
  sequences. Arbitrary raw edits do not imply automatic reconstruction of that state.
  Automatic bidirectional synchronization would be a new architecture, not a small fix.
- **Metadata ordering:** constructor explicit acquisition beats EXIF; later explicit
  operations can overwrite earlier facts. MWL copying, equipment EXIF and profile
  descriptions do not share a universal "constructor always wins" rule. Specify
  each operation rather than imposing a global merge engine.
- **Incomplete versus valid-for-exchange:** a useful template can be constructed
  and inspected without being a complete IOD. `prepare()` is not a full validator,
  and saving a file does not certify clinical/profile conformance.
- **Preparation:** photograph `save()` currently invokes preparation more than once
  through its override/base calls. `to_byte()` repairs UIDs but does not invoke full
  photograph preparation. Existing callers may depend on those effects, so factoring
  them together requires evidence, not just shorter code.
- **Grouping timing:** series `add()` stores the same photo without assigning its
  parent UIDs; study `add()` sets the series' StudyUID; series `save()` propagates
  UID/description onto the same photos and uses their stored filenames. Moving all
  propagation into `add()` could overwrite metadata earlier than existing users expect.
- **Errors:** logging/no-op for an unknown view setter is not the same contract as
  throwing on a missing required direction or invalid treatment date. Existing
  distinctions must be understood before adding strict validation.

## Minimal-change work, not a wholesale refactor

| Candidate | Concrete consequence / smallest plausible action | Status |
| --- | --- | --- |
| Document responsibility and source precedence | Stops new features choosing inconsistent models; documentation plus characterization tests is sufficient now | This pass |
| Manufacturer getter uses lowercase attribute spelling | A caller may set Manufacturer successfully but fail to read it; fix getter spelling with a focused regression if approved | Small correctness candidate; not changed |
| Image-bytes setter does not implement its bytes contract | Source replacement/caching can fail or retain an old detected format; characterize accepted inputs and invalidate only affected cache before a narrow repair | Correctness candidate; compatibility review needed |
| Repeated or unequal preparation paths | Consolidation could alter EXIF/equipment output or identity timing, so retain behavior until call-order tests and production usage are checked | Not required for contract adoption |
| Known DICOM conformance problems | Omitting a required empty orientation or mislabeling a JPEG process can make exported instances invalid; fix the specific data rule with independent validation, not through a naming migration | Separate reviewed fixes |
| Grouping defaults and identity repair edge cases | Eager rewrites or stricter validation could change study relationships and filenames; add characterization before any targeted change | Not an aesthetic cleanup |
| Historical names, argument aliases, public base classes | Renaming/inheritance cleanup alone provides no new clinical capability and forces consumer edits | Keep; no refactor required |
| Future functionality | Implement at the existing image/profile/metadata/grouping/output responsibility boundary, maintaining the Python binding and contract scenarios | Guideline for new work |

The actual production products are not present in this repository. Source/tests
support this analysis, but do not prove which quirks those products depend on.
Compatibility-sensitive fixes should be checked against those callers; no "minor"
refactor is assumed safe merely because it changes few lines.

## Contract scenarios and existing evidence

[test_api_structure.py](../test/test_api_structure.py) characterizes the following
Python behavior without network or image-server dependencies:

- An empty record remains a mutable dataset handle; a known type can form an
  image-free template, and unresolved types retain independently supplied progress.
- Property edits preserve the other patient-name component; dataset access exposes
  the same record, not a detached snapshot.
- Preparation preserves explicit clinical dates and valid identities; missing or
  duplicate hierarchy identities recover without replacing SOP instance identity.
- Type-code replacement preserves unrelated code items.
- Groups retain ordered live objects and propagate relationships at the existing
  boundaries, without writing during `add()`.
- Controller conversion returns its stored model and infers its existing default
  output path without saving during conversion.

These are baseline characterization tests, **not** proof of complete DICOM conformance
or of the Swift binding. Existing [model tests](../test/test_models.py),
[photograph tests](../test/test_photography.py),
[terminology/profile tests](https://github.com/open-ortho/dicom4ortho/blob/develop/python/test/test_generated_codes.py), and
[JPEG 2000 tests](../test/test_jpeg2000.py) supply further clinical evidence.

Validation in this pass: **156 non-E2E tests run, 4 skipped, no failures**, using
the existing Python 3.10.16 environment (pydicom 2.4.5, pynetdicom 2.1.0). This
includes nine new working-record characterization tests. The source inventory and
documentation-link checks, error-only lint, wheel/source builds, and all nine tests
from an extracted standalone source archive pass. Network/Orthanc and Swift runtime
tests were not run in this pass; no runtime implementation was edited.

An exploratory newer Nix environment (Python 3.14.7, pydicom 3.0.2, pynetdicom 3.0.4)
ran the same suite but failed existing serialization and deprecation-warning checks
(3 failures, 6 errors). Its pynetdicom version is outside this project's `<3`
constraint, so it is not a qualified baseline. Runtime source was unchanged: do not
attribute those failures to the contract tests or silently fix them during an API
formalization. Separately qualifying newer dependencies is a functional maintenance
task, not an API-aesthetics justification.

## Consequences for Swift

The current Swift API is not a design authority. Preserve its useful types and
codec integration internally, but align its public behavior with working records,
templates, explicit edits/profile operations, image preservation, preparation,
and groups retaining the same logical records. A reference-type photograph is a
straightforward option, not a demand for identical Python memory management.

Swift does not need all 89 Python declarations, Python's dict syntax, every
deprecated alias, or exact warning text to satisfy the shared contract. Its binding
does need clear input, ownership, fallback, output, and recovery rules. The
[implementation inventory](https://github.com/open-ortho/dicom4ortho/blob/develop/apple/Documentation/APIParity.md) remains useful
for locating existing capabilities, not as a checklist to clone Python mechanically.
Refactoring Swift starts after review of this draft; no Swift API is changed here.

# Python/Swift implementation inventory

Reviewed **2026-10-19**, against the Python and Swift source at `eaa9969`.
This is a source inventory, **not the language-neutral API contract** and not a
declaration of conformance. The policy was revised after inventorying the surface:
the APIs need not be identical, and production Python does not need an aesthetic
rewrite. The [draft working-record contract](../../docs/API_CONTRACT.md)
formalizes the existing model. See [the Python structure analysis](../../python/docs/API_STRUCTURE.md)
for evidence and the least-change adoption path. No runtime behavior changes here.

## How to use this inventory

Keep Python's existing production binding compatible. Use the shared contract's
capabilities and semantics to design Swift, not a mechanical copy of every Python
declaration. An existing wrapper/helper can remain Python-only; a missing clinical
capability is still a gap. Status labels below compare current surfaces, not the
number of declarations Swift must add. Constructor shapes, native types, legacy
aliases, warning conventions, and method/property choices can differ between bindings
when documented. Clinical meaning and working-record ownership must remain clear.

- Core capabilities include working photographs/templates, edits and profile/code
  operations, study/series grouping, image ingestion, and **offline MWL dataset copying**.
- Networking, transport authentication, and delivery queues are excluded by the
  agreed scope. Copying an already supplied worklist is not a network operation.
- CLI/CSV wrappers, external validation wrappers, and unrelated legacy exports
  are inventoried below; where scope is uncertain, mark a decision rather than
  silently excluding them.
- Private underscore-prefixed helpers, pydicom/DICOMKit's complete APIs, and the
  terminology generator's development API are not port-facing APIs. Constructors
  and collection protocols are included despite Python's double-underscore spelling.
- An operation's defining class is listed once. `OrthodonticPhotograph` also inherits
  `PhotographBase` and `DicomBase` operations. Preserve Python compatibility there;
  Swift need not expose those base types or an identical accessor/helper inventory.

Statuses used in the tables:

| Status | Meaning |
| --- | --- |
| Partial | Related Swift functionality exists, but the complete Python contract does not |
| Missing | No public Swift equivalent; raw dataset editing is not a substitute for a typed operation |
| Difference | Observable behavior differs; resolution/review is needed, not presumed approval |
| Excluded | Explicitly outside the agreed networking/delivery scope |
| Decision | Surface exists, but a scope or Python-baseline defect decision is needed |

No row is marked fully equivalent merely because related DICOM tags match.
Signatures below omit `self` and type annotations; defaults are retained. Property
rows cover both getter and setter unless identified as read-only. Source-level
coverage is checked offline by `test.test_api_parity_mapping`; that check does not
prove behavioral equivalence or that proposed Swift names have been implemented.

Inventory totals: **89 declared operations/properties**, **26 consumed photograph
constructor keywords**, and **23 terminology fields**. Of the operation/property
rows, 53 are Missing, 27 Partial, 3 Difference, 5 Decision, and 1 Excluded. These
counts measure public surface, not percentage of functionality or implementation
effort; other differences are captured in the metadata/state/behavior sections.

## Source and type boundaries

| Python source/type | Current Swift counterpart | Assessment |
| --- | --- | --- |
| [model.py](../../python/dicom4ortho/model.py): `DicomBase`, `PhotographBase` | Internal `PhotographProfile`, plus public `OrthodonticPhotograph` | Helpers implement only part of the inherited public surface; they are not public base-type replacements |
| [m_orthodontic_photograph.py](../../python/dicom4ortho/m_orthodontic_photograph.py): `OrthodonticPhotograph` | `OrthodonticPhotograph` + `PhotographMetadata` | Construct/edit/serialize/save lifecycle exists, not full API parity |
| Same module: `OrthodonticSeries`, `OrthodonticStudy` | None | Missing types, collections, and deferred grouping/save behavior |
| [controller.py](../../python/dicom4ortho/controller.py): `OrthodonticController` | None | Convenience conversion and stateful `photo` surface missing |
| [m_dent_oip.py](../../python/dicom4ortho/m_dent_oip.py): `DicomCode`, `AdaImageType`, `OrthoView` | `Terminology.Code`, `Terminology.ImageType`, internal `Terminology.View` | Data snapshots agree; public construction/conversion/view access do not |
| [utils.py](../../python/dicom4ortho/utils.py) | Internal DICOMKit adapters | Public utility surface mostly absent |

Swift's current photograph is a **struct with value semantics**; Python photographs
are mutable reference objects. Copy independence is tested in Swift, but shared
working-record grouping requires caller-held handles to observe child edits (C07).
Swift therefore needs a public ownership-model change, not an assumption that its
current struct semantics define the contract. Explicit snapshot values remain useful.

## Contract capability map

Rule IDs refer to the [draft contract](../../docs/API_CONTRACT.md),
not new method signatures. This map replaces the earlier one-for-one spelling plan
when planning the Swift refactor.

| Contract | Existing Python structure | Current Swift / consequence |
| --- | --- | --- |
| C01 working record | Empty/model/image constructors and image-type templates | Requires pixels + recognized type; add partial construction, not another all-inputs-required builder |
| C02 dataset and edits | Live `to_dataset()` plus setters and profile/progress state | Mutable DataSet exists, but most clinical edits and explicit state ownership are absent |
| C03 profile/code enrichment | Profile mapper, independent type-code helpers, direction/progress operations | Constructor-only mapper; needs working-record operations and custom/unknown-type handling |
| C04 context/evidence | Explicit metadata, EXIF fallback, offline MWL, clinical roles/progress | Some constructor fields work; EXIF/MWL and progressive editing remain gaps; no universal new merge policy |
| C05 image evidence | File/byte ingestion and compressed-source preservation | RGB8/codecs and baseline JPEG work; imports/preservation incomplete; retain the codec implementation where useful |
| C06 identity | Completion/recovery before output with registered roots | Valid identities survive, but default recovery policy needs explicit selection/documentation, not automatic Python rejection changes |
| C07 groups | Ordered references, delayed parent-context propagation | Groups absent; struct-copy model must not group hidden snapshots of caller records |
| C08 prepare/output | Public prepare, dataset/byte/file output, retained paths | Byte/file operations exist, but no public preparation or partial-record workflow |
| C09 error distinctions | Incomplete records, warning/no-op compatibility, semantic and operational failures | Current strict constructors conflate some incomplete/invalid cases; Swift may use native errors without copying every warning/alias |
| C10 adapters | Existing controllers, CLI/CSV, diagnostics and legacy helpers | No need to port every wrapper to satisfy the core; keep Python wrappers, add Swift conveniences when they provide value |

## Constructors and input metadata

### Entry points

| Python operation | Status | Current Swift / remaining contract |
| --- | --- | --- |
| `DicomBase.__init__(**kwargs)` | Missing | No public generic base dataset constructor; see inherited API below |
| `PhotographBase.__init__(**kwargs)` | Missing | No public untyped photograph/template constructor |
| `OrthodonticPhotograph.__init__(**metadata)` | Partial | `init(rgb8:width:height:metadata:encoding:)`, `init(jpeg:metadata:)`, `init(contentsOf:metadata:)`; typed metadata is required, encoded imports are JPEG-only, no image-free construction |

Python accepts omitted images and omitted/unknown photograph types, logging and
leaving a partially populated dataset. Swift requires a supported nonempty image
and a recognized type. Python ignores unknown `**metadata` keys rather than rejecting
them. Those facts must be considered before promising interchangeable constructors.
An `input_pil_image` argument is mentioned in Python's docstring but is not read by
the implementation; it is not an implemented Pillow-image constructor contract.

### Every consumed constructor keyword

`kwargs` in the base class and `metadata` in the photograph class are combined here.
The inventory test detects newly consumed `.get(...)` keys so this table can be
updated intentionally. Controller-only keys are listed with their controllers below.

| Python constructor keyword | Status | Current Swift / default and format notes |
| --- | --- | --- |
| `input_image_filename` | Partial | `init(contentsOf:metadata:)` reads local baseline-color JPEG only; Python detects format from bytes and supports additional paths |
| `input_image_bytes` | Partial | `init(jpeg:metadata:)` for encoded JPEG; `rgb8` is an additional raw-sample API, not general encoded input |
| `output_image_filename` | Missing | No stored default destination; Swift always requires `save(to:)` |
| `dicom_mwl` | Missing | No supplied-worklist metadata mapping or retained worklist state |
| `sop_instance_uid` | Partial | `PhotographMetadata.sopInstanceUID`; both generate when omitted, but Python also replaces falsy input; Swift checks at construction/serialization |
| `image_type` | Difference | `imageType`, required by metadata initializer; both remove hyphens, but Swift throws on unresolved type and Python returns an incomplete model |
| `view_code_keyword` | Difference | `directionKeyword`; Python constructor uses it only for variable-direction views, whereas Swift applies an override to fixed-direction views too |
| `patient_firstname` | Partial | `patientGivenName`, default empty; no equivalent post-construction model property |
| `patient_lastname` | Partial | `patientFamilyName`, default empty; no equivalent post-construction model property |
| `patient_id` | Partial | `patientID`, default empty; Python setter coerces arbitrary values with `str()`, Swift accepts a `String` |
| `patient_sex` | Partial | `patientSex`, default empty, M/F/O and full labels normalized case-insensitively; setter and dynamic invalid-input behavior remain unmapped |
| `patient_birthdate` | Difference | Python constructor parses ISO `YYYY-MM-DD`, warns/ignores invalid values; Swift `patientBirthDate` accepts an unchecked DICOM DA `YYYYMMDD` string, default empty |
| `study_instance_uid` | Difference | `studyInstanceUID`; Python photograph overwrites generated base value with omitted `None` and repairs during prepare/serialization; Swift eagerly generates and rejects invalid/reused values |
| `series_instance_uid` | Difference | `seriesInstanceUID`; same repair-versus-reject/timing distinction as study identity |
| `study_description` | Missing | No typed field; Python sets this even when omitted (empty DICOM value), Swift does not create it |
| `series_description` | Partial | No typed field; Python constructor accepts it but a resolved profile overwrites it; Swift also writes the profile description |
| `dental_provider_firstname` | Partial | `providerGivenName`; supplied nonempty values populate Physicians of Record |
| `dental_provider_lastname` | Partial | `providerFamilyName`; no post-construction getter/setter equivalent |
| `operator_firstname` | Partial | `operatorGivenName`; supplied nonempty values populate Operators' Name |
| `operator_lastname` | Partial | `operatorFamilyName`; no post-construction getter/setter equivalent |
| `manufacturer` | Missing | Swift hardcodes an empty Manufacturer; no typed manufacturer input or EXIF fallback |
| `acquisition_datetime` | Partial | `acquisitionDateTime: Date?` + `acquisitionTimeZone`; Python accepts datetime or ISO datetime strings (aware/naive), explicit input overrides EXIF; Swift has no EXIF fallback |
| `treatment_event_type` | Partial | `TreatmentEvent` in `TreatmentProgress`; canonical concepts agree, deprecated string aliases and unknown-string error contract are not represented |
| `treatment_event_date` | Partial | `ClinicalDate` in `TreatmentProgress`; Python accepts date/datetime/ISO date strings; both reject future dates and absent acquisition for this calculation |
| `days_after_event` | Missing | Deprecated but supported in Python until v2; no Swift precomputed-day input |
| `burned_in_annotation` | Missing | Python default `NO` with caller override; Swift always writes `NO` |

`acquisitionTimeZone`, explicit raw RGB8 dimensions, and compression quality are Swift
additions, not replacements for the missing baseline inputs. Python constructor
progress ignores blank optional strings and rejects conflicting/partial event/date/day
combinations. Swift's combined typed value prevents some combinations, but that is
not a tested mapping of all accepted Python inputs and errors.

## Photograph-specific operations

| Python operation | Status | Current Swift / required equivalent |
| --- | --- | --- |
| `OrthodonticPhotograph.image_type_code_dataset` | Missing | Read/write property wraps the static get/set operations; not a `Terminology.ImageType` catalog lookup |
| `OrthodonticPhotograph.get_image_type_code_dataset(ds)` | Missing | Finds first View Code item with CID 4063 + extension flag `Y`; absent/not found logs and returns `None` |
| `OrthodonticPhotograph.set_image_type_code_dataset(ds, code_dataset, creator_uid=None)` | Missing | Mutates dataset and supplied code; preserves unrelated view items; sets extension metadata/local date, uses explicit/existing/fallback creator UID, `None` code is a no-op |
| `OrthodonticPhotograph.set_dicom_attributes_by_type_keyword(type_keyword=None)` | Partial | Construction-only mapping in internal profile helper; no remap operation, no stored `type_keyword`, no inference from embedded image-type code, different unknown/missing handling |
| `OrthodonticPhotograph.set_view_code(keyword)` | Partial | Constructor-only `directionKeyword`; no setter that replaces view sequence and reapplies modifiers; Python unknown keyword warns and leaves dataset unchanged, Swift throws |
| `OrthodonticPhotograph.set_treatment_progress(event_type, days)` | Missing | Python retains deprecated aliases/warnings and integer validation; the shared contract permits a new binding to use a typed date-first API without reproducing this legacy signature |
| `OrthodonticPhotograph.set_treatment_progress_from_date(event_type, event_date, acquisition_date=None)` | Partial | Constructor-only progress; missing mutating setter, acquisition-date override, and rebuilding context from current view/progress state |
| `OrthodonticPhotograph.is_extraoral()` | Missing | Predicate on stored type keyword starting with `EV`; not inferred from arbitrary dataset anatomy |
| `OrthodonticPhotograph.is_intraoral()` | Missing | Predicate on stored type keyword starting with `IV` |

Public instance state also includes `type_keyword` (initially empty),
`treatment_event_type`, `treatment_event_date`, and `days_after_event` (initially
`None`). Swift has only constructor metadata and the dataset; it does not retain
these properties or expose a computed equivalent. Raw Acquisition Context edits do
not implement progress setters or their validation/rebuild semantics.

## Inherited lifecycle, image, and serialization operations

| Python operation | Status | Current Swift / contract gap |
| --- | --- | --- |
| `DicomBase.set_file_meta()` | Partial | Writer regenerates File Meta automatically, not a callable equivalent; Python identifies dicom4ortho implementation, Swift identifies DICOMKit |
| `DicomBase.copy_mwl_tags(dicom_mwl=None)` | Missing | Offline copy of supplied MWL, with stored-worklist precedence, patient/study/procedure/request identifiers and personnel-role semantics; not excluded with networking |
| `DicomBase.set_time_captured(time_captured)` | Partial | Explicit constructor acquisition writes acquisition and content dates/times; no setter, no EXIF-precedence state |
| `DicomBase.save_implicit_little_endian(filename=None)` | Partial | `.implicitLittleEndian` at creation; cannot choose syntax on an existing photograph or use stored output destination; Python only changes syntax/flags, does not generally transcode compressed data |
| `DicomBase.save_explicit_little_endian(filename=None)` | Partial | Default RGB8 encoding at creation, not equivalent save-time operation |
| `DicomBase.save_explicit_big_endian(filename=None)` | Missing | Public Python operation (retired DICOM syntax); not an approved removal; valid input/layout and installed-pydicom behavior need characterization before porting |
| `DicomBase.add_missing_instance_uids()` | Difference | Python repairs `None` study/series UIDs and duplicate levels with warnings; Swift never repairs, validates and throws; neither behavior is interchangeable |
| `DicomBase.to_dataset()` | Partial | Public mutable `dataSet`, dependency-specific typed representation; copy/aliasing and model-setter synchronization differ |
| `DicomBase.to_byte()` | Partial | `dicomData()` returns `Data` rather than rewound `BytesIO`; Python repairs UIDs then calls `dcmwrite` without full photograph `prepare()`, Swift regenerates Part 10 File Meta and rejects identities |
| `DicomBase.prepare()` | Missing | Public preparation stage (UID repair); current Swift constructor/serializer stages differ |
| `DicomBase.save(filename=None)` | Partial | `save(to:)` with explicit file URL, atomic replacement; no default path, UID repair, or equivalent prepare semantics |
| `DicomBase.load(filename)` | Missing | Replaces current dataset from an existing DICOM file, not loading a JPEG; no public Swift photograph loader |
| `DicomBase.print()` | Missing | No library-level dataset printing wrapper; choose a diagnostic equivalent without confusing this with DICOM Print networking |
| `PhotographBase.prepare()` | Missing | Calls base prepare and fills EXIF tags; no equivalent repeated preparation stage |
| `PhotographBase.save(filename=None)` | Partial | `save(to:)` writes a photograph, but Python runs preparation/EXIF and stored-path fallback before writing |
| `PhotographBase.is_digitized_image()` | Missing | **Mutator**, despite `is_` name: sets Image Type value 2 to SECONDARY |
| `PhotographBase.is_primary_image()` | Missing | Mutator sets Image Type value 2 to PRIMARY |
| `PhotographBase.is_original_image()` | Missing | Mutator sets Image Type value 1 to ORIGINAL |
| `PhotographBase.is_derived_image()` | Missing | Mutator sets Image Type value 1 to DERIVED |
| `PhotographBase.lossy_compression(lossy)` | Partial | Automatic encoding/import flags, not a callable lossy-history setter; changing this flag must not imply transcoding |
| `PhotographBase.set_image()` | Partial | Initializers ingest once; no image replacement or general format dispatch; Python returns `False` without image input, otherwise helper results, not a photograph object |
| `PhotographBase.set_exif_tags()` | Missing | Fill absent acquisition/content dates, equipment/software/exposure tags; explicit acquisition precedes EXIF; Orientation/GPS intentionally not mapped by Python |

Uncompressed RGB8 and retained JPEG construction in Swift do not serialize to disk.
Compressed RGB construction may use a private byte intermediate for the codec.
Keeping the caller's final SOP UID is a documented creation rule, not a Python
post-construction transcode equivalent. Repeated `dicomData()` does not re-encode.

## Inherited public properties and retained input state

These are **photograph model** getters/setters in Python. A similarly named Swift
metadata field only works at construction and is therefore marked Partial.

| Python property | Status | Swift construction counterpart / remaining behavior |
| --- | --- | --- |
| `DicomBase.image_format` | Missing | Read-only, lazy Pillow format detection/cache; Swift has explicit JPEG/RGB8 entry points |
| `DicomBase.image_bytes` | Missing | Lazy source read/cache and setter; current setter compares `type(image)` to Pillow's Image module (unreachable branch) or to `str`, and does not implement its documented bytes contract (see defects below) |
| `DicomBase.series_datetime` | Missing | Getter/setter split SeriesDate/SeriesTime; absent date/time is not silently synthesized |
| `DicomBase.study_datetime` | Missing | Getter/setter split StudyDate/StudyTime; default study date/time empty |
| `DicomBase.study_instance_uid` | Partial | `metadata.studyInstanceUID`; no model property other than direct dataset access |
| `DicomBase.series_instance_uid` | Partial | `metadata.seriesInstanceUID`; no model property; repair/reject distinction above |
| `DicomBase.series_number` | Missing | Setter assigns value or empty string; default dataset `000` |
| `DicomBase.instance_number` | Missing | Setter converts truthy input to zero-padded five-digit integer, otherwise empty; default `000` |
| `DicomBase.operator_firstname` | Partial | `metadata.operatorGivenName` → Operators' Name; model getter/setter missing |
| `DicomBase.operator_lastname` | Partial | `metadata.operatorFamilyName`; model getter/setter missing |
| `DicomBase.institution_address` | Missing | InstitutionAddress getter/setter |
| `DicomBase.institution_name` | Missing | InstitutionName getter/setter |
| `DicomBase.study_description` | Missing | StudyDescription getter/setter |
| `DicomBase.series_description` | Partial | Profile writes SeriesDescription, but no model property or constructor override |
| `DicomBase.patient_firstname` | Partial | `metadata.patientGivenName`; no model component setter that preserves other name component |
| `DicomBase.patient_lastname` | Partial | `metadata.patientFamilyName`; same setter gap |
| `DicomBase.patient_id` | Partial | `metadata.patientID`; no setter/string-coercion equivalent |
| `DicomBase.reason_for_visit` | Missing | ReasonForVisit getter/setter |
| `DicomBase.patient_sex` | Partial | `metadata.patientSex`; canonical/label mapping implemented, model mutation/invalid-input surface missing |
| `DicomBase.patient_birthdate` | Difference | Python property gets/sets a calendar `date`; Swift constructor field is a DA string, not a model property |
| `DicomBase.performing_physician_firstname` | Missing | PerformingPhysicianName is a distinct role, not the provider field |
| `DicomBase.performing_physician_lastname` | Missing | Same distinct role; do not alias to Physicians of Record |
| `DicomBase.dental_provider_firstname` | Partial | `metadata.providerGivenName` → Physicians of Record, no getter/setter |
| `DicomBase.dental_provider_lastname` | Partial | `metadata.providerFamilyName`, no getter/setter |
| `DicomBase.timezone` | Difference | Python gets/sets dataset UTC offset and initializes it at construction; Swift uses construction-only `acquisitionTimeZone` and emits offset only with explicit acquisition |
| `DicomBase.acquisition_datetime` | Partial | `metadata.acquisitionDateTime`; Python setter fills acquisition tags only (unlike `set_time_captured`), getter returns DICOM DT; naive/aware handling differs |
| `DicomBase.date_captured` | Missing | **ContentDate** calendar date despite its name; do not substitute for genuine acquisition date or progress reference |
| `DicomBase.equipment_manufacturer` | Missing | Setter writes Manufacturer; getter currently reads lowercase `manufacturer` (baseline defect needing review) |

Python also retains these public, non-property attributes:

| Python state | Status | Swift / contract notes |
| --- | --- | --- |
| `self.input_image_filename`, `self.input_image_bytes` | Missing | No retained source/path API for lazy reads, `set_image()`, or EXIF reprocessing |
| `self.output_image_filename` | Missing | No stored destination used by `save()` and grouping |
| `self.sop_instance_uid` | Difference | Plain Python constructor attribute, separate from dataset after arbitrary edits; Swift metadata UID is not retained on the model, serialization reads current dataset identity |
| `self.file_meta` | Difference | Python exposes a mutable FileMetaDataset; Swift regenerates meta from dataset/syntax and does not expose per-file meta edits |
| `self.dicom_mwl` | Missing | Stored worklist used by repeated offline copying |
| `self.time_string`, `self.date_string` | Decision | Python captures current formatted time/date at initialization; no Swift equivalent; determine whether callers rely on this state before removing it |

## Study and series collections

None of these has a Swift collection type yet. Manually sharing UIDs does not
implement the API: **when** state propagates and **which object** is mutated matter.

| Python operation | Status | Baseline contract to preserve |
| --- | --- | --- |
| `OrthodonticSeries.__init__(**kwargs)` | Missing | Consumes `uid` (generated if falsy) and `description`; creates empty `Photos`; `StudyUID` initially `None` |
| `OrthodonticSeries.__len__()` | Missing | Number of stored photographs; Swift collection/count equivalent needed |
| `OrthodonticSeries.__iter__()` | Missing | Iterate stored photograph references in insertion order |
| `OrthodonticSeries.add(photo)` | Missing | Type-checks and appends reference; does not assign grouping UIDs yet |
| `OrthodonticSeries.save(filename_prefix=None)` | Missing | On save, mutates each photo's series description, series UID, study UID; fills missing output path as prefix + 1-based index + `.dcm`; saves each photograph |
| `OrthodonticStudy.__init__(**kwargs)` | Missing | Consumes `uid` (generated if falsy), creates empty `Series`; documented `description` is not consumed |
| `OrthodonticStudy.__len__()` | Missing | Number of stored series |
| `OrthodonticStudy.__iter__()` | Missing | Iterate stored series references in insertion order |
| `OrthodonticStudy.add(serie)` | Missing | Assigns `serie.StudyUID` immediately, then stores same reference; no explicit runtime type guard |
| `OrthodonticStudy.save()` | Missing | Saves series in order using their save operations; no transaction/rollback |

Public fields are series `UID`, `StudyUID`, `description`, `Photos`, and study `UID`,
`Series`. Series save may replace a photograph's existing study UID with `None` if
not attached to a study, causing later UID repair. Missing filename prefix currently
formats as `None_1.dcm` etc. These awkward behaviors are not design recommendations;
characterize and review them before silently replacing them with eager grouping,
value-copy collections, mandatory study objects, or new naming defaults.

## Controller and adjacent scope

| Python operation | Status | Swift / baseline contract |
| --- | --- | --- |
| `OrthodonticController.__init__()` | Missing | Initializes public `photo=None`; stateful controller has no Swift counterpart |
| `OrthodonticController.convert_image_to_dicom4orthograph(metadata)` | Missing | Mutates caller's metadata dict to infer output `.dcm` path, constructs/stores/returns photograph; Swift model initialization is not the same wrapper |
| `OrthodonticController.convert_image_plus_mwl_to_dicom4orthograph(image_bytes, mwl)` | Missing | Constructs from image bytes and supplied worklist, copies MWL locally, stores/returns photo; no network query |
| `OrthodonticController.convert_image_to_dicom4orthograph_and_save(metadata)` | Missing | Converts, updates controller state, writes inferred/supplied path, no explicit return |
| `OrthodonticController.convert_images_to_orthodontic_series(images, metadata)` | Missing | Mutates shared metadata input filename for each image, creates series of photograph references, returns series |
| `OrthodonticController.bulk_convert_from_csv(csv_input)` | Decision | CSV/CLI convenience reads rows, resolves image paths relative to CSV, writes each output; not automatically excluded as networking |
| `OrthodonticController.validate_dicom_file(input_image_filename=None)` | Decision | Prints then invokes external `dciodvfy` command, defaulting to stored photo output; no portable Swift wrapper yet |
| `OrthodonticController.print_dicom_file(input_image_filename)` | Decision | Loads an existing DICOM through DicomBase and prints it; not DICOM Print networking |
| `OrthodonticController.send(send_method, **kwargs)` | Excluded | DIMSE/DICOMweb delivery and transport credentials/TLS settings |
| `OrthodonticController.get_image_view_code(ds, code_system)` | Decision | Python body is `pass`; no implemented behavior to port; do not confuse it with the working static photograph code getter |

The typo `dicom4orthograph` is in the Python API. Spelling cleanup in Swift must be
explicitly mapped, not used to justify omitting the operation. No proposed controller
type or replacement operation has been implemented/approved by this inventory.

## Terminology and utility APIs

The common generator ensures **data agreement**, not public API agreement. Python
frozen dataclasses can be publicly constructed. Swift's Code/ImageType currently
expose `Decodable` and read-only fields but no public memberwise initializer;
Swift's View and its dictionary remain internal.
The Python dataclasses also synthesize value equality and hashing. Swift Code is
Equatable but not Hashable; ImageType is neither Equatable nor Hashable. Those
capabilities are also unfinished mappings, even though synthesized methods are not
part of the source-declaration count. Python collection `len`/iteration protocols
are explicitly inventoried above, not lost through this counting convention.

| Python operation | Status | Swift / remaining contract |
| --- | --- | --- |
| `DicomCode.to_dataset()` | Missing | Internal `PhotographProfile.codeDataset` is not a public conversion; truncates meaning to DICOM LO length in Python |
| `DicomCode.to_sequence()` | Missing | Public single-item sequence conversion absent |
| `utils.generate_dicom_uid(root=None, hash=None)` | Partial | Internal DICOMKit UID generation uses existing roots; no public wrapper, root argument, or deterministic 16-byte hash mapping; exact hash→UID behavior matters to callers |
| `utils.jpeg2000_codestream(image_bytes)` | Missing | Public bare-codestream/JP2 unwrap helper; Swift new JPEG 2000 encoding is not equivalent to preserving existing codestreams |
| `utils.jpeg2000_is_reversible(image_bytes)` | Missing | Public COD-transform inspection; accepts JP2/bare input and raises for unreadable headers |
| `utils.get_scheduled_protocol_code(ds)` | Missing | Supported deprecated alias for photograph type-code getter with warning; removal not agreed |
| `m_tooth_codes.is_valid_tooth_number(tooth)` | Decision | Standalone ISO tooth-number membership helper and `SCT_TOOTH_CODES` export; not used by current photograph path, but public, not silently removed from compatibility scope |

| Python data surface | Status | Swift counterpart |
| --- | --- | --- |
| `DicomCode.value`, `DicomCode.scheme`, `DicomCode.meaning` | Partial | Same fields on `Terminology.Code`; lacks public construction/conversion |
| `AdaImageType.keyword`, `AdaImageType.abbreviation`, `AdaImageType.meaning`, `AdaImageType.code` | Partial | Same read-only fields on `Terminology.ImageType`; lacks public memberwise construction |
| `OrthoView.keyword`, `OrthoView.description`, `OrthoView.series_description` | Missing | Internal View has mapped values but no public view catalog/type |
| `OrthoView.patient_orientation`, `OrthoView.image_laterality` | Missing | Internal `patientOrientation` / `imageLaterality`, not public access |
| `OrthoView.anatomic_region`, `OrthoView.anatomic_region_modifier` | Missing | Internal lowerCamelCase counterparts only |
| `OrthoView.primary_anatomic_structure`, `OrthoView.primary_anatomic_structure_modifier` | Missing | Internal counterparts only |
| `OrthoView.devices`, `OrthoView.view_code`, `OrthoView.view_modifiers` | Missing | Internal counterparts only |
| `OrthoView.orthognathic_functional_conditions`, `OrthoView.findings_by_inspection`, `OrthoView.observable_entities`, `OrthoView.dental_occlusion` | Missing | Internal counterparts only |
| `_generated_codes.CODES`, `_generated_codes.IMAGE_TYPES` | Partial | `Terminology.bundled().codes` / `.imageTypes`; runtime bundle load can throw rather than direct module constants |
| `_generated_codes.VIEWS`, `_generated_codes.SOURCE_PROVENANCE` | Missing | JSON includes both; Swift does not publicly expose views or decoded full source provenance (`sourceLockSHA256` alone is not the latter) |
| `m_orthodontic_photograph.TREATMENT_EVENT_TYPES` | Partial | `TreatmentEvent` has canonical cases and failable raw-value initialization, but no iterable set equivalent or complete legacy-string contract |

Other discovered modules: `defaults.py` re-exports deprecated `utils`/`config` APIs;
its compatibility path and warnings need a decision, not a second maintained
terminology source. `config.py`/`__version__` expose version, UID roots, date formats,
and process configuration (such as validator path); Swift release metadata is not
a drop-in public configuration API. `snomed-codes.py` is empty,
`m_orthodontic_radiograph.py` is unimplemented, and `SimpleView.__init__()` is a no-op:
there is no working radiograph/UI behavior to claim as ported. CLI entry points
(`dicom4ortho`, `d4o_generate`) and `dicom/` transport modules are not Swift library
APIs; transport is excluded, while CLI parity needs a separate scope decision.

## Behavioral differences and unresolved baseline defects

These are compatibility/design findings, not automatically requirements to copy a
defect or duplicate a Python-only binding convenience. Resolve them against the
shared contract and Python production compatibility:

1. **Construction/templates:** Swift requires pixels + recognized type; Python permits
   image-free and unresolved-type models, including treatment context without a view.
   Both flags and constructor errors differ. Need template and unknown-type cases.
2. **Mutable identity:** Python repairs missing/duplicate study/series identities at
   prepare/to-byte/save stages; Swift throws and initializes identities earlier.
   Python's separate `sop_instance_uid`/`file_meta` state can become stale after raw
   dataset edits; Swift regenerates File Meta. Preserve identity semantics while
   reviewing defects; do not port corrupt File Meta as a compatibility requirement.
3. **Value versus reference lifecycle:** Swift value-copy behavior is observable.
   It has not been approved as equivalent to Python reference mutation/collection
   aliasing. Missing typed setters also mean metadata changes do not rebuild context.
4. **Dates:** constructor birth-date formats/error policy differ. Python supports
   naive and aware datetimes; Swift separates absolute Date and a timezone. Default
   UTC-offset emission and timestamp precision need comparison, not just same-day tests.
   Python `date_captured` is ContentDate; neither content nor edit time may substitute
   for acquisition when calculating progress.
5. **Direction:** constructor override of a fixed view differs. Python unknown setter
   directions log/no-op; Swift throws. Swift writes empty Type 2C Patient Orientation
   for IV28/IV30 whereas Python omits it. The latter is a documented independent-
   validator correction; it still needs explicit compatibility disposition, not a
   claim that all output tags already match.
6. **Default attributes:** Python writes SceneType=1 and FileSource=3; current Swift
   does not. Swift always emits empty PatientBirthDate/Manufacturer and hardcodes
   BurnedInAnnotation=NO; Python's emitted values depend on input/state. Study
   Description and timezone presence also differ. Compare omitted versus present-empty
   elements; both are not interchangeable for every DICOM attribute.
7. **Imports/encodings:** Python preserves JPEG/MPO input through a permissive JPEG
   path, and JP2/bare JPEG 2000 codestreams through a separate path. Swift accepts a
   narrower baseline JPEG subset and RGB8; it lacks grayscale/raw-image-container
   ingestion, EXIF, and JPEG 2000 preservation. Python's generic raw path supports
   RGB/L, has an explicitly uncertain mode-1 path, and raises NotImplementedError
   for palette/RGBA/CMYK/YCbCr/LAB/HSV/I/F. Do not describe all Pillow formats or
   purported multiframe MPO support as already correct. Rejecting malformed or
   mislabeled inputs can be justified, but requires characterization and review.
8. **Lossy history:** Python preserved JPEG uses a hardcoded ratio 10; Swift derives
   a ratio from dimensions/source length. New Swift lossy encodings set derivation
   metadata; they are additions, not preservation parity. Transfer-syntax save helpers
   in Python are not reliable general transcoding APIs.
9. **Deprecated compatibility:** days-based progress and old event aliases are still
   accepted until v2 in Python; preserve that production binding. A new Swift binding
   need not add old aliases solely to mirror Python. Document its supported inputs
   and preserve the underlying clinical event/day meaning.
10. **Known source inconsistencies:** `image_bytes` setter's checks do not implement
    its documented bytes contract; manufacturer getter uses lowercase tag spelling;
    Python study `description` is documented but unused; series save can infer
    `None_1.dcm`; EXIF has duplicate unreachable Make/Model branches. Characterize
    these and distinguish intended contracts from defects before changing either port.
11. **Errors:** Python mixes ValueError/TypeError, logging/no-op/False/None, Pillow
    exceptions, pydicom validation, and I/O errors. Preserve the existing Python
    binding. Swift can use native throws and documented binding-specific recovery,
    but must distinguish incomplete records from invalid supplied input under C09.
    Record validation timing as well as error meaning.

## Binding design and evidence

The earlier proposed one-for-one Swift spelling table has been withdrawn: the
language APIs do not have to match. Use the contract capability map, not method-count
parity. For example, a typed mutable clinical context can cover several Python
setters, a Swift property can replace a predicate method, and codec policy can be
typed without exposing arbitrary aliases. Preserve meaningful distinctions (provider
versus operator, profile versus type code, draft versus invalid input) and ownership.

Python constructor/default/output behavior remains compatible. Swift can expose
different overloads and native types, but needs partial/template construction as
well as completed-image construction to implement C01. Its clinical errors and identity
policy are documented binding decisions, not reasons to rewrite production Python.
No new Swift signature is selected by this documentation pass.

### Evidence and next work

Existing evidence: 15 Swift tests cover the supported constructor/serialize/save
lifecycle, repeat serialization, identity checks, baseline JPEG file/memory input,
selected clinical values, and 13 encoding choices. Independent synthetic decoding
and 73 view comparisons cover **selected clinical mappings**, not the API above.
The oracle intentionally tolerates IV28/IV30 orientation differences; current tests
do not prove defaults, error timing, mutations, aliases, or collection equivalence.
See [validation history](Development.md), [Swift usage](../Sources/DICOM4Ortho/DICOM4Ortho.docc/DICOM4Ortho.md),
and [Python usage](../../python/README.md) rather than duplicating examples here.

Contract-driven work, in dependency order (unchecked means unfinished):

- [ ] Characterize unknown/omitted inputs, identity repair, constructor defaults,
  mutable aliasing, warning/no-op behavior, and the baseline defects above in Python tests.
- [ ] Review the working-record contract and binding-specific policies; preserve
  Python compatibility rather than naming parity. Implement logical shared records in Swift.
- [ ] Add templates/type-code get/set, view remapping and predicates, and mutating
  patient/personnel/date/progress capabilities; retain legacy APIs in Python without
  automatically introducing them into a new Swift binding.
- [ ] Add general file/byte imports, EXIF precedence, raw grayscale/container paths,
  and JP2/JPEG 2000 codestream preservation without implicit recompression.
- [ ] Implement preparation and output with documented identity policy and valid
  File Meta consistency; keep Python destination/legacy-syntax behavior compatible.
- [ ] Implement reference-consistent study/series collection operations and deferred
  propagation; then offline MWL mapping and useful binding-specific conveniences.
- [ ] Resolve CSV/CLI, external diagnostics, and legacy utility/export scope decisions.
- [ ] Add contract scenarios for inputs, clinical outputs, logical-record mutation,
  identity and lifecycle; use separate binding tests for legacy formats, defaults,
  warnings, and method-specific behavior. Do not require all inventory rows to become
  identical public declarations or warnings across languages.

Networking stays excluded. Linux testing is deferred at the user's request and does
not block this mapping work. iOS simulator execution remains a separate environment
limitation; successful cross-compilation is not simulator test execution.

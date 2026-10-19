# dicom4ortho

[![MIT License](https://img.shields.io/github/license/open-ortho/dicom4ortho)](LICENSE)
[![Issues](https://img.shields.io/github/issues/open-ortho/dicom4ortho)](https://github.com/open-ortho/dicom4ortho/issues)

Libraries for creating orthodontic photographs in DICOM.

## Introduction

Dental providers take full-face, profile, intraoral, and close-up photographs to
document anatomy and monitor treatment. Exchanging those images requires a shared
description of what each photograph shows, not application-specific filenames.

[DICOM](https://www.dicomstandard.org/about) stores medical image pixels together
with structured attributes such as patient identity, anatomy, viewing direction,
and acquisition time. It supports ordinary visible-light photographs as well as
radiographs and scans. dicom4ortho applies the orthodontic photograph mappings so
applications do not have to reconstruct them independently.

### Standards and clinical scope

The [American Dental Association (ADA)](https://www.ada.org/resources/practice/dental-standards/ada-standards-program-overview)
develops dental standards through its ANSI-accredited standards program:

- **ADA 1100** defines 73 commonly used orthodontic photograph types, illustrated
  with line drawings.
- **ADA 1114** defines requirements for using DICOM for dental images and refers
  to ADA 1100 for photograph types.
- **Draft ADA-1107** specifies how to apply these standards together. It is not
  yet published. dicom4ortho implements this draft profile; its support for ADA
  1100 and ADA 1114 is through that profile.

[DICOM CP 1570](https://dicom.nema.org/Dicom/News/March2025/docs/cpack130/cp1570.pdf)
added the dental acquisition attributes and codes used by the profile. Approved
[change proposals](https://www.dicomstandard.org/submitcp) become part of the standard.
The [local CP text](docs/context/cp1570_ft_add_dental_acquisition_attributes_into_VL_IOD.txt)
is available as reference material.

The photograph types and their mappings to **SNOMED CT** (Systematized Nomenclature
of Medicine — Clinical Terms) are published at https://terminology.open-ortho.org/.
These coded concepts identify anatomy and clinical circumstances independently of
free-text labels. Profile mapping ownership remains with
[DENT-OIP](https://github.com/open-ortho/dent-oip).

An Information Object Definition (IOD) specifies the required and optional
attributes of a DICOM object. The libraries combine image pixels and caller-supplied
clinical context with the profile's anatomy, view, device, and acquisition-context
mappings to create VL Photographic instances. Patient identity and clinical history
must come from the application; a photograph alone does not provide them.

## Implementations

| Implementation | Status | Installation, API, tests, and documentation |
| --- | --- | --- |
| Python | Existing implementation; includes CLI, dataset templates, image-type identification, and network delivery | [Python README](python/README.md) |
| Swift | Partial port of DICOM creation; not yet API/feature complete | [Swift API guide (DocC)](apple/Sources/DICOM4Ortho/DICOM4Ortho.docc/DICOM4Ortho.md), [build and development](apple/README.md) |

See each implementation's guide for supported inputs, transfer syntaxes, platform
requirements, validation results, and limitations. Capability in one implementation
does not imply capability in the other. Successful test/validator results are not
a declaration of complete profile conformance or clinical suitability.

### API policy

The language APIs **do not have to be identical**. The shared contract below
formalizes the existing Python model, not the current Swift interface. Python's
production-facing interface is a compatibility binding: no cosmetic rewrite,
mass rename, or requirement for consumers to migrate. New features follow the
contract; Swift can be reorganized to implement it idiomatically. Neither port's
implementation details are the specification.

The [Python structure analysis](python/docs/API_STRUCTURE.md) explains the source
evidence and minimal-change path. The [implementation inventory](apple/Documentation/APIParity.md)
records existing surfaces and differences; its 89 operation/property rows are
**not** 89 mandatory Swift methods. See each language's API guide for current usage.

## Language-neutral API contract

**Draft 0.1, 2026-10-19 — for review, not a claim of implementation conformance.**
The organizing idea is **a mutable DICOM photograph record, incrementally enriched
with image evidence, clinical facts, and profile mappings, then prepared for output**.
This is a formalization of the Python design, not a new framework or an immutable
builder pipeline. The numbered rules describe capabilities and observable meaning,
not exact signatures, inheritance, exception classes, or a shared runtime.

### C01 — A photograph is a working record

A photograph represents one DICOM instance under construction. It can start empty,
as an image-type template, or from image input plus known metadata. Callers can
complete and correct it incrementally. Absence of pixels, a recognized image type,
or optional clinical facts does not by itself make constructing a working record
an error; it does mean the record is not necessarily ready for clinical exchange.
Unsupported supplied image bytes and contradictory clinical inputs are a different
case from omitted inputs.

**Why:** demanding all inputs up front prevents templates, staged metadata entry,
and integration with workflows that obtain patient/context/image data separately.
No camera, application, or capture-session abstraction is required.

### C02 — Convenience operations edit an accessible dataset

The record exposes its native DICOM dataset for advanced use. High-level operations
provide common patient, personnel, identity, time, image-type, and treatment edits;
callers need not construct DICOM sequences for ordinary profile operations. A binding
may use properties, methods, or typed arguments without reproducing every Python
accessor or base class. Advanced edits apply to the working record, not a detached
copy unless the operation explicitly returns a snapshot.

Profile selection and treatment state can be retained alongside the dataset. An
explicit high-level edit can rebuild its managed attributes/sequences; the contract
does not promise automatic inference of model state from arbitrary raw tag edits.
Each binding documents that boundary and which generated attributes an operation
may replace. There is no requirement for a second generic dataset abstraction.

**Why:** the dataset escape hatch handles uncommon DICOM needs without a new wrapper
for every tag, while clinical operations prevent callers from assembling fragile
sequence structures themselves. Hidden bidirectional synchronization would make
repeated edits unpredictable and require a large Python rewrite.

### C03 — A profile enriches known facts; it does not invent them

Applying a recognized photograph type supplies its anatomy, orientation where known,
devices, descriptions, view/modifiers, and acquisition-context mappings from the
reviewed offline terminology. Image type and viewing direction are distinct concepts.
Unknown/unresolved types can remain in a working record without invented mappings.
If applying a recognized mapping requires a caller-supplied direction, that operation
must report the missing input rather than guess it. Unknown optional direction for
IV29 remains unknown. Treatment context can exist without a resolved photograph type.

The record also supports inspecting/setting its embedded photograph-type code,
including private extensions. Replacing that code preserves unrelated sequence
items and identifies the extension creator. Setting a code item and applying a
whole profile are separate operations; one does not silently imply the other.

**Why:** otherwise an unknown or custom type becomes falsely classified, or updating
one identifier destroys other coded context. Standards corrections are reviewed
separately from API cleanup; this contract does not perpetuate malformed DICOM tags.

### C04 — Clinical metadata is explicit; source precedence is operation-specific

Patient identity, responsible dental provider, acquisition operator, and actual
referring/performing physicians retain their distinct clinical meanings. A supplied
Modality Worklist can enrich the record **offline**; receiving a dataset does not
require or authorize a network query. Copy only attributes appropriate to the target
IOD; requesting and scheduled-performing roles are not interchangeable with operators.

Acquisition time describes taking the photograph; content/editing time is distinct.
Explicit acquisition input takes precedence over EXIF acquisition fallback. EXIF
DateTimeOriginal can supply a missing acquisition time; digitization/editing dates
cannot substitute for it. A deliberate later metadata operation may replace values:
there is no universal rule that a constructor argument forever outranks a subsequent
worklist copy or explicit edit. Non-time EXIF precedence remains binding-specific
until characterized; do not generalize the timestamp rule to every equipment field.

Treatment progress is an event plus elapsed **calendar days**, calculated from an
event date and genuine acquisition date, with an explicit date override where needed.
Zero days is valid; a future event or missing reference date is an error. A date
without time of day must not change merely because a timezone converts an instant.
Updating progress replaces the managed progress context rather than accumulating
duplicate events/offsets. Legacy precomputed days and aliases remain supported by
the Python compatibility binding; new bindings can expose a typed date-first API.

**Why:** role confusion and use of editing timestamps produce clinically incorrect
metadata even when the file is syntactically valid DICOM. Keeping precedence local
to documented operations avoids silently changing production metadata flows.

### C05 — Image ingestion preserves evidence

Image input can come from memory or a local file without forcing an output file.
Supported formats/layouts are declared per binding, with remaining support gaps
visible. Attaching an already supported compressed photograph preserves its codestream
when possible; container removal required by DICOM is not recompression. Decoding
to uncompressed pixels or encoding a new representation are distinct operations.
Additional lossy encoding is explicit and records the appropriate history/derivation.
Selecting a transfer-syntax label alone must not misdescribe the stored pixels.

**Why:** silent recompression damages the source and can falsely claim fidelity.
Broad codec support is an extension, not a reason to discard preservation or ordinary
file/byte ingestion. Known unsupported/mislabeled legacy paths need separate fixes.

### C06 — Identity is completed deliberately, not regenerated on every output

SOP Instance identity belongs to the photograph; series/study identities establish
its relationships. Preserve valid distinct caller identities. If hierarchy identities
are unassigned, preparation supplies them under the library's registered roots.
Repeated output of the same unchanged record must not churn identities or recompress
its existing image. Creating a private codec intermediate is not publishing another
instance and does not replace the caller's final SOP UID.

Python's default recovery of missing/colliding study/series UIDs remains a documented
compatibility policy, with diagnostics for repairs; it must not be silently replaced
by mandatory strict rejection. New bindings must declare their repair/reject policy
for invalid/colliding supplied identity; that policy is not settled by this draft.
Both policies must preserve SOP identity and consistent dataset/File Meta identity,
and neither may silently change already valid study/series relationships. A deliberate
new derivation of an existing published instance needs its own identity policy; it is
not the same as first-time encoding during construction.

**Why:** regenerating IDs can separate related photographs, break references, and
create unintended duplicate instances. Exact random suffix algorithms need not
match across languages; a specifically promised deterministic UID mapping does.

### C07 — Study and series are ordered groups of working records

A series groups photographs; a study groups series. They retain the same logical
child records in insertion order. Adding a child does not save or send it. Parent
identity/description propagation happens at documented grouping/preparation/output
boundaries. When grouping edits a child, a caller retaining that child's working
handle sees the edit; detaching a snapshot is an explicit operation, not an invisible
copy caused by the binding's implementation language.

Python's existing deferred series propagation and study attachment timing remain
compatible. No single-parent restriction, deduplication rule, all-or-nothing batch
transaction, or automatic file naming scheme is introduced by this contract.

**Why:** grouping must establish the relationships on the records the caller actually
uses. Quietly grouping copies can yield files with different identities from the
objects subsequently inspected, edited, or delivered. This requires logical shared
mutation, not necessarily identical class hierarchies or memory-management mechanisms.

### C08 — Preparation and output are separate concerns

Preparation completes library-managed defaults, hierarchy identity, and applicable
metadata fallbacks. It is repeatable for an unchanged valid record and is not a
freeze/commit operation, a clinical validator, or permission to fabricate missing facts.
Callers may edit afterward and prepare again. The record provides access to its
dataset, in-memory serialization, and local-file saving as distinct capabilities.
A binding can offer output conveniences that invoke preparation, but documents when
that happens and any record mutation. Existing Python `save` versus `to_byte`
preparation differences remain compatibility facts, not an accidental universal rule.

Output serializes the current representation without implicit additional compression.
A destination may be supplied by the caller or retained as a binding convenience;
no path is required to construct/use an in-memory record. File saving and network
delivery remain separate. Serialization success is not a promise of full IOD/profile
conformance, especially for intentionally incomplete working records.

**Why:** consumers need datasets/bytes without temporary files and need to inspect
or enrich drafts without triggering delivery. Treating prepare as "validate everything"
would invalidate established template workflows and conceal the actual checks performed.

### C09 — Distinguish incomplete, invalid, unsupported, and operational failure

Missing optional facts or an unresolved profile produce an incomplete working record,
not made-up values. Contradictory treatment input, unreadable supplied images,
unsupported encoding/layout, and file I/O failure are distinct conditions. Bindings
expose diagnostics/failures in their native form and document recovery behavior;
no new contract requires reproducing Python exception class names or every legacy
warning/no-op convention in Swift. Python callers keep those existing conventions
unless a separately justified compatibility change is approved.

**Why:** a blanket throw-on-any-missing-value policy prevents progressive construction,
while swallowing genuine failures makes callers believe a conversion succeeded.
Stricter validation can be an explicit capability, not a disguised aesthetic refactor.

### C10 — Workflow adapters and legacy helpers are not the core model

Conversion controllers, CSV input, inferred output names, diagnostics, UID helpers,
and deprecated aliases can adapt to the working-record capabilities. The core
does not require an MVC hierarchy, a public base class, every historical method,
or a `materialize()` service. Python keeps its production entry points; no wholesale
adapter framework or replacement API is required merely to adopt this contract.
New functionality uses these responsibility boundaries. Swift's materialization
scope excludes networking/authentication/queues, not offline worklist metadata.

**Why:** separating responsibility in the specification is enough to guide future
implementation; physically reorganizing tested Python code without a functional
benefit adds migration risk rather than clinical capability.

### Abstract operation structure

The notation here describes capability boundaries, not required function names.
`Record` means a mutable logical photograph, not necessarily a particular class;
`Dataset` means the binding's native DICOM representation. Brackets denote optional
inputs. A language API may combine operations or expose them as properties, provided
the distinctions and effects remain explicit.

| Capability | Inputs → result | Observable effects / boundary |
| --- | --- | --- |
| Construct working record | `[image source], [clinical facts], [profile], [identities]` → Record | Initialize what is known; image-free templates allowed; may read a supplied local source, never writes/sends output |
| Access/edit dataset | Record → live Dataset access; explicit snapshot if requested | Raw edits affect that working record; high-level state inference is not automatic |
| Edit clinical facts | Record + patient/personnel/time/equipment facts → same Record | Preserve role and time meaning; affect corresponding attributes, not image evidence |
| Apply profile/direction | Record + type/direction selection → same Record or documented diagnostic | Enrich managed tags/context; distinguish unresolved type from required missing direction |
| Inspect/set type code | Record/Dataset + `[coded entry, creator]` → code or updated record | Identify/update extended type code independently of whole-profile application; preserve unrelated code items |
| Set treatment progress | Record + event/date + `[acquisition-date override]` → same Record | Validate clinical date relationship; replace managed progress items, retain zero-day progress |
| Attach image | Record + encoded file/bytes or supported raw samples → same Record | Populate pixels/layout and truthful compression history; preservation and new encoding are distinct |
| Enrich from supplied MWL | Record + supplied worklist Dataset → same Record | Copy applicable clinical/request facts locally; no network retrieval or delivery |
| Group/iterate | Study + Series, or Series + Record → ordered group of live handles | Attach without saving; parent-context propagation timing is documented; no implicit snapshots |
| Prepare | Record/group → same prepared working objects | Complete managed defaults/identity/fallbacks as documented; no output, no freeze, no full-validation claim |
| Serialize in memory | Record → DICOM bytes/file-like output | Encode current dataset/representation; document any implicit preparation; no output path/network required |
| Save local output | Record/group + supplied or retained destination → written output | Document preparation and per-child behavior; propagate I/O failure; no delivery side effect |

The contract does not require convenience-controller, CSV, printing, or deprecated
utility functions to be identical across bindings. Python's existing load/default-path
and save-syntax entry points remain supported by its compatibility binding; introducing
new bindings does not require replacing them or inventing a universal conversion service.

### Minimal-change adoption

1. Keep Python names, defaults, constructor inputs, setters, and existing production
   entry points. Do not deprecate them merely to resemble Swift. Characterize the
   intended workflows before changing execution order or recovery behavior.
2. Fix specific correctness/consistency defects only with regression tests and a
   stated consequence. Candidate differences such as memory/file preparation timing,
   malformed identity recovery, and raw/model synchronization need review, not a
   promise that a change is harmless. Pure naming cleanup is not required.
3. Rework Swift around the working-record model: partial construction, controlled
   clinical edits, explicit profile/code operations, image-preserving ingestion,
   preparation, and shared-record grouping. Typed values and efficient internals
   remain useful, but the current Swift struct/API is not authoritative.
4. Verify the contract with shared clinical scenarios and each binding with its own
   compatibility tests. Test equivalent meaning/relationships and deliberate error
   policy, not identical method spelling, dependency types, generated bytes, or all
   accidental Python implementation details. Capability gaps remain explicit.

The draft intentionally does not select a new global metadata precedence, automatic
progress recomputation after unrelated raw edits, strict-only UID policy, or new
Python API version. Those would be design changes beyond formalizing the existing
philosophy. See the [Python analysis and binding notes](python/docs/API_STRUCTURE.md)
for evidence, regression scenarios, and the small candidate-change list.

## Repository layout

```text
README.md                 Shared purpose, standards, boundaries, and terminology maintenance
python/                   Python source, tests, examples, README, and implementation docs
apple/                    Swift Sources/, Tests/, Documentation/, README, and DocC
docs/context/             Reference material, including CP 1570
tools/                    Repository maintenance and cross-port validation tools
Package.swift             SwiftPM entry point
python/pyproject.toml     Python packaging entry point (with its README, license, and config)
Makefile                  Python development and shared terminology maintenance entry points
```

Each language owns its runtime implementation, dependencies, tests, and language-
specific documentation. There is **no shared executable core** or runtime dependency
between ports. Shared terminology and conformance cases coordinate clinical behavior.
Python packaging, lint/release configuration, and development recipes live under
`python/`. The root Makefile delegates Python tasks and owns shared terminology tasks.

**SwiftPM exception:** `Package.swift` (and its resolution lock) stays at the root
because SwiftPM looks there when consuming a Git-URL dependency and offers no
package-subdirectory selector. Moving it into `apple/` would allow local
`--package-path apple` builds, but break direct installation from this repository
URL. Its explicit target paths keep Swift source, tests, and documentation in
`apple/`. The reason is also recorded in the manifest itself.

## Development environments

One root Nix flake exposes separate environments. From the repository root:

```sh
nix develop           # Python default; also prints guidance about both options.
nix develop .#python  # Explicit Python library/CLI and terminology tooling.
nix develop .#swift   # Swift support tools; requires an installed Swift 6.4+ compiler.
```

The startup guidance is informational, not an interactive selection that could
block `nix develop --command ...` or CI. The default retains Python's existing
virtual-environment setup. The Swift shell neither installs Python dependencies
nor initializes a virtual environment. It checks an external compiler selected via
`SWIFT_TOOLCHAIN_BIN` (a directory containing `swift`) or `PATH`: the pinned Nix
compiler is too old for this package. Missing/incompatible Swift produces a clear
error instead of a misleading test-ready shell. See the [Swift setup guide](apple/README.md#nix-environment).

Linux Swift/dependency compatibility remains unverified. Apple SDKs and simulator
tests still require a compatible Xcode on macOS. The bundled `dciodvfy` derivation
is available only on x86_64 Linux; other architectures/platforms omit it.

## Shared terminology

One command, `tools/generate_codes.py`, fetches and resolves these sources once:

| Input | Source |
| --- | --- |
| DICOM context-group codes | [NEMA FHIR ValueSets](https://medical.nema.org/medical/dicom/resources/valuesets/fhir/json/) |
| DCM concept names | [NEMA DCM ontology](https://medical.nema.org/medical/dicom/resources/ontology/DCM/dcm.owl) |
| ADA 1100 photograph types | [Open Ortho CodeSystems](https://terminology.open-ortho.org/fhir/sid/ada1100/CodeSystem/) |
| View layout | [DENT-OIP views.csv](https://raw.githubusercontent.com/open-ortho/dent-oip/latest/source/tables/views.csv) |

It renders both committed artifacts in memory before writing either:

- `python/dicom4ortho/_generated_codes.py`
- `apple/Sources/DICOM4Ortho/Resources/terminology.json`

Both contain the same 83 codes, 73 photograph types, and 73 view mappings. The JSON
is not derived by importing the generated Python module. Each separately distributed
library bundles its own generated data for offline use; these are not independently
maintained clinical definitions. Neither runtime loads the other implementation.

From the repository root, with the generator's development dependencies installed
as described in the [Python guide](python/README.md#installation):

```sh
make update_codes  # Fetch once and regenerate both ports; review before committing.
make check_codes   # Fetch and compare every output; write nothing.
```

These are explicit networked maintenance operations. Normal builds, terminology
tests, and runtime use committed data without fetching terminology. Network delivery
tests have separate service requirements. Do not refresh terminology merely to build.

Each artifact records observed URLs, SHA-256 hashes, and available FHIR version/date
metadata. The JSON also records the corresponding Python artifact's SHA-256 for
cross-port traceability, not as a runtime dependency or upstream version. Mutable
source URLs are not reproducible pins: reviewed committed artifacts lock behavior,
but a later fetch may differ. Source-provenance changes alone can trigger drift.
Adding a port means adding a renderer to this command, not a separate refresh tool.

The generator does not consume a pinned `fhir.dicom` package or the legacy packaged
CSV snapshot. Publishing and adopting versioned ADA-1107 mappings remains future
work tracked in [dent-oip #56](https://github.com/open-ortho/dent-oip/issues/56) and
[#11](https://github.com/open-ortho/dent-oip/issues/11). A migration must pin the
published version/checksum and verify clinical mappings, actual codes/sequences,
acquisition-time semantics, and offline behavior before replacing this resolver.

## Contributing

Use the language-specific guides for setup, testing, diagrams, and releases.
Keep clinical semantics consistent across implementations and test differences
explicitly. Document why non-obvious decisions exist; use meaningful names, small
focused functions, narrow error handling, and readable code rather than cleverness.
Avoid unused abstractions and duplicated maintained definitions. Prefer deterministic
tests, with network/filesystem effects isolated.

Report bugs, propose features, or discuss profile questions in the
[issue tracker](https://github.com/open-ortho/dicom4ortho/issues). Contributions via
pull request are welcome. The older [published documentation](https://open-ortho.github.io/dicom4ortho/)
is Python-specific and maintained on `gh-pages`; it is not the Swift API reference.

## Releases and distribution

Python publishes wheels/source archives to **PyPI**. SwiftPM resolves the package
directly from this **Git repository and semantic-version tags**; no separate registry
upload is required. Swift Package Index listing is optional discovery, not a release
prerequisite. Version tags are repository-wide: a tag created for Python is also
visible to SwiftPM. Do not describe a tag as a qualified release of both languages
unless both implementations have met their release criteria.

Before tagging, review changed shared terminology against both ports, record each
implementation's status, and follow the [Python release checklist](python/docs/RELEASING.md)
and [Swift release checklist](apple/Documentation/Releasing.md). Preserve published tags;
fixes require a new version rather than moving an existing tag. The current Swift
port is not release-qualified. PyPI publication is automated; Swift qualification
and fresh-tag consumer checks are currently manual and must be recorded.

## License and contact

Distributed under the [MIT License](LICENSE). Dependencies have their own licenses;
see the implementation guides. Contact: Toni Magni, open-ortho@afm.co.

# Language-neutral API contract

**Draft 0.1, 2026-10-19 — for review, not a claim of implementation conformance.**
The organizing idea is **a mutable DICOM photograph record, incrementally enriched
with image evidence, clinical facts, and profile mappings, then prepared for output**.
This is a formalization of the Python design, not a new framework or an immutable
builder pipeline. The numbered rules describe capabilities and observable meaning,
not exact signatures, inheritance, exception classes, or a shared runtime.

## C01 — A photograph is a working record

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

## C02 — Convenience operations edit an accessible dataset

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

## C03 — A profile enriches known facts; it does not invent them

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

## C04 — Clinical metadata is explicit; source precedence is operation-specific

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

## C05 — Image ingestion preserves evidence

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

## C06 — Identity is completed deliberately, not regenerated on every output

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

## C07 — Study and series are ordered groups of working records

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

## C08 — Preparation and output are separate concerns

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

## C09 — Distinguish incomplete, invalid, unsupported, and operational failure

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

## C10 — Workflow adapters and legacy helpers are not the core model

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

## Abstract operation structure

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

## Minimal-change adoption

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
philosophy. See the [Python analysis and binding notes](../python/docs/API_STRUCTURE.md)
for evidence, regression scenarios, and the small candidate-change list.

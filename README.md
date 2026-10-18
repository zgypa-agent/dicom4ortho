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

### API compatibility across ports

A port should preserve the clinical model, equivalent public operations, input
meaning, identity rules, and error conditions. Language conventions may change
spelling and types; they do not justify unexplained semantic differences.

**The current APIs are not equivalent yet.** The [API comparison](apple/Documentation/APIParity.md)
records the correspondence and missing operations. See each language's API guide
for actual usage; existing Python APIs remain unchanged.

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

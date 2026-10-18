# Python terminology compatibility baseline

The shared sources, generation command, provenance contract, and future package
migration are described in the [root README](../../README.md#shared-terminology).
This file preserves the Python-specific PR #70 compatibility and validation record.

## Runtime and compatibility snapshot

Python imports typed constants from `dicom4ortho._generated_codes`. The packaged
`python/dicom4ortho/resources/views.csv` is a legacy compatibility/test snapshot,
not the generator's regeneration input. `make fetch_resources` updates that CSV
only; it does not regenerate either port's terminology. `codes.csv` and
`image_types.csv` are no longer packaged terminology sources.

`test.test_terminology_bundles` checks parity against the Swift resource offline.
These repository-level tests run from a full checkout and are not shipped in the
standalone Python source archive. Neither Python distribution includes the Swift
resource, and the Python runtime does not read it.

## Clinical metadata compatibility

- Code meanings follow official sources and can change textually. This does not
  mean all terminology changes preserve the original code values.
- The mirror device changed from SCT `47162009` to SCT `1332162007`, the CID 4072
  intraoral photography mirror.
- SCT `7652006` resolves to `Frenulum labii` in NEMA CID 4061; the earlier local
  display override is no longer needed.
- IV29 has no default direction in the upstream layout. Construction without
  `view_code_keyword` remains supported: mouth/frenum anatomy is retained, while
  unknown direction and its nested close-up modifier are omitted. An explicit or
  later-supplied direction receives the current mapping's nested modifier.
  [dent-oip #63](https://github.com/open-ortho/dent-oip/issues/63) tracks the pending
  profile decision; this is not an approved new working-group rule. IV28, IV30,
  and EV40 still require a direction.
- Legacy CSV-only keywords `slap_mark`, `birthmark`, and `direct` are not in the lock.
- CID 4070 events are `PatientRegistration` (SCT `184047000`),
  `OrthodonticTreatmentStarted` (SCT `1332161000`), and
  `OrthodonticTreatmentStopped` (SCT `1340210007`).
- `acquisition_datetime` overrides EXIF `DateTimeOriginal`. Editing/digitization
  dates and `ContentDate` are not substitutes. A photograph date can also be
  supplied to `set_treatment_progress_from_date()`.
- Future event dates and incomplete/conflicting progress metadata are rejected.
  Supplied progress is serialized even without a resolved image type, including
  a zero-day interval.
- The days-based API, `OrthodonticTreatment`, and `Posttreatment` aliases remain
  supported with deprecation warnings until version 2.

## Reviewed lock and validation

The lock at reviewed source commit `bd1a73549b6bcb26cb814045820713779047bc08`
has SHA-256:

```text
56c9887dd39831b2606a430c15a8bda3a09d357503c9a029a4c3625d59d86f9c
```

This hashes committed bytes, not a fresh network regeneration. Offline generator
tests cover deterministic rendering, provenance validation, and check behavior.

Historical validation on 2026-10-17 with Python 3.10:

- Non-E2E tests: 94 passed, 4 skipped.
- Changed runtime/tests and generator: error-only Pylint passed. Full-package
  Pylint reported two errors at `dicom4ortho/__main__.py:61-62`
  (`unsupported-assignment-operation` on `PrettyTable.align`) in unchanged code
  with those dependencies.
- Source archive and wheel built from that archive: passed.
- Companion `gh-pages` Sphinx HTML build with warnings as errors: passed.
- Docker/Orthanc E2E and live terminology drift check: not run.

Any future package migration must also preserve Python's supported deprecated APIs
and acquisition-time precedence/validation. Do not restore a guessed IV29 direction
or removed display override merely to reproduce an older PR description.

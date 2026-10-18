# Swift port development

Implementation tracking: [#82](https://github.com/open-ortho/dicom4ortho/issues/82).
See [the shared scope](../../README.md) and [Swift guide](../README.md)
for the implementation boundaries. DICOMKit is integrated; qualification is incremental and
the port is not feature-complete.

## Development environment investigation (2026-10-18)

The remote build host `mainframe1` is accessible over SSH as `amagni-agent` using
the separately provisioned build key. The default `mainframe1` SSH alias selects
an unrelated, forwarding-only key and is not the development connection. Do not
change or bypass that key's server restriction. Credentials and SSH host-key
configuration belong outside this repository.

Observed build-host configuration:

- Apple Silicon (`arm64`), macOS 15.8.1.
- `/Applications/Xcode.app`: Xcode 26.3, Apple Swift 6.2.4.
- Installed iOS device and simulator SDKs report version 26.2.
- No separately installed Swift toolchain was initially present.

DICOMKit v2.7.0 requires Swift tools 6.4, so Xcode's bundled compiler cannot
resolve that release. The official Swift 6.4.1 macOS package was downloaded from
Swift.org. `pkgutil --check-signature` reported an Apple-trusted, notarized package
signed by `Developer ID Installer: Swift Open Source (V9AUD2URP3)`.

The normal current-user installation failed because the SSH-only account's
`com.apple.installd.user` service was unavailable. The signed package was expanded
into an isolated directory under that user's Downloads directory instead; its
`usr/bin/swift --version` and `swift package --help` execute successfully. No system
Xcode selection, system installation, or host security settings were changed.
The first `swift build --target DICOMKit --jobs 4` completed successfully in
67.20 seconds on this host. This establishes a macOS library build, not iOS
device/simulator compatibility or codec interoperability.

Isolated remote workspaces:

- `~/src/dicom4ortho-issue82`: fresh checkout of dicom4ortho `develop`.
- `~/src/dicomkit-qualification-v2.7.0`: upstream qualification checkout at
  `fd727eaeb7452e936f1608ddd12910d34406883f` (v2.7.0).
- `~/src/dicomkit-qualification-v2.7.0-build.log`: first upstream library build log.

## Qualification before implementation is declared ready

1. Resolve and build the selected DICOMKit product with the recorded compiler and SDKs.
2. Build for iOS devices and simulators, and run library tests on a simulator.
3. Record the complete dependency versions and revisions, plus any upstream failures.
4. Validate generated DICOM with independent tools and compressed frames with
   independent decoders; self-round-trips alone do not establish interoperability.
5. Preserve the existing Python runtime and terminology lock. Broader codec support
   is intentional; any differences in clinical metadata semantics require review.

The root package manifest and offline terminology loader are implemented. A single
maintenance command generates Python and Swift data from the same resolved inputs:

```sh
make update_codes  # Explicit upstream refresh; updates both generated artifacts.
make check_codes   # Upstream drift check for both; writes nothing.
```

These maintenance commands fetch upstream terminology. Normal builds, runtime, and
unit tests remain offline. The JSON includes all codes, photograph types, views,
source provenance, and the corresponding Python artifact's SHA-256. The former
separate export command was removed; Swift data is no longer derived by importing
the generated Python module. See [the pipeline](../../README.md#shared-terminology).

The current materializer supports RGB8, explicit/implicit little-endian output,
JPEG Baseline, JPEG Lossless SV1, JPEG-LS Lossless, JPEG 2000 lossless/lossy,
HTJ2K lossless/RPCL/lossy, JPEG XL lossless/lossy, and RLE Lossless through DICOMKit.
Lossy modes require explicit quality intent. The final SOP Instance UID supplied
by the caller is preserved: the private uncompressed intermediate is not a separate
published predecessor. Generated study, series, and SOP UIDs use the existing
dicom4ortho roots, with DICOMKit supplying unique suffixes.

`materializeJPEG` preserves an existing 8-bit, three-component baseline JPEG
without recompression. Unsupported processes and malformed frame headers are
rejected rather than mislabeled. Explicit acquisition timestamps and timezones,
canonical treatment events/day offsets, and provider/operator roles are supported.
Future events and missing acquisition dates for treatment progress are rejected;
zero-day offsets remain valid.

Independent checks on synthetic 64×64 and 1024×1024 RGB fixtures:

- All 13 encoding choices were decoded independently. Lossless outputs reproduce
  samples exactly. Lossy error metrics were recorded, not interpreted as clinical
  acceptability thresholds.
- pydicom 3.0.2 with independent libjpeg/OpenJPEG/CharLS decoding and Pillow were
  used for the applicable formats. JPEG XL was decoded with libjxl 0.12.0 `djxl`;
  it is not recognized by that pydicom version's transfer-syntax dictionary.
- All 73 Swift view mappings match Python semantically for anatomy, devices,
  view/modifier sequences, acquisition context, and descriptions. **Intentional
  difference:** IV28/IV30 emit an empty Patient Orientation rather than omitting
  it. Independent validation found the Python omission violates the General Image
  Type 2C requirement when Image Orientation (Patient) is absent. This does not
  supply an invented orientation or change Python; the parity oracle checks this
  exception explicitly.
- `dciodvfy` snapshot 20260927113651 returned zero errors for all 13 initial
  encoding fixtures. Each reported eight warnings: empty patient/study values
  needed for DICOMDIR, and the profile's standard-extended View Code Sequence.
  Successful validation is not a declaration of complete profile conformance.
- After the Patient Orientation correction, all **87** generated instances
  (13 encodings, 73 view fixtures, one treatment-progress fixture) passed
  `dciodvfy` with zero errors. Extended-profile and empty-value warnings remain.
- **11 Swift tests pass** on macOS. The final device and simulator library
  cross-builds pass; the 1024×1024 encoding matrix also passes independent decoding.

The reproducible independent decoding/parity check is:

```sh
# On the Mac, use Swift 6.4.1; the destination must contain synthetic data only.
DICOM4ORTHO_TEST_ARTIFACTS=/path/to/artifacts swift test
# Optional larger matrix: set DICOM4ORTHO_TEST_IMAGE_SIZE=1024 (default 64).
# In a separate Python validation environment, with djxl on PATH:
python tools/validate_swift_encodings.py /path/to/artifacts --python-root .
```

The Python oracle's dependencies are separate from the library's Python runtime
environment; see its module documentation. It compares clinical mappings only
when `--python-root` is supplied. A self-readback by DICOMKit is not the independent
codec check.

Remaining implementation includes EXIF fallback and other image import formats,
JP2/JPEG 2000 preservation, higher-level study/series helpers, broader pixel layouts,
JPEG XL JPEG recompression, and the remaining Python materialization behavior.
JPEG 2000 Part 2 encoding is not currently exposed: DICOMKit rejects that path.

Before adding the RGB8 materializer, the initial package built successfully for
`arm64-apple-ios18.0` and `arm64-apple-ios18.0-simulator` against the installed SDKs
(73.20 and 58.97 seconds). These were cross-compilation checks, not simulator test
execution. After adding the RGB8 materializer, all three macOS Swift tests passed
again and both device and simulator library builds passed (2.21 and 1.91 seconds
incremental). Device and simulator builds also passed after adding the encoding
and clinical metadata paths. No tests have yet executed inside an iOS simulator.
`Package.resolved` records the dependency graph used by the macOS tests.

**Simulator test-execution limitation:** a user-local `.xctoolchain` symlink was
registered for the expanded signed toolchain, and `xcrun` selects Swift 6.4.1.
However, Xcode 26.3's package resolver still rejects tools version 6.4 as newer
than its built-in 6.2.4, even with `xcodebuild -toolchain` explicitly selecting it.
Thus SwiftPM cross-compilation works but Xcode simulator testing requires a newer
compatible Xcode. No OS upgrade or replacement of system Xcode was attempted.

Python baseline: 106 tests run, 3 skipped, across `test_models`, `test_photography`,
`test_generated_codes`, and `test_jpeg2000`. The container's pre-existing Python
environment needs the Nix GCC C++ runtime on `LD_LIBRARY_PATH` for NumPy to import.
The subsequent full non-E2E Python suite ran 131 tests with 4 existing skips and
no failures. Network/Docker E2E tests were not run for this materialization work.

## Library structure/documentation review

The terminology pipeline now has one public maintenance entry point,
`tools/generate_codes.py`, rendering all port outputs from one resolution pass.
The former separate exporter was removed. No clinical definitions or generated
artifact bytes were refreshed as part of this change. Offline renderer/parity tests
check that the reviewed mappings remain unchanged; a live drift check was not run.

Swift sources now place the main public types in same-named files and use
`Type+Feature.swift` for extensions. Public APIs document input formats, defaults,
error behavior, and clinical intent. `PhotographEncoding` is policy, not a duplicate
registry: its typed transfer-syntax mapping uses DICOMKit definitions. Independent
test oracles keep numeric UIDs intentionally. See [the design article](../Sources/DICOM4Ortho/DICOM4Ortho.docc/Design.md) for the detailed
file map and rationale.

After this refactor, 11 macOS Swift tests and both iOS library cross-builds passed.
The non-E2E Python suite ran 134 tests with 4 existing skips; changed generator/test
modules passed error-only Pylint. Python wheel and source-distribution builds passed,
and the extracted source distribution's five offline terminology tests passed.
The shared generated bundle is included for those source tests, not installed in
the Python wheel. Both generated terminology artifacts remain byte-for-byte unchanged.
The DocC catalog was compiled using an extracted public symbol graph with
`xcrun docc convert ... --warnings-as-errors`, with no warnings. Every authored
public declaration in the symbol graph has documentation (synthesized Hashable
members use Swift's generated documentation). Simulator execution remains blocked
by Xcode's older package resolver as described above.

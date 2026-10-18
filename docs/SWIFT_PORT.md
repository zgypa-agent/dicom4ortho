# Swift port development

Implementation tracking: [#82](https://github.com/open-ortho/dicom4ortho/issues/82).
See [repository layout and dependency selection](REPOSITORY_LAYOUT.md#additional-implementations)
for the agreed scope. DICOMKit is selected; its integration is not yet qualified.

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

The root package manifest and initial offline terminology loader are now under
development. The terminology JSON is exported from the committed Python lock:

```sh
python tools/export_terminology.py apple/Sources/DICOM4Ortho/Resources/terminology.json
python tools/export_terminology.py apple/Sources/DICOM4Ortho/Resources/terminology.json --check
```

This maintenance command performs no upstream terminology fetch. The resource
includes all codes, photograph types, views, source provenance, and the lock's
SHA-256; it does not modify the Python lock. Swift builds and runtime do not run
Python.

The initial `OrthodonticPhotograph.materializeRGB8` path serializes single-frame
RGB8 photographs with the reviewed view mappings. Three Swift tests pass on macOS,
including materialization and self-readback for all 73 views and rejection of
missing directions or inconsistent pixel sizes. This is a first implementation
slice, not the complete port: acquisition/EXIF metadata, treatment progress,
compressed-image preservation, modern codec integration, independent conformance
tests, and the remaining Python materialization behavior still need implementation.

Before adding the RGB8 materializer, the initial package built successfully for
`arm64-apple-ios18.0` and `arm64-apple-ios18.0-simulator` against the installed SDKs
(73.20 and 58.97 seconds). These were cross-compilation checks, not simulator test
execution. After adding the RGB8 materializer, all three macOS Swift tests passed
again and both device and simulator library builds passed (2.21 and 1.91 seconds
incremental). No tests have yet executed inside an iOS simulator.
`Package.resolved` records the dependency graph used by the macOS tests.

Python baseline: 106 tests run, 3 skipped, across `test_models`, `test_photography`,
`test_generated_codes`, and `test_jpeg2000`. The container's pre-existing Python
environment needs the Nix GCC C++ runtime on `LD_LIBRARY_PATH` for NumPy to import.

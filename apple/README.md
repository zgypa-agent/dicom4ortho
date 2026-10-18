# DICOM4Ortho for Swift

An incomplete port of dicom4ortho's DICOM creation, excluding networking.

## Documentation

- [Swift API guide and examples (DocC)](Sources/DICOM4Ortho/DICOM4Ortho.docc/DICOM4Ortho.md)
  is the authoritative Swift usage documentation. Public declarations supply the
  detailed symbol reference; a compatible Xcode/DocC build renders both together.
- [Source organization and design](Sources/DICOM4Ortho/DICOM4Ortho.docc/Design.md)
- [Python/Swift API comparison and gaps](Documentation/APIParity.md)
- [Development status, validation, and toolchain limitations](Documentation/Development.md)
- [Type diagram](Documentation/ClassDiagram.puml)
- [Swift release/distribution checklist](Documentation/Releasing.md)
- [Shared standards and terminology maintenance](../README.md)

The catalog's Markdown can also be read directly on GitHub; DocC symbol links
resolve in the rendered API documentation. Examples and API explanations are
maintained in DocC rather than duplicated here.

## Package and development

Requires Swift tools 6.4, Swift 6 language mode, iOS 18 or macOS 15. The root
`Package.swift` exposes one library product, `DICOM4Ortho`, with explicit source/test
paths under `apple/`. DICOM writing and codecs use pinned DICOMKit v2.7.0.
Consumers use the repository's SwiftPM package; releases resolve through versioned
tags. The current port is not yet release-qualified.

Run from the repository root:

```sh
swift test
PYTHONPATH=python python -m unittest test.test_terminology_bundles
```

The second command checks cross-port terminology offline and requires the Python
development dependencies. Swift builds and runtime require no Python. For a deliberate
terminology refresh, follow the [shared maintenance instructions](../README.md#shared-terminology).

### Nix environment

`nix develop .#swift` provides support tools without invoking Python setup. Nix's
pinned Swift is 5.8; as checked on **2026-10-18**, `nixos-unstable`'s default `swift`
package is 6.2.4 (revision `fe13242281a67641c0102cdb1087f0ebe586c7df`). Neither
satisfies this package's tools version. The shell deliberately does not supply one
of those compilers or automatically download a toolchain. Install Swift 6.4+ for
your platform separately, then expose its `usr/bin` directory:

```sh
SWIFT_TOOLCHAIN_BIN=/path/to/swift-toolchain/usr/bin nix develop .#swift
```

An existing compatible `swift` on `PATH` also works. Startup fails with actionable
guidance when it cannot execute a sufficiently new compiler. This verifies only
the compiler version, not Linux compatibility of the codec dependencies. A Mac
with compatible Xcode is still required for Apple SDK builds and simulator tests.
See [official toolchain installation](https://www.swift.org/install/) and the
[shared environment options](../README.md#development-environments).

These are dated observations of nixpkgs, not an exhaustive claim about third-party
toolchain overlays or auto-updated flakes. Searching for alternatives found
[swift-nixos](https://github.com/lucasly-ba/swift-nixos), a community source-build
recipe reporting Swift 6.5-dev, not a drop-in stable 6.4 toolchain package. It has
not been qualified for this project. No suitable auto-updated stable Swift toolchain
flake was identified in that search; this does not establish that none exists.
Even auto-updated upstream flakes remain pinned locally by `flake.lock` until an
explicit update. Recheck available versions before maintaining a custom derivation.

## Licensing

dicom4ortho and DICOMKit are MIT-licensed. DICOMKit's source dependencies have their
own notices, including J2KSwift, JLISwift, JLSwift, and JXLSwift codec licenses.
Retain applicable upstream notices when redistributing those components; the root
project license does not replace them.

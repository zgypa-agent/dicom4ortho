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

## Licensing

dicom4ortho and DICOMKit are MIT-licensed. DICOMKit's source dependencies have their
own notices, including J2KSwift, JLISwift, JLSwift, and JXLSwift codec licenses.
Retain applicable upstream notices when redistributing those components; the root
project license does not replace them.

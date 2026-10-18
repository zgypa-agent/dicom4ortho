# Repository layout and implementation boundaries

The repository groups code by implementation language. Python is the current
implementation; additional languages can be added independently. There is no
shared executable core.

```text
python/
  dicom4ortho/        # Python package imported as dicom4ortho
  test/              # Python tests, fixtures, and Orthanc Compose configuration
  examples/          # Python/CLI examples
  README.md          # Python contributor instructions
tools/               # maintenance entry points, including the terminology generator
docs/                # project context, architecture, and release instructions
.github/workflows/   # repository CI and Python publication
pyproject.toml       # single Python packaging configuration and root build entry
Makefile             # build, test, and maintenance commands
LICENSE
README.md
```

## Packaging and maintenance entry points

Keeping a single root `pyproject.toml` avoids duplicating package metadata or
adding a custom backend/forwarding shim. Setuptools discovers only
`dicom4ortho*` under `python/`; the wheel installs `dicom4ortho`, not a `python`
package. Run installation and build commands from the repository root:

```sh
pip install -e ".[dev]"
python -m build
```

The root Makefile provides lint, test, build, maintenance, and publishing targets;
use `make help` to list them. Builds produce wheels and source distributions in
root `dist/`. Installed applications use the package and its bundled resources,
not paths within this checkout.

`tools/generate_codes.py` resolves terminology once and writes both
`python/dicom4ortho/_generated_codes.py` and the Swift target's
`apple/Sources/DICOM4Ortho/Resources/terminology.json`. These are generated package
artifacts from the same inputs, not two maintained sources. Normal builds and runtime
use their committed artifacts offline. Explicit `make update_codes` and
`make check_codes` operations fetch and validate upstream terminology; see
[the terminology documentation](TERMINOLOGY.md) for source details.

## Development environment and tests

The Nix shell installs development dependencies into `.venv`, refreshes the
editable package mapping, and activates the environment. Make runs Python tools
through one selectable `PYTHON` interpreter.

Virtual-environment activation and console scripts embed absolute paths. If the
checkout directory moves, preserve the old environment as a backup and recreate
it at the new location. See [the Python contributor instructions](../python/README.md).

Run `make test`, or use explicit unittest discovery:

```sh
PYTHONPATH=python python -m unittest discover -s python/test -t python
```

The explicit path keeps the local `test` package ahead of Python's standard-library
package of the same name. Root `pytest` uses the same suite. Fixtures are resolved
relative to their test modules, not the shell's working directory.

## Additional implementations

Add a language directory when a real implementation starts, with its own build,
dependencies, tests, and release process. Each implementation owns its runtime
code; Python/DICOM/image logic does not become a shared executable core.
Specifications, terminology definitions, and conformance cases are suitable
language-neutral boundaries for coordination between implementations.

The planned Swift DICOM materialization port is tracked in
[#82](https://github.com/open-ortho/dicom4ortho/issues/82). Its layout will be:

```text
Package.swift                # root manifest for direct SwiftPM repository resolution
python/
  dicom4ortho/
  test/
  examples/
apple/
  Sources/
    DICOM4Ortho/
      Resources/             # bundled profiles and terminology
  Tests/
    DICOM4OrthoTests/
...
```

The initial package and RGB8 materialization path are implemented; the complete
port remains in development. See [Swift development status](SWIFT_PORT.md) for
tested coverage and outstanding work. The package exposes one library product,
`DICOM4Ortho`, independent of UIKit, SwiftUI, and
AVFoundation. Existing Python materialization behavior and tests provide the
baseline for orthodontic metadata, validation, mappings, study/series relationships,
UID handling, and DICOM creation. Network transmission is outside the port's scope.

### Selected Swift DICOM dependency

On 2026-10-18, **[DICOMKit](https://github.com/raster-labs/DICOMKit)** was selected
as the Swift port's DICOM serialization and codec dependency, integrated through
SwiftPM from source. The purpose is to use upstream-maintained DICOM writing and
encoding implementations rather than maintain a separate DCMTK/GDCM bridge or
duplicate writers and codecs in dicom4ortho. This does not make DICOMKit a shared
runtime core for the Python implementation.

The objective is the broadest practical, standards-conformant DICOM materialization
and transfer-syntax support, including uncompressed data, JPEG, JPEG Lossless,
JPEG-LS, JPEG 2000, HTJ2K, and JPEG XL where applicable to the IOD. Actual encoding,
decoding, and compressed-data preservation are distinct capabilities and must be
documented separately. Broader encoding support is an intentional extension where
Python currently only preserves an existing compressed codestream.

Compiler and deployment minimums follow the capabilities and dependencies selected;
the earlier Swift 6.0 minimum is not a hard constraint. The reviewed DICOMKit release,
**v2.7.0**, declares Swift tools **6.4** and **iOS 18**. It is pinned for the initial
integration, with macOS tests and device/simulator library builds passing using
Swift 6.4.1; codec interoperability is not yet qualified. The previously recorded Swift
6.2.4 / Xcode 26.3 validation toolchain is insufficient for that package manifest.
Qualify and record a compatible Apple toolchain and dependency version, including
iOS device/simulator builds and independent validation of generated DICOM and
encoded frames. Swift 6 language mode remains the intended language mode.

DICOMKit has a small observable maintainer group; upstream maintenance and codec
claims do not remove the need for conformance and regression testing. Required
profiles and terminology must be bundled for offline use. Python retains its root
build entry points and existing behavior; no Python reorganization is a prerequisite.

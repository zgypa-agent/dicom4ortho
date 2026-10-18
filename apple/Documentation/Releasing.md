# Swift release checklist

SwiftPM normally downloads this Git repository at a semantic-version tag, such as
`1.2.3` or `v1.2.3`. Publishing consists of pushing a qualified, immutable tag; there
is no required package archive upload or central repository registration. Swift
Package Index is an optional index of Git-hosted packages, not the distributor.
A registry-based distribution would be a separate future deployment choice.

## Current status

The Swift port is incomplete and is **not release-qualified**. In particular,
public API/lifecycle parity is unfinished and iOS simulator test execution remains
blocked by the available Xcode resolver. Passing macOS tests and cross-compilation
does not satisfy all release gates. See [development status](Development.md) and
[API gaps](APIParity.md).

## Before a Swift-qualified tag

1. Resolve the version and scope with the Python release maintainer. All version
   tags belong to the same repository and are visible to SwiftPM, including tags
   created to publish Python. Release notes must identify qualification and gaps
   for each implementation; do not advertise unfinished Swift support as stable.
2. Review source, dependencies, public API compatibility, platform minimums, and
   notices. Record the exact dependency revisions and toolchain. The root manifest
   must remain consumable directly by Git URL, with no Python installation or
   generated files required to build it.
3. Run `swift test` with a compatible Swift 6.4+ toolchain. Build iOS device and
   simulator library targets and execute tests on a simulator with a compatible
   Xcode. Run DocC with warnings as errors. Record commands and results, not only
   upstream codec support claims.
4. Export synthetic fixtures and perform independent decoding and DICOM/profile
   validation as described in [the validation record](Development.md). Run the
   Python baseline and offline cross-port terminology/mapping checks. Review any
   deliberate semantic differences.
5. Coordinate any intentional terminology refresh using the
   [single shared workflow](../../README.md#shared-terminology). Normal tests and
   builds must remain offline with respect to terminology. Do not refresh sources
   implicitly during release builds.
6. Update release notes with tested capabilities, unsupported inputs, deployment
   minimums, known issues, dependency licenses, and per-language qualification.
7. Create/push the agreed repository tag **once**, coordinated with Python's
   release process. Never create a second competing tag or move a published tag.
8. In a fresh macOS consumer package outside this checkout, declare a dependency
   on `https://github.com/open-ortho/dicom4ortho.git` at that exact version and use
   `.product(name: "DICOM4Ortho", package: "dicom4ortho")` in a target. Resolve,
   build, run a small documented example, and verify bundled terminology loads
   without Python or source-generation commands. This checks the published tag
   and root manifest, not a local path override. A failed release needs a new tag.
9. If maintaining a Swift Package Index listing, verify it discovers the tag and
   reports the declared compatibility. Index ingestion is not proof of clinical
   conformance or a substitute for the qualification above.

## Automation boundary

Swift tests, platform builds, DocC, and independent validation are currently run
manually on a compatible Mac; their current results/limitations are in the
development record. The PyPI workflow does **not** validate or upload Swift.
Do not add an unconditional Swift publish job: Git tags already distribute it.
A future macOS qualification workflow should implement the checks above using an
explicit compatible Xcode/Swift toolchain before shared release tagging.

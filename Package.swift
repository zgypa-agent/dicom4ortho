// swift-tools-version: 6.4
// This language-specific manifest intentionally stays at the repository root:
// SwiftPM resolves a Git-URL dependency from its root Package.swift and has no
// subdirectory selector. Moving it into apple/ would support local --package-path
// builds but break direct installation from this repository URL. Sources, tests,
// and Swift documentation remain under apple/. See README.md#repository-layout.
import PackageDescription

let package = Package(
    name: "DICOM4Ortho",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "DICOM4Ortho", targets: ["DICOM4Ortho"])],
    dependencies: [
        .package(url: "https://github.com/raster-labs/DICOMKit.git", exact: "2.7.0")
    ],
    targets: [
        .target(
            name: "DICOM4Ortho",
            dependencies: [.product(name: "DICOMKit", package: "DICOMKit")],
            path: "apple/Sources/DICOM4Ortho",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "DICOM4OrthoTests",
            dependencies: ["DICOM4Ortho", .product(name: "DICOMKit", package: "DICOMKit")],
            path: "apple/Tests/DICOM4OrthoTests"
        )
    ],
    swiftLanguageModes: [.v6]
)

import Foundation
import Testing
import DICOMCore
import DICOMKit
@testable import DICOM4Ortho

@Test func materializesAllReviewedViews() throws {
    let terminology = try Terminology.bundled()
    for keyword in terminology.imageTypes.keys.sorted() {
        var metadata = PhotographMetadata(imageType: keyword)
        if ["IV28", "IV30", "EV40"].contains(keyword) {
            metadata.directionKeyword = "projection_right"
        }
        metadata.patientGivenName = "Alex"
        metadata.patientFamilyName = "Example"
        let photo = try OrthodonticPhotograph(
            rgb8: Data([255, 0, 0]), width: 1, height: 1, metadata: metadata)
        let bytes = try photo.dicomData()
        let file = try DICOMFile.read(from: bytes)
        #expect(file.sopClassUID == "1.2.840.10008.5.1.4.1.1.77.1.4")
        #expect(file.sopInstanceUID == metadata.sopInstanceUID)
        #expect(file.dataSet.string(for: .patientName) == "Example^Alex")
        #expect(file.dataSet.sequence(for: .anatomicRegionSequence)?.count == 1)
        #expect(file.dataSet[.pixelData]?.valueData.prefix(3) == Data([255, 0, 0]))
        if keyword == "IV29" {
            #expect(file.dataSet[.viewCodeSequence] == nil)
        }
        if ["IV28", "IV30"].contains(keyword) {
            #expect(file.dataSet[.patientOrientation] != nil)
            #expect(file.dataSet.string(for: .patientOrientation) == "")
        }
        if let directory = ProcessInfo.processInfo.environment["DICOM4ORTHO_TEST_ARTIFACTS"] {
            let url = URL(fileURLWithPath: directory, isDirectory: true)
                .appendingPathComponent("views", isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try bytes.write(to: url.appendingPathComponent(keyword + ".dcm"))
        }
    }
}

@Test func rejectsIncompleteAndInconsistentInputs() throws {
    let pixel = Data([0, 0, 0])
    #expect(throws: MaterializationError.invalidPixelData) {
        try OrthodonticPhotograph(
            rgb8: pixel, width: 2, height: 1, metadata: .init(imageType: "EV01"))
    }
    #expect(throws: MaterializationError.directionRequired("IV28")) {
        try OrthodonticPhotograph(
            rgb8: pixel, width: 1, height: 1, metadata: .init(imageType: "IV28"))
    }
    #expect(throws: MaterializationError.unknownImageType("unknown")) {
        try OrthodonticPhotograph(
            rgb8: pixel, width: 1, height: 1, metadata: .init(imageType: "unknown"))
    }
}

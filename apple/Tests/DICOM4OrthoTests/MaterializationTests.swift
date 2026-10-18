import Foundation
import Testing
import DICOMCore
import DICOMKit
@testable import DICOM4Ortho

@Test func materializesAllReviewedViews() throws {
    let materializer = try OrthodonticPhotograph()
    let terminology = try Terminology.bundled()
    for keyword in terminology.imageTypes.keys.sorted() {
        var metadata = PhotographMetadata(imageType: keyword)
        if ["IV28", "IV30", "EV40"].contains(keyword) {
            metadata.directionKeyword = "projection_right"
        }
        metadata.patientGivenName = "Alex"
        metadata.patientFamilyName = "Example"
        let bytes = try materializer.materializeRGB8(
            pixels: Data([255, 0, 0]), width: 1, height: 1, metadata: metadata)
        let file = try DICOMFile.read(from: bytes)
        #expect(file.sopClassUID == "1.2.840.10008.5.1.4.1.1.77.1.4")
        #expect(file.sopInstanceUID == metadata.sopInstanceUID)
        #expect(file.dataSet.string(for: .patientName) == "Example^Alex")
        #expect(file.dataSet.sequence(for: .anatomicRegionSequence)?.count == 1)
        #expect(file.dataSet[.pixelData]?.valueData.prefix(3) == Data([255, 0, 0]))
        if keyword == "IV29" {
            #expect(file.dataSet[.viewCodeSequence] == nil)
        }
    }
}

@Test func rejectsIncompleteAndInconsistentInputs() throws {
    let materializer = try OrthodonticPhotograph()
    let pixel = Data([0, 0, 0])
    #expect(throws: MaterializationError.invalidPixelData) {
        try materializer.materializeRGB8(
            pixels: pixel, width: 2, height: 1, metadata: .init(imageType: "EV01"))
    }
    #expect(throws: MaterializationError.directionRequired("IV28")) {
        try materializer.materializeRGB8(
            pixels: pixel, width: 1, height: 1, metadata: .init(imageType: "IV28"))
    }
    #expect(throws: MaterializationError.unknownImageType("unknown")) {
        try materializer.materializeRGB8(
            pixels: pixel, width: 1, height: 1, metadata: .init(imageType: "unknown"))
    }
}

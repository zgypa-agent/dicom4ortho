import Foundation
import Testing
import DICOMCore
import DICOMKit
@testable import DICOM4Ortho

@Test func preservesBaselineJPEGBitstreamAndIdentity() throws {
    let materializer = try OrthodonticPhotograph()
    let original = try materializer.materializeRGB8(
        pixels: Data(repeating: 127, count: 32 * 32 * 3), width: 32, height: 32,
        metadata: .init(imageType: "EV01"), encoding: .jpegBaseline(quality: 0.9))
    let source = try DICOMFile.read(from: original)
    var jpeg = try #require(source.dataSet[.pixelData]?.encapsulatedFragments?.first)
    if jpeg.last == 0 { jpeg.removeLast() } // DICOM even-length padding, not JPEG data.
    let metadata = PhotographMetadata(imageType: "EV01")
    let data = try materializer.materializeJPEG(imageData: jpeg, metadata: metadata)
    let file = try DICOMFile.read(from: data)
    let frame = try #require(file.dataSet[.pixelData]?.encapsulatedFragments?.first)
    #expect(frame.prefix(jpeg.count) == jpeg)
    #expect(frame.count - jpeg.count <= 1)
    #expect(file.sopInstanceUID == metadata.sopInstanceUID)
    #expect(file.dataSet.string(for: .lossyImageCompression) == "01")
    #expect(file.dataSet.strings(for: .imageType)?.first == "ORIGINAL")
}

@Test func rejectsTruncatedOrNonBaselineJPEG() throws {
    let materializer = try OrthodonticPhotograph()
    for bytes in [Data(), Data([0xff, 0xd8, 0xff, 0xe0, 0xff, 0xff, 0xff, 0xd9]),
                  Data([0xff, 0xd8, 0xff, 0xc2, 0, 2, 0xff, 0xd9])] {
        #expect(throws: MaterializationError.unsupportedJPEG) {
            try materializer.materializeJPEG(imageData: bytes, metadata: .init(imageType: "EV01"))
        }
    }
}

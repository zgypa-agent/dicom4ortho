import Foundation
import Testing
import DICOMCore
import DICOMKit
@testable import DICOM4Ortho

@Test func preservesBaselineJPEGBitstreamAndIdentity() throws {
    let original = try OrthodonticPhotograph(
        rgb8: Data(repeating: 127, count: 32 * 32 * 3), width: 32, height: 32,
        metadata: .init(imageType: "EV01"), encoding: .jpegBaseline(quality: 0.9))
    let source = try DICOMFile.read(from: original.dicomData())
    var jpeg = try #require(source.dataSet[.pixelData]?.encapsulatedFragments?.first)
    if jpeg.last == 0 { jpeg.removeLast() } // DICOM even-length padding, not JPEG data.
    let metadata = PhotographMetadata(imageType: "EV01")
    let photo = try OrthodonticPhotograph(jpeg: jpeg, metadata: metadata)
    let data = try photo.dicomData()
    let file = try DICOMFile.read(from: data)
    let frame = try #require(file.dataSet[.pixelData]?.encapsulatedFragments?.first)
    #expect(frame.prefix(jpeg.count) == jpeg)
    #expect(frame.count - jpeg.count <= 1)
    #expect(file.sopInstanceUID == metadata.sopInstanceUID)
    #expect(file.dataSet.string(for: .lossyImageCompression) == "01")
    #expect(file.dataSet.strings(for: .imageType)?.first == "ORIGINAL")
}

@Test func rejectsTruncatedOrNonBaselineJPEG() throws {
    for bytes in [Data(), Data([0xff, 0xd8, 0xff, 0xe0, 0xff, 0xff, 0xff, 0xd9]),
                  Data([0xff, 0xd8, 0xff, 0xc2, 0, 2, 0xff, 0xd9])] {
        #expect(throws: MaterializationError.unsupportedJPEG) {
            try OrthodonticPhotograph(jpeg: bytes, metadata: .init(imageType: "EV01"))
        }
    }
}

@Test func jpegFileAndMemoryInputsCreateEquivalentPhotographs() throws {
    let encoded = try OrthodonticPhotograph(
        rgb8: Data(repeating: 127, count: 32 * 32 * 3), width: 32, height: 32,
        metadata: .init(imageType: "EV01"), encoding: .jpegBaseline(quality: 0.9))
    var jpeg = try #require(encoded.dataSet[.pixelData]?.encapsulatedFragments?.first)
    if jpeg.last == 0 { jpeg.removeLast() }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = directory.appendingPathComponent("image-without-extension")
    try jpeg.write(to: source)
    let metadata = PhotographMetadata(imageType: "EV01")
    let memory = try OrthodonticPhotograph(jpeg: jpeg, metadata: metadata)
    let file = try OrthodonticPhotograph(contentsOf: source, metadata: metadata)
    #expect(try memory.dicomData() == file.dicomData())
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).count == 1)
    #expect(throws: (any Error).self) {
        try OrthodonticPhotograph(contentsOf: directory.appendingPathComponent("missing.jpg"),
                                 metadata: metadata)
    }
    #expect(throws: CocoaError(.fileReadUnsupportedScheme)) {
        try OrthodonticPhotograph(
            contentsOf: #require(URL(string: "https://example.invalid/image.jpg")), metadata: metadata)
    }
    try Data([0x89, 0x50, 0x4e, 0x47]).write(to: source)
    #expect(throws: MaterializationError.unsupportedJPEG) {
        try OrthodonticPhotograph(contentsOf: source, metadata: metadata)
    }
}

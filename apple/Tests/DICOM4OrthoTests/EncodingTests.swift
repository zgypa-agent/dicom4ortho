import Foundation
import Testing
import DICOMCore
import DICOMKit
@testable import DICOM4Ortho

private let encodings: [(String, PhotographEncoding)] = [
    ("explicit-le", .explicitLittleEndian),
    ("implicit-le", .implicitLittleEndian),
    ("jpeg-baseline", .jpegBaseline(quality: 0.9)),
    ("jpeg-lossless", .jpegLossless),
    ("jpeg-ls-lossless", .jpegLSLossless),
    ("jpeg2000-lossless", .jpeg2000Lossless),
    ("jpeg2000-lossy", .jpeg2000Lossy(quality: 0.9)),
    ("htj2k-lossless", .htj2kLossless),
    ("htj2k-rpcl", .htj2kLosslessRPCL),
    ("htj2k-lossy", .htj2kLossy(quality: 0.9)),
    ("jpeg-xl-lossless", .jpegXLLossless),
    ("jpeg-xl-lossy", .jpegXLLossy(quality: 0.9)),
    ("rle", .rleLossless)
]

@Test func encodeSyntheticRGBPhotographs() throws {
    let size = Int(ProcessInfo.processInfo.environment["DICOM4ORTHO_TEST_IMAGE_SIZE"] ?? "64") ?? 64
    #expect((16...4096).contains(size))
    var samples = Data()
    for y in 0..<size {
        for x in 0..<size {
            samples.append(contentsOf: [UInt8(truncatingIfNeeded: x * 4),
                                       UInt8(truncatingIfNeeded: y * 4),
                                       UInt8(truncatingIfNeeded: (x + y) * 2)])
        }
    }
    let materializer = try OrthodonticPhotograph()
    for (name, encoding) in encodings {
        let metadata = PhotographMetadata(imageType: "EV01")
        let data = try materializer.materializeRGB8(
            pixels: samples, width: size, height: size,
            metadata: metadata, encoding: encoding)
        let file = try DICOMFile.read(from: data)
        #expect(file.transferSyntaxUID == encoding.transferSyntaxUID, "\(name)")
        #expect(file.dataSet.string(for: .lossyImageCompression)
                == (encoding.quality == nil ? "00" : "01"), "\(name)")
        #expect(file.sopInstanceUID == file.fileMetaInformation.string(for: .mediaStorageSOPInstanceUID))
        #expect(file.sopInstanceUID == metadata.sopInstanceUID)
        if let directory = ProcessInfo.processInfo.environment["DICOM4ORTHO_TEST_ARTIFACTS"] {
            let url = URL(fileURLWithPath: directory, isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try data.write(to: url.appendingPathComponent(name + ".dcm"))
            try samples.write(to: url.appendingPathComponent("source.rgb"))
            try JSONSerialization.data(withJSONObject: ["width": size, "height": size])
                .write(to: url.appendingPathComponent("source.json"))
        }
    }
}

@Test func rejectsInvalidCompressionQuality() throws {
    for quality in [Double.nan, Double.infinity, -1, 0, 1, 2] {
        #expect(throws: MaterializationError.invalidCompressionQuality) {
            try OrthodonticPhotograph().materializeRGB8(
                pixels: Data([0, 0, 0]), width: 1, height: 1,
                metadata: .init(imageType: "EV01"), encoding: .jpeg2000Lossy(quality: quality))
        }
    }
}

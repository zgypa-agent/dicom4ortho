import Foundation
import DICOMCore
import DICOMKit

extension OrthodonticPhotograph {
    /// Preserve an existing 8-bit, three-component baseline JPEG without recompression.
    /// Other JPEG processes are rejected rather than mislabeled as JPEG Baseline.
    public func materializeJPEG(imageData: Data, metadata: PhotographMetadata) throws -> Data {
        let dimensions = try Self.baselineJPEGDimensions(imageData)
        var dataset = try makeMetadata(metadata)
        dataset.setUInt16(dimensions.height, for: .rows)
        dataset.setUInt16(dimensions.width, for: .columns)
        dataset.setUInt16(3, for: .samplesPerPixel)
        dataset.setUInt16(0, for: .planarConfiguration)
        dataset.setUInt16(8, for: .bitsAllocated)
        dataset.setUInt16(8, for: .bitsStored)
        dataset.setUInt16(7, for: .highBit)
        dataset.setUInt16(0, for: .pixelRepresentation)
        // Same supported source layout as the Python JPEG path, PS3.5 8.2.1.
        dataset.setString("YBR_FULL_422", for: .photometricInterpretation, vr: .CS)
        dataset.setString("01", for: .lossyImageCompression, vr: .CS)
        dataset.setString("ISO_10918_1", for: .lossyImageCompressionMethod, vr: .CS)
        let ratio = Double(dimensions.width) * Double(dimensions.height) * 3
            / Double(imageData.count)
        dataset.setString(DICOMDecimalString(value: ratio).dicomString,
                          for: .lossyImageCompressionRatio, vr: .DS)
        dataset[.pixelData] = DataElement(
            tag: .pixelData, vr: .OB, length: .max, valueData: Data(),
            encapsulatedFragments: [imageData], encapsulatedOffsetTable: [0])
        return try DICOMFile.create(dataSet: dataset,
                                    transferSyntaxUID: "1.2.840.10008.1.2.4.50").write()
    }

    /// Inspect only the JPEG frame header (ITU-T T.81 B.2.2); no codec is implemented here.
    private static func baselineJPEGDimensions(_ data: Data) throws -> (width: UInt16, height: UInt16) {
        let bytes = [UInt8](data)
        guard bytes.count >= 4, bytes[0] == 0xff, bytes[1] == 0xd8,
              bytes[bytes.count - 2] == 0xff, bytes.last == 0xd9 else {
            throw MaterializationError.unsupportedJPEG
        }
        var position = 2
        while position + 4 <= bytes.count {
            guard bytes[position] == 0xff else { throw MaterializationError.unsupportedJPEG }
            let marker = bytes[position + 1]
            if marker == 0xff { position += 1; continue }
            let length = Int(bytes[position + 2]) * 256 + Int(bytes[position + 3])
            guard length >= 2, length <= bytes.count - position - 2 else {
                throw MaterializationError.unsupportedJPEG
            }
            let isFrame = (0xc0...0xcf).contains(marker) && ![0xc4, 0xc8, 0xcc].contains(marker)
            if isFrame {
                guard marker == 0xc0, length == 17, bytes[position + 4] == 8,
                      bytes[position + 9] == 3,
                      let components = JPEGInterchangeFormat.frameComponents(in: data),
                      components.map(\.identifier) == [1, 2, 3] else {
                    throw MaterializationError.unsupportedJPEG
                }
                let height = UInt16(bytes[position + 5]) * 256 + UInt16(bytes[position + 6])
                let width = UInt16(bytes[position + 7]) * 256 + UInt16(bytes[position + 8])
                guard width > 0, height > 0 else { throw MaterializationError.unsupportedJPEG }
                return (width, height)
            }
            guard marker != 0xda, marker != 0xd9 else { throw MaterializationError.unsupportedJPEG }
            position += length + 2
        }
        throw MaterializationError.unsupportedJPEG
    }
}

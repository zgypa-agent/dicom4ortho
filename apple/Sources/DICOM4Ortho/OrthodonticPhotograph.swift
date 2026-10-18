import Foundation
import DICOMCore
import DICOMKit

/// One orthodontic photograph, with a dataset and separate serialization/save operations.
///
/// Like Python's photograph model, construction maps the clinical context and
/// prepares image data without writing a file. Swift uses a value type: copying
/// a photograph and editing its dataset does not edit the original value.
public struct OrthodonticPhotograph: Sendable {
    /// The photograph's DICOMKit dataset, available for inspection and advanced edits.
    ///
    /// This is a dependency-specific escape hatch, analogous to Python's pydicom
    /// dataset. Edits are not automatically remapped from the clinical profile.
    /// Callers must preserve pixel layout, encoding, and IOD/sequence consistency;
    /// serialization validates identity but is not a complete conformance validator.
    public var dataSet: DataSet

    /// The representation selected at construction. Serialization does not re-encode pixels.
    public let transferSyntaxUID: String

    /// Construct a photograph from row-major, interleaved RGB8 samples without file I/O.
    ///
    /// - Parameters:
    ///   - rgb8: Exactly three bytes per pixel, with no padding or alpha.
    ///   - width: Positive column count, at most 65535.
    ///   - height: Positive row count, at most 65535.
    ///   - metadata: Explicit patient/acquisition context and final instance identity.
    ///   - encoding: Explicit loss policy; defaults to uncompressed Explicit VR Little Endian.
    /// - Throws: Profile/input errors, resource decoding errors, or DICOMKit codec errors.
    ///
    /// Encoding happens during construction and may be CPU/memory intensive. Codec
    /// APIs may use a private serialized intermediate; that is not a published
    /// predecessor and does not change the final caller-supplied SOP Instance UID.
    public init(
        rgb8: Data, width: Int, height: Int, metadata: PhotographMetadata,
        encoding: PhotographEncoding = .explicitLittleEndian
    ) throws {
        let file = try PhotographProfile().makeRGB8(
            pixels: rgb8, width: width, height: height, metadata: metadata, encoding: encoding)
        dataSet = file.dataSet
        transferSyntaxUID = encoding.transferSyntaxUID
    }

    /// Construct a photograph preserving a baseline-color JPEG without recompression.
    ///
    /// - Parameters:
    ///   - jpeg: Complete SOF0 JPEG stream, three 8-bit YCbCr components identified as 1/2/3.
    ///   - metadata: Clinical context; automatic EXIF import is not implemented yet.
    /// - Throws: ``MaterializationError/unsupportedJPEG`` for unsupported headers,
    ///   profile/input errors, resource errors, or underlying DICOMKit errors.
    ///
    /// Progressive/grayscale JPEG, MPO, and JP2 are not accepted. The original
    /// compressed stream is retained, apart from required DICOM even-length padding.
    public init(jpeg: Data, metadata: PhotographMetadata) throws {
        let file = try PhotographProfile().makeJPEG(imageData: jpeg, metadata: metadata)
        dataSet = file.dataSet
        transferSyntaxUID = TransferSyntax.jpegBaseline.uid
    }

    /// Read a local baseline-color JPEG and construct the same model as in-memory input.
    ///
    /// - Parameters:
    ///   - url: Local JPEG file. Format is checked from the bytes, not the filename extension.
    ///   - metadata: Explicit clinical context; EXIF import remains unsupported.
    /// - Throws: File-read errors, a Cocoa unsupported-URL error for non-file URLs,
    ///   or the same validation errors as ``init(jpeg:metadata:)``.
    ///
    /// No output path is inferred or written. Other image formats are not yet
    /// supported; this initializer never fetches remote URLs.
    public init(contentsOf url: URL, metadata: PhotographMetadata) throws {
        guard url.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
        try self.init(jpeg: Data(contentsOf: url), metadata: metadata)
    }

    /// Serialize the current dataset as complete DICOM Part 10 bytes, without file I/O.
    ///
    /// File Meta Information is regenerated from the current dataset so edits to
    /// instance identity cannot leave a stale Media Storage SOP Instance UID.
    /// Repeated calls do not regenerate identity or re-encode pixels.
    /// - Throws: ``MaterializationError/invalidUID(_:)`` for malformed/reused identity,
    ///   or the underlying writer error. Other arbitrary dataset edits are not validated.
    public func dicomData() throws -> Data {
        let uids = [Tag.studyInstanceUID, .seriesInstanceUID, .sopInstanceUID].map {
            dataSet.string(for: $0) ?? ""
        }
        for uid in uids where !PhotographProfile.isValidUID(uid) {
            throw MaterializationError.invalidUID(uid)
        }
        guard Set(uids).count == 3 else {
            throw MaterializationError.invalidUID("Study, series and instance UIDs must differ")
        }
        return try DICOMFile.create(dataSet: dataSet, transferSyntaxUID: transferSyntaxUID).write()
    }

    /// Write the current photograph to a local file, atomically replacing an existing file.
    ///
    /// The destination's parent directory must exist. No default destination is
    /// inferred from patient metadata. This is the only filesystem-writing operation.
    /// - Throws: Serialization errors, a Cocoa unsupported-URL error for non-file URLs,
    ///   or the underlying file-write error. Network delivery is not performed.
    public func save(to url: URL) throws {
        guard url.isFileURL else { throw CocoaError(.fileWriteUnsupportedScheme) }
        try dicomData().write(to: url, options: .atomic)
    }
}

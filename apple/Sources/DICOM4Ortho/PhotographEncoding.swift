/// Explicit output encoding for RGB8 photographs. Lossy compression is never implicit.
public enum PhotographEncoding: Sendable, Equatable {
    case explicitLittleEndian
    case implicitLittleEndian
    case jpegBaseline(quality: Double)
    case jpegLossless
    case jpegLSLossless
    case jpeg2000Lossless
    case jpeg2000Lossy(quality: Double)
    case htj2kLossless
    case htj2kLosslessRPCL
    case htj2kLossy(quality: Double)
    case jpegXLLossless
    case jpegXLLossy(quality: Double)
    case rleLossless

    var codec: String {
        switch self {
        case .explicitLittleEndian: "explicit-le"
        case .implicitLittleEndian: "implicit-le"
        case .jpegBaseline: "jpeg-baseline"
        case .jpegLossless: "jpeg-lossless-sv1"
        case .jpegLSLossless: "jpeg-ls-lossless"
        case .jpeg2000Lossless: "jpeg2000-lossless-only"
        case .jpeg2000Lossy: "jpeg2000-lossy"
        case .htj2kLossless: "htj2k-lossless-only"
        case .htj2kLosslessRPCL: "htj2k-rpcl-lossless-only"
        case .htj2kLossy: "htj2k-lossy"
        case .jpegXLLossless: "jpeg-xl-lossless-only"
        case .jpegXLLossy: "jpeg-xl-lossy"
        case .rleLossless: "rle"
        }
    }

    var quality: Double? {
        switch self {
        case .jpegBaseline(let value), .jpeg2000Lossy(let value),
             .htj2kLossy(let value), .jpegXLLossy(let value): value
        default: nil
        }
    }

    /// The requested syntax, not proof of codec conformance for a particular input.
    public var transferSyntaxUID: String {
        // DICOM PS3.6, Table A-1. Keep this independent of codec alias lookup.
        switch self {
        case .explicitLittleEndian: "1.2.840.10008.1.2.1"
        case .implicitLittleEndian: "1.2.840.10008.1.2"
        case .jpegBaseline: "1.2.840.10008.1.2.4.50"
        case .jpegLossless: "1.2.840.10008.1.2.4.70"
        case .jpegLSLossless: "1.2.840.10008.1.2.4.80"
        case .jpeg2000Lossless: "1.2.840.10008.1.2.4.90"
        case .jpeg2000Lossy: "1.2.840.10008.1.2.4.91"
        case .htj2kLossless: "1.2.840.10008.1.2.4.201"
        case .htj2kLosslessRPCL: "1.2.840.10008.1.2.4.202"
        case .htj2kLossy: "1.2.840.10008.1.2.4.203"
        case .jpegXLLossless: "1.2.840.10008.1.2.4.110"
        case .jpegXLLossy: "1.2.840.10008.1.2.4.112"
        case .rleLossless: "1.2.840.10008.1.2.5"
        }
    }
}

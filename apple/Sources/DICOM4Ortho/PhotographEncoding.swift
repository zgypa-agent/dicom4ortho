import DICOMCore

/// The compression policy for creating a photograph from RGB8 samples.
///
/// DICOMKit owns transfer-syntax identifiers and codec implementations. This enum
/// adds the library-specific choice of **intent**: a general JPEG 2000, HTJ2K, or
/// JPEG XL syntax can contain either reversible or irreversible data, so a syntax
/// UID alone cannot express whether additional loss is allowed. Associated quality
/// values keep lossy intent explicit at the call site; they are codec-specific
/// controls, not clinical fidelity guarantees. No compression happens by default.
public enum PhotographEncoding: Sendable, Equatable {
    /// Uncompressed RGB with explicit value representations (the default).
    case explicitLittleEndian
    /// Uncompressed RGB with implicit value representations.
    case implicitLittleEndian
    /// JPEG Baseline, using a finite quality strictly between zero and one.
    case jpegBaseline(quality: Double)
    /// Lossless JPEG Process 14, Selection Value 1 (not JPEG Baseline at quality 1).
    case jpegLossless
    /// Reversible JPEG-LS; near-lossless NEAR parameters are not exposed yet.
    case jpegLSLossless
    /// JPEG 2000's lossless-only transfer syntax.
    case jpeg2000Lossless
    /// Irreversible JPEG 2000 with an explicit quality in the open interval (0, 1).
    case jpeg2000Lossy(quality: Double)
    /// High-throughput JPEG 2000's lossless-only transfer syntax.
    case htj2kLossless
    /// HTJ2K's lossless resolution-position-component-layer progressive profile.
    case htj2kLosslessRPCL
    /// Irreversible HTJ2K with an explicit quality in the open interval (0, 1).
    case htj2kLossy(quality: Double)
    /// JPEG XL's lossless-only syntax, not reversible recompression of an existing JPEG.
    case jpegXLLossless
    /// Irreversible JPEG XL with an explicit quality in the open interval (0, 1).
    case jpegXLLossy(quality: Double)
    /// DICOM run-length encoding without sample loss.
    case rleLossless

    // CompressionManager's public API selects an encoder by name. These aliases
    // are an adapter to the pinned dependency, not another transfer-syntax registry.
    // EncodingTests checks that the actual File Meta UID agrees with `transferSyntax`.
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

    /// The requested transfer-syntax UID from DICOMKit's standard definitions.
    ///
    /// This describes the requested representation; it does not promise that every
    /// pixel layout is supported by the underlying codec. Materialization throws
    /// for unsupported inputs. The dependency's types remain an implementation
    /// detail: callers need only this String to inspect or record the output UID.
    public var transferSyntaxUID: String {
        transferSyntax.uid
    }

    var transferSyntax: TransferSyntax {
        switch self {
        case .explicitLittleEndian: .explicitVRLittleEndian
        case .implicitLittleEndian: .implicitVRLittleEndian
        case .jpegBaseline: .jpegBaseline
        case .jpegLossless: .jpegLosslessSV1
        case .jpegLSLossless: .jpegLSLossless
        case .jpeg2000Lossless: .jpeg2000Lossless
        case .jpeg2000Lossy: .jpeg2000
        case .htj2kLossless: .htj2kLossless
        case .htj2kLosslessRPCL: .htj2kRPCLLossless
        case .htj2kLossy: .htj2kLossy
        case .jpegXLLossless: .jpegXLLossless
        case .jpegXLLossy: .jpegXL
        case .rleLossless: .rleLossless
        }
    }
}

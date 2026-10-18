/// Invalid profile or image inputs detected before a DICOM instance can be returned.
///
/// These are dicom4ortho's validation errors. Resource decoding, file access, and
/// DICOMKit codec failures retain their underlying error types rather than being
/// hidden in a generic failure or converted to an empty output.
public enum MaterializationError: Error, Equatable {
    /// The normalized ADA photograph keyword is absent from the bundled mappings.
    case unknownImageType(String)
    /// A variable-direction view requires an explicit direction keyword.
    case directionRequired(String)
    /// The supplied direction keyword is absent from the terminology snapshot.
    case unknownDirection(String)
    /// Dimensions or byte count do not describe the supported RGB8 layout.
    case invalidPixelData
    /// A UID is malformed, too long, or reused across study/series/instance levels.
    case invalidUID(String)
    /// A structural concept needed by the profile is missing from the bundled data.
    case invalidTerminology(String)
    /// A lossy quality is not finite or not strictly between zero and one.
    case invalidCompressionQuality
    /// A year/month/day combination is not a valid Gregorian date.
    case invalidClinicalDate
    /// Treatment progress cannot be calculated without a photograph acquisition date.
    case acquisitionDateRequired
    /// The treatment event occurs after the acquisition calendar date.
    case treatmentEventAfterAcquisition
    /// The JPEG header is malformed or outside the current baseline-color import subset.
    case unsupportedJPEG
}

/// Canonical CID 4070 event types for TID 3465 acquisition context.
///
/// Raw values are terminology lookup keys, not DICOM Code Values. The actual
/// SNOMED CT concepts and display meanings come from the bundled terminology.
/// Deprecated Python aliases are intentionally not introduced into this new API.
public enum TreatmentEvent: String, Sendable {
    /// Registration used as the reference event for elapsed days.
    case patientRegistration = "PatientRegistration"
    /// Start of orthodontic treatment.
    case orthodonticTreatmentStarted = "OrthodonticTreatmentStarted"
    /// Stop of orthodontic treatment.
    case orthodonticTreatmentStopped = "OrthodonticTreatmentStopped"
}

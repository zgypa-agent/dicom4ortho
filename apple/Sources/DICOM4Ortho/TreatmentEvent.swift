/// Canonical CID 4070 event types for TID 3465 acquisition context.
///
/// Raw values are terminology lookup keys, not DICOM Code Values. The actual
/// SNOMED CT concepts and display meanings come from the bundled terminology.
/// Python's supported deprecated string aliases have not been ported yet; their
/// absence is an API-parity gap, not a removal from the Python compatibility contract.
public enum TreatmentEvent: String, Sendable {
    /// Registration used as the reference event for elapsed days.
    case patientRegistration = "PatientRegistration"
    /// Start of orthodontic treatment.
    case orthodonticTreatmentStarted = "OrthodonticTreatmentStarted"
    /// Stop of orthodontic treatment.
    case orthodonticTreatmentStopped = "OrthodonticTreatmentStopped"
}

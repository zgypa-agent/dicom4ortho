/// A treatment event and its calendar date, before calculation of the elapsed-day offset.
///
/// TID 3465 serializes the event code and offset in days, not the event's date.
/// Materialization calculates that offset against the photograph's acquisition
/// date in its specified timezone. Zero is valid; future events and a missing
/// acquisition date are errors. This value does not calculate progress at construction,
/// because the same event can be used for photographs acquired on different days.
public struct TreatmentProgress: Sendable {
    /// Reference event from CID 4070.
    public let event: TreatmentEvent
    /// Calendar date on which the reference event occurred.
    public let eventDate: ClinicalDate

    /// Store an event/date pair. Its relation to acquisition is checked during materialization.
    public init(event: TreatmentEvent, eventDate: ClinicalDate) {
        self.event = event
        self.eventDate = eventDate
    }
}

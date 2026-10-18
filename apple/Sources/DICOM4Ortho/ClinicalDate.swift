import Foundation

/// A calendar date, not an instant whose timezone might change its clinical day.
public struct ClinicalDate: Sendable, Equatable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: year, month: month, day: day)
        guard (1...9999).contains(year), let date = calendar.date(from: components),
              calendar.component(.year, from: date) == year,
              calendar.component(.month, from: date) == month,
              calendar.component(.day, from: date) == day else {
            throw MaterializationError.invalidClinicalDate
        }
        self.year = year
        self.month = month
        self.day = day
    }

    var dicomValue: String { String(format: "%04d%02d%02d", year, month, day) }

    func days(until other: ClinicalDate) throws -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let start = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              let end = calendar.date(from: DateComponents(
                year: other.year, month: other.month, day: other.day)),
              let days = calendar.dateComponents([.day], from: start, to: end).day else {
            throw MaterializationError.invalidClinicalDate
        }
        return days
    }
}

/// Canonical CID 4070 events used by TID 3465.
public enum TreatmentEvent: String, Sendable {
    case patientRegistration = "PatientRegistration"
    case orthodonticTreatmentStarted = "OrthodonticTreatmentStarted"
    case orthodonticTreatmentStopped = "OrthodonticTreatmentStopped"
}

/// The profile serializes the elapsed day offset, not the event's date itself.
public struct TreatmentProgress: Sendable {
    public let event: TreatmentEvent
    public let eventDate: ClinicalDate

    public init(event: TreatmentEvent, eventDate: ClinicalDate) {
        self.event = event
        self.eventDate = eventDate
    }
}

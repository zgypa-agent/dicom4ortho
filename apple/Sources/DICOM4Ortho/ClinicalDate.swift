import Foundation

/// A calendar date, not an instant whose timezone might change its clinical day.
///
/// Treatment-event dates have no time of day. Keeping year/month/day components
/// prevents daylight-saving transitions or timezone conversions from changing
/// the profile's elapsed calendar-day offset. Gregorian arithmetic uses UTC
/// internally only to make that calculation deterministic.
public struct ClinicalDate: Sendable, Equatable {
    /// Gregorian year, in the range 1 through 9999.
    public let year: Int
    /// Month number, 1 through 12.
    public let month: Int
    /// Day number valid for the selected month and year, including leap years.
    public let day: Int

    /// Construct a validated date without silently normalizing impossible dates.
    /// - Throws: ``MaterializationError/invalidClinicalDate`` for values such as February 30.
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

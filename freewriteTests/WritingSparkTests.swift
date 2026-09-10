import Foundation
import Testing

@testable import freewrite

struct WritingSparkTests {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test func sameDayAlwaysReturnsTheSameSpark() {
        let morning = utc.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 8))!
        let night = utc.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 22))!
        let first = WritingSpark.prompt(for: morning, calendar: utc)
        let second = WritingSpark.prompt(for: night, calendar: utc)
        #expect(!first.isEmpty)
        #expect(first == second)
    }

    @Test func neighboringDaysCanDiffer() {
        let day = utc.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 12))!
        let next = utc.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 12))!
        #expect(WritingSpark.prompt(for: day, calendar: utc) != WritingSpark.prompt(for: next, calendar: utc))
    }
}

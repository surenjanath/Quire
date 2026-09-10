import Foundation
import Testing

@testable import freewrite

struct JournalInsightsTests {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var today: Date {
        utc.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 12))!
    }

    @Test func parseCanonicalTimestamp() {
        let date = JournalInsights.parseTimestamp(
            from: "[00000000-0000-0000-0000-000000000001]-[2025-09-09-08-01-04].md",
            calendar: utc
        )
        #expect(date != nil)
        let parts = utc.dateComponents([.year, .month, .day], from: date!)
        #expect(parts.year == 2025)
        #expect(parts.month == 9)
        #expect(parts.day == 9)
        #expect(JournalInsights.parseTimestamp(from: "notes.md") == nil)
    }

    @Test func onThisDayIgnoresTodayAndOtherDays() {
        let files = [
            "[00000000-0000-0000-0000-000000000001]-[2026-09-09-10-00-00].md",
            "[00000000-0000-0000-0000-000000000002]-[2025-09-09-08-00-00].md",
            "[00000000-0000-0000-0000-000000000003]-[2024-09-09-08-00-00].md",
            "[00000000-0000-0000-0000-000000000004]-[2026-09-08-08-00-00].md",
        ]
        let matches = JournalInsights.onThisDay(filenames: files, today: today, calendar: utc)
        #expect(matches.map(\.filename) == [
            "[00000000-0000-0000-0000-000000000002]-[2025-09-09-08-00-00].md",
            "[00000000-0000-0000-0000-000000000003]-[2024-09-09-08-00-00].md",
        ])
    }

    @Test func weeklyWindowIncludesLastSevenDays() {
        let files = [
            "[00000000-0000-0000-0000-000000000001]-[2026-09-09-10-00-00].md",
            "[00000000-0000-0000-0000-000000000002]-[2026-09-03-08-00-00].md",
            "[00000000-0000-0000-0000-000000000003]-[2026-09-02-08-00-00].md",
        ]
        let matches = JournalInsights.entriesInLastDays(
            filenames: files,
            days: 7,
            now: today,
            calendar: utc
        )
        #expect(matches.map(\.filename) == [
            "[00000000-0000-0000-0000-000000000001]-[2026-09-09-10-00-00].md",
            "[00000000-0000-0000-0000-000000000002]-[2026-09-03-08-00-00].md",
        ])
    }

    @Test func sessionRecapFormatsWordsAndMinutes() {
        #expect(JournalInsights.sessionRecap(wordCount: 412, durationSeconds: 900) == "Session done · 412 words · 15 min")
        #expect(JournalInsights.sessionRecap(wordCount: 1, durationSeconds: 60) == "Session done · 1 word · 1 min")
        #expect(JournalInsights.sessionRecap(wordCount: 20, durationSeconds: 30) == "Session done · 20 words")
    }

    @Test func skipsGuideAndEmptyBodies() {
        #expect(JournalInsights.isGuideOrEmpty(""))
        #expect(JournalInsights.isGuideOrEmpty("\n\n"))
        #expect(JournalInsights.isGuideOrEmpty("hi. my name is farza.\nwelcome"))
        #expect(!JournalInsights.isGuideOrEmpty("I keep thinking about the river"))
    }

    @Test func compileWeeklyReviewJoinsDatedSections() {
        let compiled = JournalInsights.compileWeeklyReview(sections: [
            (title: "Sep 9", body: "one"),
            (title: "Sep 8", body: "two"),
        ])
        #expect(compiled.contains("## Sep 9"))
        #expect(compiled.contains("one"))
        #expect(compiled.contains("## Sep 8"))
    }

    @Test func typewriterOriginKeepsCaretCentered() {
        #expect(TypewriterScroll.originY(caretMidY: 400, visibleHeight: 600, contentHeight: 2000) == 100)
        #expect(TypewriterScroll.originY(caretMidY: 100, visibleHeight: 600, contentHeight: 2000) == 0)
        #expect(TypewriterScroll.originY(caretMidY: 1900, visibleHeight: 600, contentHeight: 2000) == 1400)
    }

    @Test func daysWithEntriesCollectsUniqueDaysInMonth() {
        let files = [
            "[00000000-0000-0000-0000-000000000001]-[2026-09-09-10-00-00].md",
            "[00000000-0000-0000-0000-000000000002]-[2026-09-09-18-00-00].md",
            "[00000000-0000-0000-0000-000000000003]-[2026-09-01-08-00-00].md",
            "[00000000-0000-0000-0000-000000000004]-[2026-08-31-08-00-00].md",
        ]
        let month = utc.date(from: DateComponents(year: 2026, month: 9, day: 15))!
        #expect(JournalInsights.daysWithEntries(in: month, filenames: files, calendar: utc) == [1, 9])
    }

    @Test func latestEntryOnDayPicksTheNewest() {
        let files = [
            "[00000000-0000-0000-0000-000000000001]-[2026-09-09-10-00-00].md",
            "[00000000-0000-0000-0000-000000000002]-[2026-09-09-18-00-00].md",
            "[00000000-0000-0000-0000-000000000003]-[2026-09-08-08-00-00].md",
        ]
        let day = utc.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 12))!
        #expect(
            JournalInsights.latestEntry(on: day, filenames: files, calendar: utc)?.filename
                == "[00000000-0000-0000-0000-000000000002]-[2026-09-09-18-00-00].md"
        )
        let empty = utc.date(from: DateComponents(year: 2026, month: 9, day: 10))!
        #expect(JournalInsights.latestEntry(on: empty, filenames: files, calendar: utc) == nil)
    }

    @Test func monthCellsPadsToFullWeeksFromFirstWeekday() {
        var calendar = utc
        calendar.firstWeekday = 1 // Sunday
        let month = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        let cells = JournalInsights.monthCells(for: month, calendar: calendar)
        #expect(cells.count % 7 == 0)
        #expect(cells[0] == nil) // 2026-09-01 is a Tuesday
        #expect(cells[1] == nil)
        let first = cells.compactMap { $0 }.first
        let last = cells.compactMap { $0 }.last
        #expect(calendar.component(.day, from: first!) == 1)
        #expect(calendar.component(.day, from: last!) == 30)
        #expect(cells.filter { $0 == nil }.count >= 2)
    }
}

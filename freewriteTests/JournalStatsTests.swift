import Foundation
import Testing

@testable import freewrite

struct JournalStatsTests {
    @Test func summarizesTotalsLongestEntryAndTopTag() {
        let facts = [
            JournalStats.EntryFacts(words: 10, tags: ["river"]),
            JournalStats.EntryFacts(words: 40, tags: ["river", "morning"]),
            JournalStats.EntryFacts(words: 5, tags: []),
        ]
        let summary = JournalStats.summarize(facts, streakDays: [])
        #expect(summary.totalEntries == 3)
        #expect(summary.totalWords == 55)
        #expect(summary.longestEntryWords == 40)
        #expect(summary.topTag == "river")
        #expect(summary.topTagCount == 2)
    }

    @Test func emptyJournalHasNoStats() {
        #expect(JournalStats.summarize([], streakDays: []) == .empty)
    }

    @Test func longestStreakDedupsAndBreaksOnGaps() {
        let calendar = Calendar.current
        let day1 = Date(timeIntervalSince1970: 1_778_000_000)
        let day2 = calendar.date(byAdding: .day, value: 1, to: day1)!
        let day3 = calendar.date(byAdding: .day, value: 2, to: day1)!
        let day5 = calendar.date(byAdding: .day, value: 4, to: day1)!

        #expect(JournalStats.longestStreak(days: []) == 0)
        #expect(JournalStats.longestStreak(days: [day1]) == 1)
        #expect(JournalStats.longestStreak(days: [day1, day1, day2]) == 2)
        #expect(JournalStats.longestStreak(days: [day1, day3]) == 1)
        #expect(JournalStats.longestStreak(days: [day1, day2, day3, day5]) == 3)
    }

    @Test func topTagTiesBreakAlphabetically() {
        let summary = JournalStats.summarize([
            JournalStats.EntryFacts(words: 1, tags: ["writing"]),
            JournalStats.EntryFacts(words: 1, tags: ["morning"]),
        ], streakDays: [])
        #expect(summary.topTag == "morning")
        #expect(summary.topTagCount == 1)
    }

    @Test func bestStreakIgnoresContentFilteringOnFacts() {
        // facts (totals/tags) can be empty while streakDays (any day with a file) still counts —
        // matches the live streak badge, which doesn't care whether that day's page has content.
        let calendar = Calendar.current
        let day1 = Date(timeIntervalSince1970: 1_778_000_000)
        let day2 = calendar.date(byAdding: .day, value: 1, to: day1)!
        let summary = JournalStats.summarize([], streakDays: [day1, day2])
        #expect(summary.totalEntries == 0)
        #expect(summary.bestStreak == 2)
    }
}

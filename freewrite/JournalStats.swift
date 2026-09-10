//
//  JournalStats.swift
//  freewrite
//
//  Lifetime numbers across the whole journal: totals, the longest
//  entry, the best streak ever, and the most-used tag.
//

import Foundation
import SwiftUI

enum JournalStats {
    struct EntryFacts: Equatable {
        let words: Int
        let tags: [String]
    }

    struct Summary: Equatable {
        let totalEntries: Int
        let totalWords: Int
        let longestEntryWords: Int
        let bestStreak: Int
        let topTag: String?
        let topTagCount: Int

        static let empty = Summary(totalEntries: 0, totalWords: 0, longestEntryWords: 0, bestStreak: 0, topTag: nil, topTagCount: 0)
    }

    /// `facts` excludes the welcome guide and empty pages (nothing to count). `streakDays` is every
    /// entry's calendar day with no such filtering — a day you opened the page counts toward the
    /// streak the same way it does for the live streak badge in History, so the two numbers agree.
    static func summarize(_ facts: [EntryFacts], streakDays: [Date], calendar: Calendar = .current) -> Summary {
        let bestStreak = longestStreak(days: streakDays, calendar: calendar)
        guard !facts.isEmpty else {
            return Summary(totalEntries: 0, totalWords: 0, longestEntryWords: 0, bestStreak: bestStreak, topTag: nil, topTagCount: 0)
        }

        let totalWords = facts.reduce(0) { $0 + $1.words }
        let longestEntryWords = facts.map(\.words).max() ?? 0

        var tagCounts: [String: Int] = [:]
        for fact in facts {
            for tag in fact.tags {
                tagCounts[tag, default: 0] += 1
            }
        }
        // Highest count first; ties break alphabetically (not dictionary order, which isn't stable).
        let top = tagCounts
            .sorted { lhs, rhs in lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key < rhs.key }
            .first

        return Summary(
            totalEntries: facts.count,
            totalWords: totalWords,
            longestEntryWords: longestEntryWords,
            bestStreak: bestStreak,
            topTag: top?.key,
            topTagCount: top?.value ?? 0
        )
    }

    static func longestStreak(days: [Date], calendar: Calendar = .current) -> Int {
        let uniqueDays = Set(days.map { calendar.startOfDay(for: $0) })
        guard !uniqueDays.isEmpty else { return 0 }
        let sorted = uniqueDays.sorted()

        var longest = 1
        var current = 1
        for i in 1..<sorted.count {
            let gap = calendar.dateComponents([.day], from: sorted[i - 1], to: sorted[i]).day ?? 0
            current = gap == 1 ? current + 1 : 1
            longest = max(longest, current)
        }
        return longest
    }
}

struct StatsPanelView: View {
    let summary: JournalStats.Summary
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Journal stats")
                    .font(.system(size: 13))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if summary.totalEntries == 0 {
                Text("Write a little and these will fill in.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(14)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    row("Entries", "\(summary.totalEntries)")
                    row("Words written", "\(summary.totalWords)")
                    row("Longest entry", "\(summary.longestEntryWords) words")
                    row("Best streak", "\(summary.bestStreak) day\(summary.bestStreak == 1 ? "" : "s")")
                    if let topTag = summary.topTag {
                        row("Most-used tag", "#\(topTag) (\(summary.topTagCount)\u{00d7})")
                    }
                }
                .padding(14)
            }
        }
        .frame(width: 300)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.18), radius: 16, y: 8)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
        }
    }
}

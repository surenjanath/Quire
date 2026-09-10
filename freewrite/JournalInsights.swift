//
//  JournalInsights.swift
//  freewrite
//
//  Date math over canonical entry filenames: on-this-day, last-N-days,
//  weekly review compilation, and the timer session recap line.
//

import Foundation

struct JournalDatedEntry: Equatable {
    let filename: String
    let timestamp: Date
}

enum JournalInsights {
    static func parseTimestamp(from filename: String, calendar: Calendar = .current) -> Date? {
        guard let components = parseComponents(from: filename) else { return nil }
        return calendar.date(from: components)
    }

    static func onThisDay(
        filenames: [String],
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [JournalDatedEntry] {
        let todayMonth = calendar.component(.month, from: today)
        let todayDay = calendar.component(.day, from: today)
        let todayYear = calendar.component(.year, from: today)

        return datedEntries(from: filenames, calendar: calendar)
            .filter { entry in
                guard let components = parseComponents(from: entry.filename) else { return false }
                return components.month == todayMonth
                    && components.day == todayDay
                    && (components.year ?? todayYear) < todayYear
            }
            .sorted { $0.timestamp > $1.timestamp }
    }

    static func entriesInLastDays(
        filenames: [String],
        days: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [JournalDatedEntry] {
        let startOfToday = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -(days - 1), to: startOfToday) else {
            return []
        }

        return datedEntries(from: filenames, calendar: calendar)
            .filter { $0.timestamp >= windowStart && $0.timestamp <= now }
            .sorted { $0.timestamp > $1.timestamp }
    }

    static func sessionRecap(wordCount: Int, durationSeconds: Int) -> String {
        let wordLabel = wordCount == 1 ? "1 word" : "\(wordCount) words"
        let minutes = durationSeconds / 60
        if minutes < 1 {
            return "Session done · \(wordLabel)"
        }
        let minuteLabel = minutes == 1 ? "1 min" : "\(minutes) min"
        return "Session done · \(wordLabel) · \(minuteLabel)"
    }

    static func isGuideOrEmpty(_ body: String) -> Bool {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        return trimmed.hasPrefix("hi. my name is farza.")
    }

    static func compileWeeklyReview(sections: [(title: String, body: String)]) -> String {
        sections
            .filter { !isGuideOrEmpty($1) }
            .map { title, body in "## \(title)\n\n\(body.trimmingCharacters(in: .whitespacesAndNewlines))" }
            .joined(separator: "\n\n")
    }

    static func displayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    static func monthTitle(_ date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    static func daysWithEntries(
        in month: Date,
        filenames: [String],
        calendar: Calendar = .current
    ) -> Set<Int> {
        let year = calendar.component(.year, from: month)
        let monthNumber = calendar.component(.month, from: month)
        return Set(datedEntries(from: filenames, calendar: calendar).compactMap { entry in
            let parts = calendar.dateComponents([.year, .month, .day], from: entry.timestamp)
            guard parts.year == year, parts.month == monthNumber else { return nil }
            return parts.day
        })
    }

    static func latestEntry(
        on day: Date,
        filenames: [String],
        calendar: Calendar = .current
    ) -> JournalDatedEntry? {
        datedEntries(from: filenames, calendar: calendar)
            .filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
            .max { $0.timestamp < $1.timestamp }
    }

    static func monthCells(for month: Date, calendar: Calendar = .current) -> [Date?] {
        let comps = calendar.dateComponents([.year, .month], from: month)
        guard let start = calendar.date(from: comps),
              let dayRange = calendar.range(of: .day, in: .month, for: start) else {
            return []
        }

        let weekday = calendar.component(.weekday, from: start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in dayRange {
            cells.append(calendar.date(byAdding: .day, value: day - 1, to: start))
        }
        while !cells.isEmpty && cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }

    private static func datedEntries(from filenames: [String], calendar: Calendar) -> [JournalDatedEntry] {
        filenames.compactMap { filename in
            guard let timestamp = parseTimestamp(from: filename, calendar: calendar) else { return nil }
            return JournalDatedEntry(filename: filename, timestamp: timestamp)
        }
    }

    private static func parseComponents(from filename: String) -> DateComponents? {
        guard filename.hasPrefix("["),
              filename.hasSuffix("].md"),
              let divider = filename.range(of: "]-[") else {
            return nil
        }

        let timestampStart = divider.upperBound
        let timestampEnd = filename.index(filename.endIndex, offsetBy: -4)
        let parts = String(filename[timestampStart..<timestampEnd]).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 6 else { return nil }

        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = parts[3]
        components.minute = parts[4]
        components.second = parts[5]
        return components
    }
}

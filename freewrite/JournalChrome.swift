//
//  JournalChrome.swift
//  freewrite
//
//  Quiet History companions: a month heatmap and a play strip for voice notes.
//

import SwiftUI
import AppKit
import AVFoundation

struct HistoryMonthGrid: View {
    let month: Date
    let filenames: [String]
    let selectedFilename: String?
    let onSelectFilename: (String) -> Void
    let onShiftMonth: (Int) -> Void

    private var calendar: Calendar { .current }

    private var daysWithEntries: Set<Int> {
        JournalInsights.daysWithEntries(in: month, filenames: filenames, calendar: calendar)
    }

    private var selectedDay: Int? {
        guard let selectedFilename,
              let timestamp = JournalInsights.parseTimestamp(from: selectedFilename, calendar: calendar),
              calendar.isDate(timestamp, equalTo: month, toGranularity: .month) else {
            return nil
        }
        return calendar.component(.day, from: timestamp)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: { onShiftMonth(-1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Previous month")

                Text(JournalInsights.monthTitle(month, calendar: calendar))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)

                Button(action: { onShiftMonth(1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Next month")
            }

            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            let cells = JournalInsights.monthCells(for: month, calendar: calendar)
            let rows = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<min($0 + 7, cells.count)]) }
            VStack(spacing: 4) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 4) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            dayCell(cell)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func dayCell(_ date: Date?) -> some View {
        if let date {
            let day = calendar.component(.day, from: date)
            let hasEntry = daysWithEntries.contains(day)
            Button(action: {
                guard let entry = JournalInsights.latestEntry(on: date, filenames: filenames, calendar: calendar) else {
                    return
                }
                onSelectFilename(entry.filename)
            }) {
                Text("\(day)")
                    .font(.system(size: 10, weight: selectedDay == day ? .semibold : .regular))
                    .foregroundColor(hasEntry ? .primary : .secondary.opacity(0.45))
                    .frame(maxWidth: .infinity, minHeight: 18)
                    .background(
                        Circle()
                            .fill(selectedDay == day ? Color.gray.opacity(0.22) : Color.clear)
                    )
                    .overlay(
                        Circle()
                            .stroke(hasEntry ? Color.gray.opacity(0.35) : Color.clear, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!hasEntry)
            .help(hasEntry ? "Open the latest entry from this day" : "No entry this day")
        } else {
            Color.clear.frame(maxWidth: .infinity, minHeight: 18)
        }
    }
}

struct VoiceStrip: View {
    let paths: [String]
    let documentsDirectory: URL

    @State private var playingPath: String?
    @State private var player: AVAudioPlayer?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(paths.enumerated()), id: \.offset) { index, path in
                    Button(action: { toggle(path) }) {
                        HStack(spacing: 6) {
                            Image(systemName: playingPath == path ? "stop.fill" : "play.fill")
                                .font(.system(size: 10))
                            Text(paths.count == 1 ? "Voice note" : "Voice \(index + 1)")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .help(path)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(height: 44)
        .onDisappear {
            player?.stop()
            player = nil
            playingPath = nil
        }
    }

    private func toggle(_ path: String) {
        if playingPath == path {
            player?.stop()
            player = nil
            playingPath = nil
            return
        }
        let url = documentsDirectory.appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: url.path),
              let next = try? AVAudioPlayer(contentsOf: url) else {
            return
        }
        player?.stop()
        next.play()
        player = next
        playingPath = path
    }
}

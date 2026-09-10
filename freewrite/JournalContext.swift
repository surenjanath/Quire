//
//  JournalContext.swift
//  freewrite
//
//  Grounds Ollama in the local journal: retrieve related pages, pack
//  them into the prompt, and tell the model not to invent.
//

import Foundation

enum JournalContext {
    struct Entry: Equatable {
        let filename: String
        let dateLabel: String
        let body: String
    }

    static var systemPrompt: String { OllamaSettings.defaultSystemPrompt }

    private static let stopWords: Set<String> = [
        "the", "and", "for", "that", "this", "with", "you", "your", "was", "were",
        "are", "but", "not", "have", "has", "had", "from", "they", "them", "she",
        "him", "her", "his", "its", "our", "out", "about", "into", "just", "like",
        "what", "when", "then", "than", "did", "write", "wrote",
    ]

    static func tokens(_ text: String) -> [String] {
        text.lowercased()
            .split { !$0.isLetter }
            .map(String.init)
            .filter { $0.count >= 3 && !stopWords.contains($0) }
    }

    static func score(query: String, body: String) -> Int {
        let needles = Set(tokens(query))
        guard !needles.isEmpty else { return 0 }
        return tokens(body).reduce(0) { $0 + (needles.contains($1) ? 1 : 0) }
    }

    static func related(
        to query: String,
        in entries: [Entry],
        excluding currentFilename: String?,
        limit: Int = 3,
        excerptChars: Int = 700
    ) -> [Entry] {
        entries
            .filter { $0.filename != currentFilename }
            .map { entry -> (Entry, Int) in
                (Entry(filename: entry.filename, dateLabel: entry.dateLabel, body: excerpt(entry.body, limit: excerptChars)), score(query: query, body: entry.body))
            }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    static func focusPassage(selected: String, in stored: String) -> String? {
        let excerpt = selected.trimmingCharacters(in: .whitespacesAndNewlines)
        guard excerpt.count >= 8 else { return nil }
        let visible = MarkdownExtras.visibleBody(stored)
        guard visible.range(of: excerpt, options: .caseInsensitive) != nil else { return nil }
        return excerpt
    }

    static func userPacket(current: String, related: [Entry], focus: String? = nil) -> String {
        var parts: [String] = []
        if let focus, !focus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("FOCUS PASSAGE")
            parts.append(focus.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        parts.append("CURRENT PAGE")
        parts.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        if !related.isEmpty {
            parts.append("RELATED PAGES")
            for entry in related {
                parts.append("\(entry.dateLabel):\n\(entry.body)")
            }
        }
        return parts.joined(separator: "\n\n")
    }

    // For "Ask my journal" (Go palette): no current page to anchor on, just a question and
    // whatever pages matched it.
    static func askPacket(question: String, pages: [Entry]) -> String {
        var parts = ["QUESTION", question.trimmingCharacters(in: .whitespacesAndNewlines)]
        parts.append("JOURNAL PAGES")
        for page in pages {
            parts.append("\(page.dateLabel):\n\(page.body)")
        }
        return parts.joined(separator: "\n\n")
    }

    static func askHint(pageCount: Int) -> String {
        pageCount == 0 ? "Nothing matched yet" : "Grounded in \(pageCount) page\(pageCount == 1 ? "" : "s")"
    }

    static func hint(relatedCount: Int, focused: Bool = false) -> String {
        if focused {
            return relatedCount == 0
                ? "This selection"
                : "Selection · \(relatedCount) other page\(relatedCount == 1 ? "" : "s")"
        }
        return relatedCount == 0
            ? "This page only"
            : "Grounded in \(relatedCount) other page\(relatedCount == 1 ? "" : "s")"
    }

    static func enrichFollowUp(
        _ question: String,
        catalog: [Entry],
        excluding currentFilename: String?,
        limit: Int = 2
    ) -> String {
        let extra = related(to: question, in: catalog, excluding: currentFilename, limit: limit)
        guard !extra.isEmpty else { return question }
        return question + "\n\n" + extra.map { "\($0.dateLabel):\n\($0.body)" }.joined(separator: "\n\n")
    }

    private static func excerpt(_ text: String, limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: limit)
        return String(trimmed[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}

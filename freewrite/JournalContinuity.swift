//
//  JournalContinuity.swift
//  freewrite
//
//  A quiet way back into yesterday's last sentence when today's page
//  is still empty.
//

import Foundation

enum JournalContinuity {
    static func shouldOffer(current: String) -> Bool {
        MarkdownExtras.visibleBody(current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    static func lastSentence(in text: String, limit: Int = 180) -> String? {
        let visible = MarkdownExtras.visibleBody(text)
        guard !JournalInsights.isGuideOrEmpty(visible) else { return nil }
        let lines = visible
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                !line.isEmpty
                    && !line.hasPrefix("#")
                    && !line.hasPrefix(">>")
                    && !line.hasPrefix("[voice")
            }
        guard let line = lines.last else { return nil }
        let sentence = lastSentence(of: line)
        guard !sentence.isEmpty else { return nil }
        if sentence.count <= limit { return sentence }
        let end = sentence.index(sentence.startIndex, offsetBy: limit)
        return String(sentence[..<end]).trimmingCharacters(in: .whitespaces) + "…"
    }

    static func starting(with sentence: String) -> String {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return trimmed + " "
    }

    private static func lastSentence(of text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var start = trimmed.startIndex
        var index = trimmed.startIndex
        while index < trimmed.endIndex {
            let character = trimmed[index]
            let next = trimmed.index(after: index)
            if (character == "." || character == "?" || character == "!"), next < trimmed.endIndex {
                var cursor = next
                while cursor < trimmed.endIndex && trimmed[cursor].isWhitespace {
                    cursor = trimmed.index(after: cursor)
                }
                if cursor < trimmed.endIndex {
                    start = cursor
                }
            }
            index = next
        }
        return String(trimmed[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

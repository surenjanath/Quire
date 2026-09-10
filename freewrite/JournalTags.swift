//
//  JournalTags.swift
//  freewrite
//
//  Quiet #tags in an entry. Headings ("# Title") and things like c# are ignored.
//

import Foundation

enum JournalTags {
    static func tags(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"(?<![\w#])#([A-Za-z][A-Za-z0-9_-]{0,31})"#) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var seen = Set<String>()
        var tags: [String] = []
        for match in regex.matches(in: text, range: range) {
            guard let tagRange = Range(match.range(at: 1), in: text) else { continue }
            let before = match.range(at: 0).location
            if before > 0 {
                let idx = text.index(text.startIndex, offsetBy: before)
                if idx < text.endIndex {
                    let lineStart = text[..<idx].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
                    let prefix = text[lineStart..<idx]
                    if prefix.trimmingCharacters(in: .whitespaces).isEmpty,
                       text[idx...].hasPrefix("# ") || text[idx...].hasPrefix("#\t") {
                        continue
                    }
                }
            }
            let tag = String(text[tagRange]).lowercased()
            if seen.insert(tag).inserted {
                tags.append(tag)
            }
        }
        return tags
    }

    static func suggestions(in text: String, existing: [String], limit: Int) -> [String] {
        let already = Set(existing.map { $0.lowercased() })
        var counts: [String: Int] = [:]
        for token in JournalContext.tokens(text) {
            if already.contains(token) { continue }
            counts[token, default: 0] += 1
        }
        return counts
            .filter { $0.value >= 2 }
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .prefix(limit)
            .map(\.key)
    }

    static func adding(_ tag: String, to text: String) -> String {
        let cleaned = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty, !tags(in: text).contains(cleaned) else { return text }
        let visible = MarkdownExtras.visibleBody(text).trimmingCharacters(in: .whitespacesAndNewlines)
        let next = visible.isEmpty ? "#\(cleaned)" : visible + " #\(cleaned)"
        return MarkdownExtras.restoringImageLines(visible: next, stored: text)
    }
}

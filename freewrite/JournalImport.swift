//
//  JournalImport.swift
//  freewrite
//
//  Bring a text or markdown file in as a new page. The mirror of Export:
//  Quire already gets your writing out (PDF, Markdown, text, a zip of
//  the whole journal) — this is how writing from somewhere else gets in.
//

import Foundation

enum JournalImport {
    static func sanitize(_ raw: String) -> String {
        var text = raw
        if text.hasPrefix("\u{FEFF}") {
            text.removeFirst()
        }
        text = text.replacingOccurrences(of: "\r\n", with: "\n")
        text = text.replacingOccurrences(of: "\r", with: "\n")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

//
//  JournalApply.swift
//  freewrite
//
//  Puts an Ollama reply onto the page without the stock greeting,
//  and without wiping pasted images.
//

import Foundation

enum JournalApply {
    enum Mode {
        case append
        case replace
        case note
    }

    static func cleanedReply(_ reply: String) -> String {
        var text = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        let greetings = [
            "hey, thanks for showing me this. my thoughts:",
            "hey, thanks for showing me this. my thoughts",
        ]
        let lower = text.lowercased()
        for greeting in greetings where lower.hasPrefix(greeting) {
            text = String(text.dropFirst(greeting.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }
        return text
    }

    static func applying(_ reply: String, mode: Mode, onto stored: String) -> String {
        let clean = cleanedReply(reply)
        guard !clean.isEmpty else { return stored }
        switch mode {
        case .append:
            let visible = MarkdownExtras.visibleBody(stored)
            let next = visible.isEmpty ? clean : visible + "\n\n" + clean
            return MarkdownExtras.restoringImageLines(visible: next, stored: stored)
        case .replace:
            return MarkdownExtras.restoringImageLines(visible: clean, stored: stored)
        case .note:
            let visible = MarkdownExtras.visibleBody(stored)
            let note = ">> " + firstSentence(clean)
            let next = visible.isEmpty ? note : visible + "\n" + note
            return MarkdownExtras.restoringImageLines(visible: next, stored: stored)
        }
    }

    static func firstSentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let stops = CharacterSet(charactersIn: ".?!")
        if let index = trimmed.unicodeScalars.firstIndex(where: { stops.contains($0) }) {
            return String(trimmed[...index]).trimmingCharacters(in: .whitespaces)
        }
        return trimmed
    }

    static func restoring(_ previous: String?, ifDifferentFrom current: String) -> String? {
        guard let previous, previous != current else { return nil }
        return previous
    }
}

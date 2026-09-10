//
//  SoftMarkdown.swift
//  freewrite
//
//  Dim markdown markers in the editor. The words stay as they are.
//

import AppKit

enum SoftMarkdown {
    static func markerRanges(in text: String) -> [NSRange] {
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        let patterns = [
            "(?m)^(#{1,6})(?=\\s)",
            "(?m)^(>>)",
            "\\*\\*",
            "__",
            "==",
            "`",
            "(?<![A-Za-z0-9])\\*(?![A-Za-z0-9\\s])|(?<=\\S)\\*(?=[^*])",
        ]
        var found: [NSRange] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in regex.matches(in: text, range: full) {
                let range = match.numberOfRanges > 1 && match.range(at: 1).location != NSNotFound
                    ? match.range(at: 1)
                    : match.range
                if range.length > 0 { found.append(range) }
            }
        }
        return found
    }

    static func apply(enabled: Bool, dim: NSColor, in view: NSView? = NSApp.keyWindow?.contentView) {
        guard let textView = CompositionGuard.firstTextView(in: view),
              let layout = textView.layoutManager else { return }
        guard enabled else { return }
        let marks = markerRanges(in: textView.string)
        for range in marks {
            let end = NSMaxRange(range)
            if end <= (textView.string as NSString).length {
                layout.addTemporaryAttribute(.foregroundColor, value: dim, forCharacterRange: range)
            }
        }
    }
}

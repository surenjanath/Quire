//
//  WritingFocus.swift
//  freewrite
//
//  Idle chrome fade, starred fonts, IME-safe backspace lock, and
//  sentence focus (dim everything except the sentence under the caret).
//

import Foundation
import AppKit

enum IdleFade {
    static let defaultThreshold: TimeInterval = 8

    static func chromeVisible(
        idleFadeEnabled: Bool,
        idleFor: TimeInterval,
        threshold: TimeInterval = defaultThreshold,
        timerRunning: Bool,
        hovering: Bool,
        forceVisible: Bool
    ) -> Bool {
        if forceVisible || hovering { return true }
        if idleFadeEnabled { return idleFor < threshold }
        if timerRunning { return false }
        return true
    }
}

enum FavoriteFonts {
    static let builtins: [(id: String, title: String)] = [
        ("Lato-Regular", "Lato"),
        ("Arial", "Arial"),
        (".AppleSystemUIFont", "System"),
        ("Times New Roman", "Serif"),
    ]

    static func parse(_ stored: String) -> [String] {
        stored
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func serialize(_ fonts: [String]) -> String {
        var seen = Set<String>()
        return fonts.filter { seen.insert($0).inserted }.joined(separator: ",")
    }

    static func toggling(_ font: String, in fonts: [String]) -> [String] {
        if fonts.contains(font) {
            return fonts.filter { $0 != font }
        }
        return fonts + [font]
    }

    static func displayName(for font: String) -> String {
        builtins.first { $0.id == font }?.title ?? font
    }
}

enum CompositionGuard {
    static let deleteKey: UInt16 = 51
    static let forwardDeleteKey: UInt16 = 117

    static func shouldBlockBackspace(lockEnabled: Bool, keyCode: UInt16, hasMarkedText: Bool) -> Bool {
        guard lockEnabled else { return false }
        guard keyCode == deleteKey || keyCode == forwardDeleteKey else { return false }
        return !hasMarkedText
    }

    static func firstTextViewHasMarkedText(in view: NSView? = NSApp.keyWindow?.contentView) -> Bool {
        firstTextView(in: view)?.hasMarkedText() ?? false
    }

    static func firstTextView(in view: NSView? = NSApp.keyWindow?.contentView) -> NSTextView? {
        guard let view else { return nil }
        if let textView = view as? NSTextView { return textView }
        for child in view.subviews {
            if let found = firstTextView(in: child) { return found }
        }
        return nil
    }
}

enum SentenceFocus {
    static func range(in text: String, caret: Int) -> NSRange {
        let ns = text as NSString
        let length = ns.length
        guard length > 0 else { return NSRange(location: 0, length: 0) }
        let index = min(max(caret, 0), length)

        var start = 0
        var cursor = max(index - 1, 0)
        while cursor >= 0 {
            let mark = ns.substring(with: NSRange(location: cursor, length: 1))
            if isEnder(mark) {
                let after = cursor + 1
                if after >= length || isSpace(ns.substring(with: NSRange(location: after, length: 1))) {
                    start = after
                    while start < length && isSpace(ns.substring(with: NSRange(location: start, length: 1))) {
                        start += 1
                    }
                    break
                }
            }
            if cursor == 0 { break }
            cursor -= 1
        }

        var end = length
        var ahead = index
        while ahead < length {
            let mark = ns.substring(with: NSRange(location: ahead, length: 1))
            if isEnder(mark) {
                let after = ahead + 1
                if after >= length || isSpace(ns.substring(with: NSRange(location: after, length: 1))) {
                    end = after
                    break
                }
            }
            ahead += 1
        }

        if end < start { return NSRange(location: start, length: 0) }
        return NSRange(location: start, length: end - start)
    }

    static func apply(enabled: Bool, primary: NSColor, dim: NSColor, in view: NSView? = NSApp.keyWindow?.contentView) {
        guard let textView = CompositionGuard.firstTextView(in: view),
              let layout = textView.layoutManager else { return }
        let full = NSRange(location: 0, length: (textView.string as NSString).length)
        layout.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
        guard enabled, full.length > 0 else { return }
        layout.addTemporaryAttribute(.foregroundColor, value: dim, forCharacterRange: full)
        let focus = range(in: textView.string, caret: textView.selectedRange().location)
        guard focus.length > 0, NSMaxRange(focus) <= full.length else { return }
        layout.addTemporaryAttribute(.foregroundColor, value: primary, forCharacterRange: focus)
    }

    private static func isEnder(_ mark: String) -> Bool {
        mark == "." || mark == "!" || mark == "?"
    }

    private static func isSpace(_ mark: String) -> Bool {
        mark == " " || mark == "\n" || mark == "\t"
    }
}

enum EditorPlaceholder {
    static func apply(
        _ text: String,
        fontName: String,
        size: CGFloat,
        color: NSColor,
        in view: NSView? = NSApp.keyWindow?.contentView
    ) {
        guard let textView = CompositionGuard.firstTextView(in: view) else { return }
        let font = resolvedFont(named: fontName, size: size)
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color
        ])
        textView.setValue(attributed, forKey: "placeholderAttributedString")
    }

    static func resolvedFont(named name: String, size: CGFloat) -> NSFont {
        if name == ".AppleSystemUIFont" {
            return .systemFont(ofSize: size)
        }
        return NSFont(name: name, size: size) ?? .systemFont(ofSize: size)
    }
}

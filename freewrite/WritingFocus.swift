//
//  WritingFocus.swift
//  freewrite
//
//  Idle chrome fade, starred fonts, and IME-safe backspace lock.
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

    private static func firstTextView(in view: NSView?) -> NSTextView? {
        guard let view else { return nil }
        if let textView = view as? NSTextView { return textView }
        for child in view.subviews {
            if let found = firstTextView(in: child) { return found }
        }
        return nil
    }
}

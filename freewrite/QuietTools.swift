//
//  QuietTools.swift
//  freewrite
//
//  Small helpers that keep the page calm: safe AI URLs, in-page find,
//  debounced saves, and a cafe privacy veil.
//

import Foundation
import SwiftUI
import AppKit

enum ChatURL {
    private static var queryAllowed: CharacterSet {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=")
        return allowed
    }

    static func encodeQuery(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: queryAllowed) ?? ""
    }

    static func chatGPT(_ text: String) -> URL? {
        URL(string: "https://chat.openai.com/?prompt=" + encodeQuery(text))
    }

    static func claude(_ text: String) -> URL? {
        URL(string: "https://claude.ai/new?q=" + encodeQuery(text))
    }
}

enum PageFind {
    static func ranges(in text: String, query: String) -> [NSRange] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        let ns = text as NSString
        var cursor = NSRange(location: 0, length: ns.length)
        var found: [NSRange] = []
        while cursor.length > 0 {
            let hit = ns.range(of: needle, options: [.caseInsensitive], range: cursor)
            if hit.location == NSNotFound { break }
            found.append(hit)
            let next = hit.location + max(hit.length, 1)
            if next >= ns.length { break }
            cursor = NSRange(location: next, length: ns.length - next)
        }
        return found
    }

    static func nextIndex(after current: Int?, count: Int) -> Int? {
        guard count > 0 else { return nil }
        guard let current else { return 0 }
        return (current + 1) % count
    }

    @discardableResult
    static func select(_ range: NSRange, in view: NSView? = NSApp.keyWindow?.contentView) -> Bool {
        guard let textView = firstTextView(in: view) else { return false }
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
        return true
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

enum SaveDebounce {
    static func shouldFlush(dirty: Bool) -> Bool {
        dirty
    }
}

struct PrivacyVeil: View {
    let onReveal: () -> Void

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            VStack(spacing: 10) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                Text("Hidden")
                    .font(.system(size: 15, weight: .medium))
                Text("⌘⇧P to show the page again")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture(perform: onReveal)
    }
}

struct FindBar: View {
    @Binding var query: String
    let matchLabel: String
    let onNext: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            TextField("Find in page", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .onSubmit(onNext)
            Text(matchLabel)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Button("Next", action: onNext)
                .buttonStyle(.plain)
                .font(.system(size: 11))
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

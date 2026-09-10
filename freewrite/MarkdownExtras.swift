//
//  MarkdownExtras.swift
//  freewrite
//
//  Opt-in markdown helpers: wiki links, image refs, annotations, and a
//  filename graph. Used only when Advanced features are enabled.
//

import Foundation

enum MarkdownExtras {
    struct GraphEdge: Equatable {
        let from: String
        let to: String
    }

    static func wikiLinks(in text: String) -> [String] {
        let pattern = "\\[\\[([^\\]]+)\\]\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let value = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
    }

    static func resolve(
        link: String,
        entries: [(filename: String, preview: String, date: String)]
    ) -> String? {
        let needle = link.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return nil }
        return entries.first { entry in
            entry.preview.lowercased().contains(needle)
                || entry.date.lowercased().contains(needle)
                || entry.filename.lowercased().contains(needle)
        }?.filename
    }

    static func imageRefs(in text: String) -> [String] {
        let pattern = "!\\[[^\\]]*\\]\\(([^\\)]+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let value = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
    }

    static func insertImage(into text: String, relativePath: String, alt: String) -> String {
        let line = "![\(alt)](\(relativePath))"
        var stem = text
        if !stem.hasPrefix("\n\n") {
            stem = "\n\n" + stem.trimmingCharacters(in: .newlines)
        }
        if stem.hasSuffix("\n") {
            return stem + "\n" + line + "\n"
        }
        return stem + "\n\n" + line + "\n"
    }

    static func annotations(in text: String) -> [String] {
        text.components(separatedBy: .newlines).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(">>") else { return nil }
            let note = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            return note.isEmpty ? nil : note
        }
    }

    static func highlights(in text: String) -> [String] {
        let pattern = "==([^=]+)=="
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let value = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
    }

    static func mermaidBlocks(in text: String) -> [String] {
        let pattern = "```mermaid\\s*\\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let value = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
    }

    static func graphEdges(
        entries: [(filename: String, text: String, preview: String, date: String)]
    ) -> [GraphEdge] {
        let catalog = entries.map { (filename: $0.filename, preview: $0.preview, date: $0.date) }
        var edges: [GraphEdge] = []
        for entry in entries {
            for link in wikiLinks(in: entry.text) {
                guard let target = resolve(link: link, entries: catalog), target != entry.filename else { continue }
                let edge = GraphEdge(from: entry.filename, to: target)
                if !edges.contains(edge) {
                    edges.append(edge)
                }
            }
        }
        return edges
    }
}

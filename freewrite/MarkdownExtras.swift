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

    static func isImageMarkdownLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("![") else { return false }
        return imageRefs(in: trimmed).count == 1 && trimmed.hasSuffix(")")
    }

    static func isHiddenImageLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return isImageMarkdownLine(trimmed) || ImageStore.isImageFilePath(trimmed)
    }

    static func hidingImageLines(_ text: String) -> String {
        text
            .components(separatedBy: "\n")
            .filter { !isHiddenImageLine($0) }
            .joined(separator: "\n")
    }

    static func restoringImageLines(visible: String, stored: String) -> String {
        let imageLines = stored
            .components(separatedBy: "\n")
            .filter { isImageMarkdownLine($0) }
        var seen = Set<String>()
        let unique = imageLines.filter { seen.insert($0).inserted }
        var body = hidingImageLines(visible)
        guard !unique.isEmpty else { return body }
        while body.hasSuffix("\n\n") {
            body.removeLast()
        }
        if !body.isEmpty && !body.hasSuffix("\n") {
            body += "\n"
        }
        return body + "\n" + unique.joined(separator: "\n") + "\n"
    }

    static func insertImage(into text: String, relativePath: String, alt: String) -> String {
        let line = "![\(alt)](\(relativePath))"
        if text.contains(line) { return text }
        var body = text
        if body.isEmpty { return line + "\n" }
        if !body.hasSuffix("\n") { body += "\n" }
        return body + line + "\n"
    }

    static func scrubbingPage(_ text: String) -> String {
        var out: [String] = []
        var blankRun = 0
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if ImageStore.isImageFilePath(trimmed) {
                continue
            }
            if trimmed.isEmpty {
                blankRun += 1
                if blankRun == 1 { out.append("") }
                continue
            }
            blankRun = 0
            out.append(line)
        }
        while out.first == "" { out.removeFirst() }
        while out.last == "" { out.removeLast() }
        return out.joined(separator: "\n")
    }

    static func visibleBody(_ text: String) -> String {
        scrubbingPage(hidingImageLines(text))
    }

    static func wordCount(_ text: String) -> Int {
        visibleBody(text)
            .split { $0.isWhitespace || $0.isNewline }
            .filter { token in token.contains { $0.isLetter || $0.isNumber } }
            .count
    }

    static func isLooseFlowLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("```") else { return false }
        let arrows = ["-.->", "==>", "-->", "---", "→", "->"]
        guard arrows.contains(where: { trimmed.contains($0) }) else { return false }
        if trimmed.contains(where: { $0 == "." || $0 == "?" || $0 == "!" }) { return false }
        let words = trimmed.split { $0.isWhitespace }.count
        return (2...8).contains(words)
    }

    static func mermaidSources(in text: String) -> [String] {
        var sources = mermaidBlocks(in: text)
        for line in hidingImageLines(text).components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard isLooseFlowLine(trimmed) else { continue }
            if sources.contains(where: { $0.contains(trimmed) }) { continue }
            sources.append(trimmed)
        }
        return sources
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

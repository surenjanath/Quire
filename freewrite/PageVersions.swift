//
//  PageVersions.swift
//  freewrite
//
//  Snapshots of a page before Improve / Replace, so Undo is not
//  the only way back.
//

import Foundation
import SwiftUI

enum PageVersions {
    static let keep = 20

    struct Item: Identifiable, Equatable {
        let url: URL
        let stamp: String
        let preview: String

        var id: String { url.path }
    }

    static func folderName(from filename: String) -> String {
        (filename as NSString).deletingPathExtension
    }

    static func shouldSnapshot(current: String, next: String) -> Bool {
        if JournalInsights.isGuideOrEmpty(current) { return false }
        if current == next { return false }
        return MarkdownExtras.visibleBody(current) != MarkdownExtras.visibleBody(next)
    }

    static func stamp(date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter.string(from: date)
    }

    static func directory(root: URL, entryFilename: String) -> URL {
        JournalFolder.versionsURL(root: root)
            .appendingPathComponent(folderName(from: entryFilename), isDirectory: true)
    }

    @discardableResult
    static func write(
        current: String,
        root: URL,
        entryFilename: String,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) throws -> URL {
        let folder = directory(root: root, entryFilename: entryFilename)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        var name = stamp(date: now) + ".md"
        var url = folder.appendingPathComponent(name)
        var suffix = 2
        while fileManager.fileExists(atPath: url.path) {
            name = stamp(date: now) + "-\(suffix).md"
            url = folder.appendingPathComponent(name)
            suffix += 1
        }
        try current.write(to: url, atomically: true, encoding: .utf8)
        prune(in: folder, fileManager: fileManager)
        return url
    }

    static func list(
        root: URL,
        entryFilename: String,
        fileManager: FileManager = .default
    ) -> [Item] {
        let folder = directory(root: root, entryFilename: entryFilename)
        guard let names = try? fileManager.contentsOfDirectory(atPath: folder.path) else { return [] }
        return names
            .filter { $0.hasSuffix(".md") }
            .sorted(by: >)
            .compactMap { name in
                let url = folder.appendingPathComponent(name)
                let body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                let visible = MarkdownExtras.visibleBody(body)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let line = visible.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
                let preview = line.count > 72 ? String(line.prefix(71)) + "…" : line
                return Item(
                    url: url,
                    stamp: (name as NSString).deletingPathExtension,
                    preview: preview.isEmpty ? "Empty page" : preview
                )
            }
    }

    static func read(_ url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }

    static func restore(_ body: String, onto stored: String) -> String {
        MarkdownExtras.restoringImageLines(visible: body, stored: stored)
    }

    private static func prune(in folder: URL, fileManager: FileManager) {
        guard let names = try? fileManager.contentsOfDirectory(atPath: folder.path) else { return }
        let extra = names.filter { $0.hasSuffix(".md") }.sorted(by: >).dropFirst(keep)
        for name in extra {
            try? fileManager.removeItem(at: folder.appendingPathComponent(name))
        }
    }
}

struct VersionsPanelView: View {
    let items: [PageVersions.Item]
    let onRestore: (PageVersions.Item) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Earlier versions")
                    .font(.system(size: 13))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if items.isEmpty {
                Text("No earlier drafts yet. They appear when Chat or an agent changes this page.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(14)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(items) { item in
                            Button {
                                onRestore(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.preview)
                                        .font(.system(size: 13))
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                    Text(item.stamp)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .frame(width: 420)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.18), radius: 16, y: 8)
    }
}

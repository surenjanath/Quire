//
//  JournalFolder.swift
//  freewrite
//
//  Resolves the journal root: default ~/Documents/Freewrite, or a
//  user-chosen folder remembered as a security-scoped bookmark.
//

import Foundation

enum JournalFolder {
    static func defaultRoot(fileManager: FileManager = .default) -> URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Freewrite", isDirectory: true)
    }

    static func resolve(
        bookmarkData: Data?,
        resolving: ((Data) throws -> URL)? = nil
    ) -> URL {
        guard let bookmarkData else { return defaultRoot() }
        if let resolving {
            return (try? resolving(bookmarkData)) ?? defaultRoot()
        }
        do {
            var stale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            return url
        } catch {
            return defaultRoot()
        }
    }

    static func videosURL(root: URL) -> URL {
        root.appendingPathComponent("Videos", isDirectory: true)
    }

    static func chatsURL(root: URL) -> URL {
        root.appendingPathComponent("Chats", isDirectory: true)
    }

    static func ensureLayout(at root: URL, fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: videosURL(root: root), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: chatsURL(root: root), withIntermediateDirectories: true)
    }

    @discardableResult
    static func beginAccess(to url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    static func bookmark(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }
}

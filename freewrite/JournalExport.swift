//
//  JournalExport.swift
//  freewrite
//
//  Zip the markdown, Media, and Versions. Skip Videos and Chats.
//

import Foundation

enum JournalExport {
    static func shouldInclude(relativePath: String) -> Bool {
        let path = relativePath.replacingOccurrences(of: "\\", with: "/")
        if path.hasPrefix("Videos/") || path == "Videos" { return false }
        if path.hasPrefix("Chats/") || path == "Chats" { return false }
        if path.hasPrefix(".") { return false }
        if path.contains("/.") { return false }
        if path.hasSuffix(".md") { return true }
        if path.hasPrefix("Media/") { return true }
        if path.hasPrefix("Versions/") { return true }
        return false
    }

    static func relativePaths(in root: URL, fileManager: FileManager = .default) -> [String] {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var paths: [String] = []
        for case let url as URL in enumerator {
            let rel = url.path.replacingOccurrences(of: root.standardizedFileURL.path + "/", with: "")
            guard shouldInclude(relativePath: rel) else { continue }
            paths.append(rel)
        }
        return paths.sorted()
    }

    static func writeZip(from root: URL, to destination: URL, fileManager: FileManager = .default) throws {
        let staging = fileManager.temporaryDirectory.appendingPathComponent("quire-export-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }
        for rel in relativePaths(in: root, fileManager: fileManager) {
            let source = root.appendingPathComponent(rel)
            let dest = staging.appendingPathComponent(rel)
            try fileManager.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: dest.path) {
                try fileManager.removeItem(at: dest)
            }
            try fileManager.copyItem(at: source, to: dest)
        }
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--norsrc", staging.path, destination.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "JournalExport", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not write the zip."
            ])
        }
    }
}

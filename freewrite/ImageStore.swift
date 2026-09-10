//
//  ImageStore.swift
//  freewrite
//
//  Saves pasted or captured images next to Freewrite markdown as
//  Media/[entry-base]/shot-….png and returns the relative markdown path.
//

import AppKit

enum ImageStore {
    static func imageFromClipboard() -> NSImage? {
        let pasteboard = NSPasteboard.general
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            return image
        }
        if let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            return NSImage(data: data)
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            return urls.compactMap { NSImage(contentsOf: $0) }.first
        }
        if let plain = clipboardPlainText(), let image = image(fromFilePath: plain) {
            return image
        }
        return nil
    }

    static func clipboardHasPlainText() -> Bool {
        guard let string = clipboardPlainText() else { return false }
        return !string.isEmpty
    }

    static func clipboardPlainText() -> String? {
        NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "tif", "tiff", "heic", "heif", "bmp"
    ]

    static func resolvedFilePath(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("file://") {
            if let url = URL(string: trimmed) {
                return url.path
            }
            let withoutScheme = String(trimmed.dropFirst("file://".count))
            return withoutScheme.removingPercentEncoding ?? withoutScheme
        }
        return trimmed
    }

    static func isImageFilePath(_ text: String) -> Bool {
        let path = resolvedFilePath(text)
        guard path.hasPrefix("/") else { return false }
        let ext = (path as NSString).pathExtension.lowercased()
        return imageExtensions.contains(ext)
    }

    static func shouldPreferClipboardImage(hasImage: Bool, plainText: String?) -> Bool {
        hasImage
    }

    static func image(fromFilePath text: String) -> NSImage? {
        let path = resolvedFilePath(text)
        guard isImageFilePath(path) else { return nil }
        return NSImage(contentsOfFile: path)
    }

    static func replacingBareImagePaths(in text: String, importing: (String) -> String?) -> String {
        text
            .components(separatedBy: "\n")
            .map { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard isImageFilePath(trimmed), let relative = importing(trimmed) else {
                    return line
                }
                return "![screenshot](\(relative))"
            }
            .joined(separator: "\n")
    }

    @discardableResult
    static func captureInteractiveToClipboard() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-i", "-c"]
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    static func savePNG(
        _ image: NSImage,
        documentsDirectory: URL,
        entryFilename: String
    ) throws -> String {
        let base = (entryFilename as NSString).deletingPathExtension
        let folder = documentsDirectory
            .appendingPathComponent("Media")
            .appendingPathComponent(base)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = "shot-\(formatter.string(from: Date())).png"
        let fileURL = folder.appendingPathComponent(name)

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "ImageStore", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not encode that image as PNG."
            ])
        }
        try data.write(to: fileURL)
        return "Media/\(base)/\(name)"
    }

    static func replacePNG(
        _ image: NSImage,
        documentsDirectory: URL,
        relativePath: String
    ) throws {
        let dest = documentsDirectory.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: dest.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "ImageStore", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not encode that image as PNG."
            ])
        }
        try data.write(to: dest)
    }
}

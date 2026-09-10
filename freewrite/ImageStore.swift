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
        NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage
    }

    static func clipboardHasPlainText() -> Bool {
        guard let string = NSPasteboard.general.string(forType: .string) else { return false }
        return !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

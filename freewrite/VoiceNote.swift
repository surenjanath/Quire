//
//  VoiceNote.swift
//  freewrite
//
//  Audio-only journal clips live next to the markdown as
//  Media/[entry-base]/voice-….m4a, linked with [voice note](…).
//

import Foundation
import AVFoundation

enum VoiceNote {
    static func markdown(relativePath: String, transcript: String) -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "[voice note](\(relativePath))\n"
        }
        return "[voice note](\(relativePath))\n\n\(trimmed)\n"
    }

    static func attach(to existing: String, relativePath: String) -> String {
        let link = "[voice note](\(relativePath))"
        if existing.contains(link) { return existing }
        if existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return link + "\n"
        }
        return link + "\n\n" + existing
    }

    static func refs(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\[voice note\]\(([^)]+)\)"#) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let pathRange = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[pathRange])
        }
    }

    static func relativePath(entryFilename: String, recordedAt: Date, timeZone: TimeZone = .current) -> String {
        let base = (entryFilename as NSString).deletingPathExtension
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "Media/\(base)/voice-\(formatter.string(from: recordedAt)).m4a"
    }
}

enum VoiceNoteStore {
    static func moveRecording(
        from tempURL: URL,
        documentsDirectory: URL,
        relativePath: String
    ) throws {
        let dest = documentsDirectory.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: dest.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: tempURL, to: dest)
    }
}

@MainActor
final class VoiceNoteRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var tempURL: URL?

    func start() {
        guard !isRecording else { return }
        errorMessage = nil

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("freewrite-voice-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            guard recorder.prepareToRecord(), recorder.record() else {
                errorMessage = "Could not start the voice note."
                return
            }
            self.recorder = recorder
            self.tempURL = url
            self.isRecording = true
        } catch {
            errorMessage = "Could not start the voice note: \(error.localizedDescription)"
        }
    }

    func stop() -> URL? {
        guard isRecording else { return nil }
        recorder?.stop()
        let url = tempURL
        recorder = nil
        tempURL = nil
        isRecording = false
        return url
    }

    func discard() {
        let url = stop()
        if let url, FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

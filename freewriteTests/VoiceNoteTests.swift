import Foundation
import Testing

@testable import freewrite

struct VoiceNoteTests {
    @Test func markdownWithTranscript() {
        let note = VoiceNote.markdown(relativePath: "Media/entry/voice-20260909-200000.m4a", transcript: "  hello river  ")
        #expect(note == "[voice note](Media/entry/voice-20260909-200000.m4a)\n\nhello river\n")
    }

    @Test func markdownWithoutTranscript() {
        let note = VoiceNote.markdown(relativePath: "Media/entry/voice.m4a", transcript: "   ")
        #expect(note == "[voice note](Media/entry/voice.m4a)\n")
    }

    @Test func attachPrependsLinkWithoutDuplicatingExistingText() {
        let next = VoiceNote.attach(to: "hello river\n", relativePath: "Media/entry/voice.m4a")
        #expect(next == "[voice note](Media/entry/voice.m4a)\n\nhello river\n")
        #expect(VoiceNote.attach(to: next, relativePath: "Media/entry/voice.m4a") == next)
    }

    @Test func extractsVoiceRefs() {
        let text = "[voice note](Media/a/voice-1.m4a)\n\nhello\n[voice note](Media/a/voice-2.m4a)"
        #expect(VoiceNote.refs(in: text) == ["Media/a/voice-1.m4a", "Media/a/voice-2.m4a"])
    }

    @Test func relativePathUsesEntryBaseAndTimestamp() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 20, minute: 1, second: 4))!
        #expect(
            VoiceNote.relativePath(
                entryFilename: "[abc]-[2026-09-09-20-01-04].md",
                recordedAt: date,
                timeZone: TimeZone(secondsFromGMT: 0)!
            ) == "Media/[abc]-[2026-09-09-20-01-04]/voice-20260909-200104.m4a"
        )
    }
}

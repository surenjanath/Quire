//
//  PageNarrator.swift
//  freewrite
//
//  Read the page back, on-device. Voice notes and dictation are input;
//  this is the one output direction — hearing your own words instead
//  of just rereading them. No new entitlement: speech *synthesis*
//  (unlike speech *recognition*) needs no permission on macOS.
//

import AVFoundation

@MainActor
final class PageNarrator: NSObject, ObservableObject {
    @Published var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggle(_ text: String) {
        if isSpeaking {
            stop()
        } else {
            speak(text)
        }
    }

    func speak(_ text: String) {
        stop()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        // Not guarded on synthesizer.isSpeaking: right after speak() starts, the synthesizer can
        // report not-yet-speaking for a brief window (AVSpeechSynthesizer's own startup latency),
        // which would let this bail out without resetting isSpeaking — a published flag stuck
        // true with no way to clear it. stopSpeaking(at:) is harmless to call when idle (just
        // returns false), so always call it and always force the flag back to false.
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

extension PageNarrator: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}

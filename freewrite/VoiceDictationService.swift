//
//  VoiceDictationService.swift
//  freewrite
//
//  Microphone-only speech-to-text (no camera involved) for dictating into the
//  main editor and into Ollama chat follow-ups. Uses the same Speech framework
//  as VideoRecordingView's live transcription, but captures audio directly via
//  AVAudioEngine instead of through an AVCaptureSession.
//

import Foundation
import AVFoundation
import Speech

@MainActor
final class VoiceDictationService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var transcript = ""
    @Published var errorMessage: String? = nil

    private let recognizer = SFSpeechRecognizer(locale: Locale.current)
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    func start() {
        guard !isRecording else { return }
        errorMessage = nil
        transcript = ""

        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                guard let self else { return }
                guard authStatus == .authorized else {
                    self.errorMessage = "Speech recognition permission denied. Enable it in System Settings > Privacy & Security."
                    return
                }
                self.beginRecording()
            }
        }
    }

    private func beginRecording() {
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognizer unavailable right now."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Could not start the microphone: \(error.localizedDescription)"
            inputNode.removeTap(onBus: 0)
            return
        }

        isRecording = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            DispatchQueue.main.async {
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    self.stop()
                }
            }
        }
    }

    func stop() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
        isRecording = false
    }
}

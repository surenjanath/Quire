//
//  CaptureDevices.swift
//  freewrite
//
//  Pick a camera and microphone for video. Voice notes still use
//  the Mac's current input.
//

import AVFoundation

enum CaptureDevices {
    static func resolvedID(preferred: String, available: [String], fallback: String?) -> String? {
        let trimmed = preferred.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, available.contains(trimmed) { return trimmed }
        if let fallback, available.contains(fallback) { return fallback }
        return available.first
    }

    static func videoDevices() -> [AVCaptureDevice] {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .continuityCamera,
            .deskViewCamera,
            .external,
        ]
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .unspecified
        ).devices
    }

    static func audioDevices() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        ).devices
    }

    static func videoDevice(preferredID: String) -> AVCaptureDevice? {
        let devices = videoDevices()
        if let match = devices.first(where: { $0.uniqueID == preferredID }) { return match }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video)
            ?? devices.first
    }

    static func audioDevice(preferredID: String) -> AVCaptureDevice? {
        let devices = audioDevices()
        if let match = devices.first(where: { $0.uniqueID == preferredID }) { return match }
        return AVCaptureDevice.default(for: .audio) ?? devices.first
    }
}

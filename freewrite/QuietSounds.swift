//
//  QuietSounds.swift
//  freewrite
//
//  Optional typewriter ticks and a soft room tone. Off by default.
//

import AppKit
import AVFoundation

enum QuietSounds {
    static func shouldTick(enabled: Bool, before: String, after: String) -> Bool {
        guard enabled else { return false }
        let delta = after.count - before.count
        return delta > 0 && delta <= 2
    }

    static func tick() {
        NSSound(named: "Tink")?.play()
    }
}

@MainActor
final class QuietRoomTone: ObservableObject {
    private var player: AVAudioPlayer?

    func setEnabled(_ enabled: Bool) {
        if enabled {
            start()
        } else {
            stop()
        }
    }

    func start() {
        if player?.isPlaying == true { return }
        guard let data = Self.noiseData() else { return }
        player = try? AVAudioPlayer(data: data)
        player?.numberOfLoops = -1
        player?.volume = 0.04
        player?.play()
    }

    func stop() {
        player?.stop()
        player = nil
    }

    private static func noiseData() -> Data? {
        let sampleRate = 22050
        let seconds = 4
        let count = sampleRate * seconds
        var pcm = Data()
        pcm.reserveCapacity(count * 2)
        var seed: UInt64 = 0xC0FFEE
        for _ in 0..<count {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1
            let sample = Int16((Int(seed % 401) - 200))
            withUnsafeBytes(of: sample.littleEndian) { pcm.append(contentsOf: $0) }
        }
        return wav(pcm: pcm, sampleRate: sampleRate)
    }

    private static func wav(pcm: Data, sampleRate: Int) -> Data {
        var data = Data()
        func ascii(_ value: String) { data.append(contentsOf: value.utf8) }
        func u16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func u32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        ascii("RIFF")
        u32(UInt32(36 + pcm.count))
        ascii("WAVE")
        ascii("fmt ")
        u32(16)
        u16(1)
        u16(1)
        u32(UInt32(sampleRate))
        u32(UInt32(sampleRate * 2))
        u16(2)
        u16(16)
        ascii("data")
        u32(UInt32(pcm.count))
        data.append(pcm)
        return data
    }
}

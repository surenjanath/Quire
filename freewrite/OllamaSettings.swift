//
//  OllamaSettings.swift
//  freewrite
//
//  Thinking, temperature, context, and the system prompt sent to local
//  Ollama. Keeps Settings and the chat request in one place.
//

import Foundation

struct OllamaChatOptions: Equatable {
    var think: OllamaSettings.ThinkMode
    var temperature: Double
    var contextTokens: Int
    var systemPrompt: String

    static let standard = OllamaChatOptions(
        think: .off,
        temperature: OllamaSettings.defaultTemperature,
        contextTokens: OllamaSettings.defaultContext,
        systemPrompt: OllamaSettings.defaultSystemPrompt
    )
}

enum OllamaSettings {
    enum ThinkMode: String, CaseIterable, Identifiable {
        case off
        case on
        case low
        case medium
        case high
        case max

        var id: String { rawValue }

        var title: String {
            switch self {
            case .off: return "Off"
            case .on: return "On"
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            case .max: return "Max"
            }
        }
    }

    static let defaultTemperature = 0.45
    static let defaultContext = 8192
    static let contextChoices = [4096, 8192, 16384, 32768]

    static let defaultSystemPrompt = """
    You are reading a private local journal. Nothing in this conversation leaves the user's computer.

    Use only the journal text provided here. If something is not in that text, say you do not have it. Do not invent dates, people, places, or events. When you mention a past page, quote a short phrase from it.

    Stay in the requested tone. Do not give a therapy intake, a heading outline, or a line-by-line recap. Prefer a few honest paragraphs.

    Do not open with a greeting. Do not start with "hey, thanks for showing me this." Begin with the thought.

    If you reason step by step, keep that reasoning in thinking. The reply the user reads should be the finished words only.
    """

    static func parseThink(_ stored: String) -> ThinkMode {
        ThinkMode(rawValue: stored) ?? .off
    }

    static func clampTemperature(_ value: Double) -> Double {
        guard value.isFinite else { return defaultTemperature }
        return min(1, max(0, (value * 100).rounded() / 100))
    }

    static func clampContext(_ value: Int) -> Int {
        contextChoices.min { lhs, rhs in
            let left = abs(lhs - value)
            let right = abs(rhs - value)
            return left < right || (left == right && lhs < rhs)
        } ?? defaultContext
    }

    static func effectiveSystemPrompt(custom: String) -> String {
        let trimmed = custom.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultSystemPrompt : trimmed
    }

    static func thinkValue(_ mode: ThinkMode) -> Any {
        switch mode {
        case .off: return false
        case .on: return true
        case .low, .medium, .high, .max: return mode.rawValue
        }
    }

    static func chatPayload(
        model: String,
        messages: [[String: String]],
        think: ThinkMode,
        temperature: Double,
        contextTokens: Int
    ) -> [String: Any] {
        [
            "model": model,
            "messages": messages,
            "stream": true,
            "think": thinkValue(think),
            "options": [
                "temperature": clampTemperature(temperature),
                "num_ctx": clampContext(contextTokens),
            ] as [String: Any],
        ]
    }
}

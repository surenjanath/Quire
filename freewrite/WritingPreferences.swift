//
//  WritingPreferences.swift
//  freewrite
//
//  Sanitizes persisted writing prefs so a corrupt UserDefaults value cannot
//  leave the editor on an invalid font, size, or timer length.
//

import Foundation

enum WritingPreferences {
    static let fontSizes: [Double] = [16, 18, 20, 22, 24, 26]
    static let defaultFont = "Lato-Regular"
    static let defaultFontSize: Double = 18
    static let defaultTimerSeconds = 900
    static let minTimerSeconds = 0
    static let maxTimerSeconds = 2700
    static let timerStepMinutes = 5

    static func resolvedFont(_ stored: String) -> String {
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultFont : trimmed
    }

    static func resolvedFontSize(_ stored: Double) -> Double {
        if fontSizes.contains(stored) {
            return stored
        }
        guard stored.isFinite, stored > 0 else {
            return defaultFontSize
        }
        if let maxSize = fontSizes.last, stored > maxSize {
            return maxSize
        }
        return fontSizes.min { lhs, rhs in
            let left = abs(lhs - stored)
            let right = abs(rhs - stored)
            return left < right || (left == right && lhs < rhs)
        } ?? defaultFontSize
    }

    static func resolvedTimerSeconds(_ stored: Int) -> Int {
        let minutes = stored / 60
        return min(max(minutes * 60, minTimerSeconds), maxTimerSeconds)
    }

    static func steppedTimerSeconds(current: Int, directionMinutes: Int) -> Int {
        let currentMinutes = current / 60
        let newMinutes = currentMinutes + directionMinutes
        let roundedMinutes = (newMinutes / timerStepMinutes) * timerStepMinutes
        return min(max(roundedMinutes * 60, minTimerSeconds), maxTimerSeconds)
    }
}

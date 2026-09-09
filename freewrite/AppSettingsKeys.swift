//
//  AppSettingsKeys.swift
//  freewrite
//
//  UserDefaults keys shared by ContentView, SettingsView, and OllamaService,
//  so settings storage stays consistent in one place.
//

import Foundation

enum AppSettingsKeys {
    static let ollamaEndpoint = "ollamaEndpoint"
    static let ollamaModel = "ollamaModel"
    static let customChatGPTPrompt = "customChatGPTPrompt"
    static let customClaudePrompt = "customClaudePrompt"
    static let customOllamaPrompt = "customOllamaPrompt"
    static let selectedFont = "selectedFont"
    static let fontSize = "fontSize"
    static let backspaceDisabled = "backspaceDisabled"
    static let preferredTimerSeconds = "preferredTimerSeconds"
}

enum AppSettingsDefaults {
    static let ollamaEndpoint = "http://localhost:11434"
    static let selectedFont = WritingPreferences.defaultFont
    static let fontSize = WritingPreferences.defaultFontSize
    static let timerSeconds = WritingPreferences.defaultTimerSeconds
}

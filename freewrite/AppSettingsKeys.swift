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
    static let customOllamaSystemPrompt = "customOllamaSystemPrompt"
    static let claudeCodePath = "claudeCodePath"
    static let codexPath = "codexPath"
    static let ollamaThink = "ollamaThink"
    static let ollamaTemperature = "ollamaTemperature"
    static let ollamaContext = "ollamaContext"
    static let ollamaShowThinking = "ollamaShowThinking"
    static let selectedFont = "selectedFont"
    static let fontSize = "fontSize"
    static let backspaceDisabled = "backspaceDisabled"
    static let preferredTimerSeconds = "preferredTimerSeconds"
    static let typewriterMode = "typewriterMode"
    static let advancedImages = "advancedImages"
    static let advancedGraph = "advancedGraph"
    static let advancedAnnotations = "advancedAnnotations"
    static let advancedMermaid = "advancedMermaid"
    static let dailyWordGoal = "dailyWordGoal"
    static let journalFolderBookmark = "journalFolderBookmark"
    static let journalLockEnabled = "journalLockEnabled"
    static let followSystemAppearance = "followSystemAppearance"
    static let idleFadeEnabled = "idleFadeEnabled"
    static let favoriteFonts = "favoriteFonts"
    static let sentenceFocus = "sentenceFocus"
    static let preferredCamera = "preferredCamera"
    static let preferredMicrophone = "preferredMicrophone"
    static let typewriterSound = "typewriterSound"
    static let roomTone = "roomTone"
    static let softMarkdown = "softMarkdown"
    static let lockedPageIDs = "lockedPageIDs"
}

enum AppSettingsDefaults {
    static let ollamaEndpoint = "http://localhost:11434"
    static let selectedFont = WritingPreferences.defaultFont
    static let fontSize = WritingPreferences.defaultFontSize
    static let timerSeconds = WritingPreferences.defaultTimerSeconds
}

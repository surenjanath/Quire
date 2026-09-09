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
}

enum AppSettingsDefaults {
    static let ollamaEndpoint = "http://localhost:11434"
}

//
//  SettingsView.swift
//  freewrite
//
//  Lets users edit the AI reflection prompts and configure the local Ollama
//  connection without recompiling the app.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            TabView {
                OllamaSettingsTab()
                    .tabItem {
                        Label("Ollama", systemImage: "cpu")
                    }

                PromptsSettingsTab()
                    .tabItem {
                        Label("Prompts", systemImage: "text.bubble")
                    }
            }
            .padding(20)
        }
        .frame(width: 560, height: 520)
    }
}

private struct OllamaSettingsTab: View {
    @AppStorage(AppSettingsKeys.ollamaEndpoint) private var ollamaEndpoint: String = AppSettingsDefaults.ollamaEndpoint
    @AppStorage(AppSettingsKeys.ollamaModel) private var ollamaModel: String = ""

    @StateObject private var testService = OllamaService()
    @State private var connectionTestResult: ConnectionTestResult? = nil

    private enum ConnectionTestResult {
        case success(modelCount: Int)
        case failure(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingsCard(title: "Connection") {
                VStack(alignment: .leading, spacing: 10) {
                    labeledRow(label: "Endpoint") {
                        TextField(AppSettingsDefaults.ollamaEndpoint, text: $ollamaEndpoint)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: 10) {
                        Button("Test Connection") {
                            Task { await testConnection() }
                        }
                        .disabled(testService.isLoadingModels)

                        if testService.isLoadingModels {
                            ProgressView().controlSize(.small)
                        }

                        if let result = connectionTestResult {
                            switch result {
                            case .success(let count):
                                Label("Connected — \(count) model\(count == 1 ? "" : "s") found", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 12))
                            case .failure(let message):
                                Label(message, systemImage: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 12))
                                    .lineLimit(2)
                            }
                        }

                        Spacer()
                    }
                }
            }

            settingsCard(title: "Default Model") {
                if testService.availableModels.isEmpty {
                    Text("Test the connection above to list installed models.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else {
                    Picker("", selection: $ollamaModel) {
                        Text("None").tag("")
                        ForEach(testService.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 280)
                }
            }

            Spacer()

            Text("Ollama runs entirely on your machine — nothing you write is ever sent anywhere.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func testConnection() async {
        connectionTestResult = nil
        await testService.fetchModels(endpoint: ollamaEndpoint)
        if let error = testService.errorMessage {
            connectionTestResult = .failure(error)
        } else {
            connectionTestResult = .success(modelCount: testService.availableModels.count)
            if ollamaModel.isEmpty {
                ollamaModel = testService.availableModels.first ?? ""
            }
        }
    }
}

private struct PromptsSettingsTab: View {
    private enum PromptKind: String, CaseIterable, Identifiable {
        case chatGPT = "ChatGPT"
        case claude = "Claude"
        case ollama = "Ollama"

        var id: String { rawValue }
    }

    @AppStorage(AppSettingsKeys.customChatGPTPrompt) private var customChatGPTPrompt: String = ""
    @AppStorage(AppSettingsKeys.customClaudePrompt) private var customClaudePrompt: String = ""
    @AppStorage(AppSettingsKeys.customOllamaPrompt) private var customOllamaPrompt: String = ""

    @State private var selectedPrompt: PromptKind = .chatGPT

    private var defaultText: String {
        switch selectedPrompt {
        case .chatGPT: return PromptLibrary.defaultChatGPTPrompt
        case .claude: return PromptLibrary.defaultClaudePrompt
        case .ollama: return PromptLibrary.defaultOllamaPrompt
        }
    }

    private var binding: Binding<String> {
        switch selectedPrompt {
        case .chatGPT: return $customChatGPTPrompt
        case .claude: return $customClaudePrompt
        case .ollama: return $customOllamaPrompt
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("", selection: $selectedPrompt) {
                ForEach(PromptKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack {
                Text("Sent to \(selectedPrompt.rawValue) before your entry, to set the tone of its response.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Button("Reset to Default") {
                    binding.wrappedValue = ""
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.accentColor)
                .disabled(binding.wrappedValue.isEmpty)
            }

            TextEditor(text: Binding(
                get: { binding.wrappedValue.isEmpty ? defaultText : binding.wrappedValue },
                set: { binding.wrappedValue = $0 }
            ))
            .font(.system(size: 12))
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.25)))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

@ViewBuilder
private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)

        content()
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.06)))
    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.15)))
}

@ViewBuilder
private func labeledRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(label)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        content()
    }
}

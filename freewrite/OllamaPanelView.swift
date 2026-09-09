//
//  OllamaPanelView.swift
//  freewrite
//
//  Side panel showing a streamed, fully-offline AI reflection from a local
//  Ollama server. Mirrors the visual language of the History sidebar in
//  ContentView.swift (fixed width, header, divider, scroll body).
//

import SwiftUI

struct OllamaPanelView: View {
    @ObservedObject var service: OllamaService
    let endpoint: String
    let prompt: String
    let colorScheme: ColorScheme
    let canInsert: Bool
    let onInsert: (String) -> Void
    let onClose: () -> Void

    @AppStorage(AppSettingsKeys.ollamaModel) private var selectedModel: String = ""
    @State private var didCopy = false
    @State private var hasStarted = false
    @State private var pullModelName: String = ""

    private var textColor: Color {
        colorScheme == .light ? .gray : .gray.opacity(0.8)
    }

    private var textHoverColor: Color {
        colorScheme == .light ? .black : .white
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            body(for: service)

            Divider()

            footer
        }
        .frame(width: 320)
        .background(Color(colorScheme == .light ? .white : NSColor.black))
        .onAppear {
            Task { await refreshModels() }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ollama (Offline)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Runs locally. Nothing leaves your machine.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
                    .foregroundColor(textColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func body(for service: OllamaService) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            modelPicker

            if service.availableModels.isEmpty && !service.isLoadingModels && service.errorMessage == nil {
                emptyModelsState
            } else if let errorMessage = service.errorMessage {
                errorState(errorMessage)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(service.responseText.isEmpty && service.isStreaming ? "Thinking..." : service.responseText)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                            .id("responseBottom")
                    }
                    .onChange(of: service.responseText) { _, _ in
                        proxy.scrollTo("responseBottom", anchor: .bottom)
                    }
                }
            }
        }
        .padding(.top, 8)
        .frame(maxHeight: .infinity)
        .onChange(of: selectedModel) { _, _ in
            start()
        }
    }

    private var modelPicker: some View {
        HStack(spacing: 8) {
            Picker("", selection: $selectedModel) {
                if selectedModel.isEmpty {
                    Text("Choose a model").tag("")
                }
                ForEach(service.availableModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)

            Button(action: { Task { await refreshModels() } }) {
                if service.isLoadingModels {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(textColor)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    private var emptyModelsState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No models found.")
                .font(.system(size: 13, weight: .medium))

            if service.isPulling {
                VStack(alignment: .leading, spacing: 6) {
                    Text(service.pullStatus)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    if let progress = service.pullProgress {
                        ProgressView(value: progress)
                    } else {
                        ProgressView()
                    }
                    Button("Cancel") { service.cancelPull() }
                        .font(.system(size: 11))
                }
            } else {
                Text("Pull a model directly, or run \"ollama pull <model>\" in Terminal.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    TextField("e.g. llama3.2", text: $pullModelName)
                        .textFieldStyle(.roundedBorder)
                    Button("Pull") {
                        service.pullModel(endpoint: endpoint, name: pullModelName)
                    }
                    .disabled(pullModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let pullError = service.pullError {
                    Text(pullError)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Couldn't reach Ollama.")
                .font(.system(size: 13, weight: .medium))
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button(action: {
                if service.isStreaming {
                    service.cancel()
                } else {
                    start()
                }
            }) {
                Text(service.isStreaming ? "Stop" : (hasStarted ? "Regenerate" : "Generate"))
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(textColor)
            .disabled(selectedModel.isEmpty)

            Spacer()

            Button(action: {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(service.responseText, forType: .string)
                didCopy = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    didCopy = false
                }
            }) {
                Text(didCopy ? "Copied!" : "Copy")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(textColor)
            .disabled(service.responseText.isEmpty)

            if canInsert {
                Button(action: { onInsert(service.responseText) }) {
                    Text("Insert")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(textColor)
                .disabled(service.responseText.isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func refreshModels() async {
        await service.fetchModels(endpoint: endpoint)
        if selectedModel.isEmpty || !service.availableModels.contains(selectedModel) {
            selectedModel = service.availableModels.first ?? ""
        }
        if !hasStarted, !selectedModel.isEmpty {
            start()
        }
    }

    private func start() {
        guard !selectedModel.isEmpty else { return }
        hasStarted = true
        service.generate(endpoint: endpoint, model: selectedModel, prompt: prompt)
    }
}

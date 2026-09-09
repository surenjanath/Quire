//
//  OllamaPanelView.swift
//  freewrite
//
//  Side panel showing a streamed, fully-offline AI conversation from a local
//  Ollama server. Mirrors the visual language of the History sidebar in
//  ContentView.swift (fixed width, header, divider, scroll body). Supports
//  multi-turn follow-up questions via Ollama's /api/chat endpoint.
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
    @State private var followUpText: String = ""

    private var textColor: Color {
        colorScheme == .light ? .gray : .gray.opacity(0.8)
    }

    private var textHoverColor: Color {
        colorScheme == .light ? .black : .white
    }

    private var lastAssistantMessage: String? {
        service.messages.last(where: { $0.role == .assistant })?.content
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            body(for: service)

            Divider()

            footer
        }
        .frame(width: 340)
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

            if hasStarted {
                Button(action: restart) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11))
                        .foregroundColor(textColor)
                }
                .buttonStyle(.plain)
                .help("Start a new conversation")
            }

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
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(service.messages) { message in
                                bubble(for: message)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .id("bottomAnchor")
                    }
                    .onChange(of: service.messages) { _, _ in
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo("bottomAnchor", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .padding(.top, 8)
        .frame(maxHeight: .infinity)
        .onChange(of: selectedModel) { _, _ in
            restart()
        }
    }

    private func bubble(for message: OllamaChatMessage) -> some View {
        let isUser = message.role == .user
        let isThinking = message.content.isEmpty && service.isStreaming && message.id == service.messages.last?.id

        return HStack {
            if isUser { Spacer(minLength: 32) }

            markdownText(isThinking ? "Thinking..." : message.content)
                .font(.system(size: 13))
                .foregroundColor(isThinking ? .secondary : .primary)
                .textSelection(.enabled)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isUser ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.08))
                )

            if !isUser { Spacer(minLength: 32) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    /// Renders basic Markdown (bold, italics, headings, lists, links) with a plain-text fallback.
    private func markdownText(_ content: String) -> Text {
        if let attributed = try? AttributedString(markdown: content, options: .init(interpretedSyntax: .full)) {
            return Text(attributed)
        }
        return Text(content)
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
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask a follow-up...", text: $followUpText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .font(.system(size: 13))
                    .disabled(selectedModel.isEmpty)
                    .onSubmit { sendFollowUp() }

                Button(action: sendFollowUp) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(followUpText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || service.isStreaming ? textColor.opacity(0.4) : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(followUpText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || service.isStreaming)
            }

            HStack(spacing: 8) {
                if service.isStreaming {
                    Button("Stop") { service.cancel() }
                        .buttonStyle(.plain)
                        .foregroundColor(textColor)
                }

                Spacer()

                Button(action: copyLastResponse) {
                    Text(didCopy ? "Copied!" : "Copy")
                }
                .buttonStyle(.plain)
                .foregroundColor(textColor)
                .disabled(lastAssistantMessage == nil)

                if canInsert {
                    Button(action: {
                        if let last = lastAssistantMessage { onInsert(last) }
                    }) {
                        Text("Insert")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(textColor)
                    .disabled(lastAssistantMessage == nil)
                }
            }
            .font(.system(size: 12))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func copyLastResponse() {
        guard let last = lastAssistantMessage else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(last, forType: .string)
        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            didCopy = false
        }
    }

    private func sendFollowUp() {
        let trimmed = followUpText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !service.isStreaming else { return }
        followUpText = ""
        service.sendFollowUp(endpoint: endpoint, model: selectedModel, text: trimmed)
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
        service.startConversation(endpoint: endpoint, model: selectedModel, initialPrompt: prompt)
    }

    private func restart() {
        followUpText = ""
        service.resetConversation()
        hasStarted = false
        start()
    }
}

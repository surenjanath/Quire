//
//  OllamaPanelView.swift
//  freewrite
//
//  Side panel showing a streamed, fully-offline AI conversation from a local
//  Ollama server. Mirrors the visual language of the History sidebar in
//  ContentView.swift (fixed width, header, divider, scroll body). Supports
//  multi-turn follow-up questions via Ollama's /api/chat endpoint, voice
//  dictation for follow-ups, tone presets, and putting a reply on the page.
//

import SwiftUI

struct OllamaPanelView: View {
    @ObservedObject var service: OllamaService
    let endpoint: String
    let basePrompt: String
    let sourceText: String
    let pageText: String
    let relatedHint: String
    let journalCatalog: [JournalContext.Entry]
    let currentFilename: String?
    let colorScheme: ColorScheme
    let canInsert: Bool
    let canUndo: Bool
    let focusPassage: String
    let tagSuggestions: [String]
    let onAddTag: (String) -> Void
    let onApply: (JournalApply.Mode, String) -> Void
    let onUndo: () -> Void
    let onClose: () -> Void

    @AppStorage(AppSettingsKeys.ollamaModel) private var selectedModel: String = ""
    @AppStorage(AppSettingsKeys.ollamaThink) private var thinkMode: String = OllamaSettings.ThinkMode.off.rawValue
    @AppStorage(AppSettingsKeys.ollamaTemperature) private var temperature: Double = OllamaSettings.defaultTemperature
    @AppStorage(AppSettingsKeys.ollamaContext) private var contextTokens: Int = OllamaSettings.defaultContext
    @AppStorage(AppSettingsKeys.ollamaShowThinking) private var showThinking = true
    @AppStorage(AppSettingsKeys.customOllamaSystemPrompt) private var customSystemPrompt: String = ""
    @State private var selectedPersona: OllamaPersona = .defaultTone
    @State private var didCopy = false
    @State private var hasStarted = false
    @State private var pullModelName: String = ""
    @State private var followUpText: String = ""
    @State private var pendingApply: (JournalApply.Mode, String)? = nil
    @State private var suppressModelChangeRestart = false
    @StateObject private var dictation = VoiceDictationService()

    private var textColor: Color {
        colorScheme == .light ? .gray : .gray.opacity(0.8)
    }

    private var textHoverColor: Color {
        colorScheme == .light ? .black : .white
    }

    private var lastAssistantMessage: String? {
        service.messages.last(where: { $0.role == .assistant })?.content
    }

    // The streamed assistant turn exists (non-nil) from the moment a reply starts, before any
    // tokens arrive — so this, not `lastAssistantMessage == nil`, is what "is there something to
    // act on yet" actually means.
    private var hasReplyContent: Bool {
        !(lastAssistantMessage ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var effectivePrompt: String {
        (selectedPersona.promptOverride ?? basePrompt) + "\n\n" + sourceText
    }

    private var chatOptions: OllamaChatOptions {
        OllamaChatOptions(
            think: OllamaSettings.parseThink(thinkMode),
            temperature: temperature,
            contextTokens: contextTokens,
            systemPrompt: OllamaSettings.effectiveSystemPrompt(custom: customSystemPrompt)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            body(for: service)

            Divider()

            footer
        }
        .frame(width: 280)
        .background(Color(colorScheme == .light ? .white : NSColor.black))
        .onAppear {
            Task { await refreshModels() }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Chat")
                    .font(.system(size: 13))
                    .foregroundColor(textHoverColor)
                Text(selectedModel.isEmpty ? "Local · Ollama" : selectedModel)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(relatedHint)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Menu {
                ForEach(service.availableModels, id: \.self) { model in
                    Button(action: { selectedModel = model }) {
                        if selectedModel == model {
                            Label(model, systemImage: "checkmark")
                        } else {
                            Text(model)
                        }
                    }
                }
                Divider()
                ForEach(OllamaPersona.allCases) { persona in
                    Button(action: { selectedPersona = persona }) {
                        if selectedPersona == persona {
                            Label(persona.rawValue, systemImage: "checkmark")
                        } else {
                            Text(persona.rawValue)
                        }
                    }
                }
                Divider()
                Menu("Thinking") {
                    ForEach(OllamaSettings.ThinkMode.allCases) { mode in
                        Button(action: { thinkMode = mode.rawValue }) {
                            if thinkMode == mode.rawValue {
                                Label(mode.title, systemImage: "checkmark")
                            } else {
                                Text(mode.title)
                            }
                        }
                    }
                    Divider()
                    Button(showThinking ? "Hide thinking" : "Show thinking") {
                        showThinking.toggle()
                    }
                }
                Divider()
                Button("Refresh models") {
                    Task { await refreshModels() }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 11))
                    .foregroundColor(textColor)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 18)
            .help("Model and tone")

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
            if service.availableModels.isEmpty && !service.isLoadingModels && service.errorMessage == nil {
                emptyModelsState
            } else if let errorMessage = service.errorMessage {
                errorState(errorMessage)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(service.messages) { message in
                                transcriptLine(for: message)
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
            if suppressModelChangeRestart {
                suppressModelChangeRestart = false
                return
            }
            restart()
        }
        .onChange(of: selectedPersona) { _, _ in
            restart()
        }
    }

    private func transcriptLine(for message: OllamaChatMessage) -> some View {
        let isUser = message.role == .user
        let isThinking = message.content.isEmpty && service.isStreaming && message.id == service.messages.last?.id

        return VStack(alignment: .leading, spacing: 4) {
            Text(isUser ? "You" : "Reply")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            if !isUser, showThinking, !message.thinking.isEmpty {
                DisclosureGroup("Thinking") {
                    Text(message.thinking)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
            markdownText(isThinking && message.content.isEmpty ? "…" : message.content)
                .font(.system(size: 13))
                .italic(isUser)
                .foregroundColor(isThinking ? .secondary : (isUser ? textColor : .primary))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Renders basic Markdown (bold, italics, headings, lists, links) with a plain-text fallback.
    private func markdownText(_ content: String) -> Text {
        if let attributed = try? AttributedString(markdown: content, options: .init(interpretedSyntax: .full)) {
            return Text(attributed)
        }
        return Text(content)
    }

    private var controlsRow: some View {
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

            Menu {
                ForEach(OllamaPersona.allCases) { persona in
                    Button(action: { selectedPersona = persona }) {
                        if selectedPersona == persona {
                            Label(persona.rawValue, systemImage: "checkmark")
                        } else {
                            Text(persona.rawValue)
                        }
                    }
                }
            } label: {
                Text(selectedPersona.rawValue)
                    .font(.system(size: 12))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Tone preset")

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
            if let dictationError = dictation.errorMessage {
                Text(dictationError)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }

            HStack(alignment: .bottom, spacing: 8) {
                Button(action: toggleDictation) {
                    Image(systemName: dictation.isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 14))
                        .foregroundColor(dictation.isRecording ? .red : textColor)
                }
                .buttonStyle(.plain)
                .help(dictation.isRecording ? "Stop dictation" : "Dictate follow-up")

                TextField("Continue…", text: $followUpText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .font(.system(size: 13))
                    .disabled(selectedModel.isEmpty)
                    .onSubmit { sendFollowUp() }

                Menu {
                    Button("Continue") {
                        sendCanned(focusPassage.isEmpty
                            ? "Continue this entry in my voice. Write only the next short paragraph."
                            : "Continue this highlighted passage in my voice. Write only the next short paragraph.")
                    }
                    Button("Tighten") {
                        sendCanned(focusPassage.isEmpty
                            ? "Tighten the current page. Keep my meaning. Return only the revised paragraphs, no preamble."
                            : "Tighten the highlighted passage. Keep my meaning. Return only the revised sentences, no preamble.")
                    }
                    Button("Ask") {
                        sendCanned(focusPassage.isEmpty
                            ? "Ask me one sharp question about what I wrote. Nothing else."
                            : "Ask me one sharp question about the highlighted passage. Nothing else.")
                    }
                } label: {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 13))
                        .foregroundColor(textColor)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(service.isStreaming || selectedModel.isEmpty)
                .help("Quick prompt: Continue, Tighten, or Ask")

                Button(action: sendFollowUp) {
                    Text("Send")
                        .font(.system(size: 12))
                        .foregroundColor(followUpText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || service.isStreaming ? textColor.opacity(0.4) : textHoverColor)
                }
                .buttonStyle(.plain)
                .disabled(followUpText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || service.isStreaming)
            }

            if let pending = pendingApply {
                ApplyCompareView(
                    mode: pending.0,
                    before: PageCompare.beforeVisible(pageText),
                    after: PageCompare.preview(reply: pending.1, mode: pending.0, onto: pageText),
                    onConfirm: {
                        onApply(pending.0, pending.1)
                        pendingApply = nil
                    },
                    onCancel: { pendingApply = nil }
                )
            }

            if canInsert && !tagSuggestions.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tagSuggestions, id: \.self) { tag in
                        Button("#\(tag)") { onAddTag(tag) }
                            .buttonStyle(.plain)
                            .help("Add #\(tag) to this page")
                    }
                    Spacer(minLength: 0)
                }
                .font(.system(size: 11))
                .foregroundColor(textColor)
            }

            // Nothing to act on yet (no reply, nothing streaming, nothing to undo) — don't show
            // a row of disabled buttons for it.
            if service.isStreaming || canUndo || hasReplyContent {
                HStack(spacing: 8) {
                    if service.isStreaming {
                        Button("Stop") { service.cancel() }
                            .buttonStyle(.plain)
                            .foregroundColor(textColor)
                    }

                    Spacer()

                    if hasReplyContent {
                        Button(action: copyLastResponse) {
                            Text(didCopy ? "Copied!" : "Copy")
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(textColor)
                    }

                    if canUndo {
                        Button("Undo") { onUndo() }
                            .buttonStyle(.plain)
                            .foregroundColor(textColor)
                            .help("Put the page back the way it was")
                    }

                    if canInsert && hasReplyContent {
                        Button("Insert") { apply(.append) }
                            .buttonStyle(.plain)
                            .foregroundColor(textColor)
                            .help("Append the reply to this page")

                        Menu {
                            Button("Replace") { apply(.replace) }
                                .help("Replace the page text. Pasted images stay.")
                            Button("Note") { apply(.note) }
                                .help("Add the first sentence as a >> note")
                        } label: {
                            Text("More")
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                }
                .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .onChange(of: dictation.transcript) { _, newValue in
            guard dictation.isRecording else { return }
            followUpText = newValue
        }
    }

    private func toggleDictation() {
        if dictation.isRecording {
            dictation.stop()
        } else {
            dictation.start()
        }
    }

    private func apply(_ mode: JournalApply.Mode) {
        guard let last = lastAssistantMessage else { return }
        pendingApply = (mode, last)
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
        if dictation.isRecording { dictation.stop() }
        let grounded = JournalContext.enrichFollowUp(
            trimmed,
            catalog: journalCatalog,
            excluding: currentFilename
        )
        service.sendFollowUp(endpoint: endpoint, model: selectedModel, text: grounded, options: chatOptions)
    }

    private func sendCanned(_ text: String) {
        guard !service.isStreaming, !selectedModel.isEmpty else { return }
        service.sendFollowUp(endpoint: endpoint, model: selectedModel, text: text, options: chatOptions)
    }

    private func refreshModels() async {
        await service.fetchModels(endpoint: endpoint)
        if selectedModel.isEmpty || !service.availableModels.contains(selectedModel) {
            suppressModelChangeRestart = true
            selectedModel = service.availableModels.first ?? ""
        }
        guard !hasStarted else { return }
        if !service.messages.isEmpty {
            // A saved conversation was already restored into the service before this view
            // appeared (see ContentView.startOllamaChat) — don't overwrite it.
            hasStarted = true
        } else if !selectedModel.isEmpty {
            start()
        }
    }

    private func start() {
        guard !selectedModel.isEmpty else { return }
        hasStarted = true
        service.startConversation(
            endpoint: endpoint,
            model: selectedModel,
            initialPrompt: effectivePrompt,
            options: chatOptions
        )
    }

    private func restart() {
        followUpText = ""
        service.resetConversation()
        hasStarted = false
        start()
    }
}

//
//  SettingsView.swift
//  freewrite
//
//  Chat, Writing, and About. Never present this in Settings { } or Window("Settings")
//  — macOS draws every letter twice. Open it as a sheet or overlay instead.
//

import SwiftUI
import AppKit
import AVFoundation

struct SettingsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case writing = "Writing"
        case chat = "Chat"
        case about = "About"

        var id: String { rawValue }
    }

    var onClose: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .writing

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                Group {
                    switch tab {
                    case .writing:
                        WritingSettingsTab()
                    case .chat:
                        ChatSettingsTab()
                    case .about:
                        AboutSettingsTab()
                    }
                }
                .padding(20)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(width: 500, height: 600)
        .onDisappear {
            QuireAction.post(QuireAction.settingsClosed)
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Text(verbatim: "Settings")
                .font(.system(size: 15, weight: .semibold))

            HStack(spacing: 0) {
                ForEach(Tab.allCases) { section in
                    Button {
                        tab = section
                    } label: {
                        Text(verbatim: section.rawValue)
                            .font(.system(size: 12, weight: tab == section ? .semibold : .regular))
                            .foregroundColor(tab == section ? .primary : .secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(tab == section ? Color.primary.opacity(0.08) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            Button("Done") { close() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}

private struct ChatSettingsTab: View {
    @AppStorage(AppSettingsKeys.ollamaEndpoint) private var ollamaEndpoint: String = AppSettingsDefaults.ollamaEndpoint
    @AppStorage(AppSettingsKeys.ollamaModel) private var ollamaModel: String = ""
    @AppStorage(AppSettingsKeys.ollamaThink) private var thinkMode: String = OllamaSettings.ThinkMode.off.rawValue
    @AppStorage(AppSettingsKeys.ollamaTemperature) private var temperature: Double = OllamaSettings.defaultTemperature
    @AppStorage(AppSettingsKeys.ollamaContext) private var contextTokens: Int = OllamaSettings.defaultContext
    @AppStorage(AppSettingsKeys.customOllamaSystemPrompt) private var customSystemPrompt: String = ""
    @AppStorage(AppSettingsKeys.customOllamaPrompt) private var customOllamaPrompt: String = ""
    @AppStorage(AppSettingsKeys.customClaudePrompt) private var customClaudePrompt: String = ""
    @AppStorage(AppSettingsKeys.customChatGPTPrompt) private var customChatGPTPrompt: String = ""
    @AppStorage(AppSettingsKeys.claudeCodePath) private var claudeCodePath: String = ""
    @AppStorage(AppSettingsKeys.codexPath) private var codexPath: String = ""

    @StateObject private var testService = OllamaService()
    @State private var connectionTestResult: ConnectionTestResult? = nil

    private enum ConnectionTestResult {
        case success(modelCount: Int)
        case failure(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(verbatim: "Claude Code and Codex write in a side panel. Ollama stays on this Mac. ChatGPT and Claude in the browser use the same tone.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            settingsGroup("Local agents") {
                settingsNote("Chat → Claude Code or Codex. You read the reply, then Insert, Replace, or Note.")
                settingsDivider
                settingsFieldRow("Claude Code") {
                    HStack(spacing: 8) {
                        TextField("/opt/homebrew/bin/claude", text: $claudeCodePath)
                            .textFieldStyle(.roundedBorder)
                        Button("Choose…") { chooseBinary { claudeCodePath = $0 } }
                    }
                }
                agentStatus(for: .claude, override: claudeCodePath)
                settingsDivider
                settingsFieldRow("Codex") {
                    HStack(spacing: 8) {
                        TextField("/opt/homebrew/bin/codex", text: $codexPath)
                            .textFieldStyle(.roundedBorder)
                        Button("Choose…") { chooseBinary { codexPath = $0 } }
                    }
                }
                agentStatus(for: .codex, override: codexPath)
            }

            settingsGroup("Tone") {
                HStack(alignment: .top) {
                    settingsNote("One voice for ChatGPT, Claude, Ollama, Claude Code, and Codex.")
                    Button("Reset") {
                        customOllamaPrompt = ""
                        customClaudePrompt = ""
                        customChatGPTPrompt = ""
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.accentColor)
                    .disabled(customOllamaPrompt.isEmpty && customClaudePrompt.isEmpty && customChatGPTPrompt.isEmpty)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                TextEditor(text: Binding(
                    get: {
                        PromptLibrary.effectiveTone(
                            ollama: customOllamaPrompt,
                            claude: customClaudePrompt,
                            chatGPT: customChatGPTPrompt
                        )
                    },
                    set: { customOllamaPrompt = $0 }
                ))
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 110)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.textBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08)))
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }

            settingsGroup("Ollama") {
                settingsFieldRow("Endpoint") {
                    TextField(AppSettingsDefaults.ollamaEndpoint, text: $ollamaEndpoint)
                        .textFieldStyle(.roundedBorder)
                }
                settingsDivider
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
                            Label("Connected — \(count) model\(count == 1 ? "" : "s")", systemImage: "checkmark.circle.fill")
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
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            settingsGroup("Model") {
                settingsNote("Used when Chat opens. You can still switch in the panel.")
                if testService.availableModels.isEmpty {
                    settingsNote("Test the connection to list installed models.")
                        .padding(.bottom, 10)
                } else {
                    settingsControlRow("Default model") {
                        Picker("Model", selection: $ollamaModel) {
                            Text("None").tag("")
                            ForEach(testService.availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 220)
                    }
                }
            }

            settingsGroup("Reply") {
                settingsControlRow("Thinking") {
                    Picker("Thinking", selection: $thinkMode) {
                        ForEach(OllamaSettings.ThinkMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 160)
                }
                settingsNote("Off skips reasoning. Low / Medium / High / Max are for models like gpt-oss. Show or hide thinking from the Chat ••• menu.")
                settingsDivider
                settingsFieldRow("Temperature  \(String(format: "%.2f", OllamaSettings.clampTemperature(temperature)))") {
                    Slider(
                        value: Binding(
                            get: { OllamaSettings.clampTemperature(temperature) },
                            set: { temperature = OllamaSettings.clampTemperature($0) }
                        ),
                        in: 0...1,
                        step: 0.05
                    )
                }
                settingsDivider
                settingsControlRow("Context") {
                    Picker("Context", selection: $contextTokens) {
                        ForEach(OllamaSettings.contextChoices, id: \.self) { size in
                            Text("\(size / 1024)k").tag(OllamaSettings.clampContext(size))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 100)
                    .onChange(of: contextTokens) { _, newValue in
                        contextTokens = OllamaSettings.clampContext(newValue)
                    }
                }
            }

            settingsGroup("System prompt") {
                HStack(alignment: .top) {
                    settingsNote("Rules Ollama follows on every turn. Tone above is the friend voice.")
                    Button("Reset") { customSystemPrompt = "" }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.accentColor)
                        .disabled(customSystemPrompt.isEmpty)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                TextEditor(text: Binding(
                    get: { customSystemPrompt.isEmpty ? OllamaSettings.defaultSystemPrompt : customSystemPrompt },
                    set: { customSystemPrompt = $0 }
                ))
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 140)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.textBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08)))
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .onAppear {
            Task { await testConnection() }
        }
    }

    @ViewBuilder
    private func agentStatus(for backend: LocalAgent.Backend, override: String) -> some View {
        Text(verbatim: LocalAgent.resolvedPath(for: backend, override: override) != nil
             ? "Found"
             : "Not found. Choose the \(backend.commandName) program.")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
    }

    private func chooseBinary(set: (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Use"
        panel.message = "Pick the claude or codex program."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        set(url.path)
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

private struct WritingSettingsTab: View {
    @AppStorage(AppSettingsKeys.advancedImages) private var advancedImages = false
    @AppStorage(AppSettingsKeys.advancedGraph) private var advancedGraph = false
    @AppStorage(AppSettingsKeys.advancedAnnotations) private var advancedAnnotations = false
    @AppStorage(AppSettingsKeys.advancedMermaid) private var advancedMermaid = false
    @AppStorage(AppSettingsKeys.dailyWordGoal) private var dailyWordGoal = 0
    @AppStorage(AppSettingsKeys.followSystemAppearance) private var followSystemAppearance = false
    @AppStorage(AppSettingsKeys.idleFadeEnabled) private var idleFadeEnabled = false
    @AppStorage(AppSettingsKeys.journalLockEnabled) private var journalLockEnabled = false
    @AppStorage(AppSettingsKeys.preferredCamera) private var preferredCamera = ""
    @AppStorage(AppSettingsKeys.preferredMicrophone) private var preferredMicrophone = ""
    @AppStorage(AppSettingsKeys.typewriterSound) private var typewriterSound = false
    @AppStorage(AppSettingsKeys.roomTone) private var roomTone = false
    @AppStorage(AppSettingsKeys.softMarkdown) private var softMarkdown = false
    @AppStorage(AppSettingsKeys.smartTypography) private var smartTypography = false
    @State private var cameras: [AVCaptureDevice] = []
    @State private var microphones: [AVCaptureDevice] = []
    @State private var folderPath = JournalFolder.resolve(
        bookmarkData: UserDefaults.standard.data(forKey: AppSettingsKeys.journalFolderBookmark)
    ).path
    @State private var folderError: String?

    private var isUsingDefaultFolder: Bool {
        UserDefaults.standard.data(forKey: AppSettingsKeys.journalFolderBookmark) == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            settingsGroup("Journal") {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: "Folder")
                            .font(.system(size: 13))
                        Text(verbatim: shortFolderPath)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(folderPath)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Choose…") { chooseFolder() }
                    Button("Default") { resetFolder() }
                        .disabled(isUsingDefaultFolder)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                if let folderError {
                    Text(verbatim: folderError)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                }
            }

            settingsGroup("Page") {
                settingsToggle("Match the Mac", "Follow system light and dark", $followSystemAppearance)
                settingsDivider
                settingsToggle("Hide the bar when idle", "After eight seconds without typing", $idleFadeEnabled)
                settingsDivider
                settingsToggle("Soft markdown", "Dim # ** == and >>", $softMarkdown)
                settingsDivider
                settingsToggle("Smart quotes", "\u{201c}curly\u{201d} quotes and em dashes as you type", $smartTypography)
                settingsDivider
                settingsToggle("Typewriter ticks", "A quiet click on each key", $typewriterSound)
                settingsDivider
                settingsToggle("Room tone", "A soft hush while Quire is open", $roomTone)
                settingsDivider
                settingsControlRow("Daily word goal", subtitle: "0 hides the meter in History") {
                    TextField("0", value: $dailyWordGoal, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 64)
                        .multilineTextAlignment(.trailing)
                }
            }

            settingsGroup("Lock") {
                settingsToggle(
                    "Touch ID to open Quire",
                    "A gate only. Pages stay as markdown on disk.",
                    Binding(
                        get: { journalLockEnabled },
                        set: { newValue in
                            Task { await setLockEnabled(newValue) }
                        }
                    )
                )
            }

            settingsGroup("Video") {
                settingsControlRow("Camera") {
                    Picker("Camera", selection: $preferredCamera) {
                        Text("Default").tag("")
                        ForEach(cameras, id: \.uniqueID) { device in
                            Text(device.localizedName).tag(device.uniqueID)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 220)
                }
                settingsDivider
                settingsControlRow("Microphone") {
                    Picker("Microphone", selection: $preferredMicrophone) {
                        Text("Default").tag("")
                        ForEach(microphones, id: \.uniqueID) { device in
                            Text(device.localizedName).tag(device.uniqueID)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 220)
                }
            }

            settingsGroup("Extras") {
                settingsToggle("Images", "Paste or capture a picture", $advancedImages)
                settingsDivider
                settingsToggle("Entry graph", "Map [[wiki links]] from History", $advancedGraph)
                settingsDivider
                settingsToggle("Notes", ">> in the margin, ==highlight==", $advancedAnnotations)
                settingsDivider
                settingsToggle("Mermaid", "```mermaid charts under the page", $advancedMermaid)
            }
        }
        .onAppear {
            cameras = CaptureDevices.videoDevices()
            microphones = CaptureDevices.audioDevices()
        }
    }

    private var shortFolderPath: String {
        if folderPath.contains("/Containers/") {
            return "Documents/Freewrite"
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if folderPath.hasPrefix(home) {
            return "~" + folderPath.dropFirst(home.count)
        }
        return folderPath
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use Folder"
        panel.message = "Entries, videos, and chats will be saved here."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try JournalFolder.ensureLayout(at: url)
            let data = try JournalFolder.bookmark(for: url)
            UserDefaults.standard.set(data, forKey: AppSettingsKeys.journalFolderBookmark)
            JournalFolder.beginAccess(to: url)
            folderPath = url.path
            folderError = nil
        } catch {
            folderError = "Could not use that folder."
        }
    }

    private func resetFolder() {
        UserDefaults.standard.removeObject(forKey: AppSettingsKeys.journalFolderBookmark)
        let root = JournalFolder.defaultRoot()
        try? JournalFolder.ensureLayout(at: root)
        folderPath = root.path
        folderError = nil
    }

    private func setLockEnabled(_ enabled: Bool) async {
        if enabled {
            let ok = await JournalLock.authenticate(reason: "Turn on the Freewrite lock")
            journalLockEnabled = ok
        } else {
            journalLockEnabled = false
        }
    }
}

@ViewBuilder
private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(verbatim: title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 4)
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06))
        )
    }
}

private struct AboutSettingsTab: View {
    @State private var folderPath = JournalFolder.resolve(
        bookmarkData: UserDefaults.standard.data(forKey: AppSettingsKeys.journalFolderBookmark)
    ).path

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            settingsGroup("The room") {
                aboutDetailRow("App", QuireAction.aboutName)
                settingsDivider
                aboutDetailRow("Version", QuireAction.aboutVersion)
                settingsDivider
                aboutBlurb(QuireAction.aboutCredits)
                settingsDivider
                aboutBlurb(QuireAction.aboutIdea)
            }

            settingsGroup("Surenjanath") {
                aboutDetailRow("Author", QuireAction.aboutAuthor)
                settingsDivider
                aboutDetailRow("Email", QuireAction.aboutEmail)
                settingsDivider
                aboutDetailRow("Based on", QuireAction.aboutBasedOn)
                settingsDivider
                HStack(spacing: 16) {
                    Button("Email…") { openURL("mailto:\(QuireAction.aboutEmail)") }
                    Button("Open GitHub…") { openURL(QuireAction.aboutSite) }
                    Spacer()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.accentColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            settingsGroup("On this Mac") {
                aboutDetailRow("Pages", shortFolderPath)
                settingsDivider
                aboutBlurb(QuireAction.aboutPrivacy)
                settingsDivider
                HStack {
                    Button("Show journal folder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folderPath)
                    }
                    Spacer()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.accentColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            settingsGroup("In the room") {
                ForEach(Array(QuireAction.aboutIncludes.enumerated()), id: \.offset) { index, line in
                    if index > 0 { settingsDivider }
                    aboutListRow(line)
                }
            }

            settingsGroup("Shortcuts") {
                ForEach(Array(QuireAction.aboutShortcuts.enumerated()), id: \.offset) { index, item in
                    if index > 0 { settingsDivider }
                    aboutDetailRow(item.key, item.action)
                }
            }

            Text(verbatim: QuireAction.aboutCopyright)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
        .onAppear {
            folderPath = JournalFolder.resolve(
                bookmarkData: UserDefaults.standard.data(forKey: AppSettingsKeys.journalFolderBookmark)
            ).path
        }
    }

    private var shortFolderPath: String {
        if folderPath.contains("/Containers/") {
            return "Documents/Freewrite"
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if folderPath.hasPrefix(home) {
            return "~" + folderPath.dropFirst(home.count)
        }
        return folderPath
    }

    private func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}

private func aboutBlurb(_ text: String) -> some View {
    Text(verbatim: text)
        .font(.system(size: 12))
        .foregroundColor(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
}

private func aboutListRow(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
        Text(verbatim: "•")
            .foregroundColor(.secondary)
        Text(verbatim: text)
            .font(.system(size: 13))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 9)
}

private func aboutDetailRow(_ title: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text(verbatim: title)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .frame(width: 78, alignment: .leading)
        Text(verbatim: value)
            .font(.system(size: 13))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
}

private var settingsDivider: some View {
    Divider().padding(.leading, 14)
}

private func settingsToggle(_ title: String, _ subtitle: String, _ isOn: Binding<Bool>) -> some View {
    HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: title)
                .font(.system(size: 13))
            if !subtitle.isEmpty {
                Text(verbatim: subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        Toggle(isOn: isOn) { EmptyView() }
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()
            .fixedSize()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
}

private func settingsControlRow<Content: View>(_ title: String, subtitle: String = "", @ViewBuilder content: () -> Content) -> some View {
    HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: title)
                .font(.system(size: 13))
            if !subtitle.isEmpty {
                Text(verbatim: subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        content()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
}

private func settingsFieldRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(verbatim: title)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        content()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
}

private func settingsNote(_ text: String) -> some View {
    Text(verbatim: text)
        .font(.system(size: 11))
        .foregroundColor(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 4)
}

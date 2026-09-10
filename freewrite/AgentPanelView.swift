//
//  AgentPanelView.swift
//  freewrite
//
//  Side panel for Claude Code and Codex. You watch the reply, then put it
//  on the page. Same width and buttons as the Ollama panel.
//

import SwiftUI

struct AgentPanelView: View {
    @ObservedObject var service: LocalAgentService
    let pageText: String
    let colorScheme: ColorScheme
    let canInsert: Bool
    let canUndo: Bool
    let onRun: (LocalAgent.Job, String?) -> Void
    let onApply: (JournalApply.Mode, String) -> Void
    let onUndo: () -> Void
    let onClose: () -> Void

    @State private var followUpText: String = ""
    @State private var didCopy = false
    @State private var pendingApply: (JournalApply.Mode, String)? = nil

    private var textColor: Color {
        colorScheme == .light ? .gray : .gray.opacity(0.8)
    }

    private var textHoverColor: Color {
        colorScheme == .light ? .black : .white
    }

    private var reply: String {
        service.reply.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            transcript
            Divider()
            footer
        }
        .frame(width: 280)
        .background(Color(colorScheme == .light ? .white : NSColor.black))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(service.backend.title)
                    .font(.system(size: 13))
                    .foregroundColor(textHoverColor)
                Text(service.isRunning ? "Writing…" : service.job.title)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if service.isRunning {
                Button(action: { service.cancel() }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11))
                        .foregroundColor(textColor)
                }
                .buttonStyle(.plain)
                .help("Stop")
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

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Agent", selection: $service.backend) {
                        ForEach(LocalAgent.Backend.allCases) { backend in
                            Text(backend.title).tag(backend)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .disabled(service.isRunning)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(LocalAgent.Job.allCases) { job in
                            Button(job.title) {
                                onRun(job, nil)
                            }
                            .disabled(service.isRunning)
                            .help(job.instruction)
                        }
                    }
                    .font(.system(size: 12))
                    .buttonStyle(.plain)
                    .foregroundColor(textHoverColor)

                    if let error = service.errorMessage {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .textSelection(.enabled)
                    } else if reply.isEmpty && !service.isRunning {
                        Text("Pick Reflect, Improve, Diagram, or Ask. The reply stays here until you put it on the page.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    } else {
                        Text(reply.isEmpty ? "…" : service.reply)
                            .font(.system(size: 13))
                            .foregroundColor(reply.isEmpty ? .secondary : .primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .id("agentBottom")
            }
            .onChange(of: service.reply) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("agentBottom", anchor: .bottom)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask a follow-up…", text: $followUpText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .font(.system(size: 13))
                    .disabled(service.isRunning)
                    .onSubmit { sendFollowUp() }

                Button(action: sendFollowUp) {
                    Text("Send")
                        .font(.system(size: 12))
                        .foregroundColor(followUpText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || service.isRunning ? textColor.opacity(0.4) : textHoverColor)
                }
                .buttonStyle(.plain)
                .disabled(followUpText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || service.isRunning)
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

            HStack(spacing: 8) {
                Button(action: copyReply) {
                    Text(didCopy ? "Copied!" : "Copy")
                }
                .buttonStyle(.plain)
                .foregroundColor(textColor)
                .disabled(reply.isEmpty)

                if canUndo {
                    Button("Undo") { onUndo() }
                        .buttonStyle(.plain)
                        .foregroundColor(textColor)
                }

                Spacer()

                if canInsert {
                    Button("Insert") { pendingApply = (.append, service.reply) }
                        .buttonStyle(.plain)
                        .foregroundColor(textColor)
                        .disabled(reply.isEmpty)
                        .help("Append the reply to this page")

                    Menu {
                        Button("Replace") { pendingApply = (.replace, service.reply) }
                            .help("Replace the page text. Pasted images stay.")
                        Button("Note") { pendingApply = (.note, service.reply) }
                            .help("Add the first sentence as a >> note")
                    } label: {
                        Text("More")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .disabled(reply.isEmpty)
                }
            }
            .font(.system(size: 12))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func sendFollowUp() {
        let extra = followUpText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !extra.isEmpty, !service.isRunning else { return }
        followUpText = ""
        onRun(service.job, extra)
    }

    private func copyReply() {
        guard !reply.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(service.reply, forType: .string)
        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            didCopy = false
        }
    }
}

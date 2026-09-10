//
//  LocalAgent.swift
//  freewrite
//
//  Runs Claude Code or Codex on this Mac. The journal goes in on stdin.
//  Replies can include mermaid diagrams and SVG pictures.
//

import Combine
import Foundation

enum LocalAgent {
    enum Backend: String, CaseIterable, Identifiable {
        case claude
        case codex

        var id: String { rawValue }

        var title: String {
            switch self {
            case .claude: return "Claude Code"
            case .codex: return "Codex"
            }
        }

        var commandName: String { rawValue }
    }

    enum Job: String, CaseIterable, Identifiable {
        case reflect
        case improve
        case diagram
        case ask

        var id: String { rawValue }

        var title: String {
            switch self {
            case .reflect: return "Reflect"
            case .improve: return "Improve"
            case .diagram: return "Diagram"
            case .ask: return "Ask"
            }
        }

        var instruction: String {
            switch self {
            case .reflect:
                return "Read the journal. Talk it through with me. Point out a pattern I might not see. A few honest paragraphs."
            case .improve:
                return "Rewrite the page in my voice, clearer and tighter. Keep my meaning. Return only the revised writing, no preamble."
            case .diagram:
                return "Turn the journal into one mermaid diagram or chart that shows the shape of what I wrote. Return only the mermaid fence."
            case .ask:
                return "Ask me one sharp question about what I wrote. Nothing else."
            }
        }
    }

    enum RunError: LocalizedError {
        case missingBinary(String)
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .missingBinary(let name):
                return "Couldn't find \(name). Choose the binary in Settings → Chat."
            case .failed(let message):
                return message
            }
        }
    }

    static let visualAddendum = """
    If a diagram, flowchart, or graph would help, add a mermaid fenced block:

    ```mermaid
    graph TD
      A[Start] --> B[Write]
    ```

    Pie charts and xychart-beta are fine. For a small picture, add an SVG fenced block (```svg).
    Do not open with a greeting. Use only the journal text below.
    """

    static func defaultSearchPaths(for backend: Backend) -> [String] {
        let home = NSHomeDirectory()
        let name = backend.commandName
        return [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "\(home)/.local/bin/\(name)",
            "\(home)/.npm-global/bin/\(name)",
        ]
    }

    static func resolvedPath(for backend: Backend, override: String) -> String? {
        let trimmed = override.trimmingCharacters(in: .whitespacesAndNewlines)
        var candidates = defaultSearchPaths(for: backend)
        if !trimmed.isEmpty {
            candidates.insert(trimmed, at: 0)
        }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func arguments(for backend: Backend) -> [String] {
        switch backend {
        case .claude:
            return ["-p", "--output-format", "text"]
        case .codex:
            return ["exec"]
        }
    }

    static func packet(instruction: String, entry: String) -> String {
        packet(jobInstruction: instruction, tone: "", entry: entry, extra: nil)
    }

    static func packet(job: Job, tone: String, entry: String, extra: String? = nil) -> String {
        packet(jobInstruction: job.instruction, tone: tone, entry: entry, extra: extra)
    }

    private static func packet(jobInstruction: String, tone: String, entry: String, extra: String?) -> String {
        var parts = [jobInstruction]
        let trimmedTone = tone.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTone.isEmpty { parts.append(trimmedTone) }
        parts.append(visualAddendum)
        parts.append("JOURNAL")
        parts.append(entry.trimmingCharacters(in: .whitespacesAndNewlines))
        if let extra, !extra.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("FOLLOW UP")
            parts.append(extra.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return parts.joined(separator: "\n\n")
    }

    static func svgBlocks(in text: String) -> [String] {
        let pattern = "```svg\\s*\\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let value = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
    }

    static func strippingSVGFences(_ text: String) -> String {
        let pattern = "```svg\\s*\\n[\\s\\S]*?```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func run(
        executable: String,
        arguments: [String],
        packet: String,
        onProcess: ((Process) -> Void)? = nil,
        onChunk: ((String) -> Void)? = nil
    ) throws -> String {
        guard FileManager.default.isExecutableFile(atPath: executable) else {
            throw RunError.missingBinary(URL(fileURLWithPath: executable).lastPathComponent)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment
        let input = Pipe()
        let output = Pipe()
        let error = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = error
        onProcess?(process)
        // Both pipes must be drained while the process runs, not just stdout: a pipe's kernel
        // buffer is ~64KB, and a chatty agent CLI (progress, deprecation warnings, telemetry)
        // can fill stderr while stdout stays quiet. If nobody is reading, the child blocks on
        // its next write and `waitUntilExit()` below blocks forever — a silent, uncancelable hang.
        var collected = ""
        var stderrCollected = ""
        output.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else { return }
            collected += chunk
            onChunk?(chunk)
        }
        error.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else { return }
            stderrCollected += chunk
        }
        try process.run()
        input.fileHandleForWriting.write(Data(packet.utf8))
        try input.fileHandleForWriting.close()
        process.waitUntilExit()
        output.fileHandleForReading.readabilityHandler = nil
        error.fileHandleForReading.readabilityHandler = nil
        let leftoverOut = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if !leftoverOut.isEmpty {
            collected += leftoverOut
            onChunk?(leftoverOut)
        }
        let leftoverErr = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if !leftoverErr.isEmpty {
            stderrCollected += leftoverErr
        }
        let stdout = collected
        let stderr = stderrCollected
        let reply = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if process.terminationStatus != 0, reply.isEmpty {
            let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw RunError.failed(message.isEmpty ? "\(URL(fileURLWithPath: executable).lastPathComponent) failed." : message)
        }
        return reply
    }
}

@MainActor
final class LocalAgentService: ObservableObject {
    @Published var reply: String = ""
    @Published var isRunning: Bool = false
    @Published var errorMessage: String? = nil
    @Published var backend: LocalAgent.Backend = .claude
    @Published var job: LocalAgent.Job = .reflect

    private var worker: Task<Void, Never>? = nil
    private var process: Process? = nil
    private var didCancel = false

    func start(executable: String, backend: LocalAgent.Backend, packet: String) {
        cancel()
        didCancel = false
        self.backend = backend
        reply = ""
        errorMessage = nil
        isRunning = true
        worker = Task.detached { [weak self] in
            do {
                let text = try LocalAgent.run(
                    executable: executable,
                    arguments: LocalAgent.arguments(for: backend),
                    packet: packet,
                    onProcess: { process in
                        Task { @MainActor [weak self] in
                            self?.process = process
                        }
                    },
                    onChunk: { chunk in
                        Task { @MainActor [weak self] in
                            self?.reply += chunk
                        }
                    }
                )
                await MainActor.run { [weak self] in
                    guard let self, !self.didCancel else { return }
                    if self.reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.reply = text
                    }
                    self.isRunning = false
                    self.process = nil
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self, !self.didCancel else { return }
                    self.errorMessage = error.localizedDescription
                    self.isRunning = false
                    self.process = nil
                }
            }
        }
    }

    func cancel() {
        didCancel = true
        process?.terminate()
        process = nil
        worker?.cancel()
        worker = nil
        isRunning = false
    }
}

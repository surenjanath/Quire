//
//  OllamaService.swift
//  freewrite
//
//  Talks to a local Ollama server (https://ollama.com) for fully offline AI
//  reflection on journal entries. No data ever leaves the machine.
//

import Foundation

struct OllamaChatMessage: Identifiable, Equatable {
    enum Role: String {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    var content: String
}

@MainActor
final class OllamaService: ObservableObject {
    @Published var messages: [OllamaChatMessage] = []
    @Published var isStreaming: Bool = false
    @Published var errorMessage: String? = nil
    @Published var availableModels: [String] = []
    @Published var isLoadingModels: Bool = false
    @Published var isPulling: Bool = false
    @Published var pullStatus: String = ""
    @Published var pullProgress: Double? = nil
    @Published var pullError: String? = nil

    private var streamTask: Task<Void, Never>? = nil
    private var pullTask: Task<Void, Never>? = nil

    private struct TagsResponse: Decodable {
        struct Model: Decodable {
            let name: String
        }
        let models: [Model]
    }

    private struct ChatChunk: Decodable {
        struct Message: Decodable {
            let role: String?
            let content: String?
        }
        let message: Message?
        let done: Bool?
    }

    private struct PullChunk: Decodable {
        let status: String?
        let completed: Int?
        let total: Int?
        let error: String?
    }

    func fetchModels(endpoint: String) async {
        isLoadingModels = true
        defer { isLoadingModels = false }

        guard let url = Self.apiURL(endpoint: endpoint, path: "api/tags") else {
            errorMessage = "That doesn't look like a valid URL."
            availableModels = []
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw OllamaServiceError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
            }
            let decoded = try JSONDecoder().decode(TagsResponse.self, from: data)
            availableModels = decoded.models.map(\.name).sorted()
            errorMessage = nil
        } catch {
            availableModels = []
            errorMessage = Self.friendlyMessage(for: error)
        }
    }

    /// Starts a fresh conversation: clears history and sends `initialPrompt` as the first
    /// user turn.
    func startConversation(endpoint: String, model: String, initialPrompt: String) {
        messages = [OllamaChatMessage(role: .user, content: initialPrompt)]
        streamAssistantReply(endpoint: endpoint, model: model)
    }

    /// Appends a follow-up user message to the existing conversation and streams the
    /// assistant's reply, with the full message history sent as context each time (Ollama's
    /// `/api/chat` is stateless per-request — the client owns the transcript).
    func sendFollowUp(endpoint: String, model: String, text: String) {
        guard !isStreaming else { return }
        messages.append(OllamaChatMessage(role: .user, content: text))
        streamAssistantReply(endpoint: endpoint, model: model)
    }

    func resetConversation() {
        cancel()
        messages = []
    }

    private func streamAssistantReply(endpoint: String, model: String) {
        cancel()

        guard let url = Self.apiURL(endpoint: endpoint, path: "api/chat") else {
            errorMessage = "That doesn't look like a valid URL."
            return
        }
        guard !model.isEmpty else {
            errorMessage = "Pick a model first."
            return
        }

        errorMessage = nil
        isStreaming = true
        let assistantIndex = messages.count
        messages.append(OllamaChatMessage(role: .assistant, content: ""))
        let payloadMessages = messages.dropLast().map { ["role": $0.role.rawValue, "content": $0.content] }

        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: [
                    "model": model,
                    "messages": payloadMessages,
                    "stream": true
                ])

                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                    throw OllamaServiceError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
                }

                for try await line in bytes.lines {
                    if Task.isCancelled { return }
                    guard let data = line.data(using: .utf8),
                          let chunk = try? JSONDecoder().decode(ChatChunk.self, from: data) else {
                        continue
                    }
                    if let fragment = chunk.message?.content, !fragment.isEmpty,
                       assistantIndex < self.messages.count {
                        self.messages[assistantIndex].content += fragment
                    }
                    if chunk.done == true {
                        break
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = Self.friendlyMessage(for: error)
                    if assistantIndex < self.messages.count, self.messages[assistantIndex].content.isEmpty {
                        self.messages.remove(at: assistantIndex)
                    }
                }
            }
            self.isStreaming = false
        }
    }

    func cancel() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }

    /// Pulls a model from the Ollama library, streaming progress. On success, refreshes
    /// `availableModels` so the new model shows up immediately.
    func pullModel(endpoint: String, name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            pullError = "Enter a model name first."
            return
        }
        guard let url = Self.apiURL(endpoint: endpoint, path: "api/pull") else {
            pullError = "That doesn't look like a valid URL."
            return
        }

        pullTask?.cancel()
        pullError = nil
        pullStatus = "Starting..."
        pullProgress = nil
        isPulling = true

        pullTask = Task { [weak self] in
            guard let self else { return }
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: [
                    "name": trimmedName,
                    "stream": true
                ])

                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                    throw OllamaServiceError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
                }

                for try await line in bytes.lines {
                    if Task.isCancelled { return }
                    guard let data = line.data(using: .utf8),
                          let chunk = try? JSONDecoder().decode(PullChunk.self, from: data) else {
                        continue
                    }
                    if let error = chunk.error, !error.isEmpty {
                        self.pullError = error
                        break
                    }
                    if let status = chunk.status {
                        self.pullStatus = status
                    }
                    if let completed = chunk.completed, let total = chunk.total, total > 0 {
                        self.pullProgress = Double(completed) / Double(total)
                    }
                }
                if self.pullError == nil {
                    await self.fetchModels(endpoint: endpoint)
                }
            } catch {
                if !Task.isCancelled {
                    self.pullError = Self.friendlyMessage(for: error)
                }
            }
            self.isPulling = false
        }
    }

    func cancelPull() {
        pullTask?.cancel()
        pullTask = nil
        isPulling = false
    }

    private static func apiURL(endpoint: String, path: String) -> URL? {
        var trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        guard let base = URL(string: trimmed) else { return nil }
        return base.appendingPathComponent(path)
    }

    private static func friendlyMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .timedOut:
                return "Can't reach Ollama. Make sure it's installed and running (\"ollama serve\")."
            default:
                break
            }
        }
        if let serviceError = error as? OllamaServiceError {
            switch serviceError {
            case .httpError(let code):
                return "Ollama returned an error (HTTP \(code)). If the model isn't pulled yet, try \"ollama pull <model>\"."
            }
        }
        return error.localizedDescription
    }
}

private enum OllamaServiceError: Error {
    case httpError(Int)
}

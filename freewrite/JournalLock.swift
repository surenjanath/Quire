//
//  JournalLock.swift
//  freewrite
//
//  Optional launch gate. Files stay plain markdown on disk; this only
//  asks for Touch ID / the Mac password before showing the journal.
//

import SwiftUI
import LocalAuthentication

enum JournalLock {
    static func shouldChallenge(enabled: Bool, alreadyUnlocked: Bool, canEvaluate: Bool) -> Bool {
        enabled && !alreadyUnlocked && canEvaluate
    }

    static func canEvaluate(context: LAContext = LAContext()) -> Bool {
        context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    static func authenticate(
        reason: String = "Unlock Freewrite",
        context: LAContext = LAContext()
    ) async -> Bool {
        guard canEvaluate(context: context) else { return true }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}

struct JournalLockGate: View {
    let colorScheme: ColorScheme
    let onUnlocked: () -> Void

    @State private var message: String?
    @State private var isWorking = false

    var body: some View {
        ZStack {
            Color(colorScheme == .light ? .white : .black)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.secondary)
                Text("Freewrite is locked")
                    .font(.system(size: 16, weight: .medium))
                Text("Touch ID or your Mac password")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Button(action: { Task { await unlock() } }) {
                    Text(isWorking ? "Unlocking…" : "Unlock")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .disabled(isWorking)
                if let message {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .task {
            await unlock()
        }
    }

    private func unlock() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        if await JournalLock.authenticate() {
            message = nil
            onUnlocked()
        } else {
            message = "Try again when you are ready."
        }
    }
}

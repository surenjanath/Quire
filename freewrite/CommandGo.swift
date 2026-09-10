//
//  CommandGo.swift
//  freewrite
//
//  ⌘K: jump to a command or a past page without opening History first.
//

import SwiftUI

enum CommandGo {
    enum Kind: Equatable {
        case command
        case page
    }

    struct Item: Identifiable, Equatable {
        let id: String
        let title: String
        let hint: String
        let kind: Kind
    }

    static let catalog: [(id: String, title: String, hint: String)] = [
        ("new", "New page", "⌘N"),
        ("history", "History", "⌘⇧H"),
        ("find", "Find on this page", "⌘F"),
        ("chat", "Ollama", "⌘⇧O"),
        ("claude-code", "Claude Code", ""),
        ("codex", "Codex", ""),
        ("weekly", "Weekly review", "⌘⇧R"),
        ("focus", "Focus this sentence", "⌘⇧L"),
        ("typewriter", "Typewriter", "⌘⇧Y"),
        ("privacy", "Hide the page", "⌘⇧P"),
        ("random", "Random page", ""),
        ("versions", "Earlier versions", ""),
        ("export", "Export PDF", "⌘⇧E"),
        ("export-journal", "Export journal", ""),
        ("settings", "Settings", "⌘,"),
    ]

    static func commands(matching query: String) -> [Item] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let items = catalog.map { Item(id: $0.id, title: $0.title, hint: $0.hint, kind: .command) }
        if needle.isEmpty { return items }
        return items.filter { item in
            item.title.lowercased().contains(needle) || item.id.contains(needle)
        }
    }

    static func pageItem(id: String, title: String, hint: String) -> Item {
        Item(id: id, title: title, hint: hint, kind: .page)
    }
}

struct GoPaletteView: View {
    @Binding var query: String
    let items: [CommandGo.Item]
    let onPick: (CommandGo.Item) -> Void
    let onClose: () -> Void

    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                TextField("Go somewhere…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($fieldFocused)
                    .onSubmit { pickFirst() }
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if items.isEmpty {
                Text("Nothing matches")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            } else {
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(items.prefix(12)) { item in
                            Button {
                                onPick(item)
                            } label: {
                                HStack(spacing: 8) {
                                    Text(item.title)
                                        .font(.system(size: 13))
                                        .lineLimit(1)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(item.hint.isEmpty ? (item.kind == .page ? "Page" : "") : item.hint)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
        .frame(width: 420)
        .background(.bar)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.18), radius: 16, y: 8)
        .onAppear { fieldFocused = true }
    }

    private func pickFirst() {
        guard let first = items.first else { return }
        onPick(first)
    }
}

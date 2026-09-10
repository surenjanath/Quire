//
//  AdvancedPanels.swift
//  freewrite
//
//  Gated History companions: a quiet entry graph and an annotation rail.
//

import SwiftUI
import AppKit

struct EntryGraphPanel: View {
    let edges: [MarkdownExtras.GraphEdge]
    let entries: [HumanEntry]
    let colorScheme: ColorScheme
    let onSelectFilename: (String) -> Void
    let onClose: () -> Void

    private var textColor: Color {
        colorScheme == .light ? .gray : .gray.opacity(0.8)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Graph")
                        .font(.system(size: 13))
                    Text("Links from [[wiki]] marks")
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

            Divider()

            if edges.isEmpty {
                Text("Add [[links]] in an entry to connect it to another note.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(edges.enumerated()), id: \.offset) { _, edge in
                            Button(action: { onSelectFilename(edge.to) }) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(label(for: edge.from))
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Text(label(for: edge.to))
                                        .font(.system(size: 13))
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(width: 280)
        .background(Color(colorScheme == .light ? .white : NSColor.black))
    }

    private func label(for filename: String) -> String {
        if let entry = entries.first(where: { $0.filename == filename }) {
            let preview = entry.previewText.trimmingCharacters(in: .whitespacesAndNewlines)
            return preview.isEmpty ? entry.date : preview
        }
        return filename
    }
}

struct AnnotationRail: View {
    let notes: [String]
    let highlights: [String]
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !notes.isEmpty {
                Text("Notes")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                ForEach(notes, id: \.self) { note in
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !highlights.isEmpty {
                Text("Highlights")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                ForEach(highlights, id: \.self) { highlight in
                    Text(highlight)
                        .font(.system(size: 12))
                        .italic()
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .frame(width: 168, alignment: .topLeading)
        .background(Color(colorScheme == .light ? .white : .black))
    }
}

struct ImageStrip: View {
    let paths: [String]
    let documentsDirectory: URL
    var onEdit: ((String) -> Void)? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(paths, id: \.self) { path in
                    if let image = NSImage(contentsOf: documentsDirectory.appendingPathComponent(path)) {
                        Button(action: { onEdit?(path) }) {
                            ZStack(alignment: .bottomTrailing) {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 120, height: 72)
                                    .background(Color.gray.opacity(0.06))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                                    )
                                if onEdit != nil {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(4)
                                        .background(Circle().fill(Color.black.opacity(0.45)))
                                        .padding(4)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Draw on this image")
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(height: 88)
        .background(Color.gray.opacity(0.04))
    }
}

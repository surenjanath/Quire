//
//  PageCompare.swift
//  freewrite
//
//  Show what Insert / Replace / Note will do before it lands.
//

import SwiftUI

enum PageCompare {
    static func preview(reply: String, mode: JournalApply.Mode, onto stored: String) -> String {
        MarkdownExtras.visibleBody(JournalApply.applying(reply, mode: mode, onto: stored))
    }

    static func beforeVisible(_ stored: String) -> String {
        MarkdownExtras.visibleBody(stored)
    }

    static func changed(before: String, after: String) -> Bool {
        beforeVisible(before) != beforeVisible(after)
    }

    static func modeTitle(_ mode: JournalApply.Mode) -> String {
        switch mode {
        case .append: return "Insert"
        case .replace: return "Replace"
        case .note: return "Note"
        }
    }
}

struct ApplyCompareView: View {
    let mode: JournalApply.Mode
    let before: String
    let after: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(PageCompare.modeTitle(mode)) will look like this")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            HStack(alignment: .top, spacing: 8) {
                compareColumn(title: "Now", body: before)
                compareColumn(title: "After", body: after)
            }

            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
                Button("Put on page", action: onConfirm)
            }
            .font(.system(size: 12))
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func compareColumn(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(body.isEmpty ? "Empty" : body)
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .lineLimit(8)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.08)))
    }
}

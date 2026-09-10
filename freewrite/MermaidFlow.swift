//
//  MermaidFlow.swift
//  freewrite
//
//  Offline reader for fenced ```mermaid flowcharts (graph/flowchart TD|LR).
//

import Foundation
import SwiftUI

enum MermaidFlow {
    struct Node: Equatable, Hashable {
        let id: String
        let label: String
    }

    struct Edge: Equatable {
        let from: String
        let to: String
    }

    struct Chart: Equatable {
        var direction: String
        var nodes: [Node]
        var edges: [Edge]
    }

    static func parse(_ body: String) -> Chart {
        var direction = "TD"
        var nodes: [Node] = []
        var edges: [Edge] = []
        var seen = Set<String>()

        func addNode(id: String, label: String?) {
            guard seen.insert(id).inserted else {
                if let label, let index = nodes.firstIndex(where: { $0.id == id }), nodes[index].label == id {
                    nodes[index] = Node(id: id, label: label)
                }
                return
            }
            nodes.append(Node(id: id, label: label ?? id))
        }

        for raw in body.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("%%") { continue }
            if line.lowercased().hasPrefix("graph ") || line.lowercased().hasPrefix("flowchart ") {
                let parts = line.split(whereSeparator: { $0.isWhitespace })
                if let last = parts.last {
                    direction = String(last).uppercased()
                }
                continue
            }
            guard let parsed = parseEdgeLine(line) else { continue }
            addNode(id: parsed.from.id, label: parsed.from.label)
            addNode(id: parsed.to.id, label: parsed.to.label)
            edges.append(Edge(from: parsed.from.id, to: parsed.to.id))
        }

        return Chart(direction: direction, nodes: nodes, edges: edges)
    }

    private static func parseEdgeLine(_ line: String) -> (from: (id: String, label: String?), to: (id: String, label: String?))? {
        let arrows = ["-->", "---", "-.->", "==>"]
        guard let arrow = arrows.first(where: { line.contains($0) }) else { return nil }
        let parts = line.components(separatedBy: arrow)
        guard parts.count >= 2 else { return nil }
        let left = parseNode(parts[0])
        let right = parseNode(parts[1])
        guard let left, let right else { return nil }
        return (left, right)
    }

    private static func parseNode(_ raw: String) -> (id: String, label: String?)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let start = trimmed.firstIndex(of: "["), let end = trimmed.lastIndex(of: "]"), start < end {
            let id = String(trimmed[..<start]).trimmingCharacters(in: .whitespaces)
            let label = String(trimmed[trimmed.index(after: start)..<end])
            guard !id.isEmpty else { return nil }
            return (id, label)
        }
        if let start = trimmed.firstIndex(of: "("), let end = trimmed.lastIndex(of: ")"), start < end {
            let id = String(trimmed[..<start]).trimmingCharacters(in: .whitespaces)
            let label = String(trimmed[trimmed.index(after: start)..<end])
            guard !id.isEmpty else { return nil }
            return (id, label)
        }
        let id = trimmed.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? trimmed
        guard !id.isEmpty else { return nil }
        return (id, nil)
    }
}

struct MermaidStrip: View {
    let charts: [MermaidFlow.Chart]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(Array(charts.enumerated()), id: \.offset) { index, chart in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(charts.count == 1 ? "Diagram" : "Diagram \(index + 1)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                        if chart.edges.isEmpty {
                            ForEach(chart.nodes, id: \.id) { node in
                                Text(node.label)
                                    .font(.system(size: 12))
                            }
                        } else {
                            ForEach(Array(chart.edges.enumerated()), id: \.offset) { _, edge in
                                Text("\(label(edge.from, in: chart)) → \(label(edge.to, in: chart))")
                                    .font(.system(size: 12))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 88)
    }

    private func label(_ id: String, in chart: MermaidFlow.Chart) -> String {
        chart.nodes.first(where: { $0.id == id })?.label ?? id
    }
}

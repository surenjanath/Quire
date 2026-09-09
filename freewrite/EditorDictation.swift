//
//  EditorDictation.swift
//  freewrite
//
//  Combines a snapshot of the editor with a live speech transcript so partial
//  recognition results can replace themselves without eating already-typed text.
//

import Foundation

enum EditorDictation {
    static func combining(base: String, transcript: String) -> String {
        let spoken = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        var stem = base
        if !stem.hasPrefix("\n\n") {
            stem = "\n\n" + stem.trimmingCharacters(in: .newlines)
        }
        guard !spoken.isEmpty else {
            return stem
        }
        if stem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\n\n" + spoken
        }
        if stem.hasSuffix(" ") || stem.hasSuffix("\n") {
            return stem + spoken
        }
        return stem + " " + spoken
    }
}

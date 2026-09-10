//
//  PageLock.swift
//  freewrite
//
//  Touch ID on one page. Files stay plain markdown on disk.
//

import Foundation

enum PageLock {
    static func parse(_ stored: String) -> Set<String> {
        Set(
            stored.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    static func serialize(_ ids: Set<String>) -> String {
        ids.sorted().joined(separator: ",")
    }

    static func toggling(_ id: String, in ids: Set<String>) -> Set<String> {
        var next = ids
        if next.contains(id) {
            next.remove(id)
        } else {
            next.insert(id)
        }
        return next
    }

    static func shouldChallenge(locked: Bool, alreadyUnlocked: Bool) -> Bool {
        locked && !alreadyUnlocked
    }
}

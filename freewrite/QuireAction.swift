//
//  QuireAction.swift
//  freewrite
//
//  Menu and toolbar actions, plus the About copy. ContentView listens
//  for these notifications so the Mac menus stay out of the page.
//

import Foundation

enum QuireAction {
    static let aboutName = "Quire"
    static let aboutAuthor = "Surenjanath"
    static let aboutEmail = "surenjanath.singh@gmail.com"
    static let aboutBasedOn = "Freewrite by Farza"
    static let aboutCredits = "A quiet, local-first writing room. Pages stay on this Mac."
    static let aboutSite = "https://github.com/surenjanath/Quire"
    static let aboutIdea = "One blank page. A timer if you want urgency. Backspace lock if you want momentum. Everything else stays behind the glass until you ask."
    static let aboutPrivacy = "No account. No sync. No analytics. ChatGPT and Claude open in the browser only if you click them. Ollama, Claude Code, and Codex stay on this Mac. Pages are plain markdown you can open in any editor."
    static let aboutFolderHint = "~/Documents/Freewrite"
    static let aboutCopyright = "Copyright © 2026 Surenjanath"
    static let aboutIncludes = [
        "A daily spark on the empty page",
        "History, search, pins, streak, and a month calendar",
        "Go (⌘K) to jump to a past page, run a command, or ask your journal a question",
        "Voice notes, dictation, video journal, and Read Aloud to hear the page back",
        "Optional Chat: ChatGPT, Claude, Ollama, Claude Code, Codex — grounded in your own pages",
        "Earlier versions before Chat changes the page",
        "Import a page from another app, export one as PDF, or the whole journal as a zip",
        "Journal stats — lifetime words, longest entry, best streak",
        "Deleting asks first, then goes to the Trash — not gone forever"
    ]
    static let aboutShortcuts: [(key: String, action: String)] = [
        ("⌘N", "New page"),
        ("⌘K", "Go"),
        ("⌘,", "Settings"),
        ("⌘F", "Find on this page"),
        ("⌘⇧H", "History"),
        ("⌘⇧O", "Chat"),
        ("⌘⇧R", "Weekly review"),
        ("⌘⇧L", "Focus this sentence"),
        ("⌘⇧P", "Hide the page"),
        ("⌘⇧B", "Lock backspace"),
        ("⌘⇧D", "Light / dark"),
        ("⌘⇧T", "Timer"),
        ("⌃⌘F", "Fullscreen")
    ]

    static var aboutVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let short, let build, short != build {
            return "\(short) (\(build))"
        }
        return short ?? "1.0"
    }

    static let newPage = Notification.Name("quire.action.newPage")
    static let toggleHistory = Notification.Name("quire.action.toggleHistory")
    static let toggleChat = Notification.Name("quire.action.toggleChat")
    static let exportPDF = Notification.Name("quire.action.exportPDF")
    static let exportJournal = Notification.Name("quire.action.exportJournal")
    static let go = Notification.Name("quire.action.go")
    static let toggleSentenceFocus = Notification.Name("quire.action.toggleSentenceFocus")
    static let showVersions = Notification.Name("quire.action.showVersions")
    static let settingsClosed = Notification.Name("quireSettingsClosed")
    static let openSettings = Notification.Name("quire.action.openSettings")

    static func post(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: nil)
    }
}

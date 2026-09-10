import Foundation
import Testing

@testable import freewrite

struct JournalFolderTests {
    @Test func resolveNilAndGarbageFallBackToDefault() {
        let fallback = JournalFolder.defaultRoot()
        #expect(JournalFolder.resolve(bookmarkData: nil) == fallback)
        #expect(JournalFolder.resolve(bookmarkData: Data([0x00, 0x01, 0x02])) == fallback)
    }

    @Test func resolveUsesInjectedBookmarkURL() {
        let custom = URL(fileURLWithPath: "/tmp/MyJournal", isDirectory: true)
        let resolved = JournalFolder.resolve(bookmarkData: Data("bookmark".utf8)) { _ in custom }
        #expect(resolved == custom)
    }

    @Test func videosAndChatsLiveUnderRoot() {
        let root = URL(fileURLWithPath: "/tmp/FreewriteRoot", isDirectory: true)
        #expect(JournalFolder.videosURL(root: root).lastPathComponent == "Videos")
        #expect(JournalFolder.chatsURL(root: root).lastPathComponent == "Chats")
        #expect(JournalFolder.videosURL(root: root).deletingLastPathComponent() == root)
        #expect(JournalFolder.chatsURL(root: root).deletingLastPathComponent() == root)
    }

    @Test func ensureLayoutCreatesVideosAndChats() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("freewrite-folder-\(UUID().uuidString)", isDirectory: true)
        try JournalFolder.ensureLayout(at: root)
        #expect(FileManager.default.fileExists(atPath: JournalFolder.videosURL(root: root).path))
        #expect(FileManager.default.fileExists(atPath: JournalFolder.chatsURL(root: root).path))
        try? FileManager.default.removeItem(at: root)
    }
}

struct JournalLockTests {
    @Test func challengesOnlyWhenEnabledLockedAndAvailable() {
        #expect(JournalLock.shouldChallenge(enabled: true, alreadyUnlocked: false, canEvaluate: true))
        #expect(!JournalLock.shouldChallenge(enabled: false, alreadyUnlocked: false, canEvaluate: true))
        #expect(!JournalLock.shouldChallenge(enabled: true, alreadyUnlocked: true, canEvaluate: true))
        #expect(!JournalLock.shouldChallenge(enabled: true, alreadyUnlocked: false, canEvaluate: false))
    }
}

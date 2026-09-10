// Swift 5.0
//
//  ContentView.swift
//  freewrite
//
//  Created by thorfinn on 2/14/25.
//

import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers
import PDFKit

enum EntryType {
    case text
    case video
}

struct HumanEntry: Identifiable {
    let id: UUID
    let date: String
    let filename: String
    var previewText: String
    var entryType: EntryType
    var videoFilename: String?

    static func createNew() -> HumanEntry {
        let id = UUID()
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let dateString = dateFormatter.string(from: now)

        // For display
        dateFormatter.dateFormat = "MMM d"
        let displayDate = dateFormatter.string(from: now)

        return HumanEntry(
            id: id,
            date: displayDate,
            filename: "[\(id)]-[\(dateString)].md",
            previewText: "",
            entryType: .text,
            videoFilename: nil
        )
    }

    static func createVideoEntry() -> HumanEntry {
        let id = UUID()
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let dateString = dateFormatter.string(from: now)

        // For display
        dateFormatter.dateFormat = "MMM d"
        let displayDate = dateFormatter.string(from: now)

        let videoFilename = "[\(id)]-[\(dateString)].mov"

        return HumanEntry(
            id: id,
            date: displayDate,
            filename: "[\(id)]-[\(dateString)].md",
            previewText: "Video Entry",
            entryType: .video,
            videoFilename: videoFilename
        )
    }
}

struct HeartEmoji: Identifiable {
    let id = UUID()
    var position: CGPoint
    var offset: CGFloat = 0
}

struct ContentView: View {
    private struct VideoPermissionPopoverItem: Identifiable {
        let id = UUID()
        let message: String
        let buttonLabel: String
        let settingsPane: String
    }

    @State private var entries: [HumanEntry] = []
    @State private var text: String = ""  // Remove initial welcome text since we'll handle it in createNewEntry
    
    // Settings is an overlay. Window("Settings") and Settings { } both double letters.
    @State private var showingSettings = false
    @State private var isFullscreen = false
    @AppStorage(AppSettingsKeys.selectedFont) private var selectedFont: String = AppSettingsDefaults.selectedFont
    @State private var currentRandomFont: String = ""
    @AppStorage(AppSettingsKeys.preferredTimerSeconds) private var preferredTimerSeconds: Int = AppSettingsDefaults.timerSeconds
    @AppStorage(AppSettingsKeys.typewriterMode) private var typewriterMode = false
    @AppStorage(AppSettingsKeys.sentenceFocus) private var sentenceFocus = false
    @AppStorage(AppSettingsKeys.typewriterSound) private var typewriterSound = false
    @AppStorage(AppSettingsKeys.roomTone) private var roomToneEnabled = false
    @AppStorage(AppSettingsKeys.softMarkdown) private var softMarkdown = false
    @AppStorage(AppSettingsKeys.lockedPageIDs) private var lockedPageIDsStored = ""
    @AppStorage(AppSettingsKeys.advancedImages) private var advancedImages = false
    @AppStorage(AppSettingsKeys.advancedGraph) private var advancedGraph = false
    @AppStorage(AppSettingsKeys.advancedAnnotations) private var advancedAnnotations = false
    @AppStorage(AppSettingsKeys.advancedMermaid) private var advancedMermaid = false
    @AppStorage(AppSettingsKeys.dailyWordGoal) private var dailyWordGoal = 0
    @State private var annotatingImagePath: String?
    @State private var imageStripEpoch = 0
    @State private var privacyHidden = false
    @State private var showingFind = false
    @State private var showingGo = false
    @State private var goQuery = ""
    @State private var showingVersions = false
    @State private var showingStats = false
    @State private var journalStatsSummary: JournalStats.Summary = .empty
    @State private var findQuery = ""
    @State private var findIndex: Int?
    @State private var textNeedsSave = false
    @State private var pendingDelete: HumanEntry?
    @AppStorage(AppSettingsKeys.followSystemAppearance) private var followSystemAppearance = false
    @AppStorage(AppSettingsKeys.idleFadeEnabled) private var idleFadeEnabled = false
    @AppStorage(AppSettingsKeys.favoriteFonts) private var favoriteFonts = ""
    @State private var lastActivityAt = Date()
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var timeRemaining: Int = AppSettingsDefaults.timerSeconds
    @State private var timerIsRunning = false
    @State private var isHoveringTimer = false
    @State private var isHoveringFullscreen = false
    @AppStorage(AppSettingsKeys.fontSize) private var storedFontSize: Double = AppSettingsDefaults.fontSize
    @State private var blinkCount = 0
    @State private var isBlinking = false
    @State private var opacity: Double = 1.0
    @State private var shouldShowGray = true // New state to control color
    @State private var lastClickTime: Date? = nil
    @State private var bottomNavOpacity: Double = 1.0
    @State private var isHoveringBottomNav = false
    @State private var selectedEntryIndex: Int = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var selectedEntryId: UUID? = nil
    @State private var hoveredEntryId: UUID? = nil
    @State private var isHoveringChat = false  // Add this state variable
    @State private var showingChatMenu = false
    @State private var chatMenuAnchor: CGPoint = .zero
    @State private var showingSidebar = false  // Add this state variable
    @State private var hoveredTrashId: UUID? = nil
    @State private var hoveredExportId: UUID? = nil
    @State private var placeholderText: String = ""  // Add this line
    @State private var isHoveringNewEntry = false
    @State private var isHoveringClock = false
    @State private var isHoveringHistory = false
    @State private var isHoveringHistoryText = false
    @State private var isHoveringHistoryPath = false
    @State private var isHoveringHistoryArrow = false
    @State private var isHoveringCopyTranscript = false
    @State private var colorScheme: ColorScheme = .light // Add state for color scheme
    @State private var isHoveringThemeToggle = false // Add state for theme toggle hover
    @State private var didCopyPrompt: Bool = false // Add state for copy prompt feedback
    @State private var didCopyTranscript: Bool = false
    @State private var selectedVideoHasTranscript = false
    @AppStorage(AppSettingsKeys.backspaceDisabled) private var backspaceDisabled = false
    @State private var isHoveringBackspaceToggle = false // Add state for backspace toggle hover
    @State private var showingVideoRecording = false // Add state for video recording view
    @State private var isHoveringVideoButton = false // Add state for video button hover
    @State private var currentVideoURL: URL? = nil // Add state for current video being viewed
    @State private var isPreparingVideoRecording = false
    @State private var preparedCameraManager: CameraManager? = nil
    @State private var videoRecordingPreparationID: UUID? = nil
    @State private var showingVideoPermissionPopover = false
    @State private var videoPermissionPopoverItems: [VideoPermissionPopoverItem] = []
    @State private var videoPermissionPopoverFallbackMessage: String? = nil
    @State private var isJournalUnlocked = true
    @State private var isHoveringSettings = false
    @State private var showingOllamaPanel = false
    @State private var showingAgentPanel = false
    @State private var showingGraph = false
    @State private var ollamaSourceText: String = ""
    @State private var ollamaRelatedHint = "This page only"
    @State private var ollamaCatalog: [JournalContext.Entry] = []
    @State private var ollamaCurrentFilename: String?
    @State private var ollamaPromptOverride: String? = nil
    @State private var ollamaChatEntryId: UUID? = nil
    @State private var sessionRecapMessage: String? = nil
    @State private var sessionStartedWordCount: Int = 0
    @State private var ollamaPanelEpoch: Int = 0
    @State private var ollamaFocusPassage: String = ""
    @State private var applyBefore: String?
    @StateObject private var ollamaService = OllamaService()
    @StateObject private var agentService = LocalAgentService()
    @StateObject private var roomTone = QuietRoomTone()
    @State private var unlockedPageIDs: Set<String> = []
    @StateObject private var editorDictation = VoiceDictationService()
    @StateObject private var voiceNoteRecorder = VoiceNoteRecorder()
    @State private var editorDictationBase: String = ""
    @State private var isHoveringDictate = false
    @State private var isHoveringVoiceNote = false
    @State private var recordingPulse = false
    @State private var sidebarSearchQuery: String = ""
    @State private var calendarMonth = Date()
    @State private var pinnedEntryIDs: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "pinnedEntryIDs") ?? [])
    @AppStorage(AppSettingsKeys.customChatGPTPrompt) private var customChatGPTPrompt: String = ""
    @AppStorage(AppSettingsKeys.customClaudePrompt) private var customClaudePrompt: String = ""
    @AppStorage(AppSettingsKeys.customOllamaPrompt) private var customOllamaPrompt: String = ""
    @AppStorage(AppSettingsKeys.claudeCodePath) private var claudeCodePath: String = ""
    @AppStorage(AppSettingsKeys.codexPath) private var codexPath: String = ""
    @AppStorage(AppSettingsKeys.ollamaEndpoint) private var ollamaEndpoint: String = AppSettingsDefaults.ollamaEndpoint
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let entryHeight: CGFloat = 40
    
    let availableFonts = NSFontManager.shared.availableFontFamilies
    let standardFonts = ["Lato-Regular", "Arial", ".AppleSystemUIFont", "Times New Roman"]
    let fontSizes: [CGFloat] = WritingPreferences.fontSizes.map { CGFloat($0) }

    private var fontSize: CGFloat {
        get { CGFloat(WritingPreferences.resolvedFontSize(storedFontSize)) }
        nonmutating set { storedFontSize = Double(newValue) }
    }
    // Add file manager and save timer
    private let fileManager = FileManager.default
    private let saveTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    @State private var documentsDirectory: URL = JournalFolder.defaultRoot()

    private var videosDirectory: URL {
        JournalFolder.videosURL(root: documentsDirectory)
    }

    private var chatsDirectory: URL {
        JournalFolder.chatsURL(root: documentsDirectory)
    }

    private func chatHistoryURL(for entry: HumanEntry) -> URL {
        let base = (entry.filename as NSString).deletingPathExtension
        return chatsDirectory.appendingPathComponent(base + ".json")
    }

    private func loadChatHistory(for entry: HumanEntry) -> [OllamaChatMessage]? {
        let url = chatHistoryURL(for: entry)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([OllamaChatMessage].self, from: data)
    }

    private func saveChatHistory(_ messages: [OllamaChatMessage], for entry: HumanEntry) {
        let url = chatHistoryURL(for: entry)
        guard let data = try? JSONEncoder().encode(messages) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func deleteChatHistory(for entry: HumanEntry) {
        let url = chatHistoryURL(for: entry)
        if fileManager.fileExists(atPath: url.path) {
            moveToTrash(url)
        }
    }

    // Prefers the macOS Trash over a permanent delete, so an accidental delete on a journal
    // (unlike most in-app actions, there's no in-app Undo for this one) can still be recovered
    // from Finder. Falls back to a real delete only if Trash itself is unavailable for this path.
    @discardableResult
    private func moveToTrash(_ url: URL) -> Bool {
        guard fileManager.fileExists(atPath: url.path) else { return true }
        do {
            try fileManager.trashItem(at: url, resultingItemURL: nil)
            return true
        } catch {
            print("Could not move \(url.lastPathComponent) to Trash (\(error)); deleting instead.")
            do {
                try fileManager.removeItem(at: url)
                return true
            } catch {
                print("Error deleting \(url.lastPathComponent): \(error)")
                return false
            }
        }
    }

    private let thumbnailMemoryCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 512
        return cache
    }()
    
    private var effectiveTonePrompt: String {
        PromptLibrary.effectiveTone(
            ollama: customOllamaPrompt,
            claude: customClaudePrompt,
            chatGPT: customChatGPTPrompt
        )
    }

    private var effectiveChatGPTPrompt: String { effectiveTonePrompt }
    private var effectiveClaudePrompt: String { effectiveTonePrompt }
    private var effectiveOllamaPrompt: String { effectiveTonePrompt }
    
    // Initialize with saved theme preference if available
    init() {
        // Load saved color scheme preference
        let savedScheme = UserDefaults.standard.string(forKey: "colorScheme") ?? "light"
        _colorScheme = State(initialValue: savedScheme == "dark" ? .dark : .light)
        let storedTimer = UserDefaults.standard.object(forKey: AppSettingsKeys.preferredTimerSeconds) as? Int
            ?? AppSettingsDefaults.timerSeconds
        _timeRemaining = State(initialValue: WritingPreferences.resolvedTimerSeconds(storedTimer))

        let bookmark = UserDefaults.standard.data(forKey: AppSettingsKeys.journalFolderBookmark)
        let root = JournalFolder.resolve(bookmarkData: bookmark)
        try? JournalFolder.ensureLayout(at: root)
        JournalFolder.beginAccess(to: root)
        _documentsDirectory = State(initialValue: root)

        let lockOn = UserDefaults.standard.bool(forKey: AppSettingsKeys.journalLockEnabled)
        let challenge = JournalLock.shouldChallenge(
            enabled: lockOn,
            alreadyUnlocked: false,
            canEvaluate: JournalLock.canEvaluate()
        )
        _isJournalUnlocked = State(initialValue: !challenge)
    }
    
    // Modify getDocumentsDirectory to use cached value
    private func getDocumentsDirectory() -> URL {
        return documentsDirectory
    }

    private func refreshJournalLocation() {
        let next = JournalFolder.resolve(
            bookmarkData: UserDefaults.standard.data(forKey: AppSettingsKeys.journalFolderBookmark)
        )
        guard next.standardizedFileURL.path != documentsDirectory.standardizedFileURL.path else {
            return
        }
        try? JournalFolder.ensureLayout(at: next)
        JournalFolder.beginAccess(to: next)
        documentsDirectory = next
        selectedEntryId = nil
        currentVideoURL = nil
        text = ""
        entries = []
        loadExistingEntries()
    }

    private func getVideosDirectory() -> URL {
        return videosDirectory
    }

    private func getVideoEntryDirectory(for videoFilename: String) -> URL {
        let baseName = (videoFilename as NSString).deletingPathExtension
        return getVideosDirectory().appendingPathComponent(baseName, isDirectory: true)
    }

    private func getManagedVideoURL(for filename: String) -> URL {
        getVideoEntryDirectory(for: filename).appendingPathComponent(filename)
    }

    private func getVideoThumbnailURL(for filename: String) -> URL {
        getVideoEntryDirectory(for: filename).appendingPathComponent("thumbnail.jpg")
    }

    private func getVideoTranscriptURL(for filename: String) -> URL {
        getVideoEntryDirectory(for: filename).appendingPathComponent("transcript.md")
    }

    @discardableResult
    private func ensureVideoEntryDirectoryExists(for videoFilename: String) throws -> URL {
        let directory = getVideoEntryDirectory(for: videoFilename)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func getVideoURL(for filename: String) -> URL {
        // Current production layout: Videos/[entry-base]/[entry-filename].mov
        let managedVideoURL = getManagedVideoURL(for: filename)
        if fileManager.fileExists(atPath: managedVideoURL.path) {
            return managedVideoURL
        }

        // Backward compatibility: older builds stored videos flat under Videos/
        let flatVideosURL = getVideosDirectory().appendingPathComponent(filename)
        if fileManager.fileExists(atPath: flatVideosURL.path) {
            return flatVideosURL
        }

        // Backward compatibility: oldest builds stored videos in root Freewrite folder
        let rootVideosURL = getDocumentsDirectory().appendingPathComponent(filename)
        if fileManager.fileExists(atPath: rootVideosURL.path) {
            return rootVideosURL
        }

        // Default to managed path for newly created entries.
        return managedVideoURL
    }

    private func hasVideoAsset(for filename: String) -> Bool {
        let managedVideoURL = getManagedVideoURL(for: filename)
        if fileManager.fileExists(atPath: managedVideoURL.path) {
            return true
        }

        let flatVideosURL = getVideosDirectory().appendingPathComponent(filename)
        if fileManager.fileExists(atPath: flatVideosURL.path) {
            return true
        }

        let rootVideosURL = getDocumentsDirectory().appendingPathComponent(filename)
        return fileManager.fileExists(atPath: rootVideosURL.path)
    }

    private let historyDebugEnabled = true

    private func historyDebug(_ message: String) {
        guard historyDebugEnabled else { return }
        print("[HistoryDebug] \(message)")
    }

    private func debugEntrySummary(_ entry: HumanEntry) -> String {
        let shortID = String(entry.id.uuidString.prefix(8))
        let type = entry.entryType == .video ? "video" : "text"
        let videoFilename = resolvedVideoFilename(for: entry) ?? "-"
        return "id=\(shortID) type=\(type) file=\(entry.filename) video=\(videoFilename)"
    }

    private func logEntriesOrder(_ reason: String, limit: Int = 20) {
        guard historyDebugEnabled else { return }
        historyDebug("ORDER SNAPSHOT (\(reason)) total=\(entries.count) selected=\(selectedEntryId?.uuidString ?? "nil")")
        for (index, entry) in entries.prefix(limit).enumerated() {
            historyDebug("#\(index + 1) \(debugEntrySummary(entry))")
        }
    }

    private func resolvedVideoFilename(for entry: HumanEntry) -> String? {
        guard entry.entryType == .video else {
            return nil
        }
        if let videoFilename = entry.videoFilename, !videoFilename.isEmpty {
            return videoFilename
        }
        return entry.filename.replacingOccurrences(of: ".md", with: ".mov")
    }

    private func persistThumbnail(_ image: NSImage, for videoFilename: String) {
        do {
            let directory = try ensureVideoEntryDirectoryExists(for: videoFilename)
            let thumbnailURL = directory.appendingPathComponent("thumbnail.jpg")
            guard let tiff = image.tiffRepresentation,
                  let bitmapRep = NSBitmapImageRep(data: tiff),
                  let imageData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.82]) else {
                print("Could not convert thumbnail image to JPEG data")
                return
            }
            try imageData.write(to: thumbnailURL, options: .atomic)
        } catch {
            print("Error saving thumbnail: \(error)")
        }
    }

    private func loadThumbnailImage(for videoFilename: String) -> NSImage? {
        let cacheKey = videoFilename as NSString
        if let cachedImage = thumbnailMemoryCache.object(forKey: cacheKey) {
            return cachedImage
        }

        let thumbnailURL = getVideoThumbnailURL(for: videoFilename)
        if fileManager.fileExists(atPath: thumbnailURL.path),
           let image = NSImage(contentsOf: thumbnailURL) {
            thumbnailMemoryCache.setObject(image, forKey: cacheKey)
            return image
        }

        // Backward compatibility: generate once for old video entries, then persist.
        let videoURL = getVideoURL(for: videoFilename)
        guard fileManager.fileExists(atPath: videoURL.path),
              let generated = generateVideoThumbnail(from: videoURL) else {
            historyDebug("THUMBNAIL MISS video=\(videoFilename) thumbnailPath=\(thumbnailURL.path) videoPath=\(videoURL.path)")
            return nil
        }
        persistThumbnail(generated, for: videoFilename)
        thumbnailMemoryCache.setObject(generated, forKey: cacheKey)
        historyDebug("THUMBNAIL GENERATED video=\(videoFilename) thumbnailPath=\(thumbnailURL.path)")
        return generated
    }

    private func deleteVideoAssets(for videoFilename: String) {
        thumbnailMemoryCache.removeObject(forKey: videoFilename as NSString)

        // Trash the whole managed directory as one unit (video + thumbnail + transcript together)
        // so restoring from Finder's Trash brings the entry back intact, not as scattered files.
        let managedDirectory = getVideoEntryDirectory(for: videoFilename)
        if fileManager.fileExists(atPath: managedDirectory.path) {
            moveToTrash(managedDirectory)
        }

        let flatVideosURL = getVideosDirectory().appendingPathComponent(videoFilename)
        let rootVideosURL = getDocumentsDirectory().appendingPathComponent(videoFilename)
        for url in [flatVideosURL, rootVideosURL] where fileManager.fileExists(atPath: url.path) {
            moveToTrash(url)
        }
    }

    private func loadTranscriptText(for videoFilename: String) -> String? {
        let transcriptURL = getVideoTranscriptURL(for: videoFilename)
        guard fileManager.fileExists(atPath: transcriptURL.path),
              let content = try? String(contentsOf: transcriptURL, encoding: .utf8) else {
            return nil
        }
        let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func previewTextFromTranscript(_ transcript: String?) -> String {
        guard let transcript else {
            return "Video Entry"
        }

        let normalized = transcript
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return "Video Entry"
        }

        var preview = String(normalized.prefix(10))

        while let last = preview.last, (!last.isLetter && !last.isNumber) {
            preview.removeLast()
        }

        if preview.isEmpty {
            return "Video Entry"
        }

        return preview + "..."
    }

    private func videoPreviewText(for videoFilename: String) -> String {
        previewTextFromTranscript(loadTranscriptText(for: videoFilename))
    }

    private func copyTranscriptForSelectedVideoEntry() {
        guard let selectedEntryId,
              let selectedEntry = entries.first(where: { $0.id == selectedEntryId }),
              let videoFilename = resolvedVideoFilename(for: selectedEntry),
              let transcript = loadTranscriptText(for: videoFilename) else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(transcript, forType: .string)
        didCopyTranscript = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            didCopyTranscript = false
        }
    }
    
    private func parseCanonicalEntryFilename(_ filename: String) -> (uuid: UUID, timestamp: Date)? {
        guard filename.hasPrefix("["),
              filename.hasSuffix("].md"),
              let divider = filename.range(of: "]-[") else {
            return nil
        }

        let uuidStart = filename.index(after: filename.startIndex)
        let uuidString = String(filename[uuidStart..<divider.lowerBound])
        guard let uuid = UUID(uuidString: uuidString) else {
            return nil
        }

        let timestampStart = divider.upperBound
        let timestampEnd = filename.index(filename.endIndex, offsetBy: -4) // before ".md"
        let timestampString = String(filename[timestampStart..<timestampEnd])
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        guard let timestamp = formatter.date(from: timestampString) else {
            return nil
        }

        return (uuid: uuid, timestamp: timestamp)
    }
    
    private func isEntryNewer(_ lhs: HumanEntry, than rhs: HumanEntry) -> Bool {
        let lhsTimestamp = parseCanonicalEntryFilename(lhs.filename)?.timestamp ?? .distantPast
        let rhsTimestamp = parseCanonicalEntryFilename(rhs.filename)?.timestamp ?? .distantPast
        if lhsTimestamp == rhsTimestamp {
            return lhs.filename > rhs.filename
        }
        return lhsTimestamp > rhsTimestamp
    }
    
    private func isEntryFromToday(_ entry: HumanEntry, calendar: Calendar = .current, today: Date = Date()) -> Bool {
        guard let timestamp = parseCanonicalEntryFilename(entry.filename)?.timestamp else {
            return false
        }
        return calendar.isDate(timestamp, inSameDayAs: today)
    }
    
    // Add function to save text
    private func saveText() {
        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent("entry.md")
        
        print("Attempting to save file to: \(fileURL.path)")
        
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Successfully saved file")
        } catch {
            print("Error saving file: \(error)")
            print("Error details: \(error.localizedDescription)")
        }
    }
    
    // Add function to load text
    private func loadText() {
        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent("entry.md")
        
        print("Attempting to load file from: \(fileURL.path)")
        
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                text = try String(contentsOf: fileURL, encoding: .utf8)
                print("Successfully loaded file")
            } else {
                print("File does not exist yet")
            }
        } catch {
            print("Error loading file: \(error)")
            print("Error details: \(error.localizedDescription)")
        }
    }
    
    // Add function to load existing entries
    private func loadExistingEntries() {
        let documentsDirectory = getDocumentsDirectory()
        print("Looking for entries in: \(documentsDirectory.path)")
        print("Looking for videos in: \(getVideosDirectory().path)")
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            let mdFiles = fileURLs.filter { $0.pathExtension == "md" }

            print("Found \(mdFiles.count) .md files")

            // Process each file
            let entriesWithDates = mdFiles.compactMap { fileURL -> (entry: HumanEntry, date: Date, content: String)? in
                let filename = fileURL.lastPathComponent
                print("Processing: \(filename)")

                // Only accept canonical entry filenames: [UUID]-[yyyy-MM-dd-HH-mm-ss].md
                guard let parsed = parseCanonicalEntryFilename(filename) else {
                    print("Skipping non-canonical entry filename: \(filename)")
                    return nil
                }
                let uuid = parsed.uuid
                let fileDate = parsed.timestamp

                // Check if there's a corresponding video file
                let videoFilename = filename.replacingOccurrences(of: ".md", with: ".mov")
                let hasVideo = hasVideoAsset(for: videoFilename)

                // Read file contents for preview
                do {
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    let preview = content
                        .replacingOccurrences(of: "\n", with: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let truncated = preview.isEmpty ? "" : (preview.count > 30 ? String(preview.prefix(30)) + "..." : preview)

                    // Format display date
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "MMM d"
                    let displayDate = dateFormatter.string(from: fileDate)

                    return (
                        entry: HumanEntry(
                            id: uuid,
                            date: displayDate,
                            filename: filename,
                            previewText: hasVideo ? videoPreviewText(for: videoFilename) : truncated,
                            entryType: hasVideo ? .video : .text,
                            videoFilename: hasVideo ? videoFilename : nil
                        ),
                        date: fileDate,
                        content: content  // Store the full content to check for welcome message
                    )
                } catch {
                    print("Error reading file: \(error)")
                    return nil
                }
            }
            
            // Sort and extract entries - store in temporary variable
            let loadedEntries = entriesWithDates
                .sorted {
                    if $0.date == $1.date {
                        return $0.entry.filename > $1.entry.filename
                    }
                    return $0.date > $1.date
                }
                .map { $0.entry }

            print("Successfully loaded and sorted \(loadedEntries.count) entries")

            // Check if we need to create a new entry
            let calendar = Calendar.current
            let today = Date()
            let hasEntryToday = loadedEntries.contains { isEntryFromToday($0, calendar: calendar, today: today) }
            let hasEmptyTextEntryToday = loadedEntries.contains {
                isEntryFromToday($0, calendar: calendar, today: today) &&
                $0.entryType == .text &&
                $0.previewText.isEmpty
            }

            // Check if we have only one entry and it's the welcome message
            let hasOnlyWelcomeEntry = loadedEntries.count == 1 && entriesWithDates.first?.content.contains("Welcome to Freewrite.") == true

            // Now assign to the state variable
            entries = loadedEntries
            logEntriesOrder("loadExistingEntries")

            // Never open directly into video on startup; create a fresh text entry instead.
            if let latestEntry = entries.first, latestEntry.entryType == .video {
                print("Latest entry is video, creating new text entry for startup")
                createNewEntry()
                return
            }

            if entries.isEmpty {
                // First time user - create entry with welcome message
                print("First time user, creating welcome entry")
                createNewEntry()
            } else if !hasEntryToday && !hasOnlyWelcomeEntry {
                // No entries at all for today - create a new text entry
                print("No entry for today, creating new entry")
                createNewEntry()
            } else {
                // Prefer an empty text entry from today for writing continuity; otherwise pick latest entry.
                if hasEmptyTextEntryToday,
                   let todayEntry = entries.first(where: {
                       isEntryFromToday($0, calendar: calendar, today: today) &&
                       $0.entryType == .text &&
                       $0.previewText.isEmpty
                   }) {
                    selectedEntryId = todayEntry.id
                    loadEntry(entry: todayEntry)
                } else if hasOnlyWelcomeEntry {
                    // If we only have the welcome entry, select it
                    selectedEntryId = entries[0].id
                    loadEntry(entry: entries[0])
                } else if let latestEntry = entries.first {
                    selectedEntryId = latestEntry.id
                    loadEntry(entry: latestEntry)
                }
            }
            
        } catch {
            print("Error loading directory contents: \(error)")
            print("Creating default entry after error")
            createNewEntry()
        }
    }
    
    var randomButtonTitle: String {
        return currentRandomFont.isEmpty ? "Random" : "Random [\(currentRandomFont)]"
    }

    private var pageText: Binding<String> {
        Binding(
            get: { MarkdownExtras.hidingImageLines(text) },
            set: { text = MarkdownExtras.restoringImageLines(visible: $0, stored: text) }
        )
    }

    var currentFontDisplayName: String {
        if !currentRandomFont.isEmpty { return currentRandomFont }
        return FavoriteFonts.displayName(for: selectedFont)
    }

    private func startVideoRecordingPreflight() {
        guard !isPreparingVideoRecording, !showingVideoRecording else {
            return
        }
        finishVoiceNoteIfRecording()

        showingVideoPermissionPopover = false
        videoPermissionPopoverItems = []
        videoPermissionPopoverFallbackMessage = nil

        let preparationID = UUID()
        let manager = CameraManager()

        videoRecordingPreparationID = preparationID
        preparedCameraManager = manager

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isPreparingVideoRecording = true
        }

        manager.onReadyToRecord = { [weak manager] in
            guard let manager else { return }
            DispatchQueue.main.async {
                finishVideoRecordingPreflight(
                    preparationID: preparationID,
                    manager: manager,
                    presentationDelay: 0.5
                )
            }
        }

        manager.onCannotRecord = { [weak manager] in
            guard let manager else { return }
            DispatchQueue.main.async {
                guard self.videoRecordingPreparationID == preparationID else {
                    return
                }
                let payload = self.videoPermissionPopoverPayload(
                    cameraGranted: manager.permissionGranted,
                    microphoneGranted: manager.microphonePermissionGranted,
                    speechGranted: manager.speechPermissionGranted
                )
                self.videoPermissionPopoverItems = payload.items
                self.videoPermissionPopoverFallbackMessage = payload.fallbackMessage
                self.showingVideoPermissionPopover = true
                self.clearVideoRecordingPreparationState()
            }
        }

        manager.checkPermissions()
    }

    private func finishVideoRecordingPreflight(
        preparationID: UUID,
        manager: CameraManager,
        presentationDelay: TimeInterval = 0
    ) {
        let presentRecorder = {
            guard videoRecordingPreparationID == preparationID else {
                return
            }

            videoRecordingPreparationID = nil
            manager.onReadyToRecord = nil
            manager.onCannotRecord = nil
            preparedCameraManager = manager

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isPreparingVideoRecording = false
                showingVideoRecording = true
            }
        }

        if presentationDelay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + presentationDelay) {
                presentRecorder()
            }
        } else {
            presentRecorder()
        }
    }

    private func clearVideoRecordingPreparationState() {
        preparedCameraManager?.onReadyToRecord = nil
        preparedCameraManager?.onCannotRecord = nil
        videoRecordingPreparationID = nil
        isPreparingVideoRecording = false
        preparedCameraManager = nil
    }

    private func videoPermissionPopoverPayload(
        cameraGranted: Bool,
        microphoneGranted: Bool,
        speechGranted: Bool
    ) -> (items: [VideoPermissionPopoverItem], fallbackMessage: String?) {
        var items: [VideoPermissionPopoverItem] = []
        if !cameraGranted {
            items.append(
                VideoPermissionPopoverItem(
                    message: "Hey, we need camera permission.",
                    buttonLabel: "Open Camera Settings",
                    settingsPane: "Privacy_Camera"
                )
            )
        }
        if !microphoneGranted {
            items.append(
                VideoPermissionPopoverItem(
                    message: "Hey, we need microphone permission.",
                    buttonLabel: "Open Microphone Settings",
                    settingsPane: "Privacy_Microphone"
                )
            )
        }
        if !speechGranted {
            items.append(
                VideoPermissionPopoverItem(
                    message: "Hey, we need speech recognition permission.",
                    buttonLabel: "Open Speech Settings",
                    settingsPane: "Privacy_SpeechRecognition"
                )
            )
        }

        if items.isEmpty {
            return (
                items: [],
                fallbackMessage: "Could not prepare camera right now. Please try again."
            )
        }

        return (
            items: items,
            fallbackMessage: nil
        )
    }

    private func openVideoPermissionSettings(_ settingsPane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(settingsPane)") {
            NSWorkspace.shared.open(url)
        }
    }

    var timerButtonTitle: String {
        if !timerIsRunning && timeRemaining == 900 {
            return "15:00"
        }
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var timerColor: Color {
        if timerIsRunning {
            return isHoveringTimer ? (colorScheme == .light ? .black : .white) : .gray.opacity(0.8)
        } else {
            return isHoveringTimer ? (colorScheme == .light ? .black : .white) : (colorScheme == .light ? .gray : .gray.opacity(0.8))
        }
    }
    
    var lineHeight: CGFloat {
        let font = NSFont(name: selectedFont, size: fontSize) ?? .systemFont(ofSize: fontSize)
        let defaultLineHeight = getLineHeight(font: font)
        return (fontSize * 1.5) - defaultLineHeight
    }
    
    var fontSizeButtonTitle: String {
        return "\(Int(fontSize))px"
    }
    
    // Add a color utility computed property
    var popoverBackgroundColor: Color {
        return colorScheme == .light ? Color(NSColor.controlBackgroundColor) : Color(NSColor.darkGray)
    }
    
    var popoverTextColor: Color {
        return colorScheme == .light ? Color.primary : Color.white
    }

    
    var body: some View {
        let navHeight: CGFloat = 68
        let textColor = colorScheme == .light ? Color.gray : Color.gray.opacity(0.8)
        let textHoverColor = colorScheme == .light ? Color.black : Color.white
        let isViewingVideoEntry = currentVideoURL != nil
        
        HStack(spacing: 0) {
            // Main content
                ZStack {
                Color(colorScheme == .light ? .white : .black)
                    .ignoresSafeArea()

                if let sessionRecapMessage {
                    VStack {
                        Text(sessionRecapMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(colorScheme == .light ? Color(red: 0.25, green: 0.25, blue: 0.25) : Color(red: 0.9, green: 0.9, blue: 0.9))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(colorScheme == .light ? Color.white : Color.black)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                            )
                            .padding(.top, 16)
                        Spacer()
                    }
                    .transition(.opacity)
                    .zIndex(5)
                }

                // Show video player if a video entry is selected
                if let videoURL = currentVideoURL {
                    VideoPlayerView(
                        videoURL: videoURL,
                        isPlaybackSuspended: isPreparingVideoRecording || showingVideoRecording
                    )
                        .id(videoURL.path)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea(edges: .top)
                } else {
                    // Show text editor for text entries
                    VStack(spacing: 0) {
                    if !currentImageRefs.isEmpty {
                        ImageStrip(
                            paths: currentImageRefs,
                            documentsDirectory: documentsDirectory,
                            onEdit: { annotatingImagePath = $0 }
                        )
                        .id(imageStripEpoch)
                    }
                    HStack(alignment: .top, spacing: 0) {
                    TextEditor(text: pageText)
                    .background(Color(colorScheme == .light ? .white : .black))
                    .font(.custom(selectedFont, size: fontSize))
                    .foregroundColor(colorScheme == .light ? Color(red: 0.20, green: 0.20, blue: 0.20) : Color(red: 0.9, green: 0.9, blue: 0.9))
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.never)
                    .lineSpacing(lineHeight)
                    .frame(minWidth: 420, maxWidth: 650)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 40)
                    .id("\(selectedFont)-\(fontSize)")
                    .colorScheme(colorScheme)
                    .onAppear {
                        placeholderText = WritingSpark.prompt(for: Date())
                        DispatchQueue.main.async { refreshEditorChrome() }
                        // Removed findSubview code which was causing errors

                        // Add keyboard monitor for backspace/delete keys
                        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                            // Check if backspace is disabled and the key is delete/backspace
                            if CompositionGuard.shouldBlockBackspace(
                                lockEnabled: backspaceDisabled,
                                keyCode: event.keyCode,
                                hasMarkedText: CompositionGuard.firstTextViewHasMarkedText()
                            ) {
                                return nil
                            }
                            if currentVideoURL == nil,
                               event.modifierFlags.contains(.command),
                               event.keyCode == 9,
                               ImageStore.shouldPreferClipboardImage(
                                hasImage: ImageStore.imageFromClipboard() != nil,
                                plainText: ImageStore.clipboardPlainText()
                               ) {
                                insertClipboardImage()
                                return nil
                            }
                            return event
                        }
                    }
                    if advancedAnnotations && (!currentAnnotations.isEmpty || !currentHighlights.isEmpty) {
                        AnnotationRail(
                            notes: currentAnnotations,
                            highlights: currentHighlights,
                            colorScheme: colorScheme
                        )
                    }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if let yesterdayLine = yesterdayContinueLine, currentVideoURL == nil {
                        Button(action: { text = JournalContinuity.starting(with: yesterdayLine) }) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Yesterday")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(yesterdayLine)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: 650, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .help("Start from yesterday's last sentence")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    if !currentTags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(currentTags, id: \.self) { tag in
                                Button(action: { sidebarSearchQuery = "#\(tag)"; showingSidebar = true }) {
                                    Text("#\(tag)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.08)))
                                }
                                .buttonStyle(.plain)
                                .help("Find other entries with this tag")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    if !currentVoiceRefs.isEmpty {
                        VoiceStrip(paths: currentVoiceRefs, documentsDirectory: documentsDirectory)
                    }
                    if advancedMermaid, !currentMermaidCharts.isEmpty {
                        MermaidStrip(charts: currentMermaidCharts)
                    }
                    }
                    .padding(.bottom, bottomNavOpacity > 0 ? navHeight : 0)
                }
                    
                
                VStack {
                    Spacer()
                    HStack {
                        if isViewingVideoEntry {
                            HStack(spacing: 8) {
                                if selectedVideoHasTranscript {
                                    Button(action: {
                                        copyTranscriptForSelectedVideoEntry()
                                    }) {
                                        Text(didCopyTranscript ? "Copied Transcript" : "Copy Transcript")
                                            .font(.system(size: 13))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(isHoveringCopyTranscript ? textHoverColor : textColor)
                                    .onHover { hovering in
                                        isHoveringCopyTranscript = hovering
                                        isHoveringBottomNav = hovering
                                        if hovering {
                                            NSCursor.pointingHand.push()
                                        } else {
                                            NSCursor.pop()
                                        }
                                    }
                                }
                            }
                            .padding(8)
                            .cornerRadius(6)
                            .onHover { hovering in
                                isHoveringBottomNav = hovering
                            }
                        } else {
                            // Font controls (left) — compact dropdowns instead of an inline button row
                            HStack(spacing: 8) {
                                Menu {
                                    ForEach(fontSizes, id: \.self) { size in
                                        Button(action: { fontSize = size }) {
                                            if fontSize == size {
                                                Label("\(Int(size))px", systemImage: "checkmark")
                                            } else {
                                                Text("\(Int(size))px")
                                            }
                                        }
                                    }
                                } label: {
                                    Text(fontSizeButtonTitle)
                                        .foregroundColor(textColor)
                                }
                                .menuStyle(.borderlessButton)
                                .fixedSize()
                                .onHover { hovering in
                                    isHoveringBottomNav = hovering
                                    if hovering {
                                        NSCursor.pointingHand.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                }

                                Text("•")
                                    .foregroundColor(.gray)

                                Menu {
                                    let favorites = FavoriteFonts.parse(favoriteFonts)
                                    if !favorites.isEmpty {
                                        ForEach(favorites, id: \.self) { font in
                                            Button("★ \(FavoriteFonts.displayName(for: font))") {
                                                selectedFont = font
                                                currentRandomFont = ""
                                            }
                                        }
                                        Divider()
                                    }
                                    Button("Lato") {
                                        selectedFont = "Lato-Regular"
                                        currentRandomFont = ""
                                    }
                                    Button("Arial") {
                                        selectedFont = "Arial"
                                        currentRandomFont = ""
                                    }
                                    Button("System") {
                                        selectedFont = ".AppleSystemUIFont"
                                        currentRandomFont = ""
                                    }
                                    Button("Serif") {
                                        selectedFont = "Times New Roman"
                                        currentRandomFont = ""
                                    }
                                    Button(randomButtonTitle) {
                                        if let randomFont = availableFonts.randomElement() {
                                            selectedFont = randomFont
                                            currentRandomFont = randomFont
                                        }
                                    }
                                    Divider()
                                    Button(favorites.contains(selectedFont) ? "Remove from favorites" : "Add to favorites") {
                                        favoriteFonts = FavoriteFonts.serialize(
                                            FavoriteFonts.toggling(selectedFont, in: favorites)
                                        )
                                    }
                                    Button(action: { typewriterMode.toggle() }) {
                                        if typewriterMode {
                                            Label("Typewriter", systemImage: "checkmark")
                                        } else {
                                            Text("Typewriter")
                                        }
                                    }
                                    Button(action: { sentenceFocus.toggle() }) {
                                        if sentenceFocus {
                                            Label("Focus this sentence", systemImage: "checkmark")
                                        } else {
                                            Text("Focus this sentence")
                                        }
                                    }
                                    Button(action: { softMarkdown.toggle() }) {
                                        if softMarkdown {
                                            Label("Soft markdown", systemImage: "checkmark")
                                        } else {
                                            Text("Soft markdown")
                                        }
                                    }
                                } label: {
                                    Text(currentFontDisplayName)
                                        .foregroundColor(textColor)
                                }
                                .menuStyle(.borderlessButton)
                                .fixedSize()
                                .onHover { hovering in
                                    isHoveringBottomNav = hovering
                                    if hovering {
                                        NSCursor.pointingHand.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                }
                            }
                            .padding(8)
                            .cornerRadius(6)
                            .onHover { hovering in
                                isHoveringBottomNav = hovering
                            }
                        }
                        
                        Spacer()
                        
                        // Utility buttons (moved to right)
                        HStack(spacing: 8) {
                            if !isViewingVideoEntry, let recordingIndicatorLabel {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 6, height: 6)
                                        .opacity(recordingPulse ? 1.0 : 0.35)
                                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: recordingPulse)
                                        .onAppear { recordingPulse = true }
                                        .onDisappear { recordingPulse = false }
                                    Text(recordingIndicatorLabel)
                                        .foregroundColor(.red)
                                }
                                .help("\(recordingIndicatorLabel)… click Stop in the ⋯ menu, or press ⌘⇧M / ⌘⇧A")

                                Text("•")
                                    .foregroundColor(.gray)
                            }

                            if !isViewingVideoEntry {
                                Text("\(currentWordCount) words")
                                    .foregroundColor(textColor)

                                Text("•")
                                    .foregroundColor(.gray)
                            }

                            Button(timerButtonTitle) {
                                let now = Date()
                                if let lastClick = lastClickTime,
                                   now.timeIntervalSince(lastClick) < 0.3 {
                                    resetTimerToDefault()
                                } else {
                                    toggleTimer()
                                    lastClickTime = now
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(timerColor)
                            .help("Start or pause timer. Double-click to reset to 15:00. ⌘⇧T")
                            .onHover { hovering in
                                isHoveringTimer = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            .onAppear {
                                NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                                    if isHoveringTimer {
                                        let scrollBuffer = event.deltaY * 0.25
                                        
                                        if abs(scrollBuffer) >= 0.1 {
                                            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                                            let direction = -scrollBuffer > 0 ? 5 : -5
                                            let newTime = WritingPreferences.steppedTimerSeconds(
                                                current: timeRemaining,
                                                directionMinutes: direction
                                            )
                                            timeRemaining = newTime
                                            preferredTimerSeconds = newTime
                                        }
                                    }
                                    return event
                                }
                            }

                            Text("•")
                                .foregroundColor(.gray)

                            // Video camera button
                            Button(action: {
                                guard !isPreparingVideoRecording else { return }
                                startVideoRecordingPreflight()
                            }) {
                                Group {
                                    if isPreparingVideoRecording {
                                        ProgressView()
                                            .controlSize(.small)
                                            .tint(isHoveringVideoButton ? textHoverColor : textColor)
                                    } else {
                                        Image(systemName: "video.fill")
                                            .foregroundColor(isHoveringVideoButton ? textHoverColor : textColor)
                                    }
                                }
                                .frame(width: 14, height: 14)
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                isHoveringVideoButton = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            .popover(
                                isPresented: $showingVideoPermissionPopover,
                                attachmentAnchor: .point(UnitPoint(x: 0.5, y: 0.0)),
                                arrowEdge: .top
                            ) {
                                VStack(spacing: 0) {
                                    if let fallbackMessage = videoPermissionPopoverFallbackMessage {
                                        Text(fallbackMessage)
                                            .font(.system(size: 14))
                                            .foregroundColor(popoverTextColor)
                                            .lineLimit(nil)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                }

                                    ForEach(videoPermissionPopoverItems) { item in
                                        if item.id != videoPermissionPopoverItems.first?.id || videoPermissionPopoverFallbackMessage != nil {
                                            Divider()
                                        }

                                        Button(action: {
                                            showingVideoPermissionPopover = false
                                            openVideoPermissionSettings(item.settingsPane)
                                        }) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(item.message)
                                                    .font(.system(size: 14))
                                                    .lineLimit(nil)
                                                    .multilineTextAlignment(.leading)
                                                    .fixedSize(horizontal: false, vertical: true)

                                                Text(item.buttonLabel)
                                                    .font(.system(size: 12))
                                                    .opacity(0.85)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }
                                    }
                                }
                                .frame(minWidth: 300, idealWidth: 320, maxWidth: 360)
                                .background(colorScheme == .light ? Color.white : Color.black)
                            }

                            Text("•")
                                .foregroundColor(.gray)

                            Button("Chat") {
                                showingChatMenu = true
                                // Ensure didCopyPrompt is reset when opening the menu
                                didCopyPrompt = false
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(isHoveringChat ? textHoverColor : textColor)
                            .onHover { hovering in
                                isHoveringChat = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            .popover(isPresented: $showingChatMenu, attachmentAnchor: .point(UnitPoint(x: 0.5, y: 0)), arrowEdge: .top) {
                                VStack(spacing: 0) { // Wrap everything in a VStack for consistent styling and onChange
                                    let isVideoEntry = currentVideoURL != nil
                                    let chatSourceText = currentChatSourceText()
                                    
                                    // Calculate potential URL lengths
                                    let gptFullText = effectiveChatGPTPrompt + "\n\n" + chatSourceText
                                    let claudeFullText = effectiveClaudePrompt + "\n\n" + chatSourceText
                                    let encodedGptText = ChatURL.encodeQuery(gptFullText)
                                    let encodedClaudeText = ChatURL.encodeQuery(claudeFullText)
                                    
                                    let gptUrlLength = "https://chat.openai.com/?m=".count + encodedGptText.count
                                    let claudeUrlLength = "https://claude.ai/new?q=".count + encodedClaudeText.count
                                    let isUrlTooLong = gptUrlLength > 6000 || claudeUrlLength > 6000
                                    
                                    if isUrlTooLong {
                                        // View for long text (URL too long)
                                        Text("Hey, your entry is quite long. You'll need to manually copy the prompt by clicking 'Copy Prompt' below and then paste it into AI of your choice (ex. ChatGPT). The prompt includes your entry as well. So just copy paste and go! See what the AI says.")
                                            .font(.system(size: 14))
                                            .foregroundColor(popoverTextColor)
                                            .lineLimit(nil)
                                            .multilineTextAlignment(.leading)
                                            .frame(width: 200, alignment: .leading)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                        
                                        Divider()
                                        
                                        Button(action: {
                                            copyPromptToClipboard()
                                            didCopyPrompt = true
                                        }) {
                                            Text(didCopyPrompt ? "Copied!" : "Copy Prompt")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }

                                        Divider()

                                        Button(action: {
                                            showingChatMenu = false
                                            startOllamaChat()
                                        }) {
                                            Text("Ollama (Offline)")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }

                                        Divider()

                                        Button(action: {
                                            showingChatMenu = false
                                            startWeeklyReview()
                                        }) {
                                            Text("Weekly Review")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }

                                    } else if !isVideoEntry && text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("hi. my name is farza.") {
                                        Text("Yo. Sorry, you can't chat with the guide lol. Please write your own entry.")
                                            .font(.system(size: 14))
                                            .foregroundColor(popoverTextColor)
                                            .frame(width: 250)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)

                                        Divider()

                                        Button(action: {
                                            showingChatMenu = false
                                            startWeeklyReview()
                                        }) {
                                            Text("Weekly Review")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                    } else if !isVideoEntry && text.count < 350 {
                                        Text("Please free write for at minimum 5 minutes first. Then click this. Trust.")
                                            .font(.system(size: 14))
                                            .foregroundColor(popoverTextColor)
                                            .frame(width: 250)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)

                                        Divider()

                                        Button(action: {
                                            showingChatMenu = false
                                            startWeeklyReview()
                                        }) {
                                            Text("Weekly Review")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                    } else {
                                        // View for normal text length
                                        Button(action: {
                                            showingChatMenu = false
                                            openChatGPT()
                                        }) {
                                            Text("ChatGPT")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }
                                        
                                        Divider()
                                        
                                        Button(action: {
                                            showingChatMenu = false
                                            openClaude()
                                        }) {
                                            Text("Claude")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }

                                        Divider()

                                        Button(action: {
                                            showingChatMenu = false
                                            openLocalAgent(.codex)
                                        }) {
                                            Text("Codex")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }

                                        Divider()

                                        Button(action: {
                                            showingChatMenu = false
                                            openLocalAgent(.claude)
                                        }) {
                                            Text("Claude Code")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }

                                        Divider()

                                        Button(action: {
                                            showingChatMenu = false
                                            startOllamaChat()
                                        }) {
                                            Text("Ollama (Offline)")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }

                                        Divider()

                                        Button(action: {
                                            showingChatMenu = false
                                            startWeeklyReview()
                                        }) {
                                            Text("Weekly Review")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }

                                        Divider()

                                        Button(action: {
                                            // Don't dismiss menu, just copy and update state
                                            copyPromptToClipboard()
                                            didCopyPrompt = true
                                        }) {
                                            Text(didCopyPrompt ? "Copied!" : "Copy Prompt")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(popoverTextColor)
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }
                                    }
                                }
                                .frame(minWidth: 120, maxWidth: 250) // Allow width to adjust
                                .background(popoverBackgroundColor)
                                .cornerRadius(8)
                                .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                                // Reset copied state when popover dismisses
                                .onChange(of: showingChatMenu) { _, newValue in
                                    if !newValue {
                                        didCopyPrompt = false
                                    }
                                }
                            }
                            
                            Text("•")
                                .foregroundColor(.gray)

                            Button(action: {
                                createNewEntry()
                            }) {
                                Text("New")
                                    .font(.system(size: 13))
                            }
                            .buttonStyle(.plain)
                            .keyboardShortcut("n", modifiers: .command)
                            .help("Create a new entry. ⌘N")
                            .foregroundColor(isHoveringNewEntry ? textHoverColor : textColor)
                            .onHover { hovering in
                                isHoveringNewEntry = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }

                            Text("•")
                                .foregroundColor(.gray)

                            Button(action: {
                                QuireAction.post(QuireAction.openSettings)
                            }) {
                                Image(systemName: "gearshape")
                                    .foregroundColor(isHoveringSettings ? textHoverColor : textColor)
                            }
                            .buttonStyle(.plain)
                            .keyboardShortcut(",", modifiers: .command)
                            .help("Open settings. ⌘,")
                            .onHover { hovering in
                                isHoveringSettings = hovering
                                isHoveringBottomNav = hovering
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }

                            Text("•")
                                .foregroundColor(.gray)

                            if !isViewingVideoEntry {
                                Button(action: {
                                    backspaceDisabled.toggle()
                                }) {
                                    Image(systemName: backspaceDisabled ? "delete.backward.fill" : "delete.backward")
                                        .foregroundColor(isHoveringBackspaceToggle ? textHoverColor : textColor)
                                }
                                .buttonStyle(.plain)
                                .keyboardShortcut("b", modifiers: [.command, .shift])
                                .help(backspaceDisabled ? "Backspace locked. ⌘⇧B" : "Lock backspace. ⌘⇧B")
                                .onHover { hovering in
                                    isHoveringBackspaceToggle = hovering
                                    isHoveringBottomNav = hovering
                                    if hovering {
                                        NSCursor.pointingHand.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                }
                            }

                            Menu {
                                Button("Settings…") { QuireAction.post(QuireAction.openSettings) }
                                Button("New Page") { createNewEntry() }
                                Button(showingSidebar ? "Hide History" : "History") { toggleHistorySidebar() }
                                Divider()
                                if !isViewingVideoEntry {
                                    Button(backspaceDisabled ? "Unlock Backspace" : "Lock Backspace") {
                                        backspaceDisabled.toggle()
                                    }
                                    Button(editorDictation.isRecording ? "Stop Dictation" : "Dictate") {
                                        toggleEditorDictation()
                                    }
                                    Button(voiceNoteRecorder.isRecording ? "Stop Voice Note" : "Voice Note") {
                                        toggleVoiceNote()
                                    }
                                    Button("Paste Image") { insertClipboardImage() }
                                    Button("Import Entry\u{2026}") { importEntry() }
                                    Button("Screenshot") { captureScreenshot() }
                                    Button(privacyHidden ? "Show Page" : "Hide Page") { togglePrivacy() }
                                    Button("Earlier Versions") { showingVersions = true }
                                    Button("Journal Stats") { presentStats() }
                                    Divider()
                                }
                                Button(isFullscreen ? "Exit Fullscreen" : "Fullscreen") { toggleFullscreen() }
                                Button(followSystemAppearance ? "Following the Mac" : (colorScheme == .light ? "Dark Mode" : "Light Mode")) {
                                    toggleTheme()
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .foregroundColor(textColor)
                            }
                            .menuStyle(.borderlessButton)
                            .help("New, settings, history, fullscreen, theme")
                            .onHover { hovering in
                                isHoveringBottomNav = hovering
                            }
                        }
                        .padding(8)
                        .cornerRadius(6)
                        .onHover { hovering in
                            isHoveringBottomNav = hovering
                        }
                    }
                    .padding()
                    .background(Color(colorScheme == .light ? .white : .black))
                    .opacity(bottomNavOpacity)
                    .onHover { hovering in
                        isHoveringBottomNav = hovering
                        refreshChromeVisibility()
                    }
                }
            }
            .onPasteCommand(of: [.png, .tiff, .image, .fileURL]) { _ in
                insertClipboardImage()
            }
            
            // Right sidebar
            if showingSidebar {
                Divider()
                
                VStack(spacing: 0) {
                    // Header
                    Button(action: {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: getDocumentsDirectory().path)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text("History")
                                        .font(.system(size: 13))
                                        .foregroundColor(isHoveringHistory ? textHoverColor : textColor)
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 10))
                                        .foregroundColor(isHoveringHistory ? textHoverColor : textColor)
                                }
                                Text(getDocumentsDirectory().path)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if dailyWordGoal > 0 {
                                Text(WritingGoal.label(current: todaysWordCount, goal: dailyWordGoal))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .help("Words written today toward your daily goal")
                            }
                            if writingStreak > 0 {
                                Text("🔥 \(writingStreak)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .help("\(writingStreak) day writing streak")
                            }
                            if advancedGraph {
                                Button(action: toggleGraph) {
                                    Image(systemName: "point.3.connected.trianglepath.dotted")
                                        .font(.system(size: 12))
                                        .foregroundColor(textColor)
                                }
                                .buttonStyle(.plain)
                                .help("Open the entry graph")
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .onHover { hovering in
                        isHoveringHistory = hovering
                    }

                    Divider()

                    // Search field
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        TextField("Search entries...", text: $sidebarSearchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                        if !sidebarSearchQuery.isEmpty {
                            Button(action: { sidebarSearchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    HistoryMonthGrid(
                        month: calendarMonth,
                        filenames: entries.map(\.filename),
                        selectedFilename: entries.first(where: { $0.id == selectedEntryId })?.filename,
                        onSelectFilename: { filename in
                            if let entry = entries.first(where: { $0.filename == filename }) {
                                selectEntry(entry)
                            }
                        },
                        onShiftMonth: { delta in
                            if let next = Calendar.current.date(byAdding: .month, value: delta, to: calendarMonth) {
                                calendarMonth = next
                            }
                        }
                    )

                    Divider()

                    if let memory = onThisDayHighlight {
                        Button(action: { selectEntry(memory) }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("On this day")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text(memory.previewText.isEmpty ? JournalInsights.displayDate(JournalInsights.parseTimestamp(from: memory.filename) ?? Date()) : memory.previewText)
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                if let timestamp = JournalInsights.parseTimestamp(from: memory.filename) {
                                    Text(JournalInsights.displayDate(timestamp))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .help("Open last year's entry from this day")

                        Divider()
                    }

                    Button(action: startWeeklyReview) {
                        HStack {
                            Text("Weekly Review")
                                .font(.system(size: 12))
                            Spacer()
                            Text("⌘⇧R")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(textColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .help("Ask Ollama about the last seven days")

                    Divider()

                    // Entries List
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredSidebarEntries) { entry in
                                Button(action: {
                                    if selectedEntryId != entry.id {
                                        historyDebug("ROW TAP \(debugEntrySummary(entry))")
                                        finishVoiceNoteIfRecording()
                                        // Save current entry before switching
                                        if let currentId = selectedEntryId,
                                           let currentEntry = entries.first(where: { $0.id == currentId }),
                                           currentEntry.entryType == .text {
                                            saveEntry(entry: currentEntry)
                                        }

                                        // Re-resolve from source of truth after any state mutations.
                                        guard let targetEntry = entries.first(where: { $0.id == entry.id }) else {
                                            historyDebug("ROW TAP target missing id=\(entry.id.uuidString)")
                                            return
                                        }
                                        selectedEntryId = targetEntry.id
                                        historyDebug("ROW TAP resolved target \(debugEntrySummary(targetEntry))")
                                        loadEntry(entry: targetEntry)
                                    }
                                }) {
                                    HStack(alignment: .top) {
                                        // Show video thumbnail for video entries
                                        if let videoFilename = resolvedVideoFilename(for: entry) {
                                            if let thumbnail = loadThumbnailImage(for: videoFilename) {
                                                Image(nsImage: thumbnail)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 40, height: 40)
                                                    .cornerRadius(4)
                                                    .overlay(
                                                        Image(systemName: "play.circle.fill")
                                                            .foregroundColor(.white)
                                                            .font(.system(size: 16))
                                                    )
                                            } else {
                                                // Fallback if thumbnail generation fails
                                                ZStack {
                                                    Rectangle()
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: 40, height: 40)
                                                        .cornerRadius(4)
                                                    Image(systemName: "video.fill")
                                                        .foregroundColor(.gray)
                                                        .font(.system(size: 16))
                                                }
                                            }
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(entry.previewText)
                                                    .font(.system(size: 13))
                                                    .lineLimit(1)
                                                    .foregroundColor(.primary)

                                                Button(action: { togglePin(entry) }) {
                                                    Image(systemName: isPinned(entry) ? "star.fill" : "star")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(isPinned(entry) ? .yellow : Color.gray.opacity(0.3))
                                                }
                                                .buttonStyle(.plain)
                                                .help(isPinned(entry) ? "Unpin entry" : "Pin entry")
                                                Button(action: { togglePageLock(entry) }) {
                                                    Image(systemName: isPageLocked(entry) ? "lock.fill" : "lock.open")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(isPageLocked(entry) ? .secondary : Color.gray.opacity(0.3))
                                                }
                                                .buttonStyle(.plain)
                                                .help(isPageLocked(entry) ? "Unlock this page" : "Lock this page")
                                                .onHover { hovering in
                                                    if hovering {
                                                        NSCursor.pointingHand.push()
                                                    } else {
                                                        NSCursor.pop()
                                                    }
                                                }

                                                Spacer()

                                                // Export/Trash icons that appear on hover
                                                if hoveredEntryId == entry.id {
                                                    HStack(spacing: 8) {
                                                        // Export menu (PDF / Markdown / Text)
                                                        Menu {
                                                            Button("Export as PDF") {
                                                                exportEntryAsPDF(entry: entry)
                                                            }
                                                            Button("Export as Markdown") {
                                                                exportEntryAsMarkdown(entry: entry)
                                                            }
                                                            Button("Export as Text") {
                                                                exportEntryAsText(entry: entry)
                                                            }
                                                        } label: {
                                                            Image(systemName: "arrow.down.circle")
                                                                .font(.system(size: 11))
                                                                .foregroundColor(hoveredExportId == entry.id ?
                                                                    (colorScheme == .light ? .black : .white) :
                                                                    (colorScheme == .light ? .gray : .gray.opacity(0.8)))
                                                        }
                                                        .menuStyle(.borderlessButton)
                                                        .fixedSize()
                                                        .help("Export entry")
                                                        .onHover { hovering in
                                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                                hoveredExportId = hovering ? entry.id : nil
                                                            }
                                                            if hovering {
                                                                NSCursor.pointingHand.push()
                                                            } else {
                                                                NSCursor.pop()
                                                            }
                                                        }
                                                        
                                                        // Trash icon
                                                        Button(action: {
                                                            pendingDelete = entry
                                                        }) {
                                                            Image(systemName: "trash")
                                                                .font(.system(size: 11))
                                                                .foregroundColor(hoveredTrashId == entry.id ? .red : .gray)
                                                        }
                                                        .buttonStyle(.plain)
                                                        .onHover { hovering in
                                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                                hoveredTrashId = hovering ? entry.id : nil
                                                            }
                                                            if hovering {
                                                                NSCursor.pointingHand.push()
                                                            } else {
                                                                NSCursor.pop()
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            Text(entry.date)
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(backgroundColor(for: entry))
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contentShape(Rectangle())
                                .onHover { hovering in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        hoveredEntryId = hovering ? entry.id : nil
                                    }
                                }
                                .onAppear {
                                    NSCursor.pop()  // Reset cursor when button appears
                                }
                                .help("Click to select this entry")  // Add tooltip
                                
                                if entry.id != filteredSidebarEntries.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .scrollIndicators(.never)
                }
                .frame(width: 280)
                .background(Color(colorScheme == .light ? .white : NSColor.black))
            }

            // Ollama offline-chat panel
            if showingOllamaPanel {
                Divider()

                OllamaPanelView(
                    service: ollamaService,
                    endpoint: ollamaEndpoint,
                    basePrompt: ollamaPromptOverride ?? effectiveOllamaPrompt,
                    sourceText: ollamaSourceText,
                    pageText: text,
                    relatedHint: ollamaRelatedHint,
                    journalCatalog: ollamaCatalog,
                    currentFilename: ollamaCurrentFilename,
                    colorScheme: colorScheme,
                    canInsert: !isViewingVideoEntry,
                    canUndo: JournalApply.restoring(applyBefore, ifDifferentFrom: text) != nil,
                    focusPassage: ollamaFocusPassage,
                    tagSuggestions: JournalTags.suggestions(
                        in: MarkdownExtras.visibleBody(text),
                        existing: JournalTags.tags(in: text),
                        limit: 3
                    ),
                    onAddTag: { tag in
                        text = JournalTags.adding(tag, to: text)
                    },
                    onApply: { mode, reply in
                        guard !reply.isEmpty else { return }
                        applyChatReply(reply, mode: mode)
                    },
                    onUndo: {
                        guard let restored = JournalApply.restoring(applyBefore, ifDifferentFrom: text) else { return }
                        text = restored
                        applyBefore = nil
                    },
                    onClose: {
                        ollamaService.cancel()
                        showingOllamaPanel = false
                    }
                )
                .id(ollamaPanelEpoch)
            }

            if showingAgentPanel {
                Divider()

                AgentPanelView(
                    service: agentService,
                    pageText: text,
                    colorScheme: colorScheme,
                    canInsert: !isViewingVideoEntry,
                    canUndo: JournalApply.restoring(applyBefore, ifDifferentFrom: text) != nil,
                    onRun: { job, extra in
                        runLocalAgent(job: job, extra: extra)
                    },
                    onApply: { mode, reply in
                        applyAgentReply(reply, mode: mode)
                    },
                    onUndo: {
                        guard let restored = JournalApply.restoring(applyBefore, ifDifferentFrom: text) else { return }
                        text = restored
                        applyBefore = nil
                    },
                    onClose: {
                        agentService.cancel()
                        showingAgentPanel = false
                    }
                )
            }

            if showingGraph && advancedGraph {
                Divider()
                EntryGraphPanel(
                    edges: currentGraphEdges,
                    entries: entries,
                    colorScheme: colorScheme,
                    onSelectFilename: { filename in
                        if let entry = entries.first(where: { $0.filename == filename }) {
                            selectEntry(entry)
                        }
                    },
                    onClose: { showingGraph = false }
                )
            }
        }
        .overlay {
            if showingVideoRecording {
                VideoRecordingView(
                    isPresented: $showingVideoRecording,
                    cameraManager: preparedCameraManager
                ) { videoURL, transcript in
                    // Save the video and create entry
                    saveVideoEntry(from: videoURL, transcript: transcript)
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        showingVideoRecording = false
                    }
                }
                .zIndex(10)
            }
        }
        .background(
            Group {
                Button("") {
                    if canOfferOllamaChat() {
                        startOllamaChat()
                    }
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("") { toggleTimer() }
                    .keyboardShortcut("t", modifiers: [.command, .shift])

                Button("") { startWeeklyReview() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("") { typewriterMode.toggle() }
                    .keyboardShortcut("y", modifiers: [.command, .shift])

                Button("") { togglePrivacy() }
                    .keyboardShortcut("p", modifiers: [.command, .shift])

                Button("") { beginFind() }
                    .keyboardShortcut("f", modifiers: .command)

                Button("") { advanceFind() }
                    .keyboardShortcut("g", modifiers: .command)

                Button("") { toggleGo() }
                    .keyboardShortcut("k", modifiers: .command)

                Button("") { sentenceFocus.toggle() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])

                Button("") { toggleFullscreen() }
                    .keyboardShortcut("f", modifiers: [.command, .control])

                Button("") { toggleTheme() }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
            }
            .hidden()
        )
        .frame(minWidth: 1100, minHeight: 600)
        .animation(.easeInOut(duration: 0.2), value: showingSidebar)
        .preferredColorScheme(followSystemAppearance ? nil : colorScheme)
        .confirmationDialog(
            "Delete this entry?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let pendingDelete {
                    deleteEntry(entry: pendingDelete)
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text("This removes the markdown (and any video) from disk.")
        }
        .onAppear {
            showingSidebar = false  // Hide sidebar by default
            selectedFont = WritingPreferences.resolvedFont(selectedFont)
            storedFontSize = WritingPreferences.resolvedFontSize(storedFontSize)
            preferredTimerSeconds = WritingPreferences.resolvedTimerSeconds(preferredTimerSeconds)
            if !timerIsRunning {
                timeRemaining = preferredTimerSeconds
            }
            if followSystemAppearance {
                colorScheme = systemColorScheme
            }
            if isJournalUnlocked {
                loadExistingEntries()
            }
            roomTone.setEnabled(roomToneEnabled)
        }
        .overlay {
            if !isJournalUnlocked {
                JournalLockGate(colorScheme: colorScheme) {
                    isJournalUnlocked = true
                    loadExistingEntries()
                }
            }
        }
        .overlay {
            if privacyHidden, isJournalUnlocked, !showingVideoRecording {
                PrivacyVeil { privacyHidden = false }
            }
        }
        .overlay(alignment: .top) {
            if showingFind, currentVideoURL == nil {
                FindBar(
                    query: $findQuery,
                    matchLabel: findMatchLabel,
                    onNext: advanceFind,
                    onClose: { showingFind = false; findQuery = ""; findIndex = nil }
                )
            }
        }
        .overlay {
            if showingSettings {
                ZStack {
                    Color.black.opacity(colorScheme == .light ? 0.16 : 0.5)
                        .ignoresSafeArea()
                        .onTapGesture { showingSettings = false }
                    SettingsView(onClose: { showingSettings = false })
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(0.28), radius: 28, y: 12)
                }
            }
        }
        .overlay {
            if showingVersions {
                ZStack {
                    Color.black.opacity(0.12)
                        .ignoresSafeArea()
                        .onTapGesture { showingVersions = false }
                    VStack {
                        VersionsPanelView(
                            items: currentVersionItems,
                            onRestore: restoreVersion,
                            onClose: { showingVersions = false }
                        )
                        .padding(.top, 72)
                        Spacer()
                    }
                }
            }
        }
        .overlay {
            if showingStats {
                ZStack {
                    Color.black.opacity(0.12)
                        .ignoresSafeArea()
                        .onTapGesture { showingStats = false }
                    VStack {
                        StatsPanelView(
                            summary: journalStatsSummary,
                            onClose: { showingStats = false }
                        )
                        .padding(.top, 72)
                        Spacer()
                    }
                }
            }
        }
        .overlay {
            if showingGo {
                ZStack {
                    Color.black.opacity(0.12)
                        .ignoresSafeArea()
                        .onTapGesture { closeGo() }
                    VStack {
                        GoPaletteView(
                            query: $goQuery,
                            items: goItems,
                            onPick: performGo,
                            onClose: closeGo
                        )
                        .padding(.top, 72)
                        Spacer()
                    }
                }
            }
        }
        .overlay {
            if let annotatingImagePath,
               let image = NSImage(contentsOf: documentsDirectory.appendingPathComponent(annotatingImagePath)) {
                ImageAnnotatorCanvas(
                    image: image,
                    colorScheme: colorScheme,
                    onSave: { annotated in
                        do {
                            try ImageStore.replacePNG(
                                annotated,
                                documentsDirectory: documentsDirectory,
                                relativePath: annotatingImagePath
                            )
                            imageStripEpoch += 1
                        } catch {
                            showTransientMessage("Could not save drawing")
                        }
                        self.annotatingImagePath = nil
                    },
                    onCancel: { self.annotatingImagePath = nil }
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: QuireAction.openSettings)) { _ in
            showingSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: QuireAction.settingsClosed)) { _ in
            refreshJournalLocation()
        }
        .onReceive(NotificationCenter.default.publisher(for: QuireAction.newPage)) { _ in
            createNewEntry()
        }
        .onReceive(NotificationCenter.default.publisher(for: QuireAction.toggleHistory)) { _ in
            toggleHistorySidebar()
        }
        .onReceive(NotificationCenter.default.publisher(for: QuireAction.toggleChat)) { _ in
            toggleChatFromMenu()
        }
        .onReceive(NotificationCenter.default.publisher(for: QuireAction.exportPDF)) { _ in
            exportSelectedAsPDF()
        }
        .onReceive(NotificationCenter.default.publisher(for: QuireAction.exportJournal)) { _ in
            exportJournalZip()
        }
        .onReceive(NotificationCenter.default.publisher(for: QuireAction.go)) { _ in
            toggleGo()
        }
        .onReceive(NotificationCenter.default.publisher(for: QuireAction.toggleSentenceFocus)) { _ in
            sentenceFocus.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: QuireAction.showVersions)) { _ in
            showingVersions = true
        }
        .onChange(of: showingVideoRecording) { _, isShowing in
            if !isShowing {
                clearVideoRecordingPreparationState()
            }
        }
        .onChange(of: ollamaService.isStreaming) { _, isStreaming in
            // Persist once a turn finishes streaming, rather than on every token.
            guard !isStreaming,
                  let ollamaChatEntryId,
                  let entry = entries.first(where: { $0.id == ollamaChatEntryId }) else {
                return
            }
            saveChatHistory(ollamaService.messages, for: entry)
        }
        .onReceive(saveTimer) { _ in
            refreshChromeVisibility()
            guard SaveDebounce.shouldFlush(dirty: textNeedsSave) else { return }
            if let currentId = selectedEntryId,
               let currentEntry = entries.first(where: { $0.id == currentId }),
               currentEntry.entryType == .text {
                saveEntry(entry: currentEntry)
            }
            textNeedsSave = false
        }
        .onChange(of: text) { oldValue, newValue in
            lastActivityAt = Date()
            textNeedsSave = true
            adoptBareImagePathsIfNeeded()
            if typewriterMode, currentVideoURL == nil {
                TypewriterScroll.centerCaretInKeyWindow()
            }
            if QuietSounds.shouldTick(enabled: typewriterSound, before: oldValue, after: newValue) {
                QuietSounds.tick()
            }
            refreshEditorChrome()
        }
        .onChange(of: findQuery) { _, _ in
            findIndex = nil
            advanceFind()
        }
        .onChange(of: systemColorScheme) { _, newValue in
            if followSystemAppearance {
                colorScheme = newValue
            }
        }
        .onChange(of: typewriterMode) { _, _ in
            refreshEditorChrome()
        }
        .onChange(of: sentenceFocus) { _, _ in
            refreshEditorChrome()
        }
        .onChange(of: softMarkdown) { _, _ in
            refreshEditorChrome()
        }
        .onChange(of: colorScheme) { _, _ in
            refreshEditorChrome()
        }
        .onChange(of: selectedFont) { _, _ in
            DispatchQueue.main.async { refreshEditorChrome() }
        }
        .onChange(of: storedFontSize) { _, _ in
            DispatchQueue.main.async { refreshEditorChrome() }
        }
        .onChange(of: roomToneEnabled) { _, enabled in
            roomTone.setEnabled(enabled)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSTextView.didChangeSelectionNotification)) { _ in
            refreshEditorChrome()
        }
        .onChange(of: editorDictation.transcript) { _, newValue in
            guard editorDictation.isRecording, currentVideoURL == nil else { return }
            text = EditorDictation.combining(base: editorDictationBase, transcript: newValue)
        }
        .onChange(of: currentVideoURL) { _, videoURL in
            if videoURL != nil {
                finishVoiceNoteIfRecording()
            }
        }
        .onChange(of: showingOllamaPanel) { _, showing in
            if showing {
                finishVoiceNoteIfRecording()
            }
        }
        .onReceive(timer) { _ in
            if timerIsRunning && timeRemaining > 0 {
                timeRemaining -= 1
            } else if timeRemaining == 0 {
                let finishedSession = timerIsRunning
                timerIsRunning = false
                timeRemaining = preferredTimerSeconds
                if finishedSession {
                    presentSessionRecap()
                }
                if !isHoveringBottomNav {
                    withAnimation(.easeOut(duration: 1.0)) {
                        bottomNavOpacity = 1.0
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { _ in
            isFullscreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { _ in
            isFullscreen = false
        }
    }
    
    private var filteredSidebarEntries: [HumanEntry] {
        let query = sidebarSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = query.isEmpty ? entries : entries.filter { matchesSearch($0, query: query) }
        // Stable sort: pinned entries bubble to the top, preserving date-desc order within each group.
        return base.sorted { isPinned($0) && !isPinned($1) }
    }

    private func isPinned(_ entry: HumanEntry) -> Bool {
        pinnedEntryIDs.contains(entry.id.uuidString)
    }

    private func togglePin(_ entry: HumanEntry) {
        let key = entry.id.uuidString
        if pinnedEntryIDs.contains(key) {
            pinnedEntryIDs.remove(key)
        } else {
            pinnedEntryIDs.insert(key)
        }
        UserDefaults.standard.set(Array(pinnedEntryIDs), forKey: "pinnedEntryIDs")
    }

    private func matchesSearch(_ entry: HumanEntry, query: String) -> Bool {
        let lowercasedQuery = query.lowercased()
        if entry.previewText.lowercased().contains(lowercasedQuery) { return true }
        if entry.date.lowercased().contains(lowercasedQuery) { return true }

        if let videoFilename = resolvedVideoFilename(for: entry) {
            guard let transcript = loadTranscriptText(for: videoFilename) else { return false }
            return transcript.lowercased().contains(lowercasedQuery)
        }

        let fileURL = getDocumentsDirectory().appendingPathComponent(entry.filename)
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return false }
        return content.lowercased().contains(lowercasedQuery)
    }

    private var currentWordCount: Int {
        MarkdownExtras.wordCount(text)
    }

    // Dictate and Voice Note both live only in the ⋯ menu, which closes the moment you pick one —
    // without this, starting either leaves no sign anywhere that a mic is live. Voice Note also
    // turns dictation on underneath it (see toggleVoiceNote), so it takes label priority.
    private var recordingIndicatorLabel: String? {
        if voiceNoteRecorder.isRecording { return "Recording voice note" }
        if editorDictation.isRecording { return "Dictating" }
        return nil
    }

    private var writingStreak: Int {
        let calendar = Calendar.current
        let entryDays = Set(entries.compactMap { entry -> Date? in
            guard let timestamp = parseCanonicalEntryFilename(entry.filename)?.timestamp else { return nil }
            return calendar.startOfDay(for: timestamp)
        })
        guard !entryDays.isEmpty else { return 0 }

        var streak = 0
        var cursor = calendar.startOfDay(for: Date())
        if !entryDays.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        while entryDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }
        return streak
    }

    private func backgroundColor(for entry: HumanEntry) -> Color {
        if entry.id == selectedEntryId {
            return Color.gray.opacity(0.1)  // More subtle selection highlight
        } else if entry.id == hoveredEntryId {
            return Color.gray.opacity(0.05)  // Even more subtle hover state
        } else {
            return Color.clear
        }
    }
    
    private func updatePreviewText(for entry: HumanEntry) {
        if entry.entryType == .video {
            if let index = entries.firstIndex(where: { $0.id == entry.id }),
               let videoFilename = resolvedVideoFilename(for: entry) {
                entries[index].previewText = videoPreviewText(for: videoFilename)
            }
            return
        }

        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let preview = content
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let truncated = preview.isEmpty ? "" : (preview.count > 30 ? String(preview.prefix(30)) + "..." : preview)
            
            // Find and update the entry in the entries array
            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                entries[index].previewText = truncated
            }
        } catch {
            print("Error updating preview text: \(error)")
        }
    }
    
    private func saveEntry(entry: HumanEntry) {
        guard entry.entryType == .text else {
            return
        }

        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Successfully saved entry: \(entry.filename)")
            updatePreviewText(for: entry)  // Update preview after saving
        } catch {
            print("Error saving entry: \(error)")
        }
    }
    
    private func loadEntry(entry: HumanEntry) {
        if let videoFilename = resolvedVideoFilename(for: entry) {
            // Load video entry
            let videoURL = getVideoURL(for: videoFilename)
            let thumbnailURL = getVideoThumbnailURL(for: videoFilename)
            let transcriptURL = getVideoTranscriptURL(for: videoFilename)
            historyDebug("LOAD VIDEO \(debugEntrySummary(entry)) resolvedVideoPath=\(videoURL.path) videoExists=\(fileManager.fileExists(atPath: videoURL.path)) thumbnailPath=\(thumbnailURL.path) thumbnailExists=\(fileManager.fileExists(atPath: thumbnailURL.path))")
            text = ""
            didCopyTranscript = false
            selectedVideoHasTranscript = fileManager.fileExists(atPath: transcriptURL.path)
            if fileManager.fileExists(atPath: videoURL.path) {
                currentVideoURL = videoURL
                print("Successfully loaded video entry: \(videoFilename)")
            } else {
                print("Video file missing for entry: \(videoFilename)")
            }
        } else {
            // Load text entry
            historyDebug("LOAD TEXT \(debugEntrySummary(entry))")
            currentVideoURL = nil
            selectedVideoHasTranscript = false
            didCopyTranscript = false
            let documentsDirectory = getDocumentsDirectory()
            let fileURL = documentsDirectory.appendingPathComponent(entry.filename)

            do {
                if fileManager.fileExists(atPath: fileURL.path) {
                    let rawText = try String(contentsOf: fileURL, encoding: .utf8)
                    // Strip legacy leading newlines from older entries
                    text = MarkdownExtras.scrubbingPage(String(rawText.drop(while: { $0 == "\n" })))
                    adoptBareImagePathsIfNeeded()
                    text = MarkdownExtras.scrubbingPage(text)
                    print("Successfully loaded entry: \(entry.filename)")
                }
            } catch {
                print("Error loading entry: \(error)")
            }
        }
    }
    
    private func toggleTimer() {
        if !timerIsRunning, timeRemaining == preferredTimerSeconds {
            sessionStartedWordCount = currentWordCount
        }
        timerIsRunning.toggle()
    }

    private func resetTimerToDefault() {
        timeRemaining = AppSettingsDefaults.timerSeconds
        preferredTimerSeconds = AppSettingsDefaults.timerSeconds
        timerIsRunning = false
        lastClickTime = nil
    }

    private func toggleTheme() {
        followSystemAppearance = false
        colorScheme = colorScheme == .light ? .dark : .light
        UserDefaults.standard.set(colorScheme == .light ? "light" : "dark", forKey: "colorScheme")
    }

    private func togglePrivacy() {
        privacyHidden.toggle()
    }

    private func refreshChromeVisibility() {
        let visible = IdleFade.chromeVisible(
            idleFadeEnabled: idleFadeEnabled,
            idleFor: Date().timeIntervalSince(lastActivityAt),
            timerRunning: timerIsRunning,
            hovering: isHoveringBottomNav,
            forceVisible: showingSidebar || showingFind || showingGo || showingVersions || showingStats || showingSettings || showingOllamaPanel || showingAgentPanel || showingVideoRecording || privacyHidden
        )
        let target: Double = visible ? 1.0 : 0.0
        guard bottomNavOpacity != target else { return }
        withAnimation(.easeInOut(duration: visible ? 0.2 : 1.0)) {
            bottomNavOpacity = target
        }
    }

    private func beginFind() {
        guard currentVideoURL == nil else { return }
        showingFind = true
    }

    private var goItems: [CommandGo.Item] {
        let commands = CommandGo.commands(matching: goQuery)
        let needle = goQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return commands }
        let pages = entries.filter { matchesSearch($0, query: needle) }.prefix(8).map { entry in
            let title = entry.previewText.trimmingCharacters(in: .whitespacesAndNewlines)
            return CommandGo.pageItem(
                id: entry.filename,
                title: title.isEmpty ? entry.date : title,
                hint: entry.date
            )
        }
        return commands + pages
    }

    private func toggleGo() {
        if showingGo {
            closeGo()
        } else {
            goQuery = ""
            showingGo = true
        }
    }

    private func closeGo() {
        showingGo = false
        goQuery = ""
    }

    private func performGo(_ item: CommandGo.Item) {
        closeGo()
        if item.kind == .page {
            if let entry = entries.first(where: { $0.filename == item.id }) {
                selectEntry(entry)
            }
            return
        }
        switch item.id {
        case "new":
            createNewEntry()
        case "history":
            toggleHistorySidebar()
        case "find":
            beginFind()
        case "chat":
            toggleChatFromMenu()
        case "claude-code":
            openLocalAgent(.claude)
        case "codex":
            openLocalAgent(.codex)
        case "weekly":
            startWeeklyReview()
        case "focus":
            sentenceFocus.toggle()
        case "typewriter":
            typewriterMode.toggle()
        case "privacy":
            togglePrivacy()
        case "random":
            openRandomPage()
        case "versions":
            showingVersions = true
        case "stats":
            presentStats()
        case "export":
            exportSelectedAsPDF()
        case "export-journal":
            exportJournalZip()
        case "import":
            importEntry()
        case "settings":
            QuireAction.post(QuireAction.openSettings)
        default:
            break
        }
    }

    private func openRandomPage() {
        let pool = entries.filter { $0.id != selectedEntryId }
        guard let entry = pool.randomElement() else {
            showTransientMessage("Only one page so far")
            return
        }
        selectEntry(entry)
    }

    private func presentStats() {
        journalStatsSummary = computeJournalStats()
        showingStats = true
    }

    // Reads every entry once, so this is only called when the Stats panel opens, not on every
    // render — fine at personal-journal scale, same "just read the file" tradeoff as sidebar search.
    private func computeJournalStats() -> JournalStats.Summary {
        let documentsDirectory = getDocumentsDirectory()
        var facts: [JournalStats.EntryFacts] = []
        var streakDays: [Date] = []

        for entry in entries {
            guard let timestamp = parseCanonicalEntryFilename(entry.filename)?.timestamp else { continue }
            streakDays.append(timestamp)

            let content: String
            if entry.entryType == .video {
                content = resolvedVideoFilename(for: entry).flatMap(loadTranscriptText) ?? ""
            } else {
                let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
                content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
            }

            guard !JournalInsights.isGuideOrEmpty(content) else { continue }
            facts.append(JournalStats.EntryFacts(
                words: MarkdownExtras.wordCount(MarkdownExtras.visibleBody(content)),
                tags: JournalTags.tags(in: content)
            ))
        }

        return JournalStats.summarize(facts, streakDays: streakDays)
    }

    private func refreshEditorChrome() {
        guard currentVideoURL == nil else { return }
        let primary = colorScheme == .light
            ? NSColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1)
            : NSColor(red: 0.90, green: 0.90, blue: 0.90, alpha: 1)
        let placeholderColor = colorScheme == .light
            ? NSColor.gray.withAlphaComponent(0.45)
            : NSColor.gray.withAlphaComponent(0.55)
        EditorPlaceholder.apply(
            placeholderText,
            fontName: selectedFont,
            size: fontSize,
            color: placeholderColor
        )
        SentenceFocus.apply(enabled: sentenceFocus, primary: primary, dim: primary.withAlphaComponent(0.28))
        SoftMarkdown.apply(enabled: softMarkdown, dim: primary.withAlphaComponent(0.35))
        if let textView = CompositionGuard.firstTextView() {
            TypewriterScroll.apply(to: textView, enabled: typewriterMode)
        }
    }

    private var findRanges: [NSRange] {
        PageFind.ranges(in: MarkdownExtras.visibleBody(text), query: findQuery)
    }

    private var findMatchLabel: String {
        let ranges = findRanges
        guard !findQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        if ranges.isEmpty { return "0 matches" }
        let current = (findIndex ?? 0) + 1
        return "\(current) of \(ranges.count)"
    }

    private func advanceFind() {
        let ranges = findRanges
        findIndex = PageFind.nextIndex(after: findIndex, count: ranges.count)
        if let findIndex {
            PageFind.select(ranges[findIndex])
        }
    }

    private func toggleHistorySidebar() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if !showingSidebar {
                showingOllamaPanel = false
                showingAgentPanel = false
                agentService.cancel()
                showingGraph = false
            }
            showingSidebar.toggle()
        }
    }

    private func toggleFullscreen() {
        if let window = NSApplication.shared.windows.first {
            window.toggleFullScreen(nil)
        }
    }

    private func toggleEditorDictation() {
        guard currentVideoURL == nil else { return }
        if editorDictation.isRecording || voiceNoteRecorder.isRecording {
            finishVoiceNoteIfRecording()
        } else {
            editorDictationBase = text
            editorDictation.start()
        }
    }

    private func stopEditorDictation() {
        guard editorDictation.isRecording else { return }
        editorDictation.stop()
    }

    private func toggleVoiceNote() {
        guard currentVideoURL == nil else { return }
        if voiceNoteRecorder.isRecording {
            finishVoiceNoteIfRecording()
            return
        }
        if !editorDictation.isRecording {
            editorDictationBase = text
            editorDictation.start()
        }
        voiceNoteRecorder.start()
        if let message = voiceNoteRecorder.errorMessage {
            showTransientMessage(message)
        }
    }

    private func finishVoiceNoteIfRecording() {
        let audioURL = voiceNoteRecorder.isRecording ? voiceNoteRecorder.stop() : nil
        stopEditorDictation()
        guard let audioURL,
              let entry = entries.first(where: { $0.id == selectedEntryId }) else {
            return
        }
        let relative = VoiceNote.relativePath(entryFilename: entry.filename, recordedAt: Date())
        do {
            try VoiceNoteStore.moveRecording(
                from: audioURL,
                documentsDirectory: documentsDirectory,
                relativePath: relative
            )
            text = VoiceNote.attach(to: text, relativePath: relative)
            saveEntry(entry: entry)
        } catch {
            showTransientMessage("Could not save voice note")
        }
    }

    private var currentAnnotations: [String] {
        MarkdownExtras.annotations(in: text)
    }

    private var currentHighlights: [String] {
        MarkdownExtras.highlights(in: text)
    }

    private var currentImageRefs: [String] {
        MarkdownExtras.readableImageRefs(in: text, documentsDirectory: documentsDirectory)
    }

    private var currentVoiceRefs: [String] {
        VoiceNote.refs(in: text)
    }

    private var currentTags: [String] {
        JournalTags.tags(in: text)
    }

    private var currentMermaidCharts: [MermaidFlow.Chart] {
        MarkdownExtras.mermaidSources(in: text).map(MermaidFlow.parse)
    }

    private var todaysWordCount: Int {
        let calendar = Calendar.current
        return entries.reduce(0) { total, entry in
            guard let timestamp = JournalInsights.parseTimestamp(from: entry.filename),
                  calendar.isDateInToday(timestamp) else {
                return total
            }
            if entry.id == selectedEntryId {
                return total + currentWordCount
            }
            if let video = resolvedVideoFilename(for: entry),
               let transcript = loadTranscriptText(for: video) {
                return total + transcript.split { $0.isWhitespace || $0.isNewline }.count
            }
            let url = documentsDirectory.appendingPathComponent(entry.filename)
            let body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            return total + body.split { $0.isWhitespace || $0.isNewline }.count
        }
    }

    private var currentGraphEdges: [MarkdownExtras.GraphEdge] {
        let payload = entries.map { entry -> (filename: String, text: String, preview: String, date: String) in
            let body: String
            if let video = resolvedVideoFilename(for: entry),
               let transcript = loadTranscriptText(for: video) {
                body = transcript
            } else {
                let url = documentsDirectory.appendingPathComponent(entry.filename)
                body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            }
            return (filename: entry.filename, text: body, preview: entry.previewText, date: entry.date)
        }
        return MarkdownExtras.graphEdges(entries: payload)
    }

    private func toggleGraph() {
        showingGraph.toggle()
        if showingGraph {
            showingSidebar = false
            showingOllamaPanel = false
            showingAgentPanel = false
            agentService.cancel()
        }
    }

    private func insertClipboardImage() {
        guard currentVideoURL == nil else { return }
        guard let image = ImageStore.imageFromClipboard() else {
            showTransientMessage("Copy an image first, then paste")
            return
        }
        insertImage(image, alt: "image")
    }

    private func adoptBareImagePathsIfNeeded() {
        guard currentVideoURL == nil else { return }
        guard let entry = entries.first(where: { $0.id == selectedEntryId }) else { return }
        let next = ImageStore.replacingBareImagePaths(in: text) { path in
            guard let image = ImageStore.image(fromFilePath: path) else { return nil }
            return try? ImageStore.savePNG(
                image,
                documentsDirectory: documentsDirectory,
                entryFilename: entry.filename
            )
        }
        if next != text {
            text = MarkdownExtras.scrubbingPage(next)
        }
    }

    private func captureScreenshot() {
        guard advancedImages, currentVideoURL == nil else { return }
        guard ImageStore.captureInteractiveToClipboard() else {
            showTransientMessage("Screenshot cancelled")
            return
        }
        guard let image = ImageStore.imageFromClipboard() else {
            showTransientMessage("No screenshot captured")
            return
        }
        insertImage(image, alt: "screenshot")
    }

    private func insertImage(_ image: NSImage, alt: String) {
        guard let entry = entries.first(where: { $0.id == selectedEntryId }) else { return }
        do {
            let relative = try ImageStore.savePNG(image, documentsDirectory: documentsDirectory, entryFilename: entry.filename)
            text = MarkdownExtras.insertImage(into: text, relativePath: relative, alt: alt)
        } catch {
            showTransientMessage("Could not save image")
        }
    }

    private func createNewEntry() {
        finishVoiceNoteIfRecording()
        flushSaveIfNeeded()
        let newEntry = HumanEntry.createNew()
        entries.insert(newEntry, at: 0) // Add to the beginning
        selectedEntryId = newEntry.id
        applyBefore = nil
        currentVideoURL = nil
        selectedVideoHasTranscript = false
        didCopyTranscript = false
        historyDebug("NEW ENTRY created \(debugEntrySummary(newEntry))")
        logEntriesOrder("createNewEntry")

        // If this is the first entry (entries was empty before adding this one)
        if entries.count == 1 {
            // Read welcome message from default.md
            if let defaultMessageURL = Bundle.main.url(forResource: "default", withExtension: "md"),
               let defaultMessage = try? String(contentsOf: defaultMessageURL, encoding: .utf8) {
                text = defaultMessage
            }
            // Save the welcome message immediately
            saveEntry(entry: newEntry)
            // Update the preview text
            updatePreviewText(for: newEntry)
        } else {
            text = ""
            // Randomize placeholder text for new entry
            placeholderText = WritingSpark.prompt(for: Date())
            DispatchQueue.main.async { refreshEditorChrome() }
            // Save the empty entry
            saveEntry(entry: newEntry)
        }
    }

    // The mirror of exportEntryAsPlainFile: writing comes in as a new page, dated now (not
    // whatever date the source file claims — this isn't a migration tool, just a quick way to
    // bring one piece of writing in without leaving the app).
    private func importEntry() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.plainText, UTType(filenameExtension: "md") ?? .plainText]
        panel.prompt = "Import"
        panel.message = "Pick a text or markdown file to bring in as a new page."
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
            showTransientMessage("Could not read that file")
            return
        }
        let content = JournalImport.sanitize(raw)
        guard !content.isEmpty else {
            showTransientMessage("That file was empty")
            return
        }

        finishVoiceNoteIfRecording()
        flushSaveIfNeeded()
        let newEntry = HumanEntry.createNew()
        entries.insert(newEntry, at: 0)
        selectedEntryId = newEntry.id
        applyBefore = nil
        currentVideoURL = nil
        selectedVideoHasTranscript = false
        didCopyTranscript = false
        text = content
        saveEntry(entry: newEntry)
        updatePreviewText(for: newEntry)
        historyDebug("IMPORT ENTRY created \(debugEntrySummary(newEntry)) from \(url.lastPathComponent)")
        logEntriesOrder("importEntry")
        showTransientMessage("Imported \u{201c}\(url.lastPathComponent)\u{201d}")
    }

    private func openChatGPT() {
        let fullText = effectiveChatGPTPrompt + "\n\n" + currentChatSourceText()
        if let url = ChatURL.chatGPT(fullText) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openLocalAgent(_ backend: LocalAgent.Backend) {
        ollamaService.cancel()
        showingOllamaPanel = false
        showingSidebar = false
        showingGraph = false
        agentService.backend = backend
        agentService.reply = ""
        agentService.errorMessage = nil
        showingAgentPanel = true
        if !currentChatSourceText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            runLocalAgent(job: .reflect, extra: nil)
        }
    }

    private func runLocalAgent(job: LocalAgent.Job, extra: String?) {
        let backend = agentService.backend
        let override = backend == .claude ? claudeCodePath : codexPath
        guard let executable = LocalAgent.resolvedPath(for: backend, override: override) else {
            agentService.errorMessage = "Choose the \(backend.title) program in Settings → Chat."
            showingAgentPanel = true
            return
        }
        agentService.job = job
        showingAgentPanel = true
        agentService.start(
            executable: executable,
            backend: backend,
            packet: LocalAgent.packet(
                job: job,
                tone: effectiveTonePrompt,
                entry: currentChatSourceText(),
                extra: extra
            )
        )
    }

    private var currentVersionItems: [PageVersions.Item] {
        guard let entry = entries.first(where: { $0.id == selectedEntryId }) else { return [] }
        return PageVersions.list(root: documentsDirectory, entryFilename: entry.filename)
    }

    private func applyChatReply(_ reply: String, mode: JournalApply.Mode) {
        let next = JournalApply.applying(reply, mode: mode, onto: text)
        snapshotThenApply(next)
    }

    private func snapshotThenApply(_ next: String, from original: String? = nil) {
        let current = original ?? text
        if let entry = entries.first(where: { $0.id == selectedEntryId }),
           PageVersions.shouldSnapshot(current: current, next: next) {
            _ = try? PageVersions.write(
                current: current,
                root: documentsDirectory,
                entryFilename: entry.filename
            )
        }
        applyBefore = current
        text = next
    }

    private func restoreVersion(_ item: PageVersions.Item) {
        guard let body = PageVersions.read(item.url) else {
            showTransientMessage("Could not open that draft")
            return
        }
        let next = PageVersions.restore(body, onto: text)
        snapshotThenApply(next)
        showingVersions = false
        showTransientMessage("Restored earlier draft")
    }

    private func applyAgentReply(_ reply: String, mode: JournalApply.Mode = .append) {
        guard !reply.isEmpty else {
            showTransientMessage("No reply")
            return
        }
        let before = text
        let body = LocalAgent.strippingSVGFences(JournalApply.cleanedReply(reply))
        if let entry = entries.first(where: { $0.id == selectedEntryId }) {
            for svg in LocalAgent.svgBlocks(in: reply) {
                if let relative = try? ImageStore.saveFile(
                    data: Data(svg.utf8),
                    documentsDirectory: documentsDirectory,
                    entryFilename: entry.filename,
                    prefix: "diagram",
                    ext: "svg"
                ) {
                    text = MarkdownExtras.insertImage(into: text, relativePath: relative, alt: "diagram")
                }
            }
        }
        if !body.isEmpty {
            snapshotThenApply(JournalApply.applying(body, mode: mode, onto: text), from: before)
        }
        if !MarkdownExtras.mermaidBlocks(in: reply).isEmpty {
            advancedMermaid = true
        }
        showTransientMessage("On the page")
    }

    private func openClaude() {
        let fullText = effectiveClaudePrompt + "\n\n" + currentChatSourceText()
        if let url = ChatURL.claude(fullText) {
            NSWorkspace.shared.open(url)
        }
    }

    private func copyPromptToClipboard() {
        let fullText = effectiveChatGPTPrompt + "\n\n" + currentChatSourceText()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fullText, forType: .string)
        print("Prompt copied to clipboard")
    }

    /// Same "guide text" / "write ≥350 chars first" gating the Chat popover uses to decide
    /// whether to offer chat at all — reused so the Cmd+Shift+O shortcut can't bypass it.
    private func canOfferOllamaChat() -> Bool {
        guard currentVideoURL == nil else { return true }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("hi. my name is farza.") { return false }
        if text.count < 350 { return false }
        return true
    }

    private func toggleChatFromMenu() {
        if showingOllamaPanel {
            ollamaService.cancel()
            showingOllamaPanel = false
            return
        }
        guard canOfferOllamaChat() else {
            showTransientMessage("Write a little more first")
            return
        }
        startOllamaChat()
    }

    private func exportSelectedAsPDF() {
        guard let selectedEntryId,
              let entry = entries.first(where: { $0.id == selectedEntryId }) else {
            showTransientMessage("Nothing to export")
            return
        }
        exportEntryAsPDF(entry: entry)
    }

    private var onThisDayHighlight: HumanEntry? {
        let names = JournalInsights.onThisDay(filenames: entries.map(\.filename)).map(\.filename)
        return names.compactMap { name in entries.first(where: { $0.filename == name }) }.first
    }

    private var yesterdayContinueLine: String? {
        guard JournalContinuity.shouldOffer(current: text) else { return nil }
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return nil }
        guard let item = JournalInsights.latestEntry(on: yesterday, filenames: entries.map(\.filename)) else {
            return nil
        }
        let raw = (try? String(
            contentsOf: documentsDirectory.appendingPathComponent(item.filename),
            encoding: .utf8
        )) ?? ""
        return JournalContinuity.lastSentence(in: raw)
    }

    private func flushSaveIfNeeded() {
        guard textNeedsSave else { return }
        if let currentId = selectedEntryId,
           let currentEntry = entries.first(where: { $0.id == currentId }),
           currentEntry.entryType == .text {
            saveEntry(entry: currentEntry)
        }
        textNeedsSave = false
    }

    private func selectEntry(_ entry: HumanEntry) {
        if selectedEntryId == entry.id { return }
        let key = entry.id.uuidString
        if PageLock.shouldChallenge(
            locked: PageLock.parse(lockedPageIDsStored).contains(key),
            alreadyUnlocked: unlockedPageIDs.contains(key)
        ) {
            Task {
                if await JournalLock.authenticate(reason: "Open this page") {
                    unlockedPageIDs.insert(key)
                    finishSelecting(entry)
                }
            }
            return
        }
        finishSelecting(entry)
    }

    private func finishSelecting(_ entry: HumanEntry) {
        finishVoiceNoteIfRecording()
        flushSaveIfNeeded()
        guard let target = entries.first(where: { $0.id == entry.id }) else { return }
        selectedEntryId = target.id
        applyBefore = nil
        loadEntry(entry: target)
    }

    private func isPageLocked(_ entry: HumanEntry) -> Bool {
        PageLock.parse(lockedPageIDsStored).contains(entry.id.uuidString)
    }

    private func togglePageLock(_ entry: HumanEntry) {
        let key = entry.id.uuidString
        if isPageLocked(entry) {
            Task {
                if await JournalLock.authenticate(reason: "Unlock this page") {
                    lockedPageIDsStored = PageLock.serialize(PageLock.toggling(key, in: PageLock.parse(lockedPageIDsStored)))
                    unlockedPageIDs.insert(key)
                }
            }
        } else {
            lockedPageIDsStored = PageLock.serialize(PageLock.toggling(key, in: PageLock.parse(lockedPageIDsStored)))
            unlockedPageIDs.remove(key)
        }
    }

    private func exportJournalZip() {
        let panel = NSSavePanel()
        panel.title = "Export Journal"
        panel.nameFieldStringValue = "Quire-journal.zip"
        panel.allowedContentTypes = [.zip]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try JournalExport.writeZip(from: documentsDirectory, to: url)
            showTransientMessage("Journal exported")
        } catch {
            showTransientMessage("Could not export the journal")
        }
    }

    private func presentSessionRecap() {
        let wordsThisSession = max(0, currentWordCount - sessionStartedWordCount)
        let message = JournalInsights.sessionRecap(
            wordCount: wordsThisSession,
            durationSeconds: preferredTimerSeconds
        )
        withAnimation(.easeOut(duration: 0.2)) {
            sessionRecapMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation(.easeIn(duration: 0.3)) {
                if sessionRecapMessage == message {
                    sessionRecapMessage = nil
                }
            }
        }
    }

    private func showTransientMessage(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            sessionRecapMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeIn(duration: 0.3)) {
                if sessionRecapMessage == message {
                    sessionRecapMessage = nil
                }
            }
        }
    }

    private func startWeeklyReview() {
        let dated = JournalInsights.entriesInLastDays(filenames: entries.map(\.filename), days: 7)
        var sections: [(title: String, body: String)] = []
        for item in dated {
            guard let entry = entries.first(where: { $0.filename == item.filename }) else { continue }
            let body: String
            if let video = resolvedVideoFilename(for: entry),
               let transcript = loadTranscriptText(for: video) {
                body = transcript
            } else {
                let url = getDocumentsDirectory().appendingPathComponent(entry.filename)
                body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            }
            if JournalInsights.isGuideOrEmpty(body) { continue }
            sections.append((title: JournalInsights.displayDate(item.timestamp), body: body))
        }

        let compiled = JournalInsights.compileWeeklyReview(sections: sections)
        guard !compiled.isEmpty else {
            showTransientMessage("No entries from this week yet")
            return
        }

        ollamaPromptOverride = PromptLibrary.defaultWeeklyReviewPrompt
        ollamaSourceText = compiled
        ollamaRelatedHint = "Last seven days"
        ollamaFocusPassage = ""
        ollamaCatalog = journalCatalog()
        ollamaCurrentFilename = nil
        ollamaChatEntryId = nil
        ollamaService.resetConversation()
        ollamaPanelEpoch += 1
        showingOllamaPanel = true
        showingSidebar = false
        showingGraph = false
        showingAgentPanel = false
        agentService.cancel()
    }

    private func startOllamaChat() {
        ollamaPromptOverride = nil
        let current = currentChatSourceText()
        let focus = JournalContext.focusPassage(selected: PageFind.selectedText() ?? "", in: text)
        let filename = entries.first(where: { $0.id == selectedEntryId })?.filename
        let catalog = journalCatalog()
        let related = JournalContext.related(to: focus ?? current, in: catalog, excluding: filename)
        ollamaSourceText = JournalContext.userPacket(current: current, related: related, focus: focus)
        ollamaRelatedHint = JournalContext.hint(relatedCount: related.count, focused: focus != nil)
        ollamaFocusPassage = focus ?? ""
        ollamaCatalog = catalog
        ollamaCurrentFilename = filename

        if let selectedEntryId, let currentEntry = entries.first(where: { $0.id == selectedEntryId }) {
            ollamaChatEntryId = currentEntry.id
            if let savedHistory = loadChatHistory(for: currentEntry), !savedHistory.isEmpty {
                ollamaService.restoreConversation(savedHistory)
            } else {
                ollamaService.resetConversation()
            }
        } else {
            ollamaChatEntryId = nil
            ollamaService.resetConversation()
        }

        showingOllamaPanel = true
        showingSidebar = false
        showingGraph = false
        showingAgentPanel = false
        agentService.cancel()
    }

    private func journalCatalog() -> [JournalContext.Entry] {
        entries.compactMap { entry in
            let raw: String
            if let video = resolvedVideoFilename(for: entry),
               let transcript = loadTranscriptText(for: video) {
                raw = transcript
            } else {
                raw = (try? String(
                    contentsOf: documentsDirectory.appendingPathComponent(entry.filename),
                    encoding: .utf8
                )) ?? ""
            }
            let body = MarkdownExtras.visibleBody(raw)
            guard !JournalInsights.isGuideOrEmpty(body) else { return nil }
            let dateLabel = JournalInsights.parseTimestamp(from: entry.filename)
                .map { JournalInsights.displayDate($0) } ?? entry.date
            return JournalContext.Entry(filename: entry.filename, dateLabel: dateLabel, body: body)
        }
    }

    private func currentChatSourceText() -> String {
        if currentVideoURL != nil,
           let selectedEntryId,
           let selectedEntry = entries.first(where: { $0.id == selectedEntryId }),
           let videoFilename = resolvedVideoFilename(for: selectedEntry),
           let transcript = loadTranscriptText(for: videoFilename) {
            return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return MarkdownExtras.visibleBody(text).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveVideoEntry(from tempURL: URL, transcript: String?) {
        let replacementEntry = selectedEntryId
            .flatMap { id in entries.first(where: { $0.id == id }) }
            .flatMap { entry -> HumanEntry? in
                guard entry.entryType == .text else { return nil }
                guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return entry
            }

        let videoEntry: HumanEntry
        if let replacementEntry {
            let videoFilename = replacementEntry.filename.replacingOccurrences(of: ".md", with: ".mov")
            videoEntry = HumanEntry(
                id: replacementEntry.id,
                date: replacementEntry.date,
                filename: replacementEntry.filename,
                previewText: previewTextFromTranscript(transcript),
                entryType: .video,
                videoFilename: videoFilename
            )
        } else {
            let newEntry = HumanEntry.createVideoEntry()
            videoEntry = HumanEntry(
                id: newEntry.id,
                date: newEntry.date,
                filename: newEntry.filename,
                previewText: previewTextFromTranscript(transcript),
                entryType: .video,
                videoFilename: newEntry.videoFilename
            )
        }

        // Get the documents directory
        let documentsDirectory = getDocumentsDirectory()

        // Save the video file
        if let videoFilename = videoEntry.videoFilename {
            do {
                let videoEntryDirectory = try ensureVideoEntryDirectoryExists(for: videoFilename)
                let videoDestURL = videoEntryDirectory.appendingPathComponent(videoFilename)
                let transcriptURL = videoEntryDirectory.appendingPathComponent("transcript.md")
                let cleanedTranscript = transcript?.trimmingCharacters(in: .whitespacesAndNewlines)

                // Copy the video file from temp location to documents directory
                if fileManager.fileExists(atPath: videoDestURL.path) {
                    try fileManager.removeItem(at: videoDestURL)
                }
                try fileManager.copyItem(at: tempURL, to: videoDestURL)
                print("Successfully saved video: \(videoFilename)")

                if let thumbnailImage = generateVideoThumbnail(from: videoDestURL) {
                    persistThumbnail(thumbnailImage, for: videoFilename)
                    print("Successfully saved thumbnail for video: \(videoFilename)")
                } else {
                    print("Could not generate thumbnail for video: \(videoFilename)")
                }

                // Create the metadata file
                let metadataURL = documentsDirectory.appendingPathComponent(videoEntry.filename)
                let metadataContent = "Video Entry"
                try metadataContent.write(to: metadataURL, atomically: true, encoding: .utf8)

                if let cleanedTranscript, !cleanedTranscript.isEmpty {
                    try cleanedTranscript.write(to: transcriptURL, atomically: true, encoding: .utf8)
                    print("Successfully saved transcript for video: \(videoFilename)")
                } else if fileManager.fileExists(atPath: transcriptURL.path) {
                    try fileManager.removeItem(at: transcriptURL)
                }

                let selectNewVideoEntry = {
                    if let existingIndex = self.entries.firstIndex(where: { $0.id == videoEntry.id }) {
                        self.entries[existingIndex] = videoEntry
                    } else {
                        self.entries.insert(videoEntry, at: 0)
                    }
                    self.entries.sort { self.isEntryNewer($0, than: $1) }
                    guard let insertedEntry = self.entries.first(where: { $0.id == videoEntry.id }) else {
                        print("Could not find saved video entry in entries array")
                        return
                    }
                    self.selectedEntryId = insertedEntry.id
                    self.currentVideoURL = videoDestURL
                    self.text = ""
                    self.didCopyTranscript = false
                    self.selectedVideoHasTranscript = (cleanedTranscript?.isEmpty == false)
                    print("Successfully loaded new video entry: \(videoFilename)")
                    self.historyDebug("VIDEO SAVE selected \(self.debugEntrySummary(insertedEntry)) videoPath=\(videoDestURL.path)")
                    self.logEntriesOrder("saveVideoEntry")
                }
                
                if Thread.isMainThread {
                    selectNewVideoEntry()
                } else {
                    DispatchQueue.main.async {
                        selectNewVideoEntry()
                    }
                }

                if replacementEntry != nil {
                    print("Successfully replaced empty text entry with video entry")
                } else {
                    print("Successfully created video entry")
                }
            } catch {
                print("Error saving video entry: \(error)")
            }
        }
    }

    private func deleteEntry(entry: HumanEntry) {
        // Move the file to Trash (not a permanent delete — see moveToTrash) from the filesystem
        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)

        guard moveToTrash(fileURL) else { return }
        print("Successfully removed file: \(entry.filename)")

        // If this is a video entry, also remove the video file
        if let videoFilename = resolvedVideoFilename(for: entry) {
            deleteVideoAssets(for: videoFilename)
            print("Successfully removed video assets: \(videoFilename)")
        }

        if pinnedEntryIDs.remove(entry.id.uuidString) != nil {
            UserDefaults.standard.set(Array(pinnedEntryIDs), forKey: "pinnedEntryIDs")
        }

        deleteChatHistory(for: entry)

        // Remove the entry from the entries array
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries.remove(at: index)
            historyDebug("DELETE ENTRY removed \(debugEntrySummary(entry))")
            logEntriesOrder("deleteEntry")

            // If the deleted entry was selected, select the first entry or create a new one
            if selectedEntryId == entry.id {
                if let firstEntry = entries.first {
                    selectedEntryId = firstEntry.id
                    loadEntry(entry: firstEntry)
                } else {
                    createNewEntry()
                }
            }
        }
    }
    
    // Extract a title from entry content for PDF export
    private func extractTitleFromContent(_ content: String, date: String) -> String {
        // Clean up content by removing leading/trailing whitespace and newlines
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If content is empty, just use the date
        if trimmedContent.isEmpty {
            return "Entry \(date)"
        }
        
        // Split content into words, ignoring newlines and removing punctuation
        let words = trimmedContent
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { word in
                word.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:\"'()[]{}<>"))
                    .lowercased()
            }
            .filter { !$0.isEmpty }
        
        // If we have at least 4 words, use them
        if words.count >= 4 {
            return "\(words[0])-\(words[1])-\(words[2])-\(words[3])"
        }
        
        // If we have fewer than 4 words, use what we have
        if !words.isEmpty {
            return words.joined(separator: "-")
        }
        
        // Fallback to date if no words found
        return "Entry \(date)"
    }
    
    private func exportEntryAsMarkdown(entry: HumanEntry) {
        exportEntryAsPlainFile(entry: entry, fileExtension: "md", contentType: UTType(filenameExtension: "md") ?? .plainText)
    }

    private func exportEntryAsText(entry: HumanEntry) {
        exportEntryAsPlainFile(entry: entry, fileExtension: "txt", contentType: .plainText)
    }

    private func exportEntryAsPlainFile(entry: HumanEntry, fileExtension: String, contentType: UTType) {
        if selectedEntryId == entry.id {
            saveEntry(entry: entry)
        }

        let fileURL = getDocumentsDirectory().appendingPathComponent(entry.filename)

        do {
            let entryContent = try String(contentsOf: fileURL, encoding: .utf8)
            let suggestedFilename = extractTitleFromContent(entryContent, date: entry.date) + "." + fileExtension

            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [contentType]
            savePanel.nameFieldStringValue = suggestedFilename
            savePanel.isExtensionHidden = false

            if savePanel.runModal() == .OK, let url = savePanel.url {
                try entryContent.write(to: url, atomically: true, encoding: .utf8)
                print("Successfully exported \(fileExtension) to: \(url.path)")
            }
        } catch {
            print("Error exporting \(fileExtension): \(error)")
        }
    }

    private func exportEntryAsPDF(entry: HumanEntry) {
        // First make sure the current entry is saved
        if selectedEntryId == entry.id {
            saveEntry(entry: entry)
        }
        
        // Get entry content
        let documentsDirectory = getDocumentsDirectory()
        let fileURL = documentsDirectory.appendingPathComponent(entry.filename)
        
        do {
            // Read the content of the entry
            let entryContent = try String(contentsOf: fileURL, encoding: .utf8)
            
            // Extract a title from the entry content and add .pdf extension
            let suggestedFilename = extractTitleFromContent(entryContent, date: entry.date) + ".pdf"
            
            // Create save panel
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [UTType.pdf]
            savePanel.nameFieldStringValue = suggestedFilename
            savePanel.isExtensionHidden = false  // Make sure extension is visible
            
            // Show save dialog
            if savePanel.runModal() == .OK, let url = savePanel.url {
                // Create PDF data
                if let pdfData = createPDFFromText(text: entryContent) {
                    try pdfData.write(to: url)
                    print("Successfully exported PDF to: \(url.path)")
                }
            }
        } catch {
            print("Error in PDF export: \(error)")
        }
    }
    
    private func createPDFFromText(text: String) -> Data? {
        // Letter size page dimensions
        let pageWidth: CGFloat = 612.0  // 8.5 x 72
        let pageHeight: CGFloat = 792.0 // 11 x 72
        let margin: CGFloat = 72.0      // 1-inch margins
        
        // Calculate content area
        let contentRect = CGRect(
            x: margin,
            y: margin,
            width: pageWidth - (margin * 2),
            height: pageHeight - (margin * 2)
        )
        
        // Create PDF data container
        let pdfData = NSMutableData()
        
        // Configure text formatting attributes
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineHeight
        
        let font = NSFont(name: selectedFont, size: fontSize) ?? .systemFont(ofSize: fontSize)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1.0),
            .paragraphStyle: paragraphStyle
        ]
        
        // Trim the initial newlines before creating the PDF
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Create the attributed string with formatting
        let attributedString = NSAttributedString(string: trimmedText, attributes: textAttributes)
        
        // Create a Core Text framesetter for text layout
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        
        // Create a PDF context with the data consumer
        guard let pdfContext = CGContext(consumer: CGDataConsumer(data: pdfData as CFMutableData)!, mediaBox: nil, nil) else {
            print("Failed to create PDF context")
            return nil
        }
        
        // Track position within text
        var currentRange = CFRange(location: 0, length: 0)
        var pageIndex = 0
        
        // Create a path for the text frame
        let framePath = CGMutablePath()
        framePath.addRect(contentRect)
        
        // Continue creating pages until all text is processed
        while currentRange.location < attributedString.length {
            // Begin a new PDF page
            pdfContext.beginPage(mediaBox: nil)
            
            // Fill the page with white background
            pdfContext.setFillColor(NSColor.white.cgColor)
            pdfContext.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
            
            // Create a frame for this page's text
            let frame = CTFramesetterCreateFrame(
                framesetter, 
                currentRange, 
                framePath, 
                nil
            )
            
            // Draw the text frame
            CTFrameDraw(frame, pdfContext)
            
            // Get the range of text that was actually displayed in this frame
            let visibleRange = CTFrameGetVisibleStringRange(frame)
            
            // Move to the next block of text for the next page
            currentRange.location += visibleRange.length
            
            // Finish the page
            pdfContext.endPage()
            pageIndex += 1
            
            // Safety check - don't allow infinite loops
            if pageIndex > 1000 {
                print("Safety limit reached - stopping PDF generation")
                break
            }
        }
        
        // Finalize the PDF document
        pdfContext.closePDF()
        
        return pdfData as Data
    }
}

// Helper function to calculate line height
func getLineHeight(font: NSFont) -> CGFloat {
    return font.ascender - font.descender + font.leading
}

// Add helper extension to find NSTextView
extension NSView {
    func findTextView() -> NSView? {
        if self is NSTextView {
            return self
        }
        for subview in subviews {
            if let textView = subview.findTextView() {
                return textView
            }
        }
        return nil
    }
}

// Add helper extension for finding subviews of a specific type
extension NSView {
    func findSubview<T: NSView>(ofType type: T.Type) -> T? {
        if let typedSelf = self as? T {
            return typedSelf
        }
        for subview in subviews {
            if let found = subview.findSubview(ofType: type) {
                return found
            }
        }
        return nil
    }
}

#Preview {
    ContentView()
}

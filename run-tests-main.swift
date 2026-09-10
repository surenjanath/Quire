import Foundation
import AppKit

func expect(_ cond: Bool, _ message: String, file: StaticString = #file, line: UInt = #line) {
    if !cond {
        fputs("FAIL \(file):\(line): \(message)\n", stderr)
        exit(1)
    }
}

@main
struct QuireTestRunner {
    static func main() {
        pageQuality()
        focusAndFind()
        writingPrefs()
        dictationAndVoice()
        journalBits()
        journalContext()
        journalStats()
        journalImport()
        print("PASS")
    }

    static func pageQuality() {
        let page = """
        hello i am me
        Start → Write
        /var/folders/x/T/Screenshot.png
        ![screenshot](Media/entry/shot-1.png)
        """
        expect(MarkdownExtras.wordCount(page) == 6, "word count")
        expect(MarkdownExtras.visibleBody(page).contains("hello i am me"), "visible")
        expect(!MarkdownExtras.visibleBody(page).contains("Media/entry"), "hide media")
        expect(!MarkdownExtras.visibleBody(page).contains("/var/folders"), "hide path")
        expect(MarkdownExtras.mermaidSources(in: "Start → Write") == ["Start → Write"], "loose mermaid")
        expect(MarkdownExtras.mermaidSources(in: "hello i am me").isEmpty, "no prose chart")
        let loose = MermaidFlow.parse("Start → Write")
        expect(loose.edges == [MermaidFlow.Edge(from: "Start", to: "Write")], "unicode arrow")
        let inserted = MarkdownExtras.insertImage(into: "hello", relativePath: "Media/abc/shot.png", alt: "screenshot")
        expect(inserted.contains("hello") && inserted.contains("![screenshot](Media/abc/shot.png)"), "insert")
        expect(!inserted.hasPrefix("\n\n"), "insert no lead")
        let clean = MarkdownExtras.scrubbingPage("\n\nhello\n\n\n/var/folders/x/T/Screenshot.png\n")
        expect(clean.hasPrefix("hello"), "scrub prefix")
        expect(!clean.contains("/var/folders"), "scrub path")
    }

    static func focusAndFind() {
        expect(IdleFade.chromeVisible(idleFadeEnabled: true, idleFor: 3, timerRunning: false, hovering: false, forceVisible: false), "idle show")
        expect(!IdleFade.chromeVisible(idleFadeEnabled: true, idleFor: 8, timerRunning: false, hovering: false, forceVisible: false), "idle hide")
        expect(FavoriteFonts.displayName(for: "Lato-Regular") == "Lato", "font name")
        expect(!CompositionGuard.shouldBlockBackspace(lockEnabled: true, keyCode: 51, hasMarkedText: true), "ime")
        expect(PageFind.ranges(in: "The River was a river", query: "river").count == 2, "find")
        expect(SaveDebounce.shouldFlush(dirty: true), "dirty")
        expect(ChatURL.encodeQuery("a & b").contains("%26"), "chat amp")
        expect(ImageStore.shouldPreferClipboardImage(hasImage: true, plainText: "https://example.com/x"), "prefer image")
        let river = "Hello there. The river was loud. Home."
        let caret = (river as NSString).range(of: "river").location
        let focused = SentenceFocus.range(in: river, caret: caret)
        expect((river as NSString).substring(with: focused) == "The river was loud.", "sentence")
        expect(CommandGo.commands(matching: "").count == CommandGo.catalog.count, "go all")
        expect(CommandGo.commands(matching: "claude").contains { $0.id == "claude-code" }, "go claude")
        expect(CommandGo.commands(matching: "zzzz").isEmpty, "go none")
        expect(CommandGo.commands(matching: "random").contains { $0.id == "random" }, "go random")
    }

    static func writingPrefs() {
        expect(WritingPreferences.resolvedFont("") == "Lato-Regular", "font fallback")
        expect(WritingPreferences.resolvedFontSize(19) == 18, "size snap")
        expect(WritingPreferences.resolvedTimerSeconds(900) == 900, "timer")
        expect(WritingPreferences.steppedTimerSeconds(current: 900, directionMinutes: 5) == 1200, "step")
        expect(WritingGoal.progress(current: 375, goal: 750) == 0.5, "goal")
        expect(WritingGoal.label(current: 375, goal: 750) == "375 / 750", "goal label")
        expect(TypewriterScroll.originY(caretMidY: 400, visibleHeight: 200, contentHeight: 800) == 300, "typewriter")
    }

    static func dictationAndVoice() {
        expect(EditorDictation.combining(base: "\n\nI think", transcript: "so") == "\n\nI think so", "dictate")
        expect(EditorDictation.combining(base: "\n\nkeep me", transcript: "   ") == "\n\nkeep me", "dictate empty")
        let note = VoiceNote.markdown(relativePath: "Media/entry/voice.m4a", transcript: "  hello  ")
        expect(note.contains("[voice note](Media/entry/voice.m4a)"), "voice md")
        expect(note.contains("hello"), "voice transcript")
        expect(VoiceNote.refs(in: "[voice note](Media/a/voice-1.m4a)\nhello") == ["Media/a/voice-1.m4a"], "voice refs")
        expect(VoiceNote.isMarkdownLine("[voice note](Media/a/voice-1.m4a)"), "voice line")
        let voiced = "hello river\n[voice note](Media/a/voice-1.m4a)\nI said this out loud"
        expect(!MarkdownExtras.hidingImageLines(voiced).contains("[voice note]"), "hide voice")
        expect(MarkdownExtras.hidingImageLines(voiced).contains("I said this out loud"), "keep transcript")
        expect(MarkdownExtras.restoringImageLines(visible: MarkdownExtras.hidingImageLines(voiced), stored: voiced).contains("[voice note](Media/a/voice-1.m4a)"), "restore voice")
    }

    static func journalBits() {
        expect(JournalTags.tags(in: "hello #River and #mom-notes") == ["river", "mom-notes"], "tags")
        expect(JournalTags.tags(in: "# Heading\nplain") == [], "heading")
        let riverPage = "The river was loud. I walked to the river. Home felt far from the river."
        expect(JournalTags.suggestions(in: riverPage, existing: [], limit: 2).first == "river", "suggest")
        expect(!JournalTags.suggestions(in: riverPage, existing: ["river"], limit: 3).contains("river"), "skip tag")
        expect(JournalTags.adding("river", to: "hello") == "hello #river", "add tag")
        expect(JournalTags.adding("river", to: "hello #river") == "hello #river", "dup tag")
        let reply = "hey, thanks for showing me this. my thoughts:\n\nThe river keeps calling."
        expect(JournalApply.cleanedReply(reply) == "The river keeps calling.", "clean reply")
        expect(JournalApply.applying(reply, mode: .append, onto: "hello") == "hello\n\nThe river keeps calling.", "append")
        let replaced = JournalApply.applying("tighter now", mode: .replace, onto: "hello\n![shot](Media/a/shot.png)")
        expect(replaced.contains("tighter now") && replaced.contains("![shot](Media/a/shot.png)"), "replace")
        expect(!replaced.contains("hello"), "replace drops old")
        let noted = JournalApply.applying("Keep going. The rest can wait.", mode: .note, onto: "hello")
        expect(noted.contains(">> Keep going.") && noted.contains("hello"), "note")
        expect(JournalApply.restoring("hello", ifDifferentFrom: "hello\n\nnew") == "hello", "undo")
        expect(JournalApply.restoring("hello", ifDifferentFrom: "hello") == nil, "undo same")
        expect(JournalContinuity.lastSentence(in: "I walked home. The river was loud.") == "The river was loud.", "last sentence")
        expect(JournalContinuity.shouldOffer(current: ""), "offer empty")
        expect(!JournalContinuity.shouldOffer(current: "hello"), "skip written")
        expect(JournalContinuity.starting(with: "The river was loud.") == "The river was loud. ", "start")
        expect(JournalFolder.videosURL(root: URL(fileURLWithPath: "/tmp/Root")).lastPathComponent == "Videos", "videos")
        expect(JournalFolder.versionsURL(root: URL(fileURLWithPath: "/tmp/Root")).lastPathComponent == "Versions", "versions dir")
        expect(PageVersions.folderName(from: "[abc]-[2026-01-01-12-00-00].md") == "[abc]-[2026-01-01-12-00-00]", "version base")
        expect(PageVersions.shouldSnapshot(current: "hello river", next: "tighter"), "snap change")
        expect(!PageVersions.shouldSnapshot(current: "", next: "hello"), "skip empty")
        expect(!PageVersions.shouldSnapshot(current: "hello", next: "hello"), "skip same")
        expect(!PageVersions.shouldSnapshot(current: "hi. my name is farza. hello", next: "new"), "skip guide")
        let stamp = PageVersions.stamp(date: Date(timeIntervalSince1970: 1_778_000_000))
        expect(stamp.contains("-"), "stamp")
        let versionRoot = FileManager.default.temporaryDirectory.appendingPathComponent("quire-versions-\(UUID().uuidString)", isDirectory: true)
        let entry = "[abc]-[2026-01-01-12-00-00].md"
        let saved = try? PageVersions.write(
            current: "The river was loud.",
            root: versionRoot,
            entryFilename: entry,
            now: Date(timeIntervalSince1970: 1_778_000_000)
        )
        expect(saved != nil, "wrote version")
        let listed = PageVersions.list(root: versionRoot, entryFilename: entry)
        expect(listed.count == 1, "list one")
        expect(PageVersions.read(listed[0].url) == "The river was loud.", "read version")
        let restored = PageVersions.restore("older draft", onto: "now\n![shot](Media/a/shot.png)")
        expect(restored.contains("older draft") && restored.contains("![shot](Media/a/shot.png)"), "restore keeps images")
        try? FileManager.default.removeItem(at: versionRoot)
        expect(PageCompare.preview(reply: "more", mode: .append, onto: "hello") == "hello\n\nmore", "compare append")
        expect(PageCompare.changed(before: "hello", after: "hello\n\nmore"), "compare changed")
        expect(!JournalExport.shouldInclude(relativePath: "Videos/clip.mov"), "export skip video")
        expect(JournalExport.shouldInclude(relativePath: "Media/a/shot.png"), "export media")
        expect(JournalExport.shouldInclude(relativePath: "note.md"), "export md")
        expect(!JournalExport.shouldInclude(relativePath: "Chats/a.json"), "export skip chat")
        expect(CaptureDevices.resolvedID(preferred: "cam-2", available: ["cam-1", "cam-2"], fallback: "cam-1") == "cam-2", "device prefer")
        expect(CaptureDevices.resolvedID(preferred: "gone", available: ["cam-1"], fallback: "cam-1") == "cam-1", "device fallback")
        expect(PageLock.parse("a,b").contains("b"), "page lock parse")
        expect(PageLock.serialize(PageLock.toggling("a", in: ["b"])) == "a,b" || PageLock.serialize(PageLock.toggling("a", in: ["b"])) == "b,a", "page lock toggle")
        expect(PageLock.shouldChallenge(locked: true, alreadyUnlocked: false), "page lock ask")
        expect(!PageLock.shouldChallenge(locked: true, alreadyUnlocked: true), "page lock session")
        expect(QuietSounds.shouldTick(enabled: true, before: "hi", after: "hit"), "tick")
        expect(!QuietSounds.shouldTick(enabled: false, before: "hi", after: "hit"), "tick off")
        let marks = SoftMarkdown.markerRanges(in: "# Title\n**bold** and ==hi==\n>> note")
        expect(marks.count >= 3, "soft markers")
        expect(JournalLock.shouldChallenge(enabled: true, alreadyUnlocked: false, canEvaluate: true), "lock")
        expect(!JournalLock.shouldChallenge(enabled: false, alreadyUnlocked: false, canEvaluate: true), "lock off")
        let sparkA = WritingSpark.prompt(for: Date(timeIntervalSince1970: 1_778_000_000))
        expect(!sparkA.isEmpty, "spark")
        expect(WritingSpark.prompts.contains("What do you keep circling?"), "circling spark")
        expect(WritingSpark.prompts.allSatisfy { $0.contains(" ") }, "spark spaces")
        let size = CGSize(width: 100, height: 200)
        let unit = ImageAnnotator.normalize(CGPoint(x: 50, y: 100), in: size)
        expect(abs(unit.x - 0.5) < 0.0001, "annotator")
    }

    static func journalContext() {
        let river = JournalContext.score(
            query: "I keep thinking about the river at home",
            body: "the river was loud today and I walked home"
        )
        let milk = JournalContext.score(
            query: "I keep thinking about the river at home",
            body: "bought milk and eggs"
        )
        expect(river > milk, "context rank")
        expect(JournalContext.hint(relatedCount: 2) == "Grounded in 2 other pages", "hint")
        expect(JournalContext.hint(relatedCount: 0, focused: true) == "This selection", "focus hint")
        expect(JournalContext.focusPassage(selected: "  the river  ", in: "hello the river today") == "the river", "focus")
        expect(JournalContext.systemPrompt.lowercased().contains("only"), "grounded")
        expect(OllamaSettings.parseThink("high") == .high, "think parse")
        expect(OllamaSettings.parseThink("nope") == .off, "think fallback")
        expect(OllamaSettings.clampTemperature(1.8) == 1, "temp high")
        expect(OllamaSettings.clampTemperature(-1) == 0, "temp low")
        expect(OllamaSettings.clampContext(9000) == 8192, "ctx")
        expect(OllamaSettings.effectiveSystemPrompt(custom: "  ") == OllamaSettings.defaultSystemPrompt, "sys default")
        expect(OllamaSettings.effectiveSystemPrompt(custom: "Be brief.") == "Be brief.", "sys custom")
        let off = OllamaSettings.chatPayload(model: "qwen3", messages: [], think: .off, temperature: 0.45, contextTokens: 8192)
        expect(off["think"] as? Bool == false, "think off")
        let high = OllamaSettings.chatPayload(model: "gpt-oss", messages: [], think: .high, temperature: 0.45, contextTokens: 8192)
        expect(high["think"] as? String == "high", "think high")
        expect(OllamaSettings.defaultSystemPrompt.lowercased().contains("greeting") || OllamaSettings.defaultSystemPrompt.lowercased().contains("do not open"), "sys no greeting")
        expect(LocalAgent.packet(instruction: "Look", entry: "the river").contains("```mermaid"), "agent mermaid")
        expect(LocalAgent.Job.improve.instruction.lowercased().contains("voice"), "improve job")
        expect(LocalAgent.packet(job: .diagram, tone: "x", entry: "river").lowercased().contains("mermaid"), "diagram job")
        expect(LocalAgent.packet(job: .ask, tone: "warm", entry: "river", extra: "why?").contains("FOLLOW UP"), "follow up")
        expect(PromptLibrary.effectiveTone(ollama: "", claude: "", chatGPT: "old") == "old", "tone fallback")
        expect(PromptLibrary.effectiveTone(ollama: "now", claude: "old", chatGPT: "older") == "now", "tone prefers ollama")
        expect(
            LocalAgent.resolvedPath(for: .claude, override: "/tmp/no-claude")
                == LocalAgent.resolvedPath(for: .claude, override: ""),
            "bad override falls back"
        )
        expect(LocalAgent.svgBlocks(in: "x\n```svg\n<svg></svg>\n```").count == 1, "svg")
        expect(QuireAction.aboutName == "Quire", "about name")
        expect(QuireAction.aboutAuthor == "Surenjanath", "about author")
        expect(QuireAction.aboutEmail.contains("@"), "about email")
        expect(QuireAction.aboutBasedOn.lowercased().contains("farza"), "about lineage")
        expect(QuireAction.aboutCredits.lowercased().contains("local"), "about credits")
        expect(QuireAction.aboutPrivacy.lowercased().contains("no account"), "about privacy")
        expect(QuireAction.aboutIncludes.count >= 5, "about includes")
        expect(QuireAction.aboutShortcuts.contains { $0.key == "⌘K" }, "about go shortcut")
        expect(QuireAction.aboutSite.contains("surenjanath"), "about site")
        expect(Set([QuireAction.newPage, QuireAction.toggleHistory, QuireAction.toggleChat, QuireAction.exportPDF, QuireAction.exportJournal, QuireAction.go, QuireAction.toggleSentenceFocus, QuireAction.showVersions, QuireAction.openSettings, QuireAction.settingsClosed]).count == 10, "action names")
    }

    static func journalStats() {
        expect(JournalStats.summarize([], streakDays: []) == .empty, "stats empty")

        let day1 = Date(timeIntervalSince1970: 1_778_000_000)
        let calendar = Calendar.current
        let day2 = calendar.date(byAdding: .day, value: 1, to: day1)!
        let day3 = calendar.date(byAdding: .day, value: 2, to: day1)!
        let day5 = calendar.date(byAdding: .day, value: 4, to: day1)!

        let facts = [
            JournalStats.EntryFacts(words: 10, tags: ["river"]),
            JournalStats.EntryFacts(words: 40, tags: ["river", "morning"]),
            JournalStats.EntryFacts(words: 5, tags: []),
        ]
        let summary = JournalStats.summarize(facts, streakDays: [day1, day2, day3, day5])
        expect(summary.totalEntries == 3, "stats total entries")
        expect(summary.totalWords == 55, "stats total words")
        expect(summary.longestEntryWords == 40, "stats longest entry")
        expect(summary.bestStreak == 3, "stats best streak")
        expect(summary.topTag == "river", "stats top tag")
        expect(summary.topTagCount == 2, "stats top tag count")

        expect(JournalStats.longestStreak(days: []) == 0, "streak empty")
        expect(JournalStats.longestStreak(days: [day1]) == 1, "streak single day")
        expect(JournalStats.longestStreak(days: [day1, day1, day2]) == 2, "streak dedups same day")
        expect(JournalStats.longestStreak(days: [day1, day3]) == 1, "streak gap breaks run")

        let tied = JournalStats.summarize([
            JournalStats.EntryFacts(words: 1, tags: ["writing"]),
            JournalStats.EntryFacts(words: 1, tags: ["morning"]),
        ], streakDays: [])
        expect(tied.topTag == "morning", "stats tag tie breaks alphabetically")
        expect(tied.topTagCount == 1, "stats tag tie count")
    }

    static func journalImport() {
        expect(JournalImport.sanitize("hello\r\nworld\r\n") == "hello\nworld", "import CRLF")
        expect(JournalImport.sanitize("hello\rworld") == "hello\nworld", "import CR")
        expect(JournalImport.sanitize("\u{FEFF}hello") == "hello", "import BOM")
        expect(JournalImport.sanitize("  hello  \n\n") == "hello", "import trim")
        expect(JournalImport.sanitize("") == "", "import empty")
    }
}

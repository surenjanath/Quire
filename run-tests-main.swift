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
    }

    static func journalBits() {
        expect(JournalTags.tags(in: "hello #River and #mom-notes") == ["river", "mom-notes"], "tags")
        expect(JournalTags.tags(in: "# Heading\nplain") == [], "heading")
        expect(JournalFolder.videosURL(root: URL(fileURLWithPath: "/tmp/Root")).lastPathComponent == "Videos", "videos")
        expect(JournalLock.shouldChallenge(enabled: true, alreadyUnlocked: false, canEvaluate: true), "lock")
        expect(!JournalLock.shouldChallenge(enabled: false, alreadyUnlocked: false, canEvaluate: true), "lock off")
        let sparkA = WritingSpark.prompt(for: Date(timeIntervalSince1970: 1_778_000_000))
        expect(!sparkA.isEmpty, "spark")
        let size = CGSize(width: 100, height: 200)
        let unit = ImageAnnotator.normalize(CGPoint(x: 50, y: 100), in: size)
        expect(abs(unit.x - 0.5) < 0.0001, "annotator")
    }
}

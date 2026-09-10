import Testing

@testable import freewrite

struct MarkdownExtrasTests {

    @Test func extractsWikiLinks() {
        let text = "I keep thinking about [[river notes]] and [[Feb 20]]."
        #expect(MarkdownExtras.wikiLinks(in: text) == ["river notes", "Feb 20"])
        #expect(MarkdownExtras.wikiLinks(in: "no links here").isEmpty)
    }

    @Test func resolvesWikiLinksAgainstPreviewAndDate() {
        let entries = [
            (filename: "[a]-[2025-02-20-08-00-00].md", preview: "river notes about home...", date: "Feb 20"),
            (filename: "[b]-[2026-09-09-08-00-00].md", preview: "today I ran", date: "Sep 9"),
        ]
        #expect(MarkdownExtras.resolve(link: "river notes", entries: entries) == "[a]-[2025-02-20-08-00-00].md")
        #expect(MarkdownExtras.resolve(link: "feb 20", entries: entries) == "[a]-[2025-02-20-08-00-00].md")
        #expect(MarkdownExtras.resolve(link: "missing", entries: entries) == nil)
    }

    @Test func extractsImageRefs() {
        let text = "see\n\n![shot](Media/abc/shot.png)\n\nand ![two](Media/abc/two.jpg)"
        #expect(MarkdownExtras.imageRefs(in: text) == ["Media/abc/shot.png", "Media/abc/two.jpg"])
    }

    @Test func insertsImageMarkdownAtEnd() {
        let next = MarkdownExtras.insertImage(into: "hello", relativePath: "Media/abc/shot.png", alt: "screenshot")
        #expect(next.contains("hello"))
        #expect(next.contains("![screenshot](Media/abc/shot.png)"))
        #expect(!next.hasPrefix("\n\n"))
    }

    @Test func scrubsBareImagePathsAndExtraBlankLines() {
        let messy = """

        hello i am me
        Start → Write


        /var/folders/x/T/Screenshot.png

        ## test
        ![screenshot](Media/entry/shot-1.png)
        """
        let clean = MarkdownExtras.scrubbingPage(messy)
        #expect(clean.hasPrefix("hello i am me"))
        #expect(clean.contains("## test"))
        #expect(clean.contains("![screenshot](Media/entry/shot-1.png)"))
        #expect(!clean.contains("/var/folders/x/T/Screenshot.png"))
        #expect(!clean.contains("\n\n\n"))
    }

    @Test func hidesImageMarkdownAndBarePathsFromThePage() {
        let stored = """
        hello i am me
        Start → Write
        /var/folders/x/T/Screenshot.png
        ## test
        ![screenshot](Media/entry/shot-1.png)
        """
        let visible = MarkdownExtras.hidingImageLines(stored)
        #expect(visible.contains("hello i am me"))
        #expect(visible.contains("## test"))
        #expect(!visible.contains("![screenshot]"))
        #expect(!visible.contains("/var/folders/x/T/Screenshot.png"))
        #expect(!visible.contains("Media/entry/shot-1.png"))

        let edited = visible.replacingOccurrences(of: "hello i am me", with: "hello again")
        let restored = MarkdownExtras.restoringImageLines(visible: edited, stored: stored)
        #expect(restored.contains("hello again"))
        #expect(restored.contains("![screenshot](Media/entry/shot-1.png)"))
        #expect(!restored.contains("hello i am me"))
    }

    @Test func hidesVoiceNoteLinksButKeepsTheTranscript() {
        let stored = """
        hello river
        [voice note](Media/a/voice-1.m4a)
        I said this out loud
        """
        let visible = MarkdownExtras.hidingImageLines(stored)
        #expect(visible.contains("hello river"))
        #expect(visible.contains("I said this out loud"))
        #expect(!visible.contains("[voice note]"))
        #expect(!visible.contains("voice-1.m4a"))

        let restored = MarkdownExtras.restoringImageLines(visible: visible, stored: stored)
        #expect(restored.contains("[voice note](Media/a/voice-1.m4a)"))
        #expect(restored.contains("hello river"))
        #expect(MarkdownExtras.wordCount(stored) == 7)
    }

    @Test func wordCountIgnoresImageJunk() {
        let page = """
        hello i am me
        Start → Write
        /var/folders/x/T/Screenshot.png
        ![screenshot](Media/entry/shot-1.png)
        """
        #expect(MarkdownExtras.wordCount(page) == 6)
        #expect(MarkdownExtras.visibleBody(page).contains("hello i am me"))
        #expect(!MarkdownExtras.visibleBody(page).contains("Media/entry"))
    }

    @Test func extractsAnnotationsAndHighlights() {
        let text = """
        the river was loud
        >> remember to ask mom
        I felt ==stuck== and ==tired==
        """
        #expect(MarkdownExtras.annotations(in: text) == ["remember to ask mom"])
        #expect(MarkdownExtras.highlights(in: text) == ["stuck", "tired"])
    }

    @Test func buildsGraphEdgesFromWikiLinks() {
        let entries = [
            (filename: "a.md", text: "see [[b note]]", preview: "a", date: "Sep 1"),
            (filename: "b.md", text: "plain", preview: "b note", date: "Sep 2"),
        ]
        let edges = MarkdownExtras.graphEdges(
            entries: entries.map { (filename: $0.filename, text: $0.text, preview: $0.preview, date: $0.date) }
        )
        #expect(edges == [MarkdownExtras.GraphEdge(from: "a.md", to: "b.md")])
    }
}

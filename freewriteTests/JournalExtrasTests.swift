import Foundation
import Testing

@testable import freewrite

struct JournalTagsTests {
    @Test func extractsHashtagsAndSkipsHeadings() {
        #expect(JournalTags.tags(in: "hello #River and #mom-notes") == ["river", "mom-notes"])
        #expect(JournalTags.tags(in: "# Heading\nplain text") == [])
        #expect(JournalTags.tags(in: "use c# or #1 later") == [])
        #expect(JournalTags.tags(in: "#ok then #ok again") == ["ok"])
    }

    @Test func suggestsFrequentWordsThatAreNotAlreadyTags() {
        let text = "The river was loud. I walked to the river. Home felt far from the river."
        #expect(JournalTags.suggestions(in: text, existing: [], limit: 2).first == "river")
        #expect(!JournalTags.suggestions(in: text, existing: ["river"], limit: 3).contains("river"))
        #expect(JournalTags.adding("river", to: "hello") == "hello #river")
        #expect(JournalTags.adding("river", to: "hello #river") == "hello #river")
    }
}

struct JournalApplyTests {
    @Test func stripsTheStockGreetingAndAppliesToThePage() {
        let reply = "hey, thanks for showing me this. my thoughts:\n\nThe river keeps calling."
        #expect(JournalApply.cleanedReply(reply) == "The river keeps calling.")
        #expect(JournalApply.applying(reply, mode: .append, onto: "hello") == "hello\n\nThe river keeps calling.")
        let stored = "hello\n![shot](Media/a/shot.png)"
        let replaced = JournalApply.applying("tighter now", mode: .replace, onto: stored)
        #expect(replaced.contains("tighter now"))
        #expect(replaced.contains("![shot](Media/a/shot.png)"))
        #expect(!replaced.contains("hello"))
        let noted = JournalApply.applying("Keep going. The rest can wait.", mode: .note, onto: "hello")
        #expect(noted.contains(">> Keep going."))
        #expect(noted.contains("hello"))
        #expect(JournalApply.restoring("hello", ifDifferentFrom: "hello\n\nnew") == "hello")
        #expect(JournalApply.restoring("hello", ifDifferentFrom: "hello") == nil)
        #expect(JournalApply.restoring(nil, ifDifferentFrom: "x") == nil)
    }
}

struct JournalContinuityTests {
    @Test func offersYesterdaysLastSentenceOnAnEmptyPage() {
        #expect(JournalContinuity.lastSentence(in: "I walked home. The river was loud.") == "The river was loud.")
        #expect(JournalContinuity.lastSentence(in: "hello\n![shot](Media/a/shot.png)") == "hello")
        #expect(JournalContinuity.lastSentence(in: "hi. my name is farza. welcome") == nil)
        #expect(JournalContinuity.lastSentence(in: "") == nil)
        #expect(JournalContinuity.shouldOffer(current: ""))
        #expect(JournalContinuity.shouldOffer(current: "  \n![shot](Media/a/shot.png)"))
        #expect(!JournalContinuity.shouldOffer(current: "hello"))
        #expect(JournalContinuity.starting(with: "The river was loud.") == "The river was loud. ")
    }
}

struct MermaidFlowTests {
    @Test func extractsFencedMermaidBlocks() {
        let text = """
        before
        ```mermaid
        graph TD
          A[Start] --> B[Write]
        ```
        after
        """
        #expect(MarkdownExtras.mermaidBlocks(in: text) == ["graph TD\n  A[Start] --> B[Write]"])
        #expect(MarkdownExtras.mermaidBlocks(in: "no charts").isEmpty)
        #expect(MarkdownExtras.mermaidSources(in: "Start → Write") == ["Start → Write"])
        #expect(MarkdownExtras.mermaidSources(in: "hello i am me").isEmpty)
    }

    @Test func parsesFlowchartNodesAndEdges() {
        let chart = MermaidFlow.parse("""
        graph TD
        A[Start] --> B[Write]
        B --> C
        """)
        #expect(chart.direction == "TD")
        #expect(chart.nodes == [
            MermaidFlow.Node(id: "A", label: "Start"),
            MermaidFlow.Node(id: "B", label: "Write"),
            MermaidFlow.Node(id: "C", label: "C"),
        ])
        #expect(chart.edges == [
            MermaidFlow.Edge(from: "A", to: "B"),
            MermaidFlow.Edge(from: "B", to: "C"),
        ])
        let loose = MermaidFlow.parse("Start → Write")
        #expect(loose.edges == [MermaidFlow.Edge(from: "Start", to: "Write")])
        #expect(loose.nodes.map(\.label) == ["Start", "Write"])
    }
}

struct ImageAnnotatorTests {
    @Test func normalizesAndRestoresPoints() {
        let size = CGSize(width: 100, height: 200)
        let point = CGPoint(x: 50, y: 100)
        let unit = ImageAnnotator.normalize(point, in: size)
        #expect(abs(unit.x - 0.5) < 0.0001)
        #expect(abs(unit.y - 0.5) < 0.0001)
        let back = ImageAnnotator.denormalize(unit, in: size)
        #expect(abs(back.x - 50) < 0.0001)
        #expect(abs(back.y - 100) < 0.0001)
    }
}

struct WritingGoalTests {
    @Test func progressAndLabel() {
        #expect(WritingGoal.progress(current: 375, goal: 750) == 0.5)
        #expect(WritingGoal.progress(current: 900, goal: 750) == 1)
        #expect(WritingGoal.progress(current: 10, goal: 0) == 0)
        #expect(WritingGoal.label(current: 375, goal: 750) == "375 / 750")
        #expect(WritingGoal.label(current: 10, goal: 0) == "")
    }
}

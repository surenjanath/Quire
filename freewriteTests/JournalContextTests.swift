import Foundation
import Testing

@testable import freewrite

struct JournalContextTests {
    @Test func scoresSharedMeaningfulWords() {
        let river = JournalContext.score(
            query: "I keep thinking about the river at home",
            body: "the river was loud today and I walked home"
        )
        let milk = JournalContext.score(
            query: "I keep thinking about the river at home",
            body: "bought milk and eggs"
        )
        #expect(river > milk)
        #expect(milk == 0)
    }

    @Test func picksRelatedEntriesAndSkipsTheCurrentPage() {
        let entries = [
            JournalContext.Entry(filename: "now.md", dateLabel: "Sep 9", body: "the river keeps showing up in my dreams"),
            JournalContext.Entry(filename: "old.md", dateLabel: "Sep 2", body: "I stood by the river until dark"),
            JournalContext.Entry(filename: "other.md", dateLabel: "Aug 1", body: "the grocery list is milk and bread"),
        ]
        let related = JournalContext.related(
            to: "dreams about the river again",
            in: entries,
            excluding: "now.md",
            limit: 2
        )
        #expect(related.map(\.filename) == ["old.md"])
    }

    @Test func packsCurrentAndRelatedWithoutInventing() {
        let packet = JournalContext.userPacket(
            current: "hello from today",
            related: [
                JournalContext.Entry(filename: "old.md", dateLabel: "Sep 2", body: "the river was loud")
            ]
        )
        #expect(packet.contains("CURRENT PAGE"))
        #expect(packet.contains("hello from today"))
        #expect(packet.contains("RELATED PAGES"))
        #expect(packet.contains("Sep 2"))
        #expect(packet.contains("the river was loud"))
        #expect(JournalContext.systemPrompt.lowercased().contains("only"))
        #expect(JournalContext.hint(relatedCount: 1) == "Grounded in 1 other page")
        #expect(JournalContext.hint(relatedCount: 0) == "This page only")
        let focused = JournalContext.userPacket(
            current: "the whole page about the river",
            related: [],
            focus: "the river"
        )
        #expect(focused.contains("FOCUS PASSAGE"))
        #expect(focused.contains("the river"))
        #expect(JournalContext.hint(relatedCount: 1, focused: true) == "Selection · 1 other page")
        #expect(JournalContext.hint(relatedCount: 0, focused: true) == "This selection")
        #expect(JournalContext.focusPassage(selected: "  the river  ", in: "hello the river today") == "the river")
        #expect(JournalContext.focusPassage(selected: "nope", in: "hello") == nil)
        #expect(JournalContext.focusPassage(selected: "hi", in: "hi there friend") == nil)
    }

    @Test func enrichesAFollowUpWithMatchingPages() {
        let catalog = [
            JournalContext.Entry(filename: "mom.md", dateLabel: "May 4", body: "mom called and I did not pick up"),
            JournalContext.Entry(filename: "work.md", dateLabel: "May 5", body: "shipped the build late"),
        ]
        let enriched = JournalContext.enrichFollowUp(
            "what did I write about mom?",
            catalog: catalog,
            excluding: "today.md"
        )
        #expect(enriched.contains("what did I write about mom?"))
        #expect(enriched.contains("mom called"))
        #expect(!enriched.contains("shipped the build"))
    }
}

struct OllamaSettingsTests {
    @Test func clampsThinkTemperatureAndBuildsAChatPayload() {
        #expect(OllamaSettings.parseThink("high") == .high)
        #expect(OllamaSettings.parseThink("nope") == .off)
        #expect(OllamaSettings.clampTemperature(1.8) == 1)
        #expect(OllamaSettings.clampTemperature(-1) == 0)
        #expect(OllamaSettings.clampContext(9000) == 8192)
        #expect(OllamaSettings.effectiveSystemPrompt(custom: "  ") == OllamaSettings.defaultSystemPrompt)
        #expect(OllamaSettings.effectiveSystemPrompt(custom: "Be brief.") == "Be brief.")
        let off = OllamaSettings.chatPayload(model: "qwen3", messages: [], think: .off, temperature: 0.45, contextTokens: 8192)
        #expect(off["think"] as? Bool == false)
        let high = OllamaSettings.chatPayload(model: "gpt-oss", messages: [], think: .high, temperature: 0.45, contextTokens: 8192)
        #expect(high["think"] as? String == "high")
        #expect(OllamaSettings.defaultSystemPrompt.lowercased().contains("do not open"))
    }
}

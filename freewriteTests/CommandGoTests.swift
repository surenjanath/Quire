import Foundation
import Testing

@testable import freewrite

struct CommandGoTests {
    @Test func matchesKnownCommandsAndFallsBackToNone() {
        #expect(CommandGo.commands(matching: "").count == CommandGo.catalog.count)
        #expect(CommandGo.commands(matching: "claude").contains { $0.id == "claude-code" })
        #expect(CommandGo.commands(matching: "zzzz").isEmpty)
    }

    @Test func askItemNeedsAFewCharactersAndCarriesTheRawQuery() {
        #expect(CommandGo.askItem(query: "hi") == nil)
        #expect(CommandGo.askItem(query: "   ") == nil)

        let ask = CommandGo.askItem(query: "what did I say about mom")
        #expect(ask?.kind == .ask)
        #expect(ask?.id == "what did I say about mom")
        #expect(ask?.title.contains("what did I say about mom") == true)
    }

    @Test func askItemTitleTruncatesLongQuestions() {
        let long = CommandGo.askItem(query: String(repeating: "a", count: 80))
        #expect((long?.title.count ?? 0) < 80)
        // id keeps the full question even though the display title truncates.
        #expect(long?.id.count == 80)
    }
}

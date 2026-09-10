import Foundation
import Testing

@testable import freewrite

struct ChatURLTests {
    @Test func encodesAmpersandSoTheRestOfThePromptSurvives() {
        let encoded = ChatURL.encodeQuery("hello & world and more")
        #expect(encoded.contains("%26"))
        #expect(!encoded.contains("&"))
        let url = ChatURL.chatGPT("hello & world and more")
        #expect(url?.absoluteString.contains("world") == true)
        #expect(url?.absoluteString.contains("more") == true)
    }

    @Test func claudeURLUsesTheSameEncoding() {
        let url = ChatURL.claude("a & b")
        #expect(url?.absoluteString.contains("%26") == true)
        #expect(url?.absoluteString.contains("b") == true)
    }
}

struct PageFindTests {
    @Test func findsCaseInsensitiveRangesInOrder() {
        let ranges = PageFind.ranges(in: "The River was a river", query: "river")
        #expect(ranges.count == 2)
        #expect(ranges[0].location == 4)
        #expect(PageFind.ranges(in: "none", query: "river").isEmpty)
        #expect(PageFind.ranges(in: "abc", query: "").isEmpty)
    }

    @Test func nextWrapsAround() {
        #expect(PageFind.nextIndex(after: nil, count: 3) == 0)
        #expect(PageFind.nextIndex(after: 0, count: 3) == 1)
        #expect(PageFind.nextIndex(after: 2, count: 3) == 0)
        #expect(PageFind.nextIndex(after: 0, count: 0) == nil)
    }
}

struct SaveDebounceTests {
    @Test func flushesOnlyWhenDirty() {
        #expect(SaveDebounce.shouldFlush(dirty: true))
        #expect(!SaveDebounce.shouldFlush(dirty: false))
    }
}

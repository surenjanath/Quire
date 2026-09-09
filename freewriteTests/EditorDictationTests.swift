import Testing

@testable import freewrite

struct EditorDictationTests {

    @Test func emptyEditorGetsPrefixedTranscript() {
        #expect(EditorDictation.combining(base: "", transcript: "hello") == "\n\nhello")
        #expect(EditorDictation.combining(base: "\n\n", transcript: "hello") == "\n\nhello")
    }

    @Test func appendsWithASpaceWhenNeeded() {
        #expect(EditorDictation.combining(base: "\n\nI think", transcript: "so") == "\n\nI think so")
        #expect(EditorDictation.combining(base: "\n\nI think ", transcript: "so") == "\n\nI think so")
    }

    @Test func keepsExistingLineBreaks() {
        #expect(EditorDictation.combining(base: "\n\nI think\n", transcript: "so") == "\n\nI think\nso")
    }

    @Test func emptyTranscriptLeavesBaseAlone() {
        #expect(EditorDictation.combining(base: "\n\nkeep me", transcript: "") == "\n\nkeep me")
        #expect(EditorDictation.combining(base: "\n\nkeep me", transcript: "   ") == "\n\nkeep me")
    }
}

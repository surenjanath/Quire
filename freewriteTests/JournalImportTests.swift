import Foundation
import Testing

@testable import freewrite

struct JournalImportTests {
    @Test func normalizesLineEndings() {
        #expect(JournalImport.sanitize("hello\r\nworld\r\n") == "hello\nworld")
        #expect(JournalImport.sanitize("hello\rworld") == "hello\nworld")
    }

    @Test func stripsByteOrderMarkAndTrims() {
        #expect(JournalImport.sanitize("\u{FEFF}hello") == "hello")
        #expect(JournalImport.sanitize("  hello  \n\n") == "hello")
    }

    @Test func emptyStaysEmpty() {
        #expect(JournalImport.sanitize("") == "")
        #expect(JournalImport.sanitize("   \n\n  ") == "")
    }
}

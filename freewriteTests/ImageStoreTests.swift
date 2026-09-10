import Foundation
import Testing

@testable import freewrite

struct ImageStorePasteTests {
    @Test func recognizesMacScreenshotTempPaths() {
        let path = "/var/folders/6k/tmp/T/TemporaryItems/NSIRD_screencaptureui/Screenshot 2026-09-09 at 8.46.15 PM.png"
        #expect(ImageStore.isImageFilePath(path))
        #expect(ImageStore.isImageFilePath("file://\(path)"))
        #expect(!ImageStore.isImageFilePath("hello i am me"))
        #expect(!ImageStore.isImageFilePath("see photo.png later"))
        #expect(!ImageStore.isImageFilePath(""))
    }

    @Test func prefersClipboardImageWheneverAnImageIsPresent() {
        #expect(ImageStore.shouldPreferClipboardImage(hasImage: true, plainText: nil))
        #expect(ImageStore.shouldPreferClipboardImage(hasImage: true, plainText: ""))
        #expect(ImageStore.shouldPreferClipboardImage(
            hasImage: true,
            plainText: "/tmp/Screenshot 2026-09-09 at 8.46.15 PM.png"
        ))
        #expect(ImageStore.shouldPreferClipboardImage(hasImage: true, plainText: "https://example.com/photo"))
        #expect(ImageStore.shouldPreferClipboardImage(hasImage: true, plainText: "hello i am me"))
        #expect(!ImageStore.shouldPreferClipboardImage(hasImage: false, plainText: "/tmp/shot.png"))
    }

    @Test func replacesBareImagePathLinesWithMarkdown() {
        let source = """
        hello i am me
        Start → Write

        /var/folders/x/T/Screenshot.png

        ## test
        """
        let next = ImageStore.replacingBareImagePaths(in: source) { _ in "Media/entry/shot-1.png" }
        #expect(next.contains("![screenshot](Media/entry/shot-1.png)"))
        #expect(!next.contains("/var/folders/x/T/Screenshot.png"))
        #expect(next.contains("hello i am me"))
        #expect(next.contains("## test"))
    }
}

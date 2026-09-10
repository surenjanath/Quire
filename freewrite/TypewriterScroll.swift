//
//  TypewriterScroll.swift
//  freewrite
//
//  Keeps the caret vertically centered in the key window's NSTextView.
//  Scroll math is pure so it can be tested without AppKit layout.
//

import AppKit

enum TypewriterScroll {
    static func originY(caretMidY: CGFloat, visibleHeight: CGFloat, contentHeight: CGFloat) -> CGFloat {
        guard visibleHeight > 0 else { return 0 }
        let target = caretMidY - (visibleHeight / 2)
        let maxY = max(0, contentHeight - visibleHeight)
        return min(max(target, 0), maxY)
    }

    static func centerCaretInKeyWindow() {
        guard let textView = findTextView(in: NSApp.keyWindow?.contentView) else { return }
        apply(to: textView, enabled: true)
    }

    static func apply(to textView: NSTextView, enabled: Bool) {
        let visibleHeight = textView.enclosingScrollView?.contentView.bounds.height ?? textView.visibleRect.height
        textView.textContainerInset = enabled
            ? NSSize(width: 0, height: max(40, visibleHeight / 2.4))
            : NSSize(width: 0, height: 0)

        guard enabled else { return }

        let range = textView.selectedRange()
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        rect.origin.y += textView.textContainerOrigin.y

        let contentHeight = max(textView.bounds.height, textView.fittingSize.height)
        let y = originY(caretMidY: rect.midY, visibleHeight: visibleHeight, contentHeight: contentHeight)
        textView.scroll(NSPoint(x: 0, y: y))
    }

    private static func findTextView(in view: NSView?) -> NSTextView? {
        guard let view else { return nil }
        if let textView = view as? NSTextView {
            return textView
        }
        for child in view.subviews {
            if let found = findTextView(in: child) {
                return found
            }
        }
        return nil
    }
}

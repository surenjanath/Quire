//
//  ImageAnnotator.swift
//  freewrite
//
//  Draw on a screenshot. Strokes are stored in 0...1 space so they
//  survive scale, then burned into the PNG on save.
//

import SwiftUI
import AppKit

enum ImageAnnotator {
    struct UnitPoint: Equatable {
        var x: Double
        var y: Double
    }

    static func normalize(_ point: CGPoint, in size: CGSize) -> UnitPoint {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        return UnitPoint(
            x: min(max(Double(point.x / width), 0), 1),
            y: min(max(Double(point.y / height), 0), 1)
        )
    }

    static func denormalize(_ point: UnitPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * Double(size.width), y: point.y * Double(size.height))
    }

    static func apply(strokes: [[UnitPoint]], to image: NSImage, color: NSColor = .systemRed, lineWidth: CGFloat = 3) -> NSImage {
        let size = image.size
        let output = NSImage(size: size)
        output.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size))
        color.setStroke()
        for stroke in strokes where stroke.count > 1 {
            let path = NSBezierPath()
            path.lineWidth = lineWidth
            path.lineJoinStyle = .round
            path.lineCapStyle = .round
            path.move(to: denormalize(stroke[0], in: size))
            for point in stroke.dropFirst() {
                path.line(to: denormalize(point, in: size))
            }
            path.stroke()
        }
        output.unlockFocus()
        return output
    }
}

struct ImageAnnotatorCanvas: View {
    let image: NSImage
    let colorScheme: ColorScheme
    let onSave: (NSImage) -> Void
    let onCancel: () -> Void

    @State private var strokes: [[ImageAnnotator.UnitPoint]] = []
    @State private var live: [ImageAnnotator.UnitPoint] = []

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 12) {
                GeometryReader { geo in
                    let fitted = fittedSize(in: geo.size)
                    ZStack {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                        Canvas { context, size in
                            let all = strokes + (live.isEmpty ? [] : [live])
                            for stroke in all where stroke.count > 1 {
                                var path = Path()
                                let first = ImageAnnotator.denormalize(stroke[0], in: size)
                                path.move(to: first)
                                for point in stroke.dropFirst() {
                                    path.addLine(to: ImageAnnotator.denormalize(point, in: size))
                                }
                                context.stroke(path, with: .color(.red), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    live.append(ImageAnnotator.normalize(value.location, in: fitted))
                                }
                                .onEnded { _ in
                                    if live.count > 1 {
                                        strokes.append(live)
                                    }
                                    live = []
                                }
                        )
                    }
                    .frame(width: fitted.width, height: fitted.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: 760, maxHeight: 480)

                HStack(spacing: 16) {
                    Button("Clear") { strokes = []; live = [] }
                    Button("Cancel", action: onCancel)
                    Button("Save") {
                        onSave(ImageAnnotator.apply(strokes: strokes, to: image))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(colorScheme == .light ? .white : .gray)
                .font(.system(size: 13))
            }
            .padding(20)
        }
    }

    private func fittedSize(in bounds: CGSize) -> CGSize {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
}

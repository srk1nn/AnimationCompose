//
//  Models.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 28.10.2024.
//

import UIKit

final class Layer: NSObject {
    var shouldRedraw = false

    private var lines: [Line]
    private var drawingLine: Line?

    init(lines: [Line], drawingLine: Line? = nil) {
        self.lines = lines
        self.drawingLine = drawingLine
    }

    init(layer: Layer) {
        lines = layer.lines.map { Line(line: $0) }
        drawingLine = layer.drawingLine.map { Line(line: $0) }
    }

    func startDrawingLine(_ line: Line) {
        drawingLine = line
        shouldRedraw = true
    }

    func takeDrawingLine() {
        if let line = drawingLine {
            lines.append(line)
            drawingLine = nil
            shouldRedraw = true
        }
    }

    func popLine() -> Line? {
        defer { shouldRedraw = true }
        return lines.popLast()
    }

    func pushLine(_ line: Line) {
        lines.append(line)
        shouldRedraw = true
    }

    func drawings() -> [Line] {
        var drawing = lines

        if let drawingLine {
            drawing.append(drawingLine)
        }

        defer {
            // Always redraw when drawing line exists
            if drawingLine == nil {
                shouldRedraw = false
            }
        }

        return drawing
    }

    func hasLines() -> Bool {
        !lines.isEmpty
    }
}

final class Line: NSObject {

    struct Settings {
        var width: CGFloat
        let alpha: CGFloat
        let blur: CGFloat?
        let blendMode: CGBlendMode
        let lineCap: CGLineCap
        let color: UIColor
        let isSmooth: Bool
    }

    let stroke: Stroke
    let settings: Settings

    init(stroke: Stroke, settings: Settings) {
        self.stroke = stroke
        self.settings = settings
    }

    init(line: Line) {
        stroke = Stroke(stroke: line.stroke)
        settings = line.settings
    }
}

final class Stroke {
    var points: [CGPoint]

    init(points: [CGPoint] = []) { 
        self.points = points
    }

    init(stroke: Stroke) {
        points = stroke.points
    }
}

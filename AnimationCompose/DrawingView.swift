//
//  DrawingView.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 28.10.2024.
//

import UIKit

final class DrawingView: UIView {

    var drawingLayer: Layer? {
        didSet {
            if oldValue !== drawingLayer || drawingLayer?.shouldRedraw ?? false {
                setNeedsDisplay()
            }
        }
    }

    var relativeToCanvas: CGRect?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        layer.drawsAsynchronously = true
    }

    override func draw(_ rect: CGRect) {
        drawingLayer?.drawings().forEach {
            draw(line: $0)
        }
    }

    // MARK: - Private

    private func draw(line: Line) {
        let points = drawablePoints(from: line.stroke.points)
        let settings = line.settings

        guard
            points.count > 1,
            let context = UIGraphicsGetCurrentContext()
        else {
            return
        }

        context.setAlpha(settings.alpha)
        context.setLineCap(.round)
        context.setLineWidth(settings.width)
        context.setShadow(offset: .zero, blur: settings.blur ?? 0, color: settings.color.cgColor)
        context.setStrokeColor(settings.color.cgColor)
        context.setBlendMode(settings.blendMode)

        context.move(to: points[0])
        for i in 1..<points.count {
            let mid = CGPoint(
                x: (points[i - 1].x + points[i].x) / 2,
                y: (points[i - 1].y + points[i].y) / 2
            )
            context.addQuadCurve(to: mid, control: points[i - 1])
        }
        context.strokePath()
    }

    private func drawablePoints(from points: [CGPoint]) -> [CGPoint] {
        let drawable: [CGPoint]

        if let relativeToCanvas {
            drawable = points.map { convertPoint($0, from: relativeToCanvas, to: bounds) }
        } else {
            drawable = points
        }

        return drawable
    }

    private func convertPoint(_ point: CGPoint, from sourceRect: CGRect, to destinationRect: CGRect) -> CGPoint {
        let relativeX = (point.x - sourceRect.origin.x) / sourceRect.width
        let relativeY = (point.y - sourceRect.origin.y) / sourceRect.height

        let newX = destinationRect.origin.x + relativeX * destinationRect.width
        let newY = destinationRect.origin.y + relativeY * destinationRect.height

        return CGPoint(x: newX, y: newY)
    }
}

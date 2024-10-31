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
        let points = line.stroke.points
        let settings = line.settings

        guard
            !points.isEmpty,
            let context = UIGraphicsGetCurrentContext()
        else {
            return
        }

        let linePoints: [CGPoint]

        if let relativeToCanvas {
            linePoints = points.map { convertPoint($0, from: relativeToCanvas, to: bounds) }
        } else {
            linePoints = points
        }

        // TODO: fix it
        if linePoints.count > 1 {
            context.move(to: linePoints.first!)
            context.addLines(between: linePoints)
            context.setAlpha(settings.alpha)
            context.setLineCap(.round)
            context.setLineWidth(settings.width)
            context.setShadow(offset: .zero, blur: settings.blur ?? 0, color: settings.color.cgColor)
            context.setStrokeColor(settings.color.cgColor)
            context.setBlendMode(settings.blendMode)
            context.strokePath()
        }
    }

    private func convertPoint(_ point: CGPoint, from sourceRect: CGRect, to destinationRect: CGRect) -> CGPoint {
        let relativeX = (point.x - sourceRect.origin.x) / sourceRect.width
        let relativeY = (point.y - sourceRect.origin.y) / sourceRect.height

        let newX = destinationRect.origin.x + relativeX * destinationRect.width
        let newY = destinationRect.origin.y + relativeY * destinationRect.height

        return CGPoint(x: newX, y: newY)
    }
}

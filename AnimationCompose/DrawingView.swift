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

    private let renderer = Renderer()

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
        drawingLayer?.drawings().forEach { line in
            guard let context = UIGraphicsGetCurrentContext() else {
                return
            }

            let points = drawablePoints(from: line.stroke.points)
            let settings = line.settings
            renderer.renderLine(points, settings: settings, in: context)
        }
    }

    // MARK: - Private

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

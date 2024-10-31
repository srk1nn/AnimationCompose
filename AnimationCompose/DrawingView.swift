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
        context.addLines(between: points)
        context.strokePath()

//        realDraw(points)

//        if linePoints.count > 1 {
//            context.move(to: linePoints.first!)
//            context.addLines(between: linePoints)
//            context.setAlpha(settings.alpha)
//            context.setLineCap(.round)
//            context.setLineWidth(settings.width)
//            context.setShadow(offset: .zero, blur: settings.blur ?? 0, color: settings.color.cgColor)
//            context.setStrokeColor(settings.color.cgColor)
//            context.setBlendMode(settings.blendMode)
//            context.strokePath()
//        }
    }

//    private func realDraw(_ points: [CGPoint]) {
//        guard points.count > 1 else { return }
//
//        let path = UIBezierPath()
//        path.lineWidth = 8
//
//        path.move(to: points[0])
//
//        for i in 1..<points.count {
//            let midPoint = CGPoint(
//                x: (points[i - 1].x + points[i].x) / 2,
//                y: (points[i - 1].y + points[i].y) / 2
//            )
//            path.addQuadCurve(to: midPoint, controlPoint: points[i - 1])
//        }
//
//        if let lastPoint = points.last {
//            path.addLine(to: lastPoint)
//        }
//
//        path.stroke(with: .multiply, alpha: 0.4)
//    }

    private func drawablePoints(from points: [CGPoint]) -> [CGPoint] {
        let drawable: [CGPoint]

        if let relativeToCanvas {
            drawable = points.map { convertPoint($0, from: relativeToCanvas, to: bounds) }
        } else {
            drawable = points
        }

        return filterNearest(points: drawable, minimumDistance: 0.01)
    }

    private func filterNearest(points: [CGPoint], minimumDistance: CGFloat) -> [CGPoint] {
        guard !points.isEmpty else { return [] }

        var filteredPoints = [points[0]]

        for point in points {
            if let lastPoint = filteredPoints.last {
                let distance = hypot(point.x - lastPoint.x, point.y - lastPoint.y)
                if distance >= minimumDistance {
                    filteredPoints.append(point)
                }
            }
        }

        return filteredPoints
    }

    private func convertPoint(_ point: CGPoint, from sourceRect: CGRect, to destinationRect: CGRect) -> CGPoint {
        let relativeX = (point.x - sourceRect.origin.x) / sourceRect.width
        let relativeY = (point.y - sourceRect.origin.y) / sourceRect.height

        let newX = destinationRect.origin.x + relativeX * destinationRect.width
        let newY = destinationRect.origin.y + relativeY * destinationRect.height

        return CGPoint(x: newX, y: newY)
    }
}

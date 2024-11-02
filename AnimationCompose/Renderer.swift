//
//  Renderer.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 31.10.2024.
//

import UIKit

final class Renderer {

    func renderImage(layer: Layer, background: UIImage, canvas: CGRect) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: canvas.size)

        let image = renderer.image { ctx in

            let context = ctx.cgContext

            // Translated to fit into CG coordinate system
            context.saveGState()
            context.translateBy(x: 0, y: canvas.size.height)
            context.scaleBy(x: 1.0, y: -1.0)

            background.cgImage.map {
                context.draw($0, in: canvas)
            }

            context.restoreGState()

            layer.drawings().forEach {
                renderLine($0.stroke.points, settings: $0.settings, in: context)
            }
        }

        return image
    }

    func renderLine(_ points: [CGPoint], settings: Line.Settings, in context: CGContext) {
        guard points.count > 1 else {
            return
        }

        context.setAlpha(settings.alpha)
        context.setLineCap(settings.lineCap)
        context.setLineWidth(settings.width)
        context.setShadow(offset: .zero, blur: settings.blur ?? 0, color: settings.color.cgColor)
        context.setStrokeColor(settings.color.cgColor)
        context.setBlendMode(settings.blendMode)

        context.move(to: points[0])

        if settings.isSmooth {
            for i in 1..<points.count {
                let mid = CGPoint(
                    x: (points[i - 1].x + points[i].x) / 2,
                    y: (points[i - 1].y + points[i].y) / 2
                )
                context.addQuadCurve(to: mid, control: points[i - 1])
            }
        } else {
            context.addLines(between: points)
        }

        context.strokePath()
    }
}

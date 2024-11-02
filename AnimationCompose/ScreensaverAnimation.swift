//
//  ScreensaverAnimation.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 02.11.2024.
//

import Foundation

final class ScreensaverAnimation {

    struct Frame {
        let circle: [CGPoint]
        let icon: [CGPoint]
    }

    func makeAnimation(
        circle: [CGPoint],
        icon: [CGPoint],
        canvas: CGRect,
        framesCount: Int
    ) -> [Frame] {

        var frames = [Frame]()

        var currentCircle = circle
        var currentIcon = icon
        var xVelocity: CGFloat = Bool.random() ? 8 : -8
        var yVelocity: CGFloat = Bool.random() ? 8 : -8

        for _ in 0..<framesCount {
            var maxX = currentCircle[0].x
            var minX = currentCircle[0].x
            var maxY = currentCircle[0].y
            var minY = currentCircle[0].y

            currentCircle.forEach {
                maxX = max(maxX, $0.x)
                minX = min(minX, $0.x)
                maxY = max(maxY, $0.y)
                minY = min(minY, $0.y)
            }

            var xTranslation = xVelocity
            var yTrasnlation = yVelocity

            var shouldFlipX = false
            var shouldFlipY = false

            if minX + xVelocity <= canvas.minX {
                shouldFlipX = true
                xTranslation = canvas.minX - minX
            }
            if maxX + xVelocity >= canvas.maxX {
                shouldFlipX = true
                xTranslation = canvas.maxX - maxX
            }
            if minY + yVelocity <= canvas.minY {
                shouldFlipY = true
                yTrasnlation = canvas.minY - minY
            }
            if maxY + yVelocity >= canvas.maxY {
                shouldFlipY = true
                yTrasnlation = canvas.maxY - maxY
            }

            let newCircle = currentCircle.map {
                return CGPoint(x: $0.x + xTranslation, y: $0.y + yTrasnlation)
            }

            let newIcon = currentIcon.map { CGPoint(x: $0.x + xTranslation, y: $0.y + yTrasnlation) }

            if shouldFlipX {
                xVelocity *= -1
            }
            if shouldFlipY {
                yVelocity *= -1
            }

            let frame = Frame(circle: newCircle, icon: newIcon)
            frames.append(frame)

            currentCircle = newCircle
            currentIcon = newIcon
        }

        return frames
    }

}

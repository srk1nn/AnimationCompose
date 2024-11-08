//
//  DrawingGestureRecognizer.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 28.10.2024.
//

import UIKit

final class DrawingGestureRecognizer: UIGestureRecognizer {
    var stroke = Stroke()

    private var touch: UITouch?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if touch == nil {
            touch = touches.first
        }

        if add(touches: touches, event: event) {
            state = .began
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if add(touches: touches, event: event) {
            if state == .began {
                state = .changed
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if add(touches: touches, event: event) {
            state = .ended
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        if add(touches: touches, event: event) {
            state = .failed
        }
    }

    override func reset() {
        stroke = Stroke()
        touch = nil
        super.reset()
    }

    private func add(touches: Set<UITouch>, event: UIEvent) -> Bool {
        guard
            let touch,
            touches.contains(touch)
        else {
            return false
        }

        event.coalescedTouches(for: touch)?.forEach {
            if let lastPoint = stroke.points.last {
                let location = $0.preciseLocation(in: view)
                let distance = hypot(location.x - lastPoint.x, location.y - lastPoint.y)
                if distance >= 0.01 {
                    stroke.points.append(location)
                }
            } else {
                let location = $0.preciseLocation(in: view)
                stroke.points.append(location)
            }
        }

        return true
    }
}


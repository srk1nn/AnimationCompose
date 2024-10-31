//
//  MainPresenter.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 28.10.2024.
//

import UIKit

enum Tool {
    case pencil
    case brush
    case eraser
    case instruments
}

enum Animation {
    case idle
    case animating(_ images: [UIImage])
}

private struct State {
    var animation: Animation
    var animationSpeed: AnimationSpeed
    var tool: Tool
    var color: UIColor
}

final class MainPresenter {
    weak var view: MainViewController?

    private let layerManager = LayerManager.shared
    private let gifGenerator = GIFGenerator()

    private var state = State(
        animation: .idle,
        animationSpeed: AnimationSpeed(option: .total, duration: 1),
        tool: .pencil,
        color: .link
    )

    func didLoadView() {
        updateUI()
    }

    func invalidateState() {
        updateUI()
    }

    @objc func handleDrawing(_ sender: DrawingGestureRecognizer) {
        switch sender.state {
        case .began:
            lineSettings().map {
                layerManager.startLine(settings: $0, stroke: sender.stroke)
            }
        case .cancelled, .ended:
            layerManager.endLine()
        default:
            break
        }
        
        updateUI()
    }

    func undo() {
        if layerManager.canUndo() {
            layerManager.undo()
            updateUI()
        }
    }

    func redo() {
        if layerManager.canRedo() {
            layerManager.redo()
            updateUI()
        }
    }

    func select(tool: Tool) {
        state.tool = tool
        updateUI()
    }

    func select(color: UIColor) {
        state.color = color
        updateUI()
    }

    func addLayer() {
        if layerManager.addLayer() {
            updateUI()
        }
    }

    func removeLayer() {
        layerManager.removeLayer()
        updateUI()
    }

    func play(canvas: CGRect) {
        let worker = DrawingView(frame: canvas)
        let background = CALayer()
        background.bounds = canvas
        background.shouldRasterize = true
        background.contents = UIImage.canvas.cgImage

        var images = [UIImage]()
        let renderer = UIGraphicsImageRenderer(bounds: canvas)

        layerManager.allLayers().forEach {
            worker.drawingLayer = $0
            let image = renderer.image { context in
                background.render(in: context.cgContext)
                worker.layer.render(in: context.cgContext)
            }
            images.append(image)
        }

        state.animation = .animating(images)
        updateUI()
    }

    func pause() {
        state.animation = .idle
        updateUI()
    }

    func shareGIF() {
        guard case let .animating(images) = state.animation else {
            // Share available only while animating by logic
            return
        }

        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("AnimationCompose.gif")
            try gifGenerator.generate(at: url, frames: images, animationSpeed: state.animationSpeed)
            view?.showShare(item: url)
        } catch {
            view?.showAlert(title: "Ошибка", message: error.localizedDescription)
        }
    }

    func updateSpeed(_ animationSpeed: AnimationSpeed) {
        state.animationSpeed = animationSpeed
        updateUI()
    }

    // MARK: - Private

    private func updateUI() {
        let layers = layerManager.allLayers()

        let viewModel = MainViewModel(
            canPlay: layers.count > 1,
            animation: state.animation,
            animationSpeed: state.animationSpeed,
            canUndo: layerManager.canUndo(),
            canRedo: layerManager.canRedo(),
            canRemoveLayer: layers.count > 1 || layers.first?.hasLines() == true,
            tool: state.tool,
            color: state.color,
            layer: layerManager.currentLayer(),
            previousLayer: layerManager.previousLayer()
        )

        view?.apply(viewModel)
    }

    private func lineSettings() -> Line.Settings? {
        switch state.tool {
        case .pencil:
            Line.Settings(width: 3, alpha: 1, blur: nil, blendMode: .normal, color: state.color)
        case .brush:
            Line.Settings(width: 8, alpha: 0.4, blur: 8, blendMode: .multiply, color: state.color)
        case .eraser:
            Line.Settings(width: 12, alpha: 1, blur: nil, blendMode: .clear, color: .clear)
        default:
            nil
        }
    }
}

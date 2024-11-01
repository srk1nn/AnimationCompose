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
    private let renderer = Renderer()
    private let gifGenerator = GIFGenerator()
    private let workerQueue = DispatchQueue(label: "animation.compose.worker", qos: .userInitiated, attributes: .concurrent)
    private var animationGenerationWork: DispatchWorkItem?

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
        cancelAnimationGeneration()
        updateUI()
    }

    @objc func handleDrawing(_ sender: DrawingGestureRecognizer) {
        cancelAnimationGeneration()

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
            cancelAnimationGeneration()
            layerManager.undo()
            updateUI()
        }
    }

    func redo() {
        if layerManager.canRedo() {
            cancelAnimationGeneration()
            layerManager.redo()
            updateUI()
        }
    }

    func select(tool: Tool) {
        cancelAnimationGeneration()
        state.tool = tool
        updateUI()
    }

    func select(color: UIColor) {
        cancelAnimationGeneration()
        state.color = color
        updateUI()
    }

    func addLayer() {
        cancelAnimationGeneration()

        if layerManager.addLayer() {
            updateUI()
        }
    }

    func removeLayer() {
        cancelAnimationGeneration()
        layerManager.removeLayer()
        updateUI()
    }

    func play(canvas: CGRect) {
        var workItem: DispatchWorkItem?

        workItem = DispatchWorkItem { [self] in
            defer { workItem = nil }

            let layers = layerManager.allLayers()
            var images = [UIImage]()
            images.reserveCapacity(layers.count)

            for layer in layers {
                guard workItem?.isCancelled == false else {
                    return
                }
                let image = renderer.renderImage(layer: layer, background: .canvas, canvas: canvas)
                images.append(image)
            }

            guard workItem?.isCancelled == false else {
                return
            }

            DispatchQueue.main.async { [self] in
                state.animation = .animating(images)
                updateUI()
            }
        }

        if let workItem {
            animationGenerationWork = workItem
            workerQueue.async(execute: workItem)
            updateUI()
        }
    }

    func pause() {
        cancelAnimationGeneration()
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
        cancelAnimationGeneration()
        state.animationSpeed = animationSpeed
        updateUI()
    }

    func cancelAnimationGeneration() {
        animationGenerationWork?.cancel()
        animationGenerationWork = nil
    }

    // MARK: - Private

    private func updateUI() {
        let layers = layerManager.allLayers()

        let viewModel = MainViewModel(
            canPlay: layers.count > 1,
            isGeneratingAnimation: animationGenerationWork != nil,
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
            Line.Settings(width: 8, alpha: 0.5, blur: 8, blendMode: .multiply, color: state.color)
        case .eraser:
            Line.Settings(width: 12, alpha: 1, blur: nil, blendMode: .clear, color: .clear)
        default:
            nil
        }
    }
}

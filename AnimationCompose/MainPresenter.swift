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
    private var gifGenerationWork: DispatchWorkItem?

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
        cancelGenerationWorks()
        updateUI()
    }

    @objc func handleDrawing(_ sender: DrawingGestureRecognizer) {
        cancelGenerationWorks()

        switch sender.state {
        case .began:
            layerManager.startLine(settings: lineSettings(), stroke: sender.stroke)
        case .cancelled, .ended:
            layerManager.endLine()
        default:
            break
        }

        updateUI()
    }

    func undo() {
        if layerManager.canUndo() {
            cancelGenerationWorks()
            layerManager.undo()
            updateUI()
        }
    }

    func redo() {
        if layerManager.canRedo() {
            cancelGenerationWorks()
            layerManager.redo()
            updateUI()
        }
    }

    func select(tool: Tool) {
        cancelGenerationWorks()
        state.tool = tool
        updateUI()
    }

    func select(color: UIColor) {
        cancelGenerationWorks()
        state.color = color
        updateUI()
    }

    func addLayer() {
        cancelGenerationWorks()
        let success = layerManager.addLayer()
        updateUI()

        if !success {
            view?.showAlert(title: "Ошибка", message: "Превышено максимальное количество кадров")
        }
    }

    func removeLayer() {
        cancelGenerationWorks()
        layerManager.removeLayer()
        updateUI()
    }

    func play(canvas: CGRect) {
        let layers = layerManager.allLayers()
        var workItem: DispatchWorkItem?

        workItem = DispatchWorkItem { [self] in
            defer { workItem = nil }

            var images = [UIImage]()
            images.reserveCapacity(layers.count)

            for layer in layers {
                guard workItem?.isCancelled == false else {
                    return
                }
                let image = renderer.renderImage(layer: layer, background: .canvas, canvas: canvas)
                images.append(image)
            }

            DispatchQueue.main.async { [self] in
                let wasCancelled = animationGenerationWork?.isCancelled
                animationGenerationWork = nil
                if wasCancelled == false {
                    state.animation = .animating(images)
                    updateUI()
                }
            }
        }

        if let workItem {
            animationGenerationWork = workItem
            workerQueue.async(execute: workItem)
            updateUI()
        }
    }

    func pause() {
        cancelGenerationWorks()
        state.animation = .idle
        updateUI()
    }

    func shareGIF() {
        guard case let .animating(images) = state.animation else {
            // Share available only while animating by logic
            return
        }

        let animationSpeed = state.animationSpeed
        var workItem: DispatchWorkItem?

        workItem = DispatchWorkItem { [self] in
            defer { workItem = nil }
            
            let result: Result<URL, Error>

            do {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("AnimationCompose.gif")
                try gifGenerator.generate(at: url, frames: images, animationSpeed: animationSpeed)
                result = .success(url)
            } catch {
                result = .failure(error)
            }

            DispatchQueue.main.async { [self] in
                let wasCancelled = gifGenerationWork?.isCancelled
                gifGenerationWork = nil
                if wasCancelled == false {
                    updateUI()
                    switch result {
                    case .success(let url):
                        view?.showShare(item: url)
                    case .failure(let error):
                        view?.showAlert(title: "Ошибка", message: error.localizedDescription)
                    }
                }
            }
        }

        if let workItem {
            gifGenerationWork = workItem
            workerQueue.async(execute: workItem)
            updateUI()
        }
    }

    func updateSpeed(_ animationSpeed: AnimationSpeed) {
        cancelGenerationWorks()
        state.animationSpeed = animationSpeed
        updateUI()
    }

    func generateBackgroundLayers(in canvas: CGRect, count: Int) {
        let center = CGPoint(x: canvas.midX, y: canvas.midY)

        let maxRadius = Int(hypot(canvas.width / 2, canvas.height / 2))
        let initialRadius = 10
        let radiusStep = 20
        var radius = 10
        var additionalRadius = -(maxRadius / 2)

        struct Radius: Hashable {
            let radius: Int
            let additionalRadius: Int
        }

        var layerByRadius = [Radius: Layer]()
        var layers = [Layer]()

        for _ in 0..<count {
            let radii = Radius(radius: radius, additionalRadius: additionalRadius)
            let cachedLayer = layerByRadius[radii]
            let layer = cachedLayer.map { Layer(layer: $0) } ?? layerCircles(center: center, radius: additionalRadius > 0 ? [radius, additionalRadius] : [radius])
            layerByRadius[radii] = layer

            layers.append(layer)

            radius = radius > maxRadius ? initialRadius : radius + radiusStep
            additionalRadius = additionalRadius > maxRadius ? initialRadius : additionalRadius + radiusStep
        }

        // TODO: подумать куда вставлять
        let success = layerManager.insertLayers(layers)

        if success {
            updateUI()
        } else {
            view?.showAlert(title: "Ошибка", message: "Превышено максимальное количество кадров")
        }
    }

    func cancelGenerationWorks() {
        animationGenerationWork?.cancel()
        animationGenerationWork = nil

        gifGenerationWork?.cancel()
        gifGenerationWork = nil
    }

    // MARK: - Private

    private func updateUI() {
        let layers = layerManager.allLayers()

        let viewModel = MainViewModel(
            canPlay: layers.count > 1,
            isGeneratingAnimation: animationGenerationWork != nil,
            isGeneratingGIF: gifGenerationWork != nil,
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

    private func lineSettings() -> Line.Settings {
        switch state.tool {
        case .pencil:
            Line.Settings(width: 3, alpha: 1, blur: nil, blendMode: .normal, color: state.color)
        case .brush:
            Line.Settings(width: 8, alpha: 0.5, blur: 8, blendMode: .multiply, color: state.color)
        case .eraser:
            Line.Settings(width: 12, alpha: 1, blur: nil, blendMode: .clear, color: .clear)
        }
    }

    private func layerCircles(center: CGPoint, radius: [Int]) -> Layer {
        let settings = lineSettings()

        let lines = radius
            .map { generateCirclePoints(center: center, radius: CGFloat($0)) }
            .map { Stroke(points: $0) }
            .map { Line(stroke: $0, settings: settings) }

        return Layer(lines: lines)
    }

    private func generateCirclePoints(center: CGPoint, radius: CGFloat) -> [CGPoint] {
        return stride(from: 0, through: 360, by: 5).map { angle in
            let radians = angle * .pi / 180
            return CGPoint(
                x: center.x + radius * cos(radians),
                y: center.y + radius * sin(radians)
            )
        }
    }
}

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
    var pencilWidth: BrushWidth
    var brushWidth: BrushWidth
}

final class MainPresenter {
    weak var view: MainViewController?

    private let layerManager = LayerManager.shared
    private let renderer = Renderer()
    private lazy var gifGenerator = GIFGenerator()
    private lazy var screensaverAnimation = ScreensaverAnimation()
    private let workerQueue = DispatchQueue(label: "animation.compose.worker", qos: .userInitiated, attributes: .concurrent)
    private var animationGenerationWork: DispatchWorkItem?
    private var gifGenerationWork: DispatchWorkItem?

    private var state = State(
        animation: .idle,
        animationSpeed: AnimationSpeed(option: .frame, duration: 1 / 30), // 30 fps
        tool: .pencil,
        color: .link,
        pencilWidth: BrushWidth(min: 1, max: 10, current: 2),
        brushWidth: BrushWidth(min: 2, max: 15, current: 6)
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

    func updateWidth(percent: CGFloat) {
        switch state.tool {
        case .pencil:
            state.pencilWidth.update(percent: percent)
        case .brush:
            state.brushWidth.update(percent: percent)
        default:
            break
        }
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

    func generateBackgroundLayers(in canvas: CGRect, framesCount: Int) {
        guard framesCount > 0 else {
            return
        }

        var layers = [Layer]()
        let lines = createInitialIcon(in: canvas)

        let circleLine = Line(stroke: Stroke(points: lines.circle), settings: lineSettings(color: .white))
        let iconLine = Line(stroke: Stroke(points: lines.icon), settings: lineSettings(color: .red, lineCap: .butt, isSmooth: false))
        layers.append(Layer(lines: [circleLine, iconLine]))

        let frames = screensaverAnimation.makeAnimation(circle: lines.circle, icon: lines.icon, canvas: canvas, framesCount: framesCount - 1)
        frames.forEach {
            let circleLine = Line(stroke: Stroke(points: $0.circle), settings: lineSettings(color: .white))
            let iconLine = Line(stroke: Stroke(points: $0.icon), settings: lineSettings(color: .red, lineCap: .butt, isSmooth: false))
            let layer = Layer(lines: [circleLine, iconLine])
            layers.append(layer)
        }

        let success = layerManager.appendLayers(layers)

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
            brushWidth: state.tool == .pencil ? state.pencilWidth : state.brushWidth,
            color: state.color,
            layer: layerManager.currentLayer(),
            previousLayer: layerManager.previousLayer()
        )

        view?.apply(viewModel)
    }

    private func lineSettings(
        color: UIColor? = nil,
        lineCap: CGLineCap = .round,
        isSmooth: Bool = true
    ) -> Line.Settings {

        switch state.tool {
        case .pencil:
            Line.Settings(width: state.pencilWidth.current, alpha: 1, blur: nil, blendMode: .normal, lineCap: lineCap, color: color ?? state.color, isSmooth: isSmooth)
        case .brush:
            Line.Settings(width: state.brushWidth.current, alpha: 0.35, blur: 4, blendMode: .normal, lineCap: lineCap, color: color ?? state.color, isSmooth: isSmooth)
        case .eraser:
            Line.Settings(width: 18, alpha: 1, blur: nil, blendMode: .clear, lineCap: lineCap, color: color ?? .clear, isSmooth: isSmooth)
        }
    }

    private func createInitialIcon(in canvas: CGRect) -> (circle: [CGPoint], icon: [CGPoint]) {
        let side = canvas.width / 5
        let available = canvas.insetBy(dx: side, dy: side)

        let frame = CGRect(
            x: .random(in: available.minX...(available.maxX - side)),
            y: .random(in: available.minY...(available.maxY - side)),
            width: side,
            height: side
        )

        let center = CGPoint(x: frame.midX, y: frame.midY)
        let radius = side / 2

        let circle = circlePoints(center: center, radius: radius)
        let icon = iconPoints(in: frame.insetBy(dx: side / 4, dy: side / 4))

        return (circle, icon)
    }

    private func circlePoints(center: CGPoint, radius: CGFloat) -> [CGPoint] {
        return stride(from: 0, through: 360, by: 5).map { angle in
            let radians = angle * .pi / 180
            return CGPoint(
                x: center.x + radius * cos(radians),
                y: center.y + radius * sin(radians)
            )
        }
    }

    private func iconPoints(in rect: CGRect) -> [CGPoint] {
        let topLeft = CGPoint(x: rect.minX, y: rect.minY)
        let middle = CGPoint(x: rect.midX, y: rect.midY)
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomMiddle = CGPoint(x: rect.midX, y: rect.maxY)

        return [
            topLeft,
            middle,
            bottomMiddle,
            middle,
            topRight
        ]
    }
}

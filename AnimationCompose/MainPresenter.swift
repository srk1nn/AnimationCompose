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

private struct State {
    var animationEngine: RenderEngine?
    var animationSpeed: AnimationSpeed
    var tool: Tool
    var color: UIColor
    var pencilWidth: BrushWidth
    var brushWidth: BrushWidth
    var hasHitches: Bool
}

final class MainPresenter {
    weak var view: MainViewController?

    private let layerManager = LayerManager.shared
    private lazy var gifGenerator = GIFGenerator()
    private lazy var screensaverAnimation = ScreensaverAnimation()
    private var generationGIF: DispatchWorkItem?

    private var state = State(
        animationEngine: nil,
        animationSpeed: AnimationSpeed(option: .frame, duration: 1 / 30), // 30 frames per seconds
        tool: .pencil,
        color: .link,
        pencilWidth: BrushWidth(min: 1, max: 10, current: 2),
        brushWidth: BrushWidth(min: 2, max: 15, current: 6),
        hasHitches: false
    )

    // MARK: - Getters
    func animationSpeed() -> AnimationSpeed {
        return state.animationSpeed
    }

    func brushWidth() -> BrushWidth? {
        switch state.tool {
        case .pencil:
            state.pencilWidth
        case .brush:
            state.brushWidth
        case .eraser:
            nil
        }
    }

    // MARK: - Lifecycle

    func didLoadView() {
        updateUI()
    }

    // MARK: - Drawing

    @objc func handleDrawing(_ sender: DrawingGestureRecognizer) {
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

    // MARK: - Layers

    func addLayer() {
        let success = layerManager.addLayer()
        updateUI()

        if !success {
            view?.showAlert(title: "Ошибка", message: "Превышено максимальное количество кадров", completion: nil)
        }
    }

    func removeLayer() {
        layerManager.removeLayer()
        updateUI()
    }

    func handleLayers() {
        view?.showAnimatic()
    }

    func animaticDidClose() {
        updateUI()
    }

    // MARK: - Undo & Redo

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

    // MARK: - Colors

    func select(color: UIColor) {
        state.color = color
        updateUI()
    }

    func handlePalette() {
        view?.showPallete()
    }

    // MARK: - Tools

    func select(tool: Tool) {
        state.tool = tool
        updateUI()
    }

    // MARK: - Brush Width

    func updateWidth(percent: CGFloat) {
        switch state.tool {
        case .pencil:
            state.pencilWidth.update(percent: percent)
        case .brush:
            state.brushWidth.update(percent: percent)
        case .eraser:
            break
        }
    }

    // MARK: - Animation Speed

    func handleSpeed() {
        cancelGIFGeneration()
        pauseAnimation()
        updateUI()
        view?.showAnimationSpeed(state.animationSpeed)
    }

    func animationSpeedDidSelect(_ animationSpeed: AnimationSpeed) {
        state.animationSpeed = animationSpeed
        state.hasHitches = false
        resumeAnimation()
        updateUI()
    }

    // MARK: - Animation

    func playAnimation(in view: UIImageView, canvas: CGRect) {
        let layers = layerManager.allLayers()
        let engine = RenderEngine(layers: layers, canvas: canvas, view: view, delegate: self)
        state.animationEngine = engine
        engine.attach(animationSpeed: state.animationSpeed)
        updateUI()
    }

    func stopAnimation() {
        cancelGIFGeneration()
        state.animationEngine = nil
        updateUI()
    }

    func handleHitches() {
        cancelGIFGeneration()
        updateUI()
        view?.showAlert(
            title: "Высокая скорость анимации",
            message: "На превью не все кадры успевают прорисовываться. Рекомендуется увеличить длительность анимации",
            completion: nil
        )
    }

    // MARK: - Share

    func shareGIF(canvas: CGRect) {
        let layers = layerManager.allLayers()
        let animationSpeed = state.animationSpeed
        var workItem: DispatchWorkItem?

        workItem = DispatchWorkItem { [self] in
            defer { workItem = nil }

            let result: Result<URL, Error>

            do {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("AnimationCompose.gif")

                try gifGenerator.generate(
                    at: url,
                    layers: layers,
                    background: .canvas,
                    canvas: canvas,
                    animationSpeed: animationSpeed,
                    isCancelled: { [weak workItem] in
                        workItem?.isCancelled ?? true
                    })

                result = .success(url)
            } catch {
                result = .failure(error)
            }

            DispatchQueue.main.async { [self] in
                let wasCancelled = generationGIF?.isCancelled
                generationGIF = nil
                if wasCancelled == false {
                    pauseAnimation()
                    updateUI()
                    switch result {
                    case .success(let url):
                        view?.showShare(item: url)
                    case .failure(let error):
                        view?.showAlert(title: "Ошибка", message: error.localizedDescription, completion: { [self] in
                            resumeAnimation()
                        })
                    }
                }
            }
        }

        if let workItem {
            generationGIF = workItem
            DispatchQueue.generationQueue.async(execute: workItem)
            updateUI()
        }
    }

    func shareDidClose() {
        state.hasHitches = false
        resumeAnimation()
        updateUI()
    }

    // MARK: - Random Animation

    func createAnimation() {
        view?.showAnimationCreation()
    }

    func animationCreationDidSelect(framesCount: Int, canvas: CGRect) {
        guard framesCount > 0 else {
            return
        }

        if state.tool == .eraser {
            state.tool = .pencil
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
            view?.showAlert(title: "Ошибка", message: "Превышено максимальное количество кадров", completion: nil)
        }
    }
}

// MARK: - Private

private extension MainPresenter {

    func updateUI() {
        let layers = layerManager.allLayers()

        let viewModel = MainViewModel(
            isAnimating: state.animationEngine != nil,
            canUndo: layerManager.canUndo(),
            canRedo: layerManager.canRedo(),
            canPlay: layers.count > 1,
            canRemoveLayer: layers.count > 1 || layers.first?.hasLines() == true,
            isGeneratingGIF: generationGIF != nil,
            hasHitches: state.hasHitches,
            tool: state.tool,
            color: state.color,
            layer: layerManager.currentLayer(),
            previousLayer: layerManager.previousLayer()
        )

        view?.apply(viewModel)
    }

    func resumeAnimation() {
        guard state.animationEngine?.isAnimating == false else {
            return
        }
        state.animationEngine?.attach(animationSpeed: state.animationSpeed)
    }

    func pauseAnimation() {
        guard state.animationEngine?.isAnimating == true else {
            return
        }
        state.animationEngine?.unattach()
    }

    func cancelGIFGeneration() {
        generationGIF?.cancel()
        generationGIF = nil
    }

    func lineSettings(
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

    func createInitialIcon(in canvas: CGRect) -> (circle: [CGPoint], icon: [CGPoint]) {
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

    func circlePoints(center: CGPoint, radius: CGFloat) -> [CGPoint] {
        return stride(from: 0, through: 360, by: 5).map { angle in
            let radians = angle * .pi / 180
            return CGPoint(
                x: center.x + radius * cos(radians),
                y: center.y + radius * sin(radians)
            )
        }
    }

    func iconPoints(in rect: CGRect) -> [CGPoint] {
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

// MARK: - RenderEngineDelegate

extension MainPresenter: RenderEngineDelegate {
    func renderEngineDetectHitches() {
        state.hasHitches = true
        updateUI()
    }
}

private extension DispatchQueue {
    static let generationQueue = DispatchQueue(label: "animation.compose.generation", qos: .userInitiated)
}

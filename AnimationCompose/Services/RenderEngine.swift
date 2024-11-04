//
//  RenderEngine.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 03.11.2024.
//

import UIKit

protocol RenderEngineDelegate: AnyObject {
    func renderEngineDetectHitches()
}

final class RenderEngine {
    private var hitchesRegulator = HitchesRegulator()
    private let layers: [Layer]
    private let background: UIImage
    private let canvas: CGRect
    private let view: UIImageView
    private var layerIndex: Int = 0
    private var timer: DispatchSourceTimer?

    private weak var delegate: RenderEngineDelegate?

    private let workers: [RenderWorker] = [
        RenderWorker(),
        RenderWorker()
    ]

    var isAnimating: Bool {
        timer != nil
    }

    init(layers: [Layer], background: UIImage, canvas: CGRect, view: UIImageView, delegate: RenderEngineDelegate?) {
        self.layers = layers
        self.background = background
        self.canvas = canvas
        self.view = view
        self.delegate = delegate

        hitchesRegulator.onHitch = { [weak self] in
            self?.delegate?.renderEngineDetectHitches()
        }
    }

    deinit {
        unattach()
    }

    func attach(animationSpeed: AnimationSpeed) {
        render()

        let secondsPerFrame = animationSpeed.secondsPerFrame(framesCount: layers.count)
        let microsecPerFrame = Int(secondsPerFrame * 1000000)

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .microseconds(microsecPerFrame), leeway: .never)

        timer.setEventHandler(qos: .userInteractive) { [weak self] in
            guard let frame = self?.pop() else {
                self?.hitchesRegulator.registerHitch()
                return
            }
            self?.view.image = frame
        }

        timer.activate()
        self.timer = timer
    }

    func unattach() {
        timer?.cancel()
        timer = nil
        view.image = nil
        layerIndex = layers.startIndex
        workers.forEach { $0.cancel() }
        hitchesRegulator.reset()
    }

    private func render() {
        (0..<workers.count).forEach {
            workers[$0].render(
                layers: layers,
                background: background,
                canvas: canvas,
                workerIndex: $0,
                workersCount: workers.count
            )
        }
    }

    private func pop() -> UIImage? {
        let workerIndex = layerIndex % workers.count
        let worker = workers[workerIndex]
        let frame = worker.pop()

        if frame != nil {
            layerIndex = (layerIndex == layers.endIndex - 1) ? layers.startIndex : layers.index(after: layerIndex)
        }

        return frame
    }
}

private final class RenderWorker {
    private let renderer = Renderer()
    private let renderQueue = RenderQueue()
    private let lock = NSLock()
    private var workItem: DispatchWorkItem?

    func render(
        layers: [Layer],
        background: UIImage,
        canvas: CGRect,
        workerIndex: Int,
        workersCount: Int
    ) {
        var workItem: DispatchWorkItem?

        workItem = DispatchWorkItem { [self] in
            defer { workItem = nil }

            var index = layers.startIndex
            while index < layers.endIndex {
                if renderQueue.shouldRender {
                    if workerIndex == index % workersCount {
                        let layer = layers[index]
                        let image = renderer.renderImage(layer: layer, background: background, canvas: canvas)

                        lock.lock()
                        if workItem?.isCancelled == false {
                            renderQueue.push(image)
                        } else {
                            lock.unlock()
                            return
                        }
                        lock.unlock()

                    }
                    index = (index == layers.endIndex - 1) ? layers.startIndex : index + 1
                }
            }
        }

        if let workItem = workItem {
            self.workItem = workItem
            DispatchQueue.renderQueue.async(execute: workItem)
        }
    }

    func cancel() {
        lock.lock()
        workItem?.cancel()
        workItem = nil
        renderQueue.removeAll()
        lock.unlock()
    }

    func pop() -> UIImage? {
        renderQueue.pop()
    }
}

private final class RenderQueue {
    private let lock = NSLock()
    private var frames: [UIImage]

    init() {
        frames = [UIImage]()
        frames.reserveCapacity(Constants.framesLimit)
    }

    var shouldRender: Bool {
        lock.withLock {
            frames.count < Constants.framesLimit
        }
    }

    func push(_ image: UIImage) {
        lock.withLock {
            frames.append(image)
        }
    }

    func pop() -> UIImage? {
        lock.withLock {
            guard !frames.isEmpty else {
                return nil
            }

            return frames.removeFirst()
        }
    }

    func removeAll() {
        lock.withLock {
            frames.removeAll(keepingCapacity: true)
        }
    }

    private enum Constants {
        static let framesLimit = 3
    }
}

private extension DispatchQueue {
    static let renderQueue = DispatchQueue(label: "animation.compose.render.queue", qos: .userInteractive, attributes: .concurrent)
}

//
//  MetalDrawingView.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 31.10.2024.
//

import MetalKit

final class MetalDrawingView: MTKView, MTKViewDelegate {
    var drawingLayer: Layer?

    private var commandQueue: MTLCommandQueue?

    private lazy var pipelineState: MTLRenderPipelineState? = {
        let descriptor = MTLRenderPipelineDescriptor()
        let library = device?.makeDefaultLibrary()
        descriptor.vertexFunction = library?.makeFunction(name: "vertex_main")
        descriptor.fragmentFunction = library?.makeFunction(name: "fragment_main")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        return try? device?.makeRenderPipelineState(descriptor: descriptor)
    }()

    override init(frame frameRect: CGRect, device: (any MTLDevice)?) {
        super.init(frame: frameRect, device: device)
        setup()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }


    func draw(in view: MTKView) {
        guard
            let drawingLayer,
            let currentDrawable,
            let commandQueue,
            let currentRenderPassDescriptor,
            let pipelineState
        else {
            return
        }
        
        let buffer = commandQueue.makeCommandBuffer()
        let encoder = buffer?.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor)
        encoder?.setRenderPipelineState(pipelineState)

        let points = drawingLayer.drawings().flatMap { $0.stroke.points }
        let vertexBuffer = device?.makeBuffer(bytes: points, length: MemoryLayout<CGPoint>.size * points.count)
        encoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder?.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: points.count)
        encoder?.endEncoding()
        buffer?.present(currentDrawable)
        buffer?.commit()
    }

    private func setup() {
        delegate = self
        colorPixelFormat = .bgra8Unorm
        commandQueue = device?.makeCommandQueue()
    }
}

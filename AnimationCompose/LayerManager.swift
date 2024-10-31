//
//  LayerManager.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 31.10.2024.
//

import Foundation

final class LayerManager {
    static let shared = LayerManager()

    private let undoManager = UndoManager()
    private var layers = [Layer(lines: [])]

    // MARK: - Lines

    func startLine(settings: Line.Settings, stroke: Stroke) {
        let line = Line(stroke: stroke, settings: settings)
        layers.last?.startDrawingLine(line)
    }

    func endLine() {
        layers.last?.takeDrawingLine()
        undoManager.registerUndo(withTarget: self, selector: #selector(undoEndLine), object: nil)
    }

    // MARK: - Layers

    /// This method may fail, due to number of layers limit
    @objc func addLayer() -> Bool {
        if layers.count == Int.max {
            // Clause: Максимальное количество кадров не может превышать Int.max
            return false
        }

        let layer = Layer(lines: [])
        layers.append(layer)
        undoManager.registerUndo(withTarget: self, selector: #selector(undoAddLayer), object: nil)
        return true
    }

    /// This method may fail, due to number of layers limit
    func insertLayer(_ layer: Layer, at index: Int) -> Bool {
        insertLayer(
            InsertOptions(layer: layer, index: index)
        )
    }

    func removeLayer() {
        removeLayerAtIndex((layers.endIndex - 1) as NSNumber)
    }

    func removeLayer(at index: Int) {
        removeLayerAtIndex(index as NSNumber)
    }

    @objc func removeAllLayers() {
        let removed = layers
        layers.removeAll(keepingCapacity: true)
        layers.append(Layer(lines: []))
        undoManager.registerUndo(withTarget: self, selector: #selector(undoRemoveAll), object: removed)
    }

    func moveLayers(from source: Int, to destination: Int) {
        let layer = layers.remove(at: source)
        layers.insert(layer, at: destination)
        undoManager.registerUndo(withTarget: self, selector: #selector(undoMoveLayers), object: MoveOptions(source: destination, destination: source))
    }

    func lastLayer() -> Layer {
        // Just in case. Manager always should contains at least 1 layer
        layers.last ?? Layer(lines: [])
    }

    func previousLayer() -> Layer? {
        layers[safe: layers.endIndex - 2]
    }

    func allLayers() -> [Layer] {
        return layers
    }

    // MARK: - Undo & Redo

    func canUndo() -> Bool {
        undoManager.canUndo
    }

    func canRedo() -> Bool {
        undoManager.canRedo
    }

    func undo() {
        undoManager.undo()
    }

    func redo() {
        undoManager.redo()
    }
}

private extension LayerManager {

    @objc func insertLayer(_ options: InsertOptions) -> Bool {
        if layers.count == Int.max {
            return false
        }

        layers.insert(options.layer, at: options.index)
        undoManager.registerUndo(withTarget: self, selector: #selector(undoInsertLayer), object: options.index as NSNumber)
        return true
    }

    @objc func removeLayerAtIndex(_ index: NSNumber) {
        var firstLayerRemoved = false
        let layer = layers.remove(at: index.intValue)

        if layers.isEmpty {
            firstLayerRemoved = true
            layers.append(Layer(lines: []))
        }

        undoManager.registerUndo(withTarget: self, selector: #selector(undoRemoveLayer), object: UndoRemove(
            shouldRemoveFirstLayer: firstLayerRemoved,
            layer: layer,
            index: index.intValue
        ))
    }
}

// MARK: - Undo & Redo

@objc
private extension LayerManager {

    func undoEndLine() {
        let line = layers.last?.popLine()
        undoManager.registerUndo(withTarget: self, selector: #selector(redoEndLine), object: line)
    }

    func redoEndLine(_ line: Line?) {
        line.map { layers.last?.pushLine($0) }
        undoManager.registerUndo(withTarget: self, selector: #selector(undoEndLine), object: nil)
    }

    func undoAddLayer() {
        layers.removeLast()
        undoManager.registerUndo(withTarget: self, selector: #selector(addLayer), object: nil)
    }

    func undoInsertLayer(_ index: NSNumber) {
        let layer = layers.remove(at: index.intValue)
        undoManager.registerUndo(withTarget: self, selector: #selector(insertLayer(_:)), object: InsertOptions(layer: layer, index: index.intValue))
    }

    func undoRemoveLayer(_ options: UndoRemove) {
        if options.shouldRemoveFirstLayer {
            layers.removeFirst()
        }

        layers.insert(options.layer, at: options.index)
        undoManager.registerUndo(withTarget: self, selector: #selector(removeLayerAtIndex), object: options.index as NSNumber)
    }

    func undoMoveLayers(_ options: MoveOptions) {
        let layer = layers.remove(at: options.source)
        layers.insert(layer, at: options.destination)
        undoManager.registerUndo(withTarget: self, selector: #selector(undoMoveLayers), object: MoveOptions(source: options.destination, destination: options.source))
    }

    func undoRemoveAll(_ removed: [Layer]) {
        layers.removeAll(keepingCapacity: true)
        layers.append(contentsOf: removed)
        undoManager.registerUndo(withTarget: self, selector: #selector(removeAllLayers), object: nil)
    }

    final class InsertOptions: NSObject {
        let layer: Layer
        let index: Int

        init(layer: Layer, index: Int) {
            self.layer = layer
            self.index = index
        }
    }

    final class MoveOptions: NSObject {
        let source: Int
        let destination: Int

        init(source: Int, destination: Int) {
            self.source = source
            self.destination = destination
        }
    }

    final class UndoRemove: NSObject {
        let shouldRemoveFirstLayer: Bool
        let layer: Layer
        let index: Int

        init(shouldRemoveFirstLayer: Bool, layer: Layer, index: Int) {
            self.shouldRemoveFirstLayer = shouldRemoveFirstLayer
            self.layer = layer
            self.index = index
        }
    }
}

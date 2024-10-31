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
    private var currentIndex = 0

    // MARK: - Lines

    func startLine(settings: Line.Settings, stroke: Stroke) {
        let line = Line(stroke: stroke, settings: settings)
        layers[currentIndex].startDrawingLine(line)
    }

    func endLine() {
        let layer = layers[currentIndex]
        layer.takeDrawingLine()
        undoManager.registerUndo(withTarget: self, selector: #selector(undoEndLine), object: layer)
    }

    // MARK: - Layers

    /// This method may fail, due to number of layers limit
    func addLayer() -> Bool {
        if layers.count == Int.max {
            // Clause: Максимальное количество кадров не может превышать Int.max
            return false
        }

        registerUndo {
            let layer = Layer(lines: [])
            layers.insert(layer, at: currentIndex + 1)
            currentIndex += 1
        }

        return true
    }

    /// This method may fail, due to number of layers limit
    func insertLayer(_ layer: Layer, at index: Int) -> Bool {
        if layers.count == Int.max {
            return false
        }

        registerUndo {
            layers.insert(layer, at: index)
            if currentIndex >= index {
                currentIndex += 1
            }
        }

        return true
    }

    func removeLayer() {
        registerUndo {
            layers.remove(at: currentIndex)

            if layers.isEmpty {
                assert(currentIndex == 0)
                layers.append(Layer(lines: []))
            } else {
                currentIndex -= 1
            }
        }
    }

    func removeLayer(at index: Int) {
        registerUndo {
            layers.remove(at: index)

            if layers.isEmpty {
                assert(currentIndex == 0)
                layers.append(Layer(lines: []))
            } else {
                let hasAnotherLayers = currentIndex - 1 >= 0
                if hasAnotherLayers && currentIndex >= index {
                    currentIndex -= 1
                }
            }
        }
    }

    func removeAllLayers() {
        registerUndo {
            layers.removeAll(keepingCapacity: true)
            layers.append(Layer(lines: []))
            currentIndex = 0
        }
    }

    func moveLayers(from source: Int, to destination: Int) {
        registerUndo {
            let layer = layers.remove(at: source)
            layers.insert(layer, at: destination)
            
            let current = currentIndex

            if current == source {
                currentIndex = destination
            } else if source < destination, current > source, current <= destination {
                currentIndex -= 1
            } else if destination < source, current >= destination, current < source {
                currentIndex += 1
            }
        }
    }

    func selectLayer(at index: Int) {
        currentIndex = index
    }

    func currentLayer() -> Layer {
        layers[currentIndex]
    }

    func previousLayer() -> Layer? {
        layers[safe: currentIndex - 1]
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

// MARK: - Undo & Redo

@objc
private extension LayerManager {

    func undoEndLine(_ layer: Layer) {
        let line = layer.popLine()
        undoManager.registerUndo(withTarget: self, selector: #selector(redoEndLine), object: EndLineOptions(layer: layer, line: line))
    }

    func redoEndLine(_ options: EndLineOptions) {
        options.line.map { options.layer.pushLine($0) }
        undoManager.registerUndo(withTarget: self, selector: #selector(undoEndLine), object: options.layer)
    }

    func undoSnapshot(_ snapshot: Snapshot) {
        registerUndo {
            layers = snapshot.layers
            currentIndex = snapshot.currentIndex
        }
    }

    func registerUndo(_ action: () -> Void) {
        let snapshot = Snapshot(layers: layers, currentIndex: currentIndex)
        action()
        undoManager.registerUndo(withTarget: self, selector: #selector(undoSnapshot), object: snapshot)
    }

    final class EndLineOptions: NSObject {
        let layer: Layer
        let line: Line?

        init(layer: Layer, line: Line?) {
            self.layer = layer
            self.line = line
        }
    }

    final class Snapshot: NSObject {
        let layers: [Layer]
        let currentIndex: Int

        init(layers: [Layer], currentIndex: Int) {
            self.layers = layers
            self.currentIndex = currentIndex
        }
    }
}

//
//  AnimaticViewController.swift
//  AnimationCompose
//
//  Created by Sorokin Igor on 29.10.2024.
//

import UIKit

final class AnimaticCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var tipView: UIView!
    @IBOutlet weak var moreButton: UIButton!
    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet weak var drawingView: DrawingView!
}

final class AnimaticViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    @IBOutlet private weak var collectionView: UICollectionView!
    @IBOutlet private weak var removeBarButton: UIBarButtonItem!

    private let layerManager: LayerManager = .shared
    private var cellSize: CGSize = .zero

    var onDismiss: (() -> Void)?
    var canvas: CGRect = .zero

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.contentInset = UIEdgeInsets(
            top: Constants.padding,
            left: Constants.padding,
            bottom: 0,
            right: Constants.padding
        )

        collectionView.dataSource = self
        collectionView.delegate = self

        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        recognizer.minimumPressDuration = 0.2
        collectionView.addGestureRecognizer(recognizer)

        removeBarButton.menu = UIMenu(children: [
            UIAction(title: "Удалить все", image: UIImage(systemName: "xmark"), attributes: .destructive, handler: { [weak self] _ in
                self?.layerManager.removeAllLayers()
                self?.collectionView.reloadData()
            })
        ])

        let ratio = canvas.height / canvas.width
        let availableWidth = UIScreen.main.bounds.width - Constants.padding * 2 - Constants.spacing
        let cellWidth = floor(availableWidth / 2)
        let cellHeight = cellWidth * ratio
        cellSize = .init(width: cellWidth, height: cellHeight)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.handleShowTip()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        handleShowTip()
    }

    @objc private func handleLongPress(_ sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            let location = sender.location(in: collectionView)
            if let indexPath = collectionView.indexPathForItem(at: location) {
                if indexPath.item == 0 {
                    handleShowTip()
                }
                collectionView.beginInteractiveMovementForItem(at: indexPath)
            }
        case .changed:
            let location = sender.location(in: collectionView)
            collectionView.updateInteractiveMovementTargetPosition(location)
        case .ended:
            collectionView.endInteractiveMovement()
        default:
            collectionView.cancelInteractiveMovement()
        }
    }

    @IBAction private func closeTapped(_ sender: UIBarButtonItem) {
        onDismiss?()
        dismiss(animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return layerManager.allLayers().count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as? AnimaticCollectionViewCell else {
            return UICollectionViewCell()
        }

        let layer = layerManager.allLayers()[indexPath.item]

        cell.numberLabel.text = "\(indexPath.item + 1)"
        cell.drawingView.relativeToCanvas = canvas
        cell.drawingView.drawingLayer = layer
        cell.tipView.isHidden = !shouldShowTip(for: indexPath)

        cell.moreButton.menu = UIMenu(children: [
            UIAction(title: "Дублировать", image: UIImage(systemName: "square.2.layers.3d"), handler: { [weak self] _ in
                guard let self else {
                    return
                }

                let newLayer = Layer(layer: layer)
                let newIndexPath = IndexPath(item: indexPath.item + 1, section: indexPath.section)
                // TODO: not ignore error
                _ = layerManager.insertLayer(newLayer, at: newIndexPath.item)
                collectionView.insertItems(at: [newIndexPath])

                let fromIndexPath = IndexPath(item: newIndexPath.item + 1, section: 0)
                let toIndexPath = IndexPath(item: layerManager.allLayers().count - 1, section: 0)
                reconfigureCells(from: fromIndexPath, to: toIndexPath)
            }),
            UIAction(title: "Удалить", image: UIImage(systemName: "xmark"), attributes: .destructive, handler: { [weak self] _ in
                guard let self else {
                    return
                }

                layerManager.removeLayer(at: indexPath.item)
                let layers = layerManager.allLayers()

                if layers.count == 1 {
                    self.collectionView.reloadData()
                } else {
                    let toIndexPath = IndexPath(item: layers.count - 1, section: 0)
                    collectionView.deleteItems(at: [indexPath])
                    reconfigureCells(from: indexPath, to: toIndexPath)
                }
            })
        ])

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        return true
    }

    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        layerManager.moveLayers(from: sourceIndexPath.item, to: destinationIndexPath.item)

        let source = min(sourceIndexPath, destinationIndexPath)
        let destination = max(sourceIndexPath, destinationIndexPath)

        reconfigureCells(from: source, to: destination)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return cellSize
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return Constants.spacing
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return Constants.spacing
    }

    // Reconfigure all cells between source and destination to invalidate their menus
    private func reconfigureCells(from fromIndexPath: IndexPath, to toIndexPath: IndexPath) {
        let indexPaths = stride(
            from: fromIndexPath.item,
            through: toIndexPath.item,
            by: 1
        ).map { IndexPath(item: $0, section: 0) }

        collectionView.reconfigureItems(at: indexPaths)
    }

    private func shouldShowTip(for indexPath: IndexPath) -> Bool {
        indexPath.item == 0 && !UserDefaults.standard.bool(forKey: Constants.showTipKey)
    }

    private func handleShowTip() {
        let cell = collectionView.cellForItem(at: IndexPath(item: 0, section: 0)) as? AnimaticCollectionViewCell
        UIView.animate(withDuration: 0.3, animations: {
            cell?.tipView.alpha = 0
        }, completion: { _ in
            cell?.tipView.isHidden = true
        })
        UserDefaults.standard.setValue(true, forKey: Constants.showTipKey)
    }

    private enum Constants {
        static let padding: CGFloat = 16
        static let spacing: CGFloat = 16
        static let showTipKey = "animation.compose.show-tip"
    }
}
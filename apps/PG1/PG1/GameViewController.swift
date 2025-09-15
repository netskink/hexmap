//
//  GameViewController.swift
//  PG1
//
//  Created by john davis on 9/11/25.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Called after the view controller's view is loaded into memory.
        // This is a good place to configure the SKView and present the initial scene.
        
        if let view = self.view as! SKView? {
            // Load the SKScene from 'GameScene.sks'
            if let scene = SKScene(fileNamed: "GameScene") {
                // Set the scale mode to scale to fit the window
                scene.scaleMode = .aspectFill
                // Present the scene
                view.presentScene(scene)
            }
            
            // Rendering optimization: allows SpriteKit to reorder siblings
            // for performance as long as zPosition is respected.
            view.ignoresSiblingOrder = true
            
            // Debug overlays (OK for development; disable for release).
            view.showsFPS = true
            view.showsNodeCount = true
            
            // --- Gesture recognizers ---
            // Pinch to zoom the GameScene's `worldNode`.
            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            view.addGestureRecognizer(pinchGesture)
            
            // Pan to move the GameScene's `worldNode`.
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            view.addGestureRecognizer(panGesture)        }
    }
    
    /// Supported orientations. On iPhone, everything except upside down.
    /// On iPad, allow all orientations.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }
    
    /// Hide the status bar for a full-screen game experience.
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    
    /// Pinch gesture handler.
    /// Adjusts the scale of `scene.worldNode` with clamping to prevent
    @objc func handlePinch(_ sender: UIPinchGestureRecognizer) {
        guard let skView = self.view as? SKView,
              let scene = skView.scene as? GameScene,
              let baseMap = scene.baseMap,
              let camera = scene.camera else { return }

        let viewSize = skView.bounds.size
        let mapSize = baseMap.mapSize

        // Clamp minimum scale so the camera shows no more than 2/3 of map width
        let maxVisibleWidth = mapSize.width * (2.0 / 3.0)
        let minScale = viewSize.width / maxVisibleWidth

        // Optional: clamp max zoom-in
        let maxScale: CGFloat = 2.0

        // Apply relative zoom
        if sender.state == .changed || sender.state == .ended {
            let scale = 1 / sender.scale
            let newScale = camera.xScale * scale
            let clampedScale = min(max(newScale, minScale), maxScale)
            camera.setScale(clampedScale)
            sender.scale = 1.0
        }
        
        // ✅ Critical to keep map visually centered and within bounds
        //clampWorldNode(scene: scene, viewSize: viewSize)
        
        //print("New scale: \(newScale), Clamped: \(clampedScale), Min: \(minScale)")

    }
    
    /// Pan gesture handler.
    /// Translates `scene.worldNode` by the touch movement. Note the Y-axis
    /// is inverted in UIKit view space, so we subtract `translation.y`.
    @objc func handlePan(_ sender: UIPanGestureRecognizer) {
        guard let skView = self.view as? SKView,
              let scene = skView.scene as? GameScene,
              let baseMap = scene.baseMap,
              let camera = scene.camera else { return }

        let translation = sender.translation(in: skView)
        sender.setTranslation(.zero, in: skView)

        // Adjust for zoom and UIKit/SpriteKit Y-axis flip
        let adjustedTranslation = CGPoint(
            x: translation.x / scene.worldNode.xScale,
            y: -translation.y / scene.worldNode.yScale
        )

        // Move the world node
        let newWorldPosition = CGPoint(
            x: scene.worldNode.position.x + adjustedTranslation.x,
            y: scene.worldNode.position.y + adjustedTranslation.y
        )
        scene.worldNode.position = newWorldPosition

        // Calculate the map frame relative to the scene
        let baseMapFrameInScene = baseMap.convert(baseMap.calculateAccumulatedFrame(), to: scene)

        let viewSize = skView.bounds.size
        let scale = scene.worldNode.xScale

        let halfViewWidth = viewSize.width / 2 / scale
        let halfViewHeight = viewSize.height / 2 / scale
        let verticalBuffer: CGFloat = 10

        // Determine clamping boundaries for worldNode based on baseMap's frame inside scene
        let minX = -(baseMapFrameInScene.maxX - halfViewWidth)
        let maxX = -(baseMapFrameInScene.minX - halfViewWidth)
        let minY = -(baseMapFrameInScene.maxY - halfViewHeight + verticalBuffer)
        let maxY = -(baseMapFrameInScene.minY - halfViewHeight - verticalBuffer)

        var pos = scene.worldNode.position

        // Apply edge resistance when dragging
        if sender.state == .changed {
            let resistanceFactor: CGFloat = 0.4

            if pos.x < minX {
                pos.x += (minX - pos.x) * resistanceFactor
            } else if pos.x > maxX {
                pos.x -= (pos.x - maxX) * resistanceFactor
            }

            if pos.y < minY {
                pos.y += (minY - pos.y) * resistanceFactor
            } else if pos.y > maxY {
                pos.y -= (pos.y - maxY) * resistanceFactor
            }

            scene.worldNode.position = pos
        }

        // Snap back when released
        if sender.state == .ended || sender.state == .cancelled {
            pos.x = max(min(pos.x, maxX), minX)
            pos.y = max(min(pos.y, maxY), minY)

            let snapBack = SKAction.move(to: pos, duration: 0.25)
            snapBack.timingMode = .easeOut
            scene.worldNode.run(snapBack)
        }
    }
    


}

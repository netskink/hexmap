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
        scene.worldNode.position = CGPoint(
            x: scene.worldNode.position.x + adjustedTranslation.x,
            y: scene.worldNode.position.y + adjustedTranslation.y
        )

        // Compute camera viewport size in worldNode space
        let viewSize = skView.bounds.size
        let scale = camera.xScale
        let halfViewWidth = viewSize.width / 2 / scale
        let halfViewHeight = viewSize.height / 2 / scale

        // Compute the camera's visible rect in worldNode space
        let visibleRect = CGRect(
            x: -halfViewWidth - scene.worldNode.position.x,
            y: -halfViewHeight - scene.worldNode.position.y,
            width: halfViewWidth * 2,
            height: halfViewHeight * 2
        )

        // Map bounds in worldNode space
        let mapBounds = baseMap.calculateAccumulatedFrame()

        // Apply tile-size buffer to shrink clampable area
        let tileBufferWidth: CGFloat = 128 * 1.5
        let tileBufferHeight: CGFloat = 111 * 1

        let mapLeft = mapBounds.minX + tileBufferWidth
        let mapRight = mapBounds.maxX - tileBufferWidth
        let mapBottom = mapBounds.minY + tileBufferHeight
        let mapTop = mapBounds.maxY - tileBufferHeight

        var newPosition = scene.worldNode.position

        // Clamp horizontal
        if visibleRect.minX < mapLeft {
            newPosition.x = -(mapLeft + halfViewWidth)
        } else if visibleRect.maxX > mapRight {
            newPosition.x = -(mapRight - halfViewWidth)
        }

        // Clamp vertical
        if visibleRect.minY < mapBottom {
            newPosition.y = -(mapBottom + halfViewHeight)
        } else if visibleRect.maxY > mapTop {
            newPosition.y = -(mapTop - halfViewHeight)
        }

        // Apply position with or without animation
        if sender.state == .ended || sender.state == .cancelled {
            let snap = SKAction.move(to: newPosition, duration: 0.25)
            snap.timingMode = .easeOut
            scene.worldNode.run(snap)
        } else {
            scene.worldNode.position = newPosition
        }

        // === PAN DEBUG LOGGING ===
        print("==== PAN DEBUG ====")
        print("worldNode.position: \(scene.worldNode.position)")
        print("camera.position: \(camera.position)")
        print("baseMap.position: \(baseMap.position)")
        print("baseMap.frame: \(baseMap.frame)")

        let sceneFrameDebug = baseMap.convert(baseMap.frame, to: scene)
        print("baseMap.frame (converted to scene): \(sceneFrameDebug)")

        let worldFrame = baseMap.convert(baseMap.frame, to: scene.worldNode)
        print("baseMap.frame (converted to worldNode): \(worldFrame)")

        print("view size (screen points): \(viewSize)")
        print("====================")
    }
    


}

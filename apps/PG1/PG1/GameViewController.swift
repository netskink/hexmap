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
    /// excessive zoom in/out. Uses the recognizer's incremental `scale`
    /// (reset to 1.0 each time) to apply smooth relative zooming.
    @objc func handlePinch(_ sender: UIPinchGestureRecognizer) {
        guard let skView = self.view as? SKView,
              let scene = skView.scene as? GameScene,
              let baseMap = scene.baseMap else { return }
        
        let viewSize = skView.bounds.size
        let mapSize = baseMap.mapSize
        
        let minScaleX = viewSize.width / mapSize.width
        let minScaleY = viewSize.height / mapSize.height
        
        // limit zoom to 2/3 of map width
        let maxVisibleWidth = mapSize.width * (2.0 / 3.0)
        let minScale = viewSize.width / maxVisibleWidth
        let maxScale: CGFloat = 2.0
        
        
        let adjustedMinScale = minScale * 0.9 // Allow zoom out slightly, or remove if unwanted
        
        let newScale = scene.worldNode.xScale * sender.scale
        let clampedScale = max(adjustedMinScale, min(newScale, maxScale))
        
        scene.worldNode.setScale(clampedScale)
        sender.scale = 1.0
        
        // ✅ Critical to keep map visually centered and within bounds
        clampWorldNode(scene: scene, viewSize: viewSize)
        
        print("New scale: \(newScale), Clamped: \(clampedScale), Min: \(minScale)")
    }
    
    
    /// Pan gesture handler.
    /// Translates `scene.worldNode` by the touch movement. Note the Y-axis
    /// is inverted in UIKit view space, so we subtract `translation.y`.
    @objc func handlePan(_ sender: UIPanGestureRecognizer) {
        guard let skView = self.view as? SKView,
              let scene = skView.scene as? GameScene else { return }
        
        let translation = sender.translation(in: skView)
        let converted = CGPoint(x: translation.x / scene.worldNode.xScale,
                                y: -translation.y / scene.worldNode.yScale)
        
        scene.worldNode.position = scene.worldNode.position + converted
        sender.setTranslation(.zero, in: skView)
        
        // ✅ Clamp after panning
        if scene.baseMap != nil {
            clampWorldNode(scene: scene, viewSize: skView.bounds.size)
        }
        
        print("Pan translation: \(translation)")
        print("New worldNode position: \(scene.worldNode.position)")
    }
    
//    func clampWorldNode(scene: GameScene, viewSize: CGSize) {
//        guard let baseMap = scene.baseMap else { return }
//        
//        let mapSize = baseMap.mapSize
//        let scale = scene.worldNode.xScale
//        
//        let scaledMapWidth = mapSize.width * scale
//        let scaledMapHeight = mapSize.height * scale
//        
//        let visibleWidth = viewSize.width
//        let visibleHeight = viewSize.height
//        
//        var clampX: CGFloat = 0
//        var clampY: CGFloat = 0
//        
//        if scaledMapWidth > visibleWidth {
//            clampX = (scaledMapWidth - visibleWidth) / 2
//        }
//        
//        if scaledMapHeight > visibleHeight {
//            clampY = (scaledMapHeight - visibleHeight) / 2
//        }
//        
//        var newPosition = scene.worldNode.position
//        newPosition.x = min(max(newPosition.x, -clampX), clampX)
//        newPosition.y = min(max(newPosition.y, -clampY), clampY)
//        
//        // Center if clamping is not needed
//        if clampX == 0 { newPosition.x = 0 }
//        if clampY == 0 { newPosition.y = 0 }
//        
//        scene.worldNode.position = newPosition
//        
//        print("Clamping:")
//        print("- MapSize: \(mapSize), ViewSize: \(viewSize)")
//        print("- Scale: \(scale)")
//        print("- ScaledMap: (\(scaledMapWidth), \(scaledMapHeight))")
//        print("- ClampX: \(clampX), ClampY: \(clampY)")
//        print("Clamped position: \(scene.worldNode.position)")
//    }

    func clampWorldNode(scene: GameScene, viewSize: CGSize) {
        guard let baseMap = scene.baseMap else { return }

        let mapSize = baseMap.mapSize
        let scale = scene.worldNode.xScale

        let halfVisibleWidth = viewSize.width / 2 / scale
        let halfVisibleHeight = viewSize.height / 2 / scale

        let halfMapWidth = mapSize.width / 2
        let halfMapHeight = mapSize.height / 2

        // Compute the max allowed displacement of the worldNode (from center)
        // so that we don't scroll beyond map edges
        let minX = -halfMapWidth + halfVisibleWidth
        let maxX =  halfMapWidth - halfVisibleWidth
        let minY = -halfMapHeight + halfVisibleHeight
        let maxY =  halfMapHeight - halfVisibleHeight

        var pos = scene.worldNode.position
        pos.x = max(minX, min(pos.x, maxX))
        pos.y = max(minY, min(pos.y, maxY))
        scene.worldNode.position = pos

        print("Clamping:")
        print("- MapSize: \(mapSize), ViewSize: \(viewSize)")
        print("- Scale: \(scale)")
        print("- Half Visible: (\(halfVisibleWidth), \(halfVisibleHeight))")
        print("- WorldNode Position: \(scene.worldNode.position)")
    }
    

}

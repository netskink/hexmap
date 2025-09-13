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

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    
    /// Pinch gesture handler.
    /// Adjusts the scale of `scene.worldNode` with clamping to prevent
    /// excessive zoom in/out. Uses the recognizer's incremental `scale`
    /// (reset to 1.0 each time) to apply smooth relative zooming.
    @objc func handlePinch(_ sender: UIPinchGestureRecognizer) {
        guard let view = self.view as? SKView,
              let scene = view.scene as? GameScene else { return }

        if sender.state == .changed || sender.state == .began {
            // Compute new target scale from current xScale and the pinch delta.
            let newScale = scene.worldNode.xScale * sender.scale
            // Clamp zoom level between 0.5x and 2.0x to keep the map usable.
            let clampedScale = max(0.5, min(newScale, 2.0))
            scene.worldNode.setScale(clampedScale)
            // Reset so future deltas are incremental from the new scale.
            sender.scale = 1.0
        }
    }

    @objc func handlePan(_ sender: UIPanGestureRecognizer) {
        guard let view = self.view as? SKView,
              let scene = view.scene as? GameScene else { return }

        let translation = sender.translation(in: view)
        scene.worldNode.position.x += translation.x
        scene.worldNode.position.y -= translation.y // Flip Y-axis
        sender.setTranslation(.zero, in: view)
    }

}

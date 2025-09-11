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
        
        if let view = self.view as! SKView? {
            // Load the SKScene from 'GameScene.sks'
            if let scene = SKScene(fileNamed: "GameScene") {
                // Set the scale mode to scale to fit the window
                scene.scaleMode = .aspectFill
                
                // Present the scene
                view.presentScene(scene)
            }
            
            view.ignoresSiblingOrder = true
            
            view.showsFPS = true
            view.showsNodeCount = true
            
            // Add gesture recognizers
            let pinchGesture = UIPinchGestureRecognizer(target: self,
                                               action: #selector(handlePinch(_:)))
            view.addGestureRecognizer(pinchGesture)

            let panGesture = UIPanGestureRecognizer(target: self,
                                            action: #selector(handlePan(_:)))
            view.addGestureRecognizer(panGesture)
            
        }
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
    
    
    @objc func handlePinch(_ sender: UIPinchGestureRecognizer) {
        guard let view = self.view as? SKView,
             let scene = view.scene as? GameScene else { return }

        if sender.state == .changed || sender.state == .began {
            let newScale = scene.worldNode.xScale * sender.scale
            let clampedScale = max(0.5, min(newScale, 2.0)) // Limit zoom
            scene.worldNode.setScale(clampedScale)
            sender.scale = 1.0 // reset scale delta
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

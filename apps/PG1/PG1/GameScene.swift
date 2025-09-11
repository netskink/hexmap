//
//  GameScene.swift
//  PG1
//
//  Created by john davis on 9/11/25.
//

import SpriteKit
import GameplayKit

class GameScene: SKScene {
    
    // Reference to the World node from the SKS file
    var worldNode: SKNode!

    override func didMove(to view: SKView) {
        // Find the node by name
        worldNode = childNode(withName: "World")

        // Optional: Center world if needed
        //if worldNode.parent == self {
        //    worldNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        //}
    }
}

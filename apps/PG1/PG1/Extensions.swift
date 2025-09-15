//
//  Extensions.swift
//  PG1
//
//  Created by john davis on 9/14/25.
//

import CoreGraphics

extension CGPoint {
    static func + (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x + right.x, y: left.y + right.y)
    }
}


import SpriteKit
import GameplayKit


// Used to debug visible layou
func drawFrameBox(theNode: SKNode, in scene: GameScene, color: SKColor = .red) {
    
    if let oldBox = scene.worldNode.childNode(withName: "FrameBox") {
        oldBox.removeFromParent()
    }
    
    // This works for basemap node sinze it has space.  It fails for world node since its an empty
    // node.
    //let nodeSize = theNode.frame.size
    //
    // This works for the union of all child frames
    let nodeSize: CGSize
    if theNode.frame.size == .zero {
        let bounds = theNode.calculateAccumulatedFrame()
        nodeSize = bounds.size
    } else {
        nodeSize = theNode.frame.size
    }

    
    let box = SKShapeNode(rectOf: nodeSize)
    // Set the box’s position to match theNode.position in the same coordinate space (worldNode):
    // Assumes the sprite is a direct child of scene.worldnode
    // if not use convert
    // let positionInWorld = theNode.parent?.convert(theNode.position, to: scene.worldNode) ?? .zero
    // box.position = positionInWorld
    box.position = theNode.position // assumes direct child
    
    box.strokeColor = color
    box.lineWidth = 2
    box.name = "FrameBox"
    box.zPosition = 9999
    scene.worldNode.addChild(box)
}

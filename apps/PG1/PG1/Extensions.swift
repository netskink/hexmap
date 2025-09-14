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

func drawFrameBox(mapSize: CGSize, in scene: GameScene) {
    if let oldBox = scene.worldNode.childNode(withName: "FrameBox") {
        oldBox.removeFromParent()
    }

    let box = SKShapeNode(rectOf: mapSize)
    box.strokeColor = .red
    box.lineWidth = 2
    box.name = "FrameBox"
    box.zPosition = 9999
    scene.worldNode.addChild(box)
}

//
//  DebugUI.swift
//  SceneEditor2
//
//  Created by john davis on 9/5/25.
//

import Foundation
import SpriteKit

#if DEBUG
final class TouchVisualizer: SKNode {
    func show(at point: CGPoint, in parent: SKNode) {
        let circle = SKShapeNode(circleOfRadius: 20)
        circle.fillColor = .systemBlue.withAlphaComponent(0.4)
        circle.strokeColor = .clear
        circle.position = point
        circle.zPosition = 10_000
        parent.addChild(circle)

        circle.run(.sequence([
            .group([.fadeOut(withDuration: 0.5),
                    .scale(to: 2.0, duration: 0.5)]),
            .removeFromParent()
        ]))
    }
}
#endif

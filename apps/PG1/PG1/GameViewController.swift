import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {
    
    private var screenDot1: UIView?
    private var screenDot2: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        

        if let view = self.view as? SKView {
            if let scene = SKScene(fileNamed: "GameScene") as? GameScene {
                scene.scaleMode = .aspectFill
                view.presentScene(scene)

                // Add gesture recognizers
                let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
                view.addGestureRecognizer(panRecognizer)

                let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
                view.addGestureRecognizer(pinchRecognizer)
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        addScreenDebugDot()
        positionScreenDebugDot()
    }

    @objc func handlePan(_ sender: UIPanGestureRecognizer) {
        guard let skView = self.view as? SKView,
              let scene = skView.scene as? GameScene else { return }

        let translation = sender.translation(in: skView)
        sender.setTranslation(.zero, in: skView)

        scene.worldNode.position.x += translation.x
        scene.worldNode.position.y -= translation.y

        if sender.state == .ended || sender.state == .cancelled {
            let snap = SKAction.move(to: scene.worldNode.position, duration: 0.25)
            snap.timingMode = .easeOut
            scene.worldNode.run(snap)
        } else {
            clampWorldNode(scene: scene)
        }
    }

    @objc func handlePinch(_ sender: UIPinchGestureRecognizer) {
        guard let skView = self.view as? SKView,
              let scene = skView.scene as? GameScene,
              let camera = scene.camera else { return }

        if sender.state == .changed {
            let newScale = camera.xScale / sender.scale
            let clampedScale = max(0.2, min(newScale, 2.0))
            camera.setScale(clampedScale)
            sender.scale = 1.0
            clampWorldNode(scene: scene)
        }
    }

    private func positionScreenDebugDot() {
        guard let skView = self.view as? SKView,
              let dot1 = self.screenDot1,
              let dot2 = self.screenDot2 else { return }

        // Respect safe area so it isn't hidden under a nav bar/notch
        let insets = skView.safeAreaInsets
        let origin1 = CGPoint(x: insets.left + 10, y: insets.top + 10)
        dot1.frame.origin = origin1
        let origin2 = CGPoint(x: insets.left + 100, y: insets.top + 100)
        dot2.frame.origin = origin2

        // Make sure it's above SpriteKit's content and any gesture overlays
        skView.bringSubviewToFront(dot1)
        skView.bringSubviewToFront(dot2)
    }

    func clampWorldNode(scene: GameScene) {
        guard let skView = self.view as? SKView,
              let baseMap = scene.baseMap,
              let camera = scene.camera else { return }

        let viewSize = skView.bounds.size
        let scale = camera.xScale
        let halfViewWidth = viewSize.width / CGFloat(2.0) / scale
        let halfViewHeight = viewSize.height / CGFloat(2.0) / scale

        let tileBufferWidth: CGFloat = CGFloat(128) * 1.5
        let tileBufferHeight: CGFloat = CGFloat(111) * 1.0

        let mapBounds = baseMap.calculateAccumulatedFrame()
        let mapLeft = mapBounds.minX + tileBufferWidth
        let mapRight = mapBounds.maxX - tileBufferWidth
        let mapBottom = mapBounds.minY + tileBufferHeight
        let mapTop = mapBounds.maxY - tileBufferHeight

        // Calculate new camera viewport edges in worldNode coordinates
        var newPosition = scene.worldNode.position

        let visibleLeft = -halfViewWidth - newPosition.x
        let visibleRight = halfViewWidth - newPosition.x
        let visibleBottom = -halfViewHeight - newPosition.y
        let visibleTop = halfViewHeight - newPosition.y

        if visibleLeft < mapLeft {
            newPosition.x = -(mapLeft + halfViewWidth)
        } else if visibleRight > mapRight {
            newPosition.x = -(mapRight - halfViewWidth)
        }

        if visibleBottom < mapBottom {
            newPosition.y = -(mapBottom + halfViewHeight)
        } else if visibleTop > mapTop {
            newPosition.y = -(mapTop - halfViewHeight)
        }

        scene.worldNode.position = newPosition
    }
    
    private func addScreenDebugDot() {
        guard let skView = self.view as? SKView else { return }

        // If already added, just re-position and return
        if let existing1 = self.screenDot1, skView.subviews.contains(existing1) {
            positionScreenDebugDot()
            return
        }
        if let existing2 = self.screenDot2, skView.subviews.contains(existing2) {
            positionScreenDebugDot()
            return
        }

        let size: CGFloat = 14
        let dot1 = UIView(frame: CGRect(origin: .zero, size: CGSize(width: size, height: size)))
        dot1.backgroundColor = .systemGreen
        dot1.layer.cornerRadius = size / 2
        dot1.isUserInteractionEnabled = false
        dot1.layer.borderWidth = 1
        dot1.layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
        dot1.layer.shadowColor = UIColor.black.cgColor
        dot1.layer.shadowOpacity = 0.35
        dot1.layer.shadowRadius = 2
        dot1.layer.shadowOffset = CGSize(width: 0, height: 1)

        skView.addSubview(dot1)
        self.screenDot1 = dot1

        let dot2 = UIView(frame: CGRect(origin: .zero, size: CGSize(width: size, height: size)))
        dot2.backgroundColor = .systemBlue
        dot2.layer.cornerRadius = size / 2
        dot2.isUserInteractionEnabled = false
        dot2.layer.borderWidth = 1
        dot2.layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
        dot2.layer.shadowColor = UIColor.black.cgColor
        dot2.layer.shadowOpacity = 0.35
        dot2.layer.shadowRadius = 2
        dot2.layer.shadowOffset = CGSize(width: 0, height: 1)

        skView.addSubview(dot2)
        self.screenDot2 = dot2

        positionScreenDebugDot()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        positionScreenDebugDot()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        positionScreenDebugDot()
    }
}

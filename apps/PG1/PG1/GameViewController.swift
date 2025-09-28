import UIKit
import SpriteKit
import GameplayKit


class GameViewController: UIViewController {
    
    private var screenDot1: UIView?
    private var screenDot2: UIView?
    
    // GameViewController.swift
    private var cornerTL: UILabel?
    private var cornerTR: UILabel?
    private var cornerBR: UILabel?
    private var cornerBL: UILabel?

    
    private var sceneTL: CGPoint = .zero
    private var sceneTR: CGPoint = .zero
    private var sceneBR: CGPoint = .zero
    private var sceneBL: CGPoint = .zero
    
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
    
    private func setupCornerHUD() {
        guard let skView = self.view as? SKView else { return }

        func makeLabel() -> UILabel {
            let l = UILabel()
            l.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            l.textColor = .white
            l.backgroundColor = UIColor.black.withAlphaComponent(0.5)

            l.numberOfLines = 0             // <-- allow unlimited lines
            l.lineBreakMode = .byClipping // <-- clip text. no wrapping

            l.textAlignment = .center
            l.layer.cornerRadius = 6
            l.layer.masksToBounds = true
            l.isUserInteractionEnabled = false
            return l
        }
        
        
        if cornerTL == nil { cornerTL = makeLabel(); skView.addSubview(cornerTL!) }
        if cornerTR == nil { cornerTR = makeLabel(); skView.addSubview(cornerTR!) }
        if cornerBR == nil { cornerBR = makeLabel(); skView.addSubview(cornerBR!) }
        if cornerBL == nil { cornerBL = makeLabel(); skView.addSubview(cornerBL!) }

        updateCornerHUD()   // set initial text & frames
        // ensure above SpriteKit content
        [cornerTL, cornerTR, cornerBR, cornerBL].compactMap{$0}.forEach { skView.bringSubviewToFront($0) }
    }
    
    
    /// Compute a snug size for a multi-line, non-wrapping label.
    private func sizeForMultilineLabel(text: String, font: UIFont, padding: CGSize = CGSize(width: 12, height: 6)) -> CGSize {
        let lines = text.components(separatedBy: "\n")
        var maxWidth: CGFloat = 0
        
        
        for line in lines {
            let w = (line as NSString).size(withAttributes: [.font: font]).width
            if w > maxWidth { maxWidth = w }
        }
        let height = font.lineHeight * CGFloat(max(1, lines.count)) + padding.height
        return CGSize(width: maxWidth + padding.width, height: height)
    }
    
    private func makeCornerLabelText(viewLine: String, sceneLine: String, sceneViewLine: String) -> NSAttributedString {
        let fullText = viewLine + "\n" + sceneLine + "\n" + sceneViewLine
        let attr = NSMutableAttributedString(string: fullText)
        let font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        attr.addAttributes([.font: font, .paragraphStyle: paragraph, .foregroundColor: UIColor.white],
                           range: NSRange(location: 0, length: (viewLine as NSString).length))
        let sceneRange = NSRange(location: (viewLine as NSString).length + 1,
                                 length: (sceneLine as NSString).length)
        attr.addAttributes([.font: font, .paragraphStyle: paragraph, .foregroundColor: UIColor.systemTeal],
                           range: sceneRange)
        let sceneViewRange = NSRange(location: (viewLine as NSString).length + 1 + (sceneLine as NSString).length + 1,
                                     length: (sceneViewLine as NSString).length)
        attr.addAttributes([.font: font, .paragraphStyle: paragraph, .foregroundColor: UIColor.white],
                           range: sceneViewRange)
        return attr
    }
    
    @objc private func handleWorldCorners(_ note: Notification) {
        guard let tl = (note.userInfo?["tl"] as? NSValue)?.cgPointValue,
              let tr = (note.userInfo?["tr"] as? NSValue)?.cgPointValue,
              let br = (note.userInfo?["br"] as? NSValue)?.cgPointValue,
              let bl = (note.userInfo?["bl"] as? NSValue)?.cgPointValue else {
            return
        }
        sceneTL = tl
        sceneTR = tr
        sceneBR = br
        sceneBL = bl
        updateCornerHUD()
    }
    
    
    
    // This computes w,h from the SKView’s bounds (UIKit coords), sets the label text to
    // those screen coordinates, and positions labels inside the safe area with a small margin.
    private func updateCornerHUD() {
        guard let skView = self.view as? SKView,
              let tl = cornerTL, let tr = cornerTR, let br = cornerBR, let bl = cornerBL
        else { return }

        let size = skView.bounds.size
        let w = size.width
        let h = size.height


        
        // Convert the latest scene-corner points to UIKit view coordinates (for third line)
        var tlSceneInView = CGPoint.zero
        var trSceneInView = CGPoint.zero
        var brSceneInView = CGPoint.zero
        var blSceneInView = CGPoint.zero
        if let scene = (self.view as? SKView)?.scene {
            tlSceneInView = scene.convertPoint(toView: sceneTL)
            trSceneInView = scene.convertPoint(toView: sceneTR)
            brSceneInView = scene.convertPoint(toView: sceneBR)
            blSceneInView = scene.convertPoint(toView: sceneBL)
        }
        
        
        // Three-line text per corner: line1=view, line2=scene (world bounds), line3=scene→view
        tl.attributedText = makeCornerLabelText(
            viewLine: String(format: "TL (0, 0) view"),
            sceneLine: String(format: "(%.1f, %.1f) scene", sceneTL.x, sceneTL.y),
            sceneViewLine: String(format: "(%.1f, %.1f) scene→view", tlSceneInView.x, tlSceneInView.y))
        tr.attributedText = makeCornerLabelText(
            viewLine: String(format: "TR (%.0f, 0) view", w),
            sceneLine: String(format: "(%.1f, %.1f) scene", sceneTR.x, sceneTR.y),
            sceneViewLine: String(format: "(%.1f, %.1f) scene→view", trSceneInView.x, trSceneInView.y))

        br.attributedText = makeCornerLabelText(
            viewLine: String(format: "BR (%.0f, %.0f) view", w, h),
            sceneLine: String(format: "(%.1f, %.1f) scene", sceneBR.x, sceneBR.y),
            sceneViewLine: String(format: "(%.1f, %.1f) scene→view", brSceneInView.x, brSceneInView.y))

        bl.attributedText = makeCornerLabelText(
            viewLine: String(format: "BL (0, %.0f) view", h),
            sceneLine: String(format: "(%.1f, %.1f) scene", sceneBL.x, sceneBL.y),
            sceneViewLine: String(format: "(%.1f, %.1f) scene→view", blSceneInView.x, blSceneInView.y))
        
        
        // Resize to fit the longest line exactly (no wrapping)
        tl.frame.size = sizeForMultilineLabel(text: tl.attributedText?.string ?? "", font: tl.font)
        tr.frame.size = sizeForMultilineLabel(text: tr.attributedText?.string ?? "", font: tr.font)
        br.frame.size = sizeForMultilineLabel(text: br.attributedText?.string ?? "", font: br.font)
        bl.frame.size = sizeForMultilineLabel(text: bl.attributedText?.string ?? "", font: bl.font)

        // Position at safe-area corners (unchanged)
        let inset = skView.safeAreaInsets
        let margin: CGFloat = 8

        tl.frame.origin = CGPoint(x: inset.left + margin,
                                  y: inset.top + margin)

        tr.frame.origin = CGPoint(x: w - inset.right - margin - tr.frame.width,
                                  y: inset.top + margin)

        br.frame.origin = CGPoint(x: w - inset.right - margin - br.frame.width,
                                  y: h - inset.bottom - margin - br.frame.height)

        bl.frame.origin = CGPoint(x: inset.left + margin,
                                  y: h - inset.bottom - margin - bl.frame.height)

        [tl, tr, br, bl].forEach { skView.bringSubviewToFront($0) }
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupCornerHUD()
        addScreenDebugDot()
        positionScreenDebugDot()
        
        NotificationCenter.default.addObserver(self,
                selector: #selector(handleWorldCorners(_:)),
                name: .worldCornersDidUpdate,
                object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    

    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCornerHUD()
        positionScreenDebugDot()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateCornerHUD()
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
        let origin1 = CGPoint(x: insets.left + 1, y: insets.top + 1)
        dot1.frame.origin = origin1
        let origin2 = CGPoint(x: insets.left + 70, y: insets.top + 70)
        dot2.frame.origin = origin2

        // Make sure it's above SpriteKit's content and any gesture overlays
        skView.bringSubviewToFront(dot1)
        skView.bringSubviewToFront(dot2)
    }

    func clampWorldNode(scene: GameScene) {
        return
        
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
        dot1.backgroundColor = .systemBackground
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
        dot2.backgroundColor = .systemGray
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

}

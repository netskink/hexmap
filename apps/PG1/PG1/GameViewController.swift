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
    private var cameraWHLabel: UILabel?
    /// Create/update a HUD label that shows the camera viewport size in scene units.
    private func updateCameraWHLabel() {
        guard let skView = self.view as? SKView,
              let scene = skView.scene as? GameScene,
              let cam = scene.camera else { return }

        // Create label if missing
        if cameraWHLabel == nil {
            let l = UILabel()
            l.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .medium)
            l.textColor = .white
            l.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            l.textAlignment = .center
            l.layer.cornerRadius = 6
            l.layer.masksToBounds = true
            l.isUserInteractionEnabled = false
            (self.view as? SKView)?.addSubview(l)
            cameraWHLabel = l
        }

        // Compute camera viewport size in SCENE units (resizeFill => 1pt == 1 scene unit pre-camera)
        let viewSize = skView.bounds.size
        let camW = viewSize.width  / cam.xScale
        let camH = viewSize.height / cam.yScale

        // Update text
        cameraWHLabel?.text = String(format: "camera %.0f×%.0f (scene units)", camW, camH)

        // Size label and position it at the top-center inside the safe area
        cameraWHLabel?.sizeToFit()
        let padX: CGFloat = 12
        let padY: CGFloat = 6
        if var f = cameraWHLabel?.frame {
            f.size.width  += padX
            f.size.height += padY
            let inset = skView.safeAreaInsets
            let x = (viewSize.width - f.size.width) * 0.5
            let y = inset.top + 8
            f.origin = CGPoint(x: x, y: y)
            cameraWHLabel?.frame = f
        }

        // Keep above SpriteKit content
        if let l = cameraWHLabel { skView.bringSubviewToFront(l) }
    }

    
    private var sceneTL: CGPoint = .zero
    private var sceneTR: CGPoint = .zero
    private var sceneBR: CGPoint = .zero
    private var sceneBL: CGPoint = .zero
    
    override func viewDidLoad() {
        super.viewDidLoad()
        

        if let view = self.view as? SKView {
            if let scene = SKScene(fileNamed: "GameScene") as? GameScene {
                scene.scaleMode = .resizeFill
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
    
    private func makeCornerLabelText(viewLine: String, sceneLine: String, sceneViewLine: String, camViewLine: String, camWorldLine: String) -> NSAttributedString {
        let fullText = viewLine + "\n" + sceneLine + "\n" + sceneViewLine + "\n" + camViewLine + "\n" + camWorldLine
        let attr = NSMutableAttributedString(string: fullText)
        let font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        // line 1 (view) - white
        let viewRange = NSRange(location: 0, length: (viewLine as NSString).length)
        attr.addAttributes([.font: font, .paragraphStyle: paragraph, .foregroundColor: UIColor.white], range: viewRange)

        // line 2 (scene) - teal
        let sceneRange = NSRange(location: viewRange.location + viewRange.length + 1, length: (sceneLine as NSString).length)
        attr.addAttributes([.font: font, .paragraphStyle: paragraph, .foregroundColor: UIColor.systemTeal], range: sceneRange)

        // line 3 (scene→view) - white
        let sceneViewRange = NSRange(location: sceneRange.location + sceneRange.length + 1, length: (sceneViewLine as NSString).length)
        attr.addAttributes([.font: font, .paragraphStyle: paragraph, .foregroundColor: UIColor.white], range: sceneViewRange)

        // line 4 (cam→view) - red
        let camViewRange = NSRange(location: sceneViewRange.location + sceneViewRange.length + 1, length: (camViewLine as NSString).length)
        attr.addAttributes([.font: font, .paragraphStyle: paragraph, .foregroundColor: UIColor.systemRed], range: camViewRange)

        // line 5 (cam→world) - orange
        let camWorldRange = NSRange(location: camViewRange.location + camViewRange.length + 1, length: (camWorldLine as NSString).length)
        attr.addAttributes([.font: font, .paragraphStyle: paragraph, .foregroundColor: UIColor.systemOrange], range: camWorldRange)

        return attr
    }
    
    /// Desired min/max viewport sizes (scene units) inferred from the current screen size.
    /// Interpolates between two reference devices (iPhone 14 and iPhone 16 Pro).
    private func targetViewportRanges(for viewSize: CGSize) -> (minW: CGFloat, minH: CGFloat, maxW: CGFloat, maxH: CGFloat) {
        // Reference A: iPhone 14 (≈ 390×844 points, portrait)
        let refW1: CGFloat = 390, refH1: CGFloat = 844
        let minW1: CGFloat = 192, minH1: CGFloat = 89    // most zoomed-in (smallest viewport)
        let maxW1: CGFloat = 923, maxH1: CGFloat = 426   // most zoomed-out (largest viewport)

        // Reference B: iPhone 16 Pro (≈ 402×874 points, portrait)
        let refW2: CGFloat = 402, refH2: CGFloat = 874
        let minW2: CGFloat = 206, minH2: CGFloat = 95
        let maxW2: CGFloat = 918, maxH2: CGFloat = 422

        func lerp(_ a: CGFloat, _ b: CGFloat, t: CGFloat) -> CGFloat { a + (b - a) * t }

        // Interpolation factors, clamped to [0,1] to avoid wild extrapolation
        let tW = max(0, min(1, (viewSize.width  - refW1) / (refW2 - refW1)))
        let tH = max(0, min(1, (viewSize.height - refH1) / (refH2 - refH1)))

        // Width-driven targets vary mostly with width; height-driven with height
        let minW = lerp(minW1, minW2, t: tW)
        let maxW = lerp(maxW1, maxW2, t: tW)
        let minH = lerp(minH1, minH2, t: tH)
        let maxH = lerp(maxH1, maxH2, t: tH)

        return (minW, minH, maxW, maxH)
    }
    
    
    /// Draw/refresh a red rectangle that matches the camera's visible area.
    /// The rectangle is added as a child of the camera so it follows pan automatically.
    private func updateCameraOverlay() {
        guard let skView = self.view as? SKView,
              let scene = skView.scene as? GameScene,
              let cam = scene.camera else { return }

        // With .resizeFill and scene.size matched to the SKView, 1 view point == 1 scene unit (pre-camera).
        let viewSize = skView.bounds.size
        let halfW = (viewSize.width  * 0.5) / cam.xScale
        let halfH = (viewSize.height * 0.5) / cam.yScale
        let rect = CGRect(x: -halfW, y: -halfH, width: halfW * 2, height: halfH * 2)

        // Reuse or create overlay node under the camera
        let name = "CameraOverlay"
        let overlay: SKShapeNode
        if let existing = cam.childNode(withName: name) as? SKShapeNode {
            overlay = existing
        } else {
            overlay = SKShapeNode()
            overlay.name = name
            overlay.fillColor = .clear
            overlay.strokeColor = .systemRed
            overlay.lineJoin = .miter
            overlay.zPosition = 100_000
            cam.addChild(overlay)
        }

        // Update path and keep ~1pt line width on screen regardless of zoom
        let path = CGMutablePath()
        path.addRect(rect)
        overlay.path = path
        overlay.lineWidth = max(1.0 / cam.xScale, 0.5)
    }
    /// Ensure the SpriteKit scene's size matches the SKView's current bounds when using .resizeFill.
    private func ensureSceneMatchesView() {
        guard let skView = self.view as? SKView,
              let scene = skView.scene else { return }
        if scene.scaleMode == .resizeFill {
            scene.size = skView.bounds.size
        }
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

        // Camera viewport corners in scene -> then to view coords (should match the view corners)
        var tlCamInView = CGPoint.zero
        var trCamInView = CGPoint.zero
        var brCamInView = CGPoint.zero
        var blCamInView = CGPoint.zero
        // Camera viewport corners in scene coordinates
        var tlCamWorld = CGPoint.zero
        var trCamWorld = CGPoint.zero
        var brCamWorld = CGPoint.zero
        var blCamWorld = CGPoint.zero
        if let scene = (self.view as? SKView)?.scene as? GameScene, let cam = scene.camera {
            let halfW = (w * 0.5) / cam.xScale
            let halfH = (h * 0.5) / cam.yScale
            let tlCamScene = CGPoint(x: cam.position.x - halfW, y: cam.position.y + halfH)
            let trCamScene = CGPoint(x: cam.position.x + halfW, y: cam.position.y + halfH)
            let brCamScene = CGPoint(x: cam.position.x + halfW, y: cam.position.y - halfH)
            let blCamScene = CGPoint(x: cam.position.x - halfW, y: cam.position.y - halfH)
            // Convert to worldNode coordinates
            if let world = scene.worldNode {
                tlCamWorld = world.convert(tlCamScene, from: scene)
                trCamWorld = world.convert(trCamScene, from: scene)
                brCamWorld = world.convert(brCamScene, from: scene)
                blCamWorld = world.convert(blCamScene, from: scene)
            }
            tlCamInView = scene.convertPoint(toView: tlCamScene)
            trCamInView = scene.convertPoint(toView: trCamScene)
            brCamInView = scene.convertPoint(toView: brCamScene)
            blCamInView = scene.convertPoint(toView: blCamScene)
        }

        tl.attributedText = makeCornerLabelText(
            viewLine: String(format: "TL (0, 0) view"),
            sceneLine: String(format: "(%.1f, %.1f) scene", sceneTL.x, sceneTL.y),
            sceneViewLine: String(format: "(%.1f, %.1f) scene→view", tlSceneInView.x, tlSceneInView.y),
            camViewLine: String(format: "(%.1f, %.1f) cam→view", tlCamInView.x, tlCamInView.y),
            camWorldLine: String(format: "(%.1f, %.1f) cam→world", tlCamWorld.x, tlCamWorld.y))

        tr.attributedText = makeCornerLabelText(
            viewLine: String(format: "TR (%.0f, 0) view", w),
            sceneLine: String(format: "(%.1f, %.1f) scene", sceneTR.x, sceneTR.y),
            sceneViewLine: String(format: "(%.1f, %.1f) scene→view", trSceneInView.x, trSceneInView.y),
            camViewLine: String(format: "(%.1f, %.1f) cam→view", trCamInView.x, trCamInView.y),
            camWorldLine: String(format: "(%.1f, %.1f) cam→world", trCamWorld.x, trCamWorld.y))

        br.attributedText = makeCornerLabelText(
            viewLine: String(format: "BR (%.0f, %.0f) view", w, h),
            sceneLine: String(format: "(%.1f, %.1f) scene", sceneBR.x, sceneBR.y),
            sceneViewLine: String(format: "(%.1f, %.1f) scene→view", brSceneInView.x, brSceneInView.y),
            camViewLine: String(format: "(%.1f, %.1f) cam→view", brCamInView.x, brCamInView.y),
            camWorldLine: String(format: "(%.1f, %.1f) cam→world", brCamWorld.x, brCamWorld.y))

        bl.attributedText = makeCornerLabelText(
            viewLine: String(format: "BL (0, %.0f) view", h),
            sceneLine: String(format: "(%.1f, %.1f) scene", sceneBL.x, sceneBL.y),
            sceneViewLine: String(format: "(%.1f, %.1f) scene→view", blSceneInView.x, blSceneInView.y),
            camViewLine: String(format: "(%.1f, %.1f) cam→view", blCamInView.x, blCamInView.y),
            camWorldLine: String(format: "(%.1f, %.1f) cam→world", blCamWorld.x, blCamWorld.y))

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
        ensureSceneMatchesView()
        updateCameraOverlay()
        updateCameraWHLabel()
        
        if let skView = self.view as? SKView,
           let scene = skView.scene as? GameScene,
           let camera = scene.camera {
            let (minScaleOut, maxScaleIn) = computeScaleBounds(for: skView, scene: scene)
            camera.setScale(max(minScaleOut, min(camera.xScale, maxScaleIn)))
            updateCameraOverlay()
            updateCameraWHLabel()
        }
        
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
        ensureSceneMatchesView()
        updateCornerHUD()
        positionScreenDebugDot()
        updateCameraOverlay()
        updateCameraWHLabel()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateCornerHUD()
        positionScreenDebugDot()
        updateCameraOverlay()
        updateCameraWHLabel()
    }
    


    @objc func handlePan(_ sender: UIPanGestureRecognizer) {
        guard let skView = self.view as? SKView,
              let scene = skView.scene as? GameScene else { return }

        let translation = sender.translation(in: skView)
        sender.setTranslation(.zero, in: skView)

        scene.worldNode.position.x += translation.x
        scene.worldNode.position.y -= translation.y
        updateCameraOverlay()
        updateCameraWHLabel()

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
            // Proposed new scale from the gesture
            let proposedScale = camera.xScale / sender.scale

            // Dynamic bounds: zoom-out fits full map height; zoom-in respects min viewport target
            let (minScaleOut, maxScaleIn) = computeScaleBounds(for: skView, scene: scene)

            // Clamp
            let clampedScale = max(minScaleOut, min(proposedScale, maxScaleIn))
            camera.setScale(clampedScale)

            // Reset recognizer delta and refresh debug overlays
            sender.scale = 1.0
            clampWorldNode(scene: scene)
            updateCameraOverlay()
            updateCameraWHLabel()
        }
    }

    /// Compute camera scale bounds for the current view & scene.
    /// - minScaleOut: smallest scale (most zoomed-out) so full **map height** fits the view height.
    /// - maxScaleIn:  largest scale (most zoomed-in) so viewport is not smaller than the target min viewport.
    private func computeScaleBounds(for skView: SKView, scene: GameScene) -> (minScaleOut: CGFloat, maxScaleIn: CGFloat) {
        let viewSize = skView.bounds.size

        // Zoom-out bound: make sure full tile map height is visible, plus 111px allowance
        var minScaleOut: CGFloat = 0.001
        if let baseMap = scene.baseMap {
            let mapHeightExact = max(baseMap.mapSize.height * baseMap.yScale, 1)
            let paddedHeight = mapHeightExact + 111.0
            minScaleOut = viewSize.height / paddedHeight
        }

        // Zoom-in bound: enforce your target min viewport (interpolated by screen size)
        let ranges = targetViewportRanges(for: viewSize)
        let maxScaleIn = min(viewSize.width / ranges.minW, viewSize.height / ranges.minH)

        return (minScaleOut, maxScaleIn)
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

import UIKit
import SpriteKit
import CoreGraphics

class GameViewController: UIViewController {
    // HUD controls
    private var debugPanel: UIStackView?
    // Camera scale HUD label
    private var cameraScaleLabel: UILabel?

    // One-time assertion flag to avoid log spam
    private var didWarnViewportOnce = false

    private func makeDebugButton(title: String) -> UIButton {
        let b = UIButton(type: .system)
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.title = title
            config.baseForegroundColor = .white
            config.baseBackgroundColor = UIColor.black.withAlphaComponent(0.55)
            config.cornerStyle = .medium
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
            b.configuration = config
            b.titleLabel?.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        } else {
            b.setTitle(title, for: .normal)
            b.titleLabel?.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
            b.setTitleColor(.white, for: .normal)
            b.backgroundColor = UIColor.black.withAlphaComponent(0.55)
            b.layer.cornerRadius = 6
            b.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        }
        return b
    }

    private let DEBUG_OVERLAYS = true
    // Debug logging for pan/clamp
    private let DEBUG_PAN_LOGS = true
    private func dbg(_ text: @autoclosure () -> String) {
        if DEBUG_PAN_LOGS { print(text()) }
    }

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

        // Update the camera scale label as well
        updateCameraScaleLabel()
    }

    /// Create/update a HUD label that shows the camera's current xScale and yScale.
    private func updateCameraScaleLabel() {
        guard let skView = self.view as? SKView,
              let scene = skView.scene as? GameScene,
              let cam = scene.camera else { return }

        // Create label if missing
        if cameraScaleLabel == nil {
            let l = UILabel()
            l.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .medium)
            l.textColor = .white
            l.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            l.textAlignment = .center
            l.layer.cornerRadius = 6
            l.layer.masksToBounds = true
            l.isUserInteractionEnabled = false
            (self.view as? SKView)?.addSubview(l)
            cameraScaleLabel = l
        }

        // Compute camera scale
        let xScale = cam.xScale
        let yScale = cam.yScale
        cameraScaleLabel?.text = String(format: "scale: x=%.3f y=%.3f", xScale, yScale)

        // Size label and position it below the cameraWHLabel (centered horizontally, below top safe area)
        cameraScaleLabel?.sizeToFit()
        let padX: CGFloat = 12
        let padY: CGFloat = 6
        if var f = cameraScaleLabel?.frame {
            f.size.width  += padX
            f.size.height += padY
            let inset = skView.safeAreaInsets
            let viewSize = skView.bounds.size
            let x = (viewSize.width - f.size.width) * 0.5
            // Position just below cameraWHLabel if present, else just below top safe area
            var y: CGFloat = inset.top + 8
            if let whLabel = cameraWHLabel {
                y = whLabel.frame.maxY + 4
            }
            f.origin = CGPoint(x: x, y: y)
            cameraScaleLabel?.frame = f
        }
        // Keep above SpriteKit content
        if let l = cameraScaleLabel { skView.bringSubviewToFront(l) }
    }

    /// If a sprite named "maxzoombg" exists anywhere in the scene tree, compute the camera scale
    /// that would render it 1:1 in view points (i.e., one node point maps to one screen point).
    /// Returns nil if the node is not found or the scale cannot be determined.
    private func maxInScaleFromMaxZoomBG(in scene: GameScene) -> CGFloat? {
        guard let mz = scene.childNode(withName: "//maxzoombg") else { return nil }
        let p0 = scene.convert(CoreGraphics.CGPoint.zero, from: mz)
        let px = scene.convert(CGPoint(x: 1, y: 0), from: mz)
        let py = scene.convert(CGPoint(x: 0, y: 1), from: mz)
        let kx = abs(px.x - p0.x)
        let ky = abs(py.y - p0.y)
        let k  = max(kx, ky)
        if k.isFinite && k > 0 { return max(k, 0.0001) }
        return nil
    }

    /// Max zoom-in scale: enforce 1:1 for `maxzoombg` if present; otherwise allow deep zoom with a tiny floor.
    private func computeMaxInScale(for skView: SKView, scene: GameScene) -> CGFloat {
        let nodeScale = maxInScaleFromMaxZoomBG(in: scene)
        return max(nodeScale ?? 0.0001, 0.0001)
    }

    // Cached max-in cap and max-out (fit-by-height) cap
    private var cachedMaxInScale: CGFloat = .greatestFiniteMagnitude
    private var cachedMaxOutScale: CGFloat = .greatestFiniteMagnitude

    /// Fit scale (zoom-out cap) so the entire background height is visible.
    private func computeFitScaleHeight(for skView: SKView, scene: GameScene) -> CGFloat {
        guard let rect = backgroundBoundsInScene(scene) else { return 1.0 }
        let viewH = max(skView.bounds.height, 1)
        let bgH   = max(rect.height, 1)
        let epsilon: CGFloat = 0.998
        return (bgH / viewH) * epsilon
    }

    /// Recompute the max-in and max-out zoom caps for the current view/scene sizes
    private func updateZoomCaps() {
        guard let skView = self.view as? SKView,
              let scene  = skView.scene as? GameScene else { return }
        cachedMaxInScale  = computeMaxInScale(for: skView, scene: scene)
        cachedMaxOutScale = computeFitScaleHeight(for: skView, scene: scene)
    }

    private func ensureDebugPanel() {
        guard debugPanel == nil, let skView = self.view as? SKView else { return }

        let panel = UIStackView()
        panel.axis = .horizontal
        panel.spacing = 8
        panel.alignment = .center
        panel.distribution = .fill
        panel.isLayoutMarginsRelativeArrangement = true
        panel.layoutMargins = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        panel.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        panel.layer.cornerRadius = 8
        panel.translatesAutoresizingMaskIntoConstraints = false

        let minBtn = makeDebugButton(title: "min")
        minBtn.addTarget(self, action: #selector(handleMinTap), for: .touchUpInside)
        let midBtn = makeDebugButton(title: "mid")
        midBtn.addTarget(self, action: #selector(handleMidTap), for: .touchUpInside)
        let maxBtn = makeDebugButton(title: "max")
        maxBtn.addTarget(self, action: #selector(handleMaxTap), for: .touchUpInside)

        panel.addArrangedSubview(minBtn)
        panel.addArrangedSubview(midBtn)
        panel.addArrangedSubview(maxBtn)

        skView.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: skView.centerXAnchor),
            panel.bottomAnchor.constraint(equalTo: skView.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])

        self.debugPanel = panel
        skView.bringSubviewToFront(panel)
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
            l.numberOfLines = 0
            l.lineBreakMode = .byClipping
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

        updateCornerHUD()
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

    private func ensureDebugOverlays(in scene: GameScene) {
        guard DEBUG_OVERLAYS, scene.worldNode != nil, scene.camera != nil else { return }
        if scene.childNode(withName: "MapBoundsOverlay") == nil {
            let n = SKShapeNode()
            n.name = "MapBoundsOverlay"
            n.strokeColor = .brown
            n.fillColor = .clear
            n.zPosition = 90_000
            n.lineWidth = 2
            scene.addChild(n)
        }
        if scene.camera?.childNode(withName: "CameraOverlay") == nil {
            updateCameraOverlay()
        }
    }
    
    // Build debug overlays: background bounds (scene space)
    private func updateDebugOverlays(scene: GameScene) {
        guard DEBUG_OVERLAYS, let _ = self.view as? SKView, let _ = scene.camera else { return }
        if let bgBounds = backgroundBoundsInScene(scene),
           let mapNode = scene.childNode(withName: "MapBoundsOverlay") as? SKShapeNode {
            let p = CGMutablePath(); p.addRect(bgBounds); mapNode.path = p
        }
        // The red camera overlay is handled by updateCameraOverlay (camera child)
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
        ensureSceneMatchesView()
        updateCameraOverlay()
        updateCameraWHLabel()
        ensureDebugPanel()
        updateZoomCaps()

        if let skView = self.view as? SKView, let scene = skView.scene as? GameScene {
            ensureDebugOverlays(in: scene)
            updateDebugOverlays(scene: scene)
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
        updateCameraOverlay()
        updateCameraWHLabel()
        updateZoomCaps()
        ensureDebugPanel()
        if let skView = self.view as? SKView, let scene = skView.scene as? GameScene {
            updateDebugOverlays(scene: scene)
        }
        if let panel = debugPanel, let skView = self.view as? SKView { skView.bringSubviewToFront(panel) }
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateCornerHUD()
        updateCameraOverlay()
        updateCameraWHLabel()
        updateZoomCaps()
        ensureDebugPanel()
        if let skView = self.view as? SKView, let scene = skView.scene as? GameScene {
            updateDebugOverlays(scene: scene)
        }
        if let panel = debugPanel, let skView = self.view as? SKView { skView.bringSubviewToFront(panel) }
    }

    @objc func handlePan(_ sender: UIPanGestureRecognizer) {
        guard let skView = self.view as? SKView,
              let scene = skView.scene as? GameScene else { return }

        let translation = sender.translation(in: skView)
        sender.setTranslation(.zero, in: skView)

        if let cam = scene.camera {
            scene.worldNode.position.x += translation.x / max(cam.xScale, 0.0001)
            scene.worldNode.position.y -= translation.y / max(cam.yScale, 0.0001)
        } else {
            scene.worldNode.position.x += translation.x
            scene.worldNode.position.y -= translation.y
        }
        // Clamp after updating worldNode position
        let beforeWorld = scene.worldNode.position
        clampWorldNode(scene: scene)
        let afterWorld = scene.worldNode.position
        if let cam = scene.camera {
            let dxScene = translation.x / max(cam.xScale, 0.0001)
            let dyScene = -translation.y / max(cam.yScale, 0.0001)
            let corrX = afterWorld.x - (beforeWorld.x + dxScene)
            let corrY = afterWorld.y - (beforeWorld.y + dyScene)
            dbg(String(format:"PAN dx=%.2f dy=%.2f scale=%.3f corr=(%.2f,%.2f)",
                       dxScene, dyScene, cam.xScale, corrX, corrY))
        }

        updateCameraOverlay()
        updateCameraWHLabel()
        updateCameraScaleLabel()
        if let scene = (self.view as? SKView)?.scene as? GameScene { updateDebugOverlays(scene: scene) }

        // Optional gentle settle when the finger lifts (already at clamped pos)
        if sender.state == .ended || sender.state == .cancelled {
            dbg("PAN ended at \(scene.worldNode.position)")
            clampWorldNode(scene: scene)
            let snap = SKAction.move(to: scene.worldNode.position, duration: 0.15)
            snap.timingMode = .easeOut
            scene.worldNode.run(snap)
            debugAssertViewportInsideBackground(scene, where: "pan.ended")
        }
    }

    /// Max: jump directly to the strictest zoom-in cap at current center.
    @objc private func handleMaxTap() {
        guard let skView = self.view as? SKView,
              let scene = skView.scene as? GameScene,
              let camera = scene.camera else { return }
        updateZoomCaps()
        camera.setScale(cachedMaxInScale)
        camera.yScale = camera.xScale
        clampWorldNode(scene: scene)
        updateCameraOverlay()
        updateCameraWHLabel()
        updateCameraScaleLabel()
        updateDebugOverlays(scene: scene)
    }

    /// Convert a rect defined in `from` node's coordinate space into the scene's coordinate space.
    private func rectFromNodeToScene(_ rect: CGRect, from: SKNode, scene: SKScene) -> CGRect {
        let bl = scene.convert(CGPoint(x: rect.minX, y: rect.minY), from: from)
        let br = scene.convert(CGPoint(x: rect.maxX, y: rect.minY), from: from)
        let tl = scene.convert(CGPoint(x: rect.minX, y: rect.maxY), from: from)
        let tr = scene.convert(CGPoint(x: rect.maxX, y: rect.maxY), from: from)
        let minX = min(bl.x, br.x, tl.x, tr.x)
        let maxX = max(bl.x, br.x, tl.x, tr.x)
        let minY = min(bl.y, br.y, tl.y, tr.y)
        let maxY = max(bl.y, br.y, tl.y, tr.y)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Convert a rect defined in scene coordinates into the target node's coordinate space.
    private func rectFromSceneToNode(_ rect: CGRect, to: SKNode, scene: SKScene) -> CGRect {
        let bl = to.convert(CGPoint(x: rect.minX, y: rect.minY), from: scene)
        let br = to.convert(CGPoint(x: rect.maxX, y: rect.minY), from: scene)
        let tl = to.convert(CGPoint(x: rect.minX, y: rect.maxY), from: scene)
        let tr = to.convert(CGPoint(x: rect.maxX, y: rect.maxY), from: scene)
        let minX = min(bl.x, br.x, tl.x, tr.x)
        let maxX = max(bl.x, br.x, tl.x, tr.x)
        let minY = min(bl.y, br.y, tl.y, tr.y)
        let maxY = max(bl.y, br.y, tl.y, tr.y)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Background bounds in **scene** coordinates. Returns nil if not present.
    private func backgroundBoundsInScene(_ scene: GameScene) -> CGRect? {
        if let bgAny = scene.childNode(withName: "//background") {
            let parent = bgAny.parent ?? scene
            let frameInParent = bgAny.frame
            return rectFromNodeToScene(frameInParent, from: parent, scene: scene)
        }
        return nil
    }

    /// Background bounds expressed in worldNode coordinates. Prefers a child named "background" under worldNode.
    private func backgroundBoundsInWorld(_ scene: GameScene) -> CGRect? {
        guard let world = scene.worldNode else { return nil }
        // Case 1: background is a child of worldNode (preferred)
        if let bgWorld = world.childNode(withName: "background") {
            return bgWorld.frame // already in world's coordinates
        }
        // Case 2: background exists somewhere in the scene hierarchy
        if let bgAny = scene.childNode(withName: "//background") {
            // Convert its frame (in parent space) to SCENE space, then to WORLD space
            let parent = bgAny.parent ?? scene
            let frameInParent = bgAny.frame
            let frameInScene  = rectFromNodeToScene(frameInParent, from: parent, scene: scene)
            return rectFromSceneToNode(frameInScene, to: world, scene: scene)
        }
        return nil
    }

    // Tiny toast helper
    private func showToast(_ text: String) {
        guard let skView = self.view as? SKView else { return }
        let l = UILabel()
        l.text = text
        l.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        l.textColor = .white
        l.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        l.textAlignment = .center
        l.numberOfLines = 1
        l.layer.cornerRadius = 8
        l.layer.masksToBounds = true
        l.alpha = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        skView.addSubview(l)
        NSLayoutConstraint.activate([
            l.centerXAnchor.constraint(equalTo: skView.centerXAnchor),
            l.bottomAnchor.constraint(equalTo: skView.bottomAnchor, constant: -(skView.safeAreaInsets.bottom + 60)),
            l.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            l.heightAnchor.constraint(equalToConstant: 32)
        ])
        skView.bringSubviewToFront(l)
        UIView.animate(withDuration: 0.18, animations: { l.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.18, delay: 1.0, options: [], animations: { l.alpha = 0 }) { _ in
                l.removeFromSuperview()
            }
        }
    }

    /// Center the camera over the background using the background bounds in scene space.
    private func centerCameraOnBackground(scene: GameScene) {
        guard let camera = scene.camera, let bgScene = self.backgroundBoundsInScene(scene) else { return }
        let dx = bgScene.midX - camera.position.x
        let dy = bgScene.midY - camera.position.y
        scene.worldNode.position.x -= dx
        scene.worldNode.position.y -= dy
    }

    @objc private func handleMinTap() {
        guard let skView = self.view as? SKView,
              let scene = skView.scene as? GameScene,
              let camera = scene.camera,
              backgroundBoundsInScene(scene) != nil else {
            showToast("min unavailable: background not ready")
            return
        }

        // Ensure caps are current, then use the same cap the pinch uses for zoom-out.
        updateZoomCaps()
        let fitScale = cachedMaxOutScale
        let viewW = max(skView.bounds.width, 1)
        let viewH = max(skView.bounds.height, 1)
        camera.setScale(fitScale)
        camera.yScale = camera.xScale

        // Center, clamp and refresh overlays/HUD
        centerCameraOnBackground(scene: scene)
        clampWorldNode(scene: scene)
        updateCameraOverlay()
        updateCameraWHLabel()
        updateCameraScaleLabel()
        updateDebugOverlays(scene: scene)

        #if DEBUG
        let camW = viewW / camera.xScale
        let camH = viewH / camera.yScale
        print("[MIN] view: (\(Int(viewW))x\(Int(viewH)))  fitScale=\(String(format: "%.4f", fitScale))  camViewportAfter: (\(Int(camW))x\(Int(camH)))")        #endif

        showToast("min: full map visible")
    }

    private func clampWorldNode(scene: GameScene) {
        guard let skView = self.view as? SKView,
              let cam = scene.camera else { return }

        // Only use background-space clamping
        let maxIter = 6
        var iter = 0
        while iter < maxIter {
            guard let baseWorld = backgroundBoundsInWorld(scene) else { return }
            let vpWorld = viewportRectInWorld(scene, cam: cam, viewSize: skView.bounds.size)
            let epsW: CGFloat = max(1.0 / max(cam.xScale, 0.0001), 0.25)

            var dxW: CGFloat = 0
            var dyW: CGFloat = 0

            if vpWorld.width >= baseWorld.width - epsW {
                dxW = (baseWorld.midX - vpWorld.midX)
            } else {
                if vpWorld.minX < baseWorld.minX { dxW = (baseWorld.minX - vpWorld.minX) }
                if vpWorld.maxX > baseWorld.maxX { dxW = (baseWorld.maxX - vpWorld.maxX) }
            }

            if vpWorld.height >= baseWorld.height - epsW {
                dyW = (baseWorld.midY - vpWorld.midY)
            } else {
                if vpWorld.minY < baseWorld.minY { dyW = (baseWorld.minY - vpWorld.minY) }
                if vpWorld.maxY > baseWorld.maxY { dyW = (baseWorld.maxY - vpWorld.maxY) }
            }

            if abs(dxW) > 0.0005 || abs(dyW) > 0.0005 {
                scene.worldNode.position.x += dxW
                scene.worldNode.position.y += dyW
                dbg(String(format: "CLAMP(world) iter=%d shift(%.2f,%.2f)", iter, dxW, dyW))
            } else {
                dbg("CLAMP(world) no adjustment")
                break
            }
            iter += 1
        }
    }

    /// Mid Zoom: set scale to midpoint between min and max caps
    @objc private func handleMidTap() {
        guard let skView = self.view as? SKView,
              let scene = skView.scene as? GameScene,
              let camera = scene.camera else { return }
        // ensure caps are up to date
        updateZoomCaps()
        let minScale = cachedMaxInScale
        let maxScale = cachedMaxOutScale
        let mid = (minScale + maxScale) * 0.5
        camera.setScale(mid)
        camera.yScale = camera.xScale
        // keep current center; just clamp to bounds
        clampWorldNode(scene: scene)
        updateCameraOverlay()
        updateCameraWHLabel()
        updateCameraScaleLabel()
        updateDebugOverlays(scene: scene)
        showToast(String(format: "mid: scale=%.3f", mid))
    }

    private func viewportRectInScene(_ scene: GameScene, cam: SKCameraNode, viewSize: CGSize) -> CGRect {
        let halfW = viewSize.width  / (2.0 * cam.xScale)
        let halfH = viewSize.height / (2.0 * cam.yScale)
        return CGRect(x: cam.position.x - halfW,
                      y: cam.position.y - halfH,
                      width: halfW * 2, height: halfH * 2)
    }

    /// Viewport rect in WORLD space, by converting scene corners into worldNode coords
    private func viewportRectInWorld(_ scene: GameScene, cam: SKCameraNode, viewSize: CGSize) -> CGRect {
        let rS = viewportRectInScene(scene, cam: cam, viewSize: viewSize)
        // Convert four corners into world space and take min/max
        guard let world = scene.worldNode else { return .zero }
        let blW = world.convert(CGPoint(x: rS.minX, y: rS.minY), from: scene)
        let brW = world.convert(CGPoint(x: rS.maxX, y: rS.minY), from: scene)
        let tlW = world.convert(CGPoint(x: rS.minX, y: rS.maxY), from: scene)
        let trW = world.convert(CGPoint(x: rS.maxX, y: rS.maxY), from: scene)
        let minX = min(blW.x, brW.x, tlW.x, trW.x)
        let maxX = max(blW.x, brW.x, tlW.x, trW.x)
        let minY = min(blW.y, brW.y, tlW.y, trW.y)
        let maxY = max(blW.y, brW.y, tlW.y, trW.y)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Background-only OOB assert
    private func debugAssertViewportInsideBackground(_ scene: GameScene, where tag: String) {
        guard let skView = self.view as? SKView,
              let cam = scene.camera,
              let base = backgroundBoundsInWorld(scene) else { return }

        if didWarnViewportOnce { return }

        let vpW = viewportRectInWorld(scene, cam: cam, viewSize: skView.bounds.size)
        let outside = (vpW.minX < base.minX) || (vpW.maxX > base.maxX) || (vpW.minY < base.minY) || (vpW.maxY > base.maxY)
        if outside {
            didWarnViewportOnce = true
            print("❗️ASSERT(OOB bg \(tag)): viewport=\(vpW)  background=\(base)")
        }
    }
}

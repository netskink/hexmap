import UIKit
import SpriteKit
import GameplayKit



class GameViewController: UIViewController {
    // HUD controls
    private var debugPanel: UIStackView?
    private var btnFit: UIButton?
    private var btnMaxIn: UIButton?

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

    // MARK: - Deterministic test & clamp toggles
    /// Quantize camera scale to 3 decimals to reduce floating error after pinch.
    private let scaleQuantizeQ: CGFloat = 1000

    /// When true, clamp will only use scene-space comparisons.
    private var useSceneOnly = false
    /// When true, clamp will only use world-space comparisons.
    private var useWorldOnly = false
    /// When true, use the simple "oracle" clamp instead of the dual-space clamp.
    private var useOracleClamp = false

    /// A small helper to show current clamp mode in logs.
    private var clampModeLabel: String {
        if useOracleClamp { return "ORACLE" }
        if useSceneOnly { return "SCENE-ONLY" }
        if useWorldOnly { return "WORLD-ONLY" }
        return "BOTH"
    }

    // Tracks whether the last clamp log indicated an out-of-bounds viewport
    private var lastClampHadError = false
    
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

    /// Max zoom-in scale so that at least the 7-hex cluster (center + 6 neighbors) remains fully visible.
    private func computeMaxInScale(for skView: SKView, scene: GameScene) -> CGFloat {
        guard let map = scene.baseMap else { return 10_000 }
        let viewH = max(skView.bounds.height, 1)
        let tileH = max(map.tileSize.height, 1)
        let minViewportH = 3.0 * tileH // center + 6 neighbors => ~3 tile heights tall
        // In SpriteKit, larger camera scale => zoomed OUT. Viewport height = viewH * scale.
        // To keep at least 3 tile-heights visible: viewH * scale >= minViewportH ⇒ scale >= minViewportH / viewH
        let minScaleAllowed = minViewportH / viewH
        return max(minScaleAllowed, 0.0001)
    }

    // Cached max-in cap used by gestures and buttons so they agree
    private var cachedMaxInScale: CGFloat = .greatestFiniteMagnitude
    // Cached max-out (zoom-out) cap that matches "Fit" by height so pinch can't zoom out farther
    private var cachedMaxOutScale: CGFloat = .greatestFiniteMagnitude

    /// Fit scale (zoom-out cap) so the entire map height is visible (landscape bias).
    private func computeFitScaleHeight(for skView: SKView, scene: GameScene) -> CGFloat {
        guard let mapSceneRect = mapBoundsInScene(scene) else { return 1.0 }
        let viewH = max(skView.bounds.height, 1)
        let mapH  = max(mapSceneRect.height, 1)
        let epsilon: CGFloat = 0.998   // slight bias to ensure full coverage
        // SpriteKit: larger xScale => more zoomed OUT; viewport = view / scale.
        // To show entire map by HEIGHT: view/scale >= mapH  ⇒  scale <= viewH/mapH.
        // We return that scale as the *cap* for zooming OUT.
        return (mapH / viewH) * epsilon
    }

    /// Recompute the max-in and max-out zoom caps for the current view/scene sizes
    private func updateZoomCaps() {
        guard let skView = self.view as? SKView,
              let scene  = skView.scene as? GameScene else { return }
        // Max zoom-in (smallest scale value allowed)
        cachedMaxInScale  = computeMaxInScale(for: skView, scene: scene)
        // Max zoom-out (largest scale value allowed) — match Fit-by-height
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

        let fit = makeDebugButton(title: "Fit")
        fit.addTarget(self, action: #selector(handleFitTap), for: .touchUpInside)
        let maxIn = makeDebugButton(title: "Max In")
        maxIn.addTarget(self, action: #selector(handleMaxInTap), for: .touchUpInside)

        panel.addArrangedSubview(fit)
        panel.addArrangedSubview(maxIn)

        skView.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: skView.centerXAnchor),
            panel.bottomAnchor.constraint(equalTo: skView.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])

        self.debugPanel = panel
        self.btnFit = fit
        self.btnMaxIn = maxIn

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

    // Build debug overlays: map bounds (scene space)
    private func ensureDebugOverlays(in scene: GameScene) {
        guard DEBUG_OVERLAYS, let _ = scene.worldNode, let cam = scene.camera else { return }
        if scene.childNode(withName: "MapBoundsOverlay") == nil {
            let n = SKShapeNode(); n.name = "MapBoundsOverlay"; n.strokeColor = .brown; n.fillColor = .clear; n.zPosition = 90_000; n.lineWidth = 2
            scene.addChild(n)
        }
        if cam.childNode(withName: "CameraOverlay") == nil { updateCameraOverlay() }
    }

    /// Viewport rect in SCENE space (centered on camera)
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

    private func updateDebugOverlays(scene: GameScene) {
        guard DEBUG_OVERLAYS, let _ = self.view as? SKView, let _ = scene.baseMap, let _ = scene.camera else { return }
        // Map bounds in SCENE space (static brown box)
        if let mapBounds = mapBoundsInScene(scene),
           let mapNode = scene.childNode(withName: "MapBoundsOverlay") as? SKShapeNode {
            let p = CGMutablePath(); p.addRect(mapBounds); mapNode.path = p
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
        positionScreenDebugDot()
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
        positionScreenDebugDot()
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
        positionScreenDebugDot()
        updateCameraOverlay()
        updateCameraWHLabel()
        updateZoomCaps()
        ensureDebugPanel()
        if let skView = self.view as? SKView, let scene = skView.scene as? GameScene {
            updateDebugOverlays(scene: scene)
        }

        if let panel = debugPanel, let skView = self.view as? SKView { skView.bringSubviewToFront(panel) }
    }
    


    // MARK: - Deterministic step helpers (for reproducible debugging)
    /// Pan the world by a fixed delta in view points (positive dx = right, positive dy = down on screen).
    private func stepPan(dx: CGFloat, dy: CGFloat) {
        guard let skView = self.view as? SKView,
              let scene = skView.scene as? GameScene,
              let cam = scene.camera else { return }

        // Convert desired on-screen delta (points) to scene-space delta
        let dxScene = dx / max(cam.xScale, 0.0001)
        let dyScene = dy / max(cam.yScale, 0.0001)

        scene.worldNode.position.x += dxScene
        scene.worldNode.position.y -= dyScene

        updateCameraOverlay()
        updateCameraWHLabel()
        updateDebugOverlays(scene: scene)
    }


    /// Cycle clamp modes: BOTH → SCENE-ONLY → WORLD-ONLY → ORACLE → BOTH …
    private func cycleClampMode() {
        if !useSceneOnly && !useWorldOnly && !useOracleClamp {
            useSceneOnly = true
        } else if useSceneOnly {
            useSceneOnly = false; useWorldOnly = true
        } else if useWorldOnly {
            useWorldOnly = false; useOracleClamp = true
        } else {
            useOracleClamp = false
        }

    }

    @objc private func handleModeTap() {
        cycleClampMode()
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


        updateCameraOverlay()
        updateCameraWHLabel()
        if let scene = (self.view as? SKView)?.scene as? GameScene { updateDebugOverlays(scene: scene) }

        // Optional gentle settle when the finger lifts (already at clamped pos)
        if sender.state == .ended || sender.state == .cancelled {
            let snap = SKAction.move(to: scene.worldNode.position, duration: 0.15)
            snap.timingMode = .easeOut
            scene.worldNode.run(snap)
        }

    }

    @objc func handlePinch(_ sender: UIPinchGestureRecognizer) {
        guard let skView = self.view as? SKView,
              let scene = skView.scene as? GameScene,
              let camera = scene.camera else { return }

        if sender.state == .began || sender.state == .changed {
            // SpriteKit: larger xScale => zoomed OUT. To zoom in with pinch (>1.0), divide.
            let proposed = camera.xScale / sender.scale
            // Clamp to [max-in (min scale), max-out (fit-by-height cap)]
            let clamped = min(max(proposed, cachedMaxInScale), cachedMaxOutScale)
            camera.setScale(clamped)
            camera.yScale = camera.xScale
            sender.scale = 1.0
            updateCameraOverlay()
            updateCameraWHLabel()
            if let scene = (self.view as? SKView)?.scene as? GameScene { updateDebugOverlays(scene: scene) }
        }
        if sender.state == .ended || sender.state == .cancelled {
            if camera.xScale < cachedMaxInScale { camera.setScale(cachedMaxInScale) }
            if camera.xScale > cachedMaxOutScale { camera.setScale(cachedMaxOutScale) }
            camera.yScale = camera.xScale
        }
    }
    // (old handleFitTap removed; keeping only the later version below)

    /// Max In: jump directly to the 7-hex cap at current center.
    @objc private func handleMaxInTap() {
        guard let skView = self.view as? SKView,
              let scene = skView.scene as? GameScene,
              let camera = scene.camera else { return }
        updateZoomCaps()
        camera.setScale(cachedMaxInScale)
        camera.yScale = camera.xScale
        updateCameraOverlay(); updateCameraWHLabel(); updateDebugOverlays(scene: scene)
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

    
    /// Map bounds in world space using SKTileMapNode.frame (parent-space, anchor/scale aware).
    private func mapBoundsFromFrame(in scene: GameScene) -> CGRect? {
        guard let map = scene.baseMap else { return nil }
        return map.frame // already in worldNode coordinates
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

    /// Map bounds in **scene** coordinates.
    /// Converts the tile map's frame (in worldNode space) into scene space, so the brown box
    /// and clamp logic move with the world as it pans/zooms.
    private func mapBoundsInScene(_ scene: GameScene) -> CGRect? {
        // We want the map bounds in **scene** coordinates.
        // SKTileMapNode.frame is expressed in its parent space (worldNode),
        // so convert that rect into scene space. This keeps the brown box
        // and the clamp logic aligned with the actually rendered map as
        // the world node moves.
        guard let map = scene.baseMap else { return nil }
        let frameInWorld = map.frame              // in worldNode space
        let rectInScene  = rectFromNodeToScene(frameInWorld, from: scene.worldNode, scene: scene)
        return rectInScene
    }
    
    
    

    // MARK: - Tiny toast helper for quick visual feedback
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

    /// Center the camera over the map using the map bounds in scene space.
    private func centerCameraOnMap(scene: GameScene) {
        guard let camera = scene.camera, let mapScene = self.mapBoundsInScene(scene) else { return }
        // Move the content (worldNode) so that the map's center lands under the camera.
        // If the camera is left of the map center (dx>0), we need to shift the **world** left (subtract).
        let dx = mapScene.midX - camera.position.x
        let dy = mapScene.midY - camera.position.y
        scene.worldNode.position.x -= dx
        scene.worldNode.position.y -= dy
    }

//    @objc private func handleFitTap() {
//        guard let skView = self.view as? SKView,
//              let scene = skView.scene as? GameScene,
//              let camera = scene.camera,
//              let _ = scene.baseMap else {
//            showToast("Fit unavailable: map not ready")
//            return
//        }
//
//        // Recompute caps (not strictly required for Fit, but keeps state consistent)
//        updateZoomCaps()
//
//        // Compute a true FIT-TO-MAP (show entire map). The camera viewport in scene units is
//        //   viewport = viewSize / scale
//        // To make the entire map visible, we require viewport >= mapSize on BOTH axes ⇒
//        //   scale <= min(viewW/mapW, viewH/mapH)
//        // Use a tiny epsilon < 1 so we bias toward zooming slightly farther out, ensuring
//        // the viewport is not smaller than the map due to rounding.
//        guard let mapSceneRect = mapBoundsInScene(scene) else {
//            showToast("Fit unavailable: map bounds not ready")
//            return
//        }
//        let mapW = max(mapSceneRect.width, 1)
//        let mapH = max(mapSceneRect.height, 1)
//        let viewW = max(skView.bounds.width, 1)
//        let viewH = max(skView.bounds.height, 1)
//
//        let epsilon: CGFloat = 0.998 // slightly under to guarantee full coverage
//        let fitScale = min(viewW / mapW, viewH / mapH) * epsilon
//
//        camera.setScale(fitScale)
//        camera.yScale = camera.xScale
//
//        // Center the map under the camera and refresh overlays/HUD.
//        centerCameraOnMap(scene: scene)
//        updateCameraOverlay()
//        updateCameraWHLabel()
//        updateDebugOverlays(scene: scene)
//        showToast("Fit: full map visible")
//    }

    @objc private func handleFitTap() {
        guard let skView = self.view as? SKView,
              let scene = skView.scene as? GameScene,
              let camera = scene.camera,
              let _ = scene.baseMap,
              let _ = mapBoundsInScene(scene) else {
            showToast("Fit unavailable: map not ready")
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
        centerCameraOnMap(scene: scene)
        clampWorldNode(scene: scene)
        updateCameraOverlay()
        updateCameraWHLabel()
        updateDebugOverlays(scene: scene)

        #if DEBUG
        let camW = viewW / camera.xScale
        let camH = viewH / camera.yScale
        print("[FIT] view: (\(Int(viewW))x\(Int(viewH)))  fitScale=\(String(format: "%.4f", fitScale))  camViewportAfter: (\(Int(camW))x\(Int(camH)))")
        #endif

        showToast("Fit: full map visible")
    }
    
    
    
    /// Clamp so the camera's viewport (in scene space) never shows outside the map bounds.
    /// This adjusts `scene.worldNode.position` so that the camera center remains within
    /// [map.min+halfViewport, map.max-halfViewport] on each axis.
    private func clampWorldNode(scene: GameScene) {
        guard let skView = self.view as? SKView,
              let camera = scene.camera,
              let mapScene = mapBoundsInScene(scene) else { return }

        // Current viewport size in scene units
        let viewSize = skView.bounds.size
        let halfW = viewSize.width  / (2.0 * max(camera.xScale, 0.0001))
        let halfH = viewSize.height / (2.0 * max(camera.yScale, 0.0001))

        // Target camera center clamped inside the map rect expanded inward by half the viewport
        let minCX = mapScene.minX + halfW
        let maxCX = mapScene.maxX - halfW
        let minCY = mapScene.minY + halfH
        let maxCY = mapScene.maxY - halfH

        // If the viewport is larger than the map on an axis, just center that axis.
        let targetCX: CGFloat
        if minCX > maxCX {
            targetCX = mapScene.midX
        } else {
            targetCX = min(max(camera.position.x, minCX), maxCX)
        }
        let targetCY: CGFloat
        if minCY > maxCY {
            targetCY = mapScene.midY
        } else {
            targetCY = min(max(camera.position.y, minCY), maxCY)
        }

        // Move the world node by the delta needed to place the camera at the target center
        let dx = targetCX - camera.position.x
        let dy = targetCY - camera.position.y
        if dx != 0 || dy != 0 {
            scene.worldNode.position.x += dx
            scene.worldNode.position.y += dy
        }
    }

    // MARK: - Tiny toast helper for quick visual feedback
    private func computeScaleBounds(for skView: SKView, scene: GameScene) -> (minScaleOut: CGFloat, maxScaleIn: CGFloat) {
        let viewSize = skView.bounds.size
        guard let map = scene.baseMap else {
            return (minScaleOut: 0.05, maxScaleIn: 50.0)
        }
        // Authoritative map extents
        let mapW = max(map.mapSize.width,  1)
        let mapH = max(map.mapSize.height, 1)
        // "Fit all" scale by HEIGHT (landscape): viewport = view * scale >= map ⇒ scale >= mapH / viewH
        let fitScale = mapH / max(viewSize.height, 1)
        let minScaleOut = fitScale * 1.002   // tiny bias to guarantee full coverage
        // Max-in: keep at least 3 tile heights visible vertically
        let tileH = max(map.tileSize.height, 1)
        let minViewportH = 3.0 * tileH
        let maxScaleIn = minViewportH / max(viewSize.height, 1)
        // Safety ordering
        if minScaleOut > maxScaleIn { return (minScaleOut: maxScaleIn, maxScaleIn: maxScaleIn) }
        return (minScaleOut: minScaleOut, maxScaleIn: maxScaleIn)
    }
    
}

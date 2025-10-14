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
    // MARK: - Pan state
    private var panAnchorScene: CGPoint?
    private var panStartWorldPos: CGPoint?
    private var panStartCamPosS: CGPoint?
    
    // --- Pan Debug Kit (no behavior changes) ---
    private var panTick = 0
    
    // MARK: - Pinch state
    private var pinchStartScale: CGFloat = 1.0
    private var pinchAnchorScene: CGPoint?

    // Guard insets in **screen points** for each edge; converted to WORLD units per current camera scale.
    private var stopInsetsPts: UIEdgeInsets = .zero

    // 1 screen-point guard per edge (converted to world units per scale)
    private let defaultStopInsetsPts = UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1)
    
    // Desired cam→world stops (WORLD coords) to apply when you press the zoom buttons.
    // Set any side to nil to use the true content edge for that side.
    private let desiredStopsForMid: (tlX: CGFloat?, trX: CGFloat?, topY: CGFloat?, bottomY: CGFloat?) = (nil, nil, nil, nil)
    private let desiredStopsForMax: (tlX: CGFloat?, trX: CGFloat?, topY: CGFloat?, bottomY: CGFloat?) = (nil, nil, nil, nil)

    private func fmt(_ p: CGPoint) -> String { String(format: "(%.2f,%.2f)", p.x, p.y) }
    private func fmtR(_ r: CGRect) -> String { String(format: "(x:%.2f y:%.2f w:%.2f h:%.2f)", r.origin.x, r.origin.y, r.size.width, r.size.height) }

    private func panSnapshot(_ tag: String) {
        guard let skView = self.view as? SKView,
              let scene = skView.scene as? GameScene,
              let cam   = scene.camera,
              let world = scene.worldNode
        else { return }

        let vpScene  = viewportRectInScene(scene, cam: cam, viewSize: skView.bounds.size)
        let vpWorld  = viewportRectInWorld(scene, cam: cam, viewSize: skView.bounds.size)
        let baseWorld = contentBoundsInWorld(scene) ?? .null

        var corr = CGPoint.zero
        do {
            let corrected = correctedWorldPosition(scene: scene, proposed: world.position)
            corr = CGPoint(x: corrected.x - world.position.x, y: corrected.y - world.position.y)
        }

        let status: String
        if baseWorld.isNull { status = "base:nil" }
        else {
            let inside = baseWorld.contains(vpWorld)
            status = inside ? "inside" : "OOB"
        }

        // Extra diagnostics: show which rects we are actually comparing
        if let baseW2 = contentBoundsInWorld(scene) {
            let bgS = rectFromNodeToScene(baseW2, from: world, scene: scene)
            dbg("[BG@SCENE] vpS=\(fmtR(vpScene)) bgS=\(fmtR(bgS))")
        }
        print("[PANDBG] \(tag) scale=\(String(format: "%.4f", cam.xScale)) world=\(fmt(world.position)) " +
              "vpS=\(fmtR(vpScene)) vpW=\(fmtR(vpWorld)) baseW=\(fmtR(baseWorld)) " +
              "predictCorr=\(fmt(corr)) status=\(status)")
    }
   

    /// Calibrate stopInsetsPts (screen pts) for the *current* scale so TL/TR/TOP/BOT cam→world stop values
    /// match your desired targets (WORLD coords). Pass nil to use the content edge for a side.
    private func calibrateStopsForCurrentScale(scene: GameScene,
                                               cam: SKCameraNode,
                                               desiredTLX: CGFloat?,
                                               desiredTRX: CGFloat?,
                                               desiredTopY: CGFloat?,
                                               desiredBottomY: CGFloat?) {
        guard let base = contentBoundsInWorld(scene) else { stopInsetsPts = .zero; return }
        var insets = UIEdgeInsets.zero
        // Left: TL.x ≥ desiredTLX  → inset = (desiredTLX - base.minX) WORLD → convert to pts
        if let tlx = desiredTLX { insets.left   = max(0, tlx - base.minX) * cam.xScale }
        // Right: TR.x ≤ desiredTRX → inset = (base.maxX - desiredTRX) WORLD → convert to pts
        if let trx = desiredTRX { insets.right  = max(0, base.maxX - trx) * cam.xScale }
        // Top:   TL.y ≤ desiredTopY → inset = (base.maxY - desiredTopY) WORLD → convert to pts
        if let ty  = desiredTopY { insets.top    = max(0, base.maxY - ty) * cam.yScale }
        // Bottom: BL.y ≥ desiredBottomY → inset = (desiredBottomY - base.minY) WORLD → convert to pts
        if let by  = desiredBottomY { insets.bottom = max(0, by - base.minY) * cam.yScale }
        stopInsetsPts = insets
    }
    
    
    
    /// One-finger pan: drag the World container defined in GameScene.sks (stable at any zoom).
    @objc func handlePan(_ sender: UIPanGestureRecognizer) {
        guard let skView = self.view as? SKView,
              let scene  = skView.scene as? GameScene else { return }

        guard let world = scene.worldNode else { return } // World container from GameScene.sks

        switch sender.state {
        case .began:
            panSnapshot("pan.begin")
            debugLogBackgroundResolution(scene: scene)
            if let cam = scene.camera, let bg = contentBoundsInWorld(scene) {
                let vp = viewportRectInScene(scene, cam: cam, viewSize: skView.bounds.size)
                print(String(format:"[RANGE BEGIN] x=[%.2f,%.2f] y=[%.2f,%.2f] world=%@", vp.maxX - bg.maxX, vp.minX - bg.minX, vp.maxY - bg.maxY, vp.minY - bg.minY, fmt(world.position)))
            }
            // Anchor the finger in scene space and remember the camera's starting position (scene coords).
            panAnchorScene   = scene.convertPoint(fromView: sender.location(in: skView))
            if let cam = scene.camera {
                let camPosS: CGPoint = {
                    if let parent = cam.parent, parent !== scene {
                        return scene.convert(cam.position, from: parent)
                    } else {
                        return cam.position
                    }
                }()
                panStartCamPosS = camPosS
            }
            world.removeAction(forKey: "panFling")

        case .changed:
            guard let anchor = panAnchorScene,
                  let startS = panStartCamPosS,
                  let cam    = scene.camera else { return }

            // Current finger in scene space
            let nowScene = scene.convertPoint(fromView: sender.location(in: skView))

            // Delta since gesture began (anchor-based) in SCENE space
            let deltaS = CGPoint(x: nowScene.x - anchor.x, y: nowScene.y - anchor.y)

            // Proposed camera position in SCENE space (drag-right ⇒ camera moves left).
            let proposedS = CGPoint(x: startS.x - deltaS.x, y: startS.y - deltaS.y)

            // Clamp camera in SCENE space, then set camera.position (convert back if needed).
            let correctedS = correctedCameraPosition(scene: scene, proposed: proposedS)
            if let parent = cam.parent, parent !== scene {
                cam.position = parent.convert(correctedS, from: scene)
            } else {
                cam.position = correctedS
            }

            // Lightweight periodic diagnostics: show legal world ranges and live gap to background
            if let skView = self.view as? SKView, let bg = contentBoundsInWorld(scene) {
                let vpW = viewportRectInWorld(scene, cam: cam, viewSize: skView.bounds.size)
                let minWorldX = vpW.minX - bg.minX  // ≥ 0 inside on the left
                let maxWorldX = bg.maxX - vpW.maxX  // ≥ 0 inside on the right
                let minWorldY = vpW.minY - bg.minY  // ≥ 0 inside at bottom
                let maxWorldY = bg.maxY - vpW.maxY  // ≥ 0 inside at top
                let camPosS: CGPoint = {
                    if let parent = cam.parent, parent !== scene {
                        return scene.convert(cam.position, from: parent)
                    } else { return cam.position }
                }()
                dbg("[XRANGE@CHANGED] gapsW x=[\(String(format: "%.2f", minWorldX)),\(String(format: "%.2f", maxWorldX))] y=[\(String(format: "%.2f", minWorldY)),\(String(format: "%.2f", maxWorldY))] pos=\(fmt(camPosS))")

                // World-space gaps (≥0 means inside)
                let gapL = vpW.minX - bg.minX
                let gapR = bg.maxX - vpW.maxX
                let gapB = vpW.minY - bg.minY
                let gapT = bg.maxY - vpW.maxY
                print(String(format: "[GAPS@CHANGED] L=%.2f R=%.2f B=%.2f T=%.2f", gapL, gapR, gapB, gapT))

                // Scene-space margins (positive means inside; negative means overshoot → black)
                let vpS = viewportRectInScene(scene, cam: cam, viewSize: skView.bounds.size)
                let bgS = rectFromNodeToScene(bg, from: world, scene: scene)
                let lS = vpS.minX - bgS.minX
                let rS = bgS.maxX - vpS.maxX
                let bS = vpS.minY - bgS.minY
                let tS = bgS.maxY - vpS.maxY
                print(String(format: "[SCENE MARGINS@CHANGED] L=%.2f R=%.2f B=%.2f T=%.2f", lS, rS, bS, tS))
            }

            #if DEBUG
            debugAssertViewportInsideBackground(scene, where: "pan.changed")
            #endif
            
            updateCameraOverlay()
            updateCameraWHLabel()
            updateDebugOverlays(scene: scene)
            updateWorldDiagnosticOverlays(scene: scene)
            
            panTick &+= 1
            if panTick % 6 == 0 { panSnapshot("pan.changed") }

        case .ended, .cancelled, .failed:
            // Clear anchors
            defer { panAnchorScene = nil; panStartCamPosS = nil }

            // Stop any in-flight pan animation and hard-clamp immediately.
            world.removeAction(forKey: "panFling")
            clampCameraPosition(scene: scene)
            
            if let skView = self.view as? SKView, let cam = scene.camera, let bg = contentBoundsInWorld(scene) {
                let vp = viewportRectInScene(scene, cam: cam, viewSize: skView.bounds.size)
                let gapL = vp.minX - bg.minX
                let gapR = bg.maxX - vp.maxX
                let gapB = vp.minY - bg.minY
                let gapT = bg.maxY - vp.maxY

                let eps: CGFloat = 1.0
                let camPosS: CGPoint = {
                    if let parent = cam.parent, parent !== scene {
                        return scene.convert(cam.position, from: parent)
                    } else { return cam.position }
                }()
                if abs(gapL) <= eps || abs(gapR) <= eps {
                    dbg("[HIT X EDGE] camS.x=\(String(format: "%.2f", camPosS.x)) gaps=[L:\(String(format: "%.2f", gapL)) R:\(String(format: "%.2f", gapR))]")
                }
                if abs(gapB) <= eps || abs(gapT) <= eps {
                    dbg("[HIT Y EDGE] camS.y=\(String(format: "%.2f", camPosS.y)) gaps=[B:\(String(format: "%.2f", gapB)) T:\(String(format: "%.2f", gapT))]")
                }
                dbg("[XRANGE END] gapsW x=[\(String(format: "%.2f", gapL)),\(String(format: "%.2f", gapR))] worldY=[\(String(format: "%.2f", gapB)),\(String(format: "%.2f", gapT))]")
            }
            

            // Refresh overlays/HUD and assert
            updateCameraOverlay()
            updateCameraWHLabel()
            updateDebugOverlays(scene: scene)
            updateWorldDiagnosticOverlays(scene: scene)
            #if DEBUG
            debugAssertViewportInsideBackground(scene, where: "pan.ended.hardstop")
            #endif

            panSnapshot("pan.ended")
            return

        default:
            break
        }
    }
    

    /// Two-finger pinch-to-zoom: zoom the camera uniformly, preserving the pinch focus and
    /// clamping to the background every frame.
    @objc func handlePinch(_ sender: UIPinchGestureRecognizer) {
        guard let skView = self.view as? SKView,
              let scene  = skView.scene as? GameScene,
              let cam    = scene.camera else { return }

        switch sender.state {
        case .began:
            // Keep caps in sync with current view/scene size
            updateZoomCaps()
            pinchStartScale  = cam.xScale
            // Anchor in SCENE coordinates under the pinch centroid
            pinchAnchorScene = scene.convertPoint(fromView: sender.location(in: skView))
            // Same 1-pt safety guard used by min/mid/max
            stopInsetsPts = defaultStopInsetsPts
            panSnapshot("pinch.begin")

        case .changed:
            guard let anchorS = pinchAnchorScene else { return }

            // Desired new camera scale (SpriteKit: larger scale => zooms in)
            var newScale = pinchStartScale * sender.scale

            // Clamp between your min/max caps (order-agnostic)
            let lo = min(cachedMaxInScale, cachedMaxOutScale)
            let hi = max(cachedMaxInScale, cachedMaxOutScale)
            if !newScale.isFinite { newScale = pinchStartScale }
            newScale = max(lo, min(hi, newScale))

            // Apply uniformly
            cam.setScale(newScale)
            cam.yScale = cam.xScale

            // Preserve the pinch focus: compute where the same screen point maps now,
            // then offset the camera so the original scene point stays under the fingers.
            let anchorAfterS = scene.convertPoint(fromView: sender.location(in: skView))

            let camPosS: CGPoint = {
                if let parent = cam.parent, parent !== scene {
                    return scene.convert(cam.position, from: parent)
                } else { return cam.position }
            }()

            var proposedS = CGPoint(
                x: camPosS.x + (anchorS.x - anchorAfterS.x),
                y: camPosS.y + (anchorS.y - anchorAfterS.y)
            )

            // Clamp the camera against the background (scene-space clamp)
            proposedS = correctedCameraPosition(scene: scene, proposed: proposedS)

            if let parent = cam.parent, parent !== scene {
                cam.position = parent.convert(proposedS, from: scene)
            } else {
                cam.position = proposedS
            }

            // HUD/diagnostics
            updateCameraOverlay()
            updateCameraWHLabel()
            updateDebugOverlays(scene: scene)
            updateWorldDiagnosticOverlays(scene: scene)
            #if DEBUG
            debugAssertViewportInsideBackground(scene, where: "pinch.changed")
            #endif
            panTick &+= 1
            if panTick % 6 == 0 { panSnapshot("pinch.changed") }

        case .ended, .cancelled, .failed:
            // Hard stop inside bounds and clear anchor
            clampCameraPosition(scene: scene)
            pinchAnchorScene = nil

            updateCameraOverlay()
            updateCameraWHLabel()
            updateDebugOverlays(scene: scene)
            updateWorldDiagnosticOverlays(scene: scene)
            #if DEBUG
            debugAssertViewportInsideBackground(scene, where: "pinch.ended")
            #endif
            panSnapshot("pinch.ended")

        default:
            break
        }
    }
    
    
    
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

    
    // MARK: - Fast verification helpers (logging only)
    private func nodePath(_ node: SKNode, in scene: SKScene) -> String {
        var parts: [String] = []
        var n: SKNode? = node
        while let cur = n, cur !== scene {
            parts.append(cur.name ?? String(describing: type(of: cur)))
            n = cur.parent
        }
        parts.append(scene.name ?? "scene")
        return parts.reversed().joined(separator: "/")
    }

    private func isDescendant(_ node: SKNode, of ancestor: SKNode) -> Bool {
        var n: SKNode? = node
        while let cur = n {
            if cur === ancestor { return true }
            n = cur.parent
        }
        return false
    }

    /// Log what `//background` resolves to (class, path), and the rects we clamp to.
    /// Diagnostic only – does not change behavior.
    private func debugLogBackgroundResolution(scene: GameScene) {
        guard DEBUG_PAN_LOGS else { return }
        let world = scene.worldNode

        func rectDescInScene(for node: SKNode) -> String {
            let parent = node.parent ?? scene
            let acc = node.calculateAccumulatedFrame()
            let rS  = rectFromNodeToScene(acc, from: parent, scene: scene)
            return fmtR(rS)
        }

        if let w = world {
            dbg("[BG.RESOLVE] worldNode path=\(nodePath(w, in: scene)) children=\(w.children.count)")
        } else {
            dbg("[BG.RESOLVE] worldNode = nil")
        }

        // Candidate A: `background` under world
        if let w = world, let bgW = w.childNode(withName: "background") {
            let cls = String(describing: type(of: bgW))
            let path = nodePath(bgW, in: scene)
            let underWorld = isDescendant(bgW, of: w)
            let acc = bgW.calculateAccumulatedFrame()
            dbg("[BG.RESOLVE] bgWorld class=\(cls) path=\(path) underWorld=\(underWorld) accW=\(fmtR(acc)) accS=\(rectDescInScene(for: bgW))")
            if let sp = bgW as? SKSpriteNode {
                dbg(String(format: "[BG.SPRITE] size=(%.0f×%.0f) anchor=(%.2f,%.2f)", sp.size.width, sp.size.height, sp.anchorPoint.x, sp.anchorPoint.y))
            }
        } else {
            dbg("[BG.RESOLVE] bgWorld (world.childNodeNamed 'background') = nil")
        }

        // Candidate B: any `//background` in the scene
        if let bgAny = scene.childNode(withName: "//background") {
            let cls = String(describing: type(of: bgAny))
            let path = nodePath(bgAny, in: scene)
            let acc = bgAny.calculateAccumulatedFrame()
            dbg("[BG.RESOLVE] bgAny  class=\(cls) path=\(path) acc(parent)=\(fmtR(acc)) accS=\(rectDescInScene(for: bgAny))")
            if let sp = bgAny as? SKSpriteNode {
                dbg(String(format: "[BG.SPRITE] any size=(%.0f×%.0f) anchor=(%.2f,%.2f)", sp.size.width, sp.size.height, sp.anchorPoint.x, sp.anchorPoint.y))
            }
        } else {
            dbg("[BG.RESOLVE] bgAny (scene.childNodeNamed '//background') = nil")
        }

        // What clamp rect are we actually using right now?
        if let contentW = contentBoundsInWorld(scene), let w = world {
            let contentS = rectFromNodeToScene(contentW, from: w, scene: scene)
            dbg("[BG.CLAMP] contentW=\(fmtR(contentW)) contentS=\(fmtR(contentS))")
        } else {
            dbg("[BG.CLAMP] contentBoundsInWorld = nil")
        }
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
        // Original behavior: this value produced a correct full-map view in your project.
        // Keep a tiny safety factor to avoid rounding slivers.
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


    private var sceneTL: CGPoint = .zero
    private var sceneTR: CGPoint = .zero
    private var sceneBR: CGPoint = .zero
    private var sceneBL: CGPoint = .zero

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1) Make sure storyboard view is actually an SKView
        guard let skView = self.view as? SKView else {
           print("⚠️ self.view is a \(type(of: self.view)) (not SKView)")
           return
        }

        // 2) Present only once
        guard skView.scene == nil else { return }

        // 3) Load the authored scene FROM THE .sks FILE (critical!)
        guard let scene = SKScene(fileNamed: "GameScene") as? GameScene else {
           assertionFailure("Couldn’t load GameScene.sks as GameScene")
           return
        }

        // 4) Fit to the current view size
        scene.scaleMode = .resizeFill
        scene.size = skView.bounds.size   // ensures the initial camera math uses the actual view size
    

        
        // Optional debug knobs
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 60
        // skView.showsFPS = true
        // skView.showsNodeCount = true

        // 5) Present
        skView.presentScene(scene)

        // 6) Log to verify you’re in the right world
        print("✅ Presented GameScene.sks as GameScene; SKView.bounds =", skView.bounds)
        
        // pinch recognizer setup
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panRecognizer.minimumNumberOfTouches = 1
        panRecognizer.maximumNumberOfTouches = 1
        view.addGestureRecognizer(panRecognizer)
        
        panRecognizer.cancelsTouchesInView = false
        
        
        // pinch recognizer setup
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinchRecognizer)
        pinchRecognizer.cancelsTouchesInView = false
        
    }
    
    private weak var skViewRef: SKView!
    private weak var sceneRef: GameScene!
    private weak var worldRef: SKNode!
    private weak var bgRef: SKNode!

    private func wireSceneRefs() {
        guard let skv = view as? SKView,
              let scn = skv.scene as? GameScene,
              let world = scn.childNode(withName: "World"),
              let bg = scn.childNode(withName: "//background")
                
                
        else { return }

        // inside wireSceneRefs(), after `let world = scn.childNode(withName: "World")`
        assert(world.xScale == 1 && world.yScale == 1 && world.zRotation == 0,
           "World node must remain unscaled/unrotated for panning/clamping to work correctly.")

        // in wireSceneRefs()
        assert(bg.parent === world || isDescendant(bg, of: world),
               "`background` must be under `World` so it moves with the content.")
        
        
        skViewRef = skv
        sceneRef  = scn
        worldRef  = world
        bgRef     = bg

        scn.scaleMode = .resizeFill
        scn.backgroundColor = .green   // keep for diagnostics until you’re happy
    }
    
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { [.landscapeLeft, .landscapeRight] }
    override var prefersStatusBarHidden: Bool { true }
    
    
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

        // Camera child nodes live in *camera space* (screen points). Do not divide by camera scale.
        // Draw the overlay exactly the size of the visible view so it always hugs the screen.
        let viewSize = skView.bounds.size
        let halfW = viewSize.width  * 0.5
        let halfH = viewSize.height * 0.5
        let rect = CGRect(x: -halfW, y: -halfH, width: viewSize.width, height: viewSize.height)

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
        // Constant 1-pt line regardless of zoom because this node is in camera space
        overlay.lineWidth = 1.0
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
    
    // Build debug overlays: background bounds (scene space, matches clamp logic)
    private func updateDebugOverlays(scene: GameScene) {
        guard DEBUG_OVERLAYS,
              (self.view as? SKView) != nil,
              scene.camera != nil,
              let world = scene.worldNode,
              let contentW = contentBoundsInWorld(scene),
              let mapNode = scene.childNode(withName: "MapBoundsOverlay") as? SKShapeNode
        else { return }

        // content bounds we clamp against (WORLD → SCENE)
        let contentS = rectFromNodeToScene(contentW, from: world, scene: scene)

        let p = CGMutablePath()
        p.addRect(contentS)
        mapNode.path = p

        // visuals (stroke set in ensureDebugOverlays; harmless to set again)
        mapNode.strokeColor = .brown
        mapNode.lineWidth   = 2
        mapNode.fillColor   = UIColor.systemTeal.withAlphaComponent(0.10)
        mapNode.blendMode   = .alpha
    }
    
    
    // ===== Diagnostics: World-space overlays =====

    /// Ensure world-space debug overlays exist (children of the World node so scale doesn't change line widths).
    private func ensureWorldDiagnosticOverlays(in scene: GameScene) {
        guard DEBUG_OVERLAYS, let world = scene.worldNode else { return }

        if world.childNode(withName: "ContentBoundsOverlayW") == nil {
            let n = SKShapeNode()
            n.name = "ContentBoundsOverlayW"
            n.strokeColor = .systemGreen
            n.fillColor = .clear
            n.lineWidth = 2
            n.zPosition = 95_000
            world.addChild(n)
        }
        if world.childNode(withName: "ViewportOverlayW") == nil {
            let n = SKShapeNode()
            n.name = "ViewportOverlayW"
            n.strokeColor = .magenta
            n.fillColor = .clear
            n.lineWidth = 2
            n.zPosition = 96_000
            world.addChild(n)
        }
    }

    /// Update world-space overlays:
    ///  - Green rect: content bounds (background only)
    ///  - Magenta rect: camera viewport converted into WORLD coordinates
    private func updateWorldDiagnosticOverlays(scene: GameScene) {
        guard DEBUG_OVERLAYS,
              let skView = self.view as? SKView,
              let cam = scene.camera,
              let world = scene.worldNode else { return }

        // Green: content bounds (world space)
        if let content = contentBoundsInWorld(scene),
           let contentNode = world.childNode(withName: "ContentBoundsOverlayW") as? SKShapeNode {
            let p = CGMutablePath()
            p.addRect(content)
            contentNode.path = p
        }

        // Magenta: viewport in world space
        let vpWorld = viewportRectInWorld(scene, cam: cam, viewSize: skView.bounds.size)
        if let vpNode = world.childNode(withName: "ViewportOverlayW") as? SKShapeNode {
            let p = CGMutablePath()
            p.addRect(vpWorld)
            vpNode.path = p
        }
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
    }


    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupCornerHUD()
        ensureSceneMatchesView()
        updateCameraOverlay()
        updateCameraWHLabel()
        updateZoomCaps()

        if let skView = self.view as? SKView, let scene = skView.scene as? GameScene {
            ensureDebugOverlays(in: scene)
            updateDebugOverlays(scene: scene)
            ensureWorldDiagnosticOverlays(in: scene)
            updateWorldDiagnosticOverlays(scene: scene)
        }
        
        // in viewDidAppear
        if let skv = self.view as? SKView {
            print("SKView.bounds =", skv.bounds)
        } else {
            print("⚠️ self.view is a \(type(of: self.view)) (not SKView)")
        }
        if let win = view.window { print("Window.bounds =", win.bounds) }
        (self.view as? SKView)?.backgroundColor = .yellow
        
        wireSceneRefs()

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
        updateCameraOverlay()
        updateCameraWHLabel()
        updateZoomCaps()
        if let skView = self.view as? SKView, let scene = skView.scene as? GameScene {
            updateDebugOverlays(scene: scene)
            updateWorldDiagnosticOverlays(scene: scene)
        }
        if let panel = debugPanel, let skView = self.view as? SKView { skView.bringSubviewToFront(panel) }
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateCameraOverlay()
        updateCameraWHLabel()
        updateZoomCaps()
        if let skView = self.view as? SKView, let scene = skView.scene as? GameScene {
            updateDebugOverlays(scene: scene)
            updateWorldDiagnosticOverlays(scene: scene)
        }
        if let panel = debugPanel, let skView = self.view as? SKView { skView.bringSubviewToFront(panel) }
    }

    /// Log a one-line snapshot of view size (pts), camera scale, and background clamp rect (WORLD units).
    private func logZoomSnapshot(_ tag: String, scene: GameScene) {
        guard let skView = self.view as? SKView,
              let cam = scene.camera else { return }
        let viewSize = skView.bounds.size
        let viewW = Int(viewSize.width)
        let viewH = Int(viewSize.height)
        let scaleStr = String(format: "%.4f", cam.xScale)
        if let bg = contentBoundsInWorld(scene) {
            let bgW = Int(bg.width.rounded())
            let bgH = Int(bg.height.rounded())
            print("[\(tag) SNAP] view=\(viewW)x\(viewH)  scale=\(scaleStr)  bgW=\(bgW)x\(bgH)")
        } else {
            print("[\(tag) SNAP] view=\(viewW)x\(viewH)  scale=\(scaleStr)  bgW=nil")
        }
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
            
            
            // Use accumulated frame so we ignore anchorPoint quirks and include children.
            let frameInParent = bgAny.calculateAccumulatedFrame()
            let frameInScene  = rectFromNodeToScene(frameInParent, from: parent, scene: scene)
            return frameInScene
        }
        return nil
    }

    /// Background bounds expressed in worldNode coordinates. Prefers a child named "background" under worldNode.
    // Replace your backgroundBoundsInWorld(_:) with this strict version.
    private func backgroundBoundsInWorld(_ scene: GameScene) -> CGRect? {
        guard let world = scene.worldNode else { return nil }

        // We REQUIRE the clamping surface to be a child of World.
        guard let bg = world.childNode(withName: "background") else {
            assertionFailure("Expected a node named `background` under `World` for clamping.")
            return nil
        }

        // Use the accumulated frame in WORLD space (bg is already under World).
        let r = bg.calculateAccumulatedFrame()
        return (r.isNull || r.width <= 0 || r.height <= 0) ? nil : r
    }

    /// Union two rects; if one is `.null`, return the other.
    private func unionRect(_ a: CGRect, _ b: CGRect) -> CGRect {
        if a.isNull { return b }
        if b.isNull { return a }
        return a.union(b)
    }

    private func contentBoundsInWorld(_ scene: GameScene) -> CGRect? {
        // Clamp STRICTLY to the background sprite, per project design.
        return backgroundBoundsInWorld(scene)
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

    /// Center the camera over the content bounds used for clamping, converting to scene space before centering.
    private func centerCameraOnBackground(scene: GameScene) {
        guard let camera = scene.camera,
              let world  = scene.worldNode,
              let contentW = self.contentBoundsInWorld(scene) else { return }

        // Convert WORLD → SCENE to compute the center in scene space
        let contentS = rectFromNodeToScene(contentW, from: world, scene: scene)
        let centerS = CGPoint(x: contentS.midX, y: contentS.midY)

        if let parent = camera.parent, parent !== scene {
            camera.position = parent.convert(centerS, from: scene)
        } else {
            camera.position = centerS
        }
    }


    private func clampWorldNode(scene: GameScene) {
        guard let world = scene.worldNode else { return }
        world.position = correctedWorldPosition(scene: scene, proposed: world.position)
    }
    
    
    
    
    // In GameViewController.swift
    private func correctedWorldPosition(scene: GameScene, proposed: CGPoint) -> CGPoint {
        guard let skView = self.view as? SKView,
              let cam = scene.camera,
              let world = scene.worldNode,
              let bgS_raw = backgroundBoundsInScene(scene) else {
            return proposed
        }

        // Convert optional guard insets (screen pts) → SCENE units for current camera scale
        let insetL = stopInsetsPts.left   / max(cam.xScale, 0.0001)
        let insetR = stopInsetsPts.right  / max(cam.xScale, 0.0001)
        let insetB = stopInsetsPts.bottom / max(cam.yScale, 0.0001)
        let insetT = stopInsetsPts.top    / max(cam.yScale, 0.0001)

        // Shrink the background rect in SCENE space
        let bgS = CGRect(
            x: bgS_raw.minX + insetL,
            y: bgS_raw.minY + insetB,
            width:  max(0, bgS_raw.width  - insetL - insetR),
            height: max(0, bgS_raw.height - insetT - insetB)
        )

        // Evaluate the viewport **in SCENE coordinates** at the proposed world position
        // Temporarily apply the proposed world position to compute the correct viewport
        let oldPos = world.position
        world.position = proposed
        let vpS = viewportRectInScene(scene, cam: cam, viewSize: skView.bounds.size)

        // Overshoot amounts in SCENE space (positive => viewport has crossed that edge)
        let overL = bgS.minX - vpS.minX
        let overR = vpS.maxX - bgS.maxX
        let overB = bgS.minY - vpS.minY
        let overT = vpS.maxY - bgS.maxY

        // Scene-space delta required to bring the viewport back inside the clamp rect
        let dxS = max(0, overL) - max(0, overR)
        let dyS = max(0, overB) - max(0, overT)

        // Convert SCENE delta → WORLD delta. Moving the world by −dW applies +dxS/+dyS to the viewport.
        let p0W = world.convert(CoreGraphics.CGPoint.zero, from: scene)
        let p1W = world.convert(CGPoint(x: dxS, y: dyS), from: scene)
        let dW  = CGPoint(x: p1W.x - p0W.x, y: p1W.y - p0W.y)

        // Restore and return corrected world position
        world.position = oldPos
        let corrected = CGPoint(x: proposed.x - dW.x, y: proposed.y - dW.y)

        if DEBUG_PAN_LOGS {
            func f(_ v: CGFloat) -> String { String(format: "%.2f", v) }
            print("[ABS CLAMP (scene)] proposed=(\(f(proposed.x)),\(f(proposed.y))) → (\(f(corrected.x)),\(f(corrected.y))) " +
                  "vpS=\(fmtR(vpS)) clampS=\(fmtR(bgS)) overs(L:\(f(overL)) R:\(f(overR)) B:\(f(overB)) T:\(f(overT)))")
        }

        return corrected
    }
    

    private func viewportRectInScene(_ scene: GameScene, cam: SKCameraNode, viewSize: CGSize) -> CGRect {
        let halfW = viewSize.width  / (2.0 * cam.xScale)
        let halfH = viewSize.height / (2.0 * cam.yScale)
   
       // Camera pos in SCENE coordinates (camera may be parented under another node)
       let camPosS: CGPoint
       if let parent = cam.parent, parent !== scene {
           camPosS = scene.convert(cam.position, from: parent)
       } else {
           camPosS = cam.position
       }
       return CGRect(x: camPosS.x - halfW,
                     y: camPosS.y - halfH,
                     width: halfW * 2, height: halfH * 2)
    }

    // Compute the viewport rectangle in SCENE coordinates for a *proposed* camera center (scene coords).
    // This is exact because it converts the four camera-space corners using the camera node’s transform.
    private func viewportRectInScene(scene: GameScene,
                                     cam: SKCameraNode,
                                     viewSize: CGSize,
                                     proposedScenePos: CGPoint) -> CGRect {
        // Save/restore the camera's position in its parent's coordinate space
        let parent = cam.parent ?? scene
        let oldPos = cam.position
        let proposedInParent = parent.convert(proposedScenePos, from: scene)
        cam.position = proposedInParent

        // Corners in camera space are in screen points; convert to SCENE space
        let hw = viewSize.width * 0.5
        let hh = viewSize.height * 0.5
        let tl = scene.convert(CGPoint(x: -hw, y:  hh), from: cam)
        let tr = scene.convert(CGPoint(x:  hw, y:  hh), from: cam)
        let br = scene.convert(CGPoint(x:  hw, y: -hh), from: cam)
        let bl = scene.convert(CGPoint(x: -hw, y: -hh), from: cam)

        // Restore
        cam.position = oldPos

        let minX = min(tl.x, tr.x, br.x, bl.x)
        let maxX = max(tl.x, tr.x, br.x, bl.x)
        let minY = min(tl.y, tr.y, br.y, bl.y)
        let maxY = max(tl.y, tr.y, br.y, bl.y)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Viewport rect in WORLD space, by converting scene corners into worldNode coords
    private func viewportRectInWorld(_ scene: GameScene, cam: SKCameraNode, viewSize: CGSize) -> CGRect {
        let rS = viewportRectInScene(scene, cam: cam, viewSize: viewSize)
        guard let world = scene.worldNode else { return .zero }

        // Always convert the 4 corners SCENE → WORLD for correctness across parents/transforms.
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
    
    
    /// Camera viewport corner points in WORLD coordinates (matches HUD math).
    private func viewportCornersInWorld(_ scene: GameScene, cam: SKCameraNode, viewSize: CGSize) -> (tl: CGPoint, tr: CGPoint, br: CGPoint, bl: CGPoint) {
        let halfW = viewSize.width  / (2.0 * cam.xScale)
        let halfH = viewSize.height / (2.0 * cam.yScale)

        // Camera position in SCENE coordinates (camera may be parented)
        let camPosS: CGPoint = {
            if let parent = cam.parent, parent !== scene {
                return scene.convert(cam.position, from: parent)
            } else {
                return cam.position
            }
        }()

        let tlS = CGPoint(x: camPosS.x - halfW, y: camPosS.y + halfH)
        let trS = CGPoint(x: camPosS.x + halfW, y: camPosS.y + halfH)
        let brS = CGPoint(x: camPosS.x + halfW, y: camPosS.y - halfH)
        let blS = CGPoint(x: camPosS.x - halfW, y: camPosS.y - halfH)

        guard let world = scene.worldNode else { return (.zero, .zero, .zero, .zero) }

        // Fast path: world is pure translation
        if world.zRotation == 0, world.xScale == 1, world.yScale == 1 {
            let ox = world.position.x, oy = world.position.y
            return (
                tl: CGPoint(x: tlS.x - ox, y: tlS.y - oy),
                tr: CGPoint(x: trS.x - ox, y: trS.y - oy),
                br: CGPoint(x: brS.x - ox, y: brS.y - oy),
                bl: CGPoint(x: blS.x - ox, y: blS.y - oy)
            )
        }

        // Fallback for non-identity transforms
        return (
            tl: world.convert(tlS, from: scene),
            tr: world.convert(trS, from: scene),
            br: world.convert(brS, from: scene),
            bl: world.convert(blS, from: scene)
        )
    }
    
    
    private func allowedWorldPositionRange(scene: GameScene,
                                           cam: SKCameraNode,
                                           viewSize: CGSize,
                                           bgW: CGRect) -> (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        // Compute the viewport rect in SCENE space
        let vpS = viewportRectInScene(scene, cam: cam, viewSize: viewSize)

        // IMPORTANT:
        // Do NOT convert bgW (WORLD) into scene space here. If you do, the bounds will
        // include world.position, causing the min/max to drift with the very value we are clamping.
        // The correct fixed range derives from:
        //   world.x ≥ vpS.maxX - bgW.maxX
        //   world.x ≤ vpS.minX - bgW.minX
        // and similarly for Y.
        let minX = vpS.maxX - bgW.maxX
        let maxX = vpS.minX - bgW.minX
        let minY = vpS.maxY - bgW.maxY
        let maxY = vpS.minY - bgW.minY
        return (minX, maxX, minY, maxY)
    }
    
    
    
    /// Background-only OOB assert
    private func debugAssertViewportInsideBackground(_ scene: GameScene, where tag: String) {
        guard let skView = self.view as? SKView,
              let cam = scene.camera,
              let base = contentBoundsInWorld(scene) else { return }

        if didWarnViewportOnce { return }

        let vpW = viewportRectInWorld(scene, cam: cam, viewSize: skView.bounds.size)
        let outside = (vpW.minX < base.minX) || (vpW.maxX > base.maxX) || (vpW.minY < base.minY) || (vpW.maxY > base.maxY)
        if outside {
            didWarnViewportOnce = true
            print("❗️ASSERT(OOB content \(tag)): viewport=\(vpW)  background=\(base)")
        }
    }
}

// MARK: - Camera clamping helpers (moved into an extension so `self` is valid)
extension GameViewController {
    // Clamp camera position in scene space (for camera-drag panning)
    private func correctedCameraPosition(scene: GameScene, proposed: CGPoint) -> CGPoint {
        // Clamp entirely in SCENE space against the background rect expressed in SCENE coords.
        guard let skView = self.view as? SKView,
              let cam = scene.camera,
              let bgS_raw = backgroundBoundsInScene(scene) else {
            return proposed
        }

        // Convert optional guard insets (screen pts) → SCENE units (per current camera scale)
        let insetL = stopInsetsPts.left   / max(cam.xScale, 0.0001)
        let insetR = stopInsetsPts.right  / max(cam.xScale, 0.0001)
        let insetB = stopInsetsPts.bottom / max(cam.yScale, 0.0001)
        let insetT = stopInsetsPts.top    / max(cam.yScale, 0.0001)

        // Shrink clamp rect a bit to avoid any rounding sliver at the edges
        var bgS = CGRect(
            x: bgS_raw.minX + insetL,
            y: bgS_raw.minY + insetB,
            width:  max(0, bgS_raw.width  - insetL - insetR),
            height: max(0, bgS_raw.height - insetT - insetB)
        )

        let viewSize = skView.bounds.size

        // Exact viewport for the *proposed* camera position
        let vpS = viewportRectInScene(scene: scene, cam: cam, viewSize: viewSize, proposedScenePos: proposed)

        // If viewport is larger than the background on an axis, lock to center on that axis
        var corrected = proposed
        if vpS.width > bgS.width { corrected.x = bgS.midX }
        if vpS.height > bgS.height { corrected.y = bgS.midY }

        // Recompute viewport if we changed either axis
        let vpForDelta = (corrected == proposed)
            ? vpS
            : viewportRectInScene(scene: scene, cam: cam, viewSize: viewSize, proposedScenePos: corrected)

        // Overshoot amounts in SCENE space (positive => viewport crossed that edge)
        let overL = bgS.minX - vpForDelta.minX
        let overR = vpForDelta.maxX - bgS.maxX
        let overB = bgS.minY - vpForDelta.minY
        let overT = vpForDelta.maxY - bgS.maxY

        // Nudge the camera back inside. For camera moves, overshoot and correction have the same sign.
        let eps: CGFloat = 0.25 // inward bias (scene units) to guarantee inside after rounding
        let dx = max(0, overL) - max(0, overR)
        let dy = max(0, overB) - max(0, overT)
        corrected.x += (dx == 0 ? 0 : (dx > 0 ? (dx + eps) : (dx - eps)))
        corrected.y += (dy == 0 ? 0 : (dy > 0 ? (dy + eps) : (dy - eps)))

        return corrected
    }

    // Clamp camera to background bounds (for camera-drag panning)
    private func clampCameraPosition(scene: GameScene) {
        guard let cam = scene.camera else { return }
        let corrected = correctedCameraPosition(scene: scene, proposed: {
            if let parent = cam.parent, parent !== scene {
                return scene.convert(cam.position, from: parent)
            } else {
                return cam.position
            }
        }())
        if let parent = cam.parent, parent !== scene {
            cam.position = parent.convert(corrected, from: scene)
        } else {
            cam.position = corrected
        }
    }
}

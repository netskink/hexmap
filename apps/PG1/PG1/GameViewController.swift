import UIKit
import SpriteKit
import CoreGraphics

class GameViewController: UIViewController {

    
    // Cached max-in cap and max-out (fit-by-height) cap
    private var cachedMaxInScale: CGFloat = .greatestFiniteMagnitude
    private var cachedMaxOutScale: CGFloat = .greatestFiniteMagnitude


    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { [.landscapeLeft, .landscapeRight] }
    override var prefersStatusBarHidden: Bool { true }

    
    // MARK: - Pan state
    private var panAnchorScene: CGPoint?
    private var panStartCamPosS: CGPoint?
    
    
    // MARK: - Pinch state
    private var pinchStartScale: CGFloat = 1.0
    private var pinchAnchorScene: CGPoint?

    // Guard insets in **screen points** for each edge; converted to WORLD units per current camera scale.
    private var stopInsetsPts: UIEdgeInsets = .zero

    // 1 screen-point guard per edge (converted to world units per scale)
    private let defaultStopInsetsPts = UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1)
    


   

    
    
    /// One-finger pan: drag the World container defined in GameScene.sks (stable at any zoom).
    @objc func handlePan(_ sender: UIPanGestureRecognizer) {
        guard let skView = self.view as? SKView,
              let scene  = skView.scene as? GameScene else { return }


        switch sender.state {
        case .began:

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


        case .ended, .cancelled, .failed:
            // Clear anchors
            defer { panAnchorScene = nil; panStartCamPosS = nil }

            // Stop any in-flight pan animation and hard-clamp immediately.
            clampCameraPosition(scene: scene)
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


        case .ended, .cancelled, .failed:
            // Hard stop inside bounds and clear anchor
            clampCameraPosition(scene: scene)
            pinchAnchorScene = nil

        default:
            break
        }
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
    private func computeMaxInScale(scene: GameScene) -> CGFloat {
        let nodeScale = maxInScaleFromMaxZoomBG(in: scene)
        return max(nodeScale ?? 0.0001, 0.0001)
    }

    
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
        cachedMaxInScale  = computeMaxInScale(scene: scene)
        cachedMaxOutScale = computeFitScaleHeight(for: skView, scene: scene)
    }


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
    
    
    
    
    


    


    
    
    /// Ensure the SpriteKit scene's size matches the SKView's current bounds when using .resizeFill.
    private func ensureSceneMatchesView() {
        guard let skView = self.view as? SKView,
              let scene = skView.scene else { return }
        if scene.scaleMode == .resizeFill {
            scene.size = skView.bounds.size
        }
    }



    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ensureSceneMatchesView()
        updateZoomCaps()
    }


    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        ensureSceneMatchesView()
        updateZoomCaps()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateZoomCaps()
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

    
    
    /// Background-only OOB assert
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
        let bgS = CGRect(
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

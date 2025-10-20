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
            stopInsetsPts = defaultStopInsetsPts

        case .changed:
            guard let cam = scene.camera else { return }
            
            // cancel pan if second finger appears
            if sender.numberOfTouches > 1 {
                sender.setTranslation(.zero, in: skView)
                return
            }

            // Use incremental translation in VIEW points, convert to SCENE units via camera scale,
            // and reset the recognizer each frame. This avoids anchor drift and edge jitter.
            let t = sender.translation(in: skView) // in screen points
            if t == .zero { return }

            // Convert view-point delta → scene-space delta using current camera scale
            let dxS = t.x * cam.xScale
            let dyS = t.y * cam.yScale

            // Current camera position in SCENE space
            let camPosS: CGPoint = {
                if let parent = cam.parent, parent !== scene {
                    return scene.convert(cam.position, from: parent)
                } else {
                    return cam.position
                }
            }()

            // Finger-right should move the camera-left. UIKit Y increases downward in view points,
            // so to make the content follow the finger vertically we ADD dyS.
            var proposedS = CGPoint(x: camPosS.x - dxS, y: camPosS.y + dyS)

            // Clamp to the background bounds in SCENE space
            proposedS = correctedCameraPosition(scene: scene, proposed: proposedS)

            // Apply back in the camera's parent space
            if let parent = cam.parent, parent !== scene {
                cam.position = parent.convert(proposedS, from: scene)
            } else {
                cam.position = proposedS
            }

            // Reset so next callback gives an incremental delta from here
            sender.setTranslation(.zero, in: skView)

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
        
        skView.isMultipleTouchEnabled = true

        // 5) Present
        skView.presentScene(scene)
        
        // recompute zoom caps once the scene is on screen
        DispatchQueue.main.async { [weak self] in self?.updateZoomCaps() }

        // 6) Log to verify you’re in the right world
        print("✅ Presented GameScene.sks as GameScene; SKView.bounds =", skView.bounds)
        
        // pinch recognizer setup
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panRecognizer.minimumNumberOfTouches = 1
        panRecognizer.maximumNumberOfTouches = 1
        view.addGestureRecognizer(panRecognizer)
        
        panRecognizer.cancelsTouchesInView = false
        
        
        // pinch recognizer setup
        let pinchRecognizer = UIPinchGestureRecognizer(target: self,
                                              action: #selector(handlePinch(_:)))
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

    


    
    /// Background-only OOB assert
}

// MARK: - Camera clamping helpers (moved into an extension so `self` is valid)
extension GameViewController {
    // Clamp camera position in scene space (for camera-drag panning)
    private func correctedCameraPosition(scene: GameScene, proposed: CGPoint) -> CGPoint {
        guard let skView = self.view as? SKView,
              let cam = scene.camera,
              let bgS_raw = backgroundBoundsInScene(scene) else {
            return proposed
        }

        // Convert guard insets (screen points) → scene units using current camera scale
        let insetL = stopInsetsPts.left   / max(cam.xScale,  0.0001)
        let insetR = stopInsetsPts.right  / max(cam.xScale,  0.0001)
        let insetB = stopInsetsPts.bottom / max(cam.yScale,  0.0001)
        let insetT = stopInsetsPts.top    / max(cam.yScale,  0.0001)

        // Background rect, slightly shrunk by insets to avoid edge slivers
        let bgS = CGRect(
            x: bgS_raw.minX + insetL,
            y: bgS_raw.minY + insetB,
            width:  max(0, bgS_raw.width  - insetL - insetR),
            height: max(0, bgS_raw.height - insetT - insetB)
        )

        // Half-size of the viewport in SCENE units.
        // (SpriteKit: visible size in scene units = view size in points * camera scale)
        let halfW = (skView.bounds.width  * 0.5) * cam.xScale
        let halfH = (skView.bounds.height * 0.5) * cam.yScale

        var x = proposed.x
        var y = proposed.y

        // If the viewport is larger than the background on an axis, lock to the center on that axis.
        if (2 * halfW) >= bgS.width {
            x = bgS.midX
        } else {
            let minX = bgS.minX + halfW
            let maxX = bgS.maxX - halfW
            x = min(max(x, minX), maxX)
        }

        if (2 * halfH) >= bgS.height {
            y = bgS.midY
        } else {
            let minY = bgS.minY + halfH
            let maxY = bgS.maxY - halfH
            y = min(max(y, minY), maxY)
        }

        return CGPoint(x: x, y: y)
    }

    // Clamp camera to background bounds (for camera-drag panning)
    private func clampCameraPosition(scene: GameScene) {
        guard let cam = scene.camera else { return }

        let currentInScene: CGPoint = {
            if let parent = cam.parent, parent !== scene {
                return scene.convert(cam.position, from: parent)
            } else {
                return cam.position
            }
        }()

        let clamped = correctedCameraPosition(scene: scene, proposed: currentInScene)

        if let parent = cam.parent, parent !== scene {
            cam.position = parent.convert(clamped, from: scene)
        } else {
            cam.position = clamped
        }
    }
}

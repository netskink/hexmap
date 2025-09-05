import SwiftUI
import SpriteKit
import UIKit

struct ContentView: View {

    // Use static to avoid reloading the SKS on every ContentView init.
    private static let scene: SKScene = {
        #if targetEnvironment(simulator)
        print("🧪 Running on SIMULATOR")
        #else
        print("📱 Running on DEVICE")
        #endif

        // Quick asset sanity checks (case-sensitive on sim)
        #if DEBUG
        assert(UIImage(named: "aBlueUnit") != nil, "Missing image asset: aBlueUnit")
        assert(UIImage(named: "aMoveMarker") != nil, "Missing image asset: aMoveMarker")

        // List any .sks files we actually have in the built bundle
        if let urls = Bundle.main.urls(forResourcesWithExtension: "sks", subdirectory: nil) {
            let names = urls.map { $0.lastPathComponent }.joined(separator: ", ")
            print("Bundle .sks files:", names)
        } else {
            print("No .sks files found via bundle URL scan.")
        }
        #endif

        // Attempt to load LevelScene.sks as LevelScene.
        if let s = SKScene(fileNamed: "LevelScene") as? LevelScene {
            s.scaleMode = .resizeFill
            print("✅ Loaded LevelScene.sks as LevelScene (\(type(of: s)))")
            return s
        }

        #if DEBUG
        // Diagnostics: verify presence and hint about misconfig.
        if let path = Bundle.main.path(forResource: "LevelScene", ofType: "sks") {
            print("Found LevelScene.sks at: \(path) — but could not cast to LevelScene.")
            print("Tip: In LevelScene.sks (select root Scene) → Identity Inspector → Custom Class = LevelScene, Module = your app module.")
            // See what class actually loaded (often SKScene if Custom Class/Module is unset)
            if let raw = SKScene(fileNamed: "LevelScene") {
                print("Loaded SKScene subclass instead:", type(of: raw))
            } else {
                print("SKScene(fileNamed:) returned nil despite the path existing. Check target, caching, or file corruption.")
            }
            // This assert makes failures noisy during development; comment out if you prefer soft fallback.
            assertionFailure("LevelScene.sks loaded but is not a LevelScene. Fix Custom Class/Module.")
        } else {
            print("🚫 LevelScene.sks not found in main bundle.")
            print("Check Target Membership and Build Phases → Copy Bundle Resources for the app target (not tests).")
            assertionFailure("Missing LevelScene.sks in bundle.")
        }
        #endif

        // Fallback: create a minimal LevelScene with a visible hint.
        let size = UIScreen.main.bounds.size == .zero
            ? CGSize(width: 800, height: 600) // safety for odd early-zero sizes on sim
            : UIScreen.main.bounds.size

        let fallback = LevelScene(size: size)
        fallback.scaleMode = .resizeFill

        #if DEBUG
        let label = SKLabelNode(text: "Could not load LevelScene.sks as LevelScene")
        label.fontName = "Menlo"
        label.fontSize = 14
        label.fontColor = .red
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: fallback.size.width/2, y: fallback.size.height/2)
        fallback.addChild(label)
        #endif

        return fallback
    }()

    var body: some View {
        SpriteView(
            scene: Self.scene,
            options: [.ignoresSiblingOrder] // often a perf win
        )
        //.preferredFramesPerSecond(60)
        .ignoresSafeArea()
        .onAppear {
            #if targetEnvironment(simulator)
            print("SIM device:", UIDevice.current.model, "iOS", UIDevice.current.systemVersion)
            #endif
        }
    }
}

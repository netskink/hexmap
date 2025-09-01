import SwiftUI
import SpriteKit

struct ContentView: View {
    private let scene: SKScene = {
        // Try to load MyScene.sks and cast to LevelScene
        if let s = SKScene(fileNamed: "MyScene") as? LevelScene {
            s.scaleMode = .resizeFill
            return s
        }

        // Diagnostics: is the file even in the bundle?
        if let path = Bundle.main.path(forResource: "MyScene", ofType: "sks") {
            print("Found MyScene.sks at: \(path) — but could not cast to LevelScene.")
            print("Tip: In MyScene.sks → Identity Inspector → Custom Class = LevelScene, Module = (your app module)")
        } else {
            print("MyScene.sks not found in main bundle.")
            print("Check Target Membership + Build Phases → Copy Bundle Resources.")
        }

        // Fallback: simple scene with on-screen hint
        let fallback = LevelScene(size: UIScreen.main.bounds.size)
        fallback.scaleMode = .resizeFill
    #if DEBUG
        let label = SKLabelNode(text: "Could not load MyScene.sks as LevelScene")
        label.fontName = "Menlo"
        label.fontSize = 14
        label.fontColor = .red
        label.position = CGPoint(x: fallback.size.width/2, y: fallback.size.height/2)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        fallback.addChild(label)
    #endif
        return fallback
    }()

    var body: some View {
        SpriteView(scene: scene).ignoresSafeArea()
    }
}

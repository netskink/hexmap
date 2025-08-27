
import SwiftUI
import SpriteKit

struct ContentView: View {
    private let scene: SKScene = {
        
        // HexScene is a subclass of SKScene
        
        let scene = HexScene()
        scene.scaleMode = .resizeFill
        return scene
    }()

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
            .onAppear {
                // Optionally configure here
            }
    }
}

#Preview {
    ContentView()
}

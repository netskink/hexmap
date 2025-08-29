import SwiftUI
import SpriteKit

struct ContentView: View {
    private let scene: SKScene = {
        let s = HexAssetScene()
        s.scaleMode = .resizeFill
        return s
    }()

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
    }
}

#Preview { ContentView() }

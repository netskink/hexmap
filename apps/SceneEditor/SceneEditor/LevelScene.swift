
import SpriteKit

final class LevelScene: SKScene {
    
    private var didSetup = false
    
    //    override func didMove(to view: SKView) {
    //        guard !didSetup else { return }
    //        didSetup = true
    //
    //        backgroundColor = .black
    //
    //        if let map = childNode(withName: "Tile Map Node") as? SKTileMapNode {
    //            map.anchorPoint = CGPoint(x: 0.5, y: 0.5)
    //            map.position = CGPoint(x: size.width/2, y: size.height/2)
    //
    //            print("Loaded map: \(map.numberOfColumns)x\(map.numberOfRows), tileSize: \(map.tileSize)")
    //
    //            if let tileSet = map.tileSet as SKTileSet? {
    //                print("Tile Set default size: \(tileSet.defaultTileSize)")
    //                let names = tileSet.tileGroups.map { $0.name ?? "<unnamed>" }
    //                print("Tile Groups in tileSet: \(names)")
    //                showGroupNames(names)
    //            }
    //        } else {
    //            print("whoops2")
    //            let label = SKLabelNode(text: "No Tile Map named 'Map' found in Level1.sks")
    //            label.fontName = "Menlo"
    //            label.fontSize = 14
    //            label.fontColor = .red
    //            label.position = CGPoint(x: size.width/2, y: size.height/2)
    //            label.horizontalAlignmentMode = .center
    //            label.verticalAlignmentMode = .center
    //            addChild(label)
    //        }
    //    }
    
    private func showGroupNames(_ names: [String]) {
        guard !names.isEmpty else { return }
        let title = SKLabelNode(text: "Tile Groups:")
        title.fontName = "Menlo-Bold"
        title.fontSize = 14
        title.fontColor = .white
        title.position = CGPoint(x: size.width/2, y: size.height - 24)
        title.verticalAlignmentMode = .top
        title.horizontalAlignmentMode = .center
        addChild(title)
        
        for (i, name) in names.enumerated() {
            let line = SKLabelNode(text: "• " + name)
            line.fontName = "Menlo"
            line.fontSize = 12
            line.fontColor = .lightGray
            line.position = CGPoint(x: size.width/2, y: size.height - 44 - CGFloat(i) * 16)
            line.verticalAlignmentMode = .top
            line.horizontalAlignmentMode = .center
            addChild(line)
        }
    }
    
//    override func didMove(to view: SKView) {
//        backgroundColor = .black
//        
//        // 1) Camera sanity: if there’s a camera node, assign it and center it
//        if let cam = childNode(withName: "//Camera") as? SKCameraNode {
//            self.camera = cam
//            cam.position = CGPoint(x: size.width/2, y: size.height/2)
//            print("Camera assigned and centered.")
//        }
//        
//        // 2) Find your Tile Map Node by its name from the editor
//        guard let map = childNode(withName: "Tile Map Node") as? SKTileMapNode else {
//            print("❌ Could not find a node named 'Tile Map Node'")
//            return
//        }
//        
//        // 3) Print key facts
//        print("✅ Found Tile Map Node")
//        print("   columns: \(map.numberOfColumns), rows: \(map.numberOfRows), tileSize: \(map.tileSize)")
//        print("   position: \(map.position), anchor: \(map.anchorPoint), z: \(map.zPosition), alpha: \(map.alpha)")
//        
//        // 4) Center it (safety)
//        map.anchorPoint = CGPoint(x: 0.5, y: 0.5)
//        map.position = CGPoint(x: size.width/2, y: size.height/2)
//        
//        // 5) Ensure it has a tileset and list groups
//        if let ts = map.tileSet as SKTileSet? {
//            print("   tileSet defaultTileSize: \(ts.defaultTileSize)")
//            let names = ts.tileGroups.map { $0.name ?? "<unnamed>" }
//            print("   groups: \(names)")
//        } else {
//            print("❌ Tile Map has no tileSet assigned in the scene file.")
//        }
//        
//        // 6) Count how many cells are already painted
//        var painted = 0
//        for r in 0..<map.numberOfRows {
//            for c in 0..<map.numberOfColumns {
//                if map.tileGroup(atColumn: c, row: r) != nil { painted += 1 }
//            }
//        }
//        print("   painted cells: \(painted)")
//        
//        // 7) If empty, force-paint one tile so something shows up
//        if painted == 0, let firstGroup = map.tileSet.tileGroups.first {
//            let midC = max(0, map.numberOfColumns/2 - 1)
//            let midR = max(0, map.numberOfRows/2 - 1)
//            map.setTileGroup(firstGroup, forColumn: midC, row: midR)
//            print("   (map was empty) → placed one '\(firstGroup.name ?? "group")' tile at (\(midC), \(midR))")
//        }
//        
//        // 8) Bring it to front just in case
//        map.zPosition = 10
//    }
    
    override func didMove(to view: SKView) {
        backgroundColor = .black

        guard let map = childNode(withName: "Tile Map Node") as? SKTileMapNode else { return }

        // Place the map so its center is at the scene center (safe default)
        map.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        map.position = CGPoint(x: size.width/2, y: size.height/2)

        // Ensure we have a camera
        let cam: SKCameraNode
        if let existing = self.camera {
            cam = existing
        } else {
            cam = SKCameraNode()
            addChild(cam)
            self.camera = cam
        }

        // Compute the map’s bounding box in scene coordinates
        let mapBounds = map.calculateAccumulatedFrame()
        let mapCenter = CGPoint(x: mapBounds.midX, y: mapBounds.midY)

        // Center the camera on the map
        cam.position = mapCenter

        // Zoom to fit: visible width = scene.size.width / cam.xScale
        // So to fit the whole map width/height, choose the larger required scale.
        let requiredX = mapBounds.width  / size.width
        let requiredY = mapBounds.height / size.height
        let scale = max(requiredX, requiredY) * 1.05   // add 5% margin
        cam.setScale(max(scale, 1e-3))                 // avoid zero
    }
    
    
}

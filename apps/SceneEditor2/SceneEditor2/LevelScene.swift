
import SpriteKit

final class LevelScene: SKScene {
    
    private var didSetup = false
    
    // For UI
    private weak var map: SKTileMapNode!
    private var unit: SKSpriteNode!
    private var highlightMap: SKTileMapNode!
    private var highlightGroup: SKTileGroup!
    
    // movement range in tiles
    private let moveRange = 1
    
    
    
//    override func didMove(to view: SKView) {
//        
//        // Place the map
//        backgroundColor = .black
//        
//        guard let map = childNode(withName: "Tile Map Node") as? SKTileMapNode else { return }
//        
//        // Place the map so its center is at the scene center (safe default)
//        map.anchorPoint = CGPoint(x: 0.5, y: 0.5)
//        map.position = CGPoint(x: size.width/2, y: size.height/2)
//        
//        // Ensure we have a camera
//        let cam: SKCameraNode
//        if let existing = self.camera {
//            cam = existing
//        } else {
//            cam = SKCameraNode()
//            addChild(cam)
//            self.camera = cam
//        }
//        
//        // Compute the map’s bounding box in scene coordinates
//        let mapBounds = map.calculateAccumulatedFrame()
//        let mapCenter = CGPoint(x: mapBounds.midX, y: mapBounds.midY)
//        
//        // Center the camera on the map
//        cam.position = mapCenter
//        
//        // Zoom to fit: visible width = scene.size.width / cam.xScale
//        // So to fit the whole map width/height, choose the larger required scale.
//        let requiredX = mapBounds.width  / size.width
//        let requiredY = mapBounds.height / size.height
//        let scaleMap = max(requiredX, requiredY) * 1.05   // add 5% margin
//        cam.setScale(max(scaleMap, 1e-3))                 // avoid zero
//        
//        
//        // Place the tile
//        let unit = SKSpriteNode(imageNamed: "aBlueUnit")
//        
//        let column = 1
//        let row = 2
//        
//        // find the center point of that tile (in map coordinates)
//        let tileCenter = map.centerOfTile(atColumn: column, row: row)
//        
//        // place your sprite there
//        unit.position = tileCenter
//        
//        // scale it to roughly fit inside a tile
//        let targetHeight = map.tileSize.height * 0.9
//        let scaleUnit = targetHeight / unit.size.height
//        unit.setScale(scaleUnit)
//        
//        // make sure it draws above the terrain
//        unit.zPosition = 100
//        
//        // anchor so "feet" site at bottom center
//        //unit.anchorPoint = CGPoint(x: 0.5, y: 0.0)
//        
//        // add it to the map, so it moves with the map
//        map.addChild(unit)
//        
//        
//    }
  
    override func didMove(to view: SKView) {
        guard highlightMap == nil else { return }
        backgroundColor = .black

        // A) Grab your existing terrain map
        guard let terrain = childNode(withName: "Tile Map Node") as? SKTileMapNode else { return }
        self.map = terrain
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
 
        //
        // This stanza does not seem to do anything.
        // The screen is already zoomed to the proper position
        //
        // Zoom to fit: visible width = scene.size.width / cam.xScale
        // So to fit the whole map width/height, choose the larger required scale.
        let requiredX = mapBounds.width  / size.width
        let requiredY = mapBounds.height / size.height
        let scaleMap = max(requiredX, requiredY) * 1.05   // add 5% margin
        cam.setScale(max(scaleMap, 1e-3))                 // avoid zero

        
        // B) Build a tiny TileSet from your Image Set "aMoveMarker" (the highlight icon)
        //    (If your image set is named differently, change it below.)
        let tex = SKTexture(imageNamed: "aMoveMarker")   // <-- your highlight Image Set name
        let def = SKTileDefinition(texture: tex, size: map.tileSize)
        let group = SKTileGroup(tileDefinition: def)
        group.name = "moveHighlight"
        self.highlightGroup = group

        let overlaySet = SKTileSet(tileGroups: [group], tileSetType: .hexagonalPointy)
        
        overlaySet.defaultTileSize = map.tileSize

        // C) Create an overlay tile map (same size as terrain) for highlights only
        let overlay = SKTileMapNode(tileSet: overlaySet,
                                    columns: map.numberOfColumns,
                                    rows: map.numberOfRows,
                                    tileSize: map.tileSize)
        overlay.enableAutomapping = false
        overlay.anchorPoint = map.anchorPoint
        overlay.position = map.position
        overlay.zPosition = map.zPosition + 50        // above terrain
        self.highlightMap = overlay
        addChild(overlay)

        // D) Add your unit from Image Set "aBlueUnit"
        let unitTex = SKTexture(imageNamed: "aBlueUnit") // <-- your unit Image Set
        let u = SKSpriteNode(texture: unitTex)
        //u.anchorPoint = CGPoint(x: 0.5, y: 0.0)         // “feet down”
        let targetH = map.tileSize.height * 0.9
        u.setScale(targetH / unitTex.size().height)

        // start position
        let startC = max(0, map.numberOfColumns/2)
        let startR = max(0, map.numberOfRows/2)
        u.position = map.centerOfTile(atColumn: startC, row: startR)
        u.zPosition = overlay.zPosition + 50
        map.addChild(u)                                  // attach to map so it moves with it
        self.unit = u
    }
 
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let pScene = t.location(in: self)
        let pMap   = t.location(in: map)

        // Did we tap the unit?
        if unit.contains(t.location(in: unit.parent!)) {
            showMoveHighlights(from: pMap)
        } else {
            // Tap on a highlighted tile to move the unit there
            let c = map.tileColumnIndex(fromPosition: pMap)
            let r = map.tileRowIndex(fromPosition: pMap)
            if isInBounds(c, r), highlightMap.tileGroup(atColumn: c, row: r) != nil {
                let dest = map.centerOfTile(atColumn: c, row: r)
                unit.run(.move(to: dest, duration: 0.2))
                clearHighlights()
            } else {
                clearHighlights()
            }
        }
    }

    private func isInBounds(_ c: Int, _ r: Int) -> Bool {
        return c >= 0 && c < map.numberOfColumns && r >= 0 && r < map.numberOfRows
    }

    private func clearHighlights() {
        guard highlightMap != nil else { return }
        for r in 0..<highlightMap.numberOfRows {
            for c in 0..<highlightMap.numberOfColumns {
                highlightMap.setTileGroup(nil, forColumn: c, row: r)
            }
        }
    }

    // Compute and paint move range
    private func showMoveHighlights(from unitPosInMap: CGPoint) {
        clearHighlights()

        let startC = map.tileColumnIndex(fromPosition: unitPosInMap)
        let startR = map.tileRowIndex(fromPosition: unitPosInMap)
        guard isInBounds(startC, startR) else { return }

        // ======= CHOOSE ONE NEIGHBOR MODEL =======

        // --- A) GRID (4-way Manhattan) ---
        func gridNeighbors(_ c: Int, _ r: Int) -> [(Int,Int)] {
            return [(c+1,r), (c-1,r), (c,r+1), (c,r-1)]
        }
        paintReachable(fromC: startC, fromR: startR, range: moveRange, neighbors: gridNeighbors)

        // --- B) HEX (pointy-top, column-offset “even-q” model) ---
        // If your hex map is pointy-top and columns are staggered, this is a good default.
        /*
        func hexNeighbors(_ c: Int, _ r: Int) -> [(Int,Int)] {
            // even-q vertical layout
            let even = (c % 2 == 0)
            let deltasEven = [(+1,0), (0,+1), (-1,+1), (-1,0), (0,-1), (+1,-1)]
            let deltasOdd  = [(+1,0), (+1,+1), (0,+1), (-1,0), (0,-1), (+1,-1)]
            let ds = even ? deltasEven : deltasOdd
            return ds.map { (dc,dr) in (c+dc, r+dr) }
        }
        paintReachable(fromC: startC, fromR: startR, range: moveRange, neighbors: hexNeighbors)
        */
    }

    // Generic BFS painter
    private func paintReachable(fromC: Int, fromR: Int, range: Int,
                                neighbors: (Int,Int)->[(Int,Int)]) {
        var visited = Set<[Int]>()
        var queue: [(c:Int, r:Int, d:Int)] = [(fromC, fromR, 0)]
        visited.insert([fromC, fromR])

        while !queue.isEmpty {
            let cur = queue.removeFirst()

            // skip the start tile itself if you want only destinations
            if cur.d > 0 {
                highlightMap.setTileGroup(highlightGroup, forColumn: cur.c, row: cur.r)
            }
            if cur.d == range { continue }

            for (nc, nr) in neighbors(cur.c, cur.r) {
                if isInBounds(nc, nr) && !visited.contains([nc, nr]) {
                    visited.insert([nc, nr])
                    queue.append((nc, nr, cur.d + 1))
                }
            }
        }
    }
    
}

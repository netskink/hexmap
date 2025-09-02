
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
        //let requiredX = mapBounds.width  / size.width
        //let requiredY = mapBounds.height / size.height
        //let scaleMap = max(requiredX, requiredY) * 1.05   // add 5% margin
        //cam.setScale(max(scaleMap, 1e-3))                 // avoid zero

        
        // B) Build a tiny TileSet from your Image Set "aMoveMarker" (the highlight icon)
        let markerTexture = SKTexture(imageNamed: "aMoveMarker")   // <-- your highlight Image Set name
        let markerDefinition = SKTileDefinition(texture: markerTexture, size: map.tileSize)
        let markerGroup = SKTileGroup(tileDefinition: markerDefinition)
        markerGroup.name = "moveHighlight"
        self.highlightGroup = markerGroup
        let overlaySet = SKTileSet(tileGroups: [markerGroup], tileSetType: .hexagonalPointy)
        overlaySet.defaultTileSize = map.tileSize

        // C) Create an overlay tile map (same size as terrain) for highlights only
        let overlayMap = SKTileMapNode(tileSet: overlaySet,
                                  columns: map.numberOfColumns,
                                  rows: map.numberOfRows,
                                  tileSize: map.tileSize)
        overlayMap.enableAutomapping = false
        overlayMap.anchorPoint = map.anchorPoint
        overlayMap.position = map.position
        overlayMap.zPosition = map.zPosition + 50        // above terrain
        self.highlightMap = overlayMap
        addChild(overlayMap)

        // D) Add your unit from Image Set "aBlueUnit"
        let unitTex = SKTexture(imageNamed: "aBlueUnit") // <-- your unit Image Set
        let unit = SKSpriteNode(texture: unitTex)
        let targetHeight = map.tileSize.height * 0.9
        unit.setScale(targetHeight / unitTex.size().height)

        // place unit at center of map
        let startC = max(0, map.numberOfColumns/2)
        let startR = max(0, map.numberOfRows/2)
        unit.position = map.centerOfTile(atColumn: startC, row: startR)
        unit.zPosition = overlayMap.zPosition + 50
        map.addChild(unit)                                  // attach to map so it moves with it
        self.unit = unit
    }

    // MARK: - Movement / Highlights
    private func inBounds(_ c: Int, _ r: Int) -> Bool {
        return c >= 0 && c < map.numberOfColumns && r >= 0 && r < map.numberOfRows
    }

    private func clearHighlights() {
        for r in 0..<highlightMap.numberOfRows {
            for c in 0..<highlightMap.numberOfColumns {
                highlightMap.setTileGroup(nil, forColumn: c, row: r)
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let pMap = t.location(in: map)

        if unit.contains(t.location(in: unit.parent ?? map)) {
            showMoveHighlights(from: pMap)
            return
        }

        let c = map.tileColumnIndex(fromPosition: pMap)
        let r = map.tileRowIndex(fromPosition: pMap)
        guard inBounds(c, r) else { clearHighlights(); return }

        if highlightMap.tileGroup(atColumn: c, row: r) != nil {
            let dest = map.centerOfTile(atColumn: c, row: r)
            unit.run(.move(to: dest, duration: 0.2))
        }
        clearHighlights()
    }

    private func isInBounds(_ c: Int, _ r: Int) -> Bool {
        return c >= 0 && c < map.numberOfColumns && r >= 0 && r < map.numberOfRows
    }


    // Compute and paint move range
    private func showMoveHighlights(from posInMap: CGPoint) {
        clearHighlights()

         let startC = map.tileColumnIndex(fromPosition: posInMap)
         let startR = map.tileRowIndex(fromPosition: posInMap)
         guard inBounds(startC, startR) else { return }

         // Hex neighbors: pointy-top, "even-q vertical" offset coordinates
         func hexNeighbors(_ c: Int, _ r: Int) -> [(Int,Int)] {
             if c % 2 == 0 {
                 return [(c+1,r), (c-1,r), (c,r+1), (c,r-1), (c+1,r-1), (c-1,r-1)]
             } else {
                 return [(c+1,r), (c-1,r), (c,r+1), (c,r-1), (c+1,r+1), (c-1,r+1)]
             }
         }

         // BFS search
         var seen = Set<[Int]>()
         var q: [(c:Int,r:Int,d:Int)] = [(startC, startR, 0)]
         seen.insert([startC, startR])

         while !q.isEmpty {
             let cur = q.removeFirst()
             if cur.d > 0 {
                 highlightMap.setTileGroup(highlightGroup, forColumn: cur.c, row: cur.r)
             }
             if cur.d == moveRange { continue }
             for (nc, nr) in hexNeighbors(cur.c, cur.r) where inBounds(nc, nr) && !seen.contains([nc, nr]) {
                 seen.insert([nc, nr])
                 q.append((nc, nr, cur.d + 1))
             }
         }
    }

    
}

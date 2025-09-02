
import SpriteKit


let qParity: QParity = .evenQ   // or .oddQ — pick the one that matches your map

final class LevelScene: SKScene {
    
    private var didSetup = false
    
    // For UI
    private weak var baseMap: SKTileMapNode!
    private weak var overlayMap: SKTileMapNode!
    private var unit: SKSpriteNode!
    private var highlightGroup: SKTileGroup!
    
    // movement range in tiles
    private let moveRange = 1
    
    
    
  
    override func didMove(to view: SKView) {
        guard overlayMap == nil else { return }
        backgroundColor = .black

        // A) Grab your existing terrain map
        guard let terrain = childNode(withName: "Tile Map Node") as? SKTileMapNode else { return }
        self.baseMap = terrain
        // Place the map so its center is at the scene center (safe default)
        baseMap.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        baseMap.position = CGPoint(x: size.width/2, y: size.height/2)

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
        let mapBounds = baseMap.calculateAccumulatedFrame()
        let mapCenter = CGPoint(x: mapBounds.midX, y: mapBounds.midY)

        // Center the camera on the map
        cam.position = mapCenter
 
        
        // B) Build a tiny TileSet from your Image Set "aMoveMarker" (the highlight icon)
        let markerTexture = SKTexture(imageNamed: "aMoveMarker")   // <-- your highlight Image Set name
        let markerDefinition = SKTileDefinition(texture: markerTexture, size: baseMap.tileSize)
        let markerGroup = SKTileGroup(tileDefinition: markerDefinition)
        markerGroup.name = "moveHighlight"
        self.highlightGroup = markerGroup
        let overlaySet = SKTileSet(tileGroups: [markerGroup], tileSetType: .hexagonalPointy)
        overlaySet.defaultTileSize = baseMap.tileSize

        // C) Create an overlay tile map (same size as terrain) for highlights only
        let overlayMap = SKTileMapNode(tileSet: overlaySet,
                                  columns: baseMap.numberOfColumns,
                                  rows: baseMap.numberOfRows,
                                  tileSize: baseMap.tileSize)
        overlayMap.enableAutomapping = false
        overlayMap.anchorPoint = baseMap.anchorPoint
        overlayMap.position = baseMap.position
        overlayMap.zPosition = baseMap.zPosition + 50        // above terrain
        self.overlayMap = overlayMap
        addChild(overlayMap)

        // D) Add your unit from Image Set "aBlueUnit"
        let unitTex = SKTexture(imageNamed: "aBlueUnit") // <-- your unit Image Set
        let unit = SKSpriteNode(texture: unitTex)
        let targetHeight = baseMap.tileSize.height * 0.9
        unit.setScale(targetHeight / unitTex.size().height)

        // place unit at center of map
        let startC = max(0, baseMap.numberOfColumns/2)
        let startR = max(0, baseMap.numberOfRows/2)
        unit.position = baseMap.centerOfTile(atColumn: startC, row: startR)
        unit.zPosition = overlayMap.zPosition + 50
        baseMap.addChild(unit)                                  // attach to map so it moves with it
        self.unit = unit
    }

    // MARK: - Movement / Highlights
    private func inBounds(_ c: Int, _ r: Int) -> Bool {
        var result: Bool
        result = c >= 0 && c < baseMap.numberOfColumns && r >= 0 && r < baseMap.numberOfRows
        print(result)
        return result
    }


    private func clearHighlights() {
        for r in 0..<overlayMap.numberOfRows {
            for c in 0..<overlayMap.numberOfColumns {
            overlayMap.setTileGroup(nil, forColumn: c, row: r)
            }
        }
    }
   
    
    // File-scope helper (no extensions needed)
    private func findAncestorNamedPrefix(_ node: SKNode?, prefix: String) -> SKNode? {
        var n = node
        while let cur = n {
            if cur.name?.hasPrefix(prefix) == true { return cur }
            n = cur.parent
        }
        return nil
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }

        let locInScene = t.location(in: self)

        // 1) Prefer unit-tap if a unit (or any of its children) was hit
        if let hit = findAncestorNamedPrefix(atPoint(locInScene), prefix: "aUnit"),
           let parent = hit.parent {
            // Convert the unit's position (in its parent space) into baseMap space
            let pInBase = baseMap.convert(hit.position, from: parent)
            let c = baseMap.tileColumnIndex(fromPosition: pInBase)
            let r = baseMap.tileRowIndex(fromPosition: pInBase)
            if (0..<baseMap.numberOfColumns).contains(c),
               (0..<baseMap.numberOfRows).contains(r) {
                showMoveHighlights(fromColumn: c, row: r)
                return
            }
        }

        // 2) Otherwise, compute from the tapped tile
        let pInBase = baseMap.convert(locInScene, from: self)
        let c = baseMap.tileColumnIndex(fromPosition: pInBase)
        let r = baseMap.tileRowIndex(fromPosition: pInBase)
        if (0..<baseMap.numberOfColumns).contains(c),
           (0..<baseMap.numberOfRows).contains(r) {
            showMoveHighlights(fromColumn: c, row: r)
        }
    }
    
    
    // Compute and paint move range
    // MARK: - EditorScene overlay API
    func showMoveHighlights(from axial: Axial) {
        print("showMoveHighlights")
        guard let marker = baseMap.tileSet.tileGroups.first(where: {
            $0.name == "aMoveMarker" })
        else {
            return
        }

        // Clear overlay (fast clear: iterate rows/cols; for big maps you may want to track dirty cells)
        for c in 0..<overlayMap.numberOfColumns {
            for r in 0..<overlayMap.numberOfRows {
                overlayMap.setTileGroup(nil, forColumn: c, row: r)
            }
        }

        // Compute axial neighbors and paint
        for nb in neighbors(of: axial) {
            let (c, r) = axialToOffset(nb, parity: qParity)
            guard (0..<overlayMap.numberOfColumns).contains(c),
                  (0..<overlayMap.numberOfRows).contains(r) else { continue }
            overlayMap.setTileGroup(marker, forColumn: c, row: r)
        }
    }

    // Back-compat overload if older code passes col/row:
    func showMoveHighlights(fromColumn col: Int, row: Int) {
        let a = offsetToAxial(col: col, row: row, parity: qParity)
        showMoveHighlights(from: a)
    }
}

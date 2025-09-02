
import SpriteKit


//let qParity: QParity = .evenQ   // or .oddQ — pick the one that matches your map
let qParity: QParity = .oddQ   // or .oddQ — pick the one that matches your map

final class LevelScene: SKScene {
    
    private var didSetup = false
    
    // For UI
    private weak var baseMap: SKTileMapNode!
    private weak var overlayMap: SKTileMapNode!
    private var unit: SKSpriteNode!
    private var highlightGroup: SKTileGroup!
    private let markerLayer = SKNode()
    private let moveMarkerImageName = "aMoveMarker" // <-- add an Image Set with this name

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
        baseMap.addChild(unit)   // attach to map so it moves with it
        self.unit = unit


        
        // In didMove(to:)
        markerLayer.removeFromParent()
        baseMap.addChild(markerLayer)        // <— attach to baseMap
        markerLayer.zPosition = 1            // above tiles but below units (adjust as needed)
    }
    
    
    


    private func clearMarkers() {
        markerLayer.removeAllChildren()
    }
    
    func placeUnit(named imageName: String, atColumn c: Int, row r: Int) {
        
        let p = baseMap.centerOfTile(atColumn: c, row: r)
        let m = SKSpriteNode(imageNamed: moveMarkerImageName)
        m.position = p                       // now correct because parent == baseMap
        markerLayer.addChild(m)
        
        
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

        // Prefer a unit if tapped
        if let unitNode = findAncestorNamedPrefix(atPoint(locInScene), prefix: "unit:"),
           let parent = unitNode.parent {
            let pInBase = baseMap.convert(unitNode.position, from: parent)
            let c = baseMap.tileColumnIndex(fromPosition: pInBase)
            let r = baseMap.tileRowIndex(fromPosition: pInBase)
            guard (0..<baseMap.numberOfColumns).contains(c),
                  (0..<baseMap.numberOfRows).contains(r) else { return }
            showMoveHighlights(fromColumn: c, row: r)
            return
        }

        // Otherwise, use the touched tile
        let pInBase = baseMap.convert(locInScene, from: self)
        let c = baseMap.tileColumnIndex(fromPosition: pInBase)
        let r = baseMap.tileRowIndex(fromPosition: pInBase)
        guard (0..<baseMap.numberOfColumns).contains(c),
              (0..<baseMap.numberOfRows).contains(r) else { return }
        showMoveHighlights(fromColumn: c, row: r)
    }
    
    // Compute and paint move range
    // MARK: - EditorScene overlay API
    func showMoveHighlights(fromColumn col: Int, row: Int) {
        clearMarkers()

        // Convert to axial if your neighbor logic expects axial
        let centerAxial = offsetToAxial(col: col, row: row, parity: qParity)
        let nbs = neighbors(of: centerAxial)

        for nb in nbs {
            let (c, r) = axialToOffset(nb, parity: qParity)
            guard (0..<baseMap.numberOfColumns).contains(c),
                  (0..<baseMap.numberOfRows).contains(r) else { continue }

            let p = baseMap.centerOfTile(atColumn: c, row: r)
            let m = SKSpriteNode(imageNamed: moveMarkerImageName)
            m.name = "marker:\(c),\(r)"
            m.position = p
            m.zPosition = markerLayer.zPosition
            markerLayer.addChild(m)
        }
    }
    
    
    
}

//
//  GameScene.swift
//  PG1
//
//  Created by john davis on 9/11/25.
//

import SpriteKit
import GameplayKit

class GameScene: SKScene {
    
    // Reference to the World node from the SKS file
    var worldNode: SKNode!
    // Referenece to the Tile Map Node from the SKS file
    var baseMap: SKTileMapNode!
    
    // used by touchesBegan to detect taps on blueUnit and potential move tiles.
    var selectedUnit: SKSpriteNode?
    var possibleMoveMarkers: [SKSpriteNode] = []
    //var moveMarkers: [SKSpriteNode] = []

    override func didMove(to view: SKView) {
        // Find nodes by name
        worldNode = childNode(withName: "World")
        baseMap = worldNode.childNode(withName: "BaseMap") as? SKTileMapNode

        // Optional: Center world if needed
        //if worldNode.parent == self {
        //    worldNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        //}
        
        // Example: Add unit to row 3, column 5
        addUnit(named: "blueUnit", atRow: 7, column: 12)
    }
    
    func addUnit(named imageName: String, atRow row: Int, column col: Int) {
        guard let tileMap = self.baseMap else { return }

        // Convert tile coordinate to position in scene
        let position = tileMap.centerOfTile(atColumn: col, row: row)

        // Create the unit sprite
        let unit = SKSpriteNode(imageNamed: imageName)
        unit.position = position
        unit.zPosition = 10 // make sure it's above the tile map
        unit.name = "blueUnit"

        // Add to world node so it pans/zooms with the map
        worldNode.addChild(unit)
    }
    
 
    /// Returns the 6 neighbors for a flat-top hex grid.
    /// Important: SpriteKit’s flat-top grids are staggered by *column*, so parity check is on `column % 2`.
    /// Using row parity instead would give incorrect results (neighbors shifted diagonally).
    /// Flat-top hex neighbors using *column parity* (q-offset)
    func flatTopHexNeighbors(row r: Int, column c: Int, parityIsEvenQ: Bool) -> [(row: Int, column: Int)] {
        // even-q (even columns are "raised")
        // Even-column offsets (column 0, 2, 4, … are raised)
        let evenQ = [(r-1, c  ), (r-1, c-1), (r, c-1),
                     (r+1, c  ), (r, c+1), (r-1, c+1)]
        // Odd-column offsets (column 1, 3, 5, … are raised)
        // odd-q  (odd columns are "raised")
        let oddQ  = [(r-1, c  ), (r,   c-1), (r+1, c-1),
                     (r+1, c  ), (r+1, c+1), (r,   c+1)]

        // Choose based on column parity
        // Select the offsets based on column parity at runtime:
        if c % 2 == 0 {
            // even column
            return evenQ
        } else {
            // odd column
            return oddQ
        }
    }
    
    
   

    func clearMoveMarkers() {
        possibleMoveMarkers.forEach { $0.removeFromParent() }
        possibleMoveMarkers.removeAll()
    }

    
    func highlightNeighbors(of unit: SKSpriteNode, on map: SKTileMapNode) {
        clearMoveMarkers()
        guard let here = currentTile(of: unit, on: map) else { return }

        // Build neighbors list.  It depends on column parity (see function above)
        let neighbors = flatTopHexNeighbors(row: here.row, column: here.column, parityIsEvenQ: true)

        for (nr, nc) in neighbors {
            guard map.isValidTile(row: nr, column: nc) else { continue }
            // This gives the exact *center point* of the tile in map-local coordinates
            let center = map.centerOfTile(atColumn: nc, row: nr)

            // Place a `whitebe` sprite at that center.
            // Adding it as a child of the map keeps positions consistent with tile coordinates.
            let marker = SKSpriteNode(imageNamed: "whitebe")
            marker.name = "MoveMarker"
            marker.position = center // center is already in the map's local space
            marker.zPosition = 10
            marker.setScale(1.0)           // adjust scale if your tile art needs it
            map.addChild(marker)
            possibleMoveMarkers.append(marker)
        }
    }

    func currentTile(of unit: SKSpriteNode, on map: SKTileMapNode) -> (row: Int, column: Int)? {
        // Convert the unit's *parent-space* position into the map's local coordinates
        
        // Step 1: Convert the unit’s position from its parent (`World`) into map-local coordinates
        guard let parent = unit.parent else { return nil }
        let local = map.toLocal(from: unit.position, of: parent)

        // Step 2: Translate local coordinates into (row, column) using tile index functions
        return map.tileCoordinateForLocal(local)
    }
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let scenePoint = touch.location(in: self)

        // 1. Did we tap the unit?
        // If yes, select it and show neighbors.
        if let unit = nodes(at: scenePoint).first(where: { $0.name == "blueUnit" }) as? SKSpriteNode,
           let map = childNode(withName: "//BaseMap") as? SKTileMapNode {
            selectedUnit = unit
            highlightNeighbors(of: unit, on: map)
            return
        }

        // 2. Did we tap a move marker?
        if let marker = nodes(at: scenePoint).first(where: { $0.name == "MoveMarker" }) as? SKSpriteNode,
           let unit = selectedUnit,
           let map = childNode(withName: "//BaseMap") as? SKTileMapNode {

            // marker.position is in MAP space; convert to unit’s parent (World) to move there
            // Convert marker’s position (map-local) back into unit’s parent (World) space
            if let unitParent = unit.parent {
                let destInParent = unitParent.convert(marker.position, from: map)
                // Smooth move animation
                let move = SKAction.move(to: destInParent, duration: 0.25)
                unit.run(move)
            }

            // After move, clear markers and reset selection
            clearMoveMarkers()
            selectedUnit = nil
            return
        }

        // 3) Tapped elsewhere — clear selection
        clearMoveMarkers()
        selectedUnit = nil
    }
    
    
}



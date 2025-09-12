//
//  extensions.swift
//  PG1
//
//  Created by john davis on 9/12/25.
//


import SpriteKit
import GameplayKit



extension SKTileMapNode {
    /// Convert a point from another node’s coordinate system into this map’s local coordinates.
    /// Needed because your units live under `World` but markers are added to `BaseMap`.
    func toLocal(from point: CGPoint, of node: SKNode) -> CGPoint {
        return self.convert(point, from: node)
    }

    /// Check if (row, column) is inside map bounds.
    func isValidTile(row: Int, column: Int) -> Bool {
        return row >= 0 && row < numberOfRows && column >= 0 && column < numberOfColumns
    }

    /// Get the (row, column) of a point that is already in the map’s local space.
    /// This is used after converting from the unit’s parent coordinates into the map’s system.
    func tileCoordinateForLocal(_ localPoint: CGPoint) -> (row: Int, column: Int)? {
        let col = tileColumnIndex(fromPosition: localPoint)
        let row = tileRowIndex(fromPosition: localPoint)
        guard isValidTile(row: row, column: col) else { return nil }
        return (row, col)
    }
}

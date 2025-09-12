import SpriteKit

public extension SKTileMapNode {

    /// Center point (map-local) for (col,row)
    func center(_ col: Int, _ row: Int) -> CGPoint {
        centerOfTile(atColumn: col, row: row)
    }

    /// Robust neighbor finder: returns up to the six closest neighboring tiles
    /// around (col,row) using only map-local geometry. No parity/axial tables.
    func proximityNeighbors(col: Int, row: Int) -> [(col: Int, row: Int)] {
        guard col >= 0, col < numberOfColumns, row >= 0, row < numberOfRows else { return [] }

        let c0 = center(col, row)
        var candidates: [(Int, Int, CGFloat)] = []

        // Search a small window around the tile; ±2 is plenty for hex layouts.
        let cMin = max(0, col - 2), cMax = min(numberOfColumns - 1, col + 2)
        let rMin = max(0, row - 2), rMax = min(numberOfRows    - 1, row + 2)

        for c in cMin...cMax {
            for r in rMin...rMax {
                if c == col && r == row { continue }
                let d = hypot(center(c, r).x - c0.x, center(c, r).y - c0.y)
                candidates.append((c, r, d))
            }
        }

        // Sort by distance from the current tile’s center and take the first 6
        candidates.sort { $0.2 < $1.2 }

        // Deduplicate (can happen near borders) and clip to 6
        var out: [(Int, Int)] = []
        out.reserveCapacity(6)
        for (c, r, _) in candidates {
            if !out.contains(where: { $0.0 == c && $0.1 == r }) {
                out.append((c, r))
                if out.count == 6 { break }
            }
        }
        return out
    }

    // --- Bounds / Walkability in offset coords (unchanged) ---

    func inBounds(col: Int, row: Int) -> Bool {
        col >= 0 && col < numberOfColumns && row >= 0 && row < numberOfRows
    }

    /// Default walkable unless userData["blocked"] == true
    func isWalkable(col: Int, row: Int) -> Bool {
        guard inBounds(col: col, row: row) else { return false }
        if let def = tileDefinition(atColumn: col, row: row),
           let blocked = def.userData?["blocked"] as? Bool, blocked { return false }
        return true
    }

    // --- BFS that uses proximity neighbors ---

    func bfsPath(from start: (col: Int, row: Int),
                 to goal: (col: Int, row: Int)) -> [(col: Int, row: Int)]? {
        if start == goal { return [start] }
        var q: [(Int, Int)] = [start]
        var came: [String: (Int, Int)] = [:]
        var seen: Set<String> = ["\(start.col),\(start.row)"]

        while !q.isEmpty {
            let cur = q.removeFirst()
            for n in proximityNeighbors(col: cur.0, row: cur.1) where isWalkable(col: n.col, row: n.row) {
                let key = "\(n.col),\(n.row)"
                if seen.contains(key) { continue }
                seen.insert(key); came[key] = cur
                if n == goal {
                    var path: [(Int, Int)] = [goal]
                    var c = goal
                    while let p = came["\(c.0),\(c.1)"], p != start {
                        path.append(p); c = p
                    }
                    path.append(start)
                    return path.reversed()
                }
                q.append(n)
            }
        }
        return nil
    }

    func nextStepToward(start: (col: Int, row: Int),
                        goal: (col: Int, row: Int)) -> (col: Int, row: Int)? {
        guard let path = bfsPath(from: start, to: goal), path.count >= 2 else { return nil }
        return path[1]
    }
}

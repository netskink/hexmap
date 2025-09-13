import SpriteKit

public extension SKTileMapNode {

    // MARK: - Geometry helpers

    /// Returns the map-local **center point** for the tile at `(col, row)`.
    /// Useful for converting grid coordinates to a precise CGPoint on the map.
    /// - Parameters:
    ///   - col: Column index in the tile map.
    ///   - row: Row index in the tile map.
    /// - Returns: A CGPoint in the tile map’s local coordinate space.
    func center(_ col: Int, _ row: Int) -> CGPoint {
        centerOfTile(atColumn: col, row: row)
    }

    // MARK: - Neighborhoods

    /// Computes the **six closest neighbor tiles** around `(col, row)` using geometry
    /// rather than parity/offset lookup tables. This is robust for **flat-top hex maps**
    /// where coordinate-parity rules can be error-prone.
    ///
    /// Behavior:
    /// - Filters to **in-bounds** tiles only.
    /// - Sorts candidates by **Euclidean distance** from the center of `(col,row)`.
    /// - Returns up to **six** neighbors (fewer on edges/corners).
    ///
    /// - Parameters:
    ///   - col: Origin column.
    ///   - row: Origin row.
    /// - Returns: An array of neighbor coordinates `(col, row)`, nearest first.
    func proximityNeighbors(col: Int, row: Int) -> [(col: Int, row: Int)] {
        // (Collect candidate indices around c0, measure distance to centers,
        //  sort by distance, de-duplicate, then trim to 6.)
        guard col >= 0, col < numberOfColumns, row >= 0, row < numberOfRows else { return [] }

        
        // STEP: Compute center point of origin tile (for distance sorting)
        // let c0 = center(col, row)

        // STEP: Enumerate candidate axial/offset neighbors around (col,row)
        // var candidates: [(Int,Int)] = [...]

        // STEP: Filter to in-bounds tiles only
        // candidates = candidates.filter { inBounds(col:$0.0, row:$0.1) }

        // STEP: Sort by Euclidean distance to origin center, nearest first
        // candidates.sort { dist(center($0.0,$0.1), c0) < dist(center($1.0,$1.1), c0) }

        // STEP: Deduplicate (if needed) and cap at six entries
        // return Array(OrderedSet(candidates).prefix(6))
        
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

    // MARK: - Bounds / Walkability

    /// Returns `true` if `(col, row)` lies within the tile map’s bounds.
    /// Useful as a quick guard before sampling tiles or metadata.
    func inBounds(col: Int, row: Int) -> Bool {
        col >= 0 && col < numberOfColumns && row >= 0 && row < numberOfRows
    }

    /// Returns whether a tile is **walkable**.
    /// Default is walkable unless explicitly marked otherwise (e.g., in
    /// `userData["blocked"] == true` or via your tile definition’s metadata).
    ///
    /// Notes:
    /// - This allows level art to control pathfinding without hard-coding.
    /// - Combine with `inBounds` to avoid sampling outside the map.
    func isWalkable(col: Int, row: Int) -> Bool {
        guard inBounds(col: col, row: row) else { return false }
        if let def = tileDefinition(atColumn: col, row: row),
           let blocked = def.userData?["blocked"] as? Bool, blocked { return false }
        return true
    }

    // MARK: - Pathfinding (BFS)

    /// Breadth-first search from `start` to `goal`, traversing only **walkable**
    /// neighbors (as provided by `proximityNeighbors` + `isWalkable`).
    ///
    /// - Parameters:
    ///   - start: Starting coordinate `(col, row)`.
    ///   - goal: Goal coordinate `(col, row)`.
    /// - Returns: The full path **including** start and goal, or `nil` if unreachable.
    /// - Complexity: `O(V + E)` for the explored subgraph (typical BFS).
    ///
    ///
    /// Breadth-first search (BFS) on the hex grid to find a **shortest path**
    /// from `start` to `goal`, traversing only tiles considered **walkable**.
    /// Uses a queue and a predecessor map to reconstruct the final route.
    ///
    /// Pseudocode (high-level):
    /// ```text
    /// if start == goal: return [start]
    ///
    /// queue ← [start]
    /// visited ← { start }
    /// cameFrom ← empty map
    ///
    /// while queue not empty:
    ///   current ← queue.popFront()
    ///   if current == goal:
    ///     break
    ///
    ///   for each neighbor in proximityNeighbors(current) where isWalkable(neighbor):
    ///     if neighbor ∉ visited:
    ///       visited.insert(neighbor)
    ///       cameFrom[neighbor] ← current
    ///       queue.pushBack(neighbor)
    ///
    /// if goal ∉ cameFrom and goal != start:
    ///   return nil  // unreachable
    ///
    /// // Reconstruct path from goal → start using cameFrom
    /// path ← [goal]
    /// while path.last != start:
    ///   path.append(cameFrom[path.last]!)
    /// reverse(path)
    /// return path
    /// ```
    ///
    /// Notes & invariants:
    /// - **Grid**: Assumes a flat-top hex map; neighbor generation comes from
    ///   `proximityNeighbors(col:row:)` which already filters in-bounds tiles.
    /// - **Walkability**: `isWalkable(col:row:)` gates traversal; adjust it to tie into
    ///   your tile metadata (e.g., `userData["blocked"] == true`).
    /// - **Shortest path**: BFS guarantees the **fewest steps** (unweighted edges).
    /// - **Edge cases**:
    ///   - If `start == goal`, returns `[start]`.
    ///   - If `goal` is unreachable, returns `nil`.
    ///
    /// Complexity:
    /// - Time: `O(V + E)` over the explored region.
    /// - Space: `O(V)` for `visited` and `cameFrom`.
    func bfsPath(from start: (col: Int, row: Int),
                 to goal: (col: Int, row: Int)) -> [(col: Int, row: Int)]? {
        // (Queue-based search, predecessor map, reconstruct on reaching goal.)
        if start == goal { return [start] }
        var q: [(Int, Int)] = [start]
        var came: [String: (Int, Int)] = [:]
        var seen: Set<String> = ["\(start.col),\(start.row)"]

        // STEP: Trivial case — same start/goal
        // if start == goal { return [start] }

        // STEP: Initialize queue, visited, and predecessor map
        // var q: [(Int,Int)] = [start]
        // var visited: Set<Pair> = [start]
        // var cameFrom: [Pair: Pair] = [:]

        // STEP: Main BFS loop
        // while !q.isEmpty {
        //   let current = q.removeFirst()
        //   if current == goal { break }

        //   // STEP: Explore walkable neighbors
        //   for n in proximityNeighbors(col:current.col, row:current.row) where isWalkable(col:n.col, row:n.row) {
        //     // STEP: Discover unvisited neighbor
        //     if !visited.contains(n) {
        //       visited.insert(n)
        //       cameFrom[n] = current
        //       q.append(n) // enqueue
        //     }
        //   }
        // }

        // STEP: If goal never discovered, return nil (unreachable)
        // guard goal == start || cameFrom.keys.contains(goal) else { return nil }

        // STEP: Reconstruct path goal → start using cameFrom
        // var path: [Pair] = [goal]
        // while path.last! != start { path.append(cameFrom[path.last!]!) }
        // path.reverse()
        // return path
        
        
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
    /// Convenience: returns the **next best step** from `start` toward `goal`
    /// using BFS shortest path. If no path exists, returns `nil`.
    ///
    /// - Returns: The coordinate to move to **next**, not the full path.
    /// Returns the **next step** along a BFS shortest path from `start` toward `goal`.
    /// This is a convenience wrapper over `bfsPath(from:to:)`.
    ///
    /// Behavior:
    /// - Computes the full BFS path and, if available, returns `path[1]`
    ///   (the immediate move after `start`).
    /// - If `start == goal`, or no path exists, returns `nil`.
    ///
    /// Use when:
    /// - You’re steering a unit one tile at a time toward a destination.
    /// - You want consistent “shortest-step” behavior without exposing full paths.
    func nextStepToward(start: (col: Int, row: Int),
                        goal: (col: Int, row: Int)) -> (col: Int, row: Int)? {
        // STEP: Compute shortest path; if it exists, return the first move after start
        guard let path = bfsPath(from: start, to: goal), path.count >= 2 else { return nil }
        return path[1]
    }
}

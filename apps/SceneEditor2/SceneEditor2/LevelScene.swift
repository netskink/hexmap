import SpriteKit


//let qParity: QParity = .evenQ   // or .oddQ — pick the one that matches your map
let qParity: QParity = .oddQ   // or .oddQ — pick the one that matches your map

final class LevelScene: SKScene {


    // Strong refs; the scene owns these nodes.
    private var map: SKTileMapNode!
    private var unit: SKSpriteNode!
    private var highlightMap: SKTileMapNode!
    private var highlightGroup: SKTileGroup!

  
#if DEBUG
private var debugMode = true
private var debugDots: [SKNode] = []
#endif

    // Movement range in tiles
    private let moveRange = 1

    // Toggle this to .grid if you want 4-way movement on a rect grid.
    private enum NeighborMode { case grid, hex }
    private let neighborMode: NeighborMode = .hex   // pointy-top hex map

    // === Geometry-derived hex neighbor offsets ===
    // Once computed, these are the six (dc,dr) you should use for neighbors.
    // Order is clockwise starting near +X (east).
    private var hexDeltas: [(Int, Int)]?

    // MARK: - Scene lifecycle


    override func didMove(to view: SKView) {
        guard overlayMap == nil else { return }
        backgroundColor = .black

        // A) Grab your existing terrain map (by name or first SKTileMapNode)
        let terrain = (childNode(withName: "Tile Map Node") as? SKTileMapNode)
            ?? (children.compactMap { $0 as? SKTileMapNode }.first)

        guard let map = terrain else {
            assertionFailure("No SKTileMapNode found. Name it 'Tile Map Node' or add one to the scene.")
            return
        }
        self.map = map

        // (Optional) DEBUG: render (c,r) labels on every tile to validate indexing.
        #if DEBUG
        addDebugCRLabels()
        #endif

        // Center map in the scene (safe default)
        map.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        map.position = CGPoint(x: size.width/2, y: size.height/2)

        // Ensure camera
        let cam: SKCameraNode = self.camera ?? {
            let c = SKCameraNode()
            addChild(c)
            self.camera = c
            return c
        }()

        // Center camera on map and zoom to fit
        let mapBounds = map.calculateAccumulatedFrame()
        cam.position = CGPoint(x: mapBounds.midX, y: mapBounds.midY)

        // Correct fit math: smaller scale shows more world
        let wRatio = mapBounds.width  / size.width
        let hRatio = mapBounds.height / size.height
        let fitScale = 1.0 / max(wRatio, hRatio) * 0.95  // 5% padding inside the edges
        cam.setScale(max(fitScale, 1e-3))

        // B) Build a tiny TileSet from your Image Set "aMoveMarker"
        let markerTex = SKTexture(imageNamed: "aMoveMarker")
        markerTex.filteringMode = .nearest   // optional: crisper pixels
        let def = SKTileDefinition(texture: markerTex, size: map.tileSize)
        let group = SKTileGroup(tileDefinition: def)
        group.name = "moveHighlight"
        self.highlightGroup = group

        let overlaySet = SKTileSet(tileGroups: [group], tileSetType: .hexagonalPointy)
        overlaySet.defaultTileSize = map.tileSize

        // C) Create an overlay tile map (same grid) for highlights only
        let overlay = SKTileMapNode(tileSet: overlaySet,
                                    columns: map.numberOfColumns,
                                    rows: map.numberOfRows,
                                    tileSize: map.tileSize)
        overlay.enableAutomapping = false
        overlay.zPosition = map.zPosition + 50

        // Attach overlay to the map so any future map moves/pans also move highlights.
        map.addChild(overlay)
        // Keep overlay perfectly aligned with map
        overlay.anchorPoint = map.anchorPoint
        overlay.position = .zero

        self.highlightMap = overlay

        // D) Add your unit from Image Set "aBlueUnit"
        let unitTex = SKTexture(imageNamed: "aBlueUnit")
        unitTex.filteringMode = .nearest     // optional: crisper pixels
        let u = SKSpriteNode(texture: unitTex)
        let targetH = map.tileSize.height * 0.9
        u.setScale(targetH / unitTex.size().height)

        let startC = max(0, map.numberOfColumns / 2)
        let startR = max(0, map.numberOfRows / 2)
        u.position = map.centerOfTile(atColumn: startC, row: startR)
        u.zPosition = overlay.zPosition + 50

        // Put the unit on the map so it lives in the same coordinate space
        map.addChild(u)
        self.unit = u

        // E) Derive the six neighbor deltas from geometry (once).
        deriveHexDeltas()
    }

    // Re-fit camera if the scene size changes (rotation, split view, etc.)
    override func didChangeSize(_ oldSize: CGSize) {
        guard let cam = camera, let map = self.map else { return }

        // Keep map centered in the scene
        map.position = CGPoint(x: size.width/2, y: size.height/2)

        // Recompute bounds and fit scale
        let mapBounds = map.calculateAccumulatedFrame()
        cam.position = CGPoint(x: mapBounds.midX, y: mapBounds.midY)

        let wRatio = mapBounds.width  / size.width
        let hRatio = mapBounds.height / size.height
        let fitScale = 1.0 / max(wRatio, hRatio) * 0.95
        cam.setScale(max(fitScale, 1e-3))
    }

    // MARK: - Input

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let pMap = t.location(in: map)

        // Did we tap the unit?
        if let parent = unit.parent, unit.contains(t.location(in: parent)) {
            showMoveHighlightsFromUnit() // use the unit’s actual center
            return
        }

        // Tap on a highlighted tile to move the unit there
        let c = map.tileColumnIndex(fromPosition: pMap)
        let r = map.tileRowIndex(fromPosition: pMap)
        if isInBounds(c, r),
           highlightMap.tileGroup(atColumn: c, row: r) != nil,
           map.tileGroup(atColumn: c, row: r)?.name != "watergroup" // block water
        {
            let dest = map.centerOfTile(atColumn: c, row: r)
            unit.run(.move(to: dest, duration: 0.2))
        }
        clearHighlights()
    }
  
    
    

    
    #if DEBUG
    private let touchViz = TouchVisualizer()
    #endif

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let p = t.location(in: self)
            #if DEBUG
            touchViz.show(at: p, in: self)
            #endif
        }
        super.touchesBegan(touches, with: event)
    }

    // MARK: - Helpers

    private func isInBounds(_ c: Int, _ r: Int) -> Bool {
        c >= 0 && c < map.numberOfColumns && r >= 0 && r < map.numberOfRows
    }

    private func showMoveHighlightsFromUnit() {
        showMoveHighlights(from: unit.position)  // use the unit’s actual center
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
    
    /// Returns the 6 nearest neighbor tile coordinates around (c0,r0)
    /// by looking at centers and picking the six closest tiles.
    /// Works regardless of even/odd column or row direction.
    /// Returns the ~6 nearest neighbor tile coordinates around (c0,r0),
    /// constrained by a distance band so we don't accidentally include
    /// far tiles when we're near the edge of the map.
    private func nearestSixNeighbors(from c0: Int, r0: Int) -> [(Int, Int)] {
        struct Cand { let c: Int; let r: Int; let d2: CGFloat }
        let p0 = map.centerOfTile(atColumn: c0, row: r0)

        var cands: [Cand] = []
        for dr in -2...2 {
            for dc in -2...2 {
                if dc == 0 && dr == 0 { continue }
                let c = c0 + dc, r = r0 + dr
                if !isInBounds(c, r) { continue }
                let p  = map.centerOfTile(atColumn: c, row: r)
                let dx = p.x - p0.x, dy = p.y - p0.y
                let d2 = dx*dx + dy*dy
                cands.append(Cand(c: c, r: r, d2: d2))
            }
        }

        // Sort by distance; find the closest ring distance
        cands.sort { $0.d2 < $1.d2 }
        guard let base = cands.first?.d2, base.isFinite else { return [] }

        // Accept candidates within a tight band around the closest distance.
        // This prevents tiles ~2 steps away like (0,0) from sneaking in.
        // Tweak multipliers if needed; these are usually perfect for SK hex spacing.
        let cutoffTight: CGFloat = base * 1.35  // primary ring
        let cutoffLoose: CGFloat = base * 1.75  // fallback if we got < 6

        var out: [(Int,Int)] = []
        var seen = Set<String>()

        // 1) Take unique neighbors within the tight band
        for cand in cands where cand.d2 <= cutoffTight {
            let key = "\(cand.c),\(cand.r)"
            if seen.insert(key).inserted {
                out.append((cand.c, cand.r))
                if out.count == 6 { return out }
            }
        }

        // 2) If we still have < 6 (edge cases), allow a slightly looser band.
        for cand in cands where cand.d2 <= cutoffLoose {
            let key = "\(cand.c),\(cand.r)"
            if seen.insert(key).inserted {
                out.append((cand.c, cand.r))
                if out.count == 6 { break }
            }
        }

        // Return however many we have (can be < 6 at edges; that's OK).
        return out
    }
#if DEBUG
private func clearDebugDots() {
    for n in debugDots { n.removeFromParent() }
    debugDots.removeAll()
}

private func dot(at p: CGPoint, radius: CGFloat = 6, color: SKColor) -> SKShapeNode {
    let n = SKShapeNode(circleOfRadius: radius)
    n.position = p
    n.fillColor = color
    n.strokeColor = color
    n.lineWidth = 1
    n.zPosition = 2000
    return n
}

/// Draw numbered dots on the 6 neighbors and print details
private func showDebugNeighbors(from c0: Int, r0: Int) {
    guard debugMode else { return }
    clearDebugDots()

    // Draw a dot at center tile
    let p0 = map.centerOfTile(atColumn: c0, row: r0)
    let centerDot = dot(at: p0, radius: 8, color: .yellow)
    map.addChild(centerDot)
    debugDots.append(centerDot)

    // Collect & sort candidates by distance so we can see why 6 were chosen
    struct Cand { let c: Int; let r: Int; let d2: CGFloat }
    var cands: [Cand] = []
    for dr in -2...2 {
        for dc in -2...2 {
            if dc == 0 && dr == 0 { continue }
            let c = c0 + dc, r = r0 + dr
            if !isInBounds(c, r) { continue }
            let p  = map.centerOfTile(atColumn: c, row: r)
            let dx = p.x - p0.x, dy = p.y - p0.y
            let d2 = dx*dx + dy*dy
            cands.append(Cand(c: c, r: r, d2: d2))
        }
    }
    cands.sort { $0.d2 < $1.d2 }

    // Pick first 6 unique
    var chosen: [(Int,Int,CGFloat)] = []
    var seen = Set<String>()
    for cand in cands {
        let key = "\(cand.c),\(cand.r)"
        if seen.contains(key) { continue }
        seen.insert(key)
        chosen.append((cand.c, cand.r, cand.d2))
        if chosen.count == 6 { break }
    }

    // Print the chosen 6 with distances
    let list = chosen.map { "(\($0.0),\($0.1)) d2=\(Int($0.2))" }.joined(separator: ", ")
    print("DEBUG chosen 6 from (\(c0),\(r0)): [\(list)]")

    // Draw dots for the chosen 6 (green) and a small index label
    for (idx, entry) in chosen.enumerated() {
        let (c, r, _) = entry
        let p = map.centerOfTile(atColumn: c, row: r)
        let d = dot(at: p, radius: 5, color: .green)
        map.addChild(d)
        debugDots.append(d)

        let label = SKLabelNode(fontNamed: "Menlo")
        label.fontSize = 10
        label.text = "\(idx)"
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: p.x, y: p.y + 12)
        label.zPosition = 2001
        map.addChild(label)
        debugDots.append(label)
    }
}
#endif

#if DEBUG
private func printNeighbors(of c: Int, _ r: Int) {
    let neigh = nearestSixNeighbors(from: c, r0: r)
    print("Neighbors(\(c),\(r)) -> \(neigh)")
}
#endif

    
    private func showMoveHighlights(from unitPosInMap: CGPoint) {
        clearHighlights()

        let startC = map.tileColumnIndex(fromPosition: unitPosInMap)
        let startR = map.tileRowIndex(fromPosition: unitPosInMap)
#if DEBUG
if debugMode {
    showDebugNeighbors(from: startC, r0: startR)
}
#endif
        guard isInBounds(startC, startR) else { return }

        #if DEBUG
        print("Start tile (c,r) = (\(startC),\(startR))")
        if let deltas = hexDeltas { print("Using hex deltas:", deltas) }
        #endif

        switch neighborMode {
        case .grid:
            func gridNeighbors(_ c: Int, _ r: Int) -> [(Int,Int)] {
                [(c+1,r), (c-1,r), (c,r+1), (c,r-1)]
            }
            paintReachable(fromC: startC, fromR: startR, range: moveRange, neighbors: gridNeighbors)

        case .hex:
            func hexNeighborsMeasured(_ c: Int, _ r: Int) -> [(Int,Int)] {
                return nearestSixNeighbors(from: c, r0: r)
            }
            paintReachable(fromC: startC, fromR: startR, range: moveRange, neighbors: hexNeighborsMeasured)        }
    }

    // Generic BFS painter
    private func paintReachable(fromC: Int, fromR: Int, range: Int,
                                neighbors: (Int,Int)->[(Int,Int)]) {
        var visited = Set<[Int]>()
        var queue: [(c:Int, r:Int, d:Int)] = [(fromC, fromR, 0)]
        visited.insert([fromC, fromR])

        while !queue.isEmpty {
            let cur = queue.removeFirst()

            // Skip painting the start tile; paint all others within range
            if cur.d > 0 {
                highlightMap.setTileGroup(highlightGroup, forColumn: cur.c, row: cur.r)
            }
            if cur.d == range { continue }

            for (nc, nr) in neighbors(cur.c, cur.r) {
                if isInBounds(nc, nr) && !visited.contains([nc, nr]) {

                    // Terrain check: skip water tiles entirely (no ring, no traversal).
                    // If you prefer to show blocked tiles, paint here and do not enqueue.
                    if let name = map.tileGroup(atColumn: nc, row: nr)?.name,
                       name == "watergroup" {
                        continue
                    }

                    visited.insert([nc, nr])
                    queue.append((nc, nr, cur.d + 1))
                }
            }
        }
    }

    // === Geometry-based neighbor calibration ===
    // We find the six neighboring tiles around a center tile by
    // scanning nearby tiles, bucketing by polar angle into 6 sectors,
    // and picking the nearest in each sector. That gives robust (dc,dr)
    // for THIS map’s offset/parity/row direction—no guessing.
    private func deriveHexDeltas() {
        // Choose a safe center tile away from edges
        let c0 = max(1, min(map.numberOfColumns - 2, map.numberOfColumns / 2))
        let r0 = max(1, min(map.numberOfRows    - 2, map.numberOfRows    / 2))
        let p0 = map.centerOfTile(atColumn: c0, row: r0)

        struct Candidate {
            let dc: Int
            let dr: Int
            let dist2: CGFloat
            let angle: CGFloat
        }

        var buckets = Array(repeating: Candidate(dc: 0, dr: 0, dist2: .infinity, angle: 0), count: 6)

        // Scan a small neighborhood around (c0,r0)
        for dr in -2...2 {
            for dc in -2...2 {
                if dc == 0 && dr == 0 { continue }
                let c = c0 + dc
                let r = r0 + dr
                if !isInBounds(c, r) { continue }

                let p = map.centerOfTile(atColumn: c, row: r)
                let dx = p.x - p0.x
                let dy = p.y - p0.y
                let d2 = dx*dx + dy*dy
                // Ignore far tiles; keep those near 1 tile away
                // Use a generous radius band to accommodate any spacing.
                let minD2 = pow(min(map.tileSize.width, map.tileSize.height) * 0.5, 0.6)
                let maxD2 = pow(max(map.tileSize.width, map.tileSize.height) * 0.9, 0.9)
                if d2 < minD2 || d2 > maxD2 { continue }

                var ang = atan2(dy, dx) // radians, -π..π, 0 along +X (east)
                if ang < 0 { ang += 2 * .pi } // 0..2π

                // 6 sectors centered at 0, 60°, 120°, 180°, 240°, 300°
                let sector = Int((ang / (2 * .pi)) * 6) % 6

                // Keep the closest candidate per sector
                if d2 < buckets[sector].dist2 {
                    buckets[sector] = Candidate(dc: dc, dr: dr, dist2: d2, angle: ang)
                }
            }
        }

        // Extract valid buckets
        let found = buckets.compactMap { $0.dist2.isFinite ? ($0.dc, $0.dr) : nil }
        // As a sanity check, ensure we have 6 unique deltas
        let unique = Array(Set(found.map { "\($0.0),\($0.1)" })).count

        if found.count == 6 && unique == 6 {
            self.hexDeltas = found
        } else {
            // Fallback: a reasonable even-q guess (rows top=0 increasing downward).
            // This keeps you running even if the scan failed for some reason.
            self.hexDeltas = [(+1,0), (+1,-1), (0,-1), (-1,0), (0,+1), (+1,+1)]
        }

        #if DEBUG
        print("Derived hex deltas (dc,dr):", self.hexDeltas ?? [])
        #endif
    }

    // DEBUG: draw (c,r) labels on every tile
    #if DEBUG
    private func addDebugCRLabels() {
        for r in 0..<map.numberOfRows {
            for c in 0..<map.numberOfColumns {
                let p = map.centerOfTile(atColumn: c, row: r)
                let label = SKLabelNode(fontNamed: "Menlo")
                label.fontSize = 12
                label.zPosition = 999
                label.text = "\(c),\(r)"           // top-zero indexing
                // Or bottom-zero if preferred:
                // let bottomRow = (map.numberOfRows - 1) - r
                // label.text = "\(c),\(bottomRow)"
                label.position = p
                label.verticalAlignmentMode = .center
                label.horizontalAlignmentMode = .center
                map.addChild(label)
            }
        }
    }
    #endif
}

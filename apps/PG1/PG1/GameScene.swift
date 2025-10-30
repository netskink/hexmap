//
//  GameScene.swift
//  PG1
//

import SpriteKit

// MARK: - Hex (Flat-Top) Cube Coordinates Helpers
// Using even-q (columns) offset for a flat-top SKTileMapNode.
// If your tile set uses odd-q, swap the neighbor deltas in `offsetNeighbors(col:row:)` accordingly.
private struct Cube: Hashable {
    let x: Int
    let y: Int
    let z: Int
}

private struct Offset: Hashable { let col: Int; let row: Int }


// Cache by prototype name ("Infantry", "Armor", etc.)
private var unitPrototypes: [String: SKSpriteNode] = [:]

private func loadUnitPrototype(named name: String) -> SKSpriteNode? {
    if let cached = unitPrototypes[name] { return cached }

    // Load Units.sks once, capture the child you need
    guard let unitsScene = SKScene(fileNamed: "Units"),
          let node = unitsScene.childNode(withName: name) as? SKSpriteNode
    else {
        print("⚠️ Prototype \(name) not found in Units.sks")
        return nil
    }

    unitPrototypes[name] = node
    return node
}


private extension GameScene {
    // Convert even-q offset -> cube (flat-top)
    func cubeFrom(col q: Int, row r: Int) -> Cube {
        // even-q vertical layout (flat-top):
        // x = q
        // z = r - (q + (q & 1)) / 2
        // y = -x - z
        let z = r - (q + (q & 1)) / 2
        let x = q
        let y = -x - z
        return Cube(x: x, y: y, z: z)
    }
    
    // Convert cube -> even-q offset (flat-top)
    func offsetFrom(cube c: Cube) -> (col: Int, row: Int) {
        // r = z + (q + (q & 1)) / 2 with q = x
        let q = c.x
        let r = c.z + (q + (q & 1)) / 2
        return (q, r)
    }
    
    // Proper hex distance in cube space
    func cubeDistance(_ a: Cube, _ b: Cube) -> Int {
        return max(abs(a.x - b.x), abs(a.y - b.y), abs(a.z - b.z))
    }
    
    // Map bounds and walkability guards
    func inBounds(col: Int, row: Int) -> Bool {
        guard let map = baseMap else { return false }
        return col >= 0 && row >= 0 && col < map.numberOfColumns && row < map.numberOfRows
    }
    
    // For flat-top even-q neighbors in offset coordinates (no filtering)
    func offsetNeighbors(col q: Int, row r: Int) -> [(col: Int, row: Int)] {
        // even columns use one set, odd columns the other
        if q & 1 == 0 { // even q
            return [
                (q+1, r    ), (q+1, r-1),
                (q,   r-1 ),
                (q-1, r-1), (q-1, r   ),
                (q,   r+1 )
            ]
        } else { // odd q
            return [
                (q+1, r+1), (q+1, r   ),
                (q,   r-1),
                (q-1, r  ), (q-1, r+1),
                (q,   r+1)
            ]
        }
    }
    
    // Safe, walkable neighbors
    func walkableNeighbors(col: Int, row: Int) -> [(col: Int, row: Int)] {
        return offsetNeighbors(col: col, row: row)
            .filter { inBounds(col: $0.col, row: $0.row) }
            .filter { baseMap.isWalkable(col: $0.col, row: $0.row) }
    }
    
    // MARK: - Motorized rules helpers
    /// Returns true if this unit is marked motorized via userData["IsMotorized"].
    /// Accepts NSNumber(0/1), Bool, or String "0"/"1"/"true"/"false" (case-insensitive).
    func isMotorizedUnit(_ node: SKSpriteNode) -> Bool {
        guard let ud = node.userData else { return false }
        if let n = ud["IsMotorized"] as? NSNumber { return n.intValue != 0 }
        if let b = ud["IsMotorized"] as? Bool { return b }
        if let s = ud["IsMotorized"] as? String {
            let v = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return v == "1" || v == "true" || v == "yes"
        }
        return false
    }

    /// Checks the tile definition userData for key "AM" and returns true only when AM == 1.
    /// Xcode's Tile Set editor typically stores this as 0/1 (NSNumber). Accepts true-like values as fallback.
    func tileHasAMOne(col: Int, row: Int) -> Bool {
        guard inBounds(col: col, row: row) else { return false }
        guard let def = baseMap.tileDefinition(atColumn: col, row: row),
              let ud  = def.userData else { return false }
        if let n = ud["AM"] as? NSNumber { return n.intValue == 1 }
        if let b = ud["AM"] as? Bool { return b }
        if let s = ud["AM"] as? String { return s == "1" || s.lowercased() == "true" }
        return false
    }

    /// Returns the numeric AM flag if present on the tile definition (0/1), otherwise nil.
    func tileAMValue(col: Int, row: Int) -> Int? {
        guard inBounds(col: col, row: row) else { return nil }
        guard let def = baseMap.tileDefinition(atColumn: col, row: row),
              let ud  = def.userData else { return nil }
        if let n = ud["AM"] as? NSNumber { return n.intValue }
        if let b = ud["AM"] as? Bool { return b ? 1 : 0 }
        if let s = ud["AM"] as? String {
            if s == "1" || s.lowercased() == "true" { return 1 }
            if s == "0" || s.lowercased() == "false" { return 0 }
        }
        return nil
    }

    /// Neighbor generator that applies walkability + occupancy and the motorized rule.
    /// Motorized status comes from unit.userData["IsMotorized"] (see isMotorizedUnit(_:)).
    /// For motorized units, a neighbor is allowed if:
    ///   - it is in-bounds
    ///   - it is not occupied
    ///   - If tile userData["AM"] == 0: forbid (even if walkable)
    ///   - Else allow if (baseMap.isWalkable == true) OR (AM == 1)
    /// For non-motorized units, the neighbor must satisfy baseMap.isWalkable == true.
    func allowedNeighborTiles(for unit: SKSpriteNode,
                              from col: Int,
                              row: Int,
                              occupied: Set<Offset>) -> [(col: Int, row: Int)] {
        let motorized = isMotorizedUnit(unit)
        return offsetNeighbors(col: col, row: row)
            .filter { inBounds(col: $0.col, row: $0.row) }
            .filter { !occupied.contains(Offset(col: $0.col, row: $0.row)) }
            .filter { neighbor in
                if motorized {
                    let am = tileAMValue(col: neighbor.col, row: neighbor.row)
                    // If the tile explicitly marks AM==0, motorized units cannot enter
                    if let am = am, am == 0 { return false }
                    // Otherwise, allow normal walkables OR explicit AM==1 tiles (even if not walkable)
                    return baseMap.isWalkable(col: neighbor.col, row: neighbor.row) || (am == 1)
                } else {
                    return baseMap.isWalkable(col: neighbor.col, row: neighbor.row)
                }
            }
    }

    // MARK: - Combat helpers
    /// Reads an integer combat factor from unit.userData["CombatFactor"]. Defaults to 1 if missing/invalid.
    func combatFactor(for unit: SKSpriteNode) -> Int {
        guard let ud = unit.userData else { return 1 }
        if let n = ud["CombatFactor"] as? NSNumber { return max(1, n.intValue) }
        if let i = ud["CombatFactor"] as? Int { return max(1, i) }
        if let s = ud["CombatFactor"] as? String, let i = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) { return max(1, i) }
        return 1
    }

    /// Greatest common divisor for reducing odds ratios.
    func gcd(_ a: Int, _ b: Int) -> Int {
        var x = abs(a), y = abs(b)
        while y != 0 { let t = x % y; x = y; y = t }
        return max(1, x)
    }

    /// Returns an odds string like "1:2", "2:1" by reducing the attacker:defender ratio.
    func oddsString(attacker atk: SKSpriteNode, defender def: SKSpriteNode) -> String {
        let a = max(1, combatFactor(for: atk))
        let d = max(1, combatFactor(for: def))
        let g = gcd(a, d)
        return "\(a / g):\(d / g)"
    }

    // MARK: - Occupancy helpers
    /// Returns true if a unit (other than `excluding`) occupies the (col,row).
    func isTileOccupied(col: Int, row: Int, excluding: SKSpriteNode? = nil) -> Bool {
        let occ = occupiedOffsets(excluding: excluding)
        return occ.contains(Offset(col: col, row: row))
    }
    
    /// Collect a Set of occupied tile Offsets for all units, optionally excluding one unit (e.g., the mover).
    func occupiedOffsets(excluding: SKSpriteNode? = nil) -> Set<Offset> {
        var set: Set<Offset> = []
        for u in (blueUnits + redUnits) {
            if let ex = excluding, u === ex { continue }
            let idx = tileIndex(of: u)
            set.insert(Offset(col: idx.col, row: idx.row))
        }
        return set
    }
    
    /// Walkable + not occupied neighbors.
    func walkableUnoccupiedNeighbors(col: Int, row: Int, occupied: Set<Offset>) -> [(col: Int, row: Int)] {
        return offsetNeighbors(col: col, row: row)
            .filter { inBounds(col: $0.col, row: $0.row) }
            .filter { baseMap.isWalkable(col: $0.col, row: $0.row) }
            .filter { !occupied.contains(Offset(col: $0.col, row: $0.row)) }
    }
    
    
    // Flood-fill reachable tiles by movement points (cost = 1 per tile), avoiding occupied tiles.
    // Applies motorized rules via allowedNeighborTiles(for:).
    func reachableTiles(for unit: SKSpriteNode,
                        from start: (col: Int, row: Int),
                        movePoints: Int,
                        occupied: Set<Offset>) -> [(Int, Int)] {
        guard movePoints > 0 else { return [] }
        var visitedOffsets: Set<Offset> = [ Offset(col: start.col, row: start.row) ]
        var frontier: [(col: Int, row: Int, cost: Int)] = [ (start.col, start.row, 0) ]
        while let current = frontier.first {
            frontier.removeFirst()
            if current.cost == movePoints { continue }
            let nbrs = allowedNeighborTiles(for: unit, from: current.col, row: current.row, occupied: occupied)
            for n in nbrs {
                let key = Offset(col: n.col, row: n.row)
                if !visitedOffsets.contains(key) {
                    visitedOffsets.insert(key)
                    frontier.append( (n.col, n.row, current.cost + 1) )
                }
            }
        }
        return visitedOffsets.map { ($0.col, $0.row) }
    }
    
    
    // MARK: - A* pathfinding (avoids local minima near water/impassable tiles) and avoids occupied tiles
    func aStarPath(for unit: SKSpriteNode,
                   from start: (col: Int, row: Int),
                   to goal: (col: Int, row: Int),
                   occupied: Set<Offset>) -> [(Int, Int)] {
        let startKey = Offset(col: start.col, row: start.row)
        let goalKey  = Offset(col: goal.col,  row: goal.row)
        if startKey == goalKey { return [ (start.col, start.row) ] }

        // If the goal itself is occupied (by another unit), no legal path (no stacking).
        if occupied.contains(goalKey) { return [] }

        var gScore: [Offset: Int] = [ startKey: 0 ]
        var fScore: [Offset: Int] = [ startKey: cubeDistance(cubeFrom(col: start.col, row: start.row),
                                                             cubeFrom(col: goal.col,  row: goal.row)) ]
        var cameFrom: [Offset: Offset] = [:]
        var openSet: Set<Offset> = [ startKey ]

        while !openSet.isEmpty {
            let current: Offset = openSet.min(by: { (lhs, rhs) in
                (fScore[lhs] ?? Int.max) < (fScore[rhs] ?? Int.max)
            })!

            if current == goalKey {
                var path: [Offset] = [current]
                var c = current
                while let prev = cameFrom[c] { path.append(prev); c = prev }
                path.reverse()
                return path.map { ($0.col, $0.row) }
            }

            openSet.remove(current)
            let currentG = gScore[current] ?? Int.max

            for nb in allowedNeighborTiles(for: unit, from: current.col, row: current.row, occupied: occupied) {
                let nbKey = Offset(col: nb.col, row: nb.row)
                let tentativeG = currentG + 1
                if tentativeG < (gScore[nbKey] ?? Int.max) {
                    cameFrom[nbKey] = current
                    gScore[nbKey] = tentativeG
                    let h = cubeDistance(cubeFrom(col: nb.col, row: nb.row),
                                         cubeFrom(col: goal.col, row: goal.row))
                    fScore[nbKey] = tentativeG + h
                    openSet.insert(nbKey)
                }
            }
        }
        return []
    }
    
    
    // MARK: - Health Bar (UI.sks-driven)

    /// Clone the HealthBar prototype from UI.sks. Falls back to nil if not found.
    func makeHealthBarInstance() -> SKNode? {
        guard let proto = uiRoot?.childNode(withName: "//HealthBar")?.copy() as? SKNode else {
            return nil
        }
        proto.name = "HealthBar"
        (proto as? SKSpriteNode)?.zPosition = 1000
        proto.zPosition = 1000
        return proto
    }

    /// Clone the AttackHint prototype from UI.sks. Falls back to nil if not found.
    func makeAttackHintInstance() -> SKNode? {
        guard let proto = uiRoot?.childNode(withName: "//AttackHint")?.copy() as? SKNode else {
            return nil
        }
        proto.name = attackHighlightName
        proto.zPosition = 1001
        return proto
    }

    /// Position the health bar just above the unit sprite
    func positionHealthBar(_ bar: SKNode, over unit: SKSpriteNode) {
        let offset: CGFloat = (unit.size.height * 0.5) + 10
        bar.position = CGPoint(x: 0, y: offset)
    }

    /// Attach a health bar to a unit if not already present. Uses UI.sks if available; otherwise creates a simple fallback.
    func addHealthBar(to unit: SKSpriteNode) {
        if unit.childNode(withName: "HealthBar") != nil { return }

        if let hb = makeHealthBarInstance() {
            // Ensure fill anchor & alignment are correct regardless of editor tweaks
            if let bg = hb.childNode(withName: "bg") as? SKSpriteNode,
               let fill = hb.childNode(withName: "fill") as? SKSpriteNode {
                fill.anchorPoint = CGPoint(x: 0, y: 0.5)
                let inset = (bg.size.width - fill.size.width) * 0.5
                fill.position = CGPoint(x: -bg.size.width * 0.5 + inset, y: 0)
                fill.colorBlendFactor = 1.0
            }
            // Position using UI.sks override if provided (HealthBar.userData["YOffset"] as Number)
            if let yNum = hb.userData?["YOffset"] as? NSNumber {
                hb.position = CGPoint(x: 0, y: CGFloat(truncating: yNum))
            } else {
                positionHealthBar(hb, over: unit)
            }
            unit.addChild(hb)
            return
        }

        // Fallback if UI.sks is missing or HealthBar not found
        let hbFallback = SKNode(); hbFallback.name = "HealthBar"; hbFallback.zPosition = 1000
        let bg = SKSpriteNode(color: SKColor(white: 0, alpha: 0.35), size: CGSize(width: 48, height: 8))
        bg.name = "bg"; bg.zPosition = 0
        let fill = SKSpriteNode(color: SKColor.green, size: CGSize(width: 46, height: 6))
        fill.name = "fill"; fill.zPosition = 1; fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.position = CGPoint(x: -bg.size.width * 0.5 + (bg.size.width - fill.size.width) * 0.5, y: 0)
        fill.colorBlendFactor = 1.0
        hbFallback.addChild(bg)
        hbFallback.addChild(fill)
        positionHealthBar(hbFallback, over: unit)
        unit.addChild(hbFallback)
    }

    /// Update the bar scale and color according to HP/MaxHP in unit.userData
    func updateHealthBar(for unit: SKSpriteNode) {
        guard let hb = unit.childNode(withName: "HealthBar"),
              let fill = hb.childNode(withName: "fill") as? SKSpriteNode else { return }
        let maxHP = (unit.userData?["MaxHP"] as? NSNumber)?.doubleValue ?? 100
        let hp    = (unit.userData?["HP"] as? NSNumber)?.doubleValue ?? maxHP
        let pct   = CGFloat(max(0.0, min(1.0, hp / maxHP)))

        fill.xScale = max(pct, 0.001) // avoid collapsing to 0
        fill.colorBlendFactor = 1.0
        fill.color = colorForHealth(pct)
    }

    /// Green -> Yellow -> Red gradient for health percent [0,1]
    func colorForHealth(_ pct: CGFloat) -> SKColor {
        func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
        if pct >= 0.5 {
            let t = (1.0 - pct) / 0.5 // 0 at 1.0 to 1 at 0.5
            return SKColor(red: lerp(0, 1, t), green: 1, blue: 0, alpha: 1)
        } else {
            let t = pct / 0.5 // 0 at 0 to 1 at 0.5
            return SKColor(red: 1, green: lerp(0, 1, t), blue: 0, alpha: 1)
        }
    }

    /// Adjust HP by a damage amount; updates bar and removes the unit on death.
    func applyDamage(_ amount: Int, to unit: SKSpriteNode) {
        let maxHP = (unit.userData?["MaxHP"] as? NSNumber)?.intValue ?? 100
        var hp    = (unit.userData?["HP"] as? NSNumber)?.intValue ?? maxHP
        let dmg   = max(0, amount)
        hp = max(0, hp - dmg)
        unit.userData?["HP"] = hp
        updateHealthBar(for: unit)
        if hp <= 0 {
            // Immediately remove from arrays so subsequent UI/logic doesn't see a ghost unit.
            if let idx = blueUnits.firstIndex(of: unit) { blueUnits.remove(at: idx) }
            if let idx = redUnits.firstIndex(of: unit) { redUnits.remove(at: idx) }
            // Stop any dimming used for attack hints
            unit.removeAction(forKey: "DimForAttackHint")
            // Play death animation and then remove the node
            unit.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
            return
        }
    }

    /// Removes any units from tracking arrays that have been removed from the scene or have 0 HP, and cleans dimmed targets.
    func pruneDestroyedUnits() {
        blueUnits.removeAll { $0.parent == nil || (( $0.userData?["HP"] as? NSNumber)?.intValue ?? 1) <= 0 }
        redUnits.removeAll  { $0.parent == nil || (( $0.userData?["HP"] as? NSNumber)?.intValue ?? 1) <= 0 }
        dimmedTargets.removeAll { $0.parent == nil }
    }
}



extension Notification.Name {
    static let worldCornersDidUpdate = Notification.Name("WorldCornersDidUpdate")
}


/// Side currently taking a turn.
enum Turn { case player, computer }

/// Team affiliation used for spawning/tinting units.
enum Team { case player, computer }

/// Root SpriteKit scene.
/// - Owns `worldNode` (the container you pan/zoom), the hex `baseMap`,
///   and the units + highlight overlay.
/// - Input flow:
///   - Player taps their unit's tile → show geometric move hints
///   - Player taps a hint → move unit → `endTurn()`
///   - Computer runs a BFS step toward the player, then `endTurn()`
class GameScene: SKScene {
    
    // Debug logging toggle
    let debugTurnLogs = true

    /// Delay between player ending turn and AI starting (seconds)
    let aiTurnDelay: TimeInterval = 0.6

    // MARK: Nodes

    /// Root container for all world content (map, units, overlays).
    /// Apply panning/zooming to this node so the scene camera stays fixed.
    // Container for all gameplay content defined in GameScene.sks
    @IBOutlet weak var worldNode: SKNode!

    /// The flat-top hex tile map (from GameScene.sks → World/BaseMap).
    /// Used for coordinate transforms, neighbor queries, and pathing.
    var baseMap: SKTileMapNode!
    
    // The red background node
    var backGroundNode: SKNode!
    // The red background node
    var maxzoombgNode: SKNode!

    // Units
    /// Player unit sprite (assigned in `addUnit`).
    var blueUnit: SKSpriteNode!
    /// Computer unit sprite (assigned in `addUnit`).
    var redUnit: SKSpriteNode!

    // Multiple-units support
    var blueUnits: [SKSpriteNode] = []
    var redUnits: [SKSpriteNode] = []
    var selectedUnit: SKSpriteNode?
    private var aiUnitTurnIndex: Int = 0
    
    // MARK: - UI Prototypes (from UI.sks)
    private lazy var uiRoot: SKNode? = {
        // Loads UI.sks once; used to clone HUD elements like the HealthBar
        return SKNode(fileNamed: "UI")
    }()

    // MARK: UI / Highlights

    /// Overlay container for transient UI (move hints, highlights).
    /// Separate from the map so hints aren’t affected by per-tile z ordering.
    var overlayNode: SKNode!

    /// Currently active hint nodes (move + attack). Tracked for full cleanup.
    var highlightNodes: [SKNode] = []

    /// Node.name used to detect taps on move hints.
    let highlightName = "moveHint"
    /// Texture asset name used for hint sprites.
    let highlightTextureName = "whitebe"
    /// Node.name used to tag attackable (adjacent enemy) hint sprites.
    let attackHighlightName = "attackHint"
    /// Texture asset name used for attack hint sprites.
    let attackHighlightTextureName = "redbe"
    /// Enemy units temporarily dimmed while attack hints are visible
    private var dimmedTargets: [SKSpriteNode] = []

    // MARK: State

    /// Turn owner; toggled in `endTurn()`.
    var currentTurn: Turn = .player

    /// True while a move animation is running; blocks input until finished.
    var isAnimatingMove = false
    
    // MARK: - Turn state
    private(set) var isPlayersTurn: Bool = true
    private(set) var turnNumber: Int = 1
    
    // MARK: - Scene lifecycle

    /// Called when the scene is presented by the view.
    /// - Wires up `worldNode`, `baseMap`, and an `Overlay` node (creates one if missing).
    /// - Spawns the example units at offset coordinates.
    /// - Enables player input to begin the turn loop.
    override func didMove(to view: SKView) {
        
        
        super.didMove(to: view)

        
        
        // Find World (keep your fallback)
        if worldNode == nil { worldNode = childNode(withName: "World") }
        precondition(worldNode != nil, "GameScene.sks must contain a node named 'World'")

        // Helper: recursive lookup under World, else anywhere in the scene
        func findNode<T: SKNode>(_ name: String, as type: T.Type) -> T? {
            (worldNode.childNode(withName: name) as? T) ??
            (childNode(withName: "//" + name) as? T)
        }

        guard let map = findNode("BaseMap", as: SKTileMapNode.self) else {
            fatalError("Missing BaseMap (expected SKTileMapNode)")
        }
        baseMap = map

        guard let background = findNode("background", as: SKNode.self) else {
            fatalError("Missing background")
        }
        backGroundNode = background

        guard let maxzoombg = findNode("maxzoombg", as: SKNode.self) else {
            fatalError("Missing maxzoombg")
        }
        maxzoombgNode = maxzoombg


        // Find the camera in GameScene.sks
        if let cameraNode = childNode(withName: "Camera") as? SKCameraNode {
            self.camera = cameraNode
        }
    
        
        
        overlayNode = worldNode.childNode(withName: "Overlay") ?? {
            let n = SKNode(); n.name = "Overlay"; n.zPosition = 1000; worldNode.addChild(n); return n
        }()

        
        // Player team (spawn from Units.sks prototypes)
        _ = spawnUnit(from: "Infantry",            atCol: 9,  row: 8, team: .player)
        _ = spawnUnit(from: "Infantry",            atCol: 11, row: 6, team: .player)
        _ = spawnUnit(from: "Armor",               atCol: 10, row: 7, team: .player)
        _ = spawnUnit(from: "MotorizedInfantry",   atCol: 9,  row: 7, team: .player)
        _ = spawnUnit(from: "MechanizedInfantry",  atCol: 11, row: 8, team: .player)

        // Computer team (spawn from Units.sks prototypes)
        _ = spawnUnit(from: "Armor",               atCol: 17, row: 10, team: .computer)
        _ = spawnUnit(from: "Infantry",            atCol: 19, row: 6,  team: .computer)
        _ = spawnUnit(from: "Infantry",            atCol: 20, row: 8,  team: .computer)
        _ = spawnUnit(from: "MotorizedInfantry",   atCol: 21, row: 6,  team: .computer)
        _ = spawnUnit(from: "MechanizedInfantry",  atCol: 22, row: 5,  team: .computer)

        // Select the first player unit for convenience
        if let first = blueUnits.first { selectedUnit = first }
        
        currentTurn = .player
        enablePlayerInput(true)

    }

    
    @discardableResult
    func spawnUnit(from prototypeName: String, atCol col: Int, row: Int, team: Team) -> SKSpriteNode? {
        guard let proto = loadUnitPrototype(named: prototypeName) else { return nil }

        // Copy the prototype (this clones textures, physics, etc.)
        guard let sprite = proto.copy() as? SKSpriteNode else { return nil }

        // Carry over editor-defined userData (MP, MaxHP, etc.), then add instance state
        let copiedUserData = (proto.userData?.mutableCopy() as? NSMutableDictionary) ?? NSMutableDictionary()
        if let maxHP = copiedUserData["MaxHP"] as? Int {
            // initialize per-instance HP from MaxHP
            copiedUserData["HP"] = maxHP
        } else {
            // default if not present
            copiedUserData["HP"] = 10
        }
        sprite.userData = copiedUserData

        // Apply classic team tint
        switch team {
        case .player:
            sprite.color = .blue
            sprite.colorBlendFactor = 0.6
        case .computer:
            sprite.color = .red
            sprite.colorBlendFactor = 0.6
        }

        // Place on the map
        let center = baseMap.centerOfTile(atColumn: col, row: row)
        sprite.position = worldNode.convert(center, from: baseMap)
        sprite.zPosition = 100 // or your normal unit layer
        sprite.name = "\(prototypeName)_\(UUID().uuidString)"

        worldNode.addChild(sprite)

        // Register by team (if you track arrays)
        switch team {
        case .player: blueUnits.append(sprite)
        case .computer: redUnits.append(sprite)
        }
        
        // Attach and initialize a health bar for this unit
        addHealthBar(to: sprite)
        updateHealthBar(for: sprite)
        

        return sprite
    }
    
    // MARK: - Scene update cycle

    /// Called after all actions have been evaluated in the scene.
    /// Prints the worldNode's corners in scene space after each update cycle.
    override func didEvaluateActions() {
        super.didEvaluateActions()
        if let corners = worldNode?.accumulatedCorners(in: self) {
            NotificationCenter.default.post(name: .worldCornersDidUpdate,
                                            object: self,
                                            userInfo: [
                                                "tl": NSValue(cgPoint: corners.tl),
                                                "tr": NSValue(cgPoint: corners.tr),
                                                "br": NSValue(cgPoint: corners.br),
                                                "bl": NSValue(cgPoint: corners.bl)
                                            ])
        }
    }

    
    
    // MARK: - Add units

    // MARK: - Unit movement profiles (by asset)
    private func movementPoints(for sprite: SKSpriteNode) -> Int {
        // Default if no userData or missing key
        var movePoints = 1
        if let mpValue = sprite.userData?["MP"] {
            if let intVal = mpValue as? Int {
                movePoints = intVal
            } else if let strVal = mpValue as? String, let intVal = Int(strVal) {
                movePoints = intVal
            }
        }
        return movePoints
    }

    /// Creates a sprite from `Assets.xcassets` and places it on the map.
    /// - Parameters:
    ///   - name: Texture/set name (e.g., "blueUnit", "redUnit").
    ///   - row: Offset row index in `baseMap`.
    ///   - col: Offset column index in `baseMap`.
    /// - Returns: The created `SKSpriteNode`.
    /// NEW: Create a tinted unit from an asset, assign a node name,
    /// and place it on the map. Keeps `blueUnit` / `redUnit` references updated.
    @discardableResult
    func addUnit(asset assetName: String,
                 nodeName: String,
                 tint: UIColor,
                 atRow row: Int,
                 column col: Int) -> SKSpriteNode {
        let tex = SKTexture(imageNamed: assetName)
        let sprite = SKSpriteNode(texture: tex)

        // Keep existing codepaths that rely on node names.
        sprite.name = nodeName

        // Apply team tint.
        sprite.color = tint
        sprite.colorBlendFactor = 0.6 // try 0.6–0.8 if your art already has strong colors

        // Place on tile center (map → world).
        sprite.position = worldNode.convert(baseMap.centerOfTile(atColumn: col, row: row), from: baseMap)
        worldNode.addChild(sprite)

        // Preserve your stored references (legacy single-unit vars).
        if nodeName == "blueUnit" {
            blueUnit = sprite
            blueUnits.append(sprite)
            if selectedUnit == nil { selectedUnit = sprite }
        } else if nodeName == "redUnit" {
            redUnit = sprite
            redUnits.append(sprite)
        }
        return sprite
    }


    // MARK: - Tile index helpers

    /// Returns the (col,row) of the tile containing `node`.
    /// - Note: Converts node.position (world) → map space, then indexes.
    func tileIndex(of node: SKSpriteNode) -> (col: Int, row: Int) {
        let mapPt = baseMap.convert(node.position, from: worldNode)
        return (baseMap.tileColumnIndex(fromPosition: mapPt),
                baseMap.tileRowIndex(fromPosition: mapPt))
    }

    /// Converts a tile index to a world-space point (the visual tile center).
    func worldPointForTile(col: Int, row: Int) -> CGPoint {
        worldNode.convert(baseMap.centerOfTile(atColumn: col, row: row), from: baseMap)
    }
    
    
    func playMuzzleFlash(at point: CGPoint, on parent: SKNode) {
        var frames: [SKTexture] = []
        for i in 1...8 { frames.append(SKTexture(imageNamed: String(format: "muzzle_%04d", i))) }
        let sprite = SKSpriteNode(texture: frames.first)
        sprite.zPosition = 1200
        sprite.position = point
        parent.addChild(sprite)
        // Slower, brighter muzzle flash
        sprite.blendMode = .add
        let anim = SKAction.animate(with: frames, timePerFrame: 0.08, resize: false, restore: false)
        let scaleUp = SKAction.scale(to: 1.2, duration: 0.08 * Double(frames.count) * 0.4)
        let fadeOut = SKAction.fadeOut(withDuration: 0.1)
        sprite.run(.sequence([.group([anim, scaleUp]), fadeOut, .removeFromParent()]))
    }
    
    func playSmokePuff(at point: CGPoint, on parent: SKNode) {
        if let smoke = SKEmitterNode(fileNamed: "Smoke.sks") {
            smoke.position = point
            smoke.zPosition = 1190
            parent.addChild(smoke)
            smoke.run(.sequence([.wait(forDuration: 2.0), .removeFromParent()]))
        }
    }

    func playExplosion(at point: CGPoint, on parent: SKNode) {
        var frames: [SKTexture] = []
        for i in 1...12 { frames.append(SKTexture(imageNamed: String(format: "explosion_%04d", i))) }
        let sprite = SKSpriteNode(texture: frames.first)
        sprite.zPosition = 1200
        sprite.position = point
        parent.addChild(sprite)
        // Slightly longer explosion for readability
        sprite.blendMode = .add
        let timePerFrame = 0.07
        let anim = SKAction.animate(with: frames, timePerFrame: timePerFrame, resize: false, restore: false)
        let scaleUp = SKAction.scale(to: 1.25, duration: timePerFrame * Double(frames.count) * 0.6)
        let fadeOut = SKAction.fadeOut(withDuration: 0.12)

        // --- Explosion audio (Explosion.caf) ---
        // Play the sound only for the visual duration (animation + fade), then remove the node.
        let totalExplosionDuration = timePerFrame * Double(frames.count) + 0.12
        let explosionAudio = SKAudioNode(fileNamed: "Explosion.caf")
        explosionAudio.name = "ExplosionSFX"
        explosionAudio.autoplayLooped = false
        explosionAudio.isPositional = true
        explosionAudio.position = point
        parent.addChild(explosionAudio)
        let playExplosion = SKAction.play()
        let stopAndRemoveExplosion = SKAction.sequence([.wait(forDuration: totalExplosionDuration), .removeFromParent()])
        explosionAudio.run(.sequence([playExplosion, stopAndRemoveExplosion]))

        // Run visuals
        sprite.run(.sequence([.group([anim, scaleUp]), fadeOut, .removeFromParent()]))
    }

    // MARK: - Touches

    /// Player input (only when `currentTurn == .player` and not animating).
    /// Flow:
    /// 1) Tap on a highlight → move to that tile, then `endTurn()`.
    /// 2) Tap on your unit’s tile → (re)show move highlights.
    /// 3) Tap anywhere else → clear highlights.
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard currentTurn == .player, !isAnimatingMove, let touch = touches.first else { return }
        let scenePt = touch.location(in: self)
        
        if debugTurnLogs { print("👆 touchesEnded at \(scenePt), turn=\(currentTurn), anim=\(isAnimatingMove)") }

        // 0) If an attack hint (or any of its children) was tapped, perform an attack (no move), then end turn.
        if let actingUnit = selectedUnit {
            // Find any node under the touch, then climb ancestors to find an AttackHint container
            if let touched = nodes(at: scenePt).first {
                var node: SKNode? = touched
                var attackNode: SKNode?
                while let n = node {
                    if n.name == attackHighlightName { attackNode = n; break }
                    node = n.parent
                }
                if let attackNode = attackNode {
                    // Determine the map tile that was attacked
                    let hintWorld: CGPoint
                    if attackNode.parent === overlayNode {
                        hintWorld = overlayNode.convert(attackNode.position, to: worldNode)
                    } else if let p = attackNode.parent {
                        hintWorld = p.convert(attackNode.position, to: worldNode)
                    } else {
                        hintWorld = attackNode.position
                    }
                    let hintMap   = baseMap.convert(hintWorld, from: worldNode)
                    let target    = (baseMap.tileColumnIndex(fromPosition: hintMap),
                                     baseMap.tileRowIndex(fromPosition: hintMap))

                    if debugTurnLogs { print("➡️ Attack tap detected") }
                    print("🗡️ Player attack initiated by blue unit at target tile (\(target.0), \(target.1))")

                    // FX (attacker + target)
                    playMuzzleFlash(at: actingUnit.position, on: worldNode)
                    playSmokePuff(at: actingUnit.position, on: worldNode)   // smoke at attacker
                    let targetWorld = worldPointForTile(col: target.0, row: target.1)
                    playExplosion(at: targetWorld, on: worldNode)
                    playSmokePuff(at: targetWorld, on: worldNode)          // smoke at target
                    
                    // --- Combat resolution ---
                    let attacker = actingUnit
                    
                        // Find the defending unit on the attacked tile
                        if let defender = redUnits.first(where: { tileIndex(of: $0) == target }) {
                            let atkCF = combatFactor(for: attacker)
                            let defCF = combatFactor(for: defender)

                            let result = CombatResolution.resolve(attackerCF: Double(atkCF), defenderCF: Double(defCF))

                            // Compute damage as % of MaxHP
                            let defMaxHP = (defender.userData?["MaxHP"] as? NSNumber)?.intValue ?? 100
                            let atkMaxHP = (attacker.userData?["MaxHP"] as? NSNumber)?.intValue ?? 100

                            let defDamage = Int(Double(defMaxHP) * Double(result.defenderLossPct) / 100.0)
                            let atkDamage = Int(Double(atkMaxHP) * Double(result.attackerLossPct) / 100.0)

                            applyDamage(defDamage, to: defender)
                            applyDamage(atkDamage, to: attacker)

                            pruneDestroyedUnits()

                            print("⚔️ Combat \(result.oddsLabel) | Roll=\(result.roll) | Def-\(result.defenderLossPct)% (\(defDamage)) / Att-\(result.attackerLossPct)% (\(atkDamage))")
                        }
                    

                    clearMoveHighlights()
                    endTurn()
                    return
                }
            }
        }

        // 1) If a highlight was tapped, move the selected unit there (convert from overlay -> world -> map safely)
        if let tapped = nodes(at: scenePt).first(where: { $0.name == highlightName }) as? SKSpriteNode,
           let movingUnit = selectedUnit {
            let hintWorld = tapped.parent == overlayNode
                ? overlayNode.convert(tapped.position, to: worldNode)
                : tapped.parent!.convert(tapped.position, to: worldNode)
            let hintMap   = baseMap.convert(hintWorld, from: worldNode)
            let target    = (baseMap.tileColumnIndex(fromPosition: hintMap),
                             baseMap.tileRowIndex(fromPosition: hintMap))
            // Enforce no-stacking at the destination
            if isTileOccupied(col: target.0, row: target.1, excluding: movingUnit) {
                return
            }
            
            if debugTurnLogs { print("➡️ Move tap detected; target=\(target)") }
            
            clearMoveHighlights()
            moveUnit(movingUnit, toCol: target.0, row: target.1) { [weak self] in self?.endTurn() }
            return
        }

        // 2) Determine which tile was tapped
        let worldPt = worldNode.convert(scenePt, from: self)
        let mapPt   = baseMap.convert(worldPt, from: worldNode)
        let tapped  = (baseMap.tileColumnIndex(fromPosition: mapPt),
                       baseMap.tileRowIndex(fromPosition: mapPt))

        // If the tapped tile contains a friendly unit, select it and show moves.
        if let unit = blueUnits.first(where: { self.tileIndex(of: $0) == tapped }) {
            selectedUnit = unit
            showMoveHighlights(from: tapped)
            return
        }

        // 3) Otherwise, clear any highlights
        if !highlightNodes.isEmpty { clearMoveHighlights() }
    }

    // MARK: - Highlights (geometric neighbors)

    /// Removes any currently displayed move hints.
    func clearMoveHighlights() {
        highlightNodes.forEach { $0.removeFromParent() }
        highlightNodes.removeAll()
        // Restore any units we dimmed for readability
        for u in dimmedTargets {
            u.removeAction(forKey: "DimForAttackHint")
            u.run(.fadeAlpha(to: 1.0, duration: 0.08))
        }
        dimmedTargets.removeAll()
    }

    /// Displays move hint sprites on all **reachable tiles** within the selected unit's movement points.
    /// Uses flat-top even-q cube math and safe in-bounds + walkable checks.
    func showMoveHighlights(from start: (col: Int, row: Int)) {
        clearMoveHighlights()

        guard let unit = selectedUnit else { return }
        let mp = movementPoints(for: unit)
        let occ = occupiedOffsets(excluding: unit)
        // Compute reachable tiles (includes start); filter out the start tile.
        let reachable = reachableTiles(for: unit, from: start, movePoints: mp, occupied: occ)
            .filter { !($0.0 == start.col && $0.1 == start.row) }

        // Render move hints
        for (c, r) in reachable {
            let hint = SKSpriteNode(texture: SKTexture(imageNamed: highlightTextureName))
            hint.name = highlightName
            hint.alpha = 0.85
            hint.position = worldNode.convert(baseMap.centerOfTile(atColumn: c, row: r), from: baseMap)
            overlayNode.addChild(hint)
            highlightNodes.append(hint)
        }

        // Render attack hints (adjacent enemy-occupied tiles only).
        // Build a fast lookup map of red unit tile indices → unit node.
        var redAt: [Offset: SKSpriteNode] = [:]
        for enemy in redUnits {
            let idx = tileIndex(of: enemy)
            redAt[Offset(col: idx.col, row: idx.row)] = enemy
        }

        // Adjacent (nearest-neighbor) tiles from the selected unit's start.
        let adjacents = offsetNeighbors(col: start.col, row: start.row)
            .filter { inBounds(col: $0.col, row: $0.row) }

        // Use the AttackHint prototype from UI.sks (with built-in shadows and layout)
        for (c, r) in adjacents {
            let key = Offset(col: c, row: r)
            guard let defender = redAt[key] else { continue }
            guard let hint = makeAttackHintInstance() else { continue }

            // Position centered on the target tile
            hint.position = worldNode.convert(baseMap.centerOfTile(atColumn: c, row: r), from: baseMap)
            hint.alpha = 0.98

            // Update odds text on both label and its shadow, if present
            let odds = oddsString(attacker: unit, defender: defender)
            if let label = hint.childNode(withName: "oddsLabel") as? SKLabelNode {
                label.text = odds
            }
            if let shadow = hint.childNode(withName: "oddsLabelShadow") as? SKLabelNode {
                shadow.text = odds
            }

            // Optional: scale to approximate tile size if the prototype provides a BaseDiameter in userData
            // Otherwise, you can size the AttackHint visually in UI.sks and remove this block.
            if let base = (hint.userData?["BaseDiameter"] as? NSNumber)?.doubleValue {
                let target = Double(min(baseMap.tileSize.width, baseMap.tileSize.height) * 0.9)
                let scale = CGFloat(max(0.1, target / base))
                hint.setScale(scale)
            }

            // Dim the defender to make the red ring/odds stand out
            defender.removeAction(forKey: "DimForAttackHint")
            defender.run(.fadeAlpha(to: 0.35, duration: 0.08), withKey: "DimForAttackHint")
            if !dimmedTargets.contains(defender) { dimmedTargets.append(defender) }

            overlayNode.addChild(hint)
            highlightNodes.append(hint)
        }
    }

    // MARK: - Turn flow

    /// Toggles scene touch handling.
    func enablePlayerInput(_ on: Bool) { isUserInteractionEnabled = on }

    /// Advances the turn state:
    /// - Player → Computer: disables input and starts AI.
    /// - Computer → Player: enables input.
    func endTurn() {
        clearMoveHighlights()
        switch currentTurn {
        case .player:
            currentTurn = .computer
            enablePlayerInput(false)
            if debugTurnLogs { print("🔁 Switching to Computer turn…") }
            // Defer AI start to create a readable inter-turn pause and avoid re-entrancy with SKAction completions / FX
            run(.wait(forDuration: aiTurnDelay)) { [weak self] in
                self?.runComputerTurn()
            }
        case .computer:
            currentTurn = .player
            enablePlayerInput(true)
        }
    }

    // MARK: - Computer AI (BFS with geometric neighbors)

    /// One-step pursuit AI:
    /// - Computes (col,row) for both units.
    /// - Uses `nextStepToward` (BFS shortest path) for the red unit to step
    ///   one tile toward the blue unit; otherwise ends its turn.
    func runComputerTurn() {
        guard !redUnits.isEmpty else { endTurn(); return }
        
        if debugTurnLogs { print("🤖 Computer turn starting (reds=\(redUnits.count))") }
        

        // Choose the next red unit in a round-robin sequence.
        let unit = redUnits[aiUnitTurnIndex % redUnits.count]
        aiUnitTurnIndex += 1

        // If any blue unit is adjacent, perform an attack instead of moving.
        let redIdx = tileIndex(of: unit)
        let adjacentsToRed = offsetNeighbors(col: redIdx.col, row: redIdx.row)
            .filter { inBounds(col: $0.col, row: $0.row) }
        let bluePositions = Set(blueUnits.map { Offset(col: tileIndex(of: $0).col, row: tileIndex(of: $0).row) })
        if let targetAdj = adjacentsToRed.first(where: { bluePositions.contains(Offset(col: $0.col, row: $0.row)) }) {
            print("🗡️ Computer attack initiated by red unit adjacent to (\(redIdx.col), \(redIdx.row))")
            // FX: muzzle flash + smoke at attacker, explosion + smoke at target (both in world space)
            let attackerWorld = worldPointForTile(col: redIdx.col, row: redIdx.row)
            let targetWorld = worldPointForTile(col: targetAdj.col, row: targetAdj.row)
            playMuzzleFlash(at: attackerWorld, on: worldNode)
            playSmokePuff(at: attackerWorld, on: worldNode)    // smoke at attacker
            playExplosion(at: targetWorld, on: worldNode)
            playSmokePuff(at: targetWorld, on: worldNode)      // smoke at target
            
            // --- Combat resolution (AI) ---
            if let defender = blueUnits.first(where: { tileIndex(of: $0) == targetAdj }) {
                let atkCF = combatFactor(for: unit)
                let defCF = combatFactor(for: defender)
                let result = CombatResolution.resolve(attackerCF: Double(atkCF),
                                                     defenderCF: Double(defCF))

                let defMaxHP = (defender.userData?["MaxHP"] as? NSNumber)?.intValue ?? 100
                let atkMaxHP = (unit.userData?["MaxHP"] as? NSNumber)?.intValue ?? 100

                let defDamage = Int(Double(defMaxHP) * Double(result.defenderLossPct) / 100.0)
                let atkDamage = Int(Double(atkMaxHP) * Double(result.attackerLossPct) / 100.0)

                applyDamage(defDamage, to: defender)
                applyDamage(atkDamage, to: unit)
                pruneDestroyedUnits()

                print("🤖 Combat \(result.oddsLabel) | Roll=\(result.roll) | Def-\(result.defenderLossPct)% (\(defDamage)) / Att-\(result.attackerLossPct)% (\(atkDamage))")
            }
            
            if debugTurnLogs { print("🤖 AI attacking then ending turn") }
            endTurn()
            return
        }

        // Pick a goal: the nearest blue unit by true hex (cube) distance.
        func distance(_ a: (Int, Int), _ b: (Int, Int)) -> Int {
            let ca = cubeFrom(col: a.0, row: a.1)
            let cb = cubeFrom(col: b.0, row: b.1)
            return cubeDistance(ca, cb)
        }
        let blueTargets = blueUnits.map { tileIndex(of: $0) }
        let goal = blueTargets.min(by: { distance(redIdx, $0) < distance(redIdx, $1) })

        if let g = goal {
            let start = tileIndex(of: unit)
            let mp = movementPoints(for: unit)

            // Use A* to find a path around obstacles (e.g., water); then take up to `mp` steps this turn.
            // Avoid occupied tiles entirely. If the goal is occupied (it is, by the blue unit),
            // choose the best adjacent, unoccupied approach tile instead.
            let occ = occupiedOffsets(excluding: unit)

            // Candidates: all unoccupied neighbors around the goal that are legal for this unit
            // (non-motorized: walkable; motorized: walkable OR AM == 1, and rejected if AM == 0).
            let allNbrs = offsetNeighbors(col: g.0, row: g.1)
                .filter { inBounds(col: $0.col, row: $0.row) }
                .filter { !occ.contains(Offset(col: $0.col, row: $0.row)) }
                .filter { neighbor in
                    if isMotorizedUnit(unit) {
                        let am = tileAMValue(col: neighbor.col, row: neighbor.row)
                        if let am = am, am == 0 { return false }
                        return baseMap.isWalkable(col: neighbor.col, row: neighbor.row) || (am == 1)
                    } else {
                        return baseMap.isWalkable(col: neighbor.col, row: neighbor.row)
                    }
                }

            // Choose the neighbor that yields the shortest A* path from start. If ties, pick closer to the true goal.
            var bestPath: [(Int, Int)] = []
            for cand in allNbrs {
                let p = aStarPath(for: unit, from: start, to: cand, occupied: occ)
                if p.isEmpty { continue }
                if bestPath.isEmpty || p.count < bestPath.count {
                    bestPath = p
                } else if !bestPath.isEmpty && p.count == bestPath.count {
                    let d1 = cubeDistance(cubeFrom(col: bestPath.last!.0, row: bestPath.last!.1), cubeFrom(col: g.0, row: g.1))
                    let d2 = cubeDistance(cubeFrom(col: cand.0, row: cand.1), cubeFrom(col: g.0, row: g.1))
                    if d2 < d1 { bestPath = p }
                }
            }

            if bestPath.count >= 2 {
                let stepsToTake = min(mp, bestPath.count - 1)
                let targetIdx = bestPath[stepsToTake]
                moveUnit(unit, toCol: targetIdx.0, row: targetIdx.1) { [weak self] in self?.endTurn() }
            } else {
                // Nowhere legal to go
                if debugTurnLogs { print("🤖 AI found no path; ending turn") }
                endTurn()
            }
        } else {
            if debugTurnLogs { print("🤖 No blue targets; ending turn") }
            endTurn()
        }
    }

    // MARK: - Movement

    /// Animates `unit` to the tile at `(col,row)` and invokes `completion`
    /// when the short move action finishes. Sets `isAnimatingMove` to gate input.
    func moveUnit(_ unit: SKSpriteNode, toCol col: Int, row: Int, completion: @escaping () -> Void) {
        // Enforce no stacking at runtime
        if isTileOccupied(col: col, row: row, excluding: unit) {
            completion()
            return
        }

        let pWorld = worldPointForTile(col: col, row: row)
        
        // If we're already at (or extremely close to) the destination, finish immediately.
        let epsilon: CGFloat = 0.5
        let dx = unit.position.x - pWorld.x
        let dy = unit.position.y - pWorld.y
        if abs(dx) < epsilon && abs(dy) < epsilon {
            if debugTurnLogs { print("🟰 Already at destination (\(col), \(row)); skipping move") }
            completion()
            return
        }
        
        // Ensure no lingering actions block completion and no nodes are paused.
        unit.removeAllActions()
        unit.isPaused = false
        worldNode.isPaused = false
        self.isPaused = false
        
        isAnimatingMove = true
        if debugTurnLogs {
            let parentName = unit.parent?.name ?? "nil"
            print("🚚 Begin move to (\(col), \(row)) from \(unit.position) → \(pWorld) (parent=\(parentName))")
        }
        
        // Use an explicit sequence to guarantee the completion runs.
        let move = SKAction.move(to: pWorld, duration: 1.5)
        move.timingMode = .easeInEaseOut

        // Clean up any lingering marching node from a previous move
        unit.childNode(withName: "MarchSFX")?.removeFromParent()

        // Play marching sound only for the duration of the move using SKAudioNode.
        // Removing the node after `move.duration` cleanly stops playback even if the
        // source file is longer.
        let marchNode = SKAudioNode(fileNamed: "InfMarch.caf")
        marchNode.name = "MarchSFX"
        marchNode.autoplayLooped = true
        marchNode.isPositional = false

        let startSound = SKAction.run { [weak unit] in
            guard let unit = unit else { return }
            // Ensure no duplicate
            unit.childNode(withName: "MarchSFX")?.removeFromParent()
            unit.addChild(marchNode)
        }
        let stopSound = SKAction.run {
            marchNode.removeFromParent()
        }
        let soundForMoveDuration = SKAction.sequence([startSound, .wait(forDuration: move.duration), stopSound])
        let moveWithSound = SKAction.group([move, soundForMoveDuration])

        let finished = SKAction.run { [weak self] in
            guard let self = self else { return }
            self.isAnimatingMove = false
            if self.debugTurnLogs { print("✅ Move finished at (\(col), \(row)) pos=\(unit.position)") }
            completion()
        }
        unit.run(.sequence([moveWithSound, finished]), withKey: "MoveUnit")
    }
    
    // MARK: - Turn flow API called from HUD
    /// Called by GameViewController when the HUD "End Turn" is tapped.
    /// This ends the player's turn, runs a simple computer turn, then calls completion.
    public func requestEndTurn(completion: @escaping () -> Void) {
        guard currentTurn == .player, !isAnimatingMove else {
            // If we're already in the enemy turn or animating, don't double-trigger.
            run(.wait(forDuration: 0.05), completion: completion)
            return
        }
        // Mirror the scene's normal end-turn flow: clear hints and hand control to the existing AI.
        clearMoveHighlights()
        pruneDestroyedUnits()
        endTurn()          // This switches to .computer, disables input, and calls the real AI (runComputerTurn()).
        completion()       // HUD can re-enable immediately; AI will flip back to player when done.
    }


}


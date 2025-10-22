//
//  GameScene.swift
//  PG1
//

import SpriteKit



extension Notification.Name {
    static let worldCornersDidUpdate = Notification.Name("WorldCornersDidUpdate")
}


/// Side currently taking a turn.
enum Turn { case player, computer }

/// Root SpriteKit scene.
/// - Owns `worldNode` (the container you pan/zoom), the hex `baseMap`,
///   and the units + highlight overlay.
/// - Input flow:
///   - Player taps their unit's tile → show geometric move hints
///   - Player taps a hint → move unit → `endTurn()`
///   - Computer runs a BFS step toward the player, then `endTurn()`
class GameScene: SKScene {

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

    // MARK: UI / Highlights

    /// Overlay container for transient UI (move hints, highlights).
    /// Separate from the map so hints aren’t affected by per-tile z ordering.
    var overlayNode: SKNode!

    /// Currently active hint sprites (named `highlightName`).
    var highlightNodes: [SKSpriteNode] = []

    /// Node.name used to detect taps on move hints.
    let highlightName = "moveHint"
    /// Texture asset name used for hint sprites.
    let highlightTextureName = "whitebe"

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

        
        
        // Player team (5 units)
        addUnit(asset: "armor",          nodeName: "blueUnit", tint: .blue, atRow: 7,  column: 10)
        addUnit(asset: "infantry",  nodeName: "blueUnit", tint: .blue, atRow: 8,  column: 9)
        addUnit(asset: "infantry",       nodeName: "blueUnit", tint: .blue, atRow: 6,  column: 11)
        addUnit(asset: "motorizedinf",       nodeName: "blueUnit", tint: .blue, atRow: 7,  column: 9)
        addUnit(asset: "mechanizedinf",       nodeName: "blueUnit", tint: .blue, atRow: 8,  column: 11)

        // Computer team (5 units)
        addUnit(asset: "armor",          nodeName: "redUnit",  tint: .red,  atRow: 13, column: 13)
        addUnit(asset: "infantry",       nodeName: "redUnit",  tint: .red,  atRow: 12, column: 14)
        addUnit(asset: "infantry",  nodeName: "redUnit",  tint: .red,  atRow: 14, column: 12)
        addUnit(asset: "motorizedinf",       nodeName: "redUnit",  tint: .red,  atRow: 13, column: 14)
        addUnit(asset: "mechanizedinf",       nodeName: "redUnit",  tint: .red,  atRow: 12, column: 13)
        
        if let first = blueUnits.first { selectedUnit = first }
        
        currentTurn = .player
        enablePlayerInput(true)

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

    // MARK: - Touches

    /// Player input (only when `currentTurn == .player` and not animating).
    /// Flow:
    /// 1) Tap on a highlight → move to that tile, then `endTurn()`.
    /// 2) Tap on your unit’s tile → (re)show move highlights.
    /// 3) Tap anywhere else → clear highlights.
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard currentTurn == .player, !isAnimatingMove, let touch = touches.first else { return }
        let scenePt = touch.location(in: self)

        // 1) If a highlight was tapped, move the selected unit there
        if let tapped = nodes(at: scenePt).first(where: { $0.name == highlightName }) as? SKSpriteNode,
           let movingUnit = selectedUnit {
            let hintWorld = tapped.parent!.convert(tapped.position, to: worldNode)
            let hintMap   = baseMap.convert(hintWorld, from: worldNode)
            let target    = (baseMap.tileColumnIndex(fromPosition: hintMap),
                             baseMap.tileRowIndex(fromPosition: hintMap))
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
    }

    /// Displays move hint sprites on all **walkable geometric neighbors**
    /// around `start`. Uses `SKTileMapNode.proximityNeighbors` to avoid
    /// parity/offset mistakes common with flat-top hex maps.
    func showMoveHighlights(from start: (col: Int, row: Int)) {
        clearMoveHighlights()

        // Candidate neighbor tiles filtered to in-bounds & walkable.
        let options = baseMap.proximityNeighbors(col: start.col, row: start.row)
            .filter { baseMap.isWalkable(col: $0.col, row: $0.row) }

        for n in options {
            let hint = SKSpriteNode(texture: SKTexture(imageNamed: highlightTextureName))
            hint.name = "moveHint"
            hint.alpha = 0.85
            // Place hint at tile center (map → world).
            hint.position = worldNode.convert(
                baseMap.centerOfTile(atColumn: n.col, row: n.row),
                from: baseMap
            )
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
            runComputerTurn()
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

        // Choose the next red unit in a round-robin sequence.
        let unit = redUnits[aiUnitTurnIndex % redUnits.count]
        aiUnitTurnIndex += 1

        // Pick a goal: the nearest blue unit by simple grid distance.
        func distance(_ a: (Int, Int), _ b: (Int, Int)) -> Int {
            abs(a.0 - b.0) + abs(a.1 - b.1)
        }
        let redPos = tileIndex(of: unit)
        let blueTargets = blueUnits.map { tileIndex(of: $0) }
        let goal = blueTargets.min(by: { distance(redPos, $0) < distance(redPos, $1) })

        if let g = goal, let step = baseMap.nextStepToward(start: redPos, goal: g) {
            moveUnit(unit, toCol: step.col, row: step.row) { [weak self] in self?.endTurn() }
        } else {
            endTurn()
        }
    }

    // MARK: - Movement

    /// Animates `unit` to the tile at `(col,row)` and invokes `completion`
    /// when the short move action finishes. Sets `isAnimatingMove` to gate input.
    func moveUnit(_ unit: SKSpriteNode, toCol col: Int, row: Int, completion: @escaping () -> Void) {
        let pWorld = worldPointForTile(col: col, row: row)
        isAnimatingMove = true
        unit.run(.move(to: pWorld, duration: 0.25)) { [weak self] in
            self?.isAnimatingMove = false
            completion()
        }
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
        endTurn()          // This switches to .computer, disables input, and calls the real AI (runComputerTurn()).
        completion()       // HUD can re-enable immediately; AI will flip back to player when done.
    }


}

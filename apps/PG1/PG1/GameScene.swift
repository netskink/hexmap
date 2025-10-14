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

        
        
        // Example starting positions (OFFSET indices)
        addUnit(asset: "infantry",       nodeName: "blueUnit", tint: .blue, atRow: 7,  column: 10)
        addUnit(asset: "mechanizedinf",  nodeName: "redUnit",  tint: .red,  atRow: 13, column: 13)
        
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

        // Preserve your stored references.
        if nodeName == "blueUnit" {
            blueUnit = sprite
        } else if nodeName == "redUnit" {
            redUnit = sprite
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

        // 1) If a highlight was tapped, move there
        if let tapped = nodes(at: scenePt).first(where: { $0.name == highlightName }) as? SKSpriteNode {
            // Convert tapped hint → world → map → (col,row)
            let hintWorld = tapped.parent!.convert(tapped.position, to: worldNode)
            let hintMap   = baseMap.convert(hintWorld, from: worldNode)
            let target    = (baseMap.tileColumnIndex(fromPosition: hintMap),
                             baseMap.tileRowIndex(fromPosition: hintMap))
            clearMoveHighlights()
            // Animate and end the player's turn on completion.
            moveUnit(blueUnit, toCol: target.0, row: target.1) { [weak self] in self?.endTurn() }
            return
        }

        // 2) Show moves if the tile we tapped is the blue unit's tile
        let worldPt = worldNode.convert(scenePt, from: self)
        let mapPt   = baseMap.convert(worldPt, from: worldNode)
        let tapped  = (baseMap.tileColumnIndex(fromPosition: mapPt),
                       baseMap.tileRowIndex(fromPosition: mapPt))
        if tapped == tileIndex(of: blueUnit) {
            showMoveHighlights(from: tapped)
            return
        }

        // 3) Otherwise, clear hints
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
        let blue = tileIndex(of: blueUnit)
        let red  = tileIndex(of: redUnit)

        if let step = baseMap.nextStepToward(start: red, goal: blue) {
            moveUnit(redUnit, toCol: step.col, row: step.row) { [weak self] in self?.endTurn() }
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
}

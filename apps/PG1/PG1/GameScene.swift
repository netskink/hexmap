//
//  GameScene.swift
//  PG1
//

import SpriteKit
import GameplayKit

enum Turn { case player, computer }

class GameScene: SKScene {

    // MARK: Nodes
    var worldNode: SKNode!
    var baseMap: SKTileMapNode!

    // Units
    var blueUnit: SKSpriteNode!
    var redUnit: SKSpriteNode!

    // MARK: UI / Highlights
    var overlayNode: SKNode!
    var highlightNodes: [SKSpriteNode] = []
    let highlightName = "moveHint"
    let highlightTextureName = "whitebe"

    // MARK: State
    var currentTurn: Turn = .player
    var isAnimatingMove = false

    // MARK: - Scene lifecycle
    override func didMove(to view: SKView) {
        guard let world = childNode(withName: "//World") else { fatalError("Missing //World") }
        worldNode = world
        guard let map = worldNode.childNode(withName: "BaseMap") as? SKTileMapNode else { fatalError("Missing BaseMap") }
        baseMap = map

        overlayNode = worldNode.childNode(withName: "Overlay") ?? {
            let n = SKNode(); n.name = "Overlay"; n.zPosition = 1000; worldNode.addChild(n); return n
        }()

        // Example starting positions (OFFSET indices)
        addUnit(named: "blueUnit", atRow: 7, column: 10)
        addUnit(named: "redUnit",  atRow: 13, column: 13)

        currentTurn = .player
        enablePlayerInput(true)
    }

    // MARK: - Add units
    @discardableResult
    func addUnit(named name: String, atRow row: Int, column col: Int) -> SKNode {
        let tex = SKTexture(imageNamed: name)
        let sprite = SKSpriteNode(texture: tex); sprite.name = name
        sprite.position = worldNode.convert(baseMap.centerOfTile(atColumn: col, row: row), from: baseMap)
        worldNode.addChild(sprite)
        if name == "blueUnit" { blueUnit = sprite } else if name == "redUnit" { redUnit = sprite }
        return sprite
    }

    // MARK: - Tile index helpers
    func tileIndex(of node: SKSpriteNode) -> (col: Int, row: Int) {
        let mapPt = baseMap.convert(node.position, from: worldNode)
        return (baseMap.tileColumnIndex(fromPosition: mapPt),
                baseMap.tileRowIndex(fromPosition: mapPt))
    }

    func worldPointForTile(col: Int, row: Int) -> CGPoint {
        worldNode.convert(baseMap.centerOfTile(atColumn: col, row: row), from: baseMap)
    }

    // MARK: - Touches
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard currentTurn == .player, !isAnimatingMove, let touch = touches.first else { return }
        let scenePt = touch.location(in: self)

        // 1) If a highlight was tapped, move there
        if let tapped = nodes(at: scenePt).first(where: { $0.name == highlightName }) as? SKSpriteNode {
            let hintWorld = tapped.parent!.convert(tapped.position, to: worldNode)
            let hintMap   = baseMap.convert(hintWorld, from: worldNode)
            let target    = (baseMap.tileColumnIndex(fromPosition: hintMap),
                             baseMap.tileRowIndex(fromPosition: hintMap))
            clearMoveHighlights()
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
    func clearMoveHighlights() {
        highlightNodes.forEach { $0.removeFromParent() }
        highlightNodes.removeAll()
    }

    func showMoveHighlights(from start: (col: Int, row: Int)) {
        clearMoveHighlights()

        let options = baseMap.proximityNeighbors(col: start.col, row: start.row)
            .filter { baseMap.isWalkable(col: $0.col, row: $0.row) }

        for n in options {
            let hint = SKSpriteNode(texture: SKTexture(imageNamed: "whitebe"))
            hint.name = "moveHint"
            hint.alpha = 0.85
            hint.position = worldNode.convert(
                baseMap.centerOfTile(atColumn: n.col, row: n.row),
                from: baseMap
            )
            overlayNode.addChild(hint)
            highlightNodes.append(hint)
        }
    }
    
    
    
    // MARK: - Turn flow
    func enablePlayerInput(_ on: Bool) { isUserInteractionEnabled = on }

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
    func moveUnit(_ unit: SKSpriteNode, toCol col: Int, row: Int, completion: @escaping () -> Void) {
        let pWorld = worldPointForTile(col: col, row: row)
        isAnimatingMove = true
        unit.run(.move(to: pWorld, duration: 0.25)) { [weak self] in
            self?.isAnimatingMove = false
            completion()
        }
    }
}

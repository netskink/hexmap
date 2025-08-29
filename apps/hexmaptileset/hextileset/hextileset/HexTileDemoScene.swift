
import SpriteKit
import UIKit

final class HexTileDemoScene: SKScene {

    private var didBuild = false

    override func didMove(to view: SKView) {
        backgroundColor = .black
        if !didBuild {
            didBuild = true
            buildDemo()
        }
    }

    private func buildDemo() {
        // Two tileset scales to compare
        let sides: [CGFloat] = [32, 48]
        let titles = ["Hex pointy-top • 32pt tiles", "Hex pointy-top • 48pt tiles"]

        let spacing: CGFloat = 28
        var yCursor = size.height - 60

        for (idx, side) in sides.enumerated() {
            let tileSize = CGSize(width: side, height: side)
            let (tileSet, groups) = makeHexTileSet(tileSize: tileSize)

            let cols = 14
            let rows = 6
            let map = SKTileMapNode(tileSet: tileSet,
                                    columns: cols,
                                    rows: rows,
                                    tileSize: tileSet.defaultTileSize)
            map.enableAutomapping = false
            map.anchorPoint = CGPoint(x: 0.5, y: 1.0)

            for r in 0..<rows {
                for c in 0..<cols {
                    let pick = (c + r + idx) % groups.count
                    map.setTileGroup(groups[pick], forColumn: c, row: r)
                }
            }

            // Lay out roughly; hex maps have vertical overlap (~0.75 of tile height)
            let totalHeight = CGFloat(rows) * tileSet.defaultTileSize.height * 0.78
            let yTop = yCursor
            map.position = CGPoint(x: size.width/2, y: yTop)
            addChild(map)

            // Label
            let label = SKLabelNode(text: titles[idx])
            label.fontName = "Menlo"
            label.fontSize = 14
            label.fontColor = .white
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: size.width/2, y: yTop + 16)
            addChild(label)

            yCursor -= (totalHeight + spacing + 24)
        }

        let note = SKLabelNode(text: "SKTileSet(.hexagonalPointy) — textures drawn with UIGraphicsImageRenderer")
        note.fontName = "Menlo"
        note.fontSize = 12
        note.fontColor = .lightGray
        note.position = CGPoint(x: size.width/2, y: 12)
        note.verticalAlignmentMode = .bottom
        note.horizontalAlignmentMode = .center
        addChild(note)
    }

    // MARK: - Hex tileset

    private func makeHexTileSet(tileSize: CGSize) -> (SKTileSet, [SKTileGroup]) {
        let grass = SKTexture(image: makeHexImage(size: tileSize, kind: .grass))
        let water = SKTexture(image: makeHexImage(size: tileSize, kind: .water))
        let dirt  = SKTexture(image: makeHexImage(size: tileSize, kind: .dirt))

        let grassDef = SKTileDefinition(texture: grass, size: tileSize)
        let waterDef = SKTileDefinition(texture: water, size: tileSize)
        let dirtDef  = SKTileDefinition(texture: dirt,  size: tileSize)

        let grassGroup = SKTileGroup(tileDefinition: grassDef); grassGroup.name = "hex.grass"
        let waterGroup = SKTileGroup(tileDefinition: waterDef); waterGroup.name = "hex.water"
        let dirtGroup  = SKTileGroup(tileDefinition: dirtDef);  dirtGroup.name = "hex.dirt"

        let groups = [grassGroup, waterGroup, dirtGroup]
        let tileSet = SKTileSet(tileGroups: groups, tileSetType: .hexagonalPointy)
        tileSet.defaultTileSize = tileSize   // IMPORTANT: match definition size
        return (tileSet, groups)
    }

    private enum TileKind { case grass, water, dirt }

    private func makeHexImage(size: CGSize, kind: TileKind) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            // transparent background
            UIColor.clear.setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            // Build hex path (pointy-top, -30°)
            let path = UIBezierPath()
            let cx = size.width / 2.0
            let cy = size.height / 2.0
            let r = min(size.width, size.height) * 0.48

            func pt(_ i: Int) -> CGPoint {
                let angle = (CGFloat(i) * 60.0 - 30.0) * .pi / 180.0
                return CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle))
            }
            path.move(to: pt(0))
            for i in 1..<6 { path.addLine(to: pt(i)) }
            path.close()

            switch kind {
            case .grass:
                UIColor(red: 0.18, green: 0.66, blue: 0.22, alpha: 1).setFill()
                path.fill()
                // clipped stripes
                cg.saveGState()
                path.addClip()
                UIColor(red: 0.24, green: 0.78, blue: 0.28, alpha: 1).setFill()
                for y in stride(from: 0.0, to: size.height, by: 4.0) {
                    UIBezierPath(rect: CGRect(x: 0, y: y, width: size.width, height: 1)).fill()
                }
                cg.restoreGState()

            case .water:
                UIColor(red: 0.08, green: 0.42, blue: 0.86, alpha: 1).setFill()
                path.fill()
                cg.saveGState()
                path.addClip()
                UIColor(red: 0.25, green: 0.65, blue: 1.0, alpha: 0.35).setFill()
                let bandH = size.height / 6.0
                for i in 0..<4 {
                    UIBezierPath(rect: CGRect(x: 0, y: CGFloat(i) * (bandH + 2), width: size.width, height: bandH)).fill()
                }
                cg.restoreGState()

            case .dirt:
                UIColor(red: 0.45, green: 0.33, blue: 0.23, alpha: 1).setFill()
                path.fill()
                cg.saveGState()
                path.addClip()
                UIColor(red: 0.62, green: 0.52, blue: 0.44, alpha: 1).setFill()
                for i in 0..<10 {
                    let x = CGFloat((i * 23) % Int(size.width))
                    let y = CGFloat((i * 41) % Int(size.height))
                    UIBezierPath(rect: CGRect(x: x, y: y, width: 3, height: 3)).fill()
                }
                cg.restoreGState()
            }
        }
    }
}


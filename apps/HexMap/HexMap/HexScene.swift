
import SpriteKit
import GameplayKit
// from shared code in this repo
import SharedKit

final class HexScene: SKScene {

    // MARK: - Tunables
    private let hexSize: CGFloat = 28          // radius (corner to center)
    private let mapRadius: Int = 6             // hex "disc" radius (use width/height loops for rectangles)
    private let pointyTop = false               // flip to false for flat-top

    // sqrt(3) handy constant
    private static let sqrt3: CGFloat = 1.7320508075688772

    private var selected: SKShapeNode?
    private lazy var hexPath: CGPath = HexScene.buildHexPath(size: hexSize, pointy: pointyTop)

    // MARK: - Scene lifecycle
    override func didMove(to view: SKView) {
        backgroundColor = .black
        buildMap()
        Log.info("xxxxx")
    }

    // MARK: - Map generation
    private func buildMap() {
        // Hex "disc" (nice for demos). For a rectangular map, loop rows/cols instead.
        for q in -mapRadius...mapRadius {
            let rMin = max(-mapRadius, -q - mapRadius)
            let rMax = min(mapRadius, -q + mapRadius)
            for r in rMin...rMax {
                let p = axialToPixel(q: CGFloat(q), r: CGFloat(r))
                let center = CGPoint(x: size.width/2 + p.x, y: size.height/2 + p.y)

                let node = SKShapeNode(path: hexPath)
                node.position = center
                node.lineWidth = 1.0
                node.strokeColor = .white
                node.fillColor = ((q + r) % 2 == 0) ? .systemTeal : .systemIndigo
                node.zPosition = 1
                node.name = tileName(q: q, r: r)
                addChild(node)
            }
        }
    }

    // MARK: - Touch handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)

        // Convert screen point -> axial -> round to nearest hex
        let local = CGPoint(x: p.x - size.width/2, y: p.y - size.height/2)
        let (aq, ar) = pixelToAxial(local)
        let (rq, rr) = axialRound(q: aq, r: ar)

        // Find the node by its name and highlight it
        if let node = childNode(withName: tileName(q: rq, r: rr)) as? SKShapeNode {
            selected?.lineWidth = 1.0
            selected?.glowWidth = 0
            selected?.strokeColor = .white

            node.lineWidth = 3.0
            node.glowWidth = 2.0
            node.strokeColor = .yellow
            selected = node
        }
    }

    // MARK: - Naming helper
    private func tileName(q: Int, r: Int) -> String { "hex_\(q)_\(r)" }

    // MARK: - Geometry
    private static func buildHexPath(size: CGFloat, pointy: Bool) -> CGPath {
        let path = CGMutablePath()
        for i in 0..<6 {
            // Pointy-top: -30° offset; Flat-top: 0°
            let angleDeg: CGFloat = pointy ? (CGFloat(60 * i) - 30) : CGFloat(60 * i)
            let angle = angleDeg * .pi / 180
            let x = size * cos(angle)
            let y = size * sin(angle)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else      { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        return path
    }

    // MARK: - Axial <-> Pixel (pointy-top by default)
    // Pointy-top axial -> pixel
    // x = s * sqrt(3) * (q + r/2)
    // y = s * 3/2 * r
    private func axialToPixel(q: CGFloat, r: CGFloat) -> CGPoint {
        if pointyTop {
            let x = hexSize * HexScene.sqrt3 * (q + r * 0.5)
            let y = hexSize * 1.5 * r
            return CGPoint(x: x, y: y)
        } else {
            // Flat-top variant:
            // x = s * 3/2 * q
            // y = s * sqrt(3) * (r + q/2)
            let x = hexSize * 1.5 * q
            let y = hexSize * HexScene.sqrt3 * (r + q * 0.5)
            return CGPoint(x: x, y: y)
        }
    }

    // Pixel -> axial (fractional)
    private func pixelToAxial(_ p: CGPoint) -> (q: CGFloat, r: CGFloat) {
        if pointyTop {
            // Inverse of pointy-top
            // q = (sqrt(3)/3 * x - 1/3 * y) / s
            // r = (2/3 * y) / s
            let q = (HexScene.sqrt3/3 * p.x - 1.0/3.0 * p.y) / hexSize
            let r = (2.0/3.0 * p.y) / hexSize
            return (q, r)
        } else {
            // Inverse of flat-top
            // q = (2/3 * x) / s
            // r = (-1/3 * x + sqrt(3)/3 * y) / s
            let q = (2.0/3.0 * p.x) / hexSize
            let r = ((-1.0/3.0 * p.x) + (HexScene.sqrt3/3.0 * p.y)) / hexSize
            return (q, r)
        }
    }

    // Round fractional axial to nearest hex using cube rounding
    private func axialRound(q: CGFloat, r: CGFloat) -> (Int, Int) {
        var x = q
        var z = r
        var y = -x - z

        var rx = x.rounded()
        var ry = y.rounded()
        var rz = z.rounded()

        let dx = abs(rx - x)
        let dy = abs(ry - y)
        let dz = abs(rz - z)

        if dx > dy && dx > dz {
            rx = -ry - rz
        } else if dy > dz {
            ry = -rx - rz
        } else {
            rz = -rx - ry
        }
        return (Int(rx), Int(rz))
    }
}

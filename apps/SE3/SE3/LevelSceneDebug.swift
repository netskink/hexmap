//
//  LevelSceneDebug.swift
//  SE3
//
//  Created by john davis on 9/9/25.
//

#if DEBUG
import SpriteKit

extension LevelScene {
    // MARK: - Debug

    

    private func clearDebugDots() {
        for n in debugDots { n.removeFromParent() }
        debugDots.removeAll()
    }

    private func dot(at p: CGPoint,
                radius: CGFloat = 6,
                color: SKColor) -> SKShapeNode {
        
        let n = SKShapeNode(circleOfRadius: radius)
        n.position = p
        n.fillColor = color
        n.strokeColor = color
        n.lineWidth = 1
        n.zPosition = 2000
        return n
    }

    /// Draw numbered dots on the 6 neighbors and print details
    internal func showDebugNeighbors(from c0: Int, r0: Int) {
        guard debugMode else { return }
        clearDebugDots()

        // Draw a dot at center tile
        let p0 = map.centerOfTile(atColumn: c0, row: r0)
        let centerDot = dot(at: p0, radius: 8, color: .yellow)
        map.addChild(centerDot)
        debugDots.append(centerDot)

        // Collect & sort candidates by distance so we can see why 6 were chosen
        struct Cand {
            let c: Int
            let r: Int
            let d2: CGFloat
        }
        var cands: [Cand] = []
        for dr in -2...2 {
            for dc in -2...2 {
                if dc == 0 && dr == 0 { continue }
                let c = c0 + dc
                let r = r0 + dr
                if !isInBounds(c, r) { continue }
                let p = map.centerOfTile(atColumn: c, row: r)
                let dx = p.x - p0.x
                let dy = p.y - p0.y
                let d2 = dx * dx + dy * dy
                cands.append(Cand(c: c, r: r, d2: d2))
            }
        }
        cands.sort { $0.d2 < $1.d2 }

        // Pick first 6 unique
        var chosen: [(Int, Int, CGFloat)] = []
        var seen = Set<String>()
        for cand in cands {
            let key = "\(cand.c),\(cand.r)"
            if seen.contains(key) { continue }
            seen.insert(key)
            chosen.append((cand.c, cand.r, cand.d2))
            if chosen.count == 6 { break }
        }

        // Print the chosen 6 with distances
        let list = chosen.map { "(\($0.0),\($0.1)) d2=\(Int($0.2))" }
            .joined(separator: ", ")
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

    internal func printNeighbors(of c: Int, _ r: Int) {
        let neigh = nearestSixNeighbors(from: c, r0: r)
        print("Neighbors(\(c),\(r)) -> \(neigh)")
    }



    
    // DEBUG: draw (c,r) labels on every tile
    // DEBUG: overlay coordinate labels on each tile
    internal func addDebugCRLabels() {
        for r in 0..<map.numberOfRows {
            for c in 0..<map.numberOfColumns {
                let p = map.centerOfTile(atColumn: c, row: r)
                let label = SKLabelNode(fontNamed: "Menlo")
                label.fontSize = 12
                label.zPosition = 999
                label.text = "\(c),\(r)"  // top-zero indexing
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
    
    
    

    /// Call once after `self.map` is set (e.g. at end of didMove).
    internal func detectOffsetModel() {
        // Pick an interior tile (avoid edges so neighbors exist)
        let c0 = max(1, min(map.numberOfColumns - 2, 2))
        let r0 = max(1, min(map.numberOfRows    - 2, 2))

        let p00 = map.centerOfTile(atColumn: c0,     row: r0)
        let pRow = map.centerOfTile(atColumn: c0,     row: r0 + 1) // same col, next row
        let pCol = map.centerOfTile(atColumn: c0 + 1, row: r0)     // next col, same row

        // How a +row or +col step moves in screen space
        let dRow = CGVector(dx: pRow.x - p00.x, dy: pRow.y - p00.y)
        let dCol = CGVector(dx: pCol.x - p00.x, dy: pCol.y - p00.y)

        let axRow = abs(dRow.dx), ayRow = abs(dRow.dy)
        let axCol = abs(dCol.dx), ayCol = abs(dCol.dy)

        print("DETECT raw: dRow(dx:\(Int(dRow.dx)), dy:\(Int(dRow.dy)))  dCol(dx:\(Int(dCol.dx)), dy:\(Int(dCol.dy)))")

        // Helper
        @inline(__always) func ratio(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a / max(b, 0.0001) }
        let rowYvsX = ratio(ayRow, axRow)   // how vertical a row step is
        let colXvsY = ratio(axCol, ayCol)   // how horizontal a col step is

        // Log nice rounded values
        let r1 = Double((rowYvsX * 100).rounded() / 100)
        let r2 = Double((colXvsY * 100).rounded() / 100)
        print("DETECT ratios: rowYvsX=\(r1)  colXvsY=\(r2)")

        // Tunable thresholds
        let STRONGLY_HORIZONTAL: CGFloat = 1.8   // col step must be very horizontal
        let MORE_VERTICAL_THAN_HORIZONTAL: CGFloat = 1.1 // row step simply needs to favor vertical

        let colIsStronglyHorizontal = colXvsY >= STRONGLY_HORIZONTAL
        let rowIsVerticalDominant   = rowYvsX >= MORE_VERTICAL_THAN_HORIZONTAL

        // POINTY-TOP (row-offset “R”): col step strongly horizontal AND
        // row step more vertical than horizontal
        if colIsStronglyHorizontal && rowIsVerticalDominant {
            // Determine parity for row-offset:
            // which row (even or odd) is shifted to the right at the same column?
            let re = (r0 % 2 == 0) ? r0 : r0 - 1  // an even row near r0
            let ro = re + 1                        // the next odd row
            if re >= 0, ro < map.numberOfRows {
                let pEven = map.centerOfTile(atColumn: c0, row: re)
                let pOdd  = map.centerOfTile(atColumn: c0, row: ro)
                let evenShiftRight = pEven.x > pOdd.x
                print("DETECT: pointy-top (row-offset, R) — \(evenShiftRight ? "even-R (even rows shifted right)" : "odd-R (odd rows shifted right)")")
            } else {
                print("DETECT: pointy-top (row-offset, R) — parity check skipped (edge).")
            }
            return
        }

        // FLAT-TOP (row-offset / r):
        // col step is strongly horizontal, but row step is NOT vertically dominant.
        if colIsStronglyHorizontal && !rowIsVerticalDominant {
            // Determine parity: which row is shifted right?
            let re = (r0 % 2 == 0) ? r0 : r0 - 1  // even row near r0
            let ro = re + 1
            if re >= 0, ro < map.numberOfRows {
                let pEven = map.centerOfTile(atColumn: c0, row: re)
                let pOdd  = map.centerOfTile(atColumn: c0, row: ro)
                let evenShiftRight = pEven.x > pOdd.x
                print("DETECT: flat-top (row-offset, r) — \(evenShiftRight ? "even-r" : "odd-r")")
            } else {
                print("DETECT: flat-top (row-offset, r) — parity check skipped (edge).")
            }
            return
        }

        // Otherwise we can't say confidently.
        print("DETECT: ambiguous → rowYvsX=\(Double(rowYvsX)) colXvsY=\(Double(colXvsY)) — using geometry-based neighbors.")
    }
    
    internal func probe(_ c: Int, _ r: Int) {
        guard isInBounds(c, r) else { return }
        let p = map.centerOfTile(atColumn: c, row: r)
        let a = SKShapeNode(circleOfRadius: 6); a.fillColor = .yellow; a.position = p
        let b = SKShapeNode(circleOfRadius: 5); b.fillColor = .green;  b.position = map.centerOfTile(atColumn: c+1, row: r)
        let d = SKShapeNode(circleOfRadius: 5); d.fillColor = .blue;   d.position = map.centerOfTile(atColumn: c,   row: r+1)
        for n in [a,b,d] { n.zPosition = 9_999; map.addChild(n) }
        print("probe (c,r)=\(c),\(r)  (c+1,r) green  (c,r+1) blue")
    }


}
#endif

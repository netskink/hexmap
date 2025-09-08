//
//  AxialMath.swift
//  SceneEditor2
//
//  Created by john davis on 9/2/25.
//

import Foundation

// This almost always comes from a mismatch between your axial math and the offset (col,row) you use to talk to
// SKTileMapNode. With pointy-top hexes, if you compute neighbors in axial (q,r) but then convert to tile indices
//using the wrong parity (even-q vs odd-q), exactly one of the six ends up shifted—so it looks like a non-neighbor.

// Here’s a drop-in, parity-safe setup you can use. It keeps all logic in axial, converts to offset only when
//touching the tile map, and includes a self-check.

// Which parity are you using?

// SpriteKit’s pointy-top layout can be treated as vertical columns. Decide once and use that everywhere:
//    •    If your neighbors look right except one (your symptom), you’re probably using even-q math but
//         your grid is actually odd-q (or vice-versa).
//    •    Quick tell: print the (col,row) of two adjacent tiles you can see. If moving one column to the
//         right also moves row up by one on odd columns, that’s odd-q; if it moves up on even columns,
//         that’s even-q.

// MARK: - Axial <-> Offset (pointy-top, vertical layout, q = column)
enum QParity { case evenQ, oddQ }

struct Axial: Hashable { var q: Int; var r: Int }

func axialToOffset(_ a: Axial, parity: QParity) -> (col: Int, row: Int) {
    switch parity {
    case .evenQ:
        // "even-q" vertical layout
        // rows go down; even columns are shifted up half a row
        let col = a.q
        let row = a.r + (a.q - (a.q & 1)) / 2
        return (col, row)
    case .oddQ:
        // "odd-q" vertical layout
        // odd columns are shifted up
        let col = a.q
        let row = a.r + (a.q + (a.q & 1)) / 2
        return (col, row)
    }
}

func offsetToAxial(col: Int, row: Int, parity: QParity) -> Axial {
    switch parity {
    case .evenQ:
        // r = row - floor(q/2) with floor on even columns
        return Axial(q: col, r: row - (col - (col & 1)) / 2)
    case .oddQ:
        // r = row - floor((q+1)/2) with floor on odd columns
        return Axial(q: col, r: row - (col + (col & 1)) / 2)
    }
}

// MARK: - Axial neighbor & distance
let axialDirs: [Axial] = [
    Axial(q: +1, r:  0),
    Axial(q: +1, r: -1),
    Axial(q:  0, r: -1),
    Axial(q: -1, r:  0),
    Axial(q: -1, r: +1),
    Axial(q:  0, r: +1),
]

func neighbors(of a: Axial) -> [Axial] {
    axialDirs.map { d in Axial(q: a.q + d.q, r: a.r + d.r) }
}

// Cube distance via axial (q,r) where s = -q-r
func hexDistance(_ a: Axial, _ b: Axial) -> Int {
    let dq = a.q - b.q
    let dr = a.r - b.r
    let ds = (-a.q - a.r) - (-b.q - b.r)
    return (abs(dq) + abs(dr) + abs(ds)) / 2
}

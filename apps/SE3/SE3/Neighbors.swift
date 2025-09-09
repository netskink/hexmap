//
//  Neighbors.swift
//  SE3
//
//  Created by john davis on 9/9/25.
//



/// Pointy-top, row-offset (R), bottom-left origin.
/// Use this when **odd rows are shifted right** (odd-R).
internal func oddRNeighborsBL(_ c: Int, _ r: Int) -> [(Int, Int)] {
    if r % 2 == 1 {  // odd row shifted right
        return [
            (c+1, r),   // E
            (c+1, r+1), // NE
            (c,   r+1), // NW
            (c-1, r),   // W
            (c,   r-1), // SW
            (c+1, r-1)  // SE
        ]
    } else {         // even row not shifted
        return [
            (c+1, r),   // E
            (c,   r+1), // NE
            (c-1, r+1), // NW
            (c-1, r),   // W
            (c-1, r-1), // SW
            (c,   r-1)  // SE
        ]
    }
}



/// Even-R neighbors (pointy-top, row-offset) with bottom-left origin
//internal func EvenRNeighbors(_ c: Int, _ r: Int) -> [(Int, Int)] {
//    if r % 2 == 0 {
//        // even row shifted right
//        return [
//            (c+1, r),   // E
//            (c,   r+1), // NE
//            (c-1, r+1), // NW
//            (c-1, r),   // W
//            (c-1, r-1), // SW
//            (c,   r-1)  // SE
//        ]
//    } else {
//        // odd row not shifted
//        return [
//            (c+1, r),   // E
//            (c+1, r+1), // NE
//            (c,   r+1), // NW
//            (c-1, r),   // W
//            (c,   r-1), // SW
//            (c+1, r-1)  // SE
//        ]
//    }
//}


/// If you ever have **even rows shifted right** (even-R), use this one instead.
//internal func EvenRNeighborsBL(_ c: Int, _ r: Int) -> [(Int, Int)] {
//    if r % 2 == 0 {  // even row shifted right
//        return [
//            (c+1, r),   // E
//            (c,   r+1), // NE
//            (c-1, r+1), // NW
//            (c-1, r),   // W
//            (c-1, r-1), // SW
//            (c,   r-1)  // SE
//        ]
//    } else {         // odd row not shifted
//        return [
//            (c+1, r),   // E
//            (c+1, r+1), // NE
//            (c,   r+1), // NW
//            (c-1, r),   // W
//            (c,   r-1), // SW
//            (c+1, r-1)  // SE
//        ]
//    }
//}


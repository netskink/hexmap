//
//  CombatResolution.swift
//  PG1
//
//  Created by john davis on 10/30/25.
//

import Foundation

struct CombatResult {
    let oddsLabel: String
    let oddsRatio: Double
    let mu: Double
    let roll: Double
    let zNeutral: Double
    let defenderLossPct: Int
    let attackerLossPct: Int
}

class CombatResolution {
    private static let MU0 = 50.0
    private static let SIGMA = 16.5

    private static let TABLE_Z: [Double] = [-3, -2, -1, 0, 1, 2, 3]
    private static let DEF_LOSS: [Double] = [100, 80, 50, 20, 10, 5, 0]
    private static let ATT_LOSS: [Double] = [0, 5, 10, 20, 50, 80, 100]

    private static let ODDS_BRACKETS: [(label: String, ratio: Double, zShift: Double)] = {
        // Precomputed zShifts for odds brackets using log scale:
        // odds: 1:3, 1:2, 1:1, 2:1, 3:1
        // zShift = (log(odds) - log(1)) / 0.69314718056 (ln(2)) * 1.0 approx
        // But given the original python code, we use the following approximate values:
        // We'll compute zShift as ln(ratio)/ln(2)
        let ratios = [1.0/3.0, 1.0/2.0, 1.0, 2.0, 3.0]
        return ratios.map { ratio in
            let label = "\(Int(round(ratio * 100))):100"
            // Using natural log ratio / ln(2) to get zShift:
            // Original python used: zShift = log2(ratio)
            // log2(ratio) = ln(ratio)/ln(2)
            let zShift = log(ratio)/log(2.0)
            return (label: "\(Int(round(ratio*1))):\(Int(round(1.0/ratio)))", ratio: ratio, zShift: zShift)
        }
    }()

    private static func normalRandom(mu: Double, sigma: Double) -> Double {
        // Box-Muller transform
        let u1 = Double.random(in: 0..<1)
        let u2 = Double.random(in: 0..<1)
        let z0 = sqrt(-2.0 * log(u1)) * cos(2.0 * Double.pi * u2)
        return z0 * sigma + mu
    }

    private static func clamp<T: Comparable>(_ val: T, min minVal: T, max maxVal: T) -> T {
        if val < minVal { return minVal }
        if val > maxVal { return maxVal }
        return val
    }

    private static func linearInterp(x: Double, x0: Double, x1: Double, y0: Double, y1: Double) -> Double {
        if x1 == x0 {
            return y0
        }
        let t = (x - x0) / (x1 - x0)
        return y0 + t * (y1 - y0)
    }

    static func resolve(attackerCF: Double, defenderCF: Double, seed: UInt64? = nil) -> CombatResult {
        // Calculate odds ratio
        let ratio = attackerCF / defenderCF

        // Find nearest odds bracket by minimizing abs(log2(ratio) - zShift)
        let log2Ratio = log(ratio) / log(2.0)
        var nearest = ODDS_BRACKETS[0]
        var minDiff = abs(log2Ratio - nearest.zShift)
        for bracket in ODDS_BRACKETS {
            let diff = abs(log2Ratio - bracket.zShift)
            if diff < minDiff {
                minDiff = diff
                nearest = bracket
            }
        }

        // Compute mu for this odds bracket
        let mu = MU0 + nearest.zShift * SIGMA

        // Generate roll from normal distribution with mu, sigma
        var roll = normalRandom(mu: mu, sigma: SIGMA)
        roll = clamp(roll, min: 1.0, max: 100.0)

        // Compute zNeutral
        let zNeutral = (roll - MU0) / SIGMA

        // Interpolate defender and attacker losses
        // Find index i so that TABLE_Z[i] <= zNeutral <= TABLE_Z[i+1]
        let z = zNeutral
        var i = 0
        while i < TABLE_Z.count - 1 && z > TABLE_Z[i+1] {
            i += 1
        }
        // Clamp i to valid range
        i = clamp(i, min: 0, max: TABLE_Z.count - 2)

        let z0 = TABLE_Z[i]
        let z1 = TABLE_Z[i+1]
        let defLoss0 = DEF_LOSS[i]
        let defLoss1 = DEF_LOSS[i+1]
        let attLoss0 = ATT_LOSS[i]
        let attLoss1 = ATT_LOSS[i+1]

        let defenderLoss = linearInterp(x: z, x0: z0, x1: z1, y0: defLoss0, y1: defLoss1)
        let attackerLoss = linearInterp(x: z, x0: z0, x1: z1, y0: attLoss0, y1: attLoss1)

        return CombatResult(
            oddsLabel: nearest.label,
            oddsRatio: nearest.ratio,
            mu: mu,
            roll: roll,
            zNeutral: zNeutral,
            defenderLossPct: Int(round(defenderLoss)),
            attackerLossPct: Int(round(attackerLoss))
        )
    }
}


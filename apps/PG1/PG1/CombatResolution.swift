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
    private static let DEF_LOSS: [Int]    = [ 3,  5, 10, 15, 20, 30, 40]
    private static let ATT_LOSS: [Int]    = [40, 30, 20, 15, 10,  5,  3]

    private static let ODDS_BRACKETS: [(label: String, ratio: Double, zShift: Double)] = [
        ("1:3", 1.0/3.0, -0.6745),
        ("1:2", 1.0/2.0, -0.4307),
        ("1:1", 1.0,      0.0000),
        ("2:1", 2.0,      0.4307),
        ("3:1", 3.0,      0.6745),
    ]

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

    private static func bucketLoss(for z: Double) -> (def: Int, att: Int) {
        // Bucket intervals (neutral reference):
        // (-∞, -2] → index 0 (-3σ)
        // (-2, -1] → index 1 (-2σ)
        // (-1,  1] → index 3 (0σ)  // entire mid-band maps to 15/15
        // ( 1,  2] → index 4 (+1σ)
        // ( 2,  3] → index 5 (+2σ)
        // ( 3,  ∞) → index 6 (+3σ)
        if z <= -2.0 { return (DEF_LOSS[0], ATT_LOSS[0]) }
        if z <= -1.0 { return (DEF_LOSS[1], ATT_LOSS[1]) }
        if z <=  1.0 { return (DEF_LOSS[3], ATT_LOSS[3]) }
        if z <=  2.0 { return (DEF_LOSS[4], ATT_LOSS[4]) }
        if z <=  3.0 { return (DEF_LOSS[5], ATT_LOSS[5]) }
        return (DEF_LOSS[6], ATT_LOSS[6])
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

        // Bucketed losses (no interpolation)
        let (defenderLoss, attackerLoss) = bucketLoss(for: zNeutral)

        return CombatResult(
            oddsLabel: nearest.label,
            oddsRatio: nearest.ratio,
            mu: mu,
            roll: roll,
            zNeutral: zNeutral,
            defenderLossPct: defenderLoss,
            attackerLossPct: attackerLoss
        )
    }
}

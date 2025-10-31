import random
import math
from dataclasses import dataclass

@dataclass
class CombatResult:
    odds_label: str
    odds_ratio: float
    mu: float
    roll: float
    z_neutral: float
    defender_loss_pct: int
    attacker_loss_pct: int


class CombatResolution:
    # Normal distribution parameters
    MU0 = 50.0
    SIGMA = 16.5

    # z thresholds and corresponding losses
    Z_BANDS = [-3, -2, -1, 1, 2, 3]
    DEFENDER_LOSS = [5, 10, 15, 30, 45, 60]
    ATTACKER_LOSS = [60, 45, 15, 15, 10, 5]

    # odds brackets (ratio, label, z_shift)
    ODDS = [
        (1 / 3.0, "1:3", -0.91),
        (0.5, "1:2", -0.43),
        (1.0, "1:1", 0.0),
        (2.0, "2:1", 0.43),
        (3.0, "3:1", 0.91),
    ]

    @staticmethod
    def _snap_ratio(ratio: float):
        """Find the closest bracket."""
        return min(CombatResolution.ODDS, key=lambda o: abs(math.log(ratio / o[0])))

    @staticmethod
    def _gaussian_roll(mu: float, sigma: float) -> float:
        """Generate one Gaussian roll (clamped to 1–100)."""
        roll = random.gauss(mu, sigma)
        return max(1.0, min(100.0, roll))

    @staticmethod
    def _bucket_loss(z: float):
        """Return the discrete losses (no interpolation)."""
        bands = CombatResolution.Z_BANDS
        defL = CombatResolution.DEFENDER_LOSS
        attL = CombatResolution.ATTACKER_LOSS

        if z <= bands[0]: return defL[0], attL[0]
        elif z <= bands[1]: return defL[1], attL[1]
        elif z <= bands[2]: return defL[2], attL[2]
        elif z <= bands[3]: return defL[3], attL[3]
        elif z <= bands[4]: return defL[4], attL[4]
        else: return defL[5], attL[5]

    @staticmethod
    def resolve(attackerCF: float, defenderCF: float) -> CombatResult:
        """Main entrypoint."""
        ratio = attackerCF / max(0.001, defenderCF)
        odds_ratio, odds_label, z_shift = CombatResolution._snap_ratio(ratio)

        mu = CombatResolution.MU0 + z_shift * CombatResolution.SIGMA
        roll = CombatResolution._gaussian_roll(mu, CombatResolution.SIGMA)
        z_neutral = (roll - CombatResolution.MU0) / CombatResolution.SIGMA

        def_loss, att_loss = CombatResolution._bucket_loss(z_neutral)

        return CombatResult(
            odds_label=odds_label,
            odds_ratio=odds_ratio,
            mu=round(mu, 2),
            roll=round(roll, 1),
            z_neutral=round(z_neutral, 2),
            defender_loss_pct=def_loss,
            attacker_loss_pct=att_loss,
        )


if __name__ == "__main__":
    # Example runs
    random.seed(42)
    for atk, defn in [(10, 10), (20, 10), (10, 20), (30, 10), (10, 30)]:
        res = CombatResolution.resolve(atk, defn)
        print(res)

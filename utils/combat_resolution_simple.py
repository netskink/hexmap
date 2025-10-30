"""
combat_resolution_simple.py

Minimal combat resolver using your loss chart and a normalized 1–100 roll.
- Odds are snapped to the nearest bracket in {1:3, 1:2, 1:1, 2:1, 3:1}
  using nearest in log-space (fair around unity).
- Each bracket shifts the mean μ of a Gaussian roll; σ is fixed.
- Losses come from your z-band table with linear interpolation.
- Bands are referenced to the *neutral* curve (μ0=50), as in your charts.

No external dependencies (uses Python's random.gauss).
"""

from __future__ import annotations
import math, random
from dataclasses import dataclass
from typing import Tuple, List

# ---- Core setup ----
MU0   = 50.0          # neutral mean for 1:1
SIGMA = 16.5          # so ±3σ ≈ 1..100

# Your loss table by z band
TABLE_Z   = [-3,  -2,  -1,   0,   1,   2,   3]
DEF_LOSS  = [ 3,   5,  10,  15,  20,  30,  40]  # percent
ATT_LOSS  = [40,  30,  20,  15,  10,   5,   3]  # percent

# Odds brackets (attacker:defender) and precomputed z-shifts:
# z = Φ^{-1}(O/(1+O)); hard-coded to avoid SciPy.
BRACKETS: List[Tuple[str, float, float]] = [
    ("1:3", 1/3, -0.6745),
    ("1:2", 1/2, -0.4307),
    ("1:1", 1.0,  0.0000),
    ("2:1", 2.0,  0.4307),
    ("3:1", 3.0,  0.6745),
]

@dataclass
class CombatResult:
    odds_label: str
    odds_ratio: float
    mu: float
    roll: float
    z_neutral: float
    defender_loss_pct: float
    attacker_loss_pct: float

def _nearest_bracket(ratio: float) -> Tuple[str, float, float]:
    """Choose nearest odds bracket in log-space."""
    lr = math.log(ratio)
    best = BRACKETS[0]
    best_d = float("inf")
    for label, r, zshift in BRACKETS:
        d = abs(lr - math.log(r))
        if d < best_d:
            best_d = d
            best = (label, r, zshift)
    return best

def _lin(x0, y0, x1, y1, x):
    if x1 == x0: return y0
    t = (x - x0) / (x1 - x0)
    return y0 + t*(y1 - y0)

def _lookup_loss(z: float, bands_z, bands_v) -> float:
    """Piecewise-linear interpolation with clamping at ends."""
    if z <= bands_z[0]: return float(bands_v[0])
    if z >= bands_z[-1]: return float(bands_v[-1])
    for i in range(1, len(bands_z)):
        if z <= bands_z[i]:
            return float(_lin(bands_z[i-1], bands_v[i-1], bands_z[i], bands_v[i], z))
    return float(bands_v[-1])

def resolve(attacker_cf: float, defender_cf: float, seed: int | None = None) -> CombatResult:
    """
    Resolve one combat using two inputs.
    - attacker_cf: attacker combat factor (must be > 0)
    - defender_cf: defender combat factor (must be > 0)
    Returns a CombatResult with losses (%).
    """
    if attacker_cf <= 0 or defender_cf <= 0:
        raise ValueError("combat factors must be positive")
    
    # 1) snap odds
    ratio = attacker_cf / defender_cf
    odds_label, odds_ratio, zshift = _nearest_bracket(ratio)
    
    # 2) compute bracket mean for the roll
    mu = MU0 + zshift * SIGMA
    
    # 3) roll: Gaussian with mean mu, stdev SIGMA (clamped 1..100)
    rng = random.Random(seed)
    roll = rng.gauss(mu, SIGMA)
    roll = max(1.0, min(100.0, roll))
    
    # 4) compute z relative to *neutral* baseline (μ0=50, σ=16.5)
    z_neutral = (roll - MU0) / SIGMA
    
    # 5) lookup losses via neutral z-bands
    defender_loss = _lookup_loss(z_neutral, TABLE_Z, DEF_LOSS)
    attacker_loss = _lookup_loss(z_neutral, TABLE_Z, ATT_LOSS)
    
    return CombatResult(
        odds_label=odds_label,
        odds_ratio=odds_ratio,
        mu=round(mu, 2),
        roll=round(roll, 1),
        z_neutral=round(z_neutral, 2),
        defender_loss_pct=round(defender_loss),
        attacker_loss_pct=round(attacker_loss),
    ) # round(x,1) would return one decimal point

# Tiny demo if executed directly
if __name__ == "__main__":
    for a, d in [(10,10), (30,10), (10,30), (20,10), (15,10)]:
        r = resolve(a, d, seed=42)
        print(f"A={a:>3} D={d:>3} | {r.odds_label:>3} | μ={r.mu:5.1f} roll={r.roll:5.1f} "
              f"z={r.z_neutral:5.2f} | D%={r.defender_loss_pct:4.1f} A%={r.attacker_loss_pct:4.1f}")

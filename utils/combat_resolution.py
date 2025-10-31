"""
combat_resolution.py (extended)

Turn-based combat resolver using a normalized 0–100 Gaussian roll.
- Baseline: N(μ0=50, σ=16.5)  (≈ ±3σ covers 1..100)
- Odds shift the *mean* using standard-normal probit:
    p = O / (O+1)  →  z = Φ⁻¹(p)  →  μ = μ0 + z * σ
- Losses are read from a designer table indexed by a z-score.
- You can choose how to compute that z-score via `band_reference`:
    * "neutral":  z = (roll - μ0) / σ
    * "shifted":  z = (roll - μ)  / σ
  Neutral = one universal outcome chart; Shifted = per-fight chart.

New in this version
-------------------
• Odds brackets expanded and capped to 1:6 … 6:1
• `band_reference` parameter ("neutral" or "shifted")
• Optional multi-sample averaging to reduce variance (`roll_samples`)

Author: ChatGPT
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional, Sequence, Tuple
from bisect import bisect_left
import math

import numpy as np
from scipy.stats import norm


# -------------------------
# Core configuration
# -------------------------
MU0: float   = 50.0
SIGMA: float = (100.0 - 1.0) / 6.0  # 16.5 → ±3σ ≈ 1..100

# Cap the usable odds range
MIN_ODDS: float = 1.0 / 6.0
MAX_ODDS: float = 6.0

# Odds brackets (attacker:defender → numeric ratio).
# Ordered from defender-favored to attacker-favored.
DEFAULT_ODDS_BRACKETS: Sequence[Tuple[str, float]] = (
    ("1:6", 1/6),
    ("1:5", 1/5),
    ("1:4", 1/4),
    ("1:3", 1/3),
    ("1:2", 1/2),
    ("1:1", 1.0),
    ("2:1", 2.0),
    ("3:1", 3.0),
    ("4:1", 4.0),
    ("5:1", 5.0),
    ("6:1", 6.0),
)

# Designer z-band loss table
TABLE_Z = np.array([-3, -2, -1,  0,  1,  2,  3], dtype=float)
DEF_LOSS = np.array([  3,  5, 10, 15, 20, 30, 40], dtype=float)  # percent
ATT_LOSS = np.array([ 40, 30, 20, 15, 10,  5,  3], dtype=float)  # percent


@dataclass(frozen=True)
class CombatResult:
    odds_label: str
    odds_ratio: float
    p: float
    z_shift: float
    mu: float
    roll: float
    z_for_bands: float
    defender_loss_pct: float
    attacker_loss_pct: float


def _interp(x0: float, y0: float, x1: float, y1: float, x: float) -> float:
    if x1 == x0:
        return y0
    t = (x - x0) / (x1 - x0)
    return y0 + t * (y1 - y0)


def _piecewise_linear(x_points: Sequence[float], y_points: Sequence[float], x: float) -> float:
    """Piecewise-linear interpolation with clamping at ends."""
    if x <= x_points[0]:
        return float(y_points[0])
    if x >= x_points[-1]:
        return float(y_points[-1])
    i = bisect_left(x_points, x)
    if x_points[i] == x:
        return float(y_points[i])
    x0, x1 = x_points[i-1], x_points[i]
    y0, y1 = y_points[i-1], y_points[i]
    return float(_interp(x0, y0, x1, y1, x))


def _nearest_odds_bracket(ratio: float,
                          brackets: Sequence[Tuple[str, float]]) -> Tuple[str, float]:
    """Clamp ratio to [MIN_ODDS, MAX_ODDS] and choose nearest bracket in log space."""
    ratio = max(min(ratio, MAX_ODDS), MIN_ODDS)
    lr = math.log(ratio)
    best = None
    best_dist = float("inf")
    for label, r in brackets:
        d = abs(lr - math.log(r))
        if d < best_dist:
            best_dist = d
            best = (label, r)
    return best  # type: ignore[return-value]


def _sample_roll(mu: float, sigma: float, rng: np.random.Generator, k: int = 1) -> float:
    """Return one clamped roll; if k>1, average k normals to reduce variance."""
    if k <= 1:
        roll = rng.normal(mu, sigma)
    else:
        roll = rng.normal(mu, sigma, size=k).mean()
    return float(np.clip(roll, 1.0, 100.0))


def resolve_battle(attacker_cf: float,
                   defender_cf: float,
                   rng_seed: Optional[int] = None,
                   brackets: Sequence[Tuple[str, float]] = DEFAULT_ODDS_BRACKETS,
                   mu0: float = MU0,
                   sigma: float = SIGMA,
                   table_z: Sequence[float] = TABLE_Z,
                   def_loss: Sequence[float] = DEF_LOSS,
                   att_loss: Sequence[float] = ATT_LOSS,
                   band_reference: str = "neutral",
                   roll_samples: int = 1) -> CombatResult:
    """
    Resolve a single battle.

    Parameters
    ----------
    attacker_cf, defender_cf : float
        Positive combat factors.
    rng_seed : Optional[int]
        Seed for reproducibility.
    brackets : sequence[(label, ratio)]
        Odds brackets (will be chosen by nearest in log space after clamping to 1:6..6:1).
    mu0, sigma : float
        Baseline neutral distribution parameters.
    table_z, def_loss, att_loss : sequences
        Loss table sampled by z-bands.
    band_reference : {"neutral","shifted"}
        - "neutral" → z_for_bands = (roll - mu0) / sigma
        - "shifted" → z_for_bands = (roll - mu)  / sigma
    roll_samples : int
        If >1, average this many Normal draws to reduce variance.

    Returns
    -------
    CombatResult
    """
    if attacker_cf <= 0 or defender_cf <= 0:
        raise ValueError("Combat factors must be positive.")

    # 1) Odds bracket selection
    ratio = attacker_cf / defender_cf
    odds_label, odds_ratio = _nearest_odds_bracket(ratio, brackets)

    # 2) Mean shift from odds
    p = odds_ratio / (1.0 + odds_ratio)
    z_shift = float(norm.ppf(p))
    mu = mu0 + z_shift * sigma

    # 3) Roll
    rng = np.random.default_rng(rng_seed)
    roll = _sample_roll(mu, sigma, rng, k=roll_samples)

    # 4) z used for band lookup
    if band_reference == "neutral":
        z_for_bands = (roll - mu0) / sigma
    elif band_reference == "shifted":
        z_for_bands = (roll - mu) / sigma
    else:
        raise ValueError("band_reference must be 'neutral' or 'shifted'")

    # 5) Interpolate losses
    defender_loss_pct = _piecewise_linear(table_z, def_loss, z_for_bands)
    attacker_loss_pct = _piecewise_linear(table_z, att_loss, z_for_bands)

    return CombatResult(
        odds_label=odds_label,
        odds_ratio=float(odds_ratio),
        p=float(p),
        z_shift=z_shift,
        mu=float(mu),
        roll=float(roll),
        z_for_bands=float(z_for_bands),
        defender_loss_pct=float(defender_loss_pct),
        attacker_loss_pct=float(attacker_loss_pct),
    )


# -------------------------
# Demo (run this file)
# -------------------------
if __name__ == "__main__":
    demo_pairs = [
        ("Even", 10, 10),
        ("Attacker 3:1-ish", 30, 10),
        ("Defender 1:4-ish", 10, 40),
        ("Attacker 5:1-ish", 50, 10),
        ("Defender 1:6-ish", 10, 60),
    ]
    for ref in ("neutral", "shifted"):
        print(f"\n=== band_reference = {ref} ===")
        for name, a, d in demo_pairs:
            res = resolve_battle(a, d, rng_seed=42, band_reference=ref, roll_samples=3)
            print(f"{name:>16s} | A={a:>3} D={d:>3} | odds={res.odds_label:>3} "
                  f"| μ={res.mu:5.1f} roll={res.roll:5.1f} z*={res.z_for_bands:5.2f} "
                  f"| D_loss={res.defender_loss_pct:5.1f}% A_loss={res.attacker_loss_pct:5.1f}%")

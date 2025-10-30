# test_run.py
import random
from combat_resolution_simple import CombatResolution  # adjust if your filename differs

random.seed(123)  # reproducible rolls

rows = []
cases = [(1,1), (2,1), (3,1), (4,1), (5,1),
         (1,2), (1,3)]

# Header
print(f"{'ACF':>3}  {'DCF':>3}  {'ODDS':>5}  {'ROLL':>6}  {'Z':>6}  {'DEF%':>5}  {'ATT%':>5}")
print("-"*44)

for a, d in cases:
    res = CombatResolution.resolve(a, d)
    print(f"{a:>3}  {d:>3}  {res.odds_label:>5}  {res.roll:>6.1f}  {res.z_neutral:>6.2f}  {res.defender_loss_pct:>5d}  {res.attacker_loss_pct:>5d}")


# test_run.py
from combat_resolution import resolve_battle
print("ACF, DCF, Def Loss, Atk Loss")
for a,d in [(1,1),(2,2),(3,1),(4,1),(5,1)]:
    res = resolve_battle(a, d)
    print(a,d, res.defender_loss_pct, res.attacker_loss_pct)



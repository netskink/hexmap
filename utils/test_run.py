# test_run.py
#from combat_resolution import resolve_battle
from combat_resolution_simple import resolve
print("ACF, DCF, Def Loss, Atk Loss")
for a,d in [(1,1),(2,1),(3,1),(4,1),(5,1)]:
    #    res = resolve_battle(a, d)
    res = resolve(a, d)
    print(a,d, res.defender_loss_pct, res.attacker_loss_pct)



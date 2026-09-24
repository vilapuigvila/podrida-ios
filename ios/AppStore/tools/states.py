"""Demo games for the App Store screenshots, written as the app saves them (Game JSON)."""
import json, random

def play(names, turns, done, seed, partial=None):
    """`done` turns fully played; `partial` = calls for the next turn (no results yet)."""
    rnd = random.Random(seed)
    n = len(names)
    hands = [[None]*n for _ in range(turns)]
    won = [[None]*n for _ in range(turns)]
    for t in range(done):
        cards = t + 1
        w = [0]*n
        for _ in range(cards): w[rnd.randrange(n)] += 1
        while True:
            calls = [max(0, x + rnd.choice([0, 0, 0, 1, -1])) for x in w]
            if sum(calls) != cards: break
        hands[t], won[t] = calls, w
    if partial is not None:
        hands[done] = partial
    return {"playerNames": names, "hands": hands, "won": won}

states = {
    # Mid-game: five turns scored, the sixth being called.
    "ledger": play(["Marta", "Jordi", "Laia", "Pau"], 10, 5, 7, partial=[1, 2, None, None]),
    # Turn 3 with calls adding up to 3: the ledger flags it.
    "warning": play(["Marta", "Jordi", "Laia", "Pau"], 10, 2, 11, partial=[1, 0, 2, 0]),
    # A big table late in the game.
    "crowd": play(["Marta", "Jordi", "Laia", "Pau", "Núria", "Oriol"], 12, 8, 23),
}
for k, v in states.items():
    json.dump(v, open(f"{k}.json", "w"), ensure_ascii=False, separators=(",", ":"))

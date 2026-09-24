"""Demo games for the App Store screenshots, written as the app saves them (Game JSON)."""
import json
import random


def play(names, turns, done, seed, partial=None):
    """Plays `done` turns by the rules; `partial` is the next turn's calls, with no results yet."""
    dice = random.Random(seed)
    players = len(names)
    hands = [[None] * players for _ in range(turns)]
    won = [[None] * players for _ in range(turns)]
    for turn in range(done):
        dealt = turn + 1
        results = [0] * players
        for _ in range(dealt):
            results[dice.randrange(players)] += 1
        # Calls stay within the hands dealt and can't add up to them.
        while True:
            calls = [min(dealt, max(0, result + dice.choice([0, 0, 0, 1, -1]))) for result in results]
            if sum(calls) != dealt:
                break
        hands[turn], won[turn] = calls, results
    if partial is not None:
        hands[done] = partial
    return {"playerNames": names, "hands": hands, "won": won}


states = {
    # Mid-game: five turns scored, the sixth being called.
    "ledger": play(["Marta", "Jordi", "Laia", "Pau"], 10, 5, 7, partial=[1, 2, None, None]),
    # Turn 3 with calls adding up to 3: the ledger stops on it.
    "warning": play(["Marta", "Jordi", "Laia", "Pau"], 10, 2, 11, partial=[1, 0, 2, 0]),
    # A big table late in the game.
    "crowd": play(["Marta", "Jordi", "Laia", "Pau", "Núria", "Oriol"], 12, 8, 23),
}
for name, game in states.items():
    with open(f"{name}.json", "w") as output:
        json.dump(game, output, ensure_ascii=False, separators=(",", ":"))

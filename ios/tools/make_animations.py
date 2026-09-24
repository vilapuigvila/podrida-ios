#!/usr/bin/env python3
"""Writes the onboarding's Lottie animations into Podrida/Resources/Animations.

The animations are drawn here in code, in the app's ledger palette, so there are no third-party
assets to license. Run from anywhere: python3 ios/tools/make_animations.py
"""
import json
import math
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "Podrida" / "Resources" / "Animations"
FPS = 30
SIZE = 512


def rgb(hex_value):
    return [((hex_value >> s) & 0xFF) / 255 for s in (16, 8, 0)] + [1]


PAPER = rgb(0xEAF0E3)
CARD = rgb(0xFBFCF6)
LINE = rgb(0xC7D3BE)
RULE = rgb(0xA63D33)
INK = rgb(0x202B21)
INK_SOFT = rgb(0x5B6B57)
BRASS = rgb(0xA9812E)
BRASS_DARK = rgb(0x7E5F1F)
OLIVE = rgb(0x6E8B3D)

# Segment easings: (out tangent of this key, in tangent of the next key).
EASE = {
    "io": ({"x": [0.42], "y": [0]}, {"x": [0.58], "y": [1]}),
    "out": ({"x": [0.16], "y": [0.8]}, {"x": [0.3], "y": [1]}),
    "in": ({"x": [0.55], "y": [0]}, {"x": [0.9], "y": [0.6]}),
    "lin": ({"x": [0], "y": [0]}, {"x": [1], "y": [1]}),
}


# --- Values ------------------------------------------------------------------------------------

def static(v):
    return {"a": 0, "k": v}


def anim(*keys):
    """keys: (frame, value) or (frame, value, easing of the segment that starts here)."""
    frames = []
    for n, key in enumerate(keys):
        t, v = key[0], key[1]
        ease = key[2] if len(key) > 2 else "io"
        k = {"t": t, "s": v if isinstance(v, list) else [v]}
        if n < len(keys) - 1:
            if ease == "hold":
                k["h"] = 1
            else:
                k["o"], k["i"] = EASE[ease]
        frames.append(k)
    return {"a": 1, "k": frames}


def val(v):
    return v if isinstance(v, dict) else static(v)


# --- Shapes ------------------------------------------------------------------------------------

def rect(w, h, x=0, y=0, r=0):
    return {"ty": "rc", "d": 1, "s": static([w, h]), "p": static([x, y]), "r": static(r)}


def ellipse(w, h, x=0, y=0):
    return {"ty": "el", "d": 1, "s": static([w, h]), "p": static([x, y])}


def path(points, closed=False, tangents=None):
    tangents = tangents or [([0, 0], [0, 0])] * len(points)
    return {"ty": "sh", "d": 1, "ks": static({
        "v": [list(p) for p in points],
        "i": [list(t[0]) for t in tangents],
        "o": [list(t[1]) for t in tangents],
        "c": closed,
    })}


def fill(color, opacity=100):
    return {"ty": "fl", "c": static(color), "o": val(opacity), "r": 1}


def stroke(color, width, opacity=100):
    return {"ty": "st", "c": static(color), "o": val(opacity), "w": static(width), "lc": 2, "lj": 2, "ml": 4}


def trim(end, start=0):
    return {"ty": "tm", "s": val(start), "e": val(end), "o": static(0), "m": 1}


def group(*items, p=(0, 0), a=(0, 0), s=100, r=0, o=100):
    scale = s if isinstance(s, dict) else static([s, s])
    return {"ty": "gr", "it": list(items) + [{
        "ty": "tr", "p": val(list(p)) if not isinstance(p, dict) else p, "a": static(list(a)),
        "s": scale, "r": val(r), "o": val(o), "sk": static(0), "sa": static(0),
    }]}


def layer(name, shapes, p=(256, 256), a=(0, 0), s=100, r=0, o=100):
    scale = s if isinstance(s, dict) else static([s, s, 100])
    return {
        "ddd": 0, "ty": 4, "nm": name, "sr": 1, "ao": 0, "bm": 0, "st": 0, "ip": 0, "op": 9999,
        "ks": {
            "o": val(o), "r": val(r), "s": scale, "a": static(list(a) + [0]),
            "p": p if isinstance(p, dict) else static(list(p) + [0]),
        },
        "shapes": shapes,
    }


def scale_keys(*keys):
    """Uniform scale keyframes: (frame, percent[, easing])."""
    return anim(*[(k[0], [k[1], k[1], 100], *k[2:]) for k in keys])


def composition(name, frames, layers):
    for index, item in enumerate(layers, start=1):
        item["ind"] = index
        item["op"] = frames
    return {"v": "5.7.4", "fr": FPS, "ip": 0, "op": frames, "w": SIZE, "h": SIZE, "nm": name,
            "ddd": 0, "assets": [], "layers": layers}


def star(points, outer, inner, cx=0, cy=0, rotation=-90):
    vertices = []
    for n in range(points * 2):
        radius = outer if n % 2 == 0 else inner
        angle = math.radians(rotation + n * 180 / points)
        vertices.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    return path(vertices, closed=True)


# --- 1. Deal: Spanish-deck cards fly in and fan out --------------------------------------------

CARD_W, CARD_H = 136, 192


def suit(kind):
    """A pip from the Spanish deck, centered on the card."""
    cy = -CARD_H / 2
    if kind == "oros":  # coins
        return [
            group(ellipse(62, 62, 0, cy), fill(BRASS)),
            group(ellipse(40, 40, 0, cy), stroke(CARD, 4)),
            group(ellipse(12, 12, 0, cy), fill(CARD)),
        ]
    if kind == "copas":  # cups
        bowl = path([(-28, cy - 26), (28, cy - 26), (0, cy + 8)], closed=True,
                    tangents=[([0, 0], [0, 26]), ([0, 26], [0, 0]), ([22, 0], [-22, 0])])
        return [
            group(bowl, fill(RULE)),
            group(rect(10, 22, 0, cy + 16), fill(RULE)),
            group(rect(40, 8, 0, cy + 30, 3), fill(RULE)),
        ]
    if kind == "espadas":  # swords
        return [
            group(path([(0, cy - 44), (0, cy + 24)]), stroke(INK_SOFT, 8)),
            group(path([(-22, cy + 22), (22, cy + 22)]), stroke(INK_SOFT, 7)),
            group(ellipse(14, 14, 0, cy + 40), fill(INK_SOFT)),
        ]
    # bastos: clubs
    return [
        group(path([(-14, cy + 38), (14, cy - 38)]), stroke(OLIVE, 18)),
        group(ellipse(16, 16, 12, cy - 12), fill(OLIVE)),
        group(ellipse(12, 12, -10, cy + 10), fill(OLIVE)),
    ]


def card_shapes(kind, color):
    cy = -CARD_H / 2
    corners = [
        group(rect(14, 4, -CARD_W / 2 + 20, cy - CARD_H / 2 + 20, 2), fill(color)),
        group(rect(14, 4, CARD_W / 2 - 20, cy + CARD_H / 2 - 20, 2), fill(color)),
    ]
    frame = [
        group(rect(CARD_W - 18, CARD_H - 18, 0, cy, 8), stroke(color, 1.5, 55)),
        group(rect(CARD_W, CARD_H, 0, cy, 14), fill(CARD), stroke(INK, 4)),
    ]
    return suit(kind) + corners + frame


def deal():
    frames = 150
    kinds = [("oros", BRASS), ("copas", RULE), ("espadas", INK_SOFT), ("bastos", OLIVE), ("oros", BRASS)]
    fan = [-36, -18, 0, 18, 36]
    layers = []
    for i, (kind, color) in enumerate(kinds):
        d = i * 6
        back = (4 - i) * 3
        x = 256 + (i - 2) * 34
        y = 410 + abs(i - 2) * 10
        position = anim(
            (0, [256, 700], "hold"),
            (d, [256, 700], "out"),
            (d + 18, [x, y]),
            (96 + back, [x, y], "io"),
            (114 + back, [256, 404], "in"),
            (138, [256, 404], "in"),
            (149, [256, 720]),
        )
        rotation = anim(
            (0, fan[i] - 70, "hold"),
            (d, fan[i] - 70, "out"),
            (d + 18, fan[i] + 6, "io"),
            (d + 26, fan[i]),
            (96 + back, fan[i], "io"),
            (114 + back, 0),
        )
        layers.append(layer(f"card {i + 1}", card_shapes(kind, color), p=position, r=rotation))
    layers.reverse()  # the first card dealt sits at the bottom of the fan
    shadow = layer("shadow", [group(ellipse(300, 34), fill(INK, 12))], p=(256, 420),
                   s=anim((0, [0, 0, 100], "hold"), (6, [0, 0, 100], "out"), (40, [100, 100, 100]),
                          (100, [100, 100, 100], "io"), (120, [55, 55, 100]), (140, [55, 55, 100], "in"),
                          (149, [0, 0, 100])))
    return composition("deal", frames, layers + [shadow])


# --- 2. Call: tally marks on a score slip, then circled -------------------------------------------

def call():
    frames = 150
    slip = layer("slip", [
        group(path([(-110, -94), (-110, 94)]), stroke(RULE, 2, 70)),
        group(*[path([(-150, y), (150, y)]) for y in (-60, -20, 20, 60)], stroke(LINE, 2)),
        group(rect(320, 230, 0, 0, 10), fill(CARD), stroke(INK, 4)),
    ], r=-3, s=scale_keys((0, 96), (12, 102), (20, 100)))

    marks = []
    xs = [-58, -24, 10, 44]
    for n, x in enumerate(xs):
        start = 16 + n * 11
        mark = path([(x - 3, -46), (x + 3, 44)], tangents=[([0, 0], [4, 30]), ([-2, -30], [0, 0])])
        marks.append(group(mark, stroke(INK, 9), trim(anim((start, 0, "out"), (start + 8, 100)))))
    slash = path([(-86, 34), (74, -28)], tangents=[([0, 0], [50, -14]), ([-50, 24], [0, 0])])
    marks.append(group(slash, stroke(INK, 9), trim(anim((64, 0, "out"), (73, 100)))))
    fade = anim((0, 100), (124, 100, "io"), (140, 0))
    tally = layer("tally", marks, p=(262, 258), r=-3, o=fade)

    loop = path([(0, -92), (128, 0), (0, 92), (-128, 0)], closed=True,
                tangents=[([-72, 0], [72, 0]), ([0, -52], [0, 52]), ([70, 0], [-70, 0]), ([0, 50], [0, -50])])
    circle = layer("circle", [group(loop, stroke(RULE, 7), trim(anim((80, 0, "io"), (100, 100))))],
                   p=(256, 256), r=-8, o=fade, s=scale_keys((0, 100), (98, 100), (104, 106), (112, 100)))

    pencil_body = [
        group(path([(0, 0), (-12, -30), (12, -30)], closed=True), fill(INK)),
        group(path([(-12, -30), (12, -30), (12, -34), (-12, -34)], closed=True), fill(CARD)),
        group(rect(24, 120, 0, -94), fill(BRASS)),
        group(rect(24, 18, 0, -163, 4), fill(RULE)),
    ]
    tips = [(262 + x + 4, 300) for x in xs]
    pencil_keys = [(0, [420, 520], "hold"), (8, [420, 520], "out")]
    for n, (tx, ty) in enumerate(tips):
        t = 16 + n * 11
        pencil_keys += [(t, [tx - 6, ty - 92], "lin"), (t + 8, [tx, ty], "out")]
    pencil_keys += [(64, [178, 290], "lin"), (73, [338, 228], "out"), (84, [420, 520])]
    pencil = layer("pencil", [group(*pencil_body)], p=anim(*pencil_keys), r=24)
    return composition("call", frames, [pencil, circle, tally, slip])


# --- 3. Stamp: the rubber stamp comes down on an exact call ----------------------------------------

def stamp():
    frames = 120
    tool = layer("stamp", [
        group(rect(150, 16, 0, -8, 4), fill(RULE)),
        group(rect(172, 40, 0, -36, 6), fill(INK)),
        group(rect(28, 56, 0, -84), fill(BRASS_DARK)),
        group(ellipse(70, 60, 0, -128), fill(BRASS)),
        group(ellipse(26, 14, -12, -140), fill(CARD, 45)),
    ],
        p=anim((0, [256, -120], "in"), (16, [256, 264], "hold"), (34, [256, 264], "in"), (52, [420, -180])),
        r=anim((0, -14, "in"), (16, 0, "hold"), (34, 0, "in"), (52, 24)),
        s=anim((0, [100, 100, 100], "hold"), (16, [112, 86, 100], "out"), (24, [100, 100, 100])))

    impression = layer("impression", [
        group(star(5, 50, 21), fill(RULE)),
        group(ellipse(154, 154), stroke(RULE, 3)),
        group(ellipse(196, 196), stroke(RULE, 9)),
    ], p=(256, 262), r=-10,
        o=anim((0, 0, "hold"), (17, 100), (100, 100, "io"), (116, 0)),
        s=scale_keys((0, 130, "hold"), (17, 130, "out"), (23, 94), (30, 100)))

    rays = []
    for n in range(10):
        angle = math.radians(n * 36 + 18)
        inner, outer = 118, 170
        rays.append(path([(inner * math.cos(angle), inner * math.sin(angle)),
                          (outer * math.cos(angle), outer * math.sin(angle))]))
    burst = layer("burst", [group(*rays, stroke(BRASS, 7),
                                  trim(anim((0, 0, "hold"), (17, 0, "out"), (26, 100)),
                                       anim((0, 0, "hold"), (22, 0, "out"), (34, 100))))],
                  p=(256, 262))

    dots = []
    for n in range(6):
        angle = math.radians(n * 60)
        x, y = 150 * math.cos(angle), 150 * math.sin(angle)
        dots.append(group(ellipse(10, 10), fill(RULE),
                          p=anim((0, [0, 0], "hold"), (18, [0, 0], "out"), (40, [x * 1.3, y * 1.3])),
                          o=anim((0, 0, "hold"), (18, 100), (30, 100, "io"), (42, 0))))
    confetti = layer("dots", dots, p=(256, 262))
    return composition("stamp", frames, [tool, burst, confetti, impression])


# --- 4. Crown: the leader's crown draws itself and sparkles ----------------------------------------

def crown():
    frames = 120
    outline = path([(-120, 60), (-120, -60), (-60, 0), (0, -90), (60, 0), (120, -60), (120, 60)], closed=True)
    body = [
        group(outline, stroke(BRASS_DARK, 10), trim(anim((0, 0, "io"), (30, 100)))),
        group(outline, fill(BRASS, anim((0, 0, "hold"), (24, 0, "io"), (38, 100)))),
    ]
    band = group(rect(260, 34, 0, 76, 6), fill(BRASS_DARK, anim((0, 0, "hold"), (26, 0, "io"), (38, 100))))
    jewels = []
    for n, (x, y) in enumerate([(-120, -72), (0, -104), (120, -72)]):
        t = 36 + n * 6
        jewels.append(group(ellipse(30, 30), fill(RULE), p=(x, y),
                            s=anim((0, [0, 0], "hold"), (t, [0, 0], "out"), (t + 8, [130, 130]), (t + 14, [100, 100]))))
    gems = [group(ellipse(22, 22, x, 76), fill(CARD, anim((0, 0, "hold"), (40, 0, "io"), (48, 100))))
            for x in (-70, 0, 70)]
    fade = anim((0, 100), (104, 100, "io"), (118, 0))
    crown_layer = layer("crown", jewels + gems + [band] + body, p=(256, 280), o=fade,
                        s=scale_keys((0, 100), (54, 100, "out"), (60, 108), (70, 100)),
                        r=anim((0, 0), (54, 0, "io"), (60, -4), (68, 3), (76, 0)))

    sparkles = []
    for n, (x, y, size) in enumerate([(120, 150, 1.0), (400, 130, 0.8), (430, 330, 0.7), (90, 360, 0.9),
                                      (256, 96, 0.6)]):
        t = 56 + n * 9
        peak = 100 * size
        sparkles.append(layer(f"sparkle {n + 1}", [group(star(4, 26, 7), fill(BRASS))], p=(x, y),
                              s=scale_keys((0, 0, "hold"), (t, 0, "out"), (t + 8, peak), (t + 20, 0)),
                              r=anim((0, 0, "hold"), (t, 0, "lin"), (t + 20, 90))))
    shadow = layer("shadow", [group(ellipse(280, 26), fill(INK, 12))], p=(256, 400), o=fade,
                   s=anim((0, [0, 0, 100], "hold"), (10, [0, 0, 100], "out"), (40, [100, 100, 100])))
    return composition("crown", frames, sparkles + [crown_layer, shadow])


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for build in (deal, call, stamp, crown):
        data = build()
        (OUT / f"{data['nm']}.json").write_text(json.dumps(data, separators=(",", ":")))
        print("wrote", OUT / f"{data['nm']}.json")

from PIL import Image, ImageDraw, ImageFont
import argparse, os, textwrap

DESK, PAPER, LINE, EDGE = "#161F1A", "#EAF0E3", "#C7D3BE", "#34443A"
TYPE = "/System/Library/Fonts/Supplemental/AmericanTypewriter.ttc"
MONO = "/System/Library/Fonts/SFNSMono.ttf"

SHOTS = [
    ("ledger", "Every player a column.\nEvery turn a line.",
     "Hands called, hands won and a running score, all on one ledger."),
    ("warning", "It knows the rule.",
     "When the calls add up to the turn, the ledger waits until someone changes theirs."),
    ("crowd", "Up to 24 players.",
     "Names and totals stay pinned while you scroll the table."),
    ("setup", "Deal in seconds.",
     "Pick the players and the turns, and the ledger is ready."),
]
DEVICES = {
    # folder, canvas, headline size, subline size, wrap, screenshot width, top of screenshot, corner radius
    "iphone": ("iphone-6.9", (1320, 2868), 104, 40, 44, 1080, 640, 112),
    "ipad": ("ipad-13", (2064, 2752), 112, 44, 64, 1600, 600, 56),
}

def rounded(im, r):
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.size[0] - 1, im.size[1] - 1], r, fill=255)
    return mask

args = argparse.ArgumentParser(description="Caption raw simulator screenshots for the App Store.")
args.add_argument("--raw", required=True)
args.add_argument("--out", required=True)
args = args.parse_args()
OUT = args.out

for dev, (folder, size, hs, ss, wrap, sw, top, r) in DEVICES.items():
    os.makedirs(f"{OUT}/{folder}", exist_ok=True)
    for i, (name, head, sub) in enumerate(SHOTS, 1):
        canvas = Image.new("RGB", size, DESK)
        d = ImageDraw.Draw(canvas)
        W, H = size
        hf = ImageFont.truetype(TYPE, hs, index=0)
        sf = ImageFont.truetype(MONO, ss)
        y = 150
        for line in head.split("\n"):
            w = d.textlength(line, font=hf)
            d.text(((W - w) / 2, y), line, font=hf, fill=PAPER)
            y += int(hs * 1.18)
        y += 26
        for line in textwrap.wrap(sub, wrap):
            w = d.textlength(line, font=sf)
            d.text(((W - w) / 2, y), line, font=sf, fill=LINE)
            y += int(ss * 1.45)
        shot = Image.open(f"{args.raw}/{dev}-{name}.png").convert("RGB")
        sh = round(shot.height * sw / shot.width)
        shot = shot.resize((sw, sh), Image.LANCZOS)
        top_y = max(top, y + 60)
        x = (W - sw) // 2
        # thin edge so the dark setup screen still reads against the desk
        edge = Image.new("RGB", (sw + 8, sh + 8), EDGE)
        canvas.paste(edge, (x - 4, top_y - 4), rounded(edge, r + 4))
        canvas.paste(shot, (x, top_y), rounded(shot, r))
        canvas.save(f"{OUT}/{folder}/{i:02d}-{name}.png", optimize=True)
        print(folder, i, name, canvas.size)

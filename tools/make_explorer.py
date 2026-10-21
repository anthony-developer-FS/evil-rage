#!/usr/bin/env python3
"""Builds the explorer sprite sheet and its SpriteFrames resource.

Usage: python3 tools/make_explorer.py

Writes art/player/explorer.svg (16x16 frames, one row per animation) and
resources/explorer_frames.tres. The sheet is an SVG of whole-pixel rectangles, so
Godot imports it pixel-exact while it stays a small text file in git. Each frame is assembled from small ASCII parts,
then a dark outline is added around the silhouette. The character faces right;
the player flips the sprite to face left. Feet sit on the bottom row of the frame.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FRAME = 16

PALETTE = {
    "H": (176, 122, 64),    # hat
    "h": (110, 70, 36),     # hat band, hat shadow
    "d": (92, 56, 34),      # hair
    "S": (242, 196, 141),   # skin
    "s": (201, 141, 90),    # skin shade
    "E": (27, 22, 33),      # eye
    "R": (204, 62, 52),     # scarf
    "r": (150, 40, 38),     # scarf shade
    "K": (222, 186, 110),   # shirt
    "k": (170, 134, 66),    # shirt shade, sleeve
    "B": (112, 72, 42),     # backpack
    "b": (74, 46, 28),      # belt
    "P": (84, 100, 64),     # trousers
    "p": (58, 70, 44),      # trousers, far leg
    "F": (66, 42, 28),      # boots
    "W": (255, 255, 255),   # death flash
}
OUTLINE = (27, 22, 33)

# Upper body is head (rows 0-6) plus torso (rows 7-10). The legs below it are
# bottom-aligned, so shorter legs lower the whole upper body by a pixel.
HEAD = [
    "..HHHH...",
    ".hhhhhh..",
    "HHHHHHHHH",
    ".dSSSSS..",
    ".dSSSES..",
    ".SSSSSs..",
    ".RRRRRR..",
]
HEAD_BLINK = HEAD[:4] + [".dSSSsS.."] + HEAD[5:]
HEAD_UP = [  # looking up, used when falling
    "..HHHH...",
    ".hhhhhh..",
    "HHHHHHHHH",
    ".dSSSES..",
    ".dSSSSS..",
    ".SSSSSs..",
    ".RRRRRR..",
]

TORSO = {
    "idle": [
        "BKKKKKK",
        "BKKkKKK",
        "BKKSKKK",
        ".bbbbbb",
    ],
    "fwd": [  # near arm swung forward
        "BKKKKKK.",
        "BKKKkkK.",
        "BKKKKKS.",
        ".bbbbbb.",
    ],
    "back": [  # near arm swung back
        "BKKKKKK",
        "kKKKKKK",
        "SKKKKKK",
        ".bbbbbb",
    ],
    "up": [  # both arms up, used for jumping and falling
        "SBKKKKKS",
        "kBKKKKKk",
        ".BKKKKK.",
        "..bbbbb.",
    ],
    "wall": [  # near hand pressed on the wall ahead
        "BKKKKKKS",
        "BKKKKkk.",
        "BKKKKKK.",
        ".bbbbbb.",
    ],
}

LEGS = {
    "stand": [
        "PPPPPP.",
        "PP..PP.",
        "PP..PP.",
        "FF..FFF",
    ],
    "stand_low": [  # 3 rows: idle breathing, body dips a pixel
        "PPPPPP.",
        "PP..PP.",
        "FF..FFF",
    ],
    "stride": [  # 3 rows: body dips a pixel
        "PPPPPPP..",
        "pp....PP.",
        "FF.....FFF",
    ],
    "pass_a": [
        "PPPPPP.",
        "..PPpp.",
        "..PP.FF",
        "..FFF..",
    ],
    "stride_b": [
        "PPPPPPP..",
        "PP....pp.",
        "FFF....FF",
    ],
    "pass_b": [
        "PPPPPP.",
        ".ppPP..",
        "FF.PP..",
        "...FFF.",
    ],
    "tuck": [  # 3 rows, knees up
        "PPPPPP.",
        "PPP.PPP",
        ".FF..FF",
    ],
    "dangle": [
        "PPPPPP.",
        ".PP.PP.",
        ".PP..PP",
        ".FF..FF",
    ],
    "wall": [
        "PPPPPP.",
        ".PP.PP.",
        ".PP.PP.",
        ".FF.FFF",
    ],
}

# Trailing scarf ends, drawn behind the neck. Offsets relative to the head origin.
SCARF_TAILS = {
    None: [],
    "low": [(-1, 6, "R"), (-2, 7, "r")],
    "high": [(-1, 6, "R"), (-2, 6, "R"), (-3, 5, "r")],
    "mid": [(-1, 6, "R"), (-2, 6, "r"), (-3, 7, "r")],
    "up": [(-1, 5, "R"), (-2, 4, "r"), (-2, 3, "r")],
}

HEAD_X = 4   # frame column of the head's left edge
BODY_X = 4   # frame column of the torso's left edge (the backpack)
LEG_X = 5    # frame column of the legs' left edge


def blank():
    return [[None] * FRAME for _ in range(FRAME)]


def stamp(grid, part, x, y):
    for row, line in enumerate(part):
        for col, ch in enumerate(line):
            if ch == ".":
                continue
            gx, gy = x + col, y + row
            if 0 <= gx < FRAME and 0 <= gy < FRAME:
                grid[gy][gx] = PALETTE[ch]


def body_frame(head, torso, legs, tail=None, dx=0, dy=0, leg_dx=0):
    grid = blank()
    leg = LEGS[legs]
    top_of_legs = FRAME - len(leg) + dy
    torso_y = top_of_legs - 4
    head_y = torso_y - 7
    stamp(grid, leg, LEG_X + dx + leg_dx, top_of_legs)
    stamp(grid, TORSO[torso], BODY_X + dx, torso_y)
    stamp(grid, head, HEAD_X + dx, head_y)
    for ox, oy, ch in SCARF_TAILS[tail]:
        stamp(grid, [ch], HEAD_X + dx + ox, head_y + oy)
    return outline(grid)


def outline(grid):
    out = [row[:] for row in grid]
    for y in range(FRAME):
        for x in range(FRAME):
            if grid[y][x] is not None:
                continue
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < FRAME and 0 <= ny < FRAME and grid[ny][nx] is not None:
                    out[y][x] = OUTLINE
                    break
    return out


def flash(grid):
    return [[PALETTE["W"] if c is not None else None for c in row] for row in grid]


def death_frames():
    hit = body_frame(HEAD_BLINK, "up", "tuck", "up", dy=-1)
    # Flattened: hat knocked up, body squashed, then scattered bits.
    squash = blank()
    stamp(squash, ["..HHHH...", ".hhhhhh..", "HHHHHHHHH"], 4, 3)
    stamp(squash, [
        ".dSSSSS...",
        "SRRRRRRS..",
        "kBKKKKKKk.",
        ".bbbbbbb..",
        "PPPPPPPP..",
        "FF....FFF.",
    ], 3, 10)
    squash = outline(squash)
    burst = blank()
    stamp(burst, ["..HHHH...", ".hhhhhh..", "HHHHHHHHH"], 5, 0)
    for x, y, ch in [(2, 9, "S"), (12, 8, "S"), (4, 13, "K"), (10, 12, "K"), (7, 10, "R"),
                     (8, 11, "R"), (3, 15, "F"), (11, 15, "F"), (6, 14, "P"), (9, 14, "P")]:
        stamp(burst, [ch], x, y)
    burst = outline(burst)
    gone = blank()
    stamp(gone, ["..HHHH...", ".hhhhhh..", "HHHHHHHHH"], 5, 13)
    gone = outline(gone)
    return [flash(hit), hit, squash, burst, gone]


ANIMATIONS = [
    # name, fps, loop, frames
    ("idle", 4.0, True, [
        body_frame(HEAD, "idle", "stand"),
        body_frame(HEAD, "idle", "stand"),
        body_frame(HEAD, "idle", "stand_low"),
        body_frame(HEAD_BLINK, "idle", "stand_low"),
    ]),
    ("run", 12.0, True, [
        body_frame(HEAD, "fwd", "stride", "low", leg_dx=-1),
        body_frame(HEAD, "idle", "pass_a", "high"),
        body_frame(HEAD, "back", "pass_a", "mid"),
        body_frame(HEAD, "back", "stride_b", "low", leg_dx=-1),
        body_frame(HEAD, "idle", "pass_b", "high"),
        body_frame(HEAD, "fwd", "pass_b", "mid"),
    ]),
    ("jump", 10.0, True, [
        body_frame(HEAD, "up", "tuck", "low", dy=-1),
        body_frame(HEAD, "up", "tuck", "mid", dy=-1),
    ]),
    ("fall", 10.0, True, [
        body_frame(HEAD_UP, "up", "dangle", "up"),
        body_frame(HEAD_UP, "up", "dangle", "high"),
    ]),
    ("wall_slide", 8.0, True, [
        body_frame(HEAD, "wall", "wall", "up", dx=1),
        body_frame(HEAD, "wall", "wall", "high", dx=1),
    ]),
    # The room reloads 0.25 s after death, so the whole animation fits in that.
    ("death", 20.0, False, death_frames()),
]


def write_sheet(path):
    cols = max(len(frames) for _, _, _, frames in ANIMATIONS)
    width, height = cols * FRAME, len(ANIMATIONS) * FRAME
    rects = []
    for row, (name, _, _, frames) in enumerate(ANIMATIONS):
        rects.append(f"<!-- {name} -->")
        for col, grid in enumerate(frames):
            for y in range(FRAME):
                x = 0
                while x < FRAME:
                    color = grid[y][x]
                    if color is None:
                        x += 1
                        continue
                    run = 1  # merge same-colored pixels on a row into one rect
                    while x + run < FRAME and grid[y][x + run] == color:
                        run += 1
                    rects.append(f'<rect x="{col * FRAME + x}" y="{row * FRAME + y}" '
                                 f'width="{run}" height="1" fill="#{bytes(color).hex()}"/>')
                    x += run
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}" shape-rendering="crispEdges">\n'
        + "\n".join(rects) + "\n</svg>\n")


def write_frames(path, texture_path):
    atlases = []
    anims = []
    for row, (name, fps, loop, frames) in enumerate(ANIMATIONS):
        entries = []
        for col in range(len(frames)):
            atlas_id = f"{name}_{col}"
            atlases.append(
                f'[sub_resource type="AtlasTexture" id="{atlas_id}"]\n'
                f'atlas = ExtResource("1")\n'
                f'region = Rect2({col * FRAME}, {row * FRAME}, {FRAME}, {FRAME})\n')
            entries.append('{\n"duration": 1.0,\n'
                           f'"texture": SubResource("{atlas_id}")\n' + '}')
        anims.append('{\n"frames": [' + ", ".join(entries) + '],\n'
                     f'"loop": {"true" if loop else "false"},\n'
                     f'"name": &"{name}",\n'
                     f'"speed": {fps}\n' + '}')
    text = (f'[gd_resource type="SpriteFrames" load_steps={len(atlases) + 2} format=3]\n\n'
            f'[ext_resource type="Texture2D" path="{texture_path}" id="1"]\n\n'
            + "\n".join(atlases) + "\n"
            '[resource]\n'
            'animations = [' + ", ".join(anims) + ']\n')
    path.write_text(text)


if __name__ == "__main__":
    write_sheet(ROOT / "art/player/explorer.svg")
    write_frames(ROOT / "resources/explorer_frames.tres", "res://art/player/explorer.svg")
    print("wrote art/player/explorer.svg and resources/explorer_frames.tres")

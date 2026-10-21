#!/usr/bin/env python3
"""Builds the sprite sheets for Death and the ghost, and their SpriteFrames.

Usage: python3 tools/make_monsters.py

Writes art/monsters/reaper.svg and resources/reaper_frames.tres (20x26 frames),
and art/monsters/ghost.svg and resources/ghost_frames.tres (16x16 frames). Like
the explorer, every frame is drawn from ASCII rows, outlined, and saved as an SVG
of whole-pixel rectangles so it imports pixel-exact and stays a small text file.
Both face right; the game flips them to face left.
"""
from pathlib import Path

from make_explorer import OUTLINE

ROOT = Path(__file__).resolve().parent.parent

REAPER_PALETTE = {
    "C": (46, 30, 58),      # cloak
    "c": (28, 18, 36),      # cloak shadow
    "k": (78, 54, 96),      # cloak highlight
    "B": (232, 226, 206),   # bone
    "b": (168, 160, 140),   # bone shade
    "E": (255, 70, 60),     # eye glow
    "e": (40, 12, 16),      # eye socket
    "H": (150, 36, 44),     # horns
    "h": (96, 20, 28),      # horn shade
    "S": (200, 208, 216),   # scythe blade
    "s": (120, 128, 140),   # blade shade
    "W": (120, 80, 44),     # scythe shaft
    "G": (255, 150, 70),    # glow in his hands
    "g": (220, 70, 40),     # dim glow
    "M": (110, 100, 120),   # smoke
    "m": (70, 62, 80),      # dark smoke
}

GHOST_PALETTE = {
    "O": (236, 240, 250),   # body
    "o": (176, 186, 214),   # body shade
    "E": (30, 24, 40),      # eyes, mouth
    "R": (220, 70, 90),     # tongue
    "P": (255, 160, 180),   # blush
}

# Death, 20 wide by 26 tall. The hood has horns, because he is also the devil.
# The scythe is held in the near hand on the right.
REAPER_W, REAPER_H = 20, 26
REAPER_IDLE = [
    "....................",
    "....H.......H.......",
    "....Hh.....hH...SSSS",
    ".....HCCCCCH...SSss.",
    "....CCkkkkCC..Ss..W.",
    "...CCkBBBBkCC.s...W.",
    "...CkBBBBBBkC.....W.",
    "...CkBeEBeEkC.....W.",
    "...CkBBBbBBkC.....W.",
    "...CCkBbbBkCC.....W.",
    "...CCCkBBkCCC.....W.",
    "..CCCCCCCCCCCC....W.",
    "..CkCCCCCCCCkCC...W.",
    ".CCkCCCCCCCCCkCC.BW.",
    ".CkCCCCCCCCCCCkCCBW.",
    ".CkCCCCCCCCCCCCkC.W.",
    ".CCCCCCCCCCCCCCC..W.",
    "..CCCCCCCCCCCCCC..W.",
    "..CCCcCCCcCCCcC...W.",
    "..CCcCCCcCCCcCC...W.",
    "...CcCCcCCCcCC....W.",
    "...C.CC.CC.CC.....W.",
    "....C..C..C.C.......",
    "....................",
    "....................",
    "....................",
]
# The hem sways: the bottom rows swapped for a second frame.
REAPER_HEM_B = [
    "..CCCcCCCcCCCcC...W.",
    "..CcCCCcCCCcCCC...W.",
    "...CCcCCCcCCcC....W.",
    "....CC.CC.CC.C....W.",
    "...C..C..C..........",
]


def reaper_idle(hem_b=False, dy=0):
    rows = REAPER_IDLE[:18] + (REAPER_HEM_B if hem_b else REAPER_IDLE[18:23]) + REAPER_IDLE[23:]
    return shift(rows, dy)


def reaper_cast(stage):
    """Arms raised beside the hood, the scythe left leaning on his shoulder.
    stage 0: arms rising. 1: arms up. 2: arms up, eyes blazing."""
    rows = [list(r) for r in reaper_idle()]
    # Take the near hand off the shaft.
    for y in (13, 14):
        rows[y][17] = "."
    if stage == 0:
        # Bony arms coming up out of the sleeves.
        lift = [(1, 11, "b"), (0, 10, "B"), (0, 9, "B"), (14, 11, "b"), (15, 10, "B"), (16, 9, "B")]
    else:
        # Arms raised high either side of the hood, reaching for the glow above it.
        lift = [(1, 11, "b"), (1, 10, "B"), (1, 9, "B"), (0, 8, "B"), (0, 7, "B"), (0, 6, "B"), (1, 5, "B"),
                (14, 11, "b"), (14, 10, "B"), (14, 9, "B"), (15, 8, "B"), (15, 7, "B"), (15, 6, "B"),
                (14, 5, "B")]
    for x, y, part in lift:
        for i, ch in enumerate(part):
            if ch != ".":
                rows[y][x + i] = ch
    if stage == 2:
        rows[7][6] = rows[7][9] = "G"
        rows[7][7] = rows[7][10] = "G"
    return ["".join(r) for r in rows]


def reaper_smoke(height):
    """Rising out of (or sinking into) a puff of smoke: only the top `height`
    rows of him show, sitting on the floor, with smoke around his hem."""
    body = reaper_idle()
    visible = body[:height]
    rows = ["." * REAPER_W] * (REAPER_H - 3 - height) + visible + ["." * REAPER_W] * 3
    rows = [list(r) for r in rows[:REAPER_H]]
    puff = [
        "..m.MMm..mMM..Mm.m..",
        ".mMMMmMMMMmMMMMMMm..",
        "mMMmMMMMmMMMMmMMMMm.",
    ]
    for i, line in enumerate(puff):
        y = REAPER_H - 5 + i
        for x, ch in enumerate(line):
            if ch != ".":
                rows[y][x] = ch
    return ["".join(r) for r in rows]


def shift(rows, dy):
    blank = "." * len(rows[0])
    if dy < 0:
        return rows[-dy:] + [blank] * -dy
    if dy > 0:
        return [blank] * dy + rows[:-dy]
    return rows


GHOST_W, GHOST_H = 16, 16
GHOST_CHASE = [
    "................",
    ".....OOOOO......",
    "...OOOOOOOOO....",
    "..OOOOOOOOOOO...",
    "..OOOOOEOOOEOO..",
    ".OOOOOOEOOOEOO..",
    ".OOOOOOOOOOOOOO.",
    ".OOOOEEEEEEEOOO.",
    "OOOOOERRRRREOOO.",
    "OOOOOOEERREEOOO.",
    "oOOOOOOOOOOOOOO.",
    "ooOOOOOOOOOOOOo.",
    ".oooOOOOOOOOOo..",
    "..ooooOOOOOoo...",
    "....ooo.oo.o....",
    "................",
]
GHOST_SHY = [
    "................",
    ".....OOOOO......",
    "...OOOOOOOOO....",
    "..OOOOOOOOOOO...",
    "..OOOOOOOOOOOO..",
    ".OOOOOOooOOooOO.",
    ".OOOOOOOOOOOOOO.",
    ".OOOOPOOOOOOPOO.",
    "OOOOOOOOOOOOOOO.",
    "OOOOOOOOOOOOOOO.",
    "oOOOOOOOOOOOOOO.",
    "ooOOOOOOOOOOOOo.",
    ".oooOOOOOOOOOo..",
    "..ooooOOOOOoo...",
    "....ooo.oo.o....",
    "................",
]
# Stubby arms over its eyes when shy, out in front when chasing.
GHOST_SHY_ARMS = [(6, 4, "oOo"), (10, 4, "oOo"), (6, 5, ".o."), (10, 5, ".o.")]
GHOST_CHASE_ARMS = [(13, 7, "OO"), (14, 8, "Oo")]


def with_parts(rows, parts):
    rows = [list(r) for r in rows]
    for x, y, part in parts:
        for i, ch in enumerate(part):
            if ch != "." and 0 <= x + i < len(rows[0]):
                rows[y][x + i] = ch
    return ["".join(r) for r in rows]


def ghost_tail_b(rows):
    """Second frame: the wispy tail flicks the other way."""
    rows = list(rows)
    rows[13] = "..oooOOOOOooo..."
    rows[14] = "...oo.ooo.oo...."
    return rows


def to_grid(rows, palette):
    return [[palette[ch] if ch != "." else None for ch in row] for row in rows]


def outline(grid):
    h, w = len(grid), len(grid[0])
    out = [row[:] for row in grid]
    for y in range(h):
        for x in range(w):
            if grid[y][x] is not None:
                continue
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < w and 0 <= ny < h and grid[ny][nx] is not None:
                    out[y][x] = OUTLINE
                    break
    return out


def sprite(rows, palette):
    return outline(to_grid(rows, palette))


REAPER = [
    # name, fps, loop, frames
    ("idle", 5.0, True, [reaper_idle(), reaper_idle(dy=-1), reaper_idle(True, -1), reaper_idle(True)]),
    ("cast", 10.0, False, [reaper_cast(0), reaper_cast(1), reaper_cast(2)]),
    ("appear", 14.0, False, [reaper_smoke(h) for h in (4, 9, 14, 19, 23)]),
    ("vanish", 14.0, False, [reaper_smoke(h) for h in (19, 14, 9, 4, 0)]),
]
GHOST = [
    ("shy", 3.0, True, [with_parts(GHOST_SHY, GHOST_SHY_ARMS), ghost_tail_b(with_parts(GHOST_SHY, GHOST_SHY_ARMS))]),
    ("chase", 6.0, True, [with_parts(GHOST_CHASE, GHOST_CHASE_ARMS),
                          ghost_tail_b(with_parts(GHOST_CHASE, GHOST_CHASE_ARMS))]),
]


def write_sheet(path, animations, palette, fw, fh):
    cols = max(len(frames) for _, _, _, frames in animations)
    width, height = cols * fw, len(animations) * fh
    rects = []
    for row, (name, _, _, frames) in enumerate(animations):
        rects.append(f"<!-- {name} -->")
        for col, rows in enumerate(frames):
            assert len(rows) == fh and all(len(r) == fw for r in rows), (name, col)
            grid = sprite(rows, palette)
            for y in range(fh):
                x = 0
                while x < fw:
                    color = grid[y][x]
                    if color is None:
                        x += 1
                        continue
                    run = 1  # merge same-colored pixels on a row into one rect
                    while x + run < fw and grid[y][x + run] == color:
                        run += 1
                    rects.append(f'<rect x="{col * fw + x}" y="{row * fh + y}" '
                                 f'width="{run}" height="1" fill="#{bytes(color).hex()}"/>')
                    x += run
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}" shape-rendering="crispEdges">\n'
        + "\n".join(rects) + "\n</svg>\n")


def write_frames(path, texture_path, animations, fw, fh):
    atlases = []
    anims = []
    for row, (name, fps, loop, frames) in enumerate(animations):
        entries = []
        for col in range(len(frames)):
            atlas_id = f"{name}_{col}"
            atlases.append(
                f'[sub_resource type="AtlasTexture" id="{atlas_id}"]\n'
                f'atlas = ExtResource("1")\n'
                f'region = Rect2({col * fw}, {row * fh}, {fw}, {fh})\n')
            entries.append('{\n"duration": 1.0,\n'
                           f'"texture": SubResource("{atlas_id}")\n' + '}')
        anims.append('{\n"frames": [' + ", ".join(entries) + '],\n'
                     f'"loop": {"true" if loop else "false"},\n'
                     f'"name": &"{name}",\n'
                     f'"speed": {fps}\n' + '}')
    path.write_text(
        f'[gd_resource type="SpriteFrames" load_steps={len(atlases) + 2} format=3]\n\n'
        f'[ext_resource type="Texture2D" path="{texture_path}" id="1"]\n\n'
        + "\n".join(atlases) + "\n"
        '[resource]\n'
        'animations = [' + ", ".join(anims) + ']\n')


if __name__ == "__main__":
    for name, anims, palette, fw, fh in [("reaper", REAPER, REAPER_PALETTE, REAPER_W, REAPER_H),
                                         ("ghost", GHOST, GHOST_PALETTE, GHOST_W, GHOST_H)]:
        write_sheet(ROOT / f"art/monsters/{name}.svg", anims, palette, fw, fh)
        write_frames(ROOT / f"resources/{name}_frames.tres", f"res://art/monsters/{name}.svg", anims, fw, fh)
        print(f"wrote art/monsters/{name}.svg and resources/{name}_frames.tres")

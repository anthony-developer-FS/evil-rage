#!/usr/bin/env python3
"""Builds the art for each explorer world: a 320x180 backdrop and an 8x8 tile sheet.

Usage: python3 tools/make_themes.py   (needs numpy)

For every theme in THEMES it writes:
  art/themes/<name>/backdrop.png  the painted room background, 320x180
  art/themes/<name>/tiles.png     32x16: row 0 is four top-surface tiles, row 1 four fill tiles
  art/themes/<name>/door.png      12x16 exit door, with a see-through background

Each image is painted pixel by pixel with numpy. They are PNGs rather than SVGs like
the explorer sheet because dithered backdrops would be megabytes of rectangles;
as PNGs they are a few KB, so like the audio they are stored as plain git objects
instead of LFS (see .gitattributes). Everything is seeded, so reruns give identical output.
The theme resources in resources/themes/ point at these files and hold the colors.

Backdrops stay dark and low in contrast so blocks, spikes and the player read
clearly in front of them. Tiles are drawn on a grid aligned to the world, so a
fake floor next to a real block is seamless, which the traps depend on.
"""
import struct
import zlib
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
W, H = 320, 180
T = 8  # tile size

BAYER = np.array([
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]) / 16.0 + 1 / 32.0


def hexc(s):
    s = s.lstrip("#")
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.uint8)


def canvas(w, h, color):
    img = np.zeros((h, w, 3), dtype=np.uint8)
    img[:] = hexc(color)
    return img


def dither_mask(alpha, ox=0, oy=0):
    """Boolean mask that is on in roughly `alpha` of pixels, with an ordered pattern."""
    h, w = alpha.shape
    tiled = np.tile(BAYER, (h // 4 + 2, w // 4 + 2))[oy:oy + h, ox:ox + w]
    return alpha > tiled


def paint(img, mask, color):
    img[mask] = hexc(color)


def blend(img, alpha, color, levels=None):
    """Dithered blend toward `color`. alpha is a float array the size of img."""
    alpha = np.clip(alpha, 0, 1)
    if levels:
        alpha = np.round(alpha * levels) / levels
    paint(img, dither_mask(alpha), color)


def vgrad(img, y0, y1, stops):
    """Vertical banded gradient through a list of colors, dithered at band edges."""
    h = y1 - y0
    t = np.linspace(0, len(stops) - 1, h)
    for i, ti in enumerate(t):
        a = int(np.floor(ti))
        b = min(a + 1, len(stops) - 1)
        f = ti - a
        row = np.full((1, img.shape[1]), f)
        mask = dither_mask(row, 0, (y0 + i) % 4)[0]
        img[y0 + i] = hexc(stops[a])
        img[y0 + i, mask] = hexc(stops[b])


def noise1d(n, seed, scale, octaves=3):
    """Smooth value noise in 0..1 over n samples."""
    rng = np.random.default_rng(seed)
    out = np.zeros(n)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        step = max(scale / (2 ** o), 1)
        pts = rng.random(int(n / step) + 3)
        x = np.arange(n) / step
        i = x.astype(int)
        f = x - i
        f = f * f * (3 - 2 * f)
        out += amp * (pts[i] * (1 - f) + pts[i + 1] * f)
        total += amp
        amp *= 0.5
    return out / total


def noise2d(w, h, seed, scale):
    rng = np.random.default_rng(seed)
    gw, gh = int(w / scale) + 3, int(h / scale) + 3
    g = rng.random((gh, gw))
    ys, xs = np.mgrid[0:h, 0:w] / scale
    xi, yi = xs.astype(int), ys.astype(int)
    fx, fy = xs - xi, ys - yi
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = g[yi, xi] * (1 - fx) + g[yi, xi + 1] * fx
    b = g[yi + 1, xi] * (1 - fx) + g[yi + 1, xi + 1] * fx
    return a * (1 - fy) + b * fy


def column_mask(heights, from_top, h=H):
    """Mask filled from the top down to heights[x], or from the bottom up to it."""
    ys = np.arange(h)[:, None]
    hs = np.asarray(heights)[None, :]
    return ys < hs if from_top else ys >= hs


def radial(cx, cy, r, w=W, h=H, squash=1.0):
    ys, xs = np.mgrid[0:h, 0:w]
    d = np.sqrt((xs - cx) ** 2 + ((ys - cy) / squash) ** 2) / r
    return np.clip(1 - d, 0, 1)


def rect(img, x, y, w, h, color):
    x0, y0 = max(int(x), 0), max(int(y), 0)
    x1, y1 = min(int(x + w), img.shape[1]), min(int(y + h), img.shape[0])
    if x1 > x0 and y1 > y0:
        img[y0:y1, x0:x1] = hexc(color)


def triangle(img, x, y, w, h, color, down=True):
    """Spike-like triangle with its base at y (pointing down) or tip at y (up)."""
    for i in range(int(h)):
        frac = 1 - i / h if down else (i + 1) / h
        half = w / 2 * frac
        row = y + i
        if 0 <= row < img.shape[0]:
            x0, x1 = int(round(x + w / 2 - half)), int(round(x + w / 2 + half))
            img[row, max(x0, 0):max(min(x1, img.shape[1]), 0)] = hexc(color)


# --- backdrops ---------------------------------------------------------------

def jungle_backdrop():
    rng = np.random.default_rng(11)
    img = canvas(W, H, "#0f2725")
    vgrad(img, 0, 130, ["#0f2725", "#16352e", "#1f4536", "#2c5a40"])
    vgrad(img, 130, H, ["#2c5a40", "#21442f"])
    # Light shafts through the canopy.
    ys, xs = np.mgrid[0:H, 0:W]
    for x0 in (70, 150, 250):
        d = np.abs((xs - x0) - (ys * 0.45))
        shaft = np.clip(1 - d / 9, 0, 1) * np.clip(1 - ys / 150, 0, 1) * 0.35
        blend(img, shaft, "#4f8a5c", levels=4)
    # Far trunks and their foliage.
    for x in rng.choice(np.arange(4, W - 4), 9, replace=False):
        w = int(rng.integers(4, 8))
        rect(img, x, 0, w, H, "#21402f")
        rect(img, x + w - 1, 0, 1, H, "#1c3829")
    far = 112 + noise1d(W, 1, 40) * 26
    paint(img, column_mask(far, False), "#1d3a2c")
    # Mid trunks with lianas between them.
    mids = [18, 104, 196, 282]
    for x in mids:
        w = int(rng.integers(9, 13))
        rect(img, x, 0, w, H, "#15301f")
        rect(img, x + 2, 0, 1, H, "#1b3a27")
        for y in range(10, H, 14):
            rect(img, x + w - 3, y + int(rng.integers(0, 4)), 2, 3, "#112718")
    for a, b in zip(mids, mids[1:]):
        sag = int(rng.integers(30, 60))
        for x in range(a + 10, b):
            t = (x - a - 10) / (b - a - 10)
            y = int(28 + sag * 4 * t * (1 - t))
            img[y, x] = hexc("#24502f")
            if x % 6 == 0:
                rect(img, x - 1, y + 1, 3, 2, "#2f6a3a")
    near = 134 + noise1d(W, 2, 28) * 26
    paint(img, column_mask(near, False), "#142b1e")
    # Bushes on top of the near layer.
    leaf = noise2d(W, H, 3, 5)
    bush = column_mask(near - 6, False) & ~column_mask(near, False) & (leaf > 0.45)
    paint(img, bush, "#1a3826")
    # Canopy hanging from the top edge.
    canopy = 10 + noise1d(W, 4, 18) * 22
    paint(img, column_mask(canopy, True), "#0b1d16")
    lumps = column_mask(canopy + 5, True) & ~column_mask(canopy, True) & (leaf > 0.5)
    paint(img, lumps, "#0b1d16")
    speck = column_mask(canopy, True) & (noise2d(W, H, 5, 2) > 0.72)
    paint(img, speck, "#173a26")
    # Vines.
    for x in rng.choice(np.arange(2, W - 2), 16, replace=False):
        top = int(canopy[x])
        length = int(rng.integers(18, 80))
        for y in range(top, min(top + length, H)):
            img[y, x] = hexc("#1e4a2a")
            if (y + x) % 5 == 0:
                img[y, x + (1 if y % 2 else -1)] = hexc("#2d6a38")
    return img


def cave_backdrop():
    rng = np.random.default_rng(21)
    img = canvas(W, H, "#0e0b16")
    vgrad(img, 0, H, ["#0c0a14", "#151124", "#1a1529", "#120f1d"])
    rock = noise2d(W, H, 22, 14)
    paint(img, (rock > 0.58), "#1b1729")
    paint(img, (rock > 0.68), "#211c31")
    # Distant cavern opening with a cold glow.
    blend(img, radial(200, 92, 70, squash=0.7) * 0.6, "#25304a", levels=5)
    blend(img, radial(200, 92, 40, squash=0.7) * 0.6, "#2d3c58", levels=5)
    # Far stalactites and stalagmites.
    for _ in range(26):
        x, w = int(rng.integers(-4, W)), int(rng.integers(5, 12))
        triangle(img, x, 0, w, int(rng.integers(14, 50)), "#1c1830")
    for _ in range(20):
        x, w = int(rng.integers(-4, W)), int(rng.integers(6, 16))
        h = int(rng.integers(12, 44))
        triangle(img, x, H - h, w, h, "#18142a", down=False)
    floor = 150 + noise1d(W, 23, 30) * 14
    paint(img, column_mask(floor, False), "#110e1c")
    # Crystal clusters with glow.
    for cx, cy, col, glow in [(46, 120, "#5fd3e0", "#1d3a4a"), (132, 40, "#b46ee0", "#2e2148"),
                              (264, 132, "#5fd3e0", "#1d3a4a"), (300, 52, "#b46ee0", "#2e2148")]:
        blend(img, radial(cx, cy, 22) * 0.9, glow, levels=4)
        for dx, h in [(-3, 5), (0, 8), (3, 6), (5, 3)]:
            rect(img, cx + dx, cy - h, 2, h, col)
            rect(img, cx + dx, cy - h, 1, 1, "#e8f6ff")
    # Near stalactites, darkest.
    for x in range(-6, W, 34):
        x += int(rng.integers(0, 20))
        triangle(img, x, 0, int(rng.integers(8, 16)), int(rng.integers(16, 34)), "#09070f")
    rect(img, 0, 0, W, 3, "#09070f")
    return img


def masonry(img, y0, y1, row_h, widths, seed, base, mortar, light, dark, stain=None):
    """Courses of stone blocks with mortar lines and a lit top edge."""
    rng = np.random.default_rng(seed)
    for y in range(y0, y1, row_h):
        x = -int(rng.integers(0, widths[1]))
        while x < W:
            w = int(rng.integers(widths[0], widths[1]))
            c = base if rng.random() > 0.25 else dark
            rect(img, x, y, w, row_h, c)
            rect(img, x, y, w, 1, mortar)
            rect(img, x, y, 1, row_h, mortar)
            rect(img, x + 1, y + 1, w - 1, 1, light)
            if stain and rng.random() < 0.15:
                rect(img, x + 2, y + row_h - 3, max(w - 4, 1), 2, stain)
            x += w


def temple_backdrop():
    rng = np.random.default_rng(31)
    img = canvas(W, H, "#3a2b20")
    masonry(img, 0, H, 14, (22, 40), 32, "#3a2b20", "#24190f", "#46352a", "#33251b", "#2f3a22")
    # Carved frieze.
    rect(img, 0, 20, W, 14, "#2c2017")
    rect(img, 0, 20, W, 1, "#4a382b")
    rect(img, 0, 33, W, 1, "#1d140d")
    glyphs = [
        ["#..#", ".##.", "#..#"], ["####", "#..#", "#.##"], [".##.", "####", ".#.."], ["#.#.", ".#.#", "#.#."],
    ]
    for i, x in enumerate(range(4, W, 10)):
        g = glyphs[i % len(glyphs)]
        for gy, line in enumerate(g):
            for gx, ch in enumerate(line):
                if ch == "#":
                    img[24 + gy * 2:26 + gy * 2, x + gx * 1] = hexc("#4f3c2c")
    # Pillars.
    for px in (30, 150, 270):
        rect(img, px, 34, 22, H - 34, "#4a382a")
        for fx in range(px + 3, px + 20, 4):
            rect(img, fx, 40, 1, H - 52, "#3b2c21")
        rect(img, px + 18, 34, 4, H - 34, "#3a2a1f")
        rect(img, px - 3, 34, 28, 6, "#55412f")
        rect(img, px - 3, 39, 28, 1, "#2a1e15")
        rect(img, px - 3, H - 14, 28, 6, "#4f3c2c")
    # Torches between pillars, with warm light.
    for tx in (96, 216):
        blend(img, radial(tx, 70, 46, squash=0.85) ** 1.5 * 0.5, "#5a3c22")
        blend(img, radial(tx, 70, 20, squash=0.85) * 0.6, "#7a5028")
        rect(img, tx - 2, 72, 4, 8, "#24190f")
        rect(img, tx - 3, 70, 6, 2, "#5a4030")
        rect(img, tx - 2, 64, 4, 6, "#e0902a")
        rect(img, tx - 1, 62, 2, 4, "#f8d060")
    # Overgrowth from the cracked ceiling.
    for x in rng.choice(np.arange(0, W), 12, replace=False):
        length = int(rng.integers(10, 60))
        for y in range(0, length):
            img[y, x] = hexc("#2e4526")
            if y % 4 == 0 and x + 1 < W:
                img[y, x + 1] = hexc("#3d5a2e")
    # Rubble along the floor and shadow toward the bottom.
    ys = np.arange(H)[:, None] * np.ones((1, W))
    blend(img, np.clip((ys - 120) / 60, 0, 1) * 0.6, "#1d140d", levels=4)
    for _ in range(14):
        x = int(rng.integers(0, W))
        rect(img, x, H - 6 - int(rng.integers(0, 4)), int(rng.integers(4, 10)), 6, "#2a1e15")
    return img


def castle_backdrop():
    rng = np.random.default_rng(41)
    img = canvas(W, H, "#1d2030")
    masonry(img, 0, H, 7, (12, 20), 42, "#1d2030", "#131522", "#23273a", "#1a1c2b", "#1b2830")
    # Tall arched windows onto the night sky.
    for wx, moon in ((44, True), (236, False)):
        ww, top, bottom = 34, 26, 120
        sky = np.zeros((bottom - top, ww, 3), dtype=np.uint8)
        vgrad(sky, 0, bottom - top, ["#0b1230", "#162250", "#26346a"])
        r = ww / 2
        for y in range(bottom - top):
            for x in range(ww):
                dy = max(r - y, 0)
                if (x - r + 0.5) ** 2 + dy ** 2 <= r * r:
                    img[top + y, wx + x] = sky[y, x]
        for _ in range(14):
            sx, sy = int(rng.integers(3, ww - 3)), int(rng.integers(6, bottom - top - 4))
            img[top + sy, wx + sx] = hexc("#c8d0f0")
        if moon:
            blend(img, radial(wx + 22, top + 26, 26) * 0.5, "#1f2c5c", levels=3)
            paint(img, radial(wx + 22, top + 26, 8) > 0, "#e8e6c8")
            paint(img, radial(wx + 25, top + 24, 7) > 0, "#162250")
        # Frame and mullions.
        rect(img, wx + ww // 2, top, 2, bottom - top, "#3a3f58")
        rect(img, wx, top + 52, ww, 2, "#3a3f58")
        rect(img, wx - 3, bottom, ww + 6, 4, "#454b66")
        rect(img, wx - 3, bottom + 3, ww + 6, 1, "#16182a")
        # Moonlight spilling onto the wall below.
        ys, xs = np.mgrid[0:H, 0:W]
        spill = ((xs > wx - 4 + (ys - bottom) * 0.3) & (xs < wx + ww + 10 + (ys - bottom) * 0.3)
                 & (ys > bottom + 4)).astype(float) * np.clip(1 - (ys - bottom) / 70, 0, 1) * 0.35
        blend(img, spill, "#323a5a", levels=4)
    # Banners.
    for bx in (126, 178):
        rect(img, bx - 2, 18, 20, 2, "#5a4a2a")
        rect(img, bx, 20, 16, 52, "#6a1a26")
        rect(img, bx, 20, 2, 52, "#80202e")
        rect(img, bx + 14, 20, 2, 52, "#521420")
        rect(img, bx, 22, 16, 1, "#b08a3a")
        rect(img, bx, 66, 16, 1, "#b08a3a")
        triangle(img, bx, 72, 16, 8, "#6a1a26")
        triangle(img, bx + 4, 72, 8, 6, "#1d2030", down=False)
        rect(img, bx + 6, 34, 4, 12, "#b08a3a")
        rect(img, bx + 4, 38, 8, 4, "#b08a3a")
    # Wall torches.
    for tx in (100, 220):
        blend(img, radial(tx, 92, 36, squash=0.9) ** 1.5 * 0.5, "#3e3236")
        blend(img, radial(tx, 92, 16) * 0.6, "#6a4228")
        rect(img, tx - 1, 94, 3, 8, "#3a2a1e")
        rect(img, tx - 2, 92, 5, 2, "#6a6a7a")
        rect(img, tx - 2, 86, 5, 6, "#e0782a")
        rect(img, tx - 1, 84, 3, 4, "#f8c850")
    ys = np.arange(H)[:, None] * np.ones((1, W))
    blend(img, np.clip((ys - 130) / 50, 0, 1) * 0.6, "#12131f", levels=4)
    return img


def mine_backdrop():
    rng = np.random.default_rng(51)
    img = canvas(W, H, "#17120e")
    vgrad(img, 0, H, ["#120e0b", "#1c1611", "#211a13", "#15100c"])
    rock = noise2d(W, H, 52, 10)
    paint(img, rock > 0.6, "#221b15")
    paint(img, rock > 0.7, "#2a2119")
    # Ore veins glinting in the rock.
    vein = noise2d(W, H, 53, 4)
    paint(img, (vein > 0.84) & (rock > 0.6), "#3a2e1c")
    paint(img, (vein > 0.9) & (rock > 0.66), "#6a5226")
    # A far tunnel mouth with lantern light down it.
    blend(img, radial(160, 96, 60, squash=0.75) * 0.7, "#2a1e14", levels=4)
    paint(img, radial(160, 100, 30, squash=0.8) > 0, "#0b0806")
    blend(img, radial(160, 104, 10) * 0.8, "#4a3218", levels=3)
    # Timber supports: two posts and a beam per frame, with a lantern hung on each.
    for fx in (20, 128, 236):
        rect(img, fx, 30, 6, H - 30, "#4a3420")
        rect(img, fx + 58, 30, 6, H - 30, "#4a3420")
        rect(img, fx + 1, 30, 1, H - 30, "#5e4428")
        rect(img, fx + 59, 30, 1, H - 30, "#5e4428")
        rect(img, fx - 4, 24, 72, 7, "#553c24")
        rect(img, fx - 4, 24, 72, 1, "#6e5030")
        rect(img, fx - 4, 30, 72, 1, "#2a1c10")
        for bx in range(fx, fx + 64, 16):
            rect(img, bx + int(rng.integers(0, 10)), 26, 1, 3, "#3a2816")
        lx = fx + 32
        blend(img, radial(lx, 42, 34, squash=0.9) ** 1.5 * 0.55, "#4a3016")
        rect(img, lx, 31, 1, 6, "#2a2018")
        rect(img, lx - 2, 37, 5, 6, "#3a3028")
        rect(img, lx - 1, 38, 3, 4, "#f0b040")
        rect(img, lx, 39, 1, 2, "#fff0a0")
    # Rails along the floor.
    rect(img, 0, H - 22, W, 2, "#3a3a40")
    rect(img, 0, H - 22, W, 1, "#6a6a72")
    for x in range(0, W, 12):
        rect(img, x, H - 20, 8, 3, "#3a2816")
    ys = np.arange(H)[:, None] * np.ones((1, W))
    blend(img, np.clip((ys - 130) / 50, 0, 1) * 0.6, "#0e0a08", levels=4)
    blend(img, np.clip((20 - ys) / 20, 0, 1) * 0.7, "#0e0a08", levels=4)
    return img


def sky_backdrop():
    rng = np.random.default_rng(61)
    img = canvas(W, H, "#1e2a4e")
    vgrad(img, 0, H, ["#18203e", "#222e56", "#34436e", "#4c5680", "#6a6486"])
    # Low sun haze at dusk.
    blend(img, radial(250, 150, 120, squash=0.6) * 0.45, "#8a6a7a", levels=5)
    # Far clouds in bands, lit from below.
    for i, (y, col, lit) in enumerate([(120, "#4a5478", "#7a7a96"), (140, "#5a6084", "#8a8098")]):
        tops = y + noise1d(W, 62 + i, 22) * 18
        paint(img, column_mask(tops, False), col)
        edge = column_mask(tops + 2, False) ^ column_mask(tops, False)
        paint(img, edge, lit)
    # Floating ruins: islands with broken columns.
    for cx, cy, w in ((60, 70, 44), (196, 46, 30), (282, 96, 36)):
        under = np.zeros((H, W), dtype=bool)
        for x in range(cx - w // 2, cx + w // 2):
            if 0 <= x < W:
                t = (x - cx) / (w / 2)
                depth = int((1 - t * t) * w * 0.55 + rng.integers(0, 3))
                under[cy:cy + depth, x] = True
        paint(img, under, "#2e3658")
        rect(img, cx - w // 2, cy, w, 2, "#3e5a4a")
        rect(img, cx - w // 2, cy, w, 1, "#4e7058")
        for k, px in enumerate(range(cx - w // 2 + 4, cx + w // 2 - 4, 10)):
            ph = int(rng.integers(8, 22))
            rect(img, px, cy - ph, 5, ph, "#4e5878")
            rect(img, px + 4, cy - ph, 1, ph, "#3a4262")
            if k % 2 == 0:
                rect(img, px - 1, cy - ph - 2, 7, 2, "#5a6484")
    # Birds.
    for _ in range(5):
        bx, by = int(rng.integers(20, W - 20)), int(rng.integers(14, 60))
        img[by, bx - 2] = img[by, bx + 2] = hexc("#10162c")
        img[by - 1, bx - 1] = img[by - 1, bx + 1] = hexc("#10162c")
    # Keep the playfield calm: soften toward a uniform tone.
    ys = np.arange(H)[:, None] * np.ones((1, W))
    blend(img, np.clip((ys - 150) / 30, 0, 1) * 0.5, "#4a4a66", levels=3)
    return img


def mirror_backdrop():
    rng = np.random.default_rng(71)
    img = canvas(W, H, "#101826")
    vgrad(img, 0, H, ["#0c1220", "#121c30", "#16233a", "#0f1828"])
    # Tall framed mirrors, each showing a faint, wrong reflection of the hall.
    for i, mx in enumerate((22, 98, 174, 250)):
        mw, top, bottom = 48, 24, 138
        rect(img, mx - 3, top - 3, mw + 6, bottom - top + 6, "#5a4a2a")
        rect(img, mx - 3, top - 3, mw + 6, 1, "#b0904a")
        rect(img, mx - 2, top - 2, mw + 4, bottom - top + 4, "#3a2e1a")
        glass = np.zeros((bottom - top, mw, 3), dtype=np.uint8)
        vgrad(glass, 0, bottom - top, ["#1c3048", "#24405a", "#1a2c44"])
        img[top:bottom, mx:mx + mw] = glass
        # Diagonal glints.
        ys, xs = np.mgrid[0:bottom - top, 0:mw]
        for g in (10, 26):
            band = (np.abs(xs + ys * 0.6 - g - i * 7) < 2)
            sub = img[top:bottom, mx:mx + mw]
            sub[band] = hexc("#3e6080")
        # A silhouette that should be the player's, facing the wrong way.
        sx = mx + (12 if i % 2 else mw - 18)
        rect(img, sx, bottom - 22, 6, 16, "#142236")
        rect(img, sx + 1, bottom - 28, 4, 5, "#142236")
        rect(img, mx - 4, bottom + 3, mw + 8, 3, "#6a5630")
    # Crystal growth along the floor and ceiling.
    for _ in range(18):
        x, w = int(rng.integers(-4, W)), int(rng.integers(5, 11))
        h = int(rng.integers(8, 26))
        triangle(img, x, H - h, w, h, "#2a4a6a", down=False)
        triangle(img, x + 1, H - h + 3, w - 3, h - 3, "#3a6a8a", down=False)
    for _ in range(14):
        x, w = int(rng.integers(-4, W)), int(rng.integers(5, 10))
        triangle(img, x, 0, w, int(rng.integers(8, 20)), "#1e3450")
    ys = np.arange(H)[:, None] * np.ones((1, W))
    blend(img, np.clip((ys - 140) / 40, 0, 1) * 0.5, "#0a101c", levels=4)
    return img


def spire_backdrop():
    rng = np.random.default_rng(81)
    img = canvas(W, H, "#120c22")
    vgrad(img, 0, H, ["#1e1036", "#150c28", "#0e0a1c", "#150c28", "#1e1036"])
    # Stars, some of them falling the wrong way.
    for _ in range(70):
        x, y = int(rng.integers(0, W)), int(rng.integers(0, H))
        img[y, x] = hexc("#8a7ab8" if rng.random() < 0.7 else "#e0d8ff")
    for _ in range(4):
        x, y = int(rng.integers(10, W - 10)), int(rng.integers(30, H - 30))
        for k in range(6):
            img[y - k, x] = hexc("#5a4a8a")
        img[y, x] = hexc("#e0d8ff")
    # A tower hanging from the top and its mirror image rising from below.
    for flip in (False, True):
        tw, base = 54, 60
        cx = 160
        for y in range(base):
            row = y if not flip else H - 1 - y
            half = tw // 2 - int(y * 0.12)
            rect(img, cx - half, row, half * 2, 1, "#24183e")
            rect(img, cx - half, row, 2, 1, "#2e2050")
        for wy in range(10, base - 14, 16):
            row = wy if not flip else H - 1 - wy - 6
            rect(img, cx - 3, row, 6, 6, "#e0a0ff" if (wy // 16) % 2 == 0 else "#3a2860")
        if flip:
            triangle(img, cx - 12, H - base - 18, 24, 18, "#24183e", down=False)
        else:
            triangle(img, cx - 12, base, 24, 18, "#24183e")
    # Floating chunks of rock drifting both ways.
    for _ in range(9):
        x, y = int(rng.integers(0, W - 20)), int(rng.integers(40, H - 40))
        w = int(rng.integers(8, 20))
        rect(img, x, y, w, 4, "#2a1e48")
        rect(img, x, y, w, 1, "#4a3a78")
        triangle(img, x + 1, y + 4, w - 2, int(rng.integers(3, 8)), "#20163a")
    blend(img, radial(160, 90, 60, squash=0.5) * 0.25, "#2a1846", levels=3)
    return img


def dunes_backdrop():
    rng = np.random.default_rng(91)
    img = canvas(W, H, "#2a1a2e")
    vgrad(img, 0, H, ["#2a1a34", "#4a2a40", "#7a4040", "#a8603e", "#c8844a"])
    # A huge low sun, banded by heat haze.
    sun = radial(222, 108, 46)
    blend(img, radial(222, 108, 110, squash=0.6) * 0.5, "#d8904a", levels=4)
    paint(img, sun > 0, "#f0b860")
    paint(img, sun > 0.35, "#f8d880")
    for y in (96, 104, 111, 117):
        rect(img, 176, y, 92, 1, "#c8844a")
    # A far ruined pyramid and the tops of buried columns.
    triangle(img, 52, 74, 76, 40, "#6a3a3e", down=False)
    triangle(img, 58, 80, 52, 34, "#7a4846", down=False)
    rect(img, 76, 92, 6, 8, "#4a2830")
    for x in (150, 160, 290):
        h = int(rng.integers(10, 22))
        rect(img, x, 118 - h, 5, h, "#7a4a44")
        rect(img, x - 1, 118 - h, 7, 2, "#8a5a50")
    # Dunes, far to near, each with a lit crest.
    for i, (base, amp, col, lit) in enumerate([(112, 16, "#8a5040", "#b06a4a"), (128, 18, "#9a5a3e", "#c87e50"),
                                               (146, 16, "#7a4432", "#a86444")]):
        crest = base + noise1d(W, 92 + i, 60, 2) * amp
        paint(img, column_mask(crest, False), col)
        edge = column_mask(crest + 1, False) ^ column_mask(crest, False)
        paint(img, edge, lit)
    # Sand pouring down into a sinkhole in the middle distance.
    blend(img, radial(120, 136, 26, squash=0.25) * 0.9, "#3a2024", levels=3)
    for x in range(110, 131, 4):
        for y in range(132, 140):
            if (x + y) % 3 == 0:
                img[y, x] = hexc("#c88a5a")
    ys = np.arange(H)[:, None] * np.ones((1, W))
    blend(img, np.clip((ys - 150) / 30, 0, 1) * 0.5, "#4a2a2a", levels=3)
    return img


def frost_backdrop():
    rng = np.random.default_rng(101)
    img = canvas(W, H, "#0c1a2a")
    vgrad(img, 0, H, ["#081420", "#0e2234", "#143048", "#10283c"])
    ice = noise2d(W, H, 102, 16)
    paint(img, ice > 0.6, "#12283e")
    paint(img, ice > 0.7, "#183450")
    # A frozen waterfall glowing from inside.
    blend(img, radial(160, 90, 70, squash=1.6) * 0.5, "#1e4a6a", levels=4)
    for x in range(140, 181):
        top = 0
        bottom = 150 - int(abs(x - 160) * 0.6)
        shade = "#4a8ab0" if (x // 3) % 2 else "#3a7aa0"
        rect(img, x, top, 1, bottom, shade)
    for x in range(142, 179, 6):
        rect(img, x, 10, 1, 120, "#8ac8e8")
    rect(img, 136, 150, 50, 6, "#a8d8f0")
    # Ice crystals jutting from both sides, pale and sharp.
    for _ in range(18):
        x, w = int(rng.integers(-4, W)), int(rng.integers(5, 12))
        h = int(rng.integers(10, 34))
        triangle(img, x, H - h, w, h, "#1e3e5a", down=False)
        triangle(img, x + 2, H - h + 4, max(w - 4, 1), h - 4, "#2a5070", down=False)
    for x in range(-6, W, 18):
        x += int(rng.integers(0, 10))
        h = int(rng.integers(10, 40))
        triangle(img, x, 0, int(rng.integers(5, 10)), h, "#2a4e6a")
        triangle(img, x + 1, 0, 3, h - 6, "#4a7a98")
    rect(img, 0, 0, W, 3, "#08121e")
    ys = np.arange(H)[:, None] * np.ones((1, W))
    blend(img, np.clip((ys - 140) / 40, 0, 1) * 0.5, "#081420", levels=4)
    return img


def gear(img, cx, cy, r, teeth, col, hub):
    """A cog: a ring with square teeth and a hub with spokes."""
    ys, xs = np.mgrid[0:H, 0:W]
    d = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2)
    a = np.arctan2(ys - cy, xs - cx)
    tooth = (np.cos(a * teeth) > 0.2) & (d < r + 4) & (d >= r)
    ring = (d < r) & (d >= r - 4)
    spokes = (d < r - 4) & (np.abs(np.sin(a * 3)) < 0.18)
    paint(img, tooth | ring | spokes, col)
    paint(img, d < r * 0.25, hub)


def clockwork_backdrop():
    img = canvas(W, H, "#1a140e")
    vgrad(img, 0, H, ["#140f0a", "#1e170f", "#261c12", "#18120c"])
    # Riveted wall plates.
    for y in range(0, H, 30):
        rect(img, 0, y, W, 1, "#2a2016")
        for x in range((y // 30) % 2 * 20, W, 40):
            rect(img, x, y, 1, 30, "#2a2016")
            img[min(y + 3, H - 1), min(x + 3, W - 1)] = hexc("#4a3a24")
    # Big slow gears behind everything, warm light on them.
    blend(img, radial(160, 80, 120, squash=0.7) * 0.35, "#4a3018", levels=4)
    gear(img, 70, 70, 40, 10, "#3a2c1a", "#5a4424")
    gear(img, 140, 118, 26, 8, "#44321c", "#6a5028")
    gear(img, 258, 60, 46, 12, "#3a2c1a", "#5a4424")
    gear(img, 206, 140, 18, 6, "#4a3820", "#7a5c2c")
    # Pipes along the top with gauges.
    rect(img, 0, 16, W, 5, "#5a4426")
    rect(img, 0, 16, W, 1, "#8a6a3a")
    for x in (40, 180, 300):
        rect(img, x, 10, 4, 12, "#6a5030")
        blend(img, radial(x + 2, 28, 5) * 1.5, "#c8a050", levels=2)
        rect(img, x + 2, 26, 1, 3, "#2a1a10")
    ys = np.arange(H)[:, None] * np.ones((1, W))
    blend(img, np.clip((ys - 130) / 50, 0, 1) * 0.6, "#0e0a06", levels=4)
    return img


def observatory_backdrop():
    rng = np.random.default_rng(121)
    img = canvas(W, H, "#0a0c1e")
    vgrad(img, 0, H, ["#06081a", "#0c1028", "#141836", "#1a1c3a"])
    # Stars and a band of galaxy dust.
    band = np.clip(1 - np.abs(np.mgrid[0:H, 0:W][0] - np.mgrid[0:H, 0:W][1] * 0.35 - 20) / 30, 0, 1)
    blend(img, band * noise2d(W, H, 122, 8) * 0.8, "#2a2a5a", levels=4)
    for _ in range(110):
        x, y = int(rng.integers(0, W)), int(rng.integers(0, H - 30))
        img[y, x] = hexc("#e8e8ff" if rng.random() < 0.3 else "#6a70a8")
    # The moon, close and pitted.
    moon = radial(250, 52, 26)
    blend(img, radial(250, 52, 50) * 0.5, "#2a3060", levels=4)
    paint(img, moon > 0, "#d8d8e8")
    paint(img, (moon > 0) & (noise2d(W, H, 123, 4) > 0.62), "#a8a8c0")
    paint(img, (moon > 0) & (radial(260, 56, 26) < 0.15), "#b0b0c8")
    # The open dome's ribs framing the sky, and a great telescope.
    ys, xs = np.mgrid[0:H, 0:W]
    for k in range(-3, 4):
        rib = np.abs((xs - 160) - k * 52 - (ys - 180) * k * 0.25) < 1.5
        paint(img, rib & (ys < 150), "#24223e")
    for i in range(70):
        x, y = 60 + i, 150 - int(i * 0.9)
        rect(img, x, y, 10, 8, "#3a3a5a")
        rect(img, x, y, 10, 1, "#5a5a80")
    rect(img, 70, 140, 30, 12, "#2a2a44")
    rect(img, 76, 152, 6, 28, "#2a2a44")
    rect(img, 0, H - 26, W, 26, "#14142a")
    rect(img, 0, H - 26, W, 1, "#2a2a4a")
    return img


def warp_backdrop():
    rng = np.random.default_rng(131)
    img = canvas(W, H, "#120a22")
    vgrad(img, 0, H, ["#0c0618", "#160c2a", "#20123a", "#1a0e2e"])
    # A rift in the sky, torn and glowing violet.
    blend(img, radial(200, 60, 120, squash=0.6) * 0.45, "#3a1a5a", levels=4)
    rift = radial(200, 60, 40, squash=0.35)
    blend(img, rift * 1.2, "#6a3ab0", levels=3)
    paint(img, rift > 0.55, "#b088f0")
    paint(img, rift > 0.8, "#e8d8ff")
    for _ in range(70):
        x, y = int(rng.integers(0, W)), int(rng.integers(0, 120))
        img[y, x] = hexc("#8a6ac8" if rng.random() < 0.5 else "#4a3478")
    # A broken stone ring gate on a hill, and fallen pillars.
    ys, xs = np.mgrid[0:H, 0:W]
    d = np.sqrt((xs - 90) ** 2 + ((ys - 100) * 1.1) ** 2)
    ring = (d < 34) & (d > 26) & ~((xs > 104) & (ys < 84))
    paint(img, ring, "#3a3050")
    paint(img, ring & (d > 32), "#4a4064")
    blend(img, np.clip(1 - d / 26, 0, 1) * 0.6, "#4a2a7a", levels=3)
    for x, h in ((20, 40), (156, 28), (282, 46), (300, 22)):
        rect(img, x, 136 - h, 9, h, "#2e2644")
        rect(img, x, 136 - h, 9, 2, "#443a60")
        rect(img, x - 1, 136 - h - 3, 11, 3, "#3a3254")
    hill = 132 + noise1d(W, 132, 50, 2) * 12
    paint(img, column_mask(hill, False), "#1a1428")
    edge = column_mask(hill + 1, False) ^ column_mask(hill, False)
    paint(img, edge, "#3a2c58")
    ys = np.arange(H)[:, None] * np.ones((1, W))
    blend(img, np.clip((ys - 140) / 40, 0, 1) * 0.5, "#0c0818", levels=4)
    return img


def labyrinth_backdrop():
    rng = np.random.default_rng(141)
    img = canvas(W, H, "#0a1a1c")
    vgrad(img, 0, H, ["#081416", "#0c1e22", "#10282c", "#0c1e20"])
    # Hedge-stone walls of a maze stepping away into teal fog, one layer per depth.
    for depth, (col, lit, top, step) in enumerate([("#0e2628", "#163436", 40, 34), ("#102c2e", "#1a3c40", 64, 46),
                                                   ("#12302f", "#1e4444", 92, 62)]):
        x = -int(rng.integers(0, step))
        while x < W:
            w = int(rng.integers(step // 2, step))
            h = int(rng.integers(18, 34)) + depth * 6
            rect(img, x, top + 40 - h, w, h + 80, col)
            rect(img, x, top + 40 - h, w, 1, lit)
            # Doorways, dark, some with a faint glow of a portal in them.
            if rng.random() < 0.5 and w > 10:
                dx = x + w // 2 - 3
                rect(img, dx, top + 40 - h + 6, 6, h - 6, "#081214")
                if rng.random() < 0.5:
                    blend(img, radial(dx + 3, top + 40 - h // 2, 8, squash=1.6) * 0.8, "#2a8a8a", levels=3)
            x += w + int(rng.integers(4, 14))
        blend(img, np.ones((H, W)) * 0.25, "#0c2224", levels=2)
    ys = np.arange(H)[:, None] * np.ones((1, W))
    blend(img, np.clip((ys - 120) / 60, 0, 1) * 0.6, "#081416", levels=4)
    return img


def hoard_backdrop():
    rng = np.random.default_rng(151)
    img = canvas(W, H, "#1a120a")
    vgrad(img, 0, H, ["#120c08", "#1e1408", "#2a1c0c", "#1e140a"])
    rock = noise2d(W, H, 152, 18)
    paint(img, rock > 0.62, "#241a10")
    paint(img, rock > 0.72, "#2c2014")
    # Mountains of gold catching the light of a lantern, coins glinting.
    blend(img, radial(170, 120, 140, squash=0.5) * 0.5, "#4a3010", levels=4)
    for cx, cy, r in ((70, 160, 70), (180, 170, 90), (290, 158, 60)):
        pile = 1 - np.abs(np.arange(W) - cx) / r
        top = cy - np.clip(pile, 0, 1) ** 0.7 * r * 0.55
        paint(img, column_mask(top, False), "#6a4a18")
        paint(img, column_mask(top + 3, False), "#5a3c14")
        edge = column_mask(top + 1, False) ^ column_mask(top, False)
        paint(img, edge, "#b08a30")
    for _ in range(60):
        x, y = int(rng.integers(0, W)), int(rng.integers(110, H))
        if (img[y, x] != hexc("#1e140a")).any():
            img[y, x] = hexc("#e8c050" if rng.random() < 0.4 else "#a07a28")
    # A chest and a crown on the big pile, and a lantern hanging from a rope.
    rect(img, 166, 108, 20, 12, "#5a3418")
    rect(img, 166, 108, 20, 3, "#7a4a24")
    rect(img, 175, 110, 3, 4, "#d8b040")
    rect(img, 240, 0, 1, 52, "#3a2a18")
    blend(img, radial(240, 58, 18) * 0.9, "#c88a30", levels=3)
    rect(img, 237, 52, 7, 9, "#d8a040")
    ys = np.arange(H)[:, None] * np.ones((1, W))
    blend(img, np.clip((ys - 150) / 30, 0, 1) * 0.5, "#120c08", levels=3)
    return img


def crypt_backdrop():
    rng = np.random.default_rng(161)
    img = canvas(W, H, "#120a0e")
    vgrad(img, 0, H, ["#0e080a", "#180c10", "#201016", "#160a0e"])
    masonry(img, 0, H, 12, (20, 30), 162, "#1e1216", "#140a0e", "#261a1e", "#160c10")
    # Burial niches with skulls in them, rows of them.
    for row, y in enumerate((24, 64, 104)):
        for x in range(8 + row * 12, W, 44):
            rect(img, x, y, 22, 14, "#0a0608")
            rect(img, x, y, 22, 1, "#2a1a1e")
            if rng.random() < 0.7:
                sx = x + int(rng.integers(3, 12))
                rect(img, sx, y + 7, 6, 5, "#5a5048")
                rect(img, sx + 1, y + 9, 1, 1, "#0a0608")
                rect(img, sx + 4, y + 9, 1, 1, "#0a0608")
                rect(img, sx + 1, y + 12, 4, 2, "#4a4038")
    # A red glow from below, as if something waits down there.
    ys = np.arange(H)[:, None] * np.ones((1, W))
    blend(img, np.clip((ys - 100) / 80, 0, 1) * 0.55, "#5a1018", levels=4)
    blend(img, radial(160, 190, 120, squash=0.4) * 0.6, "#8a1a1a", levels=3)
    for x in (50, 270):
        rect(img, x, 118, 3, 10, "#6a5a40")
        blend(img, radial(x + 1, 114, 10) * 1.2, "#e07030", levels=3)
        rect(img, x, 112, 3, 4, "#ffd080")
    return img


def manor_backdrop():
    rng = np.random.default_rng(171)
    img = canvas(W, H, "#14101c")
    vgrad(img, 0, H, ["#100c18", "#16121e", "#1c1624", "#14101a"])
    # Faded striped wallpaper with a damask dot.
    for x in range(0, W, 12):
        rect(img, x, 0, 6, H, "#1a1524")
        for y in range(6 + (x // 12) % 2 * 10, H, 20):
            img[y, min(x + 9, W - 1)] = hexc("#2a2236")
    # Tall windows with the moon outside, and a staircase climbing into the dark.
    for wx in (40, 230):
        rect(img, wx - 2, 20, 44, 74, "#2a2030")
        rect(img, wx, 22, 40, 70, "#1e2a44")
        blend(img, radial(wx + 26, 40, 30) * 0.5, "#4a5a7a", levels=3)
        moon = radial(wx + 26, 40, 9)
        paint(img, moon > 0, "#c8d0e0")
        rect(img, wx + 19, 22, 2, 70, "#2a2030")
        rect(img, wx, 55, 40, 2, "#2a2030")
        # Torn curtains.
        rect(img, wx - 6, 16, 8, 84, "#3a1424")
        rect(img, wx + 38, 16, 8, 60, "#3a1424")
        triangle(img, wx + 38, 76, 8, 16, "#3a1424")
    # Portraits whose eyes follow you.
    for px in (120, 172):
        rect(img, px, 34, 22, 28, "#5a4020")
        rect(img, px + 2, 36, 18, 24, "#241c20")
        rect(img, px + 7, 40, 8, 9, "#4a3a34")
        img[44, px + 9] = img[44, px + 13] = hexc("#e04040")
    for i in range(14):
        rect(img, 300 - i * 8, 100 + i * 5, 30, 5, "#221a20")
        rect(img, 300 - i * 8, 100 + i * 5, 30, 1, "#2e2428")
    # Cobwebs in the top corners: threads fanning out, joined by sagging rings.
    for cx in (0, W - 1):
        sx = 1 if cx == 0 else -1
        for i in range(18):
            img[i, cx + sx * i] = hexc("#34303e")
            img[min(i // 2, H - 1), cx + sx * i] = hexc("#34303e")
            img[i, cx + sx * (i // 2)] = hexc("#34303e")
        for r in (6, 12):
            for i in range(r):
                img[r - i // 2 - (i * (r - i)) // (r * 2), cx + sx * i] = hexc("#2c2836")
    ys = np.arange(H)[:, None] * np.ones((1, W))
    blend(img, np.clip((ys - 130) / 50, 0, 1) * 0.6, "#0c0a10", levels=4)
    return img


# --- tiles ------------------------------------------------------------------
# Each painter draws one 8x8 tile from a variant index. Top tiles sit on the top
# row of every block; fill tiles cover the rest.

def speckle(tile, rng, color, count):
    for _ in range(count):
        tile[int(rng.integers(0, T)), int(rng.integers(0, T))] = hexc(color)


def jungle_tile(top, v):
    rng = np.random.default_rng(100 + v + top * 10)
    t = canvas(T, T, "#5a3a24")
    speckle(t, rng, "#43291a", 6)
    speckle(t, rng, "#6e4a30", 3)
    if top:
        edge = [2, 3, 2, 4, 3, 2, 3, 2]
        for x in range(T):
            e = edge[(x + v * 3) % T]
            t[0:e, x] = hexc("#3f8a35")
            t[e, x] = hexc("#2c5e27")
        t[0, :] = hexc("#6cc04e")
        t[0, (v * 3 + 1) % T] = hexc("#9ee070")
    else:
        if v == 1:
            t[2:7, 5] = hexc("#3a2416")
            t[5, 4:7] = hexc("#3a2416")
        if v == 2:
            t[3:5, 1:4] = hexc("#7a6250")
            t[3, 1:4] = hexc("#958070")
    return t


def cave_tile(top, v):
    rng = np.random.default_rng(200 + v + top * 10)
    t = canvas(T, T, "#463d62")
    speckle(t, rng, "#3a3254", 8)
    speckle(t, rng, "#544a72", 3)
    if top:
        t[0, :] = hexc("#8a7eb4")
        t[1, :] = hexc("#625688")
        t[1, (v * 3) % T] = hexc("#8a7eb4")
    elif v == 1:
        for i in range(5):
            t[1 + i, 2 + (i % 2)] = hexc("#2a2440")
    elif v == 3:
        t[4:6, 3:6] = hexc("#5a5080")
        t[4, 3:5] = hexc("#6a6090")
    return t


def brick_tile(top, v, base, mortar, light, dark, moss, accent):
    rng = np.random.default_rng(300 + v + top * 10 + int(hexc(base).sum()))
    t = canvas(T, T, base)
    t[0, :] = hexc(mortar)
    t[4, :] = hexc(mortar)
    t[0:4, 7] = hexc(mortar)
    t[4:8, 3] = hexc(mortar)
    t[1, 0:7] = hexc(light)
    t[5, 0:3] = hexc(light)
    t[5, 4:8] = hexc(light)
    speckle(t, rng, dark, 3)
    if top:
        t[0, :] = hexc(accent)
        t[1, :] = hexc(light)
        if v == 2 and moss:
            t[0:2, 1:5] = hexc(moss)
            t[2, 2:4] = hexc(moss)
    elif v == 1 and moss:
        t[6:8, 4:7] = hexc(moss)
    elif v == 3:
        t[2, 1:4] = hexc(dark)
        t[3, 3] = hexc(dark)
    return t


def temple_tile(top, v):
    return brick_tile(top, v, "#a07a4c", "#6a4c2e", "#bc9460", "#8a6640", "#5a7a3a", "#d8b078")


def castle_tile(top, v):
    return brick_tile(top, v, "#767c94", "#474b60", "#8e94ac", "#666c84", "#5a7a52", "#b4b9cc")


def mine_tile(top, v):
    rng = np.random.default_rng(500 + v + top * 10)
    t = canvas(T, T, "#5a4a3a")
    speckle(t, rng, "#4a3c2e", 8)
    speckle(t, rng, "#6c5a46", 3)
    if top:
        # A timber plank laid over the rock.
        t[0:3, :] = hexc("#8a6038")
        t[0, :] = hexc("#b08050")
        t[2, :] = hexc("#5a3a20")
        t[1, (v * 3 + 2) % T] = hexc("#5a3a20")
    elif v == 1:
        t[4, 2:4] = hexc("#8a7038")
        t[3, 2] = hexc("#b09048")
    elif v == 2:
        t[5:7, 4:7] = hexc("#3c3024")
    return t


def sky_tile(top, v):
    rng = np.random.default_rng(600 + v + top * 10)
    t = brick_tile(top, v, "#c8c4b8", "#8e8a80", "#e0dcd0", "#a8a498", None, "#f0ece0")
    if top:
        t[0, :] = hexc("#7ac060")
        t[1, :] = hexc("#5a9a48")
        for x in range(T):
            if rng.random() < 0.4:
                t[2, x] = hexc("#5a9a48")
    return t


def mirror_tile(top, v):
    rng = np.random.default_rng(700 + v + top * 10)
    t = canvas(T, T, "#3a6a9a")
    speckle(t, rng, "#2e5a88", 6)
    for i in range(T):
        t[i, (i + v * 2) % T] = hexc("#5a8aba")
    if top:
        t[0, :] = hexc("#c8f0ff")
        t[1, :] = hexc("#8ac8f0")
    elif v == 1:
        t[2:6, 3] = hexc("#a0e0ff")
        t[3:5, 2:5] = hexc("#a0e0ff")
    return t


def spire_tile(top, v):
    rng = np.random.default_rng(800 + v + top * 10)
    t = canvas(T, T, "#3a2a5a")
    speckle(t, rng, "#2e2048", 7)
    speckle(t, rng, "#4a3870", 3)
    # Lit on both faces: in these rooms the underside is often the floor.
    if top:
        t[0, :] = hexc("#8a6ac8")
        t[1, :] = hexc("#5a4490")
    if v == 1:
        t[3:5, 3:5] = hexc("#c890ff")
    elif v == 3:
        t[6, 1:6] = hexc("#251a3c")
    return t


def dunes_tile(top, v):
    rng = np.random.default_rng(900 + v + top * 10)
    t = brick_tile(top, v, "#c08a54", "#8a5e36", "#d8a46a", "#a87444", None, "#e8c084")
    if top:
        # Loose sand drifted over the stone.
        t[0:2, :] = hexc("#e8c890")
        t[0, :] = hexc("#f8e0a8")
        for x in range(T):
            if rng.random() < 0.5:
                t[2, x] = hexc("#d8b47a")
    return t


def frost_tile(top, v):
    rng = np.random.default_rng(1000 + v + top * 10)
    t = canvas(T, T, "#5a8ab8")
    speckle(t, rng, "#4a7aa8", 6)
    speckle(t, rng, "#8ab8e0", 2)
    t[(v * 2) % T, 1:4] = hexc("#a8d8f8")
    if top:
        # A cap of snow.
        t[0:2, :] = hexc("#f0f8ff")
        t[2, :] = hexc("#c8e0f4")
        t[2, (v * 3) % T] = hexc("#f0f8ff")
    elif v == 1:
        for i in range(5):
            t[1 + i, 5 - (i % 2)] = hexc("#3a6a98")
    return t


def clockwork_tile(top, v):
    rng = np.random.default_rng(1100 + v + top * 10)
    t = canvas(T, T, "#7a5a30")
    speckle(t, rng, "#6a4c28", 6)
    speckle(t, rng, "#8a6a3c", 3)
    t[:, 7] = hexc("#4a3418")
    t[7, :] = hexc("#4a3418")
    t[1, 1] = t[1, 5] = t[5, 1] = t[5, 5] = hexc("#d8b060")
    if top:
        t[0, :] = hexc("#e8c070")
        t[1, :] = hexc("#b08848")
        t[1, 1] = t[1, 5] = hexc("#f8e0a0")
    elif v == 2:
        t[3, 2:5] = hexc("#3a2a14")
    return t


def observatory_tile(top, v):
    rng = np.random.default_rng(1200 + v + top * 10)
    t = canvas(T, T, "#5a5a7a")
    speckle(t, rng, "#4a4a6a", 6)
    speckle(t, rng, "#6a6a8e", 3)
    # Marble veins, and the odd brass star set into the stone.
    for i in range(T):
        if (i + v) % 3 == 0:
            t[i, (i * 2 + v) % T] = hexc("#7a7aa0")
    if top:
        t[0, :] = hexc("#b8b8d8")
        t[1, :] = hexc("#8a8aac")
    if v == 1:
        t[4, 3:6] = hexc("#e0c060")
        t[3:6, 4] = hexc("#e0c060")
    return t


def warp_tile(top, v):
    rng = np.random.default_rng(1300 + v + top * 10)
    t = canvas(T, T, "#3a3250")
    speckle(t, rng, "#30283f", 6)
    speckle(t, rng, "#463c60", 3)
    t[:, 7] = hexc("#2a2238")
    t[7, :] = hexc("#2a2238")
    if top:
        t[0, :] = hexc("#7a6aa0")
        t[1, :] = hexc("#544878")
    if v == 1:
        # A glowing rune.
        t[3:6, 3] = hexc("#b088f0")
        t[3, 3:6] = hexc("#b088f0")
        t[5, 5] = hexc("#b088f0")
    return t


def labyrinth_tile(top, v):
    rng = np.random.default_rng(1400 + v + top * 10)
    t = canvas(T, T, "#2a5050")
    speckle(t, rng, "#224444", 6)
    speckle(t, rng, "#346060", 3)
    t[0:4, 7] = hexc("#183a3a")
    t[4:8, 3] = hexc("#183a3a")
    t[3, :] = hexc("#183a3a")
    t[7, :] = hexc("#183a3a")
    if top:
        # Ivy along the top edge.
        t[0, :] = hexc("#4a8a4a")
        t[1, (v * 2) % T:(v * 2) % T + 3] = hexc("#3a7040")
    elif v == 2:
        t[5, 0:3] = hexc("#4a8a4a")
    return t


def hoard_tile(top, v):
    rng = np.random.default_rng(1500 + v + top * 10)
    t = canvas(T, T, "#5a4430")
    speckle(t, rng, "#4a3626", 6)
    speckle(t, rng, "#6a5238", 3)
    if top:
        # Coins spilled along the top.
        t[0:2, :] = hexc("#c89a30")
        t[0, (v * 3) % T] = hexc("#fff0a0")
        t[0, (v * 3 + 4) % T] = hexc("#f8d050")
        t[2, :] = hexc("#7a5a20")
    elif v == 1:
        t[3:5, 2:4] = hexc("#e8c050")
        t[3, 2] = hexc("#fff0a0")
    elif v == 3:
        t[5, 4:7] = hexc("#c89a30")
    return t


def crypt_tile(top, v):
    t = brick_tile(top, v, "#5a4a48", "#2e2224", "#6e5e5a", "#4a3c3a", None, "#8a7a72")
    if v == 1 and not top:
        # A skull set into the wall.
        t[2:5, 2:6] = hexc("#c8beb0")
        t[3, 3] = t[3, 5] = hexc("#2e2224")
        t[5, 3:5] = hexc("#a89e90")
    return t


def manor_tile(top, v):
    rng = np.random.default_rng(1700 + v + top * 10)
    t = canvas(T, T, "#4a3226")
    speckle(t, rng, "#3e2a20", 5)
    # Floorboards: long planks with dark seams.
    t[3, :] = hexc("#2e1e16")
    t[7, :] = hexc("#2e1e16")
    t[0:3, (v * 3 + 2) % T] = hexc("#2e1e16")
    t[4:7, (v * 3 + 6) % T] = hexc("#2e1e16")
    t[1, 0:5] = hexc("#5a3e2e")
    if top:
        t[0, :] = hexc("#7a5a42")
        t[1, :] = hexc("#5e4232")
    elif v == 2:
        t[5, 2] = hexc("#6a6a74")
    return t


# --- doors ------------------------------------------------------------------
# Each world's exit door, 12x16 like the goal's hit box, drawn as pixel rows.
# "." is see-through and "#" is the shaded inside of the frame. Every door keeps
# the same green glow in its opening ("g", with a bright "G" stripe) so the way
# out reads as the way out in any world, and decoy goals draw the same picture,
# so they still pass for the real thing.

DOOR_W, DOOR_H = 12, 16
GLOW = {"g": "#4ad97a", "G": "#9af0b4"}

DOORS = {
    # A log frame wrapped in vines.
    "jungle": ({"#": "#2c1a10", "L": "#3f8a35", "l": "#6cc04e", "W": "#6e4a30", "w": "#43291a"}, [
        ".lLl..LllL..",
        "lLLLLlLLLLLl",
        "WWWLWWWWLWWW",
        "WwwwwwwwwwwW",
        "Ww#gggggg#wW",
        "Lw#ggGGgg#wW",
        "WL#ggGGgg#wW",
        "Ww#ggGGgg#LW",
        "Ww#ggGGgg#wL",
        "Lw#ggGGgg#wW",
        "Ww#ggGGgg#wW",
        "WL#ggGGgg#wW",
        "Ww#ggGGgg#wW",
        "Ww#ggGGgg#LW",
        "lw#ggGGgg#wl",
        "lL#ggGGgg#Ll",
    ]),
    # A rough stone arch with crystals growing out of it.
    "cave": ({"#": "#2a2440", "S": "#625688", "s": "#3a3254", "H": "#8a7eb4", "C": "#c890ff", "c": "#f0d0ff"}, [
        "...SSHHSS...",
        "..SHSSSSSHS.",
        ".SSssCcssSS.",
        "SSsggggggsSS",
        "Ss#ggGGgg#sS",
        "Cs#ggGGgg#sS",
        "Sc#ggGGgg#sS",
        "Ss#ggGGgg#sH",
        "Hs#ggGGgg#sS",
        "Ss#ggGGgg#cS",
        "Ss#ggGGgg#sC",
        "Ss#ggGGgg#sS",
        "Cs#ggGGgg#sS",
        "Sc#ggGGgg#sS",
        "SS#ggGGgg#SS",
        "CS#ggGGgg#SC",
    ]),
    # Sandstone pillars under a lintel with a carved eye.
    "temple": ({"#": "#6a4c2e", "T": "#bc9460", "t": "#8a6640", "A": "#d8b078", "E": "#3ab0a0"}, [
        "AAAAAAAAAAAA",
        "TTTtAEEAtTTT",
        "tttttttttttt",
        "TA#gggggg#AT",
        "TA#ggGGgg#AT",
        "tA#ggGGgg#At",
        "TA#ggGGgg#AT",
        "tA#ggGGgg#At",
        "TA#ggGGgg#AT",
        "tA#ggGGgg#At",
        "TA#ggGGgg#AT",
        "tA#ggGGgg#At",
        "TA#ggGGgg#AT",
        "tA#ggGGgg#At",
        "TT#ggGGgg#TT",
        "AA#ggGGgg#AA",
    ]),
    # A stone arch with its portcullis raised.
    "castle": ({"#": "#3a3e50", "K": "#8e94ac", "k": "#666c84", "M": "#474b60", "B": "#2a2a33"}, [
        "...KKKKKK...",
        ".KKkKKKKkKK.",
        "KkBBBBBBBBkK",
        "KKBgBggBgBKK",
        "Kk#ggGGgg#kK",
        "kM#ggGGgg#Mk",
        "Kk#ggGGgg#kK",
        "kM#ggGGgg#Mk",
        "Kk#ggGGgg#kK",
        "kM#ggGGgg#Mk",
        "Kk#ggGGgg#kK",
        "kM#ggGGgg#Mk",
        "Kk#ggGGgg#kK",
        "kM#ggGGgg#Mk",
        "Kk#ggGGgg#kK",
        "KK#ggGGgg#KK",
    ]),
    # A timbered shaft mouth with a lantern on a hook.
    "mine": ({"#": "#3a2414", "P": "#8a6038", "p": "#b08050", "d": "#5a3a20", "O": "#ffb040", "o": "#c07020"}, [
        "pppppppppppp",
        "PPPPdPPPPdPP",
        "dddddddddddd",
        "Pp#ggGdgg#pP",
        "Pp#ggOOgg#pP",
        "Pd#ggooGg#pP",
        "Pp#ggGGgg#pP",
        "Pp#ggGGgg#dP",
        "Pp#ggGGgg#pP",
        "Pd#ggGGgg#pP",
        "Pp#ggGGgg#pP",
        "Pp#ggGGgg#pP",
        "Pp#ggGGgg#dP",
        "Pp#ggGGgg#pP",
        "Pd#ggGGgg#pP",
        "Pp#ggGGgg#pP",
    ]),
    # Marble columns with a cloud resting on top.
    "sky": ({"#": "#8e8a80", "M": "#f0ece0", "m": "#c8c4b8", "n": "#a8a498", "U": "#ffffff", "u": "#d8e4f0"}, [
        "..uUUuuUUu..",
        ".uUUUUUUUUu.",
        "MMMMMMMMMMMM",
        "mnnnnnnnnnnm",
        "Mm#gggggg#mM",
        "Mn#ggGGgg#nM",
        "Mm#ggGGgg#mM",
        "Mn#ggGGgg#nM",
        "Mm#ggGGgg#mM",
        "Mn#ggGGgg#nM",
        "Mm#ggGGgg#mM",
        "Mn#ggGGgg#nM",
        "Mm#ggGGgg#mM",
        "Mn#ggGGgg#nM",
        "MM#ggGGgg#MM",
        "mm#ggGGgg#mm",
    ]),
    # A silver mirror frame.
    "mirror": ({"#": "#2e5a88", "A": "#c8f0ff", "a": "#8ac8f0", "F": "#5a8aba", "X": "#ffffff"}, [
        "...aAAAAa...",
        "..aAFFFFAa..",
        ".aAgggXgg#Aa",
        "aA#gggggg#Aa",
        "aA#ggGGgg#Aa",
        "XA#ggGGgg#Aa",
        "aA#ggGGgg#Aa",
        "aA#ggGGgg#AX",
        "aA#ggGGgg#Aa",
        "aA#ggGGgg#Aa",
        "XA#ggGGgg#Aa",
        "aA#ggGGgg#Aa",
        "aA#ggGGgg#AX",
        "aA#ggGGgg#Aa",
        "AF#ggGGgg#FA",
        "aA#ggGGgg#Aa",
    ]),
    # Dark violet stone crowned with a crystal. Often hung upside down.
    "spire": ({"#": "#1e1430", "Q": "#8a6ac8", "q": "#5a4490", "z": "#2e2048", "Y": "#c890ff", "y": "#f0d0ff"}, [
        ".....yY.....",
        "....YyYY....",
        "qQQQQYYQQQQq",
        "QzzzzzzzzzzQ",
        "Qq#gggggg#qQ",
        "Qq#ggGGgg#qQ",
        "Qz#ggGGgg#qQ",
        "Qq#ggGGgg#zQ",
        "Qq#ggGGgg#qQ",
        "Qq#ggGGgg#qQ",
        "Qz#ggGGgg#qQ",
        "Qq#ggGGgg#zQ",
        "Qq#ggGGgg#qQ",
        "Qq#ggGGgg#qQ",
        "Qz#ggGGgg#zQ",
        "Qq#ggGGgg#qQ",
    ]),
    # A sandstone arch half buried by a drift.
    "dunes": ({"#": "#8a5e36", "D": "#d8a46a", "e": "#a87444", "E": "#e8c084", "N": "#e8c890", "n": "#f8e0a8"}, [
        "...EEEEEE...",
        ".EDDDDDDDDE.",
        "EDDeggggeDDE",
        "DDeggggggeDD",
        "De#ggGGgg#eD",
        "De#ggGGgg#eD",
        "Ee#ggGGgg#eD",
        "De#ggGGgg#eE",
        "De#ggGGgg#eD",
        "De#ggGGgg#eD",
        "Ee#ggGGgg#eD",
        "De#ggGGgg#eD",
        "De#ggGGgg#eE",
        "nD#ggGGgg#Dn",
        "NNnggGGggnNN",
        "NNNNgGGgNNNN",
    ]),
    # An arch of ice with icicles hanging into it.
    "frost": ({"#": "#3a6a98", "I": "#a8d8f8", "i": "#5a8ab8", "J": "#f0f8ff", "j": "#3a6a98"}, [
        "..JJJJJJJJ..",
        ".JIIIIIIIIJ.",
        "JIiIiiiiIiIJ",
        "Ii#JgggJg#iI",
        "Ii#JgGGgg#iI",
        "Ji#ggGGgg#iJ",
        "Ii#ggGGgg#jI",
        "Ij#ggGGgg#iI",
        "Ji#ggGGgg#iJ",
        "Ii#ggGGgg#iI",
        "Ii#ggGGgg#jI",
        "Jj#ggGGgg#iJ",
        "Ii#ggGGgg#iI",
        "Ii#ggGGgg#iI",
        "Ji#ggGGgg#iJ",
        "JJ#ggGGgg#JJ",
    ]),
    # A riveted brass vault frame with a gear hub on top.
    "clockwork": ({"#": "#3a2a14", "B": "#e8c070", "b": "#b08848", "k": "#4a3418", "r": "#f8e0a0"}, [
        "..bBBBBBBb..",
        ".bBrBkkBrBb.",
        "bBkkkkkkkkBb",
        "BbkggggggkbB",
        "Br#ggGGgg#rB",
        "Bb#ggGGgg#bB",
        "Bb#ggGGgg#bB",
        "Br#ggGGgg#rB",
        "Bb#ggGGgg#bB",
        "Bb#ggGGgg#bB",
        "Br#ggGGgg#rB",
        "Bb#ggGGgg#bB",
        "Bb#ggGGgg#bB",
        "Br#ggGGgg#rB",
        "Bb#ggGGgg#bB",
        "bb#ggGGgg#bb",
    ]),
    # A marble arch set with brass stars.
    "observatory": ({"#": "#3a3a54", "V": "#b8b8d8", "v": "#8a8aac", "w": "#5a5a7a", "S": "#e0c060"}, [
        "....vVVv....",
        "..vVwSwwVv..",
        ".vVwwwwSwwVv",
        "vVwggggggwVv",
        "Vw#ggGGgg#wV",
        "Vw#ggGGgg#wV",
        "Sw#ggGGgg#wV",
        "Vw#ggGGgg#wV",
        "Vw#ggGGgg#wV",
        "Vw#ggGGgg#wS",
        "Vw#ggGGgg#wV",
        "Vw#ggGGgg#wV",
        "Sw#ggGGgg#wV",
        "Vw#ggGGgg#wV",
        "Vw#ggGGgg#wV",
        "VV#ggGGgg#VV",
    ]),
    # Broken rift stones held together by violet light.
    "warp": ({"#": "#241838", "R": "#6a5a7a", "r": "#463a56", "V": "#a070ff", "v": "#d8b8ff"}, [
        "..RRrvRRr...",
        ".RrRRVRRRrR.",
        "RRrrrrrrrrRR",
        "RrrggggggrrR",
        "Rr#ggGGgg#rV",
        "Rr#ggGGgg#rR",
        "Vr#ggGGgg#rR",
        "Rr#ggGGgg#rv",
        "Rr#ggGGgg#rR",
        "vr#ggGGgg#rR",
        "Rr#ggGGgg#rV",
        "Rr#ggGGgg#rR",
        "Rr#ggGGgg#rR",
        "Vr#ggGGgg#rR",
        "Rr#ggGGgg#rR",
        "RR#ggGGgg#RR",
    ]),
    # A square-cut labyrinth gate with ivy on its keystone.
    "labyrinth": ({"#": "#102424", "L": "#3a6a6a", "l": "#224444", "U": "#4a8a4a"}, [
        "LLLLLLLLLLLL",
        "LlllLUULlllL",
        "LlLLLLLLLLlL",
        "LlL#gggg#LlL",
        "LlL#gGGg#LlL",
        "LlL#gGGg#LlL",
        "LlL#gGGg#LlL",
        "LlL#gGGg#LlL",
        "LlL#gGGg#LlL",
        "LlL#gGGg#LlL",
        "LlL#gGGg#LlL",
        "LlL#gGGg#LlL",
        "LlL#gGGg#LlL",
        "LlL#gGGg#LlL",
        "LLL#gGGg#LLL",
        "lll#gGGg#lll",
    ]),
    # A gold frame on a heap of coins.
    "hoard": ({"#": "#5a3a10", "O": "#f8c838", "o": "#c08a20", "Y": "#fff0a0"}, [
        "...oOOOOo...",
        "..oOYOOYOo..",
        ".oOoooooooOo",
        "oOoggggggoOo",
        "Oo#ggGGgg#oO",
        "Oo#ggGGgg#oO",
        "Oo#ggGGgg#oO",
        "Yo#ggGGgg#oO",
        "Oo#ggGGgg#oY",
        "Oo#ggGGgg#oO",
        "Oo#ggGGgg#oO",
        "Oo#ggGGgg#oO",
        "Oo#ggGGgg#oO",
        "OYO#gGGg#OYO",
        "YOYOgGGgOYOY",
        "OYOYOgGOYOYO",
    ]),
    # A bone arch with a skull for a keystone.
    "crypt": ({"#": "#2a1418", "B": "#e8dcc0", "b": "#a89880", "K": "#1a0a0c", "S": "#f8f0e0"}, [
        "....SSSS....",
        "...SKSSKS...",
        "bBBBSSSSBBBb",
        "BbbbbSSbbbbB",
        "Bb#gggggg#bB",
        "bB#ggGGgg#Bb",
        "Bb#ggGGgg#bB",
        "bB#ggGGgg#Bb",
        "Bb#ggGGgg#bB",
        "bB#ggGGgg#Bb",
        "Bb#ggGGgg#bB",
        "bB#ggGGgg#Bb",
        "Bb#ggGGgg#bB",
        "bB#ggGGgg#Bb",
        "Bb#ggGGgg#bB",
        "BB#ggGGgg#BB",
    ]),
    # A pointed manor doorway with a candle burning on each side.
    "manor": ({"#": "#1e1420", "W": "#5a3a3a", "w": "#3a2428", "F": "#ffd070", "C": "#e8e0d0"}, [
        ".....WW.....",
        "....WwwW....",
        "...WwggwW...",
        "..WwggggwW..",
        ".FWw#GG#wWF.",
        ".CWw#GG#wWC.",
        ".CW#ggGg#WC.",
        "WWw#ggGg#wWW",
        "Ww#ggGGgg#wW",
        "Ww#ggGGgg#wW",
        "Ww#ggGGgg#wW",
        "Ww#ggGGgg#wW",
        "Ww#ggGGgg#wW",
        "Ww#ggGGgg#wW",
        "Ww#ggGGgg#wW",
        "WW#ggGGgg#WW",
    ]),
}


def door(name):
    """RGBA picture of a world's door, from its rows in DOORS."""
    palette, rows = DOORS[name]
    palette = {**GLOW, **palette}
    assert len(rows) == DOOR_H and all(len(r) == DOOR_W for r in rows), name
    img = np.zeros((DOOR_H, DOOR_W, 4), dtype=np.uint8)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                img[y, x, :3] = hexc(palette[ch])
                img[y, x, 3] = 255
    return img


THEMES = {
    "jungle": (jungle_backdrop, jungle_tile),
    "cave": (cave_backdrop, cave_tile),
    "temple": (temple_backdrop, temple_tile),
    "castle": (castle_backdrop, castle_tile),
    "mine": (mine_backdrop, mine_tile),
    "sky": (sky_backdrop, sky_tile),
    "mirror": (mirror_backdrop, mirror_tile),
    "spire": (spire_backdrop, spire_tile),
    "dunes": (dunes_backdrop, dunes_tile),
    "frost": (frost_backdrop, frost_tile),
    "clockwork": (clockwork_backdrop, clockwork_tile),
    "observatory": (observatory_backdrop, observatory_tile),
    "warp": (warp_backdrop, warp_tile),
    "labyrinth": (labyrinth_backdrop, labyrinth_tile),
    "hoard": (hoard_backdrop, hoard_tile),
    "crypt": (crypt_backdrop, crypt_tile),
    "manor": (manor_backdrop, manor_tile),
}


# --- output -----------------------------------------------------------------

def write_png(path, img):
    """Plain RGB or RGBA PNG, written with zlib so the tool needs nothing beyond numpy."""
    h, w, channels = img.shape
    raw = b"".join(b"\x00" + img[y].tobytes() for y in range(h))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6 if channels == 4 else 2, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def tile_sheet(painter):
    sheet = np.zeros((T * 2, T * 4, 3), dtype=np.uint8)
    for top in (1, 0):
        for v in range(4):
            sheet[(1 - top) * T:(2 - top) * T, v * T:(v + 1) * T] = painter(bool(top), v)
    return sheet


def main():
    for name, (backdrop, tile) in THEMES.items():
        out = ROOT / "art/themes" / name
        out.mkdir(parents=True, exist_ok=True)
        write_png(out / "backdrop.png", backdrop())
        write_png(out / "tiles.png", tile_sheet(tile))
        write_png(out / "door.png", door(name))
        print(f"wrote art/themes/{name}/backdrop.png, tiles.png and door.png")


if __name__ == "__main__":
    main()

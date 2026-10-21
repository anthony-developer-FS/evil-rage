#!/usr/bin/env python3
"""Builds the art for each explorer world: a 320x180 backdrop and an 8x8 tile sheet.

Usage: python3 tools/make_themes.py   (needs numpy)

For every theme in THEMES it writes:
  art/themes/<name>/backdrop.png  the painted room background, 320x180
  art/themes/<name>/tiles.png     32x16: row 0 is four top-surface tiles, row 1 four fill tiles

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


THEMES = {
    "jungle": (jungle_backdrop, jungle_tile),
    "cave": (cave_backdrop, cave_tile),
    "temple": (temple_backdrop, temple_tile),
    "castle": (castle_backdrop, castle_tile),
}


# --- output -----------------------------------------------------------------

def write_png(path, img):
    """Plain RGB PNG, written with zlib so the tool needs nothing beyond numpy."""
    h, w, _ = img.shape
    raw = b"".join(b"\x00" + img[y].tobytes() for y in range(h))

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
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
        print(f"wrote art/themes/{name}/backdrop.png and tiles.png")


if __name__ == "__main__":
    main()

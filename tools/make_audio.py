#!/usr/bin/env python3
"""Synthesizes every sound in assets/audio from scratch. No samples, no third-party
assets, so the output is ours to ship anywhere (see assets/audio/LICENSE.md).

Usage: python3 tools/make_audio.py   (needs numpy, and ffmpeg with libvorbis for music)
Deterministic: the noise generator is seeded, so reruns produce identical files.
"""
import os
import subprocess
import wave

import numpy as np

RATE = 44100
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
rng = np.random.default_rng(1337)


# --- building blocks -------------------------------------------------------

def t_axis(dur):
    return np.arange(int(dur * RATE)) / RATE


def phase(freq, dur):
    """Phase in cycles for a constant or per-sample frequency."""
    n = int(dur * RATE)
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    return np.cumsum(f) / RATE


def square(freq, dur, duty=0.5):
    return np.where((phase(freq, dur) % 1.0) < duty, 1.0, -1.0)


def triangle(freq, dur):
    p = phase(freq, dur) % 1.0
    return 4.0 * np.abs(p - 0.5) - 1.0


def sine(freq, dur):
    return np.sin(2 * np.pi * phase(freq, dur))


def noise(dur, hold=1, gen=None):
    """White noise; hold > 1 repeats samples for a crunchier, lower-pitched hiss.
    Sounds added later pass their own `gen`, so older sounds keep their exact noise."""
    n = int(dur * RATE)
    v = (gen or rng).uniform(-1, 1, n // hold + 1)
    return np.repeat(v, hold)[:n]


def sweep(f0, f1, dur, curve=1.0):
    x = np.linspace(0, 1, int(dur * RATE)) ** curve
    return f0 * (f1 / f0) ** x


def env(dur, attack=0.005, decay=None, sustain=1.0):
    """Linear attack, then exponential-ish decay to silence at the end."""
    n = int(dur * RATE)
    e = np.ones(n) * sustain
    a = max(int(attack * RATE), 1)
    e[:a] = np.linspace(0, 1, a)
    rest = n - a
    if rest > 0:
        e[a:] = np.linspace(1, 0, rest) ** (2.0 if decay is None else decay)
    return e


def lowpass(x, cutoff):
    """One-pole lowpass. Takes off the harsh edge of square waves and noise."""
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def cat(*parts):
    return np.concatenate(parts)


def pad(x, n):
    return np.pad(x, (0, max(n - len(x), 0)))[:n]


def mix(*parts):
    n = max(len(p) for p in parts)
    return sum(pad(p, n) for p in parts)


def write_wav(name, x, peak=0.8):
    x = np.asarray(x, dtype=float)
    x = x / (np.max(np.abs(x)) or 1.0) * peak
    # Short fade-out so nothing clicks when it ends.
    fade = min(len(x), int(0.004 * RATE))
    x[-fade:] *= np.linspace(1, 0, fade)
    path = os.path.join(ROOT, "sfx", name + ".wav")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    print("wrote", os.path.relpath(path, ROOT))


# --- sound effects ---------------------------------------------------------

def sfx_jump():
    d = 0.14
    return square(sweep(260, 620, d, 0.6), d, 0.25) * env(d, 0.002, 1.5) * 0.6


def sfx_wall_jump():
    d = 0.16
    tone = square(sweep(330, 820, d, 0.5), d, 0.125) * env(d, 0.002, 1.5) * 0.5
    scuff = lowpass(noise(0.05), 3000) * env(0.05, 0.001, 2.0) * 0.5
    return mix(tone, scuff)


def sfx_land():
    d = 0.07
    thump = sine(sweep(160, 60, d), d) * env(d, 0.001, 2.5)
    dust = lowpass(noise(d), 1200) * env(d, 0.001, 3.0) * 0.6
    return mix(thump, dust)


def sfx_death():
    # Splat, then a sad descending warble.
    splat = lowpass(noise(0.12, hold=3), 2500) * env(0.12, 0.001, 2.0)
    d = 0.4
    t = t_axis(d)
    f = sweep(520, 90, d, 0.8) * (1 + 0.06 * np.sin(2 * np.pi * 18 * t))
    warble = square(f, d, 0.5) * env(d, 0.005, 1.2) * 0.45
    return mix(splat, cat(np.zeros(int(0.03 * RATE)), lowpass(warble, 4000)))


def sfx_respawn():
    notes = [523.25, 659.25, 783.99]
    parts = [square(f, 0.045, 0.25) * env(0.045, 0.002, 1.0) for f in notes]
    return cat(*parts) * 0.45


def sfx_goal():
    notes = [523.25, 659.25, 783.99, 1046.5]
    parts = [square(f, 0.07, 0.5) * env(0.07, 0.002, 0.8) for f in notes[:-1]]
    parts.append(square(notes[-1], 0.25, 0.5) * env(0.25, 0.002, 1.5))
    return lowpass(cat(*parts), 5000) * 0.5


def sfx_win():
    # Fanfare that ends on a cheeky flat note.
    seq = [(523.25, 0.1), (659.25, 0.1), (783.99, 0.1), (1046.5, 0.3), (987.77, 0.12), (1046.5, 0.12), (739.99, 0.5)]
    parts = []
    for f, d in seq:
        parts.append(mix(square(f, d, 0.5) * 0.5, triangle(f / 2, d) * 0.5) * env(d, 0.003, 1.0))
    return lowpass(cat(*parts), 5000)


def sfx_fake_floor():
    # Crumble: gritty noise bursts that fall in pitch.
    d = 0.35
    grit = lowpass(noise(d, hold=6), 1800) * env(d, 0.002, 1.3)
    crack = lowpass(noise(0.03), 6000) * env(0.03, 0.0005, 2.0)
    drop = sine(sweep(220, 70, 0.25), 0.25) * env(0.25, 0.002, 2.0) * 0.6
    return mix(crack, grit, drop)


def sfx_pop_spikes():
    # Metallic "shing": inharmonic partials with a fast attack.
    d = 0.3
    t = t_axis(d)
    shing = sum(np.sin(2 * np.pi * f * t) * a for f, a in [(1840, 1), (2710, 0.6), (3930, 0.4), (5120, 0.25)])
    shing *= env(d, 0.001, 3.0)
    snap = lowpass(noise(0.025), 8000) * env(0.025, 0.0005, 2.0)
    return mix(snap, shing * 0.5)


def sfx_runaway_goal():
    # Cartoon "boing" with a little wobble, like the exit is laughing at you.
    d = 0.3
    t = t_axis(d)
    f = sweep(180, 700, d, 0.4) * (1 + 0.12 * np.sin(2 * np.pi * 22 * t))
    return lowpass(square(f, d, 0.3), 3500) * env(d, 0.002, 1.2) * 0.5


def sfx_invisible_block():
    # Bonk: a hollow wooden knock.
    d = 0.18
    knock = mix(sine(sweep(420, 280, d), d), triangle(sweep(840, 560, d), d) * 0.4) * env(d, 0.0008, 3.5)
    click = lowpass(noise(0.01), 7000) * env(0.01, 0.0005, 2.0) * 0.5
    return mix(click, knock)


def sfx_falling_ceiling():
    # Rumble as it shakes loose. The thud plays separately when it lands.
    d = 0.3
    rumble = lowpass(noise(d, hold=20), 300) * env(d, 0.03, 0.8)
    creak = lowpass(square(sweep(70, 50, d), d, 0.5), 400) * env(d, 0.02, 1.0) * 0.4
    return mix(rumble, creak)


def sfx_ceiling_thud():
    d = 0.35
    thud = sine(sweep(110, 35, d), d) * env(d, 0.001, 2.0)
    debris = lowpass(noise(d, hold=4), 1500) * env(d, 0.001, 3.0) * 0.4
    return mix(thud, debris)


def sfx_dart():
    # Fwip: a short airy whoosh with a wooden click as the dart leaves the wall.
    gen = np.random.default_rng(2001)
    d = 0.22
    t = t_axis(d)
    whoosh = lowpass(noise(d, gen=gen), 2500) * env(d, 0.01, 2.5) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t))
    click = triangle(sweep(1400, 900, 0.03), 0.03) * env(0.03, 0.0005, 3.0) * 0.5
    return mix(click, whoosh * 0.7)


def sfx_secret():
    # Three rising notes, a little "you found something" chime.
    parts = []
    for f, d in [(784.0, 0.07), (987.77, 0.07), (1318.5, 0.22)]:
        parts.append(mix(sine(f, d), triangle(f * 2, d) * 0.2) * env(d, 0.003, 1.5))
    return cat(*parts) * 0.5


def sfx_grind():
    # Stone dragging on stone as a wall starts to slide: low rumble with a scrape.
    gen = np.random.default_rng(2101)
    d = 0.45
    t = t_axis(d)
    rumble = lowpass(noise(d, hold=16, gen=gen), 250) * env(d, 0.04, 0.9)
    scrape = lowpass(noise(d, hold=3, gen=gen), 1200) * env(d, 0.02, 1.2) * (0.5 + 0.5 * np.sin(2 * np.pi * 11 * t))
    hum = lowpass(square(sweep(55, 48, d), d, 0.4), 300) * env(d, 0.03, 1.0) * 0.4
    return mix(rumble, scrape * 0.5, hum)


def sfx_gravity():
    # The world turning over: a wide sweep up with a wobble, like the floor letting go.
    d = 0.4
    t = t_axis(d)
    f = sweep(160, 900, d, 0.7) * (1 + 0.05 * np.sin(2 * np.pi * 14 * t))
    tone = mix(sine(f, d), triangle(f * 1.5, d) * 0.3)
    return lowpass(tone, 4000) * env(d, 0.01, 1.4) * 0.6


def sfx_mirror():
    # Glassy shimmer that plays backwards: the swell comes last.
    d = 0.35
    t = t_axis(d)
    shimmer = sum(np.sin(2 * np.pi * f * t) * a for f, a in [(1046.5, 1), (1567.98, 0.6), (2093.0, 0.4), (2637.0, 0.3)])
    shimmer *= (0.6 + 0.4 * np.sin(2 * np.pi * 18 * t))
    return shimmer * env(d, 0.002, 1.5)[::-1] * 0.35


def sfx_void_shift():
    # Sand pouring away: a hiss that slides down, with a soft collapse under it.
    gen = np.random.default_rng(2201)
    d = 0.4
    t = t_axis(d)
    hiss = lowpass(noise(d, hold=2, gen=gen), 1800) * env(d, 0.02, 1.2) * (0.7 + 0.3 * np.sin(2 * np.pi * 23 * t))
    slump = lowpass(noise(d, hold=24, gen=gen), 180) * env(d, 0.01, 1.6)
    return mix(hiss * 0.6, slump)


def sfx_frost():
    # Ice crackling as it grows: sparse bright ticks over a cold whistle.
    gen = np.random.default_rng(2301)
    d = 0.5
    t = t_axis(d)
    ticks = np.zeros(len(t))
    for start in gen.uniform(0, d - 0.02, 14):
        i = int(start * RATE)
        n = int(0.006 * RATE)
        ticks[i:i + n] += noise(0.006, gen=gen)[:n] * np.linspace(1, 0, n)
    whistle = sine(sweep(1800, 2400, d), d) * env(d, 0.05, 1.0) * 0.15
    return mix(ticks, whistle)


def sfx_pop_block():
    # A heavy block punching out of the floor: thump, then a springy clang.
    gen = np.random.default_rng(2401)
    thump = sine(sweep(140, 50, 0.12), 0.12) * env(0.12, 0.002, 2.0)
    crack = lowpass(noise(0.05, gen=gen), 3000) * env(0.05, 0.001, 3.0) * 0.6
    clang = mix(square(sweep(330, 300, 0.2), 0.2, 0.3), triangle(sweep(495, 450, 0.2), 0.2)) * env(0.2, 0.002, 2.5) * 0.3
    return mix(thump, crack, clang)


def sfx_chest():
    # Lid creak, then a bright little treasure arpeggio.
    gen = np.random.default_rng(2501)
    d = 0.15
    creak = lowpass(square(sweep(180, 260, d), d, 0.2), 1500) * env(d, 0.01, 1.0) * 0.3
    creak += lowpass(noise(d, hold=4, gen=gen), 900) * env(d, 0.01, 1.0) * 0.2
    notes = []
    for f, n in [(1046.5, 0.06), (1318.5, 0.06), (1568.0, 0.06), (2093.0, 0.2)]:
        notes.append(mix(square(f, n, 0.25) * 0.4, sine(f, n)) * env(n, 0.002, 1.5))
    return cat(creak, *notes) * 0.6


def sfx_curse():
    # The treasure turning on you: a sour detuned slide down.
    d = 0.6
    t = t_axis(d)
    f = sweep(520, 130, d, 0.8)
    tone = mix(square(f, d, 0.4) * 0.3, square(f * 1.06, d, 0.4) * 0.3, triangle(f / 2, d))
    return lowpass(tone, 2200) * env(d, 0.01, 1.2) * (0.75 + 0.25 * np.sin(2 * np.pi * 7 * t))


def sfx_shield():
    # The amulet cracking as it takes the hit: a glassy ping and a shatter.
    gen = np.random.default_rng(2601)
    ping = mix(sine(1760, 0.3), sine(2637, 0.3) * 0.5) * env(0.3, 0.001, 2.5)
    shatter = lowpass(noise(0.18, gen=gen), 6000) * env(0.18, 0.001, 2.0) * 0.5
    return mix(ping, shatter) * 0.7


def sfx_taunt():
    # Two-note "nyah nyah" played when a taunt appears. Quiet, it sits under the death.
    parts = []
    for f, d in [(659.25, 0.09), (554.37, 0.14)]:
        parts.append(square(f, d, 0.125) * env(d, 0.004, 1.0))
    return lowpass(cat(*parts), 3000) * 0.35


def sfx_ui_tick():
    d = 0.04
    return square(880, d, 0.25) * env(d, 0.001, 2.0) * 0.4


# --- music -----------------------------------------------------------------

NOTE = {n: i for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def hz(name):
    """'A4' -> 440.0. '-' is a rest."""
    if name == "-":
        return 0.0
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTE[pitch] + 12 * (octave + 1) - 69) / 12)


def voice(seq, step, wave_fn, gain, decay=1.0, release=0.85):
    """seq: list of (note, steps). Each note is gated for `release` of its length."""
    out = []
    for name, steps in seq:
        d = steps * step
        f = hz(name)
        if f == 0:
            out.append(np.zeros(int(d * RATE)))
            continue
        on = d * release
        tone = wave_fn(f, on) * env(on, 0.003, decay)
        out.append(pad(tone, int(d * RATE)))
    return cat(*out) * gain


def drums(pattern, step):
    """pattern: string, k = kick, s = snare, h = hat, . = rest. One char per step."""
    out = []
    for c in pattern:
        n = int(step * RATE)
        if c == "k":
            d = 0.12
            hit = sine(sweep(140, 45, d), d) * env(d, 0.001, 2.0)
        elif c == "s":
            d = 0.1
            hit = mix(lowpass(noise(d, hold=2), 4000) * 0.8, triangle(190, d) * 0.4) * env(d, 0.001, 2.0)
        elif c == "h":
            d = 0.03
            hit = noise(d) * env(d, 0.0005, 2.0) * 0.3
        else:
            hit = np.zeros(1)
        out.append(pad(hit, n))
    return cat(*out)


def music_loop():
    """A sneaky minor-key chiptune loop, 112 BPM, 16 bars. Loops seamlessly because every
    voice is cut to the same sample count and notes end before the loop point."""
    bpm = 112
    step = 60 / bpm / 4  # sixteenth note
    bars = 16
    total = int(round(bars * 16 * step * RATE))

    # Bass: A minor, i - VI - III - VII, sneaky staccato eighths.
    def bass_bar(root, fifth):
        return [(root, 2), (root, 2), (fifth, 2), (root, 2), ("-", 2), (root, 2), (fifth, 2), (root, 2)]

    prog = [("A2", "E3"), ("F2", "C3"), ("C3", "G3"), ("G2", "D3")]
    bass = []
    for _ in range(bars // 4):
        for r, f in prog:
            bass += bass_bar(r, f)

    # Lead: a creeping tiptoe phrase (A), and a mocking answer (B).
    a = [("A4", 2), ("-", 2), ("C5", 2), ("B4", 2), ("A4", 2), ("-", 2), ("E4", 4),
         ("F4", 2), ("-", 2), ("A4", 2), ("G4", 2), ("F4", 2), ("E4", 2), ("C4", 4),
         ("E4", 2), ("G4", 2), ("C5", 2), ("G4", 2), ("E5", 3), ("D5", 1), ("C5", 4),
         ("D5", 2), ("B4", 2), ("G4", 2), ("B4", 2), ("D5", 4), ("-", 4)]
    b = [("E5", 1), ("D#5", 1), ("E5", 2), ("-", 2), ("E5", 1), ("D#5", 1), ("E5", 2), ("C5", 2), ("A4", 4),
         ("F5", 1), ("E5", 1), ("F5", 2), ("-", 2), ("A4", 2), ("C5", 2), ("F5", 2), ("E5", 4),
         ("G5", 2), ("E5", 2), ("C5", 2), ("E5", 2), ("G5", 2), ("A5", 2), ("G5", 4),
         ("B4", 2), ("D5", 2), ("G4", 2), ("B4", 2), ("A4", 4), ("G#4", 4)]
    lead = a + b + a + b

    # Arpeggio counter-line on the second half only, for lift.
    arp_chords = [["A4", "C5", "E5"], ["F4", "A4", "C5"], ["C5", "E5", "G5"], ["G4", "B4", "D5"]]
    arp = [("-", 16)] * 8
    for _ in range(2):
        for chord in arp_chords:
            arp += [(chord[i % 3], 1) for i in range(16)]

    groove = "k.h.s.h.k.khs.h." * bars

    bass_v = voice(bass, step, triangle, 0.55, decay=0.6, release=0.7)
    lead_v = lowpass(voice(lead, step, lambda f, d: square(f, d, 0.25), 0.22, decay=0.7, release=0.9), 4500)
    arp_v = lowpass(voice(arp, step, lambda f, d: square(f, d, 0.125), 0.08, decay=1.5, release=0.6), 3500)
    drum_v = drums(groove, step) * 0.35

    song = mix(pad(bass_v, total), pad(lead_v, total), pad(arp_v, total), pad(drum_v, total))
    return song / np.max(np.abs(song)) * 0.7


def write_ogg(name, x):
    path = os.path.join(ROOT, "music", name + ".ogg")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = (x * 32767).astype("<i2").tobytes()
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(RATE), "-ac", "1", "-i", "-",
         "-c:a", "libvorbis", "-q:a", "4", path],
        input=pcm, check=True)
    print("wrote", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    for fn_name, fn in sorted(globals().items()):
        if fn_name.startswith("sfx_"):
            write_wav(fn_name[4:], fn())
    write_ogg("theme", music_loop())

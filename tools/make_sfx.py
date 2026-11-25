"""Generates every sound effect for QuestNotes (no external assets needed).
    python tools/make_sfx.py   ->  game/assets/sfx/*.wav
"""
import numpy as np, wave, os
SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "sfx")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)

def t(d): return np.arange(int(SR * d)) / SR
def env(n, a=0.005, r=0.1, d=None):
    e = np.ones(n); A = max(1, int(a * SR)); e[:A] = np.linspace(0, 1, A)
    R = min(n, int(r * SR)); e[-R:] *= np.linspace(1, 0, R) ** 2
    return e
def sq(f, tt, duty=0.5): return np.where((f * tt) % 1 < duty, 1.0, -1.0)
def tri(f, tt): return 2 * np.abs(2 * ((f * tt) % 1) - 1) - 1
def noise(n): return rng.uniform(-1, 1, n)
def lowpass(x, a):
    y = np.zeros_like(x); acc = 0.0
    for i, v in enumerate(x): acc += a * (v - acc); y[i] = acc
    return y
def sweep(f0, f1, d, wave_fn=np.sin):
    tt = t(d); f = np.linspace(f0, f1, len(tt)); ph = 2 * np.pi * np.cumsum(f) / SR
    return wave_fn(ph) if wave_fn is np.sin else wave_fn(ph)
def save(name, x, vol=0.6):
    x = np.asarray(x, dtype=float); m = np.max(np.abs(x)) or 1
    x = np.clip(x / m * vol, -1, 1)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
def cat(*xs): return np.concatenate(xs)
def note(f, d, kind="sq", duty=0.5, r=0.08):
    tt = t(d); w = sq(f, tt, duty) if kind == "sq" else tri(f, tt)
    return w * env(len(tt), r=r)

# UI
save("click", note(880, 0.04, "sq", 0.25, 0.03), 0.35)
save("hover", note(1320, 0.025, "sq", 0.25, 0.02), 0.2)
# Footstep: short low thud
n = int(0.07 * SR); save("step", lowpass(noise(n), 0.08) * env(n, 0.002, 0.06), 0.35)
# Battle start: rising whoosh + stinger
n = int(0.35 * SR); wh = lowpass(noise(n), np.linspace(0.02, 0.4, n).mean()) * np.linspace(0, 1, n) ** 2
save("battle", cat(wh, note(220, 0.06) + note(330, 0.06), note(440, 0.12, "sq", 0.25, 0.1)), 0.5)
# Correct: bright arpeggio
save("correct", cat(note(659, 0.07, "sq", 0.25), note(784, 0.07, "sq", 0.25), note(1047, 0.16, "sq", 0.25, 0.14)), 0.45)
# Wrong: low descending buzz
x = np.sign(np.sin(2 * np.pi * np.cumsum(np.linspace(220, 90, int(0.35 * SR))) / SR))
save("wrong", x * env(len(x), 0.005, 0.15), 0.4)
# Hurt: noise crunch
n = int(0.2 * SR); save("hurt", (lowpass(noise(n), 0.3) + 0.5 * sweep(300, 80, 0.2)) * env(n, 0.001, 0.15), 0.55)
# Magic bolt cast
n = int(0.25 * SR); save("cast", (sweep(600, 1800, 0.25) * 0.6 + 0.3 * noise(n)) * env(n, 0.005, 0.15), 0.35)
# Monster hit / poof
n = int(0.3 * SR); save("poof", (lowpass(noise(n), 0.25) + 0.6 * sweep(500, 60, 0.3)) * env(n, 0.001, 0.25), 0.55)
# Door: heavy rumble + creak
n = int(0.9 * SR); rum = lowpass(noise(n), 0.03) * env(n, 0.05, 0.4)
creak = np.sin(2 * np.pi * np.cumsum(180 + 60 * np.sin(np.linspace(0, 30, n))) / SR) * 0.25 * env(n, 0.1, 0.3)
save("door", rum * 2 + creak, 0.6)
# Room cleared jingle
save("clear", cat(note(523, 0.09, "tri"), note(659, 0.09, "tri"), note(784, 0.09, "tri"), note(1047, 0.3, "tri", r=0.25)), 0.5)
# Boss roar: detuned low saws + noise
tt = t(1.2); f = np.linspace(90, 55, len(tt))
saw = sum(((np.cumsum(f * k) / SR) % 1) * 2 - 1 for k in (1, 1.01, 0.5))
save("boss", (saw + 0.8 * lowpass(noise(len(tt)), 0.15)) * env(len(tt), 0.15, 0.6), 0.6)
# Victory fanfare
v = cat(note(523, 0.12), note(523, 0.12), note(523, 0.12), note(659, 0.3), note(587, 0.15), note(659, 0.15), note(784, 0.5, r=0.4))
bass = note(262, len(v) / SR, "tri", r=0.5)
save("victory", v + 0.5 * bass[:len(v)], 0.45)
# Defeat
save("defeat", cat(note(392, 0.25, "tri"), note(349, 0.25, "tri"), note(330, 0.25, "tri"), note(262, 0.7, "tri", r=0.6)), 0.5)
# Coin/score tick
save("coin", cat(note(988, 0.05, "sq", 0.25), note(1319, 0.12, "sq", 0.25, 0.1)), 0.3)

# Ambient loop (16 s): low drone + slow filtered wind + sparse drips. Seamless loop.
D = 16.0; tt = t(D); n = len(tt)
drone = 0.5 * np.sin(2 * np.pi * 55 * tt) + 0.3 * np.sin(2 * np.pi * 82.5 * tt + 1) + 0.15 * np.sin(2 * np.pi * 110.25 * tt)
drone *= 0.7 + 0.3 * np.sin(2 * np.pi * tt / D)          # one slow swell per loop -> seamless
wind = lowpass(noise(n), 0.01); wind /= np.max(np.abs(wind))
wind *= 0.5 + 0.5 * np.sin(2 * np.pi * 2 * tt / D + 0.5)
x = drone * 0.6 + wind * 0.5
for start in (2.1, 6.7, 9.3, 13.8):
    s = int(start * SR); d = note(1568 + rng.integers(-200, 200), 0.18, "tri", r=0.17) * 0.25
    x[s:s + len(d)] += d
fade = int(0.05 * SR); x[:fade] *= np.linspace(0, 1, fade); x[-fade:] *= np.linspace(1, 0, fade)
save("ambient", x, 0.35)
print("sfx ->", os.path.abspath(OUT), sorted(os.listdir(OUT)))

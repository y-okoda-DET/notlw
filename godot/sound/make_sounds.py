# 仮の音（ステップ E、ユーザー決定 2026-11-10「仮の音はEでやります」）を、録音や素材を使わずに数式で作る。
# 外の素材を使わないのでライセンスの心配がない（docs/素材とアドオン.md）。本番の音は段階4（サウンドクリエイター）。
#   python3 godot/sound/make_sounds.py   → godot/sound/*.wav（44.1kHz、16bit）
# 雨・発電機は 2026-11-13 からユーザーが選んだ素材（cut_materials.py）、ノック・ラジオの雑音はユーザーの収録（cut_recordings.py）。
# 鳴らし方は scripts/sound.gd。良し悪しはユーザーが聞いて決める（Claude には耳がない）。
import numpy as np, wave, os
from scipy.signal import butter, sosfilt
R = 44100
OUT = os.path.dirname(os.path.abspath(__file__))
rng = np.random.default_rng(7)

def save(name, x, stereo=False):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * 0.89
    if stereo and x.ndim == 1: x = np.stack([x, x], 1)
    d = (x * 32767).astype('<i2')
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(2 if x.ndim == 2 else 1); w.setsampwidth(2); w.setframerate(R); w.writeframes(d.tobytes())
    print(name, '%.1fs' % (len(x) / R))

def lp_fast(x, fc, n=1):  # Butterworth low pass, 2n poles (n=1 a gentle 12 dB/oct)
    sos = butter(2 * n, fc, 'low', fs=R, output='sos')
    return sosfilt(sos, x, axis=0)

def hp_fast(x, fc): return x - lp_fast(x, fc)

def loopify(x, fade):  # crossfade the tail into the head so it loops without a seam
    f = int(fade * R); head = x[:f].copy(); tail = x[-f:]
    w = np.linspace(0, 1, f)
    if x.ndim == 2: w = w[:, None]
    out = x[f:].copy(); out[-f:] = tail * (1 - w) + head * w
    return out

def env(n, a, d):  # attack, exponential decay (seconds)
    t = np.arange(n) / R
    return np.minimum(t / max(a, 1e-4), 1.0) * np.exp(-t / d)

# ---------------------------------------------------------------- rain on the roof and the boarded windows (loop, stereo)
def rain(sec=24.0):
    n = int(sec * R)
    ch = []
    for c in range(2):
        w = rng.standard_normal(n)
        body = lp_fast(w, 1800, 2) * 1.0 + hp_fast(lp_fast(w, 6000), 900) * 0.35   # the hiss of it
        # gusts: the storm swells and lets go over seconds
        g = lp_fast(rng.standard_normal(n), 0.15, 2); g = (g - g.min()) / (np.ptp(g) + 1e-9)
        body *= 0.55 + 0.6 * g
        # drops on the boards and the gutter: short ticks, more in the gusts
        drops = np.zeros(n)
        k = rng.poisson(sec * 90)
        at = rng.integers(0, n - 2000, k)
        for p in at:
            if rng.random() > 0.4 + 0.6 * g[p]: continue
            L = rng.integers(200, 900); f = rng.uniform(1500, 4200)
            tt = np.arange(L) / R
            drops[p:p + L] += np.sin(2 * np.pi * f * tt) * np.exp(-tt / rng.uniform(0.002, 0.008)) * rng.uniform(0.2, 1.0)
        ch.append(body + drops * 0.25)
    x = np.stack(ch, 1)
    return loopify(x, 2.0)

# ---------------------------------------------------------------- three knocks on a wooden door (the knuckles, the leaf, the frame)
def knock(n_knocks=3, gap=0.42):
    n = int((gap * n_knocks + 0.8) * R); x = np.zeros(n)
    for i in range(n_knocks):
        p = int((i * gap + (0.06 if i == n_knocks - 1 else 0.0)) * R)
        L = int(0.35 * R); t = np.arange(L) / R
        thump = (np.sin(2 * np.pi * 92 * t) * 1.0 + np.sin(2 * np.pi * 185 * t + 0.4) * 0.6 + np.sin(2 * np.pi * 330 * t) * 0.35) * np.exp(-t / 0.045)
        click = lp_fast(rng.standard_normal(L), 3500) * np.exp(-t / 0.004) * 2.5
        rattle = lp_fast(rng.standard_normal(L), 900) * np.exp(-t / 0.06) * 0.4   # the leaf in its frame
        v = 1.0 if i < n_knocks - 1 else 1.15
        x[p:p + L] += (thump + click + rattle) * v
    return lp_fast(x, 2500)

# ---------------------------------------------------------------- the radio between stations (loop): hiss, crackle, the fading of the mountains
def radio_static(sec=12.0):
    n = int(sec * R); w = rng.standard_normal(n)
    band = hp_fast(lp_fast(w, 3200, 2), 300)
    fade = lp_fast(rng.standard_normal(n), 0.4, 2); fade = 0.6 + 0.4 * (fade - fade.min()) / (np.ptp(fade) + 1e-9)
    crack = np.zeros(n)
    for p in rng.integers(0, n - 400, int(sec * 25)):
        L = rng.integers(30, 300); crack[p:p + L] += rng.standard_normal(L) * rng.uniform(0.5, 2.0)
    # a faint heterodyne whistle that wanders
    t = np.arange(n) / R; f = 1800 + 600 * np.sin(2 * np.pi * 0.07 * t)
    whistle = np.sin(2 * np.pi * np.cumsum(f) / R) * 0.04
    return loopify(band * fade + lp_fast(crack, 2500) * 0.35 + whistle, 1.0)

# a station as a voice would come through a small speaker, wordless (the words are the transcript's): a murmur in the speech band
def radio_voice(sec=12.0):
    n = int(sec * R); t = np.arange(n) / R
    syl = lp_fast(rng.standard_normal(n), 4.5, 2); syl = np.clip((syl - np.percentile(syl, 35)) * 6, 0, 1)   # syllables and the gaps
    pitch = 125 + 18 * lp_fast(rng.standard_normal(n), 1.5, 2) / 0.02
    buzz = np.sign(np.sin(2 * np.pi * np.cumsum(pitch) / R)) * 0.5
    voiced = lp_fast(hp_fast(buzz, 350), 2400, 2)
    fric = hp_fast(lp_fast(rng.standard_normal(n), 3000), 1500) * 0.15
    return loopify((voiced + fric) * syl, 1.0)

# ---------------------------------------------------------------- the tape: the deck's hiss and the mechanism
def tape_hiss(sec=10.0):
    n = int(sec * R); w = rng.standard_normal(n)
    hiss = hp_fast(lp_fast(w, 7000), 1200)
    hum = np.sin(2 * np.pi * 50 * np.arange(n) / R) * 0.02 + np.sin(2 * np.pi * 100 * np.arange(n) / R) * 0.01
    wow = 1 + 0.08 * np.sin(2 * np.pi * 0.55 * np.arange(n) / R)
    return loopify(hiss * wow * 0.6 + hum, 0.8)

def tape_clunk():
    L = int(0.6 * R); t = np.arange(L) / R
    a = (np.sin(2 * np.pi * 140 * t) * np.exp(-t / 0.03) + lp_fast(rng.standard_normal(L), 2500) * np.exp(-t / 0.01) * 1.5)
    b = np.zeros(L); p = int(0.18 * R); tt = t[:L - p]
    b[p:] = (np.sin(2 * np.pi * 210 * tt) * np.exp(-tt / 0.02) + lp_fast(rng.standard_normal(L - p), 3000) * np.exp(-tt / 0.006)) * 0.7
    motor = np.sin(2 * np.pi * 60 * t) * 0.05 * np.clip((t - 0.25) * 4, 0, 1)
    return a + b + motor

# ---------------------------------------------------------------- the generator in the cellar (loop) and its running out
def generator(sec=8.0):
    n = int(sec * R); t = np.arange(n) / R
    f = 29.0 * (1 + 0.006 * np.sin(2 * np.pi * 0.3 * t))
    ph = 2 * np.pi * np.cumsum(f) / R
    pulses = np.maximum(0, np.sin(ph)) ** 6                       # the firing
    eng = lp_fast(pulses - pulses.mean(), 400, 2) * 3 + np.sin(ph * 2) * 0.25 + np.sin(ph * 3) * 0.12
    mech = hp_fast(lp_fast(rng.standard_normal(n), 2500), 600) * 0.08 * (0.6 + 0.4 * pulses)
    return loopify(eng + mech, 1.0)

def generator_stop():
    sec = 6.0; n = int(sec * R); t = np.arange(n) / R
    g = generator(8.0)[:n]
    # it misses, catches, misses, and goes; the last turns slow down
    gate = np.ones(n)
    for a, b in [(0.9, 1.15), (1.6, 1.75), (2.1, 2.5)]: gate[int(a * R):int(b * R)] = 0.15
    slow = np.clip(1 - (t - 2.6) / 1.6, 0, 1); gate *= np.where(t > 2.6, slow ** 1.5, 1)
    tick = np.zeros(n)
    for p in [4.4, 4.9, 5.25]:   # the metal ticking as it cools
        i = int(p * R); L = 800; tt = np.arange(L) / R; tick[i:i + L] += np.sin(2 * np.pi * 3100 * tt) * np.exp(-tt / 0.004) * 0.15
    return g * lp_fast(gate, 20) + tick

# ---------------------------------------------------------------- a car: its engine coming up the drive, idling; its door
def car_arrive(sec=9.0):
    n = int(sec * R); t = np.arange(n) / R
    k = np.clip(t / 7.0, 0, 1)
    rpm = 900 + 700 * (1 - k) ** 1.5
    ph = 2 * np.pi * np.cumsum(rpm / 60 * 2) / R
    eng = lp_fast(np.maximum(0, np.sin(ph)) ** 4, 300, 2) * 2 + np.sin(ph) * 0.2
    tyres = lp_fast(rng.standard_normal(n), 700, 2) * 0.6 * (1 - k) + hp_fast(lp_fast(rng.standard_normal(n), 3000), 800) * 0.25 * (1 - k)   # on the wet gravel
    vol = np.clip(t / 5.0, 0, 1) ** 1.5 * 0.7 + 0.3
    vol *= np.where(t > 8.0, np.clip(1 - (t - 8.0) * 1.2, 0, 1), 1)   # it stops
    return lp_fast((eng + tyres) * vol, 1200)

def car_door():
    L = int(0.7 * R); t = np.arange(L) / R
    latch = lp_fast(rng.standard_normal(L), 3000) * np.exp(-t / 0.008)
    slam = (np.sin(2 * np.pi * 70 * t) * 1.2 + np.sin(2 * np.pi * 150 * t) * 0.5) * np.exp(-t / 0.08) + lp_fast(rng.standard_normal(L), 800) * np.exp(-t / 0.05)
    p = int(0.04 * R); x = latch * 0.6; x[p:] += slam[:L - p]
    return lp_fast(x, 1800)

# ---------------------------------------------------------------- the front door: the lock, the hinge
def door_open(sec=3.5):
    n = int(sec * R); t = np.arange(n) / R
    lock = np.zeros(n); L = 1500; tt = np.arange(L) / R
    lock[:L] = (np.sin(2 * np.pi * 2300 * tt) * np.exp(-tt / 0.006) + lp_fast(rng.standard_normal(L), 4000) * np.exp(-tt / 0.003))
    k = np.clip((t - 0.8) / 3.0, 0, 1)
    f = 180 + 260 * np.sin(np.pi * k) * (1 + 0.15 * np.sin(2 * np.pi * 9 * t))
    creak = np.sin(2 * np.pi * np.cumsum(f) / R) * (np.sin(np.pi * k) ** 2) * (0.5 + 0.5 * (lp_fast(rng.standard_normal(n), 30) > 0))
    return lock * 0.6 + lp_fast(creak, 1500) * 0.35

if __name__ == '__main__':
    # knock / knock1 / knock_weak / knock_weak1 / radio_static: the user's recordings (2026-11-12), cut by sound/cut_recordings.py
    save('radio_voice', radio_voice())
    save('tape_hiss', tape_hiss())
    save('tape_clunk', tape_clunk())
    save('car_arrive', car_arrive())
    save('car_door', car_door())

# 試作176（ユーザー、第1章「環境音があってもいいかもね」、20時「停電になった瞬間、停電になったことが分かる音を入れたい」）:
# 夕方の外の音、家のうなり（冷蔵庫と電灯）、停電でうなりが落ちる音。make_sounds.py と同じく数式で作る（ライセンスの心配なし）。
#   python3 godot/sound/make_amb_sounds.py   → godot/sound/dusk_amb.wav, house_hum.wav, power_down.wav
# 鳴らし方は scripts/sound.gd。良し悪しはユーザーが聞いて決める。
import numpy as np, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import save, lp_fast, hp_fast, loopify, env, R
rng = np.random.default_rng(176)

# ---------------------------------------------------------------- dusk outside (loop, stereo, 32 s): wind in the cedars, insects, a far bird
def dusk_amb(sec=32.0):
    n = int(sec * R); t = np.arange(n) / R
    ch = []
    for c in range(2):
        w = rng.standard_normal(n)
        g = lp_fast(rng.standard_normal(n), 0.08, 2); g = (g - g.min()) / (np.ptp(g) + 1e-9)   # slow swells of the wind
        wind = lp_fast(w, 380, 2) * (0.25 + 0.75 * g) + hp_fast(lp_fast(w, 2600), 700) * 0.12 * g   # the low air and the needles' hiss
        # insects in the grass: trains of short chirps at ~4.3 kHz, several voices, each its own rhythm
        ins = np.zeros(n)
        for v in range(5):
            f = rng.uniform(3900, 4700); rate = rng.uniform(2.2, 4.0); on = rng.uniform(0.25, 0.6)
            ph = rng.uniform(0, 1); amp = rng.uniform(0.3, 1.0)
            gate = ((t * rate + ph) % 1.0) < on * 0.35
            puls = (np.sin(2 * np.pi * 38 * t) > 0.2).astype(float)          # the wing's rasp inside each chirp
            slow = 0.5 + 0.5 * np.sin(2 * np.pi * t / rng.uniform(5, 11) + rng.uniform(0, 6))
            ins += np.sin(2 * np.pi * f * t) * gate * puls * slow * amp
        ins = lp_fast(ins, 6000) * 0.05
        # a far bird: now and then a falling two-note whistle, faint
        bird = np.zeros(n)
        for k in range(rng.integers(3, 6)):
            p = int(rng.uniform(1, sec - 2) * R)
            for j in range(2):
                L = int(rng.uniform(0.18, 0.3) * R); tt = np.arange(L) / R
                f0 = rng.uniform(2600, 3400); f = f0 - tt * rng.uniform(1500, 3000)
                s = np.sin(2 * np.pi * np.cumsum(f) / R) * np.sin(np.pi * tt / tt[-1]) ** 2
                q = p + j * int(0.35 * R)
                if q + L < n: bird[q:q + L] += s
        bird = lp_fast(bird, 3800) * 0.035
        ch.append(wind * 0.6 + ins + bird)
    x = np.stack(ch, 1)
    return loopify(x, 3.0)

# ---------------------------------------------------------------- the house's hum (loop, mono, 12 s): the fridge's compressor and the lamps
def house_hum(sec=12.0):
    n = int(sec * R); t = np.arange(n) / R
    wob = 1.0 + 0.004 * np.sin(2 * np.pi * 0.31 * t)
    comp = sum(a * np.sin(2 * np.pi * 50 * h * np.cumsum(wob) / R) for h, a in [(1, 1.0), (2, 0.55), (3, 0.25), (4, 0.12)])
    rattle = lp_fast(rng.standard_normal(n), 220) * 0.15
    buzz = np.sin(2 * np.pi * 100 * t) * 0.18 + np.sin(2 * np.pi * 200 * t) * 0.06   # the lamps
    x = (comp + rattle) * (0.85 + 0.15 * np.sin(2 * np.pi * 0.07 * t)) + buzz
    return loopify(lp_fast(x, 900), 1.5)

# ---------------------------------------------------------------- the power goes (one, mono, 1.6 s): the hum falls away under the breaker
def power_down(sec=1.6):
    n = int(sec * R); t = np.arange(n) / R
    fall = np.exp(-t / 0.35)
    f = 50 * (0.35 + 0.65 * np.exp(-t / 0.5))
    ph = 2 * np.pi * np.cumsum(f) / R
    hum = (np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph)) * fall
    # the fridge's relay lets go: a dull clack at the start
    L = int(0.05 * R); clack = np.zeros(n); clack[:L] = lp_fast(rng.standard_normal(L), 1800) * env(L, 0.0005, 0.012) * 3.0
    # the lamps' filaments tick as they cool
    tick = np.zeros(n)
    for p in [0.12, 0.31, 0.6]:
        q = int(p * R); L2 = int(0.01 * R); tick[q:q + L2] += hp_fast(rng.standard_normal(L2), 3000) * env(L2, 0.0002, 0.002) * 0.4
    return lp_fast(hum, 700) * 0.9 + clack + tick

if __name__ == '__main__':
    save('dusk_amb', dusk_amb())
    save('house_hum', house_hum())
    save('power_down', power_down())

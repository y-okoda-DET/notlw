# 2026-11-20 の練り直しの仮の音。make_sounds.py と同じく数式で作る（ライセンスの心配がない）。
#   python3 godot/sound/make_1120_sounds.py   → godot/sound/siren_far.wav（44.1kHz、16bit）
#   c7_stream   第7章の沢の底、細い流れ（輪にして鳴らす。12秒）
#   c7_breath   第7章の沢の底、陽太の荒い息（輪にして鳴らす。11秒）
#   siren_far   21時の頭、遠くの救急車（ピーポー、960/770Hz を 0.65 秒ずつ）。近づかずに消える。雨と家の壁越し（高い音を落とす）
# 良し悪しはユーザーが聞いて決める。本番の音はステップ G。
import numpy as np, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import save, lp_fast, R
from scipy.signal import butter, sosfilt
rng = np.random.default_rng(1120)

def siren_far(sec=13.0):
    n = int(sec * R); t = np.arange(n) / R
    half = 0.65
    f = np.where((t // half) % 2 == 0, 960.0, 770.0)
    f = lp_fast(f, 0.004, 1)                       # the change of pitch is not a click
    f = f * (1.0 + 0.004 * np.sin(2 * np.pi * 0.17 * t))   # far off, the air moves it a little
    ph = 2 * np.pi * np.cumsum(f) / R
    x = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
    # it comes up out of the rain and goes again, never near (a far road, behind the hill)
    e = np.interp(t, [0, 3.5, 6.5, 9.0, sec], [0.0, 0.55, 0.75, 0.45, 0.0]) ** 1.3
    wob = 0.75 + 0.25 * lp_fast(rng.standard_normal(n), 0.0006, 2) / 0.02   # the wind takes it and gives it back
    x = x * e * np.clip(wob, 0.4, 1.2)
    x = sosfilt(butter(2, 1500, 'low', fs=R, output='sos'), x)    # the walls and the boards
    x = sosfilt(butter(1, 300, 'high', fs=R, output='sos'), x)
    # a slap back off the trees
    d = int(0.21 * R); x[d:] += 0.25 * x[:-d]
    return x / (np.abs(x).max() + 1e-9) * 0.5

def _loopable(x, fade=0.6):
    k = int(fade * R); w = np.linspace(0, 1, k)
    y = x[:-k].copy(); y[:k] = y[:k] * w + x[-k:] * (1 - w)   # the tail folded onto the head: no seam when it loops
    return y

def c7_stream(sec=12.6):
    n = int(sec * R); t = np.arange(n) / R
    w = rng.standard_normal(n)
    x = sosfilt(butter(2, [250, 2400], 'band', fs=R, output='sos'), w) * 0.6
    x = x * (0.8 + 0.2 * lp_fast(rng.standard_normal(n), 0.0004, 2) / 0.02)
    # bubbles: short rising sines over the water, a few a second
    for _ in range(int(sec * 6)):
        t0 = rng.uniform(0, sec - 0.1); d = rng.uniform(0.012, 0.04); f0 = rng.uniform(500, 1400)
        i0 = int(t0 * R); m = int(d * R); tt = np.arange(m) / R
        b = np.sin(2 * np.pi * (f0 * tt + 0.5 * f0 * 6 * tt * tt)) * np.sin(np.pi * tt / d) ** 2
        x[i0:i0 + m] += b * rng.uniform(0.08, 0.25)
    x = sosfilt(butter(1, 3500, 'low', fs=R, output='sos'), x)
    x = _loopable(x)
    return x / (np.abs(x).max() + 1e-9) * 0.4

def c7_breath(sec=11.6):
    n = int(sec * R); t = np.arange(n) / R
    w = rng.standard_normal(n)
    x = np.zeros(n)
    at = 0.2
    while at < sec - 1.0:
        inh = rng.uniform(0.45, 0.7); exh = rng.uniform(0.6, 0.95); gap = rng.uniform(0.15, 0.5)
        for (a, d, f, g) in ((at, inh, (900, 2600), 0.55), (at + inh + 0.05, exh, (500, 1800), 0.8)):
            i0 = int(a * R); m = min(int(d * R), n - i0)
            e = np.sin(np.pi * np.arange(m) / m) ** 1.5
            # ragged: it catches in the chest
            e = e * (1 - 0.35 * (lp_fast(rng.standard_normal(m), 0.003, 1) > 0.01))
            seg = sosfilt(butter(2, f, 'band', fs=R, output='sos'), w[i0:i0 + m]) * e * g
            x[i0:i0 + m] += seg
        at += inh + exh + gap
    x = _loopable(x, 0.3)
    return x / (np.abs(x).max() + 1e-9) * 0.35

if __name__ == '__main__':
    save('c7_stream', c7_stream()); print('c7_stream.wav')
    save('c7_breath', c7_breath()); print('c7_breath.wav')
    save('siren_far', siren_far())
    print('siren_far.wav')

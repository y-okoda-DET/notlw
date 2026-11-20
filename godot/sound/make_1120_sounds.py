# 2026-11-20 の練り直しの仮の音。make_sounds.py と同じく数式で作る（ライセンスの心配がない）。
#   python3 godot/sound/make_1120_sounds.py   → godot/sound/siren_far.wav（44.1kHz、16bit）
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

if __name__ == '__main__':
    save('siren_far', siren_far())
    print('siren_far.wav')

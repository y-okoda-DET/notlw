# 2026-11-20 の練り直しの仮の音。make_sounds.py と同じく数式で作る（ライセンスの心配がない）。
#   python3 godot/sound/make_1120_sounds.py   → godot/sound/siren_far.wav（44.1kHz、16bit）
#   c7_stream   第7章の沢の底、細い流れ（輪にして鳴らす。12秒）
#   c7_breath   第7章の沢の底、陽太の荒い息（輪にして鳴らす。11秒）
#   car_drive・car_idle・car_gravel・car_blinker・car_radio   第1章の頭、行きの車の中（car.gd）
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

# 2026-11-20 第1章の頭、行きの車の中（car.gd）。窓を閉めた小さい車の中で聞く音
def car_drive(sec=9.6):
    """走っている車の中：低いエンジンのうなり（回転で少し揺れる）と、タイヤが舗装を転がるざらつき。輪にして鳴らす"""
    n = int(sec * R); t = np.arange(n) / R
    rpm = 1.0 + 0.04 * np.sin(2 * np.pi * 0.11 * t) + 0.02 * lp_fast(rng.standard_normal(n), 0.0005, 2) / 0.02
    f0 = 31.0 * rpm
    ph = 2 * np.pi * np.cumsum(f0) / R
    eng = np.sin(ph) + 0.6 * np.sin(2 * ph + 0.3) + 0.35 * np.sin(3 * ph) + 0.15 * np.sin(4.5 * ph)
    eng = sosfilt(butter(2, 220, 'low', fs=R, output='sos'), eng) * 0.55
    road = sosfilt(butter(2, [60, 700], 'band', fs=R, output='sos'), rng.standard_normal(n)) * 0.5
    road = road * (0.85 + 0.15 * lp_fast(rng.standard_normal(n), 0.0003, 2) / 0.02)
    hiss = sosfilt(butter(2, [1200, 4000], 'band', fs=R, output='sos'), rng.standard_normal(n)) * 0.05
    # the joints in the old asphalt: a soft thump now and then under the wheels
    for _ in range(int(sec * 0.8)):
        i0 = int(rng.uniform(0, sec - 0.2) * R); m = int(0.09 * R); tt = np.arange(m) / R
        road[i0:i0 + m] += np.sin(2 * np.pi * 48 * tt) * np.exp(-tt * 40) * rng.uniform(0.3, 0.7)
    x = _loopable(eng + road + hiss)
    return x / (np.abs(x).max() + 1e-9) * 0.5

def car_idle(sec=6.4):
    """停めた車の中：アイドリング。細かい震えだけ"""
    n = int(sec * R); t = np.arange(n) / R
    f0 = 13.0 * (1.0 + 0.01 * np.sin(2 * np.pi * 0.3 * t))
    ph = 2 * np.pi * np.cumsum(f0) / R
    eng = np.sin(2 * ph) + 0.7 * np.sin(3 * ph + 0.5) + 0.4 * np.sin(4 * ph) + 0.25 * np.sin(6 * ph)
    eng = sosfilt(butter(2, 160, 'low', fs=R, output='sos'), eng)
    fan = sosfilt(butter(2, [300, 1400], 'band', fs=R, output='sos'), rng.standard_normal(n)) * 0.06   # the air from the vents
    x = _loopable(eng * 0.6 + fan)
    return x / (np.abs(x).max() + 1e-9) * 0.4

def car_gravel(sec=7.2):
    """砂利の私道を、ゆっくり上る：小石がタイヤの下で鳴る。輪にして鳴らす"""
    n = int(sec * R)
    x = sosfilt(butter(2, [80, 500], 'band', fs=R, output='sos'), rng.standard_normal(n)) * 0.4
    for _ in range(int(sec * 70)):
        i0 = int(rng.uniform(0, sec - 0.02) * R); m = int(rng.uniform(0.003, 0.012) * R); tt = np.arange(m) / R
        f = rng.uniform(900, 3000)
        x[i0:i0 + m] += np.sin(2 * np.pi * f * tt) * np.exp(-tt * 500) * rng.uniform(0.1, 0.5)
    x = sosfilt(butter(1, 2500, 'low', fs=R, output='sos'), x)   # through the floor of the car
    x = _loopable(x, 0.3)
    return x / (np.abs(x).max() + 1e-9) * 0.4

def car_blinker():
    """方向指示器の「カチ」一つ（0.4秒おきに鳴らす）"""
    m = int(0.05 * R); tt = np.arange(m) / R
    x = (np.sin(2 * np.pi * 2200 * tt) * 0.5 + rng.standard_normal(m) * 0.5) * np.exp(-tt * 260)
    x = sosfilt(butter(2, [700, 5000], 'band', fs=R, output='sos'), x)
    return np.r_[x, np.zeros(int(0.02 * R))] / (np.abs(x).max() + 1e-9) * 0.35

def car_radio(sec=8.0):
    """山に入って、ざらつきはじめるラジオ（FM の歌番組の、遠い音楽が雑音に負けていく。最後は雑音だけ）"""
    n = int(sec * R); t = np.arange(n) / R
    # a pop song far off: a few chords and a voice-like line, thin through the dash speaker
    mus = np.zeros(n)
    chords = [(261.6, 329.6, 392.0), (220.0, 261.6, 329.6), (174.6, 220.0, 261.6), (196.0, 246.9, 293.7)]
    for k in range(int(sec / 0.9) + 1):
        c = chords[k % 4]; i0 = int(k * 0.9 * R); m = min(int(0.9 * R), n - i0)
        if m <= 0: break
        tt = np.arange(m) / R; e = np.exp(-tt * 1.5)
        for f in c: mus[i0:i0 + m] += np.sin(2 * np.pi * f * tt) * e * 0.25
        mel = [523.3, 587.3, 659.3, 587.3][k % 4]
        mus[i0:i0 + m] += np.sin(2 * np.pi * mel * tt * (1 + 0.004 * np.sin(2 * np.pi * 5.5 * tt))) * 0.3 * np.minimum(1, tt * 8) * np.exp(-tt * 0.8)
    mus = sosfilt(butter(2, [300, 3000], 'band', fs=R, output='sos'), mus)
    st = sosfilt(butter(2, [400, 6000], 'band', fs=R, output='sos'), rng.standard_normal(n))
    # the signal goes: in waves, worse, then gone (about 4.5 s in: 「あ、切れた」)
    sig = np.clip(np.interp(t, [0, 2.0, 3.5, 4.4, 4.6, sec], [1.0, 0.8, 0.45, 0.25, 0.0, 0.0]) * (0.75 + 0.25 * np.sin(2 * np.pi * 1.7 * t)), 0, 1)
    x = mus * sig + st * (1.0 - sig) * 0.35 * np.interp(t, [0, 1, sec - 1.2, sec], [0.2, 0.5, 0.5, 0.0])
    return x / (np.abs(x).max() + 1e-9) * 0.4

if __name__ == '__main__':
    # 2026-11-21: car_drive・car_idle・car_gravel・car_blinker・c7_stream・c7_breath・siren_far は本物の音に替えた（cut_1121.py）。
    # ここで作り直すと .wav が .ogg より先に読まれて戻ってしまうので、作るのは car_radio だけ
    save('car_radio', car_radio()); print('car_radio.wav')

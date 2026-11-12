"""ステップ E：ユーザーが選んだ素材（/mnt/project-files/音/素材_2026-11-12/、入手先は docs/素材とアドオン.md）から、
ゲームで鳴らす仮の音を切り出す。選んだ理由は docs/決定事項.md 2026-11-12〜13。
  python3 godot/sound/cut_materials.py      （ffmpeg、numpy、scipy、soundfile が要る）
切る場所は、波形の強さ（0.25秒・0.05秒ごと）で Claude が選んだ。耳での良し悪しはユーザー。
  雨       gentle-rain-01（10分）の 60〜210 秒、窓越し（2.5kHz より上を落とし、高い音を -6dB）、つなぎ目は 3 秒重ね → rain.ogg
  発電機   「本命」：綱を引く（空回り）0.6〜2.2、咳 14.8〜17.4、かかる 23.8〜27.0、回る 26〜55（つなぐ）、止まる 55.6〜56.5
           （最後のポロポロは切る：ユーザー「切りたい」）。freesound の generator を、上の階で聞こえる遠い唸りに（400Hz より上を落とす）
  雷       thunder_02 の頭 0〜8 秒（「もう少しスポット的に」）、「雷雨」の単発 44〜50 秒・52.4〜58 秒
  足音     「木足音２」から一歩ずつ（靴下の小さい足音）、「きしみ足音２」からきしむ一歩、「きしみ足音」は階段
  停電     ブレーカーの「パチッ」だけ（1.6〜1.9 秒）
"""
import os, subprocess, tempfile
import numpy as np, soundfile as sf
from scipy.signal import butter, sosfilt

SRC = "/mnt/project-files/音/素材_2026-11-12/"
OUT = os.path.dirname(os.path.abspath(__file__)) + "/"
SR = 48000

def load(name, mono=True):
    with tempfile.TemporaryDirectory() as d:
        w = d + "/a.wav"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", SRC + name, "-ar", str(SR)] + (["-ac", "1"] if mono else ["-ac", "2"]) + [w], check=True)
        x, _ = sf.read(w)
    return x

def cut(x, a, b, fi=0.005, fo=0.05):
    y = x[int(a * SR):int(b * SR)].copy()
    n1, n2 = int(fi * SR), int(fo * SR)
    r1 = np.linspace(0, 1, n1); r2 = np.linspace(1, 0, n2)
    if y.ndim == 2: r1 = r1[:, None]; r2 = r2[:, None]
    if n1: y[:n1] *= r1
    if n2: y[-n2:] *= r2
    return y

def peak(y, db=-3.0):
    return y / (np.abs(y).max() + 1e-9) * 10 ** (db / 20)

def rms(y, db=-20.0):
    return y / (np.sqrt(np.mean(y ** 2)) + 1e-9) * 10 ** (db / 20)

def loop(y, ov=3.0):
    """the end fades into the start: a loop with no seam"""
    n = int(ov * SR)
    a = y[:-n].copy(); t = y[-n:]
    r = np.linspace(0, 1, n)
    if y.ndim == 2: r = r[:, None]
    a[:n] = a[:n] * r + t * (1 - r)
    return a

def lp(y, f, order=4):
    return sosfilt(butter(order, f, "low", fs=SR, output="sos"), y, axis=0)

def high_shelf(y, f, db):
    hi = y - lp(y, f, 2)
    return y + hi * (10 ** (db / 20) - 1)

def save(name, y):
    sf.write(OUT + name + ".wav", np.clip(y, -1, 1), SR, subtype="PCM_16"); print(name, "%.2f s" % (len(y) / SR))

def save_ogg(name, y):
    with tempfile.TemporaryDirectory() as d:
        w = d + "/a.wav"; sf.write(w, np.clip(y, -1, 1), SR, subtype="PCM_16")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", w, "-c:a", "libvorbis", "-q:a", "4", OUT + name + ".ogg"], check=True)
    print(name, "%.2f s (ogg)" % (len(y) / SR))

def onsets(x, a, b, thr_db, gap=0.3):
    """the start of each step: where the 5 ms level jumps over thr_db"""
    n = int(0.005 * SR); seg = x[int(a * SR):int(b * SR)]
    e = 20 * np.log10(np.sqrt(np.convolve(seg ** 2, np.ones(n) / n, "same")) + 1e-9)
    out = []; last = -1e9
    for i in range(0, len(e), n):
        if e[i] > thr_db and (i - last) / SR > gap: out.append(a + i / SR - 0.01); last = i
    return out

# --- 雨（窓越し）
r = load("dragon-studio-gentle-rain-01-437305.mp3", mono=False)
r = r[60 * SR:213 * SR]
r = high_shelf(lp(r, 2500.0, 4), 1200.0, -6.0)
save_ogg("rain", rms(loop(r), -22.0))

# --- 発電機
g = load("発電機使えるかも本命.mp3")
save("gen_pull", peak(cut(g, 0.6, 2.2, fo=0.3)))
save("gen_cough", peak(cut(g, 14.8, 17.4, fo=0.4)))
save("gen_start", peak(cut(g, 23.8, 27.0, fo=0.02)))
save_ogg("generator", rms(loop(g[26 * SR:55 * SR], 2.0), -18.0))
save("generator_stop", peak(cut(g, 55.6, 56.5, fo=0.35)))
f = load("発電機freesound_community-generator-54426.mp3")
save_ogg("generator_far", rms(loop(lp(f[2 * SR:70 * SR], 400.0), 3.0), -20.0))

# --- 雷
t2 = load("VSQSE_0988_thunder_02.mp3", mono=False)
save("thunder1", peak(cut(t2, 0.0, 8.0, fi=0.02, fo=2.5)))
tr = load("雷雨.mp3", mono=False)
save("thunder2", peak(cut(tr, 44.0, 50.0, fi=0.05, fo=2.0)))
save("thunder3", peak(cut(tr, 52.4, 58.0, fi=0.05, fo=2.0)))

# --- 足音
w = load("木足音２.mp3")
on = onsets(w, 0.5, 23.5, -42.0, 0.35)
for i, s in enumerate(on[:10]): save("step%d" % (i + 1), peak(cut(w, s, s + 0.32, fo=0.12), -6.0))
c = load("きしみ足音２.mp3")
on = onsets(c, 2.0, 30.0, -24.0, 0.8)
for i, s in enumerate(on[:4]): save("creak%d" % (i + 1), peak(cut(c, s, s + 0.7, fo=0.25), -6.0))
st = load("きしみ足音.mp3")
save("stair1", peak(cut(st, 0.55, 1.4, fo=0.2), -6.0))
save("stair2", peak(cut(st, 1.9, 2.75, fo=0.2), -6.0))

# --- 停電：ブレーカーの「パチッ」
b = load("停電使えるかもブレーカー落ち.mp3")
save("breaker", peak(cut(b, 1.6, 1.9, fi=0.002, fo=0.1), -3.0))

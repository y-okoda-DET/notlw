"""第7章「去年の夏」の音（2026-11-19）。届いている素材（/mnt/project-files/ の直下、入手先とライセンスは docs/素材とアドオン.md）から切る。
  python3 godot/sound/cut_ch7.py      （ffmpeg、numpy、scipy、soundfile が要る）
切る場所は波形の強さで Claude が選んだ（耳での良し悪しはユーザー）。

  c7_crickets.ogg  夜の虫の声（輪）。去年の夜は晴れで、嵐の音は無い
  c7_slip.wav      砂利と土で足を滑らせる（falling-in-dirt の頭に砂利の一歩）
  c7_pencil.wav    鉛筆で書く（絵コンテのコマ3を描き足す）
  c7_slap.wav      手のひらで窓ガラスを叩く（ユーザーの録音「窓を叩く_新規録音51」の2打に、数式の低い当たりを下に敷いた）
まだ無い物（素材待ち。鳴らす口は ch7.gd にある）：c7_scream（澪の短い悲鳴）、c7_laugh・c7_voices（扉の向こうの声と笑い声）、
  c7_party（外から聞く飲み会のざわめき）、c7_higurashi（夕方のひぐらし）
"""
import os, subprocess, tempfile
import numpy as np, soundfile as sf
from scipy.signal import butter, sosfilt

M = "/mnt/project-files/"
OUT = os.path.dirname(os.path.abspath(__file__)) + "/"
SR = 48000

def load(path):
    with tempfile.TemporaryDirectory() as d:
        w = d + "/a.wav"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", path, "-ar", str(SR), "-ac", "1", w], check=True)
        x, _ = sf.read(w)
    return x

def cut(x, a, b, fi=0.005, fo=0.05):
    y = x[int(a * SR):int(b * SR)].copy()
    n1, n2 = int(fi * SR), int(fo * SR)
    if n1: y[:n1] *= np.linspace(0, 1, n1)
    if n2: y[-n2:] *= np.linspace(1, 0, n2)
    return y

def peak(y, db=-3.0):
    return y / max(1e-9, np.abs(y).max()) * 10 ** (db / 20)

def filt(y, lo=None, hi=None, order=2):
    if lo: y = sosfilt(butter(order, lo, 'hp', fs=SR, output='sos'), y)
    if hi: y = sosfilt(butter(order, hi, 'lp', fs=SR, output='sos'), y)
    return y

def loud(x, win=0.05):
    n = int(win * SR); m = len(x) // n
    return np.sqrt((x[:m * n].reshape(m, n) ** 2).mean(1))

def save(name, y, ogg=False):
    if ogg:
        with tempfile.TemporaryDirectory() as d:
            sf.write(d + "/a.wav", y, SR)
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", d + "/a.wav", "-c:a", "libvorbis", "-q:a", "5", OUT + name + ".ogg"], check=True)
    else: sf.write(OUT + name + ".wav", y, SR, subtype="PCM_16")
    print("%-14s %.2f s  peak %.2f" % (name, len(y) / SR, np.abs(y).max()))

# the crickets: 40 s of the field, its end crossed into its start (2 s) so the loop has no seam
x = load(M + "freesound_community-ambience-night-field-cricket-01-7015.mp3")
a, L, X = 8.0, 40.0, 2.0
y = x[int(a * SR):int((a + L + X) * SR)].copy()
n = int(X * SR); k = np.linspace(0, 1, n)
y[:n] = y[:n] * np.sqrt(k) + y[-n:] * np.sqrt(1 - k); y = y[:-n]
save("c7_crickets", peak(filt(y, lo=180), -9.0), ogg=True)

# the slip: one step on gravel that goes, then the fall in the dirt
g = load(M + "dragon-studio-footsteps-on-gravel-1-397987.mp3")
e = loud(g); i = int(np.argmax(e)); g1 = cut(g, max(0.0, i * 0.05 - 0.1), i * 0.05 + 0.45, fo=0.15)
f = load(M + "freesound_community-falling-in-dirt-87202.mp3")
f1 = cut(f, 0.0, min(2.6, len(f) / SR), fo=0.4)
y = np.zeros(int(0.25 * SR) + len(f1)); y[:len(g1)] += peak(g1, -6.0)[:len(y)]; y[int(0.25 * SR):] += peak(f1, -3.0)
save("c7_slip", peak(y, -2.0))

# the pencil: the busiest 3 seconds
p = load(M + "freesound_community-writing-with-pencil-on-paper-68981.mp3")
e = loud(p, 0.1); w = 30; s = np.convolve(e, np.ones(w), 'valid'); i = int(np.argmax(s))
save("c7_pencil", peak(cut(p, i * 0.1, i * 0.1 + 3.0, fi=0.05, fo=0.4), -6.0))

# the palm on the pane (a stand-in): two palms a few ms apart; a low thud, the pane's short buzz in its frame
rng = np.random.default_rng(7)
def palm(t0):
    t = np.arange(int(0.6 * SR)) / SR
    thud = np.sin(2 * np.pi * (95 * t + 30 * np.exp(-t * 40) / 40)) * np.exp(-t * 22)
    skin = filt(rng.standard_normal(len(t)), lo=700, hi=3800) * np.exp(-t * 120) * 0.5
    buzz = np.sin(2 * np.pi * 212 * t) * np.sin(2 * np.pi * 31 * t) ** 2 * np.exp(-t * 9) * 0.35
    rattle = filt(rng.standard_normal(len(t)), lo=2500, hi=7000) * np.exp(-t * 16) * (np.sin(2 * np.pi * 58 * t) > 0.3) * 0.12
    y = thud + skin + buzz + rattle
    out = np.zeros(int(0.8 * SR)); a0 = int(t0 * SR); out[a0:a0 + len(y)] += y[:len(out) - a0]
    return out
# on top of it, the user's own recording of a window being hit (16 kHz, quiet: its two loudest hits, one for each hand).
# The recording gives the real pane's knock; the stand-in under it gives the palm's weight that the phone did not catch
wr = load(M + "音/素材_2026-11-17/窓を叩く_新規録音51.m4a")
def hit(t):
    y = np.zeros(int(0.8 * SR)); c = cut(wr, t - 0.012, t + 0.45, fi=0.004, fo=0.2); y[:len(c)] = c
    return peak(y, 0.0)
h2 = np.roll(hit(8.11), int(0.028 * SR))
save("c7_slap", peak(0.55 * peak(palm(0.0) + 0.85 * palm(0.028), 0.0) + 0.8 * (hit(5.32) + 0.85 * h2), -1.5))

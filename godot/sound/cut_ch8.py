"""監督（2時、旧第8章）の外の音。ユーザーが揃えた素材から切る（出どころとライセンスは docs/素材とアドオン.md「監督の章の音」）。
  python3 godot/sound/cut_ch8.py      （ffmpeg、numpy、scipy、soundfile が要る）
切る場所は、波形の強さで Claude が選んだ（耳での良し悪しはユーザー）。カメラのマイクで録った音なので、どれも片耳（モノ）で、低い所は落としてある。

  rain_out.ogg       外の雨（kanematsutei heavy-rain 5〜41 秒）。家の中の rain.ogg は窓越しにこもらせた物なので、外では使えない
  ch8_wind.ogg       カメラのマイクに当たる風（freesound_community wind-on-microphone 4〜40 秒）
  ch8_slide.wav      路肩が崩れる：砂利の一歩 → 石が落ちる → 土に落ちる
  ch8_scramble.wav   斜面を下りてくる（砂利を急いで歩く＋小石）。遠く、上から
  ch8_steps_away.wav 斜面を上がっていく足音（ぬかるみ）。だんだん遠く
"""
import os, subprocess, tempfile
import numpy as np, soundfile as sf
from scipy.signal import butter, sosfilt, resample_poly

P = "/mnt/project-files/"
D1 = P + "音/素材_2026-11-17/"
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

def peak(y, db=-3.0): return y / (np.abs(y).max() + 1e-9) * 10 ** (db / 20)
def rms(y, db=-20.0): return y / (np.sqrt(np.mean(y ** 2)) + 1e-9) * 10 ** (db / 20)
def lp(y, f, order=4): return sosfilt(butter(order, f, "low", fs=SR, output="sos"), y)
def hp(y, f, order=2): return sosfilt(butter(order, f, "high", fs=SR, output="sos"), y)
def faster(y, f): return resample_poly(y, 100, int(round(100 * f)))

def loop(y, ov=3.0):
    n = int(ov * SR); a = y[:-n].copy(); t = y[-n:]; r = np.linspace(0, 1, n)
    a[:n] = a[:n] * r + t * (1 - r)
    return a

def mix(n_sec, parts):
    """parts: (at 秒, 音, 倍率)"""
    out = np.zeros(int(n_sec * SR))
    for at, y, g in parts:
        i = int(at * SR); y = y[:max(0, len(out) - i)]; out[i:i + len(y)] += y * g
    return out

def save(name, y):
    sf.write(OUT + name + ".wav", np.clip(y, -1, 1), SR, subtype="PCM_16"); print(name, "%.2f s" % (len(y) / SR))

def save_ogg(name, y):
    with tempfile.TemporaryDirectory() as d:
        w = d + "/a.wav"; sf.write(w, np.clip(y, -1, 1), SR, subtype="PCM_16")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", w, "-c:a", "libvorbis", "-q:a", "4", OUT + name + ".ogg"], check=True)
    print(name, "%.2f s (ogg)" % (len(y) / SR))

# ---- 輪
rain = load(D1 + "kanematsutei-heavy-rain-144282.mp3")
save_ogg("rain_out", rms(loop(hp(cut(rain, 5.0, 41.0, fi=0, fo=0), 120.0)), -21.0))
wind = load(P + "freesound_community-wind-on-microphone-22410.mp3")
save_ogg("ch8_wind", rms(loop(lp(cut(wind, 4.0, 40.0, fi=0, fo=0), 1800.0)), -24.0))

# ---- 一回の音
step = load(P + "dragon-studio-footsteps-on-gravel-1-397987.mp3")
stones = load(P + "freesound_community-stones-falling-6375.mp3")
dirt = load(P + "freesound_community-falling-in-dirt-87202.mp3")
gravel = load(P + "audiopapkin-walking-on-gravel-version-2-308744.mp3")
puddle = load(P + "freesound_community-squishy-footsteps-to-walking-in-a-puddle-64403.mp3")

# 崩れる：足もとが抜ける一歩（0.0）、石（0.12〜）、体が土に落ちる（1.5）、遅れて小石（2.6〜）
s1 = peak(cut(step, 0.0, 0.7, fo=0.2), -6)
st = peak(cut(stones, 0.0, 3.0, fi=0.02, fo=1.2), -3)
dr = peak(cut(dirt, 0.4, 2.3, fo=0.4), -1)
tail = peak(lp(cut(stones, 1.0, 3.2, fi=0.3, fo=1.5), 2500.0), -14)
save("ch8_slide", peak(mix(5.4, [(0.0, s1, 1.0), (0.12, st, 0.8), (1.5, dr, 1.0), (2.6, tail, 1.0)]), -2))

# 下りてくる：砂利を急いで（1.25倍速）、こもらせて遠く。途中で小石が二度
g = faster(cut(gravel, 18.0, 26.5, fi=0.4, fo=0.8), 1.25)
peb = peak(lp(cut(stones, 0.3, 1.6, fi=0.05, fo=0.7), 3000.0), -12)
sc = mix(len(g) / SR, [(0.0, peak(lp(g, 3500.0), -6), 1.0), (2.1, peb, 1.0), (4.6, peb, 0.7)])
sc *= np.linspace(0.45, 1.0, len(sc))   # 近づいてくる
save("ch8_scramble", peak(sc, -5))

# 上がっていく：ぬかるみの足音、だんだん遠く（小さく、こもる）
u = cut(puddle, 1.0, 13.0, fi=0.2, fo=2.0)
near = peak(u, -6); far = peak(lp(u, 1400.0), -6)
r = np.linspace(0, 1, len(u)) ** 0.7
save("ch8_steps_away", peak((near * (1 - r) + far * r) * np.linspace(1.0, 0.12, len(u)), -6))

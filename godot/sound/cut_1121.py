"""2026-11-21 音の当て（ユーザー「まだの物も取り込む」）。音の洗い出しのスレッドの取捨（docs/資料/当てる音_2026-11-20.md）で ○ になった物を切って、
ゲームの音の名前に当てる。仮の音（数式）と置き換える物と、鳴らす口だけあった物を埋める物。
  python3 godot/sound/cut_1121.py      （ffmpeg、numpy、scipy、soundfile が要る）
入手先とライセンスは docs/素材とアドオン.md。Krotos の原本は共有フォルダの 音/手持ち_2026-11-21/ にだけ置き、ここでは切った物だけを作る。
声は基本入れない（決定 2026-11-21）：言葉にならない声（悲鳴、息、笑い声のざわめき）は効果音として扱う。笑い声は扉越しにこもらせ、言葉は取れない。
切る場所は波形の強さで Claude が選んだ（耳での良し悪しはユーザー）。

  置き換え：car_drive（Krotos の砂利の車内＋前の唸りを薄く）、car_gravel、car_idle、car_blinker、siren_far（日本の救急車、遠く）、
            ch3_rattle（木の戸のがたつき）、c7_stream（夜の細い沢）、c7_breath（荒い息）、body_fall（木の床に倒れる）
  埋める　：c7_scream、c7_laugh、c7_voices、c7_chuckle、c7_party、c7_higurashi
  新しい　：batt_cover（第6章 カメラの電池の蓋）、dawn_bird（第6章 鳥が一声）、candle_out（第6章 ろうそくが消える）、
            cam_zoom（第8章 桐生のカメラのズーム）、shutter_slam（第2章20時 すぐ横の雨戸）
"""
import os, subprocess, tempfile
import numpy as np, soundfile as sf
from scipy.signal import butter, sosfilt

M = "/mnt/project-files/"
S21 = M + "音/素材_2026-11-21/"
KR = M + "音/手持ち_2026-11-21/Krotos/"
WR = M + "音/手持ち_2026-11-21/WrongRoom/"
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

def loudest(x, length, win=0.05):
    """the start (s) of the loudest stretch of this length"""
    l = loud(x, win); k = max(1, int(length / win))
    c = np.convolve(l, np.ones(k), 'valid')
    return float(np.argmax(c)) * win

def loopify(y, X=1.5):
    n = int(X * SR); k = np.linspace(0, 1, n)
    y = y.copy(); y[:n] = y[:n] * np.sqrt(k) + y[-n:] * np.sqrt(1 - k)
    return y[:-n]

def room(y, wet=0.25, ms=(23, 41, 67)):
    """a little of a room (behind a door): three short echoes"""
    z = y.copy()
    for i, d in enumerate(ms):
        n = int(d / 1000 * SR); z[n:] += y[:-n] * wet * (0.7 ** i)
    return z

def save(name, y, ogg=False):
    for ext in (".wav", ".ogg"):   # the old one of the other kind goes (sound.gd takes .wav first)
        p = OUT + name + ext
        if os.path.exists(p) and ext != (".ogg" if ogg else ".wav"): os.remove(p); print("  removed", name + ext)
    if ogg:
        with tempfile.TemporaryDirectory() as d:
            sf.write(d + "/a.wav", y, SR)
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", d + "/a.wav", "-c:a", "libvorbis", "-q:a", "5", OUT + name + ".ogg"], check=True)
    else: sf.write(OUT + name + ".wav", y, SR, subtype="PCM_16")
    print("%-14s %.2f s  peak %.2f" % (name, len(y) / SR, np.abs(y).max()))

# ---- the drive (car.gd). The i3 is electric: no engine, so the old hum (made) goes under it, low
import sys; sys.path.insert(0, OUT)
import make_1120_sounds as m1120   # the old made hum (its own sample rate)
old = np.asarray(m1120.car_drive(), float); sr0 = m1120.R
old = np.interp(np.arange(int(len(old) * SR / sr0)) / SR, np.arange(len(old)) / sr0, old)
x = load(KR + "BMW I3 GRAVEL DRIVE SLOW SPEED INTERIOR.wav")
y = loopify(cut(x, 10.0, 52.0, 0.3, 0.3), 2.0)
if old is not None:
    o = np.tile(old, int(np.ceil(len(y) / len(old))))[:len(y)]
    y = peak(y, -6.0) + peak(filt(o, hi=300), -16.0)
save("car_drive", peak(filt(y, lo=30), -4.0), ogg=True)
x = load(KR + "BMW I3 GRAVEL AND ASPHALT DRIVE AND STOP INTERIOR.wav")
a = loudest(x, 6.0)
save("car_gravel", peak(filt(cut(x, a, a + 6.0, 0.3, 0.8), lo=30), -5.0))
x = load(KR + "BMW I3 GRAVEL SHORT DRIVE 40 KPH TO STOP INTERIOR.wav")
L = len(x) / SR   # the stop is at its end: the last quiet seconds, the tyres gone
y = loopify(cut(x, L - 9.0, L - 0.5, 0.5, 0.5), 1.5)
save("car_idle", peak(filt(y, lo=30), -14.0), ogg=True)
x = load(M + "freesound_community-car-turn-signal-blinker-left-and-right-105622.mp3")
a = loudest(x, 2.04)
save("car_blinker", peak(cut(x, a, a + 2.04, 0.002, 0.01), -10.0))

# ---- 21時: the ambulance, far, through the walls and the storm
x = load(S21 + "Ambulance-Siren03-3Far.mp3")
save("siren_far", peak(filt(cut(x, 0.0, len(x) / SR, 0.8, 2.5), lo=200, hi=2200, order=3), -6.0))

# ---- 3時: the back door in the wind (two shakes of a wooden door)
x = load(M + "freesound_community-door-rattles-wood-2011-94336.mp3")
save("ch3_rattle", peak(filt(cut(x, 0.0, len(x) / SR, 0.01, 0.3), lo=60), -4.0))

# ---- 第4章: she falls onto the wooden floor
x = load(KR + "Fall Wood Body Close-001.wav")
save("body_fall", peak(filt(x, lo=40), -2.0))

# ---- 第7章
x = load(S21 + "dragon-studio-creek-trickling-calmly-478387.mp3")
save("c7_stream", peak(filt(loopify(cut(x, 1.0, 31.0, 0.3, 0.3), 2.0), lo=90), -9.0), ogg=True)
x = load(S21 + "ribhavagrawal-heavy-breathing-sound-effect-type-02-294195.mp3")
x = np.clip(x, -0.98, 0.98)
save("c7_breath", peak(filt(cut(x, 0.3, min(7.8, len(x) / SR), 0.2, 0.4), lo=120, hi=9000), -8.0))
x = load(S21 + "universfield-scared-woman-scream-191977.mp3")
save("c7_scream", peak(filt(x, lo=150), -4.0))
x = load(S21 + "u_879x48oguz-group-of-friends-joking-and-laughing-300997.mp3")
door = lambda y: room(filt(y, lo=180, hi=1400, order=3), 0.3)   # through a door: the words go, the laughing stays
L = len(x) / SR
save("c7_voices", peak(door(cut(x, 0.0, L, 0.3, 0.6)), -12.0))
a = loudest(x, 2.2)
save("c7_laugh", peak(door(cut(x, a, a + 2.2, 0.02, 0.4)), -9.0))
a2 = loudest(x[:int(max(0.0, a - 1.0) * SR)], 1.0) if a > 2.0 else min(L - 1.2, a + 3.0)
save("c7_chuckle", peak(door(cut(x, a2, a2 + 1.0, 0.02, 0.3)), -15.0))
x = load(M + "freesound_community-london-pub-ambience-19695.mp3")
y = loopify(cut(x, 120.0, 166.0, 0.5, 0.5), 3.0)
save("c7_party", peak(room(filt(y, lo=150, hi=1100, order=3), 0.25), -14.0), ogg=True)
x = load(S21 + "higurashi_opentracks.mp3")
save("c7_higurashi", peak(filt(loopify(cut(x, 0.5, 31.5, 0.3, 0.3), 2.5), lo=1200), -10.0), ogg=True)

# ---- 第6章
x = load(S21 + "freesound_community-opening-and-closing-remote-control-battery-cover-96496.mp3")
a = loudest(x, 0.6)
y1 = cut(x, a, a + 0.6, 0.002, 0.08)
x2 = load(S21 + "arunangshubanerjee-removing-two-aa-batteries-from-remote-330041.mp3")
b = loudest(x2, 1.0)
y = np.concatenate([y1, np.zeros(int(0.15 * SR)), cut(x2, b, b + 1.0, 0.002, 0.1)])
save("batt_cover", peak(filt(y, lo=200), -6.0))
x = load(M + "ollie53-bird-chirping-sound-415216.mp3")
a = loudest(x, 1.2)
save("dawn_bird", peak(filt(cut(x, a, a + 1.2, 0.02, 0.3), lo=1500), -6.0))
x = load(M + "kai_audio-candle-blow-out-446030.mp3")
a = loudest(x, 0.9)
save("candle_out", peak(filt(cut(x, a, a + 0.9, 0.01, 0.3), lo=120), -12.0))

# ---- 第8章: Kiryu's zoom (the small motor)
x = load(S21 + "Camera-Lens01-3.mp3")
a = loudest(x, 0.8)
save("cam_zoom", peak(filt(cut(x, a, a + 0.8, 0.01, 0.15), lo=300), -10.0))

# ---- 第2章 20時: the shutter beside her, slammed (ジャンプスケア①)
x = load(WR + "PMH_Knock_WindowSlam_01.wav")
save("shutter_slam", peak(filt(cut(x, 0.0, len(x) / SR, 0.002, 0.4), lo=50), -1.0))

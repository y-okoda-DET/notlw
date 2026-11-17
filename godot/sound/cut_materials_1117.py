"""試作127（ユーザー「新しく揃えた音入ってる？この段階で入れておいてほしい」）：2026-11-17 に届いた素材
（/mnt/project-files/音/素材_2026-11-17/ と _2/、選んだ物と理由は /mnt/project-files/素材の不足/音の取捨選択_2026-11-17.md の ○、
入手先とライセンスは docs/素材とアドオン.md）から、いまゲームにある音の口に入れる音を切り出す。数式で作った仮の音を置き換える物と、
新しく鳴らす物がある。
  python3 godot/sound/cut_materials_1117.py      （ffmpeg、numpy、scipy、soundfile が要る）
切る場所は、波形の強さ（0.01秒ごと）で Claude が選んだ（耳での良し悪しはユーザー）。

  置き換える：car_door（車のドアの開け閉め一組。第0章・第3章。ユーザー「車、ラジオの音、変。車のドアの音が鳴るとかでいいんじゃない？」）、
    car_arrive（来て止まる）、door_open（木の扉がゆっくり開く）、ch3_lock・lock（玄関の鍵。22時と2時）、ch3_tape（布テープを引いて貼る）、
    ch3_thud（人が倒れる、地下からのこもった音）、ch3_bar（閂。板の一打を低く）、ch3_blanket（毛布）、
    ch3_gap1〜5・ch3_gapfront（隙間風。barn_wind の別々の所をつないで輪に）
  新しく：tape_rip（第5章 テープをはがす）、swing（第4章 三脚を振る）、hit（第4章 命中。候補_2026-11-13/照準の命中.wav）、
    body_fall（第4章 夏希が倒れる、木の床）、tripod_bump（第4章 澪の手が三脚に当たる）、door_close（木の扉が閉まる）、
    cassette_in（第3章 0時 定点のテープを替える）
"""
import os, subprocess, tempfile
import numpy as np, soundfile as sf
from scipy.signal import butter, sosfilt, resample_poly

D1 = "/mnt/project-files/音/素材_2026-11-17/"
D2 = "/mnt/project-files/音/素材_2026-11-17_2/"
CAND = "/mnt/project-files/音/候補_2026-11-13/"
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
    return y / (np.abs(y).max() + 1e-9) * 10 ** (db / 20)

def lp(y, f, order=4):
    return sosfilt(butter(order, f, "low", fs=SR, output="sos"), y)

def hp(y, f, order=2):
    return sosfilt(butter(order, f, "high", fs=SR, output="sos"), y)

def loop(y, ov=1.5):
    n = int(ov * SR)
    a = y[:-n].copy(); t = y[-n:]
    r = np.linspace(0, 1, n)
    a[:n] = a[:n] * r + t * (1 - r)
    return a

def lower(y, f=0.8):
    """played slower: lower and heavier (f < 1)"""
    return resample_poly(y, 100, int(round(100 * f)))

def save(name, y):
    sf.write(OUT + name + ".wav", np.clip(y, -1, 1), SR, subtype="PCM_16"); print(name, "%.2f s" % (len(y) / SR))

# ---- 置き換え
cd = load(D1 + "freesound_community-car-door-open-and-close-72752.mp3")
save("car_door", peak(cut(cd, 14.25, 17.6, fo=0.3), -3))                       # 開けて（14.46）、閉める（16.85）
ca = load(D1 + "freesound_community-cararriveandstop-6191.mp3")
save("car_arrive", peak(cut(ca, 7.0, 15.4, fi=1.0, fo=0.5), -3))                  # 近づいて、14.5 で止まる（第0章の車は 7 秒で止まる）
do = load(D1 + "yodguard-door-opening-slowly-1-535465.mp3")
save("door_open", peak(lower(cut(do, 0.0, 1.0, fo=0.15), 0.85), -4))            # 玄関は少し低く重く（取捨選択の表）
lk = load(D2 + "strachszydlo-locking-and-unlocking-door-with-key-546882.mp3")
lock = peak(cut(lk, 3.62, 4.45, fo=0.08), -3)                                     # 鍵を回して、かかる
save("ch3_lock", lock); save("lock", lock)
tp = load(D1 + "freesound_community-duct-tape-sounds-sticky-tension-63674.mp3")
save("ch3_tape", peak(cut(tp, 16.55, 17.45, fo=0.12), -4))                       # 引き出して、貼る
bf = load(D1 + "freesound_community-body-fall-47877.mp3")
save("ch3_thud", peak(lp(cut(bf, 0.25, 1.6, fo=0.3), 1500), -3))                 # こもった物（地下の扉越し）
wh = load(D1 + "sumaga123-wood-hit-432148.mp3")
save("ch3_bar", peak(lower(cut(wh, 0.65, 1.3, fo=0.12), 0.75), -4))             # 閂：板の一打を低く
bl = load(D1 + "zenosounds-blanket-rustle-625141.mp3")
save("ch3_blanket", peak(cut(bl, 7.1, 7.85, fo=0.15), -6))
wd = load(D2 + "freesound_community-barn_wind_004-49157.mp3")
for i, (name, a) in enumerate([("ch3_gap1", 20.0), ("ch3_gap2", 45.0), ("ch3_gap3", 70.0), ("ch3_gap4", 95.0), ("ch3_gap5", 120.0), ("ch3_gapfront", 140.0)]):
    y = hp(cut(wd, a, a + 9.5, fi=0.05, fo=0.05), 180)
    if name == "ch3_gap4": y = hp(y, 600)                                         # 換気口：細く高い
    save(name, peak(loop(y), -4))

# ---- 新しく
rp = load(D2 + "kai_audio-duct-tape-rip-471490.mp3")
save("tape_rip", peak(cut(rp, 5.62, 6.5, fo=0.1), -3))
sw = load(D1 + "freesound_community-metal-pipe-swing-1-47741.mp3")
save("swing", peak(cut(sw, 0.7, 1.35, fo=0.12), -4))
save("hit", peak(load(CAND + "照準の命中.wav"), -3))
fi_ = load(D1 + "tripod-universfield-character-fall-impact-352287.mp3")
save("body_fall", peak(cut(fi_, 0.28, 1.6, fo=0.3), -3))
tl = load(D2 + "freesound_community-tripod-legs-unfolding-and-folding-75912.mp3")
save("tripod_bump", peak(cut(tl, 1.15, 1.6, fo=0.1), -5))
dc = load(D2 + "木の扉が閉まる_door-open-close-45475_後半.wav")
save("door_close", peak(dc, -3))
ci = load(D1 + "soundreality-tape-cassette-insert-172758.mp3")
save("cassette_in", peak(cut(ci, 0.0, 0.75, fo=0.1), -4))

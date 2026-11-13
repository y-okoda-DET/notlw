"""ステップ E：ラジオの3局と、ダイヤルを回す音（ユーザー決定 2026-11-13「この三種で」、docs/決定事項.md）。
  python3 godot/sound/cut_radio.py      （ffmpeg、numpy、scipy、soundfile が要る）
聞こえ方は /mnt/project-files/音/ラジオ加工_2026-11-13/選局の通し_トークなし_ダイヤル音つき_作り方.py と同じ作り方で、
ゲームの側（scripts/sound.gd）で混ぜられるように、局ごとに2本の繰り返しを作る：
  radio_<局>.ogg      合ったときの音（AM の帯域 300〜3000Hz）
  radio_<局>_muf.ogg  近いが外れているときの、こもった唸り（300〜1100Hz）。音の大きさは合ったときの物にそろえる
局：music（594、ユーザーの「claudehop」88BPM の16小節＝43.64秒、2.39秒から）、foreign（1350、韓国語の天気予報、
後ろに1.5秒の間）、news（1017、ユーザーのリテイク待ち。それまでは make_sounds.py の radio_voice を仮に）。
ダイヤルの音（部屋で鳴る、ラジオを通らない）：dial_rustle.wav（擦れる音の繰り返し）と dial_tick.wav（3kHz 回すごとの小さな刻み）。
"""
import os, subprocess, tempfile
import numpy as np, soundfile as sf
from scipy.signal import butter, sosfilt

SRC = "/mnt/project-files/音/ラジオ加工_2026-11-13/"
OUT = os.path.dirname(os.path.abspath(__file__)) + "/"
SR = 48000
AM = butter(4, [300, 3000], "bandpass", fs=SR, output="sos")
MUF = butter(4, [300, 1100], "bandpass", fs=SR, output="sos")

def load(path):
    with tempfile.TemporaryDirectory() as d:
        w = d + "/a.wav"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", path, "-ar", str(SR), "-ac", "1", w], check=True)
        x, _ = sf.read(w)
    return x

def norm(x, to=0.1):
    """the recipe's level: the mean of the louder half of 0.1 s blocks"""
    b = x[:len(x) // 4800 * 4800].reshape(-1, 4800); r = np.sqrt((b ** 2).mean(1))
    return x / (r[r > np.percentile(r, 50)].mean() + 1e-9) * to

def ogg(name, y):
    with tempfile.TemporaryDirectory() as d:
        w = d + "/a.wav"; sf.write(w, np.clip(y, -1, 1), SR, subtype="PCM_16")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", w, "-c:a", "libvorbis", "-q:a", "3", OUT + name + ".ogg"], check=True)
    print(name, "%.2f s" % (len(y) / SR))

def station(name, x):
    # run the filters over the loop twice so the start already carries the end's tail (no click at the seam)
    two = np.concatenate([x, x])
    raw = sosfilt(AM, two)[len(x):]
    clear = norm(raw) * 2.0
    muf = sosfilt(MUF, two)[len(x):] * (np.std(clear) / (np.std(raw) + 1e-12))
    ogg("radio_" + name, np.tanh(1.6 * clear) / 1.6)
    ogg("radio_" + name + "_muf", np.tanh(1.6 * muf) / 1.6)

m = load(SRC + "音楽_元.wav")
a = int(2.39 * SR); n = int(round(16 * 4 * 60 / 88 * SR))
loop = m[a:a + n].copy(); tail = m[a + n:a + n + int(1.5 * SR)]
loop[:len(tail)] += tail                 # the last bar's ring carries over into the first
station("music", loop)
f = load(SRC + "外国語_元.mp3")
station("foreign", np.concatenate([f, np.zeros(int(1.5 * SR))]))
news = SRC + "ニュース_元.wav"
station("news", load(news) if os.path.exists(news) else load(OUT + "radio_voice.wav"))

rng = np.random.default_rng(7)
fr = sosfilt(butter(2, [1500, 7000], "bandpass", fs=SR, output="sos"), rng.standard_normal(2 * SR))
fr = fr / np.abs(fr).max() * 0.5
k = int(0.1 * SR); r = np.linspace(0, 1, k); fr[:k] = fr[:k] * r + fr[-k:] * (1 - r); fr = fr[:-k]
sf.write(OUT + "dial_rustle.wav", fr, SR, subtype="PCM_16"); print("dial_rustle")
L = int(0.004 * SR)
tk = np.exp(-np.arange(L) / (0.0008 * SR)) * rng.standard_normal(L)
tk = sosfilt(butter(2, [2000, 8000], "bandpass", fs=SR, output="sos"), np.concatenate([tk, np.zeros(L)]))
sf.write(OUT + "dial_tick.wav", tk / np.abs(tk).max() * 0.7, SR, subtype="PCM_16"); print("dial_tick")

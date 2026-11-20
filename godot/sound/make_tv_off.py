# 試作260（第11章の最後のカット B）：ブラウン管のテレビが消える音（仮の音、数式から作る）。
# 電源の切れる「カチ」、画が線から点へつぶれる間の高い唸りの下がり、ガラスの静電気の「パチパチ」、箱の低い「ボン」。
#   python3 godot/sound/make_tv_off.py → godot/sound/tv_off.wav（44.1kHz、16bit、モノ、1.6秒）
import os, wave, numpy as np
SR = 44100; n = int(SR * 1.6); t = np.arange(n) / SR
rng = np.random.default_rng(11)
s = np.zeros(n)
# the relay: a short click
c = np.exp(-t / 0.004) * rng.standard_normal(n) * 0.7; s += c
# the thump of the tube's box as the deflection lets go
s += 0.55 * np.sin(2 * np.pi * (70 - 25 * t) * t) * np.exp(-t / 0.09)
# the whine: the flyback's high note falling and fading as the picture shrinks to a point
f = 7200 * np.exp(-t / 0.35) + 900
ph = 2 * np.pi * np.cumsum(f) / SR
s += 0.10 * np.sin(ph) * np.exp(-t / 0.45) * np.clip(t / 0.01, 0, 1)
# the glass discharging: sparse crackles, thinning out
k = rng.random(n) < (0.004 * np.exp(-t / 0.5))
cr = np.zeros(n); cr[k] = rng.standard_normal(k.sum()) * 0.6
cr = np.convolve(cr, np.exp(-np.arange(80) / 12.0), mode="same")
s += cr * 0.35
s *= np.clip((1.6 - t) / 0.2, 0, 1)
s = s / np.max(np.abs(s)) * 0.8
w = wave.open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "tv_off.wav"), "wb")
w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((s * 32767).astype("<i2").tobytes()); w.close()
print("ok")

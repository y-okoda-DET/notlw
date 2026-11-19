"""証言の場面の仮の音（数式から作る。本番の音はステップ G）。Run: python3 godot/sound/make_interview_sounds.py
  iv_kettei.wav  証言 二で一度だけ鳴る、ノベルゲームの「決定」の小さな音（二つの鈴の音が重なる、0.5 秒）"""
import os, wave, numpy as np
HERE = os.path.dirname(os.path.abspath(__file__)); SR = 44100
def save(name, x):
    x = np.clip(x, -1, 1); w = wave.open(f'{HERE}/{name}.wav', 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((x * 32767).astype(np.int16).tobytes()); w.close()
t = np.arange(int(SR * 0.6)) / SR
def bell(f, t0, a): 
    tt = np.clip(t - t0, 0, None); e = np.exp(-tt * 9.0) * (t >= t0) * np.minimum(tt * 400, 1)
    return a * e * (np.sin(2 * np.pi * f * tt) + 0.35 * np.sin(2 * np.pi * f * 2.01 * tt) + 0.12 * np.sin(2 * np.pi * f * 3.02 * tt))
save('iv_kettei', 0.5 * (bell(1318.5, 0.0, 0.6) + bell(1975.5, 0.07, 0.5)))
print('ok')

# 仮の音のうち、ユーザーが収録した物（/mnt/project-files/音/収録_2026-11-12/、決定事項 2026-11-12）を切り出す。pip install soundfile
#   python3 godot/sound/cut_recordings.py → godot/sound/knock*.wav、radio_static.wav
import soundfile as sf, numpy as np
SRC="/mnt/project-files/音/収録_2026-11-12/"
OUT="/home/user/notlw/godot/sound/"
def cut(f,a,b,name,fade=0.03,norm=0.89):
    d,sr=sf.read(SRC+f); x=d[int(a*sr):int(b*sr)].copy()
    n=int(fade*sr); w=np.linspace(0,1,n)[:,None]
    x[:n]*=w; x[-n:]*=w[::-1]
    x=x/abs(x).max()*norm
    sf.write(OUT+name+'.wav',x,sr,subtype='PCM_16'); print(name,round(b-a,2))
K2='ノック_内側_2回目_割れを直した版.wav'; K1='ノック_内側_1回目.wav'
cut(K2,8.55,9.75,'knock')        # three, strong (inside, the door at 23:00, the police at 5:00)
cut(K2,8.57,8.82,'knock1',0.005) # one of them
cut(K1,44.40,45.40,'knock_weak') # the end, the strength going (36-50 s of the first take)
cut(K1,44.42,44.70,'knock_weak1',0.005)
# the radio: only what is noise, crosstalk between stations, no broadcast that can be made out (決定事項 2026-11-12: the
# real stations cannot be used). Chosen by measure, not by ear: half-second frames with a flat spectrum and no voice pitch
# (autocorrelation 70-400 Hz under 0.3), kept half a second clear of any frame that had one. Joined with 0.25 s crossfades into a loop.
d, sr = sf.read(SRC + 'ラジオ_1回目.wav')
segs = [(0.3, 5.8), (8.0, 10.8), (24.0, 27.3), (28.0, 31.2), (35.3, 38.3), (58.0, 61.5)]
F = int(0.25 * sr); out = None
for a, b in segs:
    x = d[int(a * sr):int(b * sr)].copy()
    if out is None: out = x; continue
    w = np.linspace(0, 1, F)[:, None]
    out = np.concatenate([out[:-F], out[-F:] * (1 - w) + x[:F] * w, x[F:]])
w = np.linspace(0, 1, F)[:, None]; head = out[:F].copy(); out = out[F:]; out[-F:] = out[-F:] * (1 - w) + head * w
sf.write(OUT + 'radio_static.wav', out / abs(out).max() * 0.89, sr, subtype='PCM_16')

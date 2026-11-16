# 第3章「隔離」の仮の音（ステップ F、2026-11-16）。make_sounds.py と同じく、録音や素材を使わずに数式で作る（ライセンスの心配がない）。
#   python3 godot/sound/make_ch3_sounds.py   → godot/sound/ch3_*.wav（44.1kHz、16bit）
# 鳴らし方は scripts/ch3.gd。良し悪しはユーザーが聞いて決める（Claude には耳がない）。本番の音はステップ G。
#   ch3_gap1..5   隙間風（ループ）：板の隙間・換気口・勝手口の縁。場所ごとに笛の高さを変える。ふさぐと、その一つが消える
#   ch3_gapfront  玄関の扉の下（ループ）：低く、雨のしぶきが混じる。最後まで消えない
#   ch3_tape      布テープを引き出して貼る（ビーッ、パン）
#   ch3_bar       閂（木の棒を受け金に落とす）
#   ch3_thud      扉に人が倒れかかる音（地下から、こもって）
#   ch3_rattle    勝手口が風で鳴る（鍵のかかっていない戸が、枠の中で二、三度当たる）
#   ch3_cough     二階の咳（こもって）
#   ch3_steps     二階の足音（天井越し）
#   ch3_moan      地下のうめき（こもった男の声。仮。声は G で）
#   ch3_murmur    地下からの声（言葉にならないこもった話し声。字幕が言葉を受け持つ）
#   ch3_lock      玄関の鍵（金属のつまみ）
#   ch3_blanket   毛布を取る衣ずれ
import numpy as np, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import save, lp_fast, hp_fast, loopify, env, R
from scipy.signal import butter, sosfilt
rng = np.random.default_rng(31)

def bp(x, lo, hi, n=2):
    return sosfilt(butter(n, [lo, hi], 'band', fs=R, output='sos'), x)

def gusts(n, rate=0.2, lo=0.25):
    g = lp_fast(rng.standard_normal(n), rate, 2); g = (g - g.min()) / (np.ptp(g) + 1e-9)
    return lo + (1 - lo) * g

def gap(f0, sec=9.0, breath=0.35):
    """A thin whistle through a gap: band noise round f0 that wavers in pitch with the gust, and a breath of wide noise."""
    n = int(sec * R)
    g = gusts(n, 0.25, 0.15)
    w = rng.standard_normal(n)
    # the tone: noise through a narrow band whose middle slides with the gust (two bands, a fifth apart, the upper weak)
    out = np.zeros(n)
    blk = 2048
    for i in range(0, n, blk):
        k = g[i:i + blk].mean()
        f = f0 * (0.92 + 0.16 * k)
        seg = w[max(0, i - 4096):i + blk]
        y = bp(seg, f * 0.97, f * 1.03, 2) + 0.3 * bp(seg, f * 1.5 * 0.98, f * 1.5 * 1.02, 2)
        out[i:i + blk] = y[-len(w[i:i + blk]):]
    out = out / (np.max(np.abs(out)) + 1e-9)
    air = lp_fast(hp_fast(rng.standard_normal(n), 300), 3000)
    air = air / (np.max(np.abs(air)) + 1e-9)
    x = (out * (0.2 + 0.8 * g ** 1.6) + air * breath * g)
    return loopify(lp_fast(x, 5000), 1.5)

def gap_front(sec=10.0):
    """Under the front door: a low moan of wind, and the rain's spatter blown in on the genkan's floor."""
    n = int(sec * R)
    g = gusts(n, 0.18, 0.2)
    base = gap(260, sec, breath=0.8)[:n - int(1.5 * R)]
    m = len(base)
    sp = np.zeros(m)
    for p in rng.integers(0, m - 800, int(sec * 140)):
        if rng.random() > g[p]: continue
        L = int(rng.integers(150, 600)); tt = np.arange(L) / R
        sp[p:p + L] += rng.standard_normal(L) * np.exp(-tt / 0.003) * rng.uniform(0.2, 1)
    sp = hp_fast(sp, 1500)
    x = base / (np.max(np.abs(base)) + 1e-9) + 0.35 * sp / (np.max(np.abs(sp)) + 1e-9)
    return x

def tape():
    """Duct tape: pulled off the roll (a ripping rasp that rises), torn, pressed down with a palm."""
    n = int(1.25 * R); x = np.zeros(n)
    L = int(0.75 * R); t = np.arange(L) / R
    # the rasp: fast clicks (the adhesive letting go), rate rising as the pull speeds up
    clicks = np.zeros(L); pos = 0.0
    while pos < L:
        rate = 180 + 900 * (pos / L)
        pos += R / rate * rng.uniform(0.6, 1.4)
        p = int(pos)
        if p < L - 40: clicks[p:p + 40] += np.exp(-np.arange(40) / 6.0) * rng.uniform(0.4, 1.0)
    rasp = bp(clicks + 0.15 * rng.standard_normal(L), 900, 6000)
    rasp *= np.minimum(t / 0.05, 1.0) * np.minimum((0.75 - t) / 0.04, 1.0)
    x[:L] += rasp / (np.max(np.abs(rasp)) + 1e-9)
    # the tear
    p = int(0.8 * R); Lt = int(0.06 * R)
    x[p:p + Lt] += bp(rng.standard_normal(Lt), 1200, 7000) * np.exp(-np.arange(Lt) / (0.015 * R)) * 0.9
    # the palm: a soft thump
    p = int(1.0 * R); Lp = int(0.12 * R)
    x[p:p + Lp] += lp_fast(rng.standard_normal(Lp), 400) * np.exp(-np.arange(Lp) / (0.02 * R)) * 1.6
    return x

def bar():
    """A wooden bar dropped into its brackets behind a door, heard from the hall above: a dull clack and a thunk."""
    n = int(0.9 * R); x = np.zeros(n)
    for at, f, amp, d in ((0.0, 420, 0.6, 0.03), (0.07, 300, 1.0, 0.06), (0.11, 180, 0.8, 0.09)):
        p = int(at * R); L = int(0.4 * R); t = np.arange(L) / R
        y = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2.3 * t)) * np.exp(-t / d) + lp_fast(rng.standard_normal(L), 1200) * np.exp(-t / 0.01) * 0.6
        x[p:p + L] += y * amp
    return lp_fast(x, 1800)

def thud():
    """A body falling against a door, two floors of house between: low, short, with the door's rattle in its frame."""
    n = int(1.6 * R); x = np.zeros(n); t = np.arange(n) / R
    body = lp_fast(rng.standard_normal(n), 140, 2) * np.exp(-t / 0.08) * 5.0 + np.sin(2 * np.pi * 55 * t) * np.exp(-t / 0.12)
    x += body
    for k in range(3):
        p = int((0.12 + 0.09 * k) * R); L = int(0.08 * R)
        x[p:p + L] += bp(rng.standard_normal(L), 200, 900) * np.exp(-np.arange(L) / (0.012 * R)) * (0.4 / (k + 1))
    return lp_fast(x, 900)

def rattle():
    """The back door, unlocked and taped only at its edge, knocking in its frame when the wind leans on it."""
    n = int(1.4 * R); x = np.zeros(n)
    at = 0.0
    for k in range(int(rng.integers(2, 4))):
        p = int(at * R); L = int(0.18 * R); t = np.arange(L) / R
        f = rng.uniform(170, 230)
        y = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.035) + bp(rng.standard_normal(L), 300, 2500) * np.exp(-t / 0.008) * 0.8
        x[p:p + L] += y * (1.0 if k == 0 else rng.uniform(0.4, 0.8))
        # the latch's tongue in its keeper: a small metal tick after
        q = p + int(0.03 * R); Lq = int(0.03 * R)
        x[q:q + Lq] += np.sin(2 * np.pi * 2900 * np.arange(Lq) / R) * np.exp(-np.arange(Lq) / (0.004 * R)) * 0.3
        at += rng.uniform(0.18, 0.32)
    return lp_fast(x, 3500)

def glottal(n, f0_curve, formants, shimmer=0.05):
    """A crude voice: a pulse train at f0 (a curve over time) through formant bands."""
    t = np.arange(n) / R
    ph = np.cumsum(f0_curve / R)
    src = (np.mod(ph, 1.0) < 0.12).astype(float) * (1 + shimmer * rng.standard_normal(n))
    src = lp_fast(src, 2500) + 0.05 * rng.standard_normal(n)
    y = np.zeros(n)
    for f, g in formants: y += bp(src, f * 0.9, f * 1.1, 1) * g
    return y

def moan(sec=2.6):
    """A man groaning behind a door in the cellar (仮: the voice comes in ステップ G)."""
    n = int(sec * R); t = np.arange(n) / R
    f0 = 95 + 12 * np.sin(2 * np.pi * 0.4 * t) - 18 * (t / sec)
    y = glottal(n, f0, [(320, 1.0), (700, 0.5), (2400, 0.12)])
    a = np.minimum(t / 0.35, 1.0) * np.minimum((sec - t) / 0.8, 1.0)
    return lp_fast(y * a, 700, 2)   # through the floor and the barred door

def murmur(sec=3.4):
    """Words through the cellar's door and the floor: the shape of speech, no words."""
    n = int(sec * R); t = np.arange(n) / R
    f0 = 110 + 25 * lp_fast(rng.standard_normal(n), 3.0) * 40
    a = np.zeros(n)
    at = 0.1
    while at < sec - 0.3:
        L = rng.uniform(0.12, 0.35); p0, p1 = int(at * R), int(min(sec, at + L) * R)
        a[p0:p1] = np.hanning(p1 - p0) * rng.uniform(0.5, 1.0)
        at += L + rng.uniform(0.03, 0.25) + (0.6 if rng.random() < 0.15 else 0.0)
    y = glottal(n, np.clip(f0, 80, 170), [(500, 1.0), (1100, 0.5), (2500, 0.1)])
    return lp_fast(y * lp_fast(a, 30), 650, 2)

def cough():
    """Someone coughing upstairs, through the ceiling."""
    n = int(1.6 * R); x = np.zeros(n)
    at = 0.0
    for k in range(int(rng.integers(2, 4))):
        p = int(at * R); L = int(0.22 * R); t = np.arange(L) / R
        burst = bp(rng.standard_normal(L), 300, 1800) * np.minimum(t / 0.01, 1.0) * np.exp(-t / 0.07)
        voice = glottal(L, np.full(L, 210.0), [(600, 0.6), (1200, 0.3)]) * np.exp(-t / 0.05) * 0.5
        x[p:p + L] += (burst + voice) * (1.0 if k == 0 else 0.7)
        at += rng.uniform(0.28, 0.42)
    return lp_fast(x, 900, 2)

def steps(n_steps=7):
    """Footsteps on the floor above: dull, spaced, a board creaking under one of them."""
    gap_s = 0.62; n = int((n_steps * gap_s + 1.0) * R); x = np.zeros(n)
    for k in range(n_steps):
        p = int((0.2 + k * gap_s + rng.uniform(-0.04, 0.04)) * R); L = int(0.25 * R); t = np.arange(L) / R
        x[p:p + L] += lp_fast(rng.standard_normal(L), 160) * np.exp(-t / 0.035) * 4.0 * rng.uniform(0.6, 1.0)
        if k == 3:
            Lc = int(0.5 * R); tc = np.arange(Lc) / R
            f = 300 + 60 * np.sin(2 * np.pi * 3 * tc)
            x[p:p + Lc] += np.sin(2 * np.pi * np.cumsum(f) / R) * np.exp(-tc / 0.15) * 0.12
    return lp_fast(x, 600)

def lock():
    """The front door's thumb-turn: a small metal turn and the bolt's clack."""
    n = int(0.45 * R); x = np.zeros(n)
    for at, f, amp, d in ((0.0, 3200, 0.3, 0.006), (0.09, 1900, 1.0, 0.012), (0.1, 900, 0.6, 0.03)):
        p = int(at * R); L = int(0.2 * R); t = np.arange(L) / R
        x[p:p + L] += np.sin(2 * np.pi * f * t) * np.exp(-t / d) * amp + bp(rng.standard_normal(L), 1500, 8000) * np.exp(-t / 0.003) * amp * 0.5
    return x

def blanket():
    """A wool blanket pulled off a bed and gathered in the arms."""
    n = int(1.3 * R); t = np.arange(n) / R
    a = np.exp(-((t - 0.35) / 0.18) ** 2) + 0.6 * np.exp(-((t - 0.85) / 0.2) ** 2)
    return bp(rng.standard_normal(n), 400, 5000) * a * (0.7 + 0.3 * lp_fast(rng.standard_normal(n), 25))

if __name__ == '__main__':
    for i, f0 in enumerate((1180, 940, 1420, 760, 1050)):   # 居間・食堂・台所の北・換気口・勝手口
        save('ch3_gap%d' % (i + 1), gap(f0))
    save('ch3_gapfront', gap_front())
    save('ch3_tape', tape())
    save('ch3_bar', bar())
    save('ch3_thud', thud())
    save('ch3_rattle', rattle())
    save('ch3_cough', cough())
    save('ch3_steps', steps())
    save('ch3_moan', moan())
    save('ch3_murmur', murmur())
    save('ch3_lock', lock())
    save('ch3_blanket', blanket())

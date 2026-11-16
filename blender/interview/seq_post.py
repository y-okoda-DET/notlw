# seq.py の画を昼の刷りに通し、カットの並びどおりにつないで mp4 にする。python3 seq_post.py <seqdir> <out.mp4> <shot,shot,...>
import sys, json, os, subprocess, shutil
HERE = os.path.dirname(os.path.abspath(__file__)); IV = os.path.join(HERE, 'iv'); sys.path.insert(0, IV)
PORTRAIT = os.path.join(HERE, '..', '..', 'assets', 'interview', 'portrait_2_真顔.png')
from riso import print_frame
from PIL import Image, ImageFilter, ImageDraw, ImageFont
import numpy as np
d, outp, order = sys.argv[1], sys.argv[2], sys.argv[3].split(',')
F = ImageFont.truetype('/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf', 22)
LAB = {'a': '聞き手の正面（顎で切る）', 'b': 'T1 ゆっくり寄る（長い問い）', 'c': '澪の正面（口元で切る）', 'd': 'N3 振り', 'e': 'N5 二焦点',
       'f': '手元：答えを組む間は止める', 'g': 'T5 極端な寄り', 'h': 'T2 真上（決定の瞬間）', 'i': '相手の正面に返す',
       'j': 'N2 高い隅の長回し（証言一の頭に一度だけ）', 'k': '空：床の間', 'l': '引き：柱で割る', 'm': '聞き手の正面（胸で切る）', 'n': '澪の正面', 'o': '手元：答えを組む間', 'p': '聞き手の正面に返す',
       'q': '聞き手の正面（口元で切る）', 'r': 'T4 回り込み（止まらない）', 's': 'N1 めまい（一語が滑る）', 't': '版ずれ', 'u': '平たくなる（ディゾルブで立ち絵が立ち上がる）'}
def hblur(im, px):
    if px <= 0: return im
    a = np.asarray(im).astype(np.float32); k = max(int(px * im.width / 1920), 1); st = max(k // 12, 1); acc = np.zeros_like(a); n = 0
    for s in range(-k, k + 1, st): acc += np.roll(a, s, 1); n += 1
    return Image.fromarray((acc / n).astype(np.uint8))
# 証言 三の版ずれと平たくなった画（iv/compose.py の部品を使う）
_cs = open(os.path.join(IV, 'compose.py')).read().split('# ---- frame 2')[0]; CP = {}; exec(compile(_cs, 'compose_parts', 'exec'), CP)
_rs = open(os.path.join(IV, 'riso.py')).read().split('if __name__')[0].replace('mis = np.array([-3.0, 2.0])*k', 'mis = np.array([-26.0, 14.0])*k')
SLIP = {}; exec(compile(_rs, 'riso_slip', 'exec'), SLIP)
def flat_with(bg, portrait, lines, name='聞き手', pa=1.0, blur=0.0, off=0, window=True):
    """平たくなった画。pa=立ち絵の濃さ、blur=立ち絵のぼけ（px）、off=橙の版のずれ（px）。ディゾルブの途中にも使う"""
    W, H = 1920, 1080
    sh = CP['Sheet'](print_frame(bg.convert('RGB').resize((W, H), Image.LANCZOS), exposure=1.0, cell=2.6, flat=True))
    if pa > 0:
        p = Image.open(portrait); h = 1000; p = p.resize((int(p.width * h / p.height), h), Image.LANCZOS)
        if blur > 0: p = p.filter(ImageFilter.GaussianBlur(blur))
        a = p.split()[3]; px = (W - p.width) // 2; py = 790 - int(h * 0.80)
        margin = a.filter(ImageFilter.MaxFilter(21))
        shm = Image.new('L', (W, H)); shm.paste(margin, (px + 14, py + 12)); sh.tint(shm, 'a', 0.38 * pa)
        fig = np.asarray(p.convert('RGB')).astype(np.float32) / 255; am = np.asarray(a).astype(np.float32)[..., None] / 255
        mm = np.zeros((H, W), np.float32); mm[max(py, 0):min(py + h, H), px:px + p.width] = (np.asarray(margin).astype(np.float32) / 255)[max(py, 0) - py:min(py + h, H) - py]
        sh.rgb = sh.rgb * (1 - mm[..., None] * pa) + CP['PAPER'] * mm[..., None] * pa
        y0, y1 = max(py, 0), min(py + h, H); sub = sh.rgb[y0:y1, px:px + p.width]
        aa = am[y0 - py:y1 - py] * pa; f = fig[y0 - py:y1 - py]
        if off:   # 橙の版だけ遅れて合う：立ち絵の暗い所に、ずれた位置で橙を薄く刷る
            dark = 1 - f.mean(axis=2, keepdims=True); g = np.roll(np.roll(dark * aa, off, 0), -off, 1)
            sub[:] = sub * (1 - aa) + f * aa
            sub[:] = sub * (1 - g * 0.55 * min(off / 24, 1) * (1 - CP['INK_B']))   # ずれが小さくなるほど薄く（合ったときに色が跳ばない）
        else:
            sub[:] = sub * (1 - aa) + f * aa
    if window: CP['window'](sh, lines, name=name)
    return sh.img()
def ease_(t): return t * t * (3 - 2 * t)
def dissolve(src, bg, portrait, lines, n1=10, n2=14):
    """証言 三（ユーザー 2026-11-16「半ズレからディゾルブでぼやーっと立ち上がってくる」）：
    版ずれの画がぼけながら抜けて平たい部屋が浮かぶ（n1）→ 立ち絵がぼけた所から、青が先に、ずれた橙があとから合って立ち上がる（n2）"""
    W, H = 1920, 1080
    a = SLIP['print_frame'](src.convert('RGB').resize((W, H), Image.LANCZOS), exposure=1.0, cell=2.6, grain=0.10, day=True)
    b = flat_with(bg, portrait, lines, pa=0, window=False)
    out = []
    for i in range(n1):
        t = ease_((i + 1) / n1)
        out.append(Image.blend(a.filter(ImageFilter.GaussianBlur(14 * t)), b, t))
    for i in range(n2):
        t = (i + 1) / n2
        out.append(flat_with(bg, portrait, lines, pa=ease_(min(t * 1.4, 1)), blur=18 * (1 - ease_(t)), off=int(24 * (1 - ease_(t))), window=True))   # 窓（書き起こしの紙）は立ち絵より先に置く：手が窓に隠れる所で跳ばない
    return [o.resize((960, 540), Image.LANCZOS) for o in out]
def cap(p, lab):
    dr = ImageDraw.Draw(p); w = dr.textlength(lab, font=F); dr.rectangle((0, 540 - 34, w + 20, 540), fill=(20, 20, 20)); dr.text((10, 540 - 30), lab, fill=(235, 235, 230), font=F)
    return p
def pr(im, lab, post=None):
    if post == 'flat': p = flat_with(im, PORTRAIT, [('', '勝手口？', False)]).resize((960, 540), Image.LANCZOS)
    elif post == 'slip': p = SLIP['print_frame'](im.convert('RGB').resize((1920, 1080), Image.LANCZOS), exposure=1.0, cell=2.6, grain=0.10, day=True).resize((960, 540), Image.LANCZOS)
    else: p = None
    if p is not None:
        dr = ImageDraw.Draw(p); w = dr.textlength(lab, font=F); dr.rectangle((0, 540 - 34, w + 20, 540), fill=(20, 20, 20)); dr.text((10, 540 - 30), lab, fill=(235, 235, 230), font=F)
        return p
    p = print_frame(im.convert('RGB').resize((1920, 1080), Image.LANCZOS), exposure=1.0, cell=2.6, grain=0.10, day=True)
    p = (p if isinstance(p, Image.Image) else Image.fromarray(p)).convert('RGB').resize((960, 540), Image.LANCZOS)
    dr = ImageDraw.Draw(p); w = dr.textlength(lab, font=F); dr.rectangle((0, 540 - 34, w + 20, 540), fill=(20, 20, 20)); dr.text((10, 540 - 30), lab, fill=(235, 235, 230), font=F)
    return p
last_src = None; DISSOLVE = os.environ.get('CUT') != '1'
tmp = os.path.join(d, '_frames'); shutil.rmtree(tmp, ignore_errors=True); os.makedirs(tmp); n = 0
for s in order:
    sd = os.path.join(d, s); meta = json.load(open(os.path.join(sd, 'meta.json'))); lab = LAB.get(s[0], s)
    ims = [Image.open(os.path.join(sd, f'{i:03d}.png')).convert('RGB') for i in range(len(meta))]
    if any(m['n5'] for m in meta):   # 下が手前（テープ）、上が奥（澪）。継ぎ目は少しぼかす
        near, far = ims[0], ims[1]; mm = np.zeros((near.height, near.width), np.float32); mm[:int(near.height * 0.62), :] = 1.0
        m = Image.fromarray((mm * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(near.width * 0.02))
        seq = [(Image.composite(far, near, m), meta[1]['hold'], None)]
    else:
        seq = [(hblur(im, m_['blur']), m_['hold'], m_.get('post')) for im, m_ in zip(ims, meta)]
    if meta[0].get('post') == 'flat' and last_src is not None and DISSOLVE:   # 版ずれの画から溶かして立ち上げる
        for p in dissolve(last_src, ims[0], PORTRAIT, [('', '勝手口？', False)]):
            cap(p, lab).save(os.path.join(tmp, f'{n:05d}.png')); n += 1
    if meta[-1].get('post') == 'slip': last_src = ims[-1]
    if DISSOLVE and meta[-1].get('post') == 'slip': seq = [(im, max(1, h - 2), po) for im, h, po in seq]
    for im, hold, post in seq:
        p = pr(im, lab, post)
        for _ in range(hold): p.save(os.path.join(tmp, f'{n:05d}.png')); n += 1
    print('shot', s, 'frames so far', n)
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', '12', '-i', os.path.join(tmp, '%05d.png'), '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', outp], check=True)
print('ok', outp, n, 'frames', round(n / 12, 1), 's')

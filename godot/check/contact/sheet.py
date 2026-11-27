#!/usr/bin/env python3
"""赤字用のコンタクトシート（2026-11-27）：contact.sh で撮った画を、止まって喋る所を間引いて、章ごとの PDF にする。
  python3 godot/check/contact/sheet.py <撮った画のフォルダ（shots.tsv）> <出力フォルダ> [版の名前]
  1ページ A4 横に6枚（3列×2段。画を大きくして下に赤字の余白）。各画の下に 番号・時計（通しの頭からの秒）・章・時刻・撮った訳・位置名（F12 と同じ形）・カメラ。
  間引き：前に残した画と、縮めた画（160x90 の灰色）の差が小さい（DIFF 未満、既定 4.0）ものは捨て、残した画に「〜何秒まで同じ」と書く。
  カットとカードで撮った画は、似ていても残す。
"""
import sys, os, csv, io
from PIL import Image, ImageChops, ImageStat
from reportlab.lib.pagesizes import A4, landscape
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.utils import ImageReader

SRC, OUT = sys.argv[1], sys.argv[2]
VER = sys.argv[3] if len(sys.argv) > 3 else os.path.basename(SRC.rstrip('/'))
DIFF = float(os.environ.get('DIFF', '4.0'))
os.makedirs(OUT, exist_ok=True)

pdfmetrics.registerFont(TTFont('JP', '/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf')); JP = 'JP'   # apt: fonts-ipafont-gothic（埋め込む）

# 章の並び（scripts/order.gd、main.gd の PLAY_TIME）と名前（story/*.txt の頭）
CHAP = [
    ('ch0', '序章「夜明け」'), ('ch1car', '第1章 行きの車'), ('ch1', '第1章「定点」'), ('house-t20', '第2章「籠城」20時'), ('h21', '第2章 21時・22時'),
    ('door', '第2章 23時 扉'), ('ch3', '第3章「隔離」'), ('ch4', '第4章「戻ってきたもの」'), ('ch5', '第5章「地下」'),
    ('ch6', '第6章「片づけ」'), ('i1', '証言 一'), ('ch8', '監督（二時）'), ('i2', '証言 二'), ('ch7', '第7章「去年の夏」'),
    ('ch7n', '第7章「去年の夏」'), ('ch7b', '第7章「去年の夏」'), ('i3', '証言 三'), ('ch11', '第11章「再生」'),
]
TITLE = dict(CHAP)
CLOCK = {'dusk': '17:30', 't20': '20:00', 't23': '23:00', 't02': '2:00', 't0330': '3:30', 't0430': '4:30',
         'y21': '去年 21:30', 'y02': '去年 2:00'}

rows = list(csv.DictReader(open(os.path.join(SRC, 'shots.tsv'), encoding='utf-8'), delimiter='\t'))
def thumb(r):
    return Image.open(os.path.join(SRC, '%04d.png' % int(r['n']))).convert('L').resize((160, 90), Image.BOX)

# 間引き
kept = []; last = None; lastimg = None
for r in rows:
    if not os.path.exists(os.path.join(SRC, '%04d.png' % int(r['n']))): continue
    im = thumb(r)
    periodic = r['why'].endswith('秒')
    if last is not None and periodic and last['chapter'] == r['chapter']:
        d = ImageStat.Stat(ImageChops.difference(im, lastimg)).mean[0]
        if d < DIFF:
            last['same_until'] = r['clock']; continue
    r['same_until'] = ''
    kept.append(r); last = r; lastimg = im
print('撮った %d 枚 → 残した %d 枚' % (len(rows), len(kept)))

# 章ごとに分ける（同じ章が二度に分かれて出てきたら、続き番号で別の束）
groups = []
for r in kept:
    key = r['chapter'] if r['chapter'] else 'house-' + r['time']   # 第1章の停電のあと（20時の第2章）は play が空
    if not groups or groups[-1][0] != key: groups.append((key, []))
    groups[-1][1].append(r)

W, H = landscape(A4); M = 22; G = 10; COLS, ROWS = 3, 2
cw = (W - 2 * M - (COLS - 1) * G) / COLS; ih = cw * 9 / 16
ch_ = (H - 2 * M - 26 - (ROWS - 1) * G) / ROWS
order = {k: i for i, (k, _) in enumerate(CHAP)}
made = []
seen = {}
for gi, (key, rs) in enumerate(groups):
    seen[key] = seen.get(key, 0) + 1
    name = '%02d_%s%s' % (gi, TITLE.get(key, key).replace('「', '_').replace('」', '').replace(' ', '_').replace('〜', '-'),
                          '' if seen[key] == 1 else '_%d' % seen[key])
    path = os.path.join(OUT, name + '.pdf')
    c = canvas.Canvas(path, pagesize=(W, H)); c.setTitle('%s %s' % (VER, TITLE.get(key, key)))
    pages = (len(rs) + 5) // 6
    for p in range(pages):
        c.setFont(JP, 11); c.setFillGray(0)
        c.drawString(M, H - M - 10, '%s　%s　（%d / %d ページ）' % (VER, TITLE.get(key, key), p + 1, pages))
        c.setFont(JP, 7); c.setFillGray(0.4)
        c.drawRightString(W - M, H - M - 10, '赤字は画の上か、下の余白に。番号と位置名で同じ画を撮り直せます')
        for j, r in enumerate(rs[p * 6:(p + 1) * 6]):
            col, row = j % COLS, j // COLS
            x = M + col * (cw + G); ytop = H - M - 26 - row * (ch_ + G)
            img = Image.open(os.path.join(SRC, '%04d.png' % int(r['n']))).convert('RGB').resize((1280, 720), Image.LANCZOS)
            bio = io.BytesIO(); img.save(bio, 'JPEG', quality=85); bio.seek(0)
            c.drawImage(ImageReader(bio), x, ytop - ih, cw, ih)
            c.setStrokeGray(0.7); c.setLineWidth(0.4); c.rect(x, ytop - ch_, cw, ch_)
            c.setFillGray(0); c.setFont(JP, 7.5)
            tm = CLOCK.get(r['time'], r['time'])
            why = r['why'] if not r['why'].endswith('秒') else '定時'
            same = '　〜%s秒まで同じ画' % r['same_until'] if r['same_until'] else ''
            c.drawString(x + 2, ytop - ih - 10, '#%s　%s秒　%s　%s%s' % (r['n'], r['clock'], tm, why, same))
            c.setFont(JP, 5.2); c.setFillGray(0.3)
            c.drawString(x + 2, ytop - ih - 18, r['name'])
            c.drawString(x + 2, ytop - ih - 25, 'カメラ x,y,z,yaw,pitch,fov = ' + r['cam'])
        c.showPage()
    c.save(); made.append((path, len(rs), pages))
for p, n, pg in made: print('%s\t%d 枚\t%d ページ' % (os.path.basename(p), n, pg))

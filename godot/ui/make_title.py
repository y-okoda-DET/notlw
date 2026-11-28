"""タイトル画面の紙（2026-11-28、ユーザー「ゲームタイトル画面もつくりたいね」）。
聞き取りの部屋の座卓に置いた「上映用」のテープの箱。そのふた（紙のインデックス）に、題名のロゴと、夏希の字の「上映用」、
その下に罫線と、夏希の字の行（はじめる／つづきから／設定／おわる）。設定は別の紙（聞き手のメモ用紙）に行を並べる。
字は Yomogi（assets/fonts、SIL OFL 1.1。夏希の「上映用」と同じ字。フォントはゲームに入れず、描いた画像だけを入れる）。
  python3 godot/ui/make_title.py   → godot/ui/title_card.png（ふた）、title_row_<key>.png（行ごとの字）、title_mark.png（ペンの丸）
"""
import os, math, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

G = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(G)
FONT = os.path.join(REPO, 'assets/fonts/Yomogi-Regular.ttf')
OUT = os.path.join(G, 'ui')
INK = (34, 44, 120, 255)           # the blue ballpoint of label_jouei.png
PAPER = (238, 233, 220, 255)

# the lid's paper: 1100 x 780 px for 110 x 78 mm
W, H = 1100, 780
ROWS = [('start', 'はじめる'), ('cont', 'つづきから'), ('set', '設定'), ('quit', 'おわる'),
        ('q_hi', '画質　ふつう'), ('q_lo', '画質　かるい'), ('v_3', '音　大きい'), ('v_2', '音　ふつう'), ('v_1', '音　小さい'), ('back', 'もどる'),
        ('nocont', 'つづきから（まだない）')]
ROW_Y = [452, 532, 612, 692]       # where the menu's four lines are on the lid (the ruled lines' baselines)


def card():
    rnd = random.Random(7)
    im = Image.new('RGBA', (W, H), PAPER)
    d = ImageDraw.Draw(im)
    # the paper's own fibre: faint specks
    for _ in range(2600):
        x, y = rnd.randrange(W), rnd.randrange(H); c = rnd.randrange(200, 230)
        d.point((x, y), fill=(c, c - 4, c - 14, 255))
    # the printed frame of the index card (a cheap tape's insert): a thin red rule round it and the ruled lines
    d.rectangle((24, 24, W - 25, H - 25), outline=(170, 50, 45, 255), width=6)
    for y in ROW_Y:
        d.line((70, y + 18, W - 70, y + 18), fill=(110, 125, 170, 255), width=3)
    # the logo, printed at the top left (the film's own poster, put on the label at home)
    lg = Image.open(os.path.join(OUT, 'title_logo.png')).convert('RGBA')
    bb = lg.getbbox(); lg = lg.crop(bb)
    s = 330 / lg.height; lg = lg.resize((int(lg.width * s), 330), Image.LANCZOS)
    a = lg.split()[3]
    ink = Image.new('RGBA', lg.size, (32, 30, 34, 255)); ink.putalpha(a)
    im.alpha_composite(ink, (70, 50))
    # 上映用 in her hand, to the right of it, a little tilted
    f = ImageFont.truetype(FONT, 120)
    t = Image.new('RGBA', (560, 200), (0, 0, 0, 0)); ImageDraw.Draw(t).text((10, 20), '上映用', font=f, fill=INK)
    t = t.rotate(4, resample=Image.BICUBIC, expand=True)
    im.alpha_composite(t, (W - 520, 110))
    im.save(os.path.join(OUT, 'title_card.png'))


def row(key, text):
    f = ImageFont.truetype(FONT, 72)
    w = int(f.getlength(text)) + 30
    im = Image.new('RGBA', (w, 96), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((12, 4), text, font=f, fill=INK, stroke_width=2, stroke_fill=INK)   # a ballpoint pressed hard (thin strokes vanished in the print)
    im.save(os.path.join(OUT, f'title_row_{key}.png'))


def mark():
    # a ballpoint loop round a line, drawn fast: one stroke, not closed, overrunning its start
    rnd = random.Random(3)
    im = Image.new('RGBA', (520, 140), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    pts = []
    for i in range(140):
        u = i / 139.0
        a = -0.4 + u * (2 * math.pi + 0.7)
        rx = 240 + 6 * math.sin(u * 9); ry = 52 + 3 * math.sin(u * 7 + 1)
        pts.append((260 + rx * math.cos(a) + rnd.uniform(-1, 1), 70 + ry * math.sin(a) + u * 8 - 4))
    d.line(pts, fill=INK, width=8, joint='curve')
    im.save(os.path.join(OUT, 'title_mark.png'))


if __name__ == '__main__':
    card()
    for k, t in ROWS: row(k, t)
    mark()
    print('title: card, %d rows, mark' % len(ROWS))

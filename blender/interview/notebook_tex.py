# 聞き手の帳面（開いた A5 の見開き）：鉛筆の取材メモ。中身は企画書の夜の流れから（新しい事実は足さない）
# 字は Yomogi（SIL OFL、素材とアドオン.md 記載）を鉛筆の灰で細く。右のページは書きかけで止まる（手のお手本4）
import sys, random
import os; sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import paths as P, lived_tex as LT
from PIL import Image, ImageDraw
LT.R = random.Random(31)
W, H = 740, 1050; PEN = (70, 70, 76, 235)
L = ['証言 一', '21:00 上映会 → 停電で流れた', '桐生「今それどころじゃない」', '23:00 扉', '2:00 桐生 外へ　カメラを持って',
     '「朝まで誰も入れるな。俺でもだ」', '扉は開けなかった', '→「桐生さんが、そう言ったんです」']
R_ = ['テープ　ご家族から', '2:00〜 桐生さんの画', '扉の前で、澪さんは']
def page(lines, out, left):
    im = LT.paper(W, H, (222, 219, 208, 255)); d = ImageDraw.Draw(im)
    for k in range(18):   # 罫
        y = 120 + k * 52; d.line((40 if not left else 30, y, W - 30 if left else W - 40, y), fill=(178, 188, 196, 255), width=2)
    sh = (0, 0) if left else (0, 0)
    f = LT.hand(42); y = 120 + 52 - 50
    for i, s in enumerate(lines):
        yy = y + i * 52
        LT.hand_text(im, (70, yy), s, f, PEN, rot=-1, jit=2, sw=0)
    g = Image.new('RGBA', (W, H), (0, 0, 0, 0)); gd = ImageDraw.Draw(g)   # ノドの影
    for k in range(40): gd.line(((W - 1 - k) if left else k, 0, (W - 1 - k) if left else k, H), fill=(60, 50, 40, int(40 * (1 - k / 40))))
    Image.alpha_composite(im, g).convert('RGB').save(out)
page(L, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'tex', 'page_L.png'), True); page(R_, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'tex', 'page_R.png'), False); print('ok')

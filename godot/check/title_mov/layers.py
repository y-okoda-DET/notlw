# タイトル画面の動く版のための画の層（案2 の合成と同じ見た目）：下の青緑のかぶせ、ロゴ（影つき）、項目4つ
from PIL import Image, ImageDraw, ImageFont, ImageFilter
PAPER = (241, 236, 223); INK = (8, 33, 36)
ANTON = "/home/claude/work/ts/Anton-Regular.ttf"; O = "/home/claude/work/ovt/tm/"
W, H = 1920, 1080
veil = Image.new("RGBA", (W, H), INK + (0,)); a = Image.new("L", (W, H), 0); d = ImageDraw.Draw(a)
for y in range(H):
    k = max(0.0, (y - H * 0.50) / (H * 0.50)); d.line([(0, y), (W, y)], fill=int(200 * min(1, k) ** 1.4))
veil.putalpha(a); veil.save(O + "veil.png")
logo = Image.open("/mnt/project-files/PV/ロゴ/NOTLW_ロゴ_欧文のみ_色ずれ_透過.png").convert("RGBA")
lh = 600; lw = int(logo.width * lh / logo.height); logo = logo.resize((lw, lh), Image.LANCZOS)
L = Image.new("RGBA", (W, H), (0, 0, 0, 0))
sh = Image.new("RGBA", (W, H), (0, 0, 0, 0)); blk = Image.new("RGBA", logo.size, INK + (0,)); blk.putalpha(logo.getchannel("A").point(lambda v: int(v * 0.55)))
sh.alpha_composite(blk, (110, 380)); sh = sh.filter(ImageFilter.GaussianBlur(22))
L.alpha_composite(sh); L.alpha_composite(logo, (110, 380)); L.save(O + "logo.png")
f = ImageFont.truetype(ANTON, 38); dd = ImageDraw.Draw(L)
items = ["CONTINUE", "NEW GAME", "OPTIONS", "QUIT"]
LOGO_BOTTOM = 380 + 3833 * lh / 3980
y0 = round(LOGO_BOTTOM - dd.textbbox((0, 0), "QUIT", font=f)[3] - 66 * 3); x = W - 150
info = []
for i, s in enumerate(items):
    widths = [dd.textlength(c, font=f) for c in s]; sp = 6; tw = sum(widths) + sp * (len(s) - 1)
    im = Image.new("RGBA", (int(tw) + 8, 70), (0, 0, 0, 0)); di = ImageDraw.Draw(im); cx = 0
    for c, w in zip(s, widths): di.text((cx, 0), c, font=f, fill=PAPER + (255,)); cx += w + sp
    im.save(O + f"item{i}.png"); info.append((int(x - tw), y0 + 66 * i, int(tw)))
open(O + "items.txt", "w").write("\n".join("%d %d %d" % t for t in info))
print(info)

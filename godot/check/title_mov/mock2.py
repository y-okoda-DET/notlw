# タイトル画面 案2 の合成：夕方の杉の間の家（試作298 の pck から撮った画）＋色ずれのロゴ＋英語の4項目
from PIL import Image, ImageDraw, ImageFont, ImageFilter
PAPER = (241, 236, 223); ORANGE = (232, 118, 70); INK = (8, 33, 36)
ANTON = "/home/claude/work/ts/Anton-Regular.ttf"
bg = Image.open("/home/claude/work/house/dusk_o_t18.png").convert("RGBA")
W, H = bg.size
# a deep teal veil from the foot up (the menu's ground), the house left as it is
veil = Image.new("L", (W, H), 0); dv = ImageDraw.Draw(veil)
for y in range(H):
    k = max(0.0, (y - H * 0.50) / (H * 0.50)); dv.line([(0, y), (W, y)], fill=int(200 * min(1, k) ** 1.4))
bg = Image.composite(Image.new("RGBA", (W, H), INK + (255,)), bg, veil)
logo = Image.open("/mnt/project-files/PV/ロゴ/NOTLW_ロゴ_欧文のみ_色ずれ_透過.png").convert("RGBA")
lh = 600; lw = int(logo.width * lh / logo.height); logo = logo.resize((lw, lh), Image.LANCZOS)
# shadow so it holds on the sky
sh = Image.new("RGBA", (W, H), (0, 0, 0, 0)); a = logo.getchannel("A").point(lambda v: int(v * 0.55))
blk = Image.new("RGBA", logo.size, INK + (0,)); blk.putalpha(a); sh.alpha_composite(blk, (110, 380)); sh = sh.filter(ImageFilter.GaussianBlur(22))
bg.alpha_composite(sh); bg.alpha_composite(logo, (110, 380))
d = ImageDraw.Draw(bg)
f = ImageFont.truetype(ANTON, 38)
items = ["CONTINUE", "NEW GAME", "OPTIONS", "QUIT"]; sel = 0
LOGO_BOTTOM = 380 + 3833 * lh / 3980
y = round(LOGO_BOTTOM - d.textbbox((0, 0), "QUIT", font=f)[3] - 66 * 3); x = W - 150
print("logo bottom", LOGO_BOTTOM, "menu top", y)
def spaced(s, sp=7):
    return s  # Anton is tight; letter spacing drawn per glyph below
for i, s in enumerate(items):
    # right-aligned, letter-spaced
    widths = [d.textlength(c, font=f) for c in s]; sp = 6; tw = sum(widths) + sp * (len(s) - 1)
    cx = x - tw
    col = PAPER + (255,) if i == sel else PAPER + (150,)
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0)); dl = ImageDraw.Draw(lay)
    for c, w in zip(s, widths): dl.text((cx, y), c, font=f, fill=col); cx += w + sp
    bg.alpha_composite(lay)
    if i == sel:
        d.rectangle([x - tw - 46, y + 22, x - tw - 22, y + 28], fill=ORANGE + (255,))
    y += 66
fs = ImageFont.truetype(ANTON, 18)

bg.convert("RGB").save("/home/claude/work/ts/mock/案2_夕方の家_下揃え.png")

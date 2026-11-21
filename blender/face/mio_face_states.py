# 第11章の最後のカット B案（試作260、2026-11-20）：澪の顔の絵（godot/props/mio_seiza_mio_face_clean.png）に、
# 目線・まぶた・口の段を描き足す。澪の顔は絵を貼った1枚の面で、眼球もまぶたも無いので、絵を歪めて段を作る。
#   python3 blender/face/mio_face_states.py   → godot/props/mio_face_states/{e0..e3,b1,b2}.png と *_glow.png
# e0 = 伏し目（上まぶたが虹彩の上半分まで下り、目は下へ。口は少し開く）… e3 = レンズを見る（元の絵のまま、口を閉じる）
# b1 = まばたきの半分、b2 = 閉じた目（どちらも伏し目の口）。*_glow = 目の光（下からの小さな反射）だけの絵
import os, numpy as np
from PIL import Image, ImageFilter
HERE = os.path.dirname(os.path.abspath(__file__)); REPO = os.path.dirname(os.path.dirname(HERE))
SRC = os.path.join(REPO, "godot/props/mio_seiza_mio_face_clean.png")
OUT = os.path.join(REPO, "godot/props/mio_face_states"); os.makedirs(OUT, exist_ok=True)
im = np.asarray(Image.open(SRC).convert("RGBA")).astype(np.float32)
H, W = im.shape[:2]
# eyes in the picture (px of the 1254 picture): corners, iris centre and radius, top of the lid crease, the lower lid
EYES = [dict(x0=470, x1=567, cx=520, cy=462, r=21, top=432, low=481),
        dict(x0=681, x1=789, cx=727, cy=462, r=21, top=432, low=481)]
LIP = dict(x0=561, x1=686, y=669)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
def ss(a, b, x): t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)
def sample(img, sx, sy):
    x0 = np.clip(np.floor(sx).astype(int), 0, W - 2); y0 = np.clip(np.floor(sy).astype(int), 0, H - 2)
    fx = (sx - x0)[..., None]; fy = (sy - y0)[..., None]
    a = img[y0, x0]; b = img[y0, x0 + 1]; c = img[y0 + 1, x0]; d = img[y0 + 1, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy
def eye_srcy(lid, cover=0.0):
    # lid 0 = as painted, 1 = the lash line down to the lower lid. Per column, a piecewise-linear map in y: the lid skin
    # above the lash stretches down, the lash line itself keeps its thickness, the opening under it (iris and white) is
    # squashed toward the lower lid (the eye turned down is foreshortened), and nothing moves above the crease or below the lid.
    SY = yy.copy()
    for e in EYES:
        u = np.clip((xx - (e["x0"] + e["x1"]) / 2) / ((e["x1"] - e["x0"]) / 2), -1.2, 1.2)
        inx = (np.abs(u) < 1.15)
        L = 441.0 + 26.0 * u * u                 # the upper lash line (its lower edge)
        low = 482.0 - 11.0 * u * u               # the lower lid
        A = L - 34.0; T = 7.0                    # from the crease; T = the lash's thickness
        fx = np.clip(1 - (u / 1.1) ** 2, 0, 1) ** 0.6 if lid < 0.95 else np.ones_like(u)   # shut: the whole lid down
        Ln = L + (lid + cover) * fx * np.maximum(low - L - 0.8, 0)
        Lc = L + cover * fx * np.maximum(low - L - 0.8, 0)   # cover: the lid comes down over the eye without turning it
        y = yy
        s1 = A + (y - A) * (L - T - A) / np.maximum(Ln - T - A, 1e-3)
        s2 = (L - T) + (y - (Ln - T))
        s3 = Lc + (y - Ln) * (low - Lc) / np.maximum(low - Ln, 1e-3)
        sy = np.where(y < A, y, np.where(y < Ln - T, s1, np.where(y < Ln, s2, np.where(y < low, s3, y))))
        SY = np.where(inx & (yy > A - 1) & (yy < low + 2), sy, SY)
    return SY
def mouth_disp(m):
    # m 1 = the lips a little apart: the lower lip goes down 3.5 px in the middle, the gap is the mouth's dark
    u = (xx - (LIP["x0"] + LIP["x1"]) / 2) / ((LIP["x1"] - LIP["x0"]) / 2)
    d = m * 2.6 * np.clip(1 - u * u, 0, 1) ** 1.3
    below = ss(LIP["y"] - 0.5, LIP["y"] + 1.0, yy) * (1 - ss(LIP["y"] + 16, LIP["y"] + 34, yy))
    return d * below, d
def state(lid, m, cover=0.0, src=None, glow_eyes=None):
    SY = eye_srcy(lid, cover)
    Dm, gap = mouth_disp(m)
    out = sample(im if src is None else src, xx, SY - Dm)
    # the mouth's inside, between the lip line and the lower lip that went down
    g = ((yy >= LIP["y"]) & (yy < LIP["y"] + gap)).astype(np.float32)
    g = np.asarray(Image.fromarray((g * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32)[..., None] / 255
    out[..., :3] = out[..., :3] * (1 - g * 0.7) + np.array([38, 22, 20], np.float32) * g * 0.7
    # the light in the eyes: a small low catchlight in each iris (the deck's display is below her), moved with the lid
    glow = np.zeros((H, W), np.float32)
    for e, (ox, oy, rr) in (glow_eyes or [(e, (-4, 9, 2.3)) for e in EYES]):
        px, py = e["cx"] + ox, e["cy"] + oy
        glow += np.exp(-(((xx - px) ** 2) + ((yy - py) ** 2)) / (2 * rr ** 2))
    glow = sample(np.dstack([glow] * 4), xx, SY)[..., 0]
    # under the closed or lowering lid nothing shines: keep the glow only where the warped picture is still the iris (dark)
    lum = out[..., :3].mean(-1) / 255
    glow *= ss(0.45, 0.25, lum) if False else (1 - ss(0.25, 0.45, lum))
    return out, glow
STATES = {"e0": (0.52, 1.0), "e1": (0.36, 0.66), "e2": (0.18, 0.33), "e3": (0.0, 0.0), "b1": (0.78, 1.0), "b2": (1.0, 1.0)}
for k, (lid, m) in STATES.items():
    o, g = state(lid, m)
    Image.fromarray(np.clip(o, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, k + ".png"))
    gi = np.clip(g * 255, 0, 255).astype(np.uint8)
    Image.fromarray(np.dstack([gi, gi, gi]), "RGB").save(os.path.join(OUT, k + "_glow.png"))
    print(k, "ok")

# 試作261 C（ユーザー 2026-11-20 17時23分）：光は A。目線と閉じた口は B から。まぶたは B より下げて A と B の間、見開かない
# （cover：まぶたが目を回さずに上から下りる）。目の反射は片目に小さく一点（絵に描いてあった両目の白い点は消す）。
cim = im.copy()
for e in EYES:
    d = np.sqrt((xx - e["cx"]) ** 2 + (yy - e["cy"]) ** 2)
    lum = cim[..., :3].mean(-1) / 255
    ring = (d < e["r"] * 0.85) & (lum < 0.33)
    col = cim[ring][:, :3].mean(0)
    hot = (d < e["r"] * 0.8) & (lum > 0.36)
    hot = np.asarray(Image.fromarray((hot * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.7))).astype(np.float32) / 255
    cim[..., :3] = cim[..., :3] * (1 - hot[..., None]) + col * hot[..., None]
ONE = [(EYES[1], (6, -4, 1.25))]     # her left eye (the right of the picture), toward the door's light
CST = {"c0": (0.52, 1.0, 0.0), "c1": (0.36, 0.66, 0.10), "c2": (0.18, 0.33, 0.22), "c3": (0.0, 0.0, 0.33),
       "cb1": (0.78, 1.0, 0.0), "cb2": (1.0, 1.0, 0.0)}
for k, (lid, m, cv) in CST.items():
    o, g = state(lid, m, cv, cim, ONE)
    Image.fromarray(np.clip(o, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, k + ".png"))
    gi = np.clip(g * 255, 0, 255).astype(np.uint8)
    Image.fromarray(np.dstack([gi, gi, gi]), "RGB").save(os.path.join(OUT, k + "_glow.png"))
    print(k, "ok")

# 試作262 D（ユーザー 2026-11-20 19時24分「修正指示 その2」）：A の光と陰影のまま、目線と口だけ B。まぶたは A と B の中間で見開かない。
# 反射は片目に一点。A の光では目元が刷りの影に沈み、C は A と同じに見えた（目線が読めない）。D は、まぶたを C より上げ（cover を
# 半分に）、白目に弱い光の印（glow の G）を持たせて、影の中でも黒目の位置が読めるようにする。R は一点の反射。
DST = {"d0": (0.52, 1.0, 0.0), "d1": (0.36, 0.66, 0.06), "d2": (0.18, 0.33, 0.12), "d3": (0.0, 0.0, 0.17),
       "db1": (0.78, 1.0, 0.0), "db2": (1.0, 1.0, 0.0)}
for k, (lid, m, cv) in DST.items():
    o, g = state(lid, m, cv, cim, ONE)
    lum = o[..., :3].mean(-1) / 255
    near = np.zeros((H, W), bool)
    for e in EYES:
        near |= (np.abs(xx - (e["x0"] + e["x1"]) / 2) < (e["x1"] - e["x0"]) / 2 - 3) & (yy > e["top"]) & (yy < e["low"] - 1)
    white = (near & (lum > 0.58) & ((o[..., 0] - o[..., 2]) < 50)).astype(np.float32)   # the white: bright and not skin-coloured
    white = np.asarray(Image.fromarray((white * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32) / 255
    Image.fromarray(np.clip(o, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, k + ".png"))
    gi = np.clip(g * 255, 0, 255).astype(np.uint8); wi = np.clip(white * 255, 0, 255).astype(np.uint8)
    Image.fromarray(np.dstack([gi, wi, np.zeros_like(gi)]), "RGB").save(os.path.join(OUT, k + "_glow.png"))
    print(k, "ok")

# 試作263 D2・B2（ユーザー 2026-11-20 21時37分「比較指示 その3」）：D2 はまぶたを D より少しだけ下げる（あごを上げると目が開いて見えるので、cover を D の約2倍）。
# B2 は B の目（見開いたまま、cover 0）で、白い点はやめて片目に小さく一点（cim と ONE）。白目の光の印は両方に付ける（B2 も正面の光で白目が肌と同じ青に刷られ、眠そうに見えたため）。
for pre, covers, wmask in (("f", (0.0, 0.10, 0.21, 0.32), True), ("g", (0.0, 0.0, 0.0, 0.0), True)):
    ST = {pre + "0": (0.52, 1.0, covers[0]), pre + "1": (0.36, 0.66, covers[1]), pre + "2": (0.18, 0.33, covers[2]), pre + "3": (0.0, 0.0, covers[3]),
          pre + "b1": (0.78, 1.0, 0.0), pre + "b2": (1.0, 1.0, 0.0)}
    for k, (lid, m, cv) in ST.items():
        o, g = state(lid, m, cv, cim, ONE)
        lum = o[..., :3].mean(-1) / 255
        near = np.zeros((H, W), bool)
        for e in EYES:
            near |= (np.abs(xx - (e["x0"] + e["x1"]) / 2) < (e["x1"] - e["x0"]) / 2 - 3) & (yy > e["top"]) & (yy < e["low"] - 1)
        white = (near & (lum > 0.58) & ((o[..., 0] - o[..., 2]) < 50)).astype(np.float32) if wmask else np.zeros((H, W), np.float32)
        white = np.asarray(Image.fromarray((white * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32) / 255
        Image.fromarray(np.clip(o, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, k + ".png"))
        gi = np.clip(g * 255, 0, 255).astype(np.uint8); wi = np.clip(white * 255, 0, 255).astype(np.uint8)
        Image.fromarray(np.dstack([gi, wi, np.zeros_like(gi)]), "RGB").save(os.path.join(OUT, k + "_glow.png"))
        print(k, "ok")

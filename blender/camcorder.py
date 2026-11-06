"""撮影部の三脚とビデオカメラ（夕方は桐生が回し、夜は廊下の定点カメラとして回しっぱなし）。radio.py と同じ作り方
（決定事項 2026-11-06「ラジオくらいの仕上がりに」）：角を丸めた一体の本体、印刷の画像（ボタンの文字、レンズの刻印。
メーカー名なし）、液晶（Godot が「● REC」と時間を出す：main.gd _camcorder_lcd）、すれ・手あか・小傷、桐生の手書きのテープ。

build(M, loc, yaw, head_z) を door.tripod が呼ぶ。物の名前は vcam_*（カメラ）と tpd_*（三脚）、液晶は lcd、赤ランプは
recled：どれも光の焼き込みに入れない（export_godot.NO_LM。小さな物は焼き込みの1テクセルより細かく、まだらになる）。
画像は $WORK/cam/*.png（tex() が作る。PIL だけ）。

Local frame while building: origin at the top of the tripod head's plate, +Y the lens's way, +X the camera's right
(the grip side), +Z up. Everything is parented to one empty turned by yaw, then unparented with its world transform kept."""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths as P
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W = f'{P.WORK}/cam'
FONT_SANS = '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc'
FONT_HAND = f'{P.ASSETS}/fonts/Yomogi-Regular.ttf'
PX = 6000          # px per metre on the printed panels (6 px/mm, like the radio's front)
# body: length (Y), width (X), height (Z); its bottom sits on the plate
BL, BWd, BH = .19, .072, .086
REC_AT = (.02, .062, .08)     # the red lamp: (right, forward, up) from the plate's centre (door.rec_pos)

# ---------------------------------------------------------------- images
def _rng(s): return np.random.default_rng(s)

def _wear(im, seed, grime_bottom=True, polish=None, scratches=18, k=1.0):
    """scuffs and grime on a printed plate: darker toward the bottom edge, the paint polished pale where fingers go,
    fine scratches"""
    a = np.asarray(im.convert('RGB')).astype(np.float32); h, w = a.shape[:2]; r = _rng(seed)
    n = np.asarray(Image.fromarray((r.random((max(2, h // 24), max(2, w // 24))) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)).astype(np.float32)[..., None] / 255
    a *= (.93 + .12 * n)
    if grime_bottom:
        yy = np.mgrid[0:h, 0:w][0].astype(np.float32)
        a *= 1 - .16 * np.clip((yy / h - .7) * 3, 0, 1)[..., None] * (r.random((h, w, 1)) * .4 + .6)
    if polish is not None:
        cx, cy, rad = polish
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        g = np.exp(-(((xx - cx * w) ** 2 + (yy - cy * h) ** 2) / (rad * w) ** 2))[..., None]
        a = a * (1 - .25 * g) + 150 * .25 * g
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)); d = ImageDraw.Draw(im)
    for _ in range(scratches):
        x0, y0 = r.integers(0, w), r.integers(0, h); L = r.integers(6, 50) * k; an = r.uniform(0, math.pi)
        d.line([x0, y0, x0 + L * math.cos(an), y0 + L * math.sin(an)], fill=(120, 120, 122), width=1)
    return im

def body_tex():
    """the body's plastic: charcoal, a fine texture, scuffs, finger polish (tiled by box UV, 8 cm a tile)"""
    s = 512; r = _rng(21)
    a = np.full((s, s, 3), 34, np.float32)
    a += 6 * (r.random((s, s, 1)) - .5)
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(.6))
    im = _wear(im, 22, grime_bottom=False, scratches=40)
    p = f'{W}/cam_body.png'; im.save(p); return p

def side_tex():
    """the right side, over the grip: the zoom rocker's print, PHOTO, the tape door's seam and its EJECT slide.
    (u along the body from back to front, v up)"""
    w, h = int(.15 * PX), int(.06 * PX)
    im = Image.new('RGB', (w, h), (44, 44, 46)); d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONT_SANS, 34); fs = ImageFont.truetype(FONT_SANS, 26)
    ink = (196, 196, 190)
    # the tape door: a seam all round, the slide at its back end
    d.rounded_rectangle([60, 120, w - 160, h - 40], radius=30, outline=(14, 14, 15), width=6)
    d.text((80, h - 70), '▲ OPEN/EJECT', fill=ink, font=fs, anchor='lm')
    d.rectangle([66, h - 112, 150, h - 92], fill=(20, 20, 22))
    # zoom rocker at the top front: W | T
    d.rounded_rectangle([w - 300, 22, w - 120, 92], radius=34, fill=(70, 70, 72), outline=(14, 14, 15), width=4)
    d.text((w - 270, 57), 'W', fill=ink, font=f, anchor='mm'); d.text((w - 150, 57), 'T', fill=ink, font=f, anchor='mm')
    d.text((w - 210, 112), 'ZOOM', fill=ink, font=fs, anchor='mm')
    d.ellipse([w - 420, 30, w - 350, 100], fill=(70, 70, 72), outline=(14, 14, 15), width=4)
    d.text((w - 385, 120), 'PHOTO', fill=ink, font=fs, anchor='mm')
    im = _wear(im, 31, polish=(.8, .3, .1))
    p = f'{W}/cam_side.png'; im.save(p); return p

def back_tex():
    """the back above the battery: the START/STOP button's red ring, the power switch's print
    (u across, from the camera's right to its left as seen from behind, v up)"""
    w, h = int(.066 * PX), int(.027 * PX)
    im = Image.new('RGB', (w, h), (44, 44, 46)); d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONT_SANS, 22); ink = (196, 196, 190)
    cx, cy = int(w * .71), int(h * .48)
    d.ellipse([cx - 50, cy - 50, cx + 50, cy + 50], fill=(150, 30, 24)); d.ellipse([cx - 38, cy - 38, cx + 38, cy + 38], fill=(28, 28, 30))
    d.text((cx + 62, cy), 'REC', fill=ink, font=f, anchor='lm')
    for k, (t, c) in enumerate((('OFF', ink), ('CAMERA', (220, 120, 60)), ('PLAY', ink))):
        d.text((int(w * .2), int(h * (.2 + .3 * k))), t, fill=c, font=f, anchor='mm')
    d.rounded_rectangle([int(w * .36), int(h * .15), int(w * .44), int(h * .85)], radius=12, outline=(14, 14, 15), width=4)
    d.rectangle([int(w * .37), int(h * .4), int(w * .43), int(h * .55)], fill=(80, 80, 82))
    im = _wear(im, 41, polish=(.71, .48, .14))
    p = f'{W}/cam_back.png'; im.save(p); return p

def lens_tex():
    """the ring round the front of the lens: its print round the circle (an annulus, u = angle, v = radius)"""
    w, h = 2048, 128
    im = Image.new('RGB', (w, h), (18, 18, 19)); d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONT_SANS, 58); ink = (200, 200, 196)
    d.text((140, h // 2), 'OPTICAL 10x ZOOM', fill=ink, font=f, anchor='lm')
    d.text((1150, h // 2), '1:1.8  f=4.2-42mm', fill=ink, font=f, anchor='lm')
    d.text((1900, h // 2), '⌀37', fill=ink, font=f, anchor='lm')
    im = _wear(im, 51, grime_bottom=False, scratches=6)
    p = f'{W}/cam_lens.png'; im.save(p); return p

def lcd_tex():
    """the flip-out screen, off-white overlay on the camera's dark picture of the hallway (the timecode is Godot's)"""
    w, h = 400, 300
    r = _rng(61)
    a = np.zeros((h, w, 3), np.float32)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    a += (24 + 30 * np.exp(-(((xx - w * .5) / (w * .18)) ** 2 + ((yy - h * .45) / (h * .3)) ** 2)))[..., None] * np.array([.8, .9, 1.0])   # the hallway's far light
    a += 10 * (r.random((h, w, 1)) - .5)
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)); d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONT_SANS, 22); ink = (230, 230, 225)
    d.text((16, h - 20), 'LP', fill=ink, font=f, anchor='lb')   # long play: the fixed camera runs the night
    d.text((w - 16, h - 20), '16:9', fill=ink, font=f, anchor='rb')
    d.rectangle([w - 74, 16, w - 30, 36], outline=ink, width=3); d.rectangle([w - 30, 21, w - 25, 31], fill=ink); d.rectangle([w - 70, 20, w - 56, 32], fill=ink)   # a battery nearly gone
    d.line([w // 2 - 14, h // 2, w // 2 + 14, h // 2], fill=ink, width=2); d.line([w // 2, h // 2 - 14, w // 2, h // 2 + 14], fill=ink, width=2)
    p = f'{W}/cam_lcd.png'; im.save(p); return p

def tape_tex():
    """桐生's gaffer tape on the top: 「カメラ 桐生」 in white paint marker, and the tape number"""
    w, h = 560, 120
    im = Image.new('RGB', (w, h), (52, 54, 56))
    a = np.asarray(im).astype(np.float32) * (.92 + .12 * _rng(71).random((h, w, 1))); im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    d.text((24, h // 2 + 4), 'カメラ 桐生', fill=(232, 232, 226), font=ImageFont.truetype(FONT_HAND, 72), anchor='lm', stroke_width=2, stroke_fill=(232, 232, 226))
    d.text((w - 20, h // 2 + 4), '#3', fill=(232, 232, 226), font=ImageFont.truetype(FONT_HAND, 54), anchor='rm', stroke_width=1, stroke_fill=(232, 232, 226))
    m = Image.new('L', (w, h), 255); dm = ImageDraw.Draw(m); r = _rng(72)
    for y in range(0, h, 6):
        dm.rectangle([0, y, int(r.integers(0, 12)), y + 6], fill=0); dm.rectangle([w - int(r.integers(0, 12)), y, w, y + 6], fill=0)
    bg = Image.new('RGB', (w, h), (30, 30, 32)); im = Image.composite(im.filter(ImageFilter.GaussianBlur(.6)), bg, m)
    p = f'{W}/cam_tape.png'; im.save(p); return p

def legs_tex():
    """the tripod's tubes: anodised dark grey, the height marks on the lower sections (u round, v along)"""
    w, h = 128, 1024
    im = Image.new('RGB', (w, h), (58, 58, 60)); d = ImageDraw.Draw(im)
    for k in range(1, 10):
        y = int(h * k / 10); d.line([40, y, 88, y], fill=(200, 200, 194), width=4)
        if k % 2 == 0: d.text((64, y - 18), str(k * 5), fill=(200, 200, 194), font=ImageFont.truetype(FONT_SANS, 26), anchor='mb')
    im = _wear(im, 81, grime_bottom=True, scratches=30)
    p = f'{W}/tpd_leg.png'; im.save(p); return p

def tex():
    os.makedirs(W, exist_ok=True)
    return dict(body=body_tex(), side=side_tex(), back=back_tex(), lens=lens_tex(), lcd=lcd_tex(), tape=tape_tex(), leg=legs_tex())

# ---------------------------------------------------------------- the model (bpy)
def build(M, loc, yaw, head_z):
    import bpy, bmesh
    from mathutils import Vector, Matrix
    import lib
    T = tex()
    def mat(name, col, rough=.5, metal=0., img=None, emit=None, estr=1.0, spec=.5):
        if name in M: return M[name]
        m = bpy.data.materials.new(name); m.use_nodes = True; b = m.node_tree.nodes['Principled BSDF']
        b.inputs['Base Color'].default_value = (*col, 1); b.inputs['Roughness'].default_value = rough; b.inputs['Metallic'].default_value = metal
        b.inputs['Specular IOR Level'].default_value = spec
        if img:
            t = m.node_tree.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(img)
            m.node_tree.links.new(t.outputs['Color'], b.inputs['Base Color'])
            if emit: m.node_tree.links.new(t.outputs['Color'], b.inputs['Emission Color']); b.inputs['Emission Strength'].default_value = estr
        elif emit:
            b.inputs['Emission Color'].default_value = (*emit, 1); b.inputs['Emission Strength'].default_value = estr
        M[name] = m; return m
    body_m = mat('vcam_body', (1, 1, 1), .45, img=T['body'])
    rub = mat('vcam_rubber', (.03, .03, .03), .85, spec=.2)
    blk = mat('vcam_black', (.025, .025, .027), .35)
    sil = mat('vcam_silver', (.5, .5, .5), .3, .6)
    glass = mat('vcam_glass', (.01, .015, .03), .04, spec=1.0)
    coat = mat('vcam_coat', (.12, .06, .16), .05, .3, spec=1.0)     # the lens's coating, a violet glint
    alu = mat('tpd_alu', (1, 1, 1), .4, .5, img=T['leg'])
    cast = mat('tpd_cast', (.06, .06, .065), .5)
    red = mat('recled', (1, .05, .03), .4, emit=(1, .04, .02), estr=60)
    root = bpy.data.objects.new('vcam_root', None); bpy.context.scene.collection.objects.link(root)
    root.location = (loc[0], loc[1], head_z); root.rotation_euler.z = yaw
    made = []
    def link(name, bm, m, smooth=True):
        me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
        o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o); o.parent = root
        me.materials.append(m)
        if smooth:
            for p in me.polygons: p.use_smooth = True
        made.append(o); return o
    def rbox(name, c, s, m, bev=.003, seg=3, smooth=True):
        bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts: v.co = Vector((c[0] + v.co.x * s[0], c[1] + v.co.y * s[1], c[2] + v.co.z * s[2]))
        if bev: bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bev, segments=seg, affect='EDGES', profile=.5)
        return link(name, bm, m, smooth)
    def tube(name, a, b, r, m, seg=16, caps=True, r2=None):
        a, b = Vector(a), Vector(b); bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=caps, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=(b - a).length)
        q = (b - a).to_track_quat('Z', 'Y').to_matrix().to_4x4()
        bmesh.ops.transform(bm, matrix=Matrix.Translation((a + b) / 2) @ q, verts=bm.verts)
        return link(name, bm, m)
    def plate(name, corners, m, uvs=((0, 0), (1, 0), (1, 1), (0, 1))):
        bm = bmesh.new(); vs = [bm.verts.new(Vector(c)) for c in corners]; f = bm.faces.new(vs); uv = bm.loops.layers.uv.new()
        for l, t in zip(f.loops, uvs): l[uv].uv = t
        return link(name, bm, m, False)
    zc = BH / 2 + .004
    # ---- the body: one rounded piece, narrower and lower toward the lens, the grip side swelling out
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=4, use_grid_fill=True)
    for v in bm.verts:
        x, y, z = v.co.x * BWd, v.co.y * BL, v.co.z * BH
        t = max(0.0, (y - .02) / (BL / 2 - .02))            # 0 behind the middle .. 1 at the front
        x *= 1 - .18 * t; z = z * (1 - .14 * t) - .006 * t
        if v.co.x > 0: x += .007 * math.exp(-((y + .01) / .05) ** 2)   # the grip's swell under the right hand
        v.co = Vector((x, y - .01, z + zc))
    bmesh.ops.bevel(bm, geom=[e for e in bm.edges if e.is_boundary or len(e.link_faces) == 2 and e.calc_face_angle(0) > .5], offset=.016, segments=5, affect='EDGES', profile=.5)
    body = link('vcam_body', bm, body_m)
    lib.uv_box(body, .08)
    # the top deck: a darker strip behind the lens where the viewfinder sits
    rbox('vcam_deck', (.004, -.055, BH + .004), (.044, .07, .006), blk, .002)
    # ---- the lens: the barrel out of the front, a ridged zoom ring, the printed front ring, glass, an open flared hood
    ly0 = BL / 2 - .02; lz = zc - .004
    tube('vcam_barrel', (0, ly0, lz), (0, ly0 + .05, lz), .031, blk, 28)
    bm = bmesh.new(); n = 56; R0, R1, L = .0325, .0335, .018; rings = []
    for side in (0, 1):
        ring = []
        for i in range(n):
            a = 2 * math.pi * i / n; r = R1 if i % 2 == 0 else R0
            ring.append(bm.verts.new((r * math.cos(a), ly0 + .012 + side * L, lz + r * math.sin(a))))
        rings.append(ring)
    for i in range(n):
        j = (i + 1) % n; bm.faces.new([rings[0][i], rings[0][j], rings[1][j], rings[1][i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    link('vcam_zoomring', bm, rub, False)
    # printed front ring (an annulus facing forward)
    yf = ly0 + .0505; bm = bmesh.new(); uv = bm.loops.layers.uv.new(); n = 64; ri, ro = .0215, .0305
    vi = [bm.verts.new((ri * math.cos(2 * math.pi * i / n), yf, lz + ri * math.sin(2 * math.pi * i / n))) for i in range(n + 1)]
    vo = [bm.verts.new((ro * math.cos(2 * math.pi * i / n), yf, lz + ro * math.sin(2 * math.pi * i / n))) for i in range(n + 1)]
    for i in range(n):
        f = bm.faces.new([vi[i], vo[i], vo[i + 1], vi[i + 1]])
        for l in f.loops:
            k = (vi + vo).index(l.vert); ii = k % (n + 1); outer = k > n
            l[uv].uv = (ii / n, 1.0 if outer else 0.0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    lr = link('vcam_lensring', bm, mat('vcam_lensprint', (1, 1, 1), .4, img=T['lens']), False)
    for p in lr.data.polygons:
        if p.normal.y < 0: p.flip()
    tube('vcam_glass', (0, yf - .006, lz), (0, yf - .004, lz), .0215, glass, 32)
    tube('vcam_coat', (0, yf - .009, lz), (0, yf - .0075, lz), .014, coat, 24)
    hd = tube('vcam_hood', (0, yf, lz), (0, yf + .025, lz), .031, blk, 32, caps=False, r2=.036)
    sol = hd.modifiers.new('sol', 'SOLIDIFY'); sol.thickness = .0018
    # ---- the viewfinder on the top at the back, its tube and rubber eyecup; the mic grille in front of it
    rbox('vcam_vf', (.006, -.07, BH + .022), (.026, .055, .024), body_m, .008)
    tube('vcam_eyecup', (.006, -.097, BH + .022), (.006, -.118, BH + .024), .0155, rub, 20, r2=.0175)
    tube('vcam_eyeglass', (.006, -.1183, BH + .024), (.006, -.1186, BH + .024), .0125, glass, 16)
    mic = tube('vcam_mic', (0, .012, BH + .006), (0, .058, BH + .006), .011, sil, 20)
    for k in range(9): tube('vcam_mic', (0, .015 + k * .005, BH + .0062), (0, .0165 + k * .005, BH + .0062), .0113, blk, 20)
    # ---- the grip strap over the right side: a padded band from the back to the front, held off the body
    bm = bmesh.new(); pts = [(-.085, .0), (-.06, .012), (-.03, .018), (0, .019), (.03, .017), (.055, .01), (.07, .0)]
    vv = []
    for (y, o) in pts:
        vv.append((bm.verts.new((.043 + o, y - .01, zc - .019)), bm.verts.new((.043 + o, y - .01, zc + .015))))
    for k in range(len(vv) - 1): bm.faces.new([vv[k][0], vv[k + 1][0], vv[k + 1][1], vv[k][1]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    st = link('vcam_strap', bm, rub); sl = st.modifiers.new('sol', 'SOLIDIFY'); sl.thickness = .006; sl.offset = 1
    sb = st.modifiers.new('bv', 'BEVEL'); sb.width = .002; sb.segments = 2
    # ---- the printed side plate (right), the back panel, START/STOP raised on it
    xs = BWd / 2 + .0085   # out on the grip's swell
    plate('vcam_side', [(xs + .002, -.085, zc - .036), (xs + .002, .065, zc - .036), (xs, .065, zc + .024), (xs, -.085, zc + .024)], mat('vcam_sideprint', (1, 1, 1), .45, img=T['side']))
    yb = -BL / 2 - .0102
    plate('vcam_back', [(-.033, yb, zc + .013), (.033, yb, zc + .013), (.033, yb, zc + .04), (-.033, yb, zc + .04)], mat('vcam_backprint', (1, 1, 1), .45, img=T['back']))
    tube('vcam_startstop', (-.014, yb, zc + .026), (-.014, yb - .0035, zc + .026), .0062, rub, 20)
    # battery on the back below the viewfinder, ribbed
    rbox('vcam_batt', (0, -BL / 2 - .018, zc - .012), (.058, .02, .046), blk, .004)
    for k in range(5): rbox('vcam_batt', (0, -BL / 2 - .0285, zc - .03 + k * .009), (.05, .002, .003), blk, .0008)
    # ---- the flip-out LCD on the left: a hinge block at the front, the panel opened 100 deg, its screen to the back
    hx, hy, hz = -BWd / 2 - .001, .05, zc + .006
    rbox('vcam_hinge', (hx - .004, hy, hz), (.008, .012, .02), blk, .002)
    pan = bpy.data.objects.new('vcam_lcdpivot', None); bpy.context.scene.collection.objects.link(pan); pan.parent = root
    pan.location = (hx - .006, hy, hz); pan.rotation_euler.z = math.radians(-100)   # swung out and round to face back
    pw, ph = .074, .056
    po = rbox('vcam_lcdpanel', (0, -pw / 2 - .003, 0), (.007, pw, ph), body_m, .003); po.parent = pan
    scr = plate('lcd', [(.0037, -pw + .002, -ph / 2 + .005), (.0037, -.008, -ph / 2 + .005), (.0037, -.008, ph / 2 - .005), (.0037, -pw + .002, ph / 2 - .005)],
                mat('lcd', (1, 1, 1), .2, img=T['lcd'], emit=True, estr=.8))
    scr.parent = pan
    for p in scr.data.polygons:
        if p.normal.x < 0: p.flip()   # the screen on the panel's inner face (toward the body when shut): opened, it faces back, to Kiryu. 試作58〜62 had it on the outer face, toward the subject (ユーザー「モニター部は桐生の方を向いているように」)
    # the left side where the panel was: its recess (darker), MENU and the DV socket's cover
    rbox('vcam_recess', (-BWd / 2 + .0005, -.0, zc + .006), (.002, .072, .052), blk, .001)
    # ---- the red lamp at the front of the top, the crew's tape across the top behind the mic
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=.0042)
    bmesh.ops.translate(bm, vec=Vector(REC_AT), verts=bm.verts); link('recled', bm, red)
    tw, th = .066, .014
    t = plate('vcam_tape', [(-tw / 2, -th / 2, 0), (tw / 2, -th / 2, 0), (tw / 2, th / 2, 0), (-tw / 2, th / 2, 0)], mat('vcam_tapeprint', (1, 1, 1), .8, img=T['tape']),
              uvs=((0, 1), (0, 0), (1, 0), (1, 1)))
    t.location = (-.012, -.025, BH + .0074); t.rotation_euler.z = math.radians(88)
    # ---- the quick-release plate and the head
    rbox('tpd_qr', (0, -.005, -.004), (.05, .09, .008), cast, .002)
    rbox('tpd_qrlever', (.03, -.02, -.005), (.012, .03, .005), sil, .0015)
    rbox('tpd_head', (0, 0, -.034), (.07, .08, .044), cast, .01)
    tube('tpd_tiltknob', (.035, .005, -.034), (.05, .005, -.034), .013, rub, 16)
    tube('tpd_panlock', (-.035, -.01, -.045), (-.05, -.01, -.045), .009, rub, 12)
    tube('tpd_base', (0, 0, -.068), (0, 0, -.056), .036, cast, 28)
    tube('tpd_level', (-.018, .028, -.0555), (-.018, .028, -.0545), .007, mat('tpd_bubble', (.3, .6, .25), .1, emit=(.15, .3, .1), estr=.6), 16)
    tube('tpd_bowl', (0, 0, -.09), (0, 0, -.068), .03, cast, 24, r2=.036)
    # the pan bar: out from the head's back right, dropping, a ribbed rubber grip
    a = Vector((.03, -.03, -.035)); d = Vector((.45, -.86, -.3)).normalized(); b = a + d * .36
    tube('tpd_panbar', a, b, .0075, sil, 14)
    for k in range(10): tube('tpd_grip', b - d * (.11 - k * .011), b - d * (.104 - k * .011), .0125, rub, 14)
    tube('tpd_gripcore', b - d * .112, b + d * .008, .0108, rub, 14)
    # the spider (the top casting with three lugs), the legs: upper and lower sections, flip-locks, rubber feet
    zt = -.1
    tube('tpd_spider', (0, 0, zt - .012), (0, 0, zt + .01), .03, cast, 24)
    feet = []
    gz = -head_z + .01
    for k in range(3):
        an = k / 3 * math.tau - math.pi / 2 + math.pi / 3
        dd = Vector((math.cos(an), math.sin(an), 0))
        rbox('tpd_lug', tuple(dd * .036 + Vector((0, 0, zt))), (.024, .024, .022), cast, .004).rotation_euler.z = an
        p0 = dd * .045 + Vector((0, 0, zt - .01)); p2 = dd * .34 + Vector((0, 0, gz))
        u = (p2 - p0).normalized(); Lg = (p2 - p0).length; p1 = p0 + u * Lg * .52
        tube('tpd_leg', p0, p1 + u * .03, .0125, alu, 14)
        tube('tpd_leg', p1 - u * .02, p2 - u * .03, .0092, alu, 14)
        tube('tpd_collar', p1 - u * .025, p1 + u * .012, .016, cast, 16)
        side = dd.cross(Vector((0, 0, 1)))
        lv = rbox('tpd_lock', tuple(p1 - u * .006 + dd * .017), (.012, .006, .036), sil, .002)
        lv.rotation_euler = u.to_track_quat('Z', 'Y').to_euler()
        tube('tpd_foot', p2 - u * .035, p2, .0125, rub, 14, r2=.015)
        feet.append(p0.lerp(p2, .74))
    hub = sum(feet, Vector()) / 3
    tube('tpd_spreadhub', hub - Vector((0, 0, .01)), hub + Vector((0, 0, .01)), .02, cast, 16)
    for q in feet: tube('tpd_spread', hub, q, .0045, sil, 8)
    # unparent with the world transform kept, apply the solidify, done
    bpy.context.view_layer.update()
    for o in list(bpy.data.objects):
        if o.parent is not None and (o.parent == root or (o.parent and o.parent.name.startswith('vcam_lcdpivot'))):
            mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = mw
    for o in made:
        for m in list(o.modifiers):
            bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier=m.name)
    for e in [o for o in bpy.data.objects if o.name.startswith(('vcam_root', 'vcam_lcdpivot'))]: bpy.data.objects.remove(e)
    return body

# ---------------------------------------------------------------- 澪の小さなカメラ（定点に置く）
# 第1章で澪が持ち歩き、廊下に置く手のひら大のビデオカメラ（godot/scripts/story.gd _fixed_cam が godot/props/minicam.glb を
# 読む）。ユーザー「主人公が持つ（設置する）カメラのデザインもクオリティアップさせよう」2026-11-06。銀色（黒は刷りで手の中の
# 闇に消えた）、レンズの刻印とフード、たたんだ液晶、ファインダー、握りのベルト、録画ボタン、下に小さなクランプ。
# 上に撮影部のマスキングテープ「定点 ②」。赤ランプ（recdot）と光は Godot が作る（録画の切り替え）。
# Blender: +Y = the lens's way, +Z up, origin at the body's centre (glTF: the lens to Godot's -Z).
SW, SL, SH = .055, .115, .065

def small_body_tex():
    s = 512; r = _rng(91)
    a = np.full((s, s, 3), 150, np.float32) * np.array([1, 1, .98])
    a += 10 * (r.random((s, s, 1)) - .5)
    a += 3 * (r.random((1, s, 1)) - .5) * 2   # a faint brushed grain (one way)
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(.7))
    im = _wear(im, 92, grime_bottom=False, scratches=25, k=.5)
    p = f'{W}/mini_body.png'; im.save(p); return p

def small_tape_tex():
    w, h = 420, 110
    im = Image.new('RGB', (w, h), (222, 208, 168))
    a = np.asarray(im).astype(np.float32) * (.94 + .1 * _rng(93).random((h, w, 1))); im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    d.text((24, h // 2 + 4), '定点 ②', fill=(24, 24, 30), font=ImageFont.truetype(FONT_HAND, 74), anchor='lm', stroke_width=2, stroke_fill=(24, 24, 30))
    d.text((w - 18, h // 2 + 10), '廊下', fill=(170, 30, 24), font=ImageFont.truetype(FONT_HAND, 40), anchor='rm', stroke_width=1, stroke_fill=(170, 30, 24))
    m = Image.new('L', (w, h), 255); dm = ImageDraw.Draw(m); r = _rng(94)
    for y in range(0, h, 6):
        dm.rectangle([0, y, int(r.integers(0, 12)), y + 6], fill=0); dm.rectangle([w - int(r.integers(0, 12)), y, w, y + 6], fill=0)
    bg = Image.new('RGB', (w, h), (150, 150, 148)); im = Image.composite(im.filter(ImageFilter.GaussianBlur(.6)), bg, m)
    p = f'{W}/mini_tape.png'; im.save(p); return p

def build_small():
    import bpy, bmesh
    from mathutils import Vector, Matrix
    os.makedirs(W, exist_ok=True)
    T = dict(body=small_body_tex(), side=side_tex(), back=back_tex(), lens=lens_tex(), tape=small_tape_tex())
    bpy.ops.wm.read_factory_settings(use_empty=True)
    M = {}
    def mat(name, col, rough=.5, metal=0., img=None, spec=.5):
        if name in M: return M[name]
        m = bpy.data.materials.new(name); m.use_nodes = True; b = m.node_tree.nodes['Principled BSDF']
        b.inputs['Base Color'].default_value = (*col, 1); b.inputs['Roughness'].default_value = rough; b.inputs['Metallic'].default_value = metal
        b.inputs['Specular IOR Level'].default_value = spec
        if img:
            t = m.node_tree.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(img)
            m.node_tree.links.new(t.outputs['Color'], b.inputs['Base Color'])
        M[name] = m; return m
    root = bpy.data.objects.new('minicam', None); bpy.context.scene.collection.objects.link(root)
    def link(name, bm, m, smooth=True):
        me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
        o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o); o.parent = root
        me.materials.append(m)
        if smooth:
            for p in me.polygons: p.use_smooth = True
        return o
    def rbox(name, c, s, m, bev=.003, seg=3):
        bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts: v.co = Vector((c[0] + v.co.x * s[0], c[1] + v.co.y * s[1], c[2] + v.co.z * s[2]))
        if bev: bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bev, segments=seg, affect='EDGES', profile=.5)
        return link(name, bm, m)
    def tube(name, a, b, r, m, seg=20, caps=True, r2=None):
        a, b = Vector(a), Vector(b); bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=caps, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=(b - a).length)
        q = (b - a).to_track_quat('Z', 'Y').to_matrix().to_4x4()
        bmesh.ops.transform(bm, matrix=Matrix.Translation((a + b) / 2) @ q, verts=bm.verts)
        return link(name, bm, m)
    def plate(name, corners, m, uvs=((0, 0), (1, 0), (1, 1), (0, 1))):
        bm = bmesh.new(); vs = [bm.verts.new(Vector(c)) for c in corners]; f = bm.faces.new(vs); uv = bm.loops.layers.uv.new()
        for l, t in zip(f.loops, uvs): l[uv].uv = t
        return link(name, bm, m, False)
    sil = mat('mini_body', (1, 1, 1), .4, 0., img=T['body'])   # not metal: Godot's house has no reflection probe, metal went black (NOTES 2026-11-04)
    blk = mat('mini_black', (.03, .03, .032), .35)
    rub = mat('mini_rubber', (.03, .03, .03), .85, spec=.2)
    glass = mat('mini_glass', (.01, .015, .03), .04, spec=1.0)
    coat = mat('mini_coat', (.12, .06, .16), .05, .3, spec=1.0)
    # body: rounded, the front narrowing round the lens, the grip side (right, +X) fuller
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=4, use_grid_fill=True)
    for v in bm.verts:
        x, y, z = v.co.x * SW, v.co.y * SL, v.co.z * SH
        t = max(0.0, (y - .01) / (SL / 2 - .01))
        x *= 1 - .2 * t; z = z * (1 - .16 * t) - .004 * t
        if v.co.x > 0: x += .005 * math.exp(-((y + .005) / .04) ** 2)
        v.co = Vector((x, y - .006, z))
    bmesh.ops.bevel(bm, geom=[e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0) > .5], offset=.013, segments=5, affect='EDGES', profile=.5)   # only the corners: the flat grid's edges crumpled
    body = link('mini_body', bm, sil)
    import lib; lib.uv_box(body, .12)
    # the lens out of the front: a black barrel, the ribbed ring, the printed front ring, the glass, a short hood
    ly0 = SL / 2 - .016; lz = .002
    tube('mini_barrel', (0, ly0, lz), (0, ly0 + .03, lz), .022, blk, 28)
    bm = bmesh.new(); n = 48; rings = []
    for side in (0, 1):
        ring = []
        for i in range(n):
            a = 2 * math.pi * i / n; r = .0238 if i % 2 == 0 else .0230
            ring.append(bm.verts.new((r * math.cos(a), ly0 + .006 + side * .012, lz + r * math.sin(a))))
        rings.append(ring)
    for i in range(n):
        j = (i + 1) % n; bm.faces.new([rings[0][i], rings[0][j], rings[1][j], rings[1][i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces); link('mini_ring', bm, rub, False)
    yf = ly0 + .0305; bm = bmesh.new(); uv = bm.loops.layers.uv.new(); n = 64; ri, ro = .015, .0215
    vi = [bm.verts.new((ri * math.cos(2 * math.pi * i / n), yf, lz + ri * math.sin(2 * math.pi * i / n))) for i in range(n + 1)]
    vo = [bm.verts.new((ro * math.cos(2 * math.pi * i / n), yf, lz + ro * math.sin(2 * math.pi * i / n))) for i in range(n + 1)]
    for i in range(n):
        f = bm.faces.new([vi[i], vo[i], vo[i + 1], vi[i + 1]])
        for l in f.loops:
            k = (vi + vo).index(l.vert); l[uv].uv = ((k % (n + 1)) / n, 1.0 if k > n else 0.0)
    lr = link('mini_lensprint', bm, mat('mini_lensprint', (1, 1, 1), .4, img=T['lens']), False)
    for p in lr.data.polygons:
        if p.normal.y < 0: p.flip()
    tube('mini_glass', (0, yf - .005, lz), (0, yf - .0035, lz), .015, glass, 32)
    tube('mini_coat', (0, yf - .008, lz), (0, yf - .0065, lz), .0095, coat, 24)
    hd = tube('mini_hood', (0, yf, lz), (0, yf + .012, lz), .0218, blk, 32, caps=False, r2=.025)
    hd.modifiers.new('sol', 'SOLIDIFY').thickness = .0015
    # viewfinder pod on the top at the back, a rubber eyecup
    rbox('mini_vf', (.004, -.042, SH / 2 + .008), (.018, .032, .015), blk, .005)
    tube('mini_eyecup', (.004, -.058, SH / 2 + .008), (.004, -.069, SH / 2 + .009), .009, rub, 18, r2=.0105)
    # mic grille on the top front
    tube('mini_mic', (0, .008, SH / 2 + .002), (0, .04, SH / 2 + .002), .008, blk, 18)
    for k in range(6): tube('mini_mic', (0, .011 + k * .005, SH / 2 + .0022), (0, .0122 + k * .005, SH / 2 + .0022), .0083, sil, 18)
    # the flip screen folded on the left: a panel with a seam, its hinge at the front
    rbox('mini_lcd', (-SW / 2 - .003, -.004, .004), (.006, .068, .046), sil, .003)
    rbox('mini_lcdseam', (-SW / 2 - .0062, -.004, .004), (.0006, .06, .038), blk, 0)
    rbox('mini_hinge', (-SW / 2 - .002, .032, .004), (.006, .008, .02), blk, .002)
    # the grip side: the black printed panel, the strap over it
    xs = SW / 2 + .0062
    plate('mini_side', [(xs + .001, -.05, -.026), (xs + .001, .042, -.026), (xs, .042, .012), (xs, -.05, .012)], mat('mini_sideprint', (1, 1, 1), .45, img=T['side']))
    bm = bmesh.new(); pts = [(-.055, 0), (-.035, .01), (0, .013), (.025, .011), (.042, 0)]
    vv = [(bm.verts.new((xs + .001 + o, y - .004, -.018)), bm.verts.new((xs + .001 + o, y - .004, .006))) for (y, o) in pts]
    for k in range(len(vv) - 1): bm.faces.new([vv[k][0], vv[k + 1][0], vv[k + 1][1], vv[k][1]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    st = link('mini_strap', bm, rub); s1 = st.modifiers.new('sol', 'SOLIDIFY'); s1.thickness = .005; s1.offset = 1
    # the back: battery, the printed panel and the START/STOP button
    rbox('mini_batt', (0, -SL / 2 - .016, -.008), (.042, .016, .036), blk, .003)
    for k in range(4): rbox('mini_batt', (0, -SL / 2 - .0245, -.022 + k * .009), (.036, .0015, .0025), blk, .0006)
    yb = -SL / 2 - .0062
    plate('mini_back', [(-.024, yb, .011), (.024, yb, .011), (.024, yb, .03), (-.024, yb, .03)], mat('mini_backprint', (1, 1, 1), .45, img=T['back']))
    tube('mini_startstop', (-.01, yb, .0205), (-.01, yb - .003, .0205), .0045, rub, 18)
    # the crew's masking tape across the top, 「定点 ②」
    tw, th = .046, .012
    t = plate('mini_tape', [(-tw / 2, -th / 2, 0), (tw / 2, -th / 2, 0), (tw / 2, th / 2, 0), (-tw / 2, th / 2, 0)], mat('mini_tapeprint', (1, 1, 1), .8, img=T['tape']),
              uvs=((0, 1), (0, 0), (1, 0), (1, 1)))
    t.location = (-.012, -.012, SH / 2 + .0058); t.rotation_euler.z = math.radians(92)
    # under it: a small clamp to set it anywhere (a ball head on a jaw clamp, its screw and knob)
    tube('mini_mount', (0, 0, -SH / 2 + .002), (0, 0, -SH / 2 - .006), .012, blk, 20)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=.0085, location=(0, 0, -SH / 2 - .012))
    b = bpy.context.active_object; b.name = 'mini_ball'; b.parent = root; b.data.materials.append(mat('mini_chrome', (.7, .7, .7), .3, .2))
    tube('mini_neck', (0, 0, -SH / 2 - .018), (0, 0, -SH / 2 - .026), .006, blk, 16)
    rbox('mini_jaw', (0, 0, -SH / 2 - .03), (.026, .03, .008), blk, .002)
    rbox('mini_jawback', (0, -.013, -SH / 2 - .045), (.026, .006, .03), blk, .002)
    # the lower jaw is a flat foot (it stands on a box top as well as gripping a rail); the screw's knob on its side.
    # 試作60 had the knob under the foot: set on the apple box it stood on the knob, the clamp in the air (ユーザー
    # 「浮いていると不自然」)
    rbox('mini_jawlow', (0, 0, -SH / 2 - .0605), (.03, .034, .008), blk, .002)
    tube('mini_screw', (.013, .006, -SH / 2 - .0605), (.017, .006, -SH / 2 - .0605), .003, mat('mini_chrome', (.7, .7, .7), .3, .2), 10)
    tube('mini_knob', (.017, .006, -SH / 2 - .0605), (.025, .006, -SH / 2 - .0605), .009, rub, 14)
    for o in [o for o in bpy.data.objects if o.type == 'MESH']:
        for m in list(o.modifiers):
            bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier=m.name)
    return root

if __name__ == '__main__':
    build_small()
    import bpy
    glb = f'{P.RULES}/props/minicam.glb'
    bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', export_apply=True, export_yup=True)
    print('EXPORTED', glb)
    if '--noprev' not in sys.argv:
        from mathutils import Vector
        s = bpy.context.scene; s.render.engine = 'CYCLES'; s.cycles.samples = 32; s.cycles.device = 'CPU'
        s.render.resolution_x, s.render.resolution_y = 900, 700; s.view_settings.view_transform = 'AgX'
        w = bpy.data.worlds.new('W'); s.world = w; w.use_nodes = True; w.node_tree.nodes['Background'].inputs[0].default_value = (.35, .33, .3, 1)
        cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); s.collection.objects.link(cam); s.camera = cam; cam.data.lens = 50
        l = bpy.data.objects.new('key', bpy.data.lights.new('key', 'AREA')); s.collection.objects.link(l); l.data.energy = 12; l.data.size = .4
        l.location = (.3, .2, .45); l.rotation_euler = (Vector((0, 0, 0)) - l.location).to_track_quat('-Z', 'Y').to_euler()
        for n, eye in (('front', (.22, .3, .12)), ('back', (-.2, -.3, .14)), ('right', (.35, -.05, .02))):
            cam.location = eye; cam.rotation_euler = (Vector((0, 0, -.01)) - Vector(eye)).to_track_quat('-Z', 'Y').to_euler()
            s.render.filepath = f'{W}/mini_{n}.png'; bpy.ops.render.render(write_still=True)
    print('MINICAM_DONE')

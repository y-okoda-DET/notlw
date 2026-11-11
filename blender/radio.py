"""第2章のラジオ：別荘に置いてある古いアナログの AM/FM ポータブルラジオ（管理人の非常用）。
停電のあと下駄箱の上にあり、澪が手に取って目盛りを合わせる（godot/scripts/story.gd の「ラジオ」）。
    python3 blender/radio.py            -> godot/props/radio.glb（と $WORK/radio/prev_*.png の確認画）
Godot はこの glb を実行時に読み、つまみ（knob）を回し、針（needle）を目盛りの上で動かす。
針の動く範囲と AM の目盛りの並びは DIAL に書き、Godot（story.gd RADIO_*）と同じ値を使う。

The dial is the size and layout of the cheap two-band portables of the 80s and 90s that are still in the cupboard of
every rental cottage: a wide slide-rule window across the top, a perforated grille below, a ridged thumbwheel on the
right side, a chrome rod antenna. The manager's masking tape on the top says what it is for. No maker's name."""
import os, sys, math, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths as P
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = f'{P.RULES}/props'; os.makedirs(OUT, exist_ok=True)
W = f'{P.WORK}/radio'; os.makedirs(W, exist_ok=True)
FONT_SANS = '/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc'
FONT_HAND = f'{P.ASSETS}/fonts/Yomogi-Regular.ttf'

# body (metres): width X, depth Y (front is -Y), height Z; origin at the centre of the bottom
BW, BD, BH = .215, .058, .128
# the dial window on the front, across the top
DX0, DX1, DZ0, DZ1 = -.094, .094, .080, .114
# the needle's travel in the window (x at the AM band's ends) and the AM scale (kHz) - log spacing, as on a real dial
NX0, NX1 = -.076, .076
AM_LO, AM_HI = 531.0, 1602.0
def am_u(f): return (f - AM_LO) / (AM_HI - AM_LO)   # linear in frequency, as the cheap dials print it
DIAL = dict(nx0=NX0, nx1=NX1, am_lo=AM_LO, am_hi=AM_HI)

# ---------------------------------------------------------------- textures
K = 2.4                # drawn at 2.4 times the size it was laid out at (she holds it up to her face)
TPX = int(2600 * K)    # px per metre on the front (6.2 px/mm)
def front_tex():
    """The front plate: the dial (cream card, black print) in its window, the grille below, small print."""
    w, h = int(BW * TPX), int(BH * TPX)
    im = Image.new('RGB', (w, h), (168, 168, 164))
    d = ImageDraw.Draw(im)
    X = lambda x: int((x + BW / 2) * TPX)
    Z = lambda z: int((BH - z) * TPX)
    # dial card
    d.rectangle([X(DX0), Z(DZ1), X(DX1), Z(DZ0)], fill=(226, 219, 196))
    f_s = ImageFont.truetype(FONT_SANS, int(21 * K)); f_m = ImageFont.truetype(FONT_SANS, int(15 * K)); f_b = ImageFont.truetype(FONT_SANS, int(30 * K))
    ink = (28, 26, 24)
    nx = lambda u: X(NX0 + (NX1 - NX0) * u)
    # FM row (upper), linear 76-90 MHz: numbers along the top of the window, ticks hanging down to the line
    zf = DZ1 - .0125
    d.line([nx(0), Z(zf), nx(1), Z(zf)], fill=ink, width=max(1, int(3 * K)))
    for mhz in range(76, 91):
        u = (mhz - 76) / 14; big = mhz % 2 == 0
        d.line([nx(u), Z(zf), nx(u), Z(zf) - (13 * K if big else 7 * K)], fill=ink, width=max(1, int(3 * K)))
        if big: d.text((nx(u), Z(zf) - 16 * K), str(mhz), fill=ink, font=f_s, anchor='mb')
    d.text((X(DX0) + 4 * K, Z(zf) - 4 * K), 'FM', fill=ink, font=f_m, anchor='lb')
    d.text((X(DX1) - 3 * K, Z(zf) - 4 * K), 'MHz', fill=ink, font=f_m, anchor='rb')
    # AM row (lower): ticks standing up from the line, numbers under it (x10 kHz)
    za = DZ0 + .019   # 試作97/98: room under the line for the bigger numbers
    d.line([nx(0), Z(za), nx(1), Z(za)], fill=ink, width=max(1, int(3 * K)))
    # 試作97 (ユーザー「ラジオ、目盛りが少し見づらい」): the AM row is the one she tunes; its marks and numbers
    # were 3 px and 21 pt at this size, finer than the print's dots. Heavier ticks, bigger numbers, every 100 kHz.
    f_a = ImageFont.truetype(FONT_SANS, int(35 * K))   # 試作98: 29 (ユーザー「見えるけど、まだ見づらい」)
    for khz in [531, 600, 700, 800, 900, 1000, 1100, 1200, 1300, 1400, 1500, 1602]:
        u = am_u(khz)
        d.line([nx(u), Z(za), nx(u), Z(za) + 15 * K], fill=ink, width=max(1, int(7 * K)))
        lab = {531: '53', 1602: '160'}.get(khz, str(khz // 10))
        if khz not in (600, 800, 1000, 1200, 1400, 1602): continue   # the others: a tick only, room for the numbers
        d.text((nx(u), Z(za) + 17 * K), lab, fill=ink, font=f_a, anchor='mt', stroke_width=int(1.5 * K), stroke_fill=ink)
    for khz in range(560, 1600, 20):
        d.line([nx(am_u(khz)), Z(za), nx(am_u(khz)), Z(za) + 8 * K], fill=ink, width=max(1, int(3 * K)))
    d.text((X(DX0) + 4 * K, Z(za) + 4 * K), 'AM', fill=ink, font=f_m, anchor='lt')
    d.text((X(DX1) - 3 * K, Z(za) + 4 * K), 'kHz', fill=ink, font=f_m, anchor='rt')
    # a band of red between the rows (the tuning scale's centre line, as printed on these dials)
    d.rectangle([nx(0), Z((zf + za) / 2) - 2 * K, nx(1), Z((zf + za) / 2) + 2 * K], fill=(150, 40, 30))
    # the grille: a field of round holes in the steel, dark behind
    gx0, gx1, gz0, gz1 = -.094, .094, .012, .070
    d.rectangle([X(gx0), Z(gz1), X(gx1), Z(gz0)], fill=(190, 190, 186))
    pitch = .0042; r = .0014
    zz = gz0 + .004; row = 0
    while zz < gz1 - .003:
        xx = gx0 + .004 + (pitch / 2 if row % 2 else 0)
        while xx < gx1 - .003:
            if not (xx > .052 and zz < .03):   # the corner for the small print
                d.ellipse([X(xx - r), Z(zz + r), X(xx + r), Z(zz - r)], fill=(22, 22, 22))
            xx += pitch
        zz += pitch * .87; row += 1
    d.rectangle([X(.054), Z(.028), X(gx1 - .003), Z(gz0 + .003)], fill=(190, 190, 186))
    d.text((X(.073), Z(.021)), '2 BAND', fill=ink, font=f_m, anchor='mm')
    d.text((X(.073), Z(.0135)), 'AM / FM', fill=ink, font=f_s, anchor='mm')
    # wear: grime in the lower edge, finger polish around the dial, scratches
    a = np.asarray(im).astype(np.float32)
    rng = np.random.default_rng(7)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    grime = np.clip((yy / h - .75) * 2.5, 0, 1)[..., None] * (rng.random((h, w, 1)) * .3 + .7)
    a = a * (1 - .18 * grime)
    noise = np.asarray(Image.fromarray((rng.random((h // 20, w // 20)) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)).astype(np.float32)[..., None] / 255
    a = a * (.94 + .1 * noise)
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    for _ in range(14):
        x0 = rng.integers(0, w); y0 = rng.integers(0, h); L = rng.integers(10, 90) * K; an = rng.uniform(0, math.pi)
        d.line([x0, y0, x0 + L * math.cos(an), y0 + L * math.sin(an)], fill=(185, 182, 175), width=max(1, int(1 * K)))
    p = f'{W}/radio_front.png'; im.save(p); return p

def tape_tex():
    """The manager's masking tape on the top, in marker: 非常用, when the batteries were changed, the station that comes in."""
    w, h = 900, 200
    im = Image.new('RGB', (w, h), (214, 196, 150))
    rng = np.random.default_rng(3)
    a = np.asarray(im).astype(np.float32)
    a *= (.93 + .1 * rng.random((h, w, 1)))
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    f1 = ImageFont.truetype(FONT_HAND, 118); f2 = ImageFont.truetype(FONT_HAND, 54)
    d.text((40, 100), '非常用', fill=(20, 20, 30), font=f1, anchor='lm', stroke_width=4, stroke_fill=(20, 20, 30))
    f3 = ImageFont.truetype(FONT_HAND, 40)
    d.text((470, 62), '電池 単3×4　6/12交換', fill=(20, 20, 30), font=f3, anchor='lm', stroke_width=1, stroke_fill=(20, 20, 30))
    d.text((470, 140), 'AM 1017', fill=(20, 20, 30), font=f2, anchor='lm', stroke_width=2, stroke_fill=(20, 20, 30))   # the station that comes in here
    im = im.filter(ImageFilter.GaussianBlur(.8))
    # torn ends
    m = Image.new('L', (w, h), 255); dm = ImageDraw.Draw(m)
    for y in range(0, h, 6):
        dm.rectangle([0, y, int(rng.integers(0, 14)), y + 6], fill=0); dm.rectangle([w - int(rng.integers(0, 14)), y, w, y + 6], fill=0)
    bg = Image.new('RGB', (w, h), (10, 10, 11)); im = Image.composite(im, bg, m)
    p = f'{W}/radio_tape.png'; im.save(p); return p

# ---------------------------------------------------------------- the model (run inside bpy)
def build(front_png, tape_png):
    import bpy, bmesh
    from mathutils import Vector
    bpy.ops.wm.read_factory_settings(use_empty=True)
    def mat(name, col, rough=.6, metal=0., img=None, emit=None):
        m = bpy.data.materials.new(name); m.use_nodes = True
        b = m.node_tree.nodes['Principled BSDF']
        b.inputs['Base Color'].default_value = (*col, 1); b.inputs['Roughness'].default_value = rough; b.inputs['Metallic'].default_value = metal
        if img:
            t = m.node_tree.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(img)
            m.node_tree.links.new(t.outputs['Color'], b.inputs['Base Color'])
        if emit:
            b.inputs['Emission Color'].default_value = (*emit, 1); b.inputs['Emission Strength'].default_value = 1.0
        return m
    plastic = mat('radio_plastic', (.035, .035, .038), .42)   # black, with the silver plate on the front
    dark = mat('radio_dark', (.05, .05, .05), .45)
    chrome = mat('radio_chrome', (.8, .8, .8), .18, 1.0)
    front = mat('radio_front', (1, 1, 1), .5, img=front_png)
    tape = mat('radio_tape', (1, 1, 1), .85, img=tape_png)
    red = mat('radio_needle', (.75, .08, .04), .4)
    root = bpy.data.objects.new('radio', None); bpy.context.scene.collection.objects.link(root)
    def obj_from(bm, name, m, parent=root):
        me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
        o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o); o.parent = parent
        me.materials.append(m)
        return o
    # body: a rounded box (bevelled corners all round, softer on the vertical edges)
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts: v.co = Vector((v.co.x * BW, v.co.y * BD, (v.co.z + .5) * BH))
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=.007, segments=4, affect='EDGES', profile=.5)
    body = obj_from(bm, 'radio_body', plastic)
    for p in body.data.polygons: p.use_smooth = True
    # front plate, a thin inset panel carrying the printed dial and grille (UV 0..1 over the face)
    bm = bmesh.new()
    y = -BD / 2 - .0008
    vs = [bm.verts.new((x, y, z)) for x, z in [(-BW / 2 + .006, .006), (BW / 2 - .006, .006), (BW / 2 - .006, BH - .006), (-BW / 2 + .006, BH - .006)]]
    f = bm.faces.new(vs); uv = bm.loops.layers.uv.new()
    for l in f.loops:
        l[uv].uv = ((l.vert.co.x + BW / 2) / BW, l.vert.co.z / BH)
    f.normal_flip() if f.normal.y > 0 else None
    obj_from(bm, 'radio_front', front)
    # the dial card again, its own piece just in front: Godot lights it from behind when the radio is on (the dial lamp)
    bm = bmesh.new(); y = -BD / 2 - .0012
    vs = [bm.verts.new((x, y, z)) for x, z in [(DX0, DZ0), (DX1, DZ0), (DX1, DZ1), (DX0, DZ1)]]
    f = bm.faces.new(vs); uv = bm.loops.layers.uv.new()
    for l in f.loops:
        l[uv].uv = ((l.vert.co.x + BW / 2) / BW, l.vert.co.z / BH)
    obj_from(bm, 'dial', mat('radio_dial', (1, 1, 1), .4, img=front_png))
    # the dial window's bezel: a raised dark frame round the dial, and a clear cover just behind its lip
    def box(name, c, s, m, parent=root, bev=0.0):
        bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts: v.co = Vector((c[0] + v.co.x * s[0], c[1] + v.co.y * s[1], c[2] + v.co.z * s[2]))
        if bev: bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bev, segments=2, affect='EDGES', profile=.5)
        o = obj_from(bm, name, m, parent); [setattr(p, 'use_smooth', True) for p in o.data.polygons] if bev else None
        return o
    yb = -BD / 2 - .004; t = .003
    box('radio_bezel_t', (0, yb, DZ1 + t / 2), (DX1 - DX0 + 2 * t, .007, t), dark)
    box('radio_bezel_b', (0, yb, DZ0 - t / 2), (DX1 - DX0 + 2 * t, .007, t), dark)
    box('radio_bezel_l', (DX0 - t / 2, yb, (DZ0 + DZ1) / 2), (t, .007, DZ1 - DZ0), dark)
    box('radio_bezel_r', (DX1 + t / 2, yb, (DZ0 + DZ1) / 2), (t, .007, DZ1 - DZ0), dark)
    # the needle: rides in the window just in front of the card; Godot moves it along X between NX0 and NX1
    nd = box('needle', (0, -BD / 2 - .0022, (DZ0 + DZ1) / 2), (.0012, .0012, DZ1 - DZ0 - .004), red)
    # the tuning thumbwheel on the right side, ridged (Godot spins it about its own X)
    knob = bpy.data.objects.new('knob', None); bpy.context.scene.collection.objects.link(knob); knob.parent = root
    knob.location = (BW / 2 + .004, -.004, BH - .036)
    bm = bmesh.new(); n = 40; R0, R1, L = .021, .0225, .012
    rings = []
    for side in (-1, 1):
        ring = []
        for i in range(n):
            a = 2 * math.pi * i / n; r = R1 if i % 2 == 0 else R0
            ring.append(bm.verts.new((side * L / 2, r * math.cos(a), r * math.sin(a))))
        rings.append(ring)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([rings[0][i], rings[0][j], rings[1][j], rings[1][i]])
    bm.faces.new(list(reversed(rings[0]))); bm.faces.new(rings[1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    wheel = obj_from(bm, 'knob_wheel', dark, knob)
    # a white index dot on the wheel's face, so its turning is seen
    box('knob_dot', (L / 2 + .0006, 0, R0 - .004), (.001, .003, .003), mat('radio_dot', (.9, .9, .85), .5), knob)
    # the volume wheel lower down, and the band slide on top
    box('radio_volume', (BW / 2 + .003, -.006, .03), (.008, .03, .03), dark, bev=.003)
    box('radio_band', (.035, -.006, BH + .002), (.014, .008, .006), dark, bev=.002)
    # the carrying handle: a chrome bar on two posts, folded down along the back of the top
    for sx in (-1, 1): box(f'radio_post{sx}', (sx * .085, .018, BH + .004), (.008, .01, .01), dark, bev=.002)
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=.0035, depth=.17, location=(0, .018, BH + .009), rotation=(0, math.pi / 2, 0))
    hb = bpy.context.active_object; hb.name = 'radio_handle'; hb.parent = root; hb.data.materials.append(chrome)
    # the rod antenna: pulled half out, leaning back and to the left
    ant = bpy.data.objects.new('antenna', None); bpy.context.scene.collection.objects.link(ant); ant.parent = root
    ant.location = (BW / 2 - .014, .016, BH); ant.rotation_euler = (math.radians(-28), math.radians(-34), 0)
    zz = 0.0
    for k, (r, Lk) in enumerate([(.0045, .04), (.0036, .085), (.0029, .085), (.0022, .085)]):
        bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=r, depth=Lk, location=(0, 0, zz + Lk / 2))
        c = bpy.context.active_object; c.name = f'antenna_{k}'; c.parent = ant; c.data.materials.append(chrome if k else dark)
        zz += Lk - .008
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=.0035, location=(0, 0, zz + .005))
    c = bpy.context.active_object; c.name = 'antenna_tip'; c.parent = ant; c.data.materials.append(chrome)
    # the tape on the top, along the front edge, a little askew
    bm = bmesh.new(); tw, th = .086, .019
    vs = [bm.verts.new((x, y2, BH + .0007)) for x, y2 in [(-tw / 2, -th / 2), (tw / 2, -th / 2), (tw / 2, th / 2), (-tw / 2, th / 2)]]
    f = bm.faces.new(vs); uv = bm.loops.layers.uv.new()
    for l in f.loops: l[uv].uv = (l.vert.co.x / tw + .5, l.vert.co.y / th + .5)   # (seen from the front: checked in the render)
    to = obj_from(bm, 'radio_tape', tape); to.location = (-.045, -.012, 0); to.rotation_euler = (0, 0, math.radians(-3.5))
    # rubber feet
    for sx in (-1, 1):
        for sy in (-1, 1): box(f'radio_foot{sx}{sy}', (sx * .085, sy * .018, -.0015), (.012, .008, .003), dark)
    return root

def export(glb):
    import bpy
    bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', export_apply=True, export_yup=True)

def preview(out, view):
    """A check render (Cycles) of the radio alone."""
    import bpy
    s = bpy.context.scene; s.render.engine = 'CYCLES'; s.cycles.samples = 48; s.cycles.device = 'CPU'
    s.render.resolution_x, s.render.resolution_y = 1200, 800
    s.view_settings.view_transform = 'AgX'
    w = bpy.data.worlds.new('W'); s.world = w; w.use_nodes = True
    w.node_tree.nodes['Background'].inputs[0].default_value = (.35, .33, .3, 1)
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); s.collection.objects.link(cam); s.camera = cam
    cam.data.lens = 50
    tgt = Vector((0, 0, BH / 2)) if False else None
    from mathutils import Vector
    eye, look = view
    cam.location = eye
    d = Vector(look) - Vector(eye); cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    l = bpy.data.objects.new('key', bpy.data.lights.new('key', 'AREA')); s.collection.objects.link(l)
    l.data.energy = 30; l.data.size = .5; l.location = (.4, -.6, .6)
    l.rotation_euler = (Vector((0, 0, .06)) - l.location).to_track_quat('-Z', 'Y').to_euler()
    s.render.filepath = out
    bpy.ops.render.render(write_still=True)

if __name__ == '__main__':
    fp = front_tex(); tp = tape_tex()
    build(fp, tp)
    glb = f'{OUT}/radio.glb'
    export(glb)
    print('EXPORTED', glb)
    import json; json.dump(DIAL, open(f'{OUT}/radio_dial.json', 'w'))
    if '--noprev' not in sys.argv:
        preview(f'{W}/prev_front.png', ((-.12, -.42, .2), (0, 0, .07)))
        preview(f'{W}/prev_side.png', ((.38, -.3, .3), (0, 0, .07)))
        preview(f'{W}/prev_top.png', ((-.045, -.08, .42), (-.045, -.01, .12)))
    print('RADIO_DONE')

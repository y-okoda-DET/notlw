"""2026-11-18 第6章（ユーザー「粗いところを直そう。パーフェクトに」）：澪の手と袖。箱と筒で作っていた手を、澪本人の体
（tripo/mio_prep.blend、make_tripo('mio')）の前腕と手に替える。骨は前腕・手・指だけ残す。

左右を別の glb にする（godot/props/mio_arm_l.glb, mio_arm_r.glb）。向きは ch6.gd の手の決まりに合わせてある：
原点＝手首、指先が -Z、手のひらが -Y、前腕（袖）が +Z（Blender では 指先 +Y、手のひら -Z）。
Run: python3.13 blender/export_mio_arms.py"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import paths as P
import bpy, bmesh
from mathutils import Vector, Matrix
import chars as C

OUT = f'{P.RULES}/props'
WHO = os.environ.get('WHO', 'mio')   # 第7章：WHO=yota で陽太の腕（props/yota_arm_l|r.glb）
KEEP = ('lowerarm', 'hand', 'thumb', 'index', 'middle', 'ring', 'pinky')
TEX = 2048

def makeup(body, side):
    """第7章（2026-11-19、ユーザー「ここ陽太を映す必要はある？」）：陽太の特殊メイクは、車の窓の顔ではなく手で見せる。
    手の肌（手と指の骨に付いた、肌色の面）に、血糊（乾いた暗い赤と、新しい赤のたれ）とラテックスの傷（甲に、白っぽい縁と
    暗い裂け目）を、テクスチャの上に描く。袖（パーカー）には少しの染みだけ。"""
    import numpy as np
    from PIL import Image, ImageDraw, ImageFilter
    img = None
    for m in body.data.materials:
        for n in (m.node_tree.nodes if m and m.use_nodes else []):
            if n.type == 'TEX_IMAGE' and n.image and 'basecolor' in n.image.name.lower(): img = n.image
    if img is None: print('MAKEUP no image'); return
    W, H = img.size
    px = np.array(img.pixels[:], np.float32).reshape(H, W, 4)[::-1].copy()   # top row first
    gi = {g.index: g.name for g in body.vertex_groups}
    handv = set(v.index for v in body.data.vertices
                if sum(g.weight for g in v.groups if not gi[g.group].startswith('lowerarm')) > .5)
    uv = body.data.uv_layers.active.data
    nm = body.matrix_world.to_3x3()
    skin = Image.new('L', (W, H)); back = Image.new('L', (W, H)); cloth = Image.new('L', (W, H))
    ds, db, dc = ImageDraw.Draw(skin), ImageDraw.Draw(back), ImageDraw.Draw(cloth)
    for poly in body.data.polygons:
        pts = [(uv[li].uv.x * W, (1 - uv[li].uv.y) * H) for li in poly.loop_indices]
        cx = int(sum(p[0] for p in pts) / len(pts)) % W; cy = int(sum(p[1] for p in pts) / len(pts)) % H
        r, g, b = px[cy, cx, :3]
        is_skin = r > .45 and r > g * 1.05 and g > b
        if is_skin and sum(1 for v in poly.vertices if v in handv) * 2 >= len(poly.vertices):
            ds.polygon(pts, fill=255)
            if (nm @ poly.normal).normalized().z > .35: db.polygon(pts, fill=255)   # the hand's frame: the back of the hand is +Z
        elif not is_skin: dc.polygon(pts, fill=255)
    skin = skin.filter(ImageFilter.MaxFilter(5)); back = back.filter(ImageFilter.MaxFilter(3))
    S = np.asarray(skin, np.float32) / 255; B = np.asarray(back, np.float32) / 255; Cm = np.asarray(cloth, np.float32) / 255
    rng = np.random.default_rng(11 if side == 'l' else 23)
    def blobs(scale, thr, soft):
        n = rng.random((max(2, H // scale), max(2, W // scale))).astype(np.float32)
        im = Image.fromarray((n * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC).filter(ImageFilter.GaussianBlur(scale * .35))
        a = np.asarray(im, np.float32) / 255
        return np.clip((a - thr) / soft, 0, 1)
    dried = blobs(W // 48, .56, .08) * S                    # dried blood, dark and broad
    fresh = blobs(W // 140, .64, .05) * S                   # fresh, smaller and brighter
    grime = blobs(W // 40, .45, .3) * S * .2               # the whole hand dirtied a little
    spots = blobs(W // 260, .80, .04) * Cm * .5              # a few stains on the cuffs
    rgb = px[..., :3]
    def lay(a, col):
        a = a[..., None]; return rgb * (1 - a) + np.array(col, np.float32) * a
    rgb = lay(grime, (.38, .26, .22))
    rgb = lay(dried * .85, (.30, .04, .03))
    rgb = lay(fresh * .9, (.42, .02, .02))
    rgb = lay(spots, (.28, .06, .05))
    # latex wounds on the back of the hand: a pale raised rim, a dark gash in it
    ys, xs = np.nonzero(B > .5)
    if len(xs):
        wound = Image.new('L', (W, H)); gash = Image.new('L', (W, H)); dw, dg = ImageDraw.Draw(wound), ImageDraw.Draw(gash)
        for k in range(2):
            i = rng.integers(len(xs)); cx, cy = int(xs[i]), int(ys[i])
            rx, ry = W * rng.uniform(.016, .024), W * rng.uniform(.008, .012)
            dw.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=255)
            dg.line((cx - rx * .8, cy - ry * .2, cx + rx * .8, cy + ry * .2), fill=255, width=max(2, int(ry * .6)))
        wa = np.asarray(wound.filter(ImageFilter.GaussianBlur(W * .002)), np.float32) / 255 * B
        ga = np.asarray(gash.filter(ImageFilter.GaussianBlur(W * .001)), np.float32) / 255 * B
        rgb = lay(wa * .8, (.80, .68, .58))
        rgb = lay(ga, (.20, .02, .02))
    px[..., :3] = np.clip(rgb, 0, 1)
    img.pixels[:] = px[::-1].ravel()
    img.pack()
    print('MAKEUP', side, img.name, 'skin %.3f back %.3f' % (S.mean(), B.mean()))

def run(side):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rig, body = C.make_tripo(WHO)
    for o in list(bpy.data.objects):
        if o not in (rig, body): bpy.data.objects.remove(o)
    bpy.context.view_layer.update()
    gi = {g.index: g.name for g in body.vertex_groups}
    mine = lambda n: n.endswith('_' + side) and n.startswith(KEEP)
    up = f'upperarm_{side}'
    # the forearm and the hand, and the lower third of the upper arm (so that the sleeve's open end is far up it)
    elbow = C.bone_head(rig, f'lowerarm_{side}'); sh = C.bone_head(rig, up); ud = (elbow - sh); ul = ud.length; ud.normalize()
    keep = set()
    for v in body.data.vertices:
        w = sum(g.weight for g in v.groups if mine(gi[g.group]))
        wu = sum(g.weight for g in v.groups if gi[g.group] == up)
        if w > .5: keep.add(v.index)
        elif w + wu > .5 and ((body.matrix_world @ v.co) - sh).dot(ud) > ul * .55: keep.add(v.index)
    bm = bmesh.new(); bm.from_mesh(body.data); bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in keep], context='VERTS')
    bm.to_mesh(body.data); bm.free()
    # what is left of the upper arm moves with the forearm (one piece from the elbow up: the elbow is out of the picture)
    lo = body.vertex_groups[f'lowerarm_{side}']
    for v in body.data.vertices:
        add = 0.0
        for g in list(v.groups):
            if not mine(gi[g.group]): add += g.weight; body.vertex_groups[g.group].remove([v.index])
        if add > 0: lo.add([v.index], add, 'ADD')
    for g in list(body.vertex_groups):
        if not mine(g.name): body.vertex_groups.remove(g)
    # the bones: the forearm is the root
    bpy.context.view_layer.objects.active = rig; bpy.ops.object.mode_set(mode='EDIT')
    for eb in list(rig.data.edit_bones):
        if not mine(eb.name): rig.data.edit_bones.remove(eb)
    bpy.ops.object.mode_set(mode='OBJECT')
    # ch6.gd's frame: the wrist at the origin, the fingers to +Y, the palm to -Z (Blender) = -Z and -Y in Godot
    bpy.context.view_layer.update()
    w = C.bone_head(rig, f'hand_{side}'); tip = C.bone_tail(rig, f'middle_03_{side}')
    y = (w - elbow).normalized()                       # along the forearm, to the hand
    palm = C.palm_dir(rig, side); z = -(palm - y * palm.dot(y)).normalized(); x = y.cross(z).normalized()
    R = Matrix((x, y, z)).to_4x4()                     # rows: world -> the hand's frame
    M = R @ Matrix.Translation(-w)
    rig.matrix_world = M @ rig.matrix_world
    bpy.context.view_layer.update()
    for img in bpy.data.images:
        if img.size[0] > TEX: img.scale(TEX, TEX * img.size[1] // img.size[0])
    if WHO == 'yota': makeup(body, side)
    rig.name = f'{WHO}_arm_{side}'; body.name = f'{WHO}_arm_{side}_mesh'
    print('ARM', side, 'verts', len(body.data.vertices), 'bones', len(rig.data.bones), 'forearm', round((w - elbow).length, 3),
          'hand', round((tip - w).length, 3), 'images', [(i.name, tuple(i.size)) for i in bpy.data.images])
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); body.select_set(True)
    bpy.ops.export_scene.gltf(filepath=f'{OUT}/{WHO}_arm_{side}.glb', export_format='GLB', use_selection=True, export_apply=False,
                              export_animations=False, export_yup=True, export_image_format='JPEG', export_jpeg_quality=90,
                              export_def_bones=False, export_skins=True)

for s in ('l', 'r'): run(s)

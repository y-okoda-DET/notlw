"""Interviewer: Tripo head+body (kikite_prep.blend) on the game_engine rig, posed in seiza. Saves kikite_seiza.blend."""
import sys, math
sys.path.insert(0, '/home/user/notlw/blender')
import bpy
from mathutils import Vector
import chars as C
import os
KEY = os.environ.get('KEY', 'kikite')   # kikite (the interviewer) or a game character such as mio
if KEY == 'kikite':
    C.TRIPO['kikite'] = '/home/claude/work/kikite/kikite_prep.blend'
    C.SPEC['kikite'] = dict(g=.0, age=55, h=1.57, mus=.4, wt=.5, prop=.5, cup=.5)
    C.NECK_FILL.add('kikite')
# per character: hand skin (linear base, ramp low/high), the cloth colour that covers skin bits left on the sleeves, and
# whether the hand gets the older surface
LOOK = {'kikite': dict(skin=(0.66, 0.48, 0.38), lo=(0.60, 0.43, 0.34), hi=(0.71, 0.53, 0.43), sleeve=(0.025, 0.03, 0.07), aged=True),
        'mio': dict(skin=(0.74, 0.52, 0.38), lo=(0.70, 0.48, 0.35), hi=(0.79, 0.57, 0.43), sleeve=(0.045, 0.045, 0.047), aged=False)}[KEY]
bpy.ops.wm.read_factory_settings(use_empty=True)
# keep a copy of the MakeHuman donor (already posed to the Tripo body and applied as rest): its hands replace the
# generated ones, which are lumps that cannot take a pose (user: the hand looked wrong)
_KEEP = {}
_orig_tw = C._transfer_weights_gated
def _tw(donor, target, rig, *a, **kw):
    cp = donor.copy(); cp.data = donor.data.copy(); bpy.context.scene.collection.objects.link(cp); cp.name = f'{KEY}_hands'
    for m in list(cp.modifiers): cp.modifiers.remove(m)
    _KEEP['d'] = cp
    return _orig_tw(donor, target, rig, *a, **kw)
C._transfer_weights_gated = _tw
# the hand and thumb are the MakeHuman ones now: do not stretch them to the generated lump (thumb was made 1.2x and
# turned 36 deg, hand 1.07x). Patch make_tripo's source: keep the hand's turn, drop the hand scale and the thumb fit
import inspect, textwrap
_src = textwrap.dedent(inspect.getsource(C.make_tripo))
_a = "k = b.length / a.length; rig.pose.bones[f'hand_{s}'].scale = (k, k, k); bpy.context.view_layer.update()"
assert _a in _src; _src = _src.replace(_a, "k = 1.0")
_i = _src.index("        # the thumb: aim and scale its chain"); _j = _src.index("        print('hand fit'", _i)
_src = _src[:_i] + _src[_j:]
exec(compile(_src, C.__file__, 'exec'), C.__dict__)
rig, body = C.make_tripo(KEY)
import bmesh
HANDB = ('hand', 'thumb', 'index', 'middle', 'ring', 'pinky')
def handish(ob, v, gname, thr):
    w = sum(g.weight for g in v.groups if gname[g.group].split('_')[0] in HANDB)
    return w > thr
# 1) the donor: keep the hands and a short stub of wrist that slides up into the cuff
hd = _KEEP['d']; gn = {g.index: g.name for g in hd.vertex_groups}
fw = {}
for v in hd.data.vertices:
    fw[v.index] = (sum(g.weight for g in v.groups if gn[g.group].split('_')[0] in HANDB), sum(g.weight for g in v.groups if gn[g.group].startswith('lowerarm')))
bm = bmesh.new(); bm.from_mesh(hd.data); bm.verts.ensure_lookup_table()
kill = [bm.verts[i] for i, (h, l) in fw.items() if not (h > .25 or (l > .3 and hd.matrix_world @ hd.data.vertices[i].co and False))]
bmesh.ops.delete(bm, geom=kill, context='VERTS'); bm.to_mesh(hd.data); bm.free()
mw = hd.matrix_world.copy(); hd.parent = rig; hd.matrix_world = mw
am = hd.modifiers.new('rig', 'ARMATURE'); am.object = rig
sub = hd.modifiers.new('sub', 'SUBSURF'); sub.levels = 1; sub.render_levels = 2
for p in hd.data.polygons: p.use_smooth = True
# skin: the generated hand's own colour, with a little mottling and subsurface
skin = bpy.data.materials.new(f'{KEY}_hand_skin'); nt = skin.node_tree; pb = nt.nodes['Principled BSDF']
pb.inputs['Base Color'].default_value = (*LOOK['skin'], 1); pb.inputs['Roughness'].default_value = 0.55
pb.inputs['Subsurface Weight'].default_value = 0.15; pb.inputs['Subsurface Radius'].default_value = (0.9, 0.45, 0.3)
pb.inputs['Subsurface Scale'].default_value = 0.004
nz = nt.nodes.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 180; nz.inputs['Detail'].default_value = 6
cr = nt.nodes.new('ShaderNodeValToRGB'); cr.color_ramp.elements[0].color = (*LOOK['lo'], 1); cr.color_ramp.elements[1].color = (*LOOK['hi'], 1)
nt.links.new(nz.outputs[0], cr.inputs[0]); nt.links.new(cr.outputs[0], pb.inputs['Base Color'])
bp = nt.nodes.new('ShaderNodeBump'); bp.inputs['Strength'].default_value = 0.08; bp.inputs['Distance'].default_value = 0.0005
nz2 = nt.nodes.new('ShaderNodeTexNoise'); nz2.inputs['Scale'].default_value = 900
nt.links.new(nz2.outputs[0], bp.inputs['Height']); nt.links.new(bp.outputs[0], pb.inputs['Normal'])
hd.data.materials.clear(); hd.data.materials.append(skin)
print('donor hand verts', len(hd.data.vertices))

# ---- an older hand's surface: knuckle creases, tendons on the back, faint veins and spots (photos 1-4).
# Smooth per-vertex coordinates are stored (distance along the finger to the nearest joint, how far toward the back of
# the hand, nearness to each tendon line); the shader turns them into sharp lines, so they survive the coarse mesh.
import numpy as np
def hand_attrs():
    me = hd.data; mw = hd.matrix_world
    P = np.array([tuple(mw @ v.co) for v in me.vertices])
    jd = np.full(len(P), 1.0); jk = np.zeros(len(P)); dors = np.zeros(len(P)); tend = np.zeros(len(P)); back = np.zeros(len(P))
    for side, sx in (('l', 1), ('r', -1)):
        S = (P[:, 0] * sx) > 0.03
        hb = np.array(C.bone_head(rig, f'hand_{side}'))
        # palm normal from the hand's points (A pose: the palm faces the thigh, toward the midline)
        Q = P[S]; c = Q.mean(0); _, _, vt = np.linalg.svd(Q - c, full_matrices=False); pn = vt[2]
        if pn[0] * (-sx) < 0: pn = -pn
        dn = -pn                                    # toward the back of the hand
        segs = []
        for f in ('index', 'middle', 'ring', 'pinky', 'thumb'):
            for j, kk in (('01', .45), ('02', 1.0), ('03', .7)):
                b = f'{f}_{j}_{side}'
                segs.append((np.array(C.bone_head(rig, b)), np.array(C.bone_tail(rig, b)), kk, f, j))
        idx = np.where(S)[0]
        for i in idx:
            p = P[i]; best = None
            for a, b, kk, f, j in segs:
                ab = b - a; t = np.clip((p - a) @ ab / (ab @ ab), 0, 1); d = np.linalg.norm(p - (a + t * ab))
                if best is None or d < best[0]: best = (d, a, b, kk, f, j, t)
            d, a, b, kk, f, j, t = best
            ab = b - a; L = np.linalg.norm(ab); u = ab / L
            ax = (p - a) @ u                                     # along the bone from its head (the joint)
            # nearest joint: this bone's head, or its tail (the next joint) when nearer
            if ax > L / 2: ax -= L; kk = {'01': 1.0, '02': .7, '03': 0.0}[j]
            if d < 0.02:
                jd[i] = ax; jk[i] = kk
            r = p - (a + np.clip(ax if ax >= 0 else ax + L, 0, L) * u); r -= u * (r @ u)
            dors[i] = np.clip((r @ dn) / (np.linalg.norm(r) + 1e-9), 0, 1) if d < 0.02 else 0
        # the back of the hand: tendons from the wrist toward each knuckle
        kn = [np.array(C.bone_head(rig, f'{f}_01_{side}')) for f in ('index', 'middle', 'ring', 'pinky')]
        for i in idx:
            p = P[i]
            if (p - hb) @ dn < 0: continue
            bd = 1e9; tpar = 0
            for k_ in kn:
                ab = k_ - hb; t = (p - hb) @ ab / (ab @ ab)
                if t < 0.1 or t > 0.95: continue
                q = p - (hb + t * ab); q -= dn * (q @ dn); dd = np.linalg.norm(q)
                if dd < bd: bd = dd; tpar = t
            if bd < 1e8:
                fade = np.clip((tpar - 0.15) / 0.2, 0, 1) * np.clip((0.95 - tpar) / 0.2, 0, 1)
                tend[i] = np.exp(-(bd / 0.005) ** 2) * fade
                back[i] = fade
    for nm, arr in (('jd', jd), ('jk', jk), ('dors', dors), ('tend', tend), ('back', back)):
        at = me.attributes.new(nm, 'FLOAT', 'POINT'); at.data.foreach_set('value', arr.astype(np.float32))
    print('hand attrs: on fingers', int((jk > 0).sum()), 'tendon verts', int((tend > .3).sum()))
hand_attrs()
def aged_skin(mat):
    nt = mat.node_tree; N = nt.nodes; L = nt.links; pb = N['Principled BSDF']
    def attr(n): a = N.new('ShaderNodeAttribute'); a.attribute_name = n; return a.outputs['Fac']
    def m(op, a, b=None, c=None):
        n = N.new('ShaderNodeMath'); n.operation = op
        for k_, v in enumerate((a, b, c)):
            if v is None: continue
            if isinstance(v, (int, float)): n.inputs[k_].default_value = v
            else: L.new(v, n.inputs[k_])
        return n.outputs[0]
    jd, jk, dors, tend, back = attr('jd'), attr('jk'), attr('dors'), attr('tend'), attr('back')
    # creases: lines 1.4 mm apart within 4 mm of a joint, on the back of the fingers
    ph = m('MULTIPLY', jd, 2 * math.pi / 0.0014); cs = m('COSINE', ph)
    line = m('POWER', m('MULTIPLY_ADD', cs, 0.5, 0.5), 6.0)
    win = m('SUBTRACT', 1.0, m('SMOOTH_MIN', m('ABSOLUTE', m('DIVIDE', jd, 0.004)), 1.0, 0.3))
    crease = m('MULTIPLY', m('MULTIPLY', line, win), m('MULTIPLY', jk, m('POWER', dors, 0.7)))
    # veins: thin cell edges on the back of the hand
    # a few long wavering lines running up the back of the hand (not a web): thin crests of distorted bands, broken by noise
    tc = N.new('ShaderNodeTexCoord'); wv = N.new('ShaderNodeTexWave'); wv.wave_type = 'BANDS'; wv.bands_direction = 'Z'
    wv.inputs['Scale'].default_value = 3.0; wv.inputs['Distortion'].default_value = 6.0; wv.inputs['Detail'].default_value = 2.0; wv.inputs['Detail Scale'].default_value = 1.5
    L.new(tc.outputs['Generated'], wv.inputs['Vector'])
    crest = m('POWER', wv.outputs['Fac'], 10.0)
    nm = N.new('ShaderNodeTexNoise'); nm.inputs['Scale'].default_value = 6; L.new(tc.outputs['Generated'], nm.inputs['Vector'])
    brk = m('MAXIMUM', m('MULTIPLY', m('SUBTRACT', nm.outputs['Fac'], 0.45), 4.0), 0.0)
    vein = m('MULTIPLY', m('MULTIPLY', crest, m('MINIMUM', brk, 1.0)), back)
    # age spots
    nz = N.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 260; nz.inputs['Detail'].default_value = 2
    L.new(tc.outputs['Generated'], nz.inputs['Vector'])
    spot = m('MULTIPLY', m('MAXIMUM', m('SUBTRACT', nz.outputs['Fac'], 0.66), 0.0), m('MULTIPLY', back, 6.0))
    # colour: base mottling (already in), creases and knuckles a little darker and redder, veins bluish, spots brown
    base = pb.inputs['Base Color'].links[0].from_socket
    mix1 = N.new('ShaderNodeMix'); mix1.data_type = 'RGBA'; mix1.inputs['B'].default_value = (0.42, 0.26, 0.22, 1)
    L.new(m('MINIMUM', m('MULTIPLY', crease, 0.6), 1.0), mix1.inputs['Factor']); L.new(base, mix1.inputs['A'])
    mix2 = N.new('ShaderNodeMix'); mix2.data_type = 'RGBA'; mix2.inputs['B'].default_value = (0.42, 0.40, 0.48, 1)
    L.new(m('MULTIPLY', vein, 0.45), mix2.inputs['Factor']); L.new(mix1.outputs['Result'], mix2.inputs['A'])
    mix3 = N.new('ShaderNodeMix'); mix3.data_type = 'RGBA'; mix3.inputs['B'].default_value = (0.45, 0.30, 0.20, 1)
    L.new(m('MINIMUM', spot, 0.5), mix3.inputs['Factor']); L.new(mix2.outputs['Result'], mix3.inputs['A'])
    L.new(mix3.outputs['Result'], pb.inputs['Base Color'])
    # relief: creases cut in, tendons and veins stand up a little, plus the fine pore bump already there
    h = m('ADD', m('MULTIPLY', crease, -1.0), m('ADD', m('MULTIPLY', tend, 1.6), m('MULTIPLY', vein, 0.9)))
    bp2 = N.new('ShaderNodeBump'); bp2.inputs['Strength'].default_value = 0.6; bp2.inputs['Distance'].default_value = 0.0012
    L.new(h, bp2.inputs['Height'])
    old = pb.inputs['Normal'].links[0].from_socket; L.new(old, bp2.inputs['Normal']); L.new(bp2.outputs['Normal'], pb.inputs['Normal'])
if LOOK['aged']: aged_skin(skin)
# 2) the generated body loses its own hands (everything mostly weighted to the hand chain)
gb = {g.index: g.name for g in body.vertex_groups}
bm = bmesh.new(); bm.from_mesh(body.data); bm.verts.ensure_lookup_table()
import numpy as _np
_mat = body.data.materials[0]; _img = [n for n in _mat.node_tree.nodes if n.type == 'TEX_IMAGE'][0].image
_W, _H = _img.size; _buf = _np.empty(_W * _H * 4, _np.float32); _img.pixels.foreach_get(_buf); _px = _buf.reshape(_H, _W, 4)
_uv = body.data.uv_layers[0]
def _skin_poly(p):
    u = sum((_uv.data[li].uv for li in p.loop_indices), __import__('mathutils').Vector((0, 0))) / len(p.loop_indices)
    c = _px[min(_H - 1, int(u[1] * _H)), min(_W - 1, int(u[0] * _W)), :3]; t = c.sum()
    if KEY == 'mio':   # 澪の肌は明るく黄みが薄いので、聞き手の閾では手首の肌の切れ端が残って角に見えた（F の画、2026-11-16）
        return t > 1.2 and c[0] / t > .37 and c[2] / t < .30
    return t > .3 and c[0] / t > .40 and c[2] / t < .27
_armw = {}
for v in body.data.vertices:
    _armw[v.index] = (sum(g.weight for g in v.groups if gb[g.group].split('_')[0] in HANDB), sum(g.weight for g in v.groups if gb[g.group].startswith('lowerarm')))
kill = [bm.verts[v.index] for v in body.data.vertices if _armw[v.index][0] > .9]
_skinv = {i for p in body.data.polygons if (sum(_armw[i][0] + _armw[i][1] for i in p.vertices) / len(p.vertices)) > .4 and _skin_poly(p) for i in p.vertices}
_skinp = [p.index for p in body.data.polygons if (sum(_armw[i][0] + _armw[i][1] for i in p.vertices) / len(p.vertices)) > .4 and _skin_poly(p)]
print('skin bits on the forearms recoloured', len(_skinp))
if KEY == 'mio':   # 澪：手首の肌の切れ端は色を変えると黒い破片に見えるので、消して MakeHuman の手首を見せる（F の画、2026-11-16）
    bm.verts.ensure_lookup_table(); _kp = set(_skinp)
    kill = list({*kill, *[bm.verts[i] for p in body.data.polygons if p.index in _kp for i in p.vertices]}); _skinp = []
_pm0 = bpy.data.materials.get(f'{KEY}_patch')
if _pm0 is None:
    _pm0 = bpy.data.materials.new(f'{KEY}_patch'); _pm0.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (*LOOK['sleeve'], 1)
if _pm0 is not None and _pm0.name not in body.data.materials: body.data.materials.append(_pm0)
if _pm0 is not None:
    _mi0 = list(body.data.materials).index(_pm0)
    bm.faces.ensure_lookup_table()
    for i in _skinp: bm.faces[i].material_index = _mi0
bmesh.ops.delete(bm, geom=kill, context='VERTS')
# the cut left a saw-toothed cuff (the weights step from triangle to triangle): trim the teeth, then even the edge out
_wr = [rig.matrix_world @ rig.data.bones[f'hand_{sd}'].head_local for sd in ('l', 'r')]
def _near_wrist(p):
    return min((body.matrix_world @ p - w).length for w in _wr) < 0.07
def _cuff(bm):
    for _ in range(4):   # teeth: faces hanging on by two or more open edges, near the wrists
        teeth = [f for f in bm.faces if sum(e.is_boundary for e in f.edges) >= 2 and _near_wrist(f.calc_center_median())]
        if not teeth: break
        bmesh.ops.delete(bm, geom=teeth, context='FACES')
        loose = [v for v in bm.verts if not v.link_faces]; bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bv = [v for v in bm.verts if v.is_boundary and any(_armw.get(0) is None or True for _ in [0])]
    arm = [v for v in bv if _near_wrist(v.co)]           # only the two sleeve openings
    for _ in range(12):   # slide each open vertex toward the middle of its two open neighbours
        new = {}
        for v in arm:
            nb = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
            if len(nb) == 2: new[v] = v.co * 0.5 + (nb[0].co + nb[1].co) * 0.25
        for v, c in new.items(): v.co = c
    return len(arm)
print('cuff edge verts evened', _cuff(bm))
bm.to_mesh(body.data); bm.free()
print('generated hand verts removed', len(kill))
# skin-coloured bits the generator left on the sleeves (they read as holes): cardigan navy instead
_pm = bpy.data.materials.get(f'{KEY}_patch')
if _pm is None:
    _pm = bpy.data.materials.new(f'{KEY}_patch'); _pm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (*LOOK['sleeve'], 1)
if _pm.name not in body.data.materials: body.data.materials.append(_pm)
_mi = list(body.data.materials).index(_pm)
_left = {tuple(round(c, 5) for c in body.data.polygons[i].center) for i in _skinp} if False else None
# 澪の首の付け根（2026-11-16）：頭（髪ごとの Tripo）の首の下の端と、セーターの襟のゴムの間に、体の地図の白っぽい帯が見える
# （下着の襟のように見えて、首に白い線が入る）。その帯の面だけを、首の下の端の肌の色にする。聞き手はシャツの白い襟なので触らない
if KEY == 'mio':
    _hd = bpy.data.objects[f'{KEY}_hair']; _hm = _hd.data.materials[0]
    _himg = [n for n in _hm.node_tree.nodes if n.type == 'TEX_IMAGE'][0].image
    _hW, _hH = _himg.size; _hb = _np.empty(_hW * _hH * 4, _np.float32); _himg.pixels.foreach_get(_hb); _hpx = _hb.reshape(_hH, _hW, 4)
    _hv = [_hd.matrix_world @ v.co for v in _hd.data.vertices]
    _z0 = min(v.z for v in _hv if abs(v.x) < 0.06)
    _huv = _hd.data.uv_layers[0]; _cs = []
    for p_ in _hd.data.polygons:
        c_ = _hd.matrix_world @ p_.center
        if abs(c_.x) < 0.05 and c_.z < _z0 + 0.015 and c_.y < 0:   # 首の前の下の端
            u = sum((_huv.data[li].uv for li in p_.loop_indices), __import__('mathutils').Vector((0, 0))) / len(p_.loop_indices)
            _cs.append(_hpx[min(_hH - 1, int(u[1] * _hH)), min(_hW - 1, int(u[0] * _hW)), :3])
    _sk = _np.median(_np.array(_cs), axis=0); print('neck skin (texture)', _sk.round(3), len(_cs))
    _nm = bpy.data.materials.new(f'{KEY}_neck_skin'); _pb = _nm.node_tree.nodes['Principled BSDF']
    _skl = ((_sk + 0.055) / 1.055) ** 2.4; _pb.inputs['Base Color'].default_value = (*_skl, 1)   # 地図の値は sRGB; _pb.inputs['Roughness'].default_value = 0.55
    body.data.materials.append(_nm); _ni = len(body.data.materials) - 1
    _uv2 = body.data.uv_layers[0]; _n = 0
    for p_ in body.data.polygons:
        c_ = body.matrix_world @ p_.center
        if abs(c_.x) < 0.085 and _z0 - 0.04 < c_.z < _z0 + 0.012:
            u = sum((_uv2.data[li].uv for li in p_.loop_indices), __import__('mathutils').Vector((0, 0))) / len(p_.loop_indices)
            col = _px[min(_H - 1, int(u[1] * _H)), min(_W - 1, int(u[0] * _W)), :3]
            if col.sum() > 1.5: p_.material_index = _ni; _n += 1
    print('neck band faces recoloured', _n, 'z0', round(_z0, 4))
    # 頭の首は体の首より 1.5cm ほど太く、つなぎ目に段の線が出る（ユーザー 2026-11-16「謎の線なくして」）：
    # 頭の首の下 4cm を、いちばん近い体の面へ寄せて（下ほど強く）、段なしで体に乗せる
    from mathutils.bvhtree import BVHTree as _BVH
    _bbm = bmesh.new(); _bbm.from_mesh(body.data); _bbm.transform(body.matrix_world); _bt = _BVH.FromBMesh(_bbm)
    _iw = _hd.matrix_world.inverted(); _nl = 0
    for v in _hd.data.vertices:
        w = _hd.matrix_world @ v.co
        if w.z < _z0 + 0.04 and abs(w.x) < 0.09:
            hit = _bt.find_nearest(w)
            if hit[0] is None or hit[3] > 0.03: continue
            k = max(0.0, min(1.0, 1 - (w.z - _z0) / 0.04)); k = k * k * (3 - 2 * k)
            tgt = hit[0] + hit[1].normalized() * 0.0006
            v.co = _iw @ (w.lerp(tgt, k)); _nl += 1
    _bbm.free(); print('neck step blended', _nl)
    # 顎の描き込みの筋（頭の画像に髪の筋が描かれて、顎に黒い線が出る）：顎の肌の面の中の暗い画素だけを肌の色で埋める
    from PIL import Image as _PI, ImageDraw as _PD
    _cy = sum(w.y for w in _hv) / len(_hv); _fr = min(w.y for w in _hv if abs(w.x) < 0.03 and w.z > _z0 + 0.06)
    _mask = _PI.new('L', (_hW, _hH), 0); _md = _PD.Draw(_mask); _nf = 0
    _skl_lum = float(_sk @ _np.array([.3, .59, .11]))
    for p_ in _hd.data.polygons:
        c_ = _hd.matrix_world @ p_.center
        if _z0 + 0.025 < c_.z < _z0 + 0.12 and abs(c_.x) < 0.075 and c_.y < _fr + 0.06:
            uvs = [_huv.data[li].uv for li in p_.loop_indices]
            u = sum(uvs, __import__('mathutils').Vector((0, 0))) / len(uvs)
            med = _hpx[min(_hH - 1, int(u[1] * _hH)), min(_hW - 1, int(u[0] * _hW)), :3]
            if float(med @ _np.array([.3, .59, .11])) > 0.6 * _skl_lum:   # 肌の面だけ（垂れた髪の面は触らない）
                _md.polygon([(q[0] * _hW, (1 - q[1]) * _hH) for q in uvs], fill=255); _nf += 1
    _m = _np.asarray(_mask)[::-1] > 0   # 画像の行は下から
    _lum = _hpx[..., :3] @ _np.array([.3, .59, .11])
    _dark = _m & (_lum < 0.80 * _skl_lum)
    _px2 = _hpx.copy(); _px2[_dark, :3] = _sk
    _ni2 = bpy.data.images.new(f'{KEY}_head_clean', _hW, _hH, alpha=True); _ni2.pixels.foreach_set(_px2.ravel()); _ni2.pack()
    for n in _hm.node_tree.nodes:
        if n.type == 'TEX_IMAGE' and n.image == _himg: n.image = _ni2
    print('jaw strokes cleaned: faces', _nf, 'pixels', int(_dark.sum()))
    # 顎の黒い筋の本体は、顔の絵（mio_head）の下と横のふちの線だった：ふちの面の中の暗い画素を、顔の肌の色で埋める（口と目は触らない）
    _fo = bpy.data.objects[f'{KEY}_head']; _fm = _fo.data.materials[0]
    _fn = [n for n in _fm.node_tree.nodes if n.type == 'TEX_IMAGE'][0]; _fimg = _fn.image
    _fW, _fH = _fimg.size; _fb = _np.empty(_fW * _fH * 4, _np.float32); _fimg.pixels.foreach_get(_fb); _fpx = _fb.reshape(_fH, _fW, 4)
    _fuv = _fo.data.uv_layers[0]; _fz = [(_fo.matrix_world @ v.co).z for v in _fo.data.vertices]; _fz0 = min(_fz)
    # 顔の絵の中で、口の下から顎と首の付け根まで（画像の座標。口のまわりは残す）。絵の顎の輪郭と頬に落ちた髪の筋が、3Dの顎に線として乗っていた
    _fmask = _PI.new('L', (_fW, _fH), 0); _fd = _PD.Draw(_fmask); _sx = _fW / 1254
    _fd.ellipse((420 * _sx, 470 * _sx, 840 * _sx, 820 * _sx), fill=255); _fd.rectangle((0, 0, _fW, 560 * _sx), fill=0)
    _fd.rectangle((400 * _sx, 400 * _sx, 470 * _sx, 760 * _sx), fill=255); _fd.rectangle((790 * _sx, 400 * _sx, 860 * _sx, 760 * _sx), fill=255)   # 頬に落ちた髪の筋
    _fd.ellipse((545 * _sx, 625 * _sx, 715 * _sx, 715 * _sx), fill=0)   # 口
    _fmk = _np.asarray(_fmask)[::-1] > 0; _fl = _fpx[..., :3] @ _np.array([.3, .59, .11]); _nff = int(_fmk.sum())
    _fsk = _np.median(_fpx[_fmk & (_fl > _np.percentile(_fl[_fmk], 60))][:, :3], axis=0)
    _fdark = _fmk & (_fl < 0.93 * float(_fsk @ _np.array([.3, .59, .11])))
    # 埋める色：まわりの明るい肌だけをぼかした色（平たい色の斑にしない）
    def _box(a, r):   # 箱のぼかしを3回（ガウスの代わり）
        r = max(1, int(r))
        for _ in range(3):
            for ax in (0, 1):
                c = _np.cumsum(_np.pad(a, [(r + 1, r) if i == ax else (0, 0) for i in range(2)], mode='edge'), axis=ax)
                a = (_np.take(c, range(2 * r + 1, c.shape[ax]), axis=ax) - _np.take(c, range(0, c.shape[ax] - 2 * r - 1), axis=ax)) / (2 * r + 1)
        return a
    _ok = (~_fdark).astype(_np.float32); _acc = []
    den = _box(_ok, 8 * _sx)
    for ch in range(3):
        _acc.append(_box(_fpx[..., ch] * _ok, 8 * _sx) / _np.maximum(den, 1e-3))
    _fill = _np.stack(_acc, -1)
    _fp2 = _fpx.copy(); _fp2[_fdark, :3] = _fill[_fdark]
    _fi2 = bpy.data.images.new(f'{KEY}_face_clean', _fW, _fH, alpha=True); _fi2.pixels.foreach_set(_fp2.ravel()); _fi2.pack(); _fn.image = _fi2
    print('face edge lines cleaned: mask px', _nff, 'pixels', int(_fdark.sum()), 'skin', _fsk.round(3))
OUT = sys.argv[-1] if sys.argv[-1].endswith('.blend') else f'/home/claude/work/kikite/{KEY}_rest.blend'
for b in ('pelvis', 'thigh_l', 'calf_l', 'foot_l', 'ball_l', 'spine_03', 'neck_01', 'head', 'upperarm_l', 'lowerarm_l', 'hand_l'):
    print('BONE', b, tuple(round(x, 3) for x in C.bone_head(rig, b)), tuple(round(x, 3) for x in C.bone_tail(rig, b)))
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print('SAVED', OUT)

"""Tripo (H3.1 multi-view, Pro) Natsuki: body mesh + separately generated head, joined into one figure.
Head scaled so the eyes sit 62 mm apart and the chin meets the body's chin line; the body loses everything
above its collar, the head keeps its neck down into the collar. The front of the face is split off as its own
object with UVs that project the drawn portrait (eyes matched, jaw outline matched row by row), so the game can
swap open / closed / talking faces exactly as before.  Output: kikite_prep.blend"""
import bpy, bmesh, sys, math
import numpy as np
import os; sys.path.insert(0, '/home/user/notlw/blender'); import paths as P   # all paths: paths.env
from mathutils import Vector
import json

T = '/home/claude/work/kikite'
A_HEIGHT = 0.98
H_BODY = 1.57 / A_HEIGHT
S_HEAD = 0.36
A_CHIN = 0.843
B_CHIN = 0.352
B_EYE_Z = 0.6625; B_EYE_X = -0.0015; B_EYED = 0.165
B_CUT = 0.0
NECK_K = 1.0
A_CUT = 0.835
from mathutils import Matrix as _Mx
NORM = _Mx.Translation((0, 0, 0.49)) @ _Mx.Rotation(-math.pi / 2, 4, 'Z')   # these two came out centred and facing +X

def imp(f):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f)
    o = [o for o in bpy.data.objects if o not in before and o.type == 'MESH'][0]
    o.select_set(True); bpy.context.view_layer.objects.active = o
    o.parent = None
    o.matrix_world = NORM @ o.matrix_world
    return o

def apply_tf(o):
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

def clean_mat(o):
    for m in o.data.materials:
        p = [n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'][0]
        for inp in ('Metallic',):
            for l in list(p.inputs[inp].links): m.node_tree.links.remove(l)
            p.inputs[inp].default_value = 0.0
        p.inputs['Roughness'].default_value = .75
        for l in list(p.inputs['Roughness'].links): m.node_tree.links.remove(l)

def albedo_sampler(o):
    m = o.data.materials[0]; p = [n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'][0]
    img = p.inputs['Base Color'].links[0].from_node.image
    W, Hh = img.size; buf = np.empty(W * Hh * 4, np.float32); img.pixels.foreach_get(buf)   # no python list (4K x 4K)
    px = buf.reshape(Hh, W, 4)[..., :3]
    return lambda uv: px[min(Hh - 1, max(0, int(uv[1] * Hh))), min(W - 1, max(0, int(uv[0] * W)))]

def cut(o, keep):
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not keep(v.co)], context='VERTS')
    bm.to_mesh(o.data); bm.free()

def decimate(o, ratio):
    md = o.modifiers.new('dec', 'DECIMATE'); md.ratio = ratio; md.delimit = {'UV'}   # never collapse across a UV seam: that bleeds the next island's colour in as dark streaks
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier='dec')

bpy.ops.wm.read_factory_settings(use_empty=True)
A = imp(f'{T}/kikite_body.glb'); apply_tf(A); A.name = 'kikite_body'   # generated facing +Y
B = imp(f'{T}/kikite_head.glb'); apply_tf(B); B.name = 'kikite_hair'
clean_mat(A); clean_mat(B)
# glTF stores one UV per vertex, so the importer leaves the head split along every UV island: weld those duplicates
# (the UVs stay per corner), otherwise any smoothing of the face tears cracks between islands
bm = bmesh.new(); bm.from_mesh(B.data); n0 = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5); bm.to_mesh(B.data); print('head welded', n0, '->', len(bm.verts)); bm.free()
A.data.materials[0].name = 'kikite_tripo_body'; B.data.materials[0].name = 'kikite_tripo_head'

# ---- place
A.data.transform(__import__('mathutils').Matrix.Diagonal((H_BODY, H_BODY, H_BODY, 1)))
cut(B, lambda c: c.z > min(B_CUT, .02))   # keep the whole neck; the world-z cut at the collar decides later
for v in B.data.vertices:
    if v.co.z < .19: v.co.z = .19 - (.19 - v.co.z) * NECK_K
# neck centre of each, so the head sits on the neck front-to-back
def slice_center(o, z0, z1, xmax):
    cs = [v.co for v in o.data.vertices if z0 <= v.co.z <= z1 and abs(v.co.x) < xmax]
    return sum((c.y for c in cs), 0.0) / max(1, len(cs))
yb = slice_center(B, .19 - .09 * NECK_K, .19 - .03 * NECK_K, .15)
B.data.transform(__import__('mathutils').Matrix.Diagonal((S_HEAD, S_HEAD, S_HEAD, 1)))
zA_chin = A_CHIN * H_BODY
dz = zA_chin - B_CHIN * S_HEAD
ya = slice_center(A, (A_CUT - .012) * H_BODY, (A_CUT + .004) * H_BODY, .05)
B.data.transform(__import__('mathutils').Matrix.Translation((-B_EYE_X * S_HEAD, ya - yb * S_HEAD, dz)))
# A_CUT was read at the collar's rim. A flat cut there leaves the collar as a tube with a sliced top; instead the body is
# cut 3 cm higher and the bare neck above the rim (everything narrower than the rim's opening) is removed, so the
# collar keeps its own rounded top and the head's neck goes down inside it
collar_z = A_CUT * H_BODY
_av = [v.co for v in A.data.vertices if collar_z - .004 <= v.co.z <= collar_z + .004]
_cx = sum(c.x for c in _av) / len(_av); _cy = sum(c.y for c in _av) / len(_av)
_rim = sorted(math.hypot(c.x - _cx, c.y - _cy) for c in _av)[len(_av) // 10]    # the opening (10th percentile)
# the body's own skin colour, read off its neck just above the collar (inside the opening) before the cut: the
# cheek of the generated head can differ from the body's texture (Natsuki's socks body: nothing matched)
_sa0 = albedo_sampler(A); _uv0 = A.data.uv_layers[0]; _nk = []
for _p in A.data.polygons:
    _c0 = _p.center
    if collar_z + .012 < _c0.z < collar_z + .045 and math.hypot(_c0.x - _cx, _c0.y - _cy) < _rim * .95:
        _u0 = sum((_uv0.data[li].uv for li in _p.loop_indices), Vector((0, 0))) / len(_p.loop_indices)
        _c1 = _sa0(_u0); _nk.append(_c1 / max(_c1.sum(), 1e-4))
del _sa0
_body_skin = np.median(np.array(_nk), axis=0) if len(_nk) > 20 else None
print('body neck skin samples', len(_nk), np.round(_body_skin, 3) if _body_skin is not None else None)
CUT_UP = .012   # Natsuki's crew neck sits at collar_z; above it the generated body has skin-coloured stand-up flaps (others: .012)
cut(A, lambda c: c.z < collar_z + CUT_UP)
# the bare neck left on the body above the collar line is removed by colour (skin), so the cloth of the collar keeps
# its own shape whatever its cut; the head's neck replaces it
_sa = albedo_sampler(A); _uv = A.data.uv_layers[0]
_cs = []
for _p in A.data.polygons:
    if _p.center.z < collar_z - .03: continue
    _u = sum((_uv.data[li].uv for li in _p.loop_indices), Vector((0, 0))) / len(_p.loop_indices)
    _c = _sa(_u); _r = _c / max(_c.sum(), 1e-4)
    _cs.append((_p.index, _r))
del _sa
# skin reference: the generated head's cheek colour (sRGB, read off an unlit render; set per person) in linear light
_ck = np.array([0.878, 0.716, 0.603]); _ck = np.where(_ck <= .04045, _ck / 12.92, ((_ck + .055) / 1.055) ** 2.4)
_skin_ref = _ck / _ck.sum()
# (the body's own neck colour was tried as the reference: on Natsuki's socks body it matches the cream sweater too)
print('neck skin ratio', np.round(_skin_ref, 3))
_gone = [i for i, r in _cs if np.abs(np.array(r) - _skin_ref).sum() < .06]
# and by shape: anything left inside the collar's opening (the body's own neck stub and its flaps) goes; the head's
# neck fills the opening
NECK_GEOM = False   # Natsuki only: on Makoto it cut into the collar ribbing
_gone = set(_gone) | {_p.index for _p in A.data.polygons if NECK_GEOM and _p.center.z > collar_z - .025 and math.hypot(_p.center.x - _cx, _p.center.y - _cy) < _rim * .9}
_gone = sorted(_gone)
bm = bmesh.new(); bm.from_mesh(A.data); bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[bm.faces[i] for i in _gone], context='FACES'); bm.to_mesh(A.data); bm.free()
print('neck skin polys removed from the body', len(_gone))
print('collar rim r', round(_rim, 4))
# drop the little islands the cut leaves behind (bits of the generated jaw or neck)
bm = bmesh.new(); bm.from_mesh(A.data); bm.verts.ensure_lookup_table()
seen = set(); small = []; comps = []
for v in bm.verts:
    if v.index in seen: continue
    stack = [v]; comp = []
    while stack:
        u = stack.pop()
        if u.index in seen: continue
        seen.add(u.index); comp.append(u)
        for e in u.link_edges: stack.append(e.other_vert(u))
    if min(u.co.z for u in comp) > collar_z - .04: comps.append(comp)   # only bits at the neck cut, never shells elsewhere (sleeves)
# a shell at the neck stays only if it is cloth: its colour must match the shirt just below the collar (the generated
# body carries hair-tip and skin shells there that read as a brown ruff)
_sa = albedo_sampler(A); _uvl = bm.loops.layers.uv[0]
def _fcol(f): return _sa(sum((l[_uvl].uv for l in f.loops), Vector((0, 0))) / len(f.loops))
_ref = np.median(np.array([_fcol(f) for f in bm.faces if collar_z - .09 < f.calc_center_median().z < collar_z - .05]), axis=0)
for comp in comps:
    fs = {f for u in comp for f in u.link_faces}
    col = np.median(np.array([_fcol(f) for f in fs]), axis=0) if fs else _ref * 0
    d = np.abs(col - _ref).sum() / max(_ref.sum(), 1e-4)
    if len(comp) < 200 or d > .25: small += comp
    else:   # cloth, but the generated shells crumple up above the collar's rim into a ruff: keep only what lies below it
        small += [u for u in comp if u.co.z > collar_z + .001]
        print('collar shell kept', len(comp), round(float(d), 3), 'clipped', sum(u.co.z > collar_z + .001 for u in comp))
print('shirt ref', np.round(_ref, 3))
bmesh.ops.delete(bm, geom=small, context='VERTS')
# above the collar's rim only shirt-coloured cloth stays (skin and hair knots of the generated neck go), then crumbs
bm.faces.ensure_lookup_table()
def _skinish(f):
    c_ = _fcol(f); return np.abs(c_ / max(c_.sum(), 1e-4) - _skin_ref).sum() < .07
def _outside(f):
    p_ = f.calc_center_median(); return math.hypot(p_.x - _cx, p_.y - _cy) > _rim * 1.15
_knot = [f for f in bm.faces if (f.calc_center_median().z > collar_z + .002 and np.abs(_fcol(f) - _ref).sum() / max(_ref.sum(), 1e-4) > .25)
         or (NECK_GEOM and f.calc_center_median().z > collar_z + .002 and _skinish(f))   # skin-coloured stand-up bits of the generated neck above the rim
         or (f.calc_center_median().z > collar_z - .02 and _outside(f) and _skinish(f))   # skin knots on the shoulders
         or (f.calc_center_median().z > collar_z + .004 and math.hypot(f.calc_center_median().x - _cx, f.calc_center_median().y - _cy) > _rim * 1.3)]   # tabs standing up off the shoulders
bmesh.ops.delete(bm, geom=_knot, context='FACES'); print('non-cloth faces above the collar removed', len(_knot))
del _sa
bm.verts.ensure_lookup_table(); seen = set(); small = []
for v in bm.verts:
    if v.index in seen: continue
    stack = [v]; comp = []
    while stack:
        u = stack.pop()
        if u.index in seen: continue
        seen.add(u.index); comp.append(u)
        for e in u.link_edges: stack.append(e.other_vert(u))
    if len(comp) < 200 and min(u.co.z for u in comp) > collar_z - .04: small += comp
bmesh.ops.delete(bm, geom=small, context='VERTS'); bm.to_mesh(A.data); bm.free(); print('body islands removed verts', len(small))
cut(B, lambda c: c.z > collar_z - .022)
def _white(c): return min(c) > .45 and max(c) - min(c) < .1 * max(c)
_sb = albedo_sampler(B); _uvb = B.data.uv_layers[0]
_wh = [p.index for p in B.data.polygons if p.center.z < zA_chin - .01 and _white(_sb(sum((_uvb.data[li].uv for li in p.loop_indices), Vector((0, 0))) / len(p.loop_indices)))]
bm = bmesh.new(); bm.from_mesh(B.data); bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[bm.faces[i] for i in _wh], context='FACES'); bm.to_mesh(B.data); bm.free(); del _sb
print('white cloth faces removed from the head', len(_wh))
# below the chin only the neck stays (the cloth's rim and anything wider than the collar opening go)
cut(B, lambda c: c.z > zA_chin - .005 or math.hypot(c.x - _cx, c.y - _cy) < _rim * 1.4)
# the cloth's top left a brown ledge round the bottom of the neck: flat-lying faces low on the neck go
bm = bmesh.new(); bm.from_mesh(B.data); bm.faces.ensure_lookup_table()
_ledge = [f for f in bm.faces if f.calc_center_median().z < zA_chin - .012 and abs(f.normal.z) > .45]
bmesh.ops.delete(bm, geom=_ledge, context='FACES'); print('neck ledge faces', len(_ledge))
_iso = [v for v in bm.verts if not v.link_faces]; bmesh.ops.delete(bm, geom=_iso, context='VERTS')
bm.to_mesh(B.data); bm.free()
# the body was generated with its own ponytail hanging over the back of the cardigan: neutral grey above the waist goes
_sa2 = albedo_sampler(A); _uva = A.data.uv_layers[0]
def _navy(c):
    t = c.sum(); return t > 1e-4 and c[2] / t > .36
_lump_ids = None
def _lump(p):   # behind the neck, outside the collar or below its rim, and not cardigan: the ponytail
    return p.z > 1.2 and p.y > _cy + .015 and (math.hypot(p.x - _cx, p.y - _cy) > _rim * 1.35 or p.z < collar_z - .025)
def _hairish(c):
    t = c.sum(); return t > 1e-4 and c[2] / t < .355 and c.max() < .6 and abs(c[0] - c[1]) < .06 * max(c.max(), .05)
def _pc(p): return _sa2(sum((_uva.data[li].uv for li in p.loop_indices), Vector((0, 0))) / len(p.loop_indices))
_hp = [p.index for p in A.data.polygons if p.center.z > 1.05 and p.center.y > -.02 and (_hairish(_pc(p)) or (_lump(p.center) and not _navy(_pc(p))))]
bm = bmesh.new(); bm.from_mesh(A.data); bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[bm.faces[i] for i in _hp], context='FACES'); bm.to_mesh(A.data); bm.free(); del _sa2
print('body hair faces removed', len(_hp))
# crumbs the colour test leaves, then close the hole on the back (nothing was generated under the ponytail) with
# a flat cardigan-navy patch
bm = bmesh.new(); bm.from_mesh(A.data); bm.verts.ensure_lookup_table()
seen = set(); kill = []
for v in bm.verts:
    if v.index in seen: continue
    stack = [v]; comp = []
    while stack:
        u = stack.pop()
        if u.index in seen: continue
        seen.add(u.index); comp.append(u)
        for e in u.link_edges: stack.append(e.other_vert(u))
    if len(comp) < 400 and min(u.co.z for u in comp) > 1.0: kill += comp
bmesh.ops.delete(bm, geom=kill, context='VERTS'); print('crumbs', len(kill))
bm.verts.ensure_lookup_table(); bm.edges.ensure_lookup_table()
bv = {v for e in bm.edges if e.is_boundary for v in e.verts if v.co.y > _cy and 1.2 < v.co.z < collar_z - .006 and abs(v.co.x - _cx) < .12}
rows = []
z = collar_z - .008
while z > 1.2:
    band = [v for v in bv if abs(v.co.z - z) < .004]
    L = [v for v in band if v.co.x < _cx - .004]; R = [v for v in band if v.co.x > _cx + .004]
    if not L or not R: break
    rows.append((max(L, key=lambda v: v.co.x).co.copy(), min(R, key=lambda v: v.co.x).co.copy()))
    z -= .006
print('back patch rows', len(rows))
_nv = bpy.data.materials.new('kikite_patch')
_pb = _nv.node_tree.nodes['Principled BSDF']; _pb.inputs['Base Color'].default_value = (*[float(x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4) for x in _ref], 1); _pb.inputs['Roughness'].default_value = .9
A.data.materials.append(_nv); mi = len(A.data.materials) - 1
NC = 10; grid = []
for (l, r) in rows:
    al = math.atan2(l.x - _cx, l.y - _cy); ar = math.atan2(r.x - _cx, r.y - _cy)
    rl = math.hypot(l.x - _cx, l.y - _cy); rr = math.hypot(r.x - _cx, r.y - _cy)
    line = []
    for k in range(NC + 1):
        t = k / NC; a = al + (ar - al) * t; rad = (rl + (rr - rl) * t) * (1 + .03 * math.sin(math.pi * t))
        line.append(bm.verts.new((_cx + math.sin(a) * rad, _cy + math.cos(a) * rad, l.z + (r.z - l.z) * t)))
    grid.append(line)
if len(rows) > 1:   # close the bottom tip of the notch with the last row collapsed to its middle
    pass
for a_, b_ in zip(grid, grid[1:]):
    for k in range(NC):
        f = bm.faces.new((a_[k], a_[k + 1], b_[k + 1], b_[k])); f.material_index = mi

bm.to_mesh(A.data); bm.free()   # the head's neck stops 22 mm inside the collar
# straighten the cut collar edge
bm = bmesh.new(); bm.from_mesh(A.data)
for _ in range(30):
    nb = {}
    for v in bm.verts:
        if v.is_boundary and v.co.z > (A_CUT - .03) * H_BODY:
            ns = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
            if len(ns) == 2: nb[v] = (ns[0].co + ns[1].co) / 2
    for v, c in nb.items(): v.co = v.co.lerp(c, .5)
bm.to_mesh(A.data); bm.free()
# where the generated body's own hair lay over the back of the collar (Makoto), the cut leaves a sawtooth rim with
# loose tabs: neighbour smoothing cannot untangle it. Instead the rim height is read per direction around the neck,
# smoothed round the ring, everything above it goes and the new rim is laid on that curve. Per person (Kiryu's shirt
# collar stands up and must keep its shape)
COLLAR_RING = False
if COLLAR_RING:
    RB = 72
    bm = bmesh.new(); bm.from_mesh(A.data); bm.verts.ensure_lookup_table()
    def _ang(c_): return int((math.atan2(c_.y - _cy, c_.x - _cx) + math.pi) / math.tau * RB) % RB
    near = lambda c_: math.hypot(c_.x - _cx, c_.y - _cy) < _rim * 1.6 and c_.z > collar_z - .04
    zs_ = [[] for _ in range(RB)]
    for v in bm.verts:
        if v.is_boundary and near(v.co) and math.hypot(v.co.x - _cx, v.co.y - _cy) < _rim * 1.3: zs_[_ang(v.co)].append(v.co.z)
    zr = np.array([np.percentile(a, 50) if a else np.nan for a in zs_])
    if np.isnan(zr).all(): zr[:] = collar_z
    idx_ = np.arange(RB); ok_ = ~np.isnan(zr)
    zr = np.interp(idx_, idx_[ok_], zr[ok_], period=RB)
    from scipy import ndimage as _nd0
    zr = _nd0.gaussian_filter1d(zr, 4, mode='wrap')
    def _zr(c_):
        f_ = (math.atan2(c_.y - _cy, c_.x - _cx) + math.pi) / math.tau * RB - .5; i_ = int(math.floor(f_)); t_ = f_ - i_
        return zr[i_ % RB] * (1 - t_) + zr[(i_ + 1) % RB] * t_
    above = [f for f in bm.faces if near(f.calc_center_median()) and f.calc_center_median().z > _zr(f.calc_center_median()) + .003]
    bmesh.ops.delete(bm, geom=above, context='FACES')
    # what the cut leaves standing alone (strips one or two faces wide) would read as spikes: peel them
    for _ in range(6):
        thin = [f for f in bm.faces if near(f.calc_center_median()) and sum(e.is_boundary for e in f.edges) >= 2]
        if not thin: break
        bmesh.ops.delete(bm, geom=thin, context='FACES')
    loose = [v for v in bm.verts if not v.link_faces]; bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bm.verts.ensure_lookup_table(); seen_ = set(); crumbs = []
    for v in bm.verts:
        if v.index in seen_: continue
        st_ = [v]; comp_ = []
        while st_:
            u = st_.pop()
            if u.index in seen_: continue
            seen_.add(u.index); comp_.append(u); st_ += [e.other_vert(u) for e in u.link_edges]
        if len(comp_) < 300 and all(near(u.co) for u in comp_): crumbs += comp_
    bmesh.ops.delete(bm, geom=crumbs, context='VERTS')
    snapped = 0
    for v in bm.verts:
        if v.is_boundary and near(v.co) and math.hypot(v.co.x - _cx, v.co.y - _cy) < _rim * 1.3 and abs(v.co.z - _zr(v.co)) < .02: v.co.z = _zr(v.co); snapped += 1
    bm.to_mesh(A.data); bm.free()
    print('collar ring: faces above removed', len(above), 'rim verts snapped', snapped, 'rim z range (cm)', round((zr.max() - zr.min()) * 100, 2))
print('head offset', dz, 'neck y', ya, yb * S_HEAD)
# ---- marry the head's neck to the body's collar: the two were generated separately, so at the collar the neck is a
# different width and sits a little off. Pull the neck's ring at the cut onto the collar ring (just inside it) and
# fade the correction out 6 cm up the neck, so the join is a smooth neck instead of a step
zc = collar_z; cx_ = _cx; cy_ = _cy
NB = 48
def polar_profile(cos_, zlo, zhi):
    acc = [[] for _ in range(NB)]
    for c in cos_:
        if zlo <= c.z <= zhi:
            th = math.atan2(c.y - cy_, c.x - cx_); acc[int((th + math.pi) / math.tau * NB) % NB].append(math.hypot(c.x - cx_, c.y - cy_))
    prof = [sum(a) / len(a) if a else None for a in acc]
    for i in range(NB):                     # fill empty bins from neighbours
        if prof[i] is None:
            j = 1
            while prof[(i + j) % NB] is None and prof[(i - j) % NB] is None: j += 1
            vals = [p for p in (prof[(i + j) % NB], prof[(i - j) % NB]) if p is not None]; prof[i] = sum(vals) / len(vals)
    return prof
# the body's ring is measured at the very top of its cut (the collar's rim; lower down the sweater flares out), and
# the neck is fitted 8 % inside it, so it disappears into the collar instead of standing on it
ring = [v.co.copy() for v in A.data.vertices if collar_z - .006 <= v.co.z <= collar_z + .001 and math.hypot(v.co.x - _cx, v.co.y - _cy) < _rim * 1.25]
r_body = polar_profile(ring, zc - .006, zc + .001)
def prof_at(prof, th):
    f = (th + math.pi) / math.tau * NB; i = int(f) % NB; t = f - int(f)
    return prof[i] * (1 - t) + prof[(i + 1) % NB] * t
# the head's neck is read just inside the collar, where nothing but neck is; at the rim itself a low-set chin can
# already reach down (Kiryu: chin and rim at nearly the same height), and pulling the chin onto the collar ring left a
# vertical crease down the chin. Anything well outside that neck (the chin) is left alone below
r_neck = polar_profile([v.co for v in B.data.vertices], zc - .020, zc - .008)
def _rn(c_):
    return prof_at(r_neck, math.atan2(c_.y - cy_, c_.x - cx_))
r_head = polar_profile([v.co for v in B.data.vertices if math.hypot(v.co.x - cx_, v.co.y - cy_) < 1.3 * _rn(v.co)], zc - .006, zc + .006)
moved = 0
# the correction stops 1.5 cm below the chin: above that the radial push reached the jaw and pulled the chin forward
# into a point (the generated heads have round chins)
ztop = max(min(zc + .045, zA_chin - .03), zc + .02); span = max(ztop - zc - .005, .01)   # ends well under the jaw: pushed up to it, the neck flared into a shelf along the jawline (Kiryu)
ztop = -1.0; span = .01   # interviewer: no fitting (the generated neck is short; pushed onto the collar it became a plate)
print('neck marry top above collar (cm)', round((ztop - zc) * 100, 1))
for v in B.data.vertices:
    z = v.co.z
    if z > ztop: continue
    u_ = (z - zc - .005) / span
    w = 1.0 if z <= zc + .005 else 1 - u_ * u_ * (3 - 2 * u_)
    th = math.atan2(v.co.y - cy_, v.co.x - cx_); r = math.hypot(v.co.x - cx_, v.co.y - cy_)
    if r < 1e-6: continue
    rk = prof_at(r_neck, th); w *= min(1.0, max(0.0, (1.35 * rk - r) / (.25 * rk)))   # neck only, never the chin
    rn = r + (.98 * prof_at(r_body, th) - prof_at(r_head, th)) * w   # filling the opening
    v.co.x = cx_ + math.cos(th) * rn; v.co.y = cy_ + math.sin(th) * rn; moved += 1
print('neck married to collar: verts', moved, 'collar r', round(sum(r_body) / NB, 4), 'neck r', round(sum(r_head) / NB, 4))

# ---- lighter meshes for the engine
decimate(A, .06); decimate(B, .1)
print('tris', sum(len(p.vertices) - 2 for p in A.data.polygons), sum(len(p.vertices) - 2 for p in B.data.polygons))

# no drawn face for the interviewer (her face is never seen in 3D): the generated head as it is
B.name = 'kikite_head'
for o in (A, B):
    for p in o.data.polygons: p.use_smooth = True
bpy.ops.wm.save_as_mainfile(filepath=f'{T}/kikite_prep.blend')
print('SAVED')

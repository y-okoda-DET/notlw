# socks version of Natsuki (indoors, dusk): the same head, the body generated from the socks images (generated from prep_natsuki.py)
"""Tripo (H3.1 multi-view, Pro) Natsuki: body mesh + separately generated head, joined into one figure.
Head scaled so the eyes sit 62 mm apart and the chin meets the body's chin line; the body loses everything
above its collar, the head keeps its neck down into the collar. The front of the face is split off as its own
object with UVs that project the drawn portrait (eyes matched, jaw outline matched row by row), so the game can
swap open / closed / talking faces exactly as before.  Output: natsuki_s_prep.blend"""
import bpy, bmesh, sys, math
import numpy as np
import os; sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'blender')); import paths as P   # all paths: paths.env
from mathutils import Vector
import json

T = P.TRIPO
A_HEIGHT = .9799        # raw body height (Tripo units)
H_BODY = 1.58 / A_HEIGHT # scale applied to the body
S_HEAD = .29             # head scale: eyes 70 mm apart, between real (62) and the body's own stylised head (75)
# measured on orthographic renders of the raw Tripo meshes (Tripo units)
A_CHIN = .845            # body: chin line
B_CHIN = .228            # head: chin
B_EYE_Z = .543; B_EYE_X = 0.0; B_EYED = .242
B_CUT = .0               # head mesh: keep above this (neck runs down into the collar)
NECK_K = 1.0
A_CUT = .828             # body mesh: keep below this (just above the crew neck)

def imp(f):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f)
    o = [o for o in bpy.data.objects if o not in before and o.type == 'MESH'][0]
    o.select_set(True); bpy.context.view_layer.objects.active = o
    o.parent = None
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
A = imp(f'{T}/n3_body.glb'); A.rotation_euler.z += math.pi; apply_tf(A); A.name = 'natsuki_s_body'   # generated facing +Y
B = imp(f'{T}/n2_head.glb'); apply_tf(B); B.name = 'natsuki_s_hair'
clean_mat(A); clean_mat(B)
# glTF stores one UV per vertex, so the importer leaves the head split along every UV island: weld those duplicates
# (the UVs stay per corner), otherwise any smoothing of the face tears cracks between islands
bm = bmesh.new(); bm.from_mesh(B.data); n0 = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5); bm.to_mesh(B.data); print('head welded', n0, '->', len(bm.verts)); bm.free()
A.data.materials[0].name = 'natsuki_s_tripo_body'; B.data.materials[0].name = 'natsuki_s_tripo_head'

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
CUT_UP = .003   # Natsuki's crew neck sits at collar_z; above it the generated body has skin-coloured stand-up flaps (others: .012)
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
_ck = np.array([.91, .776, .678]); _ck = np.where(_ck <= .04045, _ck / 12.92, ((_ck + .055) / 1.055) ** 2.4)
_skin_ref = _ck / _ck.sum()
# (the body's own neck colour was tried as the reference: on Natsuki's socks body it matches the cream sweater too)
print('neck skin ratio', np.round(_skin_ref, 3))
_gone = [i for i, r in _cs if np.abs(np.array(r) - _skin_ref).sum() < .06]
# and by shape: anything left inside the collar's opening (the body's own neck stub and its flaps) goes; the head's
# neck fills the opening
NECK_GEOM = True   # Natsuki only: on Makoto it cut into the collar ribbing
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
cut(B, lambda c: c.z > collar_z - .022)   # the head's neck stops 22 mm inside the collar
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

# ---- the drawn face: front polygons inside the face oval, not hair-coloured (eye boxes always in)
eye_z = dz + B_EYE_Z * S_HEAD; eyed = B_EYED * S_HEAD
def d_of(z): return (eye_z - z) / eyed                    # distance below the eye line, in eye spacings
samp = albedo_sampler(B)
me = B.data; uvl = me.uv_layers[0]
# the face's own depth: the frontmost surface at the eye line; anything much further back inside the oval's
# x / z range (the inner side of the hair shell, the surface in front of the ears) is not the face
y_front = min(p.center.y for p in me.polygons if p.normal.y < -.5 and abs(d_of(p.center.z)) < .3 and abs(p.center.x) < .5 * eyed)
face = []
for p in me.polygons:
    c = p.center; d = d_of(c.z); xe = c.x / eyed
    if p.normal.y > -.2 or d < -.16 or d > 1.45 or abs(xe) > 1.0 or c.y > y_front + 1.1 * eyed: continue
    uv = sum((uvl.data[li].uv for li in p.loop_indices), Vector((0, 0))) / len(p.loop_indices)
    col = samp(uv); L = col.mean()
    in_eye = abs(abs(xe) - .5) < .27 and -.14 < d < .13
    if L < .16 and not in_eye: continue
    face.append(p.index)
print('face polys', len(face))
bc = []
for p in me.polygons:
    c = p.center; d = d_of(c.z); xe = c.x / eyed
    if p.normal.y < -.5 and .35 < d < .6 and .35 < abs(xe) < .7:
        uv = sum((uvl.data[li].uv for li in p.loop_indices), Vector((0, 0))) / len(p.loop_indices); bc.append(samp(uv))
bc = np.median(np.array(bc), 0)

# portrait geometry
M = json.load(open(f'{P.KF}/masks_style.json'))['natsuki']
(plx, ply), (prx, pry) = M['eyes']; pe = prx - plx; pex = (plx + prx) / 2; pey = (ply + pry) / 2
# half-width of the face (in eye spacings) along the vertical, for the Tripo head (hb) and the portrait (hp)
hb_pts = [(-.3, .87), (.17, .87), (.52, .88), (.68, .78), (.84, .68), (1.0, .55), (1.1, .4), (1.21, .12), (1.5, .1)]
hp_pts = [(-.3, .86), (.17, .85), (.51, .86), (.62, .76), (.79, .69), (1.0, .55), (1.21, .12), (1.5, .1)]
def interp(pts, x):
    if x <= pts[0][0]: return pts[0][1]
    for (a, va), (b, vb) in zip(pts, pts[1:]):
        if x <= b: return va + (vb - va) * (x - a) / (b - a)
    return pts[-1][1]
K = 1.0           # the portrait's chin is closer to its eyes than the Tripo head's
def portrait_uv(co):
    db = d_of(co.z); xe = (co.x) / eyed
    dp = min(db, 1.42) * K if db > 0 else db   # below the drawn chin the skin colour of the chin continues
    up = xe / max(.15, interp(hb_pts, db)) * interp(hp_pts, dp)
    px_ = pex + up * pe; py_ = pey + dp * pe
    return (px_ / 1254.0, 1 - py_ / 1254.0)

# keep only polygons that land on the portrait's skin (or eyes / brows / mouth): where the portrait shows hair
# strands or background, the generated head's own surface stays
from PIL import Image as _I0
_P = np.asarray(_I0.open(f'{P.ASSETS}/faces_style/natsuki_open.png').convert('RGB'), np.float32) / 255
_pc = np.median(np.concatenate([_P[int(pey + .45 * pe) - 12:int(pey + .45 * pe) + 12, int(x) - 12:int(x) + 12].reshape(-1, 3) for x in (plx, prx)]), 0)
def _skinlike(uv):
    x = int(uv[0] * 1254); y = int((1 - uv[1]) * 1254)
    if not (0 <= x < 1254 and 0 <= y < 1254): return False
    q = _P[max(0, y - 3):y + 4, max(0, x - 3):x + 4].reshape(-1, 3).mean(0)
    r = q / max(q.sum(), 1e-4); rr = _pc / _pc.sum()
    return np.abs(r - rr).sum() < .09 and q.sum() > _pc.sum() * .5 and q.sum() < _pc.sum() * 1.2
keep = []; drop = []
for pi in face:
    p_ = me.polygons[pi]; c = p_.center; d = d_of(c.z); xe = c.x / eyed
    feat = (abs(abs(xe) - .5) < .3 and -.35 < d < .16) or (abs(xe) < .4 and .7 < d < 1.05)   # brows, eyes, mouth
    uv_ = sum((uvl.data[li].uv for li in p_.loop_indices), Vector((0, 0))) / len(p_.loop_indices)
    tc = samp(uv_); tripo_skin = np.abs(tc / max(tc.sum(), 1e-4) - bc / max(bc.sum(), 1e-4)).sum() < .10 and tc.sum() > bc.sum() * .45
    # the Tripo head's own skin always takes the portrait (its painted eyes, brows and lips would show through
    # otherwise); its hair keeps the Tripo texture unless the portrait has skin there
    # below the brow line everything inside the oval takes the portrait, hair strands included (the Tripo head's
    # sidelocks are thin shells that otherwise poke through the face as dark streaks); above it the 3D bangs stay
    nostril = abs(xe) < .32 and .3 < d < .72
    if (feat and abs(xe) < .9) or nostril or tripo_skin or _skinlike(portrait_uv(c)): keep.append(pi)
    elif d > -.2: drop.append(pi)   # hair shells in front of the lower face: removed, the drawing carries the strands
print('face polys on portrait skin', len(keep), 'of', len(face), 'dropped', len(drop))
face = keep
da = me.attributes.new('drop', 'INT', 'FACE')
for pi in drop: da.data[pi].value = 1
# no separate face object any more: the portrait is baked into the generated head's own texture below, so there
# is no seam between a face patch and the head whatever the angle. Hair shells in front of the face are removed.
bm = bmesh.new(); bm.from_mesh(B.data); dl = bm.faces.layers.int['drop']
gone = [f for f in bm.faces if f[dl]]
# deleting them tears holes in the head shell (seen as black from below and the side); instead they are kept and
# painted with the face: a thin shell in front of the skin, skin coloured, reads as skin
print('sidelock polys (kept, painted as skin)', len(gone)); bm.free()
me = B.data; uvl = me.uv_layers[0]
# the face polygons after the deletion (indices shifted): re-derive by the same test on the remaining mesh
# (sampler reused from above)
face = []
for p in me.polygons:
    c = p.center; d = d_of(c.z); xe = c.x / eyed
    under = p.normal.z < -.3 and d > 1.2   # the underside of the chin / jaw
    if (p.normal.y > -.2 and not under) or d < -.16 or d > 1.95 or abs(xe) > 1.0 or c.y > y_front + 1.1 * eyed: continue
    uv = sum((uvl.data[li].uv for li in p.loop_indices), Vector((0, 0))) / len(p.loop_indices)
    col = samp(uv); L = col.mean()
    in_eye = abs(abs(xe) - .5) < .3 and -.18 < d < .16
    if L < .22 and not in_eye: continue
    feat = (abs(abs(xe) - .5) < .3 and -.35 < d < .16) or (abs(xe) < .4 and .7 < d < 1.05)
    tc = samp(uv); tripo_skin = np.abs(tc / max(tc.sum(), 1e-4) - bc / max(bc.sum(), 1e-4)).sum() < .10 and tc.sum() > bc.sum() * .45
    nostril = abs(xe) < .32 and .3 < d < .72
    if (feat and abs(xe) < .9) or nostril or tripo_skin or (d <= 1.45 and _skinlike(portrait_uv(c))): face.append(p.index)
print('face polys for the bake', len(face))   # the sidelock shells keep their hair colour (not added to the face)
# soften the sculpted relief of eyes and lips on the head itself. Neighbours are taken only among face vertices
# (as if the face were cut out), so inner geometry or hair shells connected to the eye region cannot pull it
me = B.data
fset = set(face)
fverts = set(vi for fi in face for vi in me.polygons[fi].vertices)
rim = set(vi for p in me.polygons if p.index not in fset for vi in p.vertices) & fverts
co = np.array([v.co[:] for v in me.vertices], np.float64)
nbr = {}
for e in me.edges:
    a_, b_ = e.vertices
    if a_ in fverts and b_ in fverts: nbr.setdefault(a_, []).append(b_); nbr.setdefault(b_, []).append(a_)
# the strength fades out over the last part of each box: a hard box edge left a step in the surface (the vertical
# crease from the mouth corner down the chin, seen on Kiryu from below)
def _relief_w(x, z):
    xe_, d_ = abs(x / eyed), d_of(z)
    ramp = lambda a, w_: min(1.0, max(0.0, a / w_))
    we = ramp(.3 - abs(xe_ - .5), .12) * ramp(min(d_ + .18, .16 - d_), .08)
    wm = ramp(.45 - xe_, .2) * ramp(min(d_ - .75, 1.1 - d_), .12)
    s_ = max(we, wm); return s_ * s_ * (3 - 2 * s_)
mov = {}
for vi in fverts:
    if vi in rim or vi not in nbr: continue
    s_ = _relief_w(co[vi, 0], co[vi, 2])
    if s_ > 0: mov[vi] = s_
for _ in range(24):
    ny = {vi: co[[*nbr[vi]], 1].mean() for vi in mov}
    for vi, y in ny.items(): co[vi, 1] = co[vi, 1] * (1 - .5 * mov[vi]) + y * .5 * mov[vi]
for vi in mov: me.vertices[vi].co.y = co[vi, 1]
me.update()
# per-vertex blend weight: 1 inside the face, feathered over a few rings toward its edge (never painted outside it)
me = B.data
w = np.zeros(len(me.vertices), np.float32)
for fi in face:
    for vi in me.polygons[fi].vertices: w[vi] = 1
edges = np.array([e.vertices[:] for e in me.edges])
for _ in range(6):
    acc = w.copy(); cnt = np.ones_like(w)
    np.add.at(acc, edges[:, 0], w[edges[:, 1]]); np.add.at(cnt, edges[:, 0], 1)
    np.add.at(acc, edges[:, 1], w[edges[:, 0]]); np.add.at(cnt, edges[:, 1], 1)
    w = np.minimum(w, acc / cnt)       # only ever lowers: the feather eats into the face edge, not out of it
w = np.clip((w - .15) / .85, 0, 1) ** 1.5
F = B   # the whole generated head carries the face now
# the portrait is paler than the Tripo skin: tinted copies of open/closed/talk, matched on the cheeks
from PIL import Image as _I
pim = np.asarray(_I.open(f'{P.ASSETS}/faces_style/natsuki_open.png').convert('RGB'), np.float32) / 255
pc = np.median(np.concatenate([pim[int(pey + .45 * pe) - 12:int(pey + .45 * pe) + 12, int(x) - 12:int(x) + 12].reshape(-1, 3) for x in (plx, prx)]), 0)
# tripo albedo is linear in Blender's buffer; portrait is sRGB
bc_s = np.array([.91, .776, .678])   # Tripo head cheeks, read off an unlit orthographic render (sRGB)
tint = np.clip(bc_s / pc, .5, 1.2); print('face tint', tint, 'portrait', pc, 'tripo', bc_s)
# the face patch now covers the whole lower face, so where the drawing lays hair strands over the cheeks and jaw
# those strokes would print on the skin: fill them with the nearest skin colour (eyes, brows and mouth are left
# alone, as are small marks such as a mole)
from scipy import ndimage as _nd
def inpaint_hair(q):
    h, w = q.shape[:2]; yy, xx = np.mgrid[0:h, 0:w]
    xe_ = (xx - pex) / pe; dp_ = (yy - pey) / pe
    hw = np.interp(dp_, [p[0] for p in hp_pts], [p[1] for p in hp_pts])
    # the generated head is wider than the drawn one at the jaw, so the patch samples past the drawn silhouette:
    # everything there that is not skin (hair, background) is filled too
    zone = (np.abs(xe_) < hw * 1.4) & (dp_ > -.2) & (dp_ < 2.1)   # down to the bottom of the painted patch (d 1.95)   # the patch samples down to d = 1.45 eye spacings, times K
    feat_ = ((np.abs(np.abs(xe_) - .5) < .34) & (dp_ > -.45) & (dp_ < .22)) | ((np.abs(xe_) < .5) & (dp_ > .6) & (dp_ < 1.12)) | ((np.abs(xe_) < .3) & (dp_ > .3) & (dp_ < .62))
    rr = q / np.maximum(q.sum(2, keepdims=True), 1e-4); rc = pc / pc.sum()
    lum = q.sum(2); base = _nd.median_filter(lum, size=25)
    hair = (lum < pc.sum() * .55) | (lum > pc.sum() * 1.18) | (np.abs(rr - rc).sum(2) > .1) | (lum < base * .88)   # last: thin faint strokes
    m = zone & ~feat_ & hair
    lab, n = _nd.label(m); sizes = _nd.sum(m, lab, range(1, n + 1)); objs = _nd.find_objects(lab)
    # big patches (hair, background) and thin long strokes (the jaw outline, a strand) go; a small round mark (a mole) stays
    keep_ = []
    for i, (sz, sl) in enumerate(zip(sizes, objs)):
        if sl is None: continue
        hh, ww = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
        if sz > 300 or (sz > 40 and (max(hh, ww) > 3.0 * min(hh, ww) or sz < .4 * hh * ww)): keep_.append(i + 1)   # a diagonal stroke fills little of its box
    m = np.isin(lab, keep_)
    if not m.any(): return q
    m = _nd.binary_dilation(m, iterations=2)
    skin = zone & ~m & (q.sum(2) > pc.sum() * .7) & (np.abs(rr - rc).sum(2) < .12)
    idx = _nd.distance_transform_edt(~skin, return_distances=False, return_indices=True)
    f = q[idx[0], idx[1]]
    f = np.dstack([_nd.gaussian_filter(f[..., i], 5) for i in range(3)])
    out = q.copy(); out[m] = f[m]; print('inpainted hair px', int(m.sum())); return out
# below the lower lip the drawing shades the jaw's underside and draws its outline; painted onto the 3D jaw that
# shading reads as a ledge along the jawline. Lift it to the cheek's brightness (keeping the hue), fading in from
# the lower lip down to the chin
def lift_jaw(q):
    h, w = q.shape[:2]; yy, xx = np.mgrid[0:h, 0:w]
    xe_ = (xx - pex) / pe; dp_ = (yy - pey) / pe
    hw = np.interp(dp_, [p[0] for p in hp_pts], [p[1] for p in hp_pts])
    lum = q.sum(2); ref = pc.sum()
    k = np.clip((dp_ - 1.15) / .2, 0, 1) * ((np.abs(xe_) < hw * 1.4) & (dp_ < 2.2))
    rr = q / np.maximum(lum[..., None], 1e-4); rc = pc / pc.sum()
    skinish = np.abs(rr - rc).sum(2) < .16
    gain = np.clip(ref / np.maximum(lum, 1e-4), 1.0, 1.6)
    gain = _nd.gaussian_filter(gain, 3)
    # a smooth skin fill from the lifted skin pixels only (normalised blur): the outline stroke itself is not skin
    # coloured, so it is replaced rather than lifted
    lifted = np.clip(q * gain[..., None], 0, 1); wsk = skinish.astype(np.float32)
    num = np.dstack([_nd.gaussian_filter(lifted[..., i] * wsk, 6) for i in range(3)]); den = _nd.gaussian_filter(wsk, 6)[..., None]
    fill = np.where(den > 1e-3, num / np.maximum(den, 1e-3), lifted)
    a = k[..., None]
    out = q * (1 - a) + fill * a
    print('jaw shade lifted px', int((a[..., 0] > .5).sum())); return out
for st, src in (('open', 'natsuki_open'), ('closed', 'natsuki_closed'), ('talk', 'natsuki_talk_open')):
    q = lift_jaw(inpaint_hair(np.asarray(_I.open(f'{P.ASSETS}/faces_style/{src}.png').convert('RGB'), np.float32) / 255))
    _I.fromarray((np.clip(q * tint, 0, 1) * 255).astype(np.uint8)).save(f'{T}/natsuki_s_{st}.png')
# ---- the generated head's UV atlas is thousands of tiny charts: after decimation each triangle spans a few texels
# and anything painted into it smears. The whole front of the head (the face oval, painted or not) gets one flat
# island in a texture of its own (a front projection, ~25 texels per mm), baked from the generated texture so the
# colours match the rest of the head exactly; hair and the back keep the generated texture and atlas. Two materials
# on one mesh: no seam in the geometry, and the material change is invisible because the colours are baked across.
BK = 2048   # the game ships the head texture at 2048; baking at 4096 ran out of memory on the larger heads
me = B.data; ouv = me.uv_layers[0]; ouv_name = ouv.name; uvl = ouv
oval = set()
for p in me.polygons:
    under = p.normal.z < -.3 and d_of(p.center.z) > 1.2
    if not ((p.normal.y < -.2 or under) and -.16 <= d_of(p.center.z) <= 1.95 and abs(p.center.x / eyed) <= 1.0 and p.center.y <= y_front + 1.1 * eyed): continue
    uv = sum((uvl.data[li].uv for li in p.loop_indices), Vector((0, 0))) / len(p.loop_indices)
    if samp(uv).mean() < .22 and not (abs(abs(p.center.x / eyed) - .5) < .3 and -.18 < d_of(p.center.z) < .16): continue   # hair
    oval.add(p.index)
oval |= fset
del samp   # the 4K albedo buffer is not needed any more
# a projection from a point inside the head (azimuth, elevation): every front-of-head polygon, steep sides and the
# underside of the chin included, gets its own place; a flat front projection would stack those on top of each other
fv = np.array([me.vertices[vi].co[:] for fi in oval for vi in me.polygons[fi].vertices])
Cc = Vector((0.0, y_front + 1.05 * eyed, (fv[:, 2].min() + fv[:, 2].max()) / 2))
def sph(co):
    d = (Vector(co) - Cc).normalized()
    return (math.atan2(d.x, -d.y), math.asin(max(-1.0, min(1.0, d.z))))
ang = np.array([sph(me.vertices[vi].co) for fi in oval for vi in me.polygons[fi].vertices])
a0, a1 = ang[:, 0].min(), ang[:, 0].max(); e0, e1 = ang[:, 1].min(), ang[:, 1].max(); span = max(a1 - a0, e1 - e0) * 1.04
bu = me.uv_layers.new(name='bake')
for p in me.polygons:
    for li in p.loop_indices:
        if p.index in oval:
            u_, v_ = sph(me.vertices[me.loops[li].vertex_index].co)
            bu.data[li].uv = ((u_ - a0) / span * .96 + .02, (v_ - e0) / span * .96 + .02)
        else:
            bu.data[li].uv = (.5, .5)
me.uv_layers.active = bu   # the bake writes through the active UV map; the material's textures are pinned to the original below
hm = B.data.materials[0]; hp = [n for n in hm.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'][0]
# during the bake the generated material must keep reading its own atlas: pin its textures to the original UV map
uvn = hm.node_tree.nodes.new('ShaderNodeUVMap'); uvn.uv_map = ouv_name
for n in hm.node_tree.nodes:
    if n.type == 'TEX_IMAGE' and not n.inputs['Vector'].links: hm.node_tree.links.new(uvn.outputs[0], n.inputs['Vector'])
bpy.ops.object.select_all(action='DESELECT'); B.select_set(True); bpy.context.view_layer.objects.active = B
scn = bpy.context.scene; scn.render.engine = 'CYCLES'; scn.cycles.samples = 4; scn.cycles.device = 'CPU'
scn.render.bake.use_pass_direct = False; scn.render.bake.use_pass_indirect = False; scn.render.bake.use_pass_color = True
scn.render.bake.margin = 16
def bake_to(name, btype, **kw):
    img = bpy.data.images.new(name, BK, BK, alpha=False)
    if btype == 'NORMAL': img.colorspace_settings.name = 'Non-Color'
    tn = hm.node_tree.nodes.new('ShaderNodeTexImage'); tn.image = img; hm.node_tree.nodes.active = tn
    bpy.ops.object.bake(type=btype, **kw)
    img.filepath_raw = f'{T}/natsuki_s_head_{name}.png'; img.file_format = 'PNG'; img.save()
    hm.node_tree.nodes.remove(tn); return img
cimg = bake_to('bakecol', 'DIFFUSE')
has_nm = bool(hp.inputs['Normal'].links)
if has_nm: nimg = bake_to('bakenrm', 'NORMAL', normal_space='TANGENT')
# unpin, then fold the face island into the one UV layer and drop the helper layer
for l in list(uvn.outputs[0].links): hm.node_tree.links.remove(l)
hm.node_tree.nodes.remove(uvn)
me = B.data; ouv = me.uv_layers[ouv_name]; bu = me.uv_layers['bake']
for p in me.polygons:
    if p.index in oval:
        for li in p.loop_indices: ouv.data[li].uv = bu.data[li].uv
me.uv_layers.remove(me.uv_layers['bake']); me.uv_layers.active = me.uv_layers[ouv_name]; me.uv_layers[ouv_name].active_render = True
# ---- bake the three portrait states into copies of the new head texture
import cv2
from PIL import Image as _I
hs = np.asarray(_I.open(f'{T}/natsuki_s_head_bakecol.png').convert('RGB'), np.float32) / 255; HH, HW = hs.shape[:2]
# per texel of the face island: the direction from the projection centre -> the point on the head it hits -> that
# point's place in the portrait. One ray per texel (at half resolution, then upsampled): no triangle rasterising,
# so tiny or sliver triangles cannot drop out.
from mathutils.bvhtree import BVHTree
me = B.data; uvl = me.uv_layers[0]
bvh = BVHTree.FromPolygons([v.co[:] for v in me.vertices], [p.vertices[:] for p in me.polygons])
RS = BK // 2
mapx = np.full((RS, RS), -1, np.float32); mapy = np.full((RS, RS), -1, np.float32); wmask = np.zeros((RS, RS), np.float32)
for j in range(RS):
    v_ = (1 - (j + .5) / RS)                      # texture rows run top-down; uv v runs bottom-up
    el = (v_ - .02) / .96 * span + e0
    if not (e0 - .02 <= el <= e1 + .02): continue
    ce, se = math.cos(el), math.sin(el)
    for i in range(RS):
        u_ = (i + .5) / RS
        az = (u_ - .02) / .96 * span + a0
        if not (a0 - .02 <= az <= a1 + .02): continue
        d = Vector((math.sin(az) * ce, -math.cos(az) * ce, se))
        hit = bvh.ray_cast(Cc, d, 1.0)
        if hit[0] is None or hit[2] not in oval: continue
        pu = portrait_uv(hit[0])
        mapx[j, i] = pu[0] * 1254.0; mapy[j, i] = (1 - pu[1]) * 1254.0
        if hit[2] in fset: wmask[j, i] = 1.0
print('face texels', int((mapx >= 0).sum()), 'painted', int(wmask.sum()))
# feather: fade the portrait out toward the edge of the painted region, never beyond it
from scipy import ndimage as _nd2
wsoft = _nd2.gaussian_filter(wmask, 28) * wmask   # ~1 mm feather at the rim, where the drawing meets the generated skin
wsoft = np.clip((wsoft - .2) / .8, 0, 1)
# under the jaw the drawing hands over to the generated skin gradually (from below the lips to under the chin), so no
# edge of the painted patch lies along the jawline (the line seen under Kiryu's jaw from below)
_dmap = np.where(mapy >= 0, (mapy - pey) / pe, 0)
wsoft *= np.clip((1.85 - _dmap) / .5, 0, 1)
up = lambda m: cv2.resize(m, (BK, BK), interpolation=cv2.INTER_LINEAR)
MX, MY, WW = up(mapx), up(mapy), up(wsoft)
WW[(MX < 0) | (MY < 0)] = 0
def bake_portrait(port_srgb):
    warped = cv2.remap(port_srgb, MX, MY, interpolation=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
    return hs * (1 - WW[..., None]) + warped * WW[..., None]
for st, src in (('open', 'natsuki_open'), ('closed', 'natsuki_closed'), ('talk', 'natsuki_talk_open')):
    pq = np.asarray(_I.open(f'{T}/natsuki_s_{st}.png').convert('RGB'), np.float32) / 255   # the tinted, inpainted portrait
    baked = bake_portrait(pq)
    _I.fromarray((np.clip(baked, 0, 1) * 255).astype(np.uint8)).save(f'{T}/natsuki_s_headtex_{st}.png')
    print('baked', st)
fm = bpy.data.materials.new('natsuki_s_face'); fm.use_nodes = True
pb = fm.node_tree.nodes['Principled BSDF']
pb.inputs['Roughness'].default_value = max(.6, hp.inputs['Roughness'].default_value if not hp.inputs['Roughness'].links else .6)   # no shinier than skin
t = fm.node_tree.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(f'{T}/natsuki_s_headtex_open.png')
fm.node_tree.links.new(t.outputs[0], pb.inputs['Base Color'])
if has_nm:
    nt2 = fm.node_tree.nodes.new('ShaderNodeTexImage'); nt2.image = bpy.data.images.load(f'{T}/natsuki_s_head_bakenrm.png'); nt2.image.colorspace_settings.name = 'Non-Color'
    nmn = fm.node_tree.nodes.new('ShaderNodeNormalMap'); nmn.inputs['Strength'].default_value = .2   # the generated normals carry a ledge along the jaw (Kiryu); the face is drawn, it needs little relief
    fm.node_tree.links.new(nt2.outputs[0], nmn.inputs['Color']); fm.node_tree.links.new(nmn.outputs[0], pb.inputs['Normal'])
B.data.materials.append(fm)
for p in B.data.polygons: p.material_index = 1 if p.index in oval else 0
B.name = 'natsuki_s_head'
for o in (A, B):
    for p in o.data.polygons: p.use_smooth = True
bpy.ops.file.make_paths_relative()   # images by paths relative to the .blend, so the file works wherever the repo is
bpy.ops.wm.save_as_mainfile(filepath=f'{T}/natsuki_s_prep.blend')
print('SAVED')

"""Tripo (H3.1 multi-view, Pro) Natsuki: body mesh + separately generated head, joined into one figure.
Head scaled so the eyes sit 62 mm apart and the chin meets the body's chin line; the body loses everything
above its collar, the head keeps its neck down into the collar. The front of the face is split off as its own
object with UVs that project the drawn portrait (eyes matched, jaw outline matched row by row), so the game can
swap open / closed / talking faces exactly as before.  Output: makoto_prep.blend"""
import bpy, bmesh, sys, math
import numpy as np
sys.path.insert(0, '/home/claude/kf')
from mathutils import Vector
import json

T = '/home/claude/tripo'
A_HEIGHT = 0.9799
H_BODY = 1.55 / A_HEIGHT
S_HEAD = 0.38
A_CHIN = 0.857
B_CHIN = 0.442
B_EYE_Z = 0.649; B_EYE_X = -0.009; B_EYED = 0.183
B_CUT = 0.2
NECK_K = 0.88
A_CUT = 0.812

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
A = imp(f'{T}/makoto_body.glb'); apply_tf(A); A.name = 'makoto_body'   # generated facing +Y
B = imp(f'{T}/makoto_head.glb'); apply_tf(B); B.name = 'makoto_hair'
clean_mat(A); clean_mat(B)
A.data.materials[0].name = 'makoto_tripo_body'; B.data.materials[0].name = 'makoto_tripo_head'

# ---- place
A.data.transform(__import__('mathutils').Matrix.Diagonal((H_BODY, H_BODY, H_BODY, 1)))
cut(B, lambda c: c.z > B_CUT)
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
cut(A, lambda c: c.z < A_CUT * H_BODY)
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
print('head offset', dz, 'neck y', ya, yb * S_HEAD)

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
M = json.load(open('/home/claude/kf/masks_style.json'))['makoto']
(plx, ply), (prx, pry) = M['eyes']; pe = prx - plx; pex = (plx + prx) / 2; pey = (ply + pry) / 2
# half-width of the face (in eye spacings) along the vertical, for the Tripo head (hb) and the portrait (hp)
hb_pts = [(-0.3, 0.78), (0, 0.86), (0.2, 1.05), (0.4, 1.15), (0.55, 1.2), (0.7, 1.1), (0.85, 0.89), (1.0, 0.81), (1.13, 0.72), (1.3, 0.64), (1.6, 0.62)]
hp_pts = [(-0.3, 0.9), (0, 0.9), (0.14, 0.93), (0.25, 1.18), (0.4, 1.08), (0.51, 0.99), (0.6, 0.85), (0.75, 0.8), (0.9, 0.7), (1.0, 0.62), (1.1, 0.57), (1.6, 0.57)]
def interp(pts, x):
    if x <= pts[0][0]: return pts[0][1]
    for (a, va), (b, vb) in zip(pts, pts[1:]):
        if x <= b: return va + (vb - va) * (x - a) / (b - a)
    return pts[-1][1]
K = 0.88           # the portrait's chin is closer to its eyes than the Tripo head's
def portrait_uv(co):
    db = d_of(co.z); xe = (co.x) / eyed
    dp = db * K if db > 0 else db
    up = xe / max(.15, interp(hb_pts, db)) * interp(hp_pts, dp)
    px_ = pex + up * pe; py_ = pey + dp * pe
    return (px_ / 1254.0, 1 - py_ / 1254.0)

# keep only polygons that land on the portrait's skin (or eyes / brows / mouth): where the portrait shows hair
# strands or background, the generated head's own surface stays
from PIL import Image as _I0
_P = np.asarray(_I0.open('/home/claude/assets/faces_style/makoto_open.png').convert('RGB'), np.float32) / 255
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
# split the face polygons off into makoto_head
bpy.ops.object.select_all(action='DESELECT'); B.select_set(True); bpy.context.view_layer.objects.active = B
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='DESELECT'); bpy.ops.object.mode_set(mode='OBJECT')
fs = set(face)
for p in me.polygons: p.select = p.index in fs
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.separate(type='SELECTED'); bpy.ops.object.mode_set(mode='OBJECT')
F = [o for o in bpy.context.selected_objects if o is not B][0]; F.name = 'makoto_head'
bm = bmesh.new(); bm.from_mesh(B.data); dl = bm.faces.layers.int['drop']
gone = [f for f in bm.faces if f[dl]]
bmesh.ops.delete(bm, geom=gone, context='FACES'); bm.to_mesh(B.data); bm.free()
print('sidelock polys removed', len(gone))
# soften the sculpted relief of eyes and lips, so the drawn eyes and mouth are not fighting a second set
bm = bmesh.new(); bm.from_mesh(F.data)
for _ in range(24):
    vs = []
    for v in bm.verts:
        if v.is_boundary: continue
        d = d_of(v.co.z); xe = v.co.x / eyed
        if (abs(abs(xe) - .5) < .3 and -.18 < d < .16) or (abs(xe) < .45 and .75 < d < 1.1):
            vs.append(v)
    bmesh.ops.smooth_vert(bm, verts=vs, factor=.5, use_axis_x=False, use_axis_y=True, use_axis_z=False)
bm.to_mesh(F.data); bm.free()
fu = F.data.uv_layers[0]
for p in F.data.polygons:
    for li in p.loop_indices:
        fu.data[li].uv = portrait_uv(F.data.vertices[F.data.loops[li].vertex_index].co)
# the portrait is paler than the Tripo skin: tinted copies of open/closed/talk, matched on the cheeks
from PIL import Image as _I
pim = np.asarray(_I.open('/home/claude/assets/faces_style/makoto_open.png').convert('RGB'), np.float32) / 255
pc = np.median(np.concatenate([pim[int(pey + .45 * pe) - 12:int(pey + .45 * pe) + 12, int(x) - 12:int(x) + 12].reshape(-1, 3) for x in (plx, prx)]), 0)
# tripo albedo is linear in Blender's buffer; portrait is sRGB
bc_s = np.array([0.945, 0.804, 0.702])   # Tripo head cheeks, read off an unlit orthographic render (sRGB)
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
    zone = (np.abs(xe_) < hw * 1.4) & (dp_ > -.2) & (dp_ < 1.5)
    feat_ = ((np.abs(np.abs(xe_) - .5) < .34) & (dp_ > -.45) & (dp_ < .22)) | ((np.abs(xe_) < .5) & (dp_ > .6) & (dp_ < 1.12))
    rr = q / np.maximum(q.sum(2, keepdims=True), 1e-4); rc = pc / pc.sum()
    hair = (q.sum(2) < pc.sum() * .55) | (q.sum(2) > pc.sum() * 1.18) | (np.abs(rr - rc).sum(2) > .1)
    m = zone & ~feat_ & hair
    lab, n = _nd.label(m); sizes = _nd.sum(m, lab, range(1, n + 1))
    m = np.isin(lab, [i + 1 for i, sz in enumerate(sizes) if sz > 300])
    if not m.any(): return q
    m = _nd.binary_dilation(m, iterations=2)
    skin = zone & ~m & (q.sum(2) > pc.sum() * .7) & (np.abs(rr - rc).sum(2) < .12)
    idx = _nd.distance_transform_edt(~skin, return_distances=False, return_indices=True)
    f = q[idx[0], idx[1]]
    f = np.dstack([_nd.gaussian_filter(f[..., i], 5) for i in range(3)])
    out = q.copy(); out[m] = f[m]; print('inpainted hair px', int(m.sum())); return out
for st, src in (('open', 'makoto_open'), ('closed', 'makoto_closed'), ('talk', 'makoto_talk')):
    q = inpaint_hair(np.asarray(_I.open(f'/home/claude/assets/faces_style/{src}.png').convert('RGB'), np.float32) / 255)
    _I.fromarray((np.clip(q * tint, 0, 1) * 255).astype(np.uint8)).save(f'{T}/makoto_{st}.png')
fm = bpy.data.materials.new('makoto_face'); fm.use_nodes = True
pb = fm.node_tree.nodes['Principled BSDF']; pb.inputs['Roughness'].default_value = .7
t = fm.node_tree.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(f'{T}/makoto_open.png'); t.extension = 'EXTEND'
fm.node_tree.links.new(t.outputs[0], pb.inputs['Base Color'])
F.data.materials.clear(); F.data.materials.append(fm)
for o in (A, B, F):
    for p in o.data.polygons: p.use_smooth = True
bpy.ops.wm.save_as_mainfile(filepath=f'{T}/makoto_prep.blend')
print('SAVED')

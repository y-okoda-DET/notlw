"""The umbrella stand scan (s05) as a prop: python3 scan_umbrella.py -- <prepped.glb> <out.glb>
Scaniverse could not see the clear vinyl: the three furled umbrellas came out as one grey-white lump. Kept from the scan:
the black mesh stand (below its rim) and the three J handles (above the canopies). Rebuilt between them, along the axis
each umbrella really leans on (the centre of its handle's foot -> the centre of its stem at the stand's rim): the furled
vinyl canopy (eight gores, loosely wrapped, some flaps standing out), the shaft and the ribs seen through the vinyl,
and the rubber band that holds the three together. Prints UMB_OK."""
import bpy, bmesh, sys, math, numpy as np
from mathutils import Vector
from scipy.cluster.vq import kmeans2
from scipy.spatial import ConvexHull
a = sys.argv[sys.argv.index('--') + 1:]
inp, out = a[0], a[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=inp)
src = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
for o in bpy.context.selected_objects: o.select_set(False)
bpy.context.view_layer.objects.active = src; src.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True); src.parent = None
P = np.array([v.co[:] for v in src.data.vertices])

# the stand's rim: the height where the widest slice (the stand, ~14 cm) gives way to the narrower umbrellas
zs = np.arange(.05, .45, .01)
def width(z0, z1):
    q = P[(P[:, 2] >= z0) & (P[:, 2] < z1)]
    if len(q) < 20: return 0
    return np.ptp(q[:, 0]) + np.ptp(q[:, 1])
wd = np.array([width(z, z + .01) for z in zs])
base = np.median(wd[(zs > .06) & (zs < .18)])
ST = float(zs[np.argmax((zs > .15) & (wd < base * .8))]) - .015   # just under the rim: the scan's ragged umbrella bits stop there
# the handles' feet: the highest height where the slice is still the three narrow stems, below the hooks' sweep
zh = np.arange(.62, .9, .01)
wh = np.array([width(z, z + .01) for z in zh])
stem = np.median(wh[(zh > .62) & (zh < .74)])
H0 = float(zh[np.argmax((zh > .68) & (wh > stem * 1.3))]) - .01
print('stand rim', round(ST, 3), 'handle feet', round(H0, 3))

def three(z0, z1):
    q = P[(P[:, 2] >= z0) & (P[:, 2] < z1)][:, :2]
    np.random.seed(3)
    c, lab = kmeans2(q, 3, minit='++', seed=3)
    return c
T = three(H0 - .03, H0)
B = three(ST + .01, ST + .05)
# pair each foot with a stem (the assignment with the least lean)
import itertools
best = min(itertools.permutations(range(3)), key=lambda p: sum(np.hypot(*(T[i] - B[p[i]])) for i in range(3)))
axes = []
for i in range(3):
    t = np.array([*T[i], H0]); b = np.array([*B[best[i]], ST + .03])
    d = (t - b) / np.linalg.norm(t - b)
    tip = b + d * ((0.03 - b[2]) / d[2])        # run the axis down to 3 cm off the floor (the ferrule, inside the stand)
    axes.append((tip, t))
    print('umbrella', i, 'tip', np.round(tip, 3), 'top', np.round(t, 3))

# keep the stand and the handles from the scan
bm = bmesh.new(); bm.from_mesh(src.data)
kill = [f for f in bm.faces if not (all(v.co.z < ST for v in f.verts) or all(v.co.z > H0 for v in f.verts))]
bmesh.ops.delete(bm, geom=kill, context='FACES_ONLY')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
seen = set()
for v in list(bm.verts):
    if v in seen or not v.is_valid: continue
    st = [v]; comp = []; seen.add(v)
    while st:
        u = st.pop(); comp.append(u)
        for ed in u.link_edges:
            w = ed.other_vert(u)
            if w not in seen: seen.add(w); st.append(w)
    if len(comp) < 60: bmesh.ops.delete(bm, geom=comp, context='VERTS')
bm.to_mesh(src.data); bm.free()

# ---- the rebuilt parts
def mat(name, col, alpha=1.0, rough=.4, metal=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    p = m.node_tree.nodes['Principled BSDF']
    p.inputs['Base Color'].default_value = (*col, 1); p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    if alpha < 1:
        p.inputs['Alpha'].default_value = alpha
        m.surface_render_method = 'BLENDED'
    m.use_backface_culling = False
    return m
VIN = mat('umb_vinyl', (.86, .9, .9), .38, .18)   # furled, the vinyl lies in several layers: milky, not clear
FOLD = mat('umb_vinyl_fold', (.9, .93, .93), .68, .22)     # where the vinyl lies doubled at the folds it looks whiter
RIB = mat('umb_rib', (.78, .78, .76), 1, .35, .8)
SHAFT = mat('umb_shaft', (.55, .56, .58), 1, .3, .9)
TIP = mat('umb_tip', (.05, .05, .05), 1, .5)
BAND = mat('umb_band', (.04, .04, .045), 1, .6)

verts, faces, fmat = [], [], []
MATS = [VIN, FOLD, RIB, SHAFT, TIP, BAND]
def frame(d):
    up = np.array([0, 0, 1.]) if abs(d[2]) < .9 else np.array([1., 0, 0])
    u = np.cross(d, up); u /= np.linalg.norm(u); v = np.cross(d, u)
    return u, v
def tube(p0, p1, r, m, n=8):
    d = p1 - p0; L = np.linalg.norm(d); d = d / L; u, v = frame(d); k = len(verts)
    for p in (p0, p1):
        for j in range(n):
            a = j / n * math.tau; verts.append(p + (u * math.cos(a) + v * math.sin(a)) * r)
    for j in range(n):
        faces.append((k + j, k + (j + 1) % n, k + n + (j + 1) % n, k + n + j)); fmat.append(m)

def canopy(tip, top, seed):
    R = np.random.default_rng(seed)
    d = top - tip; L = np.linalg.norm(d); d = d / L; u, v = frame(d)
    NG, NA, NL = 8, 64, 44              # gores, points round, rings along
    phase = R.uniform(0, math.tau)
    amp = R.uniform(.12, .32, NG)       # how far each gore's fold stands out
    flap = R.integers(NG); flap_amp = R.uniform(.35, .6)   # one loose gore, not wrapped tight
    twist = R.uniform(-.5, .5)          # the folds spiral a little round the shaft (wrapped by hand)
    s0 = .07                            # the canopy starts above the ferrule
    k = len(verts)
    for i in range(NL):
        s = s0 + (1 - s0) * i / (NL - 1)
        # furled profile: thin at the ferrule, fullest two-thirds up, gathered under the top notch
        r = .008 + .020 * min(1, (s - s0) / .6) ** .8   # a furled 60 cm vinyl umbrella is about 6 cm across
        if s > .82: r = r * (1 - .55 * ((s - .82) / .18) ** 1.5)
        band = math.exp(-((s - SB) / .025) ** 2)          # the snap strap pulls it in
        r *= 1 - .25 * band
        for j in range(NA):
            a = j / NA * math.tau
            g = (a - phase + twist * s) / math.tau * NG
            gi = int(math.floor(g)) % NG; fr = g - math.floor(g)
            ridge = math.cos(fr * math.tau) * .5 + .5          # 1 on a fold's crest, 0 in the gore between
            ex = amp[gi] * ridge ** 3
            if gi == flap: ex += flap_amp * ridge ** 2 * min(1, (s - s0) / .4) * (1 - band)
            rr = r * (1 + ex) + .0008 * R.standard_normal()
            p = tip + d * (s * L) + (u * math.cos(a) + v * math.sin(a)) * rr
            verts.append(p)
    for i in range(NL - 1):
        for j in range(NA):
            a0 = k + i * NA + j; a1 = k + i * NA + (j + 1) % NA
            faces.append((a0, a1, a1 + NA, a0 + NA))
            # the crests read whiter
            g = (j / NA * math.tau - phase + twist * (s0 + (1 - s0) * i / (NL - 1))) / math.tau * NG
            fr = g - math.floor(g)
            fmat.append(FOLD if (fr < .12 or fr > .88) else VIN)
    # shaft, ribs, ferrule
    tube(tip, top, .0042, SHAFT, 8)
    tube(tip - d * .005, tip + d * .06, .0065, TIP, 8)
    for g in range(NG):
        a = phase + (g + .5) / NG * math.tau
        pts = []
        for s in (.12, .4, .66, .92):
            r = .008 + .020 * min(1, (s - s0) / .6) ** .8
            if s > .82: r *= 1 - .55 * ((s - .82) / .18) ** 1.5
            pts.append(tip + d * (s * L) + (u * math.cos(a) + v * math.sin(a)) * r * .7)
        for p0, p1 in zip(pts, pts[1:]): tube(p0, p1, .0011, RIB, 4)
    return lambda s: tip + d * (s * L)

zb = .47   # the scan's rubber band
SB = (zb - .03) / (H0 - .03)
centres = [canopy(np.array(t), np.array(b), 11 + i) for i, (t, b) in enumerate(axes)]

# the rubber band round all three, at the strap height of the scan (~.47 m): the hull of the three canopies' sections
pts = []
for (tip, top) in axes:
    dd = (top - tip); c = tip + dd * ((zb - tip[2]) / dd[2])
    for j in range(24):
        a = j / 24 * math.tau; pts.append(c[:2] + .022 * np.array([math.cos(a), math.sin(a)]))
pts = np.array(pts); hull = pts[ConvexHull(pts).vertices]
cen = hull.mean(0)
ring = [np.array([*(cen + (q - cen) * 1.0), zb]) for q in hull]
k = len(verts); n = len(ring)
for q in ring:
    o = q[:2] - cen; o = o / np.linalg.norm(o)
    for dz, dr in ((-.004, 0), (.004, 0), (.004, .003), (-.004, .003)):
        verts.append(np.array([q[0] + o[0] * dr, q[1] + o[1] * dr, q[2] + dz]))
for j in range(n):
    for e in range(4):
        a0 = k + j * 4 + e; a1 = k + j * 4 + (e + 1) % 4; b0 = k + ((j + 1) % n) * 4 + e; b1 = k + ((j + 1) % n) * 4 + (e + 1) % 4
        faces.append((a0, a1, b1, b0)); fmat.append(BAND)

me = bpy.data.meshes.new('umb'); me.from_pydata([tuple(p) for p in verts], [], faces); me.validate()
for m in MATS: me.materials.append(m)
for f, m in zip(me.polygons, fmat): f.material_index = MATS.index(m); f.use_smooth = True
new = bpy.data.objects.new('umb', me); bpy.context.scene.collection.objects.link(new)
# one object: the scan's stand and handles + the rebuilt umbrellas
for o in bpy.context.selected_objects: o.select_set(False)
src.select_set(True); new.select_set(True); bpy.context.view_layer.objects.active = src
bpy.ops.object.join()
Q = np.array([v.co[:] for v in src.data.vertices])
print('size cm', np.round((Q.max(0) - Q.min(0)) * 100, 1), 'faces', len(src.data.polygons))
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True)
print('UMB_OK', out)

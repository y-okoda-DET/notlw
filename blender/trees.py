"""Japanese cedar (スギ) for the woods round the house: a plantation on a Japanese mountain, which is what a hired
villa built to look like an American film would really stand in.

  sugi_stand(M, centre, r0, r1, keep(x, y) -> bool, ground(x, y) -> z, seed, n_unique, spacing)
      plants trees between radii r0..r1 round `centre` on a jittered grid (rows of a plantation, a little uneven),
      skipping where keep() is False. n_unique different trees are built; the rest are linked copies of them,
      turned, scaled and leaned, so the glb stays small.
  sugi(name, seed, M) -> (trunk object, foliage object) at the origin

What makes it a sugi rather than a cone: a straight, tall trunk with fibrous red-brown bark, flaring at the foot;
the lower half bare except for dead grey stubs (a plantation is pruned and shades itself); the crown in the upper
40-55%, narrow and pointed; branches all round in a spiral, the lower ones drooping with upturned tips; the foliage
in separate clumps (房) with sky between them, darker inside. Each tree has its own height, girth, lean, a slight
bend, crown length and density; a few have a broken or doubled top."""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import paths as P
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import bpy, bmesh
from mathutils import Vector, Matrix, Quaternion
import lib, exterior as X

GOLD = 2.39996

# ------------------------------------------------------------------ the foliage spray (one card's image)
def spray_image():
    def make():
        rng = np.random.default_rng(3); S = 2048
        im = Image.new('RGBA', (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
        def col(depth, k):
            # tips lighter and yellower, the inside dark; a few bronzed (winter sugi browns where it is shaded)
            base = np.array([22, 38, 17]) + np.array([16, 20, 7]) * (k + rng.normal(0, .25))
            if rng.random() < .06: base = np.array([58, 40, 20]) + rng.normal(0, 6, 3)
            return tuple(int(max(0, min(255, c))) for c in base) + (255,)
        def shoot(x, y, ang, length, width, depth):
            n = max(6, int(length / (width * .5)))
            pts = []; a = ang
            for i in range(n + 1):
                pts.append((x, y)); a += rng.normal(0, .04); s = length / n
                x += math.cos(a) * s; y += math.sin(a) * s
            for i, (px, py) in enumerate(pts):   # the cord of awl-shaped needles, packed all round the shoot
                k = i / n
                w = width * (1 - .55 * k)
                for side in (-1, 1):
                    na = ang + side * rng.uniform(.25, .6)
                    ln = w * rng.uniform(.75, 1.1)
                    d.line([(px, py), (px + math.cos(na) * ln, py + math.sin(na) * ln)], fill=col(depth, k), width=max(3, int(w * .5)))
                d.ellipse([px - w * .3, py - w * .3, px + w * .3, py + w * .3], fill=col(depth, k * .8))
            if depth > 0:
                side = 1 if rng.random() < .5 else -1
                for i in range(2, n - 2, max(2, int(n / 9))):
                    side = -side
                    px, py = pts[i]; k = i / n
                    shoot(px, py, ang + side * rng.uniform(.5, .85), length * (.47 - .3 * k) * rng.uniform(.8, 1.1), width * .8, depth - 1)
        # main shoot from the bottom centre up, a fan of side shoots
        shoot(S * .5, S * .97, -math.pi / 2 + rng.normal(0, .05), S * .8, S * .032, 2)
        im = im.resize((1024, 1024), Image.LANCZOS)
        a = np.asarray(im, np.float32) / 255
        rgb = a[..., :3].copy(); al = a[..., 3]
        # un-premultiply the dark fringe the resize left round the alpha edge
        m = al > .02; rgb[m] = rgb[m] / al[m, None]
        rgb[~m] = np.array([.09, .14, .07])
        return {'a': np.dstack([np.clip(rgb, 0, 1), al])}
    p = X.cached({'spray': 7}, ('a',), make)
    return p['a']

def mats(M):
    if 'ext_sugi_leaf' in M: return
    M['ext_sugi_leaf'] = X.mat_maps('ext_sugi_leaf', spray_image(), None, rough=.8, alpha=True)
    def bark():
        a = X.src('acg_Bark014', 'diff', (1024, 1024)) * np.array([.95, .78, .68], np.float32)   # sugi: red-brown fibre (ambientCG Bark014, CC0)
        return {'a': a, 'n': X.src('acg_Bark014', 'nor_gl', (1024, 1024))}
    p = X.cached({'sugibark': 4}, ('a', 'n'), bark)
    M['ext_sugi_bark'] = X.mat_maps('ext_sugi_bark', p['a'], p['n'], rough=.9)
    M['ext_sugi_dead'] = lib.mat_basic('ext_sugi_dead', (.20, .18, .16), .9)

# ------------------------------------------------------------------ one tree
def _frame(d):
    d = d.normalized(); a = Vector((0, 0, 1)) if abs(d.z) < .95 else Vector((1, 0, 0))
    x = d.cross(a).normalized(); y = d.cross(x).normalized(); return x, y

def _tube(bm, uvl, pts, radii, sides, vrep=1.0, urep=1.0):
    """A tapered tube through pts (bmesh). UV u round, v along (metres / vrep)."""
    rings = []; vacc = 0
    for i, (p, r) in enumerate(zip(pts, radii)):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)])
        x, y = _frame(d)
        if i: vacc += (pts[i] - pts[i - 1]).length
        ring = []
        for k in range(sides + 1):
            a = k / sides * math.tau
            v = bm.verts.new(p + (x * math.cos(a) + y * math.sin(a)) * r) if k < sides else ring[0][0]
            ring.append((v, (k / sides * urep, vacc / vrep)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(sides):
            a0, a1 = rings[i][k], rings[i][k + 1]; b0, b1 = rings[i + 1][k], rings[i + 1][k + 1]
            try: f = bm.faces.new((a0[0], a1[0], b1[0], b0[0]))
            except ValueError: continue
            for loop, uv in zip(f.loops, (a0[1], a1[1], b1[1], b0[1])): loop[uvl].uv = uv

def sugi(name, seed, M, edge=False):
    mats(M)
    rng = np.random.default_rng(seed)
    h = rng.uniform(15, 25)                       # height (m)
    r0 = h * rng.uniform(.0105, .0145)           # radius at breast height
    lean = rng.uniform(0, math.radians(4)); lean_az = rng.uniform(0, math.tau)
    bend = rng.normal(0, .25)
    crown0 = h * (rng.uniform(.14, .3) if edge else rng.uniform(.42, .6))   # where the live crown starts (low at the clearing's edge: it gets the light)
    crown_r = h * rng.uniform(.10, .14) * (1.2 if edge else 1)   # its widest radius (narrow, pointed)
    dens = rng.uniform(.75, 1.15)
    top = rng.choice(['ok', 'ok', 'ok', 'ok', 'ok', 'broken', 'double'])
    ld = Vector((math.cos(lean_az), math.sin(lean_az), 0))
    def axis(z):   # trunk centre at height z: lean plus a slight bend
        t = z / h
        return ld * (math.tan(lean) * z + bend * math.sin(t * math.pi) * .4) + Vector((0, 0, z))
    def radius(z):
        t = min(1.0, max(0.0, z / h))
        return r0 * (1.15 * (1 - t) ** .85 + .02) + r0 * .7 * math.exp(-z / .45)   # taper + flare at the foot
    # --- trunk and branches (bark)
    bm = bmesh.new(); uvl = bm.loops.layers.uv.new('UVMap')
    zt = h * (.88 if top == 'broken' else 1.0)
    zs = list(np.concatenate([np.linspace(-.3, 1.2, 5), np.linspace(1.6, zt, 16)]))
    circ = 2 * math.pi * r0
    _tube(bm, uvl, [axis(z) for z in zs], [radius(z) for z in zs], 12, vrep=1.2, urep=max(1, round(circ / .5)))
    bark_tris = []
    dead_bm = bmesh.new(); duvl = dead_bm.loops.layers.uv.new('UVMap')
    # dead stubs below the crown
    for z in np.arange(crown0 - rng.uniform(2.5, 5), crown0, rng.uniform(.25, .45)):
        if z < 2: continue
        az = rng.uniform(0, math.tau); L = rng.uniform(.08, .7)
        dvec = Vector((math.cos(az), math.sin(az), -rng.uniform(.1, .6))).normalized()
        p0 = axis(z) + Vector((math.cos(az), math.sin(az), 0)) * radius(z) * .8
        _tube(dead_bm, duvl, [p0, p0 + dvec * L], [.018, .006], 4)
    # live branches
    leaf = []   # (centre, branch dir, size, inner) for the foliage cards
    n_br = int((zt - crown0) / .075 * dens)
    for i in range(n_br):
        s = i / max(1, n_br - 1)                  # 0 at the crown's base, 1 at the top
        z = crown0 + (zt - crown0) * s + rng.normal(0, .05)
        az = i * GOLD + rng.normal(0, .25)
        prof = (1 - s) ** .8 * (.55 + .45 * min(1, s * 6))   # the crown's outline: widest a little above its base
        L = crown_r * prof * rng.uniform(.7, 1.15) + .25
        if rng.random() < .08 and s < .7: L *= .45            # a shaded-out short branch: a gap in the crown
        el = math.radians(-22 + 55 * s + rng.normal(0, 8))    # low ones droop, high ones climb
        hd = Vector((math.cos(az), math.sin(az), 0))
        p0 = axis(z) + hd * radius(z) * .7
        pts = []; nseg = 4
        for k in range(nseg + 1):
            t = k / nseg
            sag = -L * .12 * math.sin(math.pi * t) * (1 - s) + L * .14 * t * t * (1 - s)   # droop, then the tip turns up
            pts.append(p0 + hd * (L * t * math.cos(el)) + Vector((0, 0, L * t * math.sin(el) + sag)))
        rb = .012 + .03 * L / 3
        _tube(bm, uvl, pts, [rb * (1 - .85 * k / nseg) for k in range(nseg + 1)], 4, vrep=1.2)
        # foliage clumps along the outer part of the branch
        nc = max(1, int(L / .17 * dens))
        for k in range(nc):
            t = .2 + .8 * (k + rng.uniform(0, .6)) / nc
            if rng.random() < .1: continue
            idx = min(nseg - 1, int(t * nseg)); f = t * nseg - idx
            c = pts[idx].lerp(pts[idx + 1], f) + Vector(rng.normal(0, .1, 3))
            dirv = ((pts[idx + 1] - pts[idx]).normalized() + Vector(rng.normal(0, .35, 3))).normalized()
            leaf.append((c, dirv, rng.uniform(.6, 1.0) * (.75 + .35 * (1 - s)), t < .5))
    # the leader: clumps round the top metre and a half
    tops = [zt] if top != 'double' else [zt, zt - .8]
    for j, ztop in enumerate(tops):
        off = Vector((0, 0, 0)) if j == 0 else ld.cross(Vector((0, 0, 1))) * .35
        for k in range(int(9 * dens)):
            z = ztop - 1.6 * k / 9
            c = axis(z) + off + Vector((rng.normal(0, .08), rng.normal(0, .08), 0))
            leaf.append((c, Vector((rng.normal(0, .3), rng.normal(0, .3), 1)).normalized(), rng.uniform(.45, .7) * (1 - .5 * (1 - k / 9) ** 3 * 0), False))
    me = bpy.data.meshes.new(name + '_trunk'); bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = True
    tr = lib.link(bpy.data.objects.new(name + '_trunk', me)); tr.data.materials.append(M['ext_sugi_bark'])
    dme = bpy.data.meshes.new(name + '_dead'); dead_bm.to_mesh(dme); dead_bm.free()
    if len(dme.polygons):
        dme.materials.append(M['ext_sugi_dead']); tr.data.materials.append(M['ext_sugi_dead'])
        # merge the stubs into the trunk object (one object per tree for the bark)
        dob = lib.link(bpy.data.objects.new(name + '_dead', dme))
        for p in dob.data.polygons: p.material_index = 1; p.use_smooth = True
        bpy.ops.object.select_all(action='DESELECT'); tr.select_set(True); dob.select_set(True)
        bpy.context.view_layer.objects.active = tr; bpy.ops.object.join()
    # --- foliage cards: 3 crossed cards per clump, the spray's main axis along the branch
    V = []; F = []; UV = []; NR = []
    for (c, dirv, size, inner) in leaf:
        x, y = _frame(dirv)
        roll = rng.uniform(0, math.pi)
        for k in range(3):
            a = roll + k * math.pi / 3
            side = x * math.cos(a) + y * math.sin(a)
            fwd = dirv
            w = size * .5; ln = size
            base = c - fwd * ln * .35
            q = [base - side * w, base + side * w, base + side * w + fwd * ln, base - side * w + fwd * ln]
            # a little droop of the far end
            q[2] = q[2] - Vector((0, 0, ln * .12)); q[3] = q[3] - Vector((0, 0, ln * .12))
            i0 = len(V); V += [tuple(v) for v in q]; F.append((i0, i0 + 1, i0 + 2, i0 + 3))
            UV.append([(0, 0), (1, 0), (1, 1), (0, 1)])
            # normals: out from the trunk axis, a bit up (soft, volume-like light on the crown)
            for v in q:
                ax = axis(max(0, min(h, v[2])))
                nrm = Vector((v[0] - ax.x, v[1] - ax.y, 0))
                nrm = (nrm.normalized() if nrm.length > 1e-4 else Vector((0, 0, 1))) * .8 + Vector((0, 0, .45))
                NR.append(nrm.normalized())
    fme = bpy.data.meshes.new(name + '_leaf'); fme.from_pydata(V, [], F); fme.update()
    uvl2 = fme.uv_layers.new(name='UVMap')
    for poly, uvs in zip(fme.polygons, UV):
        for li, uv in zip(poly.loop_indices, uvs): uvl2.data[li].uv = uv
    for p in fme.polygons: p.use_smooth = True
    try:
        fme.normals_split_custom_set_from_vertices([tuple(n) for n in NR])
    except Exception as e: print('custom normals', e)
    fo = lib.link(bpy.data.objects.new(name + '_leaf', fme)); fo.data.materials.append(M['ext_sugi_leaf'])
    return tr, fo

def sugi_stand(M, centre=(0, 0), r0=12, r1=27, keep=lambda x, y: True, ground=lambda x, y: 0.0, seed=1, n_unique=14, spacing=2.6):
    rng = np.random.default_rng(seed)
    n_edge = max(1, n_unique * 3 // 7)
    protos = [sugi(f'ext_sugi{i}', seed * 100 + i, M, edge=i < n_edge) for i in range(n_unique)]
    for tr, fo in protos:   # the prototypes are moved into place below like the copies
        tr.location = fo.location = (0, 0, -100)
    spots = []
    rot = rng.uniform(0, math.pi)   # the plantation rows' direction
    cr, sr = math.cos(rot), math.sin(rot)
    for i in np.arange(-r1, r1 + 1e-6, spacing):
        for j in np.arange(-r1, r1 + 1e-6, spacing * .9):
            x = centre[0] + i * cr - j * sr + rng.normal(0, spacing * .22)
            y = centre[1] + i * sr + j * cr + rng.normal(0, spacing * .22)
            d = math.hypot(x - centre[0], y - centre[1])
            if d < r0 + rng.normal(0, 1.2) or d > r1: continue
            if rng.random() < .1: continue                    # a gap where a tree died or was felled
            if not keep(x, y): continue
            spots.append((x, y, d))
    spots.sort(key=lambda s: s[2])
    used = [False] * n_unique
    for (x, y, d) in spots:
        k = int(rng.integers(0, n_edge)) if d < r0 + 3.5 else int(rng.integers(n_edge, n_unique))
        if not used[k]: tr, fo = protos[k]; used[k] = True
        else:
            tr0, fo0 = protos[k]
            tr = tr0.copy(); fo = fo0.copy(); lib.link(tr); lib.link(fo)   # linked: same mesh data
            tr.name = f'{tr0.name}_c'; fo.name = f'{fo0.name}_c'
        sc = rng.uniform(.85, 1.15)
        rz = rng.uniform(0, math.tau); tilt = rng.normal(0, math.radians(1.5))
        for o in (tr, fo):
            o.location = (x, y, ground(x, y) - .05); o.rotation_euler = (tilt, rng.normal(0, math.radians(1)) * 0, rz)
            o.scale = (sc, sc, sc)
    for k in range(n_unique):   # a prototype nobody used stays out of the scene
        if not used[k]:
            for o in protos[k]: bpy.data.objects.remove(o)
    print('sugi:', len(spots), 'trees,', n_unique, 'unique')
    return len(spots)

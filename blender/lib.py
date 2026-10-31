"""Shared builders for the RULES keyframes (Blender 5.2, Z-up, meters).
Everything here is meant to survive the trip to a real-time engine:
low-poly meshes, image or simple procedural materials, punctual lights only."""
import paths as P   # all paths: paths.env
import bpy, bmesh, math, json, os
import numpy as np
from mathutils import Vector, Matrix, Euler

FACES = f'{P.ASSETS}/faces'
TEX = f'{P.ASSETS}/tex'
KF = P.KF
MASKS = json.load(open(f'{KF}/masks.json'))

# ---------------------------------------------------------------- scene setup
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.engine = 'CYCLES'
    s.cycles.device = 'CPU'
    s.cycles.use_denoising = True
    s.cycles.denoiser = 'OPENIMAGEDENOISE'
    s.view_settings.view_transform = 'AgX'
    s.view_settings.look = 'None'
    s.render.resolution_x, s.render.resolution_y = 1920, 1080
    s.render.film_transparent = False
    w = bpy.data.worlds.new('W'); s.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes['Background']; bg.inputs[0].default_value = (0, 0, 0, 1); bg.inputs[1].default_value = 0
    return s

def kelvin(k):
    """Approximate blackbody -> linear RGB (Tanner Helland fit, then to linear)."""
    t = k / 100.0
    r = 255 if t <= 66 else 329.698727446 * ((t - 60) ** -0.1332047592)
    g = 99.4708025861 * math.log(t) - 161.1195681661 if t <= 66 else 288.1221695283 * ((t - 60) ** -0.0755148492)
    b = 255 if t >= 66 else (0 if t <= 19 else 138.5177312231 * math.log(t - 10) - 305.0447927307)
    c = [max(0, min(255, v)) / 255 for v in (r, g, b)]
    return tuple(v ** 2.2 for v in c)

def link(obj, col=None):
    (col or bpy.context.scene.collection).objects.link(obj); return obj

def mesh_obj(name, verts, faces, smooth=False):
    me = bpy.data.meshes.new(name); me.from_pydata(verts, [], faces); me.update()
    if smooth:
        for p in me.polygons: p.use_smooth = True
    return link(bpy.data.objects.new(name, me))

def prim(kind, name, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), mat=None, **kw):
    getattr(bpy.ops.mesh, f'primitive_{kind}_add')(location=loc, rotation=rot, **kw)
    o = bpy.context.active_object; o.name = name; o.scale = scale
    if mat: o.data.materials.append(mat)
    return o

def smooth(o, angle=40):
    for p in o.data.polygons: p.use_smooth = True
    try:
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.shade_auto_smooth(angle=math.radians(angle))
    except Exception:
        pass

# ---------------------------------------------------------------- materials
def _nodes(m):
    m.use_nodes = True; nt = m.node_tree
    return nt, nt.nodes, nt.links

def mat_basic(name, color, rough=.7, spec=.3, emit=None, estr=0, metal=0, sss=0):
    m = bpy.data.materials.new(name); nt, N, L = _nodes(m)
    p = N['Principled BSDF']
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Specular IOR Level'].default_value = spec
    p.inputs['Metallic'].default_value = metal
    if sss: p.inputs['Subsurface Weight'].default_value = sss
    if emit:
        p.inputs['Emission Color'].default_value = (*emit, 1); p.inputs['Emission Strength'].default_value = estr
    return m

def img(path, srgb=True):
    i = bpy.data.images.load(path, check_existing=True)
    i.colorspace_settings.name = 'sRGB' if srgb else 'Non-Color'
    return i

def mat_image(name, path, rough=.75, scale=(1, 1), bump=.15, tint=(1, 1, 1), coords='UV', fallback=None):
    """Image texture if the file exists, otherwise a procedural fallback (callable(nt,N,L,p))."""
    m = bpy.data.materials.new(name); nt, N, L = _nodes(m); p = N['Principled BSDF']
    p.inputs['Roughness'].default_value = rough
    if path and os.path.exists(path):
        tc = N.new('ShaderNodeTexCoord'); mp = N.new('ShaderNodeMapping')
        mp.inputs['Scale'].default_value = (scale[0], scale[1], 1)
        L.new(tc.outputs[coords], mp.inputs['Vector'])
        t = N.new('ShaderNodeTexImage'); t.image = img(path); L.new(mp.outputs[0], t.inputs[0])
        if coords == 'Object': t.projection = 'BOX'; t.projection_blend = .25
        mix = N.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'; mix.inputs['Factor'].default_value = 1
        L.new(t.outputs[0], mix.inputs['A']); mix.inputs['B'].default_value = (*tint, 1)
        L.new(mix.outputs['Result'], p.inputs['Base Color'])
        if bump:
            b = N.new('ShaderNodeBump'); b.inputs['Strength'].default_value = bump; b.inputs['Distance'].default_value = .004
            L.new(t.outputs[0], b.inputs['Height']); L.new(b.outputs[0], p.inputs['Normal'])
    elif fallback:
        fallback(nt, N, L, p)
    return m

def wood_proc(base=(.55, .36, .2), dark=(.25, .14, .07), scale=6., stretch=(1, 1, 8), bumpv=.25, axis='X'):
    """Procedural wood grain: stretched noise + wave rings. Grain runs along `axis` in object space."""
    def f(nt, N, L, p):
        tc = N.new('ShaderNodeTexCoord'); mp = N.new('ShaderNodeMapping')
        sx, sy, sz = stretch
        if axis == 'X': mp.inputs['Scale'].default_value = (1 / sz * scale, scale, scale)
        elif axis == 'Y': mp.inputs['Scale'].default_value = (scale, 1 / sz * scale, scale)
        else: mp.inputs['Scale'].default_value = (scale, scale, 1 / sz * scale)
        L.new(tc.outputs['Object'], mp.inputs['Vector'])
        nz = N.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 2.2; nz.inputs['Detail'].default_value = 9; nz.inputs['Roughness'].default_value = .62
        L.new(mp.outputs[0], nz.inputs['Vector'])
        wv = N.new('ShaderNodeTexWave'); wv.wave_type = 'RINGS'; wv.inputs['Scale'].default_value = 1.4
        wv.inputs['Distortion'].default_value = 7; wv.inputs['Detail'].default_value = 4
        L.new(mp.outputs[0], wv.inputs['Vector'])
        mx = N.new('ShaderNodeMath'); mx.operation = 'MULTIPLY'; L.new(nz.outputs['Fac'], mx.inputs[0]); L.new(wv.outputs['Fac'], mx.inputs[1])
        cr = N.new('ShaderNodeValToRGB'); cr.color_ramp.elements[0].position = .05; cr.color_ramp.elements[0].color = (*dark, 1)
        cr.color_ramp.elements[1].position = .55; cr.color_ramp.elements[1].color = (*base, 1)
        L.new(mx.outputs[0], cr.inputs[0]); L.new(cr.outputs[0], p.inputs['Base Color'])
        b = N.new('ShaderNodeBump'); b.inputs['Strength'].default_value = bumpv; b.inputs['Distance'].default_value = .003
        L.new(mx.outputs[0], b.inputs['Height']); L.new(b.outputs[0], p.inputs['Normal'])
    return f

def noise_proc(base, dark, scale=40., bumpv=.1):
    def f(nt, N, L, p):
        tc = N.new('ShaderNodeTexCoord'); nz = N.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = scale; nz.inputs['Detail'].default_value = 6
        L.new(tc.outputs['Object'], nz.inputs['Vector'])
        cr = N.new('ShaderNodeValToRGB'); cr.color_ramp.elements[0].color = (*dark, 1); cr.color_ramp.elements[1].color = (*base, 1)
        cr.color_ramp.elements[0].position = .3; cr.color_ramp.elements[1].position = .7
        L.new(nz.outputs['Fac'], cr.inputs[0]); L.new(cr.outputs[0], p.inputs['Base Color'])
        b = N.new('ShaderNodeBump'); b.inputs['Strength'].default_value = bumpv; L.new(nz.outputs['Fac'], b.inputs['Height']); L.new(b.outputs[0], p.inputs['Normal'])
    return f

def tex_path(n):
    for ext in ('png', 'jpg', 'jpeg', 'webp'):
        p = f'{TEX}/{n}.{ext}'
        if os.path.exists(p): return p
    return None

# ---------------------------------------------------------------- characters
PX = 0.37 / 1254.0   # meters per portrait pixel

def bust(key, open_eyes=True, name=None):
    """Head+hair+neck mesh lofted from the portrait silhouette; portrait projected from the front."""
    name = name or key
    info = MASKS[key]; rows = info['rows']
    fn = f'{FACES}/{key}_open.png' if key != 'yota_smile' else f'{FACES}/yota_smile.png'
    if not open_eyes:
        fn = f'{FACES}/{key}_closed.png' if key != 'yota_smile' else f'{FACES}/yota_smile_closed.png'
    im = np.asarray(bpy.data.images.load(fn, check_existing=True).pixels[:], dtype=np.float32)
    W = H = 1254
    im = im.reshape(H, W, 4)[::-1]  # top row first
    # neck: narrowest row between 760 and 980
    cand = [r for r in rows if 760 <= r[0] <= 980 and r[1] >= 0]
    neck = min(cand, key=lambda r: r[2] - r[1])
    y_end = neck[0] + 60
    sel = [[r[0], r[1] + 7, r[2] - 7] for r in rows if info['top'] + 10 <= r[0] <= y_end + 40 and r[1] >= 0]
    arr = np.array(sel, float)
    k = np.exp(-np.linspace(-2, 2, 11) ** 2); k /= k.sum()
    for c in (1, 2):
        pad = np.pad(arr[:, c], 5, mode='edge'); arr[:, c] = np.convolve(pad, k, 'valid')
    use = [list(r) for r in arr if r[0] <= y_end][::2]
    N = 36
    verts, faces, cols, uvs = [], [], [], []
    top_px = info['top']
    for ri, (y, xl, xr) in enumerate(use):
        w = (xr - xl) * PX; cx = ((xl + xr) / 2 - 627) * PX
        z = (627 - y) * PX
        tt = min(1, max(0, (y - (neck[0] - 260)) / 220.0)); tt = tt * tt * (3 - 2 * tt)
        depth = w * (1.18 - .2 * tt)
        back_off = w * (.10 - .08 * tt)
        # back colour: sample just inside the silhouette edge
        sx = int(min(W - 1, xl + 45)); sy = int(min(H - 1, y))
        bc = im[sy, sx, :3]
        for k in range(N):
            a = k / N * math.tau
            x = cx + math.sin(a) * w / 2
            yy = -math.cos(a) * depth / 2
            if math.cos(a) > 0: yy *= .86   # flatter face plane
            yy += back_off
            if math.cos(a) > .2 and y > 430:   # facial relief: nose, sockets, chin
                fx = (x / PX + 627 - 627); fy = y
                g = lambda cx_, cy_, sx_, sy_: math.exp(-(((fx - cx_) / sx_) ** 2 + ((fy - cy_) / sy_) ** 2))
                rel = .020 * g(0, 660, 38, 95) + .006 * g(0, 760, 70, 30) + .006 * g(0, 870, 90, 45) - .007 * (g(-115, 545, 55, 32) + g(115, 545, 55, 32)) + .004 * (g(-130, 470, 80, 20) + g(130, 470, 80, 20))
                yy -= rel * max(0, math.cos(a)) ** .5
            verts.append((x, yy, z)); cols.append((*bc, 1.0))
    # crown cap
    y0, xl0, xr0 = use[0]
    verts.append((((xl0 + xr0) / 2 - 627) * PX, .01, (627 - (top_px + 6)) * PX)); cols.append(cols[0])
    cap = len(verts) - 1
    for ri in range(len(use) - 1):
        for k in range(N):
            a = ri * N + k; b = ri * N + (k + 1) % N; c = (ri + 1) * N + (k + 1) % N; d = (ri + 1) * N + k
            faces.append((a, d, c, b))
    for k in range(N): faces.append((cap, k, (k + 1) % N))
    o = mesh_obj(f'{name}_head', verts, faces, smooth=True)
    me = o.data
    # planar UV from the front: u = image x, v = image y
    uvl = me.uv_layers.new(name='proj')
    for poly in me.polygons:
        for li in poly.loop_indices:
            v = me.vertices[me.loops[li].vertex_index].co
            uvl.data[li].uv = ((v.x / PX + 627) / W, 1 - (627 - v.z / PX) / H)
    ca = me.color_attributes.new('back', 'FLOAT_COLOR', 'POINT')
    for i, c in enumerate(cols): ca.data[i].color = c
    # material: portrait on the front, edge colour behind
    m = bpy.data.materials.new(f'{name}_face'); nt, Nn, L = _nodes(m); p = Nn['Principled BSDF']
    p.inputs['Roughness'].default_value = .55; p.inputs['Subsurface Weight'].default_value = .08
    p.inputs['Subsurface Radius'].default_value = (.6, .25, .15)
    t = Nn.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(fn, check_existing=True); t.extension = 'EXTEND'
    uvn = Nn.new('ShaderNodeUVMap'); uvn.uv_map = 'proj'; L.new(uvn.outputs[0], t.inputs[0])
    va = Nn.new('ShaderNodeVertexColor'); va.layer_name = 'back'
    geo = Nn.new('ShaderNodeNewGeometry')
    # facing = -normal_obj.y  (front faces -Y)
    tr = Nn.new('ShaderNodeVectorTransform'); tr.vector_type = 'NORMAL'; tr.convert_from = 'WORLD'; tr.convert_to = 'OBJECT'
    L.new(geo.outputs['Normal'], tr.inputs[0])
    sep = Nn.new('ShaderNodeSeparateXYZ'); L.new(tr.outputs[0], sep.inputs[0])
    neg = Nn.new('ShaderNodeMath'); neg.operation = 'MULTIPLY'; neg.inputs[1].default_value = -1; L.new(sep.outputs['Y'], neg.inputs[0])
    mr = Nn.new('ShaderNodeMapRange'); mr.inputs['From Min'].default_value = -.05; mr.inputs['From Max'].default_value = .35
    L.new(neg.outputs[0], mr.inputs['Value'])
    mix = Nn.new('ShaderNodeMix'); mix.data_type = 'RGBA'
    L.new(mr.outputs[0], mix.inputs['Factor']); L.new(va.outputs['Color'], mix.inputs['A']); L.new(t.outputs['Color'], mix.inputs['B'])
    L.new(mix.outputs['Result'], p.inputs['Base Color'])
    me.materials.append(m)
    # origin at neck base
    o.data.transform(Matrix.Translation((0, 0, -(627 - y_end) * PX)))
    o['neck_px'] = neck[0]
    return o

def body(name, joints, radii, mat, parent_obj=None, subdiv=1):
    """Skin-modifier limb set: joints = dict name->(x,y,z); edges inferred from `chain` lists in radii keys."""
    names = list(joints.keys()); idx = {n: i for i, n in enumerate(names)}
    edges = []
    for a, b in radii['edges']:
        if a in idx and b in idx: edges.append((idx[a], idx[b]))
    me = bpy.data.meshes.new(name); me.from_pydata([joints[n] for n in names], edges, []); me.update()
    o = link(bpy.data.objects.new(name, me))
    sk = o.modifiers.new('skin', 'SKIN'); sk.use_smooth_shade = True
    o.data.skin_vertices[0].data[0].use_root = True
    for n, i in idx.items():
        r = radii['r'].get(n, (.04, .04))
        o.data.skin_vertices[0].data[i].radius = r
    if subdiv:
        sd = o.modifiers.new('sub', 'SUBSURF'); sd.levels = subdiv; sd.render_levels = subdiv
    o.data.materials.append(mat)
    return o

def apply_mods(o):
    bpy.context.view_layer.objects.active = o
    for m in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)

# A standing human, 1.0 = person height scale. Pose overrides per joint.
BASE = dict(
    pelvis=(0, 0, .95), spine=(0, .005, 1.12), chest=(0, .0, 1.30), neckb=(0, .01, 1.44),
    lsh=(.17, .01, 1.40), lel=(.21, .03, 1.14), lwr=(.22, .0, .90), lha=(.22, -.01, .82),
    rsh=(-.17, .01, 1.40), rel=(-.21, .03, 1.14), rwr=(-.22, .0, .90), rha=(-.22, -.01, .82),
    lhip=(.09, 0, .92), lkn=(.1, -.01, .5), lan=(.1, .02, .08), lto=(.1, -.1, .03),
    rhip=(-.09, 0, .92), rkn=(-.1, -.01, .5), ran=(-.1, .02, .08), rto=(-.1, -.1, .03),
)
TOP_EDGES = [('pelvis', 'spine'), ('spine', 'chest'), ('chest', 'neckb'), ('chest', 'lsh'), ('lsh', 'lel'), ('lel', 'lwr'),
             ('chest', 'rsh'), ('rsh', 'rel'), ('rel', 'rwr')]
LEG_EDGES = [('pelvis', 'lhip'), ('lhip', 'lkn'), ('lkn', 'lan'), ('pelvis', 'rhip'), ('rhip', 'rkn'), ('rkn', 'ran')]
FOOT_EDGES = [('lan', 'lto'), ('ran', 'rto')]

def person(key, pose=None, top=None, pants=None, feet=None, skin=(0.8, .6, .5), build=1.0, height=1.0,
           loc=(0, 0, 0), yaw=0, head_yaw=0, head_pitch=0, open_eyes=True, label=None, top_rad=None):
    """Assemble a posed person. Returns root empty."""
    j = dict(BASE); j.update(pose or {})
    j = {k: (v[0] * build, v[1], v[2] * height) for k, v in j.items()}
    label = label or key
    root = link(bpy.data.objects.new(f'{label}_root', None))
    tr = dict(edges=TOP_EDGES, r=dict(pelvis=(.15 * build, .1), spine=(.14 * build, .1), chest=(.165 * build, .105), neckb=(.06, .055),
                                      lsh=(.06, .06), lel=(.047, .047), lwr=(.04, .04), rsh=(.06, .06), rel=(.047, .047), rwr=(.04, .04)))
    if top_rad: tr['r'].update(top_rad)
    tj = {k: j[k] for k in ['pelvis', 'spine', 'chest', 'neckb', 'lsh', 'lel', 'lwr', 'rsh', 'rel', 'rwr']}
    t = body(f'{label}_top', tj, tr, top); t.parent = root
    lj = {k: j[k] for k in ['pelvis', 'lhip', 'lkn', 'lan', 'rhip', 'rkn', 'ran']}
    lr = dict(edges=LEG_EDGES, r=dict(pelvis=(.145 * build, .1), lhip=(.085, .085), lkn=(.06, .06), lan=(.045, .045), rhip=(.085, .085), rkn=(.06, .06), ran=(.045, .045)))
    lg = body(f'{label}_legs', lj, lr, pants); lg.parent = root
    fj = {k: j[k] for k in ['lan', 'lto', 'ran', 'rto']}
    fo = body(f'{label}_feet', fj, dict(edges=FOOT_EDGES, r=dict(lan=(.042, .035), lto=(.04, .022), ran=(.042, .035), rto=(.04, .022))), feet); fo.parent = root
    sm = mat_basic(f'{label}_skin', skin, rough=.55, sss=.1)
    for side in 'lr':
        hj = {f'{side}wr': j[f'{side}wr'], f'{side}ha': j[f'{side}ha']}
        h = body(f'{label}_{side}hand', hj, dict(edges=[(f'{side}wr', f'{side}ha')], r={f'{side}wr': (.033, .02), f'{side}ha': (.04, .018)}), sm)
        h.parent = root
    hd = bust(key, open_eyes, name=label)
    nb = Vector(j['neckb'])
    hd.parent = root
    hd.location = nb + Vector((0, 0, -.035))
    hd.rotation_euler = Euler((math.radians(head_pitch), 0, math.radians(head_yaw)), 'XYZ')
    root.location = loc; root.rotation_euler = (0, 0, math.radians(yaw))
    return root

# ---------------------------------------------------------------- lights & camera
def spot(name, loc, target, energy, k=3200, size=45, blend=.35, radius=.05, color=None):
    l = bpy.data.lights.new(name, 'SPOT'); l.energy = energy; l.color = color or kelvin(k)
    l.spot_size = math.radians(size); l.spot_blend = blend; l.shadow_soft_size = radius
    o = link(bpy.data.objects.new(name, l)); o.location = loc
    d = Vector(target) - Vector(loc); o.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    return o

def area(name, loc, target, energy, k=5600, size=(.3, .3), color=None, spread=180):
    l = bpy.data.lights.new(name, 'AREA'); l.energy = energy; l.color = color or kelvin(k)
    l.shape = 'RECTANGLE'; l.size, l.size_y = size; l.spread = math.radians(spread)
    o = link(bpy.data.objects.new(name, l)); o.location = loc
    d = Vector(target) - Vector(loc); o.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    return o

def point(name, loc, energy, k=None, color=(1, 1, 1), radius=.01):
    l = bpy.data.lights.new(name, 'POINT'); l.energy = energy; l.color = kelvin(k) if k else color; l.shadow_soft_size = radius
    o = link(bpy.data.objects.new(name, l)); o.location = loc; return o

def sun(name, rot, energy, k=2600, angle=.6):
    l = bpy.data.lights.new(name, 'SUN'); l.energy = energy; l.color = kelvin(k); l.angle = math.radians(angle)
    o = link(bpy.data.objects.new(name, l)); o.rotation_euler = [math.radians(a) for a in rot]; return o

def camera(loc, target, lens=28, shift=(0, 0), ortho=None):
    c = bpy.data.cameras.new('cam'); c.lens = lens; c.shift_x, c.shift_y = shift
    c.sensor_width = 36
    if ortho: c.type = 'ORTHO'; c.ortho_scale = ortho
    o = link(bpy.data.objects.new('cam', c)); o.location = loc
    d = Vector(target) - Vector(loc); o.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = o
    return o

def render(path, samples=64, res=None, pct=100):
    s = bpy.context.scene
    s.cycles.samples = samples
    if res: s.render.resolution_x, s.render.resolution_y = res
    s.render.resolution_percentage = pct
    s.render.filepath = path
    bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------- real-world UVs
def uv_box(o, size=1.0, rot90=False, offset=None):
    """Planar UVs from world coordinates by dominant face normal; `size` = metres covered by one image tile."""
    import random as _r
    bpy.context.view_layer.update()
    me = o.data; mw = o.matrix_world; nm = mw.to_3x3()
    uvl = me.uv_layers.get('UVMap') or me.uv_layers.new(name='UVMap')
    off = offset if offset is not None else (_r.random(), _r.random())
    for poly in me.polygons:
        n = (nm @ poly.normal); a = max(range(3), key=lambda i: abs(n[i]))
        ax = [(1, 2), (0, 2), (0, 1)][a]
        for li in poly.loop_indices:
            w = mw @ me.vertices[me.loops[li].vertex_index].co
            u, v = w[ax[0]] / size, w[ax[1]] / size
            if rot90: u, v = v, u
            uvl.data[li].uv = (u + off[0], v + off[1])

def uv_cyl(o, length_per_tile=1.25, offset=None):
    """Cylinder whose local Z is its axis: u along the axis, v around (grain runs along the log)."""
    import random as _r
    me = o.data; uvl = me.uv_layers.get('UVMap') or me.uv_layers.new(name='UVMap')
    off = offset if offset is not None else (_r.random() * 3, _r.random())
    r = max(.001, max(abs(v.co.x) for v in me.vertices))
    for poly in me.polygons:
        cen = poly.center
        for li in poly.loop_indices:
            c = me.vertices[me.loops[li].vertex_index].co
            ang = math.atan2(c.y, c.x)
            if ang - math.atan2(cen.y, cen.x) > math.pi: ang -= math.tau
            if math.atan2(cen.y, cen.x) - ang > math.pi: ang += math.tau
            uvl.data[li].uv = (c.z / length_per_tile + off[0], ang * r / length_per_tile + off[1])

# ---------------------------------------------------------------- better bodies (lofted rings, low-poly, real-time friendly)
def _frame(t):
    t = Vector(t).normalized(); up = Vector((0, 0, 1)) if abs(t.z) < .95 else Vector((0, 1, 0))
    x = t.cross(up).normalized(); y = t.cross(x).normalized(); return x, y

def tube(name, pts, radii, mat, seg=12, sub=3, cap=True, flat=1.0):
    """Sweep a circle along a Catmull-Rom path through pts; radii per point (r or (rx,ry))."""
    P = [Vector(p) for p in pts]; R = [r if isinstance(r, tuple) else (r, r) for r in radii]
    path, rad = [], []
    for i in range(len(P) - 1):
        p0 = P[max(0, i - 1)]; p1 = P[i]; p2 = P[i + 1]; p3 = P[min(len(P) - 1, i + 2)]
        for k in range(sub):
            t = k / sub
            q = .5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)
            path.append(q); rad.append((R[i][0] + (R[i + 1][0] - R[i][0]) * t, R[i][1] + (R[i + 1][1] - R[i][1]) * t))
    path.append(P[-1]); rad.append(R[-1])
    verts, faces = [], []
    prevx = None
    for i, p in enumerate(path):
        t = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)])
        x, y = _frame(t)
        if prevx is not None and x.dot(prevx) < 0: x, y = -x, -y
        prevx = x
        for k in range(seg):
            a = k / seg * math.tau
            verts.append(tuple(p + x * math.cos(a) * rad[i][0] + y * math.sin(a) * rad[i][1]))
    n = len(path)
    for i in range(n - 1):
        for k in range(seg):
            faces.append((i * seg + k, i * seg + (k + 1) % seg, (i + 1) * seg + (k + 1) % seg, (i + 1) * seg + k))
    if cap:
        verts.append(tuple(path[0])); c0 = len(verts) - 1
        verts.append(tuple(path[-1])); c1 = len(verts) - 1
        for k in range(seg):
            faces.append((c0, (k + 1) % seg, k)); faces.append((c1, (n - 1) * seg + k, (n - 1) * seg + (k + 1) % seg))
    o = mesh_obj(name, verts, faces, smooth=True); o.data.materials.append(mat); return o

def torso(name, rings, mat, seg=20, sub=2):
    """rings: list of (z, half_w, half_d, y_off, x_off). Superellipse sections, lofted with smoothing."""
    # densify by linear interpolation then smooth
    R = []
    for i in range(len(rings) - 1):
        for k in range(sub):
            t = k / sub; a, b = rings[i], rings[i + 1]
            R.append(tuple(a[j] + (b[j] - a[j]) * t for j in range(5)))
    R.append(rings[-1])
    verts, faces = [], []
    for (z, hw, hd, yo, xo) in R:
        for k in range(seg):
            a = k / seg * math.tau; c, s_ = math.cos(a), math.sin(a)
            e = .9    # superellipse exponent
            x = xo + math.copysign(abs(s_) ** e, s_) * hw; y = yo - math.copysign(abs(c) ** e, c) * hd
            verts.append((x, y, z))
    n = len(R)
    for i in range(n - 1):
        for k in range(seg):
            faces.append((i * seg + k, i * seg + (k + 1) % seg, (i + 1) * seg + (k + 1) % seg, (i + 1) * seg + k))
    verts.append((R[0][4], R[0][3], R[0][0] - .01)); c0 = len(verts) - 1
    verts.append((R[-1][4], R[-1][3], R[-1][0] + .005)); c1 = len(verts) - 1
    for k in range(seg):
        faces.append((c0, (k + 1) % seg, k)); faces.append((c1, (n - 1) * seg + k, (n - 1) * seg + (k + 1) % seg))
    o = mesh_obj(name, verts, faces, smooth=True); o.data.materials.append(mat); return o

def figure(key, pose=None, top=None, pants=None, feet=None, skin=(0.8, .6, .5), sleeve='long', female=False,
           s=1.0, wide=1.0, loc=(0, 0, 0), yaw=0, head_yaw=0, head_pitch=0, head_roll=0, open_eyes=True, label=None, open_shirt=None):
    """Human, ~1.70 m at s=1. pose overrides joint positions (unscaled, metres at s=1)."""
    J = dict(lsh=(.162, .01, 1.36), lel=(.215, .04, 1.13), lwr=(.23, .0, .89), lha=(.235, -.01, .80),
             rsh=(-.162, .01, 1.36), rel=(-.215, .04, 1.13), rwr=(-.23, .0, .89), rha=(-.235, -.01, .80),
             lhip=(.088, 0, .88), lkn=(.095, -.015, .48), lan=(.095, .02, .07), lto=(.1, -.13, .025),
             rhip=(-.088, 0, .88), rkn=(-.095, -.015, .48), ran=(-.095, .02, .07), rto=(-.1, -.13, .025),
             neck=(0, .02, 1.47), lean=(0, 0, 0))
    if female: J.update(lsh=(.142, .012, 1.345), rsh=(-.142, .012, 1.345))
    J.update(pose or {})
    W_arm = .82 if female else 1.0
    sc = lambda p: Vector((p[0] * s * wide, p[1] * s * (1 + (wide - 1) * .6), p[2] * s))
    label = label or key
    root = link(bpy.data.objects.new(f'{label}_root', None))
    W, D = wide, 1 + (wide - 1) * .6
    lx, ly, lz = J['lean']
    def lean(z): t = max(0, (z - .9) / .6); return (lx * t, ly * t)
    if not female:
        rings = [(.835, .11, .085), (.88, .158, .102), (.96, .162, .098), (1.05, .145, .09), (1.16, .15, .1), (1.27, .162, .108),
                 (1.34, .172, .102), (1.39, .162, .092), (1.425, .128, .078), (1.45, .09, .066), (1.47, .056, .054)]
    else:
        rings = [(.835, .115, .085), (.88, .165, .102), (.96, .158, .098), (1.05, .128, .088), (1.16, .134, .1), (1.25, .142, .11),
                 (1.32, .15, .098), (1.37, .14, .088), (1.405, .112, .074), (1.435, .076, .06), (1.46, .05, .05)]
    def ringset(rs, grow=1.0):
        out = []
        for z, w, d in rs:
            ox, oy = lean(z); out.append((z * s, w * s * W * grow, d * s * D * grow, oy * s, ox * s))
        return out
    pel = ringset([r for r in rings if r[0] <= .96])
    pv = torso(f'{label}_pelvis', pel, pants); pv.parent = root
    shirt = ringset([(.93, rings[2][1], rings[2][2])] + [r for r in rings if r[0] > .96], 1.0)
    shirt[0] = (shirt[0][0], shirt[0][1] * 1.04, shirt[0][2] * 1.06, shirt[0][3], shirt[0][4])
    t = torso(f'{label}_torso', shirt, top); t.parent = root
    sm = mat_basic(f'{label}_skin', skin, rough=.55, sss=.1)
    for side in 'lr':
        sh, el, wr, ha = [sc(J[f'{side}{k}']) for k in ('sh', 'el', 'wr', 'ha')]
        ox, oy = lean(1.4); sh = sh + Vector((ox * s, oy * s, 0)); el = el + Vector((ox * s * .7, oy * s * .7, 0))
        ar = (.058 if sleeve != 'short' else .06) * s * W * W_arm
        bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=9, radius=ar * 1.0, location=sh)
        dl = bpy.context.active_object; dl.name = f'{label}_{side}deltoid'; dl.data.materials.append(top); dl.parent = root
        for p_ in dl.data.polygons: p_.use_smooth = True
        if sleeve == 'short':
            mid = sh.lerp(el, .55)
            a1 = tube(f'{label}_{side}sleeve', [sh, mid], [.06 * s * W, .055 * s * W], top, seg=12); a1.parent = root
            a2 = tube(f'{label}_{side}arm', [sh.lerp(el, .4), el, wr], [.043 * s * W, .04 * s * W, .03 * s], sm, seg=10); a2.parent = root
        else:
            a1 = tube(f'{label}_{side}arm', [sh, el, wr], [.058 * s * W * W_arm, .048 * s * W * W_arm, .038 * s * W_arm], top, seg=12); a1.parent = root
            a2 = tube(f'{label}_{side}wrist', [wr.lerp(el, .08), wr + (ha - wr) * .3], [.028 * s, .027 * s], sm, seg=8); a2.parent = root
        hd = (ha - wr); hn = hd.normalized()
        hand = tube(f'{label}_{side}hand', [wr + hd * .2, wr + hd * .8, wr + hd * 1.25], [(.03 * s, .016 * s), (.036 * s, .017 * s), (.028 * s, .013 * s)], sm, seg=8); hand.parent = root
        hip, kn, an, to = [sc(J[f'{side}{k}']) for k in ('hip', 'kn', 'an', 'to')]
        lg = tube(f'{label}_{side}leg', [hip + Vector((0, 0, .04 * s)), hip, kn, an + Vector((0, 0, .03 * s))],
                  [.09 * s * W, .085 * s * W, .058 * s * W, .048 * s], pants, seg=14); lg.parent = root
        ft = tube(f'{label}_{side}foot', [an + Vector((0, .03 * s, -.01 * s)), an.lerp(to, .55) + Vector((0, 0, -.02 * s)), to],
                  [(.04 * s, .035 * s), (.045 * s, .028 * s), (.038 * s, .018 * s)], feet, seg=10); ft.parent = root
    hd_ = bust(key, open_eyes, name=label)
    nb = sc(J['neck']); ox, oy = lean(1.47); nb = nb + Vector((ox * s, oy * s, 0))
    hd_.parent = root; hd_.location = nb + Vector((0, 0, -.03 * s)); hd_.scale = (s * .98,) * 3
    hd_.rotation_euler = Euler((math.radians(head_pitch), math.radians(head_roll), math.radians(head_yaw)), 'XYZ')
    root.location = loc; root.rotation_euler = (0, 0, math.radians(yaw))
    return root

def haze(bounds, density=.03, aniso=.35, color=(1, 1, 1)):
    """Film-set haze filling a box (min xyz, max xyz). Godot equivalent: volumetric fog volume."""
    (x0, y0, z0), (x1, y1, z1) = bounds
    m = bpy.data.materials.new('haze'); m.use_nodes = True; N = m.node_tree.nodes; L = m.node_tree.links
    N.remove(N['Principled BSDF']); v = N.new('ShaderNodeVolumePrincipled')
    v.inputs['Density'].default_value = density; v.inputs['Anisotropy'].default_value = aniso; v.inputs['Color'].default_value = (*color, 1)
    L.new(v.outputs[0], N['Material Output'].inputs['Volume'])
    o = prim('cube', 'haze', loc=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), scale=((x1 - x0) / 2, (y1 - y0) / 2, (z1 - z0) / 2), mat=m)
    o.visible_shadow = False
    bpy.context.scene.cycles.volume_bounces = 0
    return o

# ---------------------------------------------------------------- drawn heads (stylised portraits), glTF friendly
FACES_S = f'{P.ASSETS}/faces_style'
MASKS_S = json.load(open(f'{KF}/masks_style.json'))

NECK_W = dict(mio=.098, natsuki=.098, makoto=.096, kiryu=.112, yota=.112, taiga=.125)
def bust2(key, name=None, ext=0.0, flare=0.0):
    """Head lofted from the drawn portrait's silhouette, scaled so the eyes sit 63 mm apart.
    Two materials so a real-time engine can swap faces: 0 = portrait (front), 1 = side strip (hair/skin at the edge)."""
    from PIL import Image as _I
    name = name or key
    info = MASKS_S[key]; rows = info['rows']; px = info['px']
    W = H = 1254
    ex = (info['eyes'][0][0] + info['eyes'][1][0]) / 2; ey = (info['eyes'][0][1] + info['eyes'][1][1]) / 2
    fn = f'{FACES_S}/{key}_open.png'
    im = np.asarray(_I.open(fn).convert('RGB'), np.float32) / 255
    valid = [r for r in rows if r[1] >= 0]
    # the silhouette mask cannot tell neck from shoulders (the portraits are cropped tight), so below the jaw
    # the loft follows the run of skin around the centre line instead, down to where the collar opens
    import skinrows as _sk
    srows, _, d_eye = _sk.skin_rows(key)
    sk = {y: (l, r) for (y, l, r) in srows if r - l > 40}
    plate = sorted(sk[y][1] - sk[y][0] for y in sk if ey + 1.05 * d_eye <= y <= ey + 1.45 * d_eye)
    pw = plate[len(plate) // 2]
    silw = {r[0]: r[2] - r[1] for r in valid}
    y_s = next(y for y in sorted(sk) if y >= ey + .95 * d_eye and y in silw and silw[y] <= (sk[y][1] - sk[y][0]) * 1.15 + 12)
    y_end = next(y for y in sorted(sk) if y > ey + 1.2 * d_eye and sk[y][1] - sk[y][0] > pw * 1.08) - 12
    neck = [y_s]
    print('bust2', key, 'jaw->neck', y_s, 'collar', y_end, 'neck px', pw)
    sel = [[r[0], r[1] + 6, r[2] - 6] for r in valid if info['top'] + 8 <= r[0] < y_s]
    sel += [[y, sk[y][0], sk[y][1]] for y in sorted(sk) if y_s <= y <= y_end + 40 and (sk[y][1] - sk[y][0]) > pw * .8]
    arr = np.array(sel, float)
    kk = np.exp(-np.linspace(-2, 2, 11) ** 2); kk /= kk.sum()
    for c in (1, 2):
        pad = np.pad(arr[:, c], 5, mode='edge'); arr[:, c] = np.convolve(pad, kk, 'valid')
    use = [list(r) for r in arr if r[0] <= y_end][::2]
    # neck continued below the portrait's neck row, down inside the collar (replaces the body's own neck)
    if ext > 0:
        ly, lxl, lxr = use[-1]; lc = (lxl + lxr) / 2; lw = max(lxr - lxl, NECK_W.get(key, .105) / px)
        n_ext = 8
        for i in range(1, n_ext + 1):
            f = i / n_ext; ww = lw + flare / px * f * f
            use.append([ly + f * ext / px, lc - ww / 2, lc + ww / 2])
    # side strip texture: per row, the colour just inside the silhouette (both edges averaged)
    side = np.zeros((H, 4, 3), np.float32)
    rowcol = {}
    for (y, xl, xr) in use:
        if y > y_end: continue
        y = int(y); a = im[y, int(min(W - 1, xl + 26))]; b = im[y, int(max(0, xr - 26))]
        rowcol[y] = (a + b) / 2
    ys = sorted(rowcol)
    for y in range(H):
        yy = min(ys, key=lambda q: abs(q - y)); side[y, :] = rowcol[yy]
    from scipy import ndimage as _nd
    side = _nd.gaussian_filter(side, (18, 0, 0))[:, 0]          # colour just inside the silhouette, per row
    # Around the side and over the back the portrait has nothing to say, so the back is painted: hair down to
    # the nape (or as far as the hair hangs at the silhouette edge), neck skin below, with strands running down.
    d_e = info['eyes'][1][0] - info['eyes'][0][0]
    cxp = int(ex); tp = info['top']
    hair = np.median(im[tp + 30:tp + 90, cxp - 90:cxp + 90].reshape(-1, 3), 0)
    skin_n = np.median(im[int(y_end) - 30:int(y_end) - 10, cxp - 25:cxp + 25].reshape(-1, 3), 0)
    nape = ey + .72 * d_e
    SW = 128
    tex = np.zeros((H, SW, 3), np.float32)
    rng = np.random.default_rng(7)
    strands = _nd.gaussian_filter(rng.random((H // 6 + 1, SW)), (2.5, .8))
    strands = np.repeat(strands, 6, 0)[:H]; strands = (strands - strands.mean()) / (strands.std() + 1e-6)
    isHair = np.zeros(H)
    for y in range(H):
        e = side[y]
        hl = np.abs(e - hair).sum() < np.abs(e - skin_n).sum()
        isHair[y] = 1.0 if (y < nape or (hl and y < y_end)) else 0.0
    isHair = _nd.gaussian_filter(isHair, 10)
    for y in range(H):
        back = hair * isHair[y] + skin_n * (1 - isHair[y])
        u = np.linspace(0, 1, SW); m = np.clip(u / .55, 0, 1); m = m * m * (3 - 2 * m)
        col = side[y][None, :] * (1 - m[:, None]) + back[None, :] * m[:, None]
        col *= (1 + .16 * isHair[y] * strands[y][:, None])
        tex[y] = col
    tex[:tp] = tex[tp]
    sp = f'{FACES_S}/_side_{key}.png'
    _I.fromarray((np.clip(tex, 0, 1) * 255).astype(np.uint8)).save(sp)
    N = 40
    verts, faces = [], []
    for (y, xl, xr) in use:
        w = (xr - xl) * px; cx = ((xl + xr) / 2 - ex) * px
        z = (ey - y) * px
        nmin = NECK_W.get(key, .105) * min(1, max(0, (y - (neck[0] - 60)) / 60.0))
        if w < nmin:
            xl = (xl + xr) / 2 - nmin / px / 2; xr = (xl + nmin / px / 2) + nmin / px / 2; w = nmin
        tt = min(1, max(0, (y - (neck[0] - 170)) / 200.0)); tt = tt * tt * (3 - 2 * tt)
        depth = w * (1.12 - .22 * tt)
        back_off = w * (.1 - .08 * tt)
        for k in range(N):
            a = k / N * math.tau
            x = cx + math.sin(a) * w / 2
            yy = -math.cos(a) * depth / 2
            if math.cos(a) > 0: yy *= .84
            yy += back_off
            if math.cos(a) > .25:   # relief around eyes, nose, mouth, chin, measured from the eye line
                fx = x / px; fy = (y - ey) / ((info['eyes'][1][0] - info['eyes'][0][0]) / 210)
                g = lambda cx_, cy_, sx_, sy_: math.exp(-(((fx - cx_) / sx_) ** 2 + ((fy - cy_) / sy_) ** 2))
                rel = .017 * g(0, 110, 34, 80) + .005 * g(0, 225, 60, 25) + .007 * g(0, 320, 80, 40) - .006 * (g(-105, 0, 50, 30) + g(105, 0, 50, 30))
                yy -= rel * max(0, math.cos(a)) ** .5
            verts.append((x, yy, z))
    y0, xl0, xr0 = use[0]
    verts.append((((xl0 + xr0) / 2 - ex) * px, .012, (ey - (info['top'] + 4)) * px)); cap = len(verts) - 1
    for ri in range(len(use) - 1):
        for k in range(N):
            a = ri * N + k; b = ri * N + (k + 1) % N; c = (ri + 1) * N + (k + 1) % N; d = (ri + 1) * N + k
            faces.append((a, d, c, b))
    for k in range(N): faces.append((cap, k, (k + 1) % N))
    o = mesh_obj(f'{name}_head', verts, faces, smooth=True)
    me = o.data
    uvl = me.uv_layers.new(name='UVMap')
    nring = len(verts) - 1
    for poly in me.polygons:
        side_poly = poly.normal.y >= -.18
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index; v = me.vertices[vi].co
            vv = 1 - min(ey - v.z / px, y_end - 6) / H
            if side_poly and vi < nring:
                q = (1 - math.cos((vi % N) / N * math.tau)) / 2
                uvl.data[li].uv = (min(1, max(0, (q - .35) / .65)), vv)
            else:
                uvl.data[li].uv = ((v.x / px + ex) / W, vv)
    def mk(nm, path, rough):
        m = bpy.data.materials.new(nm); nt, Nn, L = _nodes(m); p = Nn['Principled BSDF']
        p.inputs['Roughness'].default_value = rough; p.inputs['Specular IOR Level'].default_value = .2
        t = Nn.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(path, check_existing=True); t.extension = 'EXTEND'
        L.new(t.outputs['Color'], p.inputs['Base Color']); return m
    me.materials.append(mk(f'{name}_face', fn, .6))
    me.materials.append(mk(f'{name}_side', sp, .7))
    for poly in me.polygons:
        poly.material_index = 0 if poly.normal.y < -.18 else 1
    o.data.transform(Matrix.Translation((0, 0, -(ey - y_end) * px)))
    o['neck_end_z'] = 0.0   # local z of the portrait's neck row; rows below are the extension
    return o


def face_skin(key):
    """Mean skin colour of the drawn face (cheeks), as linear RGB for Blender."""
    from PIL import Image as _I
    info = MASKS_S[key]; im = np.asarray(_I.open(f'{FACES_S}/{key}_open.png').convert('RGB'), np.float32) / 255
    (lx, ly), (rx, ry) = info['eyes']; sp = rx - lx
    pts = []
    for cx in (lx, rx):
        y0 = int(ly + sp * .45); x0 = int(cx)
        pts.append(im[y0 - 12:y0 + 12, x0 - 12:x0 + 12].reshape(-1, 3))
    c = np.median(np.concatenate(pts), 0)
    return tuple(float(((v + .055) / 1.055) ** 2.4 if v > .04045 else v / 12.92) for v in c)

# インタビューの部屋（客間）を layout.json から組み立てる。手作業のモデリングはしない。2026-11-15
import bpy, bmesh, json, math, random, sys, os
from mathutils import Vector, Matrix
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))   # blender/interview → リポジトリの根
LY = json.load(open(os.path.join(HERE, 'layout.json')))
R = lambda name: random.Random(f"7:{name}")

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

# ---------- materials ----------
def nodes(m):
    m.use_nodes = True; nt = m.node_tree; return nt, nt.nodes, nt.links
def principled(name, col, rough=0.6, spec=0.5):
    m = bpy.data.materials.new(name); nt, n, l = nodes(m)
    b = n['Principled BSDF']; b.inputs['Base Color'].default_value = (*col, 1); b.inputs['Roughness'].default_value = rough
    b.inputs['Specular IOR Level'].default_value = spec
    m['flat'] = col; return m
def textured(name, col_a, col_b, scale, rough=0.6, bump=0.15, kind='noise', detail=6.0, stretch=(1, 1, 1), rough_b=None, band_dir=None):
    m = bpy.data.materials.new(name); nt, n, l = nodes(m)
    b = n['Principled BSDF']; b.inputs['Roughness'].default_value = rough
    tc = n.new('ShaderNodeTexCoord'); mp = n.new('ShaderNodeMapping'); mp.inputs['Scale'].default_value = stretch
    l.new(tc.outputs['Object'], mp.inputs['Vector'])
    if kind == 'noise':
        t = n.new('ShaderNodeTexNoise'); t.inputs['Scale'].default_value = scale; t.inputs['Detail'].default_value = detail; t.inputs['Roughness'].default_value = 0.6
        fac = t.outputs['Fac']
    elif kind == 'wave':
        t = n.new('ShaderNodeTexWave'); t.inputs['Scale'].default_value = scale; t.inputs['Distortion'].default_value = 6; t.inputs['Detail'].default_value = detail
        t.wave_type = 'BANDS'; fac = t.outputs['Fac']
        if band_dir: t.bands_direction = band_dir
    elif kind == 'stripes':   # tatami: fine rows of rush
        t = n.new('ShaderNodeTexWave'); t.inputs['Scale'].default_value = scale; t.inputs['Distortion'].default_value = 0.4; t.inputs['Detail'].default_value = 1
        t.wave_type = 'BANDS'; t.bands_direction = 'X'; fac = t.outputs['Fac']
    l.new(mp.outputs['Vector'], t.inputs['Vector'])
    # broad mottling on top of the fine pattern
    t2 = n.new('ShaderNodeTexNoise'); t2.inputs['Scale'].default_value = 1.6; t2.inputs['Detail'].default_value = 3
    l.new(tc.outputs['Object'], t2.inputs['Vector'])
    mx = n.new('ShaderNodeMath'); mx.operation = 'MULTIPLY_ADD'; mx.inputs[1].default_value = 0.7
    l.new(fac, mx.inputs[0]); l.new(t2.outputs['Fac'], mx.inputs[2])
    cr = n.new('ShaderNodeMapRange'); cr.inputs['From Min'].default_value = 0.3; cr.inputs['From Max'].default_value = 1.2
    l.new(mx.outputs[0], cr.inputs['Value'])
    mix = n.new('ShaderNodeMix'); mix.data_type = 'RGBA'
    mix.inputs['A'].default_value = (*col_a, 1); mix.inputs['B'].default_value = (*col_b, 1)
    l.new(cr.outputs['Result'], mix.inputs['Factor']); l.new(mix.outputs['Result'], b.inputs['Base Color'])
    if rough_b is not None:
        rr = n.new('ShaderNodeMapRange'); rr.inputs['To Min'].default_value = rough; rr.inputs['To Max'].default_value = rough_b
        l.new(t2.outputs['Fac'], rr.inputs['Value']); l.new(rr.outputs['Result'], b.inputs['Roughness'])
    if bump:
        bp = n.new('ShaderNodeBump'); bp.inputs['Strength'].default_value = bump; bp.inputs['Distance'].default_value = 0.002
        l.new(fac, bp.inputs['Height']); l.new(bp.outputs['Normal'], b.inputs['Normal'])
    m['flat'] = tuple((a + c) / 2 for a, c in zip(col_a, col_b)); return m
def table_grain(m):
    """手のお手本の座卓：欅の拭き漆。長手に沿って波打つ太い木目（濃い筋と明るい筋）を、細かい導管の筋の上に重ねる"""
    nt = m.node_tree; n = nt.nodes; l = nt.links; b = n['Principled BSDF']
    tc = n.new('ShaderNodeTexCoord'); mp = n.new('ShaderNodeMapping'); mp.inputs['Scale'].default_value = (0.25, 1.0, 1.0)
    l.new(tc.outputs['Object'], mp.inputs['Vector'])
    w = n.new('ShaderNodeTexWave'); w.wave_type = 'BANDS'; w.bands_direction = 'Y'
    w.inputs['Scale'].default_value = 9.0; w.inputs['Distortion'].default_value = 16.0; w.inputs['Detail'].default_value = 4.0
    w.inputs['Detail Scale'].default_value = 1.2; w.inputs['Detail Roughness'].default_value = 0.55
    l.new(mp.outputs['Vector'], w.inputs['Vector'])
    p = n.new('ShaderNodeMath'); p.operation = 'POWER'; p.inputs[1].default_value = 1.6; l.new(w.outputs['Fac'], p.inputs[0])
    mp2 = n.new('ShaderNodeMapping'); mp2.inputs['Scale'].default_value = (0.03, 1.0, 1.0); l.new(tc.outputs['Object'], mp2.inputs['Vector'])
    f = n.new('ShaderNodeTexNoise'); f.inputs['Scale'].default_value = 140; f.inputs['Detail'].default_value = 4; l.new(mp2.outputs['Vector'], f.inputs['Vector'])
    mx = n.new('ShaderNodeMath'); mx.operation = 'MULTIPLY_ADD'; mx.inputs[1].default_value = 0.35
    l.new(f.outputs['Fac'], mx.inputs[0]); l.new(p.outputs[0], mx.inputs[2])
    cr = n.new('ShaderNodeMapRange'); cr.inputs['From Min'].default_value = 0.15; cr.inputs['From Max'].default_value = 1.05; l.new(mx.outputs[0], cr.inputs['Value'])
    ramp = n.new('ShaderNodeValToRGB'); e = ramp.color_ramp.elements
    e[0].position = 0.0; e[0].color = (0.028, 0.013, 0.008, 1); e[1].position = 1.0; e[1].color = (0.082, 0.040, 0.023, 1)
    mid = e.new(0.55); mid.color = (0.050, 0.024, 0.014, 1)
    l.new(cr.outputs['Result'], ramp.inputs['Fac']); l.new(ramp.outputs['Color'], b.inputs['Base Color'])
    bp = n.new('ShaderNodeBump'); bp.inputs['Strength'].default_value = 0.03; bp.inputs['Distance'].default_value = 0.001
    l.new(f.outputs['Fac'], bp.inputs['Height']); l.new(bp.outputs['Normal'], b.inputs['Normal'])
    return m
def shoji_paper():
    m = bpy.data.materials.new('shoji_paper'); nt, n, l = nodes(m); n.remove(n['Principled BSDF'])
    tr = n.new('ShaderNodeBsdfTranslucent'); tr.inputs['Color'].default_value = (0.96, 0.95, 0.91, 1)
    df = n.new('ShaderNodeBsdfDiffuse'); df.inputs['Color'].default_value = (0.86, 0.84, 0.79, 1)
    mx = n.new('ShaderNodeMixShader'); mx.inputs['Fac'].default_value = 0.15
    l.new(tr.outputs[0], mx.inputs[1]); l.new(df.outputs[0], mx.inputs[2]); l.new(mx.outputs[0], n['Material Output'].inputs['Surface'])
    m['flat'] = (0.96, 0.95, 0.92); return m

def sometsuke():
    """blue-and-white tea cup: white glaze with blotchy cobalt flowers"""
    m = bpy.data.materials.new('porcelain'); nt, n, l = nodes(m); b = n['Principled BSDF']
    b.inputs['Roughness'].default_value = 0.08
    tc = n.new('ShaderNodeTexCoord'); t = n.new('ShaderNodeTexVoronoi'); t.inputs['Scale'].default_value = 55
    l.new(tc.outputs['Object'], t.inputs['Vector'])
    t2 = n.new('ShaderNodeTexNoise'); t2.inputs['Scale'].default_value = 40; l.new(tc.outputs['Object'], t2.inputs['Vector'])
    mx = n.new('ShaderNodeMath'); mx.operation = 'MULTIPLY_ADD'; mx.inputs[1].default_value = 0.25
    l.new(t2.outputs['Fac'], mx.inputs[0]); l.new(t.outputs['Distance'], mx.inputs[2])
    cr = n.new('ShaderNodeMapRange'); cr.inputs['From Min'].default_value = 0.30; cr.inputs['From Max'].default_value = 0.36
    l.new(mx.outputs[0], cr.inputs['Value'])
    mix = n.new('ShaderNodeMix'); mix.data_type = 'RGBA'
    mix.inputs['A'].default_value = (0.05, 0.09, 0.30, 1); mix.inputs['B'].default_value = (0.80, 0.80, 0.76, 1)
    l.new(cr.outputs['Result'], mix.inputs['Factor']); l.new(mix.outputs['Result'], b.inputs['Base Color'])
    m['flat'] = (0.70, 0.72, 0.74); return m

def build_materials():
    M = {}
    M['plaster'] = textured('plaster', (0.26, 0.23, 0.18), (0.40, 0.36, 0.29), 14, rough=0.95, bump=0.25, detail=10)
    M['plaster_toko'] = textured('plaster_toko', (0.36, 0.33, 0.27), (0.52, 0.48, 0.40), 12, rough=0.95, bump=0.25, detail=10)
    M['wood'] = textured('wood', (0.035, 0.020, 0.012), (0.10, 0.060, 0.034), 3.0, rough=0.38, bump=0.05, kind='wave', stretch=(1, 1, 18))
    M['wood_table'] = textured('wood_table', (0.030, 0.016, 0.009), (0.085, 0.048, 0.026), 30, rough=0.10, bump=0.01, kind='noise', detail=10.0, stretch=(0.04, 1, 1), rough_b=0.30)   # 細い木目（長手に沿う）
    _b = M['wood_table'].node_tree.nodes['Principled BSDF']; _b.inputs['Coat Weight'].default_value = 0.30; _b.inputs['Coat Roughness'].default_value = 0.06   # 塗りの艶：障子を映す
    table_grain(M['wood_table'])
    M['wood_table']['flat'] = (0.075, 0.032, 0.016)   # 測るときに柱と分けるため少しずらす
    M['wood_post'] = textured('wood_post', (0.025, 0.015, 0.010), (0.11, 0.065, 0.035), 6.0, rough=0.3, bump=0.3, kind='wave', stretch=(1, 1, 3))
    M['wood_toko_floor'] = textured('wood_toko_floor', (0.025, 0.014, 0.008), (0.07, 0.04, 0.022), 2.0, rough=0.10, bump=0.02, kind='wave', stretch=(1, 12, 1))
    M['kumiko'] = principled('kumiko', (0.30, 0.20, 0.11), 0.6)
    M['shoji'] = shoji_paper()
    M['tatami'] = textured('tatami', (0.15, 0.12, 0.07), (0.30, 0.25, 0.15), 260, rough=0.75, bump=0.2, kind='stripes')
    M['tatami_v'] = textured('tatami_v', (0.15, 0.12, 0.07), (0.30, 0.25, 0.15), 260, rough=0.75, bump=0.2, kind='stripes', stretch=(0, 1, 0))
    M['heri'] = principled('heri', (0.04, 0.045, 0.04), 0.7)
    M['ceiling'] = textured('ceiling', (0.10, 0.065, 0.04), (0.20, 0.13, 0.08), 3.0, rough=0.7, bump=0.05, kind='wave', stretch=(16, 1, 1))
    M['fusuma'] = textured('fusuma', (0.15, 0.14, 0.11), (0.21, 0.19, 0.155), 30, rough=0.9, bump=0.05)
    M['zabuton'] = textured('zabuton', (0.02, 0.03, 0.08), (0.05, 0.07, 0.16), 40, rough=0.9, bump=0.1)
    M['scroll'] = textured('scroll', (0.66, 0.62, 0.52), (0.16, 0.16, 0.15), 3.0, rough=0.9, bump=0.0, detail=8, stretch=(1, 1, 0.6))   # 墨の山水：にじんだ濃淡だけ
    mi = bpy.data.materials.new('scroll_img'); nt, n, l = nodes(mi); b = n['Principled BSDF']; b.inputs['Roughness'].default_value = 0.9
    it = n.new('ShaderNodeTexImage'); it.image = bpy.data.images.load(os.path.join(HERE, 'scroll.jpg')); l.new(it.outputs['Color'], b.inputs['Base Color'])
    mi['flat'] = (0.55, 0.53, 0.48); M['scroll_img'] = mi
    M['scroll_mount'] = principled('scroll_mount', (0.30, 0.28, 0.22), 0.8)
    M['sumi'] = principled('sumi', (0.06, 0.06, 0.06), 0.9)
    M['porcelain'] = sometsuke()
    M['tea'] = principled('tea', (0.12, 0.14, 0.02), 0.02)
    M['camellia'] = principled('camellia', (0.55, 0.03, 0.03), 0.4)
    M['leaf'] = principled('leaf', (0.02, 0.06, 0.02), 0.3)
    M['stamen'] = principled('stamen', (0.75, 0.55, 0.08), 0.6)
    M['tape'] = principled('tape', (0.015, 0.015, 0.017), 0.35)
    M['label'] = principled('label', (0.80, 0.78, 0.70), 0.8)
    M['notebook'] = textured('notebook', (0.36, 0.38, 0.40), (0.46, 0.48, 0.50), 60, rough=0.85, bump=0.05)
    M['paper_edge'] = principled('paper_edge', (0.78, 0.76, 0.70), 0.9)
    M['recorder'] = principled('recorder', (0.03, 0.03, 0.035), 0.35)
    M['display'] = principled('display', (0.20, 0.22, 0.18), 0.2)
    M['display_text'] = principled('display_text', (0.01, 0.012, 0.01), 0.5)
    M['outside'] = principled('outside', (0.25, 0.22, 0.18), 0.8)
    M['branch'] = principled('branch', (0.02, 0.02, 0.02), 0.8)
    # people (stand-ins until Tripo)
    M['jacket'] = principled('jacket', (0.025, 0.035, 0.08), 0.85)
    M['shirt'] = principled('shirt', (0.70, 0.70, 0.68), 0.8)
    M['skin'] = principled('skin', (0.50, 0.35, 0.27), 0.5)
    M['hair'] = principled('hair', (0.02, 0.02, 0.02), 0.5)
    M['sweater'] = principled('sweater', (0.32, 0.29, 0.26), 0.9)
    M['skirt'] = principled('skirt', (0.06, 0.07, 0.09), 0.8)
    return M

# ---------- geometry helpers ----------
def box(name, x, y, z, m, bevel=0.0, coll=None):
    """x, y, z are (min, max) ranges"""
    sx, sy, sz = x[1] - x[0], y[1] - y[0], z[1] - z[0]
    bpy.ops.mesh.primitive_cube_add(size=1, location=((x[0] + x[1]) / 2, (y[0] + y[1]) / 2, (z[0] + z[1]) / 2))
    o = bpy.context.object; o.name = name; o.scale = (sx, sy, sz); bpy.ops.object.transform_apply(scale=True)
    if bevel:
        md = o.modifiers.new('bv', 'BEVEL'); md.width = bevel; md.segments = 3; md.limit_method = 'ANGLE'
    o.data.materials.append(m); tag(o, coll); return o
def cyl(name, r, z0, z1, xy, m, verts=48, coll=None, r1=None):
    bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=r if r1 is None else r1, depth=z1 - z0, location=(xy[0], xy[1], (z0 + z1) / 2), vertices=verts)
    o = bpy.context.object; o.name = name; o.data.materials.append(m); bpy.ops.object.shade_smooth(); tag(o, coll); return o
def ball(name, r, loc, m, scale=(1, 1, 1), coll=None):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=32, ring_count=16)
    o = bpy.context.object; o.name = name; o.scale = scale; o.data.materials.append(m); bpy.ops.object.shade_smooth(); tag(o, coll); return o
def capsule(name, a, b, r, m, coll=None):
    a, b = Vector(a), Vector(b); d = b - a
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=d.length, location=(a + b) / 2, vertices=24)
    o = bpy.context.object; o.name = name; o.rotation_mode = 'QUATERNION'; o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    o.data.materials.append(m); bpy.ops.object.shade_smooth(); tag(o, coll)
    for p in (a, b): ball(name + '_j', r, p, m, coll=coll)
    return o
GROUPS = {}
def tag(o, coll):
    if coll: GROUPS.setdefault(coll, []).append(o.name)
def lathe(name, profile, xy, m, coll=None, segs=48):
    """profile: list of (r, z). a turned object (cups, vase)"""
    bm = bmesh.new(); rings = []
    for i in range(segs):
        a = 2 * math.pi * i / segs; rings.append([bm.verts.new((xy[0] + r * math.cos(a), xy[1] + r * math.sin(a), z)) for r, z in profile])
    for i in range(segs):
        A, B = rings[i], rings[(i + 1) % segs]
        for j in range(len(profile) - 1): bm.faces.new((A[j], B[j], B[j + 1], A[j + 1]))
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(o)
    for p in me.polygons: p.use_smooth = True
    o.data.materials.append(m); tag(o, coll); return o

# ---------- the room ----------
def build_room(M):
    (X0, X1), (Y0, Y1), H = LY['room']['x'], LY['room']['y'], LY['room']['h']
    S = LY['shoji']; T = LY['tokonoma']; KAMOI = S['h']
    # tatami: 8 mats, top and bottom rows lie east-west, the middle band north-south
    k = 0.91
    mats = [((X0, 0), (Y1 - k, Y1), 'tatami'), ((0, X1), (Y1 - k, Y1), 'tatami'), ((X0, 0), (Y0, Y0 + k), 'tatami'), ((0, X1), (Y0, Y0 + k), 'tatami')]
    for i in range(4): mats.append(((X0 + i * k, X0 + (i + 1) * k), (Y0 + k, Y1 - k), 'tatami_v'))
    for i, (x, y, mn) in enumerate(mats):
        r = R(f'mat{i}')
        o = box(f'tatami{i}', x, y, (-0.06, 0.0 + r.uniform(-0.002, 0.002)), M[mn], bevel=0.004)
        for e, (ex, ey) in enumerate([((x[0], x[1]), (y[0], y[0] + 0.03)), ((x[0], x[1]), (y[1] - 0.03, y[1]))] if mn == 'tatami' else [((x[0], x[0] + 0.03), (y[0], y[1])), ((x[1] - 0.03, x[1]), (y[0], y[1]))]):
            box(f'heri{i}_{e}', ex, ey, (-0.005, 0.0015), M['heri'])
    # north wall: plaster either side of the shoji, kamoi, transom wall, ceiling
    box('wallN_l', (X0, S['x'][0] - 0.05), (Y1, Y1 + 0.08), (0, H), M['plaster'])
    box('wallN_r', (S['x'][1] + 0.05, X1), (Y1, Y1 + 0.08), (0, H), M['plaster'])
    box('kokabeN', (S['x'][0] - 0.05, S['x'][1] + 0.05), (Y1, Y1 + 0.08), (KAMOI + 0.05, H), M['plaster'])
    box('kamoiN', (X0, X1), (Y1 - 0.03, Y1 + 0.08), (KAMOI, KAMOI + 0.06), M['wood'])   # 壁の厚みいっぱい：障子の上から日が漏れて澪の胸に筋が出ていた
    box('nageshiN', (X0, X1), (Y1 - 0.06, Y1 - 0.0), (KAMOI + 0.18, KAMOI + 0.27), M['wood'])
    box('shikiiN', (S['x'][0] - 0.05, S['x'][1] + 0.05), (Y1 - 0.03, Y1 + 0.08), (-0.005, 0.02), M['wood'])
    for sx in (S['x'][0] - 0.05, S['x'][1] + 0.05):
        box('hashiraN', (sx - 0.06, sx + 0.06), (Y1 - 0.04, Y1 + 0.08), (0, H), M['wood'])
    # shoji: two panels, slightly offset in depth like real sliding doors
    pw = (S['x'][1] - S['x'][0]) / S['panels']
    for p in range(S['panels']):
        x0 = S['x'][0] + p * pw; yy = Y1 + (0.035 if p == 0 else 0.0)
        box(f'shoji_paper{p}', (x0 + 0.03, x0 + pw - 0.03), (yy + 0.012, yy + 0.014), (0.11, KAMOI - 0.03), M['shoji'], coll='shoji')
        box(f'shoji_frame_l{p}', (x0, x0 + 0.03), (yy, yy + 0.03), (0.02, KAMOI), M['kumiko'])
        box(f'shoji_frame_r{p}', (x0 + pw - 0.03, x0 + pw), (yy, yy + 0.03), (0.02, KAMOI), M['kumiko'])
        box(f'shoji_frame_t{p}', (x0, x0 + pw), (yy, yy + 0.03), (KAMOI - 0.03, KAMOI), M['kumiko'])
        box(f'shoji_koshi{p}', (x0, x0 + pw), (yy, yy + 0.03), (0.02, 0.11), M['kumiko'])
        for c in range(1, S['cols']):
            xc = x0 + 0.03 + c * (pw - 0.06) / S['cols']
            box(f'kumiko_v{p}_{c}', (xc - 0.006, xc + 0.006), (yy + 0.004, yy + 0.012), (0.11, KAMOI - 0.03), M['kumiko'])
        for rr in range(1, S['rows']):
            zr = 0.11 + rr * (KAMOI - 0.14) / S['rows']
            box(f'kumiko_h{p}_{rr}', (x0 + 0.03, x0 + pw - 0.03), (yy + 0.004, yy + 0.012), (zr - 0.006, zr + 0.006), M['kumiko'])
        # 引き手は付けない（ユーザー 2026-11-15「黒い線トル」）
    # outside: engawa floor, the eave and a garden wall to catch the sky
    box('engawa', (X0 - 1, X1 + 1), (Y1 + 0.08, Y1 + 1.0), (-0.10, -0.06), M['outside'])
    box('eave', (X0 - 1, X1 + 1), (Y1 + 0.08, Y1 + LY['outside']['eave_depth'] + 0.1), (H + 0.05, H + 0.1), M['outside'])
    # west wall: tokonoma (alcove) and tokowaki with a low cabinet
    Tx0 = X0 - T['depth']
    box('toko_back', (Tx0 - 0.08, Tx0), (T['y'][0], T['y'][1]), (0, H), M['plaster_toko'])
    box('toko_side', (Tx0, X0), (Y1, Y1 + 0.08), (0, H), M['plaster_toko'])
    box('toko_floor', (Tx0, X0), (T['y'][0], T['y'][1]), (0, T['floor_h']), M['wood_toko_floor'])
    box('toko_kamachi', (X0 - 0.06, X0 + 0.01), (T['y'][0], T['y'][1]), (0, T['floor_h'] + 0.005), M['wood'])
    box('toko_otoshi', (X0 - 0.10, X0 + 0.01), (T['y'][0], T['y'][1]), (T['otoshi_h'], H), M['plaster_toko'])
    box('toko_otoshi_bar', (X0 - 0.06, X0 + 0.01), (T['y'][0], T['y'][1]), (T['otoshi_h'] - 0.05, T['otoshi_h']), M['wood'])
    box('toko_ceiling', (Tx0, X0), (T['y'][0], T['y'][1]), (H - 0.02, H), M['ceiling'])
    # the toko-bashira: a natural log, slightly irregular
    post = cyl('toko_bashira', 0.105, 0, H, (X0 - 0.01, T['post_y']), M['wood_post'], verts=40, r1=0.092)
    dsp = post.modifiers.new('d', 'DISPLACE'); tx = bpy.data.textures.new('bark', 'CLOUDS'); tx.noise_scale = 0.04; dsp.texture = tx; dsp.strength = 0.006
    box('wakiback', (X0 - 0.40, X0 - 0.32), (Y0, T['y'][0] - 0.07), (0, H), M['plaster'])
    # 床の間と床脇のあいだの壁（柱の奥が抜けて見えないように）
    box('toko_waki_wall', (Tx0 - 0.08, X0 - 0.06), (T['y'][0] - 0.07, T['y'][0]), (0, H), M['plaster_toko'])
    # 違い棚と天袋
    WY0, WY1 = Y0, T['y'][0] - 0.07; wm = (WY0 + WY1) / 2
    box('chigai_a', (X0 - 0.36, X0 - 0.02), (WY0, wm + 0.08), (1.05, 1.075), M['wood'], bevel=0.003)
    box('chigai_b', (X0 - 0.36, X0 - 0.02), (wm - 0.08, WY1), (1.24, 1.265), M['wood'], bevel=0.003)
    box('chigai_post', (X0 - 0.36, X0 - 0.06), (wm - 0.09, wm - 0.07), (1.075, 1.24), M['wood'])
    box('tenbukuro', (X0 - 0.36, X0), (WY0, WY1), (1.48, KAMOI), M['wood'], bevel=0.003)
    for i in range(2):
        yy = WY0 + 0.02 + i * (WY1 - WY0) / 2
        box(f'tenbukuro_door{i}', (X0 - 0.002, X0 + 0.004), (yy, yy + (WY1 - WY0) / 2 - 0.04), (1.50, KAMOI - 0.02), M['fusuma'])
    box('waki_cab', (X0 - 0.32, X0), (Y0, T['y'][0] - 0.07), (0, LY['tokowaki']['cabinet_h']), M['wood'], bevel=0.004)
    for i, yy in enumerate([Y0 + 0.02, (Y0 + T['y'][0]) / 2 - 0.03]):
        box(f'waki_door{i}', (X0 - 0.002, X0 + 0.004), (yy, yy + (T['y'][0] - Y0) / 2 - 0.06), (0.04, LY['tokowaki']['cabinet_h'] - 0.04), M['fusuma'])
    box('waki_top', (X0 - 0.34, X0 + 0.01), (Y0, T['y'][0] - 0.07), (LY['tokowaki']['cabinet_h'], LY['tokowaki']['cabinet_h'] + 0.03), M['wood'])
    box('wallW_kokabe', (X0 - 0.40, X0 - 0.30), (Y0, T['y'][0]), (KAMOI + 0.05, H), M['plaster'])
    box('kamoiW', (X0 - 0.05, X0 + 0.01), (Y0, T['y'][0]), (KAMOI, KAMOI + 0.06), M['wood'])
    # the scroll and the camellia
    ty = (T['y'][0] + T['y'][1]) / 2
    box('scroll_mount', (Tx0 + 0.005, Tx0 + 0.012), (ty - 0.24, ty + 0.24), (0.72, 1.86), M['scroll_mount'], coll='toko')
    # 本紙：ユーザーの山水の画（/mnt/project-files/インタビュー/素材/掛け軸_山水.jpg）を板に貼る
    box('scroll', (Tx0 + 0.012, Tx0 + 0.016), (ty - 0.165, ty + 0.165), (0.84, 1.72), M['scroll'], coll='toko')
    bpy.ops.mesh.primitive_plane_add(size=1); pl = bpy.context.object; pl.name = 'scroll_img'
    pl.scale = (0.307, 0.84, 1); pl.rotation_euler = (math.pi / 2, 0, math.pi / 2); pl.location = (Tx0 + 0.0165, ty, 1.28)
    pl.data.materials.append(M['scroll_img']); tag(pl, 'toko')
    cyl('jiku', 0.012, 0.70, 0.72, (Tx0 + 0.02, ty), M['wood'], coll='toko')
    o = bpy.data.objects['jiku']; o.rotation_euler = (math.pi / 2, 0, 0); o.scale = (1, 1, 28)
    vy = ty - 0.35
    box('vase_stand', (Tx0 + 0.18, Tx0 + 0.36), (vy - 0.09, vy + 0.09), (T['floor_h'], T['floor_h'] + 0.015), M['wood'], coll='toko')
    lathe('vase', [(0.0, 0), (0.045, 0.002), (0.05, 0.06), (0.042, 0.13), (0.018, 0.19), (0.014, 0.23), (0.018, 0.25), (0.0, 0.25)],
          (Tx0 + 0.27, vy), M['porcelain'], coll='toko')
    bpy.data.objects['vase'].location.z = T['floor_h'] + 0.015
    base = Vector((Tx0 + 0.27, vy, T['floor_h'] + 0.26))
    # 椿の枝：口から斜めに立ち上がり、途中で一本分かれる。葉は枝につけて向きをそろえる
    P = [base + Vector(v) for v in [(0, 0, -0.02), (0.012, 0.03, 0.08), (0.018, 0.075, 0.17), (0.012, 0.10, 0.25)]]
    for i in range(3): capsule(f'branch{i}', P[i], P[i + 1], 0.0045 - i * 0.0008, M['branch'], coll='toko')
    Q = [P[1], P[1] + Vector((0.01, -0.06, 0.07)), P[1] + Vector((0.015, -0.085, 0.12))]
    for i in range(2): capsule(f'twig{i}', Q[i], Q[i + 1], 0.003, M['branch'], coll='toko')
    ball('camellia', 0.034, P[3] + Vector((0, 0.01, 0.018)), M['camellia'], (1, 1, 0.75), coll='toko')
    ball('camellia_c', 0.012, P[3] + Vector((-0.012, 0.012, 0.03)), M['stamen'], coll='toko')
    ball('bud', 0.014, Q[2] + Vector((0, 0, 0.012)), M['camellia'], (0.9, 0.9, 1.3), coll='toko')
    lv = [(P[1], 40, 30), (P[2], -50, 20), (P[2] + (P[3] - P[2]) * 0.5, 120, 25), (P[3], -20, 35), (Q[1], 160, 30), (Q[2], 70, 25), (P[1] + (P[2] - P[1]) * 0.5, 200, 20)]
    for i, (p, yaw, pitch) in enumerate(lv):
        dr = Vector((math.cos(math.radians(yaw)), math.sin(math.radians(yaw)), 0))
        o = ball(f'cleaf{i}', 0.045, p + dr * 0.04, M['leaf'], (1.0, 0.48, 0.09), coll='toko')
        o.rotation_euler = (0, -math.radians(pitch), math.radians(yaw))
    # east wall: fusuma, one panel left a little open (cut E looks through it)
    F = LY['fusuma']; fw = (Y1 - Y0) / F['panels']
    for i in range(F['panels']):
        y0 = Y0 + i * fw; off = F['gap'] if i == F['gap_panel'] else 0.0
        xx = X1 + (0.03 if i % 2 else 0.0)
        box(f'fusuma{i}', (xx, xx + 0.02), (y0 + off, y0 + fw + off), (0.02, KAMOI), M['fusuma'])
        box(f'fusuma_fr{i}', (xx - 0.003, xx + 0.023), (y0 + off, y0 + off + 0.02), (0.02, KAMOI), M['wood'])
    box('kamoiE', (X1 - 0.01, X1 + 0.06), (Y0, Y1), (KAMOI, KAMOI + 0.06), M['wood'])
    box('kokabeE', (X1, X1 + 0.08), (Y0, Y1), (KAMOI + 0.06, H), M['plaster'])
    # the next room behind the fusuma: dark, so the gap reads as a slit
    box('nextroom_floor', (X1 + 0.08, X1 + 3.5), (Y0, Y1), (-0.06, 0.0), M['tatami'])
    box('nextroom_wall', (X1 + 3.5, X1 + 3.6), (Y0, Y1), (0, H), M['fusuma'])
    box('nextroom_ceil', (X1 + 0.08, X1 + 3.6), (Y0, Y1), (H, H + 0.02), M['ceiling'])
    box('nextroom_n', (X1 + 0.08, X1 + 3.6), (Y1, Y1 + 0.05), (0, H), M['plaster'])
    box('nextroom_s', (X1 + 0.08, X1 + 3.6), (Y0 - 0.05, Y0), (0, H), M['plaster'])
    # south wall
    box('wallS', (X0, X1), (Y0 - 0.08, Y0), (0, H), M['plaster'])
    box('kamoiS', (X0, X1), (Y0, Y0 + 0.04), (KAMOI, KAMOI + 0.06), M['wood'])
    box('nageshiS', (X0, X1), (Y0, Y0 + 0.06), (KAMOI + 0.18, KAMOI + 0.27), M['wood'])
    box('ceiling', (X0 - 0.4, X1 + 0.1), (Y0 - 0.1, Y1 + 0.1), (H, H + 0.03), M['ceiling'])
    for i in range(9):
        x = X0 + (i + 0.5) * (X1 - X0) / 9
        box(f'saobuchi{i}', (x - 0.015, x + 0.015), (Y0, Y1), (H - 0.03, H), M['wood'])

def build_table(M):
    T = LY['table']; cx, cy = T['c']; w, d, h, t = T['w'], T['d'], T['h'], T['top_t']
    box('table_top', (cx - w / 2, cx + w / 2), (cy - d / 2, cy + d / 2), (h - t, h), M['wood_table'], bevel=0.008)
    box('table_apron_n', (cx - w / 2 + 0.05, cx + w / 2 - 0.05), (cy + d / 2 - 0.08, cy + d / 2 - 0.055), (h - t - 0.07, h - t), M['wood_table'])
    box('table_apron_s', (cx - w / 2 + 0.05, cx + w / 2 - 0.05), (cy - d / 2 + 0.055, cy - d / 2 + 0.08), (h - t - 0.07, h - t), M['wood_table'])
    for sx in (-1, 1): box('table_apron_side', (cx + sx * (w / 2 - 0.08) - 0.0125, cx + sx * (w / 2 - 0.08) + 0.0125), (cy - d / 2 + 0.06, cy + d / 2 - 0.06), (h - t - 0.07, h - t), M['wood_table'])
    for sx in (-1, 1):
        for sy in (-1, 1):
            x = cx + sx * (w / 2 - 0.08); y = cy + sy * (d / 2 - 0.08)
            box('table_leg', (x - 0.045, x + 0.045), (y - 0.045, y + 0.045), (0.035, h - t), M['wood_table'], bevel=0.008)
            lathe('table_foot', [(0.0, 0.0), (0.050, 0.0), (0.060, 0.018), (0.050, 0.040), (0.0, 0.040)], (x, y), M['wood_table'])
def build_props(M):
    T = LY['table']; top = T['h']; P = LY['props']
    for i, z in enumerate(LY['zabuton']):
        cx, cy = z['c']
        o = box(f"zabuton_{z['who']}", (cx - 0.28, cx + 0.28), (cy - 0.30, cy + 0.30), (0.0, 0.08), M['zabuton'], bevel=0.035)
        o.modifiers.new('s', 'SUBSURF').levels = 2
    def rot_box(name, c, size, z0, ang, m, coll='props'):
        o = box(name, (-size[0] / 2, size[0] / 2), (-size[1] / 2, size[1] / 2), (0, size[2]), m, bevel=0.002, coll=coll)
        o.location = (c[0], c[1], z0); o.rotation_euler = (0, 0, math.radians(ang)); return o
    x, y, a = P['tape']
    # MiniDV のテープ（66×48×12mm、ユーザー 2026-11-15「本編のカメラは小さいから mini dv サイズに」）
    rot_box('tape', (x, y), (0.066, 0.048, 0.012), top, a, M['tape'])
    lab = rot_box('tape_label', (x, y), (0.048, 0.026, 0.0008), top + 0.012, a, M['label'])
    LT_ = os.path.join(HERE, 'tex', 'tape_label.png')
    if os.path.exists(LT_):   # 夏希の字で「上映用」（label_tex.py。ユーザーに確認中 2026-11-16）。字の上は +y（澪の側から読める）
        ml = bpy.data.materials.new('label_hand'); nt_ = ml.node_tree; pb_ = nt_.nodes['Principled BSDF']; pb_.inputs['Roughness'].default_value = 0.8
        tc_ = nt_.nodes.new('ShaderNodeTexCoord'); ti_ = nt_.nodes.new('ShaderNodeTexImage'); ti_.image = bpy.data.images.load(LT_)
        nt_.links.new(tc_.outputs['Generated'], ti_.inputs['Vector']); nt_.links.new(ti_.outputs['Color'], pb_.inputs['Base Color'])
        ml['flat'] = (0.75, 0.72, 0.64); lab.data.materials.clear(); lab.data.materials.append(ml)
    x, y, a = P['notebook']
    rot_box('notebook', (x, y), (0.21, 0.297, 0.006), top, a, M['notebook'])
    rot_box('notebook_pages', (x + 0.003, y), (0.206, 0.293, 0.004), top + 0.001, a, M['paper_edge'])
    x, y, a = P['recorder']
    fnt = bpy.data.fonts.load(os.path.join(REPO, 'godot', 'fonts', 'DotGothic16-Regular.ttf'))
    REC = os.path.join(REPO, 'tripo', 'interview', 'recorder.glb')
    if os.path.exists(REC):
        # Tripo の録音機（ユーザー 2026-11-16）。長さ 14cm、マイクを澪（南）に向けて置く。表示の窓は空で届くので、時刻はここで貼る
        _before = set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=REC)
        ro = [o for o in bpy.data.objects if o not in _before and o.type == 'MESH'][0]; ro.name = 'recorder_tripo'
        for o in bpy.context.selected_objects:
            if o.type != 'MESH': bpy.data.objects.remove(o)
        ro.parent = None
        for c in list(ro.users_collection): c.objects.unlink(ro)
        for ms in ro.data.materials:   # 刷りで細かい斑がざらつくので、凹凸と艶の地図は弱めて一様に
            nt_ = ms.node_tree
            for nd in nt_.nodes:
                if nd.type == 'NORMAL_MAP': nd.inputs['Strength'].default_value = 0.3
            pb_ = [nd for nd in nt_.nodes if nd.type == 'BSDF_PRINCIPLED'][0]
            for l_ in list(pb_.inputs['Roughness'].links): nt_.links.remove(l_)
            pb_.inputs['Roughness'].default_value = 0.55
        bpy.context.collection.objects.link(ro); ro.location = (x, y, top); ro.rotation_mode = 'XYZ'; ro.rotation_euler = (0, 0, math.radians(a)); tag(ro, 'props')
        R = Matrix.Rotation(math.radians(a), 3, 'Z'); wc = R @ Vector((0, -0.0211, 0))
        disp = rot_box('recorder_display', (x + wc.x, y + wc.y), (0.0385, 0.0200, 0.0004), top + 0.0296, a, M['display'])
        lcd = bpy.data.materials.new('display_lit'); pl = lcd.node_tree.nodes['Principled BSDF']   # 録音中の液晶：裏から少し光る
        pl.inputs['Base Color'].default_value = (0.42, 0.46, 0.38, 1); pl.inputs['Roughness'].default_value = 0.25
        pl.inputs['Emission Color'].default_value = (0.55, 0.60, 0.50, 1); pl.inputs['Emission Strength'].default_value = 0.6
        lcd['flat'] = (0.45, 0.49, 0.41); disp.data.materials.clear(); disp.data.materials.append(lcd)
        cu = bpy.data.curves.new('rec_time', 'FONT'); cu.body = '01:14:08'; cu.font = fnt; cu.size = 0.0080; cu.align_x = 'CENTER'; cu.align_y = 'CENTER'
        tx = bpy.data.objects.new('rec_time', cu); bpy.context.collection.objects.link(tx); tx.data.materials.append(M['display_text'])
        tx.location = (x + wc.x, y + wc.y, top + 0.0302); tx.rotation_euler = (0, 0, math.radians(a + 180)); tag(tx, 'props')   # 字の上はマイクの側：聞き手の側から読める
    else:
        rot_box('recorder', (x, y), (0.038, 0.11, 0.016), top, a, M['recorder'])
        # 録音機の表示：ドットゴシックで 01:14:08（C のカット。セーブの時刻と同じ秒）
        disp = rot_box('recorder_display', (x, y), (0.030, 0.034, 0.0006), top + 0.016, a, M['display'])
        disp.location.x -= 0.024 * math.sin(math.radians(a)); disp.location.y += 0.024 * math.cos(math.radians(a))
        cu = bpy.data.curves.new('rec_time', 'FONT'); cu.body = '01:14:08'; cu.font = fnt; cu.size = 0.0068; cu.align_x = 'CENTER'; cu.align_y = 'CENTER'
        tx = bpy.data.objects.new('rec_time', cu); bpy.context.collection.objects.link(tx); tx.data.materials.append(M['display_text'])
        tx.location = (disp.location.x, disp.location.y, top + 0.0168); tx.rotation_euler = (0, 0, math.radians(a)); tag(tx, 'props')
    for nm in ('cup_i', 'cup_m'):
        cx, cy = P[nm]
        lathe(nm, [(0.0, 0.0), (0.026, 0.0), (0.028, 0.008), (0.036, 0.02), (0.040, 0.06), (0.041, 0.075), (0.038, 0.075), (0.036, 0.022), (0.0, 0.016)], (cx, cy), M['porcelain'], coll='props')
        bpy.data.objects[nm].location.z = top
        cyl(nm + '_tea', 0.0375, top + 0.058, top + 0.060, (cx, cy), M['tea'], coll='props')

def build_people(M):
    """stand-ins, to be replaced by the Tripo bodies"""
    IY = LY['zabuton'][0]['c'][1]; MY = LY['zabuton'][1]['c'][1]; top = LY['table']['h']
    c = 'people'
    box('i_torso', (-0.17, 0.17), (IY - 0.08, IY + 0.12), (0.36, 0.86), M['jacket'], bevel=0.08, coll=c)
    box('i_lap', (-0.23, 0.23), (IY - 0.30, IY + 0.15), (0.08, 0.24), M['jacket'], bevel=0.07, coll=c)
    box('i_collar', (-0.035, 0.035), (IY - 0.11, IY - 0.09), (0.76, 0.90), M['shirt'], coll=c)
    capsule('i_neck', (0, IY + 0.01, 0.86), (0, IY, 0.97), 0.05, M['skin'], coll=c)
    ball('i_head', 0.105, (0, IY - 0.01, 1.07), M['skin'], (0.86, 1.0, 1.18), coll=c)
    ball('i_hair', 0.112, (0, IY + 0.02, 1.10), M['hair'], (0.92, 1.0, 1.05), coll=c)
    ball('i_bun', 0.05, (0, IY + 0.10, 1.00), M['hair'], coll=c)
    tx, ty, _ = LY['props']['tape']; nx, ny, _ = LY['props']['notebook']
    for s, (hx, hy) in ((1, (tx - 0.02, ty - 0.02)), (-1, (nx + 0.04, ny - 0.02))):
        sh = (s * 0.17, IY + 0.02, 0.82); el = (s * 0.21, IY - 0.12, 0.52); wr = (hx, hy + 0.10, top + 0.04)
        capsule('i_upper', sh, el, 0.052, M['jacket'], coll=c); capsule('i_fore', el, wr, 0.045, M['jacket'], coll=c)
        ball('i_palm', 0.044, (hx, hy + 0.04, top + 0.035 + (0.025 if s > 0 else 0.008)), M['skin'], (0.85, 1.15, 0.38), coll=c)
        for k, (dx, ln) in enumerate([(-0.025, 0.055), (-0.009, 0.07), (0.009, 0.065), (0.025, 0.05)]):
            z = top + 0.03 + (0.025 if s > 0 else 0.006)
            capsule('i_finger', (hx + dx, hy + 0.005, z), (hx + dx * 1.1, hy - ln, z - 0.008), 0.009, M['skin'], coll=c)
    c = 'mio'
    box('m_torso', (-0.15, 0.15), (MY - 0.10, MY + 0.08), (0.38, 0.82), M['sweater'], bevel=0.08, coll=c)
    box('m_lap', (-0.21, 0.21), (MY - 0.12, MY + 0.30), (0.08, 0.22), M['skirt'], bevel=0.07, coll=c)
    capsule('m_neck', (0, MY - 0.01, 0.82), (0, MY, 0.92), 0.042, M['skin'], coll=c)
    ball('m_head', 0.10, (0, MY, 1.00), M['skin'], (0.86, 1.0, 1.15), coll=c)
    ball('m_hair', 0.112, (0, MY - 0.03, 1.02), M['hair'], (0.95, 1.0, 1.12), coll=c)
    box('m_hair_back', (-0.10, 0.10), (MY - 0.12, MY - 0.04), (0.74, 1.02), M['hair'], bevel=0.04, coll=c)
    for s in (-1, 1):
        capsule('m_up', (s * 0.15, MY, 0.78), (s * 0.18, MY + 0.08, 0.52), 0.046, M['sweater'], coll=c)
        capsule('m_fo', (s * 0.18, MY + 0.08, 0.52), (s * 0.05, MY + 0.22, 0.27), 0.040, M['sweater'], coll=c)
        ball('m_hand', 0.040, (s * 0.035, MY + 0.25, 0.25), M['skin'], (0.9, 1.25, 0.5), coll=c)

def build_light(sun=False):
    Y1 = LY['room']['y'][1]
    bpy.ops.object.light_add(type='AREA', location=(0, Y1 + 2.2, 1.1), rotation=(math.radians(-90), 0, 0))
    L = bpy.context.object; L.name = 'sky_light'; L.data.shape = 'RECTANGLE'; L.data.size = 5.0; L.data.size_y = 2.6
    L.data.energy = 520; L.data.color = (0.97, 0.98, 1.0)
    # 南の廊下からの弱い返り光（客間の南は廊下に面した障子、画には映らない）
    bpy.ops.object.light_add(type='AREA', location=(0, LY['room']['y'][0] + 0.05, 1.2), rotation=(math.radians(90), 0, 0))
    F = bpy.context.object; F.name = 'south_fill'; F.data.shape = 'RECTANGLE'; F.data.size = 3.0; F.data.size_y = 1.6
    F.data.energy = 10; F.data.color = (1.0, 0.97, 0.92); F.visible_camera = False; F.visible_glossy = False
    w = bpy.data.worlds.new('w'); bpy.context.scene.world = w; w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Color'].default_value = (0.75, 0.78, 0.82, 1)
    w.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.6
    if sun:
        bpy.ops.object.light_add(type='SUN'); S = bpy.context.object; S.name = 'sun'
        S.rotation_mode = 'QUATERNION'; S.rotation_quaternion = Vector((0.4, -1.0, -0.45)).to_track_quat('-Z', 'Y')
        S.data.energy = 16.0; bpy.data.objects['sky_light'].data.energy = 110   # 葉の影が障子に出るよう、空の光を減らして日を強く; S.data.angle = math.radians(1.0)

def build_tree(M):
    """庭木（障子の外）。葉の影を障子に落とすためだけの物で、画には映らない"""
    import bmesh
    Y1 = LY['room']['y'][1]; r = R('tree')
    me = bpy.data.meshes.new('leaves'); bm = bmesh.new()
    # 枝ごとに葉の房を作る（房の中心は障子の外 0.5〜1.1m）
    for c in range(7):
        cx = r.uniform(-1.1, 1.5); cy = Y1 + r.uniform(0.5, 1.0); cz = r.uniform(1.0, 2.3)
        for k in range(70):
            p = Vector((cx + r.gauss(0, 0.20), cy + r.gauss(0, 0.12), cz + r.gauss(0, 0.16)))
            ang = r.uniform(0, math.pi); L = r.uniform(0.045, 0.075); W = L * 0.42
            d = Vector((math.cos(ang), 0, math.sin(ang))); n = Vector((-math.sin(ang), 0, math.cos(ang)))
            vs = [bm.verts.new(p + d * L), bm.verts.new(p + n * W), bm.verts.new(p - d * L * 0.6), bm.verts.new(p - n * W)]
            bm.faces.new(vs)
        # 房をつなぐ細い枝
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new('tree_leaves', me); bpy.context.collection.objects.link(o); me.materials.append(M['leaf'])
    o.visible_camera = False; o.visible_glossy = False
    return o

def build(sun=False):
    reset(); M = build_materials(); build_room(M); build_table(M); build_props(M); build_people(M); build_light(sun)
    if sun: build_tree(M)
    sc = bpy.context.scene; sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.use_denoising = True
    sc.view_settings.view_transform = 'AgX'; sc.view_settings.look = 'AgX - Medium Low Contrast'; sc.view_settings.exposure = 0.7
    sc['groups'] = json.dumps(GROUPS)
    return M

if __name__ == '__main__':
    build(); bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, 'room.blend')); print('== BUILT')

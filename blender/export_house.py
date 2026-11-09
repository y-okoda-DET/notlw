"""段階2: the whole house for Godot, without the people, at the six times of the night (times.py).
  godot/assets/house/env.glb              every floor, the rooms, the outside (one geometry for all the times)
  godot/assets/house/<time>/lights.json   that time's lights (with how Godot builds each: 'g')
  godot/assets/house/<time>/lightmap.exr  that time's bounce light, baked by Cycles on the one 'lm' UV set
  godot/assets/house/scene.json           colliders, start, and the state of the house at each time (times.STATE)
What changes with the time and is not in the lightmap (Godot switches it): the boards over the windows (board_*), the
generator's cord (gencord), the front door (door_pivot), the lampshades' glow (lampshade_<light>), the sky ring.
FAST=1: fewer samples (a check bake). TIMES=t23,t0330: only those times."""
import sys, os, math, json, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import paths as P
import bpy
from mathutils import Vector
import lib, door as D, hall as Hm, house4 as H4, stage as St, cache
import export_godot as E
import times as TM
from lib import prim

OUT = f'{P.RULES}/assets/house'
os.makedirs(OUT, exist_ok=True)
E.OUT = OUT
DYN = ('board_', 'gencord', 'lampshade_', 'door_', 'door2_', 'crew_')   # switched per time in Godot: kept out of the joined, lightmapped mesh
E.NO_LM = tuple(E.NO_LM) + DYN
# Tripo's decimated cloth and rubber split into thousands of tiny lightmap islands, smaller than a texel, and the
# vest came out in dark patches (試作46). Out of the lightmap it went black (the baked mode has no live bounce), so
# these get LM_BOOST times the atlas area instead: scaled up for the unwrap, then put back.
# breaker: Poly Haven's power_box_01 (21k faces) in the cellar, its open door came out black at 試作64/65 (a sub-texel island)
TRIPO_LIVED = ('breaker', 'lived_vest', 'lived_boots', 'lived_kettle', 'lived_hide', 'lived_blanket', 'study_zabuton', 'natsuki_hoodie', 'futon_stack', 'csleepbag', 'sleepsack', 'csheet'); LM_BOOST = 3.0
LM_BOOST_OF = {'lived_hide': 8.0, 'breaker': 6.0}   # the hide still came out in light and dark blocks at 3 (試作47)

_bake_object = E.bake_object
def _bake_sized(o, size=1024):
    """A baked texture by the object's surface (about 300 px per metre), not 1024 for a nail: the whole house has many
    small procedural things, and a fixed 1024 each filled the pack with texels nobody sees."""
    import bmesh
    area = sum(p.area for p in o.data.polygons) * max(o.matrix_world.to_scale()) ** 2
    px = 2 ** max(7, min(10, round(math.log2(max(1.0, math.sqrt(area) * 300)))))
    return _bake_object(o, min(size, px))
E.bake_object = _bake_sized

def build():
    lib.reset()
    M = D.mats()
    A = H4.build_house4(M, floors=('1F', '2F', 'B1'))
    # every room open to walk into
    for k, ang in (('living', 92), ('dining', -92), ('kitchen', 92), ('toilet', 92), ('pantry', -92), ('cellar', 95)):
        A['doors'][k].rotation_euler.z = math.radians(ang)
    bpy.data.objects['door_barred_pivot'].rotation_euler.z = math.radians(-95)
    import furnish, rooms2
    boxes = H4.colliders(stair_block=False) + furnish.furnish(M)
    for (old, new) in (('furn_lampshade', 'lampshade_lamp_living'), ('furn_pendshade', 'lampshade_lamp_dining'),
                       ('furn_kshade', 'lampshade_lamp_kitchen'), ('lamp_globe', 'lampshade_lamp_lobby')):
        for o in [o for o in bpy.data.objects if o.name.startswith(old)]: o.name = new
    b2, d2 = rooms2.build(M)
    boxes += b2
    for k, piv in d2.items(): piv.rotation_euler.z = math.radians({'bed1': -92, 'bed2': 92, 'bed3': 92, 'bath': -92}[k])
    boxes += rooms2.climb_boxes()
    import lived; lived.build(M)   # the owner's life left in the house (2026-11-04)
    # each lampshade its own material, so its glow can follow its light
    for o in [o for o in bpy.data.objects if o.name.startswith('lampshade_')]:
        if o.data.materials: o.data.materials[0] = o.data.materials[0].copy()
    import shot
    shot.genkan_props4(M, shoes=5, umbrellas=5)
    # the film gear as it stands from the afternoon on: the fresnel in the walkway aimed at the mark, the camcorder on
    # its tripod, the apple box, the blue panel on the shoe cabinet, Natsuki's tape mark
    D.fresnel(St.FRESNEL, 2.0, (*St.MARK, 0), M, energy=160, size=30)
    D.tripod(St.TRIPOD_N, math.radians(205), M)
    Hm.tape_mark(*St.MARK, shot.CAM0[:2], 'tape_natsuki.png')
    ab = prim('cube', 'applebox', loc=(*St.APPLEBOX, .1), rot=(0, 0, .3), scale=(.25, .15, .1), mat=M['agari']); lib.uv_box(ab, 1.25)
    bx, by, bz = TM.BX, TM.BY, TM.BZ; dt = Vector((St.DOOR_C, St.YF - .1, 1.2))
    pnl = prim('cube', 'blue_panel', loc=(bx, by, bz), scale=(.13, .02, .1), mat=M['black'])
    pnl.rotation_euler = (dt - Vector((bx, by, bz))).to_track_quat('-Y', 'Z').to_euler()
    porch = prim('cube', 'porch', loc=(St.DOOR_C, St.YF + 1.0, Hm.ZG - .03), scale=(1.6, 1.0, .03), mat=M['floor']); lib.uv_box(porch, .87)
    import house4_ext as HX; HX.build_ext4(M, with_trees=True, cut_house=True, wide=True)
    for o in [o for o in bpy.data.objects if o.type == 'LIGHT']: bpy.data.objects.remove(o)   # times.py makes them
    bpy.context.view_layer.update()
    return M, boxes

def set_time(t, M):
    st = TM.STATE[t]
    for o in bpy.data.objects:
        if o.name.startswith('board_'): o.hide_render = not st['boards']
        if o.name.startswith('gencord'): o.hide_render = not st['cord']
        if o.name.startswith('crew_') or (o.name.startswith('lampshade_') and o.name[len('lampshade_'):].split('.')[0] in TM.CREW_KEYS):
            o.hide_render = not st.get('crew', True)
    bpy.data.objects['door_pivot'].rotation_euler.z = math.radians(st['front'])
    L = TM.lights(t)
    lit = {o.name for o in L}
    for o in bpy.data.objects:   # the shoulder on the forest road: whole until the storm takes it (outside.py)
        if o.name.startswith('ext_slipok_'): o.hide_render = st.get('slip', False)
        elif o.name.startswith('ext_slipfall_'): o.hide_render = not st.get('slip', False)
    for o in [o for o in bpy.data.objects if o.name.startswith('lampshade_')]:
        m = o.data.materials[0]; p = m.node_tree.nodes.get('Principled BSDF')
        if p: p.inputs['Emission Strength'].default_value = 4.0 if o.name[len('lampshade_'):].split('.')[0] in lit else 0.0
    sky = M.get('ext_sky')
    if sky:
        p = sky.node_tree.nodes['Principled BSDF']; p.inputs['Emission Strength'].default_value = st['sky']
    bpy.context.view_layer.update()
    return L

def join_static():
    statics = [o for o in bpy.data.objects if o.type == 'MESH' and not o.name.startswith(E.NO_LM)]
    bpy.ops.object.select_all(action='DESELECT')
    for o in statics: o.select_set(True)
    bpy.context.view_layer.objects.active = statics[0]
    bpy.ops.object.convert(target='MESH')
    boost = []
    for o in statics:
        if o.name.startswith(TRIPO_LIVED):
            c = o.matrix_world.translation.copy(); boost.append(c)
            a = o.data.attributes.new('lmboost', 'INT', 'POINT')
            for v in a.data: v.value = len(boost)
            k = next((v for key, v in LM_BOOST_OF.items() if o.name.startswith(key)), LM_BOOST)
            boost[-1] = (c, k); o.scale = o.scale * k
    for o in statics:
        if len(o.data.uv_layers) == 0: o.data.uv_layers.new(name='UVMap')
        o.data.uv_layers[0].name = 'UVMap'
        while len(o.data.uv_layers) > 1: o.data.uv_layers.remove(o.data.uv_layers[1])
    bpy.ops.object.join()
    j = bpy.context.view_layer.objects.active; j.name = 'env_static'
    me = j.data
    lm = me.uv_layers.new(name='lm'); me.uv_layers.active = lm; me.uv_layers['UVMap'].active_render = True
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=.002)
    # 試作81 (階段と踊り場の壁のむら): with the many islands, smart_project's margin ate the sheet; the islands used 0.8% of
    # the 2048 lightmap and the walls had 3 to 5 texels a metre, so each texel's noise was a 30 cm cloud. Packed again
    # with a margin of about one texel: 46% of the sheet, about 25 texels a metre
    bpy.ops.uv.select_all(action='SELECT')
    bpy.ops.uv.pack_islands(rotate=True, margin_method='FRACTION', margin=float(os.environ.get('LM_MARGIN', '.0005')))
    bpy.ops.object.mode_set(mode='OBJECT')
    lm_ids(me, f'{P.WORK}/lm_ids_house.npy')
    if boost and 'lmboost' in me.attributes:
        mw = j.matrix_world; inv = mw.inverted()
        for v, a in zip(me.vertices, me.attributes['lmboost'].data):
            if a.value:
                c, k = boost[a.value - 1]; w = mw @ v.co; v.co = inv @ (c + (w - c) / k)
        me.attributes.remove(me.attributes['lmboost'])
    return j

def lm_ids(me, path, S=2048):
    """The lightmap's island map (int32, bottom row first like the baked image; 0 = no island): denoise_lm.py smooths
    inside each island only (試作81). Islands: polygons joined by loops on the same vertex with the same 'lm' UV."""
    import numpy as np
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import connected_components
    from PIL import Image, ImageDraw
    nl, npl = len(me.loops), len(me.polygons)
    lv = np.zeros(nl, np.int64); me.loops.foreach_get('vertex_index', lv)
    uv = np.zeros(nl * 2); me.uv_layers['lm'].data.foreach_get('uv', uv); uv = uv.reshape(-1, 2)
    lt = np.zeros(npl, np.int64); me.polygons.foreach_get('loop_total', lt)
    lp = np.repeat(np.arange(npl), lt)
    q = np.round(uv * S * 16).astype(np.int64)
    _, kid = np.unique(np.stack([lv, q[:, 0], q[:, 1]], 1), axis=0, return_inverse=True); kid = kid.ravel()
    nk = kid.max() + 1
    _, lab = connected_components(coo_matrix((np.ones(nl), (lp, npl + kid)), shape=(npl + nk, npl + nk)), directed=False)
    me.calc_loop_triangles(); n = len(me.loop_triangles)
    tl = np.zeros(n * 3, np.int64); me.loop_triangles.foreach_get('loops', tl)
    tp = np.zeros(n, np.int64); me.loop_triangles.foreach_get('polygon_index', tp)
    img = Image.new('I', (S, S), 0); d = ImageDraw.Draw(img)
    for tri, i in zip(uv[tl].reshape(-1, 3, 2) * S, lab[tp] + 1):
        pts = [(x, S - y) for x, y in tri]; d.polygon(pts, fill=int(i), outline=int(i))
    np.save(path, np.array(img, dtype=np.int32)[::-1])
    print('lm_ids', path, flush=True)

def bake_time(j, t, size, samples):
    s = bpy.context.scene; s.render.engine = 'CYCLES'; s.cycles.samples = samples; s.cycles.device = 'CPU'
    s.cycles.max_bounces = 6; s.cycles.diffuse_bounces = 4
    b = s.render.bake; b.use_pass_direct = False; b.use_pass_indirect = True; b.use_pass_color = False; b.margin = 6
    os.makedirs(f'{OUT}/{t}', exist_ok=True)
    out = f'{OUT}/{t}/lightmap.exr'
    key = cache.scene_key(f'house-lm {t} {size} {samples}')
    print('lightmap', t, 'key', key)
    if cache.get('lm', key, out): print('lightmap', t, ': cache hit', key); return
    me = j.data
    img = bpy.data.images.new(f'lm_{t}', size, size, alpha=False, float_buffer=True)
    for m in me.materials:
        if m is None: continue
        n = m.node_tree.nodes.new('ShaderNodeTexImage'); n.image = img; n.name = '_lm'
        uvn = m.node_tree.nodes.new('ShaderNodeUVMap'); uvn.uv_map = 'lm'; m.node_tree.links.new(uvn.outputs[0], n.inputs[0])
        m.node_tree.nodes.active = n
    bpy.ops.object.select_all(action='DESELECT'); j.select_set(True); bpy.context.view_layer.objects.active = j
    t0 = time.time()
    bpy.ops.object.bake(type='DIFFUSE')
    print('lightmap', t, 'baked in', round(time.time() - t0), 's', flush=True)
    img.filepath_raw = out; img.file_format = 'OPEN_EXR'; img.save()
    cache.put('lm', key, out)
    for m in me.materials:
        if m is None: continue
        for n in [n for n in m.node_tree.nodes if n.name == '_lm' or (n.type == 'UVMAP' and n.uv_map == 'lm')]: m.node_tree.nodes.remove(n)
    bpy.data.images.remove(img)

if __name__ == '__main__':
    M, boxes = build()
    if os.environ.get('PREVIEW'):   # a top view of the plan in Blender, to check the doors and the rooms
        bpy.ops.wm.save_as_mainfile(filepath=f'{P.WORK}/house_build.blend'); print('SAVED_PREVIEW'); sys.exit(0)
    baked = E.simplify_materials()
    print('baked', len(baked))
    j = join_static()
    size = int(os.environ.get('LM_SIZE', '2048'))
    samples = int(os.environ.get('LM_SAMPLES', '32' if os.environ.get('FAST') else '1024'))   # 1024 (試作81): with the islands packed tight (57 times the texels) 8192 would take some 10 hours; the island-wise smoothing (denoise_lm.py) takes the grain   # 8192 (試作72; 2048 in 71): at 512 the dusk walls' bounce came out grainy with dark clouds (レビュー 63・65: 刷りなしの黒い染み)   # LM_SAMPLES=512 with FAST: check stills without the 32-sample blotches   # 128 left blotches in the dim rooms (書斎、試作45)
    sel = os.environ.get('TIMES', '').split(',') if os.environ.get('TIMES') else TM.TIMES
    for t in TM.TIMES:
        set_time(t, M)
        TM.dump(f'{OUT}/{t}/lights.json') if os.path.isdir(f'{OUT}/{t}') else (os.makedirs(f'{OUT}/{t}'), TM.dump(f'{OUT}/{t}/lights.json'))
        if t in sel: bake_time(j, t, size, samples)
    for o in [o for o in bpy.data.objects if o.type == 'LIGHT']: bpy.data.objects.remove(o)
    # the glb: dynamic things in their dusk state (Godot sets them per time)
    for o in bpy.data.objects: o.hide_render = False
    bpy.data.objects['door_pivot'].rotation_euler.z = 0
    env = [o for o in bpy.data.objects if o.type in ('MESH', 'CURVE', 'EMPTY')]
    E.export(f'{OUT}/env.glb', env)
    gx0, gy0, gz0 = H4.X(0) - .3, H4.Y(8) - .3, H4.ZB - .1
    gx1, gy1, gz1 = H4.X(10) + .3, St.YF + .6, H4.H2 + .4
    boxes = boxes + [dict(c=[St.DOOR_C, St.YF + .95, Hm.ZG - .28], s=[2.8, 1.8, .5])]
    # the outside can be walked (outside.py): the ground's collision is built in Godot from its meshes (walk), unseen
    # walls round where one may go, the car, the trunks near the paths; a ramp down the porch's two steps
    import outside as OS, house4_ext as HX
    y1 = H4.Y(-1.5); zd = H4.ZG - .03
    boxes.append(dict(c=[St.DOOR_C, y1 + .32, (zd + HX.GZ) / 2 - .02], s=[1.5, math.hypot(.64, zd - HX.GZ), .04], ramp=1, rx=-math.atan2(zd - HX.GZ, .64)))
    boxes += OS.walk_boxes() + OS.car_boxes()
    props = [[*St.TRIPOD_N, .18], [*St.FRESNEL, .25], [*St.APPLEBOX, .18]] + OS.tree_trunks()
    import wear as WR   # 段階2 使い込みの跡: Decals placed from the plan (Godot main.gd _wear)
    json.dump(dict(YF=St.YF, ZG=Hm.ZG, boxes=boxes, props=props, wear=WR.decals(), spawn=list(St.PLAYER), look=list(St.PLAYER_LOOK),
                   gi_box=[[gx0, gy0, gz0], [gx1, gy1, gz1]], mark=[*St.MARK, 0], house=True, walk=list(OS.WALK_MESHES),
                   times=TM.TIMES, labels=TM.LABEL, state=TM.STATE, crew_keys=TM.CREW_KEYS, fps=24, loop=20.0, knocks=[]),
              open(f'{OUT}/scene.json', 'w'), indent=1)
    print('EXPORTED')

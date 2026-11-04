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
DYN = ('board_', 'gencord', 'lampshade_', 'door_', 'door2_')   # switched per time in Godot: kept out of the joined, lightmapped mesh
E.NO_LM = tuple(E.NO_LM) + DYN

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
    boxes = H4.colliders() + furnish.furnish(M)
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
    import house4_ext as HX; HX.build_ext4(M, with_trees=True)
    for o in [o for o in bpy.data.objects if o.type == 'LIGHT']: bpy.data.objects.remove(o)   # times.py makes them
    bpy.context.view_layer.update()
    return M, boxes

def set_time(t, M):
    st = TM.STATE[t]
    for o in bpy.data.objects:
        if o.name.startswith('board_'): o.hide_render = not st['boards']
        if o.name.startswith('gencord'): o.hide_render = not st['cord']
    bpy.data.objects['door_pivot'].rotation_euler.z = math.radians(st['front'])
    L = TM.lights(t)
    lit = {o.name for o in L}
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
    bpy.ops.object.mode_set(mode='OBJECT')
    return j

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
    samples = 32 if os.environ.get('FAST') else int(os.environ.get('LM_SAMPLES', '512'))   # 128 left blotches in the dim rooms (書斎、試作45)
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
    # the outside is not built to walk yet (段階2 の次の作業): an unseen fence round the porch so the open door does not
    # let you walk off into the void
    for (cx, cy, sx, sy) in ((St.DOOR_C - 1.42, St.YF + .95, .05, 1.8), (St.DOOR_C + 1.42, St.YF + .95, .05, 1.8), (St.DOOR_C, St.YF + 1.87, 2.9, .05)):
        boxes.append(dict(c=[cx, cy, 1.0], s=[sx, sy, 2.4]))
    props = [[*St.TRIPOD_N, .18], [*St.FRESNEL, .25], [*St.APPLEBOX, .18]]
    json.dump(dict(YF=St.YF, ZG=Hm.ZG, boxes=boxes, props=props, spawn=list(St.PLAYER), look=list(St.PLAYER_LOOK),
                   gi_box=[[gx0, gy0, gz0], [gx1, gy1, gz1]], mark=[*St.MARK, 0], house=True,
                   times=TM.TIMES, labels=TM.LABEL, state=TM.STATE, fps=24, loop=20.0, knocks=[]),
              open(f'{OUT}/scene.json', 'w'), indent=1)
    print('EXPORTED')

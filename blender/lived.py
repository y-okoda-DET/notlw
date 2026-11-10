"""段階2: the owner's life left in the house after it was cleaned for renting (ユーザー「誰かが住んでいた家に見える？」
→ 2026-11-04 決定事項). Only the whole-house scene (export_house) builds this: the 段階1 scenes keep furnish.py as passed.
What is here is what cleaning does not take away: the pale rectangles where his photographs hung, his old things in the
kitchen, his ledger and glasses on the desk, the ash in his ashtray, the hooks his hunting gear hung on.
Plan coordinates as in furnish.py (X(x), Y(y))."""
import math
import bpy
import lib, house4 as H4
from lib import prim, mat_basic
from furnish import box, cyl, collide

X, Y = H4.X, H4.Y
W = H4.T / 2 + .021   # a partition's face (its plaster slab stands .02 off the core) from its plan line

def tinted(M, key, k, name):
    """A copy of M[key] whose image is multiplied k times brighter (the wallpaper that the sun did not fade)."""
    if name in M: return M[name]
    m = M[key].copy(); m.name = name
    for n in m.node_tree.nodes:
        if n.type == 'MIX' and n.data_type == 'RGBA':
            b = n.inputs['B'].default_value; n.inputs['B'].default_value = (b[0] * k, b[1] * k, b[2] * k, 1)
    M[name] = m
    return m

def mats(M):
    if 'kettle_al' in M: return
    M['ghost'] = tinted(M, 'plaster', 1.16, 'plaster_ghost')
    M['kettle_al'] = mat_basic('kettle_al', (.62, .62, .6), .45, metal=.8)
    M['soot'] = mat_basic('soot', (.06, .055, .05), .8)
    M['bottle'] = mat_basic('bottle', (.08, .2, .1), .15)
    M['label'] = mat_basic('label', (.85, .82, .72), .7)
    M['yunomi'] = mat_basic('yunomi', (.42, .33, .24), .35)
    M['yunomi2'] = mat_basic('yunomi2', (.25, .3, .32), .35)
    M['tin'] = mat_basic('tin', (.18, .28, .2), .4, metal=.5)
    M['newsp'] = mat_basic('newsp', (.72, .7, .64), .9)
    M['string'] = mat_basic('string', (.78, .7, .52), .9)
    M['ledger'] = mat_basic('ledger', (.12, .14, .22), .6)
    M['ash'] = mat_basic('ash', (.42, .41, .4), .95)
    M['butt'] = mat_basic('butt', (.85, .6, .35), .8)
    M['glasses'] = mat_basic('glasses', (.1, .08, .06), .3)
    M['magnet'] = mat_basic('magnet', (.7, .12, .1), .4)
    M['note_y'] = mat_basic('note_y', (.88, .82, .5), .8)
    M['towel'] = mat_basic('towel', (.55, .6, .65), .95)
    # his handwriting (blender/lived_tex.py)
    M['calendar'] = lib.mat_image('lived_calendar', lib.tex_path('lived_calendar'), rough=.85, bump=0)
    M['photo'] = lib.mat_image('lived_photo', lib.tex_path('lived_photo_lift'), rough=.9, bump=0)   # lift: the user's print (lived_photo.jpg) levelled up and matte, it was a dark square with a glare at dusk through the print (試作73)
    M['ledgerpage'] = lib.mat_image('lived_ledgerpage', lib.tex_path('lived_ledger'), rough=.85, bump=0)

def phm(a, x, y, z, rz=0.0, rx=0.0, ry=0.0, s=1.0, name=None):
    """A Poly Haven model (assets/phm/<a>, blender/ph_models.py), real size, its parts joined. Plan x, y; z absolute."""
    import os, paths as P
    f = f'{P.ASSETS}/phm/{a}/{a}.gltf'
    if not os.path.exists(f): print('NO PHM', a); return None
    before = {o.name for o in bpy.data.objects}
    bpy.ops.import_scene.gltf(filepath=f)
    names = [o.name for o in bpy.data.objects if o.name not in before]
    ms = [bpy.data.objects[n] for n in names if bpy.data.objects[n].type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in ms: o.select_set(True)
    bpy.context.view_layer.objects.active = ms[0]
    bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
    if len(ms) > 1: bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active; keep = o.name
    for n in names:
        ob = bpy.data.objects.get(n)
        if ob is not None and ob.name != keep: bpy.data.objects.remove(ob)
    o = bpy.data.objects[keep]
    # glass (KHR transmission) comes into Godot as an opaque disc lit by the lightmap (the clock's face turned solid
    # orange in 試作46): its faces are dropped, a clock face and thin lenses read without them
    gl = [i for i, m in enumerate(o.data.materials) if m and m.name.endswith('_glass')]
    if gl:
        import bmesh
        bm = bmesh.new(); bm.from_mesh(o.data)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index in gl], context='FACES')
        bm.to_mesh(o.data); bm.free()
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.name = name or f'phm_{a}'
    o.rotation_mode = 'XYZ'; o.rotation_euler = (rx, ry, rz); o.scale = (s, s, s); o.location = (X(x), Y(y), z)
    bpy.context.view_layer.update()
    return o

def ghost_frames(M, ax, fixed, face, rects):
    """Pale rectangles on a wall where frames hung for years, each with its nail. ax 'Y': the wall at plan x = fixed;
    face = +1 when the room is on the +x side. rects: (lo, hi, z0, z1) along the wall."""
    for (a, b, z0, z1) in rects:
        if ax == 'Y':
            o = prim('cube', 'lived_ghost', loc=(X(fixed) + face * (W + .0015), (Y(a) + Y(b)) / 2, (z0 + z1) / 2), scale=(.0005, (b - a) / 2, (z1 - z0) / 2), mat=M['ghost'])
            n = prim('cylinder', 'lived_nail', loc=(X(fixed) + face * (W + .006), (Y(a) + Y(b)) / 2, z1 - .03), rot=(0, math.pi / 2, 0), scale=(.003, .003, .006), mat=M['steel'], vertices=6)
        else:
            o = prim('cube', 'lived_ghost', loc=((X(a) + X(b)) / 2, Y(fixed) - face * (W + .0015), (z0 + z1) / 2), scale=((b - a) / 2, .0005, (z1 - z0) / 2), mat=M['ghost'])
            n = prim('cylinder', 'lived_nail', loc=((X(a) + X(b)) / 2, Y(fixed) - face * (W + .006), z1 - .03), rot=(math.pi / 2, 0, 0), scale=(.003, .003, .006), mat=M['steel'], vertices=6)
        lib.uv_box(o, .87)

def living(M):
    # his photographs (the hunts, the dogs, the people he went with) taken down for the renters: on the wall to the hall
    ghost_frames(M, 'Y', 4, -1, [(1.6, 2.05, 1.32, 1.68), (2.18, 2.5, 1.4, 1.82), (2.62, 2.92, 1.46, 1.7)])
    # last winter's newspapers, tied for the collection that he did not take them to, by the firewood
    for i in range(3):
        box('lived_news', .72, 4.05, 1.12, 4.33, i * .055, i * .055 + .05, M['newsp'])
    for dx in (.82, 1.02):
        box('lived_string', dx, 4.04, dx + .01, 4.34, 0, .168, M['string'])
    phm('hatchet', .9, 4.2, .168 + .015, ry=math.pi / 2, rz=.35, name='lived_hatchet')   # laid on the bundle, for the kindling

    # a deer's hide on the floor before the stove's hearth (the user's Tripo; one of his own deer)
    import furnish as F
    F.tripo_prop('hide', (X(1.75), Y(3.55), .002), .08, 1.3, name='lived_hide')

def hall(M):
    # the two hooks his vest and cap hung on, by the genkan (Tripo: the vest itself, 画像生成とTripo_2回目), and the
    # frames along the hall
    # 試作97: in his study now, on its west wall north of the fusuma (in the hall it hung in the frame of 第1章's
    # storyboard shot, where the old hall had no vest: ユーザー「ここにかかっていたベスト、1章ではなかった。別の場所にかける」)
    HX = 6.0
    for y in (2.95, 3.17):
        o = prim('cylinder', 'lived_hookbase', loc=(X(HX) + W + .006, Y(y), 1.64), rot=(0, math.pi / 2, 0), scale=(.02, .02, .006), mat=M['walnut'], vertices=10)
        o = prim('cylinder', 'lived_hook', loc=(X(HX) + W + .025, Y(y), 1.65), rot=(0, math.pi / 2 - .3, 0), scale=(.005, .005, .03), mat=M['steel'], vertices=6)
    # his orange vest and cap on the first hook (Tripo, the user's: 2026-11-04); the second hook is empty
    import furnish as F
    F.tripo_prop('vest', (X(HX) + W + .183 * .8 + .004, Y(2.95), 1.76 - .98 * .8), math.pi / 2, .8, name='lived_vest')
    ghost_frames(M, 'Y', 4, 1, [(4.3, 4.75, 1.35, 1.7)])
    # the one frame left: him and his hunting party on the forest road (the user's image, 2026-11-04)
    xf = X(4.0) + W
    box('lived_photoframe', 4.0 + W, 4.95, 4.0 + W + .022, 5.6, 1.3, 1.78, M['walnut'])
    prim('plane', 'lived_photomat', loc=(xf + .0225, Y(5.275), 1.54), rot=(math.pi / 2, 0, math.pi / 2), scale=(.3, .215, 1), mat=M['label'])
    prim('plane', 'lived_photo', loc=(xf + .0232, Y(5.275), 1.54), rot=(math.pi / 2, 0, math.pi / 2), scale=(.26, .195, 1), mat=M['photo'])
    # the genkan: his rubber boots by the shoe cabinet (the user's Tripo pair; Poly Haven's when it is not there),
    # work gloves on its top
    if not F.tripo_prop('boots', (X(5.42), Y(.7), H4.ZG), math.pi / 2, .41, name='lived_boots'):
        phm('rubber_boots', 5.42, .7, H4.ZG, rz=math.pi / 2, name='lived_boots')
    phm('garden_gloves_01', 5.8, 1.12, H4.ZG + .91, rz=.7, s=.9, name='lived_gloves')

def kitchen(M):
    # his things the cleaners left in the kitchen: tea and cups by the stove, a bottle of sake, a towel on the oven door
    # rail; the kettle on the second burner (a built one until the Tripo one comes)
    import os, paths as P, furnish as F
    if not F.tripo_prop('kettle', (X(8.0), Y(3.98), .985), math.radians(200), .24, name='lived_kettle'):
        cyl('lived_kettle', 8.0, 3.98, .985, 1.11, .1, M['kettle_al'], 18)
        cyl('lived_kettlelid', 8.0, 3.98, 1.11, 1.13, .045, M['plastic'], 12)
        cyl('lived_kettlesoot', 8.0, 3.98, .985, 1.0, .101, M['soot'], 18)
        o = prim('cylinder', 'lived_kspout', loc=(X(7.89), Y(3.95), 1.06), rot=(0, -.9, .3), scale=(.012, .012, .07), mat=M['kettle_al'], vertices=8)
        lib.tube('lived_khandle', [(X(7.93), Y(3.98), 1.12), (X(8.0), Y(3.98), 1.2), (X(8.07), Y(3.98), 1.12)], [.007] * 3, M['plastic'], seg=6, sub=3)
    cyl('lived_teatin', 6.8, 3.9, .862, .99, .045, M['tin'], 14)
    cyl('lived_sake', 6.98, 3.86, .862, 1.24, .05, M['bottle'], 14)
    cyl('lived_sakeneck', 6.98, 3.86, 1.24, 1.33, .018, M['bottle'], 10)
    box('lived_sakelabel', 6.93, 3.912, 7.03, 3.915, .98, 1.12, M['label'])
    for i, (x, y) in enumerate(((7.2, 3.92), (7.32, 3.96))):
        cyl('lived_yunomi', x, y, .862, .95, .035, M['yunomi'] if i == 0 else M['yunomi2'], 14)
    cyl('lived_yunomi', 7.2, 3.92, .95, 1.038, .035, M['yunomi2'], 14)   # stacked, as they were put away
    # the fridge door: his notes under magnets (the crew have not touched them)
    for (y, z, w, h, mat) in ((3.85, 1.4, .1, .14, 'screen'), (4.02, 1.32, .08, .08, 'note_y'), (3.9, 1.1, .12, .09, 'screen')):
        box('lived_note', 9.317, y - w / 2, 9.32, y + w / 2, z - h / 2, z + h / 2, M[mat])
        box('lived_magnet', 9.312, y - .012, 9.317, y + .012, z + h / 2 - .02, z + h / 2 + .005, M['magnet'])
    phm('pot_enamel_01', 9.62, 4.0, 1.75, rz=.3, name='lived_enamelpot')          # stored on the fridge
    phm('wooden_cutting_board', 8.62, 3.95, .862, rz=.1, name='lived_board')
    phm('plastic_thermos', 9.18, 3.86, .862, rz=2.0, name='lived_thermos')
    phm('wicker_basket_01', 6.32, 4.55, 0, rz=1.4, name='lived_basket')
    phm('wall_clock', 6.0 + W + .001, 5.3, 1.95, rz=math.pi / 2, name='lived_clock')   # stopped (no one wound it)
    # November on his calendar: the 15th circled 「解禁」, his ×s stop three days later (no one turned the page since)
    prim('plane', 'lived_calendar', loc=(X(6.0) + W + .003, Y(5.78), 1.42), rot=(math.pi / 2, 0, math.pi / 2), scale=(.15, .225, 1), mat=M['calendar'])
    # the hand towel over the sink's edge, dry for months
    box('lived_towel', 7.4, 7.3, 7.6, 7.325, .66, .862, M['towel'])

def study(M):
    # his hunting ledger open on the desk, his reading glasses folded on it, the ash still in the ashtray
    box('lived_ledger', 9.38, 1.62, 9.68, 1.86, .37, .385, M['ledger'])
    prim('plane', 'lived_ledgerpage', loc=(X(9.53), Y(1.74), .386), scale=(.145, .109, 1), mat=M['ledgerpage'])
    if not phm('round_spectacles', 9.52, 1.66, .386 + .023, rz=math.radians(160), name='lived_spectacles'):
        for s in (-1, 1):
            o = prim('cylinder', 'lived_lens', loc=(X(9.5 + s * .028), Y(1.7), .392), scale=(.022, .016, .002), mat=M['glasses'], vertices=14)
    phm('vintage_binocular', 9.68, 2.28, .37 + .027, rz=.5, name='lived_binocular')
    phm('cigarette_pack', 9.72, 1.28, .37, rz=1.2, name='lived_cigs')
    phm('vintage_lighter', 9.74, 1.52, .37 + .029, rx=math.pi / 2, rz=.4, name='lived_lighter')
    # his blankets folded in the corner by the fusuma (the user's Tripo)
    import furnish as F
    F.tripo_prop('blanket', (X(6.38), Y(3.22), .03), .1, .55, name='lived_blanket')
    # his books on the tokonoma's side: plain spines (no titles to read)
    for i in range(7):
        h = .21 + .03 * ((i * 37) % 3); w = .025 + .01 * ((i * 13) % 2)
        box('lived_book', 9.0 + i * .036, 3.4, 9.0 + i * .036 + w, 3.52, .15, .15 + h, M['ledger'] if i % 3 else M['newsp'])
    cyl('lived_ash', 9.6, 1.4, .395, .402, .05, M['ash'], 14)
    for i, a in enumerate((.4, 1.9, 3.1)):
        o = prim('cylinder', 'lived_butt', loc=(X(9.6 + .025 * math.cos(a)), Y(1.4 + .025 * math.sin(a)), .405), rot=(math.pi / 2, 0, a), scale=(.004, .004, .016), mat=M['butt'], vertices=6)

def steel(M):
    # stainless at metallic 1 has nothing to reflect in Godot (no reflection probe in the house): the counter tops and
    # the stove came out black in 試作45/46. Half metal keeps its sheen from the lights and the lightmap.
    p = M['steel'].node_tree.nodes.get('Principled BSDF')
    if p: p.inputs['Metallic'].default_value = .35; p.inputs['Roughness'].default_value = .38

def build(M):
    mats(M); steel(M)
    living(M); hall(M); kitchen(M); study(M)

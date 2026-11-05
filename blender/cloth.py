"""段階2: cloth dropped by Blender's cloth simulation instead of a box (a blanket pushed back on a bed, a dust sheet
over the cellar's old furniture, a sleeping bag left open on the floor). A box blanket reads as a board through the
print; real folds give the bed its shape in the dark.
The result of each drop is kept as a file (assets/cloth/<name>-<key>.npy, the vertex positions), keyed by everything
that goes into it (the cloth's size and grid, the colliders' shapes and places, the settings), so a build gets the
same mesh every time: the light bake is keyed on the shapes (cache.py), and a re-simulated cloth would differ in the
last digits and send every build into a fresh bake."""
import os, math, hashlib, random
import bpy, bmesh
import numpy as np
from mathutils import Vector
import paths as P

DIR = f'{P.ASSETS}/cloth'

def _key(parts):
    h = hashlib.sha256()
    for p in parts: h.update(repr(p).encode())
    return h.hexdigest()[:16]

def _col_sig(o):
    me = o.data
    co = np.empty(len(me.vertices) * 3, np.float32); me.vertices.foreach_get('co', co)
    return (o.name, tuple(round(v, 4) for v in o.matrix_world.to_translation()), tuple(round(v, 4) for v in o.matrix_world.to_euler()),
            tuple(round(v, 4) for v in o.matrix_world.to_scale()), round(float(co.sum()), 3), len(co))

def drop(name, center, size, z, mat, colliders=(), rot=(0.0, 0.0, 0.0), res=.035, frames=60, slack=1.0, rumple=.04, seed=1,
         stiff=8.0, bend=.4, mass=.3, thick=.008, floor=None, pin=None, push=None, pleat=None, mat2=None):
    """A sheet of size (w, d) metres centred at world (cx, cy), released at height z (rot: the sheet's rotation; a
    curtain is stood up with rx 90°) over the colliders (objects).
    slack > 1 lays out more cloth than the size (it bunches up when it lands); rumple lifts it in random lumps first.
    floor: the z of an invisible floor under it (the room's floor). pleat: (amp, period) folds along the sheet's x. push: (dx, dy) local: the side away from it is
    shoved that way before the drop (a blanket pushed back toward the foot). pin: a height; the verts above it stay put
    (a curtain's top on its rod). Returns the object (UV from the grid, solidified by thick)."""
    os.makedirs(DIR, exist_ok=True)
    w, d = size[0] * slack, size[1] * slack
    nx, ny = max(4, round(w / res)), max(4, round(d / res))
    key = _key((name, center, size, z, rot, pleat, res, frames, slack, rumple, seed, stiff, bend, mass, floor, pin, push,
                [_col_sig(c) for c in colliders], 'v2'))
    f = f'{DIR}/{name}-{key}.npy'
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=nx, y_subdivisions=ny, size=1, location=(center[0], center[1], z), rotation=rot)
    o = bpy.context.active_object; o.name = name
    o.scale = (w, d, 1)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat: o.data.materials.append(mat)
    if mat2: o.data.materials.append(mat2)
    me = o.data
    if os.path.exists(f):
        co = np.load(f)
        if len(co) == len(me.vertices) * 3:
            # stored in world space; the object keeps its place and rotation, so back to local
            inv = o.matrix_world.inverted()
            for i, v in enumerate(me.vertices): v.co = inv @ Vector(co[i * 3:i * 3 + 3])
            me.update()
            return _finish(o, thick, mat2)
    rng = random.Random(seed)
    # lumps: a few random bumps, so the cloth falls into folds instead of lying down flat
    bumps = [(rng.uniform(-w / 2, w / 2), rng.uniform(-d / 2, d / 2), rng.uniform(.08, .25), rng.uniform(-1, 1)) for _ in range(8)]
    for v in me.vertices:
        x, y = v.co.x, v.co.y
        v.co.z += rumple * sum(s * math.exp(-((x - bx) ** 2 + (y - by) ** 2) / (r * r)) for (bx, by, r, s) in bumps)
        if pleat: v.co.z += pleat[0] * math.sin(2 * math.pi * x / pleat[1])
        if push:   # the side away from the push is shoved toward it (bunched up), the near side stays
            pl = math.hypot(*push); ux, uy = push[0] / pl, push[1] / pl
            ext = abs(ux) * w / 2 + abs(uy) * d / 2
            t = max(0.0, -(x * ux + y * uy)) / ext
            v.co.x += push[0] * t; v.co.y += push[1] * t
    me.update()
    tmp = []
    if floor is not None:
        bpy.ops.mesh.primitive_plane_add(size=1, location=(center[0], center[1], floor)); fl = bpy.context.active_object
        fl.scale = (w * 3, d * 3, 1); tmp.append(fl); colliders = list(colliders) + [fl]
    for c in colliders:
        m = c.modifiers.new('col', 'COLLISION')
        c.collision.thickness_outer = .004; c.collision.cloth_friction = 8.0
    cm = o.modifiers.new('cloth', 'CLOTH'); s = cm.settings
    s.quality = 6; s.mass = mass; s.tension_stiffness = stiff; s.compression_stiffness = stiff; s.shear_stiffness = stiff * .6
    s.bending_stiffness = bend; s.air_damping = 2.0
    cm.collision_settings.distance_min = .004; cm.collision_settings.use_self_collision = False
    if pin is not None:   # a vertex group of the verts above the pin height (they stay where they were laid)
        g = o.vertex_groups.new(name='pin'); g.add([v.index for v in me.vertices if (o.matrix_world @ v.co).z > pin], 1.0, 'REPLACE')
        s.vertex_group_mass = 'pin'; s.pin_stiffness = 1.0
    sc = bpy.context.scene; sc.frame_start = 1; sc.frame_end = frames
    cm.point_cache.frame_start = 1; cm.point_cache.frame_end = frames
    for fr in range(1, frames + 1): sc.frame_set(fr)
    dg = bpy.context.evaluated_depsgraph_get(); ev = o.evaluated_get(dg)
    co = np.array([c for v in ev.data.vertices for c in (o.matrix_world @ v.co)], np.float32)
    o.modifiers.remove(cm)
    inv = o.matrix_world.inverted()
    for i, v in enumerate(me.vertices): v.co = inv @ Vector(co[i * 3:i * 3 + 3])
    me.update()
    if o.vertex_groups.get('pin'): o.vertex_groups.remove(o.vertex_groups['pin'])
    sc.frame_set(1)
    for c in colliders:
        for m in [m for m in c.modifiers if m.type == 'COLLISION']: c.modifiers.remove(m)
    for t in tmp: bpy.data.objects.remove(t)
    np.save(f, co)
    print('CLOTH', name, 'simulated', nx, 'x', ny, flush=True)
    return _finish(o, thick, mat2)

def _finish(o, thick, mat2=None):
    for p in o.data.polygons: p.use_smooth = True
    if thick:
        so = o.modifiers.new('so', 'SOLIDIFY'); so.thickness = thick; so.offset = 1.0
        if mat2: so.material_offset = 1   # the other face (a sleeping bag's lining) in the second material
        bpy.context.view_layer.objects.active = o; o.select_set(True)
        bpy.ops.object.modifier_apply(modifier='so')
    return o

"""Characters built from the MakeHuman base mesh (MPFB2, CC0 assets) + game_engine rig (Godot-compatible).
Clothes are offset shells of the body that share its skin weights; the head is the photo bust from lib.bust,
parented to the head bone. Poses are given as world-space aim targets per bone chain."""
import sys, math, importlib
sys.path.insert(0, '/home/claude/kf')
import bpy, bmesh, addon_utils
from mathutils import Vector, Matrix, Quaternion
import lib

_mp = {}
def mpfb():
    if not _mp:
        addon_utils.enable('bl_ext.user_default.mpfb', default_set=True)
        b = 'bl_ext.user_default.mpfb.'
        _mp['HS'] = importlib.import_module(b + 'services.humanservice').HumanService
        _mp['TS'] = importlib.import_module(b + 'services.targetservice').TargetService
    return _mp['HS'], _mp['TS']

# MakeHuman age macro: 0 -> 1y, .1875 -> 11y, .5 -> 25y, 1 -> 90y
def age01(years):
    if years <= 25: return .1875 + (years - 11) / 14 * .3125
    return .5 + (years - 25) / 65 * .5

SPEC = {
    'mio':     dict(g=.0, age=20, h=1.60, mus=.42, wt=.42, prop=.6, cup=.45),
    'natsuki': dict(g=.0, age=20, h=1.58, mus=.42, wt=.45, prop=.6, cup=.5),
    'natsuki_s': dict(g=.0, age=20, h=1.58, mus=.42, wt=.45, prop=.6, cup=.5),
    'makoto':  dict(g=.0, age=19, h=1.55, mus=.4, wt=.42, prop=.55, cup=.45),
    'kiryu':   dict(g=1., age=22, h=1.76, mus=.5, wt=.42, prop=.65),
    'taiga':   dict(g=1., age=21, h=1.83, mus=.72, wt=.68, prop=.5),
    'yota':    dict(g=1., age=21, h=1.72, mus=.5, wt=.45, prop=.6),
}

def _region(rig, mesh, bones, thresh=.45):
    """Vertex indices whose summed weight to `bones` exceeds thresh."""
    gi = {g.index: g.name for g in mesh.vertex_groups}
    out = set()
    for v in mesh.data.vertices:
        w = sum(g.weight for g in v.groups if gi.get(g.group) in bones)
        if w >= thresh: out.add(v.index)
    return out

ARM = ['clavicle_l', 'upperarm_l', 'lowerarm_l', 'clavicle_r', 'upperarm_r', 'lowerarm_r']
UPPER = ['upperarm_l', 'upperarm_r', 'clavicle_l', 'clavicle_r']
TORSO = ['spine_01', 'spine_02', 'spine_03']
LEGS = ['pelvis', 'thigh_l', 'calf_l', 'thigh_r', 'calf_r']
FEET = ['foot_l', 'ball_l', 'foot_r', 'ball_r']
HEAD = ['head']

def _shell(name, body, keep, offset, mat, rig, solid=.004, relax=0):
    """Copy of the body restricted to `keep`, pushed out along normals, sharing weights + armature."""
    me = body.data.copy(); ob = bpy.data.objects.new(name, me); lib.link(ob)
    ob.matrix_world = body.matrix_world
    for g in body.vertex_groups: pass
    bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
    kill = [v for v in bm.verts if v.index not in keep]
    bmesh.ops.delete(bm, geom=kill, context='VERTS')
    bm.normal_update()
    # straighten the zig-zag edge left by the vertex selection (hem, cuffs, collar)
    for _ in range(25):
        nb = {}
        for v in bm.verts:
            if v.is_boundary:
                ns = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
                if len(ns) == 2: nb[v] = (ns[0].co + ns[1].co) / 2
        for v, c in nb.items(): v.co = v.co.lerp(c, .5)
    bm.normal_update()
    for v in bm.verts: v.co += v.normal * offset
    for _ in range(relax):   # drape: Laplacian relax that keeps the boundary, so fabric bridges over anatomy
        bmesh.ops.smooth_vert(bm, verts=[v for v in bm.verts if not v.is_boundary], factor=.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.normal_update()
    for v in bm.verts: v.co += v.normal * offset * .3
    bm.to_mesh(me); bm.free()
    if me.shape_keys:
        ob.shape_key_clear()
    for m in list(ob.modifiers): ob.modifiers.remove(m)
    ob.data.materials.clear(); ob.data.materials.append(mat)
    am = ob.modifiers.new('rig', 'ARMATURE'); am.object = rig
    sm = ob.modifiers.new('smooth', 'CORRECTIVE_SMOOTH'); sm.iterations = 6; sm.smooth_type = 'LENGTH_WEIGHTED'
    so = ob.modifiers.new('solid', 'SOLIDIFY'); so.thickness = solid; so.offset = 1
    sd = ob.modifiers.new('sub', 'SUBSURF'); sd.levels = 1; sd.render_levels = 1
    for p in me.polygons: p.use_smooth = True
    ob.parent = rig; ob.matrix_parent_inverse = rig.matrix_world.inverted()
    return ob

def make(key, top, pants, socks, skin=(.78, .58, .47), sleeve='long', loose=1.0, label=None, open_eyes=True, head_key=None, drawn=True):
    HS, TS = mpfb()
    sp = SPEC[key]; label = label or key
    macro = TS.get_default_macro_info_dict()
    macro.update(gender=sp['g'], age=age01(sp['age']), muscle=sp['mus'], weight=sp['wt'], proportions=sp['prop'],
                 height=.5, cupsize=sp.get('cup', .5), firmness=.5)
    macro['race'] = dict(asian=1.0, caucasian=0.0, african=0.0)
    body = HS.create_human(macro_detail_dict=macro)
    body.name = f'{label}_body'
    # proportions: narrower shoulders, smaller hands, a little more neck (these read too heavy under the print)
    from bl_ext.user_default.mpfb.services.locationservice import LocationService as _LS
    troot = _LS.get_mpfb_data('targets')
    fem = sp['g'] < .5
    tweaks = [('torso/measure-shoulder-dist-decr', .8 if fem else .85), ('torso/torso-scale-horiz-decr', .25 if fem else .15),
              ('hands/l-hand-scale-decr', .7 if fem else .55), ('hands/r-hand-scale-decr', .7 if fem else .55),
              ('neck/measure-neck-height-incr', .45 if fem else .25)]
    for side in 'lr':
        tweaks.append((f'arms/{side}-upperarm-shoulder-muscle-decr', .5))
        tweaks.append((f'arms/{side}-upperarm-scale-horiz-decr', .3 if fem else .15))
    import os as _os
    for rel, wgt in tweaks:
        path = f'{troot}/{rel}.target.gz'
        if _os.path.exists(path): TS.load_target(body, path, weight=wgt, name=rel.split('/')[-1])
        else: print('missing target', rel)
    rig = HS.add_builtin_rig(body, 'game_engine'); rig.name = f'{label}_rig'
    # bake shape keys into the mesh so the shells (copies) match the deformed body
    bpy.context.view_layer.objects.active = body
    if body.data.shape_keys:
        body.shape_key_add(name='mix', from_mix=True)
        mix = body.data.shape_keys.key_blocks['mix'].data
        co = [v.co.copy() for v in mix]
        body.shape_key_clear()
        for v, c in zip(body.data.vertices, co): v.co = c
    # drop helper geometry permanently
    gi = {g.name: g.index for g in body.vertex_groups}
    if 'body' in gi:
        bm = bmesh.new(); bm.from_mesh(body.data); bm.verts.ensure_lookup_table()
        dl = body.data.vertices
        kill = [bm.verts[v.index] for v in dl if not any(g.group == gi['body'] and g.weight > .5 for g in v.groups)]
        bmesh.ops.delete(bm, geom=kill, context='VERTS'); bm.to_mesh(body.data); bm.free()
    for m in list(body.modifiers):
        if m.type == 'MASK': body.modifiers.remove(m)
    # uniform scale to target height
    bpy.context.view_layer.update()
    zs = [(body.matrix_world @ v.co).z for v in body.data.vertices]
    k = sp['h'] / (max(zs) - min(zs))
    rig.scale = (k, k, k)
    bpy.context.view_layer.update()
    # regions
    head = _region(rig, body, HEAD, .3)
    torso = _region(rig, body, TORSO + UPPER + ['neck_01'], .35) - head
    neck = _region(rig, body, ['neck_01'], .5)
    arms_lo = _region(rig, body, ['lowerarm_l', 'lowerarm_r'], .5)
    hands = _region(rig, body, ['hand_l', 'hand_r'] + [b for b in rig.data.bones.keys() if b[:-2] in ('index_01', 'index_02', 'index_03', 'middle_01', 'middle_02', 'middle_03', 'pinky_01', 'pinky_02', 'pinky_03', 'ring_01', 'ring_02', 'ring_03', 'thumb_01', 'thumb_02', 'thumb_03')], .3)
    legs = _region(rig, body, LEGS, .35)
    feet = _region(rig, body, FEET, .3)
    V = body.data.vertices
    hem = sp['h'] * .54; waist = hem + .05
    arm_all = _region(rig, body, ARM, .3) - hands
    core = {v.index for v in V if v.index not in head and v.index not in hands and v.index not in feet}
    shirt = {i for i in core if V[i].co.z * k > hem and (sleeve == 'long' or i not in arms_lo)}
    shirt -= {i for i in (_region(rig, body, ['hand_l', 'hand_r'], .08))}
    neck_line = sp['h'] * .838
    shirt = {i for i in shirt if V[i].co.z * k < neck_line}
    pants_r = {i for i in core if V[i].co.z * k < waist and i not in arm_all and i not in _region(rig, body, ['hand_l', 'hand_r', 'lowerarm_l', 'lowerarm_r'], .05)}
    ankle = sp['h'] * .055
    pants_r = {i for i in pants_r if V[i].co.z * k > ankle}
    feet = {v.index for v in V if v.co.z * k <= ankle + .01}
    # skin material on the body
    if drawn:
        skin = lib.face_skin(head_key or key)
    skm = lib.mat_basic(f'{label}_skin', skin, rough=.6, sss=.08)
    body.data.materials.clear(); body.data.materials.append(skm)
    for p in body.data.polygons: p.use_smooth = True
    _shell(f'{label}_shirt', body, shirt, .007 * loose, top, rig, .004, relax=int(6 * loose))
    _shell(f'{label}_pants', body, pants_r, .009, pants, rig, .004, relax=6)
    _shell(f'{label}_socks', body, feet, .008, socks, rig, .003, relax=40)
    # hide body under clothes, and the head (replaced by the photo bust)
    # the drawn head brings its own neck down inside the collar, so the body's neck goes too
    body_neck = {v.index for v in V if v.co.z * k > neck_line - .045 and v.index not in arm_all and v.index not in hands}
    hide = ({i for i in shirt if V[i].co.z * k < neck_line - .03} | pants_r | head | feet | (body_neck if drawn else set()))
    bm = bmesh.new(); bm.from_mesh(body.data); bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in hide if i < len(bm.verts)], context='VERTS')
    bm.to_mesh(body.data); bm.free()
    # photo bust on the head bone
    hk = head_key or key
    bust = lib.bust2(hk, name=label, ext=.075, flare=.035 if fem else .05) if drawn else lib.bust(hk, open_eyes, name=label)
    hsc = 1.0 if drawn else .93
    hb = rig.data.bones['head']
    # bone space: Y along the bone; place neck base of the bust at the head bone's head
    bust.matrix_parent_inverse = Matrix.Identity(4)
    bpy.context.view_layer.update()
    # align: bust local Z -> bone +Y, bust local -Y (face) -> body front (-Y world)
    nb = rig.data.bones['neck_01']
    mw_n = rig.matrix_world @ nb.matrix_local
    base = mw_n.translation.lerp(rig.matrix_world @ nb.tail_local, .25)
    bust.matrix_world = Matrix.Translation(base + Vector((0, .006, -.018))) @ Matrix.Diagonal((hsc, hsc, hsc, 1))
    if drawn:
        # skinned to head + neck_01 so the neck bends instead of the whole head swinging through the collar
        bpy.context.view_layer.update()
        mw = bust.matrix_world.copy()
        bust.data.transform(mw); bust.matrix_world = Matrix.Identity(4)
        hz = (rig.matrix_world @ hb.head_local).z
        gh = bust.vertex_groups.new(name='head'); gn = bust.vertex_groups.new(name='neck_01')
        for v in bust.data.vertices:
            t = min(1, max(0, (v.co.z - (hz - .035)) / .05)); t = t * t * (3 - 2 * t)
            if t > 0: gh.add([v.index], t, 'REPLACE')
            if t < 1: gn.add([v.index], 1 - t, 'REPLACE')
        bust.parent = rig; bust.matrix_parent_inverse = rig.matrix_world.inverted()
        am = bust.modifiers.new('rig', 'ARMATURE'); am.object = rig
        return rig, body
    # photo bust stays rigid with the head bone: re-parent keeping the world transform
    mw = bust.matrix_world.copy()
    bust.parent = rig; bust.parent_type = 'BONE'; bust.parent_bone = 'head'
    bpy.context.view_layer.update()
    bust.matrix_world = mw
    return rig, body

# ---------------------------------------------------------------- posing
def aim(rig, bone, world_target, roll_hint=None):
    """Rotate pose bone so its tail points at world_target (keeps its current roll as well as possible)."""
    pb = rig.pose.bones[bone]
    bpy.context.view_layer.update()
    M = rig.matrix_world @ pb.matrix
    head = M.translation
    y_now = (M.to_3x3() @ Vector((0, 1, 0))).normalized()
    y_new = (Vector(world_target) - head).normalized()
    q = y_now.rotation_difference(y_new)
    R = q.to_matrix().to_4x4()
    newM = Matrix.Translation(head) @ R @ Matrix.Translation(-head) @ M
    pb.matrix = rig.matrix_world.inverted() @ newM
    bpy.context.view_layer.update()

def twist(rig, bone, deg, axis='Y'):
    pb = rig.pose.bones[bone]; pb.rotation_mode = 'XYZ'
    r = list(pb.rotation_euler); i = 'XYZ'.index(axis); r[i] += math.radians(deg); pb.rotation_euler = r
    bpy.context.view_layer.update()

def bone_head(rig, bone):
    bpy.context.view_layer.update()
    return rig.matrix_world @ rig.pose.bones[bone].head

def bone_tail(rig, bone):
    bpy.context.view_layer.update()
    return rig.matrix_world @ rig.pose.bones[bone].tail

def arm_to(rig, side, hand_world, elbow_out=Vector((0, .15, -.3))):
    """Two-bone IK by construction: place elbow on the bend plane, aim upper then lower arm."""
    s = f'_{side}'
    sh = bone_head(rig, 'upperarm' + s)
    L1 = (bone_tail(rig, 'upperarm' + s) - sh).length
    L2 = (bone_tail(rig, 'lowerarm' + s) - bone_head(rig, 'lowerarm' + s)).length
    T = Vector(hand_world); d = T - sh; D = min(d.length, (L1 + L2) * .999); dn = d.normalized()
    a = (L1 * L1 - L2 * L2 + D * D) / (2 * D); hgt = math.sqrt(max(L1 * L1 - a * a, 0))
    pole = (rig.matrix_world.to_3x3() @ Vector(elbow_out))
    pole = (pole - dn * pole.dot(dn)).normalized()
    elbow = sh + dn * a + pole * hgt
    aim(rig, 'upperarm' + s, elbow)
    aim(rig, 'lowerarm' + s, sh + dn * D)

def leg_to(rig, side, ankle_world, knee_fwd=Vector((0, -1, 0))):
    s = f'_{side}'
    hp = bone_head(rig, 'thigh' + s)
    L1 = (bone_tail(rig, 'thigh' + s) - hp).length
    L2 = (bone_tail(rig, 'calf' + s) - bone_head(rig, 'calf' + s)).length
    T = Vector(ankle_world); d = T - hp; D = min(d.length, (L1 + L2) * .999); dn = d.normalized()
    a = (L1 * L1 - L2 * L2 + D * D) / (2 * D); hgt = math.sqrt(max(L1 * L1 - a * a, 0))
    pole = (rig.matrix_world.to_3x3() @ Vector(knee_fwd)); pole = (pole - dn * pole.dot(dn)).normalized()
    knee = hp + dn * a + pole * hgt
    aim(rig, 'thigh' + s, knee); aim(rig, 'calf' + s, hp + dn * D)

def local(rig, v):
    """Character-local offset (x right, -y forward, z up, metres) -> world point."""
    return rig.matrix_world @ (Vector(v) / rig.scale[0]) if False else rig.matrix_world.to_translation() + rig.matrix_world.to_3x3().normalized() @ Vector(v)

def relax_arms(rig):
    for s, sx in (('l', 1), ('r', -1)):
        arm_to(rig, s, local(rig, (sx * .2, -.03, .82 * rig.scale[0] / rig.scale[0])), Vector((sx * .3, .3, 0)))

def rot_world(rig, bone, axis, deg):
    """Rotate a pose bone about a world-space axis through its head."""
    pb = rig.pose.bones[bone]; bpy.context.view_layer.update()
    M = rig.matrix_world @ pb.matrix; h = M.translation
    R = Matrix.Rotation(math.radians(deg), 4, Vector(axis))
    pb.matrix = rig.matrix_world.inverted() @ (Matrix.Translation(h) @ R @ Matrix.Translation(-h) @ M)
    pb.scale = (1, 1, 1)   # the setter's decomposition leaves a little scale on bones whose rest frame is not orthonormal; it compounds
    bpy.context.view_layer.update()

def reset_pose(rig):
    for pb in rig.pose.bones:
        pb.rotation_mode = 'QUATERNION'; pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()

# ---------------------------------------------------------------- Tripo characters
TRIPO = {k: f'/home/claude/tripo/{k}_prep.blend' for k in ('natsuki', 'natsuki_s', 'mio', 'kiryu', 'taiga', 'yota', 'makoto')}   # natsuki_s: socks body (indoors)

def _base_human(key):
    """MakeHuman body + game_engine rig at the character's height, unclothed, shape keys baked (weight donor)."""
    HS, TS = mpfb()
    sp = SPEC[key]
    macro = TS.get_default_macro_info_dict()
    macro.update(gender=sp['g'], age=age01(sp['age']), muscle=sp['mus'], weight=sp['wt'], proportions=sp['prop'],
                 height=.5, cupsize=sp.get('cup', .5), firmness=.5)
    macro['race'] = dict(asian=1.0, caucasian=0.0, african=0.0)
    body = HS.create_human(macro_detail_dict=macro)
    rig = HS.add_builtin_rig(body, 'game_engine')
    bpy.context.view_layer.objects.active = body
    if body.data.shape_keys:
        body.shape_key_add(name='mix', from_mix=True)
        co = [v.co.copy() for v in body.data.shape_keys.key_blocks['mix'].data]
        body.shape_key_clear()
        for v, c in zip(body.data.vertices, co): v.co = c
    gi = {g.name: g.index for g in body.vertex_groups}
    if 'body' in gi:
        bm = bmesh.new(); bm.from_mesh(body.data); bm.verts.ensure_lookup_table()
        kill = [bm.verts[v.index] for v in body.data.vertices if not any(g.group == gi['body'] and g.weight > .5 for g in v.groups)]
        bmesh.ops.delete(bm, geom=kill, context='VERTS'); bm.to_mesh(body.data); bm.free()
    for m in list(body.modifiers):
        if m.type == 'MASK': body.modifiers.remove(m)
    bpy.context.view_layer.update()
    zs = [(body.matrix_world @ v.co).z for v in body.data.vertices]
    k = sp['h'] / (max(zs) - min(zs)); rig.scale = (k, k, k)
    bpy.context.view_layer.update()
    return rig, body

def _apply_pose_as_rest(rig, meshes):
    for ob in meshes:
        bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
        for m in list(ob.modifiers):
            if m.type == 'ARMATURE': bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='POSE'); bpy.ops.pose.select_all(action='SELECT'); bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode='OBJECT')

CUT_WEB = False   # only for generations where the sleeve came out fused to the body (free-plan Natsuki)
ARM_CHAIN = ('clavicle', 'upperarm', 'lowerarm', 'hand', 'thumb', 'index', 'middle', 'ring', 'pinky')

def _transfer_weights_gated(donor, target, rig, k=4):
    bones = set(rig.data.bones.keys())
    """Copy skin weights from the MakeHuman donor (posed to match) onto the generated mesh. Nearest-surface alone
    lets a hand hanging beside the jeans grab the thigh, so below the armpit every target vertex is first sorted
    into 'arm' or 'not arm' by the gap between arm and body in the front view, and only searches donor vertices
    of the same kind. Weights are the inverse-distance blend of the k nearest donor vertices."""
    from mathutils.kdtree import KDTree
    import numpy as np
    gname = {g.index: g.name for g in donor.vertex_groups}
    dmw = donor.matrix_world
    dv = []
    for v in donor.data.vertices:
        ws = {gname[g.group]: g.weight for g in v.groups if g.weight > 1e-3 and gname[g.group] in bones}
        if not ws: continue
        top = max(ws, key=ws.get)
        dv.append((dmw @ v.co, ws, top.split('_')[0] in ARM_CHAIN))
    trees = {}
    for kind in (True, False, None):
        sub = [d for d in dv if kind is None or d[2] == kind]
        t = KDTree(len(sub))
        for i, d in enumerate(sub): t.insert(d[0], i)
        t.balance(); trees[kind] = (t, sub)
    tmw = target.matrix_world
    P = np.array([tuple(tmw @ v.co) for v in target.data.vertices])
    # below the armpit, the hanging arms are separate pieces of the surface from the torso and legs:
    # split the mesh there and take the connected pieces that sit where the donor's arms are
    DA = np.array([tuple(d[0]) for d in dv if d[2]])
    armpit = float(np.percentile(DA[:, 2], 97)) - .12
    below = P[:, 2] < armpit
    adj = [[] for _ in P]
    for e in target.data.edges:
        a_, b_ = e.vertices
        if below[a_] and below[b_]: adj[a_].append(b_); adj[b_].append(a_)
    # the imported mesh is split along its UV seams: stitch coincident vertices back together for the walk
    from mathutils.kdtree import KDTree as _KD0
    kd0 = _KD0(len(P))
    for i, q in enumerate(P): kd0.insert(q, i)
    kd0.balance()
    for i, q in enumerate(P):
        if not below[i]: continue
        for _, j, _ in kd0.find_range(q, .0012):
            if j != i and below[j]: adj[i].append(j)
    # the arms touch the body somewhere (hand on the hip, sleeve on the sweater), so split by walking distance
    # over the surface instead: from seeds on the forearms and seeds on the torso/legs, whichever is nearer wins
    import heapq
    def seeds(points, r):
        out = set()
        for q in points:
            for _, j, _ in kd0.find_range(q, r):
                if below[j]: out.add(j)
        return out
    def seg(b_, ts):
        h = rig.matrix_world @ rig.data.bones[b_].head_local; t = rig.matrix_world @ rig.data.bones[b_].tail_local
        return [h.lerp(t, x) for x in ts]
    arm_seed = seeds([q for s_ in 'lr' for q in seg(f'lowerarm_{s_}', (.3, .6, .9)) + seg(f'hand_{s_}', (.5,))], .055)
    arm_seed |= seeds([q for s_ in 'lr' for q in seg(f'upperarm_{s_}', (.55, .75, .95))], .035)
    body_seed = seeds([q for s_ in 'lr' for q in seg(f'thigh_{s_}', (.1, .3, .5, .7, .9)) + seg(f'calf_{s_}', (.2, .5, .8))]
                      + seg('spine_01', (.2, .6)) + seg('pelvis', (.5,)), .115)
    # the whole front and back of the torso (well inside the arms) also counts as body
    sp_z = (rig.matrix_world @ rig.data.bones['spine_01'].head_local).z
    body_seed |= {i for i in range(len(P)) if below[i] and abs(P[i][0]) < .12 and P[i][2] > sp_z - .1}
    print('seeds', len(arm_seed), len(body_seed), 'overlap', len(arm_seed & body_seed))
    arm_seed -= body_seed
    INF = 1e9
    def dijkstra(src):
        d = np.full(len(P), INF); h = []
        for i in src: d[i] = 0; h.append((0.0, i))
        heapq.heapify(h)
        while h:
            du, u = heapq.heappop(h)
            if du > d[u]: continue
            for w_ in adj[u]:
                nd = du + float(np.linalg.norm(P[u] - P[w_]))
                if nd < d[w_]: d[w_] = nd; heapq.heappush(h, (nd, w_))
        return d
    dA = dijkstra(arm_seed); dB = dijkstra(body_seed)
    arm = below & (dA < dB)
    # clean up stray islands: a few rounds of majority vote among surface neighbours
    for _ in range(12):
        new = arm.copy()
        for i in range(len(P)):
            if not below[i] or not adj[i]: continue
            v = sum(1 for j in adj[i] if arm[j]) / len(adj[i])
            if v > .6: new[i] = True
            elif v < .4: new[i] = False
        arm = new
    # whole islands (after the vote) that are tiny compared to their side's arm go to the other label
    lab = -np.ones(len(P), int); n_isl = 0; sizes = []
    for i in range(len(P)):
        if not below[i] or lab[i] >= 0: continue
        st = [i]; lab[i] = n_isl; cnt = 0
        while st:
            u = st.pop(); cnt += 1
            for j in adj[u]:
                if lab[j] < 0 and arm[j] == arm[i]: lab[j] = n_isl; st.append(j)
        sizes.append(cnt); n_isl += 1
    sizes = np.array(sizes)
    for c in np.where(sizes < 400)[0]:
        m = lab == c; arm[m] = ~arm[m]
    print('arm vertices', int(arm.sum()), 'armpit z', round(armpit, 3))
    names = set()
    for d in dv: names |= set(d[1])
    for n in names:
        if n not in target.vertex_groups: target.vertex_groups.new(name=n)
    G = {g.name: g for g in target.vertex_groups}
    W = []
    for i, p in enumerate(P):
        kind = None if p[2] > armpit + .02 else bool(arm[i])
        t, sub = trees[kind]
        acc = {}; tot = 0.0
        for co, j, dist in t.find_n(p, k):
            w = 1.0 / (dist + .004); tot += w
            for n, x in sub[j][1].items(): acc[n] = acc.get(n, 0) + w * x
        W.append({n: x / tot for n, x in acc.items()})
    # smooth the weights along the surface (not across the arm/body gap), so neighbours move together
    nb = [[] for _ in P]
    for e in target.data.edges:
        a_, b_ = e.vertices
        if arm[a_] == arm[b_] or P[a_][2] > armpit + .02: nb[a_].append(b_); nb[b_].append(a_)
    # the import split the surface along its UV seams; the two sides of a seam must carry the same weights
    weld = [[j for _, j, _ in kd0.find_range(q, .0012) if j != i] for i, q in enumerate(P)]
    for i in range(len(P)):
        for j in weld[i]:
            if j not in nb[i] and (arm[i] == arm[j] or P[i][2] > armpit + .02): nb[i].append(j)
    for _ in range(24):
        W2 = []
        for i, w in enumerate(W):
            if not nb[i]: W2.append(w); continue
            acc = {n: x * .5 for n, x in w.items()}
            f = .5 / len(nb[i])
            for j in nb[i]:
                for n, x in W[j].items(): acc[n] = acc.get(n, 0) + x * f
            W2.append(acc)
        W = W2
    W3 = []
    for i, w in enumerate(W):
        grp = [i] + weld[i]; acc = {}
        for j in grp:
            for n, x in W[j].items(): acc[n] = acc.get(n, 0) + x / len(grp)
        W3.append(acc)
    W = W3
    for i, w in enumerate(W):
        tot = sum(w.values())
        for n, x in w.items():
            if x / tot > .01: G[n].add([i], x / tot, 'REPLACE')
    # where the generator fused the sleeve to the side of the sweater, the surface between them would stretch into
    # a sheet when the arm lifts: cut those faces out
    bm = bmesh.new(); bm.from_mesh(target.data); bm.faces.ensure_lookup_table()
    web = [f for f in bm.faces if all(below[v.index] for v in f.verts) and len({bool(arm[v.index]) for v in f.verts}) > 1] if CUT_WEB else []
    bmesh.ops.delete(bm, geom=web, context='FACES_ONLY')
    bm.to_mesh(target.data); bm.free()
    print('cut web faces', len(web))

def make_tripo(key, label=None):
    """Character from Tripo meshes (prepared by tripo/prep_<key>.py), rigged with the same game_engine skeleton as
    the MakeHuman characters so every pose function works unchanged. Returns (rig, body)."""
    label = label or key
    rig, donor = _base_human(key)
    rig.name = f'{label}_rig'
    with bpy.data.libraries.load(TRIPO[key]) as (src, dst):
        dst.objects = [n for n in src.objects if n.startswith(key)]
    parts = {}
    for o in dst.objects:
        lib.link(o); parts[o.name] = o
    body = parts[f'{key}_body']; hair = parts[f'{key}_hair']; face = parts[f'{key}_head']
    bpy.context.view_layer.update()
    # match the skeleton to the generated pose: wrists and ankles where the mesh has them
    V = [v.co for v in body.data.vertices]
    for s, sx in (('l', 1), ('r', -1)):
        # the hand: outermost vertices below the sweater cuff (the jeans stop short of it in x)
        Hh = max(c.z for c in V)
        xm = max(sx * c.x for c in V if .35 * Hh < c.z < .65 * Hh)
        hv = [c for c in V if sx * c.x > .8 * xm and .3 * Hh < c.z < .65 * Hh]
        tip = min(c.z for c in hv)
        wz = tip + .15
        band = [c for c in hv if abs(c.z - wz) < .012]
        print('wrist', s, round(tip, 3), tuple(round(x, 3) for x in sum(band, Vector()) / len(band)))
        wrist = sum(band, Vector()) / len(band)
        arm_to(rig, s, wrist, Vector((sx * .3, .3, 0)))
        fv = [c for c in V if sx * c.x > .02 and c.z < .12]
        ank = sum((c for c in fv if c.z > .07), Vector()) / max(1, len([c for c in fv if c.z > .07]))
        leg_to(rig, s, Vector((ank.x, bone_head(rig, f'foot_{s}').y, bone_head(rig, f'foot_{s}').z)))
    bpy.context.view_layer.update()
    _apply_pose_as_rest(rig, [donor])
    _transfer_weights_gated(donor, body, rig)
    hz = bone_head(rig, 'head').z; nz = bone_head(rig, 'neck_01').z
    for ob in (hair, face):
        gh = ob.vertex_groups.new(name='head'); gn = ob.vertex_groups.new(name='neck_01'); gs = ob.vertex_groups.new(name='spine_03')
        for v in ob.data.vertices:
            z = v.co.z
            th = min(1, max(0, (z - (hz - .045)) / .05)); th = th * th * (3 - 2 * th)
            ts = min(1, max(0, (nz + .01 - z) / .04))
            if th > 0: gh.add([v.index], th, 'REPLACE')
            rest = 1 - th
            if rest > 0:
                gn.add([v.index], rest * (1 - ts), 'REPLACE')
                if ts > 0: gs.add([v.index], rest * ts, 'REPLACE')
    for ob in (body, hair, face):
        ob.name = {body: f'{label}_body', hair: f'{label}_hair', face: f'{label}_head'}[ob]
        mw = ob.matrix_world.copy(); ob.parent = rig; ob.matrix_world = mw
        am = ob.modifiers.new('rig', 'ARMATURE'); am.object = rig
    bpy.data.objects.remove(donor)
    return rig, body

# ---------------------------------------------------------------- hands
FINGERS = ('index', 'middle', 'ring', 'pinky')

def grip(rig, side, amount=1.0, thumb=.6):
    """Curl the fingers (0 = open, 1 = closed fist). Rotates each finger joint about its local X."""
    s = f'_{side}'
    for f in FINGERS:
        for j, deg in (('01', 55), ('02', 70), ('03', 45)):
            pb = rig.pose.bones.get(f'{f}_{j}{s}')
            if pb is None: continue
            pb.rotation_mode = 'XYZ'
            pb.rotation_euler.x += math.radians(deg * amount)
    for j, deg in (('01', 20), ('02', 35), ('03', 25)):
        pb = rig.pose.bones.get(f'thumb_{j}{s}')
        if pb is None: continue
        pb.rotation_mode = 'XYZ'
        pb.rotation_euler.x += math.radians(deg * amount * thumb)

def hand_frame(rig, side):
    """World matrix of the hand bone (origin at the wrist; Y along the bone toward the fingers)."""
    bpy.context.view_layer.update()
    return rig.matrix_world @ rig.pose.bones[f'hand_{side}'].matrix

def place_in_hand(ob, rig, side, offset=(0, .07, 0), rot=(0, 0, 0)):
    """Put an object in the palm: offset and rotation are in the hand bone's frame (Y toward the fingers,
    Z out of the back of the hand, X across the palm)."""
    m = hand_frame(rig, side) @ Matrix.Translation(Vector(offset)) @ __import__('mathutils').Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()
    ob.matrix_world = m @ Matrix.Diagonal((*ob.scale, 1))   # keep the object's own size

def phone(name, screen_k, strength):
    """A phone: dark body, the screen a bright plane on its -Y face (the face that lands palm-outward in place_in_hand)."""
    from lib import prim, mat_basic
    body = prim('cube', name, loc=(0, 0, 0), scale=(.034, .004, .072), mat=mat_basic(name + '_body', (.05, .05, .06), .35))
    body.visible_shadow = False
    scr = prim('plane', name + '_scr', loc=(0, -1.02, 0), rot=(math.radians(90), 0, 0), scale=(.9, .92, 1),
               mat=mat_basic(name + '_glow', (.6, .8, 1), .3, emit=screen_k, estr=strength))
    scr.visible_shadow = False
    scr.parent = body   # local to the body, so the cube's scale (0.034, 0.004, 0.072) applies
    return body

def wet(rig, tint=(.45, .45, .5), rough=.3):
    """Rain-soaked: every Tripo material on this character gets darker and shinier (the tint is baked on export)."""
    for ob in rig.children_recursive:
        if ob.type != 'MESH': continue
        for m in ob.data.materials:
            if m is None or not m.use_nodes: continue
            p = m.node_tree.nodes.get('Principled BSDF')
            if p is None: continue
            p.inputs['Roughness'].default_value = rough
            src = p.inputs['Base Color'].links[0].from_node if p.inputs['Base Color'].links else None
            if src is None or src.type != 'TEX_IMAGE': continue
            mix = m.node_tree.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'; mix.inputs['Factor'].default_value = 1.0
            mix.inputs['B'].default_value = (*tint, 1)
            m.node_tree.links.new(src.outputs['Color'], mix.inputs['A']); m.node_tree.links.new(mix.outputs['Result'], p.inputs['Base Color'])

def socks(rig, color=(.86, .86, .83), ankle=.10):
    """Indoors nobody wears shoes: the shoe part of the Tripo body texture (everything below the ankle) is repainted as
    a plain sock, keeping the baked shading. Writes <image>_socks.png next to the Tripo texture."""
    from PIL import Image, ImageDraw
    import numpy as np
    for ob in rig.children_recursive:
        if ob.type != 'MESH' or not ob.name.endswith('_body'): continue
        me = ob.data; uv = me.uv_layers[0]
        for m in ob.data.materials:
            if m is None or not m.use_nodes: continue
            p = m.node_tree.nodes.get('Principled BSDF')
            src = p.inputs['Base Color'].links[0].from_node if p and p.inputs['Base Color'].links else None
            if src is None or src.type != 'TEX_IMAGE': continue
            img = src.image; w, h = img.size
            mask = Image.new('L', (w, h), 0); dr = ImageDraw.Draw(mask)
            n = 0
            for poly in me.polygons:
                if all(me.vertices[vi].co.z < ankle for vi in poly.vertices):
                    pts = [(uv.data[li].uv.x * w, (1 - uv.data[li].uv.y) * h) for li in poly.loop_indices]
                    dr.polygon(pts, fill=255, outline=255); n += 1
            if n == 0: continue
            buf = np.empty(w * h * 4, np.float32); img.pixels.foreach_get(buf); px = buf.reshape(h, w, 4)
            mk = np.asarray(mask, np.float32)[::-1] / 255        # blender rows start at the bottom
            lum = px[..., :3].mean(2, keepdims=True)
            ref = np.median(lum[mk > .5]) if (mk > .5).any() else .5
            sock = np.clip(np.array(color, np.float32) * np.clip(lum / max(ref, 1e-3), .55, 1.12), 0, 1)
            px[..., :3] = px[..., :3] * (1 - mk[..., None]) + sock * mk[..., None]
            name = img.name.rsplit('.', 1)[0] + '_socks'
            im = bpy.data.images.new(name, w, h, alpha=False); im.pixels.foreach_set(px.ravel())
            im.filepath_raw = f'/home/claude/tripo/{name}.png'; im.file_format = 'PNG'; im.save()
            src.image = im
            print(f'socks: {ob.name} {n} shoe polys repainted')

def palm_to(rig, side, target):
    """Turn the forearm (hand roll) so the palm faces the world point `target` as far as the forearm axis allows."""
    bpy.context.view_layer.update()
    M = hand_frame(rig, side); R = M.to_3x3().normalized()
    axis = R @ Vector((0, 1, 0)); palm = -(R @ Vector((0, 0, 1)))
    want = Vector(target) - M.translation
    palm -= axis * palm.dot(axis); want -= axis * want.dot(axis)
    if palm.length < 1e-6 or want.length < 1e-6: return
    ang = math.degrees(palm.normalized().angle(want.normalized()))
    if palm.cross(want).dot(axis) < 0: ang = -ang
    rot_world(rig, f'lowerarm_{side}', axis, ang * .55)      # share the twist between forearm and hand
    rot_world(rig, f'hand_{side}', axis, ang * .45)

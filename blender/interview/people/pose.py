"""Seiza on the interviewer's zabuton. args: hip_y lean hands(table|lap) out.blend"""
import sys, math
sys.path.insert(0, '/home/user/notlw/blender')
import bpy
from mathutils import Vector
import chars as C
a = sys.argv[sys.argv.index('--') + 1:]
HIP_Y = float(a[0]); LEAN = float(a[1]); HANDS = a[2]; OUT = a[3]
import os
KEY = os.environ.get('KEY', 'kikite')   # kikite on the north zabuton; mio is posed the same way and turned to face her
bpy.ops.wm.open_mainfile(filepath=f'/home/claude/work/kikite/{KEY}_rest.blend')
rig = bpy.data.objects[f'{KEY}_rig']
ZAB = 0.08; HIP_Z = ZAB + 0.22

def glasses():
    """thin metal frames (the user: not through Tripo). Built in the rest pose on the measured head, bone-parented to head"""
    EZ = 1.463; LY = -0.047; CX = 0.032; W = 0.046; Hh = 0.031; FACE = math.radians(7)
    mat = bpy.data.materials.new('kikite_glasses_metal'); p = mat.node_tree.nodes['Principled BSDF']
    p.inputs['Base Color'].default_value = (0.20, 0.16, 0.11, 1); p.inputs['Metallic'].default_value = 1.0; p.inputs['Roughness'].default_value = 0.3
    gl = bpy.data.materials.new('kikite_glasses_lens'); q = gl.node_tree.nodes['Principled BSDF']
    q.inputs['Base Color'].default_value = (1, 1, 1, 1); q.inputs['Transmission Weight'].default_value = 1.0; q.inputs['Roughness'].default_value = 0.0; q.inputs['IOR'].default_value = 1.05
    q.inputs['Alpha'].default_value = 0.12
    def curve(name, pts, r, closed=False):
        cu = bpy.data.curves.new(name, 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = r; cu.bevel_resolution = 2
        sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1)
        for i, P in enumerate(pts): sp.points[i].co = (*P, 1)
        sp.use_cyclic_u = closed
        o = bpy.data.objects.new(name, cu); bpy.context.scene.collection.objects.link(o); cu.materials.append(mat); return o
    def rim(sx):
        pts = []; ring = []
        for i in range(48):
            t = i / 48 * math.tau; c, s_ = math.cos(t), math.sin(t)
            x = W / 2 * math.copysign(abs(c) ** (2 / 3.2), c); z = Hh / 2 * math.copysign(abs(s_) ** (2 / 3.2), s_)
            z -= 0.003 * (1 - (x / (W / 2)) ** 2) * (1 if z < 0 else 0)   # a softer lower line
            xr = x * math.cos(FACE); yr = -sx * x * math.sin(FACE)        # face form: outer ends sweep back
            P = Vector((sx * CX + sx * xr, LY + yr, EZ + z)); pts.append(P); ring.append(P)
        o = curve(f'kikite_glasses_rim_{"l" if sx > 0 else "r"}', pts, 0.0009, True)
        # the lens: a fan inside the rim
        me = bpy.data.meshes.new('lens'); cen = sum(ring, Vector()) / len(ring)
        me.from_pydata([cen] + ring, [], [(0, 1 + i, 1 + (i + 1) % len(ring)) for i in range(len(ring))]); me.materials.append(gl)
        lo = bpy.data.objects.new(f'kikite_glasses_lens_{"l" if sx > 0 else "r"}', me); bpy.context.scene.collection.objects.link(lo)
        return o, lo, max(ring, key=lambda P: sx * P.x)
    obs = []
    hinge = {}
    for sx in (1, -1):
        o, lo, outer = rim(sx); obs += [o, lo]; hinge[sx] = outer + Vector((0, 0, Hh * 0.25))
    # bridge over the nose and two little pads
    obs.append(curve('kikite_glasses_bridge', [Vector((-CX + W / 2 - .002, LY, EZ + .009)), Vector((0, LY - .002, EZ + .012)), Vector((CX - W / 2 + .002, LY, EZ + .009))], 0.0008))
    # temples: back over the ears, then down behind them
    for sx in (1, -1):
        h = hinge[sx]
        pts = [h, h + Vector((sx * .003, .006, 0)), Vector((sx * .0745, .010, EZ + .006)), Vector((sx * .0835, .035, EZ + .004)),
               Vector((sx * .0895, .056, EZ + .0)), Vector((sx * .0885, .068, EZ - .012)), Vector((sx * .084, .074, EZ - .030))]
        obs.append(curve(f'kikite_glasses_temple_{"l" if sx > 0 else "r"}', pts, 0.0007))
    for o in obs:
        o.parent = rig; o.parent_type = 'BONE'; o.parent_bone = 'head'
        o.matrix_parent_inverse = (rig.matrix_world @ rig.pose.bones['head'].matrix @ __import__('mathutils').Matrix.Translation((0, rig.pose.bones['head'].length, 0))).inverted()
    bpy.context.view_layer.update()
if KEY == 'kikite': glasses()

import numpy as np
HAXES = {}
def measure_hand_axes():
    hm = bpy.data.objects[f'{KEY}_hands']; mw = hm.matrix_world
    P = np.array([tuple(mw @ v.co) for v in hm.data.vertices])
    for side, sx in (('l', 1), ('r', -1)):
        B = (rig.matrix_world @ rig.pose.bones[f'hand_{side}'].matrix); h = np.array(B.translation); R = B.to_3x3().normalized()
        Q = P[(P[:, 0] * sx) > 0.05]
        y = np.array(R @ Vector((0, 1, 0)))
        t = (Q - h) @ y; Q = Q[t > 0.03]; t = t[t > 0.03]
        far = Q[t > np.percentile(t, 95)].mean(0); f = far - h; f /= np.linalg.norm(f)
        Qc = Q - Q.mean(0); _, _, vt = np.linalg.svd(Qc, full_matrices=False); n = vt[2]
        n = n - f * n.dot(f); n /= np.linalg.norm(n)
        if n[0] * (-sx) < 0: n = -n          # A-pose: the palm faces the thigh, toward the midline
        Ri = R.inverted()
        HAXES[side] = (Ri @ Vector(f), Ri @ Vector(n))
        print('hand axes', side, 'finger', np.round(f, 2), 'palm', np.round(n, 2))
measure_hand_axes()
for sd in ('l','r'):
    print('hand length', sd, round((C.bone_head(rig, f'hand_{sd}') - C.finger_tips(rig, sd)['middle']).length, 3))
def orient_hand(side, fd, pn):
    fl, nl = HAXES[side]
    def frame(a, b):
        a = a.normalized(); b = (b - a * b.dot(a)).normalized(); c = a.cross(b)
        return Matrix((a, b, c)).transposed()
    from mathutils import Matrix
    Rn = frame(Vector(fd), Vector(pn)) @ frame(fl, nl).inverted()
    pb = rig.pose.bones[f'hand_{side}']; bpy.context.view_layer.update()
    h = (rig.matrix_world @ pb.matrix).translation
    pb.matrix = rig.matrix_world.inverted() @ (Matrix.Translation(h) @ Rn.to_4x4())
    pb.scale = (1, 1, 1); bpy.context.view_layer.update()
_elb = [float(x) for x in __import__('os').environ.get('ELB', '0.4,0.3,-0.2').split(',')]
def ELB(sx): return Vector((sx * _elb[0], _elb[1], _elb[2]))   # where the elbows point (rig space: out, back, down)
def forearm_dir(side):
    d = C.bone_head(rig, f'hand_{side}') - C.bone_head(rig, f'lowerarm_{side}'); d.z = 0; return d.normalized()
h0 = C.bone_head(rig, 'thigh_l'); h1 = C.bone_head(rig, 'thigh_r'); hc = (h0 + h1) / 2
rig.location = Vector((0, HIP_Y, HIP_Z)) - hc; bpy.context.view_layer.update()
# legs: knees forward on the cushion, ankles under the seat, insteps flat on the cushion, toes pointing back
for s, sx in (('l', 1), ('r', -1)):
    hp = C.bone_head(rig, f'thigh_{s}')
    ank = Vector((sx * 0.075, HIP_Y + 0.05, ZAB + 0.05))
    C.leg_to(rig, s, ank, knee_fwd=Vector((0, -1, -0.35)))
    an = C.bone_head(rig, f'foot_{s}')
    C.aim(rig, f'foot_{s}', an + Vector((sx * -0.01, 0.13, -0.045)))
    C.aim(rig, f'ball_{s}', C.bone_tail(rig, f'foot_{s}') + Vector((0, 0.05, -0.005)))
    print('knee', s, tuple(round(x, 3) for x in C.bone_head(rig, f'calf_{s}')), 'ankle', tuple(round(x, 3) for x in C.bone_head(rig, f'foot_{s}')))
# the back: a slight lean toward the table, the head bowed a little over it
if HANDS == 'pinch': LEAN = max(LEAN, 32)
if HANDS == 'stroke': LEAN = max(LEAN, 40)
if HANDS == 'write':
    LEAN = max(LEAN, 34)
    for b_, dg in (('spine_01', 6), ('spine_02', 5), ('spine_03', 4)): C.rot_world(rig, b_, (0, 0, 1), dg)   # turned a little toward the notebook
C.rot_world(rig, 'spine_01', (1, 0, 0), LEAN * .5)
C.rot_world(rig, 'spine_02', (1, 0, 0), LEAN * .3)
C.rot_world(rig, 'spine_03', (1, 0, 0), LEAN * .2)
C.rot_world(rig, 'head', (1, 0, 0), 7)
if HANDS == 'table':
    # photo 1 (right hand resting on the tape, palm down, fingers relaxed) and photo 4's left hand (flat on the notebook)
    from mathutils import Matrix
    def hand_pose(side, wrist, fdir, curls, sx, roll, pitch):
        ps = C.palm_sign(rig, side)
        if fdir is None:   # the hand straight on from the forearm (no bend inward at the wrist)
            C.arm_to(rig, side, Vector(wrist), ELB(sx)); fdir = forearm_dir(side)
        fd = Vector(fdir).normalized()
        side_ax = fd.cross(Vector((0, 0, 1))).normalized()
        fd = Matrix.Rotation(math.radians(-pitch), 3, side_ax) @ fd          # pitch: fingers tipped down toward the surface
        zd = Matrix.Rotation(math.radians(roll), 3, fd) @ Vector((0, 0, -ps))
        C.arm_to(rig, side, Vector(wrist), ELB(sx)); orient_hand(side, fd, Matrix.Rotation(math.radians(roll), 3, fd) @ Vector((0, 0, -1)))
        R = (rig.matrix_world @ rig.pose.bones[f'hand_{side}'].matrix).to_3x3().normalized(); palm = (R @ HAXES[side][1]).normalized()
        for f, c in zip(('index', 'middle', 'ring', 'pinky', 'thumb'), curls):
            for jn, deg in zip(('01', '02', '03'), (20, 30, 20) if f == 'thumb' else (40, 35, 20)):
                b = f'{f}_{jn}_{side}'; bpy.context.view_layer.update()
                M = rig.matrix_world @ rig.pose.bones[b].matrix; fdir = (M.to_3x3() @ Vector((0, 1, 0))).normalized()
                ax = fdir.cross(palm)
                if ax.length > 1e-6: C.rot_world(rig, b, ax.normalized(), deg * c)
        # fingers closer together than the rest pose's splay (photo 1: relaxed, only slightly apart)
        for f, a in (('index', 6), ('ring', -8), ('pinky', -16)):
            C.rot_world(rig, f'{f}_01_{side}', palm * (1 if side == 'r' else -1), a)
        # the thumb: relaxed beside the index, swung a little away from it and lowered toward the table (photo 1)
        C.rot_world(rig, f'thumb_01_{side}', palm * (1 if side == 'r' else -1), THUMB_OUT)
        for jn, dg in (('01', 6), ('02', 10), ('03', 12)):
            C.rot_world(rig, f'thumb_{jn}_{side}', (C.bone_tail(rig, f'thumb_{jn}_{side}') - C.bone_head(rig, f'thumb_{jn}_{side}')).normalized().cross(palm).normalized(), dg)
        for _ in range(12):   # never into the table: lift the thumb from its base until its tip clears the top
            tip = C.bone_tail(rig, f'thumb_03_{side}')
            if tip.z > 0.336: break
            v = (tip - C.bone_head(rig, f'thumb_01_{side}')).normalized(); ax = v.cross(Vector((0, 0, 1)))
            if ax.length < 1e-6: break
            C.rot_world(rig, f'thumb_01_{side}', ax.normalized(), 3)
        return C.finger_tips(rig, side)
    THUMB_OUT = float(__import__('os').environ.get('THUMB_OUT', '-8'))
    # テープは8ミリ（95×62.5×15mm、2026-11-17）：上の面は 0.33+0.015。手はその上に置く
    TT = 0.345
    POSE = {'r': dict(wrist=[-0.146, 0.562, TT + 0.003], fdir=(0.35, -1, 0), curls=(.0, .02, .05, .1, .0), sx=-1, roll=0, pitch=6, surf=TT, thumb=(-0.048, 0.48, 0.356)),
            'l': dict(wrist=[0.230, 0.540, 0.356], fdir=None, curls=(.08, .1, .12, .16, .0), sx=1, roll=0, pitch=0, surf=0.336, thumb=(0.100, 0.53, 0.352))}
    THUMB = {k: v['thumb'] for k, v in POSE.items()}
    for side, P in POSE.items():
        P['roll'] = 0
        for it in range(3):
            tips = hand_pose(side, P['wrist'], P['fdir'], P['curls'], P['sx'], P['roll'], P['pitch'])
            low = min(t.z for k, t in tips.items() if k != 'thumb')
            a, b_ = tips['index'], tips['pinky']
            print('hand', side, it, 'index-pinky dz', round(b_.z - a.z, 3), 'lowest', round(low, 3), 'palm z', round(C.palm_dir(rig, side).z, 2))
            P['wrist'][2] += max(0.0, P['surf'] + 0.006 - low)
        print('tips', side, {k: tuple(round(x, 3) for x in v) for k, v in tips.items()})
# ---- the other hand frames (photos 2-4): the right hand changes, the left stays on the notebook
elif HANDS in ('pinch', 'stroke', 'write'):
    from mathutils import Matrix
    import os as _os_
    side = 'r'
    def palm_now():
        R = (rig.matrix_world @ rig.pose.bones['hand_r'].matrix).to_3x3().normalized(); return (R @ HAXES['r'][1]).normalized()
    def curl(f, amt, degs=(40, 35, 20)):
        palm = palm_now(); bpy.context.view_layer.update()
        # one hinge axis per finger, taken before it bends: after a big first bend the bone points along the palm normal and fdir x palm vanishes
        M = rig.matrix_world @ rig.pose.bones[f'{f}_01_r'].matrix; fdir = (M.to_3x3() @ Vector((0, 1, 0))).normalized()
        ax = fdir.cross(palm)
        if ax.length < 1e-6: return
        ax = ax.normalized()
        for jn, deg in zip(('01', '02', '03'), degs):
            C.rot_world(rig, f'{f}_{jn}_r', ax, deg * amt)
    def reset_r():
        for b in rig.pose.bones:
            if b.name.endswith('_r') and any(b.name.startswith(p) for p in ('upperarm', 'lowerarm', 'hand', 'thumb', 'index', 'middle', 'ring', 'pinky')):
                b.rotation_quaternion = (1, 0, 0, 0); b.scale = (1, 1, 1); b.location = (0, 0, 0); b.rotation_euler = (0, 0, 0)
        bpy.context.view_layer.update()
    def aim_thumb(T, flex=(0, 8, 10), bend_first=False):
        def aim_():
            for _ in range(3 if bend_first else 1):
                h1 = C.bone_head(rig, 'thumb_01_r'); t3 = C.bone_tail(rig, 'thumb_03_r'); a_ = t3 - h1; b_ = Vector(T) - h1
                if a_.cross(b_).length > 1e-6: C.rot_world(rig, 'thumb_01_r', a_.cross(b_).normalized(), math.degrees(a_.angle(b_)))
        def bend_():
            palm = palm_now()
            for jn, dg in zip(('01', '02', '03'), flex):
                if dg: C.rot_world(rig, f'thumb_{jn}_r', (C.bone_tail(rig, f'thumb_{jn}_r') - C.bone_head(rig, f'thumb_{jn}_r')).normalized().cross(palm).normalized(), dg)
        # bend_first (つまむ、2026-11-19): the thumb is longer than the way from its base to the tape's near edge, so it
        # bends at its joints first and then swings to the edge; aimed first, its tip went past the edge into the table
        if bend_first:
            # CCD over the three thumb bones from a bent start: the tip reaches the edge without leaving the joints straight
            bend_()
            for _ in range(12):
                for jn in ('03', '02', '01'):
                    b = f'thumb_{jn}_r'; h = C.bone_head(rig, b); t3 = C.bone_tail(rig, 'thumb_03_r'); a_ = t3 - h; b_ = Vector(T) - h
                    if a_.cross(b_).length > 1e-7: C.rot_world(rig, b, a_.cross(b_).normalized(), min(25.0, math.degrees(a_.angle(b_))))
        else: aim_(); bend_()
    def aim_finger(f, T, flex=(30, 25)):
        palm = palm_now()
        for jn, dg in zip(('02', '03'), flex):
            b = f'{f}_{jn}_r'; d_ = (C.bone_tail(rig, b) - C.bone_head(rig, b)).normalized(); ax = d_.cross(palm)
            if ax.length > 1e-6 and dg: C.rot_world(rig, b, ax.normalized(), dg)
        for _ in range(3):
            h1 = C.bone_head(rig, f'{f}_01_r'); tip = C.bone_tail(rig, f'{f}_03_r'); a_ = tip - h1; b_ = Vector(T) - h1
            if a_.cross(b_).length < 1e-7: break
            C.rot_world(rig, f'{f}_01_r', a_.cross(b_).normalized(), math.degrees(a_.angle(b_)))
    FIST = (50, 95, 65)   # less at the knuckle: a deep first bend caves the back of the hand in at the knuckles
    def solve(wrist, fd, pn, aims, curls, main, its=6):
        """aims: finger -> (target, flex); curls: finger -> amount of a loose fist; the wrist moves until `main` reaches its target"""
        w = Vector(wrist); best = (1e9, None)
        for it in range(its + 1):
            if it == its: w = best[1]
            reset_r()
            C.arm_to(rig, 'r', w, ELB(-1)); orient_hand('r', Vector(fd), Vector(pn))
            for f, c in curls.items(): curl(f, c, FIST if f not in aims else (40, 35, 20))
            for f, (T, fl) in aims.items():
                if fl is None: continue
                if f == 'thumb':
                    aim_thumb(T, flex=(0,) + tuple(fl), bend_first=(HANDS == 'pinch' and _os_.environ.get('PTB', '1') == '1'))
                else: aim_finger(f, T, fl)
            tip = C.finger_tips(rig, 'r')[main]; err = Vector(aims[main][0]) - tip; best = min(best, (err.length, w.copy()), key=lambda t: t[0]); print('  err', tuple(round(x,3) for x in err), 'wrist want', tuple(round(x,3) for x in w), 'got', tuple(round(x,3) for x in C.bone_head(rig,'hand_r'))); w = w + err * (0.5 if it > 3 else 1.0)
            print('solve', HANDS, it, 'err mm', round(err.length * 1000, 1), {f: round((Vector(aims[f][0]) - C.finger_tips(rig, 'r')[f]).length * 1000, 1) for f in aims})
        tips = C.finger_tips(rig, 'r'); print('tips r', {k: tuple(round(x, 3) for x in v) for k, v in tips.items()})
    TT = 0.345; TC = Vector((-0.10, 0.43, TT)); a14 = math.radians(14); U = Vector((math.cos(a14), math.sin(a14), 0)); NN = Vector((-math.sin(a14), math.cos(a14), 0))
    if HANDS == 'pinch':
        # photo 2: from above, the back of the hand toward her; fingers bent down onto the far long edge, thumb on the near one
        import os as _os
        FO = float(_os.environ.get('PFO', '0.042'))   # how far past the tape's far face the index tip's bone ends (the pad is ~7 mm thick)
        farI = TC - NN * FO + U * 0.006 + Vector((0, 0, -0.004))
        near = TC + NN * 0.034 + U * 0.004 + Vector((0, 0, -0.003))
        import os as _os
        fdp = Vector(tuple(float(x) for x in _os.environ.get('PFD', '0.25,-1,-0.12').split(','))).normalized()
        pnp = Vector(tuple(float(x) for x in _os.environ.get('PPN', '0,0.1,-1').split(','))); pnp = (pnp - fdp * pnp.dot(fdp)).normalized()
        near = near + U * float(_os.environ.get('PTU', '0.045')) + Vector((0, float(_os.environ.get('PTY', '0.008')), float(_os.environ.get('PTZ', '0'))))
        _f = lambda k, d: tuple(float(x) for x in _os.environ.get(k, d).split(','))
        # 2026-11-19（ユーザー「2だけ形が明らかにモノっぽさ感が強い」、そのあとユーザーの写真3枚 /mnt/project-files/インタビュー/手のお手本/2b_*）：
        # 手のひらをテープの真上に寝かせ（PPN＝下向き、PFD＝ほぼ水平）、4本の指をみな奥の縁にかける（PRA。薬指と小指も）。
        # 親指は伸ばしたまま手前の縁に添える（PTF 小さく、PTU・PTY）。指の腹は約7mm あるので、骨の先は奥の面から 4.2cm（PFO）
        FX = _f('PFX', '70,55'); RP = _f('PRP', '.9,.95'); TF = _f('PTF', '5,10'); W0 = _f('PW0', '-0.12,0.52,0.39')
        solve(W0, fdp, pnp,
              dict({'index': (farI, FX), 'middle': (farI - U * 0.019 + Vector((0, 0.002, 0)), FX), 'thumb': (near, TF)},
                   **({'ring': (farI - U * 0.036 + Vector((0, 0.006, 0.006)), FX), 'pinky': (farI - U * 0.050 + Vector((0, 0.014, 0.012)), FX)}
                      if _os.environ.get('PRA', '1') == '1' else {})),
              {} if _os.environ.get('PRA', '1') == '1' else {'ring': RP[0], 'pinky': RP[1]}, 'index', its=10)
    elif HANDS == 'stroke':
        # photo 3: the pad of the index on the label, the other fingers closed in, thumb along the middle finger
        T = TC + Vector((0.004, 0.006, 0.007))
        fd = Vector((0.3, -1, 0.02)).normalized()
        # the index's first joint points it at the label; the closed fingers rest on the table, so the wrist height is
        # found by halving until their lowest tip sits on the top
        fd = Vector((0.3, -1, -0.08)).normalized(); pn = Matrix.Rotation(math.radians(-12), 3, fd) @ Vector((0, 0, -1))
        def stroke_at(z):
            w = Vector((T.x, T.y, 0)) - Vector((fd.x, fd.y, 0)).normalized() * 0.15; w.z = z
            solve(w, fd, pn, {'index': (T, (6, 4))}, {'middle': .75, 'ring': .8, 'pinky': .85}, 'index', its=1)
            return min(C.finger_tips(rig, 'r')[f].z for f in ('middle', 'ring', 'pinky'))
        lo, hi = 0.34, 0.45
        for _k in range(9):
            mid = (lo + hi) / 2
            if stroke_at(mid) < TT + 0.003: lo = mid
            else: hi = mid
        low = stroke_at(hi); print('stroke wrist z', round(hi, 3), 'lowest closed tip', round(low, 3), 'index tip', tuple(round(x, 3) for x in C.finger_tips(rig, 'r')['index']))
        tt = C.bone_head(rig, 'middle_02_r') + Vector((0.012, 0.0, 0.004)); tt.z = max(tt.z, 0.352)   # never under the table
        aim_thumb(tt, flex=(0, 15, 15))
    else:
        # photo 4: the notebook pulled in front of her; the pencil on the right page, the hand on its little-finger side
        P = Vector((0.06, 0.43, 0.337))
        G = P + Vector((-0.012, 0.016, 0.024))     # where the fingertips hold the pencil, 2.5 cm up from the point
        # a tripod grip, worked out against the pencil's own line: index on top, thumb on its side, middle under it,
        # and the pencil's back resting in the web between thumb and index. The line comes from the web, so go round a few times.
        aims = {'index': (G + Vector((0.002, 0.0, 0.007)), (30, 20)), 'middle': (G + Vector((0.004, -0.004, -0.006)), (40, 30)),
                'thumb': (G + Vector((-0.006, 0.010, 0.002)), (10, 12))}
        wst = Vector((-0.02, 0.53, 0.39))
        for rnd in range(4):
            solve(wst, (0.05, -0.85, -0.5), (0.85, 0.05, -0.5), aims, {'ring': .8, 'pinky': .9}, 'index')
            wst = C.bone_head(rig, 'hand_r').copy()
            web = (C.bone_head(rig, 'index_01_r') + C.bone_head(rig, 'thumb_02_r')) / 2 + Vector((0, 0, 0.008))
            D = (web - P).normalized()
            up = (Vector((0, 0, 1)) - D * D.z).normalized(); sd = D.cross(up).normalized()
            if (C.bone_head(rig, 'thumb_02_r') - P).dot(sd) < 0: sd = -sd       # sd: toward the thumb
            r = 0.0045
            aims = {'index': (P + D * 0.034 + up * (r + 0.004), (25, 20)),
                    'thumb': (P + D * 0.027 + sd * (r + 0.005), (10, 12)),
                    'middle': (P + D * 0.020 - up * (r * 0.4) - sd * (r + 0.004), (45, 30))}
            print('pencil round', rnd, 'dir', tuple(round(x, 2) for x in D), {f: round((aims[f][0] - C.finger_tips(rig, 'r')[f]).length * 1000, 1) for f in aims})
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.0037, depth=0.15)
        pc = bpy.context.object; pc.name = 'kikite_pencil'
        pm = bpy.data.materials.new('kikite_pencil_paint'); pm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.02, 0.06, 0.03, 1)
        pm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.35; pc.data.materials.append(pm)
        pc.rotation_mode = 'QUATERNION'; pc.rotation_quaternion = D.to_track_quat('Z', 'Y'); pc.location = P + D * (0.018 + 0.075)
        bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.0037, radius2=0.0004, depth=0.018)
        cn = bpy.context.object; cn.name = 'kikite_pencil_tip'
        wm = bpy.data.materials.new('kikite_pencil_wood'); wm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.55, 0.38, 0.22, 1); cn.data.materials.append(wm)
        cn.rotation_mode = 'QUATERNION'; cn.rotation_quaternion = (-D).to_track_quat('Z', 'Y'); cn.location = P + D * 0.009
        print('pencil dir', tuple(round(x, 2) for x in D))
    # the left hand on the notebook as in photo 4
    LW = Vector((0.27, 0.50, 0.356)) if HANDS == 'write' else Vector((0.230, 0.540, 0.356))
    C.arm_to(rig, 'l', LW, ELB(1))
    orient_hand('l', forearm_dir('l'), Vector((0, 0, -1)))
elif HANDS == 'lap':
    # cut F: both hands closed into fists on the thighs, a little above the knees (Mio, under the table)
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get(); bo = bpy.data.objects[f'{KEY}_body'].evaluated_get(dg)
    BP = np.array([tuple(bo.matrix_world @ v.co) for v in bo.data.vertices])
    def top_at(x, y, r=0.03):
        m_ = (np.abs(BP[:, 0] - x) < r) & (np.abs(BP[:, 1] - y) < r) & (BP[:, 2] < 0.5); return float(BP[m_, 2].max()) if m_.any() else 0.36
    for side, sx in (('l', 1), ('r', -1)):
        x, y = sx * 0.095, HIP_Y - 0.17
        w = Vector((x, y + 0.01, top_at(x, y - 0.04) + 0.055))
        C.arm_to(rig, side, w, ELB(sx)); bpy.context.view_layer.update()
        # a fist standing on its little-finger side on the thigh: knuckles forward, thumb on top, fingers curled in toward the middle
        fd = Vector((-sx * 0.15, -1, -0.12)).normalized()
        orient_hand(side, fd, Vector((-sx, 0, -0.35)))
        R_ = (rig.matrix_world @ rig.pose.bones[f'hand_{side}'].matrix).to_3x3().normalized(); palm = (R_ @ HAXES[side][1]).normalized()
        for f in ('index', 'middle', 'ring', 'pinky'):
            M_ = rig.matrix_world @ rig.pose.bones[f'{f}_01_{side}'].matrix; d_ = (M_.to_3x3() @ Vector((0, 1, 0))).normalized(); ax = d_.cross(palm).normalized()
            for jn, dgs in zip(('01', '02', '03'), (50, 95, 65)): C.rot_world(rig, f'{f}_{jn}_{side}', ax, dgs * 1.05)
        # the thumb lies across the front of the fist, over the index and middle fingers' middle joints
        T_ = (C.bone_tail(rig, f'index_02_{side}') + C.bone_tail(rig, f'middle_02_{side}')) / 2 - palm * 0.004
        for _ in range(3):
            h1 = C.bone_head(rig, f'thumb_01_{side}'); t3 = C.bone_tail(rig, f'thumb_03_{side}'); a_ = t3 - h1; b_ = T_ - h1
            if a_.cross(b_).length < 1e-7: break
            C.rot_world(rig, f'thumb_01_{side}', a_.cross(b_).normalized(), math.degrees(a_.angle(b_)))
        print('thumb to fist', side, round((C.bone_tail(rig, f'thumb_03_{side}') - T_).length * 1000, 1), 'mm')
        print('lap', side, 'wrist', tuple(round(v, 3) for v in w), 'tips', {k: tuple(round(v, 3) for v in t) for k, t in C.finger_tips(rig, side).items()})
else:
    C.arm_to(rig, 'r', Vector((-0.10, HIP_Y - 0.22, 0.33)), Vector((-0.3, 0.3, -0.2)))
    C.arm_to(rig, 'l', Vector((0.10, HIP_Y - 0.22, 0.33)), Vector((0.3, 0.3, -0.2)))
for s in ('l', 'r'):
    w = C.bone_head(rig, f'hand_{s}'); print('wrist', s, tuple(round(x, 3) for x in w), 'shoulder', tuple(round(x, 3) for x in C.bone_head(rig, f'upperarm_{s}')))
print('head top', round(max((o.matrix_world @ v.co).z for o in [bpy.data.objects[f'{KEY}_head']] for v in o.data.vertices[:1]), 3), 'head bone', tuple(round(x, 3) for x in C.bone_tail(rig, 'head')))
# the knuckles: the skinned back of the hand caves in where the fingers bend hard at their base; a corrective smooth
# after the armature evens the deformation out toward the rest shape's own detail
_hm = bpy.data.objects[f'{KEY}_hands']
if 'knuckles' not in _hm.modifiers:
    cs = _hm.modifiers.new('knuckles', 'CORRECTIVE_SMOOTH'); cs.factor = 0.6; cs.iterations = 8; cs.smooth_type = 'LENGTH_WEIGHTED'
    cs.rest_source = 'ORCO'; cs.use_only_smooth = False
    order = [m.name for m in _hm.modifiers]; ai = [i for i, m in enumerate(_hm.modifiers) if m.type == 'ARMATURE'][0]
    bpy.context.view_layer.objects.active = _hm
    while _hm.modifiers.find('knuckles') > ai + 1: bpy.ops.object.modifier_move_up(modifier='knuckles')
    print('hand modifiers', [m.name for m in _hm.modifiers])
if KEY != 'kikite':   # posed on the north zabuton; turn the whole figure about the table's centre onto the south one, facing north
    from mathutils import Matrix
    TY = 0.1; rig.matrix_world = Matrix.Translation((0, TY, 0)) @ Matrix.Rotation(math.pi, 4, 'Z') @ Matrix.Translation((0, -TY, 0)) @ rig.matrix_world
    bpy.context.view_layer.update(); print('turned to the south zabuton, hips at', tuple(round(v, 3) for v in (C.bone_head(rig, 'thigh_l') + C.bone_head(rig, 'thigh_r')) / 2))
bpy.ops.wm.save_as_mainfile(filepath=OUT)

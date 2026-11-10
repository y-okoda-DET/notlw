"""第2章 20:00 in the whole house (試作91): the people after the power cut, for the house scene's story.

Only the movement is exported here, never the bodies: <name>_t20.glb holds the rig, the phone in the right hand and one
looping action "<rig>_t20". Godot plays it on the 第1章 body (assets/dusk/<name>.glb, the same make_tripo rig and bone
names), so the heavy Tripo textures are not shipped twice. Where each one stands goes to t20.json (Blender metres and
the yaw), as do the phones (Godot gives each a small torch).

The placing (Claude の判断, ユーザーが変えてよい): the take is over, the house is dark but for the living-room lantern and
the crew's blue LED panel. Everyone has a phone out, its torch on, so the light in the hall is four small moving ones
(not one beam). Kiryu by the camera in the genkan, trying for a signal; Natsuki and Makoto at the living-room door by
the lantern; Taiga at the cellar door at the back of the hall (he knows where the generator is). For the generator he
waits in the cellar beside it (TAIGA_GEN): Godot moves him there while Mio cannot see him."""
import sys, os, math, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import paths as P
import bpy
from mathutils import Vector
import lib, chars as C, house4 as H4
import export_godot as E

X, Y = H4.X, H4.Y
OUT = f'{P.RULES}/assets/dusk'          # beside the bodies (the main pack, not the house pack)
os.makedirs(OUT, exist_ok=True)

# plan metres (x east, y north from the front wall) and what each one faces
PLACE = {
    'kiryu':   dict(at=(4.95, 0.75), face=(4.95, -1.0), z=-0.18),    # down in the genkan at the front door, his phone up for a signal (試作91: on the step he stood 60 cm from Mio, a black wall in her view)
    'natsuki': dict(at=(3.2, 3.0), face=(4.5, 3.5), z=0.0),          # just inside the living room, toward its door (試作96: at 3.75, 3.35 she and Makoto left 2 cm beside the open leaf, nobody could get in)
    'makoto':  dict(at=(2.75, 3.55), face=(4.2, 3.4), z=0.0),        # behind her, past the tip of the open leaf (3.15, 3.95)
    'taiga':   dict(at=(4.75, 6.05), face=(4.75, 3.0), z=0.0),       # at the back of the hall by the cellar door, toward Mio
}
TAIGA_GEN = dict(at=(8.5, 6.35), face=(9.2, 6.2), z=H4.ZB)            # in the cellar, at the generator's north-west, his light on its panel (8.55, 5.25 and 8.8, 5.65 stood between the stair and the panel; 9.75, 5.35 was inside the old cupboard)

def yaw_to(at, face):
    a, f = Vector((X(at[0]), Y(at[1]))), Vector((X(face[0]), Y(face[1])))
    d = f - a
    return math.atan2(d.x, -d.y)

S = {}

def pose(key, rig, t):
    kl = lambda v: C.local(rig, v)
    seed = {'kiryu': 1.0, 'natsuki': 3.0, 'makoto': 7.0, 'taiga': 2.0}[key]
    # Kiryu holds his up (a signal). 試作97 (ユーザー「大河、スマホ持ってない」「夏希、スマホを手に持ってない」): at the waist
    # (Taiga -.12, Natsuki 0) the phone was lost against the body in the dark; at the chest, the screen toward the face
    lift = {'kiryu': .22, 'natsuki': .1, 'makoto': -.04, 'taiga': .04}[key]
    if key == 'taiga': C.rot_world(rig, 'spine_03', E.axis_local(rig, (1, 0, 0)), 4)   # 試作97: before the arms are set (they hang from it)
    C.arm_to(rig, 'l', kl((.2, -.04, .86)), Vector((.3, .3, 0)))
    C.grip(rig, 'l', .3)
    eyes = C.bone_head(rig, 'head') + C.local(rig, (0, -.08, .05)) - C.local(rig, (0, 0, 0))
    C.phone_grip3(rig, 'r', S[key + '_ph'], eyes, kl((-.05, -.3, 1.22 + lift + .01 * E.noise1(t, seed + 3))), Vector((-.3, .3, -.5)))
    # looking down at the screen. 試作97: Taiga's 18 degrees pushed his collar out behind the neck (ユーザー「大河の首の後ろに
    # 変な出っ張り」「服の襟も変」): the phone is higher now, and his neck bends less, the upper back a little instead
    if key == 'taiga':
        C.rot_world(rig, 'neck_01', E.axis_local(rig, (1, 0, 0)), 6)
    else:
        C.rot_world(rig, 'neck_01', E.axis_local(rig, (1, 0, 0)), 12 + 6 * (lift < 0))
    E.idle(rig, t, seed, breath=.26, amp=.9, rate=1.0)

def build():
    lib.reset()
    n = C.make_tripo('natsuki_s', label='natsuki')[0]
    for ob in n.children_recursive: ob.name = ob.name.replace('natsuki_s_', 'natsuki_')
    rigs = {'natsuki': n, 'kiryu': C.make_tripo('kiryu')[0], 'taiga': C.make_tripo('taiga')[0], 'makoto': C.make_tripo('makoto')[0]}
    for key, rig in rigs.items():
        rig.location = (0, 0, 0); rig.rotation_euler = (0, 0, 0)
        S[key + '_ph'] = C.phone(f'{key}_t20phone', lib.kelvin(8500), 5)
    bpy.context.view_layer.update()
    for key, rig in rigs.items():
        C.reset_pose(rig); pose(key, rig, 0.0)
        # one mesh (body and screen), its whole placement baked into the vertices relative to the hand bone's head frame,
        # the object itself exactly on that frame: Godot makes the bone-parented node a BoneAttachment3D, which takes the
        # bone's pose and drops the node's own transform (試作91: the phones came in as 2 m cubes, the scale lost)
        ph = S[key + '_ph']; scr = ph.children[0]
        bpy.context.view_layer.update()
        Mb = rig.matrix_world @ rig.pose.bones['hand_r'].matrix
        for o in (ph, scr): o.data = o.data.copy()
        scr.data.transform(Mb.inverted() @ scr.matrix_world); ph.data.transform(Mb.inverted() @ ph.matrix_world)
        scr.parent = None
        ph.parent = rig; ph.parent_type = 'BONE'; ph.parent_bone = 'hand_r'
        bpy.context.view_layer.update(); ph.matrix_world = Mb
        scr.parent = ph; bpy.context.view_layer.update(); scr.matrix_world = Mb
        S[key + '_scr'] = scr
    return rigs

if __name__ == '__main__':
    rigs = build()
    out = {}
    for key, rig in rigs.items():
        act = E.bake_action(rig, lambda t, k=key, r=rig: pose(k, r, t))
        act.name = f'{rig.name}_t20'
        # a tiny mesh skinned to the rig: without a skin, glTF's bones import into Godot as plain nodes, not a Skeleton3D
        me = bpy.data.meshes.new(f'{key}_t20stub'); me.from_pydata([(0, 0, 0), (.001, 0, 0), (0, .001, 0)], [], [(0, 1, 2)])
        stub = bpy.data.objects.new(f'{key}_t20stub', me); bpy.context.scene.collection.objects.link(stub)
        stub.parent = rig; vg = stub.vertex_groups.new(name='pelvis'); vg.add([0, 1, 2], 1.0, 'REPLACE')
        md = stub.modifiers.new('arm', 'ARMATURE'); md.object = rig
        objs = [rig, S[key + '_ph'], S[key + '_scr'], stub]
        E.export(f'{OUT}/{key}_t20.glb', objs)
        p = PLACE[key]
        out[key] = dict(pos=[X(p['at'][0]), Y(p['at'][1]), p['z']], yaw=yaw_to(p['at'], p['face']), rig=rig.name, phone=f'{key}_t20phone')
    g = TAIGA_GEN
    out['taiga_gen'] = dict(pos=[X(g['at'][0]), Y(g['at'][1]), g['z']], yaw=yaw_to(g['at'], g['face']))
    json.dump(out, open(f'{OUT}/t20.json', 'w'), indent=1)
    print('EXPORTED t20')

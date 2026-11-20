# 人物の blend から、骨の形（pose の matrix_basis）・骨の休みの位置・物の位置を json に書く（rig2glb.py が形として読む）。
#   python3 dump.py -- <in.blend> <kikite|mio> <out.json>
import bpy, sys, json
a = sys.argv[sys.argv.index('--') + 1:]
src, key, out = a
bpy.ops.wm.open_mainfile(filepath=src)
rig = bpy.data.objects[key + '_rig']
d = {'rig_world': [list(r) for r in rig.matrix_world], 'bones': {}, 'rest': {}, 'objs': {}}
for pb in rig.pose.bones:
    mb = pb.matrix_basis
    d['bones'][pb.name] = [list(r) for r in mb]
    b = rig.data.bones[pb.name]
    d['rest'][pb.name] = [list(b.head_local), list(b.tail_local)]
for o in bpy.data.objects:
    d['objs'][o.name] = {'type': o.type, 'world': [list(r) for r in o.matrix_world], 'parent': o.parent.name if o.parent else None, 'pbone': o.parent_bone}
json.dump(d, open(out, 'w'))
print('DUMP', src, len(d['bones']))

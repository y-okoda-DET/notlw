import sys; sys.path.insert(0,'/home/claude/kf')
import bpy, lib, chars as C
lib.reset()
r,b=C._base_human('natsuki')
print([g.name for g in b.vertex_groups][80:])
print(len(b.data.vertices), sum(1 for v in b.data.vertices if len(v.groups)))
print([m.type for m in b.modifiers], b.parent, r.scale[:])

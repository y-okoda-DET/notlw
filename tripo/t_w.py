import sys; sys.path.insert(0,'/home/claude/kf')
import bpy, lib, chars as C, numpy as np
lib.reset(); r,b=C.make_tripo('kiryu')
gi={g.index:g.name for g in b.vertex_groups}
fing=[v for v in b.data.vertices if any(gi[g.group].split('_')[0] in C.FINGERS+('thumb',) and g.weight>.3 for g in v.groups)]
hand=[v for v in b.data.vertices if any(gi[g.group].startswith('hand_') and g.weight>.3 for g in v.groups)]
print('finger-weighted verts',len(fing),'hand verts',len(hand))
tot={}
for v in b.data.vertices:
    for g in v.groups:
        n=gi[g.group]
        if n.split('_')[0] in C.FINGERS+('thumb',): tot[n]=tot.get(n,0)+g.weight
print(sorted(tot.items(),key=lambda x:-x[1])[:8])

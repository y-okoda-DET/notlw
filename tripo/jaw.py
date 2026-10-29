import bpy, sys, math
sys.path.insert(0,'/home/claude/kf')
import lib
key=sys.argv[-1]
bpy.ops.wm.open_mainfile(filepath=f'/home/claude/tripo/{key}_prep.blend')
s=bpy.context.scene
if s.world is None: s.world=bpy.data.worlds.new('w')
s.world.use_nodes=True; s.world.node_tree.nodes['Background'].inputs[1].default_value=.25
lib.area('key',(-1.2,-2.2,2.2),(0,0,1.45),260,k=5000,size=(1.5,1.5)); lib.area('fill',(1.5,-1.5,1.5),(0,0,1.45),90,k=5000,size=(2,2))
hz={'kiryu':1.52,'taiga':1.58,'makoto':1.33}[key]
for n,(x,y,z) in {'low':(.35,-.45,hz-.25),'side':(.55,-.2,hz+.02)}.items():
    lib.camera((x,y,z),(0,0,hz-.03),lens=85)
    lib.render(f'/home/claude/tripo/jaw_{key}_{n}.png',samples=16,res=(500,500))

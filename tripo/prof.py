import bpy, numpy as np, sys
def load(f):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=f)
    o=[o for o in bpy.data.objects if o.type=='MESH'][0]
    m=o.data.materials[0]; bs=[n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'][0]
    img=bs.inputs['Base Color'].links[0].from_node.image
    W,H=img.size; px=np.array(img.pixels[:],np.float32).reshape(H,W,4)[...,:3]
    me=o.data; n=len(me.vertices)
    uv=np.zeros((len(me.loops),2)); me.uv_layers[0].data.foreach_get('uv',uv.ravel())
    li=np.zeros(len(me.loops),int); me.loops.foreach_get('vertex_index',li)
    vuv=np.zeros((n,2)); vuv[li]=uv
    col=px[np.clip((vuv[:,1]*H).astype(int),0,H-1),np.clip((vuv[:,0]*W).astype(int),0,W-1)]
    co=np.zeros(n*3); me.vertices.foreach_get('co',co); co=co.reshape(-1,3)
    co=(np.array(o.matrix_world)[:3,:3]@co.T).T+np.array(o.matrix_world)[:3,3]
    return co,col
for f in sys.argv[sys.argv.index('--')+1:]:
    co,col=load(f)
    L=col.mean(1); skin=(col[:,0]>col[:,2]+.08)&(L>.35); hair=L<.12
    print(f)
    for z in np.arange(0.5 if 'a' in f else 0,1.0,.02):
        s=(co[:,2]>=z)&(co[:,2]<z+.02)
        if s.sum()==0: continue
        sk=s&skin; 
        w_sk=(co[sk,0].max()-co[sk,0].min()) if sk.sum()>5 else 0
        d_sk=(co[sk,1].max()-co[sk,1].min()) if sk.sum()>5 else 0
        print(f' z={z:.2f} n={s.sum():6d} skin={sk.sum():5d} hair={(s&hair).sum():5d} w_all={co[s,0].max()-co[s,0].min():.3f} skin_w={w_sk:.3f} skin_d={d_sk:.3f} ymin={co[s,1].min():.3f}')

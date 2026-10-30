import bpy, math
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath='/home/claude/rules/assets/taiga.glb')
rig=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
print('GT rig rot', [round(math.degrees(a),1) for a in rig.matrix_world.to_euler()], 'loc', [round(x,2) for x in rig.matrix_world.translation], 'parent', rig.parent.name if rig.parent else None)
bpy.context.scene.frame_set(193)
for s in 'lr':
    P=lambda b: rig.matrix_world@rig.pose.bones[b].head
    sh,el,w=P(f'upperarm_{s}'),P(f'lowerarm_{s}'),P(f'hand_{s}')
    print('GT',s,'elbow',round(math.degrees((sh-el).angle(w-el))),'wrist',[round(x,2) for x in w],'head',[round(x,2) for x in P('head')])

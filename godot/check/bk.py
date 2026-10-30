import sys, bpy
sys.path.insert(0,'/home/claude/kf')
import export_dusk as X, export_godot as E, chars as C
X.build(); S=X.S; m=S['m']
C.reset_pose(m); X.pose_makoto(m, 2.0); bpy.context.view_layer.update()
A={b:(m.matrix_world@m.pose.bones[b].matrix).copy() for b in ('lowerarm_r','hand_r','index_01_r','thumb_01_r')}
E.LOOP=2.2
E.bake_action(m, lambda t: X.pose_makoto(m, t))
C.reset_pose(m); bpy.context.scene.frame_set(49); bpy.context.view_layer.update()
for b,M in A.items():
    B=m.matrix_world@m.pose.bones[b].matrix
    print('BK',b,'pos diff cm',round((B.translation-M.translation).length*100,2),'rot diff deg',round(B.to_quaternion().rotation_difference(M.to_quaternion()).angle*57.3,1))
pb=m.pose.bones['hand_r']; print('BK hand loc',tuple(round(x,4) for x in pb.location),'scale',tuple(round(x,3) for x in pb.scale))
for b in ('lowerarm_r','hand_r','middle_01_r'):
    M=m.matrix_world@m.pose.bones[b].matrix
    print('BKW',b,tuple(round(x,3) for x in M.translation),'tail',tuple(round(x,3) for x in m.matrix_world@m.pose.bones[b].tail))

extends SceneTree
func _init():
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	for i in 30: await physics_frame
	var cam = m.player.get_node("Head/Camera")
	print("CAM ", cam.global_position, " fwd ", -cam.global_transform.basis.z, " fov ", cam.fov, " keep ", cam.keep_aspect)
	for k in ["kiryu", "taiga"]:
		var sk = m.S[k + "_node"].find_children("*", "Skeleton3D", true, false)[0]
		var hi = sk.find_bone("head")
		print(k, " head bone ", sk.global_transform * sk.get_bone_global_pose(hi).origin, " skel scale ", sk.global_transform.basis.get_scale())
	quit()

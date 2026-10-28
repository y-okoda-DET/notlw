extends SceneTree
func _init():
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	await process_frame
	var cam = m.player.get_node("Head/Camera")
	print("player ", m.player.global_position, " cam ", cam.global_position, " fwd ", -cam.global_transform.basis.z)
	for k in ["env", "kiryu", "taiga", "natsuki"]:
		var n = m.S[k + "_node"]
		var ab := AABB(); var first := true
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var b = mi.global_transform * mi.get_aabb()
			if first: ab = b; first = false
			else: ab = ab.merge(b)
		print(k, " aabb ", ab.position, " size ", ab.size)
		if k != "env":
			for mi in n.find_children("*", "MeshInstance3D", true, false):
				var b = mi.global_transform * mi.get_aabb()
				print("   ", mi.name, " parent=", mi.get_parent().name, " ", b.position.snapped(Vector3.ONE*0.01), " ", b.size.snapped(Vector3.ONE*0.01))
	for l in m.lights: print("light ", l, " ", m.lights[l].global_position, " e=", m.lights[l].light_energy)
	quit()

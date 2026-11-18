extends SceneTree
var frame := 0
var cam: Camera3D
var shots := []
var w: Node3D
var todo := []
func arm(left: bool, curl: float, thumb: float) -> Node3D:
	var h := Node3D.new()
	var inst: Node3D = (load("res://props/mio_arm_%s.glb" % ("l" if left else "r")) as PackedScene).instantiate(); h.add_child(inst)
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var to_h := Transform3D(); var nd: Node3D = sk
	while nd != h: to_h = nd.transform * to_h; nd = nd.get_parent()
	for f in ["index", "middle", "ring", "pinky", "thumb"]:
		for j in 3:
			var bi := sk.find_bone("%s_0%d_%s" % [f, j + 1, "l" if left else "r"])
			if bi < 0: continue
			var gb: Basis = (to_h * sk.get_bone_global_rest(bi)).basis.orthonormalized()
			var ax: Vector3 = (gb.inverse() * gb.y.cross(Vector3.DOWN).normalized()).normalized()
			var ang: float = (thumb * [0.30, 0.55, 0.40][j]) if f == "thumb" else (curl * [0.80, 1.05, 0.70][j])
			todo.append([sk, bi, sk.get_bone_rest(bi).basis.get_rotation_quaternion() * Quaternion(ax, ang)])
	return h
func _init():
	w = Node3D.new(); root.add_child(w)
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.35, 0.35, 0.38)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(1, 1, 1); e.ambient_light_energy = 0.6; env.environment = e; w.add_child(env)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-50, 30, 0); w.add_child(l)
	cam = Camera3D.new(); cam.fov = 40; w.add_child(cam)
	var mode := OS.get_environment("VM")
	if mode == "police":
		var pb: Node3D = (load("res://props/police_body_nohead.glb") as PackedScene).instantiate(); w.add_child(pb); pb.scale = Vector3.ONE * 1.72
		var K := float(OS.get_environment("HK")); var Z := float(OS.get_environment("HZ"))
		var ph: Node3D = (load("res://props/police_head.glb") as PackedScene).instantiate(); w.add_child(ph); ph.scale = Vector3.ONE * K
		ph.position = Vector3(0, 0.978 * 1.72 + float(OS.get_environment("HY")) - 0.667 * K, Z)
		shots = [["p_front", Vector3(0, 1.5, 1.3), Vector3(0, 1.45, 0), Vector3.UP], ["p_side", Vector3(1.3, 1.5, 0), Vector3(0, 1.45, 0), Vector3.UP], ["p_back", Vector3(0.4, 1.6, -1.2), Vector3(0, 1.45, 0), Vector3.UP], ["p_full", Vector3(0.8, 1.2, 3.2), Vector3(0, 0.9, 0), Vector3.UP]]
	elif mode == "case":
		var c: Node3D = (load("res://props/tripod_case.glb") as PackedScene).instantiate(); w.add_child(c)
		shots = [["c_a", Vector3(0.6, 0.7, 1.2), Vector3(0, 0.1, 0), Vector3.UP], ["c_top", Vector3(0, 1.6, 0.01), Vector3(0, 0, 0), Vector3.UP]]
	else:
		var cs := [0.0, 0.5, 1.0, 1.3]
		for i in 4:
			var a := arm(true, cs[i], cs[i] * 0.6); w.add_child(a); a.position = Vector3(-0.27 + 0.18 * i, 0, 0)
		shots = [["a_top", Vector3(0, 0.75, -0.02), Vector3(0, 0, -0.03), Vector3(0, 0, -1)], ["a_under", Vector3(0, -0.75, -0.02), Vector3(0, 0, -0.03), Vector3(0, 0, -1)],
			["a_front", Vector3(0, 0.25, -0.7), Vector3(0, 0, -0.03), Vector3.UP], ["a_side", Vector3(0.5, 0.25, -0.65), Vector3(0, 0, -0.05), Vector3.UP]]
func _process(_d):
	frame += 1
	if frame == 2:
		for t in todo: (t[0] as Skeleton3D).set_bone_pose_rotation(t[1], t[2])
	var i := (frame - 4) / 4
	if frame >= 4 and (frame - 4) % 4 == 0 and i < shots.size(): cam.look_at_from_position(shots[i][1], shots[i][2], shots[i][3])
	if frame >= 6 and (frame - 6) % 4 == 0:
		var k := (frame - 6) / 4
		if k < shots.size(): root.get_viewport().get_texture().get_image().save_png("res://out/%s.png" % shots[k][0])
		else: quit()
	return false

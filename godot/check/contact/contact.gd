extends Node
# 赤字用のコンタクトシート（2026-11-27）：自動の通しを最後まで回しながら、実際の画面（字幕・カードもそのまま）を
# カットの変わり目と N 秒ごとに1枚ずつ撮る。撮らない間は窓を小さくして 3D を描かない（PV の clip.gd と同じ考え方）。
#   --contact=<dir>     <dir>/0000.png … と <dir>/shots.tsv（1枚1行：番号 時計 章 時刻 理由 位置名 カメラ）
#   --cevery=3          N 秒ごと（ゲームの時計。--frameclock の秒）
#   --cdelay=0.35       カットを見つけてから撮るまでの秒（フェードやカメラの落ち着き待ち）
#   --cstill=12         カメラが動いていない間は、この秒数ごとにしか撮らない（止まって喋る所）
#   --cfast=2           ゲームを1コマあたり2倍の速さで進める（通す時間がおよそ半分。撮る画は変わらない。PV の clip.gd と同じ）
# カットの見つけ方：使うカメラが替わった／場面が替わった／1コマでカメラが 0.5m か 20度より大きく跳んだ／
#                   画面いっぱいの紙（章のカード、暗転の紙）が出た・消えた
var dir := "/tmp/contact"; var every := 3.0; var delay := 0.35
var t := 0.0; var next_periodic := 0.0; var full := Vector2i(1920, 1080)
var prev_cam: Camera3D; var prev_xf := Transform3D(); var prev_scene: Node; var prev_card := false
var due := -1.0; var due_why := ""; var rec := -1; var n := 0; var f := 0
var tsv: FileAccess
var warm := 4   # --cwarm=4: frames drawn before the one saved (the fog and the exposure settle over a few frames)
var still := 12.0; var last_xf := Transform3D(); var last_shot := -99.0   # --cstill=12: a camera that has not moved is shot again only after this many seconds
var fast := 1.0   # --cfast=2: the game runs twice as fast per frame (half the frames to go through; contact.sh makes main.gd's frame clock follow)
var layers: Array = []

func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	process_priority = 100000
	for x in OS.get_cmdline_user_args():
		if x.begins_with("--contact="): dir = x.substr(10)
		if x.begins_with("--cevery="): every = float(x.substr(9))
		if x.begins_with("--cdelay="): delay = float(x.substr(9))
		if x.begins_with("--cfast="): fast = float(x.substr(8))
		if x.begins_with("--cwarm="): warm = int(x.substr(8))
		if x.begins_with("--cstill="): still = float(x.substr(9))
	DirAccess.make_dir_recursive_absolute(dir)
	tsv = FileAccess.open(dir + "/shots.tsv", FileAccess.WRITE)
	tsv.store_line("n\tclock\tchapter\ttime\twhy\tname\tcam")
	full = get_window().size
	var w := get_window()
	if DisplayServer.get_name() != "headless": w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS; w.content_scale_size = Vector2i(1920, 1080)   # the type laid out as on a 1920x1080 screen, whatever size it is drawn at
	_small(true)
	get_tree().node_added.connect(func(k: Node): if k is CanvasLayer: layers.append(k))
	for l in get_tree().root.find_children("*", "CanvasLayer", true, false): layers.append(l)

func _small(on: bool):
	if DisplayServer.get_name() != "headless": get_window().size = Vector2i(full.x / 10, full.y / 10) if on else full
	RenderingServer.render_loop_enabled = not on
	# 描かない設定だけでは家の中で毎コマ描かれていた（llvmpipe が回り続け、1コマ 1秒以上）。3D を切り、SubViewport も止める
	get_viewport().disable_3d = on
	for v in get_tree().root.find_children("*", "SubViewport", true, false):
		if on:
			if not v.has_meta("contact_mode"): v.set_meta("contact_mode", v.render_target_update_mode)
			v.render_target_update_mode = SubViewport.UPDATE_DISABLED
		elif v.has_meta("contact_mode"):
			v.render_target_update_mode = v.get_meta("contact_mode"); v.remove_meta("contact_mode")
	Engine.time_scale = fast
	Engine.max_physics_steps_per_frame = maxi(8, int(ceil(fast * 60.0 / 24.0)) + 2)

# the game's main node (main.gd) under the boot, or the chapter node itself (interview, stand-in card)
func _chapter_node() -> Node:
	var c := get_tree().current_scene
	if c == null: return null
	if "play" in c or "which" in c or "chap" in c: return c
	for k in c.get_children():
		if "play" in k: return k
	return c

func _chapter() -> Array:
	var c := _chapter_node()
	if c == null: return ["?", ""]
	if "play" in c:
		var M = c.get_script()
		return [String(c.play), String(M.TIME) if M and "TIME" in M else ""]
	if "which" in c: return ["i%d" % int(c.which), ""]
	if "chap" in c: return [String(c.chap), ""]
	return [String(c.name), ""]

func _card_up() -> bool:
	var vs := get_viewport().get_visible_rect().size
	layers = layers.filter(func(l): return is_instance_valid(l))
	for l in layers:
		if not l.is_inside_tree() or not (l as CanvasLayer).visible: continue
		for k in l.get_children():
			if k is ColorRect or k is TextureRect or k is Panel:
				var cr := k as Control
				if cr.is_visible_in_tree() and cr.modulate.a * cr.self_modulate.a > 0.6 and cr.size.x >= vs.x * 0.9 and cr.size.y >= vs.y * 0.9:
					if k is ColorRect and (k as ColorRect).color.a < 0.6: continue
					return true
	return false

func _name(cam: Camera3D, ch: Array) -> String:
	# the same form as the game's F12 (main.gd): where the player stands, so house_shots.py / close.py can take it again
	var c := _chapter_node()
	var p = c.get("player") if c and "player" in c else null
	if p and is_instance_valid(p):
		var pp: Vector3 = p.global_position
		var sc := "house-" + String(ch[1]) if ch[1] != "" else String(ch[0])
		var s := "shot_%s_x%.2f_z%.2f_yaw%.0f_pitch%.0f_t%.1f" % [sc, pp.x, pp.z, rad_to_deg(p.yaw), rad_to_deg(p.pitch), t]
		if ch[1] != "": s += "_y%.2f" % pp.y
		return s + ".png"
	return "shot_%s_t%.1f.png" % [ch[0], t]

func _process(dt: float):
	t += dt
	f += 1
	if f % 48 == 0 and OS.get_cmdline_user_args().has("--cperf"):
		print("CPERF f=%d ms=%d proc=%.1f phys=%.1f nav=%.1f objs=%d nodes=%d draw=%d" % [f, Time.get_ticks_msec(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0, Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	var cam := get_viewport().get_camera_3d()
	var scene := get_tree().current_scene
	# looking for cuts (every frame: cheap)
	var why := ""
	if scene != prev_scene: why = "場面"
	elif cam != prev_cam: why = "カメラ"
	elif cam:
		var xf := cam.global_transform
		var ang := xf.basis.get_rotation_quaternion().angle_to(prev_xf.basis.get_rotation_quaternion())
		if xf.origin.distance_to(prev_xf.origin) > 0.5 or ang > deg_to_rad(20.0): why = "カット"
	if f % 4 == 0:
		var card := _card_up()
		if card != prev_card: why = "カード" if card else "カード明け"
		prev_card = card
	prev_scene = scene; prev_cam = cam
	if cam: prev_xf = cam.global_transform
	if why != "" and due < 0.0 and rec < 0: due = t + delay; due_why = why
	# shooting: grow the window and draw, save the third frame (the first ones can still be the small window's)
	if rec >= 0:
		rec += 1
		if OS.get_cmdline_user_args().has("--cwarmtest") and rec in [2, 3, 6, 12]:
			get_viewport().get_texture().get_image().save_png("%s/%04d_w%d.png" % [dir, n, rec])
		if rec >= warm:
			var ch := _chapter()
			var img := get_viewport().get_texture().get_image()
			img.save_png("%s/%04d.png" % [dir, n])
			var cs := ""
			if cam:
				var o := cam.global_position; var r := cam.global_rotation_degrees
				cs = "%.2f,%.2f,%.2f,%.0f,%.0f,%.0f" % [o.x, o.y, o.z, r.y, r.x, cam.fov]
			tsv.store_line("%d\t%.1f\t%s\t%s\t%s\t%s\t%s" % [n, t, ch[0], ch[1], due_why, _name(cam, ch), cs]); tsv.flush()
			print("CONTACT %d t=%.1f %s %s %s ms=%d" % [n, t, ch[0], ch[1], due_why, Time.get_ticks_msec()])
			if cam: last_xf = cam.global_transform
			last_shot = t
			n += 1; rec = -1; due = -1.0; _small(true)
		return
	if due < 0.0 and t >= next_periodic:
		# 止まって喋る所：カメラが前に撮ったときから動いていなければ、still 秒たつまで撮らない（描くのが一番重いので、撮る前に間引く）
		var moved := cam == null or cam.global_transform.origin.distance_to(last_xf.origin) > 0.08 \
			or cam.global_transform.basis.get_rotation_quaternion().angle_to(last_xf.basis.get_rotation_quaternion()) > deg_to_rad(3.0)
		if moved or t - last_shot >= still: due = t; due_why = "%s秒" % str(every)
		else: next_periodic = t + every
	if due >= 0.0 and t >= due:
		next_periodic = t + every   # the next periodic one counts from this shot (a cut resets it)
		rec = 0; _small(false)

func _exit_tree():
	if tsv: tsv.flush()

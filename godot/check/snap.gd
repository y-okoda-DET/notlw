extends Node
# 自動の通しの途中で、決めた所で画を撮る（snap.sh が重ねたプロジェクトの boot.gd に足す）。撮らない間は 3D を描かず、
# 窓も小さくしておくので速い。撮り終えたら止まる。
#   --snaps=<file>   1行に1枚：「名前 いつ [+待つ秒] [x y 目の高さ yaw pitch]」
#     いつ：数字なら、ゲームを始めてからの秒（--fixed-fps の刻み）。@ で始めれば、その式が真になったとき（空白なしで書く）。
#           式の中では m＝main、s＝main.story、st＝いまの場面が始まってからの秒。例 @m.play=="h21"&&st>20、@s.hs==5
#     x y は間取りの座標（plan）、yaw・pitch は度（Godot の向き）。座標がなければ主人公の目で撮る。
#   --snapdir=<dir>  png を書く所
# 5秒ごとに SNAPCLK を出す。
var shots := []; var t := 0.0; var i := 0; var hold := -1; var dir := "/tmp"
var cam: Camera3D; var prev: Camera3D; var prev_t := Transform3D(); var prev_fov := 75.0
var full := Vector2i(960, 540)
var cur_main: Node; var st := 0.0; var wait := -1.0
func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	process_priority = 100000   # after the player's own camera work: our camera is the one drawn
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--snaps="):
			for l in FileAccess.get_file_as_string(a.substr(8)).split("\n"):
				var w := l.strip_edges().split(" ", false)
				if w.size() >= 2 and not w[0].begins_with("#"): shots.append(w)
		if a.begins_with("--snapdir="): dir = a.substr(10)
	full = get_window().size
	_small(true)

func _small(on: bool):
	get_viewport().disable_3d = on
	get_window().size = Vector2i(192, 108) if on else full

func _main() -> Node:
	var c := get_tree().current_scene
	if c == null: return null
	if "story" in c: return c
	for n in c.get_children():
		if "story" in n: return n
	return null

func _coords(w: Array) -> Array:
	var r := []
	for k in range(2, w.size()):
		if String(w[k]).is_valid_float(): r.append(float(w[k]))
	return r

func _due(w: Array) -> bool:
	var when := String(w[1])
	if not when.begins_with("@"): return t >= float(when)
	var m := _main()
	if m == null: return false
	var e := Expression.new()
	if e.parse(when.substr(1), ["m", "s", "st"]) != OK: print("SNAP bad ", when); return false
	var v = e.execute([m, m.get("story"), st], null, false)
	return not e.has_execute_failed() and bool(v)

func _process(dt: float):
	if int((t + dt) / 5.0) != int(t / 5.0): print("SNAPCLK %.1f" % (t + dt))
	t += dt
	var m := _main()
	if m != cur_main: cur_main = m; st = 0.0
	st += dt
	if i >= shots.size():
		if shots.size() > 0: get_tree().quit()
		return
	var w: Array = shots[i]
	if hold >= 0:
		hold += 1
		if cam:
			cam.make_current()
			if prev and is_instance_valid(prev): prev.global_transform = cam.global_transform; prev.fov = cam.fov
		if hold == 10:
			get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, w[0]])
			print("SNAP %s t=%.1f st=%.1f" % [w[0], t, st])
			if cam:
				cam.queue_free(); cam = null
				if prev and is_instance_valid(prev): prev.transform = prev_t; prev.fov = prev_fov
			if prev and is_instance_valid(prev): prev.make_current()
			_small(true); hold = -1; i += 1; wait = -1.0
		return
	if wait < 0.0 and _due(w):
		wait = 0.0
		for k in w: if String(k).begins_with("+"): wait = float(String(k).substr(1))
	if wait >= 0.0:
		wait -= dt
		if wait <= 0.0:
			wait = 0.0; _small(false); hold = 0
			prev = get_viewport().get_camera_3d()
			if prev: prev_t = prev.transform; prev_fov = prev.fov
			var c := _coords(w)
			for k in w:   # look=<person>: from 1.8 m before them (and a little to their right), at their chest
				if String(k).begins_with("look="):
					var mm := _main(); var r: Node3D = mm._rig_of(String(k).substr(5)) if mm else null
					if r:
						var f := r.global_basis.z; f.y = 0.0; f = f.normalized()
						var eye := r.global_position + f * 1.8 + r.global_basis.x.normalized() * 0.5 + Vector3.UP * 1.5
						var at := r.global_position + Vector3.UP * 1.1
						cam = Camera3D.new(); get_tree().root.add_child(cam)
						if prev: cam.fov = prev.fov; cam.environment = prev.environment; cam.attributes = prev.attributes
						cam.near = 0.03; cam.look_at_from_position(eye, at, Vector3.UP); cam.make_current()
			if cam == null and c.size() >= 5:
				cam = Camera3D.new(); get_tree().root.add_child(cam)
				if prev: cam.fov = prev.fov; cam.environment = prev.environment; cam.attributes = prev.attributes
				cam.near = 0.03
				cam.global_position = Vector3(c[0] - 4.8, c[2], c[1] - 6.3)
				cam.rotation = Vector3(deg_to_rad(c[4]), deg_to_rad(c[3]), 0.0)
				cam.make_current()

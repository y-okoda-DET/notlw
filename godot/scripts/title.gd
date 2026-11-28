## タイトル画面（2026-11-28、ユーザー「ゲームタイトル画面もつくりたいね」）。聞き取りの部屋の座卓（assets/interview/room.glb）の上に、
## 夏希の「上映用」のテープの箱。そのふたの紙に題名と、夏希の字の行（はじめる／つづきから／設定／おわる）。選んだ行にペンの丸。
## 画は make_title.py が描く。刷りは証言の部屋と同じ昼の刷り（riso2 look=2）。
## W/S・上下・ホイールで選び、E・Enter・Space・左クリックで決める。マウスを行に合わせても選べる。
## main.gd がゲームの初め（引数なし）にだけ作る。はじめる → 序章、つづきから → 最後に入った章（user://progress.json）。
extends Node3D

var main: Node
const A := "res://assets/interview/"
const PS := 0.0001                   # the lid's paper: 1100 x 780 px is 110 x 78 mm
const CARD_W := 1100.0; const CARD_H := 780.0
const ROW_Y := [452.0, 532.0, 612.0, 692.0]
var cam: Camera3D
var card: Node3D
var rows := []                       # [{key, sprite, y}]
var mark: Sprite3D
var sel := 0
var page := "top"                    # top | set
var riso: ShaderMaterial
var t := 0.0
var going := false
var black: ColorRect

func _ready():
	_env(); _room(); _lights(); _case(); _print()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_page_top()
	var cl := CanvasLayer.new(); cl.layer = 30; add_child(cl)
	black = ColorRect.new(); black.color = Color(0.03, 0.13, 0.13, 1.0); black.set_anchors_preset(Control.PRESET_FULL_RECT); black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(black)
	create_tween().tween_property(black, "color:a", 0.0, 1.2).set_delay(0.2)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--titleshot="):   # check stills
			var p := a.substr(12)
			get_tree().create_timer(2.5).timeout.connect(func():
				get_viewport().get_texture().get_image().save_png(p); print("TITLE shot ", p); get_tree().quit())

func _env():
	var we := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.86, 0.88, 0.9)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.80, 0.79, 0.77); env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true; env.ssao_radius = 0.1; env.ssao_intensity = 1.2
	we.environment = env; add_child(we)

var table_y := 0.39
func _room():
	if not ResourceLoader.exists(A + "room.glb"): return
	var room: Node3D = (load(A + "room.glb") as PackedScene).instantiate(); add_child(room)
	for mi in room.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if String(m.name) == "table_top":
			table_y = (m.global_transform * m.get_aabb()).end.y
			var tm: BaseMaterial3D = m.get_active_material(0).duplicate(); tm.roughness = 0.34; tm.metallic_specular = 0.6
			m.set_surface_override_material(0, tm)

func _lights():
	var sky := DirectionalLight3D.new(); sky.light_color = Color(0.97, 0.98, 1.0); sky.light_energy = 1.05
	sky.rotation = Vector3(deg_to_rad(-38), deg_to_rad(160), 0); sky.shadow_enabled = true; sky.light_angular_distance = 6.0
	sky.directional_shadow_max_distance = 3.0; sky.light_specular = 0.2
	add_child(sky)
	var fill := DirectionalLight3D.new(); fill.light_color = Color(1.0, 0.97, 0.92); fill.light_energy = 0.25
	fill.rotation = Vector3(deg_to_rad(-30), deg_to_rad(10), 0); add_child(fill)

# the tape's paper box, shut, on the table a little askew; the lid's paper face up
func _case():
	var at := Vector3(0.0, 0.0, 0.1)
	card = Node3D.new(); add_child(card)
	card.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-4.0)), Vector3(at.x, table_y + 0.016, at.z))
	var paper := StandardMaterial3D.new(); paper.albedo_color = Color(0.78, 0.74, 0.66); paper.roughness = 0.9
	var body := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.112, 0.016, 0.080); body.mesh = bm; body.material_override = paper
	add_child(body); body.global_transform = Transform3D(card.global_basis, card.global_position - Vector3(0, 0.0085, 0))
	var face := _sprite("res://ui/title_card.png"); card.add_child(face); face.position = Vector3.ZERO; face.render_priority = 0
	mark = _sprite("res://ui/title_mark.png"); card.add_child(mark); mark.render_priority = 2
	cam = Camera3D.new(); add_child(cam); cam.fov = 34.0; cam.near = 0.02; cam.far = 6.0
	# from above and a little in front: the lid fills the middle, the table's lacquer and its edge round it
	var c: Vector3 = card.global_position
	cam.global_transform = Transform3D(Basis(), c + Vector3(0.0, 0.185, 0.06)).looking_at(c + Vector3(0.0, 0.0, 0.004), Vector3(0, 0, -1))
	cam.make_current()

func _sprite(path: String) -> Sprite3D:
	var s := Sprite3D.new(); s.texture = load(path); s.pixel_size = PS; s.shaded = true; s.double_sided = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED; s.render_priority = 1; s.no_depth_test = true   # the lines and the pen's loop lie on the paper itself: never hidden by it
	s.basis = Basis(Vector3.RIGHT, -PI / 2.0)   # lying on the lid, its top to the far side
	return s

func _at(px: float, py: float, w: float) -> Vector3:   # a point of the lid's paper (px from its left, py from its top) for a sprite w px wide (its middle)
	return Vector3((px + w * 0.5 - CARD_W * 0.5) * PS, 0.0004, (py - CARD_H * 0.5) * PS)

func _print():
	var layer := CanvasLayer.new(); layer.layer = 10; add_child(layer)
	var bb := BackBufferCopy.new(); bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT; layer.add_child(bb)
	var r := ColorRect.new(); r.set_anchors_preset(Control.PRESET_FULL_RECT); r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	riso = ShaderMaterial.new(); riso.shader = load("res://shaders/riso2.gdshader")
	riso.set_shader_parameter("look", 2.0); riso.set_shader_parameter("cell_px", 2.6); riso.set_shader_parameter("exposure", 1.05)
	r.material = riso; layer.add_child(r)

# ---------------------------------------------------------------- the lines
func _set_rows(keys: Array):
	for r in rows: (r.sprite as Node).queue_free()
	rows = []
	for i in keys.size():
		var s := _sprite("res://ui/title_row_%s.png" % keys[i]); card.add_child(s)
		var w: float = s.texture.get_width()
		s.position = _at(110.0, ROW_Y[i] - 48.0 + 48.0, w)
		rows.append({"key": keys[i], "sprite": s, "w": w, "y": ROW_Y[i]})
	sel = clampi(sel, 0, rows.size() - 1)
	_mark()

func _page_top():
	page = "top"
	_set_rows(["start", "cont" if _progress() != "" else "nocont", "set", "quit"])

func _page_set():
	page = "set"
	var q: bool = bool(_prefs().get("q", true)); var v: int = int(_prefs().get("vol", 2))
	_set_rows(["q_hi" if q else "q_lo", "v_%d" % v, "back"])

func _mark():
	if rows.is_empty(): return
	var r: Dictionary = rows[sel]
	var w: float = float(r.w) + 70.0
	mark.scale = Vector3(w / 520.0, 1.0, 1.0)
	mark.position = _at(110.0 - 35.0, float(r.y) - 8.0, w)
	mark.modulate.a = 0.0
	var tw := create_tween(); tw.tween_property(mark, "modulate:a", 1.0, 0.18)
	_one("c7_pencil")

func _move(d: int):
	if going: return
	sel = (sel + d + rows.size()) % rows.size(); _mark()

func _choose():
	if going or rows.is_empty(): return
	var k: String = rows[sel].key
	match k:
		"start": _go("")
		"cont": _go(_progress())
		"nocont": pass
		"set": sel = 0; _page_set()
		"quit": get_tree().quit()
		"q_hi", "q_lo":
			var p := _prefs(); p["q"] = not bool(p.get("q", true)); _save_prefs(p); _page_set()
		"v_1", "v_2", "v_3":
			var p := _prefs(); p["vol"] = (int(p.get("vol", 2)) % 3) + 1; _save_prefs(p); _apply_vol(); _page_set()
		"back": sel = 2; _page_top()

func _go(cont: String):
	going = true
	_one("c7_pencil")
	var tw := create_tween(); tw.tween_property(black, "color:a", 1.0, 0.9)
	tw.tween_callback(func(): main.title_go(cont))

# ---------------------------------------------------------------- input
func _unhandled_input(e):
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_W, KEY_UP: _move(-1)
			KEY_S, KEY_DOWN: _move(1)
			KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: _choose()
			KEY_ESCAPE: if page == "set": sel = 2; _page_top()
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: _move(-1)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: _move(1)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			var i := _row_under(e.position)
			if i >= 0: sel = i; _choose()
	elif e is InputEventMouseMotion:
		var i := _row_under(e.position)
		if i >= 0 and i != sel: sel = i; _mark()

func _row_under(p: Vector2) -> int:
	for i in rows.size():
		var r: Dictionary = rows[i]
		var a: Vector2 = cam.unproject_position(card.global_transform * _at(80.0, float(r.y) - 40.0, 0.0))
		var b: Vector2 = cam.unproject_position(card.global_transform * _at(80.0 + float(r.w) + 80.0, float(r.y) + 40.0, 0.0))
		var rc := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())
		if rc.has_point(p): return i
	return -1

func _one(k: String):
	var path := "res://sound/%s.ogg" % k
	if not ResourceLoader.exists(path): path = "res://sound/%s.wav" % k
	if not ResourceLoader.exists(path): return
	var p := AudioStreamPlayer.new(); p.stream = load(path); p.volume_db = -8.0; add_child(p); p.play()
	p.finished.connect(p.queue_free)

# ---------------------------------------------------------------- what is kept between plays (user://progress.json)
static func _prefs() -> Dictionary:
	if not FileAccess.file_exists("user://progress.json"): return {}
	var j = JSON.parse_string(FileAccess.get_file_as_string("user://progress.json"))
	return j if j is Dictionary else {}
static func _save_prefs(p: Dictionary):
	var f := FileAccess.open("user://progress.json", FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(p))
static func _progress() -> String: return String(_prefs().get("play", ""))
static func save_progress(play: String):
	var p := _prefs(); p["play"] = play; _save_prefs(p)
static func _apply_vol():
	var v: int = int(_prefs().get("vol", 2))
	AudioServer.set_bus_volume_db(0, [-14.0, -7.0, 0.0][clampi(v - 1, 0, 2)])

## タイトル画面（2026-11-28「タイトル画面を詰める」のスレッド。ユーザー「ここはゲーム外といえばゲーム外なので取り決めから離れてOK。
## かっこいい画面にすることが重要」「載せる要素は CONTINUE/NEW GAME/SETTING/QUIT」「SETTINGよりOPTION」「ロゴの下のラインと
## QUITの下のラインを揃えたほうが綺麗」、動く版を見て「方向性OK。打撃音は無しでいい」）。
## 夕方の家を私道の下から見上げる（家まるごとの夕方の光。main.gd が TITLE で家を建て、この節に渡す）。左に PV と同じ色ずれのロゴ、
## 右下に CONTINUE／NEW GAME／OPTIONS／QUIT（Anton、字の間を少し空ける）。選んだ項目は紙の白、ほかは半分透かし、刷りの橙の短い線。
## カメラは手持ちのようにわずかに揺れながら、90 秒かけて家へ寄って戻る。音は夕方の林と弱い風。選ぶとダイヤルの「カチ」。
## W/S・上下・ホイール・マウスで選び、E・Enter・Space・クリックで決める。OPTIONS の中では Esc で戻る。
## 前の机の上のテープの箱（11-28 朝）は使わない。user://progress.json の読み書きは前のまま（main.gd が使う）。
extends Node

var main: Node
const ORANGE := Color(0.91, 0.46, 0.27)
const PAPER := Color(0.945, 0.925, 0.875)
const INK := Color(0.03, 0.13, 0.14)
# the camera: down the drive below the house, looking up at it between the cedars (house_shots o_t18; Godot world)
const CAM_AT := Vector3(6.070, -2.290 + 1.55, -24.960)
const CAM_YAW := 164.1
const CAM_PITCH := 9.8
const PUSH := 1.8           # metres toward the house at the near end of the slow swing
const SWING := 90.0         # s for the swing in and back
# the layout (1920 x 1080; scaled with the window's height): the logo's box, the items' right edge and the baseline they sit on
const LOGO_AT := Vector2(77, 350)          # ui/title_logo_misreg.png (the logo and its soft shadow) placed here
const LOGO_FOOT := 957.8                   # the logo's lowest ink: the last item's foot is set level with it
const RIGHT := 1770.0
const ROW := 66.0
const SIZE := 38
const SPACING := 6
var u := 1.0
var cam: Camera3D
var t := 0.0
var layer: CanvasLayer
var cover: ColorRect
var logo: TextureRect
var veil: TextureRect
var rows := []          # [{key, lb}]
var mark: ColorRect
var sel := 0
var page := "top"
var going := false
var mk := 0.0           # the menu's fade-in
var font: FontVariation
var demo := []          # --titledemo=key,key,...: an unattended run presses these, one a second (checks)

func _ready():
	u = get_viewport().get_visible_rect().size.y / 1080.0
	font = FontVariation.new(); font.base_font = load("res://fonts/Anton-Regular.ttf"); font.spacing_glyph = int(SPACING * u)
	cam = Camera3D.new(); var pc: Camera3D = main.player.get_node("Head/Camera")
	cam.fov = pc.fov; cam.near = pc.near; cam.far = pc.far; main.add_child(cam)
	# the body stands where the camera is (the outside haze is measured from it) and is held there
	var p := Vector3(CAM_AT.x, CAM_AT.y - 1.55, CAM_AT.z)
	main.player.global_position = p
	main.player.auto_path = [[0.0, p.x, p.z, CAM_YAW, CAM_PITCH], [1e9, p.x, p.z, CAM_YAW, CAM_PITCH]]
	main.player.set_process_unhandled_input(false); main.player.set_process_input(false)
	layer = CanvasLayer.new(); layer.layer = 100; add_child(layer)
	veil = TextureRect.new(); var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 0.75, 1.0])
	g.colors = PackedColorArray([Color(INK, 0.0), Color(INK, 0.0), Color(INK, 0.30), Color(INK, 0.78)])
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(0, 1); gt.width = 4; gt.height = 256
	veil.texture = gt; veil.set_anchors_preset(Control.PRESET_FULL_RECT); veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE; veil.modulate.a = 0.0; layer.add_child(veil)
	logo = TextureRect.new(); logo.texture = load("res://ui/title_logo_misreg.png")
	logo.position = LOGO_AT * u; logo.size = logo.texture.get_size() * u; logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE; logo.modulate.a = 0.0; layer.add_child(logo)
	mark = ColorRect.new(); mark.color = ORANGE; mark.size = Vector2(24, 6) * u; mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(mark)
	cover = ColorRect.new(); cover.color = INK; cover.set_anchors_preset(Control.PRESET_FULL_RECT); cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cover)
	_page_top()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_loop("dusk_amb", -6.0); _loop("ch8_wind", -16.0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--titledemo="): demo = Array(a.substr(12).split(","))
		if a.begins_with("--titleshot="):   # check stills: the menu up, then quit
			var path := a.substr(12)
			get_tree().create_timer(5.0).timeout.connect(func():
				get_viewport().get_texture().get_image().save_png(path); print("TITLE shot ", path); get_tree().quit())
	print("TITLE up cont=", _progress())

# ---------------------------------------------------------------- the items
func _label(text: String) -> Label:
	var lb := Label.new(); lb.text = text
	lb.add_theme_font_override("font", font); lb.add_theme_font_size_override("font_size", int(SIZE * u))
	lb.add_theme_color_override("font_color", PAPER)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lb

func _set_rows(items: Array, first := 0):
	for r in rows: (r.lb as Node).queue_free()
	rows = []
	var n := items.size()
	for i in n:
		var lb := _label(String(items[i][1])); layer.add_child(lb)
		var sz := lb.get_combined_minimum_size()
		# the caps' foot (the font's ascent from the label's top) of the last row on the logo's foot
		var asc: float = font.get_ascent(int(SIZE * u))
		var foot := LOGO_FOOT * u - (n - 1 - i) * ROW * u
		lb.position = Vector2(RIGHT * u - sz.x, foot - asc)
		lb.modulate.a = 0.0
		rows.append({"key": items[i][0], "lb": lb, "foot": foot, "asc": asc})
		layer.move_child(lb, layer.get_child_count() - 2)   # under the cover
	sel = clampi(first, 0, n - 1)

func _page_top():
	page = "top"
	var items := []
	if _progress() != "": items.append(["cont", "CONTINUE"])
	items.append_array([["new", "NEW GAME"], ["opt", "OPTIONS"], ["quit", "QUIT"]])
	_set_rows(items, 0)

func _page_opt():
	page = "opt"
	var q: bool = bool(_prefs().get("q", true)); var v: int = int(_prefs().get("vol", 2))
	_set_rows([["q", "QUALITY  " + ("HIGH" if q else "LOW")], ["vol", "VOLUME  " + ["I", "II", "III"][clampi(v - 1, 0, 2)]], ["back", "BACK"]], 0)

func _move(d: int):
	if going or rows.is_empty(): return
	sel = (sel + d + rows.size()) % rows.size(); _one("dial_tick", -8.0)

func _choose():
	if going or rows.is_empty() or mk < 0.5: return
	var k: String = rows[sel].key
	match k:
		"new": _go("")
		"cont": _go(_progress())
		"opt": _one("dial_tick", -8.0); _page_opt()
		"quit": going = true; _fade(func(): get_tree().quit())
		"q":
			var p := _prefs(); p["q"] = not bool(p.get("q", true)); _save_prefs(p); main._quality(bool(p.q)); main.SET["q"] = bool(p.q)   # (main keeps Q: the prefs follow it)
			_one("dial_tick", -8.0); _page_opt(); sel = 0
		"vol":
			var p := _prefs(); p["vol"] = (int(p.get("vol", 2)) % 3) + 1; _save_prefs(p); _apply_vol(); _one("dial_tick", -8.0); _page_opt(); sel = 1
		"back": _one("dial_tick", -8.0); _page_top(); sel = rows.size() - 2

func _go(cont: String):
	going = true
	_one("tape_clunk", -6.0)
	print("TITLE go ", cont)
	_fade(func(): main.title_go(cont))

func _fade(then: Callable):
	var tw := create_tween(); tw.tween_property(cover, "modulate:a", 1.0, 1.0); tw.tween_callback(then)
	for c in get_children():
		if c is AudioStreamPlayer: create_tween().tween_property(c, "volume_db", -60.0, 1.0)

# ---------------------------------------------------------------- each frame
var demo_t := 0.0
func _process(dt: float):
	t += dt
	var k := 0.5 - 0.5 * cos(t * TAU / SWING)
	var b := Basis.from_euler(Vector3(deg_to_rad(CAM_PITCH - 1.2 * k), deg_to_rad(CAM_YAW), 0.0), EULER_ORDER_YXZ)
	var fwd := -b.z; fwd.y = 0.0; fwd = fwd.normalized()
	var sway := Vector3(sin(t * 0.37) * 0.012, sin(t * 0.53 + 1.0) * 0.008, 0.0)
	cam.global_transform = Transform3D(b * Basis(Vector3.FORWARD, sin(t * 0.29) * 0.002), CAM_AT + fwd * PUSH * k + sway)
	cam.make_current()
	if not going: cover.modulate.a = clampf(1.0 - t / 1.6, 0.0, 1.0)
	veil.modulate.a = clampf((t - 0.3) / 1.5, 0.0, 1.0)
	logo.modulate.a = clampf((t - 1.0) / 0.8, 0.0, 1.0)
	mk = clampf((t - 2.0) / 0.8, 0.0, 1.0)
	for i in rows.size():
		var lb: Label = rows[i].lb
		var want := (1.0 if i == sel else 0.59) * mk
		lb.modulate.a = move_toward(lb.modulate.a, want, dt * 6.0) if mk >= 1.0 else want
	if not rows.is_empty():
		var r: Dictionary = rows[sel]
		var want_p := Vector2((r.lb as Label).position.x - 46.0 * u, float(r.foot) - float(r.asc) * 0.45 - 3.0 * u)
		mark.position = want_p if mark.position == Vector2.ZERO else mark.position.lerp(want_p, 1.0 - exp(-dt * 18.0))
	mark.modulate.a = mk
	if not demo.is_empty() and mk >= 1.0:
		demo_t += dt
		if demo_t > 1.0:
			demo_t = 0.0; var key: String = demo.pop_front()
			if key == "down": _move(1)
			elif key == "up": _move(-1)
			else:
				for i in rows.size():
					if rows[i].key == key: sel = i
				_choose()

# ---------------------------------------------------------------- input
func _unhandled_input(e):
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_W, KEY_UP: _move(-1)
			KEY_S, KEY_DOWN: _move(1)
			KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: _choose()
			KEY_ESCAPE: if page == "opt": _page_top(); sel = rows.size() - 2
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: _move(-1)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: _move(1)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			var i := _row_under(e.position)
			if i >= 0: sel = i; _choose()
	elif e is InputEventMouseMotion:
		var i := _row_under(e.position)
		if i >= 0 and i != sel: sel = i; _one("dial_tick", -12.0)

func _row_under(p: Vector2) -> int:
	for i in rows.size():
		var lb: Label = rows[i].lb
		var rc := Rect2(lb.position - Vector2(60, 6) * u, lb.size + Vector2(70, 12) * u)
		if rc.has_point(p): return i
	return -1

func _one(k: String, db: float):
	var path := "res://sound/%s.wav" % k
	if not ResourceLoader.exists(path): path = "res://sound/%s.ogg" % k
	if not ResourceLoader.exists(path): return
	var p := AudioStreamPlayer.new(); p.stream = load(path); p.volume_db = db; add_child(p); p.play()
	p.finished.connect(p.queue_free)

func _loop(k: String, db: float):
	var path := "res://sound/%s.wav" % k
	if not ResourceLoader.exists(path): path = "res://sound/%s.ogg" % k
	if not ResourceLoader.exists(path): return
	var p := AudioStreamPlayer.new(); p.stream = load(path); p.volume_db = db; add_child(p); p.play()
	p.finished.connect(p.play)

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

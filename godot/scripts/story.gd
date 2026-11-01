## 段階1の縦切り：第1章 夕方を遊べる形にする（歩く・調べる・話す・撮影準備のパズル）。
## main.gd が夕方の場面で（確認用の撮影でないとき）作る。
##
## The words on screen are set as the transcript of Mio's interview, months later: what people say is a line with
## the speaker's name, what Mio says when she looks at things is her testimony in the polite past tense, and when
## she chooses what to say, the lines she did not say stay on the page struck through, like a corrected transcript.
## The type is knocked out of the print (paper colour) with the blue plate a little off register behind it.
##
## The puzzle: Kiryu hands Mio storyboard #12 and the small fixed camera. She carries it, looks through it (right
## mouse), compares with the board (Tab) and sets it down (E) on something it can rest on: the stair's handrail, the
## newel post, the shoe cabinet, the apple box, the floor. Kiryu judges the frame. When it matches she starts it
## recording; the shoot begins and the power goes.
extends Node

var main            # main.gd
var player
var ink := Color(0.0, 0.2, 0.42)
var paper := Color(0.945, 0.925, 0.875)
var u := 1.0
var font: FontFile

# ---------------------------------------------------------------- the set (Blender metres; main.b2g maps to Godot)
const DOOR_C := 0.2
const YF := 6.3
const ZG := -0.18
# the frame Kiryu drew: from the stair's handrail, two thirds of the way up the hall, down onto the genkan
const TARGET_POS := [0.30, 2.90, 1.84]
const TARGET_LOOK := [0.26, 6.30, 0.40]
const FINDER_FOV := 64.0          # vertical, the small camcorder at its wide end (4:3)
# what the camera can rest on: [kind, ...]. Rails are segments (the camera's clamp sits on top).
var RESTS := [
	["rail", [0.30, 3.65, 1.20], [0.30, 0.95, 3.69]],    # handrail: newel cap at the foot up to near the top (filled in _ready)
	["point", [0.30, 3.65, 1.19], 0.09],                 # the newel cap
	["box", [0.97, 5.60, 0.75], [0.20, 0.55]],           # shoe cabinet top (half sizes x, y)
	["box", [-0.60, 3.85, 0.24], [0.22, 0.14]],          # the apple box
]
var items := {}     # key -> {pos (Godot), r, kind, name}

# ---------------------------------------------------------------- state
enum {FREE, TALK, END}
var mode := FREE
var has_board := false
var holding_cam := false
var cam_placed := false
var cam_ok := false
var recording := false
var tries := 0
var talked := {}
var finder := false
var board_up := false
var focus := ""
var fixed_cam: Node3D          # the little camera (in the hand, or set down)
var finder_cam: Camera3D
var finder_rest := {}          # where it would rest now: {pos: Vector3 (Godot), ok: bool, what: String}
var placed := {}               # {pos, yaw, pitch}

# ---------------------------------------------------------------- page (the transcript)
var page: Control
var lines_box: VBoxContainer
var note_lb: Label             # the bracketed stage note (what she is looking at)
var board_layer: CanvasLayer
var board_rect: TextureRect
var board_shadow: ColorRect
var finder_layer: CanvasLayer
var finder_ui: Control
var tc_lb: Label
var script_q: Array = []       # the conversation running: entries {who, text} | {choose: [..], then: [[..], ..]} | {do: "name"}
var cur: Dictionary = {}
var typed := 0.0
var cur_lb: Label
var choice_idx := 0
var choice_lbs: Array = []
var wait_after := 0.0
var end_t := -1.0
var demo: Array = []
var demo_i := 0
var demo_t := 0.0
var t_now := 0.0

func _ready():
	player = main.player
	font = load("res://fonts/SerifJP-Bold.otf")
	u = get_viewport().get_visible_rect().size.y / 1080.0
	# the handrail's top line (house4.stairs_up): z_rail(y) = 2.295 + (y_plan - 3.985) * .9167, plan y = 6.3 - Y
	var a := _rail_z(3.65); var b := _rail_z(0.95)
	RESTS[0] = ["rail", [0.30, 3.65, a + 0.065], [0.30, 0.95, b + 0.065]]
	_items()
	_page()
	_board()
	_finder()
	_fixed_cam()
	_lookers()
	for a2 in OS.get_cmdline_user_args():
		if a2 == "--demo": _demo_script()
		if a2.begins_with("--storystate="): call_deferred("_state", a2.substr(13))

func _rail_z(Y: float) -> float:
	return 2.295 + ((6.3 - Y) - 3.985) * 0.9167 + 0.025

func g(v: Array) -> Vector3:
	return Vector3(v[0], v[2], -v[1])

func _items():
	var add = func(key: String, p: Array, r: float, kind: String, name: String):
		items[key] = {"pos": g(p), "r": r, "kind": kind, "name": name}
	add.call("kiryu", [-0.32, 4.78, 1.55], 0.30, "talk", "桐生")
	add.call("natsuki", [0.36, 4.19, 1.48], 0.28, "talk", "夏希")
	add.call("makoto", [0.95, 3.86, 1.42], 0.28, "talk", "真琴")
	add.call("taiga", [0.26, 6.47, 1.40], 0.32, "talk", "大河")
	add.call("tape", [0.35, 4.10, 0.0], 0.16, "look", "床のテープ")
	add.call("camcorder", [-0.45, 4.47, 1.36], 0.16, "look", "桐生のカメラ")
	add.call("fresnel", [-0.50, 2.90, 1.95], 0.22, "look", "照明")
	add.call("note", [0.72, 0.67, 1.45], 0.13, "look", "扉の貼り紙")
	add.call("shoes", [0.30, 5.55, -0.12], 0.35, "look", "靴")
	add.call("fixedcam", [-0.60, 3.85, 0.30], 0.18, "take", "小さいカメラ")

# ================================================================ the page
func _label(size: float, col := Color(0, 0, 0, 0)) -> Label:
	var lb := Label.new()
	lb.add_theme_font_override("font", font)
	lb.add_theme_font_size_override("font_size", int(size * u))
	lb.add_theme_color_override("font_color", paper if col.a == 0.0 else col)
	# the blue plate a little off register behind the knocked-out type
	lb.add_theme_color_override("font_shadow_color", Color(0.0, 0.33, 0.6, 0.9))
	lb.add_theme_constant_override("shadow_offset_x", int(max(2.0, 2.5 * u)))
	lb.add_theme_constant_override("shadow_offset_y", int(max(1.0, 1.5 * u)))
	lb.add_theme_color_override("font_outline_color", Color(0.0, 0.26, 0.5, 0.75))   # a trap of blue round the type: it reads on the paper-white parts of the frame too
	lb.add_theme_constant_override("outline_size", int(max(2.0, 5.0 * u)))
	lb.autowrap_mode = TextServer.AUTOWRAP_OFF
	return lb

func _page():
	var layer := CanvasLayer.new(); layer.layer = 13; add_child(layer)
	page = Control.new(); page.set_anchors_preset(Control.PRESET_FULL_RECT); page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(page)
	lines_box = VBoxContainer.new()
	lines_box.anchor_left = 0.075; lines_box.anchor_right = 0.8; lines_box.anchor_top = 1.0; lines_box.anchor_bottom = 1.0
	lines_box.offset_bottom = -78 * u; lines_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lines_box.add_theme_constant_override("separation", int(6 * u))
	page.add_child(lines_box)
	note_lb = _label(26)
	note_lb.anchor_left = 0.075; note_lb.anchor_top = 1.0; note_lb.anchor_bottom = 1.0
	note_lb.offset_top = -66 * u; note_lb.offset_bottom = -30 * u
	page.add_child(note_lb)

# one line of the transcript: the speaker small, then the words
func _line_row(who: String, text: String, size := 36.0) -> Array:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", int(18 * u))
	var w := _label(25); w.text = who; w.custom_minimum_size = Vector2(70 * u, 0)
	w.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var t := _label(size); t.text = text
	row.add_child(w); row.add_child(t)
	lines_box.add_child(row)
	while lines_box.get_child_count() > 4:
		var c := lines_box.get_child(0); lines_box.remove_child(c); c.queue_free()
	for i in range(lines_box.get_child_count()):   # older lines fade back into the page
		(lines_box.get_child(i) as Control).modulate.a = 0.4 + 0.6 * float(i + 1) / float(lines_box.get_child_count())
	return [row, t]

func _clear_page():
	for c in lines_box.get_children(): lines_box.remove_child(c); c.queue_free()

# ================================================================ storyboard and finder
func _board():
	# above the print: the board is the print's own paper, drawn on in its blue ink (a grey pencil sheet put
	# through the print came out blank: the second print leaves mid-tones as paper), with the blue plate off register
	board_layer = CanvasLayer.new(); board_layer.layer = 12; add_child(board_layer)
	board_shadow = ColorRect.new(); board_shadow.color = Color(0.0, 0.33, 0.6, 0.85); board_layer.add_child(board_shadow)
	board_rect = TextureRect.new()
	var p := "res://ui/conte_12.png"
	if ResourceLoader.exists(p): board_rect.texture = load(p)
	board_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	board_layer.add_child(board_rect)
	board_layer.visible = false

func _place_board():
	var vs := get_viewport().get_visible_rect().size
	if finder:   # small, held beside the finder to compare
		board_rect.size = Vector2(vs.y * 0.42 * 1.414, vs.y * 0.42)
		board_rect.position = Vector2(vs.x * 0.015, vs.y * 0.55)
		board_rect.rotation = deg_to_rad(-2.5)
	else:        # held up in the left hand
		board_rect.size = Vector2(vs.y * 0.62 * 1.414, vs.y * 0.62)
		board_rect.position = Vector2(vs.x * 0.06, vs.y * 0.34)
		board_rect.rotation = deg_to_rad(-4.0)
	board_shadow.size = board_rect.size; board_shadow.rotation = board_rect.rotation
	board_shadow.position = board_rect.position + Vector2(7, 6) * u

class FinderFrame extends Control:
	# the camcorder's flip-out screen: a 4:3 picture in a dark bezel, the camera's own marks in its corners
	var tc := ""
	var rec := false
	var fnt: Font
	var u := 1.0
	func _draw():
		var s := size
		var h := s.y * 0.86; var w := h * 4.0 / 3.0
		var x0 := (s.x - w) / 2.0; var y0 := (s.y - h) / 2.0
		var bez := Color(0.05, 0.05, 0.055)
		draw_rect(Rect2(0, 0, s.x, y0), bez); draw_rect(Rect2(0, y0 + h, s.x, s.y - y0 - h), bez)
		draw_rect(Rect2(0, y0, x0, h), bez); draw_rect(Rect2(x0 + w, y0, s.x - x0 - w, h), bez)
		var lc := Color(0.92, 0.92, 0.88)
		var fs := int(30 * u)
		draw_string(fnt, Vector2(x0 + 26 * u, y0 + 46 * u), "● REC" if rec else "STBY", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.35, 0.15) if rec else lc)
		draw_string(fnt, Vector2(x0 + w - 230 * u, y0 + 46 * u), tc, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, lc)
		draw_string(fnt, Vector2(x0 + 26 * u, y0 + h - 24 * u), "WIDE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * u), lc)
		# the battery, three bars
		var bx := x0 + w - 110 * u; var by := y0 + h - 48 * u
		draw_rect(Rect2(bx, by, 70 * u, 28 * u), lc, false, 2.0 * u)
		for i in range(3): draw_rect(Rect2(bx + (5 + i * 21) * u, by + 5 * u, 17 * u, 18 * u), lc)
		draw_rect(Rect2(bx + 70 * u, by + 8 * u, 6 * u, 12 * u), lc)
		# centre mark
		var c := Vector2(x0 + w / 2.0, y0 + h / 2.0)
		draw_line(c - Vector2(18 * u, 0), c + Vector2(18 * u, 0), lc, 2.0 * u); draw_line(c - Vector2(0, 18 * u), c + Vector2(0, 18 * u), lc, 2.0 * u)

func _finder():
	finder_layer = CanvasLayer.new(); finder_layer.layer = 8; add_child(finder_layer)
	var f := FinderFrame.new(); f.fnt = font; f.u = u
	f.set_anchors_preset(Control.PRESET_FULL_RECT); f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	finder_layer.add_child(f); finder_ui = f
	finder_layer.visible = false
	finder_cam = Camera3D.new(); finder_cam.fov = FINDER_FOV; finder_cam.near = 0.03
	finder_cam.attributes = CameraAttributesPractical.new()
	main.add_child(finder_cam)

# the small camcorder: a palm-sized body, the lens, the flip screen folded, a clamp under it
func _fixed_cam():
	fixed_cam = Node3D.new(); fixed_cam.name = "fixedcam"
	# silver, like the consumer camcorders of the time: a black one in her hand vanished into the dark of the print
	var dark := StandardMaterial3D.new(); dark.albedo_color = Color(0.62, 0.62, 0.6); dark.roughness = 0.35; dark.metallic = 0.5
	var grey := StandardMaterial3D.new(); grey.albedo_color = Color(0.08, 0.08, 0.09); grey.roughness = 0.5
	var glass := StandardMaterial3D.new(); glass.albedo_color = Color(0.02, 0.03, 0.05); glass.roughness = 0.05; glass.metallic = 0.6
	var mk = func(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
		var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = mat; mi.position = pos; mi.rotation = rot
		mi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		fixed_cam.add_child(mi); return mi
	var body := BoxMesh.new(); body.size = Vector3(0.055, 0.065, 0.115)
	mk.call(body, dark, Vector3(0, 0.0, 0.0))
	var lens := CylinderMesh.new(); lens.top_radius = 0.021; lens.bottom_radius = 0.023; lens.height = 0.035
	mk.call(lens, grey, Vector3(0, 0.004, -0.072), Vector3(PI / 2, 0, 0))
	var eye := CylinderMesh.new(); eye.top_radius = 0.016; eye.bottom_radius = 0.016; eye.height = 0.004
	mk.call(eye, glass, Vector3(0, 0.004, -0.091), Vector3(PI / 2, 0, 0))
	var lcd := BoxMesh.new(); lcd.size = Vector3(0.006, 0.05, 0.068)
	mk.call(lcd, dark, Vector3(-0.031, 0.002, -0.006))
	var clamp_m := BoxMesh.new(); clamp_m.size = Vector3(0.03, 0.04, 0.03)
	mk.call(clamp_m, grey, Vector3(0, -0.052, 0.0))
	var led := OmniLight3D.new(); led.name = "rec"; led.light_color = Color(1.0, 0.2, 0.08); led.light_energy = 0.0
	led.omni_range = 0.35; led.shadow_enabled = false; led.position = Vector3(0.0, 0.03, -0.05)
	fixed_cam.add_child(led)
	var dot := SphereMesh.new(); dot.radius = 0.004; dot.height = 0.008
	var dm := StandardMaterial3D.new(); dm.albedo_color = Color(0.25, 0.05, 0.03); dm.emission_enabled = true; dm.emission = Color(1, 0.2, 0.05); dm.emission_energy_multiplier = 0.0
	var d := mk.call(dot, dm, Vector3(0.0, 0.034, -0.05)) as MeshInstance3D; d.name = "recdot"
	main.add_child(fixed_cam)
	fixed_cam.global_position = g([-0.60, 3.85, 0.24 + 0.072])
	fixed_cam.rotation.y = 0.6

func _set_rec(on: bool):
	recording = on
	(fixed_cam.get_node("rec") as OmniLight3D).light_energy = 0.6 if on else 0.0
	var dm := (fixed_cam.get_node("recdot") as MeshInstance3D).material_override as StandardMaterial3D
	dm.emission_energy_multiplier = 6.0 if on else 0.0
	(finder_ui as FinderFrame).rec = on

# ================================================================ the one she talks to turns to her
# Only the neck and the head, a little (at most 32 degrees), and only while they talk with her; the 20 s loop of
# their bodies goes on underneath. Makoto turns from the neck only (her head's weights reach the jaw: NOTES.md).
class Look extends SkeletonModifier3D:
	var target := Vector3.ZERO
	var w := 0.0
	var want := 0.0
	var v := Vector3.ZERO          # the face's forward, in the head bone's frame
	var neck := -1
	var head := -1
	var neck_share := 0.4
	func setup(fwd_world: Vector3):
		var sk := get_skeleton()
		neck = sk.find_bone("neck_01"); head = sk.find_bone("head")
		if head < 0: return
		var hb := sk.global_basis * sk.get_bone_global_pose(head).basis
		v = (hb.inverse() * fwd_world).normalized()
	func _process_modification():
		var sk := get_skeleton()
		if sk == null or head < 0 or v == Vector3.ZERO: return
		w = move_toward(w, want, get_process_delta_time() * 1.6)
		if w <= 0.001: return
		var gp := sk.get_bone_global_pose(head)
		var hw := sk.global_transform * gp
		var f := hw.basis * v; f.y = 0.0
		var to := target - hw.origin; to.y = 0.0
		if f.length() < 0.01 or to.length() < 0.01: return
		var yaw := clampf(f.normalized().signed_angle_to(to.normalized(), Vector3.UP), -0.56, 0.56)
		var e := w * w * (3.0 - 2.0 * w)
		var up_sk := (sk.global_basis.inverse() * Vector3.UP).normalized()
		for pair in [[neck, neck_share], [head, 1.0 - neck_share]]:
			if pair[0] < 0 or pair[1] <= 0.0: continue
			var p := sk.get_bone_global_pose(pair[0])
			sk.set_bone_global_pose(pair[0], Transform3D(Basis(up_sk, yaw * e * pair[1]) * p.basis, p.origin))

var looks := {}
func _lookers():
	for k in ["kiryu", "natsuki", "makoto", "taiga"]:
		if not main.S.has(k + "_node"): continue
		var sks: Array = main.S[k + "_node"].find_children("*", "Skeleton3D", true, false)
		if sks.is_empty(): continue
		var sk: Skeleton3D = sks[0]
		var lm := Look.new(); lm.neck_share = 1.0 if k == "makoto" else 0.4
		sk.add_child(lm)
		var fwd := (sk.global_basis * Vector3(0, 0, 1)); fwd.y = 0.0
		lm.setup(fwd.normalized())
		looks[k] = lm

func _update_looks():
	var eye: Vector3 = (player.get_node("Head/Camera") as Camera3D).global_position
	for k in looks:
		var lm: Look = looks[k]
		lm.target = eye
		lm.want = 1.0 if (mode == TALK and talk_with == k) else 0.0

# ================================================================ where the camera would rest
func _rest_for(eye: Vector3, dir: Vector3) -> Dictionary:
	# along her reach (25 cm to 1.4 m out), the first thing near the line that a camera could sit on
	var best := {"ok": false}
	var tt := 0.25
	while tt <= 1.4 and not best.ok:
		var want := eye + dir * tt
		var lim := 0.12 + tt * 0.08
		for r in RESTS:
			var p := Vector3.ZERO; var what := ""
			match r[0]:
				"rail":
					var a := g(r[1]); var b := g(r[2])
					var ab := b - a; var t: float = clamp((want - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
					p = a + ab * t; what = "手すり"
				"point":
					p = g(r[1]); what = "親柱"
				"box":
					var c := g(r[1]); var h: Array = r[2]
					p = Vector3(clamp(want.x, c.x - h[0], c.x + h[0]), c.y, clamp(want.z, c.z - h[1], c.z + h[1])); what = "台"
			var dd := p.distance_to(want)
			if dd < lim: best = {"ok": true, "pos": p, "what": what}; lim = dd
		tt += 0.05
	return best

# ================================================================ per frame
func _process(dt):
	t_now += dt
	if main.card.visible: return
	_demo_tick(dt)
	(finder_ui as FinderFrame).tc = "0:%02d:%02d" % [int(t_now / 60.0) % 60, int(t_now) % 60]
	finder_ui.queue_redraw()
	if mode == END: _end_tick(dt); return
	# the head and the camera
	var head: Node3D = player.get_node("Head")
	var cam: Camera3D = head.get_node("Camera")
	var eye: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_transform.basis.z
	if finder and holding_cam:
		# the spot is chosen when she lifts it to her eye (where she is looking then); after that she only aims it
		if not finder_rest.get("ok", false): finder_rest = _rest_for(eye, dir)
		var p: Vector3 = finder_rest.pos if finder_rest.get("ok", false) else eye + dir * 0.3
		finder_cam.global_transform = Transform3D(Basis.from_euler(Vector3(player.pitch, player.yaw, 0.0), EULER_ORDER_YXZ), p)
		finder_cam.current = true
	else:
		cam.current = true
	finder_layer.visible = finder and holding_cam
	board_layer.visible = board_up and has_board
	if board_layer.visible: _place_board()
	# the camera in the hand: low on the right, as she carries it
	if holding_cam:
		var hand := cam.global_transform * Transform3D(Basis.from_euler(Vector3(0.12, 0.95, 0.04)), Vector3(0.2, -0.14, -0.42))
		fixed_cam.global_transform = hand
		fixed_cam.visible = not finder
		if OS.get_cmdline_user_args().has("--storydbg"): print("HELD ", fixed_cam.global_position, " cam ", cam.global_position, " vis ", fixed_cam.is_visible_in_tree())
	# what she is looking at
	if mode == FREE:
		focus = _focus(eye, dir)
		if finder and holding_cam:
			note_lb.text = "［%sに置く｜Ｅ］" % finder_rest.what if finder_rest.get("ok", false) else "［ここには置けない］"
		elif focus != "":
			var it = items[focus]
			note_lb.text = "［%s］" % it.name
		else:
			note_lb.text = ""
	else:
		note_lb.text = ""
	if mode == TALK: _talk_tick(dt)
	_update_looks()
	player.move_enabled = (mode == FREE)
	# who is talking moves their mouth (main.gd _update_faces)
	main.talk_now = cur.get("who_key", "") if mode == TALK and cur.has("who") and typed < float(String(cur.text).length()) else ""
	main.story_talking = (mode == TALK)

func _focus(eye: Vector3, dir: Vector3) -> String:
	var best := ""; var best_s := 9.0
	for k in items:
		var it = items[k]
		if k == "fixedcam" and (holding_cam or cam_placed or not has_board): continue
		var to: Vector3 = it.pos - eye
		var d := to.length()
		var lim := 2.6 if it.kind == "talk" else 1.9
		if d > lim: continue
		var ang := acos(clamp(to.normalized().dot(dir), -1.0, 1.0))
		var allow: float = atan2(it.r, d) + 0.05
		if ang > allow: continue
		var s := ang / allow + d * 0.15
		if s < best_s: best_s = s; best = k
	# the camera she set down can be picked up again
	if cam_placed and not cam_ok:
		var to2 := fixed_cam.global_position - eye
		if to2.length() < 1.6 and acos(clamp(to2.normalized().dot(dir), -1.0, 1.0)) < atan2(0.12, to2.length()) + 0.06:
			items["placed"] = {"pos": fixed_cam.global_position, "r": 0.12, "kind": "take", "name": "定点のカメラ"}
			return "placed"
	return best

# ================================================================ input
func _unhandled_input(e):
	if main.card.visible or mode == END: return
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_E: _press()
		elif e.keycode == KEY_TAB: board_up = not board_up
		elif mode == TALK and cur.has("choose") and e.keycode in [KEY_W, KEY_UP]: _move_choice(-1)
		elif mode == TALK and cur.has("choose") and e.keycode in [KEY_S, KEY_DOWN]: _move_choice(1)
		elif mode == TALK and e.keycode in [KEY_SPACE, KEY_ENTER]: _press()
	elif e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_RIGHT: _set_finder(e.pressed)
		elif e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: _press()
		elif e.pressed and mode == TALK and cur.has("choose") and e.button_index == MOUSE_BUTTON_WHEEL_UP: _move_choice(-1)
		elif e.pressed and mode == TALK and cur.has("choose") and e.button_index == MOUSE_BUTTON_WHEEL_DOWN: _move_choice(1)

func _set_finder(on: bool):
	finder = on and holding_cam and mode == FREE
	finder_rest = {}

func _press():
	if mode == TALK: _advance(); return
	if mode != FREE: return
	if finder and holding_cam:
		if finder_rest.get("ok", false): _place()
		return
	if focus == "": return
	var it = items[focus]
	match focus:
		"placed": _pick_up_again()
		"fixedcam": _take_cam()
		_:
			talk_with = focus if items[focus].kind == "talk" else ""
			_start(_conversation(focus))

# ================================================================ the puzzle
func _take_cam():
	holding_cam = true
	_start([{"who": "澪", "text": "定点のカメラは、小さいものでした。手のひらに乗るくらいの。", "testimony": true},
		{"note": "［右クリックでのぞく　Ｅで置く］"}] if not talked.has("cam_hint") else [])
	talked["cam_hint"] = true

func _pick_up_again():
	cam_placed = false; holding_cam = true; items.erase("placed")

func _place():
	finder = false
	holding_cam = false; cam_placed = true
	var p: Vector3 = finder_rest.pos
	fixed_cam.visible = true
	fixed_cam.global_transform = Transform3D(Basis.from_euler(Vector3(player.pitch, player.yaw, 0.0), EULER_ORDER_YXZ), p + Vector3(0, 0.0, 0))
	placed = {"pos": p, "yaw": player.yaw, "pitch": player.pitch}
	talk_with = "kiryu"
	tries += 1
	_start(_judge())

func _target_angles() -> Array:
	var tp := g(TARGET_POS); var tl := g(TARGET_LOOK)
	var d := (tl - tp).normalized()
	return [atan2(-d.x, -d.z), asin(d.y)]

func _judge() -> Array:
	var tp := g(TARGET_POS)
	var ta := _target_angles()
	var dp: Vector3 = placed.pos - tp
	var dyaw := wrapf(placed.yaw - ta[0], -PI, PI)
	var dpitch: float = placed.pitch - ta[1]
	var horiz := Vector2(dp.x, dp.z).length()
	print("STORY judge try %d horiz %.2f dz %.2f yaw %.1f pitch %.1f" % [tries, horiz, dp.y, rad_to_deg(dyaw), rad_to_deg(dpitch)])
	var k := [{"who": "桐生", "text": "……どれ。"}]
	if horiz < 0.5 and abs(dp.y) < 0.32 and abs(dyaw) < deg_to_rad(13) and abs(dpitch) < deg_to_rad(11):
		cam_ok = true
		k.append({"who": "桐生", "text": "それ。……完璧。コンテそのまんま。"})
		k.append({"who": "桐生", "text": "じゃ、回しといて。夜通しな。"})
		k.append({"do": "rec_ready"})
		return k
	if tries >= 4 and horiz > 0.5:
		k.append({"who": "桐生", "text": "階段の手すり。あそこに挟んで、玄関を見下ろす。"})
	elif dp.y < -0.32:
		k.append({"who": "桐生", "text": "低い。もっと上から見下ろしたいんだよ、玄関を。"})
	elif horiz > 0.5:
		k.append({"who": "桐生", "text": "コンテ見て。手前に手すりが入ってるでしょ。"})
	elif abs(dyaw) >= deg_to_rad(13):
		k.append({"who": "桐生", "text": "もうちょい%s。扉が真ん中に来るように。" % ("右" if dyaw > 0 else "左")})
	elif dpitch > 0:
		k.append({"who": "桐生", "text": "上向きすぎ。天井はいらない、上がり框まで入れて。"})
	else:
		k.append({"who": "桐生", "text": "下向きすぎ。扉の上まで入れて。"})
	k.append({"note": "［カメラを拾い直す｜Ｅ］"})
	return k

# ================================================================ conversations
func _conversation(key: String) -> Array:
	var n: int = talked.get(key, 0); talked[key] = n + 1
	match key:
		"kiryu":
			if not has_board:
				return [{"who": "桐生", "text": "澪、ちょうどいい。定点、お願いしていい？"},
					{"who": "桐生", "text": "コンテの十二番。廊下に一台、夜通し回しっぱなしにしとくやつ。"},
					{"who": "桐生", "text": "ファウンドフッテージっぽく撮りたいんだよ。誰も見てないカメラが、全部見てた、みたいな。"},
					{"choose": ["なんで夜通し？", "わかった。どこに置けばいい？", "それ、陽太が好きなやつだ"],
					 "then": [[{"who": "桐生", "text": "何か起きたら、撮れてるだろ。……まあ、何も起きないけど。"}],
						[{"who": "桐生", "text": "それを探すのが澪の仕事。コンテと同じ画になるとこ。"}],
						[{"who": "桐生", "text": "……だろ。あいつ、こういうのがいちばん好きだったから。"}]]},
					{"who": "桐生", "text": "カメラは、そこの箱の上。コンテ渡しとく。"},
					{"do": "board"},
					{"note": "［絵コンテ｜Tab］"}]
			if cam_ok and not recording:
				return [{"who": "桐生", "text": "録画、押した？　赤いランプな。"}]
			if not holding_cam and not cam_placed:
				return [{"who": "桐生", "text": "カメラ、箱の上な。照明の横の。"}]
			return [{"who": "桐生", "text": "のぞいて、コンテと同じ画になるとこ探して。"}]
		"natsuki":
			if n == 0:
				return [{"who": "夏希", "text": "立ってるだけなのに、なんでこんなに疲れるんだろ。"},
					{"who": "夏希", "text": "澪、あのさ。"},
					{"who": "夏希", "text": "上映会のあと、ちょっとだけ時間ある？"},
					{"choose": ["あるよ", "なんの話？", "あとでね"],
					 "then": [[{"who": "夏希", "text": "……ありがと。あとで言う。"}],
						[{"who": "夏希", "text": "あとで。……今は、いい。"}],
						[{"who": "夏希", "text": "うん。あとで。"}]]}]
			return [{"who": "夏希", "text": "桐生、まだ？　足がテープに貼りつきそう。"}]
		"makoto":
			if n == 0:
				return [{"who": "真琴", "text": "先輩、これ、あとどのくらい持ってればいいんですか。"},
					{"who": "真琴", "text": "レフ板って、腕にくるんですね……。"},
					{"choose": ["代わろうか", "あと五分", "桐生に聞いて"],
					 "then": [[{"who": "真琴", "text": "だ、大丈夫です！　新入りなので！"}],
						[{"who": "真琴", "text": "五分……。はい。がんばります。"}],
						[{"who": "真琴", "text": "桐生さん、さっきから『あと五分』しか言わないんです。"}]]}]
			return [{"who": "真琴", "text": "ゾンビ映画って、最初に死ぬの、だいたい新入りですよね。"}]
		"taiga":
			if n == 0:
				return [{"who": "大河", "text": "ここ、停電多いらしいよ。管理の人が言ってた。"},
					{"who": "大河", "text": "地下に発電機あるって。いざとなったら回せるってさ。"},
					{"choose": ["いざって何", "詳しいね", "地下、行ったの？"],
					 "then": [[{"who": "大河", "text": "……ゾンビとか？"}],
						[{"who": "大河", "text": "案内係なんで。玄関、裏、地下。全部見といた。"}],
						[{"who": "大河", "text": "階段の下の扉な。貼り紙あったろ。"}]]}]
			return [{"who": "大河", "text": "この箱、どこ置けって言われたっけ。"}]
		"tape":
			return [{"who": "澪", "text": "夏希の立ち位置には、テープが貼ってありました。名前も書いてあって。字が、丸くて。", "testimony": true}]
		"camcorder":
			return [{"who": "澪", "text": "桐生さんの、いちばんいいカメラでした。あとで、私に貸してくれたんです。", "testimony": true}]
		"fresnel":
			return [{"who": "澪", "text": "照明は熱くて、近くに立つと顔が焼けそうでした。", "testimony": true}]
		"note":
			return [{"who": "澪", "text": "地下の扉には、貼り紙がありました。発電機、と書いてあったと思います。", "testimony": true}]
		"shoes":
			return [{"who": "澪", "text": "玄関に、みんなの靴がそろえてありました。そろえたのは、たぶん夏希です。", "testimony": true}]
	return []

const WHO_KEY := {"桐生": "kiryu", "夏希": "natsuki", "真琴": "makoto", "大河": "taiga"}

func _start(entries: Array):
	if entries.is_empty(): return
	script_q = entries.duplicate(true)
	if fade_tw and fade_tw.is_valid(): fade_tw.kill()
	lines_box.modulate.a = 1.0
	print("STORY start ", focus, " t=%.1f" % t_now)
	mode = TALK
	_clear_page()
	_next()

func _next():
	if script_q.is_empty():
		mode = FREE; cur = {}
		if lines_box.get_child_count() > 0:
			fade_tw = create_tween(); fade_tw.tween_property(lines_box, "modulate:a", 0.0, 1.6).set_delay(1.2)
			fade_tw.tween_callback(func(): _clear_page(); lines_box.modulate.a = 1.0)
		return
	cur = script_q.pop_front()
	typed = 0.0; wait_after = 0.0
	if cur.has("do"):
		_do(cur.do)
		if mode != END: _next()
		return
	if cur.has("note"):
		var r = _line_row("", cur.note, 26); cur_lb = r[1]; typed = 999.0; return
	if cur.has("choose"):
		choice_lbs = []; choice_idx = 0
		for i in range(cur.choose.size()):
			var r = _line_row("澪" if i == 0 else "", cur.choose[i])
			choice_lbs.append(r[1])
		_show_choice()
		return
	cur["who_key"] = WHO_KEY.get(cur.who, "")
	var r2 = _line_row(cur.who, "")
	cur_lb = r2[1]

func _show_choice():
	for i in range(choice_lbs.size()):
		var lb: Label = choice_lbs[i]
		lb.add_theme_color_override("font_color", paper if i == choice_idx else Color(paper.r, paper.g, paper.b, 0.45))
		lb.add_theme_color_override("font_shadow_color", Color(0.0, 0.33, 0.6, 0.9 if i == choice_idx else 0.3))

func _move_choice(d: int):
	if cur.get("chosen", false): return
	choice_idx = posmod(choice_idx + d, choice_lbs.size()); _show_choice()

class Strike extends Control:
	# the transcriber's double line through what she did not say
	var w := 0.0
	var u := 1.0
	func _draw():
		var c := Color(0.945, 0.925, 0.875, 0.9)
		var y := size.y * 0.52
		draw_line(Vector2(-4 * u, y - 4 * u), Vector2(w + 4 * u, y - 5 * u), c, 2.0 * u)
		draw_line(Vector2(-4 * u, y + 3 * u), Vector2(w + 4 * u, y + 2 * u), c, 2.0 * u)

func _choose():
	cur["chosen"] = true
	for i in range(choice_lbs.size()):
		if i == choice_idx: continue
		var lb: Label = choice_lbs[i]
		var s := Strike.new(); s.u = u
		s.w = font.get_string_size(lb.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(36 * u)).x
		s.size = lb.size; s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lb.add_child(s)
	var then: Array = cur.then[choice_idx]
	for i in range(then.size() - 1, -1, -1): script_q.push_front(then[i])
	wait_after = 1.1

func _talk_tick(dt):
	if cur.has("choose"):
		if cur.get("chosen", false):
			wait_after -= dt
			if wait_after <= 0.0: _next()
		return
	if cur.has("text"):
		var n: int = String(cur.text).length()
		if typed < n:
			typed = min(float(n), typed + dt * (20.0 if cur.get("testimony", false) else 24.0))
			if is_instance_valid(cur_lb): cur_lb.text = String(cur.text).substr(0, int(typed))

func _advance():
	if cur.has("choose"):
		if not cur.get("chosen", false): _choose()
		return
	if cur.has("text") and typed < String(cur.text).length():
		typed = String(cur.text).length(); cur_lb.text = cur.text; return
	_next()

func _do(what: String):
	print("STORY do ", what, " t=%.1f" % t_now)
	match what:
		"board":
			has_board = true; board_up = true
		"rec_ready":
			script_q.push_back({"note": "［録画｜Ｅ］"})
			script_q.push_back({"do": "rec"})
		"rec":
			_set_rec(true)
			# she looks up from the little camera to the take: Natsuki on her mark (the view turns by itself, then is hers again)
			var to: Vector3 = items.natsuki.pos - (player.get_node("Head/Camera") as Camera3D).global_position
			var p: Vector3 = player.global_position; var y0 := rad_to_deg(player.yaw)
			var y1: float = y0 + wrapf(rad_to_deg(atan2(-to.x, -to.z)) - y0, -180.0, 180.0)
			player.auto_path = [[0.0, p.x, p.z, y0, rad_to_deg(player.pitch)], [2.2, p.x, p.z, y1, rad_to_deg(asin(to.normalized().y))]]
			player.auto_t = 0.0
			get_tree().create_timer(2.4).timeout.connect(func(): if demo.is_empty(): player.auto_path = [])
			script_q.push_back({"who": "澪", "text": "録画のボタンを押しました。赤いランプが点いて。", "testimony": true})
			script_q.push_back({"who": "桐生", "text": "よし、本番いこう。夏希、テープの上な。"})
			script_q.push_back({"who": "夏希", "text": "はーい。"})
			script_q.push_back({"who": "桐生", "text": "よーい……"})
			script_q.push_back({"do": "blackout"})
		"blackout":
			mode = END; end_t = 0.0; script_q.clear()
			main.power_cut()
			_clear_page()

func _end_tick(dt):
	end_t += dt
	if end_t > 2.4 and lines_box.get_child_count() == 0:
		var r = _line_row("澪", "そこで、電気が消えたんです。")
		r[1].text = ""
		cur = {"text": "そこで、電気が消えたんです。"}; cur_lb = r[1]; typed = 0.0
	if cur.has("text") and typed < String(cur.text).length():
		typed += dt * 14.0; cur_lb.text = String(cur.text).substr(0, int(typed))
	if end_t > 9.0:
		main.to_night()

# check stills of the page, the board and the finder at full size without playing up to them
func _state(name: String):
	var put = func(x: float, y: float, yaw: float, pitch: float):
		player.global_position = Vector3(x, 0.0, -y); player.yaw = deg_to_rad(yaw); player.pitch = deg_to_rad(pitch)
	if name.begins_with("talk_"):   # mid-conversation with each of them: does the turned head sit right on the neck?
		var k := name.substr(5)
		var at := {"natsuki": [-0.2, 3.6, -43.0, -3.0], "makoto": [0.06, 3.3, -58.0, -3.0], "taiga": [0.2, 4.7, -2.0, -2.0], "kiryu": [-0.2, 3.6, 6.0, 0.0]}
		var q: Array = at[k]; put.call(q[0], q[1], q[2], q[3])
		talk_with = k; focus = k; _start(_conversation(k)); return
	match name:
		"talk":
			put.call(-0.2, 3.6, 6.0, 0.0); talk_with = "kiryu"; focus = "kiryu"; _start(_conversation("kiryu"))
			_advance(); _next(); _advance()
		"choice":
			put.call(-0.2, 3.6, 6.0, 0.0); talk_with = "kiryu"; focus = "kiryu"; _start(_conversation("kiryu"))
			while not cur.has("choose"): typed = 999.0; _next()
			choice_idx = 2; _show_choice(); _choose()
		"board":
			put.call(-0.2, 3.6, 6.0, 0.0); has_board = true; board_up = true
		"finder":
			put.call(0.06, 2.9, -6.0, -21.0); has_board = true; holding_cam = true; board_up = true
			finder = true; finder_rest = {"ok": true, "pos": g([0.30, 2.90, _rail_z(2.90) + 0.065]), "what": "手すり"}
		"look":
			put.call(-0.2, 3.6, -48.0, -62.0)
		"carry":
			put.call(-0.2, 3.6, 0.0, -4.0); has_board = true; holding_cam = true

# ================================================================ unattended playthrough (for the check movie)
# steps: ["go", x, y, yaw_deg, pitch_deg, secs] (Blender x, y of the feet) | ["look", yaw, pitch, secs] | ["e"] | ["pick", i]
#        ["finder", on] | ["board", on] | ["wait", secs] | ["until_free"]
func _demo_script():
	demo = [
		["wait", 1.5],
		["go", 0.06, 2.45, 2.0, -4.0, 3.0], ["go", 0.06, 3.30, 0.0, -4.0, 2.6], ["go", -0.20, 3.60, 6.0, -2.0, 1.6],
		["look", 6.0, 0.0, 1.4], ["wait", 0.6], ["e"], ["auto", 2], ["until_free"],       # 桐生: the job, the board
		["wait", 2.5], ["board", false],
		["look", -43.0, -2.0, 1.2], ["e"], ["auto", 2], ["until_free"],                   # 夏希
		["look", -48.0, -62.0, 1.2], ["wait", 0.5], ["e"], ["until_free"],               # the tape on the floor
		["look", -77.0, -2.0, 1.2], ["e"], ["auto", 0], ["until_free"],                    # 真琴
		["look", 58.0, -68.0, 1.4], ["wait", 0.5], ["e"], ["until_free"],                # the small camera on the apple box
		# first try: set it on the apple box and aim at the door - too low
		["finder", true], ["wait", 0.6], ["look", 4.0, -4.0, 1.6], ["wait", 1.4], ["e"], ["until_free"],
		["look", 58.0, -64.0, 1.0], ["wait", 0.4], ["e"],
		# up the walkway beside the stair, onto the handrail
		["go", 0.06, 3.30, 160.0, -10.0, 1.8], ["go", 0.06, 2.90, 0.0, -10.0, 1.6],
		["board", true], ["wait", 2.2], ["board", false],
		["look", -90.0, 50.0, 1.4], ["finder", true], ["wait", 0.6],
		["look", -6.0, -21.0, 2.0], ["board", true], ["wait", 2.4], ["board", false], ["wait", 0.6], ["e"], ["until_free"],
		["until_end"],
	]

func _demo_tick(dt):
	if demo.is_empty() or demo_i >= demo.size(): return
	var s: Array = demo[demo_i]
	demo_t += dt
	var done := false
	match s[0]:
		"wait": done = demo_t >= s[1]
		"go":
			if demo_t <= dt * 1.5:
				var p: Vector3 = player.global_position
				player.auto_path = [[0.0, p.x, p.z, rad_to_deg(player.yaw), rad_to_deg(player.pitch)], [float(s[5]), s[1], -s[2], s[3], s[4]]]
				player.auto_t = 0.0
			done = demo_t >= s[5] + 0.3
		"look":
			if demo_t <= dt * 1.5:
				var p2: Vector3 = player.global_position
				var y0 := rad_to_deg(player.yaw); var y1: float = y0 + wrapf(float(s[1]) - y0, -180.0, 180.0)
				player.auto_path = [[0.0, p2.x, p2.z, y0, rad_to_deg(player.pitch)], [float(s[3]), p2.x, p2.z, y1, s[2]]]
				player.auto_t = 0.0
			done = demo_t >= s[3] + 0.2
		"e": _press(); done = true
		"auto": S_auto = int(s[1]); done = true
		"finder": _set_finder(s[1]); done = true
		"board": board_up = s[1]; done = true
		"until_free":
			if mode == TALK:
				# read each line, then go on; choose the given option
				if cur.has("choose") and not cur.get("chosen", false):
					if demo_t > 1.6:
						choice_idx = clamp(S_auto, 0, choice_lbs.size() - 1); _show_choice()
					if demo_t > 2.6: _advance(); demo_t = 0.0
				elif cur.has("text") and typed >= String(cur.text).length() and demo_t > 1.0 + String(cur.text).length() * 0.035:
					_advance(); demo_t = 0.0
				elif cur.has("note") and demo_t > 1.6:
					_advance(); demo_t = 0.0
			else:
				done = demo_t > 0.3
		"until_end": done = false
	if done: demo_i += 1; demo_t = 0.0

var S_auto := 0
var fade_tw: Tween
var talk_with := ""

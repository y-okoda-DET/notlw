## 第1章の頭：行きの車の中（2026-11-20 練り直し。台本は story/ch1.txt【一.車】【一.車.停める】【一.車.*】）。
## 序章のあと、第1章のカード「あの別荘には、どうして行ったんですか？」から始まり、家が見えて題名が一度出て、夕方の撮影（main の
## dusk、story.gd）へ続く。main.gd が play="ch1car" で作る（家まるごとの夕方の光：TIME "dusk"）。
##
## 澪は助手席（左）に座ったまま見回せる。歩けない。Ｅで調べる（テープ、夏希のスマホ、後ろの真琴、窓の外）。
## カメラは澪の目のまま切らない。夏希の台詞は時間で流れ、調べている間も止まらない（door.gd と同じ仕組み）。
## 車は林道（blender/outside_geo.py ROAD）を南から上り、崩れる前の路肩の曲がり角を通り、私道（DRIVE）の入り口で停まる。
## 夏希が話し終えると私道を上る。林の切れ目で、プレイヤーが前（家）を見るまで車はゆっくり進み、見たら題名を一度だけ出す。
##
## The car is this script's own: Natsuki's white car (the Tripo mesh the house has parked on the drive, ext_car, a copy of it
## cut at the belt line so that its hood shows through the windshield) round an inside built here (dash, wheel, seats,
## pillars, roof, the mirror). Natsuki drives (sitting, her hands held on the wheel by a two-bone reach), Makoto sleeps
## behind Mio.
extends "res://scripts/story.gd"
const Sound = preload("res://scripts/sound.gd")

# the way, in Blender's world metres (x, y, z of the road's surface): the forest road from its south end up round the bend
# above the ravine (the shoulder that goes at two, its cone and its board) west to the drive, then the drive up to the house.
# Made by outside_geo.py ROAD / DRIVE (on the left half of the road, round the cone on the right): the generator is in
# NOTES.md (2026-11-20 行きの車).
const PATH := [[42.78, 106.47, -10.715], [44.07, 104.95, -10.708], [45.37, 103.43, -10.702], [46.68, 101.92, -10.698], [47.98, 100.4, -10.695], [49.28, 98.87, -10.696], [50.58, 97.34, -10.7], [51.86, 95.81, -10.708], [53.14, 94.26, -10.721], [54.4, 92.71, -10.738], [55.68, 91.18, -10.761], [56.97, 89.66, -10.788], [58.26, 88.12, -10.821], [59.54, 86.56, -10.857], [60.78, 84.96, -10.897], [61.98, 83.32, -10.94], [63.1, 81.6, -10.984], [64.12, 79.82, -11.029], [65.05, 78.01, -11.073], [65.91, 76.17, -11.114], [66.7, 74.29, -11.149], [67.4, 72.37, -11.176], [68.01, 70.42, -11.191], [68.51, 68.42, -11.189], [68.86, 66.38, -11.168], [69.03, 64.3, -11.122], [69.01, 62.22, -11.048], [68.8, 60.15, -10.944], [68.4, 58.11, -10.809], [67.82, 56.11, -10.642], [67.07, 54.17, -10.447], [66.12, 52.3, -10.23], [64.97, 50.55, -10.01], [63.66, 48.93, -9.79], [62.24, 47.43, -9.57], [60.72, 46.05, -9.35], [59.15, 44.75, -9.13], [57.52, 43.52, -8.91], [55.84, 42.37, -8.69], [54.12, 41.28, -8.47], [52.36, 40.26, -8.25], [50.55, 39.32, -8.03], [48.7, 38.46, -7.81], [46.8, 37.69, -7.59], [44.87, 37.01, -7.37], [42.9, 36.45, -7.15], [40.91, 35.99, -6.93], [38.91, 35.62, -6.71], [36.92, 35.29, -6.49], [34.93, 35.01, -6.27], [32.94, 34.75, -6.05], [30.95, 34.49, -5.83], [28.98, 34.23, -5.61], [27.0, 33.95, -5.39], [25.0, 33.69, -5.17], [23.01, 33.45, -4.95], [21.02, 33.23, -4.73], [19.02, 33.02, -4.51], [17.03, 32.81, -4.29], [15.04, 32.61, -4.07], [13.05, 32.41, -3.85], [8.3, 30.53, -3.294], [7.82, 29.11, -3.08], [7.28, 27.71, -2.839], [6.69, 26.33, -2.58], [6.07, 24.96, -2.317], [5.47, 23.59, -2.06], [4.88, 22.21, -1.822], [4.31, 20.82, -1.61], [3.74, 19.43, -1.427], [3.19, 18.04, -1.271], [2.65, 16.64, -1.138], [2.13, 15.23, -1.023], [1.63, 13.81, -0.92], [1.17, 12.39, -0.824], [0.75, 10.95, -0.731]]
const DRIVE_I := 61                  # PATH's first point on the drive
const SLIP_AT := [67.87, 60.03]      # the shoulder that goes (outside_geo SLIP_IDX)
const HOUSE_AT := [0.2, 4.0, 1.5]    # the front of the house (what she should see at the gap)
const STOP_BACK := 24.0              # she stops on the forest road this far short of the drive (the house is not seen from there:
                                     # from the drive's foot it is, 試し撮り 2026-11-20)
const REVEAL_IN := 3.0               # metres up the drive: the house in the gap of the cedars, ahead
const END_BACK := 5.0                # it stops here, short of the porch (the cut is before)

# the car's frame: x to the right, y up from the ground, -z forward (front). Right-hand drive: Natsuki at +x, Mio at -x
const LEN := 4.0
const SEAT_MIO := Vector3(-0.37, 0.40, 0.10)     # the cushion under her (the player's body stands here)
const EYE_UP := 0.70                             # her eye over it
const SEAT_NAT := Vector3(0.37, 0.40, 0.10)
const SEAT_MK := Vector3(-0.30, 0.42, 0.96)
const WHEEL := Vector3(0.37, 0.90, -0.34)        # the wheel's middle
const WHEEL_TILT := 0.42                          # its face turned up from upright (rad)
const WHEEL_R := 0.185
const MIRROR := Vector3(0.0, 1.245, -0.28)
const TAPE_AT := Vector3(-0.28, 0.934, -0.74)    # on the dash, Mio's side, against the windshield
const PHONE_AT := Vector3(0.13, 0.86, -0.505)    # clipped to the vent at the wheel's left (the middle of the dash: Mio sees it)
const BELT := 0.98                               # the Tripo body is cut above this (the inside is ours)

var LINES := []; var LIF := []; var li := 0
var STOP_LINES := []; var SIF := []; var si := 0
var car: Node3D
var curve: Curve3D
var d := 0.0                # metres along the way
var v := 4.6                # m/s
var d_slip := 0.0
var d_stop := 0.0
var d_drive := 0.0
var d_reveal := 0.0
var d_end := 0.0
var stage := "card"         # card | drive | stop | parked | drive_on | gap | title | out
var t_stage := 0.0
var card: Control
var card_t := 0.0
var wheel: Node3D
var steer := 0.0
var nat_ik: ReachIK
var mirror_vp: SubViewport
var mirror_cam: Camera3D
var mirror_mesh: MeshInstance3D
var title_layer: CanvasLayer
var title_rect: TextureRect
var title_t := -1.0
var black: ColorRect
var focus_k := ""
var looked_at := {}
var dlook := {}
var demo_car := false
var demo_looks := [[8.0, "tape"], [15.0, "window"], [26.0, "phone"], [36.0, "makoto"]]
var demo_aims := [[44.0, 52.0, "natsuki"], [53.0, 60.0, "mirror"], [61.0, 70.0, "natsuki"]]   # (t_now) the run turns to these too: the stills
var blink_t := 0.0
var loops := {}
var car_radio_on := false
var bump := 0.0
var bump_v := 0.0
var sway := Vector3.ZERO
var prev_fwd := Vector3.FORWARD

func _ready():
	player = main.player
	font = Type.say()
	u = get_viewport().get_visible_rect().size.y / 1080.0
	offscreen = []
	demo_car = "--demo" in OS.get_cmdline_user_args()
	for e in B("一.車"): _line_of(e, LINES, LIF)
	for e in B("一.車.停める"): _line_of(e, STOP_LINES, SIF)
	_page()
	_curve()
	_build_car()
	_people()
	_mirror()
	_title()
	_seat_player()
	_black()
	# the chapter's card, as the old 第1章 had it (main.gd _card), here at the car's start
	card = main.make_card(self, [["第 一 章", 46, 40], ["ルール", 150, 90], ["あの別荘には、どうして行ったんですか？", 36, 0]], Type.card())
	card_t = 0.0 if "--nocard" in OS.get_cmdline_user_args() else 3.2
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cart="): call_deferred("_jump", float(a.substr(7)))   # check stills: the drive from this second
		if a == "--carstop": call_deferred("_jump_stop")
		if a.begins_with("--carcam="): var c := a.substr(9).split(","); carcam = Vector3(float(c[0]), float(c[1]), float(c[2]))
		if a == "--cargap": call_deferred("_jump_gap")
	_loop("car_drive", -14.0)
	print("CAR ready d_slip=%.1f d_stop=%.1f d_reveal=%.1f d_end=%.1f len=%.1f" % [d_slip, d_stop, d_reveal, d_end, curve.get_baked_length()])

func _line_of(e: Dictionary, arr: Array, ifs: Array):
	ifs.append(String(e.get("if", "")))
	if e.has("do"): arr.append([e.t, e.do])
	elif e.has("note"): arr.append([e.t, "note", e.note])
	else: arr.append([e.t, e.who, e.text, "testimony" if e.get("testimony", false) else ""])

# ---------------------------------------------------------------- the way
func _curve():
	curve = Curve3D.new(); curve.bake_interval = 0.25
	var pts := []
	for p in PATH: pts.append(main.b2g(p))
	for i in pts.size():
		var a: Vector3 = pts[maxi(i - 1, 0)]; var b: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		var t: Vector3 = (b - a) * 0.22
		curve.add_point(pts[i], -t, t)
	var L := curve.get_baked_length()
	d_slip = curve.get_closest_offset(main.b2g([SLIP_AT[0], SLIP_AT[1], -11.0]))
	d_drive = curve.get_closest_offset(pts[DRIVE_I])
	d_stop = d_drive - STOP_BACK
	d_end = L - END_BACK
	d_reveal = d_drive + REVEAL_IN
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--carreveal="): d_reveal = d_drive + float(a.substr(12))

func _at(dd: float) -> Transform3D:
	var p := curve.sample_baked(clampf(dd, 0.0, curve.get_baked_length()), true)
	var a := curve.sample_baked(clampf(dd - 1.4, 0.0, curve.get_baked_length()), true)
	var b := curve.sample_baked(clampf(dd + 1.4, 0.0, curve.get_baked_length()), true)
	var f := (b - a).normalized()
	var basis := Basis.looking_at(f, Vector3.UP)
	return Transform3D(basis, p)

# ---------------------------------------------------------------- the car
func _build_car():
	car = Node3D.new(); car.name = "car1"; add_child(car)
	# the parked one goes (this is it, on its way up)
	var src: MeshInstance3D = null
	for mi in main.S.env_node.find_children("ext_car*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = false
		if src == null: src = mi
	if src:
		var body := MeshInstance3D.new(); body.mesh = src.mesh; body.name = "car_body"
		var sc: float = src.global_basis.get_scale().x
		# Tripo's front is +z in its own frame (furnish.tripo_prop: -Y in Blender); ours is -z
		body.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3(sc, sc, sc)), Vector3.ZERO)
		body.material_override = _cut_mat(src)
		print("CAR body from %s scale=%s aabb=%s" % [src.name, src.global_basis.get_scale(), src.mesh.get_aabb()])
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		car.add_child(body)
	_inside()
	# the dark under the car (as ch7 has it on the drive)
	var sh := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(1.9, 3.9); q.orientation = PlaneMesh.FACE_Y
	sh.mesh = q; sh.position = Vector3(0, 0.03, 0)
	var shm := StandardMaterial3D.new(); shm.albedo_color = Color(0, 0, 0, 0.55); shm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.fill = GradientTexture2D.FILL_RADIAL; gt.fill_from = Vector2(0.5, 0.5); gt.fill_to = Vector2(1.0, 0.5)
	shm.albedo_texture = gt; sh.material_override = shm; sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	car.add_child(sh)
	car.global_transform = _at(0.0)

# the Tripo body, cut at the belt line and behind the windshield's foot: from inside, its hood and fenders show through the glass
const CUT_SHADER := """shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D rm_tex : filter_linear_mipmap;
uniform float belt = 0.98;
uniform float scale = 4.0;
varying vec3 lp;
void vertex() { lp = VERTEX * scale; }
void fragment() {
	// Tripo's frame: +z its front. The hood runs back to z .95 (y .96), the windshield from there up to the roof (z .35,
	// y 1.30), the roof (1.40) back to z -1.25, the hatch down to -1.95. Above the belt behind the windshield's foot is ours;
	// the door mirrors (out at the sides) stay
	bool mirror = abs(lp.x) > 0.80 && lp.z > 0.55 && lp.z < 1.0 && lp.y < 1.18;
	if (lp.y > belt && lp.z < 0.95 && !mirror) discard;
	vec4 a = texture(albedo_tex, UV);
	ALBEDO = a.rgb;
	vec4 rm = texture(rm_tex, UV);
	ROUGHNESS = clamp(rm.g, 0.25, 1.0);
	METALLIC = rm.b * 0.6;
	if (!FRONT_FACING) { ALBEDO *= 0.15; }
}
"""
func _cut_mat(src: MeshInstance3D) -> Material:
	var m0 := src.get_active_material(0) as StandardMaterial3D
	var sm := ShaderMaterial.new(); var sh := Shader.new(); sh.code = CUT_SHADER; sm.shader = sh
	if m0:
		sm.set_shader_parameter("albedo_tex", m0.albedo_texture)
		sm.set_shader_parameter("rm_tex", m0.roughness_texture if m0.roughness_texture else m0.albedo_texture)
	sm.set_shader_parameter("belt", BELT)
	var sc := src.global_basis.get_scale().x
	sm.set_shader_parameter("scale", sc)
	return sm

func _mat(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = rough; m.metallic = metal
	return m

func _box(parent: Node3D, size: Vector3, at: Vector3, m: Material, rot := Vector3.ZERO, nm := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.position = at; mi.rotation = rot
	if nm != "": mi.name = nm
	parent.add_child(mi)
	return mi

# a slab between two points along z (for the dash's top, the roof, the pillars): its thickness t, its width w
func _slab(parent: Node3D, a: Vector3, b: Vector3, w: float, t: float, m: Material, nm := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new()
	var L := a.distance_to(b)
	bm.size = Vector3(w, t, L); mi.mesh = bm; mi.material_override = m
	var f := (b - a).normalized()
	var up := Vector3.UP if absf(f.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	mi.transform = Transform3D(Basis.looking_at(f, up), (a + b) * 0.5)
	if nm != "": mi.name = nm
	parent.add_child(mi)
	return mi

func _inside():
	var dash := _mat(Color(0.105, 0.105, 0.11), 0.9)
	var dash2 := _mat(Color(0.16, 0.16, 0.165), 0.7)
	var cloth := _mat(Color(0.30, 0.30, 0.31), 1.0)
	var cloth_d := _mat(Color(0.20, 0.20, 0.21), 1.0)
	var liner := _mat(Color(0.62, 0.60, 0.56), 1.0)
	var trim := _mat(Color(0.45, 0.44, 0.42), 0.8)
	var inn := Node3D.new(); inn.name = "inside"; car.add_child(inn)
	# fitted to the Tripo body (its windshield's foot at z -.95, y .96; its top at z -.30, y 1.32; the roof inside 1.34;
	# the hatch from z 1.30): the dash from the windshield's foot back over the gauges, its face down to the knees
	_slab(inn, Vector3(0, 0.905, -0.93), Vector3(0, 0.885, -0.52), 1.56, 0.04, dash, "dash_top")
	_slab(inn, Vector3(0, 0.88, -0.52), Vector3(0, 0.62, -0.40), 1.56, 0.06, dash2, "dash_face")
	_box(inn, Vector3(1.56, 0.28, 0.45), Vector3(0, 0.74, -0.74), dash, Vector3.ZERO, "dash_body")
	# the hood over the gauges (Natsuki's side), the gauges' glass, the centre stack, the glove box, the vents
	_slab(inn, Vector3(0.37, 0.955, -0.68), Vector3(0.37, 0.935, -0.50), 0.36, 0.035, dash, "binnacle")
	var gauge := _mat(Color(0.05, 0.05, 0.06), 0.2); gauge.emission_enabled = true; gauge.emission = Color(0.9, 0.55, 0.2); gauge.emission_energy_multiplier = 0.15
	_box(inn, Vector3(0.30, 0.10, 0.01), Vector3(0.37, 0.87, -0.555), gauge, Vector3(-0.3, 0, 0), "gauges")
	_box(inn, Vector3(0.24, 0.30, 0.12), Vector3(0.0, 0.70, -0.47), dash, Vector3(-0.25, 0, 0), "stack")
	var lcd := _mat(Color(0.03, 0.05, 0.05), 0.3); lcd.emission_enabled = true; lcd.emission = Color(0.35, 0.75, 0.70); lcd.emission_energy_multiplier = 0.35
	_box(inn, Vector3(0.17, 0.05, 0.01), Vector3(0.0, 0.83, -0.405), lcd, Vector3(-0.25, 0, 0), "radio_lcd")
	_box(inn, Vector3(0.40, 0.16, 0.02), Vector3(-0.40, 0.70, -0.42), dash2, Vector3(-0.2, 0, 0), "glovebox")
	for x in [-0.66, -0.12, 0.12, 0.66]:
		_box(inn, Vector3(0.12, 0.05, 0.02), Vector3(x, 0.84, -0.50), _mat(Color(0.06, 0.06, 0.065), 0.6), Vector3(-0.3, 0, 0), "vent")
	# the floor, the console between the seats, the shift
	_box(inn, Vector3(1.6, 0.04, 2.3), Vector3(0, 0.26, 0.40), cloth_d, Vector3.ZERO, "floor")
	_box(inn, Vector3(0.20, 0.20, 0.60), Vector3(0, 0.40, 0.02), dash, Vector3.ZERO, "console")
	_box(inn, Vector3(0.05, 0.12, 0.05), Vector3(0, 0.56, -0.18), dash2, Vector3(0.3, 0, 0), "shift")
	# the roof's lining and the sun visors (folded up)
	_box(inn, Vector3(1.50, 0.03, 1.62), Vector3(0, 1.345, 0.50), liner, Vector3.ZERO, "roof")
	for x in [-0.37, 0.37]: _box(inn, Vector3(0.40, 0.025, 0.17), Vector3(x, 1.315, -0.20), liner, Vector3(0.25, 0, 0), "visor")
	# the windshield's frame: the pillars (A, B, C), the roof's front edge, the doors' tops (the belt line) and the doors
	for sx in [-1.0, 1.0]:
		_slab(inn, Vector3(sx * 0.72, 0.96, -0.95), Vector3(sx * 0.66, 1.33, -0.30), 0.075, 0.09, trim, "pillar_a")
		_box(inn, Vector3(0.07, 0.38, 0.10), Vector3(sx * 0.71, 1.16, 0.42), trim, Vector3.ZERO, "pillar_b")
		_slab(inn, Vector3(sx * 0.72, 0.98, 1.48), Vector3(sx * 0.64, 1.33, 1.24), 0.07, 0.26, trim, "pillar_c")
		_box(inn, Vector3(0.06, 0.70, 1.35), Vector3(sx * 0.80, 0.63, -0.27), cloth_d, Vector3.ZERO, "door_f")
		_box(inn, Vector3(0.06, 0.70, 0.90), Vector3(sx * 0.80, 0.63, 0.86), cloth_d, Vector3.ZERO, "door_r")
		_box(inn, Vector3(0.10, 0.04, 2.45), Vector3(sx * 0.77, 0.975, 0.26), trim, Vector3.ZERO, "belt")
		_box(inn, Vector3(0.09, 0.05, 0.30), Vector3(sx * 0.74, 0.74, -0.22), dash2, Vector3.ZERO, "armrest")
	_box(inn, Vector3(1.44, 0.05, 0.08), Vector3(0, 1.325, -0.31), trim, Vector3.ZERO, "header")
	_box(inn, Vector3(1.44, 0.08, 0.06), Vector3(0, 1.31, 1.33), trim, Vector3.ZERO, "rear_header")
	_box(inn, Vector3(1.44, 0.04, 0.40), Vector3(0, 0.98, 1.62), cloth_d, Vector3.ZERO, "parcel")
	# the seats: two in front, the bench behind
	for x in [SEAT_MIO.x, SEAT_NAT.x]:
		_box(inn, Vector3(0.50, 0.12, 0.52), Vector3(x, 0.40, 0.10), cloth, Vector3(0.08, 0, 0), "cushion")
		_slab(inn, Vector3(x, 0.47, 0.38), Vector3(x, 1.10, 0.50), 0.50, 0.12, cloth, "back")
		_box(inn, Vector3(0.26, 0.19, 0.10), Vector3(x, 1.21, 0.53), cloth, Vector3(-0.1, 0, 0), "headrest")
	_box(inn, Vector3(1.36, 0.12, 0.50), Vector3(0, 0.42, 0.98), cloth, Vector3(0.06, 0, 0), "bench")
	_slab(inn, Vector3(0, 0.48, 1.22), Vector3(0, 1.04, 1.32), 1.36, 0.12, cloth, "bench_back")
	# the wheel: a ring on its column, turned by the road (Natsuki's hands on it)
	wheel = Node3D.new(); wheel.name = "wheel"; inn.add_child(wheel)
	wheel.position = WHEEL; wheel.rotation = Vector3(WHEEL_TILT, 0, 0)
	var ring := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = WHEEL_R - 0.016; tm.outer_radius = WHEEL_R + 0.016
	tm.rings = 32; tm.ring_segments = 10; ring.mesh = tm; ring.rotation = Vector3(PI / 2, 0, 0); ring.material_override = _mat(Color(0.06, 0.06, 0.06), 0.55)
	wheel.add_child(ring)
	_box(wheel, Vector3(0.12, 0.10, 0.06), Vector3(0, 0, 0.0), dash2, Vector3.ZERO, "hub")
	for a in [PI / 2, -PI / 2, PI]:
		_box(wheel, Vector3(WHEEL_R - 0.02, 0.03, 0.02), Vector3(cos(a) * WHEEL_R * 0.5, sin(a) * WHEEL_R * 0.5, 0.0), dash2, Vector3(0, 0, a), "spoke")
	_slab(inn, WHEEL + Vector3(0, -0.02, -0.05), WHEEL + Vector3(0, -0.10, -0.24), 0.07, 0.07, dash, "column")
	# Natsuki's things: the tape on the dash, her phone on the vent
	_tape(inn)
	_phone(inn)
	# the glass: faint, the dash and the sky in it (no more: the road must read through it)
	var glass := StandardMaterial3D.new(); glass.albedo_color = Color(0.55, 0.62, 0.66, 0.07); glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05; glass.metallic_specular = 0.9; glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ws := _slab(inn, Vector3(0, 0.955, -0.97), Vector3(0, 1.33, -0.31), 1.42, 0.004, glass, "windshield")
	ws.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# a little light inside (the sky through the glass): the dash is not lost to black against the bright road
	var fill := OmniLight3D.new(); fill.name = "car_fill"; fill.position = Vector3(0, 1.25, 0.30); fill.omni_range = 2.2
	fill.light_energy = 0.35; fill.light_color = Color(0.85, 0.88, 0.92); fill.shadow_enabled = false; fill.light_specular = 0.05
	car.add_child(fill)
	var fill2 := OmniLight3D.new(); fill2.name = "car_fill2"; fill2.position = Vector3(0, 1.05, -1.0); fill2.omni_range = 1.4
	fill2.light_energy = 0.25; fill2.light_color = Color(1.0, 0.95, 0.88); fill2.shadow_enabled = false; fill2.light_specular = 0.0
	car.add_child(fill2)

# the cassette (8 mm: the size of a deck of cards), its label in Natsuki's round hand
var tape_node: Node3D
func _tape(inn: Node3D):
	tape_node = Node3D.new(); tape_node.name = "tape8"; inn.add_child(tape_node)
	tape_node.position = TAPE_AT; tape_node.rotation = Vector3(0, 0.35, 0)
	_box(tape_node, Vector3(0.095, 0.016, 0.062), Vector3.ZERO, _mat(Color(0.08, 0.08, 0.085), 0.4), Vector3.ZERO, "shell")
	_box(tape_node, Vector3(0.06, 0.002, 0.03), Vector3(0, 0.0085, 0.006), _mat(Color(0.93, 0.92, 0.86), 0.9), Vector3.ZERO, "label")
	var l := Label3D.new(); l.text = "上映用"; l.font = Type.say(); l.font_size = 64; l.pixel_size = 0.00028
	l.modulate = Color(0.12, 0.16, 0.45); l.outline_size = 0; l.shaded = true
	l.rotation = Vector3(-PI / 2, 0, 0); l.position = Vector3(0, 0.0098, 0.006)
	tape_node.add_child(l)

var phone_lb: Label3D
func _phone(inn: Node3D):
	var ph := Node3D.new(); ph.name = "phone"; inn.add_child(ph)
	ph.position = PHONE_AT; ph.rotation = Vector3(-0.3, 0.18, 0)
	_box(ph, Vector3(0.072, 0.15, 0.009), Vector3.ZERO, _mat(Color(0.05, 0.05, 0.06), 0.3), Vector3.ZERO, "case")
	var scr := _mat(Color(0.02, 0.02, 0.03), 0.2); scr.emission_enabled = true; scr.emission = Color(0.55, 0.62, 0.72); scr.emission_energy_multiplier = 0.55
	_box(ph, Vector3(0.064, 0.138, 0.001), Vector3(0, 0, 0.005), scr, Vector3.ZERO, "screen")
	phone_lb = Label3D.new(); phone_lb.text = "16:52\n8月14日"; phone_lb.font = Type.say(); phone_lb.font_size = 48
	phone_lb.pixel_size = 0.00032; phone_lb.modulate = Color(1, 1, 1, 0.92); phone_lb.position = Vector3(0, 0.03, 0.0062)
	phone_lb.shaded = false; phone_lb.line_spacing = -10
	ph.add_child(phone_lb)

# ---------------------------------------------------------------- the people
func _people():
	for k in ["kiryu", "taiga"]:
		if main.S.has(k + "_node"): (main.S[k + "_node"] as Node3D).visible = false
		if main.S.has(k + "_col"): (main.S[k + "_col"] as Node3D).position.y = -50.0
	_seat("natsuki", SEAT_NAT, "res://assets/dusk/natsuki_c7.res", "sit_idle")
	_seat("makoto", SEAT_MK, "res://assets/dusk/makoto_talk.res", "sit_a")
	# Makoto sleeps: her eyes stay shut (main.gd _update_faces)
	if main.faces.has("makoto"):
		var f = main.faces.makoto
		f.tex = {"open": f.tex.closed, "closed": f.tex.closed, "talk": f.tex.closed}
	if main.S.has("makoto_node"): _earphone()
	if main.S.has("natsuki_node"):
		var sk: Skeleton3D = (main.S.natsuki_node as Node).find_children("*", "Skeleton3D", true, false)[0]
		nat_ik = ReachIK.new(); nat_ik.name = "reach"; sk.add_child(nat_ik)
		nat_ik.setup()

func _seat(k: String, at: Vector3, lib_path: String, clip: String):
	if not main.S.has(k + "_node"): return
	var inst: Node3D = main.S[k + "_node"]
	var sks: Array = inst.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty(): return
	var sk: Skeleton3D = sks[0]
	var rig := sk.get_parent() as Node3D
	# one clip only on this player (Godot 4.4.1 and many animations on one player: main.gd TALK_CLIPS)
	for ap in inst.find_children("*", "AnimationPlayer", true, false):
		var p := ap as AnimationPlayer
		p.stop()
		for ln in p.get_animation_library_list(): p.remove_animation_library(ln)
		if ResourceLoader.exists(lib_path):
			var src: AnimationLibrary = load(lib_path)
			var lib := AnimationLibrary.new()
			if src.has_animation(clip):
				var an: Animation = src.get_animation(clip).duplicate(); an.loop_mode = Animation.LOOP_LINEAR
				lib.add_animation("sit", an)
			p.add_animation_library("car", lib)
			if p.has_animation("car/sit"): p.play("car/sit")
	# in the car's frame: facing forward (-z); the rig's own forward is +z (main.place_person: Basis(UP, yaw))
	if main.S.has(k + "_col"): (main.S[k + "_col"] as Node3D).position.y = -50.0
	var holder := Node3D.new(); holder.name = "seat_" + k; car.add_child(holder)
	holder.position = at + Vector3(0, -SIT_HIP, 0.04)
	holder.rotation = Vector3(0, PI, 0)
	sitters[k] = [rig, holder]
const SIT_HIP := 0.31        # the sitting clips (a chair: hips .43 over the feet) set lower: in the car the feet are on its floor (.28), the hips on the cushion (car.gd probe)
var sitters := {}

var earphone: MeshInstance3D
func _earphone():
	# one earphone (white), in her left ear: the other hangs
	var sk: Skeleton3D = (main.S.makoto_node as Node).find_children("*", "Skeleton3D", true, false)[0]
	var ba := BoneAttachment3D.new(); ba.bone_name = "head"; sk.add_child(ba)
	earphone = MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.011; sm.height = 0.02; earphone.mesh = sm
	earphone.material_override = _mat(Color(0.92, 0.92, 0.9), 0.4)
	ba.add_child(earphone)
	earphone.position = Vector3(0.075, 0.07, 0.0)

var probed := false
var probe_n := 0
func _place_people():
	for k in sitters:
		var r: Node3D = sitters[k][0]; var h: Node3D = sitters[k][1]
		r.global_transform = h.global_transform
	if not probed and Engine.get_process_frames() > 150 and "--carprobe" in OS.get_cmdline_user_args():
		probed = true
		for k in sitters:
			for ap in (main.S[k + "_node"] as Node).find_children("*", "AnimationPlayer", true, false):
				print("CAR probe %s ap %s playing=%s cur=%s pos=%.2f active=%s libs=%s" % [k, ap.name, ap.is_playing(), ap.current_animation, ap.current_animation_position, ap.active, ap.get_animation_library_list()])
			var sk: Skeleton3D = (main.S[k + "_node"] as Node).find_children("*", "Skeleton3D", true, false)[0]
			var inv := car.global_transform.affine_inverse()
			for b in ["pelvis", "head", "foot_l", "hand_l", "hand_r", "upperarm_r"]:
				var bi := sk.find_bone(b)
				if bi >= 0: print("CAR probe %s %s %s" % [k, b, inv * (sk.global_transform * sk.get_bone_global_pose(bi).origin)])

# ---------------------------------------------------------------- the mirror (Makoto asleep behind, in it)
func _mirror():
	var inn: Node3D = car.get_node("inside")
	var holder := Node3D.new(); holder.name = "mirror"; inn.add_child(holder)
	holder.position = MIRROR; holder.rotation = Vector3(0.05, 0.22, 0)   # turned to the driver
	_box(holder, Vector3(0.23, 0.068, 0.03), Vector3(0, 0, -0.012), _mat(Color(0.08, 0.08, 0.085), 0.5), Vector3.ZERO, "mirror_back")
	_box(holder, Vector3(0.02, 0.05, 0.02), Vector3(0, 0.06, -0.02), _mat(Color(0.08, 0.08, 0.085), 0.5), Vector3.ZERO, "mirror_stem")
	mirror_vp = SubViewport.new(); mirror_vp.size = Vector2i(384, 112); mirror_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(mirror_vp)
	mirror_cam = Camera3D.new(); mirror_cam.fov = 40.0; mirror_cam.near = 0.05; mirror_cam.far = 120.0
	mirror_vp.add_child(mirror_cam)
	mirror_mesh = MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(0.215, 0.058); mirror_mesh.mesh = q
	mirror_mesh.position = Vector3(0, 0, 0.0045); mirror_mesh.name = "mirror_glass"
	var mm := StandardMaterial3D.new(); mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_texture = mirror_vp.get_texture(); mm.uv1_scale = Vector3(-1, 1, 1); mm.uv1_offset = Vector3(1, 0, 0)
	mm.albedo_color = Color(0.82, 0.82, 0.84)
	mirror_mesh.material_override = mm; mirror_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mirror_mesh)

func _mirror_tick():
	if mirror_cam == null or not is_inside_tree() or not mirror_mesh.is_inside_tree(): return
	var cam: Camera3D = player.get_node("Head/Camera")
	var mt := mirror_mesh.global_transform
	var n := mt.basis.z.normalized()                 # the glass faces back (+z of the quad)
	var o := mt.origin
	var e := cam.global_position
	var refl := e - 2.0 * (e - o).dot(n) * n          # the eye seen in the glass
	var fwd := (o - refl).normalized()
	mirror_cam.global_transform = Transform3D(Basis.looking_at(fwd, mt.basis.y), refl)
	mirror_cam.fov = clampf(rad_to_deg(2.0 * atan(0.06 / maxf(refl.distance_to(o), 0.1))) * 1.6, 8.0, 50.0)

# ---------------------------------------------------------------- Mio in her seat
func _seat_player():
	player.fly = true; player.move_enabled = false
	player.collision_layer = 0; player.collision_mask = 0
	player.eye_height = EYE_UP
	player.yaw = 0.0; player.pitch = deg_to_rad(-2.0)
	_follow()

var carcam := Vector3.ZERO      # check stills: the camera outside the car, at this point of its frame, looking at it (--carcam=x,y,z)
func _follow():
	if carcam != Vector3.ZERO:
		var at := car.global_transform * carcam; var to := car.global_transform * Vector3(0, 0.8, 0)
		player.eye_height = 0.0; player.global_transform = Transform3D(Basis.IDENTITY, at)
		var dv := (to - at).normalized(); player.yaw = atan2(-dv.x, -dv.z); player.pitch = asin(dv.y)
		return
	# turning round to the back seat she leans in over the console (her own seat's back is in the way otherwise)
	var k := smoothstep(deg_to_rad(75.0), deg_to_rad(150.0), absf(player.yaw))
	# she keeps her head level: on the steep drive the car pitches ~10 deg, and looking out of her side window
	# that pitch would roll the whole picture. A third of the car's tilt is felt, the rest her neck takes.
	var cb := car.global_transform.basis.orthonormalized()
	var fw := -cb.z; fw.y = 0.0
	var lvl := Basis.looking_at(fw.normalized(), Vector3.UP) if fw.length() > 0.01 else cb
	var hb := lvl.slerp(cb, 0.33)
	var at := car.global_transform * (SEAT_MIO + Vector3(0.30 * k, 0.03 * k, -0.04 * k))
	player.global_transform = Transform3D(hb, at)
	player.velocity = Vector3.ZERO
	# she turns in her seat, not round: to her window and back over her shoulder, a little toward Natsuki
	player.yaw = clampf(player.yaw, -2.9, 2.9)
	player.pitch = clampf(player.pitch, -0.95, 0.55)

# ---------------------------------------------------------------- the title (the gap in the cedars)
func _title():
	title_layer = CanvasLayer.new(); title_layer.layer = 12; add_child(title_layer)
	title_rect = TextureRect.new()
	if ResourceLoader.exists("res://ui/title_logo.png"): title_rect.texture = load("res://ui/title_logo.png")
	title_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; title_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_rect.anchor_left = 0.5; title_rect.anchor_right = 0.5; title_rect.anchor_top = 0.5; title_rect.anchor_bottom = 0.5
	# low, over the dark of the dashboard: the house she has just seen stays in the middle of the picture
	var vs := get_viewport().get_visible_rect().size
	var h := vs.y * 0.34
	title_rect.offset_left = -h * 0.5; title_rect.offset_right = h * 0.5; title_rect.offset_top = vs.y * 0.10; title_rect.offset_bottom = vs.y * 0.10 + h
	title_rect.modulate = Color(1, 1, 1, 0); title_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_layer.add_child(title_rect)

func _black():
	var layer := CanvasLayer.new(); layer.layer = 15; add_child(layer)
	black = ColorRect.new(); black.color = Color(0, 0, 0, 0); black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(black)

# ---------------------------------------------------------------- sounds
func _loop(name: String, db: float) -> AudioStreamPlayer:
	if loops.has(name): return loops[name]
	if "--nosound" in OS.get_cmdline_user_args(): return null
	var s := Sound.stream(name, true)
	if s == null: return null
	var p := AudioStreamPlayer.new(); p.stream = s; p.volume_db = db; add_child(p); p.play()
	loops[name] = p
	print("SOUND loop %s %.1f" % [name, db])
	return p

func _loop_to(name: String, db: float, sec: float):
	var p: AudioStreamPlayer = loops.get(name)
	if p == null: p = _loop(name, -60.0)
	if p == null: return
	var tw := create_tween(); tw.tween_property(p, "volume_db", db, sec)

func _one(name: String, db := 0.0):
	if "--nosound" in OS.get_cmdline_user_args(): return
	Sound.one(self, name, db)

# ---------------------------------------------------------------- the clock
func _process(dt: float):
	if not is_inside_tree() or not car.is_inside_tree(): return
	if card_t > 0.0:
		card_t -= dt
		card.visible = true; player.look_enabled = false
		if card_t <= 0.0: card.visible = false; player.look_enabled = true; stage = "drive"; t_stage = 0.0
		_drive(0.0)
		return
	card.visible = false
	if stage == "card": stage = "drive"; t_stage = 0.0
	t_now += dt; t_stage += dt
	main.story_talking = true
	if demo_car: _demo_car(dt)
	_drive(dt)
	_lines(dt)
	_inspect(dt)
	_title_tick(dt)
	_update_looks()

func _drive(dt: float):
	match stage:
		"drive":
			# up the forest road: slower round the bend above the ravine (the cone, the board), then on to the drive's foot
			var want := 4.6
			if absf(d - d_slip) < 14.0: want = 3.0
			var to_stop := d_stop - d
			if to_stop < 22.0: want = minf(want, maxf(0.0, sqrt(maxf(to_stop, 0.0) * 2.0 * 0.62)))
			v = move_toward(v, want, dt * (1.2 if want > v else 1.8))
			if to_stop < 0.05 or (to_stop < 0.6 and v < 0.12):
				v = 0.0; stage = "parked"; t_stage = 0.0
				_loop_to("car_drive", -60.0, 1.2); _loop_to("car_idle", -15.0, 0.8)
				print("CAR parked t=%.1f d=%.1f" % [t_now, d])
		"parked":
			v = 0.0
		"drive_on":
			var want2 := 2.4
			if d > d_reveal - 7.0: want2 = lerpf(2.4, 0.55, clampf((d - (d_reveal - 7.0)) / 7.0, 0.0, 1.0))
			v = move_toward(v, want2, dt * 0.9)
			if d >= d_reveal:
				stage = "gap"; t_stage = 0.0
				print("CAR gap t=%.1f" % t_now)
		"gap":
			# the car creeps at the gap until she looks at the house (the camera is not taken: the light ahead draws her)
			v = move_toward(v, 0.45, dt * 0.6)
			if _looking_at_house() and t_stage > 0.4:
				stage = "title"; t_stage = 0.0; title_t = 0.0
				print("CAR title t=%.1f" % t_now)
		"title":
			v = move_toward(v, 0.0 if d > d_end - 1.0 else 0.6, dt * 0.5)
			if t_stage > 9.5:
				stage = "out"; t_stage = 0.0
				var tw := create_tween(); tw.tween_property(black, "color:a", 1.0, 1.6)
				_loop_to("car_gravel", -60.0, 1.4); _loop_to("car_drive", -60.0, 1.4); _loop_to("car_idle", -60.0, 1.4)
		"out":
			v = move_toward(v, 0.0, dt * 0.6)
			if t_stage > 2.2:
				stage = "done"
				_one("car_door", -6.0)
				if demo_car: print("DEMO car done t=%.1f fails=%d" % [t_now, demo_fails])
				get_tree().create_timer(1.4).timeout.connect(_to_dusk)
	d = minf(d + v * dt, curve.get_baked_length())
	var tf := _at(d)
	# the body: a slow rock on the old asphalt, a lean into the bends, a nod as it slows
	var fwd := -tf.basis.z
	var turn := 0.0
	if dt > 0.0: turn = prev_fwd.signed_angle_to(fwd, Vector3.UP) / dt
	prev_fwd = fwd
	steer = lerpf(steer, clampf(turn * 2.2, -1.6, 1.6), 1.0 - exp(-dt * 3.0))
	bump_v += (randf_range(-1.0, 1.0) * v * 0.9 - bump * 30.0 - bump_v * 4.0) * dt
	bump += bump_v * dt
	var gravel := 1.6 if d > d_drive else 1.0
	var roll := clampf(-turn * v * 0.012, -0.03, 0.03) + bump * 0.6 * gravel
	var pitch := bump * 0.35 * gravel
	tf.basis = tf.basis * Basis.from_euler(Vector3(pitch * 0.02, 0.0, roll * 0.02))
	tf.origin += tf.basis.y * (bump * 0.004 * gravel)
	car.global_transform = tf
	if wheel: wheel.rotation = Vector3(WHEEL_TILT, 0, 0); wheel.rotate_object_local(Vector3(0, 0, 1), steer)
	if nat_ik: nat_ik.wheel = wheel; _nat_look_tick(dt)
	_place_people()
	_follow()
	_mirror_tick()

func _looking_at_house() -> bool:
	var cam: Camera3D = player.get_node("Head/Camera")
	var to: Vector3 = main.b2g(HOUSE_AT) - cam.global_position
	return (-cam.global_basis.z).angle_to(to) < deg_to_rad(24.0)

func _title_tick(dt: float):
	if title_t < 0.0: return
	title_t += dt
	var a := clampf(title_t / 1.6, 0.0, 1.0) * clampf((8.2 - title_t) / 1.8, 0.0, 1.0)
	title_rect.modulate.a = a

func _to_dusk():
	main._save_settings(); main.SCENE = "house"; main.NEXT_PLAY = "ch1"; main.FROM_CAR = true   # a --play= on the command line must not bring the car back
	get_tree().reload_current_scene()

# ---------------------------------------------------------------- what is said (on its second, like door.gd)
func _lines(dt: float):
	if stage in ["drive", "parked", "stop"]:
		while li < LINES.size() and t_now >= float(LINES[li][0]):
			if LIF[li] == "" or has_flag(LIF[li]): _event(LINES[li])
			li += 1
	if stage == "parked":
		while si < STOP_LINES.size() and t_stage >= float(STOP_LINES[si][0]):
			if SIF[si] == "" or has_flag(SIF[si]): _event(STOP_LINES[si])
			si += 1
	if cur.has("text") and typed < String(cur.text).length() and is_instance_valid(cur_lb):
		typed = minf(float(String(cur.text).length()), typed + dt * 15.0)
		_type(cur_lb, String(cur.text), int(typed))
	main.talk_now = cur.get("who_key", "") if cur.has("text") and typed < String(cur.text).length() else ""
	# a line goes when the next comes; the last fades out
	if cur.has("text") and typed >= String(cur.text).length():
		read_t += dt
		if read_t > 6.0 + String(cur.text).length() * 0.05:
			var tw := create_tween(); tw.tween_property(lines_box, "modulate:a", 0.0, 1.2)
			tw.tween_callback(func(): _clear_box(lines_box); lines_box.modulate.a = 1.0)
			cur = {}
	if dlook.has("lb") and not is_instance_valid(dlook.lb): dlook = {}
	if dlook.has("lb") and dlook.typed < String(dlook.text).length():
		dlook.typed = minf(float(String(dlook.text).length()), dlook.typed + dt * 20.0)
		_type(dlook.lb, String(dlook.text), int(dlook.typed))

func _event(e: Array):
	if e.size() == 2 and _flag_do(String(e[1])): return
	if demo_car: print("SAY %.1f " % float(e[0]), "：".join(e.slice(1, 3)) if e.size() > 2 else "＞" + String(e[1]))
	match e[1]:
		"note":
			_line_row("", e[2], 22, "note"); cur = {}
			if String(e[2]).contains("ラジオ"): _radio()
		"drive_on":
			stage = "drive_on"; t_stage = 0.0
			_blinker(5)
			_loop_to("car_idle", -60.0, 2.0); _loop_to("car_drive", -17.0, 1.5); _loop_to("car_gravel", -16.0, 2.0)
			print("CAR drive_on t=%.1f" % t_now)
		_:
			var who: String = e[1]
			cur = {"who": who, "text": _wrap_row(Tw(e[2])), "who_key": WHO_KEY.get(who, "")}
			typed = 0.0; read_t = 0.0
			lines_box.modulate.a = 1.0
			var r = _line_row(who, "", SAY_SIZE, "say")
			cur_lb = r[1]
			if who == "夏希": _nat_glance()

func _radio():
	if car_radio_on: return
	car_radio_on = true
	_one("car_radio", -12.0)

func _blinker(n: int):
	for i in n * 2:
		get_tree().create_timer(0.2 + i * 0.4).timeout.connect(func(): _one("car_blinker", -14.0))

# Natsuki keeps her eyes on the road; at the hard lines she looks at Mio once, and back
var glance_t := 0.0
var glance_at := ""
func _nat_glance():
	var tx := String(cur.get("text", ""))
	if tx.contains("撮ってきた"): glance_at = "tape"; glance_t = 2.6
	elif tx.contains("澪"): glance_at = "mio"; glance_t = 3.6

func _nat_look_tick(dt: float):
	if nat_ik == null: return
	glance_t -= dt
	var want := 1.0 if glance_t > 0.0 else 0.0
	nat_ik.look_w = move_toward(nat_ik.look_w, want, dt * 1.4)
	var cam: Camera3D = player.get_node("Head/Camera")
	if glance_at == "tape": nat_ik.look_alt = car.global_transform * TAPE_AT
	else: nat_ik.look_alt = cam.global_position
	# the road: 12 m ahead, a little up from the dash
	nat_ik.look_road = car.global_transform * Vector3(0.37, 1.2, -12.0)

# ---------------------------------------------------------------- what she can look at (E)
const ITEMS := {"tape": ["テープ", "一.車.テープ", 9.0], "phone": ["スマホ", "一.車.スマホ", 9.0], "makoto": ["真琴", "一.車.真琴", 14.0], "window": ["窓の外", "一.車.窓", 30.0]}
func _item_at(k: String) -> Vector3:
	match k:
		"tape": return car.global_transform * TAPE_AT
		"phone": return car.global_transform * PHONE_AT
		"makoto": return car.global_transform * (SEAT_MK + Vector3(0.0, 0.72, 0.02))
		"window": return car.global_transform * Vector3(-2.5, 1.15, -0.1)
	return Vector3.ZERO

func _inspect(_dt: float):
	focus_k = ""
	if stage in ["title", "out", "done", "card"]: note_lb.text = ""; return
	var cam: Camera3D = player.get_node("Head/Camera")
	var fwd := -cam.global_basis.z
	var best := 999.0
	for k in ITEMS:
		var to := _item_at(k) - cam.global_position
		var ang := rad_to_deg(fwd.angle_to(to))
		if ang < float(ITEMS[k][2]) and ang < best: best = ang; focus_k = k
	note_lb.text = ("［%s］" % T(String(ITEMS[focus_k][0]))) if focus_k != "" and not looked_at.has(focus_k) else ""

func _look(k: String):
	if looked_at.has(k): return
	looked_at[k] = true
	var es: Array = B(String(ITEMS[k][1]))
	var text := ""
	for e in es:
		if e.has("do"): _flag_do(String(e.do))
		elif e.has("text") and text == "": text = String(e.text)
	if text == "": return
	if demo_car: print("SAY 澪＊：", text)
	text = _wrap_row(Tw(text))
	var r = _line_row("澪", "", SAY_SIZE, "testimony")
	dlook = {"lb": r[1], "text": text, "typed": 0.0}
	print("STORY car look %s t=%.1f" % [k, t_now])

func _unhandled_input(e):
	if card_t > 0.0 or stage in ["title", "out", "done"]: return
	var press: bool = (e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	if press and focus_k != "": _look(focus_k)

# ---------------------------------------------------------------- check stills and the unattended run
func _jump(t: float):
	card_t = 0.0; card.visible = false; stage = "drive"
	var step := 1.0 / 24.0
	while t_now < t and stage == "drive":
		t_now += step; t_stage += step; _drive(step)
		while li < LINES.size() and t_now >= float(LINES[li][0]):
			if LIF[li] == "" or has_flag(LIF[li]): _event(LINES[li])
			li += 1

func _jump_stop():
	_jump(999.0)

func _jump_gap():
	_jump(999.0)
	stage = "drive_on"; t_stage = 0.0; d = d_reveal - 0.5; v = 0.6
	li = LINES.size(); si = STOP_LINES.size(); cur = {}; _clear_box(lines_box)
	_drive(0.0)

# the playthrough: she looks at the four things, then ahead at the gap
var aim_k := ""
func _demo_car(dt: float):
	aim_k = ""
	var cam: Camera3D = player.get_node("Head/Camera")
	var aim := Vector3.ZERO
	if stage in ["gap", "drive_on", "title"]: aim = main.b2g(HOUSE_AT)
	elif not demo_looks.is_empty() and t_now >= float(demo_looks[0][0]):
		var k: String = demo_looks[0][1]
		aim = _item_at(k); aim_k = k
		if focus_k == k: _look(k); demo_looks.pop_front()
		elif t_now > float(demo_looks[0][0]) + 10.0: demo_fails += 1; print("DEMO FAIL car: cannot look at ", k, " yaw=%.2f pitch=%.2f off=%.1fdeg" % [player.yaw, player.pitch, rad_to_deg((-cam.global_basis.z).angle_to(aim - cam.global_position))]); demo_looks.pop_front()
	for a in demo_aims:
		if aim == Vector3.ZERO and t_now >= float(a[0]) and t_now < float(a[1]) and stage == "parked":
			aim = (car.global_transform * (SEAT_NAT + Vector3(0, 0.78, -0.05))) if a[2] == "natsuki" else mirror_mesh.global_position
	if aim == Vector3.ZERO: return
	# turn her head (yaw/pitch are the head's, in the car's frame)
	var to_l: Vector3 = (player.global_basis.inverse() * (aim - cam.global_position)).normalized()   # her head is levelled (_follow), not the car's frame
	var k2 := 1.0 - exp(-dt * 3.0)
	var want := atan2(-to_l.x, -to_l.z)
	# right behind her the aim's side flips as she leans in; Makoto is over her left shoulder, so she turns that way
	if absf(want) > 2.3 and aim_k == "makoto": want = absf(want)
	player.yaw = lerpf(player.yaw, want, k2)   # (not the short way round: she turns back the way she came, inside the seat)
	player.pitch = lerpf(player.pitch, asin(clampf(to_l.y, -1.0, 1.0)), k2)

# ---------------------------------------------------------------- Natsuki's hands on the wheel
# Two bones each arm (upper, fore): the hand goes to its place on the ring (ten and two), the elbow down and out.
class ReachIK extends SkeletonModifier3D:
	const WHEEL_R := 0.185
	var wheel: Node3D
	var arms := []      # [upper, lower, hand, side]
	# her eyes: on the road ahead; a glance (look_w) at Mio or at the tape
	var look_road := Vector3.ZERO
	var look_alt := Vector3.ZERO
	var look_w := 0.0
	var neck := -1
	var head := -1
	var face_v := Vector3.ZERO    # the face's forward in the head bone's frame
	func setup():
		var sk := get_skeleton()
		neck = sk.find_bone("neck_01"); head = sk.find_bone("head")
		if head >= 0:
			face_v = (sk.get_bone_global_rest(head).basis.inverse() * Vector3(0, 0, 1)).normalized()
		for s in ["l", "r"]:
			var a := sk.find_bone("upperarm_" + s); var b := sk.find_bone("lowerarm_" + s); var c := sk.find_bone("hand_" + s)
			if a >= 0 and b >= 0 and c >= 0: arms.append([a, b, c, -1.0 if s == "l" else 1.0])
	func _process_modification():
		var sk := get_skeleton()
		if sk == null or wheel == null or not is_instance_valid(wheel): return
		var inv := sk.global_transform.affine_inverse()
		for arm in arms:
			var side: float = arm[3]
			# the rig's left is the car's... the hands at ten (left) and two (right) of the ring, a little in front of it
			var ang := deg_to_rad(58.0) * side
			var local := Vector3(sin(ang) * WHEEL_R, cos(ang) * WHEEL_R * 0.92, 0.02)
			var tgt_w: Vector3 = wheel.global_transform * local
			var car_basis: Basis = wheel.get_parent().global_basis
			var pole_w: Vector3 = tgt_w + car_basis * Vector3(side * 0.30, -0.45, 0.25)
			_two_bone(sk, arm[0], arm[1], arm[2], inv * tgt_w, inv * pole_w)
		if head >= 0 and look_road != Vector3.ZERO:
			var e := look_w * look_w * (3.0 - 2.0 * look_w)
			var tgt: Vector3 = look_road.lerp(look_alt, e) if look_alt != Vector3.ZERO else look_road
			var gh := sk.get_bone_global_pose(head)
			var f := (gh.basis * face_v).normalized()
			var to := (inv * tgt - gh.origin).normalized()
			var q := Quaternion(f, to)
			var ang := q.get_angle()
			if ang > 1.3: q = Quaternion(q.get_axis().normalized(), 1.3)
			if neck >= 0:
				var gn := sk.get_bone_global_pose(neck)
				sk.set_bone_global_pose(neck, Transform3D(Basis(Quaternion.IDENTITY.slerp(q, 0.45)) * gn.basis, gn.origin))
				gh = sk.get_bone_global_pose(head)
				f = (gh.basis * face_v).normalized(); to = (inv * tgt - gh.origin).normalized()
				q = Quaternion(f, to)
			sk.set_bone_global_pose(head, Transform3D(Basis(q) * gh.basis, gh.origin))
	func _two_bone(sk: Skeleton3D, a: int, b: int, c: int, t: Vector3, pole: Vector3):
		var ga := sk.get_bone_global_pose(a); var gb := sk.get_bone_global_pose(b); var gc := sk.get_bone_global_pose(c)
		var A := ga.origin; var Bp := gb.origin; var C := gc.origin
		var l1 := A.distance_to(Bp); var l2 := Bp.distance_to(C)
		if l1 < 0.01 or l2 < 0.01: return
		var to := t - A
		var dist := clampf(to.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.005)
		var dir := to.normalized()
		var cos_a := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
		var pl := pole - A
		var bend := (pl - dir * pl.dot(dir))
		if bend.length() < 0.001: bend = Vector3.DOWN
		bend = bend.normalized()
		var B2 := A + dir * (l1 * cos_a) + bend * (l1 * sqrt(1.0 - cos_a * cos_a))
		var C2 := A + dir * dist
		var q1 := Quaternion((Bp - A).normalized(), (B2 - A).normalized())
		var na := Transform3D(Basis(q1) * ga.basis, A)
		sk.set_bone_global_pose(a, na)
		var gb2 := sk.get_bone_global_pose(b)
		var gc2 := sk.get_bone_global_pose(c)
		var q2 := Quaternion((gc2.origin - gb2.origin).normalized(), (C2 - gb2.origin).normalized())
		sk.set_bone_global_pose(b, Transform3D(Basis(q2) * gb2.basis, gb2.origin))

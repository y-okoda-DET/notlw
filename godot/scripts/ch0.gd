## ステップ E：第0章（序章）「夜明け」 5:00、玄関の廊下（docs/企画書.md の第0章・第9章）。台詞は story/ch0.txt。
## 家まるごとの 4:30 の光で動く（5:00 の光は焼いていない。--scene=house --time=t0430 に、このノードを main の子として足す）。
##
## The same hall as 第4章, an hour and a half on. Mio sits on the floor where she stood at half past three, her back to
## the stair's boarding. What she struck is still where it fell, between her and the front door, and the trail it left
## comes in from the door to it. Nothing says who it is. The generator in the cellar runs out and its warm light goes;
## what is left is the cold of the dawn coming through the boards. A car's lights come up the drive. Someone knocks.
## The transcript counts her silence, as it did at the door at eleven.
##
## Then she gets up (W), and walks to the door through what is on the floor, and opens it (E). It is the one door she
## opens with her own hand in the whole game: not to Natsuki at eleven, not to Yota a year ago; to the police, at five,
## when there is nobody left to keep out. Her hand leaves its print on the inside of the door as it swings. The light
## comes in white, the question under the chapter's name is answered with one line, and the evening begins (第一章).
##
## It rides on fps.gd's stage (her, the trail, the blood, the small camera on the handrail, the lantern), as tape.gd does.
extends "res://scripts/fps.gd"
const Sound = preload("res://scripts/sound.gd")

const SIT_AT := [4.42, 3.42]          # plan x, y: on the floor against the stair's boarding, a step behind where she stood at 3:30
const SIT_EYE := 0.86
const STAND_EYE := 1.52
const FRONT_DOOR := [5.0, 0.02, 1.05] # plan x, y, z: the middle of the front door's leaf (what she looks at to open it)
const OPEN_REACH := 1.7
const OPEN_DEG := 74.0
const SIDE_GLASS := [4.14, 0.005, 1.08]   # plan: the sidelight's glass west of the door (x 4.03..4.24), the hall's face
const LANTERN_E := 0.2

var L0 := []
var l0 := 0
var can_stand := false
var stand_t := -1.0
var silence0 := {}
var silent_total0 := 0.0
var opened_t := -1.0
var after0 := 0
var car_t := -1.0
var car: Array = []             # the two headlamps
var car_body: MeshInstance3D
var knocks0: Array = []         # the clock's seconds of each knock
var door_rest0 := 0.0
var door_pos0 := Vector3.ZERO
var front_leaf: MeshInstance3D
var hand: MeshInstance3D
var prints := 0
var last_foot := 1.0
var slip0 := Vector2.ZERO
var demo0 := false
var dstep := 0
var dwait := 0.0

func _ready():
	player = main.player
	font = Type.say()
	offscreen = ["警察官"]        # behind the door: the name on every line
	u = get_viewport().get_visible_rect().size.y / 1080.0
	load_story("ch0")
	_page()
	_stage()
	_hud(); hud.visible = false
	weapon.visible = false        # the tripod went back into its bag at four (第6章)
	if lantern: lantern.light_energy = LANTERN_E   # its battery nearly gone
	_lay_her_down()
	L0 = _flow("序.流れ")
	var c: Array = D.lines("序.カード")
	card4 = main.make_card(self, [[c[0], 46, 40], [c[1], 150, 90], [c[2], 36, 0]], Type.card())
	black = ColorRect.new(); black.color = Color(0, 0, 0, 0); black.set_anchors_preset(Control.PRESET_FULL_RECT); black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bl := CanvasLayer.new(); bl.layer = 22; add_child(bl); bl.add_child(black)
	player.global_position = gp(SIT_AT[0], SIT_AT[1], 0.0)
	player.eye_height = SIT_EYE; player.get_node("Head").position.y = SIT_EYE
	player.yaw = deg_to_rad(-6.0); player.pitch = deg_to_rad(-20.0)   # down the hall to the front door, and what is on the floor before it
	mio_shadow.scale = Vector3(1.0, SIT_EYE / STAND_EYE, 1.0)          # her shadow from the lantern is a sitting one
	_foot.call_deferred("マウス 見る　　Ｆ１２ 画面の保存　Ｅｓｃ マウス解放")
	_car()
	call_deferred("_front_door_mine")
	for a in OS.get_cmdline_user_args():
		if a == "--demo": demo0 = true
		if a == "--nocard0": card_t = 0.0
		if a.begins_with("--c0at="): call_deferred("_jump0", float(a.substr(7)))   # check stills: the scene at this second
		if a.begins_with("--c0yp="):   # check stills: where she looks (degrees)
			var yp := a.substr(7).split(","); player.yaw = deg_to_rad(float(yp[0])); player.pitch = deg_to_rad(float(yp[1]))
		if a.begins_with("--c0mio="):  # check stills: stand her here (plan x,y)
			var xy := a.substr(8).split(","); player.global_position = gp(float(xy[0]), float(xy[1]), 0.0)
			player.eye_height = STAND_EYE; player.get_node("Head").position.y = STAND_EYE
		if a == "--c0open": call_deferred("_open")

# the front door is this scene's, not doors.gd's (which would say 開かない。 of a boarded house)
func _front_door_mine():
	await get_tree().physics_frame; await get_tree().physics_frame
	var dn = main.get_node_or_null("Doors")
	if dn:
		for k in dn.doors.keys():
			if dn.doors[k].pivot == main.door_pivot: front_leaf = k; dn.doors.erase(k)
	if main.door_pivot:
		door_rest0 = float(main.S.get("door_rot", 0.0)); door_pos0 = main.S.get("door_rest", main.door_pivot.position)
		main.door_pivot.rotation.y = door_rest0; main.door_pivot.position = door_pos0
	if front_leaf == null and main.door_pivot:
		for mi in main.door_pivot.find_children("door_front*", "MeshInstance3D", true, false):
			if not String(mi.name).contains("knob") and not String(mi.name).contains("glass"): front_leaf = mi; break
	_hand()
	if "--c0dbg" in OS.get_cmdline_user_args():
		var bb: AABB = front_leaf.global_transform * front_leaf.get_aabb() if front_leaf else AABB()
		for mi in main.S.env_node.find_children("*", "MeshInstance3D", true, false):
			var ab: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			if ab.size.length() < 4.0 and absf(ab.get_center().z + 6.3) < 0.4 and ab.get_center().x > -1.6 and ab.get_center().x < 1.8: print("C0DBG near %s %s" % [mi.name, ab])
		print("C0DBG pivot=%s leaf=%s %s nrig=%s nhead=%s player=%s hand=%s" % [main.door_pivot.global_position if main.door_pivot else null, front_leaf.name if front_leaf else null, bb, nrig.global_position, _nhead(), player.global_position, hand.global_position if hand else null])

# She is where the second blow put her (fps.gd's own fall, run to its end and held), the trail from the door to her.
func _lay_her_down():
	nat.visible = true
	var mio := gp(TAPE_MIO[0], TAPE_MIO[1], 0.0)
	var at := gp(NPATH[-1][0], NPATH[-1][1], NPATH[-1][2])
	var m := mio - at
	nrig.global_transform = Transform3D(Basis(Vector3.UP, atan2(m.x, m.z)), at)
	nap.play("walk/walk"); nap.seek(0.3, true); nap.pause()
	_drops_upto(NPATH.size() - 1)
	nstate = "stand"
	_blow(true)
	for i in 24: _night(0.05)
	_blow(true)
	for i in 44: _night(0.05)
	_clear_page(); cur = {}
	set_meta("freeze", true)
	_pool()

# what ran from her in an hour and a half: a dark, flat, wet pool under her head, its edge gone tacky
func _pool():
	var h := _nhead(); h.y = 0.0
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.13, 0.006, 0.006); mat.roughness = 0.1; mat.metallic_specular = 0.85
	for i in 7:
		var mi := MeshInstance3D.new(); var cm := CylinderMesh.new()
		var r := rng.randf_range(0.10, 0.22) * (1.0 if i == 0 else 0.8)
		cm.top_radius = r; cm.bottom_radius = r; cm.height = 0.002 + 0.0004 * i; cm.radial_segments = 20; cm.rings = 1
		mi.mesh = cm; mi.material_override = mat; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		main.add_child(mi)
		var off := Vector3(rng.randf_range(-0.16, 0.16), 0.003, rng.randf_range(-0.16, 0.16)) if i > 0 else Vector3(0, 0.003, 0)
		mi.global_position = h + off
		mi.scale = Vector3(1.0, 1.0, rng.randf_range(0.7, 1.3)); mi.rotation.y = rng.randf_range(0.0, PI)

# ---------------------------------------------------------------- the car: two lamps that come up the drive and stop
const CAR_FROM := [13.0, -16.0, 0.75]   # plan: down the forest road, out of sight
const CAR_TO := [7.4, -11.0, 0.72]       # on the drive below Natsuki's car, its lamps on the front door
func _car():
	for side in [-0.75, 0.75]:
		var l := SpotLight3D.new(); l.light_color = Color(1.0, 0.95, 0.84); l.light_energy = 0.0
		l.spot_range = 22.0; l.spot_angle = 22.0; l.spot_angle_attenuation = 1.6; l.spot_attenuation = 0.4
		l.shadow_enabled = true; l.light_volumetric_fog_energy = 0.8; l.light_specular = 0.3
		l.set_meta("side", side)
		main.add_child(l); car.append(l)
		var lens := MeshInstance3D.new(); var sp := SphereMesh.new(); sp.radius = 0.09; sp.height = 0.12; lens.mesh = sp
		var lm := StandardMaterial3D.new(); lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; lm.albedo_color = Color(1, 0.97, 0.9)
		lens.material_override = lm; lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; l.add_child(lens); lens.position = Vector3(0, 0, -0.05)
	# the car itself is only a dark shape against the dawn behind its lamps
	car_body = MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(1.75, 1.0, 4.4); car_body.mesh = bm
	var cm := StandardMaterial3D.new(); cm.albedo_color = Color(0.05, 0.05, 0.06); cm.roughness = 0.4; car_body.material_override = cm
	var cab := MeshInstance3D.new(); var cbm := BoxMesh.new(); cbm.size = Vector3(1.6, 0.55, 2.2); cab.mesh = cbm; cab.material_override = cm
	car_body.add_child(cab); cab.position = Vector3(0, 0.75, 0.35)
	main.add_child(car_body)

func _car_tick(dt: float):
	if car_t < 0.0: return
	car_t += dt
	var k := clampf(car_t / 7.0, 0.0, 1.0); k = 1.0 - pow(1.0 - k, 2.2)       # up the drive, slowing to a stop
	var p := gp(CAR_FROM[0], CAR_FROM[1], CAR_FROM[2]).lerp(gp(CAR_TO[0], CAR_TO[1], CAR_TO[2]), k)
	# it turns up the drive: the lamps swing across the front of the house before they settle on the door
	var aim := gp(lerpf(-1.5, 5.0, k), lerpf(-1.0, 0.4, k), lerpf(0.4, 1.0, k))
	var fw := (aim - p); fw.y = 0.0; fw = fw.normalized()
	var right := fw.cross(Vector3.UP)
	for l in car:
		var lp: Vector3 = p + right * float(l.get_meta("side"))
		l.look_at_from_position(lp, aim + right * float(l.get_meta("side")) * 0.6, Vector3.UP)
		l.light_energy = 9.0 * smoothstep(0.0, 1.5, car_t)
	car_body.global_transform = Transform3D(Basis.looking_at(fw, Vector3.UP), p + Vector3(0, -0.12, 0) - fw * 2.25)

# ---------------------------------------------------------------- her print on the door, her feet on the floor
const HAND_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;
uniform float fade = 1.0;
varying vec2 q;
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 x) { vec2 i = floor(x); vec2 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }
float cap(vec2 p, vec2 a, vec2 b, float r) { vec2 pa = p - a; vec2 ba = b - a; float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0); return 1.0 - length(pa - ba * t) / r; }
void vertex() { q = vec2(UV.x, 1.0 - UV.y) * vec2(0.22, 0.26); }
void fragment() {
	vec2 p = q - vec2(0.11, 0.10);                 // the palm's middle (metres on the leaf)
	float m = 1.0 - length(p / vec2(0.044, 0.05));
	m = max(m, cap(p, vec2(-0.030, 0.035), vec2(-0.040, 0.105), 0.010));   // the fingers, a little spread, the hand flat and pushing
	m = max(m, cap(p, vec2(-0.010, 0.045), vec2(-0.012, 0.128), 0.0105));
	m = max(m, cap(p, vec2(0.012, 0.045), vec2(0.016, 0.122), 0.0105));
	m = max(m, cap(p, vec2(0.031, 0.035), vec2(0.044, 0.094), 0.009));
	m = max(m, cap(p, vec2(0.040, -0.012), vec2(0.078, 0.022), 0.012));     // the thumb
	m = max(m, cap(p, vec2(0.0, -0.02), vec2(0.004, -0.105), 0.016) * 0.8); // where it slid down as the door went
	float n = vn(q * 160.0) * 0.6 + vn(q * 420.0) * 0.4;
	float al = smoothstep(0.0, 0.25, m + (n - 0.5) * 0.55);
	ALBEDO = vec3(0.07, 0.004, 0.004);
	ALPHA = al * fade;
}
"""
func _hand():
	if front_leaf == null: return
	var qm := QuadMesh.new(); qm.size = Vector2(0.22, 0.26)
	var sm := ShaderMaterial.new(); var sh := Shader.new(); sh.code = HAND_SHADER; sm.shader = sh
	hand = MeshInstance3D.new(); hand.mesh = qm; hand.material_override = sm
	hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; hand.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# on the hall's side of the narrow window beside the door (its lit glass: the print is a dark hand against the dawn).
	# At eleven Natsuki's palm was on the other side of this glass with every knock (main.gd knocks, door.gd).
	main.add_child(hand)
	hand.global_transform = Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.BACK, -0.12), gp(SIDE_GLASS[0], SIDE_GLASS[1], SIDE_GLASS[2]))
	hand.visible = opened_t >= 0.0

const FOOT_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
uniform float fade = 1.0;
varying vec2 q;
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 x) { vec2 i = floor(x); vec2 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }
void vertex() { q = (UV - 0.5) * vec2(0.12, 0.28); }
void fragment() {
	float ball = 1.0 - length((q - vec2(0.0, -0.06)) / vec2(0.042, 0.058));   // a sock's print: the ball and the toes
	float heel = 1.0 - length((q - vec2(0.004, 0.085)) / vec2(0.033, 0.04));
	float toes = 1.0 - length((q - vec2(-0.004, -0.112)) / vec2(0.036, 0.022));
	float m = max(max(ball, heel), toes * 0.8);
	float n = vn(q * 150.0) * 0.6 + vn(q * 380.0) * 0.4;
	ALBEDO = vec3(0.15, 0.01, 0.01); ROUGHNESS = 0.4; SPECULAR = 0.5;
	ALPHA = smoothstep(0.0, 0.3, m + (n - 0.5) * 0.7) * fade * 0.9;
}
"""
func _footprint():
	if prints >= 7: return
	var qm := QuadMesh.new(); qm.size = Vector2(0.12, 0.28); qm.orientation = PlaneMesh.FACE_Y
	var sm := ShaderMaterial.new(); var sh := Shader.new(); sh.code = FOOT_SHADER; sm.shader = sh
	sm.set_shader_parameter("fade", 1.0 - prints * 0.13)
	var mi := MeshInstance3D.new(); mi.mesh = qm; mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	main.add_child(mi)
	var b := Basis(Vector3.UP, player.yaw)
	mi.global_transform = Transform3D(b, Vector3(player.global_position.x, 0.004, player.global_position.z) + b * Vector3(0.09 * player.foot, 0, 0))
	prints += 1

# ---------------------------------------------------------------- the clock
func _process(dt):
	if not _clock(dt): return
	if not can_stand or stand_t < 0.0: player.move_enabled = false
	while l0 < L0.size() and clock >= float(L0[l0][0]):
		_event0(L0[l0]); l0 += 1
	_blood_tick()
	mio_shadow.global_position = player.global_position; mio_shadow.rotation.y = player.yaw
	_typing(dt)
	_car_tick(dt)
	_knock_tick()
	_silence_tick(dt)
	_stand_tick(dt)
	_open_tick(dt)
	if demo0: _demo0(dt)
	if main.note: main.note.visible = false   # the house's settings line is not this chapter's

func _event0(e: Array):
	match e[1]:
		"do": _do0(e[2])
		"note":
			_close_silence0()
			if String(e[2]).contains("車のドア"): Sound.one(self, "car_door", -10.0)
			if demo0: print("SAY %.1f %s" % [clock, e[2]])
			_line_row("", T(e[2]), 26, "note"); cur = {}
		"say":
			_close_silence0()
			_say(e[2], e[3], e[4])

func _do0(what: String):
	if demo0: print("SAY %.1f ＞%s" % [clock, what])
	match what:
		"genoff": _gen_off()
		"car": car_t = 0.0; Sound.one(self, "car_arrive", -6.0)
		"knock": for i in 3: knocks0.append(clock + 0.42 * i + (0.1 if i == 2 else 0.0))
		"silence":
			_close_silence0()
			var r = _line_row("澪", "（沈黙）")
			silence0 = {"lb": r[1], "t0": clock}
			cur = {}
		"stand":
			can_stand = true
			note_lb.text = T(String(D.lines("序.立つ")[0]))

# the generator's bulbs go (main.generator(false) would also take the dawn out of the lightmap: at 4:30 it holds both)
func _gen_off():
	main.gen_on = false
	for k in ["lamp_lobby", "lamp_cellar", "lamp_cellarw"]:
		if main.lights.has(k): main.lights[k].visible = false
	for mi in main.S.env_node.find_children("lampshade_*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if not (nm.contains("lamp_lobby") or nm.contains("lamp_cellar")): continue
		for i in range(mi.get_surface_override_material_count()):
			var m := mi.get_surface_override_material(i) as StandardMaterial3D
			if m: m.emission_enabled = false; m.albedo_color = m.albedo_color * Color(0.3, 0.3, 0.3, 1.0)
	print("STORY ch0 generator off t=%.1f lights=%s" % [clock, main.lights.keys().filter(func(k): return String(k).begins_with("lamp"))])

func _close_silence0():
	if silence0.has("lb"):
		var secs := clock - float(silence0.t0)
		silent_total0 += secs
		if is_instance_valid(silence0.lb): (silence0.lb as Label).text = T("（沈黙・%s秒）") % num(int(secs))
	silence0 = {}

func _silence_tick(dt: float):
	var want := Vector2.ZERO
	if silence0.has("lb") and is_instance_valid(silence0.lb):
		var secs := clock - float(silence0.t0)
		(silence0.lb as Label).text = T("（沈黙・%s秒）") % num(int(secs))
		want = Vector2(-0.85, 0.53) * min(secs * 0.55, 9.0)
	slip0 = want if want.length() > slip0.length() else slip0.move_toward(want, dt * 40.0)
	if main.PRINT_V == 2 and main.riso: main.riso.set_shader_parameter("slip", slip0)

# each knock moves the door a few millimetres in its frame (door.gd's door at eleven does the same)
func _knock_tick():
	if main.door_pivot == null or opened_t >= 0.0 or knocks0.is_empty(): return
	var j := 0.0
	for k in knocks0:
		var dtk: float = clock - float(k)
		if dtk > 0.0 and dtk < 0.6: j += exp(-dtk / 0.07) * sin(dtk * 95.0)
	main.door_pivot.position = door_pos0 + Vector3(0.0, 0.0, 0.010 * j)
	main.door_pivot.rotation.y = door_rest0 + 0.005 * j

func _stand_tick(dt: float):
	if stand_t < 0.0: return
	if stand_t < 1.8:
		stand_t += dt
		var k := smoothstep(0.0, 1.8, stand_t)
		player.eye_height = lerpf(SIT_EYE, STAND_EYE, k)
		mio_shadow.scale = Vector3(1.0, player.eye_height / STAND_EYE, 1.0)
		if stand_t >= 1.8:
			player.move_enabled = true
			_foot("ＷＡＳＤ 歩く　マウス 見る　Ｅ 開ける　　Ｆ１２ 画面の保存　Ｅｓｃ マウス解放")
	if player.foot != last_foot:   # a step: what she walked through goes with her a little way
		last_foot = player.foot
		if player.move_enabled: _footprint()
	if opened_t < 0.0:
		var cam: Camera3D = player.get_node("Head/Camera")
		var to := gp(FRONT_DOOR[0], FRONT_DOOR[1], FRONT_DOOR[2]) - cam.global_position
		var near := Vector2(to.x, to.z).length() < OPEN_REACH and (-cam.global_basis.z).angle_to(to) < deg_to_rad(28.0)
		note_lb.text = T(String(D.lines("序.扉")[0])) if near else ""

func _unhandled_input(e):
	if card4 and card4.visible: return
	if e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_W, KEY_UP] and can_stand and stand_t < 0.0:
		_get_up(); return
	var key_e: bool = e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E
	var click: bool = e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if (key_e or click) and opened_t < 0.0 and stand_t >= 1.8 and note_lb.text != "": _open()

func _get_up():
	stand_t = 0.0; note_lb.text = ""
	print("STORY ch0 stand t=%.1f" % clock)

# ---------------------------------------------------------------- she opens it
func _open():
	if opened_t >= 0.0: return
	_close_silence0()
	opened_t = 0.0; note_lb.text = ""
	Sound.one(self, "door_open", -3.0, gp(FRONT_DOOR[0], FRONT_DOOR[1], FRONT_DOOR[2]))
	player.move_enabled = false
	if hand: hand.visible = true
	door_light.light_color = Color(0.92, 0.94, 1.0)
	print("STORY ch0 open t=%.1f silence=%.0f" % [clock, silent_total0])

func _open_tick(dt: float):
	if opened_t < 0.0: return
	opened_t += dt
	if main.door_pivot:
		var k := clampf((opened_t - 0.8) / 3.2, 0.0, 1.0); k = k * k * (3.0 - 2.0 * k)   # her hand on the glass first, then the door
		main.door_pivot.position = door_pos0
		main.door_pivot.rotation.y = door_rest0 + deg_to_rad(OPEN_DEG) * k * float(main.S.get("door_sign", 1.0))
		door_light.light_energy = 3.0 * k
		for l in car: l.light_energy = 9.0 + 6.0 * k
	var A: Array = B("序.あと")
	if after0 == 0 and opened_t > 3.0:
		after0 = 1; _say(A[0].who, A[0].text, false)
	elif after0 == 1 and opened_t > 6.5:
		after0 = 2; _say(A[1].who, A[1].text, true)
	elif after0 == 2 and opened_t > 14.0:
		black.color.a = clampf((opened_t - 14.0) / 2.0, 0.0, 1.0)
		if opened_t > 16.5:
			after0 = 3
			if demo0: print("DEMO ch0 t=%.1f fails=%d" % [clock, DEMO_FAILS])
			if demo0 and "--demoquit" in OS.get_cmdline_user_args(): print("DEMO DONE ch0 t=%.1f" % clock); get_tree().quit(); return
			# the evening (第一章): main.gd plays 第1章 when the scene asked for is the dusk
			main._save_settings(); main.SCENE = "dusk"; get_tree().reload_current_scene()

# check stills: the scene at t seconds, the lines before it on the page
func _jump0(t: float):
	card_t = 0.0
	if card4: card4.visible = false
	while l0 < L0.size() and float(L0[l0][0]) <= t:
		clock = float(L0[l0][0]); _event0(L0[l0]); l0 += 1
		if cur.has("text"): typed = String(cur.text).length(); _type(cur_lb, String(cur.text), int(typed))
	if car_t >= 0.0: car_t = 30.0
	clock = t

# the unattended run: sit through it, get up, round her by the west wall, open the door
const DEMO_PATH := [[4.30, 2.70], [4.30, 1.20], [4.80, 0.75]]
func _demo0(dt: float):
	var cam: Camera3D = player.get_node("Head/Camera")
	match dstep:
		0:
			if can_stand and clock > 52.0: _get_up(); dstep = 1
		1:
			if stand_t >= 1.8:
				var path := [[0.0, player.global_position.x, player.global_position.z, rad_to_deg(player.yaw), -10.0]]
				var tt := 0.6
				var prev: Vector3 = player.global_position
				for q in DEMO_PATH:
					var p := gp(q[0], q[1], 0.0)
					tt += prev.distance_to(p) / 0.9 + 0.3
					var d := p - prev
					path.append([tt, p.x, p.z, rad_to_deg(atan2(-d.x, -d.z)), -10.0]); prev = p
				player.auto_path = path; player.auto_t = 0.0
				dwait = tt + 1.0; dstep = 2
		2:
			dwait -= dt
			if dwait <= 0.0:
				player.auto_path = []
				dstep = 3; dwait = 6.0
		3:
			var to := gp(FRONT_DOOR[0], FRONT_DOOR[1], FRONT_DOOR[2]) - cam.global_position
			var k := 1.0 - exp(-dt * 4.0)
			player.yaw = lerp_angle(player.yaw, atan2(-to.x, -to.z), k)
			player.pitch = lerp(player.pitch, asin(clampf(to.normalized().y, -1.0, 1.0)), k)
			dwait -= dt
			if note_lb.text != "": _open(); dstep = 4
			elif dwait <= 0.0:
				print("DEMO FAIL ch0: cannot open the front door t=%.1f at=%s" % [clock, player.global_position]); DEMO_FAILS += 1; dstep = 4; _open()

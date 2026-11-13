## ステップ D：第11章「再生」。数か月後、澪が手すりのカメラのテープを初めて再生する（docs/企画書.md「テープ再生（第11章）」）。
## fps.gd（第4章）と同じ夜を、同じ秒で、誰も操作しないまま走らせ、手すりの上の小さいカメラから撮った画をテレビに映す。
## 台詞は story/ch11.txt。
##
## A dark room, a television on the floor, the deck under it. E on the deck plays the tape; nothing else happens until
## she does. The picture is the wide frame Kiryu drew at dusk: the whole hall, the front door, and one hurt person
## walking in. Mio herself stands just under the camera, out of the frame; what comes into it from her side is the
## tripod. The tracking is off: the picture tears and the words drop out, as the radio's did at eight (第2章). Right
## mouse puts her hand on the tracking knob and the mouse turns it, the radio's own handling; this time the words come.
## What Natsuki says is written with her name. In 第4章 the same seconds were （うめき声）.
## When the tape runs out the view goes down to the deck's two keys, 録画 and 取り出し, and cuts to black.
extends "res://scripts/fps.gd"

const ROOM := Vector3(0.0, -40.0, 0.0)     # far under the house: nothing of the night reaches it
const TV_C := Vector3(0.0, 0.62, 0.0)      # the middle of the screen (room metres)
const SCR := Vector2(0.44, 0.33)           # a 21-inch tube, 4:3
const EYE := Vector3(0.0, 0.66, 0.74)      # she sits on the floor before it
const NIGHT_AT := 4.0                      # the tape's 0 s is the night's 4 s (ch4.txt)
const HIT_LAG := 0.4                       # a blow lands this long after it starts (fps.gd _swing)
enum {ROOM_WAIT, PLAYING, ENDED, BLACK}
var st := ROOM_WAIT
var vp: SubViewport
var tcam: Camera3D
var scr_mat: ShaderMaterial
var osd: Label
var osd_trk: Label
var stamp: Label
var glow: OmniLight3D
var knob: MeshInstance3D
var trk := 0.18                # the knob, 0..1
var on_knob := false
var tape_t := 0.0
var room_t := 0.0
var end_t2 := -1.0
var card11: Control
var card11_t := 5.0
var tline := {}                # the line being written: {lb, text, written, segs, n_all, n_clear}
var heard_clear := 0
var heard_all := 0
var tswing := -1.0
var tswings := 0
var held_since := -1.0
var black2: ColorRect
var demo11 := false

func _init():
	tape = true

func _ready():
	super._ready()
	load_story("ch11")
	for e in _flow("テープ.流れ"): e[0] = float(e[0]) + NIGHT_AT; LINES.append(e)
	_room()
	_screen()
	var c: Array = D.lines("十一.カード")
	card11 = main.make_card(self, [[c[0], 46, 40], [c[1], 150, 90], [c[2], 36, 0]], Type.card())
	black2 = ColorRect.new(); black2.color = Color(0, 0, 0, 0); black2.set_anchors_preset(Control.PRESET_FULL_RECT); black2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bl := CanvasLayer.new(); bl.layer = 22; add_child(bl); bl.add_child(black2)
	# she sits; she does not walk in this chapter
	player.fly = true; player.collision_layer = 0; player.collision_mask = 0; player.move_enabled = false
	player.eye_height = EYE.y
	player.global_position = ROOM + Vector3(EYE.x, 0.0, EYE.z)
	player.yaw = 0.0; player.pitch = deg_to_rad(-7.0)
	(player.get_node("Head/Camera") as Camera3D).fov = 34.0
	_foot.call_deferred("マウス 見る　Ｅ 再生　右クリック（押したまま） つまみに手を置く　　Ｆ１２ 画面の保存　Ｅｓｃ マウス解放")
	# the hall waits as it was at the tape's first frame
	clock = NIGHT_AT
	for a in OS.get_cmdline_user_args():
		if a == "--demo": demo11 = true
		if a == "--nocard4": card11_t = 0.0
		if a.begins_with("--d11at="):    # stills: the tape at this second, the tracking as --d11trk= has it (default: right)
			card11_t = 0.0; call_deferred("_tape_jump", float(a.substr(8)))
		if a.begins_with("--d11trk="): set_meta("trk", float(a.substr(9)))
		if a == "--d11full":   # stills: the tape's own picture over the whole view (what the small camera took), under the print
			var fl := CanvasLayer.new(); fl.layer = 9; add_child(fl)
			var tr := TextureRect.new(); tr.texture = vp.get_texture(); tr.set_anchors_preset(Control.PRESET_FULL_RECT)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; fl.add_child(tr)
			var bg := ColorRect.new(); bg.color = Color.BLACK; bg.set_anchors_preset(Control.PRESET_FULL_RECT); bg.show_behind_parent = true; tr.add_child(bg)
		if a.begins_with("--d11gain="): (tcam.attributes as CameraAttributesPractical).exposure_multiplier = float(a.substr(10))
		if a == "--d11end": card11_t = 0.0; call_deferred("_end_tape"); set_meta("endstill", true)

# ================================================================ the room
func _box(at: Vector3, size: Vector3, col: Color, rough := 0.8) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm
	var m := StandardMaterial3D.new(); m.albedo_color = col; m.roughness = rough
	mi.material_override = m; mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	main.add_child(mi); mi.global_position = ROOM + at
	return mi

func _tvbox(at: Vector3, size: Vector3, col: Color, rough := 0.5) -> MeshInstance3D:
	var mi := _box(at, size, col, rough); mi.layers = 2      # the set does not light its own face
	return mi

func _room():
	_box(Vector3(0, -0.05, 0.6), Vector3(4.0, 0.1, 4.0), Color(0.42, 0.36, 0.27))             # the floor
	_box(Vector3(0, 1.2, -0.42), Vector3(4.0, 2.6, 0.1), Color(0.62, 0.60, 0.55))             # the wall behind the set
	_box(Vector3(-2.0, 1.2, 0.6), Vector3(0.1, 2.6, 4.0), Color(0.62, 0.60, 0.55))
	_box(Vector3(2.0, 1.2, 0.6), Vector3(0.1, 2.6, 4.0), Color(0.62, 0.60, 0.55))
	_box(Vector3(0, 2.5, 0.6), Vector3(4.0, 0.1, 4.0), Color(0.5, 0.5, 0.48))
	_box(Vector3(0, 1.2, 2.6), Vector3(4.0, 2.6, 0.1), Color(0.5, 0.5, 0.48))
	# a low board on two bricks' worth of books; the deck on it, the television on the deck
	_box(Vector3(0, 0.13, -0.08), Vector3(0.95, 0.03, 0.46), Color(0.30, 0.22, 0.15))
	_box(Vector3(-0.36, 0.06, -0.08), Vector3(0.16, 0.12, 0.24), Color(0.55, 0.5, 0.42))
	_box(Vector3(0.36, 0.06, -0.08), Vector3(0.16, 0.12, 0.24), Color(0.45, 0.5, 0.52))
	var deck := _box(Vector3(0, 0.20, -0.06), Vector3(0.43, 0.10, 0.34), Color(0.10, 0.10, 0.11), 0.45)
	_box(Vector3(-0.07, 0.215, 0.111), Vector3(0.20, 0.028, 0.004), Color(0.03, 0.03, 0.03), 0.3)   # the slot
	# its keys: 録画 and 取り出し at the right, each a key with its name printed over it
	for k in [[0.085, "録画", Color(0.55, 0.12, 0.08)], [0.150, "取り出し", Color(0.30, 0.30, 0.31)]]:
		_box(Vector3(k[0], 0.178, 0.112), Vector3(0.042, 0.016, 0.006), k[2], 0.5)
		var lb := Label3D.new(); lb.text = k[1]; lb.font = Type.cam(); lb.font_size = 32; lb.pixel_size = 0.00042
		lb.modulate = Color(0.82, 0.82, 0.78); lb.outline_size = 0; lb.shaded = false
		main.add_child(lb); lb.global_position = ROOM + Vector3(k[0], 0.198, 0.1115)
	# the tracking knob, at the left
	knob = MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.016; cy.bottom_radius = 0.016; cy.height = 0.012
	knob.mesh = cy; var km := StandardMaterial3D.new(); km.albedo_color = Color(0.32, 0.32, 0.33); km.roughness = 0.4; knob.material_override = km
	main.add_child(knob); knob.global_position = ROOM + Vector3(-0.175, 0.185, 0.114); knob.rotation.x = PI / 2.0
	var mark := MeshInstance3D.new(); var mb := BoxMesh.new(); mb.size = Vector3(0.003, 0.002, 0.014); mark.mesh = mb
	var mm := StandardMaterial3D.new(); mm.albedo_color = Color(0.9, 0.9, 0.85); mark.material_override = mm
	knob.add_child(mark); mark.position = Vector3(0, 0.0065, -0.008)
	var kl := Label3D.new(); kl.text = "トラッキング"; kl.font = Type.cam(); kl.font_size = 32; kl.pixel_size = 0.00036
	kl.modulate = Color(0.82, 0.82, 0.78); kl.outline_size = 0; kl.shaded = false
	main.add_child(kl); kl.global_position = ROOM + Vector3(-0.175, 0.216, 0.1115)
	# the television: a grey tube set, the glass a little back in its face
	var tv := Vector3(TV_C.x, TV_C.y, -0.10)
	_tvbox(tv + Vector3(0, -0.02, -0.02), Vector3(0.60, 0.50, 0.44), Color(0.20, 0.20, 0.21), 0.6)
	_tvbox(tv + Vector3(0, 0.0, 0.196), Vector3(0.50, 0.385, 0.012), Color(0.05, 0.05, 0.055), 0.4)    # the mask round the glass
	# the tape's case on the floor, its label to her
	_box(Vector3(0.52, 0.012, 0.42), Vector3(0.075, 0.024, 0.105), Color(0.12, 0.12, 0.13), 0.5).rotation.y = 0.5
	# the only light: the screen
	glow = OmniLight3D.new(); glow.light_color = Color(0.72, 0.82, 1.0); glow.light_energy = 0.05
	glow.omni_range = 3.2; glow.omni_attenuation = 1.3; glow.shadow_enabled = true; glow.light_volumetric_fog_energy = 0.0; glow.light_specular = 0.2; glow.light_cull_mask = 1
	glow.set_meta("own_shadow", true); main.add_child(glow); glow.global_position = ROOM + tv + Vector3(0, 0.0, 0.50)

const SCREEN_SHADER := """shader_type spatial;
render_mode unshaded;
uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform float err = 0.0;      // the tracking: 0 right .. 1 lost
uniform float tm = 0.0;
uniform float on = 0.0;       // 0 dark glass, 1 the tape, 2 after the tape (the deck's blank blue)
float h(float x) { return fract(sin(x * 91.17) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	float ln = floor(uv.y * 240.0);
	// off its track the heads read between two fields: bands of lines sheared sideways roll up the picture, the bands
	// wider and more of them the further off; whole picture slides and its top hooks over
	float roll = fract(uv.y * 1.6 + tm * 0.23);
	float band = smoothstep(0.0, 0.04, roll) * (1.0 - smoothstep(0.10 + 0.55 * err, 0.16 + 0.6 * err, roll));
	float tear = (h(ln * 0.37 + floor(tm * 24.0)) - 0.5) * 0.34 * err * band;
	tear += 0.05 * err * sin(uv.y * 31.0 + tm * 5.0);
	tear += 0.08 * smoothstep(0.92, 1.0, uv.y) * (0.25 + err) * (h(ln + floor(tm * 12.0)) - 0.2);   // the head switch, at the foot, always
	uv.x += tear;
	uv.y = mix(uv.y, fract(uv.y + 0.18 * sin(tm * 0.7)), step(0.75, err));
	vec3 c = texture(tex, uv).rgb;
	float out_x = step(uv.x, 0.0) + step(1.0, uv.x);
	c = mix(c, vec3(0.02), clamp(out_x, 0.0, 1.0));
	c = mix(c, vec3(dot(c, vec3(0.3, 0.6, 0.1))) * 1.15 + 0.06, band * err);      // in the band the colour goes and the black lifts
	if (on < 0.5) c = vec3(0.012, 0.014, 0.018);
	if (on > 1.5) c = vec3(0.10, 0.16, 0.42);
	ALBEDO = c;
}"""

func _screen():
	vp = SubViewport.new(); vp.size = Vector2i(768, 576); vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_2X
	add_child(vp)
	tcam = Camera3D.new(); tcam.fov = FINDER_FOV; tcam.near = 0.03; tcam.far = 60.0
	main.set_meta("shadow_eye", tcam)   # 2026-11-14 重さ：家の影は、テレビの中のカメラの近くの明かりだけ（main._shadow_budget）
	var at := CameraAttributesPractical.new(); tcam.attributes = at
	at.exposure_multiplier = 3.0       # the camcorder's gain is up in the dark: it has what her eyes did not
	vp.add_child(tcam); tcam.global_transform = _rail_cam(); tcam.current = true
	fixed_cam.visible = false          # the camera does not see itself
	# what the camcorder burned into its own picture, and what the deck writes over it
	var ui := Control.new(); ui.set_anchors_preset(Control.PRESET_FULL_RECT); vp.add_child(ui)
	var mk = func(txt: String, pos: Vector2, fs: int) -> Label:
		var lb := Label.new(); lb.text = txt; lb.add_theme_font_override("font", Type.cam()); lb.add_theme_font_size_override("font_size", fs)
		lb.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9)); lb.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		lb.add_theme_constant_override("shadow_offset_x", 2); lb.add_theme_constant_override("shadow_offset_y", 2)
		lb.position = pos; ui.add_child(lb); return lb
	stamp = mk.call("AM 3:29:54", Vector2(566, 34), 32)
	osd = mk.call("再生", Vector2(44, 34), 32)
	osd_trk = mk.call("", Vector2(44, 78), 32)
	var q := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = SCR; q.mesh = qm
	var sh := Shader.new(); sh.code = SCREEN_SHADER
	scr_mat = ShaderMaterial.new(); scr_mat.shader = sh
	scr_mat.set_shader_parameter("tex", vp.get_texture())
	q.material_override = scr_mat; q.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	main.add_child(q); q.global_position = ROOM + Vector3(TV_C.x, TV_C.y, 0.103)

# ================================================================ time
func _target_trk(t: float) -> float:
	# where the knob has to be: the tape was stretched in two places, so it wanders twice
	return 0.62 + 0.11 * smoothstep(20.0, 25.0, t) - 0.16 * smoothstep(29.5, 33.0, t)

func _err() -> float:
	return clampf(absf(trk - _target_trk(tape_t)) / 0.30, 0.0, 1.0)

func _clock(dt: float) -> bool:
	if card11_t > 0.0:
		card11_t -= dt; player.look_enabled = false
		if card11_t <= 0.0: card11.visible = false; player.look_enabled = true
		return false
	card11.visible = false
	room_t += dt
	_room_tick(dt)
	if st != PLAYING: return false
	tape_t += dt
	clock = tape_t + NIGHT_AT; t_now = clock
	return true

func _room_tick(dt: float):
	var cam: Camera3D = player.get_node("Head/Camera")
	var deck_at := ROOM + Vector3(0, 0.20, 0.11)
	var at_deck: bool = (-cam.global_basis.z).angle_to(deck_at - cam.global_position) < deg_to_rad(14.0)
	var e := _err()
	scr_mat.set_shader_parameter("tm", room_t)
	scr_mat.set_shader_parameter("err", e)
	scr_mat.set_shader_parameter("on", 0.0 if st == ROOM_WAIT else (1.0 if st == PLAYING else 2.0))
	glow.light_energy = 0.05 if st == ROOM_WAIT else (0.55 if st == PLAYING else 0.8)
	knob.rotation.z = (trk - 0.5) * 4.4
	player.look_enabled = not on_knob and st != ENDED
	match st:
		ROOM_WAIT:
			note_lb.text = T(String(B("十一.部屋")[0].note)) if at_deck else ""
			if demo11 and room_t > 3.0:
				player.pitch = lerp(player.pitch, deg_to_rad(-34.0), 1.0 - exp(-dt * 3.0))
				if at_deck and room_t > 5.0: _play()
		PLAYING:
			var G: Array = B("テープ.案内")
			note_lb.text = T(String(G[1].note if on_knob else G[0].note)) if (e > 0.2 or on_knob) else ""
			osd.visible = tape_t < 4.0
			if tape_t < 1.6:                     # the key pressed, her eyes go back up to the picture
				var ku := 1.0 - exp(-dt * 4.0)
				player.yaw = lerp_angle(player.yaw, 0.0, ku); player.pitch = lerp(player.pitch, deg_to_rad(-7.0), ku)
			osd_trk.text = ("トラッキング " + "-".repeat(int(trk * 16.0)) + "|" + "-".repeat(16 - int(trk * 16.0))) if on_knob else ""
			var s := 54 + int(tape_t)
			stamp.text = "AM 3:%02d:%02d" % [29 + s / 60, s % 60]
			_tape_swing(dt)
			if demo11: _demo11(dt)
		ENDED:
			end_t2 += dt
			note_lb.text = ""
			# her eyes go down to the deck's two keys; then nothing
			if end_t2 > 2.0:
				var k := 1.0 - exp(-dt * 1.6)
				player.yaw = lerp_angle(player.yaw, deg_to_rad(-8.5), k); player.pitch = lerp(player.pitch, deg_to_rad(-36.5), k)
				cam.fov = lerp(cam.fov, 17.0, k * 0.7)
			if end_t2 > 9.0 and not has_meta("endstill"):
				st = BLACK; black2.color.a = 1.0
				print("STORY ch11 black room_t=%.1f heard %d/%d" % [room_t, heard_clear, heard_all])
		BLACK:
			end_t2 += dt
			if demo11 and end_t2 > 12.0:
				print("DEMO DONE t=%.1f fails=%d (ch11, heard %d/%d)" % [room_t, DEMO_FAILS, heard_clear, heard_all]); demo11 = false
				if "--demoquit" in OS.get_cmdline_user_args(): get_tree().quit()

func _play():
	st = PLAYING; tape_t = 0.0
	note_lb.text = ""
	print("STORY ch11 play room_t=%.1f" % room_t)

func _end_tape():
	_tape_close()
	st = ENDED; end_t2 = 0.0
	_clear_page(); cur = {}
	print("STORY ch11 tape end t=%.1f" % tape_t)

# ================================================================ what the night does on the tape
func _do4(what: String):
	match what:
		"strike", "strike2": tswing = 0.0; tswings += 1
		"end": _end_tape()
		_: super._do4(what)

# Mio is under the camera, out of its frame. The tripod is in her hands from the second she took it up in 第4章;
# what the tape has of her is the tripod coming into the frame, twice.
func _tape_swing(dt: float):
	if clock < 13.5: return
	if weapon.get_parent() != main:
		weapon.get_parent().remove_child(weapon); main.add_child(weapon)
	var hands := gp(TAPE_MIO[0] + 0.12, TAPE_MIO[1] - 0.25, 1.18)
	var tgt := gp(NPATH[-1][0], NPATH[-1][1], 1.5) if nstate == "out" else _nhead()
	var dir := tgt - hands; dir.y = 0.0; dir = dir.normalized()
	var ang := -0.22                       # held upright against her shoulder
	if tswing >= 0.0:
		tswing += dt
		var k := tswing / 0.9
		if k < 0.3: ang = lerp(-0.22, -0.75, smoothstep(0.0, 0.3, k))
		elif k < 0.5: ang = lerp(-0.75, 1.55, pow((k - 0.3) / 0.2, 2.0))
		else: ang = lerp(1.55, -0.22, smoothstep(0.5, 1.0, k))
		if k >= 0.44 and not swing_hit: swing_hit = true; _blow(true)
		if k >= 1.0: tswing = -1.0; swing_hit = false
	var axis := Vector3.UP.cross(dir).normalized()
	weapon.global_transform = Transform3D(Basis(axis, ang) * Basis(Vector3.UP, atan2(dir.x, dir.z)), hands) * Transform3D(Basis(), Vector3(0, -0.42, 0))

func _blow(head: bool):
	head_hits += 1
	nap.pause(); nwalk = false
	if head_hits == 1: hit_base = Transform3D(Basis(Vector3.UP, nrig.global_rotation.y), nrig.global_position)
	nbase = hit_base
	if head_hits == 1: _capture(); nstate = "reel"; reel_t = 0.0
	else: reel_pose = last_pose.duplicate(true); nstate = "down"; fall_t = 0.0
	print("STORY ch11 blow %d tape_t=%.1f" % [head_hits, tape_t])

# ================================================================ the words, as far as the tracking lets them through
func _event(e: Array):
	match e[1]:
		"do": _do4(e[2])
		"note":
			_tape_close()
			if demo11: print("SAY %.1f %s" % [tape_t, e[2]])
			_line_row("", T(e[2]) if _err() < 0.45 else T("（雑音）"), 26, "note")
		"say":
			_tape_close()
			named.erase(e[2]); last_who = ""          # every line of a tape's transcript carries who says it
			var r = _line_row(e[2], "")
			tline = {"lb": r[1], "who": e[2], "text": Tw(e[3]), "written": 0.0, "n": 0, "n_all": 0, "n_clear": 0}
			rrow = {"segs": []}

func _typing(dt: float):
	if not tline.has("lb") or not is_instance_valid(tline.lb): return
	var text: String = tline.text
	if tline.n >= text.length(): return
	tline.written += dt * 9.0             # as it is said, not as a transcript is typed
	var e := _err()
	while tline.n < int(tline.written) and tline.n < text.length():
		var ch := text[tline.n]; tline.n += 1
		if ch == ZW: _seg("ok", ch); continue
		# the tracking, moment by moment: the dropouts come in clumps, as the radio's did
		var wob := 0.5 + 0.5 * sin(tape_t * 4.7 + 2.0 * sin(tape_t * 1.9)) * sin(tape_t * 0.83 + 1.0)
		var clear: bool = (1.0 - e) + 0.25 * (wob - 0.5) > 0.72
		if ch in "、。……？！　『』": _seg("ok" if clear or e < 0.6 else "gap", ch if clear or e < 0.6 else ""); continue
		tline.n_all += 1
		if clear: tline.n_clear += 1; _seg("ok", ch)
		elif e > 0.75: _seg("noise", "")
		else: _seg("gap", "")
	(tline.lb as Label).text = _wrap_row(_segs_text(rrow.segs))

func _tape_close():
	if tline.has("lb"):
		heard_all += tline.n_all; heard_clear += tline.n_clear
		print("SAY %.1f %s：%s  (clear %d/%d)" % [tape_t, tline.who, String(tline.text).replace(ZW, ""), tline.n_clear, tline.n_all])
	tline = {}

# ================================================================ her hands
func _unhandled_input(e):
	if card11.visible or st in [ENDED, BLACK]: return
	if st == ROOM_WAIT:
		var press: bool = (e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
		if press and note_lb.text != "": _play()
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT: on_knob = e.pressed
	elif e is InputEventMouseMotion and on_knob and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		trk = clampf(trk + e.relative.x * 0.0006, 0.0, 1.0)
	elif on_knob and e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		trk = clampf(trk + (0.004 if e.button_index == MOUSE_BUTTON_WHEEL_UP else -0.004), 0.0, 1.0)

# stills: the tape at t seconds
func _tape_jump(t: float):
	_play()
	trk = float(get_meta("trk", _target_trk(t)))
	var placed_n := false
	var place = func():
		var j := 0
		for i in range(NPATH.size() - 1):
			if t + NIGHT_AT > float(NPATH[i][3]) + 3.0: j = i + 1
		ni = j + 1
		var at := gp(NPATH[j][0], NPATH[j][1], NPATH[j][2])
		var m := _mio_eye() - at
		nrig.global_transform = Transform3D(Basis(Vector3.UP, atan2(m.x, m.z) if j >= 2 else 0.0), at)
		_drops_upto(j)
		nap.play("walk/walk"); nap.seek(0.3, true); nap.pause(); nstate = "stand"
	while li < LINES.size() and float(LINES[li][0]) <= t + NIGHT_AT:
		clock = float(LINES[li][0]); tape_t = clock - NIGHT_AT
		var e: Array = LINES[li]; li += 1
		if e[1] == "do" and e[2] in ["strike", "strike2"]:
			if not placed_n: place.call(); placed_n = true
			if t >= tape_t + HIT_LAG: _blow(true); reel_t = 9.0; fall_t = 9.0 if head_hits > 1 else -1.0
			else: tswing = t - tape_t
			continue
		_event(e)
		if tline.has("lb"): tline.written = 999.0; _typing(0.0)
	if door_t >= 0.0: door_t = 10.0
	if nstate in ["stand", "walk"] and not placed_n: place.call()
	tape_t = t; clock = t + NIGHT_AT

# the unattended run: her hand goes to the knob when the picture tears, and finds the place
func _demo11(dt: float):
	var want := _target_trk(tape_t)
	var off := absf(trk - want)
	if off > 0.05 and held_since < 0.0 and tape_t > 3.0: held_since = tape_t
	on_knob = held_since >= 0.0 and tape_t - held_since > 1.2
	if on_knob:
		trk = move_toward(trk, want, dt * 0.09)
		if absf(trk - want) < 0.004: held_since = -1.0; on_knob = false

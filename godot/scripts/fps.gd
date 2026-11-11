## ステップ D：第4章「戻ってきたもの」 3:30、廊下。FPS の場面（docs/企画書.md「FPS（第4章・3:30）」）。
## 家まるごとの 3:30 で動く（--scene=house --time=t0330 に、このノードを main の子として足す）。台詞は story/ch4.txt。
##
## Mio stands at the foot of the stairs, under the small camera she set on the handrail at dusk (it is still recording:
## 第11章's tape is this night from there, scripts/tape.gd, which plays this same file with tape = true). The front
## door, unlocked since Kiryu left at two, opens. Someone comes in, bleeding, slowly. In her memory what they say is
## （うめき声）, without a name. Kiryu's tripod stands by the newel with the camcorder still on it; when she takes it
## up (E) the game's own marks come on without a sound: a crosshair that turns red on the head, 頭を狙え, a hit marker.
##
## The HUD is the one thing in the whole game that is not printed: it is drawn over the print layer, in a white and a
## red that neither plate has, sharp to the pixel. Everything Mio remembers is paper and two inks; this comes from
## outside the paper, from every zombie game the player has played. It goes as it came when the figure is down.
extends "res://scripts/story.gd"

# ---------------------------------------------------------------- the night (plan metres: x east, y north from the front door; z up)
const MIO_AT := [4.55, 3.0]                       # her feet: the middle of the hall, left of the handrail camera's frame
const TAPE_MIO := [4.35, 3.15]                    # on the tape she stands a step further left: all of her, and the tripod at her shoulder, outside the small camera's frame
const WEAPON_AT := [4.16, 2.62]                   # the tripod, moved from the genkan to the stair's foot for this night
const DOOR_OPEN := 88.0                           # as Kiryu left it open at two (scene.json state.t02.front)
const HEAD_R := 0.14
const REACH := 1.75                               # eye to her head: the tripod's length and an arm
const NSPEED := 0.36                              # m/s: she drags herself in
# where she comes: [plan x, y, z, the second she goes on from there]. The last is where she stops in the canonical
# night (the tape); played, the last is a metre short of wherever Mio stands when she sets off for it.
const NPATH := [[5.0, -0.75, -0.21, 10.0], [5.0, 0.15, -0.18, 17.5], [4.95, 0.75, -0.18, 25.0], [4.85, 1.5, 0.0, 33.0], [4.75, 2.0, 0.0, 1e9]]
const STRIKES := [50.0, 51.2]                     # the canonical blows (the tape: 46.0 and 47.2)

var tape := false              # 第11章: the same night, nobody at the controls (tape.gd)
var LINES := []                # [t, kind, ...] from 【四.流れ】 / 【テープ.流れ】
var li := 0
var clock := 0.0               # the night's clock (seconds after the card)
var card4: Control
var aim_n := 0
var card_t := 5.0
var nat: Node3D
var nrig: Node3D
var nap: AnimationPlayer
var nsk: Skeleton3D
var nhead := -1
var ni := 0                    # the point she is walking to
var nstate := "out"            # out | walk | stand | reel | down
var nwalk := false
var reel_t := 0.0
var fall_t := -1.0
var nbase := Transform3D()     # the rig where it stood when she was hit
var weapon: Node3D
var weapon_h := 1.4
var holding := false
var swing_t := -1.0
var swing_hit := false
var head_hits := 0
var hud: Hud
var hud_on := false
var after_t := -1.0            # seconds since she went down
var after_said := 0
var rec_t := -1.0
var black: ColorRect
var door_t := -1.0
var door_light: SpotLight3D
var told_tripod := false
var demo4 := false
var demo_step := 0

static func load_story(file: String):
	D.load_all()
	if D.blocks.has("@" + file): return
	D.blocks["@" + file] = []
	var p := "res://story/%s.txt" % file
	if not FileAccess.file_exists(p): print("SCRIPT ERROR 台本: no file ", p); return
	var key := ""
	for raw in FileAccess.get_file_as_string(p).split("\n"):
		var ln := String(raw).strip_edges()
		if ln == "" or ln.begins_with("//"): continue
		if ln.begins_with("【") and ln.ends_with("】"):
			key = ln.substr(1, ln.length() - 2); D.blocks[key] = []
		elif key != "": D.blocks[key].append(String(raw).rstrip(" \t\r"))

func _flow(key: String) -> Array:
	var out := []
	for e in B(key):
		if not e.has("t"): continue
		if e.has("do"): out.append([e.t, "do", e.do])
		elif e.has("note"): out.append([e.t, "note", e.note])
		else: out.append([e.t, "say", e.get("who", ""), e.text, e.get("testimony", false)])
	return out

func _ready():
	player = main.player
	font = Type.say()
	u = get_viewport().get_visible_rect().size.y / 1080.0
	load_story("ch4")
	_page()
	_stage()
	if tape: return
	LINES = _flow("四.流れ")
	_finder()
	_hud()
	var c: Array = D.lines("四.カード")
	card4 = main.make_card(self, [[c[0], 46, 40], [c[1], 150, 90], [c[2], 36, 0]], Type.card())
	black = ColorRect.new(); black.color = Color(0, 0, 0, 0); black.set_anchors_preset(Control.PRESET_FULL_RECT); black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bl := CanvasLayer.new(); bl.layer = 22; add_child(bl); bl.add_child(black)
	player.global_position = gp(MIO_AT[0], MIO_AT[1], 0.0)
	player.yaw = 0.0; player.pitch = deg_to_rad(-4.0)     # south (Godot -z), down the hall to the front door
	if main.foot: main.foot.text = T("ＷＡＳＤ 歩く　マウス 見る　Ｅ 手に取る　　Ｆ１２ 画面の保存　Ｅｓｃ マウス解放")
	for a in OS.get_cmdline_user_args():
		if a == "--demo": demo4 = true
		if a.begins_with("--d4at="): call_deferred("_jump", float(a.substr(7)))   # stills: start the night at this second
		if a == "--d4hold": holding = true; call_deferred("_take")                  # stills: the tripod already in her hands
		if a == "--nocard4": card_t = 0.0
		if a.begins_with("--d4swing="): set_meta("swingk", float(a.substr(10)))   # stills: the tripod at this point of the blow (0..1)

# ================================================================ the stage: the same for the game and for the tape
func _stage():
	# Natsuki as she was outside the door at eleven (wet, her shoes on), with the walk the 20:00 people have
	main._load_scene("res://assets/natsuki.glb", "natsuki")
	nat = main.S.natsuki_node
	main._faces()
	main._walk_anims("natsuki", nat)
	nsk = nat.find_children("*", "Skeleton3D", true, false)[0]
	nrig = nsk.get_parent() as Node3D
	nap = nat.find_children("*", "AnimationPlayer", true, false)[0]
	nhead = nsk.find_bone("head")
	nap.stop(); nsk.reset_bone_poses()
	for ba in nsk.find_children("nphone*", "BoneAttachment3D", true, false): (ba as Node3D).visible = false   # no phone: its battery went hours ago
	if not "--d4noblood" in OS.get_cmdline_user_args(): _blood()
	_lookers()
	nrig.global_transform = Transform3D(Basis(Vector3.UP, 0.0), gp(NPATH[0][0], NPATH[0][1], NPATH[0][2]))
	nat.visible = false
	# the tripod and the camcorder on it: lifted out of the house (their vertices are in the house's own frame) onto a
	# node at their feet, and stood by the newel
	var parts: Array = []
	for mi in main.S.env_node.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if nm.begins_with("tpd_") or nm.begins_with("vcam_") or nm == "lcd" or nm.begins_with("lcd_") or nm.begins_with("recled"): parts.append(mi)
	var bb := AABB(); var first := true
	for mi in parts:
		var a: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		bb = a if first else bb.merge(a); first = false
	weapon = Node3D.new(); weapon.name = "weapon"; main.add_child(weapon)
	weapon.global_position = Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)
	weapon_h = bb.size.y
	for mi in parts:
		var gt: Transform3D = (mi as Node3D).global_transform
		mi.get_parent().remove_child(mi); weapon.add_child(mi); (mi as Node3D).global_transform = gt
		(mi as MeshInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		(mi as MeshInstance3D).extra_cull_margin = 2.0
	if main.lights.has("rec_light"):
		var rl: Light3D = main.lights.rec_light
		var gt2 := rl.global_transform
		rl.get_parent().remove_child(rl); weapon.add_child(rl); rl.global_transform = gt2
	_weapon_rest()
	# the storm's light in the doorway when the door is open: she is a shape against it before she is anyone
	door_light = SpotLight3D.new(); door_light.light_color = Color(0.62, 0.74, 1.0); door_light.light_energy = 0.0
	door_light.spot_range = 9.0; door_light.spot_angle = 26.0; door_light.spot_angle_attenuation = 1.4; door_light.spot_attenuation = 0.7
	door_light.shadow_enabled = true; door_light.light_volumetric_fog_energy = 0.6; door_light.light_specular = 0.15
	main.add_child(door_light)
	door_light.look_at_from_position(gp(5.0, -3.2, 1.9), gp(4.85, 2.2, 0.2), Vector3.UP)
	_night_cam4()
	_lantern()
	_mio_shadow()

# A second camp lantern, the crew's, hung under the handrail camera: Mio's, for her watch over the door. It is the one warm light
# at this end of the hall, and a weak one. Whoever comes in is a shape against the storm in the door, and walks into
# this light only in the last two metres; the small camera, its gain up, has a face from the genkan on (第11章).
# (On the newel's cap it stood in the middle of the small camera's picture. On the stairs' treads it lit nothing: the stairs are boarded in on the hall's side. On the floor behind her, Mio's
# own shadow covered whoever stood before her.)
const LANTERN_AT := [4.97, 3.50, 1.40]     # plan x, y; z its foot: hung on the stair's boarding under the handrail camera, below its frame
var lantern: OmniLight3D
func _lantern():
	var src: Light3D = main.lights.get("lantern_stair")
	var from := Vector3.ZERO
	if src: from = src.global_position
	var to := gp(LANTERN_AT[0], LANTERN_AT[1], LANTERN_AT[2] + 0.154)
	for mi in main.S.env_node.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if not (nm.begins_with("crew_lantern_stair") or nm.begins_with("lampshade_lantern_stair")): continue
		var c := mi.duplicate() as MeshInstance3D
		c.name = "d_" + nm; mi.get_parent().add_child(c)
		c.global_transform = (mi as MeshInstance3D).global_transform.translated(to - from)
		c.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lantern = OmniLight3D.new(); lantern.light_color = Color(1.0, 0.74, 0.50); lantern.light_energy = 0.4
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--d4lantern="): lantern.light_energy = float(a.substr(12))
		if a == "--d4lnoshadow": set_meta("lnosh", true)
	lantern.omni_range = 5.0; lantern.omni_attenuation = 1.3; lantern.shadow_enabled = true
	lantern.light_volumetric_fog_energy = 0.2; lantern.light_specular = 0.2; lantern.light_size = 0.03
	main.add_child(lantern); lantern.global_position = to
	if has_meta("lnosh"): lantern.shadow_enabled = false

# Mio has no body in this game (she is the eye). She has a shadow: the lantern behind her throws it down the hall, at
# whoever comes in. A column and a head that only cast.
var mio_shadow: Node3D
func _mio_shadow():
	mio_shadow = Node3D.new(); main.add_child(mio_shadow)
	var mat := StandardMaterial3D.new()
	for spec in [[CapsuleMesh.new(), Vector3(0, 0.70, 0), Vector3(0.36, 1.40, 0.24)], [SphereMesh.new(), Vector3(0, 1.50, 0), Vector3(0.21, 0.24, 0.22)], [CapsuleMesh.new(), Vector3(0, 1.26, 0), Vector3(0.44, 0.30, 0.22)]]:
		var mi := MeshInstance3D.new(); mi.mesh = spec[0]; mi.material_override = mat
		if mi.mesh is CapsuleMesh: (mi.mesh as CapsuleMesh).radius = 0.5; (mi.mesh as CapsuleMesh).height = 1.0 if spec[2].y < 0.5 else 2.0
		mi.position = spec[1]; mi.scale = spec[2] if not (mi.mesh is CapsuleMesh) else Vector3(spec[2].x, spec[2].y / (1.0 if spec[2].y < 0.5 else 2.0), spec[2].z)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mio_shadow.add_child(mi)
	mio_shadow.global_position = gp(MIO_AT[0], MIO_AT[1], 0.0)

func _weapon_rest():
	weapon.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(35.0)), gp(WEAPON_AT[0], WEAPON_AT[1], 0.0))

# the small camera on the handrail, still recording (door.gd _night_cam: the frame Kiryu drew, or where she set it)
func _night_cam4():
	_fixed_cam()
	fixed_cam.global_transform = _rail_cam()
	(fixed_cam.get_node("rec") as OmniLight3D).light_energy = 0.6
	var dm := (fixed_cam.get_node("recdot") as MeshInstance3D).material_override as StandardMaterial3D
	dm.emission_energy_multiplier = 6.0
	(fixed_cam.get_node("recdot2") as MeshInstance3D).material_override = dm

func _rail_cam() -> Transform3D:
	if PLACED.has("pos"): return Transform3D(PLACED.basis, PLACED.pos)
	var ta := _target_angles()
	return Transform3D(Basis.from_euler(Vector3(ta[1], ta[0], 0.0), EULER_ORDER_YXZ), g([TARGET_POS[0], TARGET_POS[1], _rail_z(TARGET_POS[1]) + 0.065]))

# blood from the hairline down the left of her face and onto the shoulder. In the print a dark red is the orange plate
# under the blue: it is the darkest warm thing in the hall.
func _blood():
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new(); rng.seed = 330
	var blots := []
	for i in 9: blots.append([rng.randf_range(34, 94), rng.randf_range(20, 108), rng.randf_range(9, 24)])
	for y in 128:
		for x in 128:
			var a := 0.0
			for b in blots: a = maxf(a, 1.0 - Vector2(x - b[0], y - b[1]).length() / b[2])
			a = maxf(a, 1.0 - absf(x - 60.0 - 5.0 * sin(y * 0.11)) / 7.0 if y > 30 else 0.0)   # the run down the cheek
			img.set_pixel(x, y, Color(0.30, 0.012, 0.012, clampf(a * 2.6, 0.0, 0.94)))
	var tex := ImageTexture.create_from_image(img)
	# [bone, where on her (rig frame: x her left, y up, z forward; from the bone), the box: across, deep, tall]
	var fwd := nsk.global_basis * Vector3(0, 0, 1); var up := Vector3.UP; var left := up.cross(fwd).normalized()
	for spec in [["head", Vector3(0.045, 0.10, 0.06), Vector3(0.15, 0.22, 0.24)], ["spine_03", Vector3(0.12, 0.12, 0.06), Vector3(0.22, 0.30, 0.30)]]:
		var bi := nsk.find_bone(spec[0])
		if bi < 0: continue
		var ba := BoneAttachment3D.new(); ba.bone_idx = bi; nsk.add_child(ba)
		var bw: Transform3D = nsk.global_transform * nsk.get_bone_global_pose(bi)
		var d := Decal.new(); d.texture_albedo = tex; d.size = spec[2]
		d.upper_fade = 0.3; d.lower_fade = 0.3; d.albedo_mix = 1.0
		ba.add_child(d)
		# it projects along its own -y: y out of her face, the texture's up her up
		var off: Vector3 = spec[1]
		var wb := Basis(left, fwd, left.cross(fwd).normalized())
		d.global_transform = Transform3D(wb, bw.origin + left * off.x + up * off.y + fwd * off.z)

# ================================================================ the HUD (not printed: over the print layer)
class Hud extends Control:
	var on_head := false
	var hit := 0.0             # seconds left of the hit marker
	var hit_head := false
	var guide := ""
	var key := ""
	var fnt: Font
	var u := 1.0
	var a := 0.0               # 0 gone .. 1 there
	const WHITE := Color(1, 1, 1)
	const RED := Color(1.0, 0.13, 0.09)
	func _draw():
		if a <= 0.0: return
		var c := (size / 2.0).round()
		var col := RED if on_head else WHITE
		col.a = a
		var w: float = maxf(2.0, round(2.0 * u)); var g0: float = round(7.0 * u); var g1: float = round(19.0 * u)
		var bk := Color(0, 0, 0, a * 0.85); var e := maxf(1.0, round(1.0 * u))
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_line(c + d * (g0 - e), c + d * (g1 + e), bk, w + 2.0 * e)
		draw_rect(Rect2(c - Vector2(w, w) / 2.0 - Vector2(e, e), Vector2(w, w) + Vector2(e, e) * 2.0), bk)
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_line(c + d * g0, c + d * g1, col, w)
		draw_rect(Rect2(c - Vector2(w, w) / 2.0, Vector2(w, w)), col)
		if hit > 0.0:
			var hc := RED if hit_head else WHITE
			hc.a = a * clampf(hit / 0.12, 0.0, 1.0)
			var h0: float = round(11.0 * u); var h1: float = round(25.0 * u)
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(c + d * (h0 - e), c + d * (h1 + e), Color(0, 0, 0, hc.a * 0.85), maxf(2.0, round(3.0 * u)) + 2.0 * e)
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(c + d * h0, c + d * h1, hc, maxf(2.0, round(3.0 * u)))
		var fs := int(32 * u)
		var gw := fnt.get_string_size(guide, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(fnt, Vector2(c.x - gw / 2.0, c.y + 96 * u), guide, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(maxf(2.0, 4.0 * u)), Color(0, 0, 0, a * 0.85))
		draw_string(fnt, Vector2(c.x - gw / 2.0, c.y + 96 * u), guide, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, a))
		var ks := int(24 * u)
		var kw := fnt.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, ks).x
		draw_string_outline(fnt, Vector2(size.x - kw - 60 * u, size.y - 56 * u), key, HORIZONTAL_ALIGNMENT_LEFT, -1, ks, int(maxf(2.0, 4.0 * u)), Color(0, 0, 0, a * 0.85))
		draw_string(fnt, Vector2(size.x - kw - 60 * u, size.y - 56 * u), key, HORIZONTAL_ALIGNMENT_LEFT, -1, ks, Color(1, 1, 1, a))

func _hud():
	var layer := CanvasLayer.new(); layer.layer = 20; add_child(layer)
	hud = Hud.new(); hud.fnt = Type.cam(); hud.u = u
	hud.guide = T("頭を狙え"); hud.key = T("左クリック　振る")
	hud.set_anchors_preset(Control.PRESET_FULL_RECT); hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)

# ================================================================ time
func _clock(dt: float) -> bool:
	# the chapter's card first; the night's clock starts when it has gone
	if card4 and card_t > 0.0:
		card_t -= dt
		player.move_enabled = false; player.look_enabled = false
		if card_t <= 0.0:
			card4.visible = false; player.move_enabled = true; player.look_enabled = true
		return false
	if card4: card4.visible = false
	clock += dt; t_now = clock
	return true

func _process(dt):
	if not _clock(dt): return
	while li < LINES.size() and clock >= float(LINES[li][0]):
		_event(LINES[li]); li += 1
	_night(dt)
	_typing(dt)
	if tape: return
	mio_shadow.global_position = Vector3(player.global_position.x, player.global_position.y, player.global_position.z)
	mio_shadow.rotation.y = player.yaw
	_look_at_things()
	_swing(dt)
	_hud_tick(dt)
	_after(dt)
	if demo4: _demo4(dt)
	if aim_n > 0 and nstate != "out":            # check stills: the middle of the view on her head
		aim_n -= 1
		var d: Vector3 = _nhead() - _mio_eye()
		player.yaw = atan2(-d.x, -d.z); player.pitch = asin(clampf(d.normalized().y, -1.0, 1.0))

func _typing(dt: float):
	if cur.has("text") and typed < String(cur.text).length():
		typed = min(float(String(cur.text).length()), typed + dt * (20.0 if cur.get("testimony", false) else 15.0))
		_type(cur_lb, String(cur.text), int(typed))

func _say(who: String, text: String, testimony := false):
	if demo4 or "--demo" in OS.get_cmdline_user_args(): print("SAY %.1f %s%s：%s" % [clock, who, "＊" if testimony else "", text])
	cur = {"who": who, "text": _wrap_row(Tw(text)), "testimony": testimony}
	typed = 0.0
	var r = _line_row(who, "", SAY_SIZE, "testimony" if testimony else "say")
	cur_lb = r[1]

func _event(e: Array):
	match e[1]:
		"do": _do4(e[2])
		"note":
			if nstate == "down": return          # nothing more is heard
			if demo4: print("SAY %.1f %s" % [clock, e[2]])
			_line_row("", T(e[2]), 26, "note"); cur = {}
		"say": _say(e[2], e[3], e[4])

func _do4(what: String):
	match what:
		"door": door_t = 0.0
		"enter":
			nat.visible = true; nstate = "stand"; ni = 1
			print("STORY ch4 enter t=%.1f" % clock)

# the night itself: the door, the one who comes in
func _night(dt: float):
	if door_t >= 0.0 and main.door_pivot:
		door_t += dt
		var k := clampf(door_t / 4.5, 0.0, 1.0); k = k * k * (3.0 - 2.0 * k)
		main.door_pivot.rotation.y = float(main.S.get("door_rot", 0.0)) + deg_to_rad(DOOR_OPEN) * k
		door_light.light_energy = 2.2 * k
	if nstate == "out": return
	if looks.has("natsuki"):
		var lm: Look = looks.natsuki
		lm.target = _mio_eye(); lm.want = 1.0 if nstate in ["walk", "stand"] else 0.0
	match nstate:
		"stand":
			if nwalk: nwalk = false; nap.pause()
			if ni < NPATH.size() and clock >= float(NPATH[ni - 1][3]): nstate = "walk"
			elif ni >= NPATH.size() and not tape and (_mio_eye() - nrig.global_position).length() > 2.1: ni = NPATH.size() - 1; nstate = "walk"   # Mio backs away: she comes on
			_sway(dt)
		"walk":
			if not nwalk:
				nwalk = true; nap.play("walk/walk", 0.4); nap.speed_scale = NSPEED / 1.14 * 1.25   # the feet a little quicker than the ground: she does not stride
			var to := _npoint(ni)
			var p := nrig.global_position
			var seg := to - p
			var hz := Vector2(seg.x, seg.z).length()
			var step := NSPEED * dt
			if step >= hz:
				p = to; ni += 1; nstate = "stand"
			else: p += seg * (step / hz)
			var yaw := nrig.global_rotation.y
			if hz > 0.05: yaw = lerp_angle(yaw, atan2(seg.x, seg.z), minf(1.0, dt * 3.0))
			nrig.global_transform = Transform3D(Basis(Vector3.UP, yaw), p)
		"reel":
			# the first blow: she goes back half a step, bent, and stays on her feet
			reel_t += dt
			var k2 := clampf(reel_t / 0.35, 0.0, 1.0); k2 = 1.0 - pow(1.0 - k2, 3.0)
			var back := nbase.basis * Vector3(0, 0, -1)
			nrig.global_transform = Transform3D(nbase.basis * Basis(Vector3.RIGHT, -0.20 * k2) * Basis(Vector3.FORWARD, 0.10 * k2), nbase.origin + back * 0.32 * k2)
		"down":
			fall_t += dt
			var k3 := clampf(fall_t / 0.62, 0.0, 1.0); k3 = k3 * k3
			var b0 := nbase.basis
			nrig.global_transform = Transform3D(b0 * Basis(Vector3.RIGHT, -1.50 * k3) * Basis(Vector3.FORWARD, 0.25 * k3), nbase.origin + Vector3(0, 0.10 * k3, 0) + (b0 * Vector3(0, 0, -1)) * 0.25 * k3)

var sway_t := 0.0
func _sway(dt: float):
	sway_t += dt
	var p := nrig.global_position; var y := nrig.global_rotation.y
	nrig.global_transform = Transform3D(Basis(Vector3.UP, y) * Basis(Vector3.FORWARD, 0.022 * sin(sway_t * 0.9)) * Basis(Vector3.RIGHT, 0.03 + 0.015 * sin(sway_t * 0.63 + 1.0)), p)

func _npoint(i: int) -> Vector3:
	var q: Array = NPATH[mini(i, NPATH.size() - 1)]
	if i >= NPATH.size() - 1 and not tape:
		# a metre short of Mio, wherever she stands
		var m: Vector3 = player.global_position
		var p: Vector3 = nrig.global_position
		var d: Vector3 = m - p; d.y = 0.0
		var L: float = d.length()
		var to: Vector3 = p + d * (1.0 - 1.05 / L) if L > 1.05 else p
		to.y = 0.0 if to.z > gp(0, 1.45, 0).z else p.y
		return to
	return gp(q[0], q[1], q[2])

func _mio_eye() -> Vector3:
	if tape: return gp(TAPE_MIO[0], TAPE_MIO[1], 1.5)
	return (player.get_node("Head/Camera") as Camera3D).global_position

func _nhead() -> Vector3:
	return nsk.global_transform * (nsk.get_bone_global_pose(nhead).origin + Vector3(0, 0.09, 0.0))

# ================================================================ the tripod in her hands
func _look_at_things():
	if holding or after_t >= 0.0: return
	var cam: Camera3D = player.get_node("Head/Camera")
	var at := weapon.global_position + Vector3(0, 1.0, 0)
	var near: bool = (at - cam.global_position).length() < 1.9 and (-cam.global_basis.z).angle_to(at - cam.global_position) < deg_to_rad(22.0)
	note_lb.text = T("［Ｅ　三脚］") if near else ""
	# she stands before her and Mio has taken nothing up: where the tripod is, once
	if not told_tripod and nstate == "stand" and ni >= NPATH.size() and clock > 46.0:
		told_tripod = true
		var e: Dictionary = B("四.まだ")[0]; _say(e.who, e.text, true)

func _take():
	holding = true
	note_lb.text = ""
	if weapon.get_parent() != player.get_node("Head/Camera"):
		weapon.get_parent().remove_child(weapon); player.get_node("Head/Camera").add_child(weapon)
	_held(0.0)
	for c in weapon.get_children():
		if c is MeshInstance3D: (c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	print("STORY ch4 take t=%.1f" % clock)

# the tripod in the view: gripped low on its legs, the head and the camcorder up at the right; k 0 at rest .. 1 the blow
func _held(k: float):
	var grip := 0.42                                   # metres up from the feet, where her hands are
	var rest := Basis.from_euler(Vector3(deg_to_rad(-12.0), deg_to_rad(8.0), deg_to_rad(-16.0)))
	var up := Basis.from_euler(Vector3(deg_to_rad(28.0), deg_to_rad(4.0), deg_to_rad(-10.0)))     # drawn back over the shoulder
	var down := Basis.from_euler(Vector3(deg_to_rad(-78.0), deg_to_rad(14.0), deg_to_rad(6.0)))   # through to the floor
	var b := rest; var hand := Vector3(0.30, -0.52, -0.42)
	if k > 0.0 and k < 0.3:
		var q := k / 0.3; q = q * q * (3.0 - 2.0 * q)
		b = rest.slerp(up, q); hand = hand.lerp(Vector3(0.30, -0.36, -0.36), q)
	elif k >= 0.3 and k < 0.5:
		var q2 := (k - 0.3) / 0.2; q2 = q2 * q2
		b = up.slerp(down, q2); hand = Vector3(0.30, -0.36, -0.36).lerp(Vector3(0.12, -0.50, -0.50), q2)
	elif k >= 0.5:
		var q3 := (k - 0.5) / 0.5; q3 = q3 * q3 * (3.0 - 2.0 * q3)
		b = down.slerp(rest, q3); hand = Vector3(0.12, -0.50, -0.50).lerp(hand, q3)
	weapon.transform = Transform3D(b, hand) * Transform3D(Basis(), Vector3(0, -grip, 0))

func _aim() -> Dictionary:
	# what the middle of the view is on: {head: bool, body: bool, dist: float}
	var cam: Camera3D = player.get_node("Head/Camera")
	var o := cam.global_position; var d := -cam.global_basis.z
	var out := {"head": false, "body": false, "dist": 99.0}
	if nstate in ["out", "down"]: return out
	var h := _nhead()
	out.dist = (h - o).length()
	var tproj := (h - o).dot(d)
	if tproj > 0.0 and (o + d * tproj - h).length() < HEAD_R: out.head = true
	# the body: a column from her feet to her neck
	var f := nrig.global_position
	for i in 8:
		var c := f + Vector3(0, 0.25 + i * 0.16, 0) + (h - Vector3(f.x, h.y, f.z)) * (float(i) / 7.0)
		var tp := (c - o).dot(d)
		if tp > 0.0 and (o + d * tp - c).length() < 0.19: out.body = true
	return out

func _swing(dt: float):
	if has_meta("swingk") and holding: _held(float(get_meta("swingk"))); return
	if swing_t < 0.0: return
	swing_t += dt
	var k := swing_t / 0.9
	_held(clampf(k, 0.0, 1.0))
	if not swing_hit and k >= 0.44:
		swing_hit = true
		var a := _aim()
		if a.dist <= REACH and (a.head or a.body): _blow(a.head)
	if k >= 1.0: swing_t = -1.0; _held(0.0)

func _blow(head: bool):
	hud.hit = 0.22; hud.hit_head = head
	print("STORY ch4 hit %s t=%.1f" % ["head" if head else "body", clock])
	if not head:
		if nstate in ["walk", "stand"]:   # a blow to the body: she rocks, and comes on
			var p := nrig.global_position + (nrig.global_basis * Vector3(0, 0, -1)) * 0.08
			nrig.global_position = p
		return
	head_hits += 1
	nap.pause(); nwalk = false
	nbase = Transform3D(Basis(Vector3.UP, nrig.global_rotation.y), nrig.global_position)
	if head_hits == 1:
		nstate = "reel"; reel_t = 0.0
	else:
		nstate = "down"; fall_t = 0.0; after_t = 0.0
		_clear_page(); cur = {}

func _hud_tick(dt: float):
	var want: bool = holding and nstate in ["walk", "stand", "reel"]
	if want != hud_on:
		hud_on = want
		print("STORY ch4 hud %s t=%.1f" % ["on" if want else "off", clock])
	hud.a = 1.0 if hud_on else 0.0         # no fade: it is there, then it is not
	hud.hit = maxf(0.0, hud.hit - dt)
	var a := _aim()
	hud.on_head = hud_on and a.head and a.dist <= REACH
	hud.queue_redraw()

# ================================================================ after
func _after(dt: float):
	if after_t < 0.0: return
	after_t += dt
	var A: Array = B("四.あと")
	if after_said == 0 and after_t > 4.0:
		after_said = 1; _say(A[0].who, A[0].text, true)
	elif after_said == 1 and after_t > 12.5:
		after_said = 2; _say(A[1].who, A[1].text, true)
	elif after_said == 2 and after_t > 16.0:
		after_said = 3; note_lb.text = T(String(A[2].note))
	if rec_t >= 0.0:
		rec_t += dt
		(finder_ui as FinderFrame).tc = "0:00:%02d" % int(rec_t)
		finder_ui.queue_redraw()
		if rec_t > 7.0: black.color.a = clampf((rec_t - 7.0) / 2.5, 0.0, 1.0)
		if rec_t > 11.0 and demo4:
			print("DEMO DONE ch4 t=%.1f" % clock); demo4 = false
			if "--demoquit" in OS.get_cmdline_user_args(): get_tree().quit()

func _record():
	# the camcorder comes off the tripod and to her eye: the hall through its screen, recording
	rec_t = 0.0
	note_lb.text = ""
	weapon.visible = false
	finder_layer.visible = true
	(finder_ui as FinderFrame).rec = true
	(player.get_node("Head/Camera") as Camera3D).fov = FINDER_FOV
	var e: Dictionary = B("四.録画")[0]
	get_tree().create_timer(2.5).timeout.connect(func(): _say(e.who, e.text, true))
	print("STORY ch4 record t=%.1f" % clock)

func _unhandled_input(e):
	if tape or (card4 and card4.visible): return
	var key_e: bool = e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E
	var click: bool = e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if not holding and after_t < 0.0:
		if (key_e or click) and note_lb.text != "": _take()
		return
	if after_t >= 0.0:
		if (key_e or click) and after_said == 3 and rec_t < 0.0: _record()
		return
	if click and swing_t < 0.0:
		swing_t = 0.0; swing_hit = false

# check stills: the night at t seconds, the lines before it on the page
func _jump(t: float):
	card_t = 0.0
	if card4: card4.visible = false
	while li < LINES.size() and float(LINES[li][0]) <= t:
		clock = float(LINES[li][0]); _event(LINES[li]); li += 1
		if cur.has("text"): typed = String(cur.text).length(); _type(cur_lb, String(cur.text), int(typed))
	if door_t >= 0.0: door_t = 10.0
	# she is where the hour has her
	if nstate != "out":
		var j := 0
		for i in range(NPATH.size() - 1):
			if t > float(NPATH[i][3]) + 3.0: j = i + 1
		ni = j + 1
		var at := gp(NPATH[j][0], NPATH[j][1], NPATH[j][2])
		var m := _mio_eye() - at
		nrig.global_transform = Transform3D(Basis(Vector3.UP, atan2(m.x, m.z) if j >= 2 else 0.0), at)
		nap.play("walk/walk"); nap.seek(0.3, true); nap.pause()
		nstate = "stand"
		print("JUMP j=%d at=%s rig=%s player=%s" % [j, at, nrig.global_position, player.global_position])
	clock = t
	if "--d4aim" in OS.get_cmdline_user_args(): aim_n = 4

# the unattended run: take the tripod up when she is in, wait as the canonical night does, two blows to the head
func _demo4(dt: float):
	var cam: Camera3D = player.get_node("Head/Camera")
	var turn = func(to: Vector3, rate: float):
		var d: Vector3 = to - cam.global_position
		var k := 1.0 - exp(-dt * rate)
		player.yaw = lerp_angle(player.yaw, atan2(-d.x, -d.z), k)
		player.pitch = lerp(player.pitch, asin(clampf(d.normalized().y, -1.0, 1.0)), k)
	match demo_step:
		0:
			if clock > 13.0: demo_step = 1
		1:
			turn.call(weapon.global_position + Vector3(0, 1.0, 0), 3.0)
			if note_lb.text != "": _take(); demo_step = 2
			elif clock > 22.0: print("DEMO FAIL ch4: cannot take the tripod t=%.1f" % clock); demo_step = 9
		2:
			if nstate != "out": turn.call(_nhead(), 2.5)
			if clock >= STRIKES[0] and swing_t < 0.0: swing_t = 0.0; swing_hit = false; demo_step = 3
		3:
			turn.call(_nhead(), 6.0)
			if clock >= STRIKES[1] and swing_t < 0.0: swing_t = 0.0; swing_hit = false; demo_step = 4
		4:
			if nstate != "down" and swing_t < 0.0:
				turn.call(_nhead(), 6.0)
				if clock > STRIKES[1] + 6.0: print("DEMO FAIL ch4: she is not down t=%.1f" % clock); demo_step = 9
				elif (-cam.global_basis.z).angle_to(_nhead() - cam.global_position) < 0.03: swing_t = 0.0; swing_hit = false
			if after_said == 3 and rec_t < 0.0: _record(); demo_step = 5

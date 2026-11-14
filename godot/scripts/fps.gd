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
const Sound = preload("res://scripts/sound.gd")
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
const TAPE_TAKE := 45.6                          # on the tape, the tripod leaves its place (Mio takes it up) after the grab
const GRAB_AT := 44.0                             # she falls against Mio and catches her sleeve (ch4.txt ＞grab; the tape: 40.0, 「ひとりじゃ、……むりだった」)
const STRIKES := [50.0, 51.2]                     # the canonical blows (the tape: 46.0 and 47.2)
const QUIET_AT := 70.0                            # nothing has struck her by now: a short black, and Mio says it anyway (ch4.txt 【四.殴らなかった】)

var tape := false              # 第11章: the same night, nobody at the controls (tape.gd)
var LINES := []                # [t, kind, ...] from 【四.流れ】 / 【テープ.流れ】
var li := 0
var clock := 0.0               # the night's clock (seconds after the card)
var card4: Control
var left := false
var hit_base := Transform3D()
var aim_n := 0
var still_n := 0
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
var quiet_t := -1.0            # seconds since the night went black without a blow
var black_layer: CanvasLayer
var black: ColorRect
var door_t := -1.0
var door_light: SpotLight3D
var told_tripod := false
var demo4 := false
var demo_step := 0

static func load_story(file: String):
	D.load_all()
	if file in D.FILES or D.blocks.has("@" + file): return
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

# the keys along the top (main.gd makes the line after the chapter's script is in)
func _foot(text: String):
	if main.foot: main.foot.text = T(text)

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
	var bl := CanvasLayer.new(); bl.layer = 22; add_child(bl); bl.add_child(black); black_layer = bl
	player.global_position = gp(MIO_AT[0], MIO_AT[1], 0.0)
	player.yaw = 0.0; player.pitch = deg_to_rad(-4.0)     # south (Godot -z), down the hall to the front door
	_foot.call_deferred("ＷＡＳＤ 歩く　マウス 見る　Ｅ 手に取る　左クリック 振る　　Ｆ１２ 画面の保存　Ｅｓｃ マウス解放")
	for a in OS.get_cmdline_user_args():
		if a == "--demo": demo4 = true
		if a == "--d4quiet": set_meta("quiet", true)   # the unattended run never takes the tripod up (the no-blow ending)
		if a.begins_with("--d4mio="): var xy := a.substr(8).split(","); player.global_position = gp(float(xy[0]), float(xy[1]), 0.0)   # check stills: where she stands
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
	if "--d4bones" in OS.get_cmdline_user_args():
		for i in nsk.get_bone_count(): print("BONE %d %s parent=%d rest=%s" % [i, nsk.get_bone_name(i), nsk.get_bone_parent(i), nsk.get_bone_global_rest(i).origin])
		for mi in nat.find_children("*", "MeshInstance3D", true, false): print("MESH %s xf=%s surf=%d aabb=%s" % [mi.name, (mi as MeshInstance3D).global_transform, (mi as MeshInstance3D).mesh.get_surface_count(), (mi as MeshInstance3D).get_aabb()])
		print("SK ", nsk.global_transform, " rig ", nrig.name)
	for ba in nsk.find_children("nphone*", "BoneAttachment3D", true, false): (ba as Node3D).visible = false   # no phone: its battery went hours ago
	if not "--d4noblood" in OS.get_cmdline_user_args(): _blood()
	_lookers()
	hold = Hold.new(); nsk.add_child(hold)
	nrig.global_transform = Transform3D(Basis(Vector3.UP, 0.0), gp(NPATH[0][0], NPATH[0][1], NPATH[0][2]))
	nat.visible = false
	# the tripod and the camcorder on it: lifted out of the house (their vertices are in the house's own frame) onto a
	# node at their feet, and stood by the newel
	var parts: Array = []
	for mi in main.S.env_node.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if nm.begins_with("vcam_") or nm == "lcd" or nm.begins_with("lcd_") or nm.begins_with("recled"): (mi as Node3D).visible = false; continue   # 2026-11-13 夜: Kiryu took the big camera out at 2:00; the tripod stands bare
		if nm.begins_with("tpd_"): parts.append(mi)
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
	if main.lights.has("rec_light"): (main.lights.rec_light as Light3D).visible = false   # the camcorder is not here (2026-11-13 夜)
	_weapon_rest()
	# 2026-11-13 (ユーザー「三脚の通り抜け、直したい」): standing, it is a thing she bumps into, until she takes it
	tripod_col = StaticBody3D.new(); tripod_col.name = "tripod_col"
	var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 0.3; cy.height = maxf(weapon_h, 1.2)
	cs.shape = cy; cs.position = Vector3(0.0, cy.height * 0.5, 0.0); tripod_col.add_child(cs)
	main.add_child(tripod_col); tripod_col.global_position = weapon.global_position
	# the storm's light in the doorway when the door is open: she is a shape against it before she is anyone
	door_light = SpotLight3D.new(); door_light.light_color = Color(0.62, 0.74, 1.0); door_light.light_energy = 0.0
	door_light.spot_range = 9.0; door_light.spot_angle = 26.0; door_light.spot_angle_attenuation = 1.4; door_light.spot_attenuation = 0.7
	door_light.shadow_enabled = false; door_light.light_volumetric_fog_energy = 0.6; door_light.light_specular = 0.15
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
	lantern = OmniLight3D.new(); lantern.light_color = Color(1.0, 0.74, 0.50); lantern.light_energy = 0.30
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--d4lantern="): lantern.light_energy = float(a.substr(12))
		if a == "--d4lnoshadow": set_meta("lnosh", true)
	lantern.omni_range = 5.0; lantern.omni_attenuation = 1.3; lantern.shadow_enabled = true
	lantern.light_volumetric_fog_energy = 0.2; lantern.light_specular = 0.2
	# 2026-11-13 (ユーザー「四章、すごいカクつく」): its shadow (Mio's, down the hall) was a soft cube shadow, six renders of the
	# house each frame with a soft-shadow search. Two halves (dual paraboloid) and a plain blur instead.
	lantern.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID; lantern.light_size = 0.0; lantern.shadow_blur = 2.0
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

# Blood, from a wound at the left of her hairline: down the temple and the cheek, into the collar, soaked through the
# sweater's left shoulder and run down its front. It left her an hour ago on the road; it is dark and half dry, and what
# the lantern finds of it is its wet shine. (A Decal does not draw on her here; this is an overlay on her own meshes,
# painted in her rest pose's coordinates, carried by the head bone and the chest bone.)
const BLOOD_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
uniform mat4 inv;            // world -> her rest pose (x her left, y up, z forward; metres), by this part's bone
uniform int part = 0;        // 0 the head, 1 the body
uniform float dbg = 0.0;
varying vec3 rp;
float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1,0,0)), f.x), mix(h3(i + vec3(0,1,0)), h3(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(h3(i + vec3(0,0,1)), h3(i + vec3(1,0,1)), f.x), mix(h3(i + vec3(0,1,1)), h3(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float cap(vec3 p, vec3 a, vec3 b, float r) { vec3 pa = p - a; vec3 ba = b - a; float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0); return 1.0 - length(pa - ba * h) / r; }
float ell(vec3 p, vec3 c, vec3 r) { return 1.0 - length((p - c) / r); }
void vertex() { rp = (inv * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = vn(rp * 55.0) * 0.6 + vn(rp * 140.0) * 0.4;
	float m = -1.0;
	if (part == 0) {
		m = max(m, ell(rp, vec3(0.062, 1.435, 0.075), vec3(0.055, 0.045, 0.06)));                       // the wound, in the hair
		m = max(m, cap(rp + vec3(0.006 * sin(rp.y * 60.0), 0.0, 0.0), vec3(0.068, 1.42, 0.09), vec3(0.058, 1.27, 0.07), 0.024));   // the run down the temple and the cheek
		m = max(m, cap(rp, vec3(0.04, 1.40, 0.10), vec3(0.032, 1.33, 0.11), 0.012));                       // a second, by the eye
		m = max(m, ell(rp, vec3(0.05, 1.24, 0.05), vec3(0.05, 0.05, 0.06)));                              // under the jaw
	} else {
		m = max(m, ell(rp, vec3(0.085, 1.14, 0.04), vec3(0.12, 0.085, 0.13)));                            // the collar and the shoulder, soaked
		m = max(m, cap(rp + vec3(0.008 * sin(rp.y * 45.0), 0.0, 0.0), vec3(0.075, 1.12, 0.09), vec3(0.06, 0.90, 0.10), 0.034));   // down the front
		m = max(m, cap(rp, vec3(0.13, 1.10, 0.05), vec3(0.17, 0.95, 0.04), 0.03));                         // down the sleeve
	}
	float a = smoothstep(0.0, 0.22, m + (n - 0.5) * 0.5);
	if (dbg > 0.5) { ALBEDO = vec3(0.0, 1.0, 0.0); EMISSION = vec3(0.0, 1.0, 0.0); ALPHA = a; }
	else {
		float wet = smoothstep(0.25, 0.6, m + (n - 0.5) * 0.3);
		ALBEDO = mix(vec3(0.10, 0.012, 0.008), vec3(0.17, 0.008, 0.008), wet);
		ROUGHNESS = mix(0.6, 0.16, wet); SPECULAR = 0.75; METALLIC = 0.0;
		ALPHA = a * 0.94;
	}
}
"""
var blood_mats: Array = []      # [material, bone]
func _blood():
	var sh := Shader.new(); sh.code = BLOOD_SHADER
	for mi in nat.find_children("natsuki_*", "MeshInstance3D", true, false):
		var m := ShaderMaterial.new(); m.shader = sh
		var is_head := String(mi.name).contains("head")
		m.set_shader_parameter("part", 0 if is_head else 1)
		m.set_shader_parameter("dbg", 1.0 if "--d4bloodgreen" in OS.get_cmdline_user_args() else 0.0)
		(mi as MeshInstance3D).material_overlay = m
		(mi as MeshInstance3D).extra_cull_margin = 3.0      # she is still drawn when she lies where her standing box is not
		blood_mats.append([m, nsk.find_bone("head" if is_head else "spine_03")])
	_blood_tick()

# What she leaves on the floor: it is still coming, slowly. In the dark of the hall this is what says so.
var drop_mat: StandardMaterial3D
var drop_rng := RandomNumberGenerator.new()
var drop_d := 0.0
var drop_last := Vector3.INF
func _drop(at: Vector3, yaw: float):
	if drop_mat == null:
		drop_mat = StandardMaterial3D.new(); drop_mat.albedo_color = Color(0.20, 0.008, 0.008); drop_mat.roughness = 0.12; drop_mat.metallic_specular = 0.8
		drop_rng.seed = 331
	var left := Basis(Vector3.UP, yaw) * Vector3(1, 0, 0)
	for i in (1 if drop_rng.randf() < 0.6 else 3):
		var mi := MeshInstance3D.new(); var cm := CylinderMesh.new()
		var r := drop_rng.randf_range(0.009, 0.026) * (1.0 if i == 0 else 0.45)
		cm.top_radius = r; cm.bottom_radius = r; cm.height = 0.003; cm.radial_segments = 10; cm.rings = 1
		mi.mesh = cm; mi.material_override = drop_mat; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		main.add_child(mi)
		mi.global_position = at + left * (0.07 + drop_rng.randf_range(-0.05, 0.07)) + Basis(Vector3.UP, yaw) * Vector3(0, 0.003, drop_rng.randf_range(-0.07, 0.07))
		mi.scale = Vector3(1.0, 1.0, drop_rng.randf_range(1.0, 1.5)); mi.rotation.y = yaw

func _drops_walk(p: Vector3, yaw: float):
	if drop_last == Vector3.INF: drop_last = p; return
	drop_d += Vector2(p.x - drop_last.x, p.z - drop_last.z).length(); drop_last = p
	if drop_d > 0.30: drop_d = -drop_rng.randf_range(0.0, 0.22); _drop(p, yaw)

# check stills: the trail she would have left by the path's point j
func _drops_upto(j: int):
	for i in range(j):
		var a := gp(NPATH[i][0], NPATH[i][1], NPATH[i][2]); var b := gp(NPATH[i + 1][0], NPATH[i + 1][1], NPATH[i + 1][2])
		var n := int(a.distance_to(b) / 0.06)
		for k in n:
			var p := a.lerp(b, float(k) / float(n)); if k > n / 2: p.y = b.y
			_drops_walk(p, atan2(b.x - a.x, b.z - a.z))

func _blood_tick():
	for bm in blood_mats:
		var bi: int = bm[1]
		var carry: Transform3D = nsk.global_transform * nsk.get_bone_global_pose(bi) * nsk.get_bone_global_rest(bi).affine_inverse()
		(bm[0] as ShaderMaterial).set_shader_parameter("inv", Projection(carry.affine_inverse()))

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
	_grab_mio(dt)
	_swing(dt)
	_hud_tick(dt)
	_after(dt)
	_quiet(dt)
	if demo4: _demo4(dt)
	if still_n > 0:
		still_n -= 1
		if still_n == 0:
			_blow(true)
			if has_meta("reel_at"): reel_t = float(get_meta("reel_at"))
			else: reel_t = 1.2; _night(0.0); _blow(true); fall_t = float(get_meta("fall_at"))
			set_meta("freeze", true); _night(0.0)
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
		"grab":
			if nstate in ["stand", "walk"]: _grab_start()

# the night itself: the door, the one who comes in
func _night(dt: float):
	if door_t >= 0.0 and main.door_pivot:
		door_t += dt
		var k := clampf(door_t / 4.5, 0.0, 1.0); k = k * k * (3.0 - 2.0 * k)
		main.door_pivot.rotation.y = float(main.S.get("door_rot", 0.0)) + deg_to_rad(DOOR_OPEN) * k
		door_light.light_energy = 2.2 * k
		door_light.shadow_enabled = k > 0.01   # its shadow costs a render of the house: only once the door opens
	if nstate == "out": return
	if has_meta("freeze"): dt = 0.0
	_blood_tick()
	if looks.has("natsuki"):
		var lm: Look = looks.natsuki
		lm.target = _mio_eye(); lm.want = 1.0 if nstate in ["walk", "stand", "grab"] else 0.0
	_wobble(dt)
	match nstate:
		"grab": _grab_nat(dt)
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
			_drops_walk(p, yaw)
		"reel":
			# the first blow, on the left of her head: the head goes over and down, her knees give a little, she goes
			# back and to her right a step and a half, her left hand comes up to where it landed; she stays on her feet
			reel_t += dt
			var snap := 1.0 - pow(1.0 - clampf(reel_t / 0.14, 0.0, 1.0), 2.0)          # the head, at once
			var k2 := clampf(reel_t / 0.55, 0.0, 1.0); k2 = 1.0 - pow(1.0 - k2, 3.0)   # the body after it
			var rec := 1.0 - 0.45 * smoothstep(0.5, 1.3, reel_t)                      # and she half straightens
			var kn := 0.38 * k2 * rec
			_pose({"head": [0.30 * snap * rec, 0.0, 0.42 * snap * rec], "neck_01": [0.20 * snap * rec, 0.0, 0.26 * snap * rec],
				"spine_03": [0.20 * k2 * rec, 0.0, 0.12 * k2], "spine_02": [0.14 * k2 * rec, 0.0, 0.08 * k2], "spine_01": [0.08 * k2, 0.0, 0.0],
				"thigh_l": [-kn, 0.0, 0.0], "calf_l": [2.0 * kn, 0.0, 0.0], "foot_l": [-kn, 0.0, 0.0],
				"thigh_r": [-kn * 0.8, 0.0, 0.0], "calf_r": [1.6 * kn, 0.0, 0.0], "foot_r": [-kn * 0.8, 0.0, 0.0],
				"upperarm_l": [0.0, 0.0, 0.0], "lowerarm_l": [0.0, 0.0, 0.0],        # the hand stays on the wound
				"upperarm_r": [0.0, 0.0, -0.22 * k2]})
			var back := nbase.basis * Vector3(0, 0, -1); var right := nbase.basis * Vector3(-1, 0, 0)
			var drop := 0.33 * (1.0 - cos(kn)) + 0.33 * (1.0 - cos(kn))
			nrig.global_transform = Transform3D(nbase.basis * Basis(Vector3.BACK, 0.05 * k2 + 0.02 * sin(reel_t * 2.3)), nbase.origin + back * 0.24 * k2 + right * 0.10 * k2 - Vector3(0, drop, 0))
		"down":
			# the second: her legs go out from under her. She comes down onto her knees and then forward, onto the
			# floor at Mio's feet, a little onto her right side; nothing of her tries to break the fall
			fall_t += dt
			var snap2 := 1.0 - pow(1.0 - clampf(fall_t / 0.12, 0.0, 1.0), 2.0)
			var kneel := clampf(fall_t / 0.42, 0.0, 1.0); kneel = kneel * kneel                         # falling, not lowering herself
			var over := clampf((fall_t - 0.36) / 0.62, 0.0, 1.0); over = over * over                      # from her knees, forward
			var settle := smoothstep(0.98, 1.5, fall_t)
			var limp := smoothstep(0.0, 0.4, fall_t)
			var th := 0.45 * kneel - 0.40 * over; var cf := 1.95 * kneel - 1.30 * over
			var curl := kneel * (1.0 - over)
			for nm in arm_held: pose0[nm][0] = (arm_held[nm] as Quaternion).slerp(arm_anim[nm], 0.8 * limp)     # the hand comes off the wound
			_pose({"head": [0.40 * snap2 * (1.0 - over) - 0.25 * over, -0.75 * over, 0.30 * snap2 * (1.0 - over)], "neck_01": [0.22 * snap2 * (1.0 - over), -0.3 * over, 0.0],
				"spine_03": [0.32 * curl - 0.06 * over, 0.0, 0.10 * kneel], "spine_02": [0.26 * curl, 0.0, 0.06 * kneel], "spine_01": [0.18 * curl, 0.0, 0.0],
				"thigh_l": [-th, 0.0, 0.0], "calf_l": [cf, 0.0, 0.0], "foot_l": [0.7 * kneel, 0.0, 0.0],
				"thigh_r": [-th + 0.12 * over, 0.0, 0.0], "calf_r": [cf + 0.25 * over, 0.0, 0.0], "foot_r": [0.7 * kneel, 0.0, 0.0],
				"upperarm_l": [-0.75 * over, 0.0, 0.25 * limp], "lowerarm_l": [-0.3 * limp, 0.0, 0.0],
				"upperarm_r": [-0.30 * limp + 0.5 * over, 0.0, -0.30 * limp], "lowerarm_r": [-0.35 * limp, 0.0, 0.0]}, reel_pose, 1.0 - 0.6 * over)
			var b0 := nbase.basis
			var thk: float = th + float(reel_pose.get("thigh_l", [0.0])[0]) * -1.0 * (1.0 - 0.6 * over)   # her thigh's whole angle, the first blow's bend with it
			var cfk: float = cf + float(reel_pose.get("calf_l", [0.0])[0]) * (1.0 - 0.6 * over)
			var hip := 0.33 * (1.0 - cos(thk)) + 0.33 * (1.0 - cos(cfk - thk))                           # how far the knees' giving lets her hips down
			var right2 := b0 * Vector3(-1, 0, 0); var back2 := b0 * Vector3(0, 0, -1)
			var feet := nbase.origin + back2 * 0.24 + right2 * 0.10
			var rb := b0 * Basis(Vector3.BACK, 0.04 + 0.22 * over) * Basis(Vector3.RIGHT, 1.40 * over + 0.03 * settle)
			var knee_l := Vector3(0.0, 0.74 - 0.33 * cos(thk), 0.33 * sin(thk))                           # her knees, in her own frame
			var knee_w := feet + b0 * Vector3(0.0, 0.0, 0.33 * sin(0.45)) + Vector3(0, 0.045, 0)          # and where they came down
			var org_a := feet - Vector3(0, hip, 0)                                                         # on her feet
			var org_b := knee_w - rb * knee_l                                                             # on her knees
			nrig.global_transform = Transform3D(rb, org_a.lerp(org_b, smoothstep(0.30, 0.42, fall_t)))

# Her left hand, held to the wound all the way in: in the dark of the hall it is the first thing that says she is hurt.
# Over the walk's clip, as a modifier (the clip's own arm comes back when w is 0).
class Hold extends SkeletonModifier3D:
	var w := 1.0
	var last := {}           # bone -> the rotation it was given this frame
	const WRIST := Vector3(0.112, 1.385, 0.075)     # where her wrist is when the palm is on the wound (rest pose: x her left, y up, z forward)
	const POLE := Vector3(0.75, -0.45, 0.50)        # where the elbow hangs
	func _process_modification():
		var sk := get_skeleton()
		if sk == null or w <= 0.001: return
		var ua := sk.find_bone("upperarm_l"); var la := sk.find_bone("lowerarm_l"); var ha := sk.find_bone("hand_l"); var hd := sk.find_bone("head")
		if ua < 0 or la < 0 or ha < 0 or hd < 0: return
		var t: Vector3 = (sk.get_bone_global_pose(hd) * sk.get_bone_global_rest(hd).affine_inverse()) * WRIST
		var sp := sk.get_bone_global_pose(ua).origin
		var l1 := sp.distance_to(sk.get_bone_global_pose(la).origin); var l2 := sk.get_bone_global_pose(la).origin.distance_to(sk.get_bone_global_pose(ha).origin)
		var n := t - sp; var d := minf(n.length(), l1 + l2 - 0.005); n = n.normalized()
		var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
		var pole := (POLE - n * POLE.dot(n)).normalized()
		var elbow := sp + n * a + pole * sqrt(maxf(l1 * l1 - a * a, 0.0))
		var g1 := sk.get_bone_global_pose(ua)
		var q1 := Quaternion((sk.get_bone_global_pose(la).origin - sp).normalized(), (elbow - sp).normalized())
		sk.set_bone_global_pose(ua, Transform3D(Basis(Quaternion().slerp(q1, w)) * g1.basis, g1.origin))
		var g2 := sk.get_bone_global_pose(la)
		var q2 := Quaternion((sk.get_bone_global_pose(ha).origin - g2.origin).normalized(), (sp + n * d - g2.origin).normalized())
		sk.set_bone_global_pose(la, Transform3D(Basis(Quaternion().slerp(q2, w)) * g2.basis, g2.origin))
		last = {"upperarm_l": sk.get_bone_pose_rotation(ua), "lowerarm_l": sk.get_bone_pose_rotation(la)}
var hold: Hold

# The blows are not in her walk's clips. From the pose she had when the blow landed, each bone is turned about her own
# axes (x her left: + bows forward; y up: + turns to her left; z forward: + leans to her right), carried by its parent.
var arm_anim := {}; var arm_held := {}
var pose0 := {}          # bone -> [its rotation, its parent's rotation in the skeleton's frame], as the blow found her
var reel_pose := {}      # what the first blow had made of her when the second landed
var last_pose := {}
func _capture():
	pose0 = {}
	for i in nsk.get_bone_count():
		var par := nsk.get_bone_parent(i)
		pose0[nsk.get_bone_name(i)] = [nsk.get_bone_pose_rotation(i), nsk.get_bone_global_pose(par).basis.orthonormalized() if par >= 0 else Basis()]
	if looks.has("natsuki"): (looks.natsuki as Look).w = 0.0; (looks.natsuki as Look).want = 0.0
	arm_anim = {}
	for nm in hold.last:   # her hand stays where it was, on the wound: from here the arm is carried by the blow's pose
		arm_anim[nm] = pose0[nm][0]; pose0[nm][0] = hold.last[nm]
	arm_held = hold.last.duplicate()
	hold.w = 0.0

func _pose(d: Dictionary, under := {}, uw := 1.0):
	last_pose = d
	for nm in pose0:
		var e: Array = [0.0, 0.0, 0.0]
		if d.has(nm): e = d[nm]
		if under.has(nm): e = [e[0] + under[nm][0] * uw, e[1] + under[nm][1] * uw, e[2] + under[nm][2] * uw]
		elif not d.has(nm): continue
		var bi := nsk.find_bone(nm)
		var pg: Basis = pose0[nm][1]
		var r := Basis(Vector3.UP, e[1]) * Basis(Vector3.BACK, e[2]) * Basis(Vector3.RIGHT, e[0])
		nsk.set_bone_pose_rotation(bi, (pg.inverse() * r * pg).get_rotation_quaternion() * (pose0[nm][0] as Quaternion))

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
	if holding or after_t >= 0.0 or quiet_t >= 0.0: return
	var cam: Camera3D = player.get_node("Head/Camera")
	var at := weapon.global_position + Vector3(0, 1.0, 0)
	var near: bool = (at - cam.global_position).length() < 1.9 and (-cam.global_basis.z).angle_to(at - cam.global_position) < deg_to_rad(22.0)
	note_lb.text = T("［Ｅ　三脚］") if near else ""
	# she stands before her and Mio has taken nothing up: where the tripod is, once
	if not told_tripod and nstate == "stand" and ni >= NPATH.size() and clock > 46.0:
		told_tripod = true
		var e: Dictionary = B("四.まだ")[0]; _say(e.who, e.text, true)

var tripod_col: StaticBody3D
func _take():
	holding = true
	if is_instance_valid(tripod_col): tripod_col.queue_free()
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
	if head_hits == 1: hit_base = Transform3D(Basis(Vector3.UP, nrig.global_rotation.y), nrig.global_position)
	nbase = hit_base
	if head_hits == 1:
		_capture()
		nstate = "reel"; reel_t = 0.0
	else:
		reel_pose = last_pose.duplicate(true)
		nbase = hit_base
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
	# 2026-11-13 夜（カメラは2台）: she says nothing and films nothing. The HUD is gone; silence, then black, then the tape (第11章)
	if after_t > 6.0 and rec_t < 0.0: rec_t = 0.0
	if rec_t >= 0.0:
		rec_t += dt
		black.color.a = clampf(rec_t / 2.5, 0.0, 1.0)
		if rec_t > 4.0 and not left:      # the recording has gone to black: months later, the tape (第11章)
			left = true
			if demo4: print("DEMO ch4 t=%.1f fails=%d" % [clock, DEMO_FAILS])
			if main.play == "ch4": main.to_chapter("ch11")
			elif demo4 and "--demoquit" in OS.get_cmdline_user_args(): print("DEMO DONE ch4 t=%.1f" % clock); get_tree().quit()

# ブラッシュアップ案 2026-11-13: she was never struck. The night goes black for a moment, and the testimony goes on flat,
# as if she had been: whatever the player did, Mio says this. Then the tape (第11章), which shows what happened.
func _quiet(dt: float):
	if after_t >= 0.0: return
	if quiet_t < 0.0:
		if clock < QUIET_AT or swing_t >= 0.0 or nstate in ["reel", "down"]: return
		quiet_t = 0.0
		player.move_enabled = false; player.look_enabled = false
		note_lb.text = ""; hud.visible = false
		_clear_page(); cur = {}
		black_layer.layer = 12              # under her words (story.gd: layer 13)
		print("STORY ch4 quiet t=%.1f" % clock)
		return
	quiet_t += dt
	black.color.a = clampf(quiet_t / 0.5, 0.0, 1.0)
	if quiet_t >= 1.5 and not cur.has("text"):
		var e: Dictionary = B("四.殴らなかった")[0]; _say(e.who, e.text, true)
	var said: float = 1.5 + float(String(cur.get("text", "")).length()) / 20.0
	if quiet_t > said + 3.0 and not left:
		left = true
		if demo4: print("DEMO ch4 quiet t=%.1f fails=%d" % [clock, DEMO_FAILS])
		if main.play == "ch4": main.to_chapter("ch11")
		elif demo4 and "--demoquit" in OS.get_cmdline_user_args(): print("DEMO DONE ch4 t=%.1f" % clock); get_tree().quit()

func _unhandled_input(e):
	if tape or (card4 and card4.visible) or quiet_t >= 0.0: return
	var key_e: bool = e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E
	var click: bool = e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if not holding and after_t < 0.0:
		if (key_e or click) and note_lb.text != "": _take()
		return
	if after_t >= 0.0:
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
		_drops_upto(j)
		nap.play("walk/walk"); nap.seek(0.3, true); nap.pause()
		nstate = "stand"
		print("JUMP j=%d at=%s rig=%s player=%s" % [j, at, nrig.global_position, player.global_position])
	clock = t
	if "--d4aim" in OS.get_cmdline_user_args(): aim_n = 4
	for a in OS.get_cmdline_user_args():       # check stills: her, this long after the first blow / the second (two frames on, when her hand is up)
		if a.begins_with("--d4reel="): set_meta("reel_at", float(a.substr(9))); still_n = 3
		if a.begins_with("--d4fall="): set_meta("fall_at", float(a.substr(9))); still_n = 3

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
			if clock > GRAB_AT + 1.4 and not has_meta("quiet"): demo_step = 1   # after she has caught Mio's sleeve and Mio's hand has hit the tripod
		1:
			turn.call(weapon.global_position + Vector3(0, 1.0, 0), 3.0)
			if note_lb.text != "": _take(); demo_step = 2
			elif clock > GRAB_AT + 5.0: print("DEMO FAIL ch4: cannot take the tripod t=%.1f" % clock); DEMO_FAILS += 1; demo_step = 9
		2:
			if nstate != "out": turn.call(_nhead(), 2.5)
			if clock >= STRIKES[0] and swing_t < 0.0: swing_t = 0.0; swing_hit = false; demo_step = 3
		3:
			turn.call(_nhead(), 6.0)
			if clock >= STRIKES[1] and swing_t < 0.0: swing_t = 0.0; swing_hit = false; demo_step = 4
		4:
			if nstate != "down" and swing_t < 0.0:
				turn.call(_nhead(), 6.0)
				if clock > STRIKES[1] + 6.0: print("DEMO FAIL ch4: she is not down t=%.1f" % clock); DEMO_FAILS += 1; demo_step = 9
				elif (-cam.global_basis.z).angle_to(_nhead() - cam.global_position) < 0.03: swing_t = 0.0; swing_hit = false
			if nstate == "down": turn.call(_nhead().lerp(nrig.global_position, 0.4), 1.6)      # and she looks at what is at her feet
			if rec_t >= 0.0: demo_step = 5

# ================================================================ the motive (決定事項 2026-11-14 朝、ユーザー「自然に殴る動機を与えたい」)
# Her foot gives; she falls against Mio and her right hand catches Mio's left sleeve. Mio is pulled, staggers, and her
# free hand, thrown out to stop herself, comes down on the tripod by the newel: it rocks. That is where the tripod comes
# into her head. The same seconds in 第4章 and on the tape (第11章); taking it and swinging it stay the player's.
var grab_t := -1.0
var grab_p0 := Vector3.ZERO
var grab_to := Vector3.ZERO
var grab_yaw := 0.0
var reach: Reach
var mio_g := {}                 # 第4章: Mio's side of it {t, pull, to, hit, yaw0, pitch0}
var wob_t := -1.0

func _mio_feet() -> Vector3:
	return gp(TAPE_MIO[0], TAPE_MIO[1], 0.0) if tape else player.global_position

func _grab_start():
	grab_t = 0.0; nstate = "grab"
	if nwalk: nwalk = false
	nap.pause()
	var p := nrig.global_position; var m := _mio_feet()
	var d := m - p; d.y = 0.0
	var L := maxf(d.length(), 0.01); d /= L
	# a lurch, not a walk: a third of a metre at most (on the tape she stays in the frame; only her arm goes out of it, to Mio)
	grab_p0 = p; grab_to = p + d * clampf(L - 0.62, 0.0, 0.22 if tape else 0.35); grab_to.y = p.y
	grab_yaw = atan2(d.x, d.z)
	if reach == null: reach = Reach.new(); nsk.add_child(reach)
	reach.w = 0.0
	print("STORY ch4 grab t=%.1f dist=%.2f" % [clock, L])
	if tape: return
	# Mio: where the stumble takes her. Toward the tripod if it is near enough to be what her hand finds, else a step back
	var tp: Vector3 = weapon.global_position; tp.y = player.global_position.y
	var mp: Vector3 = player.global_position
	mio_g = {"t": 0.0, "pull": d * -1.0, "hit": false, "yaw0": player.yaw, "pitch0": player.pitch}
	if not holding and weapon.get_parent() == main and (tp - mp).length() < 1.7:
		var v: Vector3 = tp - mp; var vl: float = v.length()
		mio_g["to"] = v / maxf(vl, 0.01) * maxf(vl - 0.55, 0.0)   # her shoulder half a metre short: her hand on it
		mio_g["tripod"] = true
	else:
		mio_g["to"] = d * 0.22; mio_g["tripod"] = false

func _sleeve() -> Vector3:
	# Mio's left forearm: below her eye, to her left, a little toward Natsuki
	var e := _mio_eye()
	var f: Vector3
	if tape: f = (nrig.global_position - gp(TAPE_MIO[0], TAPE_MIO[1], 0.0)); f.y = 0.0; f = f.normalized()
	else: f = Basis(Vector3.UP, player.yaw) * Vector3(0, 0, -1)
	var left := Vector3.UP.cross(f).normalized()
	return e + Vector3.DOWN * 0.55 + left * 0.22 + f * 0.18

func _grab_nat(dt: float):
	grab_t += dt
	var g := grab_t
	var go := smoothstep(0.0, 0.45, g)                    # the fall forward, all at once
	var lean := 0.34 * go - 0.22 * smoothstep(1.4, 2.2, g)
	var sink := 0.07 * smoothstep(0.3, 0.8, g) * (1.0 - smoothstep(1.4, 2.2, g))
	var p := grab_p0.lerp(grab_to, go * go) - Vector3(0, sink, 0)
	var yaw := lerp_angle(nrig.global_rotation.y, grab_yaw, minf(1.0, dt * 8.0))
	nrig.global_transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lean), p)
	reach.target = _sleeve()
	reach.w = smoothstep(0.1, 0.4, g) * (1.0 - smoothstep(1.4, 2.0, g))
	if g >= 2.3:
		reach.w = 0.0; nstate = "stand"; ni = NPATH.size(); grab_t = -1.0
		nrig.global_transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, 0.12), p)

func _grab_mio(dt: float):
	if mio_g.is_empty(): return
	mio_g.t += dt
	var g: float = mio_g.t
	if g < 0.4: return                                     # she has not reached her yet
	player.move_enabled = false; player.look_enabled = false
	var prev: float = mio_g.get("k", 0.0)
	# pulled toward her (0.4-0.6), then the stumble (0.6-1.25)
	var pull: Vector3 = -mio_g.pull * 0.16 * smoothstep(0.4, 0.6, g)
	var st: Vector3 = mio_g.to * smoothstep(0.6, 1.25, g)
	var now := pull + st
	var was: Vector3 = mio_g.get("at", Vector3.ZERO)
	player.move_and_collide(now - was)
	mio_g["at"] = now
	# the view: down to her hand on the sleeve (and her face over it), then, as she staggers, to what her hand hit
	var cam: Camera3D = player.get_node("Head/Camera")
	var ang = func(at: Vector3) -> Vector2:
		var d: Vector3 = at - cam.global_position
		return Vector2(atan2(-d.x, -d.z), asin(clampf(d.normalized().y, -1.0, 1.0)))
	var s1: Vector2 = ang.call(_sleeve().lerp(_nhead(), 0.45))
	var wa := smoothstep(0.4, 0.62, g) * (1.0 - (smoothstep(0.85, 1.3, g) if mio_g.tripod else smoothstep(1.2, 1.8, g)))
	var yaw: float = lerp_angle(float(mio_g.yaw0), s1.x, wa)
	var pit: float = lerpf(float(mio_g.pitch0), s1.y, wa)
	if mio_g.tripod:
		var s2: Vector2 = ang.call(weapon.global_position + Vector3(0, 0.75, 0))
		var wb := 0.85 * smoothstep(0.85, 1.3, g)
		yaw = lerp_angle(yaw, s2.x, wb); pit = lerpf(pit, s2.y, wb)
		if not mio_g.hit and g >= 1.2:
			mio_g.hit = true; wob_t = 0.0
			Sound.one(self, "knock_weak", -6.0, weapon.global_position + Vector3(0, 0.9, 0))
			print("STORY ch4 tripod hit t=%.1f" % clock)
	if g > 0.5 and not mio_g.has("step"): mio_g["step"] = 1; Sound.one(self, "step3", -4.0)
	player.yaw = yaw; player.pitch = pit
	if g >= 1.9:
		player.move_enabled = true; player.look_enabled = true
		mio_g = {}

# the tripod, hit and rocking on its feet (only while it stands)
func _wobble(dt: float):
	if tape and clock >= GRAB_AT + 1.0 and clock < GRAB_AT + 1.1 and wob_t < 0.0: wob_t = 0.0   # on the tape: her hand, out of the frame
	if wob_t < 0.0 or weapon.get_parent() != main or (tape and clock >= TAPE_TAKE): return
	wob_t += dt
	var a := 0.09 * exp(-wob_t * 3.2) * sin(wob_t * 17.0)
	_weapon_rest()
	weapon.global_transform = weapon.global_transform * Transform3D(Basis(Vector3(1, 0, 0.4).normalized(), a), Vector3.ZERO)
	if wob_t > 2.0: wob_t = -1.0; _weapon_rest()

# Natsuki's right hand to Mio's sleeve (two-bone reach, as Hold; w 0 leaves the clip's arm)
class Reach extends SkeletonModifier3D:
	var w := 0.0
	var target := Vector3.ZERO      # world
	const POLE := Vector3(-0.6, -0.5, -0.3)   # the elbow out and down (rest frame: x her left)
	func _process_modification():
		var sk := get_skeleton()
		if sk == null or w <= 0.001: return
		var ua := sk.find_bone("upperarm_r"); var la := sk.find_bone("lowerarm_r"); var ha := sk.find_bone("hand_r")
		if ua < 0 or la < 0 or ha < 0: return
		var t: Vector3 = sk.global_transform.affine_inverse() * target
		var sp := sk.get_bone_global_pose(ua).origin
		var l1 := sp.distance_to(sk.get_bone_global_pose(la).origin); var l2 := sk.get_bone_global_pose(la).origin.distance_to(sk.get_bone_global_pose(ha).origin)
		var n := t - sp; var d := minf(n.length(), l1 + l2 - 0.005); n = n.normalized()
		var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
		var pole := (POLE - n * POLE.dot(n)).normalized()
		var elbow := sp + n * a + pole * sqrt(maxf(l1 * l1 - a * a, 0.0))
		var g1 := sk.get_bone_global_pose(ua)
		var q1 := Quaternion((sk.get_bone_global_pose(la).origin - sp).normalized(), (elbow - sp).normalized())
		sk.set_bone_global_pose(ua, Transform3D(Basis(Quaternion().slerp(q1, w)) * g1.basis, g1.origin))
		var g2 := sk.get_bone_global_pose(la)
		var q2 := Quaternion((sk.get_bone_global_pose(ha).origin - g2.origin).normalized(), (sp + n * d - g2.origin).normalized())
		sk.set_bone_global_pose(la, Transform3D(Basis(Quaternion().slerp(q2, w)) * g2.basis, g2.origin))

## 第2章 23:00 prototype. Builds the scene from the Blender exports (assets/*.glb, lights.json, scene.json).
## Keys: WASD/mouse walk and look, 1 one screen everywhere / 2 fine at the centre,
## C camera 12 / 18 / 12+slide / smooth, G GI, Q quality, P print on/off, Esc release mouse, F11 fullscreen.
## Unattended recording: godot --path . --write-movie out.png --fixed-fps 24 -- --record=walk
extends Node3D

var CARD_TIME := 3.2
const LOOP := 20.0
const LIGHTNING_T := 14.0

var S := {}
var riso: ShaderMaterial
var player
var t0 := 0.0
var quality_high := true
var lights := {}
var fog_vol: FogVolume
var env: Environment
var anims: Array = []
var card: Control
var record := ""
var ARGS := {}
static var PRINT_V := 2              # 1: first print, 2: second print (V switches)
static var PRINT_EXP := {"night": 1.8, "dusk": 1.3}   # the printer's exposure per scene; - and = adjust
static var SET := {}             # every setting survives N (scene switch reloads the tree)
static var SCENE := ""            # "night" (第2章 23:00) or "dusk" (第1章 夕方); N switches
var BASE := "res://assets/"
var door_pivot: Node3D

static func b2g(v) -> Vector3:
	return Vector3(v[0], v[2], -v[1])

func _ready():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--record="): record = a.substr(9)
		if a.begins_with("--pose="): ARGS["pose"] = Array(a.substr(7).split(",")).map(func(x): return float(x))
		if a.begins_with("--poses="):   # check stills: "x,z,yaw,pitch;x,z,yaw,pitch;..." held 1.5 s each, then quit
			ARGS["poses"] = Array(a.substr(8).split(";")).map(func(q): return Array(q.split(",")).map(func(x): return float(x)))
		if a.begins_with("--print="): ARGS["print"] = float(a.substr(8))
		if a == "--nocard": CARD_TIME = 0.0
		if a.begins_with("--riso="): PRINT_V = int(a.substr(7))
		if a.begins_with("--pexp="): PRINT_EXP[SCENE if SCENE != "" else "night"] = float(a.substr(7))
		if a == "--status": ARGS["status"] = true; SET["pin"] = true
		if a == "--bright": ARGS["bright"] = true
		if a == "--bake-gi": ARGS["bake"] = true
		if a.begins_with("--gi="): ARGS["gi"] = a.substr(5)
		if a.begins_with("--gie="): ARGS["gie"] = a.substr(6)
		if a.begins_with("--lme="): ARGS["lme"] = a.substr(6)
		if a.begins_with("--scene=") and SCENE == "": SCENE = a.substr(8)
	if SCENE == "": SCENE = "night"
	BASE = "res://assets/dusk/" if SCENE == "dusk" else "res://assets/"
	S = JSON.parse_string(FileAccess.get_file_as_string(BASE + "scene.json"))
	_environment()
	_load_scene(BASE + "env.glb", "env")
	for n in CHARS:
		if ResourceLoader.exists(BASE + "%s.glb" % n): _load_scene(BASE + "%s.glb" % n, n)
	door_pivot = S.env_node.find_child("door_pivot", true, false) as Node3D
	if door_pivot: S["door_rest"] = door_pivot.position; S["door_rot"] = door_pivot.rotation.y
	for mi in S.env_node.find_children("*", "MeshInstance3D", true, false):
		for pre in ["fresnel", "fres_lens", "barndoor", "yoke", "cscol", "csleg", "recled", "rain", "nphone", "kphone", "slitglass", "lcd"]:
			if String(mi.name).begins_with(pre): mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if SCENE == "dusk": TALK = {"natsuki": [[2.0, 4.6], [9.0, 10.4], [14.5, 16.8]], "kiryu": [[11.2, 12.4]]}
	_faces()
	if SCENE == "dusk": _lights_dusk()
	else: _lights()
	_gi()
	_colliders()
	_rain()
	_player()
	_print_layer()
	_card()
	_restore_settings()
	if record == "": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	t0 = Time.get_ticks_msec() / 1000.0

# ------------------------------------------------------------------ world
func _environment():
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.26, 0.32)
	env.ambient_light_energy = 0.06
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0
	env.volumetric_fog_albedo = Color(1, 1, 1)
	env.volumetric_fog_anisotropy = 0.0
	env.volumetric_fog_length = 14.0
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.4
	if SCENE == "dusk":
		env.ambient_light_color = Color(0.55, 0.42, 0.34)
		env.ambient_light_energy = 0.1
	if ARGS.has("bright"): env.ambient_light_energy = 3.0; env.volumetric_fog_enabled = false
	we.environment = env
	add_child(we)
	# the film-set haze fills the house only
	fog_vol = FogVolume.new()
	fog_vol.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fog_vol.size = Vector3(3.2, 2.65, 5.7)
	fog_vol.position = b2g([0.0, 3.45, 1.12])
	var fm := FogMaterial.new()
	fm.density = 0.05 if SCENE == "dusk" else 0.085
	fm.albedo = Color(1, 1, 1)
	fm.edge_fade = 0.05
	fog_vol.material = fm
	add_child(fog_vol)

func _load_scene(path: String, key: String):
	var ps: PackedScene = load(path)
	var inst := ps.instantiate()
	inst.name = key
	add_child(inst)
	for ap in inst.find_children("*", "AnimationPlayer", true, false):
		var names = ap.get_animation_list()
		if names.size() > 0:
			# the glb may carry every rig's action (same bone names): play this character's own, never the first by name
			var pick: String = names[0]
			for nm in names:
				if String(nm).begins_with(key + "_rig"): pick = nm
			var a: Animation = ap.get_animation(pick)
			a.loop_mode = Animation.LOOP_LINEAR
			ap.play(pick)
			anims.append(ap)
	S[key + "_node"] = inst

const CHARS := ["kiryu", "taiga", "natsuki", "makoto"]
var faces := {}   # key -> {mat, tex:{open,closed,talk}, next_blink, blink_until}
func _faces():
	for k in CHARS:
		if not S.has(k + "_node"): continue
		var head := S[k + "_node"].find_child(k + "_head", true, false) as MeshInstance3D
		if head == null: continue
		# the face is the surface whose material is named <k>_face (the head mesh also carries the hair surface)
		var si := 0
		for i in range(head.get_surface_override_material_count()):
			var mm := head.get_active_material(i)
			if mm != null and String(mm.resource_name).ends_with("_face"): si = i
		var src := head.get_active_material(si) as StandardMaterial3D
		var m := src.duplicate() as StandardMaterial3D
		head.set_surface_override_material(si, m)
		var tex := {}
		for st in ["open", "closed", "talk"]:
			var pj := "res://assets/faces/%s_%s.jpg" % [k, st]
			tex[st] = load(pj if ResourceLoader.exists(pj) else "res://assets/faces/%s_%s.png" % [k, st]) as Texture2D
		m.albedo_texture = tex.open
		faces[k] = {"mat": m, "tex": tex, "next": randf_range(1.0, 4.0), "until": 0.0, "state": "open"}

# who talks when (seconds into the 20 s loop)
var TALK := {"natsuki": [[5.7, 7.4], [11.0, 12.6]], "taiga": [[7.8, 8.6]]}

func _update_faces(t: float, lt: float):
	for k in faces:
		var f = faces[k]
		var st := "open"
		var talking := false
		if TALK.has(k):
			for span in TALK[k]:
				if lt > span[0] and lt < span[1]: talking = true
		if talking:
			# syllables: open/close at ~7 Hz with a little irregularity
			var ph := sin(t * 44.0) + 0.6 * sin(t * 27.0 + 1.3)
			if ph > 0.1: st = "talk"
		if t > f.next:
			f.until = t + 0.11
			f.next = t + randf_range(2.2, 5.5)
		if t < f.until: st = "closed"
		if st != f.state:
			f.state = st
			f.mat.albedo_texture = f.tex[st]

func _mk_spot(L: Dictionary, energy: float, angle: float, size: float, shadows := true) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.light_color = Color(L.color[0], L.color[1], L.color[2]).linear_to_srgb()
	l.light_energy = energy
	l.spot_angle = clamp(angle, 1.0, 89.0)
	l.spot_angle_attenuation = 0.6
	l.spot_range = 12.0
	l.spot_attenuation = 1.6
	l.light_size = size
	l.shadow_enabled = shadows
	l.shadow_blur = 1.0
	l.light_volumetric_fog_energy = 1.0
	add_child(l)
	l.global_position = b2g(L.pos)
	var d = b2g(L.dir)
	l.look_at(l.global_position + d, Vector3.UP if abs(d.y) < 0.95 else Vector3.FORWARD)
	return l

func _mk_omni(L: Dictionary, energy: float, rng: float, size := 0.02) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = Color(L.color[0], L.color[1], L.color[2]).linear_to_srgb()
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.6
	l.light_size = size
	l.shadow_enabled = false
	add_child(l)
	l.global_position = b2g(L.pos)
	return l

# ------------------------------------------------------------------ bounce light
# VoxelGI: the house is voxelised once (assets/gi.res, baked offline with --bake-gi); the lights stay dynamic,
# so the fresnel's flicker and the lightning bounce off the floor and the logs in real time.
# G cycles VoxelGI -> SDFGI -> none, for comparing cost and look on the player's machine.
var voxel_gi: VoxelGI
var gi_mode := 0
func _gi():
	for mi in S.env_node.find_children("*", "MeshInstance3D", true, false):
		mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		if String(mi.name).begins_with("rain") or String(mi.name).begins_with("slitglass"): mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	for k in CHARS:
		if not S.has(k + "_node"): continue
		for mi in S[k + "_node"].find_children("*", "MeshInstance3D", true, false): mi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	voxel_gi = VoxelGI.new()
	voxel_gi.size = Vector3(3.8, 3.1, 6.4)
	voxel_gi.subdiv = VoxelGI.SUBDIV_128
	add_child(voxel_gi)
	voxel_gi.global_position = b2g([0.0, 3.45, 1.1])
	if ARGS.has("bake"):
		var t := Time.get_ticks_msec()
		voxel_gi.bake(S.env_node, false)
		var data := voxel_gi.data
		data.energy = 1.0; data.propagation = 0.75; data.bias = 1.5; data.normal_bias = 0.0; data.interior = true; data.use_two_bounces = true
		ResourceSaver.save(data, BASE + "gi.res")
		print("GI BAKED in ", Time.get_ticks_msec() - t, " ms")
		get_tree().quit()
		return
	if ResourceLoader.exists(BASE + "gi.res"):
		voxel_gi.data = load(BASE + "gi.res")
		print("GI DATA ", voxel_gi.data != null)
	# art-directed bounce: the haze in the house scatters the key everywhere, so the bounce is pushed above physical
	voxel_gi.data.energy = float(ARGS.get("gie", "4.0"))
	voxel_gi.data.propagation = 0.85
	env.sdfgi_energy = float(ARGS.get("gie", "4.0"))
	for k in ["fres", "blue", "sky"]:
		if lights.has(k): lights[k].light_indirect_energy = 2.0
	_lightmap()
	_set_gi({"baked": 0, "voxel": 1, "sdfgi": 2, "none": 3}.get(ARGS.get("gi", "sdfgi"), 2))

# modes: 0 baked bounce (Blender lightmap)  1 VoxelGI  2 SDFGI  3 none
const GI_NAMES := ["焼き込み", "VoxelGI", "SDFGI", "なし"]
var lm_mats: Array = []
func _lightmap():
	if not FileAccess.file_exists(BASE + "lightmap.exr") and not ResourceLoader.exists(BASE + "lightmap.exr"): return
	var lm: Texture2D = load(BASE + "lightmap.exr")
	var sh: Shader = load("res://shaders/lightmapped.gdshader")
	var mi := S.env_node.find_child("env_static", true, false) as MeshInstance3D
	if mi == null: return
	for i in mi.mesh.get_surface_count():
		var src := mi.get_active_material(i) as StandardMaterial3D
		var m := ShaderMaterial.new(); m.shader = sh
		if src:
			m.set_shader_parameter("use_tex", src.albedo_texture != null)
			if src.albedo_texture: m.set_shader_parameter("albedo_tex", src.albedo_texture)
			m.set_shader_parameter("albedo_color", src.albedo_color)
			m.set_shader_parameter("roughness_v", src.roughness)
			m.set_shader_parameter("metallic_v", src.metallic)
			if src.emission_enabled:
				m.set_shader_parameter("emission_color", src.emission); m.set_shader_parameter("emission_energy", src.emission_energy_multiplier)
		m.set_shader_parameter("lightmap", lm)
		mi.set_surface_override_material(i, m)
		lm_mats.append(m)

func _set_gi(m: int):
	gi_mode = m
	voxel_gi.visible = (m == 1)
	env.sdfgi_enabled = (m == 2)
	if m == 2:
		env.sdfgi_cascades = 4; env.sdfgi_min_cell_size = 0.1; env.sdfgi_use_occlusion = true; env.sdfgi_read_sky_light = false
	for mm in lm_mats: mm.set_shader_parameter("bounce", float(ARGS.get("lme", "1.5")) if m == 0 else 0.0)
	if lights.has("fake_bounce"): lights.fake_bounce.visible = false
	env.ambient_light_energy = 0.06 if SCENE == "dusk" else 0.02

# 第1章 夕方: low sun through the open front door, the sky in the doorway, the fresnel being aimed at her mark,
# and a white board throwing the floor's sunlight back up into Natsuki's face
func _lights_dusk():
	var arr = JSON.parse_string(FileAccess.get_file_as_string(BASE + "lights.json"))
	var k: float = float(ARGS.get("dk", "1.0"))
	for L in arr:
		match L.name:
			"sun":
				var d := DirectionalLight3D.new()
				d.light_color = Color(L.color[0], L.color[1], L.color[2]).linear_to_srgb()
				d.light_energy = 2.4 * k; d.shadow_enabled = true; d.light_angular_distance = 0.8; d.light_specular = 0.3
				d.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS; d.directional_shadow_max_distance = 14.0
				d.light_volumetric_fog_energy = 1.6
				add_child(d)
				var dir = b2g(L.dir)
				d.look_at_from_position(Vector3.ZERO, dir, Vector3.UP if abs(dir.y) < 0.95 else Vector3.FORWARD)
				lights.sun = d
			"door_sky":
				# the sky in the doorway lights the hall, not the people: Taiga stands in it and would burn to paper white
				lights.doorsky = _mk_spot(L, 1.1 * k, L.spread / 2.0, 0.6, false)
				lights.doorsky.light_specular = 0.15
			"fresnel_key":
				lights.fres_d = _mk_spot(L, 2.6 * k, L.angle, 0.06)
				lights.fres_d.light_volumetric_fog_energy = 2.0
			"reflector_bounce":
				var r := _mk_spot(L, 0.9 * k, 70.0, 0.4, false); r.light_specular = 0.1; r.light_volumetric_fog_energy = 0.0
				lights.refl = r

func _lights():
	var arr = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lights.json"))
	for L in arr:
		match L.name:
			"fresnel_key":
				lights.fres = _mk_spot(L, 9.0, L.angle, 0.06)
				lights.fres.light_volumetric_fog_energy = 3.0
				# what the pool of light throws back up: a warm, shadowless fill (baked GI in the final build)
				var b := OmniLight3D.new(); b.light_color = Color(1.0, 0.62, 0.35); b.light_energy = 0.35; b.omni_range = 3.2
				b.omni_attenuation = 1.2; b.shadow_enabled = false; b.light_volumetric_fog_energy = 0.0; b.light_specular = 0.0
				add_child(b); b.global_position = b2g([0.35, 3.75, 0.35])
				lights.fake_bounce = b
			"blue_door":
				lights.blue = _mk_spot(L, 1.4, L.spread / 2.0, 0.2)
			"rain_sky":
				lights.sky = _mk_spot(L, 1.6, 40.0, 0.6)
			"lightning":
				lights.bolt = _mk_spot(L, 0.0, 55.0, 1.0)
				lights.bolt.light_volumetric_fog_energy = 2.0
			"rec_light":
				lights.rec = _mk_omni(L, 0.25, 0.6, 0.005)
			"nphone_light":
				pass
			"kiryu_phone_light":
				pass
	# lights that travel with the held phones
	var kp := S.kiryu_node.find_child("kphone", true, false) as Node3D
	if kp:
		var l := SpotLight3D.new()
		l.light_color = Color(0.82, 0.88, 1.0); l.light_energy = 0.32; l.spot_angle = 55; l.spot_range = 0.9
		l.spot_attenuation = 1.2; l.shadow_enabled = false; l.light_volumetric_fog_energy = 0.3
		kp.add_child(l)
		l.position = Vector3(0, 0, 0)
		l.rotation_degrees = Vector3(0, 180, 0)   # the screen is the phone's +Z face (Blender -Y); a spot points down its -Z
		lights.kphone = l
	var np := S.natsuki_node.find_child("nphone", true, false) as Node3D
	if np:
		var o := OmniLight3D.new()
		o.light_color = Color(0.8, 0.88, 1.0); o.light_energy = 0.5; o.omni_range = 0.7; o.shadow_enabled = false
		np.add_child(o)
		lights.nphone = o

func _rain():
	var r := S.env_node.find_child("rain", true, false) as MeshInstance3D
	if r == null: return
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add;
void vertex() { VERTEX.y -= mod(TIME * 7.5, 0.9); }
void fragment() { ALBEDO = vec3(0.32, 0.4, 0.55); ALPHA = 0.6; }
"""
	var m := ShaderMaterial.new(); m.shader = sh
	r.material_override = m

# ------------------------------------------------------------------ collision (Blender plan, metres)
func _box(center_b: Array, size_b: Array):
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(size_b[0], size_b[2], size_b[1])
	cs.shape = bx
	sb.add_child(cs)
	add_child(sb)
	sb.global_position = b2g(center_b)

func _colliders():
	var XL = -1.6; var XR = 1.6; var YB = 0.6; var YF = 6.3; var ZG = S.ZG; var YG = 4.6
	_box([0, (YB + YG) / 2.0, -0.25], [3.4, YG - YB, 0.5])                 # hall floor
	_box([0.78, (YG + YF) / 2.0, ZG - 0.25], [1.7, YF - YG, 0.5])          # genkan floor
	_box([-0.4, (YG + YF) / 2.0, 0.45], [0.8, YF - YG, 0.9])               # shoe cabinet block
	_box([-1.2, (YG + YF) / 2.0, -0.25], [0.8, YF - YG, 0.5])              # floor behind it
	# ramp down into the genkan so you can walk back up (the 18 cm step)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bx := BoxShape3D.new()
	bx.size = Vector3(1.6, 0.04, 0.45); cs.shape = bx; sb.add_child(cs); add_child(sb)
	sb.global_position = b2g([0.78, YG + 0.2, ZG / 2.0])
	sb.rotation.x = atan2(ZG, 0.4)
	for w in [[XL - 0.15, 3.45, 1.2, 0.3, 6.2, 2.8], [XR + 0.15, 3.45, 1.2, 0.3, 6.2, 2.8], [0, YF + 0.15, 1.2, 3.6, 0.3, 2.8], [0, YB - 0.15, 1.2, 3.6, 0.3, 2.8]]:
		_box([w[0], w[1], w[2]], [w[3], w[4], w[5]])
	_box([-1.19, 2.9, 1.2], [0.82, 3.4, 2.6])                              # staircase
	var props := [[-0.32, 4.02, 0.24], [1.05, 6.1, 0.3], [-0.45, 4.35, 0.26], [1.25, 2.55, 0.32], [1.25, 3.3, 0.22], [1.42, 6.05, 0.14]]
	if SCENE == "dusk":
		props = [[0.36, 3.84, 0.24], [-0.42, 4.5, 0.22], [-0.45, 4.12, 0.26], [1.25, 2.55, 0.32], [1.25, 3.3, 0.22], [0.95, 2.75, 0.2], [0.82, 6.3, 0.3]]
	for o in props:
		var s2 := StaticBody3D.new(); var c2 := CollisionShape3D.new(); var cy := CylinderShape3D.new()
		cy.radius = o[2]; cy.height = 2.0; c2.shape = cy; s2.add_child(c2); add_child(s2)
		s2.global_position = b2g([o[0], o[1], 1.0])

func _player():
	player = preload("res://scripts/player.gd").new()
	var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.2; cap.height = 1.6
	cs.shape = cap; cs.position.y = 0.8
	player.add_child(cs)
	var head := Node3D.new(); head.name = "Head"; player.add_child(head)
	var cam := Camera3D.new(); cam.name = "Camera"; cam.fov = 62; cam.near = 0.05; head.add_child(cam)
	var attr := CameraAttributesPractical.new()
	cam.attributes = attr
	add_child(player)
	player.global_position = Vector3(-0.5, 0.0, -1.35)
	player.yaw = -0.25
	if ARGS.has("pose"):
		var q = ARGS["pose"]
		player.global_position = Vector3(q[0], 0.0, q[1]); player.yaw = deg_to_rad(q[2]); player.pitch = deg_to_rad(q[3])
		player.auto_path = [[0.0, q[0], q[1], q[2], q[3]], [99.0, q[0], q[1], q[2], q[3]]]
	if record == "walk":
		player.auto_path = [[0.0, -0.5, -1.35, -14.0, -6.0], [CARD_TIME + 1.0, -0.5, -1.35, -14.0, -6.0],
			[CARD_TIME + 6.5, -0.15, -3.0, -10.0, -10.0], [CARD_TIME + 8.0, -0.12, -3.2, 18.0, -4.0],
			[CARD_TIME + 11.0, 0.25, -3.5, 4.0, -3.0], [CARD_TIME + 14.0, 0.35, -3.9, 0.0, 2.0]]

# ------------------------------------------------------------------ print + card
func _print_layer():
	var layer := CanvasLayer.new(); layer.layer = 10; add_child(layer)
	var r := ColorRect.new(); r.set_anchors_preset(Control.PRESET_FULL_RECT); r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	riso = ShaderMaterial.new(); riso.shader = load("res://shaders/riso2.gdshader" if PRINT_V == 2 else "res://shaders/riso.gdshader")
	riso.set_shader_parameter("exposure", PRINT_EXP[SCENE] if PRINT_V == 2 else 1.0)
	if ARGS.has("print"): print_on = ARGS["print"] > 0.5; riso.set_shader_parameter("enabled", ARGS["print"])
	r.material = riso
	layer.add_child(r)

# ------------------------------------------------------------------ settings slip
# All current settings on one slip of paper in the bottom-left corner, like the label stuck on a test print.
# It appears for a few seconds whenever a setting changes (the one just changed in orange); H keeps it up.
var note: PanelContainer
var note_label: RichTextLabel
var note_until := 0.0
var shown_start := false
const INK := "#00336b"
const ORANGE := "#e8521c"

var ht_mode := 0
var print_on := true
func _set_ht(m: int):
	ht_mode = m; riso.set_shader_parameter("mode", m)
func _set_print(on: bool):
	print_on = on; riso.set_shader_parameter("enabled", 1.0 if on else 0.0)

func _save_settings():
	SET["cam"] = player.cam_mode
	SET["gi"] = gi_mode
	SET["ht"] = ht_mode
	SET["print"] = print_on
	SET["q"] = quality_high

func _restore_settings():
	if SET.has("cam"): player.cam_mode = SET.cam
	if SET.has("gi"): _set_gi(SET.gi)
	if SET.has("ht"): _set_ht(SET.ht)
	if SET.has("print"): _set_print(SET.print)
	if SET.has("q") and not SET.q: _quality(false)

func _status(changed: String):
	_save_settings()
	if note == null:
		var layer := CanvasLayer.new(); layer.layer = 12; add_child(layer)
		note = PanelContainer.new(); layer.add_child(note)
		var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.93, 0.91, 0.85)
		sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 6; sb.content_margin_bottom = 6
		note.add_theme_stylebox_override("panel", sb)
		note_label = RichTextLabel.new(); note_label.bbcode_enabled = true; note_label.fit_content = true
		note_label.autowrap_mode = TextServer.AUTOWRAP_OFF; note_label.scroll_active = false
		var font: FontFile = load("res://fonts/SerifJP-Bold.otf")   # the imported resource (load_dynamic_font fell back to a system sans on Windows)
		var u: float = get_viewport().get_visible_rect().size.y / 1080.0
		note_label.add_theme_font_override("normal_font", font); note_label.add_theme_font_size_override("normal_font_size", int(24 * u))
		note_label.add_theme_color_override("default_color", Color(0.0, 0.2, 0.42))
		note.add_child(note_label)
		note.anchor_left = 0.0; note.anchor_top = 1.0; note.anchor_bottom = 1.0
		note.offset_left = 28 * u; note.offset_bottom = -24 * u; note.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var items := [
		["scene", "第一章 夕方" if SCENE == "dusk" else "第二章 夜"],
		["cam", "カメラ " + player.CAM_MODES[player.cam_mode]],
		["gi", "照り返し " + GI_NAMES[gi_mode]],
		["ht", "網点 " + ("全体" if ht_mode == 0 else "中心だけ細かく")],
		["print", "刷り " + (("二版" if PRINT_V == 2 else "初版") if print_on else "なし")],
		["exp", "刷りの明るさ %.2f" % PRINT_EXP[SCENE] if PRINT_V == 2 else "刷りの明るさ －"],
		["q", "画質 " + ("高" if quality_high else "低")]]
	var parts := []
	for it in items:
		var c: String = ORANGE if it[0] == changed else INK
		parts.append("[color=%s]%s[/color]" % [c, it[1]])
	var pin := "　　（Ｈ 固定中）" if SET.get("pin", false) else ""
	note_label.text = "　｜　".join(parts) + pin
	var plain := note_label.get_parsed_text()
	var f: Font = note_label.get_theme_font("normal_font"); var fs: int = note_label.get_theme_font_size("normal_font_size")
	note_label.custom_minimum_size = Vector2(f.get_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 4, 0)
	note.reset_size()
	note.visible = true
	note_until = Time.get_ticks_msec() / 1000.0 + 3.0

func _card():
	var layer := CanvasLayer.new(); layer.layer = 11; add_child(layer)
	card = ColorRect.new(); (card as ColorRect).color = Color(0.93, 0.91, 0.85)
	card.set_anchors_preset(Control.PRESET_FULL_RECT); card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(card)
	var font: FontFile = load("res://fonts/SerifJP-Bold.otf")   # the imported resource (load_dynamic_font fell back to a system sans on Windows)
	var u: float = get_viewport().get_visible_rect().size.y / 1080.0
	var vb := VBoxContainer.new(); vb.anchor_left = 0.1; vb.anchor_top = 0.28; vb.anchor_right = 0.9; vb.anchor_bottom = 0.8
	card.add_child(vb)
	var ink := Color(0.0, 0.2, 0.42)
	var lines := [["扉を開けなかったのは、", 92], ["なぜですか？", 92], ["", 26], ["第二章　籠城　二十三時", 38]]
	if SCENE == "dusk": lines = [["あの別荘には、", 92], ["どうして行ったんですか？", 92], ["", 26], ["第一章　ルール　夕方", 38]]
	for line in lines:
		var lb := Label.new(); lb.text = line[0]
		lb.add_theme_font_override("font", font); lb.add_theme_font_size_override("font_size", int(line[1] * u))
		lb.add_theme_color_override("font_color", ink)
		vb.add_child(lb)
	var foot := Label.new()
	foot.text = "ＷＡＳＤ 移動　マウス 視点　Ｎ 場面（夕方／夜）　Ｃ カメラのコマ　Ｇ 照り返し　１／２ 網点　Ｑ 画質　Ｐ 刷り　Ｖ 刷りの版　－／＝ 刷りの明るさ　Ｈ 設定表示の固定　Ｅｓｃ マウス解放"
	foot.add_theme_font_override("font", font); foot.add_theme_font_size_override("font_size", int(19 * u))
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_theme_color_override("font_color", ink)
	foot.anchor_left = 0.1; foot.anchor_top = 0.855; foot.anchor_right = 0.92; foot.anchor_bottom = 0.985
	card.add_child(foot)

# ------------------------------------------------------------------ time
func _process(dt):
	var t: float = Time.get_ticks_msec() / 1000.0 - t0
	if Engine.get_write_movie_path() != "": t = float(Engine.get_process_frames()) / 24.0
	_update_faces(t, fmod(max(t - CARD_TIME, 0.0), LOOP))
	card.visible = t < CARD_TIME
	player.input_enabled = t > CARD_TIME - 0.4
	var lt: float = fmod(max(t - CARD_TIME, 0.0), LOOP)
	if t < CARD_TIME:
		for ap in anims: ap.seek(0.0, true)
	# lightning once per loop, and the fresnel's generator hiccups with it
	var p = func(x, c, w): return exp(-pow((x - c) / w, 2.0))
	var bolt: float = p.call(lt, LIGHTNING_T, 0.035) + 0.6 * p.call(lt, LIGHTNING_T + 0.12, 0.03) + 0.25 * p.call(lt, LIGHTNING_T + 0.3, 0.05)
	if lights.has("bolt"): lights.bolt.light_energy = 22.0 * bolt
	if note and note.visible and not SET.get("pin", false) and Time.get_ticks_msec() / 1000.0 > note_until: note.visible = false
	if not shown_start and t > CARD_TIME:
		shown_start = true
		if record == "" or ARGS.has("status"): _status("scene" if SET.has("cam") else "")
	# each knock moves the whole door a few millimetres in its frame (there is no sound yet, so it has to be seen)
	if door_pivot and S.has("knocks"):
		var j := 0.0
		for k in S.knocks:
			var dtk: float = lt - float(k)
			if dtk > 0.0 and dtk < 0.6: j += exp(-dtk / 0.07) * sin(dtk * 95.0)
		door_pivot.position = S.door_rest + Vector3(0.0, 0.0, 0.012 * j)
		door_pivot.rotation.y = S.door_rot + 0.006 * j
		# her palm on the slit glass cuts the light coming in with every blow
		if lights.has("blue"): lights.blue.light_energy = 1.4 * (1.0 - 0.45 * clamp(abs(j), 0.0, 1.0))
	if lights.has("fres"):
		var dip: float = 1.0 - 0.55 * p.call(lt, LIGHTNING_T + 0.15, 0.12) - 0.25 * p.call(lt, LIGHTNING_T + 0.4, 0.08)
		lights.fres.light_energy = 9.0 * (1.0 + 0.03 * sin(t * 6.1) + 0.02 * sin(t * 17.3)) * dip
	if ARGS.has("poses"):
		var idx := int(t / 1.5)
		if idx >= ARGS["poses"].size(): get_tree().quit()
		elif idx != S.get("pose_idx", -1):
			S["pose_idx"] = idx
			var q = ARGS["poses"][idx]
			player.global_position = Vector3(q[0], 0.0, q[1]); player.yaw = deg_to_rad(q[2]); player.pitch = deg_to_rad(q[3])
			player.auto_path = [[0.0, q[0], q[1], q[2], q[3]], [99.0, q[0], q[1], q[2], q[3]]]; player.auto_t = 0.0
	elif record != "" and t > CARD_TIME + 15.0: get_tree().quit()

func _unhandled_input(e):
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_1:
				_set_ht(0); _status("ht")
			KEY_2:
				_set_ht(1); _status("ht")
			KEY_C:
				player.cam_mode = (player.cam_mode + 1) % 4; _status("cam")
			KEY_P:
				_set_print(not print_on); _status("print")
			KEY_Q:
				_quality(not quality_high); _status("q")
			KEY_G:
				_set_gi((gi_mode + 1) % 4); _status("gi")
			KEY_MINUS, KEY_EQUAL:
				if PRINT_V == 2:
					PRINT_EXP[SCENE] = clamp(PRINT_EXP[SCENE] * (0.85 if e.keycode == KEY_MINUS else 1.0 / 0.85), 0.5, 8.0)
					riso.set_shader_parameter("exposure", PRINT_EXP[SCENE]); _status("exp")
			KEY_V:
				_save_settings(); PRINT_V = 1 if PRINT_V == 2 else 2
				get_tree().reload_current_scene()
			KEY_H:
				SET["pin"] = not SET.get("pin", false); _status("")
			KEY_N:
				_save_settings()
				SCENE = "dusk" if SCENE == "night" else "night"
				get_tree().reload_current_scene()
			KEY_F11:
				var w := get_window()
				w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN or w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

func _quality(high: bool):
	quality_high = high
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if high else Viewport.SCALING_3D_MODE_FSR
	vp.scaling_3d_scale = 1.0 if high else 0.6
	RenderingServer.environment_set_volumetric_fog_volume_size(96 if high else 48, 96 if high else 48)
	for k in lights: if lights[k] is Light3D and lights[k].shadow_enabled: lights[k].shadow_blur = 1.0 if high else 0.5

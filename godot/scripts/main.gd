## 第2章 23:00 prototype. Builds the scene from the Blender exports (assets/*.glb, lights.json, scene.json).
## Keys: WASD/mouse walk and look, 1 one screen everywhere / 2 fine at the centre,
## C camera 12 / 18 / 12+slide / smooth, G GI, Q quality, P print on/off, Esc release mouse, F11 fullscreen.
## Unattended recording: godot --path . --write-movie out.png --fixed-fps 24 -- --record=walk
extends Node3D
const Type = preload("res://scripts/type.gd")

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
static var PRINT_EXP := {"night": 1.8, "dusk": 1.3, "house": 1.8}   # the printer's exposure per scene; - and = adjust
static var SET := {}             # every setting survives N (scene switch reloads the tree)
static var DUSK_K := {"sun": 1.0, "sky": 1.0, "key": 1.0}   # 夕方の光の強さ（太陽／戸口の空／フレネル）: 7-8, 9-0, [-] keys
static var DUSK_BASE := {}       # the lights' designed energies, to scale from
static var SCENE := ""            # "night" (第2章 23:00) or "dusk" (第1章 夕方) or "house" (段階2: the whole house, no people); N switches
static var TIME := ""             # 段階2, the house: dusk t20 t23 t02 t0330 t0430 (T steps through them)
const TIME_LABEL := {"dusk": "十七時半（夕方）", "t20": "二十時（停電）", "t23": "二十三時", "t02": "二時", "t0330": "三時半", "t0430": "四時半（夜明け）"}
var ST := {}                      # the house's state at TIME (scene.json "state")
var BASE := "res://assets/"
var door_pivot: Node3D
var story                          # 段階1: the playable 第1章 (scripts/story.gd), dusk only, not in check runs
var talk_now := ""                 # whose mouth moves while a conversation runs
var story_talking := false
var door_scene := false            # 段階1: 第2章 23:00, the door (scripts/door.gd)

static func b2g(v) -> Vector3:
	return Vector3(v[0], v[2], -v[1])

# 段階2: the whole house is its own pack (RULES_house.pck beside RULES.pck, build.sh), so that the zip stays under the
# 400MiB the user can send and a change to the story scenes alone does not send the house again (決定事項 2026-11-04).
# Looked for beside the executable, or where --housepack=<file> says (the check shots run the editor binary with
# --main-pack, which Godot keeps out of the arguments a script can read).
func _house_pack():
	var fs := [OS.get_executable_path().get_base_dir() + "/RULES_house.pck"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--housepack="): fs.push_front(a.substr(12))
	for f in fs:
		if FileAccess.file_exists(f):
			ProjectSettings.load_resource_pack(f, false)
			return

func _ready():
	if SCENES_RUN > 0: f0 = Engine.get_process_frames()
	SCENES_RUN += 1
	_house_pack()
	get_tree().root.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # every string is translated by hand (story.gd T/Tw), with the phrase marks handled
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--record="): record = a.substr(9)
		if a.begins_with("--pose="): ARGS["pose"] = Array(a.substr(7).split(",")).map(func(x): return float(x))
		if a.begins_with("--hold="): ARGS["hold"] = a.substr(7)
		if a.begins_with("--at="): ARGS["at"] = a.substr(5)
		if a.begins_with("--chklight="): ARGS["chklight"] = a.substr(11)
		if a.begins_with("--poses="):   # check stills: "x,z,yaw,pitch;x,z,yaw,pitch;..." held 1.5 s each, then quit
			ARGS["poses"] = Array(a.substr(8).split(";")).map(func(q): return Array(q.split(",")).map(func(x): return float(x)))
		if a.begins_with("--shots="):   # check stills in one run: "x,z,yaw,pitch,eye,t;..." each its own fresh moment (see _shot_tick)
			ARGS["shots"] = Array(a.substr(8).split(";")).map(func(q): return Array(q.split(",")).map(func(x): return float(x)))
		if a.begins_with("--shotframes="): ARGS["shotframes"] = int(a.substr(13))
		if a == "--shotkeepfog": ARGS["shotkeepfog"] = true
		if a.begins_with("--print="): ARGS["print"] = float(a.substr(8))
		if a == "--nocard": CARD_TIME = 0.0
		if a.begins_with("--riso="): PRINT_V = int(a.substr(7))
		if a.begins_with("--pexp="): PRINT_EXP[SCENE if SCENE != "" else "night"] = float(a.substr(7)); ARGS["pexp"] = float(a.substr(7))
		if a.begins_with("--time=") and TIME == "": TIME = a.substr(7)
		if a.begins_with("--look="): ARGS["look"] = float(a.substr(7))
		if a == "--status": ARGS["status"] = true; SET["pin"] = true
		if a == "--bright": ARGS["bright"] = true
		if a.begins_with("--dusk="):   # check stills: the dusk light scales sun,sky,key (as the 7-0 [ ] keys set them)
			var v = Array(a.substr(7).split(",")).map(func(x): return float(x))
			DUSK_K.sun = v[0]; DUSK_K.sky = v[1]; DUSK_K.key = v[2]
		if a == "--noclip": ARGS["noclip"] = true   # check stills from outside the house: no walls, no gravity
		if a == "--bake-gi": ARGS["bake"] = true
		if a.begins_with("--gi="): ARGS["gi"] = a.substr(5)
		if a.begins_with("--gie="): ARGS["gie"] = a.substr(6)
		if a.begins_with("--lme="): ARGS["lme"] = a.substr(6)
		if a.begins_with("--fogd="): ARGS["fogd"] = float(a.substr(7))   # the outside's distance haze (check shots)
		if a.begins_with("--fogl="): ARGS["fogl"] = float(a.substr(7))
		if a.begins_with("--glassd="): ARGS["glassd"] = float(a.substr(9))
		if a == "--nowear": ARGS["nowear"] = true      # 段階2 使い込みの跡 off (before/after shots)
		if a == "--weardbg": ARGS["weardbg"] = true    # the wear decals in red (where they land)
		if a == "--minicam": ARGS["minicam"] = true    # check stills: 澪の小さなカメラ, the old boxes and the new model side by side
		if a.begins_with("--tf="): ARGS["tf"] = a.substr(5)       # Taiga's dusk fill/rim scale (check shots)
		if a.begins_with("--lamp="): ARGS["lamp"] = a.substr(7)   # the lobby bulb's scale (check shots)
		if a.begins_with("--scene=") and SCENE == "": SCENE = a.substr(8)
		if a == "--nostory": ARGS["nostory"] = true
		if a == "--frameclock": ARGS["frameclock"] = true
		if a.begins_with("--lite="): ARGS["lite"] = a.substr(7)
		if a == "--perf": ARGS["perf"] = true
		if a == "--old3": ONE = false                          # 試作97: the three scenes as they were (to compare)
		if a.begins_with("--play="): ARGS["play"] = a.substr(7)   # the whole house as a chapter has it: ch0 | ch1 | h21 | door | ch4 | ch11
		if a == "--noch0": ARGS["noch0"] = true   # ステップ E: the game begins at 第1章, not at 序章 (the dawn)
		if a == "--door": ARGS["door"] = true   # 第2章 23:00 the door scene without playing up to it
		if a.begins_with("--mfps="): ARGS["mfps"] = float(a.substr(7))   # a movie written at another rate than 24 (the check movie: 12, like the print)
		if a == "--genoff": ARGS["genoff"] = true
		if a == "--noocc": ARGS["noocc"] = true   # 試作92: without the occluders and the far cedars' shadows cut (to compare)
		if a == "--sugishadow": ARGS["sugishadow"] = true   # 試作97: 第1章 with the cedars' shadows left on (to compare)
		if a == "--ch2": ARGS["ch2"] = true   # 試作91: the house at 20:00 as 第2章 has it (the people; the story too unless checking)
		if a == "--nochars": ARGS["nochars"] = true   # the storyboard is drawn of the empty hall (ui/make_conte.py)
		if a.begins_with("--fov="): ARGS["fov"] = float(a.substr(6))   # the storyboard's frame is shot at the small camera's angle (ui/make_conte.py)
	var start: bool = SCENE == "" and SCENES_RUN == 1   # ステップ E: the game itself begins (not N, not a reload)
	if SCENE == "": SCENE = "dusk"   # 段階1: the game begins with 第1章 (N still switches)
	# 試作97 (ステップ C): one stage. 第1章 is played in the whole house at 17:30 and the door in the whole house at 23:00,
	# with the people and the few things only that chapter has brought in from the old scenes' files (_ch1_set, _door_set).
	# The check stills of the old scenes (--record, --shots, --poses) still get the old scenes, and --old3 plays them.
	var checking0: bool = record != "" or ARGS.has("shots") or ARGS.has("poses") or ARGS.has("pose") or ARGS.has("nostory") or ARGS.has("bake")   # 試作120: --bake-gi --scene=dusk が家の夕方へ回され、assets/dusk/gi.res ができなかった
	var one: bool = ONE and FileAccess.file_exists("res://assets/house/scene.json")
	if NEXT_PLAY != "": SCENE = "house"; play = NEXT_PLAY; NEXT_PLAY = ""; TIME = String(PLAY_TIME.get(play, "t0330"))   # ステップ D・E: a chapter reached by playing (to_chapter)
	elif SCENE == "house" and ARGS.has("play"): play = ARGS.play; TIME = String(PLAY_TIME.get(play, "t23"))
	elif start and one and not checking0 and not ARGS.has("noch0") and not ARGS.has("door"): SCENE = "house"; TIME = "t0430"; play = "ch0"   # ステップ E: 序章 at 5:00 first; it goes on to 第1章 (ch0.gd)
	elif one and not checking0 and SCENE == "dusk": SCENE = "house"; TIME = "dusk"; play = "ch1"
	elif one and not checking0 and SCENE == "night" and (FROM_STORY or ARGS.has("door")): SCENE = "house"; TIME = "t23"; play = "door"
	BASE = "res://assets/dusk/" if SCENE == "dusk" else ("res://assets/house/" if SCENE == "house" else "res://assets/")
	S = JSON.parse_string(FileAccess.get_file_as_string(BASE + "scene.json"))
	if SCENE == "house":
		if TIME == "" or not S.state.has(TIME): TIME = "dusk"
		ST = S.state[TIME]
		PRINT_EXP["house"] = float(ARGS.get("pexp", ST.exp))
		if CARD_TIME > 0.0: CARD_TIME = 2.0
	_environment()
	_load_scene(BASE + "env.glb", "env")
	for n in ([] if ARGS.has("nochars") else CHARS):
		if ResourceLoader.exists(BASE + "%s.glb" % n): _load_scene(BASE + "%s.glb" % n, n)
	ch2_house = (CH2 or ARGS.has("ch2")) and SCENE == "house"; CH2 = false
	if ch2_house: _t20_people()
	if play == "ch1" and not ARGS.has("nochars"): _ch1_set()
	if play == "door" and not ARGS.has("nochars"): _door_set()
	if play == "h21" and not ARGS.has("nochars"): _t20_people()   # ステップ E: 21時・22時, the people of 20:00 (ch2_21.gd places them)
	if play == "h21":   # every board is up by then
		for mi in S.env_node.find_children("board_*", "MeshInstance3D", true, false): mi.visible = true
	if ch2_house and "--taigagen" in OS.get_cmdline_user_args() and S.has("taiga_node"):
		place_person("taiga", T20.taiga_gen.pos, T20.taiga_gen.yaw)
	if ARGS.has("nochars"):   # the people's things go too (the reflector Makoto holds, the box and the tape)
		for mi in S.env_node.find_children("*", "MeshInstance3D", true, false):
			if String(mi.name).begins_with("reflector") or String(mi.name).begins_with("carrybox") or String(mi.name).begins_with("taperoll"): mi.visible = false
	door_pivot = S.env_node.find_child("door_pivot", true, false) as Node3D
	if door_pivot: S["door_rest"] = door_pivot.position; S["door_rot"] = door_pivot.rotation.y
	for mi in S.env_node.find_children("*", "MeshInstance3D", true, false):
		for pre in ["fresnel", "fres_lens", "barndoor", "yoke", "cscol", "csleg", "recled", "rain", "nphone", "kphone", "slitglass", "lcd", "ext_sky", "lamp_", "winglass", "cbulb_", "lampshade_lamp_cellar", "lampshade_lantern_"]:   # the cellar bulb and lantern: their own glass round the light shadowed the room in a 12-sided blot (試作50); ext_sky: the sky ring round the wood (it shaded the ground near it)
			if String(mi.name).begins_with(pre): mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# the whole house is single-sided walls: a low sun from outside sees their backs, which a one-sided shadow pass
		# culls, and the dawn came through every wall (段階2, 4:30 の廊下が真っ白)
		if SCENE == "house" and mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON: mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	if SCENE == "dusk" or play == "ch1": TALK = {"natsuki": [[2.0, 4.6], [9.0, 10.4], [14.5, 16.8]], "kiryu": [[11.2, 12.4]]}
	_faces()
	_camcorder_lcd()
	if ARGS.has("minicam"): _minicam_dbg()
	if SCENE == "house":
		_house_state(); _lights_house()
		if play == "ch1": _lights_dusk(["reflector_bounce", "taiga_fill", "taiga_rim"])
		if play == "door": _phone_lights(); lights["blue"] = lights.get("blue_door"); if lights.blue == null: lights.erase("blue")
		_window_glass(); _wear(); _house_cheaper()
	elif SCENE == "dusk": _lights_dusk()
	else: _lights()
	_gi()
	_colliders()
	_rain()
	_player()
	if SCENE == "house":   # 試作90: E opens and shuts the doors (ユーザー「扉、開くと嬉しい」)
		var dn = preload("res://scripts/doors.gd").new(); dn.name = "Doors"; add_child(dn); dn.setup(self)
	_print_layer()
	if (SCENE == "dusk" or play == "ch1") and record == "" and not ARGS.has("shots") and not ARGS.has("poses") and not ARGS.has("pose") and not ARGS.has("nostory"):
		if CARD_TIME > 0.0: CARD_TIME = 5.0
		story = preload("res://scripts/story.gd").new(); story.main = self; add_child(story)
	var checking: bool = record != "" or ARGS.has("shots") or ARGS.has("poses") or ARGS.has("pose") or ARGS.has("nostory")
	if (play == "door" or (SCENE == "night" and (FROM_STORY or ARGS.has("door")))) and not checking:
		if CARD_TIME > 0.0: CARD_TIME = 3.0   # only the time card: the chapter's door was at 二十時
		story = preload("res://scripts/door.gd").new(); story.main = self; add_child(story)
		door_scene = true
	if play in ["ch4", "ch11"] and not checking:   # ステップ D: 3:30 の廊下 (scripts/fps.gd) and the same night on the tape (scripts/tape.gd); each has its own chapter card
		CARD_TIME = 0.0
		story = (load("res://scripts/fps.gd") if play == "ch4" else load("res://scripts/tape.gd")).new(); story.main = self; add_child(story)
	if play in ["ch0", "h21"] and not checking:   # ステップ E: 序章（5時の玄関）and 第2章の残り（21時・22時）, each with its own card
		CARD_TIME = 0.0
		story = (load("res://scripts/ch0.gd") if play == "ch0" else load("res://scripts/ch2_21.gd")).new(); story.main = self; add_child(story)
	if ARGS.has("genoff"): generator(false)   # 試作91: the stills of 第2章 before the generator
	if "--boards" in OS.get_cmdline_user_args() and SCENE == "house":   # 試作92: stills of the boards as 第2章 leaves them at 20:00
		for mi in S.env_node.find_children("board_*", "MeshInstance3D", true, false): mi.visible = true
	if ch2_house and not checking:   # 試作91: 第2章 at 20:00 in the whole house, reached by playing 第1章
		story = preload("res://scripts/story.gd").new(); story.main = self; story.house = true; add_child(story)
	FROM_STORY = false
	if not checking0 and not has_node("Sound"):   # ステップ E: the stand-in sounds (rain, generator, knock, radio, tape; scripts/sound.gd)
		var snd: Node = load("res://scripts/sound.gd").new(); snd.name = "Sound"; add_child(snd); snd.setup(self)
	_card()
	_restore_settings()
	_perf(checking0)
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
	if SCENE == "house":
		env.ambient_light_color = Color(ST.amb[0], ST.amb[1], ST.amb[2]); env.ambient_light_energy = ST.ambe
	if SCENE == "house" and S.has("walk"):   # 段階2 外: the woods fade into the sky with distance, outside only (_outside_fog)
		env.fog_enabled = true; env.fog_mode = Environment.FOG_MODE_EXPONENTIAL; env.fog_density = 0.0
		var a: Color = Color(ST.amb[0], ST.amb[1], ST.amb[2]); var mx: float = max(a.r, max(a.g, a.b))
		env.fog_light_color = Color(a.r / mx, a.g / mx, a.b / mx); env.fog_light_energy = ST.sky * float(ARGS.get("fogl", 0.35))
		env.fog_sun_scatter = 0.0; env.fog_sky_affect = 0.0
	if ARGS.has("bright"): env.ambient_light_energy = 3.0; env.volumetric_fog_enabled = false
	we.environment = env
	add_child(we)
	# the film-set haze fills the house only
	fog_vol = FogVolume.new()
	fog_vol.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fog_vol.size = Vector3(3.2, 2.65, 5.7)
	fog_vol.position = b2g([0.0, 3.45, 1.12])
	if S.has("gi_box"):   # the v4 house: the hall only (the rooms beyond are shut)
		var g0: Array = S.gi_box[0]; var g1: Array = S.gi_box[1]
		fog_vol.size = Vector3(g1[0] - g0[0] - 0.3, 2.65, g1[1] - g0[1] - 0.3)
		fog_vol.position = b2g([(g0[0] + g1[0]) / 2.0, (g0[1] + g1[1]) / 2.0, 1.12])
	var fm := FogMaterial.new()
	fm.density = 0.05 if SCENE == "dusk" else 0.085
	if SCENE == "house":   # the whole house, every floor
		var h0: Array = S.gi_box[0]; var h1: Array = S.gi_box[1]
		fog_vol.size = Vector3(h1[0] - h0[0] - 0.6, h1[2] - h0[2] - 0.2, h1[1] - h0[1] - 0.6)
		fog_vol.position = b2g([(h0[0] + h1[0]) / 2.0, (h0[1] + h1[1]) / 2.0, (h0[2] + h1[2]) / 2.0])
		fm.density = ST.fog
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
	if key in CHARS:
		# the generated clothes are single shells: seen through a collar or a cuff, culled back faces read as black holes
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var m3 := mi as MeshInstance3D
			# 試作98 (ユーザー「カメラで覗いて見下ろすと、キャラの首がなくなる」): a skinned part is culled by its rest-pose
			# box, not where the pose has put it; looking down, the head's box left the view while the head was in it
			m3.extra_cull_margin = 1.0
			for i in range(m3.mesh.get_surface_count()):
				var mat := m3.get_active_material(i) as BaseMaterial3D
				if mat != null:
					var d := mat.duplicate() as BaseMaterial3D
					d.cull_mode = BaseMaterial3D.CULL_DISABLED
					if key == "makoto" and String(mi.name).ends_with("_body"):
						# 試作19b: when she turns her head, the inside of the sweater's collar shows behind the neck; lit only
						# from inside it is nearly black and prints as a hole. Thin cloth lets the light through from outside.
						d.backlight_enabled = true
						d.backlight = Color(0.7, 0.7, 0.7)
					m3.set_surface_override_material(i, d)
			if key == "taiga" and not String(mi.name).begins_with("carrybox"): m3.layers = 1 | 2   # layer 2: the dusk fill and rim that only he gets (taiga_fill/_rim); the box he holds keeps its sunlit wood

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
			var fk: String = "natsuki_s" if ((SCENE == "dusk" or ch2_house or play == "ch1" or play == "h21") and k == "natsuki") else k   # her indoor head has its own UV layout
			var pj := "res://assets/faces/%s_%s.jpg" % [fk, st]
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
		if story_talking:
			talking = (k == talk_now)
		elif TALK.has(k):
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

# the bulb left on over the cellar door's lobby (house4.lobby_lamp): a dim warm pool so the door and its note read
func _lamp(L: Dictionary) -> OmniLight3D:
	var l := _mk_omni(L, 1.25 * float(ARGS.get("lamp", "1.0")), 3.5, 0.06)   # 1.25: the dark plank door reads in the print (0.5 lit only its casing)
	l.shadow_enabled = true; l.omni_attenuation = 1.4; l.light_volumetric_fog_energy = 0.3
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
	if S.has("gi_box"):
		var g0: Array = S.gi_box[0]; var g1: Array = S.gi_box[1]
		voxel_gi.size = Vector3(g1[0] - g0[0], g1[2] - g0[2], g1[1] - g0[1])
		voxel_gi.global_position = b2g([(g0[0] + g1[0]) / 2.0, (g0[1] + g1[1]) / 2.0, (g0[2] + g1[2]) / 2.0])
	if ARGS.has("bake"):
		var t := Time.get_ticks_msec()
		# 試作97: the voxels keep what glows when they are baked. 20:00 is the blackout: baked with the generator's bulbs
		# lit, the cellar and the hall were lit before Mio started it (ユーザー「発電機を回すまで地下の電球が点いていた」).
		# Its bulbs are dynamic lights, so once on they still bounce.
		if SCENE == "house" and TIME == "t20": generator(false)
		voxel_gi.bake(S.env_node, false)
		var data := voxel_gi.data
		data.energy = 1.0; data.propagation = 0.75; data.bias = 1.5; data.normal_bias = 0.0; data.interior = true; data.use_two_bounces = true
		ResourceSaver.save(data, _gi_path())
		print("GI BAKED in ", Time.get_ticks_msec() - t, " ms")
		get_tree().quit()
		return
	if ResourceLoader.exists(_gi_path()):
		voxel_gi.data = load(_gi_path())
		print("GI DATA ", voxel_gi.data != null)
	# art-directed bounce: the haze in the house scatters the key everywhere, so the bounce is pushed above physical
	if voxel_gi.data:
		voxel_gi.data.energy = float(ARGS.get("gie", "4.0"))
		voxel_gi.data.propagation = 0.85
	env.sdfgi_energy = float(ARGS.get("gie", "4.0"))
	for k in ["fres", "blue", "sky"]:
		if lights.has(k): lights[k].light_indirect_energy = 2.0
	_lightmap()
	_set_gi({"baked": 0, "voxel": 1, "sdfgi": 2, "none": 3}.get(ARGS.get("gi", "voxel"), 1))

# modes: 0 baked bounce (Blender lightmap)  1 VoxelGI  2 SDFGI  3 none
const GI_NAMES := ["焼き込み", "VoxelGI", "SDFGI", "なし"]
var lm_mats: Array = []
func _gi_path() -> String:
	return BASE + TIME + "/gi.res" if SCENE == "house" else BASE + "gi.res"

func _lightmap():
	var lp: String = BASE + TIME + "/lightmap.exr" if SCENE == "house" else BASE + "lightmap.exr"
	if not FileAccess.file_exists(lp) and not ResourceLoader.exists(lp): return
	var lm: Texture2D = load(lp)
	var sh: Shader = load("res://shaders/lightmapped.gdshader")
	# 試作93: the house comes in pieces (export_house.split_env: by floor and a 2.5 m grid), each piece env_static*;
	# pieces that share a material share one ShaderMaterial
	var pieces: Array = S.env_node.find_children("env_static*", "MeshInstance3D", true, false)
	if pieces.is_empty(): return
	var made := {}
	for mi in pieces:
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i) as StandardMaterial3D
			if made.has(src): mi.set_surface_override_material(i, made[src]); continue
			var m := ShaderMaterial.new(); m.shader = sh; made[src] = m
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
	for mm in lm_mats: mm.set_shader_parameter("bounce", float(ARGS.get("lme", str(S.get("lme", 1.5)))) if m == 0 else 0.0)
	if lights.has("fake_bounce"): lights.fake_bounce.visible = false
	env.ambient_light_energy = 0.06 if SCENE == "dusk" else 0.02
	if SCENE == "house": env.ambient_light_energy = ST.ambe

# 第1章 夕方: low sun through the open front door, the sky in the doorway, the fresnel being aimed at her mark,
# and a white board throwing the floor's sunlight back up into Natsuki's face
func _lights_dusk(only: Array = []):
	var arr = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dusk/lights.json"))
	var k: float = float(ARGS.get("dk", "1.0"))
	for L in arr:
		if not only.is_empty() and not (L.name in only): continue   # the whole house has its own sun, sky and lamps (試作97)
		match L.name:
			"sun":
				var d := DirectionalLight3D.new()
				d.light_color = Color(L.color[0], L.color[1], L.color[2]).linear_to_srgb()
				d.light_energy = 2.4 * k * DUSK_K.sun; d.shadow_enabled = true; d.light_angular_distance = 0.8; d.light_specular = 0.3
				DUSK_BASE["sun"] = 2.4 * k
				d.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS; d.directional_shadow_max_distance = 14.0
				d.light_volumetric_fog_energy = 1.6
				add_child(d)
				var dir = b2g(L.dir)
				d.look_at_from_position(Vector3.ZERO, dir, Vector3.UP if abs(dir.y) < 0.95 else Vector3.FORWARD)
				lights.sun = d
			"door_sky":
				# the sky in the doorway lights the hall, not the people: Taiga stands in it and would burn to paper white
				lights.doorsky = _mk_spot(L, 1.1 * k * DUSK_K.sky, L.spread / 2.0, 0.6, false)
				lights.doorsky.light_specular = 0.15; DUSK_BASE["sky"] = 1.1 * k
			"fresnel_key":
				lights.fres_d = _mk_spot(L, 2.6 * k * DUSK_K.key, L.angle, 0.06); DUSK_BASE["key"] = 2.6 * k
				lights.fres_d.light_volumetric_fog_energy = 2.0
			"reflector_bounce":
				var r := _mk_spot(L, 0.9 * k, 70.0, 0.4, false); r.light_specular = 0.1; r.light_volumetric_fog_energy = 0.0
				lights.refl = r
			"taiga_fill", "taiga_rim":
				# Taiga against the sky, as the eye adapts to him (ユーザー指摘): only his layer, no shadow, no fog
				var tl := _mk_spot(L, (0.7 if L.name == "taiga_fill" else 1.2) * float(ARGS.get("tf", "1.0")), 40.0, 0.5, false)
				tl.light_cull_mask = 2; tl.light_specular = 0.2; tl.light_volumetric_fog_energy = 0.0; tl.spot_range = 4.0
				lights[L.name] = tl
			"lamp_lobby":
				lights.lamp = _lamp(L)
			"lamp_kitchen", "lamp_living", "lamp_dining":
				# the rooms' lamps, on at dusk (the rooms beyond the hall, 試作33「部屋、もう少し回れるように」)
				var kl := _mk_omni(L, (3.5 if L.name == "lamp_living" else 1.4) * float(ARGS.get("klamp", "1.0")), 5.0, 0.08)   # the living room: only the floor lamp, and the dark sofa and table need it (試作42、klamp 2.5 で読めた)
				kl.shadow_enabled = true; kl.omni_attenuation = 1.3; kl.light_volumetric_fog_energy = 0.0
				lights[L.name] = kl

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
				add_child(b); b.global_position = b2g([S.mark[0], S.mark[1], 0.35]) if S.has("mark") else b2g([0.35, 3.75, 0.35])
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
			"lamp_lobby":
				lights.lamp = _lamp(L)
			"kiryu_phone_light":
				pass
	_phone_lights()

# lights that travel with the held phones (23:00)
func _phone_lights():
	if not S.has("kiryu_node") or not S.has("natsuki_node"): return
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

# 段階2: the whole house at one of the six times (blender/times.py). What the time changes besides the lights: the boards
# over the windows, the generator's cord, the front door, which lampshades glow, the sky ring round the wood.
func _house_state():
	for mi in S.env_node.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if nm.begins_with("board_"): mi.visible = ST.boards
		elif nm.begins_with("gencord"): mi.visible = ST.cord
		elif nm.begins_with("crew_"): mi.visible = ST.get("crew", true)   # the crew's lanterns and candles, out from 23:00 (times.py)
		elif nm.begins_with("ext_slipok_"): mi.visible = not ST.get("slip", false)   # the shoulder the storm takes (outside.py)
		elif nm.begins_with("ext_slipfall_"): mi.visible = ST.get("slip", false)
	var arr = JSON.parse_string(FileAccess.get_file_as_string(BASE + TIME + "/lights.json"))
	var lit := {}
	for L in arr: lit[L.name] = true
	for mi in S.env_node.find_children("lampshade_*", "MeshInstance3D", true, false):
		var key := String(mi.name).substr(10).get_slice(".", 0).get_slice("_0", 0)
		if key in S.get("crew_keys", []): mi.visible = ST.get("crew", true)
		for i in range(mi.mesh.get_surface_count()):
			var m := mi.get_active_material(i) as StandardMaterial3D
			if m == null: continue
			var d := m.duplicate() as StandardMaterial3D
			if lit.has(key): d.emission_enabled = true; d.emission_energy_multiplier = max(d.emission_energy_multiplier, 2.0)
			else: d.emission_enabled = false
			mi.set_surface_override_material(i, d)
	for mi in S.env_node.find_children("ext_sky*", "MeshInstance3D", true, false):
		var m := mi.get_active_material(0) as StandardMaterial3D
		if m:
			var d := m.duplicate() as StandardMaterial3D
			d.emission_energy_multiplier = ST.sky; d.emission = Color(ST.skyc[0], ST.skyc[1], ST.skyc[2])
			mi.set_surface_override_material(0, d)
	if door_pivot: door_pivot.rotation.y = S.get("door_rot", 0.0) + deg_to_rad(ST.front); S["door_rot"] = door_pivot.rotation.y

func _lights_house():
	var arr = JSON.parse_string(FileAccess.get_file_as_string(BASE + TIME + "/lights.json"))
	for L in arr:
		var g: Dictionary = L.g
		var l: Light3D
		match String(g.get("kind", "omni")):
			"omni":
				var o := _mk_omni(L, g.e, g.get("r", 4.0), g.get("size", 0.02))
				o.shadow_enabled = g.get("sh", 0) > 0; o.omni_attenuation = g.get("att", 1.6)
				l = o
			"spot":
				l = _mk_spot(L, g.e, g.get("ang", 30.0), g.get("size", 0.1), g.get("sh", 1) > 0)
				if g.has("satt"): (l as SpotLight3D).spot_angle_attenuation = g.satt   # a soft edge (blue_door: its hard rim was an oval on the front door, レビュー 試作65)
			"sun":
				var d := DirectionalLight3D.new()
				d.light_color = Color(L.color[0], L.color[1], L.color[2]).linear_to_srgb()
				d.light_energy = g.e; d.shadow_enabled = g.get("sh", 1) > 0; d.light_angular_distance = g.get("ang", 0.8)
				d.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS; d.directional_shadow_max_distance = 22.0
				add_child(d)
				var dir = b2g(L.dir)
				d.look_at_from_position(Vector3.ZERO, dir, Vector3.UP if abs(dir.y) < 0.95 else Vector3.FORWARD)
				l = d
			"bolt":
				l = _mk_spot(L, 0.0, 55.0, 1.0)
				lights.bolt = l
		if l == null: continue
		l.light_volumetric_fog_energy = g.get("fog", 1.0)
		if g.has("spec"): l.light_specular = g.spec
		l.set_meta("e", float(g.get("e", 0.0))); l.set_meta("flick", String(g.get("flick", "")))
		lights[L.name] = l

func _house_flicker(t: float, lt: float, p: Callable):
	var dip: float = 1.0 - 0.55 * p.call(lt, LIGHTNING_T + 0.15, 0.12) - 0.25 * p.call(lt, LIGHTNING_T + 0.4, 0.08)
	for k in lights:
		var l = lights[k]
		if not (l is Light3D) or not l.has_meta("flick"): continue
		var e: float = l.get_meta("e")
		match String(l.get_meta("flick")):
			"fres": l.light_energy = e * (1.0 + 0.03 * sin(t * 6.1) + 0.02 * sin(t * 17.3)) * dip
			"gen":
				# a bulb on the generator: it breathes with the engine, and at 20:00 the engine has only just caught
				var w: float = 0.05 if TIME == "t20" else 0.018
				l.light_energy = e * (1.0 + w * sin(t * 7.3) + w * 0.8 * sin(t * 23.1 + 1.0)) * dip
			"candle": l.light_energy = e * (1.0 + 0.08 * sin(t * 9.1) + 0.06 * sin(t * 15.7 + 2.0) + 0.04 * sin(t * 31.0))
			"batt": l.light_energy = e * (1.0 + 0.01 * sin(t * 3.0))

func _rain():
	var r := S.env_node.find_child("rain", true, false) as MeshInstance3D
	if r == null: return
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add;
uniform float toff = 0.0;
void vertex() { VERTEX.y -= mod((TIME + toff) * 7.5, 0.9); }
void fragment() { ALBEDO = vec3(0.32, 0.4, 0.55); ALPHA = 0.6; }
"""
	var m := ShaderMaterial.new(); m.shader = sh
	r.material_override = m; S["rain_mat"] = m

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
	if S.has("boxes"):   # the v4 house: boxes measured from the built meshes (house4.colliders), props from stage.py
		for b in S.boxes:
			if b.has("times") and not (TIME in b.times): continue   # the slip's edge: only once the shoulder has gone
			if b.has("door") and SCENE == "house": continue   # 試作90: in the whole house each leaf carries its own collision and turns with it (doors.gd)
			if b.has("ramp"):
				var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bx := BoxShape3D.new()
				bx.size = Vector3(b.s[0], b.s[2], b.s[1]); cs.shape = bx; sb.add_child(cs); add_child(sb)
				sb.global_position = b2g(b.c); sb.rotation.x = b.rx
			else:
				_box(b.c, b.s)
		for o in S.props:
			var s2 := StaticBody3D.new(); var c2 := CollisionShape3D.new(); var cy := CylinderShape3D.new()
			cy.radius = o[2]; cy.height = 2.0; c2.shape = cy; s2.add_child(c2); add_child(s2)
			s2.global_position = b2g([o[0], o[1], 1.0])
		if S.has("walk"):   # 段階2 外: the ground, the roads and the slip walk on their own meshes (outside.py WALK_MESHES)
			for mi in S.env_node.find_children("ext_*", "MeshInstance3D", true, false):
				if not mi.visible: continue
				var nm := String(mi.name)
				for w in S.walk:
					if nm == w or nm.begins_with(w + "_") or nm.begins_with(w + "."):
						mi.create_trimesh_collision(); break
		return
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
	var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.17; cap.height = 1.6
	cs.shape = cap; cs.position.y = 0.8
	player.wall_min_slide_angle = 0.0
	player.floor_max_angle = deg_to_rad(52.0)   # 段階2: the stairs are ramps (42° up, 39° down to the cellar)
	player.floor_snap_length = 0.35   # walking nearly head-on into a wall or a person slides along it instead of stopping (試作33「窮屈感」)
	player.add_child(cs)
	var head := Node3D.new(); head.name = "Head"; player.add_child(head)
	var cam := Camera3D.new(); cam.name = "Camera"; cam.fov = ARGS.get("fov", 62.0); cam.near = 0.05; head.add_child(cam)
	var attr := CameraAttributesPractical.new()
	cam.attributes = attr
	add_child(player)
	player.global_position = Vector3(-0.5, 0.0, -1.35)
	player.yaw = -0.25
	if S.has("spawn"):
		player.global_position = Vector3(S.spawn[0], 0.0, -S.spawn[1])
		player.yaw = -atan2(S.look[0] - S.spawn[0], S.look[1] - S.spawn[1])
	if SCENE == "house" and SET.has("house_pos"):   # T: the next time, standing where you stood
		player.global_position = SET.house_pos[0]; player.yaw = SET.house_pos[1]; player.pitch = SET.house_pos[2]
	if ARGS.has("noclip"): player.collision_layer = 0; player.collision_mask = 0; player.fly = true
	if ARGS.has("pose"):
		var q = ARGS["pose"]
		player.global_position = Vector3(q[0], 0.0, q[1]); player.yaw = deg_to_rad(q[2]); player.pitch = deg_to_rad(q[3])
		player.auto_path = [[0.0, q[0], q[1], q[2], q[3]], [99.0, q[0], q[1], q[2], q[3]]]
	if record == "walk":
		player.auto_path = [[0.0, -0.5, -1.35, -14.0, -6.0], [CARD_TIME + 1.0, -0.5, -1.35, -14.0, -6.0],
			[CARD_TIME + 6.5, -0.15, -3.0, -10.0, -10.0], [CARD_TIME + 8.0, -0.12, -3.2, 18.0, -4.0],
			[CARD_TIME + 11.0, 0.25, -3.5, 4.0, -3.0], [CARD_TIME + 14.0, 0.35, -3.9, 0.0, 2.0]]

# ------------------------------------------------------------------ print + card
const NIGHT_PRINT := {"t20": [0.2, 1.35], "t23": [0.45, 1.8], "t02": [0.45, 1.8], "t0330": [0.45, 1.8], "t0430": [0.45, 1.8]}
func _print_layer():
	var layer := CanvasLayer.new(); layer.layer = 10; add_child(layer)
	var r := ColorRect.new(); r.set_anchors_preset(Control.PRESET_FULL_RECT); r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	riso = ShaderMaterial.new(); riso.shader = load("res://shaders/riso2.gdshader" if PRINT_V == 2 else "res://shaders/riso.gdshader")
	riso.set_shader_parameter("exposure", PRINT_EXP[SCENE] if PRINT_V == 2 else 1.0)
	# 試作94 the night print (riso2 look=1): the whole house after dark. 夕方 and the two old scenes keep the print they had
	# (ユーザー OK 2026-11-10). [dodge, dodge_max]: 20時 is the blackout, so its darks are lifted less. --look=0 shoots the old print.
	if PRINT_V == 2 and SCENE == "house" and NIGHT_PRINT.has(TIME) and float(ARGS.get("look", 1.0)) > 0.5:
		riso.set_shader_parameter("look", 1.0)
		riso.set_shader_parameter("dodge", NIGHT_PRINT[TIME][0]); riso.set_shader_parameter("dodge_max", NIGHT_PRINT[TIME][1])
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
		var font: Font = Type.say()   # the imported resource (load_dynamic_font fell back to a system sans on Windows)
		var u: float = get_viewport().get_visible_rect().size.y / 1080.0
		note_label.add_theme_font_override("normal_font", font); note_label.add_theme_font_size_override("normal_font_size", int(24 * u))
		note_label.add_theme_color_override("default_color", Color(0.0, 0.2, 0.42))
		note.add_child(note_label)
		note.anchor_left = 0.0; note.anchor_top = 1.0; note.anchor_bottom = 1.0
		note.offset_left = 28 * u; note.offset_bottom = -24 * u; note.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var items := [
		["scene", ("家　" + String(TIME_LABEL.get(TIME, TIME))) if SCENE == "house" else ("第一章 夕方" if SCENE == "dusk" else "第二章 夜")],
		["cam", "カメラ " + player.CAM_MODES[player.cam_mode]],
		["gi", "照り返し " + GI_NAMES[gi_mode]],
		["ht", "網点 " + ("全体" if ht_mode == 0 else "中心だけ細かく")],
		["print", "刷り " + (("二版" if PRINT_V == 2 else "初版") if print_on else "なし")],
		["exp", "刷りの明るさ %.2f" % PRINT_EXP[SCENE] if PRINT_V == 2 else "刷りの明るさ －"],
		["q", "画質 " + ("高" if quality_high else "低")]]
	if SCENE == "dusk":
		items.append(["sun", "太陽 %.2f" % DUSK_K.sun]); items.append(["sky", "戸口の空 %.2f" % DUSK_K.sky]); items.append(["key", "フレネル %.2f" % DUSK_K.key])
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

# Chapter cards (2026-11-02, after the user's "タランティーノっぽく"): a chapter door is the night print's darkest ink
# laid flat, the paper showing through in the letters, centred: the chapter's number small, its name large in brackets,
# the interviewer's question under it. It cuts in and cuts out, no fade. A time card ("二十三時") is the same ground
# with one small line. The card after a scene that the interviewer asks about (door.gd) is not a chapter door but
# an exchange, set as the transcript's rows: left-aligned, the question in brackets, Mio's line under it.
const CARD_BG := Color(0.071, 0.165, 0.133)
const CARD_INK := Color(0.925, 0.90, 0.84)
const CARD_GHOST := Color(0.16, 0.43, 0.67, 0.2)   # the blue plate, a little off register
const CARD_GRAIN := """shader_type canvas_item;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() { float n = h(floor(FRAGCOORD.xy)); COLOR = vec4(vec3(step(0.5, n)), 0.09 * abs(n - 0.5) * 2.0); }
"""

# rows: [text, size at 1080p, gap after] centred, or [text, size, gap, speaker] as an exchange (centred = false)
static func make_card(parent: Node, rows: Array, font: Font, centred := true) -> ColorRect:
	var layer := CanvasLayer.new(); layer.layer = 14; parent.add_child(layer)   # over the transcript (13) and the keys (12)
	var vs: Vector2 = parent.get_viewport().get_visible_rect().size
	var u: float = vs.y / 1080.0
	var c := ColorRect.new(); c.color = CARD_BG
	c.set_anchors_preset(Control.PRESET_FULL_RECT); c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(c)
	var total := 0.0
	var small := font
	for r in rows: total += font.get_height(int(r[1] * u)) + r[2] * u
	var y: float = (vs.y - total) / 2.0
	for r in rows:
		var fs := int(r[1] * u)
		var name: bool = centred and r[1] >= Type.TITLE_FROM   # a chapter's name: lighter, no brackets, 長体 (docs/フォント設計.md)
		font = Type.title(fs) if name else small
		var h: float = small.get_height(fs)
		var x := 0.0
		if not centred:
			x = 420.0 / 1920.0 * vs.x
			if String(r[0]).begins_with("「"): x -= fs * 0.45          # the bracket hangs into the margin
			if r.size() > 3 and r[3] != "":
				var sp := _card_label(String(TranslationServer.translate(String(r[3]))).replace("\u200b", ""), int(34 * u), font, CARD_INK * Color(1, 1, 1, 0.85))
				sp.position = Vector2(300.0 / 1920.0 * vs.x, y + h - font.get_height(int(34 * u)) - 6 * u)
				c.add_child(sp)
		for k in 2:
			var lb := _card_label(String(TranslationServer.translate(String(r[0]))).replace("\u200b", ""), fs, font, CARD_GHOST if k == 0 else CARD_INK)
			if centred: lb.size.x = vs.x; lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lb.position = Vector2(x, y) + (Vector2(-3, 4) * u if k == 0 else Vector2.ZERO)
			if name:
				lb.position.x += Type.TITLE_TRACK * fs * 0.5          # the tracking after the last letter is not part of the word
				lb.pivot_offset = Vector2(vs.x / 2.0, 0); lb.scale.x = Type.TITLE_SQUEEZE
			c.add_child(lb)
		y += h + r[2] * u
	var grain := ColorRect.new(); grain.set_anchors_preset(Control.PRESET_FULL_RECT); grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new(); sh.code = CARD_GRAIN
	var gm := ShaderMaterial.new(); gm.shader = sh; grain.material = gm
	c.add_child(grain)
	return c

static func _card_label(text: String, fs: int, font: Font, col: Color) -> Label:
	var lb := Label.new(); lb.text = text
	lb.add_theme_font_override("font", font); lb.add_theme_font_size_override("font_size", fs)
	lb.add_theme_color_override("font_color", col)
	return lb

var foot: Label
func _card():
	var font: Font = Type.say()
	var u: float = get_viewport().get_visible_rect().size.y / 1080.0
	var rows := [["二十三時", 52, 0]]
	if SCENE == "house": rows = [[String(TIME_LABEL.get(TIME, TIME)), 52, 0]]
	if SCENE == "dusk" or play == "ch1": rows = [["第 一 章", 46, 40], ["ルール", 150, 90], ["あの別荘には、どうして行ったんですか？", 36, 0]]
	card = make_card(self, rows, Type.card())
	# the keys: not on the card (the card is the interviewer's), but along the top once the scene has begun
	var layer := CanvasLayer.new(); layer.layer = 12; add_child(layer)
	foot = Label.new()
	foot.text = "ＷＡＳＤ 移動　マウス 視点　Ｎ 場面（夕方／夜）　Ｃ カメラのコマ　Ｇ 照り返し　１／２ 網点　Ｑ 画質　Ｐ 刷り　Ｖ 刷りの版　－／＝ 刷りの明るさ　Ｈ 設定表示の固定　Ｅｓｃ マウス解放"
	if SCENE == "house" and play == "": foot.text = "ＷＡＳＤ 歩く　マウス 見る　Ｔ 時刻　Ｎ 場面　Ｇ 照り返し　Ｐ 刷り　－／＝ 刷りの明るさ　Ｆ１２ 画面の保存　Ｅｓｃ マウス解放"
	elif door_scene: foot.text = "ＷＡＳＤ 歩く　マウス 見る　　Ｎ 場面　Ｆ１２ 画面の保存　Ｅｓｃ マウス解放"
	elif story: foot.text = "ＷＡＳＤ 歩く　マウス 見る　Ｅ（左クリック） 調べる・話す・次へ　Ｗ／Ｓ 言葉を選ぶ　Tab 絵コンテ　右クリック（押したまま） カメラをのぞく　　Ｎ 場面　Ｆ１２ 画面の保存　Ｅｓｃ マウス解放"
	foot.add_theme_font_override("font", font); foot.add_theme_font_size_override("font_size", int(18 * u))
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_theme_color_override("font_color", CARD_INK)
	Type.soft(foot, u)
	foot.anchor_left = 0.05; foot.anchor_top = 0.025; foot.anchor_right = 0.95; foot.anchor_bottom = 0.1
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.text = String(TranslationServer.translate(foot.text)).replace("\u200b", "")
	# break only between keys (at the full-width spaces), never inside "Ｅｓｃ マウス解放"
	var fw := (0.95 - 0.05) * get_viewport().get_visible_rect().size.x
	var fl := ""; var fout := ""
	for item in foot.text.split("　", false):
		var cand: String = item if fl == "" else fl + "　" + item
		if fl != "" and font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * u)).x > fw:
			fout += fl + "\n"; fl = item
		else: fl = cand
	foot.text = fout + fl
	foot.autowrap_mode = TextServer.AUTOWRAP_OFF
	layer.add_child(foot)
	foot.visible = false

# ------------------------------------------------------------------ time
func _process(dt):
	var t: float = Time.get_ticks_msec() / 1000.0 - t0
	_shadow_budget(dt)
	# a movie, or an unattended run without a screen (--frameclock, godot --headless --fixed-fps 24): the clock is the frames,
	# counted from this scene's start (the playthrough goes from scene to scene)
	if Engine.get_write_movie_path() != "" or ARGS.has("frameclock"): t = float(Engine.get_process_frames() - f0) / float(ARGS.get("mfps", 24.0))
	if ARGS.has("shots"):
		t = _shot_tick()
		if t < 0.0: return
	if SCENE == "house" and S.has("walk"): _outside_fog(dt)
	if not walkers.is_empty(): _walk_tick(dt)
	if not torches.is_empty(): _aim_torches()
	if not carried.is_empty(): _carry_tick()
	if ARGS.has("at"): t += float(ARGS.at)   # check stills: start the clock at this loop time, so a moment can be shot in seconds
	_update_faces(t, fmod(max(t - CARD_TIME, 0.0), LOOP))
	card.visible = t < CARD_TIME
	if foot:
		foot.visible = t >= CARD_TIME and t < CARD_TIME + 12.0 and record == ""
		foot.modulate.a = clamp((CARD_TIME + 12.0 - t) / 2.0, 0.0, 1.0)
	player.input_enabled = t > CARD_TIME - 0.4
	var lt: float = fmod(max(t - CARD_TIME, 0.0), LOOP)
	if t < CARD_TIME:
		for ap in anims: ap.seek(0.0, true)
	if ARGS.has("chklight") and float(ARGS.chklight) > 0.0 and not S.has("chklight"):
		var cl := OmniLight3D.new(); cl.light_energy = float(ARGS.chklight); cl.omni_range = 2.5; cl.shadow_enabled = false
		player.get_node("Head").add_child(cl); S["chklight"] = true
	if ARGS.has("at") and not S.has("at_seeked"):
		S["at_seeked"] = true
		for ap in anims: ap.seek(lt, true)
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
	if SCENE == "house": _house_flicker(t, lt, p)
	if lights.has("fres"):
		var dip: float = 1.0 - 0.55 * p.call(lt, LIGHTNING_T + 0.15, 0.12) - 0.25 * p.call(lt, LIGHTNING_T + 0.4, 0.08)
		lights.fres.light_energy = 9.0 * (1.0 + 0.03 * sin(t * 6.1) + 0.02 * sin(t * 17.3)) * dip
	if ARGS.has("shots"): pass
	elif ARGS.has("poses"):
		var hold: float = float(ARGS.get("hold", "1.5"))
		var idx := int((t - float(ARGS.get("at", "0"))) / hold)
		if idx >= ARGS["poses"].size(): get_tree().quit()
		elif idx != S.get("pose_idx", -1):
			S["pose_idx"] = idx
			var q = ARGS["poses"][idx]
			player.global_position = Vector3(q[0], 0.0, q[1]); player.yaw = deg_to_rad(q[2]); player.pitch = deg_to_rad(q[3])
			if q.size() > 4: player.eye_height = q[4]; (player.get_node("Head") as Node3D).position.y = q[4]
			player.auto_path = [[0.0, q[0], q[1], q[2], q[3]], [99.0, q[0], q[1], q[2], q[3]]]; player.auto_t = 0.0
	elif record != "" and t > CARD_TIME + 15.0: get_tree().quit()

# Several check stills from one start of the game (the start is most of the time of a still). Each shot gets the frames a
# fresh run would have had: the same clock (frames counted from its own start), the print's and the rain's shader time
# moved back by the frames before it, the anims seeked again, a new player body (made on the last, unused frame of the
# shot before, so the physics before the pose is a fresh run's) and the fog's temporal history dropped (fog off on that
# same unused frame). Returns the clock, or -1 when done.
func _minicam_dbg():
	# where story.gd sets the little camera down at the start (on the shoe cupboard); the old one (boxes) 13 cm to its right (both on the apple box)
	var at := b2g([-0.60, 3.85, 0.272])
	var ps: PackedScene = load("res://props/minicam.glb")
	if ps:
		var m3: Node3D = ps.instantiate(); add_child(m3); m3.global_position = at + Vector3(0, 0.025, 0); m3.rotation.y = 0.6
	var sil := StandardMaterial3D.new(); sil.albedo_color = Color(0.62, 0.62, 0.6); sil.roughness = 0.35; sil.metallic = 0.5
	var blk := StandardMaterial3D.new(); blk.albedo_color = Color(0.08, 0.08, 0.09); blk.roughness = 0.5
	var old := Node3D.new(); add_child(old); old.global_position = at + Vector3(0.13, 0, 0.0); old.rotation.y = 0.6
	for q in [[Vector3(0.055, 0.065, 0.115), Vector3.ZERO, sil], [Vector3(0.006, 0.05, 0.068), Vector3(-0.031, 0.002, -0.006), sil], [Vector3(0.03, 0.04, 0.03), Vector3(0, -0.052, 0), blk]]:
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = q[0]; mi.mesh = bm; mi.position = q[1]; mi.material_override = q[2]; old.add_child(mi)
	var cy := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.021; cm.bottom_radius = 0.023; cm.height = 0.035; cy.mesh = cm
	cy.material_override = blk; cy.position = Vector3(0, 0.004, -0.072); cy.rotation = Vector3(PI / 2, 0, 0); old.add_child(cy)

func _camcorder_lcd():
	# the crew's camcorder (blender/camcorder.py): its flip-out screen shows ● REC and the tape running. In the world,
	# small (7 cm), read only up close. The counter starts where the night has got to (LP, a 90-minute tape)
	var found := find_children("lcd*", "MeshInstance3D", true, false)
	if found.is_empty(): return
	var mi: MeshInstance3D = found[0]
	var arr = mi.mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var gt := mi.global_transform
	var a := gt * vs[0]; var b := gt * vs[1]; var c := gt * vs[2]
	var n := (b - a).cross(c - a).normalized()
	var ctr := Vector3.ZERO
	for v in vs: ctr += gt * v
	ctr /= vs.size()
	# the screen's own normal (it faces back, to the one filming: the side away from the body was wrong once it did)
	var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	if nrm.size() > 0 and n.dot(gt.basis * nrm[0]) < 0: n = -n
	var up := Vector3.UP - n * n.dot(Vector3.UP); up = up.normalized()
	var lab := Label3D.new()
	lab.font = Type.cam(); lab.pixel_size = 0.000125; lab.font_size = 48; lab.outline_size = 0   # the camera's own type (DotGothic16 at three times its grid)
	lab.modulate = Color(0.92, 0.92, 0.88); lab.shaded = false; lab.double_sided = false
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(lab)
	lab.global_transform = Transform3D(Basis(up.cross(n), up, n), ctr + n * 0.0015 + up * 0.016)
	var base: float = {"night": 2465.0, "dusk": 252.0}.get(SCENE, 0.0)
	if SCENE == "house": base = {"dusk": 252.0, "t20": 1000.0, "t23": 2465.0, "t02": 3757.0, "t0330": 4438.0, "t0430": 4880.0}.get(TIME, 0.0)
	var t := [base]
	get_tree().process_frame.connect(func():
		t[0] += get_process_delta_time()
		var s := int(t[0])
		var dot: String = "●" if fmod(t[0], 1.0) < 0.6 else "  "
		lab.text = "%s REC  %d:%02d:%02d" % [dot, s / 3600, (s / 60) % 60, s % 60])

func _wear():
	# 段階2 室内の質感（試作57）: years of use, as Decals placed from the plan (blender/wear.py): grime along the skirting,
	# hands on the door jambs, the floor worn through the doorways, damp streaks under the windows, old leaks on the
	# ceilings. Images from blender/wear_tex.py. Nothing re-baked: the lightmaps and the pack stay as they were
	if ARGS.has("nowear") or not S.has("wear"): return
	var tex := {}
	for d in S.wear:
		var k: String = d.k
		if not tex.has(k): tex[k] = load("res://assets/wear/%s.png" % k)
		var dc := Decal.new()
		dc.texture_albedo = tex[k]
		dc.size = Vector3(d.s[0], d.s[2], d.s[1])   # x along the image's width, y the projection's depth, z its height
		dc.normal_fade = 0.4                         # not smeared down the sides of casings and stools
		var n := b2g(d.n).normalized(); var u := b2g(d.u).normalized()
		var z: Vector3
		if absf(n.y) > 0.9: z = n.cross(u).normalized()   # floor or ceiling: the image's height across the opening
		else: z = Vector3(0, -1, 0)                       # a wall: the image's top up
		var x := n.cross(z).normalized()
		dc.transform = Transform3D(Basis(x, n, z), b2g(d.c))
		if ARGS.has("weardbg"): dc.modulate = Color(1, 0, 0); dc.texture_emission = tex[k]; dc.emission_energy = 40.0
		add_child(dc)
	print("WEAR ", S.wear.size())

func _window_glass():
	# 段階2 室内の質感: the panes were opaque grey (glTF's transmission comes in as a solid surface), so every window read
	# as a blank card (and printed as paper). Now old, faintly dirty clear glass: the sugi and the sky outside show through
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08; m.metallic_specular = 0.6
	# years of dust and dried rain on the outside: streaks running down, thicker toward the sill (a noise stretched
	# tall, through a ramp from clear to grey film)
	var nz := FastNoiseLite.new(); nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH; nz.frequency = 0.03; nz.fractal_octaves = 4; nz.seed = 7
	var tex := NoiseTexture2D.new(); tex.width = 256; tex.height = 256; tex.seamless = true; tex.noise = nz
	var g := Gradient.new()
	g.set_color(0, Color(0.55, 0.58, 0.57, 0.04)); g.set_color(1, Color(0.62, 0.6, 0.55, float(ARGS.get("glassd", 0.38))))
	g.add_point(0.55, Color(0.56, 0.58, 0.56, 0.1))
	tex.color_ramp = g
	m.albedo_texture = tex; m.albedo_color = Color(1, 1, 1, 1)
	m.uv1_scale = Vector3(3.0, 0.6, 1.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for mi in S.env_node.find_children("winglass*", "MeshInstance3D", true, false):
		mi.material_override = m; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _outside_fog(dt: float):
	# no haze in the house; out of it, distance fades the woods (eased over a few metres from the walls)
	var h0: Array = S.gi_box[0]; var h1: Array = S.gi_box[1]
	var p: Vector3 = player.global_position
	var bx: float = p.x; var by: float = -p.z
	var dx: float = max(max(h0[0] - bx, bx - h1[0]), 0.0); var dy: float = max(max(h0[1] - by, by - h1[1]), 0.0)
	var k: float = clamp(sqrt(dx * dx + dy * dy) / 4.0, 0.0, 1.0)
	env.fog_density = float(ARGS.get("fogd", 0.006)) * k

func _shot_tick() -> float:
	var per: int = ARGS.get("shotframes", 12)
	var F: int = Engine.get_process_frames()
	if not S.has("shot_f0"):
		S["shot_f0"] = F; print("SHOTS ", ARGS["shots"].size())   # close.py looks for this: an older pck ignores --shots
	var idx: int = (F - int(S.shot_f0)) / per
	if idx >= ARGS["shots"].size():
		get_tree().quit(); return -1.0
	var k: int = F - idx * per   # the frame count a fresh run of this shot would have (its start frames included)
	if idx != S.get("shot_idx", -1):
		S["shot_idx"] = idx
		var q = ARGS["shots"][idx]
		ARGS["at"] = str(q[5]); S.erase("at_seeked")
		player.global_position = Vector3(q[0], q[6] if q.size() > 6 else 0.0, q[1]); player.yaw = deg_to_rad(q[2]); player.pitch = deg_to_rad(q[3])   # q[6]: where the body stands (outside, on the slope)
		player.eye_height = q[4]; (player.get_node("Head") as Node3D).position.y = q[4]
		player.auto_path = [[0.0, q[0], q[1], q[2], q[3]], [99.0, q[0], q[1], q[2], q[3]]]; player.auto_t = 0.0
		var off: float = -float(idx * per) / 24.0
		if riso: riso.set_shader_parameter("time_offset", off)
		if S.has("rain_mat"): S.rain_mat.set_shader_parameter("toff", off)
		if S.has("shot_fog"): env.volumetric_fog_enabled = S.shot_fog
	if not S.has("shot_fog"): S["shot_fog"] = env.volumetric_fog_enabled
	if F - int(S.shot_f0) - idx * per == 9: S["shot_p9"] = player.global_position
	if F - int(S.shot_f0) - idx * per == 10:   # the frame close.py keeps: is the camera (the player) still moving?
		var p: Vector3 = player.global_position
		var m: float = (p - S.shot_p9).length()
		print("SHOTPOS ", idx, " ", p.x, " ", p.y, " ", p.z, " ", 1 if player.is_on_floor() else 0, " ", m)
	if F - int(S.shot_f0) - idx * per == per - 1 and idx + 1 < ARGS["shots"].size():
		# a new body at the spawn point, so the next shot's physics starts as a fresh run's does (the camera is the
		# player: where walls push it and how it falls back depends on the body's state)
		var cam_mode = player.cam_mode
		remove_child(player); player.free(); _player(); player.cam_mode = cam_mode; S.erase("chklight")
		if not ARGS.has("shotkeepfog"): env.volumetric_fog_enabled = false
	return float(k) / 24.0


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
				if perf and is_instance_valid(perf): perf.user_chose(quality_high)
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
				SCENE = {"dusk": "night", "night": "house", "house": "dusk"}.get(SCENE, "dusk") if ResourceLoader.exists("res://assets/house/scene.json") else ("dusk" if SCENE == "night" else "night")
				get_tree().reload_current_scene()
			KEY_T:
				if SCENE == "house":   # 段階2: the next time of the night, in the same house, from where you stand
					_save_settings()
					var ts: Array = S.times
					TIME = ts[(ts.find(TIME) + 1) % ts.size()]
					SET["house_pos"] = [player.global_position, player.yaw, player.pitch]
					get_tree().reload_current_scene()
			KEY_7, KEY_8, KEY_9, KEY_0, KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
				if SCENE == "dusk":
					var which := "sun" if e.keycode in [KEY_7, KEY_8] else ("sky" if e.keycode in [KEY_9, KEY_0] else "key")
					var down: bool = e.keycode in [KEY_7, KEY_9, KEY_BRACKETLEFT]
					DUSK_K[which] = clamp(DUSK_K[which] * (0.8 if down else 1.25), 0.05, 8.0)
					if which == "sun" and lights.has("sun"): lights.sun.light_energy = DUSK_BASE.sun * DUSK_K.sun
					if which == "sky" and lights.has("doorsky"): lights.doorsky.light_energy = DUSK_BASE.sky * DUSK_K.sky
					if which == "key" and lights.has("fres_d"): lights.fres_d.light_energy = DUSK_BASE.key * DUSK_K.key
					_status(which)
			KEY_F12:
				# a screenshot next to the exe, named with where the player stands, so the same view can be taken again
				var img := get_viewport().get_texture().get_image()
				var p: Vector3 = player.global_position; var t: float = Time.get_ticks_msec() / 1000.0
				var name := "shot_%s_x%.2f_z%.2f_yaw%.0f_pitch%.0f_t%.1f.png" % [SCENE if SCENE != "house" else "house-" + TIME, p.x, p.z, rad_to_deg(player.yaw), rad_to_deg(player.pitch), t]
				if SCENE == "house": name = name.replace(".png", "_y%.2f.png" % p.y)
				if SCENE == "dusk":   # the dusk light set with 7/8, 9/0, [ ] goes into the name, to become the defaults
					name = name.replace(".png", "_sun%.2f_sky%.2f_key%.2f.png" % [DUSK_K.sun, DUSK_K.sky, DUSK_K.key])
				var dir := OS.get_executable_path().get_base_dir() if OS.has_feature("template") else ProjectSettings.globalize_path("user://")
				img.save_png(dir.path_join(name)); _status("")
			KEY_F11:
				var w := get_window()
				w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN or w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

# 段階1: the first take starts and the power goes. The film light and the bulb die; the sunset in the door stays.
func power_cut(dark := true):
	for k in ["fres_d", "lamp", "refl"]:
		if lights.has(k): lights[k].visible = false
	if SCENE == "house":   # 試作97: 第1章 in the whole house: the key light and every lamp of the house
		for k in lights:
			if lights[k] is Light3D and (k == "fresnel_key" or String(k).begins_with("lamp_")): lights[k].visible = false
	for mm in lm_mats: mm.set_shader_parameter("bounce", float(ARGS.get("lme", str(S.get("lme", 1.5)))) * 0.45 if gi_mode == 0 else 0.0)
	# 試作89 (ユーザー「そこで、電気が消えたんです。のところ、真っ暗になるのがよくない？」): the eye goes black with the lights,
	# through her testimony line and the chapter card; it opens again, slowly, as chapter 2 begins (power_eyes_open)
	if env and dark: create_tween().tween_property(env, "tonemap_exposure", 0.0, 0.12)

func power_eyes_open():
	if env: create_tween().tween_property(env, "tonemap_exposure", 1.0, 2.5).set_ease(Tween.EASE_OUT)

static var SCENES_RUN := 0        # how many scenes this run has started (the frame clock starts again with each)
var f0 := 0
static var CH2 := false            # 試作91: the house was reached from 第1章's power cut (第2章 runs in it, at 20:00)
var ch2_house := false
static var FROM_STORY := false     # 段階1: the night was reached by playing (the door scene runs), not by N

func to_house_ch2():
	_save_settings()
	SCENE = "house"; TIME = "t20"; CH2 = true
	get_tree().reload_current_scene()

# 試作91: the people at 20:00 (blender/export_t20.py). Each 第1章 body plays the 20:00 movement (<k>_t20.glb: the same
# rig, a phone in the right hand); the phone gets a small torch, the body a column the player cannot walk through.
var T20 := {}
func _t20_people():
	T20 = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dusk/t20.json"))
	for k in CHARS:
		if not ResourceLoader.exists("res://assets/dusk/%s_t20.glb" % k): continue
		_load_scene("res://assets/dusk/%s.glb" % k, k)
		var inst: Node3D = S[k + "_node"]
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			if String(mi.name).begins_with("carrybox") or String(mi.name).begins_with("taperoll"): mi.visible = false
		var mv: Node = (load("res://assets/dusk/%s_t20.glb" % k) as PackedScene).instantiate()
		var src: AnimationPlayer = mv.find_children("*", "AnimationPlayer", true, false)[0]
		var an: Animation = src.get_animation(src.get_animation_list()[0]).duplicate()
		an.loop_mode = Animation.LOOP_LINEAR
		var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
		for ap in inst.find_children("*", "AnimationPlayer", true, false):
			ap.stop(); sk.reset_bone_poses()
			var lib := AnimationLibrary.new(); lib.add_animation("loop", an); ap.add_animation_library("t20", lib); ap.play("t20/loop")
		for ba in mv.find_children("*", "BoneAttachment3D", true, false):
			# 試作97: the phone and its screen come in as bones of their own (k_t20phone, _scr: glTF made the hand's mesh
			# children into bones). Moved onto the body's skeleton their index pointed at lowerarm_twist_r and neck_01: the
			# screen stood out of the back of the neck (ユーザー「首の後ろに変な出っ張り」「スマホを持ってない」).
			# Hang it from the nearest bone the body has, by the rest offsets up to it.
			var msk := ba.get_parent() as Skeleton3D
			var off := Transform3D.IDENTITY; var bi: int = ba.bone_idx
			while msk and bi >= 0 and sk.find_bone(msk.get_bone_name(bi)) < 0:
				off = msk.get_bone_rest(bi) * off; bi = msk.get_bone_parent(bi)
			ba.get_parent().remove_child(ba); ba.owner = null
			for c in ba.find_children("*", "", true, false): c.owner = null
			if msk and bi >= 0:
				ba.bone_name = msk.get_bone_name(bi)
				for c in ba.get_children():
					if c is Node3D: (c as Node3D).transform = off * (c as Node3D).transform
			sk.add_child(ba)
			if msk and bi >= 0: ba.bone_idx = sk.find_bone(ba.bone_name)   # the index wins over the name when it binds
			# the torch on the phone's back, the screen's glow toward the face: which side the screen is on comes from where
			# its plane sits on the body's thin axis (export_t20 bakes the phone into the hand bone's frame)
			var body: MeshInstance3D = null; var scr: MeshInstance3D = null
			for mi2 in ba.find_children("*", "MeshInstance3D", true, false):
				if String(mi2.name).ends_with("_scr"): scr = mi2
				else: body = mi2
			if body == null: continue
			var bb: AABB = body.get_aabb(); var c: Vector3 = bb.get_center()
			var ax := 1
			if bb.size.x < bb.size.y and bb.size.x < bb.size.z: ax = 0
			elif bb.size.z < bb.size.y: ax = 2
			var n := Vector3.ZERO; n[ax] = 1.0
			if scr and (scr.get_aabb().get_center() - c)[ax] > 0.0: n = -n   # n: out of the back
			var up := Vector3.UP if abs(n.y) < 0.9 else Vector3.RIGHT
			var sp := SpotLight3D.new(); sp.name = "torch"
			sp.light_color = Color(0.86, 0.92, 1.0); sp.light_energy = 3.0; sp.spot_range = 8.0; sp.spot_angle = 34.0   # 試作97: 2.0; with the bulbs dark until the generator, the torches are the light (ユーザー「地下への階段真っ暗すぎる」)
			sp.spot_attenuation = 1.0; sp.spot_angle_attenuation = 1.6; sp.shadow_enabled = true; sp.light_volumetric_fog_energy = 2.0   # 試作98 (ユーザー「スマホから発電機の間に光がない」): 0.25 left no beam in the haze
			sp.light_specular = 0.2
			sp.transform = body.transform * Transform3D(Basis.looking_at(n, up), c + n * 0.01)
			ba.add_child(sp)
			sp.add_child(_torch_beam(sp))
			torches.append([sp, sk])
			# the screen's own glow on the face that reads it (the night scene's phones: shot.py nphone_light)
			var gl := OmniLight3D.new(); gl.name = "screen"; gl.light_color = Color(0.8, 0.88, 1.0); gl.light_energy = 0.025   # 試作97: 0.5 / 1.0 m (and still 0.12 / 0.6 m) lit the whole of Natsuki and Makoto white (ユーザー「白く飛びすぎ」)
			gl.omni_range = 0.45; gl.omni_attenuation = 1.4; gl.shadow_enabled = false; gl.light_volumetric_fog_energy = 0.0; gl.light_specular = 0.05
			gl.position = body.transform * (c - n * 0.06)
			ba.add_child(gl)
		mv.free()
		_walk_anims(k, inst)
		var col := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new()
		cy.radius = 0.2; cy.height = 1.8; cs.shape = cy; cs.position.y = 0.9; col.add_child(cs); add_child(col)
		S[k + "_col"] = col
		place_person(k, T20[k].pos, T20[k].yaw)

# 試作97: in the dark they hold the phone's torch down on the floor ahead of their feet, not out at the others: straight
# out from the chest it lit Natsuki and Makoto white from behind Taiga (ユーザー「白く飛びすぎ」)
var torches := []              # [SpotLight3D, Skeleton3D]
const TORCH_DOWN := 32.0
# 試作98 (ユーザー「スマホのライトで発電機を照らしているのに、スマホから発電機の間に光がない」): the beam in the air.
# The haze's own beam (light_volumetric_fog_energy) is too coarse for a phone's 5 mm lens, and gone at 低: a faint cone
# that adds light, fades along its length and where it meets a surface
func _torch_beam(sp: SpotLight3D) -> MeshInstance3D:
	var L := 2.6
	var cm := CylinderMesh.new(); cm.top_radius = 0.008; cm.bottom_radius = L * tan(deg_to_rad(sp.spot_angle * 0.55))
	cm.height = L; cm.radial_segments = 20; cm.rings = 1; cm.cap_top = false; cm.cap_bottom = false
	var mi := MeshInstance3D.new(); mi.name = "beam"; mi.mesh = cm
	mi.rotation.x = PI / 2; mi.position = Vector3(0, 0, -L / 2)   # its narrow end at the lens, along the spot's -Z
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var gt := GradientTexture2D.new(); var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1)); gr.set_color(1, Color(0, 0, 0)); gr.add_point(0.35, Color(0.45, 0.45, 0.45))
	gt.gradient = gr; gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(0, 1); gt.width = 4; gt.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED; m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_texture = gt; m.albedo_color = Color(0.07, 0.075, 0.085)
	m.proximity_fade_enabled = true; m.proximity_fade_distance = 0.25
	mi.material_override = m
	return mi

func _aim_torches():
	for e in torches:
		var sp = e[0]
		if not is_instance_valid(sp) or not (sp as SpotLight3D).is_visible_in_tree(): continue
		var f: Vector3 = (e[1] as Skeleton3D).global_basis * Vector3(0, 0, 1); f.y = 0.0
		if f.length() < 0.01: continue
		var a := deg_to_rad(TORCH_DOWN)
		(sp as SpotLight3D).global_basis = Basis.looking_at(f.normalized() * cos(a) + Vector3.DOWN * sin(a), Vector3.UP)

# 試作92: people walk (export_walk.py: Mixamo's legs on our rigs, the phone arm ours). walk.json: per person and clip,
# the ground speed (m/s, along the floor) the feet were made for
var WALKJ := {}
var walkers := {}              # k -> {"pts": [Vector3], "i": int, "mode": String, "done": Callable}
func _walk_anims(k: String, inst: Node):
	var p := "res://assets/dusk/%s_walk.glb" % k
	if not ResourceLoader.exists(p): return
	if WALKJ.is_empty(): WALKJ = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dusk/walk.json"))
	var mv: Node = (load(p) as PackedScene).instantiate()
	var src: AnimationPlayer = mv.find_children("*", "AnimationPlayer", true, false)[0]
	var lib := AnimationLibrary.new()
	for nm in src.get_animation_list():
		var clip := String(nm).get_slice("_rig_", 1)
		if clip == "": continue
		var an: Animation = src.get_animation(nm).duplicate()
		an.loop_mode = Animation.LOOP_LINEAR if clip in ["walk", "up", "down"] else Animation.LOOP_NONE
		lib.add_animation(clip, an)
	for ap in inst.find_children("*", "AnimationPlayer", true, false): ap.add_animation_library("walk", lib)
	mv.free()

func _rig_of(k: String) -> Node3D:
	return S[k + "_node"].find_children("*", "Skeleton3D", true, false)[0].get_parent() as Node3D

# walk k through plan points [x, y, z] (plan metres; z the floor's height); done() when there
# 試作97 (ユーザー「大河、立ち姿が変。木材を持ってない」): the boards up from the cellar, carried as he carried the box at
# dusk (his 第1章 movement: both hands under it), the box made a bundle of old shelf boards; the phone in his pocket
var carried := {}
func carry_boards(k: String, on: bool):
	if not S.has(k + "_node"): return
	var inst: Node3D = S[k + "_node"]
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	if not carried.has(k):
		# where 第1章's box sat (export_dusk.py: 0.3 m before him, its middle 1.01 m up, 0.2 m tall): the planks lie on his palms
		var b := Node3D.new(); b.name = "boards_carried"
		sk.add_child(b)
		b.position = Vector3(0.0, 0.91, 0.3)
		var mat: Material = null
		for mi in S.env_node.find_children("board_*", "MeshInstance3D", true, false):
			mat = (mi as MeshInstance3D).get_active_material(0); if mat: break
		for i in 4:
			var pm := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.95 - i * 0.04, 0.022, 0.15)
			pm.mesh = bm; pm.material_override = mat
			pm.position = Vector3((i % 2) * 0.03 - 0.015, 0.011 + i * 0.023, (i % 2) * 0.01)
			pm.rotation.y = (i - 1.5) * 0.025
			b.add_child(pm)
		carried[k] = b
	(carried[k] as Node3D).visible = on
	for ba in sk.find_children("*", "BoneAttachment3D", true, false):
		if ba.find_child("torch", true, false): (ba as Node3D).visible = not on
	var dusk := ""
	for a in ap.get_animation_list():
		if not (a.begins_with("t20/") or a.begins_with("walk/")): dusk = a; break
	if on and dusk != "": ap.play(dusk, 0.5)
	elif not on: ap.play("t20/loop", 0.5)

# 試作98 (ユーザー「板、手との接合があってない」): the bundle rides on his palms, between the two hands, every frame
func _carry_tick():
	for k in carried:
		var b := carried[k] as Node3D
		if not b.visible: continue
		var sk: Skeleton3D = S[k + "_node"].find_children("*", "Skeleton3D", true, false)[0]
		var il := sk.find_bone("hand_l"); var ir := sk.find_bone("hand_r")
		if il < 0 or ir < 0: continue
		var hl: Vector3 = sk.global_transform * sk.get_bone_global_pose(il).origin
		var hr: Vector3 = sk.global_transform * sk.get_bone_global_pose(ir).origin
		var across := hr - hl; across.y = 0.0
		if across.length() < 0.05: continue
		var fwd := across.normalized().cross(Vector3.UP)
		if fwd.dot(sk.global_basis * Vector3(0, 0, 1)) < 0.0: fwd = -fwd
		# 2026-11-13 (ユーザー「大河の木の持ち方、まだ変」): not a tray across both hands but the bundle under the right arm, its length
		# along the way he walks (tilted a little, front end down), resting in the right hand
		var f := (sk.global_basis * Vector3(0, 0, 1)); f.y = 0.0
		if f.length() < 0.01: continue
		f = f.normalized()
		var x := (f * cos(deg_to_rad(-12.0)) + Vector3.UP * sin(deg_to_rad(-12.0))).normalized()
		var side := x.cross(Vector3.UP).normalized()
		b.global_basis = Basis(x, side, x.cross(side))   # the planks on edge, side by side against his flank
		b.global_position = hr + Vector3.UP * 0.08 - f * 0.05

func walk_to(k: String, plan_pts: Array, done := Callable(), end_yaw = null):
	if not S.has(k + "_node"): return
	var ap: AnimationPlayer = S[k + "_node"].find_children("*", "AnimationPlayer", true, false)[0]
	if not ap.has_animation("walk/walk"):   # no walk exported: the old way, there at once
		var q: Array = plan_pts[-1]; place_person(k, [q[0] - 4.8, 6.3 - q[1], q[2]], _rig_of(k).global_rotation.y)
		if done.is_valid(): done.call()
		return
	var pts := []
	for q in plan_pts: pts.append(b2g([q[0] - 4.8, 6.3 - q[1], q[2]]))
	walkers[k] = {"pts": pts, "i": 0, "mode": "", "done": done, "ap": ap, "yaw": end_yaw}

func _walk_tick(dt: float):
	for k in walkers.keys():
		var w: Dictionary = walkers[k]
		var rig := _rig_of(k)
		if w.i >= w.pts.size():   # there: turn to face where the stand faces, then done
			var y0 := rig.global_rotation.y
			var y1 := move_toward(y0, y0 + wrapf(float(w.yaw) - y0, -PI, PI), dt * 2.2)
			rig.global_transform = Transform3D(Basis(Vector3.UP, y1), rig.global_position)
			if absf(wrapf(float(w.yaw) - y1, -PI, PI)) < 0.01:
				walkers.erase(k)
				if w.done.is_valid(): w.done.call()
			continue
		var p := rig.global_position
		var seg: Vector3 = w.pts[w.i] - p
		var hz := Vector2(seg.x, seg.z).length()
		var mode := "walk"
		if hz > 0.01 and absf(seg.y) / hz > 0.4: mode = "up" if seg.y > 0.0 else "down"
		if mode != w.mode:
			w.mode = mode; (w.ap as AnimationPlayer).play("walk/" + mode, 0.3)
		var J: Dictionary = WALKJ.get(k, {}).get(mode, {})
		var v: float = float(J.get("speed", 1.0))
		if mode != "walk": v = 0.5 / float(J.get("dur", 1.0)) * 0.95   # a cycle is two treads of the house's stairs (25 cm and 23 cm deep): the feet land on them
		var step := v * dt
		if step >= hz:
			p = w.pts[w.i]; w.i += 1
		else:
			p += seg * (step / hz)
		var yaw := rig.global_rotation.y
		if hz > 0.05: yaw = lerp_angle(yaw, atan2(seg.x, seg.z), minf(1.0, dt * 5.0))
		rig.global_transform = Transform3D(Basis(Vector3.UP, yaw), p)
		(S[k + "_col"] as Node3D).global_position = p
		if w.i >= w.pts.size():
			var ap: AnimationPlayer = w.ap
			ap.play("t20/loop", 0.4)
			# the stand has no track for the hips' place: put them back where the stand has them
			var sk: Skeleton3D = S[k + "_node"].find_children("*", "Skeleton3D", true, false)[0]
			var bi := sk.find_bone("pelvis")
			get_tree().create_timer(0.45).timeout.connect(func(): if not walkers.has(k) or walkers[k].i >= walkers[k].pts.size(): sk.set_bone_pose_position(bi, sk.get_bone_rest(bi).origin))
			if w.yaw == null:
				walkers.erase(k)
				if w.done.is_valid(): w.done.call()

func walking(k: String) -> bool:
	return walkers.has(k)

func place_person(k: String, pos: Array, yaw: float):
	var sk: Skeleton3D = S[k + "_node"].find_children("*", "Skeleton3D", true, false)[0]
	var rig := sk.get_parent() as Node3D
	rig.global_transform = Transform3D(Basis(Vector3.UP, yaw), b2g(pos))
	(S[k + "_col"] as Node3D).global_position = b2g(pos)

# 試作91: the generator's circuit (the lobby bulb and the cellar's two): out until Mio starts it in 第2章
var gen_on := true
func generator(on: bool):
	gen_on = on
	for k in ["lamp_lobby", "lamp_cellar", "lamp_cellarw"]:
		if lights.has(k): lights[k].visible = on
	for mi in S.env_node.find_children("lampshade_*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if not (nm.contains("lamp_lobby") or nm.contains("lamp_cellar")): continue
		for i in range(mi.get_surface_override_material_count()):
			var m := mi.get_surface_override_material(i) as StandardMaterial3D
			if m:
				m.emission_enabled = on
				# 試作97: unlit, the white glass in a phone's light still read as a bulb that was on (ユーザー「地下の電気、発電機が掛かる前からついてた？」)
				if not m.has_meta("alb"): m.set_meta("alb", m.albedo_color)
				m.albedo_color = m.get_meta("alb") if on else (m.get_meta("alb") as Color) * Color(0.3, 0.3, 0.3, 1.0)
	var base := float(ARGS.get("lme", str(S.get("lme", 1.5))))
	# 試作97: the 20:00 lightmap holds only the generator's bulbs and the storm's sky: off, almost nothing is left of it
	for mm in lm_mats: mm.set_shader_parameter("bounce", (base if on else base * 0.04) if gi_mode == 0 else 0.0)

# ------------------------------------------------------------------ 試作97: one stage (ステップ C)
static var ONE := true
var play := ""                 # what the whole house carries besides its time: "ch1" (17:30) | "door" (23:00)

# what a chapter adds to the whole house comes out of the old scene's files: the people, where they stand (the
# columns), and the few things only that scene's env.glb has
func _bring(dir: String, things: Array):
	var J: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "scene.json"))
	for n in CHARS:
		if ResourceLoader.exists(dir + "%s.glb" % n): _load_scene(dir + "%s.glb" % n, n)
	# the columns: this scene's (people, tripod, lamp stand, box) instead of the house's own that stand near them
	var keep: Array = []
	for o in S.props:
		var near := false
		for q in J.props:
			if Vector2(o[0] - q[0], o[1] - q[1]).length() < 0.3: near = true
		if not near: keep.append(o)
	S.props = J.props + keep
	if J.has("knocks"): S["knocks"] = J.knocks
	if J.has("mark"): S["mark"] = J.mark
	if things.is_empty(): return
	# the things only the old scene's env.glb has (the reflector sways with Makoto: its movement is in that file's
	# AnimationPlayer, so the file is played as it is and everything else in it taken out)
	_load_scene(dir + "env.glb", "brought")
	var old: Node3D = S.brought_node
	for mi in old.find_children("*", "MeshInstance3D", true, false):
		var want := false
		for pre in things:
			if String(mi.name).begins_with(pre): want = true
		if not want: mi.free()
	for l in old.find_children("*", "Light3D", true, false): l.free()
	remove_child(old); S.env_node.add_child(old)   # story.gd and _rain look for these under the house

func _ch1_set():
	_bring("res://assets/dusk/", ["reflector"])
	# 2026-11-14（ユーザー「赤いランプ…光は1つでOK」）：桐生の大きいカメラの赤いランプ（recled と rec_light）は消す。
	# 赤いランプは、澪が置く小さいカメラの1つだけ（story.gd）
	if lights.has("rec") and lights.rec is Light3D: lights.rec.visible = false
	for mi in S.env_node.find_children("recled*", "MeshInstance3D", true, false): mi.visible = false
	# the low sun comes in through the front door onto Makoto and her reflector, as in the old scene, which had no woods:
	# the cedars throw no shadow in this chapter
	if not ARGS.has("sugishadow"):
		for mi in S.env_node.find_children("ext_sugi*", "MeshInstance3D", true, false): (mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 試作98 (ユーザー「木、一気に黒くなりすぎ？」, behind the house): the cedars in the house's long shadow had only the
	# ambient and went black at its edge. The dusk sky still lights them from above: a fill that only they get (layer 4)
	var sky_fill := DirectionalLight3D.new(); sky_fill.name = "sugi_sky"
	sky_fill.light_color = Color(0.78, 0.82, 0.95); sky_fill.light_energy = 0.45; sky_fill.shadow_enabled = false
	sky_fill.light_specular = 0.0; sky_fill.light_volumetric_fog_energy = 0.0; sky_fill.light_cull_mask = 4
	# 試作98 の感想（「色がぜんぜん違う」）: the cull mask does not reach the bounce. As a dynamic light it lit the whole
	# VoxelGI (x4) from the side and washed the house white. It lights the cedars directly and nothing else
	sky_fill.light_bake_mode = Light3D.BAKE_DISABLED; sky_fill.light_indirect_energy = 0.0
	sky_fill.rotation = Vector3(deg_to_rad(-25), deg_to_rad(200), 0)
	add_child(sky_fill)
	for mi in S.env_node.find_children("ext_sugi*", "MeshInstance3D", true, false): (mi as MeshInstance3D).layers |= 4
	# the camcorder on its tripod stands 23 cm nearer the stair at dusk (stage.TRIPOD_D / TRIPOD_N): Kiryu is behind it
	var moved: Array = []
	for mi in S.env_node.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if nm.begins_with("tpd_") or nm.begins_with("vcam_") or nm.begins_with("lcd") or nm.begins_with("recled"): moved.append(mi)
	for mi in moved:
		var under := false
		var pa: Node = mi.get_parent()
		while pa != null and pa != S.env_node:
			if pa in moved: under = true
			pa = pa.get_parent()
		if not under: (mi as Node3D).global_position += b2g([0.0, 4.47 - 4.70, 0.0])

func _door_set():
	_bring("res://assets/", ["rain", "cable"])

# ステップ D: on to a chapter that is played in the whole house at 3:30 ("ch4" | "ch11")
static var NEXT_PLAY := ""
const PLAY_TIME := {"ch0": "t0430", "ch1": "dusk", "h21": "t20", "ch4": "t0330", "ch11": "t0330"}
func to_chapter(p: String):
	_save_settings()
	SCENE = "house"; NEXT_PLAY = p
	get_tree().reload_current_scene()

func to_night(from_story := false):
	_save_settings()
	SCENE = "night"
	FROM_STORY = from_story
	get_tree().reload_current_scene()

# 試作92: the whole house was heavy. 3586 cedar meshes (14M of the 16M triangles) were drawn from every room, and
# again for each shadowed lamp. Inside, the house's own walls and floors now hide what is behind them (occlusion
# culling: one box per wall piece of scene.json, its window and door holes left open, so the woods still show through a
# window); far cedars cast no shadow. NOOCC=1 / --noocc for the old way.
func _house_cheaper():
	# --lite=…: the check movie on a machine without a GPU (a software renderer draws the 14 million triangles of the
	# cedars every frame). Letters: t no trees, f no volumetric fog, s only the sun and the nearest lamps throw shadows
	var lite := String(ARGS.get("lite", ""))
	if lite.contains("t"):
		for mi in S.env_node.find_children("ext_sugi*", "MeshInstance3D", true, false): mi.visible = false
	if lite.contains("f") and env: env.volumetric_fog_enabled = false
	if lite.contains("s"):
		for k in lights:
			if lights[k] is OmniLight3D: lights[k].shadow_enabled = false
	if ARGS.has("noocc"): return
	get_viewport().use_occlusion_culling = true
	var n := 0
	# 試作98 (ユーザー「外、このへん描画が崩れる」, by the back porch): the outside's unseen walls (the back stair's open
	# sides, the porch rail, the walls round where one may go) became occluders too, and hid the house and the woods
	# behind them: the sky showed where the foundation was. Only the house's own walls and floors hide things
	var g0: Array = S.gi_box[0] if S.has("gi_box") else [-1e9, -1e9]; var g1: Array = S.gi_box[1] if S.has("gi_box") else [1e9, 1e9]
	for b in S.boxes:
		if b.has("door") or b.has("ramp") or b.has("times"): continue
		if b.c[0] < g0[0] or b.c[0] > g1[0] or b.c[1] < g0[1] or b.c[1] > g1[1]: continue
		var sz: Array = b.s
		var thin: float = minf(minf(sz[0], sz[1]), sz[2])
		var area: float = sz[0] * sz[1] * sz[2] / maxf(thin, 0.001)
		if thin > 0.2 or area < 0.25: continue   # walls and floors only, not furniture
		var oc := OccluderInstance3D.new(); var bo := BoxOccluder3D.new()
		bo.size = Vector3(sz[0], sz[2], sz[1]) * 0.98   # a hair inside the wall: never hides the wall's own face
		oc.occluder = bo; oc.position = b2g(b.c); add_child(oc); n += 1
	var far := 0
	for mi in S.env_node.find_children("ext_sugi*", "MeshInstance3D", true, false):
		if Vector2(mi.global_position.x, mi.global_position.z).length() > 28.0:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; far += 1
	# the lamps' shadows are drawn every frame over the whole joined house (env: 1.1M triangles, one object, never
	# culled by room), six times for each shadowed lamp: only lamps within 9 m of the eye cast shadows now
	var fl := 0
	for k in lights:
		var l = lights[k]
		if l is OmniLight3D or l is SpotLight3D:
			if not l.shadow_enabled: continue
			if (l is OmniLight3D and l.omni_range < 1.5): l.shadow_enabled = false; continue   # a glow of a metre throws no shadow worth six passes
			l.distance_fade_enabled = true; l.distance_fade_begin = 40.0; l.distance_fade_length = 5.0; l.distance_fade_shadow = 9.0; fl += 1
	print("house occluders %d, cedars without shadow %d, lamps with near shadows only %d" % [n, far, fl])

# 2026-11-13 重さ（scripts/perf.gd）：書き出した版で遊ぶときだけ（--perf で試せる）。確認の画・通しでは動かない
var perf: Node
func _perf(checking0: bool):
	var on := (OS.has_feature("template") or ARGS.has("perf")) and not checking0 and not "--demo" in OS.get_cmdline_user_args()
	if not on: return
	perf = get_tree().root.get_node_or_null("Perf")
	if perf == null:
		perf = load("res://scripts/perf.gd").new(); perf.name = "Perf"; get_tree().root.add_child.call_deferred(perf)
		await get_tree().process_frame
	var w: String = {"ch0": "序章 5時", "ch1": "第1章 夕方", "h21": "第2章 21時・22時", "door": "第2章 23時の扉", "ch4": "第4章 3時半", "ch11": "第11章 テープ"}.get(play, "")
	if w == "": w = ("第2章 20時" if ch2_house else "家 " + String(TIME_LABEL.get(TIME, TIME))) if SCENE == "house" else SCENE
	perf.set_main(self, w)

# 2026-11-14 重さ（試作120 の重さの記録：第4章 338ms・第11章 301ms）：家は 1.1M 三角形の一つの物で、影を落とす明かり1つごとに
# 家じゅうを描き直す（点の光は6面）。第4章は影の明かりが20、描く量の8倍を影に使っていた。第11章はテレビの中の映像の
# ために家じゅうの影を計算していた。影は、目（shadow_eye の印があればそのカメラ）に近い明かり shadow_n 個だけに落とす。
# 太陽・月（DirectionalLight3D）は別。--allshadows で前のまま。
var shadow_n := 4
var _sb_t := 0.0
func _shadow_budget(dt: float):
	_sb_t -= dt
	if _sb_t > 0.0 or ARGS.has("allshadows"): return
	_sb_t = 0.25
	var eye: Node3D = get_meta("shadow_eye") if has_meta("shadow_eye") and is_instance_valid(get_meta("shadow_eye")) else get_viewport().get_camera_3d()
	if eye == null: return
	var e := eye.global_position
	var cand: Array = []
	for l in find_children("*", "Light3D", true, false):
		if l is DirectionalLight3D or l.has_meta("own_shadow"): continue
		if not l.has_meta("want_shadow"): l.set_meta("want_shadow", l.shadow_enabled)
		if not l.get_meta("want_shadow"): continue
		if not l.is_visible_in_tree() or l.light_energy <= 0.0: l.shadow_enabled = false; continue
		var r: float = l.omni_range if l is OmniLight3D else l.spot_range
		cand.append([l.global_position.distance_to(e) - 0.5 * r, l])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	for i in cand.size(): cand[i][1].shadow_enabled = i < shadow_n

func _quality(high: bool):
	quality_high = high
	shadow_n = 4 if high else 2
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if high else Viewport.SCALING_3D_MODE_FSR
	vp.scaling_3d_scale = 1.0 if high else 0.6
	RenderingServer.environment_set_volumetric_fog_volume_size(96 if high else 48, 96 if high else 48)
	for k in lights: if lights[k] is Light3D and lights[k].shadow_enabled: lights[k].shadow_blur = 1.0 if high else 0.5
	# 試作92: 低 also draws each lamp's shadow in two passes instead of six, and the moon's in two splits
	for k in lights:
		var l = lights[k]
		if l is OmniLight3D: l.omni_shadow_mode = OmniLight3D.SHADOW_CUBE if high else OmniLight3D.SHADOW_DUAL_PARABOLOID
		elif l is DirectionalLight3D: l.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if high else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS

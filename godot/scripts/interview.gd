## 証言 一・二・三：インタビューの部屋（数か月後、昼。澪の実家の客間）。
## 第1稿 2026-11-19「インタビューの証言一〜三を作る」、第2稿 2026-11-20「インタビューを作り直す」のスレッド。
## 台本は story/interview.txt、並びは scripts/order.gd、部屋は assets/interview/（blender/interview/export_interview.py）。
## 第2稿で変えたこと（決定事項 2026-11-20、企画書「証言 一〜三（インタビュー）」）：
##   ・答えは一問一答。選んだ文は澪が声に出す言葉として画の下に出る。本当と嘘が混ざり、失敗で止まらない。
##   ・平たい2Dの画面、立ち絵、ロード、「上書きしますか？」をやめた。
##   ・紙芝居にしない：人は骨つき（tripo/interview/*_rig.glb、blender/interview/people/rig2glb.py）で、形から形へ動いて移り、
##     息・首・ペン・拳がいつも動く。選ぶあいだも時間は止めず、カメラが澪の肩越しから手元・口元へ寄る。
##   ・聞き手は名刺を置き、桐生の母から預かったテープを部屋のテレビで再生して、監督の章へつなぐ。
## 画と刷りの決まりは前のまま（docs/資料/インタビュー場面_ゲームへの入れ方_2026-11-16.md）：カメラも人も 12 コマ／秒で進む、
## 昼の刷り（riso2 の look=2）。聞き手の顔と澪の顔は画に出さない（どのカットも口元か胸で切る）。
##
## The house is not loaded here: this node is its own scene (order.gd packs it), and at its end it goes on down the
## late chapters' order.
extends Node3D
const Type = preload("res://scripts/type.gd")
const Main = preload("res://scripts/main.gd")
const Snd = preload("res://scripts/sound.gd")
const A := "res://assets/interview/"
const FPS := 12.0
const PAPER := Color(0.945, 0.925, 0.875)
const INK := Color(0.06, 0.08, 0.14)
const CARD_SEC := 3.2
const AMBIENT := 0.5
static var HAND_K := 0.75           # --handk= for trying
const SUN_DIR := Vector3(0.4, -0.45, 1.0)   # the way the sun goes (blender/interview/build.py: (0.4, -1.0, -0.45))
const SAY_SIZE := 32.0
const PICK_SIZE := 28.0

@export var which := 1

var u := 1.0
var demo := false
var demo_k := 1.0                 # the unattended run goes 40 times as fast (--demo); --demoslow: at the real pace, for check pictures
var only := false                 # --ivonly: quit at the end instead of going on (check runs)
var demo_lie := false             # --ivlie: the unattended run takes the lie where there is one (else the first true answer)
var blocks := {}                  # 台本：name -> Array of entries
var cuts := {}
var cams := {}
var cam: Camera3D
var env: Environment
var riso: ShaderMaterial
var blur_mat: ShaderMaterial
var room: Node3D
var tree_base := Transform3D.IDENTITY
var hide_now: Array = []
var lights_3d: Array = []
var fails := 0
var t_scene := 0.0               # this scene's clock (the people's and the camera's)
# camera playback
var frames: Array = []            # the running cut, one entry per 1/12 s
var frame_t := 0.0
var frame_dt := 1.0 / FPS
# page
var page: Control
var lines_box: VBoxContainer
var note_lb: Label
var font: Font
var skip := false                 # E / click: finish the line being typed, or go on
var last_who := ""

static func T(s: String) -> String: return String(TranslationServer.translate(s)).replace("​", "")
static func b2g(v) -> Vector3: return Vector3(v[0], v[2], -v[1])

# what she did earlier in the night (入口のスレッドが記録を作る。ここでは Engine の meta "night_flags" か --ivflags=a,b を見る)
static func flag(n: String) -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ivflags=") and n in a.substr(10).split(","): return true
	var f = Engine.get_meta("night_flags", {})
	if not (f is Dictionary): return false
	var v = f.get(n, null)
	return v != null and not (v is bool and v == false)

func _ready():
	var args := OS.get_cmdline_user_args()
	_mio_adj_args()
	demo = "--demo" in args or "--demoslow" in args; only = "--ivonly" in args
	demo_k = 40.0 if "--demo" in args else 1.0
	demo_lie = "--ivlie" in args
	for a in args:
		if a.begins_with("--handk="): HAND_K = float(a.substr(8))
	u = get_viewport().get_visible_rect().size.y / 1080.0
	font = Type.say()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_read_script()
	cuts = JSON.parse_string(FileAccess.get_file_as_string(A + "cuts.json"))
	cams = JSON.parse_string(FileAccess.get_file_as_string(A + "cameras.json"))
	_environment(); _room(); _people(); _tv(); _meishi(); _lights(); _camera(); _print_layer(); _page()
	Type.Soft.k = 2.2   # the day room is paper white where the night was ink: the pool under the type is made heavier here only
	_sounds()
	_run.call_deferred()

func _exit_tree():
	Type.Soft.k = 1.0

# ================================================================ 台本
func _entry(l: String) -> Dictionary:
	var e := {}
	if l.begins_with("［"):
		var k := l.find("］")
		var c := l.substr(1, k - 1); var rest := l.substr(k + 1).strip_edges()
		e = _entry(rest); e["cond"] = c; return e
	if l.begins_with("？"): return {"pick": int(l.substr(1)), "cards": []}
	if l.begins_with("＞"):
		var w := l.substr(1).split(" ", false)
		e = {"do": w[0], "arg": w[1] if w.size() > 1 else "", "arg2": w[2] if w.size() > 2 else ""}
		if w[0] == "card": e.arg = l.substr(l.find("card") + 5)
		return e
	if l.begins_with("（"): return {"note": l}
	if l.contains("："): return {"who": l.get_slice("：", 0), "text": l.substr(l.find("：") + 1)}
	return {}

func _read_script():
	var name := ""
	var last_pick: Dictionary = {}
	var last_card: Dictionary = {}
	for raw in FileAccess.get_file_as_string("res://story/interview.txt").split("\n"):
		var cmt := raw.find("//")
		var l: String = raw.substr(0, cmt) if cmt >= 0 else raw
		var indented := l.begins_with("    ") or l.begins_with("\t")
		l = l.strip_edges()
		if l == "": continue
		if l.begins_with("【"):
			name = l.trim_prefix("【").trim_suffix("】"); blocks[name] = []; last_pick = {}; last_card = {}; continue
		if name == "": continue
		if indented and not last_card.is_empty():
			var r := _entry(l)
			if r.is_empty(): print("SCRIPT ERROR interview: line not understood: ", l); continue
			(last_card.reply as Array).append(r); continue
		var cond := ""
		var l2 := l
		if l.begins_with("［") and l.find("］・") > 0:
			cond = l.substr(1, l.find("］") - 1); l2 = l.substr(l.find("］") + 1)
		if l2.begins_with("・") and not last_pick.is_empty():
			var parts := l2.substr(1).split("｜")
			last_card = {"text": parts[0].strip_edges(), "truth": true, "lie": "", "reply": [], "cond": cond}
			for k in range(1, parts.size()):
				var p := parts[k].strip_edges()
				if p.begins_with("嘘"): last_card.truth = false; last_card.lie = p.substr(2) if p.length() > 2 else "?"
			(last_pick.cards as Array).append(last_card); continue
		last_card = {}
		var e := _entry(l)
		if e.is_empty(): print("SCRIPT ERROR interview: line not understood: ", l); continue
		if e.has("pick"): last_pick = e
		(blocks[name] as Array).append(e)

# ================================================================ the room
func _environment():
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.86, 0.88, 0.9)       # past the shoji: the white of an overcast noon
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.80, 0.79, 0.77)   # lights.json world (0.75, 0.78, 0.82), warmed: the room's own walls and tatami return the light
	env.ambient_light_energy = AMBIENT
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true; env.ssao_radius = 0.35; env.ssao_intensity = 1.6   # the room has no baked light: the corners still sink
	we.environment = env
	add_child(we)

func _room():
	room = (load(A + "room.glb") as PackedScene).instantiate(); add_child(room)
	for mi in room.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var n := String(m.name)
		if n.begins_with("shoji_paper"):
			# the paper is lit from behind: the day's light and the leaves' shadows show through it (backlight). It is on
			# its own layer so that the sky's soft light, which stands for what the paper lets through, is not stopped by it
			m.layers = 2
			var pm := StandardMaterial3D.new(); pm.albedo_color = Color(0.93, 0.92, 0.89); pm.roughness = 1.0
			pm.backlight_enabled = true; pm.backlight = Color(1, 1, 1)
			pm.cull_mode = BaseMaterial3D.CULL_DISABLED
			pm.emission_enabled = true; pm.emission = Color(0.93, 0.92, 0.89); pm.emission_energy_multiplier = 0.12
			m.material_override = pm
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 2 mm thick: its own far face would shadow the near one
			_leaf_shadow(m)
		if n == "table_top":   # the lacquer: the baked material kept only its colour
			var tm: BaseMaterial3D = m.get_active_material(0).duplicate(); tm.roughness = 0.34; tm.metallic_specular = 0.6
			m.set_surface_override_material(0, tm)
			m.layers = 1 | 8   # the sheen light (_lights) is for this top only
		if n.begins_with("rec_time") or n.begins_with("recorder_display"):
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var probe := ReflectionProbe.new(); probe.position = Vector3(0, 0.9, 0); probe.size = Vector3(3.7, 2.4, 3.7)   # the low table's lacquer shows the shoji
	probe.update_mode = ReflectionProbe.UPDATE_ONCE; probe.interior = true; probe.ambient_mode = ReflectionProbe.AMBIENT_ENVIRONMENT
	probe.cull_mask = 1 | 2; probe.box_projection = true; probe.intensity = 1.0
	add_child(probe)

# The garden tree past the shoji is only its shadow on the paper (laid flat on each panel, along the sun's way)
const LEAF_SH := """shader_type spatial;
render_mode unshaded, blend_mul, cull_disabled, shadows_disabled;
uniform float x0 = -9.0; uniform float x1 = 9.0; uniform float y0 = -9.0; uniform float y1 = 9.0;
uniform vec3 tint : source_color = vec3(0.84, 0.84, 0.85);
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() { if (wp.x < x0 || wp.x > x1 || wp.y < y0 || wp.y > y1) discard; ALBEDO = tint; }"""
var trees: Array = []
func _leaf_shadow(paper: MeshInstance3D):
	if not ResourceLoader.exists(A + "tree.glb"): return
	var bb: AABB = paper.global_transform * paper.get_aabb()
	var t: Node3D = (load(A + "tree.glb") as PackedScene).instantiate(); tree_base = t.transform
	var holder := Node3D.new(); add_child(holder); holder.add_child(t); trees.append(t)
	var d := SUN_DIR; var z0 := bb.end.z + 0.004
	holder.transform = Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(-d.x / d.z, -d.y / d.z, 0.0004)), Vector3(d.x / d.z * z0, d.y / d.z * z0, z0))
	var sh := Shader.new(); sh.code = LEAF_SH
	var lm := ShaderMaterial.new(); lm.shader = sh
	lm.set_shader_parameter("x0", bb.position.x); lm.set_shader_parameter("x1", bb.end.x)
	lm.set_shader_parameter("y0", bb.position.y); lm.set_shader_parameter("y1", bb.end.y)
	for mi in t.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(mi as MeshInstance3D).material_override = lm
		(mi as MeshInstance3D).extra_cull_margin = 10.0

# the people's meshes are reduced scans: where a fold is open, the bright shoji showed through as white nicks
func _two_sided(n: Node):
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i)
			if mat is BaseMaterial3D:
				var m2: BaseMaterial3D = mat.duplicate(); m2.cull_mode = BaseMaterial3D.CULL_DISABLED; m2.metallic_specular = 0.0
				if "hand" in String(mat.resource_name) or "hand" in String(m.name): m2.albedo_color = Color(HAND_K, HAND_K, HAND_K)   # the hands' skin is paper-white in the day print without this: no fingers
				m.set_surface_override_material(i, m2)

func _lights():
	# one soft sun-less "sky" from the north, low, that the paper does not stop (shadow_caster_mask), a weak return from the
	# south, and the sun itself on the paper's back, where only the leaves and the lattice shadow it
	var sky := DirectionalLight3D.new(); sky.name = "sky"
	sky.light_color = Color(0.97, 0.98, 1.0); sky.light_energy = 1.8
	sky.rotation = Vector3(deg_to_rad(-16), deg_to_rad(180), 0)     # from the north (-z) down into the room
	sky.shadow_enabled = true; sky.light_angular_distance = 9.0; sky.shadow_blur = 2.0
	sky.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL; sky.directional_shadow_max_distance = 8.0
	sky.shadow_caster_mask = 1
	sky.light_specular = 0.0
	sky.light_cull_mask = 1
	add_child(sky); lights_3d.append(sky)
	var fill := DirectionalLight3D.new(); fill.name = "fill"
	fill.light_color = Color(1.0, 0.97, 0.92); fill.light_energy = 0.22
	fill.rotation = Vector3(deg_to_rad(-25), 0, 0)                  # from the south
	fill.shadow_enabled = false; fill.light_cull_mask = 1; fill.light_specular = 0.0
	add_child(fill); lights_3d.append(fill)
	var sheen := DirectionalLight3D.new(); sheen.name = "sheen"
	sheen.light_color = Color(0.97, 0.98, 1.0); sheen.light_energy = 0.12; sheen.light_specular = 9.0
	sheen.rotation = Vector3(deg_to_rad(-20), deg_to_rad(180), 0); sheen.shadow_enabled = true; sheen.shadow_caster_mask = 1
	sheen.light_angular_distance = 9.0; sheen.directional_shadow_max_distance = 8.0
	sheen.light_cull_mask = 8
	add_child(sheen); lights_3d.append(sheen)
	var sun := DirectionalLight3D.new(); sun.name = "sun"
	sun.light_energy = 0.62; sun.light_specular = 0.0
	sun.basis = Basis.looking_at(SUN_DIR.normalized(), Vector3.UP)
	sun.shadow_enabled = false
	sun.light_cull_mask = 2
	add_child(sun); lights_3d.append(sun)

# ================================================================ the two people (骨つき)
# Each is the Tripo body on the game_engine rig, its forms as one-key animations (rig2glb.py). The pose every 1/12 s is
# the blend of two forms (from → to, eased) with what a living body adds on top: the breath, the head's small drift and
# where it looks, a nod, the pen's hand, and (Mio) the fist. The additions are turns about the world's axes through the
# bone (lateral = x, up = y, the facing = z), so they read the same whichever way the rig's bones were rolled.
var ppl := {}          # "kikite" / "mio" -> person (Dictionary)
const BREATH := {"kikite": [4.6, 1.0], "mio": [3.7, 1.0]}   # period (s), depth

func _people():
	if ResourceLoader.exists(A + "kikite_rig.glb"): ppl["kikite"] = _person("kikite", "kikite_rig.glb", "seiza", 1.0)
	if ResourceLoader.exists(A + "mio_rig.glb"): ppl["mio"] = _person("mio", "mio_rig.glb", "lap", -1.0)
	if ppl.has("kikite"): _pencil(ppl.kikite)
	for k in ppl: _pose(ppl[k], 0.0)

# 試作297（赤字 #28「このへんが気になる」, circled: the two points where the cardigan meets the white collar by the neck):
# the generated cardigan stands up in two little navy ears at the collar's outer corners (|x| 3.5–10 cm, up to 1.274 m
# in the rest form while the collar's top is at about 1.255). They are pressed down to the collar's height here, on
# the body's own vertices (bind space: glTF y-up), before anything poses it.
var COLLAR_FIX := 1.0
func _collar_fix(root: Node):
	for mi in root.find_children("kikite_body*", "MeshInstance3D", true, false):
		var am := (mi as MeshInstance3D).mesh as ArrayMesh
		if am == null: continue
		var nm := ArrayMesh.new(); var moved := 0
		for si in am.get_surface_count():
			var arr := am.surface_get_arrays(si)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var top := am.get_aabb().end.y; var c0 := top - 0.024   # the ears' tips are the body's top; the collar's top 2.4 cm under (3 cm bared the neck's foot)
			for i in v.size():
				var q := v[i]
				var ax := absf(q.x)
				if q.y > c0 and ax > 0.032 and ax < 0.11:
					var w := clampf((ax - 0.032) / 0.012, 0.0, 1.0) * clampf((0.11 - ax) / 0.015, 0.0, 1.0) * COLLAR_FIX
					v[i] = Vector3(q.x, lerpf(q.y, c0 + (q.y - c0) * 0.15, w), q.z); moved += 1
			arr[Mesh.ARRAY_VERTEX] = v
			var bs := am.surface_get_blend_shape_arrays(si)
			nm.add_surface_from_arrays(am.surface_get_primitive_type(si), arr, bs, {}, am.surface_get_format(si) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			nm.surface_set_material(si, am.surface_get_material(si))
		(mi as MeshInstance3D).mesh = nm
		print("COLLAR_FIX moved ", moved)

func _person(key: String, file: String, rest_form: String, facing: float) -> Dictionary:
	var root: Node3D = (load(A + file) as PackedScene).instantiate(); add_child(root)
	_two_sided(root)
	if key == "kikite" and COLLAR_FIX > 0.0: _collar_fix(root)
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
	var forms := {}
	for an in ap.get_animation_list():
		var a: Animation = ap.get_animation(an)
		var f := {}
		for t in a.get_track_count():
			var bi := sk.find_bone(String(a.track_get_path(t).get_concatenated_subnames()))
			if bi < 0 or a.track_get_key_count(t) == 0: continue
			var ent: Dictionary = f.get(bi, {})
			match a.track_get_type(t):
				Animation.TYPE_POSITION_3D: ent["p"] = a.track_get_key_value(t, 0)
				Animation.TYPE_ROTATION_3D: ent["r"] = a.track_get_key_value(t, 0)
			f[bi] = ent
		forms[String(an)] = f
	ap.stop(); ap.get_parent().remove_child(ap); ap.queue_free()
	var p := {"key": key, "root": root, "sk": sk, "forms": forms, "from": rest_form, "to": rest_form, "k": 1.0, "dur": 0.9,
		"facing": facing, "axes": {}, "bones": {}, "breath": 0.0, "look": Vector2.ZERO, "look_to": Vector2.ZERO,
		"nod": -1.0, "pen": "", "pen_t": 0.0, "fist": 0.0, "fist_to": 0.0, "seed": randf() * 100.0, "tense": 0.0}
	for b in ["spine_01", "spine_02", "spine_03", "neck_01", "head", "clavicle_l", "clavicle_r", "hand_l", "hand_r", "lowerarm_l", "lowerarm_r", "upperarm_l", "upperarm_r"]:
		p.bones[b] = sk.find_bone(b)
	# the bones' local axes for the world's lateral, up and facing, measured once in the resting form
	_set_form_pose(p, rest_form, rest_form, 1.0)
	sk.force_update_all_bone_transforms()
	for b in p.bones:
		var bi: int = p.bones[b]
		if bi < 0: continue
		var gb: Basis = (sk.global_transform.basis.orthonormalized() * sk.get_bone_global_pose(bi).basis.orthonormalized()).inverse()
		p.axes[bi] = [(gb * Vector3.RIGHT).normalized(), (gb * Vector3.UP).normalized(), (gb * Vector3(0, 0, facing)).normalized()]
	return p

var MIO_ADJ := [-4.0, 4.0, 3.0]   # clavicles about the facing axis (deg), neck and head up (deg); --mioadj=a,b,c for checks
func _mio_adj_args():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--collarfix="): COLLAR_FIX = float(a.substr(12))
		if a.begins_with("--mioadj="): MIO_ADJ = Array(a.substr(9).split(",")).map(func(v): return float(v))

func _form_bone(p: Dictionary, form: String, bi: int) -> Array:
	var f: Dictionary = p.forms.get(form, {})
	var sk: Skeleton3D = p.sk
	var rest := sk.get_bone_rest(bi)
	var e: Dictionary = f.get(bi, {})
	return [e.get("p", rest.origin), e.get("r", rest.basis.get_rotation_quaternion())]

func _set_form_pose(p: Dictionary, a: String, b: String, k: float, extra := {}):
	var sk: Skeleton3D = p.sk
	var e := k * k * (3.0 - 2.0 * k)
	for bi in sk.get_bone_count():
		var fa := _form_bone(p, a, bi); var fb := _form_bone(p, b, bi)
		var pos: Vector3 = (fa[0] as Vector3).lerp(fb[0], e)
		var rot: Quaternion = (fa[1] as Quaternion).slerp(fb[1], e)
		if extra.has(bi): rot = rot * (extra[bi] as Quaternion)
		sk.set_bone_pose_position(bi, pos); sk.set_bone_pose_rotation(bi, rot)

# a turn about a world axis (0 lateral, 1 up, 2 facing) of `deg`, added to what the bone already turns
func _turn(p: Dictionary, extra: Dictionary, bone: String, axis: int, deg: float):
	var bi: int = p.bones.get(bone, -1)
	if bi < 0 or absf(deg) < 0.0001: return
	var q := Quaternion((p.axes[bi][axis] as Vector3), deg_to_rad(deg))
	extra[bi] = (extra.get(bi, Quaternion.IDENTITY) as Quaternion) * q

static func _wob(t: float, s: float) -> float:
	# a slow drift: three sines that never line up
	return 0.55 * sin(t * 0.37 + s) + 0.3 * sin(t * 0.83 + s * 1.7) + 0.15 * sin(t * 1.9 + s * 0.3)

func _pose(p: Dictionary, dt: float):
	# the forms
	if p.k < 1.0: p.k = minf(1.0, float(p.k) + dt / float(p.dur))
	var t: float = t_scene + float(p.seed)
	var f: float = p.facing
	var x := {}
	# the breath: the chest rises and opens a little, the shoulders with it; the neck takes it back so the head stays
	var per: float = BREATH[p.key][0] * (1.0 - 0.25 * float(p.tense))
	p.breath = float(p.breath) + dt * TAU / per
	var br := sin(float(p.breath)) * float(BREATH[p.key][1]) * (1.0 + 0.4 * float(p.tense))
	_turn(p, x, "spine_02", 0, -f * 0.7 * br)
	_turn(p, x, "spine_03", 0, -f * 1.1 * br)
	_turn(p, x, "neck_01", 0, f * 1.4 * br)
	_turn(p, x, "clavicle_l", 2, 1.1 * br)
	_turn(p, x, "clavicle_r", 2, -1.1 * br)
	# the head: a slow drift, where it is looking (lerped), a nod
	p.look = (p.look as Vector2).lerp(p.look_to, 1.0 - exp(-dt * 3.0))
	var nod := 0.0
	if float(p.nod) >= 0.0:
		p.nod = float(p.nod) + dt
		nod = 6.0 * sin(PI * clampf(float(p.nod) / 0.75, 0.0, 1.0))
		if float(p.nod) > 0.75: p.nod = -1.0
	var pitch: float = 1.3 * _wob(t * 0.9, 1.0) + (p.look as Vector2).y + nod
	var yaw: float = 2.0 * _wob(t * 0.7, 4.0) + (p.look as Vector2).x
	_turn(p, x, "neck_01", 0, f * pitch * 0.35); _turn(p, x, "head", 0, f * pitch * 0.65)
	_turn(p, x, "neck_01", 1, yaw * 0.4); _turn(p, x, "head", 1, yaw * 0.6)
	_turn(p, x, "spine_01", 2, 0.6 * _wob(t * 0.5, 7.0))   # the weight shifting on the knees
	if p.key == "mio" or p.key == "kikite":
		# 試作297（赤字 #28: the shot is the interviewer's, q_聞き手_口元; both sit the same way, so both)（赤字 #28「このへんが気になる」: her shoulders' tops by the neck, and the collar under her chin): the shoulders
		# let down a little (the clip held them up into two points by the collar), the chin lifted off the collar
		_turn(p, x, "clavicle_l", 2, MIO_ADJ[0]); _turn(p, x, "clavicle_r", 2, -MIO_ADJ[0])
		_turn(p, x, "neck_01", 0, -f * MIO_ADJ[1]); _turn(p, x, "head", 0, -f * MIO_ADJ[2])
	# the pen: writing is small turns of the wrist, a stop is the hand lifted off the page and held
	if String(p.pen) != "" and p.has("pen_hand"):
		p.pen_t = float(p.pen_t) + dt
		var hb := String(p.pen_hand); var lb := "lowerarm_" + hb.substr(5)
		if p.pen == "write":
			var w := float(p.pen_t)
			_turn(p, x, hb, 1, 4.0 * sin(w * TAU * 2.6) + 1.5 * sin(w * TAU * 0.7))
			_turn(p, x, hb, 0, f * 2.0 * absf(sin(w * TAU * 1.3)))
			_turn(p, x, lb, 1, 1.6 * sin(w * TAU * 0.45))
		elif p.pen == "stop":
			var up := clampf(float(p.pen_t) / 0.18, 0.0, 1.0)
			_turn(p, x, hb, 0, -f * 7.0 * up)
	# Mio's fist
	if p.key == "mio":
		p.fist = move_toward(float(p.fist), float(p.fist_to), dt / (0.35 if float(p.fist_to) > float(p.fist) else 1.6))
	if p.key == "mio" and float(p.fist) > 0.0:
		_set_form_pose(p, "lap", "fist", float(p.fist), x)
	else:
		_set_form_pose(p, p.from, p.to, p.k, x)
	if p.key == "kikite": _pencil_tick(p)

func _form(who: String, form: String, dur := 0.9):
	if not ppl.has(who): return
	var p: Dictionary = ppl[who]
	if not (p.forms as Dictionary).has(form): print("SCRIPT ERROR interview: no form ", who, " ", form); fails += 1; return
	if p.to == form and float(p.k) >= 1.0: return
	p.from = p.to if float(p.k) >= 0.5 else p.from
	p.to = form; p.k = 0.0; p.dur = dur
	if form != "write": p.pen = ""

# the pencil: in the write form it is in the writing hand (where the write file had it); otherwise it lies on the notebook
var pencil: Array = []
var pencil_rel: Array = []
var pencil_rest: Array = []
func _pencil(p: Dictionary):
	for n in (p.root as Node).find_children("kikite_pencil*", "MeshInstance3D", true, false): pencil.append(n)
	if pencil.is_empty(): return
	var sk: Skeleton3D = p.sk
	_set_form_pose(p, "write", "write", 1.0); sk.force_update_all_bone_transforms()
	var pg: Vector3 = (pencil[0] as Node3D).global_position
	var best := ""; var bd := 9.0
	for h in ["hand_l", "hand_r"]:
		var g: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(h))).origin
		if g.distance_to(pg) < bd: bd = g.distance_to(pg); best = h
	p.pen_hand = best
	var hg: Transform3D = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(best))
	# lying on the notebook: the same pencil, its long axis turned flat and across the page
	var gw: Transform3D = (pencil[0] as Node3D).global_transform
	var ab: AABB = (pencil[0] as MeshInstance3D).get_aabb()
	var ax := Vector3.RIGHT if ab.size.x >= maxf(ab.size.y, ab.size.z) else (Vector3.UP if ab.size.y >= ab.size.z else Vector3.BACK)
	var L: Vector3 = (gw.basis * ax).normalized()
	var d := Vector3(cos(deg_to_rad(20.0)), 0.0, sin(deg_to_rad(20.0)))
	var grest := Transform3D(Basis(Quaternion(L, d)) * gw.basis, b2g([0.30, 0.47, 0.338]))
	for n in pencil:
		var g := (n as Node3D).global_transform
		pencil_rel.append(hg.affine_inverse() * g)
		pencil_rest.append(grest * (gw.affine_inverse() * g))
	_set_form_pose(p, "seiza", "seiza", 1.0)

func _pencil_tick(p: Dictionary):
	if pencil.is_empty(): return
	var held: bool = (p.to == "write" and float(p.k) > 0.5) or (p.from == "write" and float(p.k) < 0.5)
	var sk: Skeleton3D = p.sk
	var hg: Transform3D = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(p.pen_hand))
	for i in pencil.size():
		(pencil[i] as Node3D).global_transform = (hg * pencil_rel[i]) if held else pencil_rest[i]

func _show_people():
	if ppl.has("kikite"): (ppl.kikite.root as Node3D).visible = not ("people" in hide_now)
	if ppl.has("mio"): (ppl.mio.root as Node3D).visible = not ("mio" in hide_now)

var people_t := 0.0
func _people_tick(dt: float):
	# the people are drawn at the print's 12 a second, like the camera
	people_t += dt
	if people_t < 1.0 / FPS: return
	var step := people_t; people_t = 0.0
	for k in ppl: _pose(ppl[k], step)

# ================================================================ the deck and the set, the card
var tv_root: Node3D
var deck_root: Node3D
var screen: MeshInstance3D
var screen_mat: ShaderMaterial
var screen_lb: Label3D
const TV_AT := [-1.50, -0.95, 0.42]      # Blender: on the low cabinet of the tokowaki (west wall, south of the post), facing east
const SCREEN_SH := """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float on = 0.0;      // 0 dark glass, 1 the deck's blue, 2 the tape (the hall at two o'clock, through the finder)
uniform float tm = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	vec3 c = vec3(0.025, 0.028, 0.032);   // 試作281: the dead glass darker, so the picture, when it comes, is a light in it
	if (on > 0.5 && on < 1.5) c = vec3(0.12, 0.26, 0.75);
	if (on > 1.5) {
		// 試作281（ユーザー「テレビに映像が写っているように見えない」）: the hall at two, as the small camera saw it: the lit hall
		// beyond the door frame bright, the frame and the floor's boards running away, the stair's rail, the picture
		// rolling a little. Bright enough to be a lit tube (it was grey on grey)
		float roll = fract(tm * 0.11);
		float band = smoothstep(0.0, 0.04, abs(uv.y - roll)) * 0.2 + 0.8;
		float n = h(floor(uv * vec2(220.0, 160.0)) + floor(tm * 24.0));
		float wob = sin(uv.y * 40.0 + tm * 3.0) * 0.002;
		vec2 q = uv + vec2(wob, 0.0);
		float inner = step(0.36, q.x) * step(q.x, 0.62) * step(0.16, q.y) * step(q.y, 0.80);          // the lit doorway
		float frame = (step(0.33, q.x) * step(q.x, 0.65) * step(0.12, q.y) * step(q.y, 0.84)) - inner; // its frame
		float boards = smoothstep(0.78, 1.0, q.y) * (0.55 + 0.45 * step(0.5, fract((q.x - 0.5) / (1.2 - q.y) * 6.0)));
		float rail = smoothstep(0.012, 0.0, abs((q.y - 0.30) - (q.x - 0.70) * 0.9)) * step(0.68, q.x);   // the stair's rail, down to the right
		float wallL = smoothstep(0.0, 0.33, q.x) * 0.18;
		c = vec3(0.06) + vec3(0.62) * inner + vec3(0.30) * frame + vec3(0.35) * boards * (1.0 - inner) + wallL;
		c += vec3(0.4) * rail;
		c = c * band + (n - 0.5) * 0.08;
		c *= vec3(0.9, 0.97, 1.05);
	}
	// 試作277（ユーザー「テレビに表示されているように」、証言 一）: it read as a card stuck on the glass. A tube's picture: scan
	// lines, the phosphor's three stripes, a soft glow, rounded dark corners, and the glass's own sheen over it
	if (on > 0.5) {
		float scan = 0.72 + 0.28 * sin(uv.y * 480.0 * 3.14159);
		float tri = mod(floor(FRAGCOORD.x), 3.0);
		vec3 ph = tri < 1.0 ? vec3(1.12, 0.94, 0.94) : (tri < 2.0 ? vec3(0.94, 1.12, 0.94) : vec3(0.94, 0.94, 1.12));
		c = c * scan * ph * 1.25 + c * 0.18;
		c *= 0.96 + 0.04 * sin(tm * 50.0);
	}
	vec2 d = uv - 0.5;
	c *= 1.0 - dot(d, d) * 2.2;
	float corner = smoothstep(0.5, 0.44, max(abs(d.x) * 1.04, abs(d.y) * 1.08) + 0.06 * dot(d, d));
	c *= corner;
	float sheen = smoothstep(0.35, 0.0, length(uv - vec2(0.3, 0.22))) * 0.06;
	ALBEDO = c + vec3(sheen);
}"""

func _tv():
	var at := b2g(TV_AT)
	tv_root = Node3D.new(); add_child(tv_root)
	deck_root = Node3D.new(); add_child(deck_root)
	var deck_top := at.y
	if ResourceLoader.exists("res://props/vcr.glb"):
		var v: Node3D = (load("res://props/vcr.glb") as PackedScene).instantiate(); deck_root.add_child(v)
		v.scale = Vector3(0.44, 0.68, 0.44); v.rotation.y = deg_to_rad(90.0)
		var bb := _aabb(v)
		v.global_position += Vector3(at.x + 0.06 - bb.get_center().x, at.y - bb.position.y, at.z - bb.get_center().z)
		deck_top = _aabb(v).end.y
	var w := 0.46
	if ResourceLoader.exists("res://props/crt_tv.glb"):
		var t: Node3D = (load("res://props/crt_tv.glb") as PackedScene).instantiate(); tv_root.add_child(t)
		t.rotation.y = deg_to_rad(8.0)
		var bb := _aabb(t); var k := w / bb.size.z
		t.scale = Vector3(k, k, k)
		bb = _aabb(t)
		t.global_position += Vector3(at.x - 0.02 - bb.get_center().x, (deck_top if deck_root.get_child_count() > 0 else at.y) - bb.position.y, at.z - bb.get_center().z)
		bb = _aabb(t)
		# the glass: a little in front of the set's face, most of its width
		screen = MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(bb.size.z * 0.66, bb.size.y * 0.57); screen.mesh = q
		var sh := Shader.new(); sh.code = SCREEN_SH; screen_mat = ShaderMaterial.new(); screen_mat.shader = sh; screen.material_override = screen_mat
		add_child(screen)
		screen.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(bb.end.x - 0.03, bb.position.y + bb.size.y * 0.565, bb.get_center().z))
		screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		screen_lb = Label3D.new(); screen_lb.font = Type.cam(); screen_lb.font_size = 48; screen_lb.pixel_size = 0.0006
		screen_lb.modulate = Color(0.85, 0.88, 0.9); screen_lb.outline_size = 0; screen_lb.shaded = false; screen_lb.text = ""
		screen_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_child(screen_lb)
		screen_lb.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), screen.global_position + Vector3(0.002, q.size.y * 0.36, q.size.x * 0.30))
	# the deck comes with her: it is in the room once she has played the tape (証言 一), and stays (二、三、第11章)
	deck_root.visible = which >= 2

func _aabb(n: Node3D) -> AABB:
	var bb := AABB(); var first := true
	for g in n.find_children("*", "MeshInstance3D", true, false):
		var m := g as MeshInstance3D
		var b2: AABB = m.global_transform * m.get_aabb(); bb = b2 if first else bb.merge(b2); first = false
	return bb

# 名刺：91 × 55 mm, laid on the table to her (証言 一), left there (二、三)
var meishi: Node3D
func _meishi():
	meishi = Node3D.new(); add_child(meishi)
	var m := MeshInstance3D.new(); var bx := BoxMesh.new(); bx.size = Vector3(0.091, 0.0004, 0.055); m.mesh = bx
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.95, 0.94, 0.91); mat.roughness = 0.9; m.material_override = mat
	meishi.add_child(m)
	# printed lines (a name, a line of small type): marks, not words
	for r in [[-0.012, 0.010, 0.040, 0.0035], [-0.008, -0.004, 0.048, 0.0016], [-0.008, -0.010, 0.040, 0.0016], [0.022, 0.018, 0.020, 0.0016]]:
		var l := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = Vector3(r[2], 0.0002, r[3]); l.mesh = b
		var lm := StandardMaterial3D.new(); lm.albedo_color = Color(0.15, 0.15, 0.16); l.material_override = lm
		meishi.add_child(l); l.position = Vector3(r[0], 0.0003, -r[1])
	meishi.visible = which >= 2
	meishi.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(4.0)), b2g(MEISHI_DOWN))
const MEISHI_FROM := [-0.08, 0.36, 0.3605]   # from under her fingers on the tape (the stroke form)
const MEISHI_DOWN := [-0.12, 0.25, 0.3605]   # pushed toward Mio, in front of the tape

# ================================================================ camera
# the shots made here (Blender's axes, as cuts.json): the choosing, the answer, the pen, the set
const SHOTS := {
	"選ぶ_肩越し": [[0.55, -1.50, 0.84], [-0.06, 0.80, 0.24], 58.0, 0.0, [], [0.48, -1.28, 0.82], 8.0],
	"選ぶ_手元": [[-0.85, -0.52, 0.44], [0.0, -0.58, 0.30], 38.0, 0.0, ["people"], [-0.70, -0.54, 0.42], 10.0],
	# 2026-11-22（全体レビュー 2）：口元の二つは顎から下しか入っていなかった。20 cm 上げて、鼻から胸までに
	"選ぶ_口元": [[0.0, 0.45, 0.70], [0.0, -0.72, 0.70], 40.0, 0.17, ["people"], [0.0, 0.20, 0.70], 14.0],
	"澪_口元": [[0.0, 0.42, 0.70], [0.0, -0.72, 0.70], 42.0, 0.17, ["people"], [0.0, 0.38, 0.70], 4.0],
	# a lie: after her words, her hands in her lap closing (from her side, under the table's edge)
	"澪_拳": [[-0.80, -0.52, 0.42], [0.0, -0.60, 0.28], 46.0, 0.0, ["people"], [-0.74, -0.53, 0.41], 3.0],
	"ペン": [[-0.30, 0.02, 0.85], [0.18, 0.46, 0.36], 40.0, 0.0, ["mio"], [-0.27, 0.06, 0.82], 4.0],
	"名刺": [[-0.16, -0.30, 0.78], [-0.10, 0.36, 0.33], 50.0, 0.0, ["mio"], [-0.15, -0.24, 0.75], 4.0],
	"テレビ_引き": [[-0.40, -0.40, 0.76], [-1.48, -0.95, 0.70], 32.0, 0.0, [], [-0.62, -0.30, 0.73], 4.0],
	"テレビ_正面": [[-0.45, -0.95, 0.72], [-1.48, -0.95, 0.72], 30.0, 0.0, ["mio", "people"], [-0.45, -0.95, 0.72], 1.0],
	"テレビ_上": [[-1.0, -0.95, 2.2], [-1.48, -0.95, 0.6], 30.0, 0.0, ["mio", "people"], [-1.0, -0.95, 2.2], 1.0],
	"テレビ_寄る": [[-0.55, -0.40, 0.74], [-1.48, -0.95, 0.70], 36.0, 0.0, [], [-1.08, -0.93, 0.70], 5.0],
	"澪_手_沈黙": [[-0.85, -0.52, 0.44], [0.0, -0.58, 0.30], 44.0, 0.0, ["people"], [-0.78, -0.53, 0.43], 6.0],
}
# 受けの画：the interviewer after an answer, cut lower each time (証言 一 胸、二 顎、三 口元)
const RECEIVE := {1: "k3a_聞き手_胸", 2: "k3b_聞き手_顎", 3: "k3c_聞き手_口元"}

func _camera():
	cam = Camera3D.new(); cam.near = 0.05; cam.far = 40.0
	cam.projection = Camera3D.PROJECTION_FRUSTUM; cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.cull_mask = 1 | 2
	add_child(cam); cam.current = true
	_set_cam({"loc": [0, -1.3, 0.5], "at": [0, 1.82, 0.55], "lens": 35.0, "hide": ["people", "mio"]})

func _set_cam(f: Dictionary):
	var loc := b2g(f.loc); var at := b2g(f.at)
	cam.position = loc
	var fwd := (at - loc).normalized()
	var up := Vector3.UP if absf(fwd.dot(Vector3.UP)) < 0.9999 else Vector3(0, 0, -1)
	cam.basis = Basis.looking_at(fwd, up)
	if f.has("roll"): cam.rotate_object_local(Vector3(0, 0, 1), deg_to_rad(float(f.roll)))
	var size: float = cam.near * 36.0 / float(f.lens)
	cam.set_frustum(size, Vector2(0, float(f.get("shift_y", 0.0)) * size), cam.near, cam.far)
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	hide_now = f.get("hide", [])
	_show_people()
	if blur_mat: blur_mat.set_shader_parameter("px", float(f.get("blur", 0.0)))
	if f.has("sway"):
		var t := TAU * float(f.sway)
		for tr in trees:
			tr.transform = tree_base
			tr.rotate_x(0.02 * sin(t)); tr.rotate_z(-0.035 * sin(t + 0.7)); tr.position.x = tree_base.origin.x + 0.03 * sin(t + 1.3)

# a shot of SHOTS as frames at 12 a second: from its start to its end over its seconds, slow at both ends
func _shot_frames(name: String, sec := 0.0) -> Array:
	var s: Array = SHOTS[name]
	var dur: float = sec if sec > 0.0 else float(s[6])
	var n := maxi(int(dur * FPS), 1)
	var out: Array = []
	for i in n:
		var t := float(i) / float(maxi(n - 1, 1)); t = t * t * (3.0 - 2.0 * t) if name != "テレビ_寄る" else t * t
		var loc: Array = []
		for j in 3: loc.append(lerpf(float(s[0][j]), float(s[5][j]), t))
		out.append({"loc": loc, "at": s[1], "lens": s[2], "shift_y": s[3], "hide": s[4]})
	return out

# a cut: its frames laid out one per 1/12 s (hold = that many); sec > 0 stretches it to that length
func _cut(name: String, sec := 0.0) -> float:
	frames = []
	if SHOTS.has(name):
		frames = _shot_frames(name, sec)
		frame_dt = 1.0 / FPS
	elif cuts.shots.has(name):
		for f in cuts.shots[name]:
			for i in int(f.get("hold", 1)): frames.append(f)
		frame_dt = (sec / frames.size()) if sec > 0.0 else 1.0 / FPS
	elif cams.has(name):
		_still(name); return 0.0
	else:
		print("SCRIPT ERROR interview: no cut ", name); fails += 1; return 0.0
	frame_t = 0.0
	_set_cam(frames[0])
	return frames.size() * frame_dt

func _still(name: String):
	if SHOTS.has(name):
		_cut(name)
		var f0: Dictionary = frames[0]
		frames = []; _set_cam(f0); return
	if not cams.has(name): print("SCRIPT ERROR interview: no camera ", name); fails += 1; return
	frames = []
	var c: Dictionary = cams[name]
	_set_cam({"loc": c.loc, "at": c.at, "lens": c.lens, "shift_y": c.get("shift_y", 0.0), "hide": c.get("hide", [])})

func _process(dt: float):
	t_scene += dt
	_people_tick(dt)
	if frames.size() > 0:
		frame_t += dt
		var i := mini(int(frame_t / frame_dt), frames.size() - 1)
		_set_cam(frames[i])
	if screen_mat: screen_mat.set_shader_parameter("tm", t_scene)

# ================================================================ the print
const BLUR := """shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float px = 0.0;   // the whip pan's smear, px at 1920 wide
void fragment() {
	vec3 c = vec3(0.0); float w = 0.0;
	float r = px / 1920.0;
	for (int i = -8; i <= 8; i++) { float k = 1.0 - abs(float(i)) / 9.0; c += textureLod(screen_tex, SCREEN_UV + vec2(float(i) / 8.0 * r, 0.0), 0.0).rgb * k; w += k; }
	COLOR = vec4(c / w, 1.0);
}"""
func _print_layer():
	var bl := CanvasLayer.new(); bl.layer = 9; add_child(bl)
	var br := ColorRect.new(); br.set_anchors_preset(Control.PRESET_FULL_RECT); br.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new(); sh.code = BLUR
	blur_mat = ShaderMaterial.new(); blur_mat.shader = sh; br.material = blur_mat
	bl.add_child(br)
	var layer := CanvasLayer.new(); layer.layer = 10; add_child(layer)
	var bb := BackBufferCopy.new(); bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT; layer.add_child(bb)
	var r := ColorRect.new(); r.set_anchors_preset(Control.PRESET_FULL_RECT); r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	riso = ShaderMaterial.new(); riso.shader = load("res://shaders/riso2.gdshader")
	riso.set_shader_parameter("look", 2.0); riso.set_shader_parameter("cell_px", 2.6)
	riso.set_shader_parameter("exposure", 1.3)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--print="): riso.set_shader_parameter("enabled", float(a.substr(8)))
		if a.begins_with("--pexp="): riso.set_shader_parameter("exposure", float(a.substr(7)))
	r.material = riso
	layer.add_child(r)

# ================================================================ the sound of the room
func _sounds():
	for s in [["iv_room", -16.0], ["iv_leaves", -24.0]]:
		var st := Snd.stream(String(s[0]), true)
		if st == null: continue
		var p := AudioStreamPlayer.new(); p.stream = st; p.volume_db = float(s[1]); add_child(p); p.play()

# ================================================================ the page (as story.gd sets it)
func _label(size: float, col := Color(0, 0, 0, 0), shadow := true) -> Label:
	var lb := Label.new()
	lb.add_theme_font_override("font", font)
	lb.add_theme_font_size_override("font_size", int(size * u))
	lb.add_theme_color_override("font_color", PAPER if col.a == 0.0 else col)
	if shadow: Type.soft(lb, u)
	# the ink's edge round the letters: the day print is paper white behind them (試作232、全体レビュー3)
	lb.add_theme_color_override("font_outline_color", Color(INK.r, INK.g, INK.b, 0.9)); lb.add_theme_constant_override("outline_size", maxi(4, int(7.0 * u)))
	lb.autowrap_mode = TextServer.AUTOWRAP_OFF
	lb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return lb

func _page():
	var layer := CanvasLayer.new(); layer.layer = 13; add_child(layer)
	page = Control.new(); page.set_anchors_preset(Control.PRESET_FULL_RECT); page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(page)
	lines_box = VBoxContainer.new()
	lines_box.anchor_left = 0.08; lines_box.anchor_right = 0.92; lines_box.anchor_top = 1.0; lines_box.anchor_bottom = 1.0
	lines_box.offset_bottom = -64 * u; lines_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lines_box.add_theme_constant_override("separation", int(6 * u))
	page.add_child(lines_box)
	note_lb = _label(24)
	note_lb.anchor_left = 0.075; note_lb.anchor_top = 1.0; note_lb.anchor_bottom = 1.0
	note_lb.offset_top = -50 * u; note_lb.offset_bottom = -18 * u
	page.add_child(note_lb)

# break a long sentence at its commas and stops, n full-width letters to a line at most
static func wrap_ja(s: String, n: int) -> String:
	var out := ""; var line := ""
	var i := 0
	while i < s.length():
		line += s[i]; i += 1
		if line.length() >= n - 8 and i < s.length():
			var c := s[i - 1]
			var nxt := s[i]
			if (c in "、。」？" or line.length() >= n) and not (nxt in "、。」？…　"):
				if s.length() - i >= 3: out += line + "\n"; line = ""
	return out + line

func _clear(b: Container):
	for c in b.get_children(): b.remove_child(c); c.queue_free()

# a spoken line at the foot of the frame; the speaker's name in small type when the speaker changes (story.gd)
func _say_row(who: String, text: String) -> Label:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", int(14 * u)); row.alignment = BoxContainer.ALIGNMENT_CENTER
	if who != "":   # 試作282: every spoken line carries its name (字幕の決まり)
		var w := _label(23); w.text = T(who) + "　"; w.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(w)
	last_who = who
	var lb := _label(SAY_SIZE); lb.text = wrap_ja(T(text), 30); lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(lb)
	lines_box.add_child(row)
	# 字幕は折り返しを含めて3行まで（試作277、story.gd _fit_lines と同じ決まり。docs/字幕の決まり.md）
	while lines_box.get_child_count() > 1:
		var total := 0
		for r in lines_box.get_children(): total += _row_lines(r)
		if total <= 3: break
		var c := lines_box.get_child(0); lines_box.remove_child(c); c.queue_free()
	for i in range(lines_box.get_child_count()):
		(lines_box.get_child(i) as Control).modulate.a = 1.0 if i == lines_box.get_child_count() - 1 else 0.5
	return lb

static func _row_lines(row: Node) -> int:
	var n := 0
	for c in row.get_children():
		if c is Label and (c as Label).text != "" and not String((c as Label).text).ends_with("　"): n = maxi(n, String((c as Label).text).count("\n") + 1)
	return maxi(n, 1)

# type a line in, then hold it; E / click finishes the typing, then goes on
func _type(lb: Label, cps := 22.0, hold := 1.4):
	var n := lb.text.length()
	lb.visible_characters = 0
	var t := 0.0
	skip = false
	while t * cps < n:
		await get_tree().process_frame
		if not is_instance_valid(lb): return
		t += get_process_delta_time() * demo_k
		if skip: skip = false; break
		lb.visible_characters = mini(n, int(t * cps))
	lb.visible_characters = -1
	await _hold(hold + n * 0.035)

func _hold(sec: float):
	var t := 0.0
	skip = false
	while t < sec:
		await get_tree().process_frame
		t += get_process_delta_time() * demo_k
		if skip: skip = false; break

func _unhandled_input(e):
	if e is InputEventKey and e.pressed and not e.echo:
		if picking:
			if e.keycode in [KEY_W, KEY_UP]: _move_pick(-1)
			elif e.keycode in [KEY_S, KEY_DOWN]: _move_pick(1)
			elif e.keycode in [KEY_E, KEY_ENTER, KEY_SPACE]: pick_go = true
		elif e.keycode in [KEY_E, KEY_ENTER, KEY_SPACE]: skip = true
		if e.keycode == KEY_F12: _save_frame()
	elif e is InputEventMouseButton and e.pressed:
		if picking:
			if e.button_index == MOUSE_BUTTON_WHEEL_UP: _move_pick(-1)
			elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: _move_pick(1)
			elif e.button_index == MOUSE_BUTTON_LEFT: pick_go = true
		elif e.button_index == MOUSE_BUTTON_LEFT: skip = true

func _save_frame():
	var d := OS.get_executable_path().get_base_dir()
	get_viewport().get_texture().get_image().save_png("%s/shot_interview%d_%d.png" % [d, which, Time.get_ticks_msec()])

# ================================================================ answering
var picking := false
var pick_go := false
var pick_idx := 0
var pick_rows: Array = []         # [{card, lb}]
var choose_cam := false           # ＞choose_in：the next question is watched from over her shoulder, coming in

func _move_pick(d: int):
	pick_idx = posmod(pick_idx + d, pick_rows.size())
	_show_pick()

func _show_pick():
	for i in pick_rows.size():
		var lb: Label = pick_rows[i].lb
		lb.add_theme_color_override("font_color", PAPER if i == pick_idx else Color(PAPER.r, PAPER.g, PAPER.b, 0.62))

func _strike(lb: Label, dur := 0.9):
	var fs := lb.get_theme_font_size("font_size")
	var lh := font.get_height(fs) + lb.get_theme_constant("line_spacing")
	var lines := lb.text.split("\n")
	for i in lines.size():
		var s2 = load("res://scripts/story.gd").Strike.new()
		s2.u = u; s2.anim = dur
		s2.w = font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		s2.position = Vector2(0, i * lh); s2.size = Vector2(s2.w, font.get_height(fs))
		s2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lb.add_child(s2)

# the choosing camera: over her shoulder onto the interviewer waiting, then her hands, then her mouth; it does not stop
func _choose_frames() -> Array:
	return _shot_frames("選ぶ_肩越し") + _shot_frames("選ぶ_手元") + _shot_frames("選ぶ_口元")

# one question: the answers she could give, at the foot of the frame; she says one. Time goes on while she chooses
func _pick(e: Dictionary):
	var cards: Array = (e.cards as Array).filter(func(c): return String(c.cond) == "" or flag(String(c.cond)))
	if cards.is_empty(): return
	_clear(lines_box); last_who = ""
	pick_rows = []
	for c in cards:
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", int(12 * u))
		var dash := _label(PICK_SIZE); dash.text = "—"
		var lb := _label(PICK_SIZE); lb.text = wrap_ja(T(String(c.text)), 34); lb.add_theme_constant_override("line_spacing", int(4 * u))
		row.add_child(dash); row.add_child(lb)
		lines_box.add_child(row)
		pick_rows.append({"card": c, "lb": lb})
	pick_idx = 0
	_show_pick()
	note_lb.text = T("［Ｗ／Ｓ　言葉を選ぶ］　［Ｅ　言う］")
	# the room goes on: the camera comes in, the interviewer waits, Mio looks down at her hands
	if choose_cam:
		frames = _choose_frames(); frame_dt = 1.0 / FPS; frame_t = 0.0; _set_cam(frames[0])
	choose_cam = false
	if ppl.has("mio"): ppl.mio.look_to = Vector2(0, 7.0); ppl.mio.tense = 0.6
	if ppl.has("kikite"): ppl.kikite.look_to = Vector2(-2.0, 2.0)
	picking = true; pick_go = false
	var wait_t := 0.0
	while not pick_go:
		await get_tree().process_frame
		wait_t += get_process_delta_time() * demo_k
		if demo and wait_t > 3.0: pick_idx = _demo_choice(); _show_pick(); pick_go = true
	picking = false
	note_lb.text = ""
	var card: Dictionary = pick_rows[pick_idx].card
	for i in pick_rows.size():
		if i != pick_idx: _strike(pick_rows[i].lb)
	await _hold(0.9)
	_clear(lines_box)
	var lie := not bool(card.truth)
	print("SAY 澪：%s" % String(card.text))
	print("IV answer %s %s" % ["嘘=" + String(card.lie) if lie else "本当", String(card.text).substr(0, 12)])
	# she says it: her mouth's cut, the line at the foot of the frame. A lie: her hands close in her lap as she says it
	_cut("澪_口元")
	if ppl.has("mio"):
		ppl.mio.look_to = Vector2(0, 3.0)
		if lie: ppl.mio.fist_to = 1.0; ppl.mio.tense = 1.0
		else: ppl.mio.tense = 0.2
	if ppl.has("kikite"): ppl.kikite.look_to = Vector2.ZERO
	var lb2 := _say_row("澪", String(card.text))
	# the pen's sound comes in half a beat before its picture
	var n := lb2.text.length()
	lb2.visible_characters = 0
	var t := 0.0; var pen_in := false
	skip = false
	while t * 20.0 < n:
		await get_tree().process_frame
		t += get_process_delta_time() * demo_k
		if skip: skip = false; break
		lb2.visible_characters = mini(n, int(t * 20.0))
	lb2.visible_characters = -1
	if lie: _cut("澪_拳")   # 2026-11-22（全体レビュー 2）: the fist was never in a picture; it closes here, seen
	await _hold(0.6 + n * 0.03 + (1.2 if lie else 0.0))
	Snd.one(self, "c7_pencil", -14.0)
	await _hold(0.45)
	# the pen: a true answer is written down at length; at a lie the pen stops for a moment, then goes on a little
	_form("kikite", "write", 0.5)
	_cut("ペン")
	var stops := false
	for r in card.reply:
		if String(r.get("do", "")) == "pen_stop": stops = true
	if ppl.has("kikite"):
		ppl.kikite.pen = "write"; ppl.kikite.pen_t = 0.0
		if lie or stops:
			await _hold(0.8)
			ppl.kikite.pen = "stop"; ppl.kikite.pen_t = 0.0
			print("IV pen stop")
			await _hold(1.4)
			ppl.kikite.pen = "write"; ppl.kikite.pen_t = 0.0
			await _hold(0.9)
		else:
			print("IV pen write")
			await _hold(3.2)
		ppl.kikite.pen = ""
	# 受けの画
	# 試作276 の感想（点検5「本当の答えのとき、聞き手の口元が笑って見える」、ユーザー OK 2026-11-23）: the head has no mouth that
	# moves (one Tripo mesh, its smile in it). On a true answer the receiving cut stays at her chest, the pen in it: the mouth
	# out of the picture. On a lie it goes down to the chin and the mouth, as before (the smile then reads as knowing)
	_still(RECEIVE[which] if lie else RECEIVE[1])
	if lie: get_tree().create_timer(3.0 / demo_k).timeout.connect(_unfist)
	for r in card.reply:
		if String(r.get("do", "")) in ["pen_stop", "pen_write"]: continue
		await _one(r)

func _unfist():
	if ppl.has("mio"): ppl.mio.fist_to = 0.0; ppl.mio.tense = 0.3

func _demo_choice() -> int:
	# the unattended run: the lie where there is one (--ivlie), else the first true answer
	for i in pick_rows.size():
		if demo_lie != bool(pick_rows[i].card.truth): return i
	return 0

# check stills: --ivstill=名前[@コマ][+形][+fist][+deck][+meishi][+tv=on|tape],…  --ivout=フォルダ（1枚ずつ撮って終わる）
func _stills(spec: String):
	var out := "/tmp"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ivout="): out = a.substr(8)
	if Main.COVER and is_instance_valid(Main.COVER): Main.COVER.queue_free()
	Main.COVER = null
	var k := 0
	for item in spec.split(","):
		var parts := item.split("+")
		var nm := parts[0].get_slice("@", 0); var fr := int(parts[0].get_slice("@", 1)) if parts[0].contains("@") else 0
		var form := "seiza"; var fist := 0.0
		for q in range(1, parts.size()):
			var w := String(parts[q])
			if w == "fist": fist = 1.0
			elif w == "deck": deck_root.visible = true
			elif w == "meishi": meishi.visible = true
			elif w == "cuff": cuff_on = true
			elif w.begins_with("tv="):
				if screen_mat: screen_mat.set_shader_parameter("on", 1.0 if w == "tv=on" else 2.0)
				if screen_lb and w != "tv=on": screen_lb.text = "ＲＥＣ　２：００"
			elif w.begins_with("t="): t_scene = float(w.substr(2))
			else: form = w
		if ppl.has("kikite"): ppl.kikite.from = form; ppl.kikite.to = form; ppl.kikite.k = 1.0; ppl.kikite.pen = ""
		if ppl.has("mio"): ppl.mio.fist = fist; ppl.mio.fist_to = fist
		for p in ppl: _pose(ppl[p], 0.0)
		if cuff_on and not cuff_done: cuff_done = true; _cuff_stain()
		if SHOTS.has(nm) or cuts.shots.has(nm):
			_cut(nm); var fs := frames; frames = []; _set_cam(fs[clampi(fr, 0, fs.size() - 1)])
		else: _still(nm)
		for i in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [out, k, item.replace("@", "_").replace("+", "_").replace("=", "")]); k += 1
	get_tree().quit()

# ================================================================ the script runner
var ended := false
func _run():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ivstill="): await _stills(a.substr(10)); return
	var nm: String = ["", "一", "二", "三"][which]
	if not blocks.has(nm): print("SCRIPT ERROR interview: no block for ", which); _finish(); return
	await _block(nm)
	if not ended: _finish()

func _block(name: String):
	if not blocks.has(name): print("SCRIPT ERROR interview: no block ", name); fails += 1; return
	print("IV block ", name)
	var q: Array = blocks[name]
	var i := 0
	while i < q.size() and not ended:
		var e: Dictionary = q[i]; i += 1
		if e.has("do") and String(e["do"]) == "go":
			var to := String(e.arg)
			if blocks.has(to): await _block(to)
			else: print("IV go ", to); _finish()
			return
		await _one(e)

func _one(e: Dictionary):
	if e.has("cond") and not flag(String(e.cond)): return
	if e.has("who"):
		var text := String(e.text)
		print("SAY %s：%s" % [e.who, text])
		if e.who == "澪" and ppl.has("mio"): ppl.mio.look_to = Vector2(0, 4.0)
		await _type(_say_row(String(e.who), text))
	elif e.has("note"):
		print("SAY %s" % e.note)
		note_lb.text = T(String(e.note)); await _hold(2.2); note_lb.text = ""
	elif e.has("pick"):
		await _pick(e)
	elif e.has("do"):
		var a := String(e.arg)
		match String(e["do"]):
			"card": await _card(a)
			"cut":
				var d := _cut(a, float(e.arg2) if String(e.arg2) != "" else 0.0)
				# a cut that moves is watched to its end before the talk goes on, unless it was given a length to talk over
				if String(e.arg2) == "" and frames.size() > 1 and _moves(a): await _hold(d)
			"cam": _still(a)
			"hand": _form("kikite", a if a != "none" else "seiza")
			"wait": await _hold(float(a))
			# 2026-11-28 (user: "証言二の選択音はなしにします"): the novel-game "decision" chime never sounds, even if a script asks for it
			"sound": if a != "決定": Snd.one(self, a, -6.0)
			"choose_in": choose_cam = true
			"fist":
				if ppl.has("mio"):
					ppl.mio.fist_to = 1.0; ppl.mio.tense = 1.0
					get_tree().create_timer(3.5 / demo_k).timeout.connect(_unfist)
			"pen_write":
				_form("kikite", "write", 0.5)
				if ppl.has("kikite"): ppl.kikite.pen = "write"; ppl.kikite.pen_t = 0.0
			"pen_stop":
				if ppl.has("kikite"): ppl.kikite.pen = "stop"; ppl.kikite.pen_t = 0.0
			"glance_hands":
				# she looks down at Mio's hands once, says nothing
				if ppl.has("kikite"):
					ppl.kikite.look_to = Vector2(0, 14.0)
					await _hold(1.4)
					ppl.kikite.look_to = Vector2.ZERO
			"cuff_stain": _cuff_stain()
			"card_on_table": await _card_on_table()
			"deck_play": await _deck_play()
			"silence": await _silence()
			"end": _finish()
			_: print("SCRIPT ERROR interview: ＞", e["do"]); fails += 1

func _moves(name: String) -> bool:
	if SHOTS.has(name): return true
	if not cuts.shots.has(name): return false
	var fs: Array = cuts.shots[name]
	return fs.size() > 1 and (fs[0].loc != fs[-1].loc or fs[0].at != fs[-1].at or fs[0].lens != fs[-1].lens)

# 試作289（第6章の「消えずに残る物」、ユーザー OK 2026-11-25「袖口と電池、賛成」）: the cuff she wiped the tripod with
# (第6章) keeps a brown mark. The left one: 選ぶ_手元 looks at her left side. Pressed onto the cuff from the camera side, warm
# enough that the print gives it orange dots on the blue sweater. Nobody speaks of it
var cuff_on := false
var cuff_done := false
func _cuff_stain(bone := "hand_l", col := Color(0.62, 0.3, 0.12), amax := 0.8):
	if not ppl.has("mio"): return
	var sk: Skeleton3D = ppl.mio.sk
	var bi := sk.find_bone(bone)
	if bi < 0: print("STORY interview cuff: no bone ", bone); return
	var ba := BoneAttachment3D.new(); ba.bone_idx = bi; sk.add_child(ba)
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new(); rng.seed = 6
	# a smear along the cuff's edge (u = around the wrist), thin across it (v = along the arm), its edge worn by the wash
	var nz := FastNoiseLite.new(); nz.seed = 6; nz.frequency = 0.09
	for y in 64:
		for x in 64:
			var d := Vector2((x - 32) / 30.0, (y - 36) / 13.0).length() + nz.get_noise_2d(x, y) * 0.45 + rng.randf_range(-0.05, 0.05)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, clampf((1.0 - d) * 1.4, 0.0, amax)))
	var dc := Decal.new(); dc.texture_albedo = ImageTexture.create_from_image(img)
	dc.size = Vector3(0.06, 0.08, 0.045); dc.normal_fade = 0.0; dc.upper_fade = 0.0; dc.lower_fade = 0.0
	ba.add_child(dc)
	# the attachment follows the bone only after a frame; then the stain sits a few cm up the forearm from the wrist
	# (the bone's -Y), pressed straight down onto the back of the cuff (her hands rest in her lap)
	await get_tree().process_frame; await get_tree().process_frame
	if not is_instance_valid(dc): return
	dc.position = Vector3(0, -0.012, 0); dc.global_basis = Basis(Vector3.BACK, PI / 2.0); dc.global_position += Vector3.UP * 0.012
	print("STORY interview cuff stain at ", dc.global_position)

# 名刺：her hand goes out flat over the table with the card under her fingers, and leaves it in front of Mio
func _card_on_table():
	print("IV meishi")
	_cut("名刺")
	_form("kikite", "stroke", 0.8)
	# 2026-11-27（ユーザー赤字 #432「名刺を投げるアニメーションはやめたい。やるなら机の上に置いた名刺を示すとか」）: the card is
	# already on the table in front of Mio; her hand goes out to it and rests by it a moment (it no longer slides)
	meishi.visible = true
	meishi.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(4.0)), b2g(MEISHI_DOWN))
	await _hold(1.6)
	_form("kikite", "seiza", 1.0)
	await _hold(1.2)

# the deck: she has brought it; the tape goes in (heard), the set comes on, its blue, then the tape's picture
func _deck_play():
	print("IV deck")
	if ppl.has("kikite"): ppl.kikite.look_to = Vector2(-18.0, 4.0)
	if ppl.has("mio"): ppl.mio.look_to = Vector2(16.0, 2.0)
	_cut("テレビ_引き")
	deck_root.visible = true
	Snd.one(self, "cassette_in", -8.0)
	await _hold(1.3)
	Snd.one(self, "tape_clunk", -8.0)
	await _hold(0.6)
	Snd.one(self, "iv_tv_on", -16.0)
	if screen_mat: screen_mat.set_shader_parameter("on", 1.0)
	await _hold(1.4)
	if screen_mat: screen_mat.set_shader_parameter("on", 2.0)
	if screen_lb: screen_lb.text = "ＲＥＣ　２：００"
	await _hold(1.0)

# 証言 二の終わり：she does not answer. Her hands in her lap, the room's sound, then the cut
func _silence():
	print("IV silence")
	_clear(lines_box)
	_cut("澪_手_沈黙")
	if ppl.has("mio"): ppl.mio.look_to = Vector2(0, 9.0); ppl.mio.tense = 0.8
	await _hold(4.5)

func _card(arg: String):
	var p := arg.split("｜")
	var rows := [[p[0].strip_edges(), 46, 40], [p[1].strip_edges() if p.size() > 1 else "", 150, 0]]
	var c: ColorRect = Main.make_card(self, rows, Type.card())
	print("SAY （カード）%s" % rows[1][0])
	await get_tree().process_frame; await get_tree().process_frame
	if Main.COVER and is_instance_valid(Main.COVER): Main.COVER.queue_free()
	Main.COVER = null
	await _hold(CARD_SEC)
	c.get_parent().queue_free()

func _finish():
	if ended: return
	ended = true
	print("DEMO DONE interview %d fails=%d" % [which, fails])
	if only: get_tree().quit(); return
	load("res://scripts/order.gd").go(self, "i%d" % which)

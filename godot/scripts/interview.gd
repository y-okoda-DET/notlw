## 証言 一・二・三：インタビューの部屋（数か月後、昼。澪の実家の客間）。2026-11-19「インタビューの証言一〜三を作る」のスレッド。
## 台本は story/interview.txt、並びは scripts/order.gd、部屋と人物は assets/interview/（blender/interview/export_interview.py）。
## 画・カメラ・刷りの決まりは docs/資料/インタビュー場面_ゲームへの入れ方_2026-11-16.md のとおり：
##   ・カメラは cuts.json のカットを 12 コマ／秒で（コマの間を補わない）。Blender の枠と同じになるようにレンズのずらしを frustum で。
##   ・昼の刷り（riso2 の look=2、網点 2.6）。聞き手の顔は、平たくなるまで画に出さない。澪の顔は見せない。
##   ・証言 三：一語が滑る → めまい → 版ずれ → 溶けて平たくなる（物の色だけ・立ち絵・書き起こしの窓・ロード）。
##
## The house is not loaded here: this node is its own scene (order.gd packs it), and at its end it goes on down the
## late chapters' order. The words on screen follow story.gd: what the interviewer says at the foot of the frame, what
## Mio answers top left under a short rule, what she did not say struck through with the transcriber's double line.
extends Node3D
const Type = preload("res://scripts/type.gd")
const Main = preload("res://scripts/main.gd")
const Snd = preload("res://scripts/sound.gd")
const A := "res://assets/interview/"
const FPS := 12.0
const PAPER := Color(0.945, 0.925, 0.875)
const INK := Color(0.0, 0.2, 0.42)
const BLUE := Color(0.0, 0.47, 0.75)
const ORANGE := Color(1.0, 0.424, 0.184)
const TEAL := Color(0.06, 0.36, 0.46)     # the window's type: where both inks overlap, lightened to read as print
const REC_TIME := "01:14:08"             # the recorder's display = every save's time (決定事項 2026-11-15, カット C)
const CARD_SEC := 3.2
const AMBIENT := 0.5
const SUN_DIR := Vector3(0.4, -0.45, 1.0)   # the way the sun goes (blender/interview/build.py: (0.4, -1.0, -0.45))

@export var which := 1

var u := 1.0
var demo := false
var demo_k := 1.0                 # the unattended run goes 40 times as fast (--demo); --demoslow: at the real pace, for check pictures
var only := false                 # --ivonly: quit at the end instead of going on (check runs)
var blocks := {}                  # 台本：name -> Array of entries
var cuts := {}
var cams := {}
var flat_colors := {}
var cam: Camera3D
var env: Environment
var riso: ShaderMaterial
var blur_mat: ShaderMaterial
var room: Node3D
var tree_base := Transform3D.IDENTITY
var mio: Node3D
var hands := {}                   # form -> Node3D
var hand_now := "seiza"
var hide_now: Array = []
var lights_3d: Array = []
var flat_on := false
var flat_saved := {}              # MeshInstance3D -> its material_override before
# camera playback
var frames: Array = []            # the running cut, one entry per 1/12 s
var frame_t := 0.0
var frame_dt := 1.0 / FPS
var orbit := 0.0                  # >0: seconds per turn (証言 三の回り込み)
var orbit_a := 20.0
# page
var page: Control
var lines_box: VBoxContainer
var tes_box: VBoxContainer
var note_lb: Label
var font: Font
var skip := false                 # E / click: finish the line being typed, or go on
# 証言 三
var slips: Array = []             # the answers taken back by loading (struck in the window and in the list)
var slipped_cards := {}           # card text -> true (cannot be said again)
var loaded := false               # she has loaded at least once: 「さっきも、そうおっしゃいましたね」
var win: Control                  # the flattened screen's layer (portrait, the transcript window)
var win_text: Label
var win_ghost: Label
var win_mark: Label
var win_load: Label
var win_struck: VBoxContainer
var portrait: TextureRect
var fails := 0

static func T(s: String) -> String: return String(TranslationServer.translate(s)).replace("​", "")
static func b2g(v) -> Vector3: return Vector3(v[0], v[2], -v[1])

func _ready():
	var args := OS.get_cmdline_user_args()
	demo = "--demo" in args or "--demoslow" in args; only = "--ivonly" in args
	demo_k = 40.0 if "--demo" in args else 1.0
	for a in args:
		if a.begins_with("--ivslip="): demo_slip = a.substr(9)
	u = get_viewport().get_visible_rect().size.y / 1080.0
	font = Type.say()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_read_script()
	cuts = JSON.parse_string(FileAccess.get_file_as_string(A + "cuts.json"))
	cams = JSON.parse_string(FileAccess.get_file_as_string(A + "cameras.json"))
	flat_colors = JSON.parse_string(FileAccess.get_file_as_string(A + "flat_colors.json")).objects
	_environment(); _room(); _lights(); _camera(); _print_layer(); _page()
	Type.Soft.k = 2.2   # the day room is paper white where the night was ink: the pool under the type is made heavier here only
	_run.call_deferred()

func _exit_tree():
	Type.Soft.k = 1.0

# ================================================================ 台本
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
			name = l.trim_prefix("【").trim_suffix("】"); blocks[name] = []; last_pick = {}; continue
		if name == "": continue
		var e := {}
		if indented and not last_card.is_empty() and l.contains("："):
			(last_card.reply as Array).append({"who": l.get_slice("：", 0), "text": l.substr(l.find("：") + 1)}); continue
		if l.begins_with("・") and not last_pick.is_empty():
			var parts := l.substr(1).split("｜")
			last_card = {"text": parts[0].strip_edges(), "slip": "", "reply": []}
			for k in range(1, parts.size()):
				if parts[k].begins_with("滑る="): last_card.slip = parts[k].substr(3).strip_edges()
			(last_pick.cards as Array).append(last_card); continue
		last_card = {}
		if l.begins_with("？"): e = {"pick": int(l.substr(1)), "cards": []}; last_pick = e
		elif l.begins_with("＞"):
			var w := l.substr(1).split(" ", false)
			e = {"do": w[0], "arg": w[1] if w.size() > 1 else "", "arg2": w[2] if w.size() > 2 else ""}
			if w[0] == "card": e.arg = l.substr(l.find("card") + 5)
		elif l.begins_with("（") or l.begins_with("［"): e = {"note": l}
		elif l.contains("："): e = {"who": l.get_slice("：", 0), "text": l.substr(l.find("：") + 1)}
		else: print("SCRIPT ERROR interview: line not understood: ", l); continue
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
			print("IV table_top ", m.get_active_material(0).roughness)
		if n.begins_with("rec_time") or n.begins_with("recorder_display"):
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for f in ["seiza", "pinch", "stroke", "write"]:
		var p := A + "kikite_%s.glb" % f
		if not ResourceLoader.exists(p): continue
		var h: Node3D = (load(p) as PackedScene).instantiate(); h.visible = false; add_child(h); hands[f] = h
		_two_sided(h)
	if ResourceLoader.exists(A + "mio_seiza.glb"):
		mio = (load(A + "mio_seiza.glb") as PackedScene).instantiate(); add_child(mio)
		_two_sided(mio)
	var probe := ReflectionProbe.new(); probe.position = Vector3(0, 0.9, 0); probe.size = Vector3(3.7, 2.4, 3.7)   # the low table's lacquer shows the shoji
	probe.update_mode = ReflectionProbe.UPDATE_ONCE; probe.interior = true; probe.ambient_mode = ReflectionProbe.AMBIENT_ENVIRONMENT
	probe.cull_mask = 1 | 2; probe.box_projection = true; probe.intensity = 1.0
	add_child(probe)

# The garden tree past the shoji is only its shadow on the paper. A paper lit from behind does not take a shadow here,
# so the leaves themselves are laid flat on each panel's near face, along the sun's way, as its shadow (the two panels
# slide past each other, 35 mm apart: one copy of the tree for each, cut to its panel)
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
				var m2: BaseMaterial3D = mat.duplicate(); m2.cull_mode = BaseMaterial3D.CULL_DISABLED
				m.set_surface_override_material(i, m2)

func _lights():
	# Blender lit the room with an area light the size of the shoji. Here: one soft sun-less "sky" from the north, low,
	# that the paper does not stop (shadow_caster_mask), a weak return from the south, and the sun itself on the paper's
	# back, where only the leaves and the lattice shadow it
	var sky := DirectionalLight3D.new(); sky.name = "sky"
	sky.light_color = Color(0.97, 0.98, 1.0); sky.light_energy = 1.8
	sky.rotation = Vector3(deg_to_rad(-16), deg_to_rad(180), 0)     # from the north (-z) down into the room
	sky.shadow_enabled = true; sky.light_angular_distance = 9.0; sky.shadow_blur = 2.0
	sky.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL; sky.directional_shadow_max_distance = 8.0
	sky.shadow_caster_mask = 1
	sky.light_specular = 0.0   # it stands for a light as large as the wall: no hard glint (the lacquer shows the shoji by the probe)
	sky.light_cull_mask = 1
	add_child(sky); lights_3d.append(sky)
	var fill := DirectionalLight3D.new(); fill.name = "fill"
	fill.light_color = Color(1.0, 0.97, 0.92); fill.light_energy = 0.22
	fill.rotation = Vector3(deg_to_rad(-25), 0, 0)                  # from the south
	fill.shadow_enabled = false; fill.light_cull_mask = 1; fill.light_specular = 0.0
	add_child(fill); lights_3d.append(fill)
	# the lacquer's sheen: the shoji as a soft glare on the table top, toward whoever looks north across it
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
	sun.light_cull_mask = 2                                          # it lights the paper only (the room has the sky)
	add_child(sun); lights_3d.append(sun)

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
		# Blender's rotation (0.02 sin t, 0.035 sin(t+0.7), 0) and x + 0.03 sin(t+1.3), in Godot's axes
		for tr in trees:
			tr.transform = tree_base
			tr.rotate_x(0.02 * sin(t)); tr.rotate_z(-0.035 * sin(t + 0.7)); tr.position.x = tree_base.origin.x + 0.03 * sin(t + 1.3)
	if riso: riso.set_shader_parameter("slip", Vector2(-26, 14) if String(f.get("post", "")) == "slip" else Vector2.ZERO)

func _show_people():
	for k in hands: (hands[k] as Node3D).visible = (k == hand_now) and not ("people" in hide_now) and not flat_on
	if mio: mio.visible = not ("mio" in hide_now) and not flat_on

# a cut: its frames laid out one per 1/12 s (hold = that many); sec > 0 stretches it to that length
func _cut(name: String, sec := 0.0) -> float:
	if not cuts.shots.has(name): print("SCRIPT ERROR interview: no cut ", name); fails += 1; return 0.0
	orbit = 0.0
	frames = []
	for f in cuts.shots[name]:
		for i in int(f.get("hold", 1)): frames.append(f)
	frame_dt = (sec / frames.size()) if sec > 0.0 else 1.0 / FPS
	frame_t = 0.0
	_set_cam(frames[0])
	return frames.size() * frame_dt

func _still(name: String):
	if not cams.has(name): print("SCRIPT ERROR interview: no camera ", name); fails += 1; return
	orbit = 0.0; frames = []
	var c: Dictionary = cams[name]
	_set_cam({"loc": c.loc, "at": c.at, "lens": c.lens, "shift_y": c.get("shift_y", 0.0), "hide": c.get("hide", [])})

func _process(dt: float):
	if frames.size() > 0:
		frame_t += dt
		var i := mini(int(frame_t / frame_dt), frames.size() - 1)
		_set_cam(frames[i])
	elif orbit > 0.0:
		# 証言 三：the camera goes round the table and does not stop, stepping at the print's 12 a second
		orbit_a += dt * 360.0 / orbit
		var a := deg_to_rad(snappedf(orbit_a, 360.0 / orbit / FPS))
		_set_cam({"loc": [1.30 * sin(a), 0.10 - 1.30 * cos(a), 0.50], "at": [0, 0.10, 0.50], "lens": 40.0, "shift_y": -0.12, "hide": []})

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

# ================================================================ the page (as story.gd sets it)
func _label(size: float, col := Color(0, 0, 0, 0), shadow := true) -> Label:
	var lb := Label.new()
	lb.add_theme_font_override("font", font)
	lb.add_theme_font_size_override("font_size", int(size * u))
	lb.add_theme_color_override("font_color", PAPER if col.a == 0.0 else col)
	if shadow: Type.soft(lb, u)
	lb.autowrap_mode = TextServer.AUTOWRAP_OFF
	lb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return lb

func _page():
	var layer := CanvasLayer.new(); layer.layer = 13; add_child(layer)
	page = Control.new(); page.set_anchors_preset(Control.PRESET_FULL_RECT); page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(page)
	lines_box = VBoxContainer.new()
	lines_box.anchor_left = 0.1; lines_box.anchor_right = 0.9; lines_box.anchor_top = 1.0; lines_box.anchor_bottom = 1.0
	lines_box.offset_bottom = -64 * u; lines_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lines_box.add_theme_constant_override("separation", int(4 * u))
	page.add_child(lines_box)
	tes_box = VBoxContainer.new()
	tes_box.anchor_left = 0.075; tes_box.anchor_right = 0.7; tes_box.anchor_top = 0.0; tes_box.anchor_bottom = 0.0
	tes_box.offset_top = 92 * u
	tes_box.add_theme_constant_override("separation", int(12 * u))
	page.add_child(tes_box)
	note_lb = _label(26)
	note_lb.anchor_left = 0.075; note_lb.anchor_top = 1.0; note_lb.anchor_bottom = 1.0
	note_lb.offset_top = -66 * u; note_lb.offset_bottom = -30 * u
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

# a row under a short rule, top left (her answer); returns its Label
func _tes_row(text: String, size := 26.0) -> Label:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", int(14 * u))
	var rule := ColorRect.new(); rule.color = Color(PAPER.r, PAPER.g, PAPER.b, 0.85)
	rule.custom_minimum_size = Vector2(26 * u, 2 * u); rule.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var holder := MarginContainer.new(); holder.add_theme_constant_override("margin_top", int(17 * u)); holder.add_child(rule)
	row.add_child(holder)
	var lb := _label(size); lb.text = wrap_ja(T(text), 34); lb.add_theme_constant_override("line_spacing", int(6 * u))
	row.add_child(lb)
	tes_box.add_child(row)
	return lb

func _say_row(who: String, text: String) -> Label:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", int(14 * u)); row.alignment = BoxContainer.ALIGNMENT_CENTER
	var lb := _label(32.0); lb.text = wrap_ja(T(text), 30); lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(lb)
	lines_box.add_child(row)
	while lines_box.get_child_count() > 2:
		var c := lines_box.get_child(0); lines_box.remove_child(c); c.queue_free()
	for i in range(lines_box.get_child_count()):
		(lines_box.get_child(i) as Control).modulate.a = 1.0 if i == lines_box.get_child_count() - 1 else 0.62
	return lb

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
		elif asking_load:
			if e.keycode == KEY_L: load_answer = "load"
			elif e.keycode in [KEY_E, KEY_ENTER, KEY_SPACE]: load_answer = "go"
		elif e.keycode in [KEY_E, KEY_ENTER, KEY_SPACE]: skip = true
		if e.keycode == KEY_F12: _save_frame()
	elif e is InputEventMouseButton and e.pressed:
		if picking:
			if e.button_index == MOUSE_BUTTON_WHEEL_UP: _move_pick(-1)
			elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: _move_pick(1)
			elif e.button_index == MOUSE_BUTTON_LEFT: pick_go = true
		elif asking_load:
			if e.button_index == MOUSE_BUTTON_LEFT:
				load_answer = "load" if (win_load and win_load.get_global_rect().grow(18 * u).has_point(e.position)) else "go"
		elif e.button_index == MOUSE_BUTTON_LEFT: skip = true

func _save_frame():
	var d := OS.get_executable_path().get_base_dir()
	get_viewport().get_texture().get_image().save_png("%s/shot_interview%d_%d.png" % [d, which, Time.get_ticks_msec()])

# ================================================================ answering: the cards
var picking := false
var pick_go := false
var pick_idx := 0
var pick_rows: Array = []         # [{card, lb, taken}]
var demo_slip := ""               # --ivslip=語: the unattended run says the line with this word (証言 三)
var demo_slip_done := false

func _move_pick(d: int):
	var n := pick_rows.size()
	for k in n:
		pick_idx = posmod(pick_idx + d, n)
		if not pick_rows[pick_idx].taken and not pick_rows[pick_idx].dead: break
	_show_pick()

func _show_pick():
	for i in pick_rows.size():
		var r: Dictionary = pick_rows[i]
		var a := 1.0 if (r.taken or i == pick_idx) else 0.74
		if r.dead: a = 0.5
		(r.lb as Label).add_theme_color_override("font_color", Color(PAPER.r, PAPER.g, PAPER.b, a))

func _strike(lb: Label, dur := 0.9):
	var st = load("res://scripts/story.gd").Strike.new()
	st.u = u; st.anim = dur
	var w := 0.0
	for ln in lb.text.split("\n"): w = maxf(w, font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, lb.get_theme_font_size("font_size")).x)
	# one double line per line of the sentence
	var lh := font.get_height(lb.get_theme_font_size("font_size")) + lb.get_theme_constant("line_spacing")
	var lines := lb.text.split("\n")
	for i in lines.size():
		var s2 = st if i == 0 else load("res://scripts/story.gd").Strike.new()
		s2.u = u; s2.anim = dur
		s2.w = font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, lb.get_theme_font_size("font_size")).x
		s2.position = Vector2(0, i * lh); s2.size = Vector2(s2.w, font.get_height(lb.get_theme_font_size("font_size")))
		s2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lb.add_child(s2)

# the question's cards on the page; she says `n` of them. Returns the cards said, in order; stops early with the card
# that slipped (証言 三) as the last one
func _pick(e: Dictionary) -> Array:
	_clear(tes_box)
	pick_rows = []
	for c in e.cards:
		var lb := _tes_row(String(c.text), 25.0)
		var dead: bool = slipped_cards.has(String(c.text))
		pick_rows.append({"card": c, "lb": lb, "taken": false, "dead": dead})
		if dead: _strike(lb, 0.0)
	pick_idx = 0
	for i in pick_rows.size():
		if not pick_rows[i].dead: pick_idx = i; break
	_show_pick()
	note_lb.text = T("［Ｗ／Ｓ　言葉を選ぶ］　［Ｅ　言う］")
	var said: Array = []
	var need := int(e.pick)
	while said.size() < need:
		picking = true; pick_go = false
		if demo:
			await _hold(0.6)
			pick_idx = _demo_choice()
			_show_pick(); pick_go = true
		while not pick_go: await get_tree().process_frame
		picking = false
		var r: Dictionary = pick_rows[pick_idx]
		if r.taken or r.dead: continue
		r.taken = true; said.append(r.card)
		print("SAY 澪＊：%s" % String(r.card.text))
		var slip := String(r.card.slip)
		# she says it: the line is typed again over itself, and a slipping word stops everything where it falls
		var lb: Label = r.lb
		var full := lb.text
		var stop_at := full.length()
		if slip != "" and which == 3:
			var k := full.replace("\n", "").find(slip)
			if k >= 0: stop_at = _index_with_breaks(full, k + slip.length())
		lb.add_theme_color_override("font_color", PAPER)
		var t := 0.0
		lb.visible_characters = 0
		while int(t * 20.0) < stop_at:
			await get_tree().process_frame
			t += get_process_delta_time() * demo_k
			lb.visible_characters = mini(stop_at, int(t * 20.0))
		if slip != "" and which == 3:
			note_lb.text = ""
			return said
		lb.visible_characters = -1
		await _hold(0.5)
		if said.size() < need: _move_pick(1)
	note_lb.text = ""
	# what she did not say stays on the page struck through, then the page is left with her answer
	for r in pick_rows:
		if not r.taken and not r.dead: _strike(r.lb)
	await _hold(1.6)
	for r in pick_rows:
		if not r.taken: (r.lb as Label).get_parent().queue_free()
	await _hold(0.9)
	return said

func _index_with_breaks(full: String, n_plain: int) -> int:
	var seen := 0
	for i in full.length():
		if full[i] != "\n": seen += 1
		if seen >= n_plain: return i + 1
	return full.length()

func _demo_choice() -> int:
	# the unattended run: the first card not yet said; in 証言 三 the slipping card once (--ivslip=語, default こっちへ), then the safe ones
	var want := demo_slip if demo_slip != "" else "こっちへ"
	if which == 3 and not demo_slip_done:
		for i in pick_rows.size():
			if String(pick_rows[i].card.slip) == want and not pick_rows[i].dead and not pick_rows[i].taken: demo_slip_done = true; return i
	for i in pick_rows.size():
		if not pick_rows[i].taken and not pick_rows[i].dead and String(pick_rows[i].card.slip) == "": return i
	return 0

# check stills: --ivstill=名前[@コマ][+手の形][+flat],…  --ivout=フォルダ（カットかカメラの名前。1枚ずつ撮って終わる）
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
		hand_now = "seiza"
		var want_flat := false
		for q in range(1, parts.size()):
			if parts[q] == "flat": want_flat = true
			else: hand_now = parts[q]
		if cuts.shots.has(nm):
			_cut(nm); var fs := frames; frames = []; _set_cam(fs[clampi(fr, 0, fs.size() - 1)])
		else: _still(nm)
		if want_flat: await _flatten()
		for i in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [out, k, item.replace("@", "_").replace("+", "_")]); k += 1
		if want_flat: _unflatten()
	get_tree().quit()

# ================================================================ the script runner
var ended := false
func _run():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ivstill="): await _stills(a.substr(10)); return
	# its card first (the cover from the chapter before comes off once the card is up)
	var first: Array = blocks.get(["", "一", "二", "三"][which], [])
	if first.is_empty(): print("SCRIPT ERROR interview: no block for ", which); _finish(); return
	await _block(["", "一", "二", "三"][which])
	if not ended: _finish()

func _block(name: String):
	if not blocks.has(name): print("SCRIPT ERROR interview: no block ", name); fails += 1; return
	print("IV block ", name)
	var q: Array = blocks[name]
	var i := 0
	while i < q.size() and not ended:
		var e: Dictionary = q[i]; i += 1
		if e.has("who"):
			var text := String(e.text)
			if text.contains("%s"): text = text % last_slip
			print("SAY %s：%s" % [e.who, text])
			if e.who == "澪":
				_clear(tes_box); await _type(_tes_row(text), 20.0, 1.6)
			elif flat_on: await _win_say(text)
			else: await _type(_say_row(String(e.who), text))
		elif e.has("note"):
			print("SAY %s" % e.note)
			note_lb.text = T(String(e.note)); await _hold(2.2); note_lb.text = ""
		elif e.has("pick"):
			var said: Array = await _pick(e)
			if which == 3 and said.size() > 0 and String(said[-1].slip) != "":
				last_slip = String(said[-1].slip); last_slip_card = String(said[-1].text)
				await _block("三.滑る"); return
			if which == 3 and name == "三.問い" and loaded:
				_clear(lines_box); await _block("三.覚えている"); return
			_clear(lines_box)
			for c in said:
				for r in c.reply:
					print("SAY %s：%s" % [r.who, r.text]); await _type(_say_row(String(r.who), String(r.text)))
		elif e.has("do"):
			match String(e["do"]):
				"card": await _card(String(e.arg))
				"cut":
					var d := _cut(String(e.arg), float(e.arg2) if String(e.arg2) != "" else 0.0)
					# a cut that moves is watched to its end before the talk goes on, unless it was given a length to talk over
					if String(e.arg2) == "" and frames.size() > 1 and _moves(String(e.arg)): await _hold(d)
				"cam": _still(String(e.arg))
				"orbit": frames = []; orbit = float(e.arg); orbit_a = 20.0
				"hand": hand_now = String(e.arg); _show_people()
				"wait": await _hold(float(e.arg))
				"sound": Snd.one(self, {"決定": "iv_kettei"}.get(String(e.arg), String(e.arg)), -6.0)
				"flat": await _flatten()
				"unflat": _unflatten()
				"load": await _ask_load(); return
				"save": await _save_list(true)
				"go": await _block(String(e.arg)); return
				"end": _finish(); return
				_: print("SCRIPT ERROR interview: ＞", e["do"]); fails += 1

func _moves(name: String) -> bool:
	var fs: Array = cuts.shots[name]
	return fs.size() > 1 and (fs[0].loc != fs[-1].loc or fs[0].at != fs[-1].at or fs[0].lens != fs[-1].lens)

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

# ================================================================ 証言 三：平たくなる、ロード
var last_slip := ""
var last_slip_card := ""
var asking_load := false
var load_answer := ""

const WIN_BLUR := """shader_type canvas_item;
uniform float px = 0.0;
uniform float alpha = 1.0;
void fragment() {
	vec4 c = vec4(0.0); float w = 0.0;
	for (int i = -3; i <= 3; i++) for (int j = -3; j <= 3; j++) {
		float k = exp(-float(i * i + j * j) / 6.0);
		c += texture(TEXTURE, UV + vec2(float(i), float(j)) * px / 3.0 * TEXTURE_PIXEL_SIZE) * k; w += k; }
	c /= w; COLOR = vec4(c.rgb, c.a * alpha);
}"""

# the slipped frame is held as a picture and dissolved, blurring, into the flattened room; then the window, and the
# portrait rising out of a blur with its orange plate coming into register last (決定事項 2026-11-16)
func _flatten():
	await get_tree().process_frame
	var img: Image = null if DisplayServer.get_name() == "headless" else get_viewport().get_texture().get_image()
	var layer := CanvasLayer.new(); layer.layer = 11; add_child(layer)
	var hold := TextureRect.new()
	if img: hold.texture = ImageTexture.create_from_image(img)
	hold.set_anchors_preset(Control.PRESET_FULL_RECT); hold.stretch_mode = TextureRect.STRETCH_SCALE; hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new(); sh.code = WIN_BLUR
	var hm := ShaderMaterial.new(); hm.shader = sh; hold.material = hm
	layer.add_child(hold)
	_clear(tes_box); _clear(lines_box)
	# under it, the room without light: each thing its own flat colour, no people, three flat inks
	flat_on = true; _show_people()
	riso.set_shader_parameter("slip", Vector2.ZERO); riso.set_shader_parameter("flat_ink", 1.0)
	for l in lights_3d: (l as Light3D).visible = false
	for t in trees: (t as Node3D).visible = false
	env.ssao_enabled = false; env.ambient_light_energy = 0.0
	for mi in room.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		flat_saved[m] = m.material_override
		var fm := StandardMaterial3D.new(); fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var c = _flat_colour(String(m.name))
		fm.albedo_color = Color(c[0], c[1], c[2]) if c != null else Color(0.8, 0.78, 0.74)
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.material_override = fm
	_still("k3c_聞き手_口元"); hide_now = ["mio", "people"]; _show_people()
	for k in 10:   # 10 コマ：溶かし前半
		var t := float(k + 1) / 10.0; var e := t * t * (3.0 - 2.0 * t)
		hm.set_shader_parameter("px", 14.0 * u * e); hm.set_shader_parameter("alpha", 1.0 - e)
		await _frames12(1)
	layer.queue_free()
	_window()
	var pm: ShaderMaterial = portrait.material
	for k in 14:   # 14 コマ：窓は最初から、立ち絵が立ち上がる
		var t := float(k + 1) / 14.0; var e := t * t * (3.0 - 2.0 * t)
		portrait.modulate.a = minf(1.4 * t, 1.0) * minf(1.4 * t, 1.0) * (3.0 - 2.0 * minf(1.4 * t, 1.0))
		portrait_shadow.modulate.a = e
		pm.set_shader_parameter("px", 18.0 * u * (1.0 - e)); pm.set_shader_parameter("split", 24.0 * u * (1.0 - e))
		await _frames12(1)
	portrait.modulate.a = 1.0; portrait_shadow.modulate.a = 1.0

func _frames12(n: int):
	await _hold(n / FPS)

func _flat_colour(n: String):
	if flat_colors.has(n): return flat_colors[n]
	for k in flat_colors:   # Godot renames "a.001" to "a_001"
		if String(k).replace(".", "_") == n: return flat_colors[k]
	var best = null; var bl := 0
	for k in flat_colors:
		if n.begins_with(String(k).replace(".", "_")) and String(k).length() > bl: best = flat_colors[k]; bl = String(k).length()
	return best

func _unflatten():
	if not flat_on: return
	flat_on = false
	riso.set_shader_parameter("flat_ink", 0.0)
	for l in lights_3d: (l as Light3D).visible = true
	for t in trees: (t as Node3D).visible = true
	env.ssao_enabled = true; env.ambient_light_energy = AMBIENT
	for m in flat_saved:
		if is_instance_valid(m): (m as MeshInstance3D).material_override = flat_saved[m]
	flat_saved = {}
	if win: win.get_parent().queue_free(); win = null
	_show_people()

const PORTRAIT_SH := """shader_type canvas_item;
uniform float px = 0.0;      // blur
uniform float split = 0.0;   // the orange plate off register (px)
uniform vec3 paper = vec3(0.945, 0.925, 0.875);
void fragment() {
	// blue first: the picture's warm part (what the orange plate printed) comes in from the side as `split` closes
	vec4 a = vec4(0.0), b = vec4(0.0); float w = 0.0;
	vec2 off = vec2(split, -split * 0.5) * TEXTURE_PIXEL_SIZE;
	for (int i = -3; i <= 3; i++) for (int j = -3; j <= 3; j++) {
		float k = exp(-float(i * i + j * j) / 6.0);
		vec2 d = vec2(float(i), float(j)) * px / 3.0 * TEXTURE_PIXEL_SIZE;
		a += texture(TEXTURE, UV + d) * k; b += texture(TEXTURE, UV + off + d) * k; w += k; }
	a /= w; b /= w;
	float warm_a = clamp((a.r - a.b) * 2.0, 0.0, 1.0), warm_b = clamp((b.r - b.b) * 2.0, 0.0, 1.0);
	vec3 blue_only = mix(a.rgb, paper * vec3(dot(a.rgb, vec3(0.3, 0.6, 0.1)) / 0.9), warm_a);
	vec3 orange = mix(vec3(1.0), b.rgb / max(paper, vec3(0.01)), warm_b * b.a);
	vec3 o = (split > 0.5) ? blue_only * orange : a.rgb;
	COLOR = vec4(o, a.a) * COLOR;
}"""

const SHADOW_SH := """shader_type canvas_item;
uniform float cell = 4.2;
void fragment() {
	float a = texture(TEXTURE, UV).a;
	float t = radians(15.0);
	vec2 r = vec2(FRAGCOORD.x * cos(t) + FRAGCOORD.y * sin(t), -FRAGCOORD.x * sin(t) + FRAGCOORD.y * cos(t)) / cell;
	float d = length(fract(r) - 0.5);
	COLOR = vec4(0.0, 0.47, 0.75, step(0.5, a) * step(d, 0.30) * COLOR.a);
}"""
var portrait_shadow: TextureRect

class Dots extends Control:
	# a flat screen of the blue plate's dots (a shadow under cut paper; the selected record's ground)
	var cell := 5.0
	var col := Color(0.0, 0.47, 0.75)
	func _draw():
		var a := deg_to_rad(15.0)
		var r := cell * 0.27
		var n := int((size.x + size.y) / cell) + 4
		for i in range(-n, n):
			for j in range(-n, n):
				var p := Vector2(i * cell * cos(a) - j * cell * sin(a), i * cell * sin(a) + j * cell * cos(a))
				if p.x > 0 and p.y > 0 and p.x < size.x and p.y < size.y: draw_circle(p, r, col)

func _ink_label(size: float, col: Color, f: Font = null) -> Label:
	var lb := Label.new()
	lb.add_theme_font_override("font", f if f else font); lb.add_theme_font_size_override("font_size", int(size * u))
	lb.add_theme_color_override("font_color", col)
	lb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return lb

# the transcript window: a sheet of the transcript laid over the foot of the frame (square corners, a flat dot shadow),
# the name on a slip of cut paper, the type in ink (not knocked out: it is on paper), 「ロード」 bottom right
func _window():
	var vs := get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new(); layer.layer = 11; add_child(layer)
	win = Control.new(); win.set_anchors_preset(Control.PRESET_FULL_RECT); win.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(win)
	# the portrait: cut out of paper (the white allowance is in the picture), a flat dot shadow behind it
	portrait = TextureRect.new(); portrait.texture = load(A + "portrait_2_真顔.png")
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var ph := vs.y * 0.917
	portrait.size = Vector2(ph * portrait.texture.get_width() / portrait.texture.get_height(), ph)
	portrait.position = Vector2((vs.x - portrait.size.x) / 2.0, 0.0)
	var psh := Shader.new(); psh.code = PORTRAIT_SH
	var pm := ShaderMaterial.new(); pm.shader = psh; portrait.material = pm
	portrait.modulate.a = 0.0
	# its shadow: the cut-out's shape in flat blue dots, down and to the right
	var shd := TextureRect.new(); shd.texture = portrait.texture; shd.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; shd.stretch_mode = portrait.stretch_mode
	shd.size = portrait.size; shd.position = portrait.position + Vector2(14, 12) * u
	var ssh := Shader.new(); ssh.code = SHADOW_SH; var sm := ShaderMaterial.new(); sm.shader = ssh; sm.set_shader_parameter("cell", 4.2 * u); shd.material = sm
	shd.modulate.a = 0.0; portrait_shadow = shd
	win.add_child(shd)
	win.add_child(portrait)
	var top := vs.y * 0.741
	var sheet := ColorRect.new(); sheet.color = PAPER; sheet.position = Vector2(0, top); sheet.size = Vector2(vs.x, vs.y - top)
	var edge := Dots.new(); edge.position = Vector2(0, top - 7 * u); edge.size = Vector2(vs.x, 7 * u); edge.cell = 4.2 * u
	win.add_child(edge); win.add_child(sheet)
	# the name slip
	var slip := ColorRect.new(); slip.color = PAPER; slip.position = Vector2(150 * u, top - 46 * u); slip.size = Vector2(220 * u, 56 * u); slip.rotation = deg_to_rad(-0.6)
	var sdots := Dots.new(); sdots.position = slip.position + Vector2(6, 5) * u; sdots.size = slip.size; sdots.cell = 4.2 * u; sdots.rotation = slip.rotation
	win.add_child(sdots); win.add_child(slip)
	var nm := _ink_label(30, INK, Type.card()); nm.text = T("聞き手"); nm.position = Vector2(64 * u, 6 * u); slip.add_child(nm)
	# what she has taken back, struck through, piles up in the window
	win_struck = VBoxContainer.new(); win_struck.position = Vector2(290 * u, top + 96 * u); win_struck.add_theme_constant_override("separation", int(4 * u))
	win.add_child(win_struck)
	for s in slips: _win_strike_row(String(s), 0.0)
	win_ghost = _ink_label(32, Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.85)); win_ghost.position = Vector2(288 * u, top + 28 * u) + Vector2(-2, 2) * u; win.add_child(win_ghost)
	win_text = _ink_label(32, INK); win_text.position = Vector2(288 * u, top + 28 * u); win.add_child(win_text)
	win_mark = _ink_label(26, BLUE); win_mark.text = "▼"; win_mark.visible = false; win.add_child(win_mark)
	win_load = _ink_label(30, BLUE, Type.card()); win_load.text = T("ロード")
	win_load.position = Vector2(vs.x - 210 * u, vs.y - 86 * u); win.add_child(win_load)
	var ul := ColorRect.new(); ul.color = BLUE; ul.position = Vector2(-28 * u, 46 * u); ul.size = Vector2(118 * u, 2 * u); win_load.add_child(ul)

func _win_strike_row(text: String, dur: float):
	var lb := _ink_label(22, Color(BLUE.r, BLUE.g, BLUE.b, 0.9)); lb.text = text
	win_struck.add_child(lb)
	var st = load("res://scripts/story.gd").Strike.new(); st.u = u; st.anim = dur; st.col = BLUE
	st.w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * u)).x
	st.size = Vector2(st.w, font.get_height(int(22 * u))); st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.add_child(st)

# a line in the window: typed, then the ▼ waits for E / click
func _win_say(text: String):
	win_mark.visible = false
	win_text.text = wrap_ja(T(text), 40); win_ghost.text = win_text.text
	var n := win_text.text.length(); var t := 0.0
	skip = false
	while int(t * 22.0) < n:
		win_text.visible_characters = int(t * 22.0); win_ghost.visible_characters = win_text.visible_characters
		await get_tree().process_frame
		t += get_process_delta_time() * demo_k
		if skip: skip = false; break
	win_text.visible_characters = -1; win_ghost.visible_characters = -1
	var last: String = win_text.text.split("\n")[-1]
	win_mark.position = win_text.position + Vector2(font.get_string_size(last, HORIZONTAL_ALIGNMENT_LEFT, -1, int(32 * u)).x + 26 * u, (win_text.text.count("\n")) * font.get_height(int(32 * u)) + 6 * u)
	win_mark.visible = true
	skip = false
	var w := 0.0
	while not skip:
		await get_tree().process_frame
		w += get_process_delta_time()
		win_mark.modulate.a = 1.0 if fmod(w, 1.0) < 0.6 else 0.25
		if demo and w > 0.05: break
		if asking_load_next: break
	skip = false

var asking_load_next := false
# the window waits: 「ロード」 (L / click on it) takes the answer back; E goes on
func _ask_load():
	asking_load = true; load_answer = ""
	note_lb.text = ""
	var hint := _ink_label(20, Color(BLUE.r, BLUE.g, BLUE.b, 0.8)); hint.text = T("Ｌ　ロード　　Ｅ　続ける")
	hint.position = Vector2(get_viewport().get_visible_rect().size.x - 330 * u, get_viewport().get_visible_rect().size.y - 34 * u); win.add_child(hint)
	var w := 0.0
	while load_answer == "":
		await get_tree().process_frame
		w += get_process_delta_time()
		win_load.modulate.a = 1.0 if fmod(w, 1.2) < 0.8 else 0.55
		if demo and w > 0.1: load_answer = "load" if slips.size() < 1 else "go"
	asking_load = false
	if load_answer == "go":
		print("IV load: no")
		await _block("三.続ける"); return
	print("IV load: yes")
	slips.append(last_slip_card); slipped_cards[last_slip_card] = true; loaded = true
	await _save_list(false)
	_unflatten()
	_clear(tes_box); _clear(lines_box)
	await _block("三.問い")

# the list of records, as a page of the transcript: number, a small print of the room, the recorder's time (every one
# the same second), the answer taken back struck through. At the end the last frame asks 「上書きしますか？」
func _save_list(final: bool):
	var vs := get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new(); layer.layer = 12; add_child(layer)
	var bg := ColorRect.new(); bg.color = PAPER; bg.set_anchors_preset(Control.PRESET_FULL_RECT); layer.add_child(bg)
	var grain := ColorRect.new(); grain.set_anchors_preset(Control.PRESET_FULL_RECT); grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gsh := Shader.new(); gsh.code = Main.CARD_GRAIN; var gm := ShaderMaterial.new(); gm.shader = gsh; grain.material = gm
	_clear(tes_box); _clear(lines_box); note_lb.text = ""
	var title_g := _ink_label(84, Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.9), Type.card()); title_g.text = T("ロード"); title_g.position = Vector2(124, 56) * u; bg.add_child(title_g)
	var title := _ink_label(84, INK, Type.card()); title.text = T("ロード"); title.position = Vector2(128, 52) * u; bg.add_child(title)
	var sub := _ink_label(30, BLUE, Type.card()); sub.text = T("証言 三　書き起こし"); sub.position = Vector2(122, 186) * u; bg.add_child(sub)
	var recs: Array = slips.duplicate()
	var n := maxi(recs.size() + (1 if final else 0), 1)
	var thumb: Texture2D = load("res://ui/iv_room_thumb.png") if ResourceLoader.exists("res://ui/iv_room_thumb.png") else null
	var sel := n - 1
	var rows := 5
	for i in 10:
		var col := i % 2; var row := i / 2
		var x := (120 + col * 860) * u; var y := (270 + row * 158) * u
		var live := i < n
		var is_sel := live and i == sel
		if is_sel:
			var d := Dots.new(); d.position = Vector2(x - 16 * u, y - 14 * u); d.size = Vector2(832 * u, 152 * u); d.cell = 5.0 * u; d.col = Color(BLUE.r, BLUE.g, BLUE.b, 0.55); bg.add_child(d)
		var num := _ink_label(30, BLUE, Type.card()); num.text = "%02d" % (i + 1); num.position = Vector2(x, y + 2 * u); bg.add_child(num)
		var line := ColorRect.new(); line.color = BLUE; line.position = Vector2(x, y + 140 * u); line.size = Vector2(800 * u, 2 * u); bg.add_child(line)
		if not live:
			var dash := ColorRect.new(); dash.color = BLUE; dash.position = Vector2(x + 340 * u, y + 22 * u); dash.size = Vector2(60 * u, 2 * u); bg.add_child(dash)
			continue
		if thumb:
			var tr := TextureRect.new(); tr.texture = thumb; tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tr.position = Vector2(x + 70 * u, y); tr.size = Vector2(240, 135) * u; bg.add_child(tr)
		var tg := _ink_label(34, Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.9), Type.cam()); tg.text = REC_TIME; tg.position = Vector2(x + 336 * u, y + 8 * u); bg.add_child(tg)
		var tm := _ink_label(34, INK, Type.cam()); tm.text = REC_TIME; tm.position = Vector2(x + 338 * u, y + 6 * u); bg.add_child(tm)
		if final and is_sel:
			var ow := _ink_label(42, BLUE, Type.card()); ow.text = T("上書きしますか？"); ow.position = Vector2(x + 338 * u, y + 66 * u); bg.add_child(ow)
			print("SAY （記録）上書きしますか？")
		elif i < recs.size():
			var head := String(recs[i]); if head.length() > 19: head = head.substr(0, 19)
			var lb := _ink_label(24, BLUE); lb.text = head; lb.position = Vector2(x + 338 * u, y + 66 * u); bg.add_child(lb)
			var st = load("res://scripts/story.gd").Strike.new(); st.u = u; st.col = BLUE; st.anim = 0.8 if i == recs.size() - 1 and not final else 0.0
			st.w = font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * u)).x; st.size = Vector2(st.w, font.get_height(int(24 * u))); lb.add_child(st)
			if i == recs.size() - 1 and not final: print("SAY （記録）%s %s" % [REC_TIME, head])
	bg.add_child(grain)
	if final:
		# it only asks. There is no answer to give: the next thing is the tape (第11章)
		await _hold(5.0)
	else:
		var hint := _ink_label(22, Color(BLUE.r, BLUE.g, BLUE.b, 0.8)); hint.text = T("Ｅ　この記録に戻る"); hint.position = Vector2(vs.x - 330 * u, vs.y - 60 * u); bg.add_child(hint)
		await _hold(1.0)
		skip = false
		var w := 0.0
		while not skip:
			await get_tree().process_frame
			w += get_process_delta_time()
			if demo and w > 0.1: break
		skip = false
		layer.queue_free()

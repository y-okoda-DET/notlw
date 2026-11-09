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
##
## 第2章 20:00 (the same set, the power gone): the interviewer's next question on a card, then the radio. Taiga's radio
## (the manager's, for the outages) is on the apple box. She takes it, holds it up (right mouse) and turns the dial with
## the mouse. There is no sound yet (段階4): what comes out of it is what the transcript could make of it - the words,
## "……" where the signal dropped, （雑音） between stations. Tuned dead on, one thing never comes through: the name of
## the place. The same hand on the same kind of dial gets the tape to speak in 第11章.
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
	["box", [-0.60, 3.85, 0.20], [0.15, 0.08]],            # the apple box (its top at .20: export_dusk applebox; .24 left the camera 4 cm in the air)
]
static var PLACED := {}        # where she set the small camera (Godot): the 23:00 scene shows it there, still recording
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
var tes_box: VBoxContainer     # Mio's answers to the interviewer (testimony)
var offscreen: Array = ["ラジオ"]   # voices from off the frame: these lines keep the speaker's name
var named := {}                     # who has had their name shown in this conversation (試作34「名前はその会話の最初だけ」)
var last_who := ""                   # who spoke the line before (試作89: a name on every change of speaker; ユーザー「やめとけ、外に出るな。の前、桐生の名前がない」)
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
	if house: _house_ready(); return
	# the handrail's top line (house4.stairs_up): z_rail(y) = 2.295 + (y_plan - 3.985) * .9167, plan y = 6.3 - Y
	var a := _rail_z(3.65); var b := _rail_z(0.95)
	RESTS[0] = ["rail", [0.30, 3.65, a + 0.065], [0.30, 0.95, b + 0.065]]
	_items()
	_page()
	_board()
	_finder()
	_fixed_cam()
	_lookers()
	_radio()
	_card2()
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
	add.call("radio", [RADIO_AT[0], RADIO_AT[1], RADIO_AT[2] + 0.07], 0.16, "look", "ラジオ")

# ================================================================ the words, in the player's language
# Every string on screen is written here in Japanese and looked up in lang/text.csv (keys = the Japanese, one column
# per language; NOTES.md「画面の文章と言語」). A language without a column, or a line without a translation, shows the
# Japanese. Translate whole lines before they are typed out letter by letter, never the pieces.
# The Japanese column of the table carries the phrase breaks (U+200B, put there by lang/extract.py with BudouX): Tw()
# keeps them for text that is wrapped (wrap() breaks only there), T() drops them for everything else.
const ZW := "\u200b"
static func Tw(s: String) -> String:
	return s if s == "" else String(TranslationServer.translate(s))

static func T(s: String) -> String:
	return Tw(s).replace(ZW, "")

static func Tl(lines: Array) -> Array:
	return lines.map(func(x): return Tw(String(x)))

# Break a line to fit the width, between phrases only (and at spaces, for a translation): never inside a word, never
# before 、。」. A text with no phrase marks (an untranslated key) falls back to breaking after punctuation, then anywhere.
# The breaks are settled before the line is typed out, so a word never jumps to the next line half-typed.
static func wrap_text(text: String, font: Font, fs: int, width: float) -> String:
	if text == "": return text
	var pieces: Array = []
	var cur_p := ""
	var marked := text.contains(ZW) or text.contains(" ")
	for ch in text:
		if ch == ZW:
			pieces.append(cur_p); cur_p = ""; continue
		cur_p += ch
		if ch == " " or (not marked and ch in "、。」）！？…"): pieces.append(cur_p); cur_p = ""
	if cur_p != "": pieces.append(cur_p)
	# greedy by phrase, but when a line has to break, break at its last 、。」？ instead if that keeps the line at least
	# half full (a sentence breaks where it breathes, not wherever the width runs out)
	var out := ""; var line: Array = []
	var sz := func(arr: Array) -> float: return font.get_string_size("".join(arr), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	for p0 in pieces:
		var p: String = p0
		if not line.is_empty() and sz.call(line + [p]) > width:
			var cut := line.size()
			for marks in [["。」？！", 0.4], ["、", 0.5]]:   # a sentence's end first, then a comma
				for i in range(line.size() - 1, 0, -1):
					if String(line[i - 1]).replace("　", "").right(1) in marks[0] and sz.call(line.slice(0, i)) >= width * marks[1]:
						cut = i; break
				if cut < line.size(): break
			out += "".join(line.slice(0, cut)).rstrip(" 　") + "\n"; line = line.slice(cut)
			if not line.is_empty(): line[0] = String(line[0]).lstrip("　")
			if not line.is_empty() and sz.call(line + [p]) > width:
				out += "".join(line).rstrip(" ") + "\n"; line = []
		while font.get_string_size(p, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width and p.length() > 1:   # a piece wider than the line
			var k := p.length() - 1
			while k > 1 and font.get_string_size(p.substr(0, k), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width: k -= 1
			out += p.substr(0, k) + "\n"; p = p.substr(k)
		line.append(p)
	return out + "".join(line)

func _wrap_row(text: String, size := SAY_SIZE) -> String:
	var w: float = 0.56 * get_viewport().get_visible_rect().size.x   # a subtitle's measure: about 30 characters
	return wrap_text(text, font, int(size * u), w)

# numbers in the transcript: kanji while the words are Japanese (also where no translation exists yet), figures in a translation
static func num(n: int) -> String:
	return _kan(n) if T("（沈黙・%s秒）") == "（沈黙・%s秒）" else str(n)

static func _kan(n: int) -> String:
	var d := ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
	if n <= 0: return "〇"
	if n < 10: return d[n]
	if n < 100: return ("" if n / 10 == 1 else d[n / 10]) + "十" + d[n % 10]
	return ("" if n / 100 == 1 else d[n / 100]) + "百" + (_kan(n % 100) if n % 100 > 0 else "")

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
	lb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # translated by T() before it is set (typed text is partial)
	return lb

func _page():
	var layer := CanvasLayer.new(); layer.layer = 13; add_child(layer)
	page = Control.new(); page.set_anchors_preset(Control.PRESET_FULL_RECT); page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(page)
	# what is said in the hall: centred at the foot of the frame like a film's subtitles, two lines at most, no names
	# (the one speaking turns to her); only a voice from off the frame gets its name (試作33: big, left, names every line)
	lines_box = VBoxContainer.new()
	lines_box.anchor_left = 0.1; lines_box.anchor_right = 0.9; lines_box.anchor_top = 1.0; lines_box.anchor_bottom = 1.0
	lines_box.offset_bottom = -64 * u; lines_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lines_box.add_theme_constant_override("separation", int(4 * u))
	page.add_child(lines_box)
	# what Mio tells the interviewer months later: not in the hall but over it, top left, smaller, under a short rule,
	# the way a transcript sets the answer apart from what it quotes
	tes_box = VBoxContainer.new()
	tes_box.anchor_left = 0.075; tes_box.anchor_right = 0.62; tes_box.anchor_top = 0.0; tes_box.anchor_bottom = 0.0
	tes_box.offset_top = 92 * u
	tes_box.add_theme_constant_override("separation", int(8 * u))
	page.add_child(tes_box)
	note_lb = _label(26)
	note_lb.anchor_left = 0.075; note_lb.anchor_top = 1.0; note_lb.anchor_bottom = 1.0
	note_lb.offset_top = -66 * u; note_lb.offset_bottom = -30 * u
	page.add_child(note_lb)

# one line: kind "say" (said in the hall: centred), "testimony" (her answer, months later: top left), "note" (the
# bracketed stage note), "choose" (what she could say). Typed in by _type() so a centred line does not slide as it grows.
const SAY_SIZE := 30.0
func _line_row(who: String, text: String, size := SAY_SIZE, kind := "say") -> Array:
	var tes := kind == "testimony"
	var box: VBoxContainer = tes_box if tes else lines_box
	if tes: _clear_box(tes_box)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", int(14 * u))
	row.alignment = BoxContainer.ALIGNMENT_BEGIN if tes else BoxContainer.ALIGNMENT_CENTER
	if tes:
		var rule := ColorRect.new(); rule.color = Color(paper.r, paper.g, paper.b, 0.85)
		rule.custom_minimum_size = Vector2(26 * u, 2 * u); rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(rule)
	elif who != "" and kind == "say" and (who in offscreen or not named.has(who) or who != last_who):
		named[who] = true
		var w := _label(20); w.text = T(who) + "　"; w.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(w)
	var sz := 26.0 if tes else size
	var t := _label(sz); t.text = _wrap_row(Tw(text), sz)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if tes else HORIZONTAL_ALIGNMENT_CENTER
	if tes: t.add_theme_constant_override("line_spacing", int(6 * u))
	row.add_child(t)
	box.add_child(row)
	if kind == "say" and who != "": last_who = who
	if kind == "choose": row.set_meta("choice", true)
	if not tes:
		# two lines at most; but the choices (the struck-through ones too) stay with the first line that follows them
		while lines_box.get_child_count() > 2:
			var c := lines_box.get_child(0)
			var after := 0
			for k in range(lines_box.get_child_count() - 1, -1, -1):
				if lines_box.get_child(k).has_meta("choice"): break
				after += 1
			if c.has_meta("choice") and after <= 1: break
			lines_box.remove_child(c); c.queue_free()
		for i in range(lines_box.get_child_count()):   # the line before fades back
			(lines_box.get_child(i) as Control).modulate.a = 1.0 if i == lines_box.get_child_count() - 1 else 0.45
	return [row, t]

# type a line in: the whole line is laid out from the start, the characters show one by one
func _type(lb: Label, full: String, n: int):
	if not is_instance_valid(lb): return
	if lb.text != full: lb.text = full
	lb.visible_characters = -1 if n >= full.length() else n

func _clear_box(b: Container):
	for c in b.get_children(): b.remove_child(c); c.queue_free()

func _clear_page():
	_clear_box(lines_box); _clear_box(tes_box)

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
	var mk = func(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
		var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = mat; mi.position = pos; mi.rotation = rot
		mi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		fixed_cam.add_child(mi); return mi
	# the model: blender/camcorder.py build_small (godot/props/minicam.glb; ユーザー「主人公が持つカメラもクオリティアップ」
	# 2026-11-06). Raised .025 so the clamp's flat foot (.097 under the model's centre) sits where the old box clamp's did
	# (.072 under the origin)
	var ps: PackedScene = load("res://props/minicam.glb")
	if ps:
		var m3: Node3D = ps.instantiate(); m3.position = Vector3(0, 0.025, 0); fixed_cam.add_child(m3)
		for mi in m3.find_children("*", "MeshInstance3D", true, false): (mi as MeshInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	else:
		var body := BoxMesh.new(); body.size = Vector3(0.055, 0.065, 0.115)
		mk.call(body, dark, Vector3(0, 0.0, 0.0))
	var led := OmniLight3D.new(); led.name = "rec"; led.light_color = Color(1.0, 0.2, 0.08); led.light_energy = 0.0
	led.omni_range = 0.35; led.shadow_enabled = false; led.position = Vector3(0.0, 0.068, -0.05)
	fixed_cam.add_child(led)
	var dot := SphereMesh.new(); dot.radius = 0.004; dot.height = 0.008
	var dm := StandardMaterial3D.new(); dm.albedo_color = Color(0.25, 0.05, 0.03); dm.emission_enabled = true; dm.emission = Color(1, 0.2, 0.05); dm.emission_energy_multiplier = 0.0
	var d := mk.call(dot, dm, Vector3(0.012, 0.071, -0.048)) as MeshInstance3D; d.name = "recdot"
	main.add_child(fixed_cam)
	fixed_cam.global_position = g([-0.60, 3.85, 0.20 + 0.072])   # the middle of the apple box (at -.72, 3.81 it hung past the edge, 試作61)
	fixed_cam.rotation.y = 0.6

func _set_rec(on: bool):
	recording = on
	(fixed_cam.get_node("rec") as OmniLight3D).light_energy = 0.6 if on else 0.0
	var dm := (fixed_cam.get_node("recdot") as MeshInstance3D).material_override as StandardMaterial3D
	dm.emission_energy_multiplier = 6.0 if on else 0.0
	(finder_ui as FinderFrame).rec = on

# ================================================================ the one she talks to turns to her
# Only the neck and the head, a little (at most 32 degrees), and only while they talk with her; the 20 s loop of
# their bodies goes on underneath. Makoto stands with her back half to Mio, holding the bounce board: she turns from
# the waist up (spine, then neck; never the head bone, whose weights reach her jaw: NOTES.md), up to 60 degrees.
class Look extends SkeletonModifier3D:
	var target := Vector3.ZERO
	var w := 0.0
	var want := 0.0
	var v := Vector3.ZERO          # the face's forward, in the head bone's frame
	var head := -1
	var chain := [["neck_01", 0.4], ["head", 0.6]]   # bones from the root up, and each one's share of the turn
	var max_yaw := 0.56
	var bones: Array = []
	var props: Array = []          # [node, where it stands]: what she holds turns with her
	var carry := -1
	func hold(things: Array, bone: String):
		var sk := get_skeleton()
		carry = sk.find_bone(bone)
		if carry < 0: return
		for n in things: props.append([n, (n as Node3D).global_transform])   # [node, where it stands]
	func setup(fwd_world: Vector3):
		var sk := get_skeleton()
		head = sk.find_bone("head")
		bones = []
		for c in chain: bones.append([sk.find_bone(c[0]), c[1]])
		if head < 0: return
		var hb := sk.global_basis * sk.get_bone_global_pose(head).basis
		v = (hb.inverse() * fwd_world).normalized()
	func _process_modification():
		var sk := get_skeleton()
		if sk == null or head < 0 or v == Vector3.ZERO: return
		w = move_toward(w, want, get_process_delta_time() * 1.6)
		if w <= 0.001:
			for pr in props: (pr[0] as Node3D).global_transform = pr[1]
			return
		var gp := sk.get_bone_global_pose(head)
		var hw := sk.global_transform * gp
		var f := hw.basis * v; f.y = 0.0
		var to := target - hw.origin; to.y = 0.0
		if f.length() < 0.01 or to.length() < 0.01: return
		var yaw := clampf(f.normalized().signed_angle_to(to.normalized(), Vector3.UP), -max_yaw, max_yaw)
		var e := w * w * (3.0 - 2.0 * w)
		var up_sk := (sk.global_basis.inverse() * Vector3.UP).normalized()
		for pair in bones:
			if pair[0] < 0 or pair[1] <= 0.0: continue
			var p := sk.get_bone_global_pose(pair[0])
			if pair[0] == carry:   # what she holds turns with this bone, about the bone's own root, as her arms do
				var piv := sk.global_transform * p.origin
				var r := Transform3D(Basis(Vector3.UP, yaw * e * pair[1]), Vector3.ZERO)
				for pr in props: (pr[0] as Node3D).global_transform = Transform3D.IDENTITY.translated(piv) * r * Transform3D.IDENTITY.translated(-piv) * pr[1]
			sk.set_bone_global_pose(pair[0], Transform3D(Basis(up_sk, yaw * e * pair[1]) * p.basis, p.origin))

var looks := {}
var look_eye := Vector3.ZERO   # stills (--lookfrom): where she turns to when the camera is elsewhere
func _lookers():
	for k in ["kiryu", "natsuki", "makoto", "taiga"]:
		if not main.S.has(k + "_node"): continue
		var sks: Array = main.S[k + "_node"].find_children("*", "Skeleton3D", true, false)
		if sks.is_empty(): continue
		var sk: Skeleton3D = sks[0]
		var lm := Look.new()
		if k == "makoto":
			lm.chain = [["spine_03", 0.5], ["neck_01", 0.5]]; lm.max_yaw = 1.05   # one spine bone: the reflector turns about it exactly
		sk.add_child(lm)
		var fwd := (sk.global_basis * Vector3(0, 0, 1)); fwd.y = 0.0
		lm.setup(fwd.normalized())
		if k == "makoto":
			# the reflector is the room's, not hers: without this her hands turned away and left it in the air (ユーザー指摘)
			var held: Array = []
			for mi in main.S.env_node.find_children("reflector*", "MeshInstance3D", true, false): held.append(mi)
			if main.lights.has("refl"): held.append(main.lights.refl)
			if not "--nohold" in OS.get_cmdline_user_args(): lm.hold(held, "spine_03")   # --nohold: the before, for stills
		looks[k] = lm

func _update_looks():
	var eye: Vector3 = look_eye if look_eye != Vector3.ZERO else (player.get_node("Head/Camera") as Camera3D).global_position
	for k in looks:
		var lm: Look = looks[k]
		lm.target = eye
		lm.want = 1.0 if (mode == TALK and talk_with == k and not "--nolook" in OS.get_cmdline_user_args()) else 0.0   # --nolook: stills, the pose before she turns

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
	if house: _house_tick(dt)
	if ch2: _radio_tick(dt)
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
		if holding_radio:
			note_lb.text = T("［マウスで目盛りを合わせる］") if radio_up else ""
		elif finder and holding_cam:
			note_lb.text = T("［%sに置く｜Ｅ］") % T(finder_rest.what) if finder_rest.get("ok", false) else T("［ここには置けない］")
		elif focus != "":
			var it = items[focus]
			note_lb.text = "［%s］" % T(it.name)
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
		if ch2 and k != "radio": continue          # after the power goes there is only the radio
		if house and k == "taiga" and taiga_moving: continue
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
	if e is InputEventMouseMotion and radio_up and mode == FREE and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		tune = clamp(tune + e.relative.x * 0.00035, 0.0, 1.0)   # the whole band is about 2900 px of the mouse
		return
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_E: _press()
		elif e.keycode == KEY_TAB: board_up = not board_up
		elif mode == TALK and cur.has("choose") and e.keycode in [KEY_W, KEY_UP]: _move_choice(-1)
		elif mode == TALK and cur.has("choose") and e.keycode in [KEY_S, KEY_DOWN]: _move_choice(1)
		elif mode == TALK and e.keycode in [KEY_SPACE, KEY_ENTER]: _press()
	elif e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_RIGHT:
			if holding_radio: radio_up = e.pressed   # also while a line is on screen (the line that says to right-click): it comes up when the line closes (試作33「顔の前に来なかった」)
			else: _set_finder(e.pressed)
		elif radio_up and mode == FREE and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			tune = clamp(tune + (0.0015 if e.button_index == MOUSE_BUTTON_WHEEL_UP else -0.0015), 0.0, 1.0)
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
	if house and focus.begins_with("g_"): _gen_use(focus); return
	match focus:
		"placed": _pick_up_again()
		"fixedcam": _take_cam()
		"radio":
			if ch2: _take_radio()
			else: talk_with = ""; _start(_conversation("radio"))
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
		k.append({"who": "桐生", "text": "それ。……完璧。コンテそのまんま。カーペンターでもそこに置く。"})
		k.append({"who": "桐生", "text": "じゃ、回しといて。夜通しな。"})
		k.append({"do": "rec_ready"})
		return k
	if tries >= 4 and horiz > 0.5:
		k.append({"who": "桐生", "text": "階段の手すり。あそこに挟んで、玄関を見下ろす。『ハロウィン』の階段の画だよ。"})
	elif dp.y < -0.32:
		k.append({"who": "桐生", "text": "低い。それじゃロメロのゾンビの目線。もっと上から、玄関を見下ろしたいんだよ。"})
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
	if house: return _house_conv(key, n)
	match key:
		"kiryu":
			if not has_board:
				return [{"who": "桐生", "text": "澪、ちょうどいい。定点、お願いしていい？"},
					{"who": "桐生", "text": "コンテの十二番。廊下に一台、夜通し回しっぱなし。『パラノーマル・アクティビティ』の寝室のやつな。"},
					{"who": "桐生", "text": "誰も見てないカメラが、全部見てた。『ブレア・ウィッチ・プロジェクト』から続く、正しいファウンドフッテージの作法。"},
					{"choose": ["なんで夜通し？", "わかった。どこに置けばいい？", "それ、陽太が好きなやつだ"],
					 "then": [[{"who": "桐生", "text": "何か起きたら、撮れてるだろ。……まあ、何も起きないけど。起きたら『REC』だ。"}],
						[{"who": "桐生", "text": "それを探すのが澪の仕事。コンテと同じ画になるとこ。"}],
						[{"who": "桐生", "text": "……だろ。あいつ、『パラノーマル』観たあと三日、廊下で寝てたからな。"}]]},
					{"who": "桐生", "text": "カメラは、そこの箱の上。コンテ渡しとく。"},
					{"do": "board"},
					{"note": "［絵コンテ｜Tab］"}]
			if cam_ok and not recording:
				return [{"who": "桐生", "text": "録画、押した？　赤いランプ。押し忘れたら、ただの置物な。"}]
			if not holding_cam and not cam_placed:
				return [{"who": "桐生", "text": "カメラ、箱の上な。照明の横の。"}]
			return [{"who": "桐生", "text": "のぞいて、コンテと同じ画になるとこ探して。キューブリックみたいに一ミリまでとは言わないから。"}]
		"natsuki":
			if n == 0:
				return [{"who": "夏希", "text": "立ってるだけなのに、なんでこんなに疲れるんだろ。長回しってそういうもんか。"},
					{"who": "夏希", "text": "澪、あのさ。"},
					{"who": "夏希", "text": "上映会のあと、ちょっとだけ時間ある？"},
					{"choose": ["あるよ", "なんの話？", "あとでね"],
					 "then": [[{"who": "夏希", "text": "……ありがと。あとで言う。"}],
						[{"who": "夏希", "text": "あとで。……今は、いい。"}],
						[{"who": "夏希", "text": "うん。あとで。"}]]}]
			return [{"who": "夏希", "text": "桐生、まだ？　このテイク、ヒッチコックの『ロープ』より長いよ。"}]
		"makoto":
			if n == 0:
				return [{"who": "真琴", "text": "澪さん、これ、あとどのくらい持ってればいいんですか。"},
					{"who": "真琴", "text": "レフ板って、腕にくるんですね……。"},
					{"choose": ["代わろうか", "あと五分", "桐生に聞いて"],
					 "then": [[{"who": "真琴", "text": "だ、大丈夫です！　新入りなので！"}],
						[{"who": "真琴", "text": "五分……。はい。がんばります。"}],
						[{"who": "真琴", "text": "桐生さん、さっきから「あと五分」しか言わないんです。"}]]}]
			if n == 1:
				return [{"who": "真琴", "text": "この前、桐生さんに『遊星からの物体Ｘ』を借りました。血液を熱した針で調べるところ、医学的には全然だめです。"}]
			return [{"who": "真琴", "text": "ゾンビ映画って、最初に死ぬの、だいたい新入りですよね。……あ、笑うところでした。"}]
		"taiga":
			if n == 0:
				return [{"who": "大河", "text": "ここ、停電多いらしいぞ。管理の人が言ってた。"},
					{"who": "大河", "text": "地下に発電機あるってさ。いざとなったら俺が回す。任せとけ。"},
					{"choose": ["いざって何", "詳しいね", "地下、行ったの？"],
					 "then": [[{"who": "大河", "text": "……ゾンビとか？　『ナイト・オブ・ザ・デッド・リビング』なら、まず窓に板だろ。"}, {"who": "桐生", "text": "『ナイト・オブ・ザ・リビングデッド』な。"}],
						[{"who": "大河", "text": "案内係だからな。玄関、裏、地下。全部見といた。"}],
						[{"who": "大河", "text": "階段の下の扉な。貼り紙あったろ。"}]]}]
			return [{"who": "大河", "text": "この箱、どこ置けって言われたっけ。……『ゾンビ』のモールなら、置き場に困んねえのにな。"}]
		"tape":
			return [{"who": "澪", "text": "夏希の立ち位置には、テープが貼ってありました。名前も書いてあって。字が、丸くて。", "testimony": true}]
		"camcorder":
			return [{"who": "澪", "text": "桐生さんの、いちばんいいカメラでした。『ハロウィン』を撮るならこれだ、って。あとで、私に貸してくれたんです。", "testimony": true}]
		"fresnel":
			return [{"who": "澪", "text": "照明は熱くて、近くに立つと顔が焼けそうでした。", "testimony": true}]
		"note":
			return [{"who": "澪", "text": "地下の扉には、貼り紙がありました。発電機、と書いてあったと思います。", "testimony": true}]
		"shoes":
			return [{"who": "澪", "text": "玄関に、みんなの靴がそろえてありました。そろえたのは、たぶん夏希です。", "testimony": true}]
		"radio":
			return [{"who": "澪", "text": "大河くんが、管理の人から借りてきたラジオでした。ここは停電が多いから、って。", "testimony": true}]
	return []

const WHO_KEY := {"桐生": "kiryu", "夏希": "natsuki", "真琴": "makoto", "大河": "taiga"}

func _start(entries: Array):
	if entries.is_empty(): return
	script_q = entries.duplicate(true)
	if fade_tw and fade_tw.is_valid(): fade_tw.kill()
	lines_box.modulate.a = 1.0; tes_box.modulate.a = 1.0
	print("STORY start ", focus, " t=%.1f" % t_now)
	mode = TALK
	_clear_page()
	named.clear(); last_who = ""
	rrow = {}
	radio_up = false
	_next()

func _next():
	if script_q.is_empty():
		mode = FREE; cur = {}
		if ch2 and holding_radio: return
		if lines_box.get_child_count() > 0 or tes_box.get_child_count() > 0:
			fade_tw = create_tween().set_parallel(true)
			fade_tw.tween_property(lines_box, "modulate:a", 0.0, 1.6).set_delay(1.2)
			fade_tw.tween_property(tes_box, "modulate:a", 0.0, 1.6).set_delay(1.2)
			fade_tw.chain().tween_callback(func(): _clear_page(); lines_box.modulate.a = 1.0; tes_box.modulate.a = 1.0)
		return
	cur = script_q.pop_front()
	if cur.has("text"): cur.text = _wrap_row(Tw(cur.text))
	typed = 0.0; wait_after = 0.0
	if cur.has("do"):
		_do(cur.do)
		if mode != END: _next()
		return
	if cur.has("note"):
		var r = _line_row("", cur.note, 22, "note"); cur_lb = r[1]; typed = 999.0; return
	if cur.has("choose"):
		choice_lbs = []; choice_idx = 0
		for i in range(cur.choose.size()):
			var r = _line_row("", cur.choose[i], SAY_SIZE, "choose")
			choice_lbs.append(r[1])
		_show_choice()
		return
	cur["who_key"] = WHO_KEY.get(cur.who, "")
	if ch2 and cur.who_key != "": talk_with = cur.who_key
	var r2 = _line_row(cur.who, "", SAY_SIZE, "testimony" if cur.get("testimony", false) else "say")
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
	var col := Color(0.945, 0.925, 0.875, 0.9)
	func _draw():
		var c := col
		var y := size.y * 0.52
		draw_line(Vector2(-4 * u, y - 4 * u), Vector2(w + 4 * u, y - 5 * u), c, 2.0 * u)
		draw_line(Vector2(-4 * u, y + 3 * u), Vector2(w + 4 * u, y + 2 * u), c, 2.0 * u)

func _choose():
	cur["chosen"] = true
	for i in range(choice_lbs.size()):
		if i == choice_idx: continue
		var lb: Label = choice_lbs[i]
		var s := Strike.new(); s.u = u
		s.w = font.get_string_size(lb.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(SAY_SIZE * u)).x
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
			_type(cur_lb, String(cur.text), int(typed))

func _advance():
	if cur.has("choose"):
		if not cur.get("chosen", false): _choose()
		return
	if cur.has("text") and typed < String(cur.text).length():
		typed = String(cur.text).length(); _type(cur_lb, String(cur.text), int(typed)); return
	_next()

func _do(what: String):
	print("STORY do ", what, " t=%.1f" % t_now)
	match what:
		"house_lights": main.generator(true); _gen_flicker()
		"taiga_up": taiga_after = "door"
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
			script_q.push_back({"who": "夏希", "text": "はーい。テイクワン、一発でいこ。"})
			script_q.push_back({"who": "桐生", "text": "よーい……"})
			script_q.push_back({"do": "blackout"})
		"blackout":
			mode = END; end_t = 0.0; script_q.clear()
			if cam_placed: PLACED = {"pos": fixed_cam.global_position, "basis": fixed_cam.global_basis}
			main.power_cut()
			_clear_page()
		"ch2_cut":
			# a cut, not a fade: the next thing is the card for 23:00 (the hours between are not told)
			mode = END; script_q.clear(); end_t = 100.0
			main.to_night(true)

func _end_tick(dt):
	end_t += dt
	if end_t > 2.4 and end_t < 9.0 and lines_box.get_child_count() == 0 and tes_box.get_child_count() == 0:
		var r = _line_row("澪", "そこで、電気が消えたんです。", SAY_SIZE, "testimony")
		r[1].text = ""
		cur = {"text": _wrap_row(Tw("そこで、電気が消えたんです。"))}; cur_lb = r[1]; typed = 0.0
	if cur.has("text") and typed < String(cur.text).length():
		typed += dt * 14.0; _type(cur_lb, String(cur.text), int(typed))
	if end_t >= 100.0: return
	if end_t > 9.0 and card2_t < 0.0 and not ch2:
		_begin_ch2()
	if card2_t >= 0.0:
		card2_t += dt
		if card2_t > 5.5:
			# 試作91: 第2章 goes on in the whole house at 20:00 (dark outside, the people where the outage left them,
			# the generator in the cellar). Without the house pack, the old way: the radio in this hall
			if ResourceLoader.exists("res://assets/house/scene.json") and not demo_on: card2_t = -1.0; main.to_house_ch2()
			else: _ch2_start()

# check stills of the page, the board and the finder at full size without playing up to them
func _state(name: String):
	var put = func(x: float, y: float, yaw: float, pitch: float):
		player.global_position = Vector3(x, 0.0, -y); player.yaw = deg_to_rad(yaw); player.pitch = deg_to_rad(pitch)
	if name.begins_with("talk_"):   # mid-conversation with each of them: does the turned head sit right on the neck?
		var k := name.substr(5)
		var at := {"natsuki": [-0.2, 3.6, -43.0, -3.0], "makoto": [0.06, 3.3, -58.0, -3.0], "taiga": [0.2, 4.7, -2.0, -2.0], "kiryu": [-0.2, 3.6, 6.0, 0.0]}
		var q: Array = at[k]; put.call(q[0], q[1], q[2], q[3])
		for a2 in OS.get_cmdline_user_args():   # stills only: she keeps turning to Mio's place while the camera looks from x,y,yaw,pitch
			if a2.begins_with("--lookfrom="):
				var lf := a2.substr(11).split(","); look_eye = Vector3(q[0], 1.52, -q[1])
				put.call(float(lf[0]), float(lf[1]), float(lf[2]), float(lf[3]))
		talk_with = k; focus = k; _start(_conversation(k)); return
	if name.begins_with("page_"):   # a whole conversation written out on the page (the last rows): page_<who>[_<n>] | page_rule1
		var parts := name.substr(5).split("_")
		put.call(-0.2, 3.6, 6.0, 0.0)
		if parts[0] == "rule1":
			main.power_cut(false); main.TALK = {}; ch2 = true; _start(_rule1_lines().slice(0, -1))
		else:
			talked[parts[0]] = int(parts[1]) if parts.size() > 1 else 0
			talk_with = parts[0] if WHO_KEY.values().has(parts[0]) else ""; _start(_conversation(parts[0]))
		for k in 2:   # page_<who>_<n>_<choice>: take that choice and write out what follows
			while not cur.is_empty() and not cur.has("choose"):
				typed = 999.0
				if cur.has("text"): _type(cur_lb, String(cur.text), 1 << 20)
				_next()
			if k == 0 and cur.has("choose") and parts.size() > 2:
				choice_idx = int(parts[2]); _show_choice(); _choose()
				_next()
		return
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
		"note_look":   # the paper on the cellar door, from a step back (is it readable in the print?)
			put.call(0.72, -0.25, 0.0, -4.0)
		"carry":
			put.call(-0.2, 3.6, 0.0, -4.0); has_board = true; holding_cam = true
		"card2":
			main.power_cut(); mode = END; end_t = 9.5; _begin_ch2()
		"ch2":   # from the power cut on (the unattended playthrough goes on from here when --demo is given)
			demo = []; main.CARD_TIME = 0.0; main.power_cut(); mode = END; end_t = 9.5; _begin_ch2()
		"radio", "radio_up", "radio_off", "radio_news", "radio_half":
			# 第2章: the radio in her hand, held up to the dial, or tuned between stations
			main.power_cut(false); main.TALK = {}; ch2 = true; mode = FREE; items.radio.kind = "take"
			put.call(-0.20, 3.35, 2.0, -8.0); _take_radio(); script_q.clear(); mode = FREE; _clear_page()
			radio_up = name != "radio"
			tune = 0.43 if name == "radio_off" else (1017.0 - AM_LO) / (AM_HI - AM_LO)
			if name == "radio_half": tune = (1011.0 - AM_LO) / (AM_HI - AM_LO)   # a little off: words drop out
			if name in ["radio_news", "radio_half"]: bc_t = 2.9   # just before the second sentence (the place); shoot ~100 frames
		"radio_rclick":   # 試作33: right-click while the line that says so is still on screen, then close the line
			main.power_cut(false); main.TALK = {}; ch2 = true; mode = FREE; items.radio.kind = "take"
			put.call(-0.20, 3.35, 2.0, -8.0); _take_radio()
			await get_tree().create_timer(0.5).timeout
			var ev := InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_RIGHT; ev.pressed = true
			Input.parse_input_event(ev)
			await get_tree().create_timer(0.3).timeout
			while mode == TALK: _press(); await get_tree().create_timer(0.3).timeout
		"radio_box":
			main.power_cut(false); main.TALK = {}; ch2 = true; mode = FREE; items.radio.kind = "take"
			put.call(-0.20, 3.35, 29.5, -62.0)

# ================================================================ unattended playthrough (for the check movie)
# steps: ["go", x, y, yaw_deg, pitch_deg, secs] (Blender x, y of the feet) | ["look", yaw, pitch, secs] | ["e"] | ["pick", i]
#        ["finder", on] | ["board", on] | ["wait", secs] | ["until_free"]
func _demo_script():
	demo_on = true
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
		"until_talk": done = mode == TALK
		"rup": radio_up = s[1]; done = true
		"tune":   # turn the dial to s[1] over s[2] seconds (eased), as a hand would
			if demo_t <= dt * 1.5: S_tune0 = tune
			var k: float = clamp(demo_t / float(s[2]), 0.0, 1.0)
			tune = lerp(S_tune0, float(s[1]), k * k * (3.0 - 2.0 * k))
			done = demo_t >= float(s[2])
	if done: demo_i += 1; demo_t = 0.0

var S_auto := 0
var S_tune0 := 0.0
var fade_tw: Tween
var talk_with := ""

# ================================================================ 第2章 20:00: the radio
const RADIO_AT := [-0.50, 3.88, 0.20]     # on the apple box, beside where the small camera was (Blender; z = the box's top)
const RADIO_YAW := 27.0                   # turned with the box, a little more toward the hall
const AM_LO := 531.0                      # the dial (blender/radio.py DIAL): AM, linear in kHz
const AM_HI := 1602.0
const NEEDLE_X0 := -0.076
const NEEDLE_X1 := 0.076
const STATIONS := [[594.0, 0.62, "music"], [747.0, 0.5, "talk"], [1017.0, 0.94, "news"], [1350.0, 0.4, "foreign"]]
# the bulletin, read at about eight characters a second. # is the place: whatever the signal, it never comes through
const NEWS := [
	"……臨時ニュースを、お伝えします。",
	"今日午後七時すぎ、#の化学工場で爆発があり、有毒なガスが広がっているとの情報が入っています。",
	"#と、その周辺にお住まいの方は、屋内にとどまり、窓を閉めてください。",
	"屋外にいた方は、衣服を脱いで袋に入れ、ほかの人との接触を避けてください。",
	"体調に異変のある方は、むやみに外へ出ず、その場で救助を待ってください。",
	"繰り返します。",
]
const TALKSHOW := ["……それでね、このお便りの方がね、今夜は映画の『ゴースト』を観て寝ますって。", "（笑い声）", "いやいや、それは無理でしょう。", "（笑い声）", "さあ、次のお便り、いきましょうか。"]
var radio: Node3D
var radio_needle: Node3D
var radio_knob: Node3D
var radio_dial_mat: StandardMaterial3D
var radio_lamp: OmniLight3D
var ch2 := false
var holding_radio := false
var radio_up := false
var radio_on := false
var tune := 0.2                # the dial, 0..1 across the AM band
var bc_t := 0.0                # the stations' clock: they go on whether she listens or not
var rrow := {}                 # the radio's line being written
var heard := {}                # bulletin sentence -> times it came through clearly
var radio_since := -1.0
var radio_stage := 0           # 0: nothing yet  1: heard it once (Taiga asks where)  2: the end of the scene
var hint_said := 0
var card2: Control
var card2_t := -1.0
var demo_on := false

func _radio():
	var ps: PackedScene = load("res://props/radio.glb")
	if ps == null: return
	radio = ps.instantiate()
	main.add_child(radio)
	for mi in radio.find_children("*", "MeshInstance3D", true, false): (mi as MeshInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	radio_needle = radio.find_child("needle", true, false) as Node3D
	radio_knob = radio.find_child("knob", true, false) as Node3D
	var dial := radio.find_child("dial", true, false) as MeshInstance3D
	if dial:
		radio_dial_mat = (dial.get_active_material(0) as StandardMaterial3D).duplicate()
		dial.set_surface_override_material(0, radio_dial_mat)
	# the dial lamp: warm, small, only when it is on
	radio_lamp = OmniLight3D.new(); radio_lamp.light_color = Color(1.0, 0.72, 0.42); radio_lamp.light_energy = 0.0
	radio_lamp.omni_range = 0.8; radio_lamp.omni_attenuation = 1.6; radio_lamp.shadow_enabled = false
	radio_lamp.light_volumetric_fog_energy = 0.0; radio_lamp.light_specular = 0.1
	radio.add_child(radio_lamp); radio_lamp.position = Vector3(0.0, 0.097, 0.02)   # behind the front plate: it lights her side of the room, not its own face
	_radio_rest()
	_set_dial()

func _radio_rest():
	radio.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(RADIO_YAW)), g(RADIO_AT))

func _set_dial():
	if radio_needle: radio_needle.position.x = lerp(NEEDLE_X0, NEEDLE_X1, tune)
	if radio_knob: radio_knob.rotation.x = -tune * TAU * 5.0

func _radio_power(on: bool):
	radio_on = on
	if radio_dial_mat:
		radio_dial_mat.emission_enabled = on
		radio_dial_mat.emission = Color(1.0, 0.78, 0.5)
		radio_dial_mat.emission_texture = radio_dial_mat.albedo_texture
		radio_dial_mat.emission_energy_multiplier = 0.09
	radio_lamp.light_energy = 0.3 if on else 0.0

func _card2():
	# the second chapter's door, set as the first (main.gd make_card)
	card2 = main.make_card(self, [["第 二 章", 46, 40], ["「籠城」", 150, 90], ["最初に、おかしいと思ったのは、いつですか？", 36, 0]], font)
	card2.visible = false

func _begin_ch2():
	card2.visible = true; card2_t = 0.0
	main.TALK = {}                   # nobody mouths their lines from the take any more
	_clear_page()

func _ch2_start():
	card2.visible = false; card2_t = -1.0
	ch2 = true; mode = FREE
	main.power_eyes_open()
	items.radio.kind = "take"
	talk_with = "taiga"
	_start([{"who": "大河", "text": "ラジオ。りんご箱の上の。"},
		{"who": "大河", "text": "停電したら、まずラジオだ。管理の人が言ってた。"},
		{"who": "桐生", "text": "澪、つけて。……停電、ラジオ、山の中。『ミスト』の始まり方だな。"},
		{"who": "夏希", "text": "桐生、今それ言う？"},
		{"note": "［ラジオ｜Ｅ］"}])
	if demo_on: _demo2()

func _take_radio():
	holding_radio = true; radio_since = t_now
	items.erase("radio")
	_radio_power(true)
	talk_with = ""
	_start([{"who": "澪", "text": "スイッチを入れると、目盛りに明かりが点きました。", "testimony": true},
		{"note": "［右クリック（押したまま）で顔の前へ　マウスで目盛りを合わせる］"}])

func _radio_tick(dt):
	bc_t += dt
	if not holding_radio: return
	var cam: Camera3D = player.get_node("Head/Camera")
	var up := radio_up and mode == FREE
	var tf := Transform3D(Basis.from_euler(Vector3(0.25, -0.45, 0.06)), Vector3(0.22, -0.27, -0.47))
	if up: tf = Transform3D(Basis.from_euler(Vector3(0.12, 0.0, 0.0)), Vector3(0.0, -0.11, -0.29))   # the dial window at the middle of the view
	radio.global_transform = cam.global_transform * tf
	player.look_enabled = not up
	_set_dial()
	if mode == FREE: _radio_write()
	# Taiga remembers the manager's number when it will not come
	if radio_stage == 0 and mode == FREE and hint_said == 0 and t_now - radio_since > 40.0:
		hint_said = 1; talk_with = "taiga"; radio_up = false
		_start([{"who": "大河", "text": "管理の人、千十七って言ってた。テープにも書いてあるだろ。"},
			{"who": "大河", "text": "目盛りの、百のちょい右。"}])
	elif radio_stage == 0 and mode == FREE and hint_said == 1 and t_now - radio_since > 85.0:
		hint_said = 2; talk_with = "taiga"; radio_up = false
		var f := _khz()
		_start([{"who": "大河", "text": "もうちょい%s。……ゆっくり。" % ("右" if f < 1017.0 else "左")}])
	# what they make of it
	var where: int = heard.get(1, 0) + heard.get(2, 0)
	if mode == FREE and radio_stage == 0 and where >= 1:
		radio_stage = 1; radio_up = false
		_start([{"who": "大河", "text": "どこだって？　今、どこって言った？"},
			{"choose": ["聞き取れなかった", "……もう一回"],
			 "then": [[{"who": "桐生", "text": "地名だけ、飛んだな。"}], [{"who": "桐生", "text": "待って。繰り返すはず。"}]]},
			{"note": "［右クリック（押したまま）で顔の前へ］"}])
	elif mode == FREE and radio_stage == 1 and where >= 2 and heard.get(3, 0) >= 1:
		radio_stage = 2; radio_up = false
		_start(_rule1_lines())

func _rule1_lines() -> Array:
	return [{"who": "桐生", "text": "……接触を避けて、って言った？"},
			{"who": "真琴", "text": "人と、ってことですか？　ガスなのに。"},
			{"who": "夏希", "text": "車のラジオなら、ちゃんと入るかも。地名も。"},
			{"who": "桐生", "text": "やめとけ。……夜は、外に出るな。"},
			{"note": "（間）"},
			{"who": "桐生", "text": "ルール１な。『スクリーム』のランディなら、まずそう言う。"},
			{"who": "大河", "text": "窓、塞いどこう。板なら、地下にあった。"},
			{"who": "夏希", "text": "……みんな、映画の観すぎ。"},
			{"do": "ch2_cut"}]

func _khz() -> float:
	return AM_LO + tune * (AM_HI - AM_LO)

# which station she has, and how well (0..1)
func _reception() -> Array:
	var f := _khz()
	var best := -1; var q := 0.0
	for i in range(STATIONS.size()):
		var st: Array = STATIONS[i]
		var c: float = st[1] * exp(-pow((f - float(st[0])) / (11.0 if st[2] == "news" else 7.0), 2.0))   # the bulletin a little wider (合格の試し1「合わせが甘かった」)
		if st[2] == "news": c *= 1.0 - 0.1 * (0.5 + 0.5 * sin(bc_t * 1.3))   # the mountains: the signal swells and fades
		if c > q: q = c; best = i
	return [best, q]

# where the station's speaker is now: [sentence index, characters spoken so far (float), the sentence]
func _spoken(lines: Array) -> Array:
	var total := 0.0
	for l in lines: total += float(String(l).length()) / 8.0 + 1.1
	var t := fmod(bc_t, total)
	for i in range(lines.size()):
		var d := float(String(lines[i]).length()) / 8.0
		if t < d: return [i, t * 8.0, lines[i]]
		t -= d + 1.1
		if t < 0.0: return [i, float(String(lines[i]).length()), lines[i]]
	return [0, 0.0, lines[0]]

func _radio_note(text: String):
	if rrow.get("note", "") == text: return
	_radio_close()
	var r = _line_row("ラジオ", text)
	rrow = {"note": text, "lb": r[1]}

func _radio_close():
	# a sentence counts as heard when it came through from its start to its end, nearly all of it clear
	if rrow.has("sent") and rrow.station == "news" and rrow.written >= String(rrow.text).length() and rrow.n_all > 0 and rrow.from <= 2:
		if float(rrow.n_clear) / float(rrow.n_all) >= 0.75: heard[rrow.sent] = heard.get(rrow.sent, 0) + 1
		print("STORY radio sentence %d clear %d/%d" % [rrow.sent, rrow.n_clear, rrow.n_all])
	rrow = {}

func _radio_write():
	if rrow.has("lb") and not is_instance_valid(rrow.lb): rrow = {}
	var rq := _reception()
	var q: float = rq[1]
	if rq[0] < 0 or q < 0.12: _radio_note("（雑音）"); return
	var kind: String = STATIONS[rq[0]][2]
	if kind == "music": _radio_note("（音楽）"); return
	if kind == "foreign": _radio_note("（外国語の放送）"); return
	var sp := _spoken(Tl(NEWS) if kind == "news" else Tl(TALKSHOW))   # a translation keeps # where the place is
	var text: String = sp[2]
	if text.begins_with("（"): _radio_note(text); return
	if rrow.get("station", "") != kind or rrow.get("sent", -1) != sp[0]:
		_radio_close()
		var r = _line_row("ラジオ", "")
		var from := int(sp[1])
		rrow = {"station": kind, "sent": sp[0], "text": text, "written": from, "from": from, "segs": [], "lb": r[1], "n_clear": 0, "n_all": 0}
		if from > 0: rrow.segs.append(["gap", ""])    # came in in the middle of it
	var upto := int(sp[1])
	while rrow.written < upto and rrow.written < text.length():
		var ch := text[rrow.written]
		rrow.written += 1
		if ch == ZW: _seg("ok", ch); continue   # a phrase break: not a sound, kept for wrapping the line
		# the signal, moment by moment: dropouts come in clumps
		var wob := 0.5 + 0.5 * sin(bc_t * 4.7 + 2.0 * sin(bc_t * 1.9)) * sin(bc_t * 0.83 + 1.0)
		var clear := q + 0.3 * (wob - 0.5) > 0.6
		if ch == "#":
			# the place: it never comes through, but as broken sound, not as a transcriber's label (合格の試し1「露骨。がぎぐで……の方が自然」)
			_seg("name", _garble())
			continue
		rrow.n_all += 1
		if clear: rrow.n_clear += 1; _seg("ok", ch)
		elif q < 0.3: _seg("noise", "")
		else: _seg("gap", "")
	if is_instance_valid(rrow.lb): (rrow.lb as Label).text = _wrap_row(_segs_text(rrow.segs))
	if rrow.written >= text.length(): pass   # closed when the next sentence starts (so it is counted once)

# a place name torn by the signal: two or three syllables of it, different each time it is read out
func _garble() -> String:
	var syl := ["ガ", "ギ", "ザ", "ズ", "ミ", "ム", "ヌ", "グ", "ジ", "キ"]
	var rng := RandomNumberGenerator.new(); rng.seed = int(bc_t / 4.0) * 7919 + rrow.get("sent", 0)
	var out := "……"
	for k in rng.randi_range(2, 3): out += syl[rng.randi() % syl.size()] + ("、" if k == 0 else "")
	return out + "……"

func _seg(kind: String, ch: String):
	var segs: Array = rrow.segs
	if segs.size() > 0 and segs[-1][0] == kind and kind != "name":
		segs[-1][1] += ch
	else:
		segs.append([kind, ch])

func _segs_text(segs: Array) -> String:
	var out := ""
	for sg in segs:
		match sg[0]:
			"ok", "name": out += sg[1]
			"gap": out += T("……")
			"noise": out += T("（雑音）")
	return out

# the unattended playthrough goes on into 第2章: take the radio, sweep the dial past the other stations, find the
# bulletin, hear it through twice
func _demo2():
	var u := func(khz: float) -> float: return (khz - AM_LO) / (AM_HI - AM_LO)
	demo_i = 0; demo_t = 0.0
	demo = [
		["until_free"],
		["go", 0.06, 3.20, 20.0, -10.0, 1.4], ["go", -0.20, 3.35, 29.5, -62.0, 1.8], ["wait", 0.6], ["e"], ["until_free"],
		["look", 2.0, -8.0, 1.4], ["rup", true], ["wait", 1.0],
		["tune", u.call(600.0), 2.2], ["wait", 2.4],       # music
		["tune", u.call(745.0), 2.0], ["wait", 4.0],       # the talk show
		["tune", u.call(880.0), 1.6], ["wait", 1.5],       # nothing
		["tune", u.call(1040.0), 1.4], ["wait", 2.0],      # past it, half there
		["tune", u.call(1012.0), 1.2], ["wait", 2.5],
		["tune", u.call(1017.0), 0.8],
		["until_talk"], ["auto", 1], ["until_free"],      # 大河: where? - もう一回
		["rup", true], ["until_talk"], ["until_free"], ["until_end"],
	]

# ================================================================ 第2章 20:00 in the whole house (試作91)
# The order (決定事項 2026-11-09, ユーザー「賛成！」): the power goes; Taiga takes Mio down to the generator; she starts
# it (the fuel tap, the choke, the switch, the cord: the owner's tape says only 「チョーク 引いてから」); the change-over
# switch lights the lobby and the cellar only (the generator feeds a few circuits); Taiga: 「停電したら、まずラジオだ」;
# the radio on the apple box and Kiryu's rule 1; then the boards (the next prototype). main.gd made the people
# (export_t20: phones out, each with a small torch) and turned the generator's circuit off.
var house := false
var hs := 0                    # 0 the card, 1 dark: follow Taiga, 2 the generator, 3 the lights are on: back up, 4 the radio
var gen := {"fuel": false, "choke": false, "sw": false, "run": false, "fails": 0, "fails_c": 0, "run_t": 0.0}
var taiga_at := "door"
var taiga_after := ""          # where he goes next, the moment Mio is not looking at him
var taiga_moving := false
const GEN_P := 9.45            # rooms2.GEN (plan): the generator against the cellar's east wall, its panel to the west
const GEN_Y := 6.3
const ZB := -2.45

func gp(x: float, y: float, z: float) -> Vector3:   # plan metres -> Godot
	return g([x - 4.8, 6.3 - y, z])

func _house_ready():
	_page(); _board(); _finder(); _fixed_cam(); _lookers(); _radio()
	if PLACED.is_empty(): fixed_cam.visible = false
	else:
		fixed_cam.global_position = PLACED.pos; fixed_cam.global_basis = PLACED.basis; _set_rec(true)   # still recording
	items = {}
	for k in ["kiryu", "natsuki", "makoto", "taiga"]: _person_item(k)
	main.TALK = {}
	main.generator(false)
	if main.env: main.env.tonemap_exposure = 0.0
	# Mio where the take was: on the step above the genkan, facing the hall
	player.global_position = gp(4.95, 2.3, 0.0); player.yaw = PI; player.pitch = 0.0

func _person_item(k: String):
	if not main.T20.has(k) or not main.S.has(k + "_node"): return
	var p: Array = main.T20[k].pos if not (k == "taiga" and taiga_at == "gen") else main.T20.taiga_gen.pos
	items[k] = {"pos": g([p[0], p[1], p[2] + 1.5]), "r": 0.3, "kind": "talk", "name": {"kiryu": "桐生", "natsuki": "夏希", "makoto": "真琴", "taiga": "大河"}[k]}

func _move_taiga(where: String):
	taiga_at = where
	var J: Dictionary = main.T20.taiga_gen if where == "gen" else main.T20.taiga
	main.place_person("taiga", J.pos, J.yaw)
	_person_item("taiga")
	if looks.has("taiga"):
		var sk: Skeleton3D = main.S.taiga_node.find_children("*", "Skeleton3D", true, false)[0]
		var fwd := sk.global_basis * Vector3(0, 0, 1); fwd.y = 0.0
		looks.taiga.setup(fwd.normalized())

func _house_tick(dt):
	var cam: Camera3D = player.get_node("Head/Camera")
	var pz: float = player.global_position.y
	if hs == 0:
		hs = 1; main.power_eyes_open()
		talk_with = ""
		_start([{"who": "夏希", "text": "……え、停電？"},
			{"who": "桐生", "text": "カット、カット。……ブレーカー？"},
			{"who": "大河", "text": "いや、家じゅうだ。……発電機。地下だ。"},
			{"who": "大河", "text": "澪、来て。手が足りない。"},
			{"note": "［大河について、地下へ］"}])
		taiga_after = ""
		return
	# Taiga goes ahead (or back up) while she is not looking at him: there is no walking for the people yet
	if taiga_after != "" and taiga_after != taiga_at and mode == FREE:
		var head: Vector3 = items.taiga.pos
		if not cam.is_position_in_frustum(head) or head.distance_to(cam.global_position) > 7.0:
			_move_taiga(taiga_after); taiga_after = ""
	if hs == 1 and mode == FREE:
		if taiga_at == "door" and items.taiga.pos.distance_to(cam.global_position) < 2.4 and not talked.has("t_stair"):
			talked["t_stair"] = 1; talk_with = "taiga"
			_start([{"who": "大河", "text": "先、下りる。足もと、気をつけて。急だから。"}])
			taiga_after = "gen"
		elif pz < -0.4 and taiga_at == "door": taiga_after = "gen"
		if taiga_at == "gen" and pz < ZB + 0.5 and player.global_position.distance_to(gp(GEN_P, GEN_Y, ZB)) < 3.6:
			hs = 2; _gen_items(); talk_with = "taiga"
			_start([{"who": "大河", "text": "これ。管理の人に、一回だけ教わった。"},
				{"who": "大河", "text": "燃料のつまみ開けて、スイッチ入れて、そこの綱を引く。……たしか、もう一個あった。"},
				{"note": "［発電機を調べる］"}])
	# a running engine with the choke still out floods and dies
	if gen.run and gen.choke:
		gen.run_t += dt
		if gen.run_t > 14.0 and mode == FREE:
			gen.run = false; gen.run_t = 0.0; talk_with = "taiga"
			_start([{"who": "澪", "text": "エンジンが咳きこんで、止まりました。", "testimony": true},
				{"who": "大河", "text": "かぶった。……チョーク、かかったらすぐ戻すんだ。"}])
	if hs == 3 and pz > -0.3 and mode == FREE:
		hs = 4; ch2 = true; mode = FREE
		for k in items.keys(): if k.begins_with("g_"): items.erase(k)
		items["radio"] = {"pos": g([RADIO_AT[0], RADIO_AT[1], RADIO_AT[2] + 0.07]), "r": 0.16, "kind": "take", "name": "ラジオ"}
		talk_with = "taiga"
		_start([{"who": "大河", "text": "ラジオ。りんご箱の上の。"},
			{"who": "桐生", "text": "澪、つけて。……停電、ラジオ、山の中。『ミスト』の始まり方だな。"},
			{"who": "夏希", "text": "桐生、今それ言う？"},
			{"note": "［ラジオ｜Ｅ］"}])

func _gen_items():
	var add = func(key: String, p: Vector3, r: float, name: String): items[key] = {"pos": p, "r": r, "kind": "look", "name": name}
	var x := GEN_P - 0.3   # the panel's face
	add.call("g_fuel", gp(x, GEN_Y + 0.17, ZB + 0.56), 0.06, "燃料のつまみ")
	add.call("g_choke", gp(x, GEN_Y + 0.03, ZB + 0.44), 0.06, "チョーク")
	add.call("g_sw", gp(x, GEN_Y - 0.1, ZB + 0.56), 0.06, "エンジンのスイッチ")
	add.call("g_tape", gp(x + 0.015, GEN_Y - 0.12, ZB + 0.52), 0.05, "古いテープ")
	add.call("g_pull", gp(GEN_P, GEN_Y - 0.42, ZB + 0.42), 0.08, "引き綱")
	add.call("g_gauge", gp(GEN_P, GEN_Y + 0.1, ZB + 0.66), 0.07, "燃料の目盛り")
	add.call("g_change", gp(6.18, 3.75, ZB + 1.34), 0.12, "切り替えスイッチ")

func _gen_use(key: String):
	talk_with = ""
	var say := func(text: String) -> Dictionary: return {"who": "澪", "text": text, "testimony": true}
	match key:
		"g_fuel":
			gen.fuel = not gen.fuel
			if not gen.fuel and gen.run: gen.run = false; _start([say.call("燃料のつまみを戻すと、しばらくしてエンジンが止まりました。")]); return
			_start([say.call("燃料のつまみを、横から縦に回しました。" if gen.fuel else "燃料のつまみを、横に戻しました。")])
		"g_choke":
			if gen.run and gen.choke:
				gen.choke = false; gen.run_t = 0.0; talk_with = "taiga"
				_start([say.call("チョークを戻すと、音が落ち着きました。"),
					{"who": "大河", "text": "よし。……あとは切り替え。階段の下の、灰色の箱。"}])
				return
			if gen.run: _start([say.call("チョークは、もう戻してありました。")]); return
			gen.choke = not gen.choke
			_start([say.call("チョークを、いっぱいに引きました。" if gen.choke else "チョークを、戻しました。")])
		"g_sw":
			gen.sw = not gen.sw
			if not gen.sw and gen.run: gen.run = false; _start([say.call("スイッチを切ると、エンジンが止まりました。")]); return
			_start([say.call("エンジンのスイッチを、入れました。" if gen.sw else "スイッチを、切りました。")])
		"g_tape":
			_start([say.call("操作盤に古いマスキングテープが貼ってあって、持ち主の字で『チョーク　引いてから』とだけ。")])
		"g_gauge":
			var k := [say.call("燃料の目盛りは、四分の一くらいでした。")]
			if not talked.has("gauge"):
				talked["gauge"] = 1; talk_with = "taiga"
				k.append({"who": "大河", "text": "朝までは、もたないな。……夜中に一回、足しに来ないと。"})
			_start(k)
		"g_pull":
			if gen.run: _start([say.call("エンジンは、もう回っていました。")]); return
			if not gen.fuel or not gen.sw:
				gen.fails += 1
				var k := [say.call("引き綱を引きました。……空回りするだけでした。")]
				if gen.fails >= 2:
					talk_with = "taiga"; k.append({"who": "大河", "text": "スイッチ、入ってる？　燃料のつまみも。"})
				_start(k); return
			if not gen.choke:
				gen.fails_c += 1
				var k := [say.call("引き綱を引くと、一度だけ咳きこんで、止まりました。")]
				if gen.fails_c >= 2:
					talk_with = "taiga"; k.append({"who": "大河", "text": "……テープ。なんか貼ってあったろ。"})
				_start(k); return
			gen.run = true; gen.run_t = 0.0; talk_with = "taiga"
			_start([say.call("三回引いて、かかりました。ひどい音でした。"),
				{"who": "大河", "text": "かかった！　……チョーク。戻さないと、かぶる。"}])
		"g_change":
			if not gen.run or gen.choke:
				_start([say.call("切り替えのレバーを動かしても、何も点きませんでした。")]); return
			if hs >= 3: _start([say.call("レバーは、もう下りていました。")]); return
			hs = 3; talk_with = "taiga"
			_start([say.call("切り替えのレバーを下ろすと、頭の上で電球が点きました。"),
				{"do": "house_lights"},
				{"who": "大河", "text": "点いた。……でも、ここと前室だけか。"},
				{"who": "大河", "text": "発電機につながってるの、一部の回路だけなんだって。管理の人が言ってた。"},
				{"who": "大河", "text": "停電したら、まずラジオだ。これも管理の人。……上、戻ろう。"},
				{"do": "taiga_up"},
				{"note": "［一階へ］"}])

func _gen_flicker():
	# the bulbs come up unsteady on the engine (main.gd _house_flicker 'gen' keeps them breathing after)
	for k in ["lamp_lobby", "lamp_cellar", "lamp_cellarw"]:
		if not main.lights.has(k): continue
		var l: Light3D = main.lights[k]; var e: float = l.get_meta("e")
		l.set_meta("e", 0.0)
		var tw := create_tween()
		tw.tween_method(func(x): l.set_meta("e", e * x), 0.0, 0.6, 0.15)
		tw.tween_method(func(x): l.set_meta("e", e * x), 0.6, 0.2, 0.2)
		tw.tween_method(func(x): l.set_meta("e", e * x), 0.2, 1.0, 0.8)

func _house_conv(key: String, n: int) -> Array:
	match key:
		"kiryu":
			if hs <= 2: return [{"who": "桐生", "text": "電波、一本も立たない。……山だな。"}] if n == 0 else [{"who": "桐生", "text": "定点、回ってるな。……暗いけど、まあ、撮れてる。"}]
			return [{"who": "桐生", "text": "点いた。……廊下は真っ暗のままだけどな。"}]
		"natsuki":
			if hs <= 2: return [{"who": "夏希", "text": "真っ暗。……澪、大河についてってあげて。"}]
			return [{"who": "夏希", "text": "前室だけ明るいの、逆に怖くない？"}]
		"makoto":
			return [{"who": "真琴", "text": "レフ、どこ置いたっけ……。あ、ランタン、ここ置いときますね。"}] if n == 0 else [{"who": "真琴", "text": "電池、予備あります。ロケ用の。"}]
		"taiga":
			if hs == 1: return [{"who": "大河", "text": "地下。発電機、動かす。来て。"}]
			if hs == 2: return [{"who": "大河", "text": "燃料のつまみ、スイッチ、綱。……もう一個、なんだっけ。"}]
			return [{"who": "大河", "text": "上、戻ろう。ラジオ。"}]
	return []

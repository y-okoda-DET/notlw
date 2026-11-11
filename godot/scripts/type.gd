extends RefCounted
# The three kinds of type on the screen (docs/フォント設計.md, 2026-11-11):
#   printed on the card (chapter doors, the time card, the exchange at the end)  -> Shippori Mincho B1
#   what people say, and everything else laid over the picture                    -> BIZ UD Mincho Bold
#   what the camcorder itself shows (REC, the time code, WIDE)                    -> DotGothic16
# No face from one kind is set in another's place.
const SAY_PATH := "res://fonts/BIZUDMincho-Bold.ttf"
const CARD_PATH := "res://fonts/ShipporiMinchoB1-SemiBold.ttf"
const TITLE_PATH := "res://fonts/ShipporiMinchoB1-Medium.ttf"
const CAM_PATH := "res://fonts/DotGothic16-Regular.ttf"
const TITLE_SQUEEZE := 0.85     # 長体: a chapter's name only, never the small lines
const TITLE_TRACK := 0.16       # em between its letters
const TITLE_FROM := 100.0       # a card row this large (at 1080p) is a chapter's name

static func say() -> Font: return load(SAY_PATH)
static func card() -> Font: return load(CARD_PATH)
static func cam() -> Font: return load(CAM_PATH)
static func title(fs: int) -> Font:
	var f := FontVariation.new(); f.base_font = load(TITLE_PATH)
	f.spacing_glyph = int(round(TITLE_TRACK * fs))
	return f

# The shadow under type laid over the picture. Not an outline (it closed up the counters of a mincho) and not a hard
# drop shadow (it read as an advertisement): a wide, thin pool of the print's darkest ink, so that one does not
# notice it is there, and the line still reads where it crosses paper white (ユーザー 2026-11-11「弱」).
# A Label cannot blur its shadow, so the pool is built of rings: the line's outline drawn at growing widths,
# each very thin, the sum falling off like a blur of about 12 px at 1080p.
static func soft(lb: Label, u: float) -> Label:
	var s := Soft.new(); s.u = u; s.name = "soft"
	lb.add_child(s)
	return lb

class Soft extends Control:
	const SHADOW := Color(0.024, 0.086, 0.157)
	const RINGS := [[3, 0.115], [6, 0.10], [9, 0.085], [12, 0.07], [15, 0.055], [18, 0.04], [21, 0.03], [24, 0.02], [27, 0.012]]   # px at 1080p, opacity
	static var k := 1.0   # strength, for trying (--shadowk=)
	var u := 1.0
	var seen := ""
	func _ready():
		show_behind_parent = true; mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(_dt):
		var p := get_parent() as Label
		var now := p.text + str(p.size) + str(p.horizontal_alignment)
		if now != seen: seen = now; queue_redraw()
	func _draw():
		var p := get_parent() as Label
		if p.text == "": return
		var f: Font = p.get_theme_font("font"); var fs: int = p.get_theme_font_size("font_size")
		var gap: int = p.get_theme_constant("line_spacing")
		var lines := p.text.split("\n")
		var lh := f.get_height(fs)
		var total := lines.size() * lh + (lines.size() - 1) * gap
		var y := 0.0
		if p.vertical_alignment == VERTICAL_ALIGNMENT_CENTER: y = (p.size.y - total) / 2.0
		elif p.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM: y = p.size.y - total
		for line in lines:
			if line != "":
				var w := f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var x := 0.0
				if p.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER: x = (p.size.x - w) / 2.0
				elif p.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT: x = p.size.x - w
				var at := Vector2(x + 1.0 * u, y + f.get_ascent(fs) + 2.0 * u)
				for r in RINGS:
					draw_string_outline(f, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(1, int(round(r[0] * u))), Color(SHADOW.r, SHADOW.g, SHADOW.b, minf(1.0, r[1] * k)))
			y += lh + gap

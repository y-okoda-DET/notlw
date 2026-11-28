## 後半の並び（企画書「後半の組み直し」2026-11-13）と、次の章へ進む入口。2026-11-19「インタビューの証言一〜三を作る」のスレッド。
## 章の終わりは main.next_chapter("いまの名前") を呼ぶ（main.gd → Order.go）。並びはこの表の1か所だけ。
## まだ作っていない章（場面のスクリプトが無い章）は、仮の章カードを数秒出して次へ進む（通しで並びの感覚を見るため）。
## 証言 一〜三（i1・i2・i3）は家と別の場面（scripts/interview.gd）。そのほかは家の場面（main.to_chapter）。
##
## The late chapters' order in one place. A chapter whose script is not there yet is a stand-in card for a few seconds.
## This node itself is the stand-in's scene (built in code, so that the overlay check's renamed scripts are followed).
extends Node
const Type = preload("res://scripts/type.gd")
const Main = preload("res://scripts/main.gd")

const LATE_ORDER := ["ch6", "i1", "ch8", "i2", "ch7", "i3", "ch11"]
# the script each name needs; when it is missing the name is a stand-in card
const NEEDS := {"ch6": "res://scripts/ch6.gd", "ch7": "res://scripts/ch7.gd", "ch8": "res://scripts/ch8.gd",
	"ch11": "res://scripts/tape.gd", "i1": "res://scripts/interview.gd", "i2": "res://scripts/interview.gd", "i3": "res://scripts/interview.gd"}
# the stand-in cards (the chapter numbers are put right when the late chapters' scripts are written: 企画書)
const STAND_IN := {
	"ch8": [["二時", 46, 40], ["監督", 150, 90], ["（この章は、まだ作っていない）", 30, 0]],
	"ch7": [["一年前", 46, 40], ["去年の夏", 150, 90], ["（この章は、まだ作っていない）", 30, 0]],
}
const STAND_IN_SEC := 4.0

static func next_of(cur: String) -> String:
	var i := LATE_ORDER.find(cur)
	return "" if i < 0 or i + 1 >= LATE_ORDER.size() else String(LATE_ORDER[i + 1])

static func ready_to_play(name: String) -> bool:
	return ResourceLoader.exists(String(NEEDS.get(name, "")))

# --play=名前 で直に開ける物（証言と、まだ無い章の仮のカード）。main.gd の頭で見る
static func direct(name: String) -> bool:
	return NEEDS.has(name) and ((name.begins_with("i") and ready_to_play(name)) or (STAND_IN.has(name) and not ready_to_play(name)))

# from the chapter `cur` on to the next one. `from` is any node in the tree
static func go(from: Node, cur: String):
	var nx := next_of(cur)
	if nx == "": nx = "ch11"
	start(from, nx)

# start the chapter `name` from its card (the same way playing reaches it; F5 uses it too)
static func start(from: Node, name: String):
	var tree := from.get_tree()
	print("ORDER ", name)
	if name.begins_with("i") or STAND_IN.has(name): load("res://scripts/title.gd").save_progress(name)   # house chapters save in main.to_chapter
	if name.begins_with("i") and ready_to_play(name):
		_cover(from)
		_to_node(tree, load("res://scripts/interview.gd"), {"which": int(name.substr(1))})
	elif STAND_IN.has(name) and not ready_to_play(name):
		_cover(from)
		_to_node(tree, load("res://scripts/order.gd"), {"chap": name})
	else:
		_to_house(tree, name)

# back into the game's main scene, at a chapter of the house (the overlay check's main scene is its boot, which puts
# its own main.gd back on: so the main scene is taken from the project, not named here)
static func _to_house(tree: SceneTree, name: String):
	Main.SCENE = "house"; Main.NEXT_PLAY = name
	if "--orderonly" in OS.get_cmdline_user_args():   # check/interview.sh order: the house has a few seconds to start, then the run ends
		tree.create_timer(12.0).timeout.connect(func(): print("ORDER DONE ", name); tree.quit())
	if tree.current_scene and tree.current_scene.get_script() == Main and tree.current_scene.has_method("to_chapter"):
		tree.current_scene.to_chapter(name); return
	var mains := tree.root.find_children("*", "", true, false).filter(func(n): return n.get_script() == Main)
	if mains.size() > 0: mains[0].to_chapter(name); return
	tree.change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))

static func _to_node(tree: SceneTree, script: Script, vars: Dictionary):
	var n := Node.new() if script != load("res://scripts/interview.gd") else Node3D.new()
	n.set_script(script)
	for k in vars: n.set(k, vars[k])
	n.name = "Chapter"
	var ps := PackedScene.new(); ps.pack(n)
	tree.change_scene_to_packed(ps)
	n.free()

static func _cover(from: Node):
	var layer := CanvasLayer.new(); layer.layer = 100; from.get_tree().root.add_child(layer)
	var c := ColorRect.new(); c.color = Main.CARD_BG; c.set_anchors_preset(Control.PRESET_FULL_RECT); c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(c)
	Main.COVER = layer

# ---------------------------------------------------------------- the stand-in card (this node as a scene)
@export var chap := ""
func _ready():
	if chap == "": return
	Main.make_card(self, STAND_IN[chap], Type.card())
	if Main.COVER and is_instance_valid(Main.COVER): Main.COVER.queue_free(); Main.COVER = null
	print("SAY （仮のカード）%s" % String(STAND_IN[chap][1][0]))
	await get_tree().create_timer(STAND_IN_SEC).timeout
	go(self, chap)

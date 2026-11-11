#!/bin/bash
# ステップ D（第4章の FPS・第11章のテープ再生）を、書き出した pck に重ねて動かす（main.gd に入口を足すまでの仮の入口）。
#   bash godot/check/d_overlay.sh        → $WORK/overlay（overlay.sh と同じ物に、--d=fps|tape の入口を足す）
#   動かす：godot --path $WORK/overlay -- --basepack=<RULES.pck> --housepack=<RULES_house.pck> --scene=house --time=t0330 --nocard --d=fps
#   撮る：bash godot/check/d_run.sh fps|tape <出力の名前> [コマ数] [ほかの引数…]
set -eu
. "$(dirname "$0")/../../blender/paths.sh"
bash "$(dirname "$0")/overlay.sh" >/dev/null
O=$WORK/overlay
cat > $O/boot.gd <<'GD'
extends Node
func _ready():
	var p := ""; var d := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--basepack="): p = a.substr(11)
		if a.begins_with("--d="): d = a.substr(4)
	if not ProjectSettings.has_setting("ov_loaded"):
		print("BOOT pack ", p, " ", ProjectSettings.load_resource_pack(p, false)); ProjectSettings.set_setting("ov_loaded", true)
		for f in ["res://lang/text.ja.translation"]:
			if ResourceLoader.exists(f): TranslationServer.add_translation(load(f))
	var m: Node = load("res://main.tscn").instantiate()
	m.set_script(load("res://ov_main.gd"))
	add_child(m)
	if d != "":   # ステップ D: the chapter rides on the whole house as story.gd and door.gd do
		var s: Node = load("res://ov_%s.gd" % d).new(); s.main = m; m.add_child(s); m.story = s
GD
$GODOT --headless --path $O --import >/dev/null 2>&1 || true
echo $O

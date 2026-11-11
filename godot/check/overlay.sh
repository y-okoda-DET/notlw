#!/bin/bash
# 書き出した pck の上に、いまのリポジトリのスクリプト（と刷りのシェーダー）を重ねた試し用のプロジェクトを作る。
#   bash godot/check/overlay.sh            → $WORK/overlay ができる
#   使い方：godot --path $WORK/overlay -- --basepack=<pck> （あとはいつもの引数）
#           house_shots.py なら PROJ=$WORK/overlay GARGS="--basepack=<pck>"、通しなら OV=1 bash godot/check/playthrough.sh <pck>
# スクリプトだけを変えたとき、書き出し直さずに確かめるための物。pck の中のスクリプトは書き出しで別の形になっていて、
# 同じ名前のファイルを置いても読まれないので、ov_ を付けた名前で置き、main.tscn に付け替える（NOTES.md「pck に重ねる」）。
# ユーザーに見せる画は、書き出した pck から撮る決まりのまま（これは途中の確認用）。
set -eu
. "$(dirname "$0")/../../blender/paths.sh"
O=$WORK/overlay; S=$REPO/godot
mkdir -p $O/shaders
sed 's#run/main_scene="res://main.tscn"#run/main_scene="res://boot.tscn"#' $S/project.godot | grep -v "locale/translations" > $O/project.godot
cp $S/check/trial/boot.tscn $O/
cp $S/shaders/*.gdshader $O/shaders/
rm -rf $O/story; cp -r $S/story $O/story   # 台本（スクリプトと同じく、いまのリポジトリの物）
cat > $O/boot.gd <<'GD'
extends Node
func _ready():
	var p := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--basepack="): p = a.substr(11)
	if not ProjectSettings.has_setting("ov_loaded"):
		print("BOOT pack ", p, " ", ProjectSettings.load_resource_pack(p, false)); ProjectSettings.set_setting("ov_loaded", true)
		for f in ["res://lang/text.ja.translation"]:
			if ResourceLoader.exists(f): TranslationServer.add_translation(load(f))
	var m: Node = load("res://main.tscn").instantiate()
	m.set_script(load("res://ov_main.gd"))
	add_child(m)   # under this scene, so that the game's reload_current_scene comes back through here
GD
# フォント（pck に無い新しい書体も試せるように。.import は Godot に作らせる）
mkdir -p $O/fonts; cp $S/fonts/*.ttf $S/fonts/*.ttf.import $O/fonts/ 2>/dev/null || true
N=$(cd $S/scripts && ls *.gd | sed 's/\.gd$//' | tr '\n' '|' | sed 's/|$//')
for f in $S/scripts/*.gd; do sed -E "s#res://scripts/($N)\.gd#res://ov_\1.gd#g" $f > $O/ov_$(basename $f); done
$GODOT --headless --path $O --import >/dev/null 2>&1 || true
echo $O

#!/bin/bash
# ステップ E：d_overlay.sh（pck にいまのスクリプトを重ね、--d=<場面> の入口を足す）に、仮の音（godot/sound/、scripts/sound.gd）を足す。
# main.gd に sound.gd をつなぐまでの仮の入口。--nosound で切れる。
set -eu
. "$(dirname "$0")/../../blender/paths.sh"
bash "$(dirname "$0")/d_overlay.sh" >/dev/null
O=$WORK/overlay
rm -rf $O/sound; mkdir -p $O/sound; cp $REPO/godot/sound/*.wav $REPO/godot/sound/*.ogg $O/sound/
python3 - "$O/boot.gd" <<'PY'
import sys; p=sys.argv[1]; s=open(p).read()
if "ov_sound" not in s:
    s=s.replace("\tadd_child(m)\n","\tadd_child(m)\n\tif ResourceLoader.exists(\"res://ov_sound.gd\") and not m.has_node(\"Sound\"):\n\t\tvar snd: Node = load(\"res://ov_sound.gd\").new(); snd.name = \"Sound\"; m.add_child(snd); snd.setup(m)\n",1)
open(p,'w').write(s)
PY
$GODOT --headless --path $O --import >/dev/null 2>&1 || true
echo $O

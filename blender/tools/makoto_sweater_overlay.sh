set -e
export WORK=$1
bash /tmp/claude-0/lw/godot/check/e_overlay.sh >/dev/null
O=$WORK/overlay; mkdir -p $O/assets/dusk
cp /home/claude/work/knit/makoto_anime_girl_3d_model_basecolor.png $O/assets/dusk/
cp /home/user/notlw/godot/assets/dusk/makoto_anime_girl_3d_model_basecolor.png.import $O/assets/dusk/
. /tmp/claude-0/lw/blender/paths.sh
$GODOT --headless --path $O --import >/dev/null 2>&1 || true
ls -la $O/.godot/imported/ | grep anime_girl_3d_model_basecolor

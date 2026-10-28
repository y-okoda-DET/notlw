# 作業環境の作り方（新しいチャット／新しい作業環境で最初にやること）

この作業環境（Linux、GPUなし、CPU2コア、メモリ約7GB）で確かめた手順。所要 20〜40 分。

## 1. Python ライブラリ
```
pip install --break-system-packages bpy==5.2.3 numpy scipy pillow fonttools matplotlib
```
`bpy` は Blender 5.2.3 を Python から使うための本体（約 300MB）。

## 2. MakeHuman（MPFB2）……人物の骨組みの元
```
git clone https://github.com/makehumancommunity/mpfb2.git /home/claude/mh/mpfb2   # 使ったのは 6ff1eb3
pip install --break-system-packages makehuman   # MakeHuman 1.3.x の wheel。MPFB2 が内部で使う
```
MPFB2 を Blender の拡張として入れる：`/home/claude/mh/mpfb2/src/mpfb` を
`~/.config/blender/5.2/extensions/user_default/mpfb` にコピー（または symlink）する。
`blender/chars.py` の `mpfb()` が `bl_ext.user_default.mpfb` として読み込む。
MakeHuman の体データ（base.obj とターゲット）は MPFB2 に同梱。

## 3. Godot 4.4.1
```
mkdir -p /home/claude/godot && cd /home/claude/godot
# Godot_v4.4.1-stable_linux.x86_64 を GitHub の godotengine/godot の release から取得し、実行権限を付ける
# Windows 書き出し用テンプレート（Godot_v4.4.1-stable_export_templates.tpz）を取得し、
# 展開して ~/.local/share/godot/export_templates/4.4.1.stable/ に置く
```
画面なしで動かすので `xvfb-run` が必要（`apt install xvfb`）。動画の結合に `ffmpeg`、配布に `zip`。

## 4. フォント
Noto Serif CJK（`fonts-noto-cjk`）。`godot/fonts/SerifJP-Bold.otf` は使う文字だけ抜き出したもの。
文字を増やしたら `fonttools` で作り直す（main.gd の文字列から文字集合を取る。やり方はこのチャットの履歴ではなく、以下）:
```
python3 - <<'PY'
from fontTools.ttLib import TTCollection; from fontTools import subset; import re
tc=TTCollection('/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc')
f=[x for x in tc.fonts if 'JP' in x['name'].getDebugName(1)][0]
src=open('godot/scripts/main.gd').read()+open('godot/scripts/player.gd').read()
chars=set(''.join(re.findall(r'"([^"]*)"',src)))|set('0123456789.０１２３４５６７８９ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz　、。，．・：；？！ー（）「」『』／｜＋－＝ ')
o=subset.Options(); o.layout_features=['*']; o.name_IDs=['*']
s=subset.Subsetter(o); s.populate(text=''.join(chars)); s.subset(f); f.save('godot/fonts/SerifJP-Bold.otf')
PY
```

## 5. パス
スクリプトは `/home/claude/kf`（= このリポジトリの `blender/`）、`/home/claude/rules`（= `godot/`）、
`/home/claude/tripo`（= `tripo/`）、`/home/claude/assets`（= `assets/`）を決め打ちで参照している。
新しい環境では、リポジトリを `/home/claude/notlw` に置いたうえで symlink を張るのが一番早い：
```
ln -s /home/claude/notlw/blender /home/claude/kf
ln -s /home/claude/notlw/godot   /home/claude/rules
ln -s /home/claude/notlw/tripo   /home/claude/tripo
ln -s /home/claude/notlw/assets  /home/claude/assets
mkdir -p /home/claude/kf/out /home/claude/build /home/claude/rules_movie/st
```

## 6. 一通り動くか確かめる
```
cd /home/claude/tripo && python3 prep_natsuki.py        # 頭と体をつなぐ（約5分）
cd /home/claude/kf && python3 export_godot.py           # 夜を書き出す（ライトマップ込みで約15分）
python3 denoise_lm.py -- /home/claude/rules/assets/lightmap.exr
python3 export_dusk.py && python3 denoise_lm.py -- /home/claude/rules/assets/dusk/lightmap.exr
cd /home/claude/rules && G=/home/claude/godot/Godot_v4.4.1-stable_linux.x86_64
$G --headless --path . --import
xvfb-run -a -s "-screen 0 960x540x24" $G --path . --windowed --resolution 960x540 -- --bake-gi --scene=night
xvfb-run -a -s "-screen 0 960x540x24" $G --path . --windowed --resolution 960x540 -- --bake-gi --scene=dusk
$G --headless --path . --export-release "Windows Desktop" ../build/RULES_proto/RULES.exe
```
書き出した Windows 版を動かして確認する（`$G --main-pack ../build/RULES_proto/RULES.pck ...`）。
確認用の静止画は `--record=still --nocard --gi=baked --pose=x,z,yaw,pitch --write-movie ...` で撮る（main.gd の引数を参照）。

# 書き出した pck に、刷り（シェーダー）や main.gd だけをかぶせて試す

書き出し（Blender、約20〜45分）をせずに、配布した pck の画へ刷りの直しを当てて確認画を撮るための小さなプロジェクト。
2026-11-10 の夜の刷り（riso2.gdshader の look=1）はこれで試した。

```
T=/home/claude/trialproj; mkdir -p $T/shaders
cp godot/check/trial/boot.gd godot/check/trial/boot.tscn $T/
sed 's#run/main_scene="res://main.tscn"#run/main_scene="res://boot.tscn"#' godot/project.godot > $T/project.godot
cp godot/shaders/riso2.gdshader $T/shaders/          # 試したいシェーダー（このフォルダにある物が pck の物より優先される）
cp <pck と同じ版の main.gd に直しを当てた物> $T/trial_main.gd   # main.gd も試すとき（なければ pck の main.gd のまま）
cd godot && PROJ=$T WORK=/home/claude/work/after GARGS="--basepack=/path/RULES.pck [--housepack=/path/RULES_house.pck]" \
  RES=1920x1080 PER=90 python3 house_shots.py t23 hall,living
```

- 仕組み：boot.gd が pck を `load_resource_pack(…, false)` で読む（replace_files=false なので、フォルダにある同じパスのファイルが勝つ）。
- スクリプトは pck の中で .gdc に変換され .remap が付くので、同じパスに main.gd を置いても効かない。別名（trial_main.gd）で置くと、boot.gd が main.tscn に付け替える。pck と版の違う main.gd は story.gd や scene.json と食い違うので、pck を作った時点の main.gd に直しだけを当てる。
- `--dodge=` `--dodgemax=` は刷りの値をその場で変える（boot.gd）。
- 1920x1080 は1か所あたり約1分。house_shots.py の時間切れは PER（1か所あたりの秒）で延ばす。足りないと MISSING が出る。
- 刷りの割合（紙・青・橙・青緑）は `python3 godot/check/print_share.py 画像…`。

## スクリプトをまるごと重ねる（2026-11-10、ステップ C）
`bash godot/check/overlay.sh` が、いまのリポジトリの scripts/*.gd と shaders を重ねたプロジェクトを $WORK/overlay に作る
（スクリプトは ov_ を付けた名前で置き、互いの読み込み先も書き換える）。pck と版の離れたスクリプトは assets と食い違うので、
同じ版の pck に、スクリプトだけの変更を確かめるときに使う。通しは `OV=1 bash godot/check/playthrough.sh <pck>`。

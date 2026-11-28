# タイトル画面 案2（夕方の家）の確認用の道具（2026-11-28。ゲームの本体ではない）
- views.py：家を外から撮る候補（house_shots.py に位置を足す）。背景は dusk の o_t18。
- mock2.py：静止画の合成。layers.py：動く版の画の層（tm/*.png、items.txt）。Anton（OFL、Google Fonts）とPVの色ずれロゴを使う。
- titlemov.gd：overlay（godot/check/overlay.sh の $WORK/overlay を複製した $WORK/ovt）に置き、boot.gd に「--titlemov のとき TitleMov を足す」2行を足す。
- mov.sh <コマ数> <出力>：試作298 の pck から 1920x1080・24コマで書き出す（1コマ約3秒）。ffmpeg で f_.wav と合わせて mp4 に。

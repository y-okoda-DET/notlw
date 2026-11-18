# 手の構えを速く確かめる（第6章、2026-11-18）
家を読み込まずに、澪の腕（props/mio_arm_l/r.glb）と持ち物の代わりの箱だけを、ゲームと同じ画角（62°）で描く。1枚数秒。
1. 空のフォルダに project.godot（renderer/rendering_method="forward_plus" だけ）と props/（mio_arm_*.glb ほか）を置き、`godot --headless --path . --import`
2. lab.gd と poses.json を置き、`xvfb-run -a godot --path . --windowed --resolution 960x540 --script lab.gd` → out/L_<名前>.png
   poses.json：l / r は [位置, 角度(YXZ, 度), 指の曲げ, 親指]。ch6.gd の `_hand_to` と `_curl` にそのまま写せる値。objs は箱か筒（on: "l"/"r" で手の子）。
3. view.gd は模型を四方から見る（VM=arm | police | case）。
注意：SceneTree の _init の中で骨の姿勢を入れても描かれない。木に入って1コマ後に入れる（lab.gd の todo）。

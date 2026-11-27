# NIGHT OF THE LIVING WITNESS（作業中の仮題『ルールズ』）作業リポジトリ

- 新しく作業を始めるときは、まず docs/要約.md（いまの段階・スレッドの分担・次の作業・どの資料に何があるか）。Claude 向けの読む順は CLAUDE.md。
- 作品の中身（物語・章・ロードマップ・間取りの意図）の正本は docs/企画書.md。ユーザーが決めたことは docs/決定事項.md、試作番号の台帳とこれまでの記録は docs/次の作業.md、はまりどころは NOTES.md。Claude への指示は docs/プロジェクトの指示.md。

## 中身
- `blender/` … Blender（bpy, 5.2）で家・人物・光を組み、Godot に書き出すスクリプト
  - `build.sh <番号>` が全部をまとめて書き出す（家まるごと・人物・光の焼き込み・Godot の pck と zip。速い確認は `FAST=1`。docs/手順_作り直し.md）
  - `export_house.py` 家まるごと（6つの時刻）、`export_godot.py`・`export_dusk.py` 人物と古い2場面、`interview/` 証言の部屋
  - `chars.py` 人物（`make_tripo()` が Tripo のモデルに骨を付ける）、`lib.py` 共通部品、`check.sh` 送る前の確認
- `tripo/` … Tripo（有料版 H3.1・多視点）で作った元モデル（`<人物>_body.glb` / `<人物>_head.glb`。夏希は `n2_*`）と、
  頭と体をつないで描いた顔を貼る準備スクリプト（`prep_<人物>.py` → `<人物>_prep.blend`）。`chars_cfg.json` が人物ごとの寸法
- `godot/` … Godot 4.4.1 のゲーム本体（`scripts/main.gd`・`story.gd` と章ごとの `ch*.gd`、台本は `story/*.txt`、刷りは `shaders/riso2.gdshader`）。確認の道具は `check/`（自動の通し `playthrough.sh`、コンタクトシート `contact/`）
- `assets/` … 描いた顔の絵（`faces_style/`）、テクスチャ（`tex/`）、フォント
- `plan/` … 間取り図（v4）

## Tripo の入れ方（間違えやすい）
多視点の欄：前＝正面、**左＝顔が画面の左を向く横顔**、**右＝顔が画面の右を向く横顔**、裏面＝後ろ姿。逆にすると後頭部に顔ができる。
全身と頭は別々に生成。設定は H3.1・ウルトラメッシュ品質・テクスチャ4K・ライティング除去 ON。GLB・骨なしで書き出す。

## 入れていないもの
書き出した Windows 版（pck は本体・家まるごと・証言の部屋の3つ、zip も3つ）と動画、確認画、ログ（作り直せるため）。無料版で作った夏希のモデル（公開扱い・商用不可のため）。

## 書き出したデータ（godot/assets）は入れていない
`godot/assets/`（家と人物の glb、ライトマップ、顔の差し替え画像）は Blender スクリプトから作り直せるので入れていない。作り直し方：
`bash blender/build.sh <試作の番号>`（SETUP.md の 6）
（パスはリポジトリの根の paths.env の1か所。別の PC では paths.local.env で上書きする。SETUP.md 5）

## 大きなファイルの扱い
Git LFS は使っていない（この作業環境から LFS の保存先に接続できないため）。Tripo の元モデル（1つ約60MB）は通常の git で入っている。
GitHub の上限は1ファイル100MBなので、それを超えるモデルは入れられない。

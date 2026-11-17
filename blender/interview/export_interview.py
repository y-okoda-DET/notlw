"""インタビューの部屋（証言 一〜三）をゲームへ書き出す。2026-11-16、「インタビュー場面の画を詰める」のスレッド。
Run: python3 blender/interview/export_interview.py   （Blender の Python。build.sh にはまだ入れていない：入口のスレッドが入れる）

Out（godot/assets/interview/。git に入れない）:
  room.glb       客間と座卓と小物（テープ、帳面、録音機、湯呑み、掛け軸、椿）。手続きの材質は色の画像に焼く（export_godot と同じ）
  tree.glb       障子の外の庭木の葉。画には映さず、影だけ落とす（障子の葉の影。証言一の長回しで揺らす）
  kikite_<形>.glb 聞き手の形 5 つ（seiza＝テープに手、pinch＝つまむ、stroke＝ラベルをなでる、write＝書きかけて止まる）。形を焼き込んだ動かない体
  mio_seiza.glb  澪（南の座布団に正座、膝の上に拳）
  portrait_*.png 立ち絵 4 枚（切り抜き。平たくなった画面で使う）
  lights.json    光（空の面光、南の返り光、日）。Blender の値のまま、Godot で組み直す
  cuts.json      証言 一〜三のカット（cuts.py をそのまま。1コマ＝1/12秒）
  scene.json     置き場所（座卓の高さ、座布団、テープ・帳面・録音機の位置）、groups（映さない組の名前）
人物の元は tripo/interview/*.glb（Tripo の体と頭＋MakeHuman の手を骨で正座させた物。作り方は people/ と README）。
"""
import sys, os, json, math, shutil
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE); sys.path.insert(0, os.path.dirname(HERE))
import paths as P
import bpy
import build as B
import cuts
import export_godot as E

OUT = f'{P.RULES}/assets/interview'
os.makedirs(OUT, exist_ok=True)
TRIPO = f'{P.TRIPO}/interview'

def lights():
    out = []
    for o in bpy.data.objects:
        if o.type != 'LIGHT': continue
        q = o.matrix_world.to_quaternion()
        d = dict(name=o.name, type=o.data.type, loc=list(o.matrix_world.translation), rot_quat=[q.w, q.x, q.y, q.z],
                 energy=o.data.energy, color=list(o.data.color))
        if o.data.type == 'AREA': d.update(shape=o.data.shape, size=o.data.size, size_y=o.data.size_y)
        out.append(d)
    w = bpy.context.scene.world.node_tree.nodes['Background']
    return dict(lights=out, world=dict(color=list(w.inputs['Color'].default_value)[:3], strength=w.inputs['Strength'].default_value),
                note='Blender の W のまま。座標は Blender（z が上）。Godot では y が上（x, z, -y）。')

def main():
    B.build(sun=True)
    sc = bpy.context.scene; groups = json.loads(sc['groups'])
    # 箱の仮の人物は捨てる（本物は人物の GLB）
    for g in ('people', 'mio'):
        for n in groups.get(g, []):
            if n in bpy.data.objects: bpy.data.objects.remove(bpy.data.objects[n])
    # 録音機の時刻（文字）は面にする
    for o in list(bpy.data.objects):
        if o.type == 'FONT':
            me = bpy.data.meshes.new_from_object(o); n = bpy.data.objects.new(o.name + '_m', me); n.matrix_world = o.matrix_world.copy()
            sc.collection.objects.link(n); me.materials.clear(); [me.materials.append(m) for m in o.data.materials]
            nm = o.name; bpy.data.objects.remove(o); n.name = nm
    json.dump(lights(), open(f'{OUT}/lights.json', 'w'), ensure_ascii=False, indent=1)
    # 平たくなる画（証言 三）の色：物ごとの「物の色」（材質の flat。焼くと材質の名前が変わるので、物の名前で持つ。sRGB）
    srgb = lambda c: [12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055 for x in c]
    flat = {}
    for o in bpy.data.objects:
        if o.type == 'MESH':
            cs = [list(m['flat']) for m in o.data.materials if m is not None and m.get('flat') is not None]
            if cs: flat[o.name] = srgb(cs[0])
    json.dump(dict(objects=flat, note='光を受けない材質に、この色だけを塗る。人物は平たくなる画では映さない（立ち絵に替わる）。'),
              open(f'{OUT}/flat_colors.json', 'w'), ensure_ascii=False, indent=1)
    # 手続きの材質を色の画像に焼く（木目、畳、漆喰、紙…）
    baked = E.simplify_materials(); print('baked', len(baked))
    tree = [o for o in bpy.data.objects if o.name == 'tree_leaves']
    room = [o for o in bpy.data.objects if o.type == 'MESH' and o not in tree]
    E.export(f'{OUT}/room.glb', room)
    if tree: E.export(f'{OUT}/tree.glb', tree)
    LY = B.LY
    json.dump(dict(table=LY['table'], zabuton=LY['zabuton'], props=LY['props'], room=LY['room'],
                   groups={k: [n for n in v if n in bpy.data.objects] for k, v in groups.items()},
                   people={'people': 'kikite_<形>.glb の全部', 'mio': 'mio_seiza.glb の全部'}),
              open(f'{OUT}/scene.json', 'w'), ensure_ascii=False, indent=1)
    json.dump(dict(fps=cuts.FPS, order=cuts.ORDER, shots=cuts.SHOTS,
                   note='1コマ＝1/12秒。loc/at は Blender の座標（z が上）。lens は mm（センサー幅 36mm）、shift_y は Blender のレンズのずらし（幅に対する割合）。'
                        'hold＝そのコマを何コマ伸ばすか。blur＝横の流し（px／1920）。sway＝葉の揺れの位相（0〜1）。roll＝度。'
                        'post＝slip（橙の版だけ (-26,14)px／1080 ずれる）、flat（平たくなる。前の slip から約2秒で溶かす。手引きを見る）。'),
              open(f'{OUT}/cuts.json', 'w'), ensure_ascii=False, indent=1)
    for f in os.listdir(TRIPO):
        if f.endswith('.glb') and not f.startswith('recorder'): shutil.copy(f'{TRIPO}/{f}', OUT)
    for f in os.listdir(f'{P.ASSETS}/interview'):
        if f.startswith('portrait_'): shutil.copy(f'{P.ASSETS}/interview/{f}', OUT)
    print('== DONE', OUT, sorted(os.listdir(OUT)))

if __name__ == '__main__':
    main()

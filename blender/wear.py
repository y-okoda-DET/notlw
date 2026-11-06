"""段階2 室内の質感：使い込みの跡（試作57）。Godot の Decal で、家の図面から位置を決めて汚れを重ねる。
材質を焼き直さないので、pck は増えない（画像5種類で 3MB ほど）。光の焼き込みもそのまま。

decals() は scene.json の 'wear' に入れる一覧を返す（Blender の座標、メートル）：
  dict(k=種類, c=[x, y, z] 中心, n=[x, y, z] 汚れが乗る面から部屋へ向く向き, u=[x, y, z] 画像の横の向き, s=[幅, 高さ, 奥行き])
  種類（godot/assets/wear/<k>.png、blender/wear_tex.py が作る）：
    skirt0..2 壁の下の黒ずみと靴・掃除機の当たり（幅2m ごとに区切る）
    jamb      戸口の両脇の手あか（真ん中は透明、閉じた扉には乗らない）
    floor     戸口の床のすり減り（人が通る所）
    streak    窓の下の壁の雨じみ（結露が垂れた筋）
    ceil      天井の雨もりのしみ（2階に3つ、1階に2つ）"""
import math, random
import house4 as H4

FACE = .08      # the room-side face of a wall stands .08 m in from its plan line (hall.flat_wall: .06 + the .02 slab)
SEG = 2.0       # skirt decals: one per 2 m (the image is 2 m wide)

def _wall_faces(walls, z0):
    """(axis, fixed in Blender, lo, hi in Blender along the wall, holes [(a, b, h0, h1)], room direction sign, z0)"""
    out = []
    for w in walls:
        ax, fixed, lo, hi, holes, wins, outer = w[:7]
        wz = w[7] if len(w) > 7 else z0
        hs = H4._face_holes(holes, wins, wz, H4.SILL1 if z0 < 1 else H4.SILL2, H4.WH1 if z0 < 1 else H4.WH2, 0)
        if ax == 'X':
            bfix, blo, bhi = H4.Y(fixed), H4.X(lo), H4.X(hi)
            bh = [(H4.X(a), H4.X(b), c, d) for (a, b, c, d) in hs]
            sides = [-outer] if outer else [1, -1]
        else:
            bfix, blo, bhi = H4.X(fixed), H4.Y(hi), H4.Y(lo)
            bh = [(H4.Y(b), H4.Y(a), c, d) for (a, b, c, d) in hs]
            sides = [outer] if outer else [1, -1]
        for s in sides:
            out.append((ax, bfix, blo, bhi, bh, -s, wz, outer))
    return out

def _pt(ax, fixed, along, z):
    return [along, fixed, z] if ax == 'X' else [fixed, along, z]

def _dir(ax, room):
    """normal (into the room) and the along-wall unit, in Blender"""
    n = [0, room, 0] if ax == 'X' else [room, 0, 0]
    u = [1, 0, 0] if ax == 'X' else [0, 1, 0]
    return n, u

def decals(seed=57):
    R = random.Random(seed)
    D = []
    floors = [(H4.F1_WALLS, 0.0, H4.H1), (H4.F2_WALLS, H4.F2, H4.H2)]
    for walls, z0, top in floors:
        for (ax, fixed, lo, hi, holes, room, wz, outer) in _wall_faces(walls, z0):
            n, u = _dir(ax, room)
            f = fixed + room * FACE
            doors = [(a, b) for (a, b, c, d) in holes if c <= wz + .01]
            wins = [(a, b, c, d) for (a, b, c, d) in holes if c > wz + .01]
            # skirt: the stretches between the doors, cut into ≤2 m pieces
            spans = [(lo, hi)]
            for (a, b) in doors:
                nsp = []
                for (p, q) in spans:
                    if b <= p or a >= q: nsp.append((p, q)); continue
                    if a > p: nsp.append((p, a))
                    if b < q: nsp.append((b, q))
                spans = nsp
            for (p, q) in spans:
                L = q - p
                if L < .15: continue
                k = max(1, math.ceil(L / SEG)); d = L / k
                for i in range(k):
                    a = p + i * d
                    D.append(dict(k=f'skirt{R.randrange(3)}', c=_pt(ax, f, a + d / 2, wz + .11), n=n, u=u, s=[d + .02, .22, .14]))
            # doors: hands on both jambs, the floor worn through the opening (once per opening: from the room == +1 side,
            # or from the only side of an outer wall)
            for (a, b) in doors:
                w = b - a
                D.append(dict(k='jamb', c=_pt(ax, f, (a + b) / 2, wz + 1.05), n=n, u=u, s=[w + .3, 2.1, .1]))
                if room == 1 or outer:
                    fl = _pt(ax, fixed, (a + b) / 2, wz + .02)
                    D.append(dict(k='floor', c=fl, n=[0, 0, 1], u=u, s=[w + .25, 1.7, .1]))
            # windows: damp streaks down the wall under the sill
            for (a, b, c, dd) in wins:
                if c - wz < .4: continue
                D.append(dict(k='streak', c=_pt(ax, f, (a + b) / 2, c - .32), n=n, u=u, s=[b - a + .12, .64, .1]))
    # ceilings: old leaks, in the 2F rooms under the roof and two in 1F (kitchen, under the bath upstairs; the study)
    for (x, y, z, r) in ((1.5, 6.6, H4.H2, .55), (8.6, 1.3, H4.H2, .7), (2.6, 2.0, H4.H2, .4), (8.2, 7.0, H4.H1, .5), (7.4, 1.8, H4.H1, .35)):
        D.append(dict(k='ceil', c=[H4.X(x), H4.Y(y), z], n=[0, 0, -1], u=[1, 0, 0], s=[2 * r, 2 * r, .12]))
    return D

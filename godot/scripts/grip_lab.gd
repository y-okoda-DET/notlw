extends RefCounted
# 確認と下ごしらえだけ（ゲームの中では走らない）。澪の指と手のひらが、持っている物に入り込んでいないかを数で確かめ、
# 物に触れる所まで指を一節ずつ曲げた角度を出す（ch6.gd の GRIPS に書き写す）。
#   --c6grip      場面が変わるたびに、いまの構えの入り込み（mm）とひじの位置を出す（GRIP …）
#   --c6fit       同じ所で、触れるまで曲げた角度を出す（FIT …）
# 手の向き：手首が原点、指先 -Z、手のひら -Y、袖 +Z。

const MAXA := [[1.45, 1.75, 1.20], [1.45, 1.75, 1.20], [1.45, 1.75, 1.20], [1.45, 1.75, 1.20], [0.75, 0.95, 0.95]]
const MINA := [[-0.30, -0.22, -0.12], [-0.30, -0.22, -0.12], [-0.30, -0.22, -0.12], [-0.30, -0.22, -0.12], [-0.35, -0.10, -0.10]]   # opened flat (at rest her fingers hang a little curled)
const NAMES := ["人差し指", "中指", "薬指", "小指", "親指"]

static func sk_to_h(h: Node3D) -> Transform3D:
	var t := Transform3D(); var nd: Node3D = h.get_meta("sk")
	while nd != h: t = nd.transform * t; nd = nd.get_parent()
	return t

# a skinned model's triangles as they are posed now, in the skeleton's frame (the vertices in the file are in the body's frame, before the bones)
static func skinned_faces(mi: MeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var sk := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	if sk == null or mi.skin == null: return mi.mesh.get_faces()
	var mats := []
	for k in mi.skin.get_bind_count():
		var bi := mi.skin.get_bind_bone(k)
		if bi < 0: bi = sk.find_bone(mi.skin.get_bind_name(k))
		mats.append(sk.get_bone_global_pose(bi) * mi.skin.get_bind_pose(k))
	for s in mi.mesh.get_surface_count():
		var ar := mi.mesh.surface_get_arrays(s)
		var V: PackedVector3Array = ar[Mesh.ARRAY_VERTEX]; var B = ar[Mesh.ARRAY_BONES]; var W = ar[Mesh.ARRAY_WEIGHTS]; var I = ar[Mesh.ARRAY_INDEX]
		var n: int = B.size() / V.size()
		var P := PackedVector3Array(); P.resize(V.size())
		for i in V.size():
			var q := Vector3.ZERO
			for k in n:
				var w: float = W[i * n + k]
				if w > 0.0: q += (mats[B[i * n + k]] * V[i]) * w
			P[i] = q
		if I == null or I.size() == 0: out.append_array(P)
		else:
			for i in I: out.append(P[i])
	return out

# the closest point of a triangle (Ericson)
static func closest(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a; var ac := c - a; var ap := p - a
	var d1 := ab.dot(ap); var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0: return a
	var bp := p - b; var d3 := ab.dot(bp); var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3: return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0: return a + ab * (d1 / (d1 - d3))
	var cp := p - c; var d5 := ab.dot(cp); var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6: return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0: return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0: return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var den := 1.0 / (va + vb + vc)
	return a + ab * (vb * den) + ac * (vc * den)

# the things near a hand, as triangles in the hand's frame. [tris, names (one per triangle)]
static func near(h: Node3D, root: Node, skip: Array, reach := 0.17, only: Array = []) -> Array:
	var tris := PackedVector3Array(); var names := []
	var inv := h.global_transform.affine_inverse()
	var c := Vector3(0, -0.02, -0.07)
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree(): continue
		if String(mi.name).begins_with("nocol"): continue   # a film over a thing (the blood on the tripod's head), not a thing
		var own := false
		for s in skip:
			if s == mi or (s as Node).is_ancestor_of(mi): own = true
		if own: continue
		if not only.is_empty():
			var ok := false
			for o in only:
				if o == mi or (o as Node).is_ancestor_of(mi): ok = true
			if not ok: continue
		var xf: Transform3D = inv * mi.global_transform
		var f: PackedVector3Array
		if mi.skin != null:
			var sk2 := mi.get_node_or_null(mi.skeleton) as Skeleton3D
			if sk2 == null: continue
			xf = inv * sk2.global_transform; f = skinned_faces(mi)
		else:
			var bb: AABB = xf * mi.mesh.get_aabb()
			if not bb.grow(reach).has_point(c): continue
			f = mi.mesh.get_faces()
		for i in range(0, f.size(), 3):
			var a := xf * f[i]; var b := xf * f[i + 1]; var d := xf * f[i + 2]
			if closest(c, a, b, d).distance_to(c) < reach:
				tris.append(a); tris.append(b); tris.append(d); names.append("%s/%s" % [mi.get_parent().name, mi.name])
	return [tris, names]

static func dist(p: Vector3, tris: PackedVector3Array) -> Array:
	var best := 9.0; var bi := -1
	for i in range(0, tris.size(), 3):
		var d := closest(p, tris[i], tris[i + 1], tris[i + 2]).distance_to(p)
		if d < best: best = d; bi = i / 3
	return [best, bi]

# is the point inside a closed thing? (how many faces a ray to far away crosses)
static func inside(p: Vector3, tris: PackedVector3Array) -> bool:
	# three rays, and all must say so (a sheet with no back is crossed by one ray and not by another)
	for dir in [Vector3(0.31, 0.83, 0.47), Vector3(-0.72, -0.35, 0.60), Vector3(0.44, -0.20, -0.87)]:
		var n := 0; var far: Vector3 = p + dir * 3.0
		for i in range(0, tris.size(), 3):
			if Geometry3D.segment_intersects_triangle(p, far, tris[i], tris[i + 1], tris[i + 2]) != null: n += 1
		if n % 2 == 0: return false
	return true

# the fingers' thickness and the tips' length, from her own model (in the hand's frame, at rest)
static func measure(h: Node3D) -> Dictionary:
	if h.has_meta("gl_m"): return h.get_meta("gl_m")
	var sk: Skeleton3D = h.get_meta("sk"); var fb: Array = h.get_meta("fb"); var th := sk_to_h(h)
	# measured on her model by eye from the side views (the automatic measure took the next finger's flesh for this one's)
	var rad := [[0.0090, 0.0085, 0.0078], [0.0092, 0.0087, 0.0080], [0.0088, 0.0083, 0.0076], [0.0080, 0.0075, 0.0070], [0.0115, 0.0100, 0.0090]]
	var tip := []; var off := []
	for f in 5:
		tip.append((th * sk.get_bone_global_rest(fb[f * 3 + 2].i)).origin.distance_to((th * sk.get_bone_global_rest(fb[f * 3 + 1].i)).origin) * (0.95 if f < 4 else 0.85))
		off.append([Vector3.ZERO, Vector3.ZERO, Vector3.ZERO])
	var m := {"rad": rad, "tip": tip, "off": off}
	h.set_meta("gl_m", m)
	print("GRIPM %s tips(mm) %s radii(mm) %s off(mm) %s" % [h.name, tip.map(func(x): return snappedf(x * 1000.0, 0.1)), rad.map(func(r): return r.map(func(x): return snappedf(x * 1000.0, 0.1))), off.map(func(r): return r.map(func(x): return snappedf(x.length() * 1000.0, 0.1)))])
	return m

static func open_angles() -> Array:
	var a := []
	for f in 5:
		for j in 3: a.append(MINA[f][j])
	a[12] = 0.0; a.append(1.0)
	return a

# 15 joints' bends, and (16th) the thumb's swing out of the palm's plane
static func set_angles(h: Node3D, ang: Array):
	var sk: Skeleton3D = h.get_meta("sk"); var fb: Array = h.get_meta("fb")
	for k in fb.size():
		var b = fb[k]
		var q: Quaternion = sk.get_bone_rest(b.i).basis.get_rotation_quaternion()
		if b.has("ab") and ang.size() > 15: q = q * Quaternion(b.ab, ang[15])
		sk.set_bone_pose_rotation(b.i, q * Quaternion(b.ax, ang[k]))

# one finger's three segments [a, b] (the middle of the flesh, not the bone), in the hand's frame, as it is posed now
static func chain(h: Node3D, f: int) -> Array:
	var sk: Skeleton3D = h.get_meta("sk"); var fb: Array = h.get_meta("fb"); var th := sk_to_h(h)
	var m := measure(h)
	var X := []; var R := []
	for j in 3:
		X.append(th * sk.get_bone_global_pose(fb[f * 3 + j].i)); R.append(th * sk.get_bone_global_rest(fb[f * 3 + j].i))
	var segs := []
	for j in 3:
		var o: Vector3 = X[j].basis.orthonormalized() * (R[j].basis.orthonormalized().inverse() * m.off[f][j])
		var b: Vector3 = X[j + 1].origin if j < 2 else X[2].origin + X[2].basis.y.normalized() * m.tip[f]
		segs.append([X[j].origin + o, b + o])
	return segs

# the deepest a segment of a finger is in something: + is in, − is clear (metres), and what
static func seg_pen(a: Vector3, b: Vector3, r: float, tris: PackedVector3Array, deep := false) -> Array:
	var worst := -9.0; var wi := -1
	for k in 4:
		var q := a.lerp(b, (k + 0.5) / 4.0)
		var d := dist(q, tris)
		var pen: float = r - d[0]
		if deep and inside(q, tris): pen = r + d[0]
		if pen > worst: worst = pen; wi = d[1]
	return [worst, wi]

static func palm_pts(h: Node3D) -> Array:
	var sk: Skeleton3D = h.get_meta("sk"); var fb: Array = h.get_meta("fb"); var th := sk_to_h(h)
	var out := []
	for f in 4:
		var k: Vector3 = (th * sk.get_bone_global_rest(fb[f * 3].i)).origin
		for t in [0.25, 0.5, 0.75, 0.95]: out.append(Vector3(k.x * (0.55 + 0.45 * t), k.y * t, k.z * t))
	return out

static func report(h: Node3D, root: Node, skip: Array, tag: String) -> float:
	var nr := near(h, root, skip); var tris: PackedVector3Array = nr[0]; var names: Array = nr[1]
	if tris.is_empty(): print("GRIP %s %s 近くに物なし" % [tag, h.name]); return 0.0
	var m := measure(h); var worst := 0.0; var lines := []
	for f in 5:
		var p := chain(h, f)
		for j in 3:
			var sp := seg_pen(p[j][0], p[j][1], m.rad[f][j] * 0.9, tris, true)
			if sp[0] > 0.0015:
				lines.append("%s%d節 %.1fmm→%s" % [NAMES[f], j + 1, sp[0] * 1000.0, names[sp[1]]]); worst = maxf(worst, sp[0])
	var pw := -9.0; var pn := ""
	for q in palm_pts(h):
		var d := dist(q, tris); var pen: float = 0.010 - d[0]
		if inside(q, tris): pen = 0.010 + d[0]
		if pen > pw: pw = pen; pn = names[d[1]]
	if pw > 0.0015: lines.append("手のひら %.1fmm→%s" % [pw * 1000.0, pn]); worst = maxf(worst, pw)
	print("GRIP %s %s 三角 %d  %s" % [tag, h.name, tris.size() / 3, ("入り込み: " + "、".join(lines)) if lines.size() > 0 else "入り込みなし（手のひらの空き %.1fmm）" % (-pw * 1000.0)])
	return worst

# bend each finger, joint by joint from the root, until it touches. Returns the 15 angles
static func fit(h: Node3D, root: Node, skip: Array, tag: String, only: Array = [], relax := true, side_ab := -9.0, thumb_fix: Array = []) -> Array:
	var nr := near(h, root, skip, 0.17, only); var tris: PackedVector3Array = nr[0]
	var m := measure(h)
	var ang := open_angles()
	set_angles(h, ang)
	var touched := []
	for f in 5:
		var hit := false
		if f == 4 and thumb_fix.size() == 4:   # or: it is put where it is told (beside a thing whose whole face must be seen)
			ang[12] = thumb_fix[0]; ang[13] = thumb_fix[1]; ang[14] = thumb_fix[2]; ang[15] = thumb_fix[3]; set_angles(h, ang); touched.append(true); continue
		if f == 4 and side_ab > -5.0:   # or: it stays a little out of the palm, and closes sideways against the thing's edge
			ang[15] = side_ab; set_angles(h, ang)
		elif f == 4:   # the thumb comes down from out of the palm, like the other jaw of a clamp
			var ab := 1.0
			while ab > -0.35:
				ang[15] = ab - 0.03; set_angles(h, ang)
				var pt := chain(h, 4); var colt := false
				for s in 3:
					if seg_pen(pt[s][0], pt[s][1], m.rad[4][s], tris)[0] > -0.0005: colt = true
				if colt: ang[15] = ab; hit = true; break
				ab -= 0.03
			set_angles(h, ang)
		# the joints close together; when a segment meets the thing, it and the joints behind it stop, and the rest go on round it
		var first := 1 if (f == 4 and side_ab < -5.0) else 0
		var live := first
		var ratio := [0.8, 1.05, 0.7]
		for it in 80:
			if live > 2: break
			var prev := [ang[f * 3], ang[f * 3 + 1], ang[f * 3 + 2]]
			var any := false
			for j in range(live, 3):
				if ang[f * 3 + j] < MAXA[f][j]: ang[f * 3 + j] = minf(ang[f * 3 + j] + 0.03 * ratio[j], MAXA[f][j]); any = true
			if not any: break
			set_angles(h, ang)
			var p := chain(h, f); var hit_s := -1
			for s in range(live, 3):
				if seg_pen(p[s][0], p[s][1], m.rad[f][s], tris)[0] > -0.0005: hit_s = s
			if hit_s >= 0:
				for j in 3: ang[f * 3 + j] = prev[j]
				set_angles(h, ang)
				hit = true; live = hit_s + 1
		touched.append(hit)
	# a finger that met nothing goes with the one beside it (they do not close one by one)
	if relax:
		for f in [1, 2, 0, 3]:
			if touched[f]: continue
			var nb := -1
			for g in ([f - 1, f + 1] if f != 3 else [2]):
				if g >= 0 and g < 4 and touched[g]: nb = g
			if nb < 0:
				for g in 4:
					if touched[g]: nb = g
			for j in 3: ang[f * 3 + j] = ang[nb * 3 + j] if nb >= 0 else 0.25
		if not touched[4]:
			ang[12] = 0.25; ang[13] = 0.3; ang[14] = 0.2; ang[15] = 0.0
	set_angles(h, ang)
	print("FIT %s %s 触れた %s 三角 %d\n\t\"%s\": %s," % [tag, h.name, touched, tris.size() / 3, tag, ang.map(func(x): return snappedf(x, 0.01))])
	return ang

# her hand's own skin (not the sleeve) as points, as it is posed now, in the hand's frame
static func hand_pts(h: Node3D, every := 1) -> PackedVector3Array:
	var th := sk_to_h(h); var out := PackedVector3Array(); var seen := {}
	for n in h.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).skin == null: continue
		var k := 0
		for v in skinned_faces(n as MeshInstance3D):
			var q: Vector3 = th * v
			if q.z > -0.004: continue
			var key := Vector3i(q * 2000.0)
			if seen.has(key): continue
			seen[key] = true; k += 1
			if k % every == 0: out.append(q)
	return out

# how the hand's skin stands to the things: [deepest in (m, 0 if none), nearest gap (m), what]
static func skin_check(h: Node3D, tris: PackedVector3Array, names: Array, every := 1, pts = null) -> Array:
	var deep := 0.0; var gap := 9.0; var what := ""; var at := Vector3.ZERO
	for q in (pts if pts != null else hand_pts(h, every)):
		var d := dist(q, tris)
		if d[0] > 0.03: continue
		if d[0] < 0.012 and inside(q, tris):
			if d[0] > deep: deep = d[0]; what = names[d[1]] if d[1] >= 0 and d[1] < names.size() else ""; at = q
		elif d[0] < gap: gap = d[0]
	return [deep, gap, what, at]

# the last word: her skin itself against the things
static func verify(h: Node3D, root: Node, skip: Array, tag: String, only: Array = []) -> float:
	var nr := near(h, root, skip, 0.17, only)
	if (nr[0] as PackedVector3Array).is_empty(): print("VERIFY %s %s 近くに物なし" % [tag, h.name]); return 0.0
	var r := skin_check(h, nr[0], nr[1], 2)
	print("VERIFY %s %s 入り込み %.1fmm%s  いちばん近い肌と物の間 %.1fmm" % [tag, h.name, r[0] * 1000.0, ("（%s、手の中の場所 %s）" % [r[2], (r[3] as Vector3).snappedf(0.001)]) if r[0] > 0.0 else "", r[1] * 1000.0])
	return r[0]

# a thing that rides the hand: bring it up from under the palm (along the hand's Y) until it meets the skin. Returns its place
static func seat_obj(h: Node3D, obj: Node3D, tag: String) -> Vector3:
	var base := obj.position
	# (not the thumb: it stands out of the palm now, and comes down on the thing afterwards)
	var oa := open_angles(); oa[15] = 0.0; set_angles(h, oa)
	var all := hand_pts(h, 4); var pts := PackedVector3Array(); var tc := chain(h, 4)
	for q in all:
		var far := true
		for j in 3:
			if Geometry3D.get_closest_point_to_segment(q, tc[j][0], tc[j][1]).distance_to(q) < 0.026: far = false
		if far: pts.append(q)
	var nr := near(h, obj, [], 0.5); var t0: PackedVector3Array = nr[0]
	var y := -0.07
	for stepv in [0.004, 0.001]:
		while y < 0.03:
			var sh := Vector3(0, y - base.y, 0); var tr := PackedVector3Array()
			for v in t0: tr.append(v + sh)
			var r := skin_check(h, tr, nr[1], 1, pts)
			if r[0] > 0.0 or r[1] < 0.0008: break
			y += stepv
		if stepv > 0.002: y -= 0.006
	obj.position = Vector3(base.x, y - 0.001, base.z)
	set_angles(h, open_angles())
	print("SEAT %s %s → y %.4f" % [tag, obj.name, obj.position.y])
	return obj.position

# the hand onto a thing that stands by itself: slide the hand along its own Y (palm first) until the skin meets it. Returns the hand's place
static func seat_hand(h: Node3D, root: Node, tag: String, only: Array = [], as_is := false) -> Vector3:
	var base := h.position; var up := h.basis.y.normalized()
	var oa := open_angles(); oa[15] = -0.1
	if not as_is: set_angles(h, oa)
	# the palm first (the fingers come round the thing afterwards)
	var pts := PackedVector3Array(); var ch := []
	for f in 5: ch.append(chain(h, f))
	for q in hand_pts(h, 3):
		var far := true
		for f in 5:
			for j in 3:
				if not as_is and Geometry3D.get_closest_point_to_segment(q, ch[f][j][0], ch[f][j][1]).distance_to(q) < (0.024 if f == 4 else 0.014): far = false
		if far: pts.append(q)
	var y := 0.06
	for stepv in [0.005, 0.001]:
		while y > -0.06:
			h.position = base + up * y
			var nr := near(h, root, [h], 0.17, only)
			if not (nr[0] as PackedVector3Array).is_empty():
				var r := skin_check(h, nr[0], nr[1], 1, pts)
				if r[0] > 0.0 or r[1] < 0.0008: break
			y -= stepv
		if stepv > 0.002: y += 0.0075
	h.position = base + up * (y + 0.001)
	print("SEAT %s %s → hand position %s (moved %.1fmm along its Y)" % [tag, h.name, h.position.snappedf(0.0005), (y + 0.001) * 1000.0])
	return h.position

# after the fit (which takes the fingers for round rods): her skin itself. Where it is still in the thing, that finger lets go a little;
# where it is the palm, the thing (if it rides the hand) moves off it. Returns the angles
static func refine(h: Node3D, root: Node, skip: Array, tag: String, ang: Array, only: Array, obj: Node3D = null, tol := 0.0012, thumb_up := false) -> Array:
	var last := 0.0; var pushed := 0.0
	for it in 40:
		var nr := near(h, root, skip, 0.17, only)
		var r := skin_check(h, nr[0], nr[1], 2)
		last = r[0]
		if r[0] <= tol: break
		var bf := -1; var bd := 0.016
		for f in 5:
			var c := chain(h, f)
			for j in 3:
				var d: float = Geometry3D.get_closest_point_to_segment(r[3], c[j][0], c[j][1]).distance_to(r[3])
				if d < bd: bd = d; bf = f
		if bf == 4 and thumb_up:    # the palm lies on the thing: the thumb lifts to the back of the hand's side, and lets go
			if ang[15] > -0.6: ang[15] -= 0.04
			else: ang[12] = maxf(ang[12] - 0.03, -0.5)
			ang[13] = maxf(ang[13] - 0.02, MINA[4][1]); ang[14] = maxf(ang[14] - 0.02, MINA[4][2])
		elif bf == 4: ang[15] += 0.03; ang[13] = maxf(ang[13] - 0.02, MINA[4][1])
		elif bf >= 0:
			var moved := false
			for j in [2, 1, 0]:
				if ang[bf * 3 + j] > MINA[bf][j] + 0.001: ang[bf * 3 + j] -= 0.03; moved = true; break
			if not moved:
				if obj == null and pushed < 0.015: h.position += h.basis.y.normalized() * 0.001; pushed += 0.001
				else: break
		elif obj != null and pushed < 0.002: obj.position.y -= 0.0007; pushed += 0.0007
		elif obj == null and pushed < 0.015: h.position += h.basis.y.normalized() * 0.001; pushed += 0.001
		else: break
		set_angles(h, ang)
	if obj == null and pushed > 0.0: print("REFINE %s hand backed off %.1fmm, now %s" % [tag, pushed * 1000.0, h.position.snappedf(0.0005)])
	print("REFINE %s %s 残り %.1fmm%s\n\t\"%s\": %s," % [tag, h.name, last * 1000.0, (" obj y %.4f" % obj.position.y) if obj else "", tag, ang.map(func(x): return snappedf(x, 0.01))])
	return ang

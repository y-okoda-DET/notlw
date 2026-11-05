"""段階2 外（2026-11-05）: the lay of the land round the house, without Blender (house_shots.py uses it too).

The house stands on a terrace cut into a hillside that falls to the south-east. A gravel drive goes down from the front
porch to an old one-lane forest road (林道). The road comes up from the valley in the south, swings round a bend above a
ravine (沢) east of it, and runs west past the foot of the drive. At that bend, the outer shoulder (路肩) is the one the
storm takes away in the night (第8章: 桐生 falls from it at 2:00).

All in Blender metres (Z up, the front of the house toward +Y = south, east = +X). Heights: 1F floor 0, ground at the
front -.55 (house4_ext.ground).

  terrain(x, y)   the natural ground (before the road is cut in)
  ROAD, DRIVE     the two roads (Road objects: dense stations with position, tangent, normal, height)
  final(x, y)     the ground with the roads cut in (what is built and walked on), state 'ok' or 'fall'
"""
import math
import numpy as np

# the house (house4: wall centre lines x -4.8..5.2, y -1.7..6.3)
HX0, HX1, HYN, HYS = -4.8, 5.2, -1.7, 6.3
HC = ((HX0 + HX1) / 2, (HYN + HYS) / 2)
GZ = -.55

def _ss(a, b, v):
    t = np.clip((v - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)

def ground_house(x, y):
    """house4_ext.ground, vectorised (the terrace round the house; kept exactly so the house still sits on it)."""
    fall = _ss(1.2, 5.2, x) * _ss(HYS + .6, HYS - 1.2, y)
    z = GZ - 1.25 * fall
    z = z - np.where(x > 5.2, .16 * (x - 5.2) * _ss(HYS + 3, HYS - 1, y), 0)
    return z

def _noise(x, y):
    # long, low swells: a hillside is never a plane
    return (.9 * np.sin(x * .061 + 1.3) * np.sin(y * .047 + .4) + .5 * np.sin(x * .13 + y * .09 + 2.1)
            )

RAV_A, RAV_D = np.array([74.0, 36.0]), np.array([16.0, 42.0]) / math.hypot(16, 42)
def terrain(x, y):
    x = np.asarray(x, float); y = np.asarray(y, float)
    hill = GZ - .11 * (x - 3) - .07 * (y - 8) + _noise(x, y)
    # the ravine east of the bend: a stream cut 12 m into the slope
    rx, ry = x - RAV_A[0], y - RAV_A[1]
    along = rx * RAV_D[0] + ry * RAV_D[1]; perp = rx * RAV_D[1] - ry * RAV_D[0]
    hill = hill - 12 * np.exp(-(perp / 9.0) ** 2) * _ss(-25, 5, along)
    dh = np.hypot(x - HC[0], y - HC[1])
    w = _ss(15, 30, dh)
    return (1 - w) * ground_house(x, y) + w * hill

# ------------------------------------------------------------------ roads
def _catmull(pts, step):
    pts = [np.array(p, float) for p in pts]
    P = [pts[0] * 2 - pts[1]] + pts + [pts[-1] * 2 - pts[-2]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        n = max(2, int(np.linalg.norm(p2 - p1) / step * 2))
        for t in np.linspace(0, 1, n, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-1])
    a = np.array(out)
    # even spacing
    seg = np.r_[0, np.cumsum(np.linalg.norm(np.diff(a, axis=0), axis=1))]
    s = np.arange(0, seg[-1], step)
    return np.c_[np.interp(s, seg, a[:, 0]), np.interp(s, seg, a[:, 1])], s

def _gauss(z, sigma):
    if sigma <= 0: return z
    k = np.arange(-int(3 * sigma), int(3 * sigma) + 1); w = np.exp(-(k / sigma) ** 2 / 2); w /= w.sum()
    zp = np.r_[np.full(len(k) // 2, z[0]), z, np.full(len(k) // 2, z[-1])]
    return np.convolve(zp, w, mode='valid')

class Road:
    def __init__(self, name, pts, hw, step=.25, smooth=10.0, z0=None, z1=None, maxg=None):
        self.name, self.hw, self.step = name, hw, step
        self.P, self.s = _catmull(pts, step)
        d = np.gradient(self.P, axis=0); self.T = d / np.linalg.norm(d, axis=1)[:, None]
        self.N = np.c_[-self.T[:, 1], self.T[:, 0]]           # left of the direction of travel
        z = terrain(self.P[:, 0], self.P[:, 1])
        z = _gauss(z, smooth / step)
        if maxg:   # no steeper than maxg: integrate the clamped slope out from the lowest-error middle
            dz = np.clip(np.diff(z), -maxg * step, maxg * step); z2 = np.r_[0, np.cumsum(dz)]
            z = z2 + np.mean(z - z2)
        if z0 is not None or z1 is not None:                   # pinned ends (the drive: the porch, the junction)
            a = (z0 - z[0]) if z0 is not None else 0; b = (z1 - z[-1]) if z1 is not None else 0
            z = z + a + (b - a) * self.s / self.s[-1]
        self.z = z
        from scipy.spatial import cKDTree
        self.kd = cKDTree(self.P)
    def at(self, s):
        i = int(np.clip(round(s / self.step), 0, len(self.s) - 1)); return i
    def query(self, x, y):
        """(distance across, side +1 left / -1 right, station index) for points."""
        q = np.c_[np.ravel(x), np.ravel(y)]
        _, i = self.kd.query(q)
        v = q - self.P[i]
        across = np.einsum('ij,ij->i', v, self.N[i])
        along = np.einsum('ij,ij->i', v, self.T[i])
        # past the ends the distance is the true one (no road there)
        d = np.where((i == 0) & (along < 0) | (i == len(self.s) - 1) & (along > 0), np.hypot(across, along), np.abs(across))
        return d, np.sign(across + 1e-9), i

# the forest road, from its west end (it goes on up round a spur) east past the drive, round the bend above the
# ravine and south down the valley
ROAD = Road('road', [(-45, 22), (-25, 28), (-5, 31.5), (10, 33), (28, 35), (45, 38), (58, 45), (66, 54), (68, 66),
                     (63, 80), (53, 93), (42, 106)], hw=2.0, maxg=.11)
J_IDX = int(ROAD.kd.query([9.0, 33.0])[1])
J = ROAD.P[J_IDX]
# the private gravel drive: from the front porch's steps (the house's front, x .2) down to the road
DRIVE = Road('drive', [(.2, 8.0), (.9, 11.5), (2.6, 16.5), (5.0, 22.5), (7.4, 28.0), (J[0] - .3, J[1] - 1.2)], hw=1.4,
             smooth=4.0, z0=GZ, z1=float(ROAD.z[J_IDX]))

# the shoulder that goes: the outer (east) edge of the bend
SLIP_IDX = int(ROAD.kd.query([67.6, 60.0])[1])
SLIP_HALF = 7.0                        # metres of road either side of the middle
def _outer_side():
    i = SLIP_IDX
    return 1.0 if terrain(*(ROAD.P[i] + ROAD.N[i] * 6)) < terrain(*(ROAD.P[i] - ROAD.N[i] * 6)) else -1.0
SLIP_SIDE = _outer_side()

def slip_u(i):
    """metres along the road from the slip's middle"""
    return (np.asarray(i) - SLIP_IDX) * ROAD.step

def scarp_edge(u, seed=4):
    """how far from the centre line the road still holds, along the slip (u metres from its middle): the outer 1.6 m
    of the 2 m half-width is gone at the middle, less toward the ends, the broken edge ragged."""
    u = np.asarray(u, float)
    t = np.clip(1 - (u / SLIP_HALF) ** 2, 0, 1)
    rag = .12 * np.sin(u * 3.7 + seed) + .07 * np.sin(u * 9.1 + 1.3) + .05 * np.sin(u * 17.3)
    return ROAD.hw + .45 - (2.05 * t ** .7) + rag * t

# ------------------------------------------------------------------ the ground with the roads cut in
WALL_MAX = 2.4
J_GAP = DRIVE.hw + 2.5          # no gutter or wall this far either side of where the drive joins the road
def side_heights(road, i, side):
    """the natural ground 3.5 m off the edge, minus the road: >0 cut (a retaining wall), <0 fill (a bank down)"""
    p = road.P[i] + road.N[i] * (np.asarray(side, float) * (road.hw + 3.5))[..., None]
    return terrain(p[..., 0], p[..., 1]) - road.z[i]

def _cut(z, d, side, i, road, walls):
    hw = road.hw; zr = road.z[i]; dd = d - hw
    up = side_heights(road, i, side)
    if walls:
        W = np.clip(up - .3, 0, WALL_MAX)
        lean = .3 * W
        # gutter (側溝) dd 0..0.5 on the cut side; wall face leaning back from dd .5 to .5+lean; the slope above
        cut = np.where(dd < .52, zr - .42,
              np.where(dd < .5 + lean + .15, zr + W * np.clip((dd - .5) / np.maximum(lean, .01), 0, 1) - .12,
                       zr + W - .12 + (dd - .5 - lean - .15) * .9))
        cut = np.where(W < .05, np.where(dd < .52, zr - .42, zr + (dd - .5) * .7), cut)
        fill = np.where(dd < .6, zr - .06, zr - .06 - (dd - .6) * 1.15)
    else:
        cut = zr - .03 + np.maximum(dd, 0) * .55
        fill = zr - .03 - np.maximum(dd, 0) * .55
    zin = np.where(d <= hw, zr - .03, np.nan)
    zz = np.where(up > 0, np.minimum(z, cut), np.maximum(z, fill))
    return np.where(np.isnan(zin), zz, zin)

def final(x, y, state='ok'):
    x = np.asarray(x, float); y = np.asarray(y, float); sh = x.shape
    x = x.ravel(); y = y.ravel()
    z = terrain(x, y)
    for road, walls, reach in ((ROAD, True, 16.0), (DRIVE, False, 9.0)):   # the drive last: it opens the road's bank where it joins
        d, side, i = road.query(x, y)
        m = d < reach
        if m.any():
            z[m] = _cut(z[m], d[m], side[m], i[m], road, walls)
    d, side, i = ROAD.query(x, y)                         # the road's own bed stays under the asphalt
    on = d <= ROAD.hw; z[on] = ROAD.z[i[on]] - .03
    sl = on & slip_region(x, y); z[sl] = ROAD.z[i[sl]] - .1      # under the settled outer slab (it sinks 5.5 cm before it goes)
    if state == 'fall':
        z = z - slip_depth(x, y)
    return z.reshape(sh)

def slip_depth(x, y):
    """how much lower the ground is where the shoulder went (0 outside the slip)"""
    d, side, i = ROAD.query(x, y)
    u = slip_u(i); a = d * side * SLIP_SIDE                  # across, + toward the outside
    e = scarp_edge(u)
    t = np.clip(1 - (u / (SLIP_HALF + 1.5)) ** 2, 0, 1)
    inside = (np.abs(u) < SLIP_HALF + 1.5) & (a > e - .05) & (a < ROAD.hw + 13)
    # a 1.6 m scarp at the broken edge, then the slumped earth, thickest under it and thinning down the slope
    k = np.clip((a - e) / .35, 0, 1)
    dep = (1.6 * k) * np.clip(1 - (a - e - .35) / 11.0, 0, 1) ** .8 + .4 * np.sin(np.clip((a - e) / 12, 0, 1) * math.pi)
    return np.where(inside, dep * t, 0.0)

def slip_region(x, y, pad=0.0):
    d, side, i = ROAD.query(x, y)
    u = slip_u(i); a = d * side * SLIP_SIDE
    return ((np.abs(u) < SLIP_HALF + 1.5 + pad) & (a > ROAD.hw - 2.3 - pad) & (a < ROAD.hw + 13 + pad)).reshape(np.shape(x))

# where one may walk (the rest is fenced off by unseen walls): the clearing round the house, the drive, the road on
# its own width (the guardrail side and the wall side stop you), as far down as the next bend below the slip
WALK_END = SLIP_IDX + int(40 / ROAD.step)
WALK_START = int(ROAD.kd.query([-12.0, 30.0])[1])
def walkable(x, y):
    x = np.asarray(x, float); y = np.asarray(y, float)
    dh = np.maximum(np.maximum(HX0 - 7 - x, x - HX1 - 6), 0) ** 2 + np.maximum(np.maximum(HYN - 6 - y, y - HYS - 9), 0) ** 2
    ok = dh < 1e-9
    d, side, i = DRIVE.query(x, y); ok |= (d < DRIVE.hw + 1.2).reshape(x.shape)
    d, side, i = ROAD.query(x, y); ok |= ((d < ROAD.hw + .1) & (i >= WALK_START) & (i <= WALK_END)).reshape(x.shape)
    return ok

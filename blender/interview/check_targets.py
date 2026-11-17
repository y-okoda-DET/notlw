# 明るさの目標を自動で測る。flat の画で材質ごとの範囲を取り、本番の画の輝度(0-255, sRGB)の中央値を目標と比べる。
# python3 check_targets.py out ref1 ref2 ref3
import sys, json, numpy as np
from PIL import Image
TARGETS = {   # お手本の写真から測った値（中央値の目安, 許す幅）
 'ref1': {'shoji_paper': (231, 18), 'plaster': (74, 20), 'fusuma': (82, 20), 'wood_table': (47, 18), 'tatami': (53, 18), 'zabuton': (40, 18)},
 'ref2': {'plaster_toko': (109, 20), 'scroll': (132, 25), 'wood_post': (49, 18), 'wood_toko_floor': (54, 20), 'tatami_v': (116, 25), 'tatami': (116, 25), 'shoji_paper': (228, 18)},
 'ref3': {'wood_table': (112, 30), 'shoji_paper': (235, 18)},
}
FLAT = json.load(open(sys.argv[1] + '/flat_colors.json'))
def lum(a): return (0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2])
out = []
for cam in sys.argv[2:]:
    img = np.asarray(Image.open(f'{sys.argv[1]}/{cam}.png').convert('RGB')).astype(float)
    fl = np.asarray(Image.open(f'{sys.argv[1]}/{cam}_flat.png').convert('RGB')).astype(float)
    if fl.shape != img.shape: fl = np.asarray(Image.open(f'{sys.argv[1]}/{cam}_flat.png').convert('RGB').resize(img.shape[1::-1], Image.NEAREST)).astype(float)
    names = list(FLAT); cols = np.array([FLAT[n] for n in names]) * 255
    d = ((fl[:, :, None, :] - cols[None, None]) ** 2).sum(-1); idx = d.argmin(-1); ok = d.min(-1) < 60
    L = lum(img)
    out.append(f'## {cam}  黒つぶれ(<10) {100*(L<10).mean():.1f}%  白飛び(>250) {100*(L>250).mean():.1f}%')
    for n, (t, tol) in TARGETS[cam].items():
        if n not in names: continue
        m = ok & (idx == names.index(n))
        if cam == 'ref1' and n == 'tatami': m[:int(m.shape[0]*0.72)] = False   # お手本で測ったのは手前の畳
        if m.sum() < 200: out.append(f'  {n:16s} 画に無い'); continue
        v = np.median(L[m]); mark = '○' if abs(v - t) <= tol else '×'
        out.append(f'  {mark} {n:16s} {v:6.1f}  目標 {t}±{tol}  ({100*m.mean():.1f}% の面積)')
print('\n'.join(out))

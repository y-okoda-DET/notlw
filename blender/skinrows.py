import json, numpy as np
from PIL import Image
M = json.load(open('/home/claude/kf/masks_style.json'))
def skin_rows(k):
    info = M[k]; (lx, ly), (rx, ry) = info['eyes']; d = rx - lx; ey = (ly + ry) / 2; cx = int((lx + rx) / 2)
    im = np.asarray(Image.open(f'/home/claude/assets/faces_style/{k}_open.png').convert('RGB'), np.float32) / 255
    ref = np.median(np.concatenate([im[int(ly + d * .45) - 10:int(ly + d * .45) + 10, int(x) - 10:int(x) + 10].reshape(-1, 3) for x in (lx, rx)]), 0)
    out = []
    for y in range(int(ey), min(im.shape[0], int(ey + 2.6 * d))):
        row = im[y]; dist = np.abs(row - ref).sum(1)
        # skin, allowing for drawn shading (darker, same hue)
        ratio = row / np.maximum(row.sum(1, keepdims=True), 1e-4); rref = ref / ref.sum()
        ok = (np.abs(ratio - rref).sum(1) < .07) & (row.sum(1) > ref.sum() * .55) & (row.sum(1) < ref.sum() * 1.15)
        if not ok[cx]:
            # centre may be a shadow line: look a few px around
            near = [x for x in range(cx - 15, cx + 16) if ok[x]]
            if not near: out.append((y, -1, -1)); continue
            c = near[0]
        else: c = cx
        l = c; miss = 0
        while l > 0 and miss < 6:
            l -= 1; miss = 0 if ok[l] else miss + 1
        r = c; miss = 0
        while r < im.shape[1] - 1 and miss < 6:
            r += 1; miss = 0 if ok[r] else miss + 1
        out.append((y, l + 6, r - 6))
    return out, ey, d
if __name__ == '__main__':
    for k in M:
        o, ey, d = skin_rows(k)
        print(k, int(ey), int(d), [(y, r - l) for y, l, r in o][::12])

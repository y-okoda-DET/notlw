"""How much of a printed still is paper / blue alone / orange alone / both inks (the dark teal).
python3 print_share.py a.png [b.png ...]   -> one line per image. Used to keep the night print a print:
a night frame that is mostly 'both' has gone back to a dark picture with grain (試作4, 試作91)."""
import sys, numpy as np
from PIL import Image
PAPER = np.array([.945, .925, .875]); A = np.array([0, .47, .75]); B = np.array([1, .424, .184])
REF = np.stack([PAPER, PAPER * A, PAPER * B, PAPER * A * B]) * 255; NAMES = ['紙', '青', '橙', '青緑']
def share(path):
    im = np.asarray(Image.open(path).convert('RGB')).astype(np.float32)
    d = ((im[:, :, None, :] - REF[None, None]) ** 2).sum(-1).argmin(-1)
    return [float((d == i).mean()) for i in range(4)]
if __name__ == '__main__':
    for f in sys.argv[1:]:
        s = share(f); print(f.split('/')[-1], ' '.join(f'{n} {v * 100:.0f}%' for n, v in zip(NAMES, s)))

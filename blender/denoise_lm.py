import paths as P   # all paths: paths.env
import sys, os
import bpy, numpy as np
from scipy import ndimage
path = sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else f'{P.RULES}/assets/lightmap.exr'
im=bpy.data.images.load(path); W,H=im.size
a=np.array(im.pixels[:],dtype=np.float32).reshape(H,W,4)
rgb=a[...,:3]; m=(rgb.sum(-1)>0).astype(np.float32)
rgb=np.minimum(rgb, np.percentile(rgb[m>0],99.9))
ids_path = os.environ.get('LM_IDS', '')
if ids_path and os.path.exists(ids_path) and np.load(ids_path, mmap_mode='r').shape == (H, W):
    # 試作81: the islands are packed a texel apart now, so a plain blur mixed each island with its neighbours (a dark
    # prop's island spotted the wall next to it). Smooth inside each island only: repeated 3x3 averaging among the
    # texels of the same island (LM_ITER passes, about a gaussian of sigma sqrt(2/3 * n)); the gaps take the nearest
    # island's colour after, as the bake margin did
    ids=np.load(ids_path)
    n=int(os.environ.get('LM_ITER', '10'))
    v=rgb.copy(); inside=ids>0
    sh=[(dy,dx) for dy in (-1,0,1) for dx in (-1,0,1)]
    same={}
    for dy,dx in sh:
        nb=np.roll(np.roll(ids,dy,0),dx,1); same[(dy,dx)]=((nb==ids)&inside).astype(np.float32)
    for _ in range(n):
        acc=np.zeros_like(v); w=np.zeros(ids.shape,np.float32)
        for dy,dx in sh:
            s=same[(dy,dx)]; acc+=np.roll(np.roll(v,dy,0),dx,1)*s[...,None]; w+=s
        v=np.where(inside[...,None], acc/np.maximum(w,1e-6)[...,None], v)
    # gaps: nearest inside texel
    idx=ndimage.distance_transform_edt(~inside, return_distances=False, return_indices=True)
    out=v[idx[0],idx[1]]
    print('denoised by island', n)
else:
    out=np.zeros_like(rgb); den=ndimage.gaussian_filter(m,2.5)+1e-6
    for c in range(3): out[...,c]=ndimage.gaussian_filter(rgb[...,c]*m,2.5)/den
    out*=m[...,None]>0
    print('denoised')
a[...,:3]=out
im.pixels.foreach_set(a.ravel()); im.filepath_raw=path; im.file_format='OPEN_EXR'; im.save()

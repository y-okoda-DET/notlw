import paths as P   # all paths: paths.env
import sys
import bpy, numpy as np
from scipy import ndimage
im=bpy.data.images.load((sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else f'{P.RULES}/assets/lightmap.exr')); W,H=im.size
a=np.array(im.pixels[:],dtype=np.float32).reshape(H,W,4)
rgb=a[...,:3]; m=(rgb.sum(-1)>0).astype(np.float32)
rgb=np.minimum(rgb, np.percentile(rgb[m>0],99.9))
out=np.zeros_like(rgb); den=ndimage.gaussian_filter(m,2.5)+1e-6
for c in range(3): out[...,c]=ndimage.gaussian_filter(rgb[...,c]*m,2.5)/den
out*=m[...,None]>0
a[...,:3]=out
im.pixels.foreach_set(a.ravel()); im.filepath_raw=(sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else f'{P.RULES}/assets/lightmap.exr'); im.file_format='OPEN_EXR'; im.save()
print('denoised')

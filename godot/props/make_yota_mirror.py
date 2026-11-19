"""車の窓に映る陽太の顔（第7章）。yota_mirror.png（ユーザーの画像 E の切り抜き）から、映り込みに見える2枚を作る。
切り抜きをそのまま置くとシールに見えた（ユーザー 2026-11-19「これは仮？」）：輪郭をぼかし、明るさと色を抑え、
頭と肩の影（外の光を体がさえぎる所）は別の一枚で大きくやわらかく。
  yota_mirror_soft.png   顔。少しぼかし、白を抑え、ガラスの青緑に寄せ、縁を溶かす
  yota_mirror_shade.png  影。切り抜きの形を大きくぼかした黒
Run: python3 make_yota_mirror.py"""
from PIL import Image, ImageFilter, ImageEnhance, ImageChops
import os
D = os.path.dirname(os.path.abspath(__file__))
src = Image.open(f'{D}/yota_mirror.png').convert('RGBA')
W = src.size[0]
rgb = src.convert('RGB'); a = src.split()[3]
rgb = rgb.filter(ImageFilter.GaussianBlur(W / 768 * 2.2))
rgb = ImageEnhance.Color(rgb).enhance(.55)
rgb = ImageEnhance.Contrast(rgb).enhance(.8)
rgb = ImageEnhance.Brightness(rgb).enhance(.72)
rgb = Image.blend(rgb, Image.new('RGB', rgb.size, (70, 96, 104)), .22)   # the glass's own colour
# the edge melts: the alpha eroded a little, then blurred wide; and the bottom (the chest) fades out
a2 = a.filter(ImageFilter.MinFilter(9)).filter(ImageFilter.GaussianBlur(W / 768 * 16))
fade = Image.linear_gradient('L').resize(src.size).point(lambda v: 255 if v < 120 else max(0, int(255 - (v - 120) * 255 / 70)))
a2 = ImageChops.multiply(a2, fade)
out = rgb.convert('RGBA'); out.putalpha(a2); out.save(f'{D}/yota_mirror_soft.png')
sh = Image.new('RGBA', src.size, (0, 0, 0, 0))
sa = a.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(W / 768 * 48))
sh.putalpha(ImageChops.multiply(sa, fade)); sh.save(f'{D}/yota_mirror_shade.png')
print('made', out.size)

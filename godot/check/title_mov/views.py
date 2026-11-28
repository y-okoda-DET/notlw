# タイトル画面の背景の候補を撮る（house_shots.py の外の画に、候補の位置を足す）
import sys, os
sys.path.insert(0, '/home/user/notlw/godot'); os.chdir('/home/user/notlw/godot')
import house_shots as H
H.OUTV = H._out_views()
H.OUTV.update({
 'o_t14':  ((4.5, 21.3, -1.68), (0.4, 5.0, 2.6), ''),
 'o_t18':  ((6.07, 24.96, -2.32), (0.4, 5.0, 2.8), ''),
 'o_t18l': ((3.6, 25.5, -2.4), (0.4, 5.0, 2.8), ''),
 'o_t22':  ((7.65, 28.6, -3.0), (0.6, 5.0, 3.0), ''),
 'o_side': ((-9.0, 16.0, -1.0), (0.4, 4.0, 2.4), ''),
 'o_low':  ((5.0, 20.0, -2.6), (0.4, 5.0, 3.6), ''),
})
sys.argv = ['x', sys.argv[1], sys.argv[2]]
H.main()

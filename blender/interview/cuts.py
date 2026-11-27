# 証言 一〜三のカット（カメラの位置・向き・レンズ・長さ・切り替え）。seq.py（Blender の下見）と export_interview.py（ゲームへ）が読む。
# 1コマ＝1/12秒（刷りの 12 コマと同じ）。hold は止まったコマを何コマ伸ばすか。hide は映さない組（people＝聞き手、mio＝澪）。
# post：slip＝橙の版だけ大きくずれる、flat＝平たくなる（光と影を抜いて物の色だけ＋立ち絵と書き起こしの窓。前の slip から溶かす）
import json, math, os
HERE = os.path.dirname(os.path.abspath(__file__))
FPS = 12
def ease(t): return t * t * (3 - 2 * t)
def lerp(p, q, t): return [x + (y - x) * t for x, y in zip(p, q)] if isinstance(p, list) else p + (q - p) * t
def seg(n, A, Bk, e=ease, **kw):
    return [dict({k: lerp(A[k], Bk[k], e(i / max(n - 1, 1))) for k in A}, **kw) for i in range(n)]
def still(sec, **f): return [dict(f, hold=round(sec * FPS))]
CAMS = json.load(open(os.path.join(HERE, 'cameras.json')))
def cam(name, sec, **over):
    c = dict(CAMS[name]); c.update(over); return still(sec, loc=c['loc'], at=c['at'], lens=c['lens'], shift_y=c.get('shift_y', 0.0), hide=tuple(c.get('hide', ())))
TAPE = [-0.10, 0.43, 0.35]; REC = [-0.057, 0.029, 0.364]; FIST = [-0.09, -0.47, 0.33]; TEA_I = [0.58, 0.28, 0.38]
SHOTS = {
 # 証言 二（決まった形）：聞き手の顎で切った正面 → 長い問いの間 T1 ゆっくり寄る → 澪の正面
 # 試作297（赤字 #25「この2枚、ちょっと絵に工夫が無い。カメラに角度つける？…ゴダール的にしてみるとか？」）：正面・真ん中をやめる。
 # 聞き手を斜め前から、画の左の端に寄せ（体の半分は枠の外）、右の三分の二は障子の白い余白（字幕はそこに乗る）。顔は今までどおり
 # 顎で切って見せない。長い問いの間は、ゆっくり寄る代わりに、同じ向きのまま3回ぶつ切りに寄る（ゴダールのジャンプカット）
 'a_聞き手_顎': still(1.5, loc=[0.42, 0.05, 0.62], at=[0.267, 1.038, 0.55], lens=40.0, shift_y=0.0, hide=('mio',)),
 'b_T1_寄る': (still(1.3, loc=[0.40, 0.14, 0.62], at=[0.25, 1.12, 0.56], lens=50.0, shift_y=0.0, hide=('mio',)) +
              still(1.3, loc=[0.37, 0.22, 0.63], at=[0.23, 1.20, 0.58], lens=62.0, shift_y=0.0, hide=('mio',)) +
              still(1.4, loc=[0.34, 0.30, 0.64], at=[0.21, 1.28, 0.60], lens=80.0, shift_y=0.0, hide=('mio',))),
 'c_澪_正面': cam('k4_澪_口元', 1.5),
 # やり取りを N3 振り が運ぶ：机の真ん中から 澪→聞き手 へ一気に振って、相手の正面で止まる
 'd_N3_振り': (still(0.8, loc=[0, 0.10, 0.56], at=[0, -0.72, 0.56], lens=32.0, shift_y=0.0, hide=()) +
              [dict(loc=[0, 0.10, 0.56], at=[0.82 * math.sin(math.radians(180 * ease((i + 1) / 5))), 0.10 - 0.82 * math.cos(math.radians(180 * ease((i + 1) / 5))), 0.56], lens=32.0, shift_y=0.0, hide=(), blur=[60, 140, 160, 120, 40][i]) for i in range(5)] +
              still(1.2, loc=[0, 0.10, 0.56], at=[0, 0.92, 0.56], lens=32.0, shift_y=0.0, hide=())),
 # N5 二焦点：手前のテープと奥の澪の両方にピント（2枚を描いて継ぐ）
 'e_N5_二焦点': [dict(loc=[-0.08, 0.58, 0.40], at=[-0.02, -0.72, 0.42], lens=24.0, shift_y=-0.10, hide=('people',), dof=0.17, fstop=2.8, n5='near'),
               dict(loc=[-0.08, 0.58, 0.40], at=[-0.02, -0.72, 0.42], lens=24.0, shift_y=-0.10, hide=('people',), dof=1.25, fstop=1.2, n5='far', hold=round(2.0 * FPS))],
 # 答えを組む間：手元の画。カメラは止める
 'f_手元_止める': cam('k5_手元', 2.5),
 # 決定の音の直前：T5 極端な寄りのぶつ切り（お茶の面、ラベルの指、録音機の秒、澪の拳）
 'g_T5_寄り': (seg(6, dict(loc=[0.58, 0.12, 0.52], at=TEA_I, lens=70.0, shift_y=0.0), dict(loc=[0.58, 0.14, 0.50], at=TEA_I, lens=120.0, shift_y=0.0), e=lambda t: t ** 0.4, hide=('mio',)) +
              seg(6, dict(loc=[-0.20, 0.20, 0.48], at=[-0.10, 0.42, 0.355], lens=70.0, shift_y=0.0), dict(loc=[-0.19, 0.22, 0.47], at=[-0.10, 0.42, 0.355], lens=120.0, shift_y=0.0), e=lambda t: t ** 0.4, hide=('mio',)) +
              seg(6, dict(loc=[-0.04, 0.16, 0.43], at=REC, lens=60.0, shift_y=0.0), dict(loc=[-0.04, 0.16, 0.43], at=REC, lens=120.0, shift_y=0.0), e=lambda t: t ** 0.4, hide=('mio',)) +
              seg(6, dict(loc=[-0.42, -0.30, 0.25], at=FIST, lens=50.0, shift_y=0.0), dict(loc=[-0.40, -0.31, 0.25], at=FIST, lens=95.0, shift_y=0.0), e=lambda t: t ** 0.4, hide=('people',))),
 # 決定の瞬間：T2 真上。机を盤のように見下ろして少し回る
 'h_T2_真上': seg(30, dict(loc=[0, 0.10, 2.05], at=[0, 0.1001, 0.0], lens=30.0, shift_y=0.0, roll=-8.0), dict(loc=[0, 0.10, 1.85], at=[0, 0.1001, 0.0], lens=30.0, shift_y=0.0, roll=14.0), hide=()),
 # 動いたあとは必ず相手の正面に返す
 'i_聞き手_顎': cam('k3b_聞き手_顎', 2.0),
 # 証言 一：カメラは一度も動かさない（小津の切り返し）。頭に一度だけ N2 ハネケの高い隅の長回し。動くのは障子の葉の影だけ
 'j_N2_長回し': [dict(loc=[1.72, 0.10, 2.15], at=[-0.40, 0.10, 0.45], lens=24.0, shift_y=0.0, hide=(), sway=i / 24, hold=3) for i in range(24)],
 'k_空_床の間': cam('k1_空_床の間', 2.0),
 'l_引き_柱で割る': cam('k2_引き_柱で割る', 2.5),
 'm_聞き手_胸': cam('k3a_聞き手_胸', 2.0),
 'n_澪_正面': cam('k4_澪_口元', 2.0),
 'o_手元_止める': cam('k5_手元', 2.5),
 'p_聞き手_胸': cam('k3a_聞き手_胸', 1.5),
 # 証言 三：口元で切った正面 → T4 回り込みが速まって止まらない → 一語が滑る：N1 めまい（下がりながら寄せる。聞き手の大きさはそのまま、障子が迫る）
 #          → 橙の版だけが大きくずれる1コマ → 陰影が抜けて平たくなり、口元の上に顔（立ち絵）が出る
 'q_聞き手_口元': cam('k3c_聞き手_口元', 1.5),
 'r_T4_回り込み': [dict(loc=[0.0 + 1.30 * math.sin(math.radians(20 + 450 * (i / 59) ** 1.5)), 0.10 - 1.30 * math.cos(math.radians(20 + 450 * (i / 59) ** 1.5)), 0.50],
                   at=[0, 0.10, 0.50], lens=40.0, shift_y=-0.12, hide=(), blur=int(0.14 * 38 * 675 * (i / 59) ** 0.5 / 59)) for i in range(60)],
 's_N1_めまい': [dict(loc=[0, 0.10 - 0.60 * ease(i / 29), 0.50], at=[0, 0.92, 0.50], lens=50.0 * (0.75 + 0.60 * ease(i / 29)) / 1.35, shift_y=0.124, hide=('mio',)) for i in range(30)],
 't_版ずれ': [dict(loc=[0, -0.50, 0.50], at=[0, 0.92, 0.50], lens=50.0, shift_y=0.124, hide=('mio',), post='slip', hold=3)],
 'u_平たくなる': [dict(loc=[0, -0.50, 0.50], at=[0, 0.92, 0.50], lens=50.0, shift_y=0.124, hide=('mio', 'people'), flat=True, post='flat', hold=round(3.5 * FPS))],
}
ORDER = {
    '証言一': ['j_N2_長回し', 'k_空_床の間', 'l_引き_柱で割る', 'm_聞き手_胸', 'n_澪_正面', 'o_手元_止める', 'p_聞き手_胸'],
    '証言二': ['a_聞き手_顎', 'b_T1_寄る', 'c_澪_正面', 'd_N3_振り', 'e_N5_二焦点', 'f_手元_止める', 'g_T5_寄り', 'h_T2_真上', 'i_聞き手_顎'],
    '証言三': ['q_聞き手_口元', 'r_T4_回り込み', 's_N1_めまい', 't_版ずれ', 'u_平たくなる'],
}

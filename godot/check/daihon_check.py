"""台本（godot/story/*.txt）とスクリプトの食い違いを探す：python3 godot/check/daihon_check.py
- スクリプトが呼ぶ名前（B("…")、D.lines("…")、D.has("…")）が、台本に全部あるか
- 台本にあって、どこからも呼ばれない名前（消し忘れ・書き間違い）
- 書式：話者の名前が知らない名前でないか、＞ の動きが story.gd の _do か door.gd にあるか、選択肢に返事があるか"""
import glob, os, re, sys
G = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WHO = {'澪', '桐生', '夏希', '真琴', '大河', 'ラジオ'}
blocks, bad = {}, []
for p in sorted(glob.glob(G + '/story/*.txt')):
    key = None
    for n, raw in enumerate(open(p, encoding='utf-8'), 1):
        s = raw.strip()
        if not s or s.startswith('//'): continue
        m = re.match(r'^【(.+)】$', s)
        if m:
            key = m.group(1)
            if key in blocks: bad.append(f'{os.path.basename(p)}:{n} 【{key}】が2つある')
            blocks[key] = []; continue
        if key is None: bad.append(f'{os.path.basename(p)}:{n} 【】の前に行がある'); continue
        blocks[key].append((os.path.basename(p), n, raw.rstrip('\n')))
src = ''.join(open(p, encoding='utf-8').read() for p in glob.glob(G + '/scripts/*.gd') if not os.path.basename(p).startswith('dbg'))
called = set()
for m in re.finditer(r'\b(?:B|D\.lines|D\.has|D\.entries|_flow)\(([^\n]*)', src):
    called |= set(re.findall(r'"([^"]+)"', m.group(1).split(')')[0] if '[' not in m.group(1) else m.group(1)))
called = {c for c in called if re.search(r'[　-ヿ一-鿿]', c) and '.' in c}
names = set(blocks)
for c in sorted(called):
    if '%d' in c:
        if not any(re.fullmatch(c.replace('.', r'\.').replace('%d', r'\d+'), k) for k in names): bad.append(f'スクリプトが呼ぶ【{c}】が台本にない')
    elif c not in names: bad.append(f'スクリプトが呼ぶ【{c}】が台本にない')
for k in sorted(names):
    if k not in called and not any('%d' in c and re.fullmatch(c.replace('.', r'\.').replace('%d', r'\d+'), k) for c in called): bad.append(f'台本の【{k}】はどこからも呼ばれていない')
dos = {w for ln in re.findall(r'^\t\t("\w+"(?:, "\w+")*):', src, re.M) for w in re.findall(r'\w+', ln)} | {'silence', 'leave', 'end'}
for k, ls in blocks.items():
    for i, (f, n, raw) in enumerate(ls):
        s = raw.strip(); s = re.sub(r'^\d+(\.\d+)?\s+', '', s)
        if s.startswith('＞'):
            if s[1:].strip() not in dos: bad.append(f'{f}:{n} ＞{s[1:].strip()} という動きは story.gd にない')
        elif s.startswith('？'):
            nxt = ls[i + 1][2] if i + 1 < len(ls) else ''
            if not nxt[:1] in (' ', '\t', '　'): bad.append(f'{f}:{n} 選択肢「{s[1:]}」に返事（字下げした行）がない')
        elif not s.startswith(('［', '（')) and '：' in s:
            who = s.split('：', 1)[0].rstrip('＊').split('→')[0]
            if who not in WHO: bad.append(f'{f}:{n} 知らない名前「{who}」')
for b in bad: print('×', b)
print(f'台本 {len(names)} かたまり、スクリプトが呼ぶ名前 {len(called)}：' + ('○' if not bad else f'× {len(bad)} 件'))
sys.exit(1 if bad else 0)

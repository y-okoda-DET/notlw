#!/usr/bin/env python3
# シナリオの決定が台本に入っているかを確かめる。表は docs/シナリオの点検表.md。
import sys, os, re
here = os.path.dirname(os.path.abspath(__file__))
story = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, '..', 'godot', 'story')
rows = []
for l in open(os.path.join(here, 'シナリオの点検表.md'), encoding='utf-8'):
    c = [x.strip() for x in l.strip().strip('|').split('|')]
    if len(c) == 5 and c[0].isdigit():
        rows.append(c)
def body(name):
    p = os.path.join(story, name)
    if not os.path.exists(p):
        return None
    # 注釈（// の行）は台本の中身ではない
    return [x.rstrip('\n') for x in open(p, encoding='utf-8') if not x.lstrip().startswith('//')]
bad = 0
for n, f, kind, s, why in rows:
    if kind == '未':
        print(f'未 {n} {f} {why}'); continue
    b = body(f)
    if b is None:
        print(f'× {n} {f} ファイルが無い'); bad += 1; continue
    hit = [x for x in b if s in x]
    ok = (not hit) if kind == '無い' else bool(hit)
    bad += not ok
    extra = '' if ok else ('　残っている行：' + hit[0].strip() if hit else '　入っていない')
    print(f"{'○' if ok else '×'} {n} {f} 「{s}」が{kind}（{why}）{extra}")
for f in ['ch2_20.txt', 'ch2_21.txt', 'ch2_23.txt', 'ch4.txt', 'ch11.txt']:
    b = body(f)
    if b is None: continue
    block, count = '', {}
    for x in b:
        m = re.match(r'【(.+?)】', x)
        if m: block = m.group(1); continue
        if '『' not in x or block.startswith('発電機.テープ'): continue
        sp = re.sub(r'^[\d.]+\s*', '', x.strip())
        who = re.split('[：:]', sp)[0] if re.search('[：:]', sp) else ''
        if not who.startswith('桐生'):
            print(f'× 題名 {f}【{block}】桐生以外の行に題名：{x.strip()}'); bad += 1
        else:
            count[block] = count.get(block, 0) + 1
    for k, v in count.items():
        if v > 1:
            print(f'× 題名 {f}【{k}】一場面に題名が{v}つ'); bad += 1
print('全部 ○' if not bad else f'× が {bad} 個')
sys.exit(1 if bad else 0)

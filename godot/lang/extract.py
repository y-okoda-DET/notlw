"""Collect every Japanese string in the scripts into lang/text.csv (run from anywhere; keeps translations already in it).
keys = the Japanese as written in the scripts. Add a column per language (en, zh_CN, ...) and fill it; an empty cell
falls back to the Japanese. The ja column is the key with U+200B between phrases (BudouX), for line breaking (the column is left out of the import until it is filled: see NOTES.md「画面の文章と言語」).
Notes for translators: # in a radio line is where the place name drops out (keep it); %s is a number or a name."""
import csv, glob, os, re
import budoux   # pip install budoux (Apache-2.0; only here, not shipped): marks the phrase breaks in the ja column
ZW = "\u200b"
BP = budoux.load_default_japanese_parser()
NOBREAK = ['間に合', '目盛り', 'ちょい右', 'ちょい左', '切り替え', 'かぶった', '手のひら', '置いときます', '四分の一']   # BudouX splits these; never break inside them

def phrases(k):
    out = ZW.join(BP.parse(k))
    for w in NOBREAK:
        for i in range(1, len(w)): out = out.replace(w[:i] + ZW + w[i:], w)
    return out
G = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = G + '/lang/text.csv'
JP = re.compile(r'[　-ヿ一-鿿＀-￯]')
keys = []
NAMES = set()   # the blocks' names in story/*.txt (【…】): story.gd asks for them by name, they are not words on screen
for p in glob.glob(G + '/story/*.txt'):
    NAMES |= set(re.findall(r'^【(.+)】\s*$', open(p, encoding='utf-8').read(), re.M))
for p in sorted(glob.glob(G + '/scripts/*.gd')):
    if os.path.basename(p).startswith('dbg') or os.path.basename(p) == 'daihon.gd': continue
    for line in open(p, encoding='utf-8'):
        code = line.split('#', 1)[0] if '"' not in line else line
        for s in re.findall(r'"((?:[^"\\]|\\.)*)"', code):
            if JP.search(s) and s not in keys and s not in NAMES and s.replace('%d', '1') not in NAMES: keys.append(s)
# the chapter files (story/*.txt, 書式は story/README.md): the words after 名前：, a choice after ？, a note, a plain line
for p in sorted(glob.glob(G + '/story/*.txt')):
    for line in open(p, encoding='utf-8'):
        s = line.strip()
        if not s or s.startswith('//') or s.startswith('【') or s.startswith('＞'): continue
        m = re.match(r'^\d+(\.\d+)?\s+(.*)$', s)
        if m: s = m.group(2)
        if s.startswith('＞'): continue
        if s.startswith('？'): s = s[1:].strip()
        elif not (s.startswith('［') or s.startswith('（')) and '：' in s:
            who, s = s.split('：', 1)
            who = who.rstrip('＊').split('→')[0]
            if who not in keys: keys.append(who)
        if JP.search(s) and s not in keys: keys.append(s)
cols, old = ['keys', 'ja'], {}
if os.path.exists(OUT):
    with open(OUT, encoding='utf-8', newline='') as f:
        r = csv.reader(f); cols = next(r)
        for row in r: old[row[0]] = row
with open(OUT, 'w', encoding='utf-8', newline='') as f:
    w = csv.writer(f, quoting=csv.QUOTE_ALL); w.writerow(cols)
    for k in keys:
        row = old.get(k, [k, k] + [''] * (len(cols) - 2))
        # the game breaks lines only at these (story.gd wrap_text). A line already in the table keeps its breaks (another
        # BudouX version breaks some of them differently, and worse: は|ーい、屋内にと|どまり); REBREAK=1 does them all again
        if k not in old or os.environ.get('REBREAK'): row[1] = phrases(k) if not k.startswith("［") else k
        w.writerow(row + [''] * (len(cols) - len(row)))
print('lang/text.csv:', len(keys), 'lines,', 'columns', cols)

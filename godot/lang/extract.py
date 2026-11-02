"""Collect every Japanese string in the scripts into lang/text.csv (run from anywhere; keeps translations already in it).
keys = the Japanese as written in the scripts. Add a column per language (en, zh_CN, ...) and fill it; an empty cell
falls back to the Japanese. The ja column is the key with U+200B between phrases (BudouX), for line breaking (the column is left out of the import until it is filled: see NOTES.md「画面の文章と言語」).
Notes for translators: # in a radio line is where the place name drops out (keep it); %s is a number or a name."""
import csv, glob, os, re
import budoux   # pip install budoux (Apache-2.0; only here, not shipped): marks the phrase breaks in the ja column
ZW = "\u200b"
BP = budoux.load_default_japanese_parser()
G = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = G + '/lang/text.csv'
JP = re.compile(r'[　-ヿ一-鿿＀-￯]')
keys = []
for p in sorted(glob.glob(G + '/scripts/*.gd')):
    if os.path.basename(p).startswith('dbg'): continue
    for line in open(p, encoding='utf-8'):
        code = line.split('#', 1)[0] if '"' not in line else line
        for s in re.findall(r'"((?:[^"\\]|\\.)*)"', code):
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
        row[1] = ZW.join(BP.parse(k)) if not k.startswith("［") else k   # the game breaks lines only at these (story.gd wrap_text)
        w.writerow(row + [''] * (len(cols) - len(row)))
print('lang/text.csv:', len(keys), 'lines,', 'columns', cols)

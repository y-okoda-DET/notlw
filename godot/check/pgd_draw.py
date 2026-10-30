import json
from PIL import Image, ImageDraw
d=json.load(open('/home/claude/work/pgd.json')); W=500
cols={'index':'red','middle':'orange','ring':'green','pinky':'purple','thumb':'cyan'}
o=Image.new('RGB',(W*3,W))
for i,nm in enumerate(['screen','back','eye']):
    im=Image.open(f'/home/claude/work/pgd_{nm}.png').convert('RGB'); dr=ImageDraw.Draw(im)
    P=lambda q:(q[0]*W,(1-q[1])*W)
    cs=[P(q) for q in d[nm]['corners']]; dr.polygon(cs,outline='blue',width=3)
    t=P(d[nm]['top'][0]); dr.ellipse((t[0]-6,t[1]-6,t[0]+6,t[1]+6),fill='blue')
    for f,cl in cols.items():
        ps=[P(q) for q in d[nm][f]]; dr.line(ps,fill=cl,width=3)
        dr.ellipse((ps[-1][0]-4,ps[-1][1]-4,ps[-1][0]+4,ps[-1][1]+4),fill=cl)
    dr.text((5,5),nm,fill='white'); o.paste(im,(i*W,0))
o.save('/home/claude/work/pgd.png')

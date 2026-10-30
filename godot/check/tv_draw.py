import json
from PIL import Image, ImageDraw
d=json.load(open('/home/claude/work/tv.json')); W,Hh=450,600
o=Image.new('RGB',(W*2,Hh))
for i,nm in enumerate(['side','back']):
    im=Image.open(f'/home/claude/work/tv_{nm}.png').convert('RGB'); dr=ImageDraw.Draw(im)
    P=lambda q:(q[0]*W,(1-q[1])*Hh)
    for s,cl in (('l','red'),('r','cyan')):
        ps=[P(q) for q in d[nm][s]]; dr.line(ps,fill=cl,width=3)
        for p in ps: dr.ellipse((p[0]-4,p[1]-4,p[0]+4,p[1]+4),fill=cl)
    dr.line([P(q) for q in d[nm]['door']],fill='yellow',width=2)
    o.paste(im,(i*W,0))
o.save('/home/claude/work/tv.png')

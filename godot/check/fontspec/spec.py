# Font specimens at true pixel size (PIL mock, not from the pck)
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import random, sys
F='/home/user/work/fonts/'; NOTO='/home/user/notlw/godot/fonts/SerifJP-Bold.otf'
B1=F+'shipporiminchob1_ShipporiMinchoB1-Bold.ttf'; B1S=F+'shipporiminchob1_ShipporiMinchoB1-SemiBold.ttf'
DOT=F+'dotgothic16_DotGothic16-Regular.ttf'
OUT='/home/user/work/fontcheck/'; SRC='/mnt/project-files/段階1/'
BG=(18,42,34); INK=(236,230,214); GH=(41,110,171)
def card(font):
    im=Image.new('RGB',(1920,1080),BG); random.seed(1)
    px=im.load()
    for i in range(60000):
        x,y=random.randrange(1920),random.randrange(1080); c=px[x,y]; d=random.choice((-6,6)); px[x,y]=tuple(max(0,v+d) for v in c)
    d=ImageDraw.Draw(im)
    rows=[('第 一 章',46,40),('「ルール」',150,90),('あの別荘には、どうして行ったんですか？',36,0)]
    tot=sum(r[1]*1.36+r[2] for r in rows); y=540-tot/2
    for t,s,g in rows:
        f=ImageFont.truetype(font,s)
        ov=Image.new('RGBA',im.size,(0,0,0,0)); od=ImageDraw.Draw(ov)
        od.text((960+4,y+3),t,font=f,fill=GH+(51,),anchor='ma'); im.paste(ov,(0,0),ov)
        d.text((960,y),t,font=f,fill=INK,anchor='ma'); y+=s*1.36+g
    return im.crop((0,230,1920,830))
def say(font,bg,y0):
    im=bg.copy(); ov=Image.new('RGBA',im.size,(0,0,0,0)); d=ImageDraw.Draw(ov)
    fs=30; f=ImageFont.truetype(font,fs); fn=ImageFont.truetype(font,22)
    line='澪、ちょうどいい。定点、お願いしていい？'
    w=d.textlength(line,font=f); x=im.width/2-w/2+30; y=y0
    for t,ff,xx in ((line,f,x),('桐生',fn,x-60)):
        d.text((xx+2.5,y+1.5),t,font=ff,fill=(0,84,153,230),stroke_width=5,stroke_fill=(0,66,128,190))
        d.text((xx,y),t,font=ff,fill=INK+(255,),stroke_width=5,stroke_fill=(0,66,128,190))
    im=im.convert('RGBA'); im.alpha_composite(ov); return im.convert('RGB')
def osd(font,bg):
    im=bg.copy(); d=ImageDraw.Draw(im); f=ImageFont.truetype(font,30); f2=ImageFont.truetype(font,24)
    lc=(235,235,224); d.text((40,40),'STBY',font=f,fill=lc); d.text((470,40),'0:00:02',font=f,fill=lc)
    d.text((40,250),'WIDE',font=f2,fill=lc); d.text((150,40),'● REC',font=f,fill=(255,89,38))
    return im
def lab(im,t):
    d=ImageDraw.Draw(im); f=ImageFont.truetype('/home/user/work/fonts/bizudpmincho_BIZUDPMincho-Bold.ttf',26) 
    d.rectangle((0,0,int(d.textlength(t,font=f))+24,44),fill=(250,248,240)); d.text((12,6),t,font=f,fill=(20,20,20)); return im
def stack(a,b,ta,tb,name):
    a=lab(a,ta); b=lab(b,tb); im=Image.new('RGB',(max(a.width,b.width),a.height+b.height+8),(250,248,240))
    im.paste(a,(0,0)); im.paste(b,(0,a.height+8)); im.save(OUT+name); print(name,im.size)
stack(card(NOTO),card(B1),'今：Noto Serif CJK Bold','案：しっぽり明朝 B1 Bold（にじみ入り）','1_章カード_上が今_下が案.png')
sc=Image.open(SRC+'試作35_確認/2_台詞_会話の最初だけ名前.png').convert('RGB').crop((360,760,1560,900))
stack(say(NOTO,sc,50),say(B1S,sc,50),'今：Noto Serif CJK Bold 30px','案：しっぽり明朝 B1 SemiBold 30px','2_台詞_上が今_下が案.png')
vf=Image.open(SRC+'試作26_確認/5_のぞいてコンテと見比べる.png').convert('RGB').crop((700,280,1340,600))
stack(osd(NOTO,vf),osd(DOT,vf),'今：明朝（Noto Serif）','案：ドットゴシック16（カメラの表示だけ）','3_カメラの表示_上が今_下が案.png')

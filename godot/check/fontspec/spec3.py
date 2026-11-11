# Feedback round: chapter card (no brackets / lighter / condensed) and dialogue (size / UD mincho / shadow vs outline / shadow colour)
# PIL mock at true pixel size (1920x1080), not from the pck
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import random
F='/home/user/work/fonts/'; NOTO='/home/user/notlw/godot/fonts/SerifJP-Bold.otf'
B1=lambda w: F+'shipporiminchob1_ShipporiMinchoB1-%s.ttf'%w
UDP=F+'bizudpmincho_BIZUDPMincho-Bold.ttf'; UD=F+'bizudmincho_BIZUDMincho-Bold.ttf'
OUT='/home/user/work/fontcheck/'; SRC='/mnt/project-files/段階1/'
BG=(18,42,34); INK=(236,230,214); GH=(41,110,171)
LF=ImageFont.truetype(UDP,26)
def lab(im,t,sc=1.0):
    d=ImageDraw.Draw(im); f=ImageFont.truetype(UDP,int(26*sc))
    d.rectangle((0,0,int(d.textlength(t,font=f))+24,int(44*sc)),fill=(250,248,240)); d.text((12,int(7*sc)),t,font=f,fill=(20,20,20)); return im
def grid(ims,cols,name,bg=(250,248,240)):
    w=max(i.width for i in ims); h=max(i.height for i in ims); rows=(len(ims)+cols-1)//cols
    g=Image.new('RGB',(cols*w+(cols-1)*8,rows*h+(rows-1)*8),bg)
    for k,i in enumerate(ims): g.paste(i,((k%cols)*(w+8),(k//cols)*(h+8)))
    g.save(OUT+name); print(name,g.size)
def tracked(text,font,size,track=0.0,squeeze=1.0,fill=INK+(255,)):
    """text as an RGBA strip, letter-spaced by track em, then squeezed horizontally (長体)"""
    f=ImageFont.truetype(font,size); d0=ImageDraw.Draw(Image.new('RGBA',(8,8)))
    ws=[d0.textlength(c,font=f) for c in text]; W=int(sum(ws)+track*size*(len(text)-1))+8; H=int(size*1.5)
    im=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(im); x=4
    for c,w in zip(text,ws): d.text((x,int(size*0.1)),c,font=f,fill=fill); x+=w+track*size
    if squeeze!=1.0: im=im.resize((max(1,int(W*squeeze)),H),Image.LANCZOS)
    return im
def card(rows):
    """rows: (text, font, size, gap, track, squeeze)"""
    im=Image.new('RGB',(1920,1080),BG); random.seed(1); px=im.load()
    for i in range(60000):
        x,y=random.randrange(1920),random.randrange(1080); c=px[x,y]; dd=random.choice((-6,6)); px[x,y]=tuple(max(0,v+dd) for v in c)
    tot=sum(r[2]*1.36+r[3] for r in rows); y=540-tot/2
    for t,font,s,g,tr,sq in rows:
        gh=tracked(t,font,s,tr,sq,GH+(51,)); tx=tracked(t,font,s,tr,sq)
        x=960-tx.width//2; im.paste(gh,(x+4,int(y)+3),gh); im.paste(tx,(x,int(y)),tx); y+=s*1.36+g
    return im.crop((0,230,1920,830))
Q='あの別荘には、どうして行ったんですか？'
def c(title,fbig,fsmall,tr=0.0,sq=1.0,ch='第 一 章'):
    return card([(ch,fsmall,46,40,0,1.0),(title,fbig,150,90,tr,sq),(Q,fsmall,36,0,0.02 if tr else 0,1.0)])
cards=[('1 今：Noto Serif Bold・括弧あり',c('「ルール」',NOTO,NOTO)),
       ('2 前回の案：しっぽり明朝B1 Bold・括弧あり',c('「ルール」',B1('Bold'),B1('SemiBold'))),
       ('3 括弧なし（B1 Bold）',c('ルール',B1('Bold'),B1('SemiBold'),0.10)),
       ('4 括弧なし＋細く（B1 Medium）',c('ルール',B1('Medium'),B1('Medium'),0.10)),
       ('5 括弧なし＋細く＋長体85%（小さい字は SemiBold）',c('ルール',B1('Medium'),B1('SemiBold'),0.16,0.85)),
       ('6 括弧なし＋細く＋長体75%（小さい字は SemiBold）',c('ルール',B1('Medium'),B1('SemiBold'),0.22,0.75)),
       ('7 括弧なし＋もっと細く（B1 Regular）＋長体85%',c('ルール',B1('Regular'),B1('Regular'),0.16,0.85)),
       ('8 第二章でも確かめる：5と同じ組み方',card([('第 二 章',B1('SemiBold'),46,40,0,1.0),('籠城',B1('Medium'),150,90,0.16,0.85),('最初に、おかしいと思ったのは、いつですか？',B1('SemiBold'),36,0,0.02,1.0)]))]
grid([lab(im.resize((960,300),Image.LANCZOS),t) for t,im in cards],2,'比較4_章カード_括弧なし・細く・長体_半分の大きさ.png')
grid([lab(cards[0][1],'今：Noto Serif Bold・括弧あり'),lab(cards[4][1],'案：しっぽり明朝B1 Medium・括弧なし・長体85%（小さい字は SemiBold）'),lab(cards[7][1],'案（第二章）')],1,'比較5_章カード_今と案_実寸.png')

BLUE=(0,84,153); NAVY=(6,22,40)
def say(bg,font,fs,style,col,line='澪、ちょうどいい。定点、お願いしていい？',name='桐生',cy=None,strength=3):
    im=bg.convert('RGBA'); f=ImageFont.truetype(font,fs); fn=ImageFont.truetype(font,int(fs*0.73))
    d0=ImageDraw.Draw(im); w=d0.textlength(line,font=f); x=im.width/2-w/2+fs; y=(im.height/2-fs*0.7) if cy is None else cy
    items=((line,f,x,y),(name,fn,x-fs*2.0,y+fs*0.22))
    if style=='fukuro':   # what the game does now: outline 5 + offset shadow
        ov=Image.new('RGBA',im.size,(0,0,0,0)); d=ImageDraw.Draw(ov)
        for t,ff,xx,yy in items:
            d.text((xx+2.5,yy+1.5),t,font=ff,fill=(0,84,153,230),stroke_width=5,stroke_fill=(0,66,128,190))
            d.text((xx,yy),t,font=ff,fill=INK+(255,),stroke_width=5,stroke_fill=(0,66,128,190))
        im.alpha_composite(ov)
    else:                 # soft drop shadow, no outline
        sh=Image.new('RGBA',im.size,(0,0,0,0)); d=ImageDraw.Draw(sh)
        for t,ff,xx,yy in items: d.text((xx+2,yy+3),t,font=ff,fill=col+(255,),stroke_width=2,stroke_fill=col+(255,))
        sh=sh.filter(ImageFilter.GaussianBlur(fs*0.16))
        for k in range(strength): im.alpha_composite(sh)
        ov=Image.new('RGBA',im.size,(0,0,0,0)); d=ImageDraw.Draw(ov)
        for t,ff,xx,yy in items: d.text((xx,yy),t,font=ff,fill=INK+(255,))
        im.alpha_composite(ov)
    return im.convert('RGB')
fr=Image.open(SRC+'試作43_確認/1_居間_廊下の扉から.png').convert('RGB')
st=fr.crop((260,400,1720,530))     # dark wall / paper-white screen / wall: the worst case for type
rows=[('a 今：Noto Bold 30px・袋文字（青）',NOTO,30,'fukuro',BLUE),
      ('b 大きさだけ 46px・袋文字（青）',NOTO,46,'fukuro',BLUE),
      ('c 46px・袋文字をやめてシャドウ（今の青）',NOTO,46,'shadow',BLUE),
      ('d 46px・シャドウ（黒に近い青）',NOTO,46,'shadow',NAVY),
      ('e しっぽり明朝B1 SemiBold 46px・シャドウ（黒に近い青）',B1('SemiBold'),46,'shadow',NAVY),
      ('f しっぽり明朝B1 Bold 46px・シャドウ（黒に近い青）',B1('Bold'),46,'shadow',NAVY),
      ('g BIZ UDP明朝 Bold 46px・シャドウ（黒に近い青）',UDP,46,'shadow',NAVY),
      ('h BIZ UD明朝 Bold（字幅そろえ）46px・シャドウ（黒に近い青）',UD,46,'shadow',NAVY)]
grid([lab(say(st,f,fs,sty,col,cy=62),t,0.8) for t,f,fs,sty,col in rows],1,'比較6_台詞_白い所にかかったとき_実寸.png')
dk=Image.open(SRC+'試作35_確認/2_台詞_会話の最初だけ名前.png').convert('RGB').crop((230,770,1690,900))
grid([lab(say(dk,f,fs,sty,col,cy=62),t,0.8) for t,f,fs,sty,col in rows],1,'比較7_台詞_暗い所_実寸.png')
import sys
PICK=sys.argv[1] if len(sys.argv)>1 else 'f'
r={x[0][0]:x for x in rows}; a=r['a']; p=r[PICK]
full=[lab(say(fr,a[1],a[2],a[3],a[4],cy=975),'今：30px・袋文字'),lab(say(fr,p[1],p[2],p[3],p[4],cy=962),'案：'+p[0][2:])]
grid(full,1,'比較8_台詞_画面全体_上が今_下が案.png')
# sizes of the pick
grid([lab(say(st,p[1],fs,p[3],p[4],cy=58),'%dpx（画面の高さの %.1f%%）'%(fs,fs/10.8),0.8) for fs in (30,38,46,54)],1,'比較9_台詞_大きさ_実寸.png')

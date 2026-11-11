# The chosen combination only, as whole 1920x1080 frames (PIL mock, not from the pck)
import sys
src=open('/home/user/notlw/godot/check/fontspec/spec3.py').read().split("fr=Image.open")[0].split("cards=[")[0]
exec(src)
exec("BLUE=(0,84,153); NAVY=(6,22,40)")
DOT=F+'dotgothic16_DotGothic16-Regular.ttf'
def shadow_text(im,items,col=(6,22,40),strength=3):
    """items: (text, font path, size, x, y, fill)"""
    im=im.convert('RGBA'); sh=Image.new('RGBA',im.size,(0,0,0,0)); d=ImageDraw.Draw(sh)
    for t,fp,fs,x,y,fill in items:
        f=ImageFont.truetype(fp,fs); d.text((x+2,y+3),t,font=f,fill=col+(255,),stroke_width=2,stroke_fill=col+(255,))
    sh=sh.filter(ImageFilter.GaussianBlur(7))
    for k in range(strength): im.alpha_composite(sh)
    d=ImageDraw.Draw(im)
    for t,fp,fs,x,y,fill in items: d.text((x,y),t,font=ImageFont.truetype(fp,fs),fill=fill)
    return im.convert('RGB')
def width(t,fp,fs): return ImageDraw.Draw(Image.new('RGB',(8,8))).textlength(t,font=ImageFont.truetype(fp,fs))
def fullcard(rows):
    im=Image.new('RGB',(1920,1080),BG); random.seed(1); px=im.load()
    for i in range(60000):
        x,y=random.randrange(1920),random.randrange(1080); c=px[x,y]; dd=random.choice((-6,6)); px[x,y]=tuple(max(0,v+dd) for v in c)
    tot=sum(r[2]*1.36+r[3] for r in rows); y=540-tot/2
    for t,font,s,g,tr,sq in rows:
        gh=tracked(t,font,s,tr,sq,GH+(51,)); tx=tracked(t,font,s,tr,sq)
        x=960-tx.width//2; im.paste(gh,(x+4,int(y)+3),gh); im.paste(tx,(x,int(y)),tx); y+=s*1.36+g
    return im
M=B1('Medium'); S=B1('SemiBold')
fullcard([('第 一 章',S,46,40,0,1.0),('ルール',M,150,90,0.16,0.85),('あの別荘には、どうして行ったんですか？',S,36,0,0.02,1.0)]).save(OUT+'案1_章カード_第一章.png')
fullcard([('第 二 章',S,46,40,0,1.0),('籠城',M,150,90,0.16,0.85),('最初に、おかしいと思ったのは、いつですか？',S,36,0,0.02,1.0)]).save(OUT+'案2_章カード_第二章.png')
INKA=INK+(255,)
HINT='ＷＡＳＤ 歩く　　マウス 見る　　Ｅ 調べる・話す　　Tab 絵コンテ　　右クリック カメラをのぞく'
def dusk(fs):
    fr=Image.open(SRC+'試作43_確認/1_居間_廊下の扉から.png').convert('RGB')
    line='澪、ちょうどいい。定点、お願いしていい？'; w=width(line,UD,fs); x=960-w/2+fs; y=1080-70-fs
    hw=width(HINT,UD,24)
    return shadow_text(fr,[(HINT,UD,24,960-hw/2,34,INKA),(line,UD,fs,x,y,INKA),('桐生',UD,int(fs*0.73),x-fs*2.0,y+fs*0.22,INKA)])
dusk(46).save(OUT+'案3_台詞_夕方_46px.png'); dusk(42).save(OUT+'案3b_台詞_夕方_42px.png')
# 23時: the old lines sit bottom-left on flat dark green; cover them with the same rows from the right of the frame
nt=Image.open(SRC+'試作31_確認/6_二十三時_扉の前.png').convert('RGB')
patch=nt.crop((1250,860,1900,1040))
for x in (60,710): nt.paste(patch if x==60 else patch.transpose(Image.FLIP_LEFT_RIGHT),(x,860))
fs=46; x0=250; y1=1080-70-fs*2-22; y2=1080-70-fs
nt=shadow_text(nt,[('澪',UD,int(fs*0.73),x0-fs*2.0,y1+fs*0.22,INKA),('二十三時ごろでした。夏希が、外から扉を叩いたんです。',UD,fs,x0,y1,INKA),
                   ('夏希',UD,int(fs*0.73),x0-fs*2.0-int(fs*0.73)*0,y2+fs*0.22,INKA),('澪？　……澪、いるんでしょ。',UD,fs,x0,y2,INKA)])
nt.save(OUT+'案4_台詞_二十三時_46px.png')
# the camcorder's screen: a 4:3 picture in a dark bezel, its own marks in dot type, a line of dialogue below in BIZ UD
fr=Image.open(SRC+'試作43_確認/1_居間_廊下の扉から.png').convert('RGB')
h=int(1080*0.86); w=h*4//3; x0=(1920-w)//2; y0=(1080-h)//2
cam=Image.new('RGB',(1920,1080),(13,13,14)); pic=fr.crop((240,0,240+1440,1080)).resize((w,h),Image.LANCZOS); cam.paste(pic,(x0,y0))
d=ImageDraw.Draw(cam); lc=(235,235,224); f=ImageFont.truetype(DOT,32); f2=ImageFont.truetype(DOT,26)
d.ellipse((x0+26,y0+26,x0+46,y0+46),fill=(255,89,38)); d.text((x0+56,y0+18),'REC',font=f,fill=(255,89,38))
d.text((x0+w-190,y0+18),'0:04:12',font=f,fill=lc); d.text((x0+26,y0+h-50),'WIDE',font=f2,fill=lc)
bx=x0+w-110; by=y0+h-48; d.rectangle((bx,by,bx+70,by+28),outline=lc,width=2); d.rectangle((bx+70,by+8,bx+75,by+20),fill=lc)
for k in range(3): d.rectangle((bx+5+k*21,by+5,bx+5+k*21+17,by+23),fill=lc)
fs=46; line='……回ってる？　じゃあ、本番。'; lw=width(line,UD,fs); x=960-lw/2+fs; y=1080-150
cam=shadow_text(cam,[(line,UD,fs,x,y,INKA),('桐生',UD,int(fs*0.73),x-fs*2.0,y+fs*0.22,INKA)])
cam.save(OUT+'案5_カメラをのぞく_表示はドットゴシック.png')
print('done')

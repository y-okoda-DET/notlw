# 32px default, a wider and thinner shadow in three strengths (PIL mock, not from the pck)
import sys
src=open('/home/user/notlw/godot/check/fontspec/spec3.py').read().split("cards=[")[0]
exec(src)
DOT=F+'dotgothic16_DotGothic16-Regular.ttf'; NAVY=(6,22,40); INKA=INK+(255,)
def soft(im,items,blur,alpha,grow=1,col=NAVY):
    """items: (text, font path, size, x, y). one wide soft shadow at the given opacity, then the type"""
    im=im.convert('RGBA'); sh=Image.new('RGBA',im.size,col+(0,)); d=ImageDraw.Draw(sh)
    for t,fp,fs,x,y in items: d.text((x+1,y+2),t,font=ImageFont.truetype(fp,fs),fill=col+(255,),stroke_width=grow,stroke_fill=col+(255,))
    a=sh.split()[3].filter(ImageFilter.GaussianBlur(blur)).point(lambda v:int(min(255,v*alpha)))
    sh.putalpha(a); im.alpha_composite(sh)
    d=ImageDraw.Draw(im)
    for t,fp,fs,x,y in items: d.text((x,y),t,font=ImageFont.truetype(fp,fs),fill=INKA)
    return im.convert('RGB')
def width(t,fp,fs): return ImageDraw.Draw(Image.new('RGB',(8,8))).textlength(t,font=ImageFont.truetype(fp,fs))
def line_items(im,fs,cy,line='澪、ちょうどいい。定点、お願いしていい？',name='桐生'):
    w=width(line,UD,fs); x=im.width/2-w/2+fs
    return [(line,UD,fs,x,cy),(name,UD,int(fs*0.73),x-fs*2.0,cy+fs*0.22)]
# strength: (label, blur px, opacity multiplier, grow px)
ST=[('弱：広さ12・濃さ45%',12,1.1,3),('中：広さ12・濃さ65%',12,1.6,3),('強：広さ10・濃さ85%',10,2.1,3)]
fr=Image.open(SRC+'試作43_確認/1_居間_廊下の扉から.png').convert('RGB')
wh=fr.crop((260,400,1720,530)); dk=Image.open(SRC+'試作35_確認/2_台詞_会話の最初だけ名前.png').convert('RGB').crop((230,770,1690,900))
def now(bg):   # what the game does now: 30px, outline + offset shadow in blue
    im=bg.convert('RGBA'); ov=Image.new('RGBA',im.size,(0,0,0,0)); d=ImageDraw.Draw(ov)
    for t,fp,fs,x,y in [(a,NOTO,c,dd,e) for a,b,c,dd,e in line_items(bg,30,66)]:
        f=ImageFont.truetype(fp,fs)
        d.text((x+2.5,y+1.5),t,font=f,fill=(0,84,153,230),stroke_width=5,stroke_fill=(0,66,128,190)); d.text((x,y),t,font=f,fill=INKA,stroke_width=5,stroke_fill=(0,66,128,190))
    im.alpha_composite(ov); return im.convert('RGB')
def plain(bg): 
    im=bg.copy(); d=ImageDraw.Draw(im)
    for t,fp,fs,x,y in line_items(bg,32,66): d.text((x,y),t,font=ImageFont.truetype(fp,fs),fill=INK)
    return im
for bg,name in ((wh,'比較10_台詞32px_シャドウの濃さ_白い所_実寸.png'),(dk,'比較11_台詞32px_シャドウの濃さ_暗い所_実寸.png')):
    rows=[lab(now(bg),'今：Noto Bold 30px・袋文字',0.8),lab(plain(bg),'BIZ UD明朝 Bold 32px・シャドウなし（比べる用）',0.8)]
    rows+=[lab(soft(bg,line_items(bg,32,66),b,a,g),'BIZ UD明朝 Bold 32px・シャドウ '+t,0.8) for t,b,a,g in ST]
    grid(rows,1,name)
PICK=int(sys.argv[1]) if len(sys.argv)>1 else 1
t,b,a,g=ST[PICK]
HINT='ＷＡＳＤ 歩く　　マウス 見る　　Ｅ 調べる・話す　　Tab 絵コンテ　　右クリック カメラをのぞく'
fs=32
f1=fr.copy(); it=line_items(f1,fs,1080-64-fs); hw=width(HINT,UD,20); it.append((HINT,UD,20,960-hw/2,34))
soft(f1,it,b,a,g).save(OUT+'案3_台詞_夕方_32px.png')
nt=Image.open(SRC+'試作31_確認/6_二十三時_扉の前.png').convert('RGB')
patch=nt.crop((1250,860,1900,1040))
for x in (60,710): nt.paste(patch if x==60 else patch.transpose(Image.FLIP_LEFT_RIGHT),(x,860))
x0=236; y1=1080-64-fs*2-16; y2=1080-64-fs; ns=int(fs*0.73)
soft(nt,[('澪',UD,ns,x0-fs*3.2,y1+fs*0.22),('二十三時ごろでした。夏希が、外から扉を叩いたんです。',UD,fs,x0,y1),('夏希',UD,ns,x0-fs*3.2,y2+fs*0.22),('澪？　……澪、いるんでしょ。',UD,fs,x0,y2)],b,a,g).save(OUT+'案4_台詞_二十三時_32px.png')
h=int(1080*0.86); w=h*4//3; x0=(1920-w)//2; y0=(1080-h)//2
cam=Image.new('RGB',(1920,1080),(13,13,14)); cam.paste(fr.crop((240,0,1680,1080)).resize((w,h),Image.LANCZOS),(x0,y0))
d=ImageDraw.Draw(cam); lc=(235,235,224); f=ImageFont.truetype(DOT,32); f2=ImageFont.truetype(DOT,26)
d.ellipse((x0+26,y0+26,x0+46,y0+46),fill=(255,89,38)); d.text((x0+56,y0+18),'REC',font=f,fill=(255,89,38))
d.text((x0+w-190,y0+18),'0:04:12',font=f,fill=lc); d.text((x0+26,y0+h-50),'WIDE',font=f2,fill=lc)
bx=x0+w-110; by=y0+h-48; d.rectangle((bx,by,bx+70,by+28),outline=lc,width=2); d.rectangle((bx+70,by+8,bx+75,by+20),fill=lc)
for k in range(3): d.rectangle((bx+5+k*21,by+5,bx+5+k*21+17,by+23),fill=lc)
soft(cam,line_items(cam,fs,1080-150,'……回ってる？　じゃあ、本番。'),b,a,g).save(OUT+'案5_カメラをのぞく_32px.png')
print('pick',t)

# Several fonts side by side, same conditions (PIL mock, not from the pck)
import sys; sys.path.insert(0,'/home/user/work/fontcheck')
from PIL import Image, ImageDraw, ImageFont
exec(open('/home/user/work/fontcheck/spec.py').read().split("stack(card(NOTO)")[0])
F='/home/user/work/fonts/'
C=[('A 今：Noto Serif CJK Bold',NOTO,NOTO),
   ('B しっぽり明朝 B1（にじみ入り）',F+'shipporiminchob1_ShipporiMinchoB1-Bold.ttf',F+'shipporiminchob1_ShipporiMinchoB1-SemiBold.ttf'),
   ('C 禅オールド明朝（Zen Old Mincho）',F+'zenoldmincho_ZenOldMincho-Bold.ttf',F+'zenoldmincho_ZenOldMincho-SemiBold.ttf'),
   ('D 解星 特ミン（Kaisei Tokumin）',F+'kaiseitokumin_KaiseiTokumin-Bold.ttf',F+'kaiseitokumin_KaiseiTokumin-Medium.ttf'),
   ('E BIZ UDP明朝',F+'bizudpmincho_BIZUDPMincho-Bold.ttf',F+'bizudpmincho_BIZUDPMincho-Bold.ttf'),
   ('F クレー One（ペン字）',F+'kleeone_KleeOne-SemiBold.ttf',F+'kleeone_KleeOne-SemiBold.ttf')]
def grid(ims,cols,name,bg=(250,248,240)):
    w=max(i.width for i in ims); h=max(i.height for i in ims); rows=(len(ims)+cols-1)//cols
    g=Image.new('RGB',(cols*w+(cols-1)*8,rows*h+(rows-1)*8),bg)
    for k,i in enumerate(ims): g.paste(i,((k%cols)*(w+8),(k//cols)*(h+8)))
    g.save(OUT+name); print(name,g.size)
cards=[]
for t,big,small in C:
    im=card(big); im=im.resize((960,300),Image.LANCZOS); cards.append(lab(im,t))
grid(cards,2,'比較1_章カード_半分の大きさ.png')
sc=Image.open(SRC+'試作35_確認/2_台詞_会話の最初だけ名前.png').convert('RGB').crop((360,770,1560,890))
grid([lab(say(small,sc,48),t+'　30px') for t,big,small in C],1,'比較2_台詞_実寸.png')
vf=Image.open(SRC+'試作26_確認/5_のぞいてコンテと見比べる.png').convert('RGB').crop((700,280,1340,600))
O=[('A 今：Noto Serif（明朝）',NOTO),('G ドットゴシック16',F+'dotgothic16_DotGothic16-Regular.ttf'),('H VT323（英数字だけ）',F+'vt323_VT323-Regular.ttf'),('I Share Tech Mono（英数字だけ）',F+'sharetechmono_ShareTechMono-Regular.ttf')]
def osd2(font,bg):
    im=bg.copy(); d=ImageDraw.Draw(im); f=ImageFont.truetype(font,30); f2=ImageFont.truetype(font,24); lc=(235,235,224)
    d.text((40,40),'STBY',font=f,fill=lc); d.ellipse((180,50,198,68),fill=(255,89,38)); d.text((206,40),'REC',font=f,fill=(255,89,38))
    d.text((440,40),'0:00:02',font=f,fill=lc); d.text((40,260),'WIDE',font=f2,fill=lc); return im
grid([lab(osd2(p,vf),t) for t,p in O],2,'比較3_カメラの表示_実寸.png')

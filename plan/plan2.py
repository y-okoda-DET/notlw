import matplotlib, math
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager as fm
from matplotlib.patches import Rectangle, Arc, Polygon
fp=fm.FontProperties(fname='/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc')
INK='#0b3a6b'; OR='#e8521c'; PAPER='#efe9dc'; GREY='#8a96a3'
fig,axs=plt.subplots(1,3,figsize=(24,9.4))
fig.patch.set_facecolor(PAPER)
def T(ax,x,y,t,fs=12,c=INK,ha='center',va='center'): ax.text(x,y,t,fontproperties=fp,fontsize=fs,color=c,ha=ha,va=va)
def box(ax,x,y,w,h,lw=2.2,c=INK,ls='-'): ax.add_patch(Rectangle((x,y),w,h,fill=False,ec=c,lw=lw,ls=ls))
def gap(ax,x0,y0,x1,y1,w=6): ax.plot([x0,x1],[y0,y1],color=PAPER,lw=w,solid_capstyle='butt',zorder=3)
def door(ax,x,y,orient,width=0.85,swing=1,c=INK,kind='hinge'):
    """door in a wall. orient 'h' = wall along x at y; 'v' = wall along y at x. swing=+1/-1 side."""
    if orient=='h':
        gap(ax,x,y,x+width,y)
        if kind=='slide':
            ax.plot([x,x+width],[y+0.07*swing,y+0.07*swing],color=c,lw=2,zorder=4)
        else:
            ax.plot([x,x],[y,y+width*swing],color=c,lw=1.3,zorder=4)
            ax.add_patch(Arc((x,y),2*width,2*width,theta1=0 if swing>0 else 270,theta2=90 if swing>0 else 360,color=c,lw=0.9,zorder=4))
    else:
        gap(ax,x,y,x,y+width)
        if kind=='slide':
            ax.plot([x+0.07*swing,x+0.07*swing],[y,y+width],color=c,lw=2,zorder=4)
        else:
            ax.plot([x,x+width*swing],[y,y],color=c,lw=1.3,zorder=4)
            ax.add_patch(Arc((x,y),2*width,2*width,theta1=0 if swing>0 else 90,theta2=90 if swing>0 else 180,color=c,lw=0.9,zorder=4))
def win(ax,x0,y0,x1,y1):
    gap(ax,x0,y0,x1,y1); ax.plot([x0,x1],[y0,y1],color=INK,lw=1.4,ls=(0,(1,1.2)),zorder=4)
def stairs(ax,x,y,w,h,n,up=True,c=INK,ls='-',lw=0.8):
    for i in range(n+1): ax.plot([x,x+w],[y+h*i/n]*2,color=c,lw=lw,ls=ls)
    ax.plot([x,x],[y,y+h],color=c,lw=lw,ls=ls); ax.plot([x+w,x+w],[y,y+h],color=c,lw=lw,ls=ls)
    ax.annotate('',xy=(x+w/2,y+h-0.12 if up else y+0.12),xytext=(x+w/2,y+0.12 if up else y+h-0.12),arrowprops=dict(arrowstyle='->',color=c,lw=1.5))
for ax,t in zip(axs,['1階','2階','地下']):
    ax.set_facecolor(PAPER); ax.set_aspect('equal'); ax.axis('off'); ax.set_title(t,fontproperties=fp,fontsize=19,color=INK,pad=2)
# ============ 1F ============  x: west->east, y: south(front)->north
a=axs[0]; a.set_xlim(-1.6,12.4); a.set_ylim(-5.0,9.2)
box(a,0,0,10,8,lw=3.4)
# rooms
box(a,0,0,4,4.6); box(a,0,4.6,4,3.4); box(a,6,0,4,3.6); box(a,6,3.6,4,4.4); box(a,8.6,6.6,1.4,1.4)
box(a,4,0,2,8)                     # hall
box(a,5.0,6.8,1.0,1.2)             # toilet
a.plot([4,6],[1.4,1.4],color=INK,lw=1.2,ls='--')    # agarikamachi (step)
T(a,2,2.6,'居間',13); T(a,2,2.05,'上映会・薪ストーブ・鹿の剥製',8.5)
T(a,2,6.5,'食堂',13); T(a,2,6.0,'大きなテーブル',8.5)
T(a,8,1.9,'書斎（和室）',13); T(a,8,1.35,'オーナーの部屋・剥製・机',8.5)
T(a,7.6,5.3,'台所',13); T(a,7.6,4.75,'工具箱（金槌・釘）',8.5)
T(a,9.3,7.4,'食品庫',9); T(a,5.5,7.45,'トイレ',8.5)
T(a,5,0.75,'玄関（土間）',10); T(a,5,1.62,'上がり框（段差）',7.5); T(a,4.5,7.4,'廊下',10)
# stairs: up (south->north), cellar stair underneath (dashed, descends north->south)
stairs(a,5.1,2.6,0.85,3.0,10,True)
stairs(a,5.1,2.6,0.85,3.0,10,False,c=GREY,ls=(0,(2,2)),lw=0.7)
T(a,5.52,2.35,'上り',8)
door(a,5.1,5.6,'h',0.85,1,c=OR)   # cellar door at north end of stair (under its high end)
T(a,6.75,6.15,'',8)
a.annotate('地下への扉（階段の下）',xy=(5.5,5.75),xytext=(3.1,8.55),fontproperties=fp,fontsize=8.5,color=OR,arrowprops=dict(arrowstyle='->',color=OR,lw=1))
# interior doors
door(a,4,3.1,'v',0.85,-1)          # hall -> living
door(a,4,6.1,'v',0.85,-1)          # hall -> dining
gap(a,0.6,4.6,3.2,4.6); T(a,1.9,4.75,'（開口）',7.5)   # living <-> dining open
door(a,6,1.6,'v',0.85,1,kind='slide')   # hall -> study (fusuma)
door(a,6,6.0,'v',0.85,1)          # hall -> kitchen
door(a,8.6,6.9,'v',0.7,-1)        # kitchen -> pantry
door(a,5.0,7.0,'v',0.7,-1)        # toilet
# exterior doors
door(a,4.45,0,'h',1.1,1,c=OR); door(a,10,4.4,'v',0.95,-1,c=OR)
# windows
for w in [(0.6,0,1.8,0),(2.4,0,3.4,0),(0,1.0,0,1.8),(0,5.4,0,7.0),(1.2,8,2.8,8),(6.6,0,7.6,0),(8.4,0,9.4,0),(10,1.0,10,2.4),(6.8,8,8.0,8),(10,6.0,10,6.4)]:
    win(a,*w)
win(a,4.15,0,4.35,0); T(a,4.25,-0.25,'細い窓',7,OR)
# stove + chimney outside west wall
a.add_patch(Rectangle((0.15,2.9),0.6,0.6,fc=INK,ec=INK)); a.add_patch(Rectangle((-0.55,3.0),0.45,0.45,fill=False,ec=INK,lw=1.5))
a.plot([-0.1,0.15],[3.22,3.22],color=INK,lw=1.5); T(a,-0.35,3.75,'煙突\n（外壁沿い）',7.5)
# porches, car
box(a,3.6,-1.5,2.8,1.5,lw=1.4,ls='--'); T(a,5,-0.95,'ポーチ（夏希が立つ）',9)
box(a,10,3.9,1.4,2.0,lw=1.4,ls='--'); T(a,10.7,5.2,'裏\nポーチ',8.5); T(a,10.7,4.3,'薪・灯油',7.5)
a.add_patch(Rectangle((7.2,-4.1),2.2,1.25,fill=False,ec=INK,lw=1.6)); T(a,8.3,-3.47,'夏希の車',9)
a.plot([6.4,10.5],[-2.3,-2.3],color=GREY,lw=1,ls=':'); T(a,10.6,-2.2,'私道',7.5,GREY,ha='left')
T(a,-1.5,-4.75,'点線＝窓（すべて板で塞げる）　オレンジ＝外への出入口・地下への扉　灰色の点線＝上り階段の下にある地下への階段',8,INK,ha='left')
T(a,5,-1.85,'正面（南）',8.5)
# ============ 2F ============
b=axs[1]; b.set_xlim(-1.6,12.4); b.set_ylim(-5.0,9.2)
box(b,0,0,10,8,lw=3.4)
box(b,0,0,4,4.2); box(b,0,4.2,4,3.8); box(b,6,0,4,4.2); box(b,6,4.2,4,3.8); box(b,4,0,2,8)
T(b,2,2.3,'寝室1',13)
T(b,2,6.3,'寝室2',13); T(b,8,2.3,'寝室3',13)
T(b,8,6.1,'洗面・浴室',12)
# stairwell (void) + arrival
b.add_patch(Rectangle((5.1,2.6),0.85,3.0,fill=False,ec=INK,lw=1)); b.plot([5.1,5.95],[2.6,5.6],color=INK,lw=0.7); b.plot([5.1,5.95],[5.6,2.6],color=INK,lw=0.7)
T(b,5.52,2.35,'吹抜け',7.5)
b.add_patch(Rectangle((5.1,5.6),0.85,0.75,fc='none',ec=OR,lw=1.8))
b.annotate('階段を上り切った所',xy=(5.52,6.0),xytext=(6.2,8.55),fontproperties=fp,fontsize=8.5,color=OR,arrowprops=dict(arrowstyle='->',color=OR,lw=1))
T(b,4.5,7.4,'廊下',10); T(b,5.0,1.0,'窓（玄関の真上）\nポーチと車が\nいちばんよく見える',7.5)
door(b,4,3.1,'v',0.85,-1); door(b,4,6.6,'v',0.85,-1); door(b,6,1.2,'v',0.85,1); door(b,6,6.7,'v',0.85,1)
for w in [(0.8,0,2.2,0),(0,1.2,0,2.6),(0,5.4,0,6.8),(1.2,8,2.8,8),(4.4,0,5.6,0),(6.6,0,8.0,0),(10,1.2,10,2.6),(10,6.0,10,7.0),(6.6,8,7.6,8)]:
    win(b,*w)
b.add_patch(Rectangle((-0.55,3.0),0.45,0.45,fill=False,ec=INK,lw=1.5)); T(b,-0.35,3.75,'煙突',7.5)
# ============ B1 ============  same coordinates as the house, partial view x 3..11
c=axs[2]; c.set_xlim(-1.6,12.4); c.set_ylim(-5.0,9.2)
box(c,0,0,10,8,lw=1,c=GREY,ls=(0,(3,3))); T(c,0.2,7.6,'（1階の外壁）',7.5,GREY,ha='left')
box(c,4,1.0,6,6.0,lw=3.2)
T(c,8.0,3.9,'地下室',13)
c.add_patch(Rectangle((8.6,6.0),1.0,0.7,fc='none',ec=INK,lw=1.5)); T(c,9.1,6.35,'発電機',7)
c.plot([9.6,10.0],[6.35,6.45],color=INK,lw=1.2)
stairs(c,5.1,2.6,0.85,3.0,10,False)
T(c,5.52,6.4,'1階から下りる',7.5)
# barred door at the foot of the stair, bar on the basement side
c.plot([4.9,6.15],[2.55,2.55],color=OR,lw=2.5); c.plot([4.9,6.15],[2.35,2.35],color=OR,lw=4)
T(c,5.52,1.75,'閂の扉（内側から閉める）',8,OR)
# east wall exposed (slope)
win(c,10,6.15,10,6.75)
c.annotate('',xy=(11.4,6.45),xytext=(10.0,6.45),arrowprops=dict(arrowstyle='->',color=OR,lw=2))
T(c,10.15,7.25,'小窓＝排気口',8.5,OR,ha='left')
T(c,10.15,8.0,'排気ホースは\nこの小窓から外へ',7.5,OR,ha='left')
c.add_patch(Rectangle((10,3.9),1.4,2.0,fill=False,ec=GREY,lw=1,ls=(0,(3,3)))); T(c,10.7,4.9,'（裏ポーチ）',7,GREY)
T(c,5.2,-1.6,'敷地は東へ下る斜面：地下の東側の壁だけが地上に出る。\n小窓は裏ポーチより北（勝手口から離れた位置）。\n第2章で窓を外から板で塞ぐと、発電機の排気もいっしょに塞がる\n（第3章で大河が死ぬ仕掛け。第5章で外の板だけが残る）。',8.5)
plt.tight_layout(); plt.savefig('/home/claude/plan/plan_v4.png',dpi=105,facecolor=PAPER)

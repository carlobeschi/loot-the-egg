import json,hashlib,zipfile,os
import sys
OUT=sys.argv[1] if len(sys.argv)>1 else 'loot-the-egg.sb3'
# ---------------- SVG art ----------------
def svg(w,h,body):return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>'
def tree(x,y,s=1):return f'<rect x="{x-5*s}" y="{y}" width="{10*s}" height="{24*s}" fill="#6b4423"/><circle cx="{x}" cy="{y-6*s}" r="{22*s}" fill="#1f6b2e"/><circle cx="{x-10*s}" cy="{y+2*s}" r="{14*s}" fill="#2a8a3c"/><circle cx="{x+11*s}" cy="{y}" r="{15*s}" fill="#237a33"/>'
import random;random.seed(7)
trees=''.join(tree(random.randint(10,470),random.randint(30,330),random.uniform(.8,1.3)) for _ in range(34))
backdrop=svg(480,360,'<rect width="480" height="360" fill="#4f9a3c"/>'+''.join(f'<circle cx="{random.randint(0,480)}" cy="{random.randint(0,360)}" r="{random.randint(14,40)}" fill="#{random.choice(["468c36","58a644"])}" opacity=".6"/>' for _ in range(40))+trees+
 '<g><rect x="355" y="30" width="90" height="110" fill="#6d6a78"/><polygon points="345,34 400,-6 455,34" fill="#4a2f6b"/><rect x="385" y="95" width="30" height="45" fill="#1a1420"/><rect x="368" y="50" width="12" height="18" fill="#ffd34a"/><rect x="420" y="50" width="12" height="18" fill="#ffd34a"/><text x="400" y="158" font-size="13" text-anchor="middle" fill="#fff" font-family="Arial" font-weight="bold">DUNGEON TOWER</text></g>')
knight=svg(36,60,'<rect x="9" y="26" width="18" height="20" rx="4" fill="#a7b0b8"/><rect x="9" y="44" width="7" height="14" rx="3" fill="#3d4852"/><rect x="20" y="44" width="7" height="14" rx="3" fill="#3d4852"/><rect x="2" y="26" width="7" height="16" rx="3" fill="#dfe5e8"/><rect x="27" y="26" width="7" height="16" rx="3" fill="#dfe5e8"/><circle cx="18" cy="17" r="11" fill="#f5cd30"/><path d="M6 15 a12 12 0 0 1 24 0 v3 h-24z" fill="#dfe5e8"/><rect x="16" y="2" width="4" height="8" fill="#c0392b"/><circle cx="14" cy="19" r="1.6" fill="#222"/><circle cx="22" cy="19" r="1.6" fill="#222"/><rect x="30" y="8" width="3" height="34" fill="#eef3f6"/><rect x="27" y="40" width="9" height="3" fill="#8b6a2a"/>')
wizard=svg(36,66,'<path d="M9 28 h18 l4 30 h-26z" fill="#7b4fd6"/><rect x="2" y="28" width="7" height="14" rx="3" fill="#4b3a9a"/><rect x="27" y="28" width="7" height="14" rx="3" fill="#4b3a9a"/><circle cx="18" cy="20" r="10" fill="#f5cd30"/><rect x="14" y="24" width="8" height="9" fill="#f0f0f0"/><polygon points="3,16 33,16 18,-2" fill="#4b3a9a"/><rect x="3" y="14" width="30" height="4" rx="2" fill="#4b3a9a"/><rect x="12" y="14" width="12" height="2" fill="#ffc933"/><circle cx="14" cy="20" r="1.5" fill="#222"/><circle cx="22" cy="20" r="1.5" fill="#222"/><rect x="31" y="14" width="3" height="44" fill="#5a3d28"/><circle cx="32.5" cy="12" r="5" fill="#b9aeff"/>')
bowman=svg(36,60,'<rect x="9" y="26" width="18" height="20" rx="4" fill="#3fae4b"/><rect x="9" y="44" width="7" height="14" rx="3" fill="#7a5230"/><rect x="20" y="44" width="7" height="14" rx="3" fill="#7a5230"/><rect x="2" y="26" width="7" height="16" rx="3" fill="#f5cd30"/><rect x="27" y="26" width="7" height="16" rx="3" fill="#f5cd30"/><circle cx="18" cy="17" r="10" fill="#f5cd30"/><path d="M6 17 a12 12 0 0 1 24 0 v-3 q-12 -10 -24 0z" fill="#2f5a2a"/><circle cx="14" cy="18" r="1.6" fill="#222"/><circle cx="22" cy="18" r="1.6" fill="#222"/><path d="M33 8 q10 22 0 44" stroke="#5a3d28" stroke-width="3" fill="none"/>')
shot1=svg(30,30,'<path d="M2 24 Q15 -4 28 24 Q15 8 2 24z" fill="#f2f8ff" stroke="#9fd0ff" stroke-width="2"/>')
shot2=svg(22,22,'<circle cx="11" cy="11" r="9" fill="#b9aeff"/><circle cx="11" cy="11" r="5" fill="#fff"/>')
shot3=svg(34,10,'<rect x="2" y="4" width="26" height="2" fill="#8b6a2a"/><polygon points="34,5 26,0 26,10" fill="#ddd"/><polygon points="0,5 6,0 6,3 3,5 6,7 6,10" fill="#f1ead2"/>')
zombie=svg(36,60,'<rect x="9" y="26" width="18" height="20" rx="4" fill="#3b78d4"/><rect x="9" y="44" width="7" height="14" rx="3" fill="#4a4a8a"/><rect x="20" y="44" width="7" height="14" rx="3" fill="#4a4a8a"/><rect x="-2" y="26" width="11" height="7" rx="3" fill="#8fc15a"/><rect x="27" y="26" width="11" height="7" rx="3" fill="#8fc15a"/><circle cx="18" cy="17" r="11" fill="#8fc15a"/><circle cx="13" cy="16" r="2.5" fill="#ffe040"/><circle cx="23" cy="16" r="2.5" fill="#ffe040"/><rect x="12" y="23" width="12" height="3" fill="#2a3a1a"/>')
boss=svg(70,100,'<rect x="14" y="44" width="42" height="34" rx="8" fill="#6a1fa0"/><rect x="14" y="76" width="14" height="22" rx="5" fill="#1a1a22"/><rect x="42" y="76" width="14" height="22" rx="5" fill="#1a1a22"/><rect x="0" y="44" width="14" height="26" rx="6" fill="#3a3a46"/><rect x="56" y="44" width="14" height="26" rx="6" fill="#3a3a46"/><circle cx="35" cy="28" r="20" fill="#3a3a46"/><circle cx="27" cy="26" r="4" fill="#ff2020"/><circle cx="43" cy="26" r="4" fill="#ff2020"/><rect x="26" y="36" width="18" height="4" fill="#111"/><polygon points="15,14 20,-2 27,10 35,-4 43,10 50,-2 55,14" fill="#ffc933"/>')
egg=svg(28,36,'<ellipse cx="14" cy="19" rx="12" ry="16" fill="#ffd34a" stroke="#c99a10" stroke-width="2"/><circle cx="9" cy="14" r="3" fill="#ff9a2a"/><circle cx="18" cy="24" r="3.5" fill="#ff9a2a"/><circle cx="17" cy="11" r="2" fill="#ff9a2a"/>')
home=svg(90,80,'<polygon points="0,30 45,0 90,30" fill="#a8452f"/><rect x="8" y="30" width="74" height="48" fill="#c9a86a"/><rect x="36" y="48" width="18" height="30" fill="#5a3d28"/><text x="45" y="43" font-size="12" text-anchor="middle" fill="#3a2410" font-family="Arial" font-weight="bold">HOME</text>')
assets={}
def reg(name,s,cx,cy):
    d=s.encode();m=hashlib.md5(d).hexdigest();assets[m+'.svg']=d
    return {"assetId":m,"name":name,"bitmapResolution":1,"md5ext":m+'.svg',"dataFormat":"svg","rotationCenterX":cx,"rotationCenterY":cy}
# ---------------- block builder ----------------
class T:
    def __init__(s,name):s.name=name;s.b={};s.n=0;s.vars={}
    def blk(s,op,inputs=None,fields=None,mut=None,shadow=False,top=False,x=0,y=0):
        s.n+=1;i=f'{s.name[:3]}{op.split("_",1)[-1][:10]}{s.n}'.replace(' ','_')
        d={"opcode":op,"next":None,"parent":None,"inputs":inputs or {},"fields":fields or {},"shadow":shadow,"topLevel":top}
        if mut:d["mutation"]=mut
        if top:d["x"]=x;d["y"]=y
        s.b[i]=d;return i
G={}  # global var name->id
def vid(n):
    if n not in G:G[n]='var_'+n
    return G[n]
def num(v):return [1,[4,str(v)]]
def txt(v):return [1,[10,str(v)]]
def val(x):
    if isinstance(x,V):return [3,[12,x.n,vid(x.n)],[4,"0"]]
    if isinstance(x,str) and x.startswith('@'):return [3,x[1:],[4,"0"]]
    if isinstance(x,(int,float)):return num(x)
    return txt(x)
class V:
    def __init__(s,n):s.n=n
def mk(t):
    B=t.blk
    def menu(op,f,v):
        return [1,B(op,{}, {f:[v,None]},shadow=True)]
    def R(op,**ins):return '@'+B(op,{k:val(v) for k,v in ins.items()})
    def C(op,**ins):return '@'+B(op,{k:val(v) for k,v in ins.items()})
    def cond(x):return [2,x[1:]]
    def link(ids):
        for a,b in zip(ids,ids[1:]):t.b[a]['next']=b
        return ids[0] if ids else None
    def sub(ids):return [2,link(ids)] if ids else None
    def st(op,fields=None,mut=None,**ins):return B(op,{k:val(v) for k,v in ins.items()},fields)
    o={}
    o['setv']=lambda n,v:B('data_setvariableto',{'VALUE':val(v)},{'VARIABLE':[n,vid(n)]})
    o['chv']=lambda n,v:B('data_changevariableby',{'VALUE':val(v)},{'VARIABLE':[n,vid(n)]})
    o['wait']=lambda s:B('control_wait',{'DURATION':val(s)})
    o['forever']=lambda *a:B('control_forever',{'SUBSTACK':sub(list(a))})
    o['iff']=lambda c,*a:B('control_if',{'CONDITION':cond(c),**({'SUBSTACK':sub(list(a))} if a else {})})
    o['ifelse']=lambda c,a,b:B('control_if_else',{'CONDITION':cond(c),'SUBSTACK':sub(a),'SUBSTACK2':sub(b)})
    o['repeat']=lambda n,*a:B('control_repeat',{'TIMES':val(n),'SUBSTACK':sub(list(a))})
    o['until']=lambda c,*a:B('control_repeat_until',{'CONDITION':cond(c),'SUBSTACK':sub(list(a))})
    o['waituntil']=lambda c:B('control_wait_until',{'CONDITION':cond(c)})
    o['stopall']=lambda:B('control_stop',{},{'STOP_OPTION':['all',None]},mut={"tagName":"mutation","children":[],"hasnext":"false"})
    o['move']=lambda n:B('motion_movesteps',{'STEPS':val(n)})
    o['gotoxy']=lambda x,y:B('motion_gotoxy',{'X':val(x),'Y':val(y)})
    o['gotospr']=lambda n:B('motion_goto',{'TO':menu('motion_goto_menu','TO',n)})
    o['towards']=lambda n:B('motion_pointtowards',{'TOWARDS':menu('motion_pointtowards_menu','TOWARDS',n)})
    o['chx']=lambda n:B('motion_changexby',{'DX':val(n)})
    o['chy']=lambda n:B('motion_changeyby',{'DY':val(n)})
    o['show']=lambda:B('looks_show');o['hide']=lambda:B('looks_hide')
    o['say']=lambda m:B('looks_say',{'MESSAGE':val(m)})
    o['sayfor']=lambda m,s:B('looks_sayforsecs',{'MESSAGE':val(m),'SECS':val(s)})
    o['costume']=lambda n:B('looks_switchcostumeto',{'COSTUME':menu('looks_costume','COSTUME',n)})
    o['size']=lambda n:B('looks_setsizeto',{'SIZE':val(n)})
    o['clone']=lambda:B('control_create_clone_of',{'CLONE_OPTION':menu('control_create_clone_of_menu','CLONE_OPTION','_myself_')})
    o['delclone']=lambda:B('control_delete_this_clone')
    o['bc']=lambda n:B('event_broadcast',{'BROADCAST_INPUT':[1,[11,n,'bc_'+n]]})
    o['ask']=lambda q:B('sensing_askandwait',{'QUESTION':val(q)})
    # reporters
    o['add']=lambda a,b:R('operator_add',NUM1=a,NUM2=b)
    o['sub']=lambda a,b:R('operator_subtract',NUM1=a,NUM2=b)
    o['mul']=lambda a,b:R('operator_multiply',NUM1=a,NUM2=b)
    o['rnd']=lambda a,b:R('operator_random',FROM=a,TO=b)
    o['round']=lambda a:R('operator_round',NUM=a)
    o['join']=lambda a,b:R('operator_join',STRING1=a,STRING2=b)
    o['lt']=lambda a,b:C('operator_lt',OPERAND1=a,OPERAND2=b)
    o['gt']=lambda a,b:C('operator_gt',OPERAND1=a,OPERAND2=b)
    o['eq']=lambda a,b:C('operator_equals',OPERAND1=a,OPERAND2=b)
    o['and_']=lambda a,b:'@'+B('operator_and',{'OPERAND1':cond(a),'OPERAND2':cond(b)})
    o['or_']=lambda a,b:'@'+B('operator_or',{'OPERAND1':cond(a),'OPERAND2':cond(b)})
    o['not_']=lambda a:'@'+B('operator_not',{'OPERAND':cond(a)})
    o['touch']=lambda n:'@'+B('sensing_touchingobject',{'TOUCHINGOBJECTMENU':menu('sensing_touchingobjectmenu','TOUCHINGOBJECTMENU',n)})
    o['key']=lambda k:'@'+B('sensing_keypressed',{'KEY_OPTION':menu('sensing_keyoptions','KEY_OPTION',k)})
    o['mouse']=lambda:'@'+B('sensing_mousedown')
    o['dist']=lambda n:'@'+B('sensing_distanceto',{'DISTANCETOMENU':menu('sensing_distancetomenu','DISTANCETOMENU',n)})
    o['answer']=lambda:'@'+B('sensing_answer')
    o['xpos']=lambda:'@'+B('motion_xposition');o['ypos']=lambda:'@'+B('motion_yposition')
    # hats
    def hat(op,fields=None,x=20,y=20):return B(op,{},fields or {},top=True,x=x,y=y)
    o['flag']=lambda:hat('event_whenflagclicked')
    o['onkey']=lambda k:hat('event_whenkeypressed',{'KEY_OPTION':[k,None]})
    o['onmsg']=lambda n:hat('event_whenbroadcastreceived',{'BROADCAST_OPTION':[n,'bc_'+n]})
    o['onclone']=lambda:hat('control_start_as_clone')
    cnt=[0]
    def script(h,*a):
        cnt[0]+=1;t.b[h]['x']=20+(cnt[0]%2)*420;t.b[h]['y']=20+(cnt[0]//2)*360
        first=link(list(a))
        if first:t.b[h]['next']=first
        return h
    o['script']=script
    o['V']=V
    return o
def finish(t):
    for i,d in t.b.items():
        if d['next']:t.b[d['next']]['parent']=i
        for k,v in d['inputs'].items():
            if v is None:continue
            if v[0] in (1,2,3) and isinstance(v[1],str):t.b[v[1]]['parent']=i
    return t.b
# ---------------- targets ----------------
MSGS=['choose','begin','fire','eggdrop','newround','grabbed','fight']
targets=[]
GV=['coins','eggs','hp','carrying','aggro','dmg','dmgcost','shotlife','shotspeed','cls','bhp','round','income','rebirth','mult','bx','by','rarity']
# Stage
st=T('Stage');s=mk(st);V_=V
s['script'](s['flag'](),*[s['setv'](n,v) for n,v in [('coins',0),('eggs',0),('hp',10),('carrying',0),('aggro',0),('dmg',4),('dmgcost',20),('shotlife',7),('shotspeed',9),('cls',1),('bhp',30),('round',1),('income',0),('rebirth',0),('mult',1),('bx',0),('by',0),('rarity','Common')]],s['bc']('choose'))
s['script'](s['onmsg']('begin'),s['forever'](s['wait'](1),s['chv']('coins',s['mul'](V('income'),V('mult')))))
# Player
pl=T('Player');p=mk(pl)
p['script'](p['onmsg']('choose'),p['gotoxy'](-170,-110),p['show'](),p['costume']('knight'),
  p['ask']('Pick a class!  1 = Knight   2 = Wizard   3 = Bowman'),
  p['setv']('cls',1),p['setv']('dmg',4),p['setv']('shotlife',7),p['setv']('shotspeed',9),
  p['iff'](p['eq'](p['answer'](),2),p['setv']('cls',2),p['setv']('dmg',3),p['setv']('shotlife',22),p['setv']('shotspeed',7),p['costume']('wizard')),
  p['iff'](p['eq'](p['answer'](),3),p['setv']('cls',3),p['setv']('dmg',2),p['setv']('shotlife',40),p['setv']('shotspeed',12),p['costume']('bowman')),
  p['bc']('begin'))
mv=[('up arrow','w','chy',4),('down arrow','s','chy',-4),('right arrow','d','chx',4),('left arrow','a','chx',-4)]
p['script'](p['onmsg']('begin'),p['forever'](*[p['iff'](p['or_'](p['key'](k1),p['key'](k2)),p[fn](d)) for k1,k2,fn,d in mv]))
p['script'](p['onmsg']('begin'),p['forever'](p['iff'](p['or_'](p['key']('space'),p['mouse']()),p['bc']('fire'),p['wait'](.35))))
rar=[p['setv']('rarity','Common'),p['iff'](p['gt'](V('round'),2),p['setv']('rarity','Rare')),p['iff'](p['gt'](V('round'),4),p['setv']('rarity','Epic')),p['iff'](p['gt'](V('round'),6),p['setv']('rarity','Legendary')),p['iff'](p['gt'](V('round'),8),p['setv']('rarity','Mythic'))]
p['script'](p['onmsg']('begin'),p['forever'](
  p['iff'](p['touch']('Home'),p['setv']('hp',10)),
  p['iff'](p['and_'](p['touch']('Home'),p['eq'](V('carrying'),1)),
     *rar,p['chv']('eggs',1),p['chv']('income',V('round')),p['chv']('coins',p['mul'](p['mul'](25,V('round')),V('mult'))),
     p['setv']('carrying',0),p['setv']('aggro',0),p['sayfor'](p['join']('Pet hatched! Rarity: ',V('rarity')),2),
     p['chv']('round',1),p['bc']('newround'))))
p['script'](p['onmsg']('begin'),p['waituntil'](p['lt'](V('hp'),1)),p['say']('You were defeated! Click the green flag to try again.'),p['stopall']())
p['script'](p['onmsg']('grabbed'),p['sayfor']('Run home!',2))
p['script'](p['onkey']('u'),p['iff'](p['gt'](V('coins'),p['sub'](V('dmgcost'),1)),p['chv']('coins',p['sub'](0,V('dmgcost'))),p['chv']('dmg',1),p['setv']('dmgcost',p['round'](p['mul'](V('dmgcost'),1.6))),p['sayfor']('Damage up!',1)))
p['script'](p['onkey']('r'),p['iff'](p['gt'](V('coins'),p['sub'](p['mul'](500,p['add'](V('rebirth'),1)),1)),p['setv']('coins',0),p['chv']('rebirth',1),p['setv']('mult',p['add'](1,p['mul'](.5,V('rebirth')))),p['sayfor']('REBIRTH! Pets kept, coins x more!',2)))
# Shot
sh=T('Shot');q=mk(sh)
q['script'](q['flag'](),q['hide'](),q['setv']('sclone',0))
q['script'](q['onmsg']('fire'),q['iff'](q['eq'](V('sclone'),0),q['gotospr']('Player'),
  q['costume']('slash'),q['iff'](q['eq'](V('cls'),2),q['costume']('orb')),q['iff'](q['eq'](V('cls'),3),q['costume']('arrow')),
  q['towards']('_mouse_'),q['clone']()))
q['script'](q['onclone'](),q['setv']('sclone',1),q['show'](),q['repeat'](V('shotlife'),q['move'](V('shotspeed'))),q['delclone']())
# Zombie
zb=T('Zombie');z=mk(zb)
z['script'](z['flag'](),z['hide'](),z['setv']('isclone',0))
spawn=lambda:z['repeat'](6,z['clone']())
z['script'](z['onmsg']('begin'),spawn())
z['script'](z['onmsg']('newround'),z['wait'](.3),spawn())
z['script'](z['onmsg']('newround'),z['iff'](z['eq'](V('isclone'),1),z['delclone']()))
z['script'](z['onclone'](),z['setv']('isclone',1),z['setv']('zhp',z['add'](3,z['mul'](2,V('round')))),
  z['gotoxy'](z['rnd'](-40,220),z['rnd'](-150,150)),z['show'](),
  z['forever'](
    z['iff'](z['touch']('Shot'),z['chv']('zhp',z['sub'](0,V('dmg'))),z['wait'](.25)),
    z['iff'](z['lt'](V('zhp'),1),z['chv']('coins',V('mult')),z['delclone']()),
    z['iff'](z['or_'](z['eq'](V('aggro'),1),z['lt'](z['dist']('Player'),110)),z['towards']('Player'),z['move'](z['add'](1,z['add'](z['mul'](V('aggro'),1.3),z['mul'](V('round'),.05))))),
    z['iff'](z['touch']('Player'),z['chv']('hp',-1),z['wait'](.6))))
# Boss
bs=T('Boss');b=mk(bs)
b['script'](b['flag'](),b['hide']())
b['script'](b['onmsg']('begin'),b['setv']('bhp',30),b['gotoxy'](170,100),b['size'](130),b['show'](),b['bc']('fight'))
b['script'](b['onmsg']('newround'),b['wait'](.5),b['setv']('bhp',b['add'](30,b['mul'](10,V('round')))),b['gotoxy'](170,100),b['show'](),b['bc']('fight'))
b['script'](b['onmsg']('fight'),b['until'](b['lt'](V('bhp'),1),
    b['iff'](b['touch']('Shot'),b['chv']('bhp',b['sub'](0,V('dmg'))),b['wait'](.3)),
    b['iff'](b['or_'](b['eq'](V('aggro'),1),b['lt'](b['dist']('Player'),150)),b['towards']('Player'),b['move'](b['add'](.8,V('aggro')))),
    b['iff'](b['touch']('Player'),b['chv']('hp',-2),b['wait'](.7))),
  b['setv']('bx',b['xpos']()),b['setv']('by',b['ypos']()),b['hide'](),b['bc']('eggdrop'))
# Egg
eg=T('Egg');e=mk(eg)
e['script'](e['flag'](),e['hide']())
e['script'](e['onmsg']('eggdrop'),e['gotoxy'](V('bx'),V('by')),e['show'](),e['waituntil'](e['touch']('Player')),e['setv']('carrying',1),e['setv']('aggro',1),e['hide'](),e['bc']('grabbed'))
# Home
hm=T('Home');h=mk(hm)
h['script'](h['flag'](),h['gotoxy'](-190,-125),h['show']())
# ---------------- assemble ----------------
def vars_for(names,locals_=()):
    d={vid(n):[n,0] for n in names}
    return d
bd=reg('forest',backdrop,240,180)
stage={"isStage":True,"name":"Stage","variables":{vid(n):[n,0] for n in GV},"lists":{},"broadcasts":{'bc_'+m:m for m in MSGS},"blocks":finish(st),"comments":{},"currentCostume":0,"costumes":[bd],"sounds":[],"volume":100,"layerOrder":0,"tempo":60,"videoTransparency":50,"videoState":"on","textToSpeechLanguage":None}
def sprite(name,t,costs,x,y,layer,vis,size=100,rot="don't rotate",locals_=()):
    return {"isStage":False,"name":name,"variables":{'loc_'+n:[n,0] for n in locals_},"lists":{},"broadcasts":{},"blocks":finish(t),"comments":{},"currentCostume":0,"costumes":costs,"sounds":[],"volume":100,"layerOrder":layer,"visible":vis,"x":x,"y":y,"size":size,"direction":90,"draggable":False,"rotationStyle":rot}
# local variable ids: zhp/isclone must map to loc_ ids
for t_ in (zb,sh):
    for d in t_.b.values():
        for f in d['fields'].values():
            if f[0] in('zhp','isclone','sclone'):f[1]='loc_'+f[0]
        for k,v in d['inputs'].items():
            if v and v[0]==3 and isinstance(v[1],list) and v[1][1] in('zhp','isclone','sclone'):v[1][2]='loc_'+v[1][1]
sprites=[
 sprite('Home',hm,[reg('home',home,45,40)],-190,-125,1,False),
 sprite('Egg',eg,[reg('egg',egg,14,18)],0,0,2,False),
 sprite('Zombie',zb,[reg('zombie',zombie,18,30)],0,0,3,False,locals_=('zhp','isclone')),
 sprite('Boss',bs,[reg('boss',boss,35,50)],170,100,4,False),
 sprite('Player',pl,[reg('knight',knight,18,30),reg('wizard',wizard,18,33),reg('bowman',bowman,18,30)],-170,-110,5,False),
 sprite('Shot',sh,[reg('slash',shot1,15,15),reg('orb',shot2,11,11),reg('arrow',shot3,17,5)],0,0,6,False,rot="all around",locals_=('sclone',)),
]
mon=[]
for i,(n,lab) in enumerate([('coins','coins'),('eggs','eggs'),('hp','hp'),('round','round'),('income','income'),('mult','mult'),('carrying','carrying')]):
    mon.append({"id":vid(n),"mode":"default","opcode":"data_variable","params":{"VARIABLE":n},"spriteName":None,"value":0,"width":0,"height":0,"x":5,"y":5+i*26,"visible":True})
proj={"targets":[stage]+sprites,"monitors":mon,"extensions":[],"meta":{"semver":"3.0.0","vm":"0.2.0","agent":"Loot the Egg builder"}}
# validate
for tg in proj['targets']:
    for i,d in tg['blocks'].items():
        for k in ('next','parent'):
            assert d[k] is None or d[k] in tg['blocks'],(tg['name'],i,k)
        for k,v in d['inputs'].items():
            if v and v[0] in(1,2,3) and isinstance(v[1],str):assert v[1] in tg['blocks'],(tg['name'],i,k)
with zipfile.ZipFile(OUT,'w',zipfile.ZIP_DEFLATED) as zf:
    zf.writestr('project.json',json.dumps(proj))
    for n,dta in assets.items():zf.writestr(n,dta)
print('ok',sum(len(t['blocks']) for t in proj['targets']),'blocks')

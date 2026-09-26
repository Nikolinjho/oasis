import subprocess, numpy as np
import sys; F=sys.argv[1]
pts=sorted(float(l.strip().strip(',')) for l in open('pts.txt') if l.strip().strip(','))
W,H=116,114
p=subprocess.Popen(['ffmpeg','-loglevel','error','-i',F,'-fps_mode','passthrough','-vf','crop=116:114:624:35,format=gray','-f','rawvideo','-'],stdout=subprocess.PIPE)
prev=None;i=0;ev=[]
while True:
    b=p.stdout.read(W*H)
    if len(b)<W*H: break
    a=np.frombuffer(b,np.uint8).astype(float)
    if prev is not None:
        d=np.abs(a-prev).mean()
        if d>2: ev.append((pts[i],round(d,1),round(a.mean(),1),round(a.std(),1)))
    prev=a;i+=1
# сгруппировать события
grp=[];
for e in ev:
    if grp and e[0]-grp[-1][-1][0]<0.1: grp[-1].append(e)
    else: grp.append([e])
for g in grp:
    if 28<g[0][0]<70: print(f'{g[0][0]:.3f}–{g[-1][0]:.3f}s ({(g[-1][0]-g[0][0])*1000:.0f} мс, {len(g)} кадров) std: '+' '.join(str(x[3]) for x in g[:40]))

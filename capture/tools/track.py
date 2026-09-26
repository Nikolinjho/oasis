# Трекинг габаритов острова: ширина и высота чёрной области у верхнего края, в пунктах (px/2)
import subprocess, sys, json, numpy as np
F = sys.argv[1]
X0, W, H = int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6])  # полоса в пикселях записи
pts = [float(l.strip().strip(',')) for l in open(sys.argv[2]) if l.strip().strip(',')]
pts.sort()
cmd = ['ffmpeg','-loglevel','error','-i',F,'-fps_mode','passthrough','-vf',f'crop={W}:{H}:{X0}:0,format=gray','-f','rawvideo','-']
p = subprocess.Popen(cmd, stdout=subprocess.PIPE)
out = []
i = 0
while True:
    buf = p.stdout.read(W*H)
    if len(buf) < W*H: break
    a = np.frombuffer(buf, np.uint8).reshape(H, W)
    dark = a < 12
    # остров касается верхнего края: берём связную по вертикали колонку от y=0
    col = dark[2]                       # строка чуть ниже края
    xs = np.where(col)[0]
    if len(xs) == 0: out.append(None); i += 1; continue
    # самый длинный непрерывный отрезок тёмных пикселей в строке 2
    splits = np.split(xs, np.where(np.diff(xs) > 3)[0] + 1)
    seg = max(splits, key=len)
    x1, x2 = seg[0], seg[-1]
    cx = (x1 + x2) // 2
    # высота по центральной колонке (±20 px, медиана), обход курсора
    hs = []
    for c in range(max(cx-40,0), min(cx+40,W), 8):
        colv = dark[:, c]
        nz = np.where(~colv)[0]
        hs.append(nz[0] if len(nz) else H)
    h = int(np.median(hs))
    out.append([round(pts[i],4), round((x2-x1+1)/2,1), round(h/2,1), round((x1+X0)/2,1)])
    i += 1
json.dump(out, open(sys.argv[3], 'w'))
print('frames', i)

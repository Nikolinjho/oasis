import json, numpy as np
t = [r for r in json.load(open('track.json')) if r]
T = np.array([r[0] for r in t]); Wd = np.array([r[1] for r in t])
def seg(a, b): m = (T >= a) & (T <= b); return T[m], Wd[m]
def spring(tt, x0, x1, k, c):
    w0 = np.sqrt(k); z = c / (2*np.sqrt(k))
    if z < 1:
        wd = w0*np.sqrt(1-z*z)
        return x1 + (x0-x1)*np.exp(-z*w0*tt)*(np.cos(wd*tt) + z*w0/wd*np.sin(wd*tt))
    return x1 + (x0-x1)*np.exp(-w0*tt)*(1 + w0*tt)
def fit(name, a, b, x0, x1):
    ts, ws = seg(a, b)
    # старт — первый кадр, где ширина ушла от x0 больше чем на 1 pt
    i0 = np.argmax(np.abs(ws - x0) > 1); t0 = ts[i0] - 1/60
    tt = ts - t0; m = tt >= 0
    best = None
    for k in np.arange(50, 601, 5):
        for c in np.arange(5, 61, 0.5):
            e = np.mean((spring(tt[m], x0, x1, k, c) - ws[m])**2)
            if best is None or e < best[0]: best = (e, k, c)
    e, k, c = best; z = c/(2*np.sqrt(k)); resp = 2*np.pi/np.sqrt(k)
    peak = ws.max() if x1 > x0 else ws.min()
    print(f'{name:28s} {x0:.0f}→{x1:.0f}  stiffness={k:.0f} damping={c:.1f}  ζ={z:.2f} response={resp:.3f}s  rmse={np.sqrt(e):.1f}pt  пик={peak:.1f}')







fit('компакт музыки: появление', 92.37, 92.86, 186, 261)
fit('компакт музыки: уход', 111.40, 111.95, 261, 186)
fit('компакт → сжатие перед HUD', 74.89, 75.20, 261, 195)
fit('сжатие → HUD громкости', 75.20, 75.80, 195, 369)
fit('HUD → сжатие', 73.66, 74.04, 369, 199)
fit('сжатие → компакт', 74.03, 74.60, 199, 261)
fit('сжатие → Charging', 99.15, 99.90, 195, 357)
fit('Charging → сжатие', 104.70, 105.06, 357, 200)
fit('раскрытие с музыкой (высота?)', 26.47, 27.30, 189, 370)

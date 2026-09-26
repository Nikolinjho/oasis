# Подгонка пружин по записи 26.09 (track.json рядом): python3 fit.py
import json

import numpy as np

from springfit import fit as fit_segment

t = [r for r in json.load(open('track.json')) if r]
T = np.array([r[0] for r in t]); Wd = np.array([r[1] for r in t])


def seg(a, b):
    m = (T >= a) & (T <= b)
    return T[m], Wd[m]


def fit(name, a, b, x0, x1):
    ts, ws = seg(a, b)
    r = fit_segment(ts, ws, x0, x1)
    k, c = r["stiffness"], r["damping"]
    z = c / (2 * np.sqrt(k)); resp = 2 * np.pi / np.sqrt(k)
    peak = ws.max() if x1 > x0 else ws.min()
    print(f'{name:28s} {x0:.0f}→{x1:.0f}  stiffness={k:.0f} damping={c:.1f}  ζ={z:.2f} response={resp:.3f}s  rmse={r["rmse"]:.1f}pt  пик={peak:.1f}')


fit('клик: раскрытие (ширина)', 61.80, 62.60, 186, 365)
fit('раскрытие #2', 66.15, 66.70, 186, 365)
fit('схлопывание 365→186', 58.28, 59.05, 365, 186)
fit('схлопывание #2', 63.93, 64.70, 365, 186)
fit('схлопывание #3', 66.70, 67.40, 365, 186)
fit('HUD яркости: вход', 68.74, 69.60, 186, 374)
fit('HUD: выход', 77.48, 78.30, 374, 186)

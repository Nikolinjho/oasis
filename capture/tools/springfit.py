"""Модель пружины с массой 1 и её подгонка по треку ширины. Общая для fit.py и compare.py"""
import numpy as np


def spring(tt, x0, x1, k, c):
    """Положение затухающей пружины через tt секунд после старта из x0 к x1"""
    w0 = np.sqrt(k)
    z = c / (2 * np.sqrt(k))
    if z < 1:
        wd = w0 * np.sqrt(1 - z * z)
        return x1 + (x0 - x1) * np.exp(-z * w0 * tt) * (np.cos(wd * tt) + z * w0 / wd * np.sin(wd * tt))
    return x1 + (x0 - x1) * np.exp(-w0 * tt) * (1 + w0 * tt)


def fit(ts, ws, x0, x1, t0_search=False):
    """Перебором подбирает stiffness и damping. Старт — кадр перед первым сдвигом больше 1 pt в сторону x1.
    t0_search=True: запись иногда роняет кадры (интервал >1/60), тогда «кадр перед движением» —
    неверная оценка старта; перебирает несколько кандидатов между последним неподвижным и первым
    сдвинутым кадром и берёт лучший по ошибке. Использует только compare.py — fit.py вызывает fit()
    без этого параметра, его вывод не меняется"""
    ts = np.asarray(ts, dtype=float)
    ws = np.asarray(ws, dtype=float)
    moved = (ws - x0) * np.sign(x1 - x0) > 1
    if not moved.any():
        return None
    i = int(np.argmax(moved))
    if t0_search:
        # от последнего кадра, где ширина ещё у x0 (±0.5 pt): перед ним может быть
        # разрыв записи, а кадр i-1 уже сдвинут меньше чем на 1 pt
        still = np.where(np.abs(ws[:i] - x0) <= 0.5)[0]
        lo = ts[still[-1]] if len(still) else (ts[i - 1] if i > 0 else ts[i] - 1 / 60)
        t0_candidates = np.linspace(lo, ts[i], 12)
    else:
        t0_candidates = [ts[i] - 1 / 60]  # кадр перед движением; частота записи считается 60 fps
    best = None
    for t0 in t0_candidates:
        tt = ts - t0
        m = tt >= 0
        for k in np.arange(50, 601, 5):
            for c in np.arange(5, 61, 0.5):
                e = np.mean((spring(tt[m], x0, x1, k, c) - ws[m]) ** 2)
                if best is None or e < best[0]:
                    best = (e, k, c, t0)
    e, k, c, t0 = best
    return {"stiffness": float(k), "damping": float(c), "rmse": float(np.sqrt(e)), "t0": float(t0)}


def overshoot_pt(x0, x1, k, c):
    """Насколько пружина перелетает цель, в пунктах"""
    xs = spring(np.linspace(0, 3, 3001), x0, x1, k, c)
    beyond = xs.max() - x1 if x1 > x0 else x1 - xs.min()
    return float(max(0.0, beyond))


def settle_time(x0, x1, k, c, band_pt=1.0):
    """Момент, после которого ширина держится в пределах band_pt от цели"""
    tt = np.linspace(0, 3, 3001)
    out = np.abs(spring(tt, x0, x1, k, c) - x1) > band_pt
    return float(tt[np.where(out)[0][-1]]) if out.any() else 0.0

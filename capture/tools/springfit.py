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


def fit(ts, ws, x0, x1):
    """Перебором подбирает stiffness и damping. Старт — кадр перед первым сдвигом больше 1 pt в сторону x1"""
    ts = np.asarray(ts, dtype=float)
    ws = np.asarray(ws, dtype=float)
    moved = (ws - x0) * np.sign(x1 - x0) > 1
    if not moved.any():
        return None
    t0 = ts[np.argmax(moved)] - 1 / 60
    tt = ts - t0
    m = tt >= 0
    best = None
    for k in np.arange(50, 601, 5):
        for c in np.arange(5, 61, 0.5):
            e = np.mean((spring(tt[m], x0, x1, k, c) - ws[m]) ** 2)
            if best is None or e < best[0]:
                best = (e, k, c)
    e, k, c = best
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

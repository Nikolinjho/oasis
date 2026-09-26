"""Сверка записи demo-прогона прототипа с эталоном Alcove.
python3 compare.py <track.json> [targets.json]. Код выхода 1, если хоть один сегмент вне допуска"""
import json
import sys
from pathlib import Path

import numpy as np

from springfit import fit, overshoot_pt, settle_time, spring


def evaluate(T, W, targets):
    T = np.asarray(T, dtype=float)
    W = np.asarray(W, dtype=float)
    anchor, tol = targets["anchor"], targets["tolerance"]

    # плечи острова и чёрный вырез делают ширину покоя в записи больше выреза: вычитаем разницу
    baseline = float(np.median(W[T < T[0] + 0.5]))
    W = W - (baseline - anchor["fromWidth"])

    moved = np.where(W > anchor["fromWidth"] + 2)[0]
    if len(moved) == 0:
        raise ValueError("остров не менял ширину: проверь запись")
    # -1/60: кадр перед детектированным движением; частота записи считается 60 fps (см. measure.sh)
    offset = T[moved[0]] - 1 / 60 - anchor["demoTime"]

    rows = []
    for s in targets["segments"]:
        m = (T >= s["start"] + offset - 0.01) & (T <= s["end"] + offset)
        ts, ws = T[m], W[m]
        row = {"name": s["name"], "x1": s["x1"]}

        x0 = s["x0"]
        if len(ts) > 0:
            # цепочка переходов: предыдущий сегмент мог закончиться раньше или позже
            # своего номинального x1 (задержка на кадр-другой), тогда этот сегмент трогается
            # не с s["x0"], а с фактической точки разворота хода — ищем её в первые 0.1с
            # окна и режем трек на ней, иначе весь ход посчитается «движением» от кадра 0
            d = np.sign(s["x1"] - s["x0"])
            head = ts < ts[0] + 0.1
            i = int(np.argmin(ws[head] * d))
            if (ws[0] - x0) * d > 1 or i > 0:
                ts, ws = ts[i:], ws[i:]
                x0 = float(ws[0])

        got = fit(ts, ws, x0, s["x1"]) if len(ts) > 3 else None
        if got is None:
            row.update(ok=False, note="нет движения")
            rows.append(row)
            continue
        ref = (x0, s["x1"], s["stiffness"], s["damping"])
        ours = (x0, s["x1"], got["stiffness"], got["damping"])
        final = float(np.median(ws[-3:]))
        row.update(
            x0=x0, final=final,
            overshoot=overshoot_pt(*ours), overshoot_ref=overshoot_pt(*ref),
            stiffness=got["stiffness"], damping=got["damping"])
        ok = abs(row["overshoot"] - row["overshoot_ref"]) <= tol["overshootPt"]
        if s.get("settle", True):
            expected = s["x1"]
        else:
            # сегмент прерывается следующей анимацией: цель — где эталонная пружина
            # окажется к тем же кадрам, а не номинальный x1 («~195» в analysis/README.md)
            expected = float(np.median(spring(ts[-3:] - got["t0"], *ref)))
        row["expected"] = expected
        ok = ok and abs(final - expected) <= tol["sizePt"]
        if s.get("settle", True):
            row.update(settle=settle_time(*ours), settle_ref=settle_time(*ref))
            ok = ok and abs(row["settle"] - row["settle_ref"]) * 1000 <= tol["settleMs"]
        row["ok"] = bool(ok)
        rows.append(row)
    return {"baseline": baseline, "offset": float(offset), "rows": rows}


def main():
    if len(sys.argv) < 2:
        print(f"использование: python3 {Path(sys.argv[0]).name} <track.json> [targets.json]", file=sys.stderr)
        return 2
    track = [r for r in json.loads(Path(sys.argv[1]).read_text()) if r]
    targets_path = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).resolve().parent.parent / "targets.json"
    targets = json.loads(targets_path.read_text())
    T = np.array([r[0] for r in track])
    W = np.array([r[1] for r in track])
    result = evaluate(T, W, targets)

    correction = result["baseline"] - targets["anchor"]["fromWidth"]
    print(f"покой в записи {result['baseline']:.1f} pt, поправка {correction:+.1f} pt, старт прогона на {result['offset']:.2f} с записи\n")
    print(f"{'сегмент':22s} {'x0':>5s} {'ширина/цель':>14s} {'перелёт/эталон':>16s} {'затухание, мс':>16s} {'k/c':>11s}  итог")
    for r in result["rows"]:
        if "final" not in r:
            print(f"{r['name']:22s} {r['note']}  FAIL")
            continue
        settle = f"{r['settle'] * 1000:6.0f}/{r['settle_ref'] * 1000:<6.0f}" if "settle" in r else f"{'—':>13s}"
        print(
            f"{r['name']:22s} {r['x0']:5.0f} {r['final']:6.1f}/{r['expected']:<7.1f} {r['overshoot']:6.1f}/{r['overshoot_ref']:<6.1f}"
            f"   {settle}   {r['stiffness']:4.0f}/{r['damping']:<4.1f}  {'ok' if r['ok'] else 'FAIL'}")
    failed = sum(not r["ok"] for r in result["rows"])
    print(f"\n{len(result['rows']) - failed}/{len(result['rows'])} сегментов в допуске")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

"""Сверка записи demo-прогона прототипа с эталоном Alcove.
python3 compare.py <track.json> [targets.json]. Код выхода 1, если хоть один сегмент вне допуска"""
import json
import sys
from pathlib import Path

import numpy as np

from springfit import fit, overshoot_pt, settle_time, spring

LEAD = 0.05  # хвост окна сверх длины сегмента: старт по кадру перед движением точен до кадра
SEARCH = 0.3  # насколько фактический старт сегмента может уйти от номинального
LAG_TOL = 0.1  # допуск задержки старта сегмента относительно медианной задержки прогона, с
CHAIN_TOL = 1 / 30  # допуск паузы сжатие → раскрытие (таймер grow), 2 кадра


def segment_window(T, W, s, offset):
    """Кадры сегмента от его фактического старта и оценка момента старта.
    Общий offset (по первому движению) точен только для первого шага: шаги demo и таймеры
    машины приходят с задержкой до ~0.15 с, а запись статичного экрана роняет кадры (разрыв
    до ~0.1 с перед первым движением), поэтому окно от номинального start резало начало хода.
    Старт ищем в ±SEARCH от номинала: первые два шага подряд больше 0.5 pt в сторону x1.
    Если окно поиска открылось уже посреди хода, отходим назад к кадру покоя или разворота:
    x0 не должен оказаться серединой движения. Такой старт уйдёт за SEARCH, и его поймает
    проверка задержки. Возвращает (ts, ws, t_move) или None, если старт не найден"""
    d = np.sign(s["x1"] - s["x0"])
    nominal = s["start"] + offset
    idx = np.where((T >= nominal - SEARCH) & (T <= nominal + SEARCH))[0]
    for i in idx:
        if i + 2 < len(T) and (W[i + 1] - W[i]) * d > 0.5 and (W[i + 2] - W[i + 1]) * d > 0.5:
            while i > 0 and (W[i] - W[i - 1]) * d > 0.5:
                i -= 1
            # движение началось не раньше кадра перед первым сдвинутым: при разрыве записи
            # перед ним T[i] — давний кадр покоя, и хвост окна от него съел бы конец хода
            t_move = max(T[i], T[i + 1] - 1 / 60)
            # прерываемый сегмент без хвоста: сразу за ним разворот следующего
            tail = LEAD if s.get("settle", True) else 0
            m = (T >= T[i]) & (T <= t_move + (s["end"] - s["start"]) + tail)
            return T[m], W[m], t_move
    return None


def evaluate(T, W, targets):
    T = np.asarray(T, dtype=float)
    W = np.asarray(W, dtype=float)
    anchor, tol = targets["anchor"], targets["tolerance"]

    # anchor.fromWidth уже посчитан по rowWidth (тело плюс ушки на строке track.py), так что для
    # наших записей correction обычно ~0: правит только дрейф самой записи (шум трекера, другой notch
    # на машине записи), а не системную разницу тела и выреза, как было до вывода целей из геометрии
    baseline = float(np.median(W[T < T[0] + 0.5]))
    correction = baseline - anchor["fromWidth"]
    if abs(correction) > 1:
        print(f"warning: baseline на {correction:+.2f} pt от anchor.fromWidth — проверь notch или запись", file=sys.stderr)
    W = W - correction

    moved = np.where(W > anchor["fromWidth"] + 2)[0]
    if len(moved) == 0:
        raise ValueError("остров не менял ширину: проверь запись")
    # -1/60: кадр перед детектированным движением; частота записи считается 60 fps (см. measure.sh)
    offset = T[moved[0]] - 1 / 60 - anchor["demoTime"]

    rows = []
    for s in targets["segments"]:
        row = {"name": s["name"], "x1": s["x1"], "nominal": s["start"] + offset}
        window = segment_window(T, W, s, offset)
        if window is None:
            row.update(ok=False, note=f"нет движения: старт не найден в ±{SEARCH} с от номинала")
            rows.append(row)
            continue
        ts, ws, t_move = window
        # x0 — фактическая ширина в кадре перед стартом: прошлый сегмент мог закончиться
        # раньше или позже номинального x1 (цепочка сжатие → раскрытие разворачивается по факту)
        x0 = float(ws[0])
        got = fit(ts, ws, x0, s["x1"], t0_search=True) if len(ts) > 3 else None
        if got is None:
            row.update(ok=False, note="нет движения")
            rows.append(row)
            continue
        ref = (x0, s["x1"], s["stiffness"], s["damping"])
        ours = (x0, s["x1"], got["stiffness"], got["damping"])
        final = float(np.median(ws[-3:]))
        row.update(
            x0=x0, final=final, t0=got["t0"], lag=got["t0"] - row["nominal"],
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

    # тайминг: старт ищется по факту, поэтому его надо сверять отдельно. Общий сдвиг всех
    # сегментов (~-0.1 с — смещение anchor из-за разрыва кадров) не ошибка, выпадение одного — да
    lags = [r["lag"] for r in rows if "lag" in r]
    median_lag = float(np.median(lags)) if lags else 0.0
    for r in rows:
        if "lag" in r and abs(r["lag"] - median_lag) > LAG_TOL:
            r["ok"] = False
            r["timing"] = "старт"
    # цепочка сжатие → раскрытие: пауза между стартами — таймер grow (IslandTiming.shrink),
    # номинал берём из самих targets (start раскрытия − start сжатия)
    for s, nxt, r, rn in zip(targets["segments"], targets["segments"][1:], rows, rows[1:]):
        if s["to"] == "shrink" and nxt["from"] == "shrink" and "t0" in r and "t0" in rn:
            rn["chain"] = rn["t0"] - r["t0"]
            rn["chain_ref"] = nxt["start"] - s["start"]
            if abs(rn["chain"] - rn["chain_ref"]) > CHAIN_TOL:
                rn["ok"] = False
                rn["timing"] = "пауза"
    return {"baseline": baseline, "offset": float(offset), "median_lag": median_lag, "rows": rows}


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
    print(f"медианная задержка старта {result['median_lag'] * 1000:+.0f} мс, допуск отклонения ±{LAG_TOL * 1000:.0f} мс; "
          f"пауза сжатие → раскрытие ±{CHAIN_TOL * 1000:.0f} мс\n")
    print(f"{'сегмент':22s} {'x0':>5s} {'ширина/цель':>14s} {'перелёт/эталон':>16s} {'затухание, мс':>16s} {'k/c':>11s}"
          f" {'старт, мс':>10s} {'пауза, мс':>10s}  итог")
    for r in result["rows"]:
        if "final" not in r:
            print(f"{r['name']:22s} {r['note']}  FAIL")
            continue
        chain = f"{r['chain'] * 1000:.0f}/{r['chain_ref'] * 1000:.0f}" if "chain" in r else "—"
        settle = f"{r['settle'] * 1000:6.0f}/{r['settle_ref'] * 1000:<6.0f}" if "settle" in r else f"{'—':>13s}"
        print(
            f"{r['name']:22s} {r['x0']:5.0f} {r['final']:6.1f}/{r['expected']:<7.1f} {r['overshoot']:6.1f}/{r['overshoot_ref']:<6.1f}"
            f"   {settle}   {r['stiffness']:4.0f}/{r['damping']:<4.1f} {r['lag'] * 1000:+10.0f} {chain:>10s}"
            f"  {'ok' if r['ok'] else 'FAIL'}{' (' + r['timing'] + ')' if 'timing' in r else ''}")
    failed = sum(not r["ok"] for r in result["rows"])
    print(f"\n{len(result['rows']) - failed}/{len(result['rows'])} сегментов в допуске")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

"""Тесты подгонки пружин и сверки с эталоном: python3 -m unittest test_springfit -v (из capture/tools)"""
import copy
import json
import unittest
from pathlib import Path

import numpy as np

from compare import evaluate
from springfit import fit, overshoot_pt, settle_time, spring

TARGETS = json.loads((Path(__file__).resolve().parent.parent / "targets.json").read_text())


def synthetic_track(targets, extra=0.0, fps=60, lead=2.0, override=None):
    """Трек ширины из самих targets, непрерывный по позиции: следующий сегмент стартует не с
    номинального x0, а с фактического значения хода в момент своего начала (скорость не
    сохраняем — только позицию). Так же ведёт себя реальная запись, где границы сегментов
    не всегда совпадают идеально с моментом разворота.
    override — {"name", "stiffness", "damping"}: подменяет пружину одного сегмента в самом
    треке, чтобы проверить, что сверка ловит расхождение с эталоном.
    Упрощение: между «раскрытие в компакт» (261) и «раскрытие плеера» (номинальный x0=190)
    реального промежуточного hover-сжатия к ~190×73 здесь нет (см. analysis/README.md) — трек
    просто держит 261 до начала сегмента плеера, а точку разворота находит сверка по факту"""
    segments = sorted(targets["segments"], key=lambda s: s["start"])
    ts = np.arange(0, segments[-1]["end"] + 1.0 + lead, 1 / fps)
    ws = np.empty_like(ts)

    value = float(segments[0]["x0"])  # текущее фактическое значение хода
    active = None                     # индекс сегмента, чья пружина сейчас считается
    start_t = 0.0                     # demo-время фактического старта active
    start_x0 = value                  # фактическое значение хода в start_t

    for i, t in enumerate(ts):
        demo_t = t - lead
        idx = None
        for j, s in enumerate(segments):
            if s["start"] <= demo_t <= s["end"]:
                idx = j
                break
            if demo_t < s["start"]:
                break
        if idx is not None and idx != active:
            active = idx
            start_t = demo_t
            start_x0 = value
        if active is not None and demo_t <= segments[active]["end"]:
            s = segments[active]
            k, c = s["stiffness"], s["damping"]
            if override and s["name"] == override["name"]:
                k = override.get("stiffness", k)
                c = override.get("damping", c)
            value = spring(demo_t - start_t, start_x0, s["x1"], k, c)
        # иначе (гэп между сегментами) держим value как есть — плато на месте разворота
        ws[i] = value + extra
    return ts, ws


class SpringFitTests(unittest.TestCase):
    def test_recovers_open_spring(self):
        """Подгонка восстанавливает пружину раскрытия 175/16"""
        ts = np.arange(0, 1.2, 1 / 60)
        start = 12 / 60
        ws = np.where(ts < start, 186.0, spring(np.clip(ts - start, 0, None), 186, 365, 175, 16))
        got = fit(ts, ws, 186, 365)
        self.assertAlmostEqual(got["stiffness"], 175, delta=10)
        self.assertAlmostEqual(got["damping"], 16, delta=1.5)

    def test_no_motion(self):
        """Без движения подгонять нечего"""
        ts = np.arange(0, 1, 1 / 60)
        self.assertIsNone(fit(ts, np.full_like(ts, 186.0), 186, 365))

    def test_overshoot_matches_measurement(self):
        """Перелёт раскрытия 175/16 около +17 pt, как в записи Alcove"""
        self.assertTrue(15 <= overshoot_pt(186, 365, 175, 16) <= 18)

    def test_critical_has_no_overshoot(self):
        self.assertEqual(overshoot_pt(365, 186, 250, 32), 0)

    def test_settle_time_of_smooth(self):
        """.smooth(0.4) на ходе 179 pt входит в полосу 1 pt примерно за 0.46 с"""
        self.assertTrue(0.42 <= settle_time(365, 186, 246.7, 31.4) <= 0.5)


class CompareTests(unittest.TestCase):
    def test_reference_track_passes(self):
        """Трек из самих эталонных пружин проходит все сегменты"""
        ts, ws = synthetic_track(TARGETS)
        result = evaluate(ts, ws, TARGETS)
        failed = [r["name"] for r in result["rows"] if not r["ok"]]
        self.assertEqual(failed, [])
        self.assertEqual(len(result["rows"]), len(TARGETS["segments"]))

    def test_idle_offset_is_corrected(self):
        """anchor.fromWidth уже посчитан по rowWidth (тело плюс ушки): смоделированный сдвиг +6 pt —
        это дрейф самой записи (шум трекера, другой notch на машине записи), не системная разница
        тела и выреза. Сверка всё равно вычитает поправку и возвращает данные к нашей геометрии"""
        ts, ws = synthetic_track(TARGETS, extra=6)
        result = evaluate(ts, ws, TARGETS)
        self.assertAlmostEqual(result["baseline"], TARGETS["anchor"]["fromWidth"] + 6, delta=0.01)
        self.assertTrue(all(r["ok"] for r in result["rows"]))

    def test_interrupted_segment_checks_against_reference(self):
        """Сегмент settle:false тоже сверяется по ширине — с эталонной пружиной на тех же кадрах,
        а не только по перелёту: неверная пружина в записи должна проваливать сверку"""
        ts, ws = synthetic_track(TARGETS, override={"name": "сжатие после HUD", "stiffness": 120, "damping": 30})
        result = evaluate(ts, ws, TARGETS)
        row = next(r for r in result["rows"] if r["name"] == "сжатие после HUD")
        self.assertFalse(row["ok"])

    def test_late_chain_handoff_still_passes(self):
        """Прототип может закончить «сжатие после HUD» на кадр позже номинального конца
        сегмента: следующий сегмент цепочки («раскрытие в компакт») должен всё равно
        сверяться с фактической точки разворота, а не с номинального x0=195"""
        stretched = copy.deepcopy(TARGETS)
        for s in stretched["segments"]:
            if s["name"] == "сжатие после HUD":
                s["end"] += 1 / 60
        ts, ws = synthetic_track(stretched)
        result = evaluate(ts, ws, TARGETS)
        failed = [r["name"] for r in result["rows"] if not r["ok"]]
        self.assertEqual(failed, [])

    def test_quantised_dropped_frames_pass(self):
        """Реальная запись квантуется до 0.5pt (ретина, px/2) и роняет кадры (track.py пишет
        None, где ffmpeg не смог прочитать кадр) — сверка должна это выдерживать"""
        ts, ws = synthetic_track(TARGETS)
        ws = np.round(ws * 2) / 2
        keep = np.arange(len(ts)) % 8 != 5  # каждый 8-й кадр выпал
        ts, ws = ts[keep], ws[keep]
        result = evaluate(ts, ws, TARGETS)
        failed = [r["name"] for r in result["rows"] if not r["ok"]]
        self.assertEqual(failed, [], f"провалились: {failed}")


if __name__ == "__main__":
    unittest.main()

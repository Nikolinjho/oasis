"""Тесты подгонки пружин и сверки с эталоном: python3 -m unittest test_springfit -v (из capture/tools)"""
import json
import unittest
from pathlib import Path

import numpy as np

from compare import evaluate
from springfit import fit, overshoot_pt, settle_time, spring

TARGETS = json.loads((Path(__file__).resolve().parent.parent / "targets.json").read_text())


def synthetic_track(targets, extra=0.0, fps=60, lead=2.0, override=None):
    """Трек ширины из самих targets: до сегмента держим его x0, внутри — эталонная пружина.
    override — {"name", "stiffness", "damping"}: подменяет пружину одного сегмента в самом
    треке, чтобы проверить, что сверка ловит расхождение с эталоном"""
    segments = sorted(targets["segments"], key=lambda s: s["start"])
    ts = np.arange(0, segments[-1]["end"] + 1.0 + lead, 1 / fps)
    ws = np.empty_like(ts)
    for i, t in enumerate(ts):
        demo_t = t - lead
        value = segments[-1]["x1"]
        for s in segments:
            if demo_t < s["start"]:
                value = s["x0"]
                break
            if demo_t <= s["end"]:
                k, c = s["stiffness"], s["damping"]
                if override and s["name"] == override["name"]:
                    k, c = override["stiffness"], override["damping"]
                value = spring(demo_t - s["start"], s["x0"], s["x1"], k, c)
                break
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
        """Плечи делают покой в записи шире выреза: поправка вычитается"""
        ts, ws = synthetic_track(TARGETS, extra=6)
        result = evaluate(ts, ws, TARGETS)
        self.assertAlmostEqual(result["baseline"], 192, delta=0.01)
        self.assertTrue(all(r["ok"] for r in result["rows"]))

    def test_interrupted_segment_checks_against_reference(self):
        """Сегмент settle:false тоже сверяется по ширине — с эталонной пружиной на тех же кадрах,
        а не только по перелёту: неверная пружина в записи должна проваливать сверку"""
        ts, ws = synthetic_track(TARGETS, override={"name": "сжатие после HUD", "stiffness": 120, "damping": 30})
        result = evaluate(ts, ws, TARGETS)
        row = next(r for r in result["rows"] if r["name"] == "сжатие после HUD")
        self.assertFalse(row["ok"])


if __name__ == "__main__":
    unittest.main()

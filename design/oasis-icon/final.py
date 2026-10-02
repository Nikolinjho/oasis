#!/usr/bin/env python3
# Финальная иконка Oasis: C3 (росток из выреза) с жёлтым островом.
# Запуск: python3 final.py → final/*.svg, PNG-превью и ресурсы бандла:
# app/Resources/AppIcon.icns и app/Resources/MenuBarIcon.png / MenuBarIcon@2x.png (template, 18 pt)
import os
import subprocess
import tempfile

from gen import grad, squircle
from gen3 import geo_palm, mono_c, render

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "final")
RES = os.path.join(HERE, "..", "..", "app", "Resources")
os.makedirs(OUT, exist_ok=True)


def app(p="f"):
    return f"""<defs>{grad(p+'bg', [(0, '#26282D'), (1, '#0E0F12')])}</defs>
{squircle(p, f'url(#{p}bg)')}
<rect x="312" y="600" width="400" height="120" rx="60" fill="#F7D774"/>
{geo_palm(512, 606, 530, 380, -30, 30, 95, '#E9A866', '#7ED957')}"""


if __name__ == "__main__":
    s = os.path.join(OUT, "oasis-app.svg")
    open(s, "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">{app()}</svg>')
    m = os.path.join(OUT, "oasis-menubar.svg")
    open(m, "w").write(mono_c(3, "#000", "m"))
    for w in (1024, 256, 64, 32):
        render(s, os.path.join(OUT, f"oasis-app-{w}.png"), w)
    # icns: все размеры iconset рисуются из вектора, а не уменьшаются из 1024
    with tempfile.TemporaryDirectory() as tmp:
        iconset = os.path.join(tmp, "AppIcon.iconset")
        os.makedirs(iconset)
        for pt in (16, 32, 128, 256, 512):
            render(s, os.path.join(iconset, f"icon_{pt}x{pt}.png"), pt)
            render(s, os.path.join(iconset, f"icon_{pt}x{pt}@2x.png"), pt * 2)
        subprocess.run(["iconutil", "-c", "icns", iconset, "-o", os.path.join(RES, "AppIcon.icns")], check=True)
    render(m, os.path.join(RES, "MenuBarIcon.png"), 18)
    render(m, os.path.join(RES, "MenuBarIcon@2x.png"), 36)
    print("ok")

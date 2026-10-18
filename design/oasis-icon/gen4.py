#!/usr/bin/env python3
# Четвёртый раунд: C2, остров в форме выреза (нотча) — плоский верх с «ушками», скруглённый низ.
# Запуск: python3 gen4.py → svg/r4-*.svg, png/r4-*.png, sheet4.svg, sheet4.png
import os
import subprocess

from gen import HERE, PNG, SVG, f, squircle
from gen2 import mask_svg
from gen3 import geo_palm, inner, render


def notch(x0, y0, w, h, r, e):
    # силуэт выреза: верх по линии y0, ушки радиусом e снаружи, нижние углы радиусом r
    x1 = x0 + w
    y1 = y0 + h
    return (f"M{f(x0-e)} {f(y0)} H{f(x1+e)} Q{f(x1)} {f(y0)} {f(x1)} {f(y0+e)} "
            f"V{f(y1-r)} Q{f(x1)} {f(y1)} {f(x1-r)} {f(y1)} H{f(x0+r)} "
            f"Q{f(x0)} {f(y1)} {f(x0)} {f(y1-r)} V{f(y0+e)} Q{f(x0)} {f(y0)} {f(x0-e)} {f(y0)}Z")


def scene(p, island, palm_trunk="#E9A866", leaf="#1DBFA6", lines="#62B6F5", bg="#FBF3E4"):
    return f"""{squircle(p, bg)}
<rect x="212" y="752" width="600" height="18" rx="9" fill="{lines}"/>
<rect x="342" y="796" width="340" height="18" rx="9" fill="{lines}"/>
<path d="{notch(262, 640, 500, 78, 36, 26)}" fill="{island}"/>
{geo_palm(532, 646, 496, 330, 34, 42, 128, palm_trunk, leaf)}"""


def d1(p):
    """C2: песочный остров-нотч"""
    return scene(p, "#F7D774")


def d2(p):
    """C2: чёрный остров-нотч, как настоящий вырез"""
    return scene(p, "#111214")


def d3(p):
    """C2 на тёмном: чёрный нотч на графите, зелёная пальма"""
    return scene(p, "#000000", leaf="#7ED957", lines="#3A8FD6", bg="#1C1E22")


def mono_d(color, mid):
    keep = ('<rect x="6" y="51" width="52" height="3.6" rx="1.8"/><rect x="18" y="57" width="28" height="3.6" rx="1.8"/>'
            f'<path d="{notch(13, 41, 38, 7, 3, 2.6)}"/>' + geo_palm(33, 42, 30, 16, 3, 4.6, 11.5, "#fff", "#fff"))
    return mask_svg(keep, "", color, mid)


R4 = [("d1", "Песочный нотч", d1), ("d2", "Чёрный нотч", d2), ("d3", "Чёрный нотч на графите", d3)]

if __name__ == "__main__":
    for key, name, fn in R4:
        s = os.path.join(SVG, f"r4-{key}-app.svg")
        open(s, "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">{fn(key)}</svg>')
        render(s, os.path.join(PNG, f"r4-{key}-app-1024.png"), 1024)
    m = os.path.join(SVG, "r4-menubar.svg")
    open(m, "w").write(mono_d("#000", "md"))
    render(m, os.path.join(PNG, "r4-menubar-36.png"), 36)

    W, ROW = 1500, 330
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{ROW*len(R4)+40}">'
             f'<rect width="100%" height="100%" fill="#F4F4F6"/>']
    for i, (key, name, fn) in enumerate(R4):
        y = 20 + i * ROW
        parts.append(f'<text x="30" y="{y+30}" font-family="Helvetica" font-size="26" font-weight="bold" fill="#222">{key.upper()}. {name}</text>')
        for (x, yy, sz, sfx) in [(30, 45, 270, "s"), (320, 165, 128, "t"), (470, 229, 64, "u"), (550, 261, 32, "w")]:
            parts.append(f'<svg x="{x}" y="{y+yy}" width="{sz}" height="{sz}" viewBox="0 0 1024 1024">{fn(sfx+key)}</svg>')
        for j, (bg, fg) in enumerate([("#ECECEE", "#000"), ("#1E1E20", "#fff")]):
            bx = 640 + j * 420
            parts.append(f'<rect x="{bx}" y="{y+60}" width="390" height="44" rx="8" fill="{bg}"/>')
            parts.append(f'<svg x="{bx+20}" y="{y+73}" width="18" height="18" viewBox="0 0 64 64">{inner(mono_d(fg, f"k{key}{j}"))}</svg>')
            parts.append(f'<text x="{bx+50}" y="{y+88}" font-family="Helvetica" font-size="14" fill="{fg}" opacity=".6">18 pt</text>')
            parts.append(f'<rect x="{bx}" y="{y+120}" width="170" height="170" rx="12" fill="{bg}"/>')
            parts.append(f'<svg x="{bx+20}" y="{y+140}" width="130" height="130" viewBox="0 0 64 64">{inner(mono_d(fg, f"l{key}{j}"))}</svg>')
    parts.append("</svg>")
    sheet = os.path.join(HERE, "sheet4.svg")
    open(sheet, "w").write("".join(parts))
    subprocess.run(["rsvg-convert", "-o", os.path.join(HERE, "sheet4.png"), sheet], check=True)
    print("ok")

#!/usr/bin/env python3
# Третий раунд: минималистичные варианты — 2–3 цвета, крупные простые формы, много воздуха.
# Запуск: python3 gen3.py → svg/r3-*.svg, png/r3-*.png, sheet3.svg, sheet3.png
import os
import subprocess

from gen import HERE, PNG, SVG, f, grad, mpalm, squircle
from gen2 import mask_svg

CLIP = '<clipPath id="{p}clip"><rect x="100" y="100" width="824" height="824" rx="186"/></clipPath>'


def geo_crown(cx, cy, r, fill, leaves=((-68, .95, .10), (-28, 1.12, .32), (12, 1.0, .55))):
    # крона из отдельных изогнутых листьев с просветами: лист — сужающийся серп от центра кроны
    out = []
    for a, k, droop in leaves:
        L = r * 1.55 * k
        W = r * .32
        D = L * droop
        d = (f"M0 0 Q{f(L*.45)} {f(-W*1.6)} {f(L)} {f(D)} "
             f"Q{f(L*.5)} {f(-W*.2+D*.35)} 0 {f(W*.55)}Z")
        for sx in ("", "scale(-1 1) "):
            out.append(f'<path d="{d}" fill="{fill}" transform="translate({f(cx)} {f(cy)}) {sx}rotate({a})"/>')
    out.append(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r*.2)}" fill="{fill}"/>')
    return "".join(out)


def geo_trunk(bx, by, tx, ty, bend, w, color):
    qx, qy = (bx + tx) / 2 + bend, (by + ty) / 2
    return (f'<path d="M{f(bx)} {f(by)} Q{f(qx)} {f(qy)} {f(tx)} {f(ty)}" stroke="{color}" '
            f'stroke-width="{f(w)}" stroke-linecap="round" fill="none"/>')


def geo_palm(bx, by, tx, ty, bend, w, r, trunk_c, leaf_c):
    return geo_trunk(bx, by, tx, ty, bend, w, trunk_c) + geo_crown(tx, ty, r, leaf_c)


# --- цветные -----------------------------------------------------------------

def c1(p):
    """Белая пальма на глубокой бирюзе, песок одной дугой"""
    return f"""{squircle(p, '#0E7C86')}
<path d="M300 720 Q512 640 724 720Z" fill="#F6D7A0"/>
{geo_palm(505, 700, 530, 400, -40, 38, 120, '#FFFFFF', '#FFFFFF')}"""


def c2(p):
    """Геометрическая пальма из полукругов на тёплом светлом"""
    return f"""{squircle(p, '#FBF3E4')}
<path d="M290 740 A222 222 0 0 1 734 740Z" fill="#F7D774"/>
<rect x="250" y="770" width="524" height="18" rx="9" fill="#62B6F5"/>
<rect x="360" y="812" width="304" height="18" rx="9" fill="#62B6F5"/>
{geo_palm(520, 640, 470, 360, 40, 40, 115, '#E9A866', '#1DBFA6')}"""


def c3(p):
    """Чёрная плитка, маленький вырез-таблетка и зелёный росток пальмы из неё"""
    return f"""<defs>{grad(p+'bg', [(0, '#26282D'), (1, '#0E0F12')])}</defs>
{squircle(p, f'url(#{p}bg)')}
<rect x="312" y="600" width="400" height="120" rx="60" fill="#000"/>
<rect x="312" y="600" width="400" height="120" rx="60" fill="none" stroke="#3A3E46" stroke-width="5"/>
{geo_palm(512, 606, 530, 380, -30, 30, 95, '#E9A866', '#7ED957')}"""


def c4(p):
    """Пальма в круге: силуэт вырезан из диска лагуны"""
    return f"""<defs>{grad(p+'bg', [(0, '#7FE0D4'), (1, '#2CB5C9')])}
<mask id="{p}m"><circle cx="512" cy="520" r="290" fill="#fff"/>
<g fill="#000" stroke="#000">{geo_palm(500, 760, 535, 420, -40, 34, 110, '#000', '#000')}
<path d="M290 700 Q512 620 734 700 L734 900 L290 900Z"/></g></mask></defs>
{squircle(p, f'url(#{p}bg)')}
<rect x="100" y="100" width="824" height="824" fill="#FFFFFF" mask="url(#{p}m)"/>"""


def c5(p):
    """Буква O из песка и один зелёный лист сверху"""
    leaf = "M0 0 C40 -70 140 -90 220 -40 C150 -10 70 10 0 0Z"
    return f"""{squircle(p, '#1F8FB8')}
<circle cx="512" cy="560" r="230" fill="none" stroke="#F6D7A0" stroke-width="84"/>
<path d="{leaf}" fill="#8EE06A" transform="translate(512 340) rotate(-20)"/>
<path d="{leaf}" fill="#5CC44A" transform="translate(512 340) scale(-1 1) rotate(-35)"/>"""


def c6(p):
    """Таблетка и пальма двумя цветами на белом"""
    return f"""{squircle(p, '#FFFFFF')}
<rect x="232" y="620" width="560" height="150" rx="75" fill="#111214"/>
{geo_palm(500, 625, 525, 360, -35, 34, 105, '#111214', '#111214')}"""


def c7(p):
    """Горизонт: песчаный полукруг, бирюзовая вода, одна пальма — три цвета"""
    return f"""<defs>{CLIP.format(p=p)}</defs>
{squircle(p, '#E8F6F3')}
<g clip-path="url(#{p}clip)">
<rect x="100" y="660" width="824" height="270" fill="#2BB3A6"/>
<path d="M250 660 A262 120 0 0 1 774 660Z" fill="#F4C27A"/>
{geo_palm(500, 610, 530, 330, -40, 36, 115, '#C9824A', '#2BB3A6')}
</g>"""


# --- монохромы (viewBox 64) ----------------------------------------------------


def mono_c(n, color, mid):
    gp = lambda *a: geo_palm(*a, "#fff", "#fff")  # noqa: E731
    if n == 1:
        return mask_svg('<path d="M14 54 Q32 46 50 54Z"/>' + gp(32, 52, 34, 20, -4, 4.5, 11), "", color, mid)
    if n == 2:
        return mask_svg('<path d="M14 50 A18 18 0 0 1 50 50Z"/><rect x="10" y="53" width="44" height="3.5" rx="1.75"/>'
                        '<rect x="20" y="58" width="24" height="3.5" rx="1.75"/>' + gp(34, 40, 30, 18, 3, 4.5, 10.5),
                        "", color, mid)
    if n == 3:
        return mask_svg('<rect x="8" y="40" width="48" height="16" rx="8"/>' + gp(32, 42, 34, 16, -3, 4, 10.5),
                        "", color, mid)
    if n == 4:
        return mask_svg('<circle cx="32" cy="32" r="28"/>',
                        geo_palm(31, 56, 34, 22, -4, 4.5, 11, "#000", "#000") +
                        '<path d="M8 46 Q32 38 56 46 L56 64 L8 64Z"/>', color, mid)
    if n == 5:
        return mask_svg('<circle cx="32" cy="36" r="19" fill="none" stroke="#fff" stroke-width="8"/>'
                        '<path d="M0 0 C4 -7 14 -9 22 -4 C15 -1 7 1 0 0Z" transform="translate(32 13) rotate(-20)"/>'
                        '<path d="M0 0 C4 -7 14 -9 22 -4 C15 -1 7 1 0 0Z" transform="translate(32 13) scale(-1 1) rotate(-35)"/>',
                        "", color, mid)
    if n == 6:
        return mask_svg('<rect x="6" y="40" width="52" height="16" rx="8"/>' + gp(31, 42, 33, 14, -3, 4.5, 11),
                        "", color, mid)
    if n == 7:
        return mask_svg('<path d="M10 48 A22 10 0 0 1 54 48Z"/><rect x="4" y="52" width="56" height="4" rx="2"/>'
                        + gp(31, 44, 34, 16, -4, 4.5, 11), "", color, mid)


R3 = [
    ("c1", "Белая пальма на бирюзе", c1), ("c2", "Остров-полукруг и горизонт", c2),
    ("c3", "Росток из выреза", c3), ("c4", "Пальма, вырезанная из диска", c4),
    ("c5", "Буква O и лист", c5), ("c6", "Таблетка и пальма, два цвета", c6),
    ("c7", "Горизонт в три цвета", c7),
]


def inner(svg):
    return svg[svg.index(">") + 1:-6]


def render(src, out, w):
    subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(w), "-o", out, src], check=True)


if __name__ == "__main__":
    for i, (key, name, fn) in enumerate(R3, 1):
        s = os.path.join(SVG, f"r3-{key}-app.svg")
        open(s, "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">{fn(key)}</svg>')
        render(s, os.path.join(PNG, f"r3-{key}-app-1024.png"), 1024)
        m = os.path.join(SVG, f"r3-{key}-menubar.svg")
        open(m, "w").write(mono_c(i, "#000", f"m{key}"))
        render(m, os.path.join(PNG, f"r3-{key}-menubar-36.png"), 36)

    W, ROW = 1500, 330
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{ROW*len(R3)+40}">'
             f'<rect width="100%" height="100%" fill="#F4F4F6"/>']
    for i, (key, name, fn) in enumerate(R3):
        y = 20 + i * ROW
        parts.append(f'<text x="30" y="{y+30}" font-family="Helvetica" font-size="26" font-weight="bold" fill="#222">{key.upper()}. {name}</text>')
        for (x, yy, sz, sfx) in [(30, 45, 270, "s"), (320, 165, 128, "t"), (470, 229, 64, "u"), (550, 261, 32, "w")]:
            parts.append(f'<svg x="{x}" y="{y+yy}" width="{sz}" height="{sz}" viewBox="0 0 1024 1024">{fn(sfx+key)}</svg>')
        for j, (bg, fg) in enumerate([("#ECECEE", "#000"), ("#1E1E20", "#fff")]):
            bx = 640 + j * 420
            parts.append(f'<rect x="{bx}" y="{y+60}" width="390" height="44" rx="8" fill="{bg}"/>')
            parts.append(f'<svg x="{bx+20}" y="{y+73}" width="18" height="18" viewBox="0 0 64 64">{inner(mono_c(i+1, fg, f"k{key}{j}"))}</svg>')
            parts.append(f'<text x="{bx+50}" y="{y+88}" font-family="Helvetica" font-size="14" fill="{fg}" opacity=".6">18 pt</text>')
            parts.append(f'<rect x="{bx}" y="{y+120}" width="170" height="170" rx="12" fill="{bg}"/>')
            parts.append(f'<svg x="{bx+20}" y="{y+140}" width="130" height="130" viewBox="0 0 64 64">{inner(mono_c(i+1, fg, f"l{key}{j}"))}</svg>')
    parts.append("</svg>")
    sheet = os.path.join(HERE, "sheet3.svg")
    open(sheet, "w").write("".join(parts))
    subprocess.run(["rsvg-convert", "-o", os.path.join(HERE, "sheet3.png"), sheet], check=True)
    print("ok")

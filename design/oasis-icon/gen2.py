#!/usr/bin/env python3
# Второй раунд: пара «цветной 3 + монохром 1» и вариации на тему 6 (остров под вырезом).
# Запуск: python3 gen2.py → svg/r2-*.svg, png/r2-*.png, sheet2.svg, sheet2.png
import os
import subprocess

from gen import GREEN, HERE, PNG, SVG, f, grad, mono_svg, mpalm, palm, squircle, waves

CLIP = '<clipPath id="{p}clip"><rect x="100" y="100" width="824" height="824" rx="186"/></clipPath>'


def silhouette(color):
    return {"leafDark": color, "leafLight": color, "trunk": color, "trunkShade": None, "stripe": None}


# --- пара 3 + 1 ----------------------------------------------------------------

def a1(p):
    """Плоский круг (3) + волны под островом, как у монохрома 1"""
    c3 = {"leafDark": "#2E8B57", "leafLight": "#5DBB63", "trunk": "#FF6B35",
          "trunkShade": "#C4532A", "stripe": None}
    return f"""
<defs>{CLIP.format(p=p)}<clipPath id="{p}circ"><circle cx="512" cy="512" r="330"/></clipPath></defs>
{squircle(p, '#0F6F7A')}
<g clip-path="url(#{p}clip)">
<circle cx="512" cy="512" r="330" fill="#A8E3EC"/>
<g clip-path="url(#{p}circ)">
<path d="M330 330 L560 280 L1000 720 L800 1000Z" fill="#7DC7D6"/>
<rect x="150" y="700" width="740" height="200" fill="#2BA3C4"/>
<path d="M512 700 L900 700 L900 900 L700 900Z" fill="#2391B0"/>
{waves(770, 170, 860, 12, 60, '#A8E3EC', 12)}
<path d="M300 720 Q512 610 724 720Z" fill="#FFE8B0"/>
<path d="M512 638 Q640 650 724 720 L512 720Z" fill="#FFD36B"/>
{palm(500, 690, 530, 350, -40, 1.05, c3, p, 1)}
</g></g>"""


# --- вариации 6 --------------------------------------------------------------

def b1(p):
    """Вырез раскрылся в оазис: чёрный остров свисает с верхнего края"""
    return f"""
<defs>{CLIP.format(p=p)}
{grad(p+'bg', [(0, '#4FD1C5'), (1, '#1E7FB8')])}
{grad(p+'sky', [(0, '#1B1F3A'), (1, '#3A3F7A')])}
{grad(p+'sea', [(0, '#34C3EB'), (1, '#1584C8')])}
{grad(p+'sand', [(0, '#FFE2A6'), (1, '#F2B95A')])}
<clipPath id="{p}isl"><path d="M190 100 H834 V560 Q834 700 694 700 H330 Q190 700 190 560Z"/></clipPath></defs>
{squircle(p, f'url(#{p}bg)')}
<g clip-path="url(#{p}clip)">
<path d="M190 100 H834 V560 Q834 700 694 700 H330 Q190 700 190 560Z" fill="#000"/>
<g clip-path="url(#{p}isl)">
<rect x="190" y="560" width="644" height="140" fill="url(#{p}sea)"/>
{waves(600, 220, 820, 9, 52, '#9BE8FF', 8)}
<ellipse cx="512" cy="575" rx="190" ry="48" fill="url(#{p}sand)"/>
{palm(500, 560, 535, 260, -50, .95, GREEN, p, 1)}
</g></g>"""


def b2(p):
    """Ночная таблетка: внутри месяц и звёзды, пальма силуэтом на сиреневом"""
    stars = "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#fff" opacity="{o}"/>'
                    for x, y, r, o in [(300, 640, 4, .9), (380, 700, 3, .6), (720, 690, 3, .7),
                                       (650, 620, 4, .8), (460, 760, 3, .5)])
    return f"""
<defs>{CLIP.format(p=p)}
{grad(p+'bg', [(0, '#FFB199'), (.5, '#C86DD7'), (1, '#3023AE')])}</defs>
{squircle(p, f'url(#{p}bg)')}
<g clip-path="url(#{p}clip)">
<rect x="180" y="560" width="664" height="260" rx="130" fill="#000"/>
{stars}
<circle cx="560" cy="690" r="54" fill="#FFF2C2"/><circle cx="584" cy="672" r="48" fill="#000"/>
{palm(400, 590, 430, 330, -45, .85, silhouette('#1A1240'), p, 1)}
<path d="M300 600 Q400 560 520 600Z" fill="#1A1240"/>
</g>"""


def b3(p):
    """Таблетка-окно: в чёрном вырезе закат и пальма"""
    return f"""
<defs>{CLIP.format(p=p)}
{grad(p+'bg', [(0, '#E9F7EF'), (1, '#BDE7D2')])}
{grad(p+'sun', [(0, '#FF5F6D'), (.6, '#FFC371'), (1, '#FFE8B0')])}
<clipPath id="{p}pill"><rect x="200" y="380" width="624" height="264" rx="132"/></clipPath></defs>
{squircle(p, f'url(#{p}bg)')}
<rect x="170" y="350" width="684" height="324" rx="162" fill="#000"/>
<g clip-path="url(#{p}pill)">
<rect x="200" y="380" width="624" height="264" fill="url(#{p}sun)"/>
<circle cx="600" cy="560" r="70" fill="#FFF3D1" opacity=".9"/>
<rect x="200" y="572" width="624" height="80" fill="#2A3B8F"/>
<rect x="540" y="590" width="120" height="7" rx="3.5" fill="#FFD9A0" opacity=".7"/>
<path d="M260 590 Q400 545 540 590Z" fill="#1B1430"/>
{palm(390, 578, 410, 460, -20, .5, silhouette('#1B1430'), p, 1)}
</g>"""


def b4(p):
    """Стеклянная таблетка на закате, цветная пальма вырастает из неё"""
    return f"""
<defs>{CLIP.format(p=p)}
{grad(p+'bg', [(0, '#FF9A8B'), (.5, '#FF6A88'), (1, '#FF99AC')])}
{grad(p+'glass', [(0, '#FFFFFF'), (1, '#FFFFFF')])}
{grad(p+'sand', [(0, '#FFE2A6'), (1, '#F2B95A')])}</defs>
{squircle(p, f'url(#{p}bg)')}
<g clip-path="url(#{p}clip)">
<rect x="180" y="580" width="664" height="240" rx="120" fill="#fff" opacity=".28"/>
<rect x="180" y="580" width="664" height="240" rx="120" fill="none" stroke="#fff" stroke-opacity=".7" stroke-width="6"/>
<path d="M210 700 Q512 600 814 700 Q800 790 694 816 H330 Q224 790 210 700Z" fill="url(#{p}sand)" opacity=".95"/>
{waves(760, 260, 780, 10, 52, '#FFFFFF', 9)}
{palm(500, 670, 535, 320, -50, 1.0, GREEN, p, 1)}
</g>"""


def b5(p):
    """Таблетка-лагуна: в чёрном вырезе вода и отражение пальмы"""
    return f"""
<defs>{CLIP.format(p=p)}
{grad(p+'bg', [(0, '#2B2F36'), (1, '#0C0D10')])}
{grad(p+'sea', [(0, '#3FD0F0'), (1, '#0B5FA0')])}
<clipPath id="{p}pill"><rect x="196" y="606" width="632" height="208" rx="104"/></clipPath></defs>
{squircle(p, f'url(#{p}bg)')}
<g clip-path="url(#{p}clip)">
<rect x="180" y="590" width="664" height="240" rx="120" fill="#000"/>
<g clip-path="url(#{p}pill)">
<rect x="196" y="606" width="632" height="208" fill="url(#{p}sea)"/>
<g opacity=".35" transform="translate(0 1260) scale(1 -1)">{palm(500, 640, 535, 330, -50, 1.0, silhouette('#003A66'), p+'r', 1)}</g>
{waves(700, 230, 800, 8, 50, '#9BE8FF', 7)}
{waves(760, 280, 760, 7, 46, '#6FD3F5', 6)}
</g>
<path d="M330 640 Q512 560 694 640Z" fill="#F7C873"/>
{palm(500, 625, 535, 310, -50, 1.0, GREEN, p, 1)}
</g>"""


# --- монохромы ---------------------------------------------------------------

def mask_svg(keep, cut, color="#000", mid="x"):
    # template: одноцветный силуэт, вырезы через маску
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><defs><mask id="{mid}">'
            f'<g fill="#fff">{keep}</g><g fill="#000" stroke="#000">{cut}</g></mask></defs>'
            f'<rect width="64" height="64" fill="{color}" mask="url(#{mid})"/></svg>')


def mono_b(n, color="#000", mid="x"):
    if n == 1:
        return mask_svg('<path d="M10 4 H54 V30 Q54 42 42 42 H22 Q10 42 10 30Z"/>',
                        mpalm(31, 38, 33, 15, -4, .62) + '<path d="M20 39 Q32 33 44 39Z"/>', color, mid)
    if n == 2:
        return mask_svg('<rect x="4" y="34" width="56" height="24" rx="12"/>' + mpalm(26, 40, 28, 12, -5, .85),
                        '<circle cx="42" cy="46" r="6"/><circle cx="45" cy="44" r="5" fill="#fff"/>', color, mid)
    if n == 3:
        return mask_svg('<rect x="2" y="16" width="60" height="32" rx="16"/>',
                        mpalm(28, 42, 30, 22, -3, .55) + '<path d="M16 44 Q28 38 40 44Z"/>', color, mid)
    if n == 4:
        return mask_svg('<rect x="4" y="34" width="56" height="24" rx="12"/>' + mpalm(31, 40, 33, 12, -5, .85),
                        '<rect x="9" y="39" width="46" height="14" rx="7"/>', color, mid)
    if n == 5:
        return mask_svg('<rect x="4" y="34" width="56" height="24" rx="12"/>' + mpalm(31, 38, 33, 10, -5, .85),
                        '<path d="M12 48 q4 -3 8 0 t8 0 t8 0 t8 0 t8 0" stroke-width="3" fill="none" stroke-linecap="round"/>',
                        color, mid)


R2 = [
    ("a1", "Круг 3 + волны · menu bar 1", a1, lambda c, m: mono_svg(1, c)),
    ("b1", "Вырез раскрылся в оазис", b1, lambda c, m: mono_b(1, c, m)),
    ("b2", "Ночная таблетка", b2, lambda c, m: mono_b(2, c, m)),
    ("b3", "Таблетка-окно с закатом", b3, lambda c, m: mono_b(3, c, m)),
    ("b4", "Стеклянная таблетка", b4, lambda c, m: mono_b(4, c, m)),
    ("b5", "Таблетка-лагуна с отражением", b5, lambda c, m: mono_b(5, c, m)),
]


def inner(svg):
    return svg[svg.index(">") + 1:-6]


def render(src, out, w):
    subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(w), "-o", out, src], check=True)


if __name__ == "__main__":
    for key, name, fn, mono in R2:
        s = os.path.join(SVG, f"r2-{key}-app.svg")
        open(s, "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">{fn(key)}</svg>')
        render(s, os.path.join(PNG, f"r2-{key}-app-1024.png"), 1024)
        m = os.path.join(SVG, f"r2-{key}-menubar.svg")
        open(m, "w").write(mono("#000", f"m{key}"))
        render(m, os.path.join(PNG, f"r2-{key}-menubar-36.png"), 36)

    W, ROW = 1500, 330
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{ROW*len(R2)+40}">'
             f'<rect width="100%" height="100%" fill="#F4F4F6"/>']
    for i, (key, name, fn, mono) in enumerate(R2):
        y = 20 + i * ROW
        parts.append(f'<text x="30" y="{y+30}" font-family="Helvetica" font-size="26" font-weight="bold" fill="#222">{key.upper()}. {name}</text>')
        for (x, yy, sz, sfx) in [(30, 45, 270, "s"), (320, 165, 128, "t"), (470, 229, 64, "u"), (550, 261, 32, "w")]:
            parts.append(f'<svg x="{x}" y="{y+yy}" width="{sz}" height="{sz}" viewBox="0 0 1024 1024">{fn(sfx+key)}</svg>')
        for j, (bg, fg) in enumerate([("#ECECEE", "#000"), ("#1E1E20", "#fff")]):
            bx = 640 + j * 420
            parts.append(f'<rect x="{bx}" y="{y+60}" width="390" height="44" rx="8" fill="{bg}"/>')
            parts.append(f'<svg x="{bx+20}" y="{y+73}" width="18" height="18" viewBox="0 0 64 64">{inner(mono(fg, f"k{key}{j}"))}</svg>')
            parts.append(f'<text x="{bx+50}" y="{y+88}" font-family="Helvetica" font-size="14" fill="{fg}" opacity=".6">18 pt</text>')
            parts.append(f'<rect x="{bx}" y="{y+120}" width="170" height="170" rx="12" fill="{bg}"/>')
            parts.append(f'<svg x="{bx+20}" y="{y+140}" width="130" height="130" viewBox="0 0 64 64">{inner(mono(fg, f"l{key}{j}"))}</svg>')
    parts.append("</svg>")
    sheet = os.path.join(HERE, "sheet2.svg")
    open(sheet, "w").write("".join(parts))
    subprocess.run(["rsvg-convert", "-o", os.path.join(HERE, "sheet2.png"), sheet], check=True)
    print("ok")

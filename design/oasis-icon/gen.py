#!/usr/bin/env python3
# Генератор вариантов иконки Oasis: цветная иконка приложения (1024, сквиркл macOS)
# и монохромный template-значок для menu bar (64-единичный viewBox, рендер 18/36 px).
# Запуск: python3 gen.py → svg/*.svg, png/*.png, sheet.svg, sheet.png
import math
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
SVG = os.path.join(HERE, "svg")
PNG = os.path.join(HERE, "png")
os.makedirs(SVG, exist_ok=True)
os.makedirs(PNG, exist_ok=True)


def f(v):
    return f"{v:.1f}".rstrip("0").rstrip(".")


# --- примитивы ---------------------------------------------------------------

def squircle(p, fill):
    # тело иконки по сетке macOS: 824×824 с отступом 100, скругление ~ continuous corner
    return (f'<rect x="100" y="100" width="824" height="824" rx="186" fill="{fill}"/>')


def leaf(cx, cy, angle, length, width, droop, fill, mirror=False):
    L, W, D = length, width, droop
    d = (f"M0 0 C{f(L*.3)} {f(-W)} {f(L*.72)} {f(-W*.55+D*.45)} {f(L)} {f(D)} "
         f"C{f(L*.72)} {f(W*.15+D*.6)} {f(L*.32)} {f(W*.55)} 0 0Z")
    sx = "scale(-1 1) " if mirror else ""
    return f'<path d="{d}" fill="{fill}" transform="translate({f(cx)} {f(cy)}) {sx}rotate({f(angle)})"/>'


def crown(cx, cy, scale, dark, light, spread=None):
    # крона: пары листьев справа и слева, тёмный слой снизу, светлый сверху
    spread = spread or [(-72, 0.92, 0.38), (-34, 1.06, 0.62), (2, 0.9, 0.85)]
    out = []
    for i, (a, k, dr) in enumerate(spread):
        L = 250 * scale * k
        W = 62 * scale
        for mirror in (False, True):
            a2 = a + (6 if mirror else 0)
            out.append(leaf(cx, cy, a2 + 3, L, W * .95, L * dr * 1.08, dark, mirror))
            out.append(leaf(cx, cy, a2 - 1, L * .93, W * .72, L * dr * .95, light, mirror))
    return "".join(out)


def trunk(bx, by, tx, ty, bend, w0, w1, fill, shade=None, stripes=None, cid=None):
    qx, qy = (bx + tx) / 2 + bend, (by + ty) / 2
    wm = (w0 + w1) / 2
    d = (f"M{f(bx-w0/2)} {f(by)} Q{f(qx-wm/2)} {f(qy)} {f(tx-w1/2)} {f(ty)} "
         f"L{f(tx+w1/2)} {f(ty)} Q{f(qx+wm/2)} {f(qy)} {f(bx+w0/2)} {f(by)}Z")
    out = [f'<path d="{d}" fill="{fill}"/>']
    if shade or stripes:
        out.append(f'<clipPath id="{cid}"><path d="{d}"/></clipPath><g clip-path="url(#{cid})">')
        if shade:
            # тень по правой половине ствола
            ds = (f"M{f(bx)} {f(by)} Q{f(qx)} {f(qy)} {f(tx)} {f(ty)} "
                  f"L{f(tx+w1)} {f(ty)} Q{f(qx+wm)} {f(qy)} {f(bx+w0)} {f(by)}Z")
            out.append(f'<path d="{ds}" fill="{shade}"/>')
        if stripes:
            col, n = stripes
            for i in range(1, n + 1):
                t = i / (n + 1)
                # точка на кривой Безье
                x = (1-t)**2*bx + 2*(1-t)*t*qx + t*t*tx
                y = (1-t)**2*by + 2*(1-t)*t*qy + t*t*ty
                out.append(f'<path d="M{f(x-60)} {f(y+6)} Q{f(x)} {f(y-6)} {f(x+60)} {f(y+6)}" '
                           f'stroke="{col}" stroke-width="11" stroke-linecap="round" fill="none"/>')
        out.append("</g>")
    return "".join(out)


def palm(bx, by, tx, ty, bend, scale, c, p, k, stripes=True, nuts=None):
    s = trunk(bx, by, tx, ty, bend, 46 * scale, 26 * scale, c["trunk"], c.get("trunkShade"),
              (c["stripe"], 4) if stripes and c.get("stripe") else None, f"{p}tr{k}")
    s += crown(tx, ty, scale, c["leafDark"], c["leafLight"])
    s += f'<circle cx="{f(tx)}" cy="{f(ty+4*scale)}" r="{f(20*scale)}" fill="{c["leafDark"]}"/>'
    if nuts:
        for dx, dy in [(-14, 14), (12, 18), (0, 30)]:
            s += f'<circle cx="{f(tx+dx*scale)}" cy="{f(ty+dy*scale)}" r="{f(15*scale)}" fill="{nuts}"/>'
    return s


def grad(gid, stops, x1=0, y1=0, x2=0, y2=1):
    st = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in stops)
    return f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{st}</linearGradient>'


def waves(y, x0, x1, amp, step, color, width):
    d = f"M{x0} {y}"
    x = x0
    up = True
    while x < x1:
        d += f" q{step/2} {-amp if up else amp} {step} 0"
        x += step
        up = not up
    return f'<path d="{d}" stroke="{color}" stroke-width="{width}" stroke-linecap="round" fill="none"/>'


GREEN = {"leafDark": "#4E9E2B", "leafLight": "#8FD14F", "trunk": "#E8893A",
         "trunkShade": "#C96B22", "stripe": "#B85D1C"}

# --- цветные варианты --------------------------------------------------------


def v1(p):
    """Лагуна: небо, солнце, море и одна пальма на острове"""
    return f"""
<defs>{grad(p+'sky', [(0, '#5CC8F2'), (1, '#C9F1FF')])}
{grad(p+'sea', [(0, '#1FA2D6'), (1, '#0B7FB8')])}
{grad(p+'sand', [(0, '#FFE2A6'), (1, '#F2C46E')])}
<clipPath id="{p}clip"><rect x="100" y="100" width="824" height="824" rx="186"/></clipPath></defs>
{squircle(p, f'url(#{p}sky)')}
<g clip-path="url(#{p}clip)">
<circle cx="700" cy="300" r="92" fill="#FFF3B0"/><circle cx="700" cy="300" r="66" fill="#FFD84D"/>
<rect x="100" y="690" width="824" height="240" fill="url(#{p}sea)"/>
{waves(745, 130, 900, 14, 70, '#8EDCFA', 12)}
{waves(820, 200, 860, 12, 64, '#5FC6EF', 10)}
<ellipse cx="500" cy="720" rx="250" ry="70" fill="url(#{p}sand)"/>
<ellipse cx="560" cy="702" rx="120" ry="28" fill="#FFF0CC" opacity=".7"/>
{palm(470, 700, 520, 330, -70, 1.15, GREEN, p, 1)}
</g>"""


def v2(p):
    """Две пальмы на закате"""
    c2 = dict(GREEN, trunk="#B8622A", trunkShade="#97491C", stripe=None)
    return f"""
<defs>{grad(p+'sky', [(0, '#FF8A65'), (.55, '#FFC371'), (1, '#FFE6A8')])}
{grad(p+'sea', [(0, '#3A7BD5'), (1, '#2A5CB0')])}
<clipPath id="{p}clip"><rect x="100" y="100" width="824" height="824" rx="186"/></clipPath></defs>
{squircle(p, f'url(#{p}sky)')}
<g clip-path="url(#{p}clip)">
<circle cx="512" cy="640" r="190" fill="#FFF1C9" opacity=".8"/>
<rect x="100" y="700" width="824" height="230" fill="url(#{p}sea)"/>
<rect x="380" y="730" width="260" height="10" rx="5" fill="#FFD9A0" opacity=".7"/>
<rect x="430" y="770" width="160" height="10" rx="5" fill="#FFD9A0" opacity=".5"/>
<path d="M250 715 Q512 600 774 715Z" fill="#F7C873"/>
<path d="M250 715 Q380 650 512 640 L512 715Z" fill="#FFDD99"/>
{palm(420, 690, 330, 330, 40, .95, c2, p, 1, nuts='#3B2A20')}
{palm(560, 690, 650, 390, -30, .8, c2, p, 2, nuts='#3B2A20')}
</g>"""


def v3(p):
    """Плоский круг с длинной тенью"""
    c3 = {"leafDark": "#2E8B57", "leafLight": "#5DBB63", "trunk": "#FF6B35",
          "trunkShade": "#C4532A", "stripe": None}
    return f"""
<defs><clipPath id="{p}clip"><rect x="100" y="100" width="824" height="824" rx="186"/></clipPath>
<clipPath id="{p}circ"><circle cx="512" cy="512" r="330"/></clipPath></defs>
{squircle(p, '#0F6F7A')}
<g clip-path="url(#{p}clip)">
<circle cx="512" cy="512" r="330" fill="#A8E3EC"/>
<g clip-path="url(#{p}circ)">
<path d="M330 330 L560 280 L1000 720 L800 1000Z" fill="#7DC7D6"/>
<path d="M150 760 Q512 640 874 760 L874 900 L150 900Z" fill="#FFE8B0"/>
<path d="M512 662 Q700 680 874 760 L874 900 L512 900Z" fill="#FFD36B"/>
{palm(500, 700, 530, 360, -40, 1.05, c3, p, 1)}
</g></g>"""


def v4(p):
    """Ночной оазис: луна, звёзды, отражение"""
    cn = {"leafDark": "#2F7D4A", "leafLight": "#5CC27A", "trunk": "#8A5A3C",
          "trunkShade": "#6A4128", "stripe": "#5A3520"}
    stars = "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#FFFFFF" opacity="{o}"/>'
                    for x, y, r, o in [(220, 250, 5, .9), (300, 180, 3, .7), (820, 230, 4, .8),
                                       (760, 400, 3, .6), (250, 420, 3, .5), (420, 200, 4, .8),
                                       (880, 520, 3, .5)])
    return f"""
<defs>{grad(p+'sky', [(0, '#141B4D'), (.7, '#3B2C7A'), (1, '#6A4C9C')])}
{grad(p+'sand', [(0, '#F3C98B'), (1, '#C98F52')])}
<clipPath id="{p}clip"><rect x="100" y="100" width="824" height="824" rx="186"/></clipPath></defs>
{squircle(p, f'url(#{p}sky)')}
<g clip-path="url(#{p}clip)">
{stars}
<circle cx="680" cy="300" r="80" fill="#FFF2C2"/><circle cx="715" cy="275" r="72" fill="#1F2460"/>
<rect x="100" y="740" width="824" height="200" fill="#1B2A6B"/>
<rect x="430" y="780" width="170" height="9" rx="4.5" fill="#FFF2C2" opacity=".55"/>
<rect x="470" y="815" width="100" height="8" rx="4" fill="#FFF2C2" opacity=".35"/>
<path d="M200 760 Q512 610 824 760Z" fill="url(#{p}sand)"/>
{palm(480, 720, 540, 340, -60, 1.1, cn, p, 1)}
</g>"""


def v5(p):
    """Оазис в пустыне: дюны и голубое озерцо"""
    c5 = dict(GREEN, trunk="#9C6B43", trunkShade="#7A5232", stripe="#6B4428")
    return f"""
<defs>{grad(p+'sky', [(0, '#FFF6DC'), (1, '#FFE0A3')])}
{grad(p+'dune1', [(0, '#F6B65A'), (1, '#E08E2E')])}
{grad(p+'dune2', [(0, '#FFD27F'), (1, '#F4A947')])}
{grad(p+'pool', [(0, '#5ED3F3'), (1, '#1E9BD7')])}
<clipPath id="{p}clip"><rect x="100" y="100" width="824" height="824" rx="186"/></clipPath></defs>
{squircle(p, f'url(#{p}sky)')}
<g clip-path="url(#{p}clip)">
<circle cx="300" cy="300" r="70" fill="#FFC94D"/>
<path d="M100 640 Q350 520 620 640 T924 600 L924 930 L100 930Z" fill="url(#{p}dune1)"/>
<path d="M100 760 Q420 640 760 740 T924 720 L924 930 L100 930Z" fill="url(#{p}dune2)"/>
<ellipse cx="560" cy="790" rx="190" ry="48" fill="url(#{p}pool)"/>
<ellipse cx="520" cy="780" rx="90" ry="12" fill="#B9F0FF" opacity=".7"/>
{palm(470, 780, 420, 400, 30, 1.0, c5, p, 1)}
{palm(660, 770, 720, 480, -20, .75, c5, p, 2)}
</g>"""


def v6(p):
    """Остров под вырезом: чёрный «динамический остров» с пальмой"""
    return f"""
<defs>{grad(p+'bg', [(0, '#2B2F36'), (1, '#0C0D10')])}
{grad(p+'sea', [(0, '#3FD0F0'), (1, '#1584C8')])}
{grad(p+'sand', [(0, '#FFE2A6'), (1, '#F2B95A')])}
<clipPath id="{p}clip"><rect x="100" y="100" width="824" height="824" rx="186"/></clipPath>
<clipPath id="{p}pill"><rect x="180" y="560" width="664" height="260" rx="130"/></clipPath></defs>
{squircle(p, f'url(#{p}bg)')}
<g clip-path="url(#{p}clip)">
<rect x="180" y="560" width="664" height="260" rx="130" fill="#000000"/>
<g clip-path="url(#{p}pill)">
<rect x="180" y="700" width="664" height="140" fill="url(#{p}sea)"/>
{waves(730, 230, 800, 10, 56, '#9BE8FF', 9)}
<ellipse cx="512" cy="712" rx="210" ry="56" fill="url(#{p}sand)"/>
</g>
<rect x="180" y="560" width="664" height="260" rx="130" fill="none" stroke="#3A3F48" stroke-width="6"/>
{palm(500, 690, 540, 330, -55, 1.05, GREEN, p, 1)}
</g>"""


def v7(p):
    """Атолл-«O»: кольцо лагуны с пальмой в центре"""
    return f"""
<defs>{grad(p+'bg', [(0, '#E9FBFF'), (1, '#B6ECF7')])}
{grad(p+'ring', [(0, '#22B8E8'), (1, '#0A7CC2')], 0, 0, 1, 1)}
{grad(p+'sand', [(0, '#FFE7B3'), (1, '#F5C470')])}</defs>
{squircle(p, f'url(#{p}bg)')}
<circle cx="512" cy="530" r="300" fill="none" stroke="url(#{p}ring)" stroke-width="92"/>
<circle cx="512" cy="530" r="300" fill="none" stroke="#9BE3F7" stroke-width="10" stroke-dasharray="40 30" opacity=".7"/>
<ellipse cx="512" cy="690" rx="190" ry="54" fill="url(#{p}sand)"/>
{palm(500, 680, 535, 370, -45, .95, GREEN, p, 1)}"""


# --- монохромные template-значки (viewBox 64) ----------------------------------

def mleaf(cx, cy, a, L, W, D, mirror=False):
    d = (f"M0 0 C{f(L*.3)} {f(-W)} {f(L*.72)} {f(-W*.55+D*.45)} {f(L)} {f(D)} "
         f"C{f(L*.72)} {f(W*.15+D*.6)} {f(L*.32)} {f(W*.55)} 0 0Z")
    sx = "scale(-1 1) " if mirror else ""
    return f'<path d="{d}" transform="translate({f(cx)} {f(cy)}) {sx}rotate({f(a)})"/>'


def mpalm(bx, by, tx, ty, bend, s=1.0):
    qx, qy = (bx + tx) / 2 + bend, (by + ty) / 2
    w0, w1 = 5.5 * s, 3.4 * s
    wm = (w0 + w1) / 2
    d = (f"M{f(bx-w0/2)} {f(by)} Q{f(qx-wm/2)} {f(qy)} {f(tx-w1/2)} {f(ty)} "
         f"L{f(tx+w1/2)} {f(ty)} Q{f(qx+wm/2)} {f(qy)} {f(bx+w0/2)} {f(by)}Z")
    out = [f'<path d="{d}"/>']
    for a, L, D in [(-58, 17, 4), (-14, 19, 8), (24, 15, 8)]:
        for m in (False, True):
            out.append(mleaf(tx, ty, a, L * s, 5.2 * s, D * s, m))
    return "".join(out)


def mono(n):
    island = '<path d="M10 52 Q32 40 54 52Z"/>'
    if n == 1:
        return mpalm(30, 48, 33, 16, -6) + island + \
            '<path d="M6 58 q4 -3 8 0 t8 0 t8 0 t8 0 t8 0 t8 0 t8 0" stroke="#000" stroke-width="3.2" fill="none" stroke-linecap="round"/>'
    if n == 2:
        return mpalm(26, 50, 20, 18, 5, .85) + mpalm(38, 50, 45, 26, -4, .72) + island
    if n == 3:
        return ('<circle cx="32" cy="32" r="28" fill="none" stroke="#000" stroke-width="4"/>' +
                mpalm(31, 48, 33, 20, -4, .8) + '<path d="M12 50 Q32 40 52 50 L50 54 Q32 47 14 54Z"/>')
    if n == 4:
        return (mpalm(28, 50, 31, 20, -6, .9) + island +
                '<path d="M52 6 a9 9 0 1 0 6 14 a7 7 0 1 1 -6 -14Z"/>')
    if n == 5:
        return (mpalm(28, 50, 24, 18, 4, .9) +
                '<path d="M4 54 Q20 44 36 50 Q48 54 60 48 L60 60 L4 60Z"/>' +
                '<ellipse cx="36" cy="54" rx="11" ry="3" fill="#fff"/>')
    if n == 6:
        return ('<rect x="4" y="34" width="56" height="24" rx="12"/>' +
                mpalm(31, 40, 33, 12, -5, .85))
    if n == 7:
        return ('<circle cx="32" cy="32" r="25" fill="none" stroke="#000" stroke-width="7"/>' +
                mpalm(31, 42, 33, 22, -3, .62) + '<path d="M21 43 Q32 37 43 43Z"/>')


VARIANTS = [
    (1, "Лагуна", v1), (2, "Две пальмы на закате", v2), (3, "Плоский круг", v3),
    (4, "Ночной оазис", v4), (5, "Оазис в пустыне", v5), (6, "Остров под вырезом", v6),
    (7, "Атолл «O»", v7),
]


def icon_svg(fn, p):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">{fn(p)}</svg>'


def mono_svg(n, color="#000"):
    body = mono(n).replace('fill="#fff"', 'fill="#fff" class="cut"')
    # вырез у озерца делаем маской, чтобы template оставался одноцветным
    if 'class="cut"' in body:
        cut = '<ellipse cx="36" cy="54" rx="11" ry="3" fill="#000"/>'
        body = body.replace('<ellipse cx="36" cy="54" rx="11" ry="3" fill="#fff" class="cut"/>', "")
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><defs><mask id="m{n}">'
                f'<rect width="64" height="64" fill="#fff"/>{cut}</mask></defs>'
                f'<g fill="{color}" mask="url(#m{n})">{body}</g></svg>')
    body = body.replace('stroke="#000"', f'stroke="{color}"')
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><g fill="{color}">{body}</g></svg>'


def render(src, out, w):
    subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(w), "-o", out, src], check=True)


if __name__ == "__main__":
    for n, name, fn in VARIANTS:
        s = os.path.join(SVG, f"oasis-{n}-app.svg")
        open(s, "w").write(icon_svg(fn, f"v{n}"))
        render(s, os.path.join(PNG, f"oasis-{n}-app-1024.png"), 1024)
        m = os.path.join(SVG, f"oasis-{n}-menubar.svg")
        open(m, "w").write(mono_svg(n))
        render(m, os.path.join(PNG, f"oasis-{n}-menubar-36.png"), 36)

    # --- контактный лист для просмотра --------------------------------------------
    W, ROW = 1500, 330
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{ROW*len(VARIANTS)+40}">'
             f'<rect width="100%" height="100%" fill="#F4F4F6"/>']
    for i, (n, name, fn) in enumerate(VARIANTS):
        y = 20 + i * ROW
        parts.append(f'<text x="30" y="{y+30}" font-family="Helvetica" font-size="26" font-weight="bold" fill="#222">{n}. {name}</text>')
        parts.append(f'<svg x="30" y="{y+45}" width="270" height="270" viewBox="0 0 1024 1024">{fn(f"s{n}")}</svg>')
        parts.append(f'<svg x="320" y="{y+165}" width="128" height="128" viewBox="0 0 1024 1024">{fn(f"t{n}")}</svg>')
        parts.append(f'<svg x="470" y="{y+229}" width="64" height="64" viewBox="0 0 1024 1024">{fn(f"u{n}")}</svg>')
        parts.append(f'<svg x="550" y="{y+261}" width="32" height="32" viewBox="0 0 1024 1024">{fn(f"w{n}")}</svg>')
        # menu bar: светлая и тёмная полоса, значок 18 pt и крупно
        for j, (bg, fg) in enumerate([("#ECECEE", "#000"), ("#1E1E20", "#fff")]):
            bx = 640 + j * 420
            parts.append(f'<rect x="{bx}" y="{y+60}" width="390" height="44" rx="8" fill="{bg}"/>')
            parts.append(f'<svg x="{bx+20}" y="{y+73}" width="18" height="18" viewBox="0 0 64 64">{mono_svg(n, fg)[mono_svg(n, fg).index(">")+1:-6]}</svg>')
            parts.append(f'<text x="{bx+50}" y="{y+88}" font-family="Helvetica" font-size="14" fill="{fg}" opacity=".6">18 pt</text>')
            parts.append(f'<rect x="{bx}" y="{y+120}" width="170" height="170" rx="12" fill="{bg}"/>')
            parts.append(f'<svg x="{bx+20}" y="{y+140}" width="130" height="130" viewBox="0 0 64 64">{mono_svg(n, fg)[mono_svg(n, fg).index(">")+1:-6]}</svg>')
    parts.append("</svg>")
    sheet = os.path.join(HERE, "sheet.svg")
    open(sheet, "w").write("".join(parts))
    subprocess.run(["rsvg-convert", "-o", os.path.join(HERE, "sheet.png"), sheet], check=True)
    print("ok")

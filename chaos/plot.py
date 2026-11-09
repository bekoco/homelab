"""Graphique SVG de la disponibilite HTTP d'un ou plusieurs tests de panne.

Usage : python3 chaos/plot.py sortie.svg "Titre 1" results/dossier1 "Titre 2" results/dossier2
Aucune dependance : le SVG est ecrit a la main.
"""
import csv
import sys
from pathlib import Path

out = Path(sys.argv[1])
tests = list(zip(sys.argv[2::2], map(Path, sys.argv[3::2])))

W, ROW_H, LEFT, RIGHT, TOP = 960, 110, 150, 30, 70
BAR_H = 34
H = TOP + ROW_H * len(tests) + 60
T_MIN, T_MAX = -60, 580
scale = (W - LEFT - RIGHT) / (T_MAX - T_MIN)


def x(t):
    return LEFT + (t - T_MIN) * scale


def events_of(folder):
    ev = {}
    for line in (folder / "events.log").read_text().splitlines():
        ts, label = line.split(" ", 2)[:2]
        ev.setdefault(label, int(ts))
    return ev


svg = [
    f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" '
    'font-family="Segoe UI, Helvetica, Arial, sans-serif">',
    f'<rect width="{W}" height="{H}" fill="#ffffff"/>',
    f'<text x="{LEFT}" y="32" font-size="20" font-weight="600" fill="#1f2328">'
    "Disponibilité de l'application pendant la perte d'un nœud</text>",
    f'<text x="{LEFT}" y="54" font-size="13" fill="#59636e">'
    "1 requête HTTP par seconde · vert : réponse OK · rouge : échec · T0 = arrêt brutal de la VM</text>",
]

for i, (title, folder) in enumerate(tests):
    ev = events_of(folder)
    t0 = ev["PANNE"]
    rows = list(csv.DictReader((folder / "http.csv").open()))
    y = TOP + i * ROW_H + 30
    fails = sum(r["code"] != "200" for r in rows)
    pct = 100 * (len(rows) - fails) / max(len(rows), 1)
    svg.append(f'<text x="{LEFT - 12}" y="{y + 14}" font-size="14" font-weight="600" '
               f'fill="#1f2328" text-anchor="end">{title}</text>')
    svg.append(f'<text x="{LEFT - 12}" y="{y + 32}" font-size="12" fill="#59636e" '
               f'text-anchor="end">{pct:.1f} % OK ({fails} échecs)</text>')
    # Periode ou la VM est eteinte
    if "REPRISE" in ev:
        svg.append(f'<rect x="{x(0):.1f}" y="{y - 8}" width="{x(ev["REPRISE"] - t0) - x(0):.1f}" '
                   f'height="{BAR_H + 16}" fill="#f6f8fa" stroke="#d1d9e0" stroke-dasharray="4 3"/>')
    for r in rows:
        t = int(r["ts"]) - t0
        if T_MIN <= t <= T_MAX:
            color = "#1a7f37" if r["code"] == "200" else "#cf222e"
            svg.append(f'<rect x="{x(t):.1f}" y="{y}" width="{max(scale, 1.2):.1f}" '
                       f'height="{BAR_H}" fill="{color}"/>')

# Axe du temps
ya = TOP + ROW_H * len(tests) + 10
svg.append(f'<line x1="{LEFT}" y1="{ya}" x2="{W - RIGHT}" y2="{ya}" stroke="#59636e"/>')
for t in range(0, T_MAX + 1, 60):
    svg.append(f'<line x1="{x(t):.1f}" y1="{ya}" x2="{x(t):.1f}" y2="{ya + 5}" stroke="#59636e"/>')
    svg.append(f'<text x="{x(t):.1f}" y="{ya + 20}" font-size="12" fill="#59636e" '
               f'text-anchor="middle">T+{t // 60} min</text>')
svg.append(f'<line x1="{x(0):.1f}" y1="{TOP}" x2="{x(0):.1f}" y2="{ya}" stroke="#cf222e" '
           'stroke-width="1.5" stroke-dasharray="5 4"/>')
svg.append(f'<text x="{x(0) + 6:.1f}" y="{TOP + 8}" font-size="12" fill="#cf222e">panne</text>')
svg.append(f'<text x="{x(395):.1f}" y="{TOP + 8}" font-size="12" fill="#59636e">'
           "cadre pointillé : VM éteinte</text>")
svg.append("</svg>")

out.parent.mkdir(parents=True, exist_ok=True)
out.write_text("\n".join(svg), encoding="utf-8")
print(f"ecrit : {out}")

"""Tablas del vuelo de los saltos del peregrino para el flotar en la luz.

Por fotograma de 04_limpios (master, el doble del juego): fila de arriba (cabeza),
fila de abajo (pies) y centroide del alfa. El cuerpo = media de cabeza y
centroide. Se ajusta UNA parabola que pasa por el despegue (D, 0), el apogeo
(altura H) y la toma de suelo (T, L) con la misma gravedad en la subida y en la
bajada; su apogeo A* sale de ahi. Residuo = cuerpo - parabola.

Lo que imprime va a VUELO en scripts/characters/peregrino.gd (flotar en la luz).
    python tablas_vuelo.py
"""
import os, glob, math
import numpy as np
from PIL import Image

# raw/master_mason/anim (este script vive en anim/peregrino_salto_parado/).
base = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
JOBS = {
    # anim: (job, D, T, suelo de los pies en el master)
    "salto_parado": ("peregrino_salto_parado", 18, 45, 677),
    "saltar": ("peregrino_salto_andando", 13, 45, 678),
    # casilla propia (680x800 master); despegue y toca, los de peregrino.gd
    # (salto_correr_despegue, salto_correr_toca)
    "salto_correr": ("peregrino_salto_corriendo", 2, 29, 750),
}
FPS = 60.0

for anim, (job, D, T, suelo) in JOBS.items():
    fs = sorted(glob.glob(os.path.join(base, job, "04_limpios", "*.png")))
    top, bot, cy = [], [], []
    for f in fs:
        a = np.asarray(Image.open(f).convert("RGBA"))[:, :, 3].astype(float) / 255.0
        rows = np.nonzero(a.sum(1) > 0.5)[0]
        top.append(rows[0]); bot.append(rows[-1])
        cy.append((a * np.arange(a.shape[0])[:, None]).sum() / a.sum())
    top = np.array(top, float); bot = np.array(bot, float); cy = np.array(cy, float)
    # Altura del cuerpo sobre la del despegue, en px del juego (arriba +).
    cab = (top[D] - top) / 2.0
    cen = (cy[D] - cy) / 2.0
    cuerpo = (cab + cen) / 2.0
    tramo = cuerpo[D:T + 1]
    H = tramo.max()
    iA = int(np.argmax(tramo)) + D
    L = cuerpo[T]
    r = math.sqrt((H - L) / H)
    nA = (T - D) / (1.0 + r)              # fotogramas del despegue al apogeo
    g = 2.0 * H / nA ** 2                 # px/fotograma^2
    v0 = g * nA                           # px/fotograma
    n = np.arange(0, T - D + 1, dtype=float)
    P = v0 * n - g * n * n / 2.0
    res = tramo - P
    pies = np.maximum((suelo - bot[D:T + 1]) / 2.0, 0.0)
    centro = (suelo - cy[D]) / 2.0
    print(f"== {anim}: D={D} T={T} apogeo medido en {iA}, A*={D + nA:.2f}")
    print(f"   H={H:.2f} L={L:.2f} g={g * FPS * FPS:.1f} px/s2 v0={v0 * FPS:.1f} px/s")
    print(f"   centro del cuerpo sobre los pies en el despegue: {centro:.1f}")
    print("   f   cab   cen  cuerpo   P     res   pies")
    for i, f in enumerate(range(D, T + 1)):
        print(f"  {f:2d} {cab[f]:5.1f} {cen[f]:5.1f} {tramo[i]:6.2f} {P[i]:6.2f} {res[i]:6.2f} {pies[i]:5.1f}")
    print(f'   &"{anim}": {{"despegue": {D}, "toca": {T}, "apogeo": {D + nA:.2f}, "alto": {H:.2f}, "centro": {centro:.1f},')
    print('      "pose": [' + ", ".join(f"{x:.1f}" for x in res) + '],')
    print('      "pies": [' + ", ".join(f"{x:.1f}" for x in pies) + ']},')

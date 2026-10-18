"""Pies y piernas de pisar_hoja como los de flotar (2026-10-14).

El usuario: "los pies los tiene mal, hay que revisarlos a mano porque estan
desnudos; fijarse en las otras animaciones como flotacion y fusilarlo para que
queden iguales". Medido en c_012 (lo que cuelga de la tunica, ip.mascara):
  piel del pie       ~(132,103,100) y (122,91,73)   tono 0-14, poco saturado
  restos de la hoja  ~(110,79,43) y (101,88,48)     tono 14-30, saturado
  borde verde        ~(60,72,42)                    tono 30-60 (el croma)
  pierna             ~(90,75,78)                    gris morado
y las piernas del salto de parado en el aire (las de flotar ya igualadas a
ellas, peregrino_flotar/igualar_piernas.py): media (76,64,57).

1. Lo que queda de la hoja (naranja y dorado saturado en la franja de los pies)
   fuera: la hoja es un sprite aparte en el juego.
2. El borde verde, sin verde (el verde no pasa del mayor de rojo y azul).
3. Piernas y pies (la mascara de peregrino_secuencia_frontal/igualar_piernas.py)
   al color de las del salto: transferencia en Lab con las estadisticas de todo
   el video, como peregrino_flotar/igualar_piernas.py. La piel clara cae en la
   parte clara de la referencia: el pie marron de los saltos.
4. Los pies aparte (la franja de abajo de lo que cuelga, PIE_ALTO px): al
   color de los pies ya aceptados (los de flotar al tocar el suelo y los del
   reposo del salto: pardo morado apagado, (75-85, 62-65, 56-59), los claros
   ~(100-106, 78-87, 70-78)), con la luz entera; la piel salia mucho mas clara.
5. (Probado y fuera: mas finos, ADELGAZAR_PIE, cada columna del pie estrecha
   hacia la planta; dejaba un hueco en el tobillo.)
La primera vez guarda 04_limpios en 04_limpios_veo/ y sale siempre de ahi.

  python pies.py [job]     (por defecto peregrino_pisar_hoja)
"""
import glob
import os
import shutil
import sys

import cv2
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
sys.path.insert(0, os.path.join(ANIM, 'peregrino_flotar'))
sys.path.insert(0, os.path.join(ANIM, 'peregrino_secuencia_frontal'))
import igualar_piernas as ip   # noqa: E402  (mascara, lab, rgb, estadisticas)

SALTO = os.path.join(ANIM, 'peregrino_salto_parado', '04_limpios')
REFERENCIA = range(18, 38)
BANDA_HOJA = 42          # filas del final de la figura donde puede quedar hoja
PESO_L = 0.85
PIE_ALTO = 24            # px de master: lo que se cuenta como pie, desde la planta
ADELGAZAR_PIE = 1.0      # 0,7 dejaba un hueco en el tobillo (el pie bajaba y la pierna no): fuera
PIES_ACEPTADOS = [os.path.join(ANIM, 'peregrino_flotar', '04_limpios', 'c_%03d.png' % k) for k in range(70, 82)] +     [os.path.join(SALTO, 'c_%02d.png' % k) for k in range(1, 6)]


def leer(ruta):
    return np.asarray(Image.open(ruta).convert('RGBA'))


def quitar_hoja(a):
    b = a.copy()
    al = b[..., 3] > 8
    ys = np.nonzero(al.any(1))[0]
    yb = ys.max()
    hsv = cv2.cvtColor(np.ascontiguousarray(b[..., :3]), cv2.COLOR_RGB2HSV)
    h, s = hsv[..., 0].astype(int), hsv[..., 1].astype(int)
    hoja = (h >= 13) & (h <= 34) & (s > 112)
    hoja[:yb - BANDA_HOJA] = False
    # dilatado solo sobre lo que tambien es de su color o borde: no comerse el pie
    hoja = cv2.dilate(hoja.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool) & al & (h >= 11) & (h <= 40)
    b[hoja, 3] = 0
    # sueltos que queden por debajo de los pies: solo lo conectado al cuerpo
    n, lab, st, _ = cv2.connectedComponentsWithStats((b[..., 3] > 8).astype(np.uint8), 8)
    if n > 2:
        mayor = 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA]))
        b[(lab != mayor) & (lab > 0), 3] = 0
    return b


def sin_verde(a, m):
    b = a.copy().astype(int)
    tope = np.maximum(b[..., 0], b[..., 2])
    verde = m & (b[..., 1] > tope)
    b[..., 1] = np.where(verde, tope, b[..., 1])
    return b.astype(np.uint8)


def transferir(a, m, fuente, destino):
    (mu_s, sd_s), (mu_t, sd_t) = fuente, destino
    b = a.copy()
    X = ip.lab(a[m][:, :3])
    Y = (X - mu_s) * (sd_t / sd_s) + mu_t
    Y[:, 0] = X[:, 0] * (1 - PESO_L) + Y[:, 0] * PESO_L
    b[m, :3] = ip.rgb(Y)
    return b


def mascara_pies(a, m):
    """Lo de la mascara de piernas en las PIE_ALTO filas de encima de la planta
    de cada pie (cada trozo conectado de la franja de abajo, por columnas)."""
    pie = np.zeros_like(m)
    ys = np.nonzero(m.any(1))[0]
    if len(ys) == 0:
        return pie
    for x in np.nonzero(m.any(0))[0]:
        col = np.nonzero(m[:, x])[0]
        fondo = col.max()
        # solo columnas que llegan cerca de la planta de la figura (no la tunica)
        if fondo < ys.max() - 2 * PIE_ALTO:
            continue
        pie[max(fondo - PIE_ALTO, 0):fondo + 1, x] = m[max(fondo - PIE_ALTO, 0):fondo + 1, x]
    return pie


def adelgazar_pie(a, pie, s):
    """Cada columna del pie a s de su alto, hacia su fila de abajo (premultiplicado)."""
    f = a.astype(float)
    pm = f.copy()
    pm[..., :3] *= pm[..., 3:4] / 255.0
    out = pm.copy()
    for x in np.nonzero(pie.any(0))[0]:
        ys = np.nonzero(pie[:, x])[0]
        for seg in np.split(ys, np.nonzero(np.diff(ys) > 1)[0] + 1):
            y0, y1 = seg[0], seg[-1]
            ny = np.arange(y0, y1 + 1)
            fuente = y1 - (y1 - ny) / s
            dentro = fuente >= y0 - 0.5
            g0 = np.clip(np.floor(fuente).astype(int), 0, a.shape[0] - 1)
            g1 = np.clip(g0 + 1, 0, a.shape[0] - 1)
            t = (fuente - np.floor(fuente))[:, None]
            val = pm[g0, x] * (1 - t) + pm[g1, x] * t
            out[ny, x] = np.where(dentro[:, None], val, 0.0)
    al = out[..., 3:4]
    rgb = np.where(al > 0, out[..., :3] * 255.0 / np.maximum(al, 1e-6), 0.0)
    return np.clip(np.concatenate([rgb, al], -1), 0, 255).astype(np.uint8)


def muestras_pies(imagenes):
    px = []
    for a in imagenes:
        al = a[..., 3] > 200
        ys = np.nonzero(al.any(1))[0]
        banda = np.zeros_like(al)
        banda[ys.max() - PIE_ALTO:ys.max() + 1] = True
        px.append(a[al & banda & ip.mascara(a)][:, :3])
    return np.concatenate(px)


def transferir_pies(a, pie, fuente, destino):
    (mu_s, sd_s), (mu_t, sd_t) = fuente, destino
    b = a.copy()
    sel = pie & (a[..., 3] > 0)
    X = ip.lab(a[sel][:, :3])
    Y = (X - mu_s) * (sd_t / sd_s) + mu_t
    b[sel, :3] = ip.rgb(Y)
    return b


def muestras(imagenes):
    px = []
    for a in imagenes:
        px.append(a[ip.mascara(a) & (a[..., 3] > 200)][:, :3])
    return np.concatenate(px)


def main(job):
    limpios = os.path.join(ANIM, job, '04_limpios')
    veo = os.path.join(ANIM, job, '04_limpios_veo')
    if not os.path.isdir(veo):
        shutil.copytree(limpios, veo)
    rutas = sorted(glob.glob(os.path.join(veo, 'c_*.png')))
    pasos = []
    for r in rutas:
        a = quitar_hoja(leer(r))
        a = sin_verde(a, ip.mascara(a))
        pasos.append(a)
    destino = ip.estadisticas(muestras([leer(os.path.join(SALTO, 'c_%02d.png' % (f + 1))) for f in REFERENCIA]))
    fuente = ip.estadisticas(muestras(pasos))
    print('%s: piernas L %.0f -> %.0f, a* %+.1f -> %+.1f, b* %+.1f -> %+.1f (%d fotogramas)' % (
        job, fuente[0][0], destino[0][0], fuente[0][1] - 128, destino[0][1] - 128,
        fuente[0][2] - 128, destino[0][2] - 128, len(rutas)))
    piernas = [transferir(a, ip.mascara(a), fuente, destino) for a in pasos]
    pies_dst = ip.estadisticas(muestras_pies([leer(r) for r in PIES_ACEPTADOS]))
    pies_px = np.concatenate([b[mascara_pies(b, ip.mascara(b)) & (b[..., 3] > 200)][:, :3] for b in piernas])
    pies_src = ip.estadisticas(pies_px)
    print('  pies L %.0f -> %.0f, a* %+.1f -> %+.1f, b* %+.1f -> %+.1f' % (
        pies_src[0][0], pies_dst[0][0], pies_src[0][1] - 128, pies_dst[0][1] - 128,
        pies_src[0][2] - 128, pies_dst[0][2] - 128))
    for r, b in zip(rutas, piernas):
        pie = mascara_pies(b, ip.mascara(b))
        b = transferir_pies(b, pie, pies_src, pies_dst)
        if ADELGAZAR_PIE < 1.0:
            b = adelgazar_pie(b, pie, ADELGAZAR_PIE)
        Image.fromarray(b).save(os.path.join(limpios, os.path.basename(r)))


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'peregrino_pisar_hoja')

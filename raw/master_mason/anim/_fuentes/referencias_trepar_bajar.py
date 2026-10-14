"""Referencias 1080x1920 (9:16) para los videos de TREPAR un muro alto y de
BAJAR de el de un saltito (prompt_trepar.txt, prompt_bajar_saltando.txt; Flow,
fotogramas a video). Empiezan y acaban en el reposo del juego (magnus_respirando
c_01, sin baston: el guardado lo pinta el juego encima):
  referencia_trepar_inicio.png  abajo, pegado al muro (mirando a la derecha)
  referencia_trepar_fin.png     de pie encima del muro, un paso dentro del borde
  referencia_bajar_inicio.png   de pie encima del muro, junto al borde
  referencia_bajar_fin.png      abajo, a un paso largo del muro (donde cae)
En vertical porque abajo y arriba no caben en 16:9 con el personaje a su tamano
de master (1:1, como todas las referencias): el muro mide 1,15 del alto del
peregrino (algo por encima de la capucha: llega al borde con los brazos en alto).
Suelo en y=1880, croma #24D732. El muro es de relleno (sillares low-poly de
piedra clara, como el de empujar): esta quieto, asi que se quita restando su
imagen.
Y para SUBIRSE A UN SILLAR MEDIANO (prompt_trepar_mediano.txt), en 16:9 (1920x1080,
suelo en y=1040: a esta altura cabe de pie arriba), con el mismo sillar del
empuje v1 (0,55 del alto, referencias_empujar.py):
  referencia_trepar_mediano_inicio.png  abajo, pegado al sillar
  referencia_trepar_mediano_fin.png     de pie encima del sillar
Y para CAER de algo alto (prompt_caer.txt), otra vez en vertical, con una
plataforma de 1,8 del alto (la de bajar de un saltito, mas alta):
  referencia_caer_inicio.png  de pie encima, junto al borde
  referencia_caer_fin.png     abajo, al pie, donde se levanta  python referencias_trepar_bajar.py [carpeta de salida; por defecto esta]"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy.spatial import Delaunay

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
SALIDA = sys.argv[1] if len(sys.argv) > 1 else AQUI
VERDE = (36, 215, 50, 255)
ANCHO, ALTO, SUELO = 1080, 1920, 1880         # SUELO: fila de la planta del pie abajo
SS = 3                                        # supermuestreo del muro

rep = Image.open(os.path.join(ANIM, 'magnus_respirando', '04_limpios', 'c_01.png')).convert('RGBA')
op = np.asarray(rep)[..., 3] > 128
ys, xs = np.where(op)
H = ys.max() - ys.min()                       # 627: alto del peregrino
PIE_Y = ys.max()                              # 677
pies = np.where(op[PIE_Y - 25:PIE_Y + 1].any(0))[0]
TALON, PUNTA = pies.min(), pies.max()         # 285 y 336
ESPALDA, DELANTE = xs.min(), xs.max()         # 194 y 383

HM = round(1.15 * H)                          # alto del muro
ARRIBA = SUELO - HM + 1                       # fila de arriba del muro (la base en SUELO)
WM = 600                                      # ancho del muro que se ve
# trepar: el muro a la derecha, su cara en CARA_T
CARA_T = ANCHO - WM
PEGADO = round(0.08 * H)                      # de la punta del pie a la cara: el abrigo casi la toca
DENTRO = round(0.22 * H)                      # del borde al talon, de pie arriba al acabar
# bajar: el muro a la izquierda, su borde en BORDE_B
BORDE_B = 540
ASOMA = round(0.10 * H)                       # de la punta del pie al borde, arriba al empezar
CAE = round(0.35 * H)                         # del pie del muro al talon, abajo al acabar (saltito)


def muro(w, h, semilla=11):
    """Muro de sillares low-poly visto de lado: hiladas con las juntas
    desfasadas, cada sillar con sus caras planas; la cara y el filo de arriba,
    rectos."""
    rng = np.random.default_rng(semilla)
    W, Hh = w * SS, h * SS
    img = Image.new('RGBA', (W, Hh), (118, 110, 96, 255))   # el mortero, en las juntas
    d = ImageDraw.Draw(img)
    junta = 3 * SS
    hiladas = max(1, round(h / 144.2))        # hiladas de ~144 px: 5 en el muro de 1,15
    alto = Hh / hiladas
    base = np.array([172, 163, 145], float)  # caliza clara, la del sillar de empujar
    for f in range(hiladas):
        y0, y1 = f * alto, (f + 1) * alto
        x = 0.0
        while x < W - 1:
            largo = rng.uniform(1.1, 1.8) * alto
            if x == 0 and f % 2 == 1:         # hiladas alternas, juntas desfasadas
                largo *= 0.55
            x0, x1 = x, min(W, x + largo)
            if W - x1 < 0.5 * alto:           # sin trocitos al final
                x1 = W
            bx0 = x0 + (junta / 2 if x0 > 0 else 0)
            bx1 = x1 - (junta / 2 if x1 < W else 0)
            by0 = y0 + (junta / 2 if f > 0 else 0)
            by1 = y1 - (junta / 2 if f < hiladas - 1 else 0)
            pts = [(bx0, by0), (bx1, by0), (bx1, by1), (bx0, by1),
                   ((bx0 + bx1) / 2, by0), ((bx0 + bx1) / 2, by1), (bx0, (by0 + by1) / 2), (bx1, (by0 + by1) / 2)]
            for _ in range(7):
                pts.append((rng.uniform(bx0, bx1), rng.uniform(by0, by1)))
            pts = np.array(pts)
            tono = rng.uniform(-0.05, 0.05)   # cada sillar algo distinto
            for s in Delaunay(pts).simplices:
                p = pts[s]
                cy = (p[:, 1].mean() - by0) / (by1 - by0)
                gy = p[:, 1].mean() / Hh
                luz = 1.08 - 0.12 * cy - 0.10 * gy + tono + rng.uniform(-0.07, 0.07)
                col = tuple(int(v) for v in np.clip(base * luz, 0, 255)) + (255,)
                d.polygon([tuple(q) for q in p], fill=col)
            x = x1
    arr = np.asarray(img).astype(float)
    yy = np.arange(Hh)[:, None]
    arr[..., :3] *= np.where(yy < 5 * SS, 1.07, 1.0)[..., None]       # filo de arriba, a la luz
    arr[..., :3] *= np.where(yy > Hh - 8 * SS, 0.88, 1.0)[..., None]  # pie del muro
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    return img.resize((w, h), Image.LANCZOS)


m = muro(WM, HM)
m_bajar = m.transpose(Image.FLIP_LEFT_RIGHT)  # la cara recta, a la derecha: el borde del que baja
X_ABAJO_T = CARA_T - PEGADO - PUNTA
X_ARRIBA_T = CARA_T + DENTRO - TALON
X_ARRIBA_B = BORDE_B - ASOMA - PUNTA
X_ABAJO_B = BORDE_B + CAE - TALON
Y_ABAJO = SUELO - PIE_Y
Y_ARRIBA = ARRIBA - 1 - PIE_Y                 # la planta del pie sobre el filo del muro
casos = (('referencia_trepar_inicio.png', m, CARA_T, X_ABAJO_T, Y_ABAJO),
         ('referencia_trepar_fin.png', m, CARA_T, X_ARRIBA_T, Y_ARRIBA),
         ('referencia_bajar_inicio.png', m_bajar, BORDE_B - WM, X_ARRIBA_B, Y_ARRIBA),
         ('referencia_bajar_fin.png', m_bajar, BORDE_B - WM, X_ABAJO_B, Y_ABAJO))
for nombre, img_muro, xm, x0, y0 in casos:
    lien = Image.new('RGBA', (ANCHO, ALTO), VERDE)
    lien.alpha_composite(img_muro, (max(xm, 0), ARRIBA), (max(-xm, 0), 0))
    lien.alpha_composite(rep, (x0, y0))
    lien.convert('RGB').save(os.path.join(SALIDA, nombre))
    print('%-30s peregrino x %d-%d, pies en %d' % (nombre, x0 + ESPALDA, x0 + DELANTE, y0 + PIE_Y))
print('H %d  muro %dx%d (arriba en %d)  trepar: cara %d  bajar: borde %d'
      % (H, WM, HM, ARRIBA, CARA_T, BORDE_B))

# Subirse al sillar mediano (el del empuje v1), en 16:9
sys.path.insert(0, AQUI)
import referencias_empujar as E               # noqa: E402

fb, fw = E.VARIANTES['v1'][:2]
hs, ws = round(fb * H), round(fw * H)         # 345 x 389
sillar_m = E.sillar(ws, hs)                   # el mismo sillar del empuje v1
SUELO_M = 1040
ARRIBA_M = SUELO_M - hs + 1                   # fila de arriba del sillar
# de la espalda al empezar al filo derecho del sillar, centrado en el cuadro
CARA_M = (1920 - (ws + PEGADO + PUNTA - ESPALDA)) // 2 + PEGADO + PUNTA - ESPALDA
for nombre, x0, y0 in (('referencia_trepar_mediano_inicio.png', CARA_M - PEGADO - PUNTA, SUELO_M - PIE_Y),
                       ('referencia_trepar_mediano_fin.png', CARA_M + DENTRO - TALON, ARRIBA_M - 1 - PIE_Y)):
    lien = Image.new('RGBA', (1920, 1080), VERDE)
    lien.alpha_composite(sillar_m, (CARA_M, ARRIBA_M))
    lien.alpha_composite(rep, (x0, y0))
    lien.convert('RGB').save(os.path.join(SALIDA, nombre))
    print('%-38s peregrino x %d-%d y %d-%d' % (nombre, x0 + ESPALDA, x0 + DELANTE, y0 + ys.min(), y0 + PIE_Y))
print('sillar mediano %dx%d, cara en %d, arriba en %d' % (ws, hs, CARA_M, ARRIBA_M))

# CAER de algo alto (prompt_caer.txt), en vertical: una plataforma de 1,8 del alto
# (mas que el muro de bajar de un saltito); de pie arriba junto al borde, y abajo
# donde se levanta, al pie. (Si Flow bloquea el prompt, plan B sin plataforma:
# prompt_aterrizaje.txt, referencias en referencias_coger_tirar_tumbarse.py.)
HC = round(1.8 * H)
ARRIBA_C = SUELO - HC + 1
m_caer = muro(WM, HC, semilla=12).transpose(Image.FLIP_LEFT_RIGHT)
CAE_C = round(0.30 * H)                       # del pie de la plataforma al talon, abajo
for nombre, x0, y0 in (('referencia_caer_inicio.png', BORDE_B - ASOMA - PUNTA, ARRIBA_C - 1 - PIE_Y),
                       ('referencia_caer_fin.png', BORDE_B + CAE_C - TALON, SUELO - PIE_Y)):
    lien = Image.new('RGBA', (ANCHO, ALTO), VERDE)
    lien.alpha_composite(m_caer, (0, ARRIBA_C), (WM - BORDE_B, 0))
    lien.alpha_composite(rep, (x0, y0))
    lien.convert('RGB').save(os.path.join(SALIDA, nombre))
    print('%-30s peregrino x %d-%d y %d-%d' % (nombre, x0 + ESPALDA, x0 + DELANTE, y0 + ys.min(), y0 + PIE_Y))
print('plataforma de caer %dx%d, arriba en %d, borde en %d' % (WM, HC, ARRIBA_C, BORDE_B))

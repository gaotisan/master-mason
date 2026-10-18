"""Referencias 1920x1080 para el video de EMPUJAR (Flow, fotogramas a video):
  referencia_empujar[_v2]_inicio.png  el reposo del juego (peregrino_respirando
      c_01, sin baston: el guardado lo pinta el juego encima) con un sillar
      delante;
  referencia_empujar[_v2]_fin.png     lo mismo desplazado D a la derecha (lo
      que lo ha empujado).
Variantes:
  v1  prompt_empujar.txt: sillar mediano, algo por encima de la cintura, a medio
      paso (las manos acaban en su filo de arriba).
  v2  prompt_empujar_v2.txt: sillar alto (hasta los hombros) con la cara de
      empuje recta, a un brazo de distancia: empuja a media altura con las
      manos enteras planas y en vertical, como una puerta. Las manos a ~0,45
      del alto valen para el sillar de v1 (filo a 0,55) y para todo lo mas alto.
Casilla master 1:1 (584x720), pies en y=1040, croma #24D732. El sillar es de
relleno (low-poly, piedra clara para separarlo bien de la tunica oscura): se
quita al montar y el juego pone sus objetos. referencias_trepar_bajar.py usa el
mismo sillar mediano (sillar() y VARIANTES['v1']) para subirse a el.
  python referencias_empujar.py [v1|v2] [carpeta de salida; por defecto esta]"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy.spatial import Delaunay

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
VERDE = (36, 215, 50, 255)
SS = 3                                        # supermuestreo del sillar
# alto y ancho del sillar y hueco de la punta del pie a su cara (fracciones del
# alto del peregrino), cara de empuje recta, puntos de las caras, sufijo
VARIANTES = {
    'v1': (0.55, 0.62, 0.20, False, 26, ''),
    'v2': (0.90, 0.70, 0.35, True, 46, '_v2'),
}


def peregrino():
    """El reposo del juego y sus medidas: imagen, alto, fila de la planta, x de
    la espalda, del talon, de la punta del pie y de lo mas adelantado."""
    rep = Image.open(os.path.join(ANIM, 'peregrino_respirando', '04_limpios', 'c_01.png')).convert('RGBA')
    op = np.asarray(rep)[..., 3] > 128
    ys, xs = np.where(op)
    pie_y = ys.max()                          # 677
    pies = np.where(op[pie_y - 25:pie_y + 1].any(0))[0]
    return rep, ys.max() - ys.min(), pie_y, xs.min(), pies.min(), pies.max(), xs.max()


def sillar(w, h, recta=False, puntos=26, semilla=7):
    """Bloque de piedra low-poly de perfil: contorno algo picado y caras planas;
    recta: la cara de la izquierda (la de empuje) sin picar."""
    rng = np.random.default_rng(semilla)
    W, Hh = w * SS, h * SS
    c = 11 * SS                               # chaflan de las esquinas
    borde = []
    # cuatro lados con las esquinas achaflanadas; la base, recta (apoya en el suelo)
    for (x0, y0), (x1, y1) in (((c, 0), (W - c, 0)), ((W, c), (W, Hh - 2)), ((W - c, Hh), (c, Hh)), ((0, Hh - 2), (0, c))):
        for i in range(5):
            t = i / 5
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            if i > 0 and x0 == x1:            # pica los costados (la cara de empuje, recta en v2)
                picado = rng.uniform(-1.5, 1.5) * SS
                if not (recta and x0 == 0):
                    x += picado
            elif i > 0 and y0 == 0:           # y el filo de arriba
                y += rng.uniform(-1.5, 1.5) * SS
            borde.append((x, y))
    pts = list(borde)
    for _ in range(puntos):
        pts.append((rng.uniform(0.08, 0.92) * W, rng.uniform(0.08, 0.92) * Hh))
    pts = np.array(pts)
    tri = Delaunay(pts)
    img = Image.new('RGBA', (W, Hh), (0, 0, 0, 0))
    mask = Image.new('L', (W, Hh), 0)
    ImageDraw.Draw(mask).polygon([tuple(p) for p in borde], fill=255)
    d = ImageDraw.Draw(img)
    base = np.array([172, 163, 145], float)  # caliza clara, algo gris: piedra, no carton
    for s in tri.simplices:
        p = pts[s]
        cy = p[:, 1].mean() / Hh
        luz = 1.08 - 0.22 * cy + rng.uniform(-0.09, 0.09)   # mas claro arriba, caras marcadas
        col = tuple(int(v) for v in np.clip(base * luz, 0, 255)) + (255,)
        d.polygon([tuple(q) for q in p], fill=col)
    # filo de arriba algo mas claro y pie algo mas oscuro, como el sombreado del personaje
    arr = np.asarray(img).astype(float)
    yy = np.arange(Hh)[:, None]
    arr[..., :3] *= np.where(yy < 6 * SS, 1.07, 1.0)[..., None]
    arr[..., :3] *= np.where(yy > Hh - 10 * SS, 0.86, 1.0)[..., None]
    arr[..., 3] = np.asarray(mask)
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    return img.resize((w, h), Image.LANCZOS)


def main(variante, salida):
    fb, fw, fh, recta, puntos, sufijo = VARIANTES[variante]
    rep, H, pie_y, espalda, _, punta, _ = peregrino()
    hb, wb = round(fb * H), round(fw * H)
    hueco = round(fh * H)                     # de la punta del pie a la cara del sillar
    d = round(0.70 * H)                       # lo que lo empuja (~4 s a ~110 px/s de master;
                                              # andar va a 384)
    y0 = 1040 - pie_y
    tramo = (punta + hueco + wb + d) - espalda   # de la espalda al empezar al sillar al acabar
    x0 = (1920 - tramo) // 2 - espalda
    bloque = sillar(wb, hb, recta, puntos)
    for nombre, dx in (('referencia_empujar%s_inicio.png' % sufijo, 0), ('referencia_empujar%s_fin.png' % sufijo, d)):
        lien = Image.new('RGBA', (1920, 1080), VERDE)
        lien.alpha_composite(bloque, (x0 + punta + hueco + dx, 1040 - hb + 1))   # base en la 1040, como los pies
        lien.alpha_composite(rep, (x0 + dx, y0))
        lien.convert('RGB').save(os.path.join(salida, nombre))
        q = np.asarray(lien.convert('RGB')).astype(int)
        v = (q[..., 1] > 150) & (q[..., 0] < 100) & (q[..., 2] < 120)
        yy, xx = np.where(~v)
        print(nombre, 'todo x %d-%d y %d-%d' % (xx.min(), xx.max(), yy.min(), yy.max()))
    print('%s: H %d  sillar %dx%d  hueco %d  D %d  X0 %d  Y0 %d  espalda %d  punta %d  cara del sillar %d'
          % (variante, H, wb, hb, hueco, d, x0, y0, x0 + espalda, x0 + punta, x0 + punta + hueco))


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'v1', sys.argv[2] if len(sys.argv) > 2 else AQUI)

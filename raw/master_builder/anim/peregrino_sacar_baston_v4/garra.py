"""La garra (donde va la bola) en cada fotograma del sacar v4 -> baston/garra_sacar_v4.json.

Casilla master de 744 (la de 584 con 80 px mas a cada lado: al descolgarlo la
punta del baston sale por delante). Tres tramos, comprobados con una bola
simulada detras del sprite (como la pinta el juego) fotograma a fotograma:
  - c_01-c_26: patron desde el primer fotograma (garra_patron.seguir, caso
    "sacar_v4"): la garra a la espalda, detras de la capucha, mientras el
    baston se inclina y vuelve;
  - c_27-c_37: a mano (MARCAS): la garra pasa por encima de la cabeza, tapada
    casi entera por la capucha, y sale por delante; el patron se iba a la mano;
  - c_38-c_63: patron desde el final hacia atras con la garra del reposo con el
    baston en la mano (el de ahora del juego): la garra en anillo delante de la
    cara hasta asentarse.
mano.py la suaviza ([1,2,1]), la pasa a la casilla de 584 y empalma los
extremos con la bola a la espalda y la del reposo en la mano.
  python garra.py"""
import json
import os
import sys

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
BASTON = os.path.join(os.path.dirname(AQUI), 'baston')
sys.path.insert(0, BASTON)
os.chdir(BASTON)
import garra_patron as GP
import giro_mano as G
import mano

MARGEN = 80
N = 63
MARCAS = {27: (355, 80), 28: (375, 70), 29: (395, 62), 30: (410, 56), 31: (425, 62), 32: (445, 70), 33: (455, 75), 34: (462, 85), 35: (476, 90), 36: (485, 105), 37: (492, 110)}
HASTA_PATRON, DESDE_ATRAS = 26, 38


def leer(c):
    return np.asarray(Image.open(os.path.join(AQUI, '04_limpios', 'c_%02d.png' % c)).convert('RGBA'))


if __name__ == '__main__':
    ida = GP.seguir('sacar_v4')
    rep, orbe = G.reposo_mano()
    rep744 = np.zeros((720, 584 + 2 * MARGEN, 4), np.uint8)
    rep744[:, MARGEN:MARGEN + 584] = rep
    g0 = mano.garra(rep744)
    off = (orbe[0] + MARGEN - g0[0], orbe[1] - g0[1])           # del hueco de garra() a la bola del reposo
    atras = mano.garra_patron([rep744] + [leer(c) for c in range(N, DESDE_ATRAS - 1, -1)], rep744)[1:][::-1]
    out = []
    for c in range(1, N + 1):
        if c <= HASTA_PATRON:
            e = ida[c - 1]
            x, y = e['x'], e['y']
        elif c in MARCAS:
            x, y = MARCAS[c]
        else:
            p = atras[c - DESDE_ATRAS]
            x, y = p[0] + off[0], p[1] + off[1]
        out.append({'x': round(float(x), 1), 'y': round(float(y), 1)})
    ruta = os.path.join(BASTON, 'garra_sacar_v4.json')
    with open(ruta, 'w', encoding='utf-8') as f:
        json.dump(out, f)
    print('escrito', ruta, len(out), 'fotogramas')
    print(' '.join('c%02d:(%.0f,%.0f)' % (i + 1, e['x'], e['y']) for i, e in enumerate(out)))

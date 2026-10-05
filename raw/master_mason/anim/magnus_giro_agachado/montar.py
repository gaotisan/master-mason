"""Monta los 5 sprites del giro agachado en 04_limpios, en el orden del juego.

  c_01  el agachado del juego (magnus_agacharse c_089, el fotograma del bucle por
        el que se entra y se sale): el giro arranca exacto desde el bucle
  c_02  vista 2 de la IA, tres cuartos (unos 35 grados)
  c_03  vista 5, de frente
  c_04  vista 2 espejada
  c_05  el agachado espejado: al acabar, magnus.gd voltea el sprite y el bucle
        sigue por el c_089 volteado, que es este mismo dibujo
El espejo va contra el centro de la casilla, que es lo que hace flip_h. Las
vistas vienen de _vistas/ (ya centradas, sin fondo, con el color igualado y en
el suelo de siempre) y se mueven 1 px a la derecha, lo que mejor encaja la
vista de perfil con el agachado (0,190 frente a 0,200).
Por que estas (distancia entre sprites seguidos; giro de pie 1,17 0,94 0,88 1,17):
  agachado v2 v5 m2 m_agachado              0,62 1,28 1,27 0,62
  con la v4 (68 grados) entre v2 y el frente 0,62 1,47 0,95 0,95 1,47 0,62
La v4 tiene las manos y la tunica de otra manera: se aparta del camino entre la
v2 y el frente (a 1,57 de la v2 y 1,04 del frente, cuando de la v2 al frente hay
1,37) y mete un salto mayor. La v3 casi repite la v2 (0,36) y la v1 es el perfil,
que ya da el agachado del juego.
    python montar.py
"""
import os, shutil
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
VISTAS = os.path.join(AQUI, '_vistas')
SALIDA = os.path.join(AQUI, '04_limpios')
AGACHADO = os.path.join(AQUI, '..', 'magnus_agacharse', '04_limpios', 'c_089.png')
DX = 1


def vista(n):
    im = np.asarray(Image.open(os.path.join(VISTAS, 'c_%02d.png' % n)).convert('RGBA'))
    out = np.zeros_like(im)
    out[:, DX:] = im[:, :-DX]
    return out


ag = np.asarray(Image.open(AGACHADO).convert('RGBA'))
espejo = lambda a: a[:, ::-1]
for f in os.listdir(SALIDA):
    os.remove(os.path.join(SALIDA, f))
for k, a in enumerate([ag, vista(2), vista(5), espejo(vista(2)), espejo(ag)]):
    Image.fromarray(np.ascontiguousarray(a)).save(os.path.join(SALIDA, 'c_%02d.png' % (k + 1)))
print('5 sprites en 04_limpios')

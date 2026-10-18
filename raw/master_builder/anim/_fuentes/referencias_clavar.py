"""Referencias 1920x1080 (16:9) para CLAVAR el baculo y ARRANCARLO
(prompt_clavar_baculo.txt; Flow, fotogramas a video):
  referencia_clavar_inicio.png  = referencia_arrancar_fin.png: el reposo con el
      baston en la mano del juego (giro_mano.reposo_mano), garra VACIA
  referencia_clavar_fin.png     = referencia_arrancar_inicio.png: el reposo
      normal (peregrino_respirando c_01) con el baston clavado delante, donde lo
      tenia en la mano, hundido HUNDIDO px en el suelo
Casilla master 1:1 en x=668 (como las de sacar el baston), pies en y=1040, croma
#24D732. El baston clavado sale del propio reposo con baston, para que sea el
mismo dibujo: lo que hay a la derecha del cuerpo (la garra y la vara), con el
tramo que tapa la mano (filas 303-341 de la casilla) rellenado con el de debajo.
  python referencias_clavar.py [carpeta de salida; por defecto esta]"""
import os
import sys

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
BASTON = os.path.join(os.path.dirname(AQUI), 'baston')
SALIDA = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else AQUI
sys.path.insert(0, AQUI)
sys.path.insert(0, BASTON)
import referencias_empujar as E               # noqa: E402

os.chdir(BASTON)
import giro_mano as G                         # noqa: E402

rep, H, PIE_Y, ESPALDA, TALON, PUNTA, DELANTE = E.peregrino()
X0, Y0 = 668, 1040 - PIE_Y
HUNDIDO = round(0.08 * H)                     # lo que se mete en el suelo al clavarlo
MANO = (303, 342)                             # filas que tapa la mano (medidas)

con = G.reposo_mano()[0]                      # 720x584 RGBA, el reposo con el baston en la mano
assert con.shape == (720, 584, 4), con.shape
vara = np.zeros_like(con)
vara[:MANO[0], 380:] = con[:MANO[0], 380:]    # garra y vara de encima de la mano (la barba acaba en 371)
vara[MANO[1]:, 412:] = con[MANO[1]:, 412:]    # vara de debajo (la manga llega a 405)
n = MANO[1] - MANO[0]
vara[MANO[0]:MANO[1], 412:] = con[MANO[1]:MANO[1] + n, 412:]   # el tramo de la mano, con el de debajo
clavada = np.zeros_like(vara)
clavada[HUNDIDO:] = vara[:-HUNDIDO]           # hundida
clavada[PIE_Y + 1:] = 0                       # lo que queda bajo el suelo no se ve
ys = np.where(clavada[..., 3].any(1))[0]
print('baston clavado: filas %d-%d de la casilla (en la mano %d-%d)'
      % (ys.min(), ys.max(), np.where(vara[..., 3].any(1))[0].min(), np.where(vara[..., 3].any(1))[0].max()))

inicio = Image.fromarray(con)
fin = Image.fromarray(clavada)
fin.alpha_composite(rep)                      # el cuerpo (no se tocan: el reposo acaba en x 383)
for nombres, celda in ((('referencia_clavar_inicio.png', 'referencia_arrancar_fin.png'), inicio),
                       (('referencia_clavar_fin.png', 'referencia_arrancar_inicio.png'), fin)):
    lien = Image.new('RGBA', (1920, 1080), E.VERDE)
    lien.alpha_composite(celda, (X0, Y0))
    for nombre in nombres:
        lien.convert('RGB').save(os.path.join(SALIDA, nombre))
        print(nombre)

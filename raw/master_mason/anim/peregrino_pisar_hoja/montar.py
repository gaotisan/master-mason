"""PISAR UNA HOJA EN LA LUZ (2026-10-14): el peregrino cae flotando sobre una hoja,
la pisa, flexiona con ella y se impulsa. Video de Flow del usuario
(_fuentes/Pilgrim_jumping_on_floating_leaf_20261014022349.mp4, 24 fps): "como
el peregrino dentro de la luz pisa las hojas y se impulsa con ellas queda un
poco falso, he creado una animacion nueva; centrate en la parte en la que pisa
la hoja y en como enlazarla con la flotacion".

El video (medido con la silueta, a 24 fps):
   0-13  baja hacia la hoja, piernas recogidas y la tunica abierta
  14-16  los pies tocan la hoja
  16-27  flexiona: el cuerpo baja ~38 px de master con los pies quietos
  27-35  empuja (los pies aun en la hoja)
     36  despega
  36-59  sube hasta quedarse de pie flotando
Se usa del 14 (toca) al 36 (despega): `flotar_pisar`. En el juego el nodo va
pegado a la hoja mientras dura (los pies en ella, que se hunde con el) y al
acabar sale el rebote de siempre (peregrino.gd, PISAR LA HOJA).

Encaje: a la escala de los otros videos de flotar (1,5054: de pie flotando mide
411 px de video y el reposo 619 de master) y con los pies sobre la hoja en el
sitio de los pies de pie del juego (x del centro de los pies del c_01 del salto
de parado; fila de la planta = ORIGEN - PLANTA). La hoja del video se quita por
color (sin_croma de montar_flotar.py).

Pies: el video los saco descalzos (color carne, con dedos) y las piernas
verdosas. pies.py los lleva al color de los de flotar (piernas a las del salto
en el aire, pies al marron oscuro), despues de casillas.

  python montar.py casillas
  python ../igualar_tono.py peregrino_pisar_hoja "1-23"
  python pies.py
  python montar.py hoja        (anade flotar_pisar a flotar.json)
"""
import glob
import json
import os
import sys

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
PROYECTO = os.path.abspath(os.path.join(ANIM, '..', '..', '..'))
sys.path.insert(0, os.path.join(ANIM, 'peregrino_flotar'))
import montar_flotar as mf   # noqa: E402  (fotogramas, sin_croma, medidas)

VIDEO = os.path.join(ANIM, '_fuentes', 'Pilgrim_jumping_on_floating_leaf_20261014022349.mp4')
LIMPIOS = os.path.join(AQUI, '04_limpios')
SALIDA = os.path.join(AQUI, '05_salida')
JUEGO = os.path.join(PROYECTO, 'assets', 'characters', 'peregrino')
FLOTAR_JSON = os.path.join(JUEGO, 'flotar.json')

ESCALA = 1.5054           # la de los otros videos de flotar
PIES_VIDEO = (645.5, 607.0)   # centro de los pies sobre la hoja y su planta, en el video
CASILLA_W = 584           # como las de master: el eje del cuerpo en x 292
CASILLA_H = 910
ORIGEN = 900              # fila de la linea de suelo (aqui, la hoja)
PLANTA = 13               # la planta del pie de pie, sobre la linea de suelo
PIES_X = 312.5            # centro de los pies del c_01 del salto de parado
DESDE, HASTA = 14, 36     # toca -> despega
FPS = 48.0                # el doble del video (los saltos van a 2,5x; aqui algo mas lento)


def registro():
    dx = round(PIES_X - PIES_VIDEO[0] * ESCALA)
    dy = round((ORIGEN - PLANTA) - PIES_VIDEO[1] * ESCALA)
    return dx, dy


def casillas():
    os.makedirs(LIMPIOS, exist_ok=True)
    for f in glob.glob(os.path.join(LIMPIOS, 'c_*.png')):
        os.remove(f)
    dx, dy = registro()
    k = 1
    for i, f in mf.fotogramas(VIDEO, DESDE, HASTA):
        rgba = mf.sin_croma(f)
        im = Image.fromarray(rgba).resize((round(mf.VW * ESCALA), round(mf.VH * ESCALA)), Image.LANCZOS)
        lien = Image.new('RGBA', (CASILLA_W, CASILLA_H), (0, 0, 0, 0))
        lien.alpha_composite(im, (dx, dy))
        lien.save(os.path.join(LIMPIOS, 'c_%03d.png' % k))
        k += 1
    print('casillas: video %d-%d -> c_001-c_%03d (registro %d, %d)' % (DESDE, HASTA, k - 1, dx, dy))


def hoja():
    ims = [Image.open(r).convert('RGBA') for r in sorted(glob.glob(os.path.join(LIMPIOS, 'c_*.png')))]
    n = len(ims)
    y0 = x0 = 10 ** 6
    y1 = x1 = 0
    for im in ims:
        ys, xs = np.where(np.asarray(im)[..., 3] > 8)
        y0, y1, x0, x1 = min(y0, ys.min()), max(y1, ys.max()), min(x0, xs.min()), max(x1, xs.max())
    y0, x0 = max(y0 - 4, 0) // 2 * 2, max(x0 - 4, 0) // 2 * 2
    y1, x1 = min(y1 + 6, CASILLA_H) // 2 * 2, min(x1 + 6, CASILLA_W) // 2 * 2
    y0, y1, x0, x1 = int(y0), int(y1), int(x0), int(x1)
    hw, hh = (x1 - x0) // 2, (y1 - y0) // 2
    cols = min(n, 12)
    filas = (n + cols - 1) // cols
    lamina = Image.new('RGBA', (cols * hw, filas * hh), (0, 0, 0, 0))
    cuerpo, pies = [], []
    for j, im in enumerate(ims):
        arriba, cy, abajo = mf.medidas(np.asarray(im))
        cuerpo.append(round((ORIGEN - (arriba + cy) / 2.0) / 2.0, 1))
        pies.append(round(max(ORIGEN - PLANTA - abajo, 0) / 2.0, 1))
        lamina.alpha_composite(im.crop((x0, y0, x1, y1)).resize((hw, hh), Image.LANCZOS),
                               ((j % cols) * hw, (j // cols) * hh))
    os.makedirs(SALIDA, exist_ok=True)
    archivo = 'peregrino_flotar_pisar.png'
    lamina.save(os.path.join(SALIDA, archivo))
    lamina.save(os.path.join(JUEGO, archivo))
    entrada = {
        'hoja': 'res://assets/characters/peregrino/%s' % archivo,
        'n': n, 'cols': cols, 'casilla': [hw, hh], 'fps': FPS, 'bucle': False,
        'offset': [-round(((CASILLA_W / 2.0 - x0) - (x1 - x0) / 2.0) / 2.0, 1),
                   -round(((ORIGEN - y0) - (y1 - y0) / 2.0) / 2.0, 1)],
        'cuerpo': cuerpo, 'pies': pies,
    }
    datos = json.load(open(FLOTAR_JSON))
    datos['flotar_pisar'] = entrada
    json.dump(datos, open(FLOTAR_JSON, 'w'), indent=1)
    json.dump(datos, open(os.path.join(ANIM, 'peregrino_flotar', '05_salida', 'flotar.json'), 'w'), indent=1)
    print('flotar_pisar: %d fotogramas a %.0f fps, cuerpo %.1f -> %.1f (min %.1f), pies %s' % (
        n, FPS, cuerpo[0], cuerpo[-1], min(cuerpo), pies))


if __name__ == '__main__':
    {'casillas': casillas, 'hoja': hoja}[sys.argv[1]]()

"""Rampa de tamano y posicion del arranque: empieza igual que el agachado del juego
y acaba como el ciclo.

La escala por el zoom (escalar.py) deja el primer sprite un 2 % mas grande que
el agachado del juego (494 px de alto frente a 485) y con los pies 5 px mas
abajo: al arrancar, la cabeza subia y los pies bajaban de golpe (lo vio el
usuario). Medido por distancia: el primero casa con el agachado escalado a
0,985 y movido (+1, -3) (0,107, antes 0,173); el ultimo casa con el ciclo sin
escalar y movido (+1, 0) (0,174, antes 0,194). Se reparte en linea recta a lo
largo del arranque. La escala se hace sobre el pie (centro de abajo del dibujo)
y en premultiplicado, para no ensuciar el borde. Parte de _sin_ajuste_tamano/.
    python ajustar_tamano.py
"""
import glob, os, shutil
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
CARPETA = os.path.join(AQUI, '04_limpios')
COPIA = os.path.join(AQUI, '_sin_ajuste_tamano')
INICIO = (0.985, 1, -3)     # escala, dx, dy del primer sprite
FIN = (1.0, 1, 0)           # y del ultimo

if not os.path.isdir(COPIA):
    shutil.copytree(CARPETA, COPIA)
fs = sorted(glob.glob(os.path.join(COPIA, '*.png')))
for k, f in enumerate(fs):
    t = k / float(len(fs) - 1)
    s, dx, dy = [a + t * (b - a) for a, b in zip(INICIO, FIN)]
    im = Image.open(f).convert('RGBA')
    a = np.asarray(im)[..., 3] > 128
    ys, xs = np.where(a)
    cx, by = (xs.min() + xs.max()) / 2.0, float(ys.max())
    w, h = im.size
    p = im.convert('RGBa').resize((int(round(w * s)), int(round(h * s))), Image.LANCZOS)
    out = Image.new('RGBa', (w, h), (0, 0, 0, 0))
    out.paste(p, (int(round(cx - cx * s + dx)), int(round(by - by * s + dy))))
    out.convert('RGBA').save(os.path.join(CARPETA, os.path.basename(f)))
print('%d sprites: escala %.3f -> %.3f, desplazamiento (%+d, %+d) -> (%+d, %+d)' % (
    len(fs), INICIO[0], FIN[0], INICIO[1], INICIO[2], FIN[1], FIN[2]))

"""La funda de cuero del baston a la espalda, en dos capas.

Idea del usuario (2026-10-08, concepto de Gemini Gemini_Generated_Image_zgihfez
gihfezgih.jpeg en _fuentes/baston_concepto_funda.jpeg): el baston guardado va
por FUERA de la tunica, en diagonal por la espalda, metido en un tubo corto de
cuero cosido a la altura del omoplato. Pieza: _fuentes/baston_funda_cuero.jpeg
(Gemini, 1376x768, croma verde): tubo vertical visto de frente, con las dos
bocas abiertas (interior oscuro), costuras a los lados y una lengueta con
remache arriba y abajo para coserla.

Para que el baston pase POR DENTRO se parte en dos capas:
  funda_cuero_atras.png    lenguetas, interior de las bocas y su borde de atras
                           (detras del baston)
  funda_cuero_delante.png  la pared de delante del tubo y las costuras (delante)
Las bocas se segmentan por el interior oscuro (luminancia < 40, componente
mayor arriba y abajo); por columna, la pared de delante va de la fila mas baja
de la boca de arriba a la mas alta de la de abajo (donde no hay boca, del
principio al final del cuerpo, filas 190-578).

Escala: la boca (130 px) = 2,4 veces el palo del baston a esa altura (5 px de
hoja), como en el concepto -> 0,092 px de hoja por px de imagen. Se guarda a
4x hoja (0,37) para el primer plano, suavizada 1 px de master como la garra.
Color: se deja el de Gemini (ya casa con la madera y la tunica).
    python funda_cuero.py
"""
import json, os
import numpy as np
from PIL import Image, ImageFilter
from scipy.ndimage import label, distance_transform_edt

AQUI = os.path.dirname(os.path.realpath(__file__))
PROY = os.path.abspath(os.path.join(AQUI, '..', '..', '..', '..'))
SRC = os.path.join(PROY, 'raw', 'master_mason', 'anim', '_fuentes', 'baston_funda_cuero.jpeg')
DST = os.path.join(PROY, 'assets', 'characters', 'baston')
HOJA = 12.0 / 130.0           # px de hoja por px de imagen
TEX = 4.0                     # la textura va a 4x hoja
CUERPO = (190, 578)           # filas del tubo (sin las lenguetas)

g = np.asarray(Image.open(SRC).convert('RGB')).astype(float)
fondo = np.median(g[:40, :200].reshape(-1, 3), 0)
d = g[..., 1] - np.maximum(g[..., 0], g[..., 2])
fuera = fondo[1] - max(fondo[0], fondo[2]) - 15
alfa = np.clip((fuera - d) / (fuera - 5), 0, 1)
lab, _ = label(alfa > 0.5)
alfa *= lab == (np.bincount(lab.ravel())[1:].argmax() + 1)
solido = alfa >= 0.95
_, (iy, ix) = distance_transform_edt(~solido, return_indices=True)
col = g.copy()
borde = (alfa > 0) & ~solido
col[borde] = col[iy[borde], ix[borde]]
col[..., 1] = np.minimum(col[..., 1], np.maximum(col[..., 0], col[..., 2]))

# las bocas
lum = g.mean(2)
lab, n = label((lum < 40) & solido)
comps = sorted(((np.sum(lab == i), i) for i in range(1, n + 1)), reverse=True)
bocas = []
for _, i in comps:
    ys = np.nonzero(lab == i)[0]
    if ys.mean() < 384 and not any(b[0] == 'arriba' for b in bocas):
        bocas.append(('arriba', lab == i))
    elif ys.mean() >= 384 and not any(b[0] == 'abajo' for b in bocas):
        bocas.append(('abajo', lab == i))
    if len(bocas) == 2:
        break
arriba = dict(bocas)['arriba']; abajo = dict(bocas)['abajo']
H, W = alfa.shape
delante = np.zeros_like(solido)
for x in range(W):
    ya = np.nonzero(arriba[:, x])[0]; yb = np.nonzero(abajo[:, x])[0]
    y0 = ya.max() + 1 if len(ya) else CUERPO[0]
    y1 = yb.min() if len(yb) else CUERPO[1] + 1
    delante[y0:y1, x] = True
delante &= alfa > 0

ys, xs = np.nonzero(alfa > 0)
caja = (xs.min() - 4, ys.min() - 4, xs.max() + 5, ys.max() + 5)
eje_x = float(np.nonzero(arriba.any(0) | abajo.any(0))[0].mean())   # centro de las bocas
s = HOJA * TEX
salida = {}
for nombre, m in (('atras', alfa * ~delante), ('delante', alfa * delante)):
    im = Image.fromarray(np.dstack([col * (m[..., None] > 0), m * 255]).round().astype(np.uint8), 'RGBA').crop(caja)
    im = im.convert('RGBa').resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    im = im.filter(ImageFilter.GaussianBlur(TEX / 2 * 0.5)).convert('RGBA')
    im.save(os.path.join(DST, 'funda_cuero_%s.png' % nombre))
    salida['tamano'] = [im.width, im.height]
# en la textura: el eje de las bocas (donde va el palo) y el centro del tubo
salida['eje'] = [round((eje_x - caja[0]) * s, 2), round(((CUERPO[0] + CUERPO[1]) / 2 - caja[1]) * s, 2)]
salida['escala'] = 1 / TEX
json.dump(salida, open(os.path.join(DST, 'funda_cuero.json'), 'w'))
print('funda_cuero_atras/delante.png', salida)

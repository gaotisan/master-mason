"""Derribo: en el fotograma del golpe la IA pinta un proyectil, una varilla oscura
que sale de la mano hacia la derecha con una estela verde clara (video f028-f029,
c_021 y c_022 de 04_limpios). En el juego no hay proyectil: se pinta de croma,
antes de fondo.ps1 (o fondo_paralelo.py), lo que hay por delante de la mano en la
franja de la estela: la estela (verde claro) y, en c_021, la varilla.
  python borrar_rayo.py   (sobre 04_limpios, con el croma aun puesto)"""
import os
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
VERDE = (47, 208, 66)
FRANJA = (185, 246)            # filas de la estela
DESDE_X = 470                   # por delante de la mano
VARILLA = (528, 760, 198, 234)  # c_021: x0, x1, y0, y1 (hasta la punta)
RESTO = (530, 195, 248)          # c_022: x0, y0, y1, lo fino que quede de la estela
# el trozo de varilla junto a la barba (c_021) y las plumas que asoman por la
# espalda (c_022): la varilla oscura y las plumas claras, no la tunica ni la barba
TROZO = {21: (466, 534, 204, 234), 22: (296, 356, 218, 252)}

for k in (21, 22):
    ruta = os.path.join(AQUI, '04_limpios', 'c_%03d.png' % k)
    a = np.asarray(Image.open(ruta).convert('RGB')).copy()
    x = a.astype(int)
    claro = (x[..., 1] - x[..., 0] > 25) & (x[..., 1] - x[..., 2] > 25) & (x[..., 0] > 70)
    zona = np.zeros(claro.shape, bool)
    zona[FRANJA[0]:FRANJA[1], DESDE_X:] = True
    borra = claro & zona
    if k == 21:
        x0, x1, y0, y1 = VARILLA
        borra[y0:y1, x0:x1] = True
    else:
        x0, y0, y1 = RESTO
        no_verde = np.abs(x - np.array(VERDE)).max(-1) > 30
        borra[y0:y1, x0:] |= no_verde[y0:y1, x0:]
    x0, x1, y0, y1 = TROZO[k]
    caja = np.zeros(claro.shape, bool)
    caja[y0:y1, x0:x1] = True
    oscuro = x.max(-1) < 70
    pluma = (x.min(-1) > 150) & (np.abs(x[..., 0] - x[..., 2]) < 30)
    mx, mn = x.max(-1), x.min(-1)
    tunica = (x[..., 0] > x[..., 1]) & (x[..., 1] >= x[..., 2] - 4) & ((mx - mn) > 0.15 * np.maximum(mx, 1))
    if k == 21:
        borra |= caja                       # delante de la barba: todo (varilla, plumas y su borde)
    else:
        # en la espalda: solo las plumas (muy claras) y su borde verdoso; la
        # tunica (tambien sus paneles grises) se queda
        verdoso = (x[..., 1] > x[..., 0] + 8) & (x[..., 1] > x[..., 2] + 8)
        borra |= caja & ((mn > 140) | verdoso)
    a[borra] = VERDE
    Image.fromarray(a).save(ruta)
    print('c_%03d: %d px a croma' % (k, int(borra.sum())))

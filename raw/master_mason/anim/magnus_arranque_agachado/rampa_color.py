"""Rampa de color del arranque: empieza igualado al agachado del juego y acaba
igualado al ciclo del andar agachado.

igualar_color.py iguala el arranque por su principio (el agachado quieto). Pero
en el video la luz cambia mientras la camara se aleja, y el final del arranque
(video 46) sale un 2 % mas claro que el fotograma del ciclo por el que entra
(c_23, video 164): (94,2, 69,9, 61,7) frente a (92,4, 68,3, 60,1). Se corrige
en rampa, de nada en el primer sprite a todo en el ultimo, con el mismo peso por
saturacion que igualar_color.py (solo la tunica). Parte de _sin_rampa/.
    python rampa_color.py
"""
import glob, os, shutil
import numpy as np
from PIL import Image
aqui = os.path.dirname(os.path.abspath(__file__))
carpeta = os.path.join(aqui, '04_limpios'); copia = os.path.join(aqui, '_sin_rampa')
CICLO = os.path.join(aqui, '..', 'magnus_andar_agachado', '04_limpios', 'c_23.png')
def leer(f): return np.asarray(Image.open(f).convert('RGBA')).astype(float) / 255
def peso(rgb):
    mx = rgb.max(-1); mn = rgb.min(-1); s = (mx - mn) / np.maximum(mx, 1e-6)
    return np.clip((s - 0.08) / 0.12, 0, 1) * (rgb[..., 0] > rgb[..., 2])
def media(im):
    rgb = im[..., :3]; mx = rgb.max(-1); mn = rgb.min(-1); s = (mx - mn) / np.maximum(mx, 1e-6)
    t = (im[..., 3] > 0.8) & (rgb[..., 0] > rgb[..., 1]) & (rgb[..., 1] >= rgb[..., 2] - 0.02) & (s > 0.12) & (mx > 0.15) & (mx < 0.85)
    return rgb[t].mean(0)
if not os.path.isdir(copia):
    shutil.copytree(carpeta, copia)
fs = sorted(glob.glob(os.path.join(copia, '*.png')))
g_fin = media(leer(CICLO)) / media(leer(fs[-1]))
for k, f in enumerate(fs):
    im = leer(f); t = k / float(len(fs) - 1)
    g = 1 + t * (g_fin - 1)
    im[..., :3] = np.clip(im[..., :3] * (1 + peso(im[..., :3])[..., None] * (g - 1)), 0, 1)
    Image.fromarray((im * 255).round().astype(np.uint8)).save(os.path.join(carpeta, os.path.basename(f)))
print('rampa hasta (%.3f, %.3f, %.3f); final ahora %s, ciclo %s' % (tuple(g_fin) + (
    tuple((media(leer(os.path.join(carpeta, os.path.basename(fs[-1])))) * 255).round(1)), tuple((media(leer(CICLO)) * 255).round(1)))))

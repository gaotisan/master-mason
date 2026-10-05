"""Lleva el color de la tunica de todo el job al del agachado del juego, con UNA ganancia comun.

Copiado de magnus_agacharse/igualar_color.py. Aqui la referencia no es el reposo
sino el bucle agachado ya igualado (magnus_agacharse c_062-c_089), que es desde
donde se entra y adonde se vuelve: agachado, la luz sobre la tunica no es la de
de pie. La ganancia sale de los dos sprites quietos del final del video (los dos
ultimos de la seleccion, c_43 y c_44: fotogramas 225 y 235), que son la misma
pose agachada. Se aplica en proporcion a
la saturacion (solo lo calido, sin borde entre paneles) y no toca capucha,
barba ni piernas. Copia previa en _sin_igualar_color/; parte siempre de ella.
    python igualar_color.py
"""
import glob, os, shutil
import numpy as np
from PIL import Image
aqui = os.path.dirname(os.path.abspath(__file__))
carpeta = os.path.join(aqui, '04_limpios'); copia = os.path.join(aqui, '_sin_igualar_color')
REF = [os.path.join(aqui, '..', 'magnus_agacharse', '04_limpios', 'c_%03d.png' % k) for k in range(62, 90)]

def tunica(rgb):
    mx = rgb.max(-1); mn = rgb.min(-1); s = (mx - mn) / np.maximum(mx, 1e-6)
    return (rgb[..., 0] > rgb[..., 1]) & (rgb[..., 1] >= rgb[..., 2] - 0.02) & (s > 0.12) & (mx > 0.15) & (mx < 0.85)

def leer(f):
    return np.asarray(Image.open(f).convert('RGBA')).astype(float) / 255

def media(ims):
    px = [im[..., :3][(im[..., 3] > 0.8) & tunica(im[..., :3])] for im in ims]
    return np.concatenate(px).mean(0)

if not os.path.isdir(copia):
    shutil.copytree(carpeta, copia)
fs = sorted(glob.glob(os.path.join(copia, '*.png')))
ref = media([leer(f) for f in REF])
de_pie = [leer(f) for f in fs[-2:]]
def aplicar(im, g):
    rgb = im[..., :3]; mx = rgb.max(-1); mn = rgb.min(-1); s = (mx - mn) / np.maximum(mx, 1e-6)
    peso = np.clip((s - 0.08) / 0.12, 0, 1) * (rgb[..., 0] > rgb[..., 2])
    out = im.copy(); out[..., :3] = np.clip(rgb * (1 + peso[..., None] * (g - 1)), 0, 1); return out
g = np.ones(3)
for _ in range(4):   # el peso no es 1 en toda la tunica: se afina la ganancia hasta caer en la media
    g = g * ref / media([aplicar(im, g) for im in de_pie])
for f in fs:
    Image.fromarray((aplicar(leer(f), g) * 255).round().astype(np.uint8)).save(os.path.join(carpeta, os.path.basename(f)))
print('ganancia comun (%.3f, %.3f, %.3f); reposo %s; de pie ahora %s' % (g[0], g[1], g[2],
      tuple(int(v) for v in (ref * 255).round()), tuple(int(v) for v in (media([leer(os.path.join(carpeta, os.path.basename(f))) for f in fs[:10]]) * 255).round())))

"""Rampa de color en los extremos de pie: que casen con el reposo.

igualar_color.py iguala toda la hoja con una sola ganancia (sacada de los diez
primeros, de pie). Pero la luz del video cambia con la postura: al final del
levantarse (c_118-c_127) la tunica sale mas clara, hasta (99,2, 72,7, 62,9) en
el c_127 frente a (95,1, 70,2, 61,6) del reposo, y el c_127 es a la vez el
ultimo de incorporarse y el primero de agacharse (el puente): al agacharse y al
levantarse habia un fogonazo de 4 niveles. Aqui se lleva el c_127 al reposo en
rampa desde el c_118, y el principio de la bajada (c_001, +2) igual, en rampa
hasta el c_005. Mismo peso por saturacion que igualar_color.py (solo tunica).
Parte de _sin_rampa/ (solo los sprites que toca).
    python rampa_color.py
"""
import glob, os, shutil
import numpy as np
from PIL import Image
AQUI = os.path.dirname(os.path.abspath(__file__))
CARPETA = os.path.join(AQUI, '04_limpios'); COPIA = os.path.join(AQUI, '_sin_rampa')
REPOSO = sorted(glob.glob(os.path.join(AQUI, '..', 'magnus_respirando', '04_limpios', '*.png')))[:29]
TRAMOS = [(127, 118), (1, 5)]    # (sprite que va al color del reposo, sprite donde la rampa ya no toca)

def leer(f): return np.asarray(Image.open(f).convert('RGBA')).astype(float) / 255
def media(im):
    rgb = im[..., :3]; mx = rgb.max(-1); mn = rgb.min(-1); s = (mx - mn) / np.maximum(mx, 1e-6)
    t = (im[..., 3] > 0.9) & (rgb[..., 0] > rgb[..., 1]) & (rgb[..., 1] >= rgb[..., 2] - 0.02) & (s > 0.12) & (mx > 0.15) & (mx < 0.85)
    return rgb[t].mean(0)
def aplicar(im, g):
    rgb = im[..., :3]; mx = rgb.max(-1); mn = rgb.min(-1); s = (mx - mn) / np.maximum(mx, 1e-6)
    peso = np.clip((s - 0.08) / 0.12, 0, 1) * (rgb[..., 0] > rgb[..., 2])
    out = im.copy(); out[..., :3] = np.clip(rgb * (1 + peso[..., None] * (g - 1)), 0, 1); return out
os.makedirs(COPIA, exist_ok=True)
ref = np.mean([media(leer(f)) for f in REPOSO], 0)
for extremo, libre in TRAMOS:
    paso = 1 if libre > extremo else -1
    sprites = list(range(extremo, libre, paso))
    for k in sprites:
        f = os.path.join(CARPETA, 'c_%03d.png' % k)
        if not os.path.exists(os.path.join(COPIA, os.path.basename(f))):
            shutil.copy(f, COPIA)
    g_fin = ref / media(leer(os.path.join(COPIA, 'c_%03d.png' % extremo)))
    for i, k in enumerate(sprites):
        w = 1 - i / float(len(sprites))
        g = 1 + w * (g_fin - 1)
        im = leer(os.path.join(COPIA, 'c_%03d.png' % k))
        for _ in range(3):   # el peso no es 1 en toda la tunica: se afina
            g = g * (1 + w * (ref / media(aplicar(im, g)) - 1)) if k == extremo else g
        Image.fromarray((aplicar(im, g) * 255).round().astype(np.uint8)).save(os.path.join(CARPETA, 'c_%03d.png' % k))
    print('c_%03d..c_%03d: el c_%03d ahora %s, reposo %s' % (sprites[0], sprites[-1], extremo,
          tuple((media(leer(os.path.join(CARPETA, 'c_%03d.png' % extremo))) * 255).round(1)), tuple((ref * 255).round(1))))

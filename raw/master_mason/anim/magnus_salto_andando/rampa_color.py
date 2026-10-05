"""Rampa de color en la cola del salto andando: que acabe con la luz del reposo.

La cola del salto (desde el sprite 55, ya cayendo e incorporandose) sale unos
5 niveles mas oscura que el reposo y que andar: (89, 65, 59) frente a (95, 70,
62) y (93, 69, 62). Al acabar el salto (a reposo, o cortando a andar desde el 60,
ver SALTO_CORTE_DESDE en magnus.gd) habia un pequeno fogonazo al volver a la luz
de siempre. Aqui la tunica de los sprites 51-70 va en rampa al color del reposo
(nada en el 51, del todo del 61 en adelante), con el peso por saturacion de
igualar_color.py (solo la tunica). Parte de _sin_rampa/.
    python rampa_color.py
"""
import glob, os, shutil
import numpy as np
from PIL import Image
AQUI = os.path.dirname(os.path.abspath(__file__))
CARPETA = os.path.join(AQUI, '04_limpios'); COPIA = os.path.join(AQUI, '_sin_rampa')
REPOSO = sorted(glob.glob(os.path.join(AQUI, '..', 'magnus_respirando', '04_limpios', '*.png')))[:29]
DESDE, LLENO = 51, 61

def leer(f): return np.asarray(Image.open(f).convert('RGBA')).astype(float) / 255
def media(im):
    rgb = im[..., :3]; mx = rgb.max(-1); mn = rgb.min(-1); s = (mx - mn) / np.maximum(mx, 1e-6)
    t = (im[..., 3] > 0.9) & (rgb[..., 0] > rgb[..., 1]) & (rgb[..., 1] >= rgb[..., 2] - 0.02) & (s > 0.12) & (mx > 0.15) & (mx < 0.85)
    return rgb[t].mean(0)
def aplicar(im, g):
    rgb = im[..., :3]; mx = rgb.max(-1); mn = rgb.min(-1); s = (mx - mn) / np.maximum(mx, 1e-6)
    peso = np.clip((s - 0.08) / 0.12, 0, 1) * (rgb[..., 0] > rgb[..., 2])
    out = im.copy(); out[..., :3] = np.clip(rgb * (1 + peso[..., None] * (g - 1)), 0, 1); return out
if not os.path.isdir(COPIA):
    shutil.copytree(CARPETA, COPIA)
ref = np.mean([media(leer(f)) for f in REPOSO], 0)
fs = sorted(glob.glob(os.path.join(COPIA, '*.png')))
for k in range(DESDE, len(fs) + 1):
    w = min((k - DESDE) / float(LLENO - DESDE), 1.0)
    im = leer(fs[k - 1])
    g = np.ones(3)
    for _ in range(4):   # el peso no es 1 en toda la tunica: se afina hasta el objetivo
        objetivo = media(im) * (1 - w) + ref * w
        g = g * objetivo / media(aplicar(im, g))
    Image.fromarray((aplicar(im, g) * 255).round().astype(np.uint8)).save(os.path.join(CARPETA, os.path.basename(fs[k - 1])))
print('cola %d-%d: el ultimo ahora %s, reposo %s' % (DESDE, len(fs), tuple((media(leer(os.path.join(CARPETA, os.path.basename(fs[-1])))) * 255).round(1)), tuple((ref * 255).round(1))))

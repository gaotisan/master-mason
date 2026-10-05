"""Iguala el color de las cinco vistas al agachado del juego, por zonas.

El giro empieza y acaba en el agachado (magnus_agacharse c_077-c_089), asi que
esa es la referencia. Cada vista la pinto la IA por su cuenta y no casa ni con
el agachado ni entre ellas (medido en 04_limpios, media RGB):
               capucha          tunica               pies
  agachado    (156,161,166)    (91,68,60)           (76,51,48)
  vista 1     (137,145,150)    (93,67,62)           (74,48,50)
  vista 4     (151,157,159)    (100,74,67)          (80,55,56)
  vista 5     (157,162,164)    (100,74,68)          (95,71,69)
La barba ya casa (190-196 frente a 195-200). En el giro de pie se noto como "la
tunica se enciende y se apaga" y "los pies centellean": por eso por zonas.
Ganancia por canal en cada zona hasta la media del agachado:
  tunica   lo calido y saturado, con el peso por saturacion de igualar_color.py
           de los otros jobs (sin borde entre paneles)
  capucha  gris azulado de la parte de arriba (150 filas desde la punta)
  pies     piel calida de las 25 filas de abajo
Las zonas no se pisan: los pies se igualan aparte y la tunica no entra en ellos.
Copia previa en _sin_igualar_color/; parte siempre de ella.
    python igualar_color.py
"""
import glob, os, shutil
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
CARPETA = os.path.join(AQUI, '04_limpios'); COPIA = os.path.join(AQUI, '_sin_igualar_color')
REF = [os.path.join(AQUI, '..', 'magnus_agacharse', '04_limpios', 'c_%03d.png' % k) for k in range(77, 90)]


def leer(f):
    return np.asarray(Image.open(f).convert('RGBA')).astype(float) / 255


def mascaras(im):
    rgb = im[..., :3]; r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    al = im[..., 3] > 0.9
    ys = np.where(al.any(1))[0]; arriba, abajo = ys.min(), ys.max()
    fila = np.arange(im.shape[0])[:, None]
    mx, mn = rgb.max(-1), rgb.min(-1); s = (mx - mn) / np.maximum(mx, 1e-6)
    pies = al & (fila > abajo - 25) & (r > g + 0.06)
    capucha = al & (np.abs(r - g) < 0.065) & (b >= r - 0.01) & (r > 0.43) & (r < 0.79) & (fila < arriba + 150)
    tunica = al & ~pies & (r > g) & (g >= b - 0.02) & (s > 0.12) & (mx > 0.15) & (mx < 0.85)
    peso_t = np.clip((s - 0.08) / 0.12, 0, 1) * (r > b) * ~pies
    return {'tunica': (tunica, peso_t), 'capucha': (capucha, capucha.astype(float)),
            'pies': (pies, pies.astype(float))}


def medias(im):
    return {k: im[..., :3][m].mean(0) for k, (m, _) in mascaras(im).items()}


def aplicar(im, ganancias):
    out = im.copy()
    for k, (_, peso) in mascaras(im).items():
        g = ganancias[k]
        out[..., :3] = out[..., :3] * (1 + peso[..., None] * (g - 1))
    out[..., :3] = np.clip(out[..., :3], 0, 1)
    return out


if not os.path.isdir(COPIA):
    shutil.copytree(CARPETA, COPIA)
refs = [medias(leer(f)) for f in REF]
ref = {k: np.mean([r[k] for r in refs], 0) for k in refs[0]}
for f in sorted(glob.glob(os.path.join(COPIA, '*.png'))):
    im = leer(f)
    gan = {k: np.ones(3) for k in ref}
    for _ in range(4):        # los pesos no son 1 en toda la zona: se afina hasta el objetivo
        m = medias(aplicar(im, gan))
        gan = {k: gan[k] * ref[k] / m[k] for k in ref}
    out = aplicar(im, gan)
    Image.fromarray((out * 255).round().astype(np.uint8)).save(os.path.join(CARPETA, os.path.basename(f)))
    m = medias(out)
    print('%s  ' % os.path.basename(f) + '  '.join('%s %s' % (k, tuple((m[k] * 255).round().astype(int))) for k in ref))
print('referencia ' + '  '.join('%s %s' % (k, tuple((ref[k] * 255).round().astype(int))) for k in ref))

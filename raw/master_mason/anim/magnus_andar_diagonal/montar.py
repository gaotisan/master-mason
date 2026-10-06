"""Monta el ciclo de andar en diagonal (tres cuartos, de cara a la derecha).

El video (_fuentes/Cloaked_figure_walking_diagonally_20261006172813.mp4, Flow,
720x1280 en vertical, fondo beis liso) anda en el sitio del 1 al 160 con la
camara siguiendole; despues se va por la derecha. El ciclo (dos pasos) dura 42
fotogramas: el mejor cierre es el 81 -> 123 (1,54 de diferencia, menos que el
paso medio, 2,28), asi que el bucle es 81-122.
Fondo: beis (230,226,218) perfectamente liso; con fondo.ps1 a tolerancia 10 (la
de fondos claros con barba blanca; a 22 se comia trozos de la barba).
Cada sprite: los pies a la fila 677 del juego (un solo desplazamiento: la camara
sigue al personaje y los pies no cambian de fila) y una ganancia por zonas
(tunica, capucha, pies) contra la media del reposo.
Lee de _todos/ (43 sprites, video 81-123, centrados y sin fondo) y escribe
04_limpios/ (42).
    python montar.py
"""
import glob, os
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
TODOS = os.path.join(AQUI, '_todos'); SALIDA = os.path.join(AQUI, '04_limpios')
N = 42
SUELO = 677
REPOSOS = sorted(glob.glob(os.path.join(AQUI, '..', 'magnus_respirando', '04_limpios', '*.png')))[:29]
src = open(os.path.join(AQUI, '..', 'magnus_giro_agachado', 'igualar_color.py'), encoding='utf-8').read()
z = {'__file__': os.path.join(AQUI, '..', 'magnus_giro_agachado', 'igualar_color.py')}
exec(src[:src.index('if not os.path.isdir(COPIA)')], z)


def mover(a, dy):
    out = np.zeros_like(a); h = a.shape[0]
    if dy >= 0:
        out[dy:] = a[:h - dy]
    else:
        out[:h + dy] = a[-dy:]
    return out


fs = sorted(glob.glob(os.path.join(TODOS, '*.png')))[:N]
ims = [np.asarray(Image.open(f).convert('RGBA')).astype(float) / 255 for f in fs]
pies = int(np.median([np.where(a[..., 3] > 0.5)[0].max() for a in ims]))
DY = SUELO - pies
ref = {k: np.mean([z['medias'](z['leer'](p))[k] for p in REPOSOS], 0) for k in ('tunica', 'capucha', 'pies')}
med = {k: np.mean([z['medias'](a)[k] for a in ims], 0) for k in ref}
gan = {k: ref[k] / med[k] for k in ref}
for p in glob.glob(os.path.join(SALIDA, '*.png')):
    os.remove(p)
for k, a in enumerate(ims):
    s = z['aplicar'](mover(a, DY), gan)
    Image.fromarray((np.ascontiguousarray(s) * 255).round().astype(np.uint8)).save(os.path.join(SALIDA, 'c_%02d.png' % (k + 1)))
print('%d sprites; pies del video en la %d -> dy %d; ganancias %s' % (len(ims), pies, DY, {k: tuple(np.round(v, 3)) for k, v in gan.items()}))

"""Monta el giro de pie del juego a partir del video (Flow) en 04_limpios.

El video (_fuentes/Wizard_rotating_on_green_background_20261005182314.mp4) gira
de pie, siempre hacia la camara, del perfil IZQUIERDO al frente (19-66), se queda
de frente moviendose un poco (66-100) y sigue hasta el perfil derecho (100-151);
1-18 y 151-240, quieto. Se espeja entero (en el juego el giro de la animacion va
de mirar a la derecha a mirar a la izquierda; volteado, al reves).
Lo que se usa, a su ritmo y SIN saltarse fotogramas (de dos en dos a mucha
velocidad era lo que hacia ir a saltitos el giro agachado):
  - el reposo del juego (magnus_respirando c_01, el fotograma por el que se entra
    al reposo) y dos de fundido hasta el 22 del video
  - del 22 al 69, y del 88 al 150: se salta el rato de frente; 69 y 88 son el
    mejor empalme (0,37, con pasos de 0,20-0,24 alrededor) y van con dos de
    fundido entre medias
  - uno de fundido y el reposo espejado (al acabar magnus.gd voltea)
A 60 fps (1,9 s): cada fotograma del video cambia 0,12, que a 60 fps es el mismo
ritmo de cambio que andar (0,24 a 30 fps).
Cada sprite: sin las bolsas de croma (el verde encerrado entre las piernas que
fondo.ps1 no alcanza), espejado, movido lo que mejor encaja el principio con el
reposo (+4, -8) y el final con el reposo espejado (+1, -8) en rampa, y una ganancia
por zonas (tunica, capucha, pies) de esos dos extremos contra el reposo.
Lee de _todos/ (156 sprites, video 10-165, centrados y sin fondo) y escribe
04_limpios/.
    python montar.py
"""
import glob, os, shutil
import numpy as np
from PIL import Image
from scipy import ndimage

AQUI = os.path.dirname(os.path.abspath(__file__))
TODOS = os.path.join(AQUI, '_todos'); SALIDA = os.path.join(AQUI, '04_limpios')
CON_FONDO = os.path.join(AQUI, '_con_fondo', '04_limpios')
PRIMERO = 10
TRAMOS = [range(22, 70), range(88, 151)]
DX0, DX1, DY = 4, 1, -8
REPOSO = os.path.join(AQUI, '..', 'magnus_respirando', '04_limpios', 'c_01.png')
REPOSOS = sorted(glob.glob(os.path.join(AQUI, '..', 'magnus_respirando', '04_limpios', '*.png')))[:29]
src = open(os.path.join(AQUI, '..', 'magnus_giro_agachado', 'igualar_color.py'), encoding='utf-8').read()
z = {'__file__': os.path.join(AQUI, '..', 'magnus_giro_agachado', 'igualar_color.py')}
exec(src[:src.index('if not os.path.isdir(COPIA)')], z)              # mascaras, medias, aplicar

if not os.path.isdir(TODOS):
    shutil.copytree(SALIDA, TODOS)


def video(n):
    k = n - PRIMERO + 1
    im = np.asarray(Image.open(os.path.join(TODOS, 'c_%03d.png' % k)).convert('RGBA')).copy()
    s = np.asarray(Image.open(os.path.join(CON_FONDO, 'c_%03d.png' % k)).convert('RGB')).astype(int)
    r, g, b = s[..., 0], s[..., 1], s[..., 2]
    croma = (g > r + 50) & (g > b + 40)
    lab, _ = ndimage.label(croma)
    borde = set(np.unique(np.r_[lab[0], lab[-1], lab[:, 0], lab[:, -1]])) - {0}
    bolsa = croma & ~np.isin(lab, list(borde))
    orla = ndimage.binary_dilation(bolsa, iterations=2) & ~bolsa & (im[..., 1].astype(int) > im[..., 0])
    im[bolsa | orla] = 0
    return (im.astype(float) / 255)[:, ::-1]


def mover(a, dx, dy):
    out = np.zeros_like(a); h, w = a.shape[:2]
    out[max(dy, 0):h + min(dy, 0), max(dx, 0):w + min(dx, 0)] = a[max(-dy, 0):h - max(dy, 0), max(-dx, 0):w - max(dx, 0)]
    return out


def fundir(a, b, t):
    pa = np.concatenate([a[..., :3] * a[..., 3:], a[..., 3:]], 2)
    pb = np.concatenate([b[..., :3] * b[..., 3:], b[..., 3:]], 2)
    m = (1 - t) * pa + t * pb
    al = m[..., 3:]
    return np.concatenate([np.where(al > 0, m[..., :3] / np.maximum(al, 1e-6), 0), al], 2)


usados = [n for t in TRAMOS for n in t]
primero, ultimo = usados[0], usados[-1]
ref = {k: np.mean([z['medias'](z['leer'](f))[k] for f in REPOSOS], 0) for k in ('tunica', 'capucha', 'pies')}
ext = [z['medias'](video(primero)), z['medias'](video(ultimo))]
gan = {k: ref[k] / np.mean([e[k] for e in ext], 0) for k in ref}


def sprite(n):
    t = (n - primero) / float(ultimo - primero)
    return mover(z['aplicar'](video(n), gan), int(round(DX0 + t * (DX1 - DX0))), DY)


rep = z['leer'](REPOSO)
a = [sprite(n) for n in TRAMOS[0]]
b = [sprite(n) for n in TRAMOS[1]]
sprites = ([rep, fundir(rep, a[0], 1 / 3.0), fundir(rep, a[0], 2 / 3.0)] + a
           + [fundir(a[-1], b[0], 1 / 3.0), fundir(a[-1], b[0], 2 / 3.0)] + b
           + [fundir(b[-1], rep[:, ::-1], 0.5), rep[:, ::-1]])
for f in glob.glob(os.path.join(SALIDA, '*.png')):
    os.remove(f)
for k, s in enumerate(sprites):
    Image.fromarray((np.ascontiguousarray(s) * 255).round().astype(np.uint8)).save(os.path.join(SALIDA, 'c_%03d.png' % (k + 1)))
print('%d sprites; ganancias %s' % (len(sprites), {k: tuple(np.round(v, 3)) for k, v in gan.items()}))

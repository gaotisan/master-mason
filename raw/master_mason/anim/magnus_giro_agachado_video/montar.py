"""Monta el giro agachado del juego a partir del video (Flow) en 04_limpios.

El video (Wizard_turning_in_place, 240 fotogramas) gira dos veces: del perfil al
frente y vuelta (25-100), y despues el giro entero por detras hasta el perfil
del otro lado (100-160). Se usa el segundo:
  - la primera mitad hacia la camara, espejada, empezaba exacta pero la IA le
    hunde la cabeza 12 px de master antes de girar (31): click al empezar y al
    acabar;
  - en el de por detras la cabeza va a la altura del agachado del juego al
    empezar (103) y al acabar (162), la velocidad es uniforme (0,18-0,28 por
    fotograma) y frena sola al final. Lo unico que no casa al empezar es el
    mosaico de la tunica (0,43 del agachado), y queda tapado por el propio
    giro: cada paso del juego cambia casi lo mismo.
Sprites: el agachado del juego (c_089), dos de fundido, TODOS los fotogramas
del 103 al 162 del video, uno de fundido y el agachado espejado: 65, a 24 fps
como el video (2,8 s con el arranque suave; ver _spriteframes.py). Version del
2026-10-05 tras ver el usuario las anteriores "a saltitos": de dos en dos a 60
fps (5 veces la velocidad del video) los pasitos de los pies parecian saltos;
a su ritmo y sin saltarse fotogramas va tan fluido como el video. Empieza y acaba en el sprite
del bucle, asi que los enlaces son exactos (al acabar magnus.gd voltea).
A cada fotograma del video se le quitan las bolsas de croma (sin_bolsas), se sube 7 px y se mueve de -2 a -4 px en x (lo que mejor
lo encaja con el agachado al principio y con el espejado al final) y lleva una
ganancia por zonas (tunica, capucha, pies, ver magnus_giro_agachado/igualar_color.py)
sacada de los dos extremos contra el agachado del juego. De espaldas sale mas
oscuro: es la sombra de la espalda y se deja.
Lee de _todos/ (los 81 sprites del video ya centrados y sin fondo, 95-175) y
escribe 04_limpios/.
    python montar.py
"""
import glob, os, shutil
import numpy as np
from PIL import Image
from scipy import ndimage

AQUI = os.path.dirname(os.path.abspath(__file__))
TODOS = os.path.join(AQUI, '_todos'); SALIDA = os.path.join(AQUI, '04_limpios')
PRIMERO = 95                                  # fotograma del video de _todos/c_01
FOTOGRAMAS = list(range(103, 163))            # del video: TODOS, a su ritmo
INICIO, FIN = 103, 162                        # entre los que va la rampa de dx
DY, DX0, DX1 = -7, -2, -4
AGACHADO = os.path.join(AQUI, '..', 'magnus_agacharse', '04_limpios', 'c_089.png')

src = open(os.path.join(AQUI, '..', 'magnus_giro_agachado', 'igualar_color.py'), encoding='utf-8').read()
z = {'__file__': os.path.join(AQUI, '..', 'magnus_giro_agachado', 'igualar_color.py')}
exec(src[:src.index('if not os.path.isdir(COPIA)')], z)           # mascaras, medias, aplicar, REF

if not os.path.isdir(TODOS):
    shutil.copytree(SALIDA, TODOS)


CON_FONDO = os.path.join(AQUI, '_con_fondo', '04_limpios')


def sin_bolsas(im, n):
    """Quita las bolsas de croma que el fondo no alcanzo.

    fondo.ps1 inunda el verde desde el borde: el que queda encerrado entre el
    brazo y el cuerpo (de espaldas, 115-139: hasta 1000 px de master) se queda,
    despintado a verde azulado. Se buscan en el fotograma con fondo (el verde que
    no toca el borde) y se borran, con su orla de 2 px si es verdosa (g > r): el
    borde marron de la tunica no se toca. Por color no se puede: la capucha es
    gris azulada (121,154,160) y las bolsas (81,107,106)."""
    src = np.asarray(Image.open(os.path.join(CON_FONDO, 'c_%02d.png' % (n - PRIMERO + 1))).convert('RGB')).astype(int)
    r, g, b = src[..., 0], src[..., 1], src[..., 2]
    croma = (g > r + 50) & (g > b + 40)
    lab, _ = ndimage.label(croma)
    borde = set(np.unique(np.r_[lab[0], lab[-1], lab[:, 0], lab[:, -1]])) - {0}
    bolsa = croma & ~np.isin(lab, list(borde))
    orla = ndimage.binary_dilation(bolsa, iterations=2) & ~bolsa & (im[..., 1] > im[..., 0])
    out = im.copy()
    out[bolsa | orla] = 0
    return out


def video(n):
    return sin_bolsas(z['leer'](os.path.join(TODOS, 'c_%02d.png' % (n - PRIMERO + 1))), n)


def mover(im, dx, dy):
    out = np.zeros_like(im)
    h, w = im.shape[:2]
    out[max(dy, 0):h + min(dy, 0), max(dx, 0):w + min(dx, 0)] = im[max(-dy, 0):h - max(dy, 0), max(-dx, 0):w - max(dx, 0)]
    return out


ref = {k: np.mean([z['medias'](z['leer'](f))[k] for f in z['REF']], 0) for k in ('tunica', 'capucha', 'pies')}
extremos = [z['medias'](video(INICIO)), z['medias'](video(FIN))]
gan = {k: ref[k] / np.mean([e[k] for e in extremos], 0) for k in ref}
def fundir(a, b, t):
    """Mezcla premultiplicada de dos sprites (t = cuanto de b)."""
    pa = np.concatenate([a[..., :3] * a[..., 3:], a[..., 3:]], 2)
    pb = np.concatenate([b[..., :3] * b[..., 3:], b[..., 3:]], 2)
    m = (1 - t) * pa + t * pb
    al = m[..., 3:]
    return np.concatenate([np.where(al > 0, m[..., :3] / np.maximum(al, 1e-6), 0), al], 2)


ag = z['leer'](AGACHADO)
del_video = []
for n in FOTOGRAMAS:
    t = (n - INICIO) / float(FIN - INICIO)
    dx = int(round(DX0 + t * (DX1 - DX0)))
    del_video.append(mover(z['aplicar'](video(n), gan), dx, DY))
# Enlaces fundidos: el mosaico de la tunica del video no es el del agachado del
# juego (0,43 al empezar, 0,22 al acabar); dos fotogramas de fundido a la entrada
# y uno a la salida, con la silueta ya encajada, lo pasan sin salto.
sprites = ([ag, fundir(ag, del_video[0], 1 / 3.0), fundir(ag, del_video[0], 2 / 3.0)]
           + del_video + [fundir(del_video[-1], ag[:, ::-1], 0.5), ag[:, ::-1]])
for f in glob.glob(os.path.join(SALIDA, '*.png')):
    os.remove(f)
for k, s in enumerate(sprites):
    Image.fromarray((np.ascontiguousarray(s) * 255).round().astype(np.uint8)).save(os.path.join(SALIDA, 'c_%02d.png' % (k + 1)))
print('%d sprites en 04_limpios; ganancias %s' % (len(sprites), {k: tuple(np.round(v, 3)) for k, v in gan.items()}))

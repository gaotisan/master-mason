"""Monta el paso agachado (un solo paso, de agachado a agachado) en 04_limpios.

Dos videos de Flow seguidos (camara quieta, fondo verde):
  1. _fuentes/Crouching_pilgrim_stepping_forward_20261006205235.mp4 (este job):
     agachado (nuestro c_089) -> el pie de delante sale y se planta 77 px de
     master mas adelante; el cuerpo casi no se mueve. Se mueve del 45 al 92.
  2. _fuentes/Pilgrim_shifting_weight_forward_20261006230324.mp4 (job
     magnus_paso_agachado_2), pedido con el ultimo fotograma del 1 de inicial y
     nuestro agachado 77 px mas adelante de final: el cuerpo avanza sobre el pie
     de delante, que no se mueve, y el de atras se junta. Se mueve del 47 al 90 y
     acaba en nuestro agachado 78 px mas adelante (0,22).
Los dos se centraron con el MISMO eje fijo (centrar.ps1 -Eje 501, la camara no
se mueve), elegido para que el primer fotograma caiga donde el c_089 en su
casilla: asi las coordenadas son las del mundo y los pies apoyados no se mueven.

Empalme (2026-10-06): el 1 hasta el 86 y el 2 desde el 46, donde mejor casan
(0,265) sin el rato de quietos entre los dos; antes (1 hasta el 92, 2 desde el 47)
se paraba entre medias y el usuario veia "dos avances". El 1 se inclina hacia
delante y vuelve (8 px del juego): eso viene del video y a media inclinacion los
dos videos no casan (0,7-0,9).
Sprites: el agachado del juego, dos de fundido, el video 1 (45-86), dos de
fundido (Flow redibujo la textura al hacer el 2: 0,34 entre el ultimo del 1 y el
primero del 2 con la misma pose), el video 2 (46-90), dos de fundido y el
agachado del juego. Cada sprite se mueve hacia atras lo que ha avanzado el cuerpo
(D: el tronco en el video 2, de 0 a 78 px de master; en el 1, 0) y el nodo avanza
eso mismo (AVANCE_PASO_AGACHADO en magnus.gd, la mitad en px del juego): lo que se
dibuja queda en las coordenadas del video, con los pies clavados, y la camara del
juego sigue al nodo sin saltos. El ultimo sprite es el agachado del juego tal
cual: enlace exacto con el bucle.
Ademas: sin bolsas de croma (lo que era croma y quedo opaco del todo), ganancia
por zonas en rampa contra el bucle del agachado y enfoque calibrado a tamano de
hoja contra el agachado en los dos extremos de cada video.
Lee de _todos/ de los dos jobs y escribe 04_limpios/ de este; imprime la tabla
de avance.
    python montar.py
"""
import glob, os
import numpy as np
from PIL import Image
from scipy import ndimage as _nd

AQUI = os.path.dirname(os.path.abspath(__file__))
OTRO = os.path.join(AQUI, '..', 'magnus_paso_agachado_2')
SALIDA = os.path.join(AQUI, '04_limpios')
TRAMO1 = (AQUI, 30, range(45, 87))      # carpeta, primer fotograma de _todos, fotogramas
TRAMO2 = (OTRO, 40, range(46, 91))
PASO = 78                                # px de master que avanza el paso
DY = -1                                  # pies a la 677 del juego
AGACHADO = os.path.join(AQUI, '..', 'magnus_agacharse', '04_limpios', 'c_089.png')
src = open(os.path.join(AQUI, '..', 'magnus_giro_agachado', 'igualar_color.py'), encoding='utf-8').read()
z = {'__file__': os.path.join(AQUI, '..', 'magnus_giro_agachado', 'igualar_color.py')}
exec(src[:src.index('if not os.path.isdir(COPIA)')], z)


def video(carpeta, primero, n):
    k = n - primero + 1
    nombre = 'c_%03d.png' % k
    if not os.path.exists(os.path.join(carpeta, '_todos', nombre)):
        nombre = 'c_%02d.png' % k                 # el clip 2 tiene menos de 100
    im = np.asarray(Image.open(os.path.join(carpeta, '_todos', nombre)).convert('RGBA')).copy()
    s = np.asarray(Image.open(os.path.join(carpeta, '_con_fondo', '04_limpios', nombre)).convert('RGB')).astype(int)
    r, g, b = s[..., 0], s[..., 1], s[..., 2]
    bolsa = (g > r + 50) & (g > b + 40) & (im[..., 3] >= 250)
    orla = _nd.binary_dilation(bolsa, iterations=2) & ~bolsa & (im[..., 1].astype(int) > im[..., 0])
    im[bolsa | orla] = 0
    return im.astype(float) / 255


def mover(a, dx, dy=0):
    out = np.zeros_like(a); h, w = a.shape[:2]
    out[max(dy, 0):h + min(dy, 0), max(dx, 0):w + min(dx, 0)] = a[max(-dy, 0):h - max(dy, 0), max(-dx, 0):w - max(dx, 0)]
    return out


def fundir(a, b, t):
    pa = np.concatenate([a[..., :3] * a[..., 3:], a[..., 3:]], 2)
    pb = np.concatenate([b[..., :3] * b[..., 3:], b[..., 3:]], 2)
    m = (1 - t) * pa + t * pb
    al = m[..., 3:]
    return np.concatenate([np.where(al > 0, m[..., :3] / np.maximum(al, 1e-6), 0), al], 2)


def dist(a, b):
    pa, pb = a[..., :3] * a[..., 3:], b[..., :3] * b[..., 3:]
    m = (a[..., 3] > 0) | (b[..., 3] > 0)
    ys, xs = np.where(m)
    c = (slice(ys.min(), ys.max() + 1), slice(xs.min(), xs.max() + 1))
    return 10 * np.abs(pa[c] - pb[c]).mean()


def nitidez(im):
    pre = im[..., :3] * im[..., 3:]
    h, w = (im.shape[0] // 2) * 2, (im.shape[1] // 2) * 2
    g = pre[:h, :w].mean(2).reshape(h // 2, 2, w // 2, 2).mean((1, 3))
    a = im[:h, :w, 3].reshape(h // 2, 2, w // 2, 2).mean((1, 3))
    return float(np.abs(_nd.laplace(g)[a > 0.78]).mean() * 1000)


def enfocar(im, k, sigma=2.0):
    a = im[..., 3]
    if k <= 0:
        return im
    rgb = im[..., :3]
    peso = _nd.gaussian_filter(a, sigma)
    borroso = np.stack([_nd.gaussian_filter(rgb[..., c] * a, sigma) for c in range(3)], -1) / np.maximum(peso, 1e-6)[..., None]
    out = np.clip(rgb + k * (rgb - borroso), 0, 1)
    return np.concatenate([np.where(a[..., None] > 0, out, 0), a[..., None]], 2)


def calibrar(im, objetivo):
    return min(np.arange(0, 3.01, 0.05), key=lambda k: abs(nitidez(enfocar(im, k)) - objetivo))


def tronco(im):
    al = im[..., 3] > 0.5
    ys, xs = np.where(al)
    top = ys.min(); h = ys.max() - top
    return float(np.where(al[top:top + int(0.4 * h)])[1].mean())


ag = z['leer'](AGACHADO)
ref = {k: np.mean([z['medias'](z['leer'](p))[k] for p in z['REF']], 0) for k in ('tunica', 'capucha', 'pies')}
tramos = []
for carpeta, primero, ns in (TRAMO1, TRAMO2):
    crudos = [mover(video(carpeta, primero, n), 0, DY) for n in ns]
    e0, e1 = z['medias'](crudos[0]), z['medias'](mover(crudos[-1], -PASO if carpeta == OTRO else 0))
    g0 = {k: ref[k] / e0[k] for k in ref}; g1 = {k: ref[k] / e1[k] for k in ref}
    col = [z['aplicar'](s, {k: g0[k] + (g1[k] - g0[k]) * i / (len(crudos) - 1.0) for k in ref}) for i, s in enumerate(crudos)]
    k0, k1 = calibrar(col[0], nitidez(ag)), calibrar(col[-1], nitidez(ag))
    tramos.append([enfocar(s, k0 + (k1 - k0) * i / (len(col) - 1.0)) for i, s in enumerate(col)])
    print('tramo %s: enfoque %.2f -> %.2f' % (os.path.basename(carpeta), k0, k1))
v1, v2 = tramos
# Avance del cuerpo: 0 en el video 1; en el 2, el tronco, llevado a 0..PASO,
# siempre hacia delante.
t2 = np.array([tronco(s) for s in v2])
d2 = np.clip((t2 - t2[0]) / (t2[-1] - t2[0]) * PASO, 0, PASO)
d2 = np.maximum.accumulate(d2); d2[-1] = PASO
ag_final = mover(ag, PASO)                       # el agachado donde acaba el paso
mundo = ([ag, fundir(ag, v1[0], 1 / 3.0), fundir(ag, v1[0], 2 / 3.0)] + v1
         + [fundir(v1[-1], v2[0], 1 / 3.0), fundir(v1[-1], v2[0], 2 / 3.0)] + v2
         + [fundir(v2[-1], ag_final, 1 / 3.0), fundir(v2[-1], ag_final, 2 / 3.0), ag_final])
D = [0.0] * (3 + len(v1) + 2) + list(d2) + [PASO] * 3
D = [int(round(x)) for x in D]
sprites = [ag if i == 0 else (ag if i == len(mundo) - 1 else mover(s, -D[i])) for i, s in enumerate(mundo)]
for p in glob.glob(os.path.join(SALIDA, '*.png')):
    os.remove(p)
for k, s in enumerate(sprites):
    Image.fromarray((np.ascontiguousarray(s) * 255).round().astype(np.uint8)).save(os.path.join(SALIDA, 'c_%03d.png' % (k + 1)))
pasos = [dist(a, b) for a, b in zip(mundo, mundo[1:])]
print('%d sprites; pasos (en el mundo) media %.3f max %.3f' % (len(sprites), np.mean(pasos), max(pasos)))
print('pasos: %s' % ' '.join('%.2f' % q for q in pasos))
print('AVANCE_PASO_AGACHADO (px del juego) := %s' % [x / 2.0 for x in D])

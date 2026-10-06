"""Monta el giro de pie del juego a partir del video rapido (Flow) en 04_limpios.

El video (_fuentes/Wizard_turning_around_green_screen_20261005230414.mp4, pedido
con _fuentes/prompt_giro_pie_rapido.txt) esta quieto de perfil mirando a la
IZQUIERDA (1-69, casi el reposo del juego), da la vuelta DE ESPALDAS a la camara
con dos pasos (70-112: acelera, va parejo y frena el solo, 0,12 -> 0,37 -> 0,13 de
paso) y se queda de perfil mirando a la derecha, recolocandose un poco (113-160).
Se espeja entero: en el juego la animacion va de mirar a la derecha a mirar a la
izquierda (volteada, al reves); al acabar magnus.gd voltea.

Sprites: el reposo del juego (magnus_respirando c_01), uno de fundido, TODOS los
fotogramas del 70 al 112, uno de fundido y el reposo espejado: 47, a 30 fps (1,6
s; el video va a 24). Sin saltarse ninguno: con dos pasos de verdad el ritmo es el
del video, no el arrastre de pies que salia acelerando el giro lento.
El 70 es el que mejor casa con el reposo (0,24) y el 112 con el reposo espejado
(0,29): los dos fundidos dejan esos saltos en la mitad.
Cada sprite: sin las bolsas de croma (el verde que fondo.ps1 deja opaco entre las
piernas o entre brazo y cuerpo; se buscan en el fotograma con fondo), espejado, movido lo que mejor
encaja el principio con el reposo (DX0, DY) y el final con el reposo espejado (DX1,
DY) en rampa, y una ganancia por zonas (tunica, capucha, pies) de esos dos extremos
contra la media del reposo.
Lee de _todos/ (105 sprites, video 56-160, centrados y sin fondo) y escribe
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
PRIMERO = 56
INICIO, FIN = 70, 112
DX0, DX1, DY = -1, 0, -12
REPOSO = os.path.join(AQUI, '..', 'magnus_respirando', '04_limpios', 'c_01.png')
REPOSOS = sorted(glob.glob(os.path.join(AQUI, '..', 'magnus_respirando', '04_limpios', '*.png')))[:29]
src = open(os.path.join(AQUI, '..', 'magnus_giro_agachado', 'igualar_color.py'), encoding='utf-8').read()
z = {'__file__': os.path.join(AQUI, '..', 'magnus_giro_agachado', 'igualar_color.py')}
exec(src[:src.index('if not os.path.isdir(COPIA)')], z)              # mascaras, medias, aplicar

if not os.path.isdir(TODOS):
    shutil.copytree(SALIDA, TODOS)


def video(n):
    """Fotograma n del video, sin bolsas de croma y espejado."""
    k = n - PRIMERO + 1
    im = np.asarray(Image.open(os.path.join(TODOS, 'c_%03d.png' % k)).convert('RGBA')).copy()
    s = np.asarray(Image.open(os.path.join(CON_FONDO, 'c_%03d.png' % k)).convert('RGB')).astype(int)
    r, g, b = s[..., 0], s[..., 1], s[..., 2]
    # Bolsa: lo que era croma en el original y fondo.ps1 dejo opaco. (Buscar solo
    # el verde encerrado no basta: entre las piernas toca el fondo por un hueco
    # de 1 px y se quedaba, despintado a verde azulado.)
    croma = (g > r + 50) & (g > b + 40)
    # Solo lo que quedo opaco del todo: el borde suave de la silueta (alfa parcial)
    # tambien es verde en el original, y quitandolo (con su orla, que en la
    # capucha gris azulada tambien es g > r) se comia 2-5 px del contorno.
    bolsa = croma & (im[..., 3] >= 250)
    orla = ndimage.binary_dilation(bolsa, iterations=2) & ~bolsa & (im[..., 1].astype(int) > im[..., 0])
    im[bolsa | orla] = 0
    return (im.astype(float) / 255)[:, ::-1]


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


ns = list(range(INICIO, FIN + 1))
crudos = {n: video(n) for n in ns}
ref = {k: np.mean([z['medias'](z['leer'](p))[k] for p in REPOSOS], 0) for k in ('tunica', 'capucha', 'pies')}
ext = [z['medias'](mover(crudos[INICIO], DX0, DY)), z['medias'](mover(crudos[FIN], DX1, DY))]
gan = {k: ref[k] / np.mean([e[k] for e in ext], 0) for k in ref}


def sprite(n):
    t = (n - INICIO) / float(FIN - INICIO)
    return z['aplicar'](mover(crudos[n], int(round(DX0 + t * (DX1 - DX0))), DY), gan)


rep = z['leer'](REPOSO)
giro = [sprite(n) for n in ns]
# Nitidez: el video (720p ampliado 1,5) sale algo mas blando que el reposo; se
# enfoca en rampa, calibrado a tamano de hoja contra el reposo al principio y al
# final (como magnus_agacharse_flow y magnus_giro_agachado_video).
from scipy import ndimage as _nd


def nitidez(im):
    """Laplaciano medio a tamano de hoja (la mitad), que es lo que se ve."""
    pre = im[..., :3] * im[..., 3:]
    h, w = (im.shape[0] // 2) * 2, (im.shape[1] // 2) * 2
    g = pre[:h, :w].mean(2).reshape(h // 2, 2, w // 2, 2).mean((1, 3))
    a = im[:h, :w, 3].reshape(h // 2, 2, w // 2, 2).mean((1, 3))
    return float(np.abs(_nd.laplace(g)[a > 0.78]).mean() * 1000)


def enfocar(im, k, sigma=2.0):
    """Mascara de desenfoque ponderada por el alfa (el fondo no entra)."""
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


K0, K1 = calibrar(giro[0], nitidez(rep)), calibrar(giro[-1], nitidez(rep))
giro = [enfocar(s, K0 + (K1 - K0) * i / (len(giro) - 1.0)) for i, s in enumerate(giro)]
print('enfoque %.2f -> %.2f: reposo %.1f, primero %.1f, ultimo %.1f' % (K0, K1, nitidez(rep), nitidez(giro[0]), nitidez(giro[-1])))
sprites = [rep, fundir(rep, giro[0], 0.5)] + giro + [fundir(giro[-1], rep[:, ::-1], 0.5), rep[:, ::-1]]
for p in glob.glob(os.path.join(SALIDA, '*.png')):
    os.remove(p)
for k, s in enumerate(sprites):
    Image.fromarray((np.ascontiguousarray(s) * 255).round().astype(np.uint8)).save(os.path.join(SALIDA, 'c_%03d.png' % (k + 1)))
pasos = [dist(a, b) for a, b in zip(sprites, sprites[1:])]
print('%d sprites; pasos %s' % (len(sprites), ' '.join('%.2f' % q for q in pasos)))
print('media %.3f, max %.3f' % (np.mean(pasos), max(pasos)))
print('ganancias %s' % {k: tuple(np.round(v, 3)) for k, v in gan.items()})

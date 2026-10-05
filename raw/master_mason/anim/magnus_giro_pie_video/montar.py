"""Monta el giro de pie del juego a partir del video (Flow) en 04_limpios.

El video (_fuentes/Wizard_rotating_on_green_background_20261005182314.mp4) gira
de pie, siempre hacia la camara, del perfil IZQUIERDO al frente (19-66), se queda
de frente moviendose un poco (66-100) y sigue hasta el perfil derecho (100-113),
donde todavia se recoloca 40 fotogramas mas (113-151); 1-18 y 151-240, quieto.

Version 2 (2026-10-05). La primera (montar_v1_dos_tramos.py: 22-69 + 88-150 a 60
fps) el usuario la vio "a saltos, a tirones y sin fluidez", "como en dos partes":
  - la primera mitad del giro iba en 45 fotogramas y la segunda en 25: cambiaba de
    velocidad en el frente, justo en el empalme 69 -> 88;
  - despues venia la recolocacion (113-150), otro movimiento distinto;
  - y a 60 fps (2,5 veces el video) el temblor del video entre fotogramas (de 2-3 px
    de lado a lado) se veia como tirones.
El giro agachado, que si gusto, es un solo tramo seguido a 24 fps.
Version 2: todos los fotogramas a 30 fps, 3,2 s, y el frente fundido con su espejo
en 5 fotogramas: "no esta mal", pero "tarda un monton, no es jugable" y "tiene un
blur raro" (el mosaico de la tunica no es simetrico y la mezcla lo doblaba).

Version 3 (esta). Para que dure SEGUNDOS sin ir a saltos no se quita uno de cada
dos: se eligen los fotogramas para que cada uno cambie lo mismo (por la distancia
acumulada entre fotogramas), con un arranque suave (ARRANQUE: al principio va a
VEL_INICIAL de la velocidad de crucero). Asi se quitan los que casi no cambian (el
arranque lento del video, la llegada al frente) y en los tramos rapidos no se
salta nada. A 60 fps cada sprite dura un refresco. En el frente, un solo sprite
mitad y mitad con su espejo (1/60 s, no se llega a ver como mezcla) parte en dos el
salto de 0,45.

El giro es UNA mitad del video y su espejo:
  - del 20 al 65 (perfil -> frente, espejado: en el juego empieza mirando a la
    derecha), que empieza casi en el reposo del juego (0,20) porque se pidio con
    el como primer fotograma; la otra mitad del video solo casa con el reposo
    pasados 40 fotogramas de recolocarse;
  - y la misma mitad espejada y al reves (frente -> el otro perfil): misma
    velocidad a los dos lados del frente, sin empalmes, y acaba en el reposo
    espejado (al acabar magnus.gd voltea);
  - el frente del video no es simetrico (0,42 contra su espejo): ver arriba;
  - el temblor de lado a lado se quita moviendo cada fotograma a la media movil
    (7 fotogramas) del centro de su silueta;
  - mas un desplazamiento en rampa: al principio el que mejor encaja con el reposo,
    en el frente el que lo deja centrado en la casilla (para que el espejo case).
Cada sprite: sin las bolsas de croma (el verde encerrado entre las piernas que
fondo.ps1 no alcanza) y una ganancia por zonas (tunica, capucha, pies) del
primero contra el reposo. Lee de _todos/ (156 sprites, video 10-165, centrados y
sin fondo) y escribe 04_limpios/.
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
INICIO, FRENTE = 20, 65
SEGUNDOS = 1.0          # lo que dura el giro (a 60 fps, un sprite por refresco)
FPS = 60
ARRANQUE = 0.3          # parte de cada media vuelta en la que acelera (y frena)
VEL_INICIAL = 0.35      # velocidad al empezar, respecto a la de crucero
DY = -8
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
    croma = (g > r + 50) & (g > b + 40)
    lab, _ = ndimage.label(croma)
    borde = set(np.unique(np.r_[lab[0], lab[-1], lab[:, 0], lab[:, -1]])) - {0}
    bolsa = croma & ~np.isin(lab, list(borde))
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


def centro(a):
    return np.where(a[..., 3] > 0.5)[1].mean()


ns = list(range(INICIO, FRENTE + 1))
crudos = {n: video(n) for n in ns}
# Temblor: cada fotograma a la media movil de 7 del centro de su silueta.
cx = np.array([centro(crudos[n]) for n in ns])
suave = np.convolve(np.pad(cx, 3, mode='edge'), np.ones(7) / 7, mode='valid')
temblor = {n: int(round(s - c)) for n, s, c in zip(ns, suave, cx)}
estable = {n: mover(crudos[n], temblor[n]) for n in ns}
rep = z['leer'](REPOSO)
# Rampa: al principio lo que mejor casa con el reposo, en el frente lo que lo
# deja simetrico en la casilla.
dx0 = min(range(-8, 9), key=lambda dx: dist(mover(estable[INICIO], dx, DY), rep))
f = estable[FRENTE]
dxf = min(range(-8, 9), key=lambda dx: dist(mover(f, dx), mover(f, dx)[:, ::-1]))
ref = {k: np.mean([z['medias'](z['leer'](p))[k] for p in REPOSOS], 0) for k in ('tunica', 'capucha', 'pies')}
ext = z['medias'](mover(estable[INICIO], dx0, DY))
gan = {k: ref[k] / ext[k] for k in ref}


def sprite(n):
    t = (n - INICIO) / float(FRENTE - INICIO)
    return z['aplicar'](mover(estable[n], int(round(dx0 + t * (dxf - dx0))), DY), gan)


media = [rep] + [sprite(n) for n in ns]         # reposo -> frente
acum = np.concatenate([[0.0], np.cumsum([dist(a, b) for a, b in zip(media, media[1:])])])
M = (int(round(SEGUNDOS * FPS)) - 1) // 2               # sprites por media vuelta
x = np.linspace(0, 1, 2001)
vel = np.where(x < ARRANQUE, VEL_INICIAL + (1 - VEL_INICIAL) * np.clip(x / ARRANQUE, 0, 1) ** 2 * (3 - 2 * np.clip(x / ARRANQUE, 0, 1)), 1.0)
avance = np.concatenate([[0.0], np.cumsum((vel[1:] + vel[:-1]) / 2 * np.diff(x))]); avance /= avance[-1]
# Que fotogramas: los M (del reposo al frente) cuyos pasos, medidos entre ellos y
# no sumando los de en medio (el video tiembla y la suma engaña), mas se parecen
# al perfil de velocidad (arranque suave y luego parejo). Programacion dinamica,
# saltando como mucho SALTO_MAX fotogramas, para varias escalas de paso.
SALTO_MAX = 4
peso = np.diff(np.interp(np.linspace(0, 1, M), x, avance)); peso /= peso.max()
n = len(media)
D = {(i, j): dist(media[i], media[j]) for i in range(n) for j in range(i + 1, min(n, i + SALTO_MAX + 1))}


def mejor_camino(s):
    coste = {0: (0.0, [0])}
    for m in range(1, M):
        nuevo = {}
        for i, (c, cam) in coste.items():
            for j in range(i + 1, min(n, i + SALTO_MAX + 1)):
                if n - 1 - j < M - 1 - m or (m == M - 1 and j != n - 1):
                    continue
                cj = c + (D[i, j] / (s * peso[m - 1]) - 1) ** 2
                if j not in nuevo or cj < nuevo[j][0]:
                    nuevo[j] = (cj, cam + [j])
        coste = nuevo
    return coste.get(n - 1, (np.inf, None))


coste, elegidos = min((mejor_camino(s) for s in np.linspace(0.15, 0.45, 31)), key=lambda r: r[0])
ida = [media[k] for k in elegidos]
frente = fundir(ida[-1], ida[-1][:, ::-1], 0.5)
sprites = ida + [frente] + [s[:, ::-1] for s in reversed(ida)]
for p in glob.glob(os.path.join(SALIDA, '*.png')):
    os.remove(p)
for k, s in enumerate(sprites):
    Image.fromarray((np.ascontiguousarray(s) * 255).round().astype(np.uint8)).save(os.path.join(SALIDA, 'c_%03d.png' % (k + 1)))
pasos = [dist(a, b) for a, b in zip(sprites, sprites[1:])]
print('%d sprites, %.2f s a %d fps; dx0 %d, dx frente %d; temblor %s' % (len(sprites), len(sprites) / float(FPS), FPS, dx0, dxf, sorted(set(temblor.values()))))
print('del video: reposo, %s' % [ns[k - 1] for k in elegidos[1:]])
print('pasos %s' % ' '.join('%.2f' % q for q in pasos[:M + 1]))
print('media %.3f, max %.3f; frente %.2f + %.2f' % (np.mean(pasos), max(pasos), pasos[M - 1], pasos[M]))
print('ganancias %s' % {k: tuple(np.round(v, 3)) for k, v in gan.items()})

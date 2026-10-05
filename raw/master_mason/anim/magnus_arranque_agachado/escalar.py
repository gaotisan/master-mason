"""Lleva los fotogramas del arranque a la escala de Magnus, corrigiendo el zoom.

En este tramo del video la camara se aleja: el agachado quieto del principio
(fotogramas 1-24) mide 1,182 veces el del final (205-240), que es el que ya
casa con el agachado del juego a escala 0,50. El zoom, medido comparando cada
fotograma con el mismo punto del paso 42, 84 y 126 fotogramas despues (el paso
se repite), sigue
    log z(f) = L                         hasta el fotograma T0
    log z(f) = L * exp(-(f - T0) / TAU)  despues
con L = log 1,182, T0 = 24, TAU = 82 (error mediano 0,65 %). Cada fotograma se
escala por 0,50 * zref / z(f): zref va en linea recta de z(205) en el primero
(asi el quieto de partida mide lo que el agachado del juego) a z(FC) en el
ultimo, FC el fotograma del ciclo con el que empalma (asi casa con el ciclo, que
se saco a 0,50 sin corregir).
El suelo sigue al zoom (centro en la fila 941 del video: pies en la 1233 al
principio, 1192 al final) y se pega siempre en la misma fila del lienzo, para
que el arranque no bote.

Lee de _sin_escalar/ y escribe 03_seleccion/.
    python escalar.py <primer fotograma del video> <FC>
"""
import glob, os, shutil, sys
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
SEL = os.path.join(AQUI, '03_seleccion')
ORIG = os.path.join(AQUI, '_sin_escalar')
L, T0, TAU = np.log(1.182), 24, 82.0
CY, SUELO_FIN = 941.0, 1192.0
LIENZO = (1000, 860)


def z(f):
    return np.exp(L if f < T0 else L * np.exp(-(f - T0) / TAU))


primero, fc = int(sys.argv[1]), int(sys.argv[2])
if not os.path.isdir(ORIG):
    shutil.copytree(SEL, ORIG)
fs = sorted(glob.glob(os.path.join(ORIG, '*.png')))
for k, f in enumerate(fs):
    n = primero + k
    t = k / float(max(len(fs) - 1, 1))
    zref = (1 - t) * z(205) + t * z(fc)
    s = 0.5 * zref / z(n)
    suelo = CY + (SUELO_FIN - CY) * z(n) / z(205)        # fila del suelo en el video
    im = Image.open(f).convert('RGB')
    fondo = tuple(int(v) for v in np.median(np.asarray(im)[20:200, 20:120].reshape(-1, 3), axis=0))
    w, h = int(round(im.width * s)), int(round(im.height * s))
    im = im.resize((w, h), Image.LANCZOS)
    lienzo = Image.new('RGB', LIENZO, fondo)
    lienzo.paste(im, ((LIENZO[0] - w) // 2, int(round(LIENZO[1] - 100 - suelo * s))))
    lienzo.save(os.path.join(SEL, os.path.basename(f)))
print('%d fotogramas (video %d-%d), escala %.4f -> %.4f' % (
    len(fs), primero, primero + len(fs) - 1, 0.5 * z(205) / z(primero), 0.5 * z(fc) / z(primero + len(fs) - 1)))

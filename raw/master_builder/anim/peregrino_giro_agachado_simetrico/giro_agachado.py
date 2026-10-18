"""Giro agachado POR DELANTE, del video entero a su ritmo (-> 04_giro; animacion "giro_agachado").

Por que (2026-10-11). El giro agachado de antes (peregrino_giro_agachado_video)
giraba POR DETRAS, ensenando la espalda: quedaba raro y el baston a la espalda
tenia que pasar por delante del cuerpo con una funda de cuero. El usuario pidio
hacerlo por delante, como el giro de pie, "para facilitar la animacion del
baston". Video Crouching_character_pivots_in_place_20261011020817.mp4 (Flow,
prompt _fuentes/prompt_giro_agachado_frente.txt, fotograma inicial el agachado
del juego, c_089 de peregrino_agacharse, y final el mismo espejado): un solo giro
por delante, agachado todo el rato, en ~2 s.

Lo mismo que el giro de pie (peregrino_giro_simetrico/giro_video.py, de donde salen
las piezas), con el agachado en lugar del reposo:
  - tramo f042 -> f100 del video: quieto hasta el 44, gira del 45 al 93 (de
    frente del 61 al 77) y se asienta; despues, quieto hasta el final;
  - tono: el del agachado del juego (el que se ve antes y despues);
  - colocacion: encaje con el agachado al empezar y con su espejo al acabar,
    con rampa suave entre medias;
  - extremos al agachado y a su espejo (forma moviendo pixeles, que se apaga
    viajando con el movimiento, y un fundido corto con el hombre quieto);
  - sombra de la capucha en la cara de frente (la cara sale iluminada);
  - restos del croma.
  python giro_agachado.py   (luego hoja.ps1 -Job peregrino_giro_agachado_simetrico -Desde 04_giro -Fps 24 -Escala 2 -Cols 10)"""
import os
import shutil
import sys

import cv2
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(AQUI), 'peregrino_giro_simetrico'))
import giro_video as GV                   # cabeza, sombra_cara, campo_hacia (y E = espejo.py)
E = GV.E
tono = GV.tono

ORIGEN = os.path.join(AQUI, '04_limpios')            # recortado, sin fondo, pulido (va a git)
DESTINO = os.path.join(AQUI, '04_giro')
AGACHADO = os.path.join(os.path.dirname(AQUI), 'peregrino_agacharse', '04_limpios', 'c_089.png')
# en ORIGEN: c_01 = f001 (el agachado), c_02..c_72 = f040..f110, c_73 = f192 (agachado espejado)
REF_INI, REF_FIN = 1, 73


def c_de(f):
    return f - 38


DESDE, HASTA = 42, 100                 # fotogramas del video que se usan
N_INI, N_FIN = 10, 8                   # fotogramas en que se apaga / enciende la correccion de forma
N_FUNDIDO = 5                          # y el fundido con el agachado (quieto)


def leer(c):
    return np.asarray(Image.open(os.path.join(ORIGEN, 'c_%02d.png' % c)).convert('RGBA'))


if __name__ == '__main__':
    ag = np.asarray(Image.open(AGACHADO).convert('RGBA'))
    ag_e = E.espejo(ag)
    ini, fin = leer(REF_INI), leer(REF_FIN)
    dx0, dy0 = E.encaje(ini, ag)
    dx1, dy1 = E.encaje(fin, ag_e)
    print('encaje con el agachado: al empezar dx %d dy %d; al acabar (espejado) dx %d dy %d' % (dx0, dy0, dx1, dy1))
    fs = list(range(DESDE, HASTA + 1))
    n = len(fs)

    def colocacion(i):
        t = E.suave(i / (n - 1))
        return dx0 + (dx1 - dx0) * t, dy0 + (dy1 - dy0) * t

    # tono: el del agachado del juego (lo que se ve antes y despues)
    objetivo = tono.media([ag.astype(float) / 255])
    muestra = [E.mover(ini, dx0, dy0).astype(float) / 255]
    g = np.ones(3)
    for _ in range(5):
        g = g * objetivo / tono.media([tono.aplicar(im, g) for im in muestra])
    print('ganancia de tono (%.3f, %.3f, %.3f)' % tuple(g))

    def preparar(a, dx, dy):
        im = E.mover(a, dx, round(dy)).astype(float) / 255
        return E.quitar_verde((tono.aplicar(im, g) * 255).round().astype(np.uint8))

    X = [preparar(leer(c_de(f)), *colocacion(i)) for i, f in enumerate(fs)]
    R0, R1 = ag, ag_e

    h, W = X[0].shape[:2]
    yy, xx = np.mgrid[0:h, 0:W].astype(np.float32)
    ident = np.dstack([xx, yy])
    # empiece: el primero, al agachado; la correccion se apaga en N_INI fotogramas
    d0 = GV.campo_hacia(X[0], R0)
    P = ident
    Y = list(X)
    for i in range(0, N_INI + 1):
        if i > 0:
            f = E.flujo(X[i], X[i - 1])          # X[i](x) ~ X[i-1](x + f)
            P = cv2.remap(P, xx + f[..., 0], yy + f[..., 1], cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
        w = 1 - E.suave(i / N_INI)
        if w > 0:
            Y[i] = E.deformar(Y[i], E.llevar(d0, P, 0.0) * w)
    # final: el ultimo, al agachado espejado; la correccion se enciende en N_FIN fotogramas
    d1 = GV.campo_hacia(X[-1], R1)
    P = ident
    for j in range(0, N_FIN + 1):
        i = n - 1 - j
        if j > 0:
            f = E.flujo(X[i], X[i + 1])
            P = cv2.remap(P, xx + f[..., 0], yy + f[..., 1], cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
        w = 1 - E.suave(j / N_FIN)
        if w > 0:
            Y[i] = E.deformar(Y[i], E.llevar(d1, P, 0.0) * w)
    # lo que queda, fundido con el agachado (empieza en el y acaba en su espejo)
    for i in range(N_FUNDIDO):
        t = E.suave(1 - i / N_FUNDIDO)
        Y[i] = E.fundir(Y[i], R0, t)
        Y[n - 1 - i] = E.fundir(Y[n - 1 - i], R1, t)

    # sombra de la capucha en la cara, segun lo de frente que mira (suavizado en el tiempo)
    frente = np.array([GV.cabeza(a)[2] for a in Y])
    frente = np.convolve(np.pad(frente, 2, mode='edge'), np.ones(5) / 5, mode='valid')
    fuerza = GV.SOMBRA * np.array([E.suave((f - 0.15) / 0.55) for f in frente])
    print('sombra de la cara por fotograma: ' + ' '.join('%.2f' % f for f in fuerza))
    Y = [GV.sombra_cara(a, s) for a, s in zip(Y, fuerza)]

    if os.path.isdir(DESTINO):
        shutil.rmtree(DESTINO)
    os.makedirs(DESTINO)
    for i, a in enumerate(Y):
        Image.fromarray(a, 'RGBA').save(os.path.join(DESTINO, 'c_%02d.png' % (i + 1)))
    print(n, "fotogramas (f%03d-f%03d): %.2f s a 24 fps" % (DESDE, HASTA, n / 24))

    # comprobacion: los extremos frente al agachado y el cambio por fotograma
    def pm(x):
        x = x.astype(np.float32)
        return x[..., :3] * x[..., 3:] / 255
    pasos = np.array([np.abs(pm(Y[i + 1]) - pm(Y[i])).mean() for i in range(n - 1)])
    med = np.median(pasos)
    print('al empezar, frente al agachado: %.2f pasos (sin corregir %.2f)'
          % (np.abs(pm(Y[0]) - pm(R0)).mean() / med, np.abs(pm(X[0]) - pm(R0)).mean() / med))
    print('al acabar, frente al agachado espejado: %.2f pasos (sin corregir %.2f)'
          % (np.abs(pm(Y[-1]) - pm(R1)).mean() / med, np.abs(pm(X[-1]) - pm(R1)).mean() / med))
    print('cambio por fotograma (pasos): max %.2f en %d; ' % (pasos.max() / med, pasos.argmax() + 1)
          + ' '.join('%.1f' % (p / med) for p in pasos))

"""Mide los videos de flotar (flotar_*.mp4) fotograma a fotograma, sobre el croma:
fila de la capucha y de los pies, centro (x, y) de la silueta, ancho, y lo que
cambia la silueta de un fotograma al siguiente (para ver tramos quietos, giros
y saltos). Lee el video por tuberia (no escribe fotogramas a disco).

  python medir_flotar.py [bucle|girar|rebote|aterrizar|avanzar ...]"""
import glob
import os
import subprocess
import sys

import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
FFMPEG = os.path.join(AQUI, '..', '..', '..', '..', 'tools', 'ffmpeg', 'bin', 'ffmpeg.exe')
W, H = 1280, 720


def fotogramas(ruta):
    p = subprocess.Popen([FFMPEG, '-v', 'error', '-i', ruta, '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'],
                         stdout=subprocess.PIPE)
    while True:
        b = p.stdout.read(W * H * 3)
        if len(b) < W * H * 3:
            break
        yield np.frombuffer(b, np.uint8).reshape(H, W, 3)


def silueta(f):
    r, g, b = f[..., 0].astype(int), f[..., 1].astype(int), f[..., 2].astype(int)
    verde = (g > 150) & (g - r > 70) & (g - b > 70)
    return ~verde


def main(cual):
    ruta = glob.glob(os.path.join(AQUI, 'flotar_%s_*.mp4' % cual))[0]
    print('==', os.path.basename(ruta))
    print('  f    capucha  pies   cx     cy    ancho  cambio')
    antes = None
    for i, f in enumerate(fotogramas(ruta)):
        m = silueta(f)
        m[:, :4] = False
        m[:, -4:] = False
        filas = np.where(m.sum(1) > 2)[0]
        cols = np.where(m.sum(0) > 2)[0]
        if len(filas) == 0:
            print('%3d  (vacio)' % i)
            continue
        ys, xs = np.nonzero(m)
        cambio = 0.0 if antes is None else float((m ^ antes).sum()) / max(m.sum(), 1)
        antes = m
        print('%3d  %5d  %5d  %6.1f %6.1f  %4d   %.3f' % (i, filas[0], filas[-1], xs.mean(), ys.mean(),
                                                         cols[-1] - cols[0], cambio))


for c in (sys.argv[1:] or ['bucle', 'girar', 'rebote', 'aterrizar', 'avanzar']):
    main(c)

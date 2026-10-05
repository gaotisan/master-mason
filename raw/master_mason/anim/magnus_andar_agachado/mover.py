"""Desplaza en bloque los sprites de una carpeta (dx a la derecha, dy abajo), sin
dejar que nada se salga de la casilla. Es el ajuste final que hace casar las tres
animaciones del andar agachado con el agachado del juego (ver como_se_hizo.txt).
    python mover.py <carpeta> <dx> <dy>
"""
import glob, os, sys
import numpy as np
from PIL import Image
carpeta, dx, dy = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
for f in sorted(glob.glob(os.path.join(carpeta, '*.png'))):
    im = np.asarray(Image.open(f).convert('RGBA'))
    h, w = im.shape[:2]
    ys, xs = np.where(im[..., 3] > 0)
    assert xs.min() + dx >= 0 and xs.max() + dx < w and ys.min() + dy >= 0 and ys.max() + dy < h, f + ': se sale'
    out = np.zeros_like(im)
    out[max(dy, 0):h + min(dy, 0), max(dx, 0):w + min(dx, 0)] = im[max(-dy, 0):h - max(dy, 0), max(-dx, 0):w - max(dx, 0)]
    Image.fromarray(out).save(f)
print('%s: %+d, %+d' % (carpeta, dx, dy))

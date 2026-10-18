"""Desplaza verticalmente los PNG de una carpeta (in place).
  alinear.py <carpeta> --bajar N          desplaza todos N px hacia abajo
  alinear.py <carpeta> --cabeza FILA      fija la fila del primer pixel opaco (alfa>128) en FILA, por fotograma
  alinear.py <carpeta> --ensanchar N      anade N px transparentes a cada lado (la casilla pasa de W a W+2N)
Guarda copia previa en <job>/_sin_alinear/ si no existe.
"""
import sys, glob, os, shutil
import numpy as np
from PIL import Image
carpeta = sys.argv[1]
modo, val = sys.argv[2], int(sys.argv[3])
job = os.path.dirname(os.path.abspath(carpeta))
copia = os.path.join(job, '_sin_alinear')
if not os.path.isdir(copia):
    shutil.copytree(carpeta, copia)
    print('copia previa en', copia)
for f in sorted(glob.glob(os.path.join(carpeta, '*.png'))):
    im = np.asarray(Image.open(f).convert('RGBA'))
    h = im.shape[0]
    if modo == '--bajar':
        d = val
    else:
        ys = np.where((im[..., 3] > 128).any(1))[0]
        d = val - ys.min()
    if modo == '--ensanchar':
        out = np.zeros((h, im.shape[1] + 2 * val, 4), im.dtype)
        out[:, val:val + im.shape[1]] = im
        Image.fromarray(out).save(f)
        print('  %s: %dx%d' % (os.path.basename(f), out.shape[1], h))
        continue
    out = np.zeros_like(im)
    if d >= 0:
        out[d:] = im[:h - d]
    else:
        out[:h + d] = im[-d:]
    Image.fromarray(out).save(f)
    print('  %s: %+d px' % (os.path.basename(f), d))

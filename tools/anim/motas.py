"""Borra de los sprites las manchas sueltas diminutas: restos de polvo, sombra o
croma que el keyeado dejo separados del personaje.

Una mancha es un grupo de pixeles con alfa (8 vecinos) que no toca al dibujo
principal (el grupo mas grande). Se borran las de menos de --menos px de master
(por defecto 60: a media escala, 15 px). Nada del personaje mide eso suelto;
los trozos de pie separados por un hueco de antialias miden mas de mil.
Copia previa en <job>/_sin_motas/ (solo la primera vez; parte siempre de ella).
    python motas.py <carpeta 04_limpios> [--menos N]
"""
import glob, os, shutil, sys
import numpy as np
from PIL import Image
from scipy import ndimage

carpeta = sys.argv[1]
menos = int(sys.argv[sys.argv.index('--menos') + 1]) if '--menos' in sys.argv else 60
copia = os.path.join(os.path.dirname(os.path.abspath(carpeta)), '_sin_motas')
if not os.path.isdir(copia):
    shutil.copytree(carpeta, copia)
total = 0
for f in sorted(glob.glob(os.path.join(copia, '*.png'))):
    im = np.asarray(Image.open(f).convert('RGBA')).copy()
    lab, n = ndimage.label(im[..., 3] > 0, structure=np.ones((3, 3)))
    if n > 1:
        tam = ndimage.sum(im[..., 3] > 0, lab, range(1, n + 1))
        grande = int(np.argmax(tam)) + 1
        fuera = [i + 1 for i, t in enumerate(tam) if i + 1 != grande and t < menos]
        if fuera:
            m = np.isin(lab, fuera)
            im[m] = 0
            total += len(fuera)
            print('  %s: %d manchas, %d px' % (os.path.basename(f), len(fuera), int(m.sum())))
    Image.fromarray(im).save(os.path.join(carpeta, os.path.basename(f)))
print('%d manchas borradas' % total)

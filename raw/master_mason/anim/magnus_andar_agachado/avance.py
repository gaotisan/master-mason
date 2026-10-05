"""Cuanto avanza el cuerpo en cada fotograma: lo que retrocede el pie apoyado.

En los sprites el tronco esta siempre centrado (centrar.ps1), asi que el pie que
apoya se va hacia atras lo que el cuerpo avanza. Entre dos fotogramas seguidos se
busca el desplazamiento horizontal que mejor superpone la franja de suelo (las
12 filas de abajo de cada pie apoyado: la del pie cercano, 663-676, y la del
lejano, 653-666). Da px de master; en el juego, la mitad (hoja a escala 1/2).
    python avance.py <carpeta 04_limpios> [n]
"""
import glob, os, sys
import numpy as np
from PIL import Image
fs = sorted(glob.glob(os.path.join(sys.argv[1], '*.png')))
if len(sys.argv) > 2:
    fs = fs[:int(sys.argv[2])]
A = [np.asarray(Image.open(f).convert('RGBA'))[..., 3].astype(float) / 255 for f in fs]
def franja(a):
    return np.concatenate([a[663:677], a[653:667]], 0)
pasos = []
for i in range(len(A) - 1):
    a, b = franja(A[i]), franja(A[i + 1])
    mejor = None
    for dx in range(-24, 7):
        e = np.abs(np.roll(a, dx, 1) - b).sum()
        if mejor is None or e < mejor[0]:
            mejor = (e, dx)
    pasos.append(-mejor[1])
print('avance por fotograma (px de master):', pasos)
print('media %.2f; acumulado %d' % (np.mean(pasos), sum(pasos)))

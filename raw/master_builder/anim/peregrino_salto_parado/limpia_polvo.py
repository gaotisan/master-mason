"""Quita el polvo que levanta al caer (sprites 46-58) en 04_limpios.

El video pinta una nube de polvo gris claro alrededor de los pies al aterrizar.
Lo que queda debajo de la linea de suelo ya se pinto de fondo antes de centrar
(_sin_recortar_suelo/ guarda los originales); lo que queda por encima sale del
keyeado como pixeles GRISES (112,115,110), casi todos opacos, y algun resto
verdoso oscuro por el derrame. Se borra, de la fila 600 para abajo, lo gris de
verdad (|r-g| <= 10, |g-b| <= 16, max(rgb) entre 100 y 200) y, de la 560 para
abajo, lo verdoso oscuro (g > r+12, max(rgb) < 110). El panel beige del abrigo
es (110,92,87), r-g = 18, y se salva; los zapatos son marrones y las piernas
gris OSCURO (< 100). Un primer intento con "neutro" a |r-g| < 25 y max > 110 se
comia el panel del abrigo y los zapatos. El polvo que cae ENCIMA del zapato no
se toca: quitarlo dejaria agujeros, y son 5 sprites. Parte siempre de _sin_limpiar/.
    python limpia_polvo.py
"""
import glob, os, shutil
import numpy as np
from PIL import Image
aqui = os.path.dirname(os.path.abspath(__file__))
carpeta = os.path.join(aqui, '04_limpios'); copia = os.path.join(aqui, '_sin_limpiar')
if not os.path.isdir(copia):
    shutil.copytree(carpeta, copia)
for f in sorted(glob.glob(os.path.join(copia, '*.png'))):
    im = np.asarray(Image.open(f).convert('RGBA')).astype(int)
    h = im.shape[0]; r, g, b, a = im[..., 0], im[..., 1], im[..., 2], im[..., 3]
    filas = np.arange(h)[:, None]; mx = np.maximum(np.maximum(r, g), b)
    verdoso = (a > 0) & (g > r + 12) & (mx < 110) & (filas >= 560)
    polvo = (a > 0) & (mx >= 100) & (mx <= 200) & (np.abs(r - g) <= 10) & (np.abs(g - b) <= 16) & (filas >= 600)
    quitar = verdoso | polvo
    im[..., 3][quitar] = 0
    Image.fromarray(im.astype(np.uint8)).save(os.path.join(carpeta, os.path.basename(f)))
    n = int(quitar.sum())
    if n > 20: print('%s: %d px (%d verdosos, %d polvo)' % (os.path.basename(f), n, int(verdoso.sum()), int(polvo.sum())))

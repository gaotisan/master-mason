"""Quita el polvo con tinte de croma que queda junto a los pies en 04_limpios.

Dos restos, medidos en _sin_limpiar/:
  - la sombra del polvo al aterrizar (c_01-05): un reguero OPACO de verde muy
    oscuro (24,41,37) en el suelo, filas 660-720, junto al pie delantero
  - una bolsa de croma entre las piernas (c_16-17), filas 540-660, x 250-287:
    opaca y oscurecida por el despill, (39,60,57), 1000 px
Se borra, de la fila 520 para abajo, todo pixel verdoso y oscuro: g > r + 12 y
max(r,g,b) < 110. El abrigo es marron (r > g), las piernas gris neutro y el
suelo no existe, asi que solo entra eso. La capucha tiene brillos gris-verdosos
(110,128,125) pero estan por encima de la fila 240 y son mas claros. Ademas, en
el 18 % inferior, lo claro y neutro con alfa a medias (polvo suelto).
Guarda copia en _sin_limpiar/ y parte siempre de ella (es idempotente).
    python limpia_pies.py
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
    h = im.shape[0]
    r, g, b, a = im[..., 0], im[..., 1], im[..., 2], im[..., 3]
    filas = np.arange(h)[:, None]
    verdoso = (a > 0) & (g > r + 12) & (np.maximum(np.maximum(r, g), b) < 110) & (filas >= 520)
    polvo = (a > 20) & (a < 230) & (np.maximum(np.maximum(r, g), b) > 110) & (np.abs(r - g) < 25) & (np.abs(g - b) < 25) & (filas >= int(h * 0.82))
    quitar = verdoso | polvo
    im[..., 3][quitar] = 0
    Image.fromarray(im.astype(np.uint8)).save(os.path.join(carpeta, os.path.basename(f)))
    print('%s: %d px quitados (%d verdosos, %d polvo)' % (os.path.basename(f), int(quitar.sum()), int(verdoso.sum()), int(polvo.sum())))

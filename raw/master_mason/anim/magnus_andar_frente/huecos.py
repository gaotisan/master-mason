"""Quita el croma en sombra que queda encerrado (entre las piernas, entre la
mano y la tunica): fondo.ps1 rellena desde el borde del cuadro y ahi no llega.

Un pixel es croma si es verde dominante (g - max(r, b) > VERDE) o gris verdoso
(g >= b y g - r > VERDE_R, lo que queda de la sombra mezclada): la tunica es
marron, las piernas gris oscuro y la barba blanca, ninguno lo es. (La sombra
proyectada no es croma puro oscurecido, lleva luz ambiente: por la recta del
croma, como _sombra.py, se quedaban manchas.) Esos pasan a transparentes. Al resto se le
quita el tinte verde de borde (g no pasa de max(r, b) + 4).
Las piernas son casi negras pero no verdes: no las toca. El gris verdoso solo se
busca en la franja de los pies (el ultimo PIES del alto): mas arriba, la barba
blanca tiene algo de verde y se agujereaba. Dentro de esa franja se cierran
los poros de la mancha (cierre de 3x3) donde no sea piel ni tunica (r > g).
Sobre 04_limpios, en el sitio.
    python huecos.py <job>
"""
import glob, os, sys
import numpy as np
from scipy.ndimage import binary_closing
from PIL import Image

ANIM = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERDE = 6; VERDE_R = 8; PIES = 0.22
n = 0
for f in sorted(glob.glob(os.path.join(ANIM, sys.argv[1], '04_limpios', '*.png'))):
    a = np.asarray(Image.open(f).convert('RGBA')).astype(float)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    ys = np.nonzero((al > 0).any(1))[0]
    franja = np.zeros_like(al, bool); franja[int(ys.max() - PIES * (ys.max() - ys.min())):] = True
    gris = franja & (g >= b) & (g - r > VERDE_R)
    gris = binary_closing(gris, np.ones((3, 3))) & franja & (g >= r)
    croma = ((g - np.maximum(r, b) > VERDE) | gris) & (al > 0)
    n += croma.sum()
    al[croma] = 0
    a[..., 1] = np.minimum(g, np.maximum(r, b) + 4)
    Image.fromarray(a.round().astype(np.uint8)).save(f)
print('%d pixeles de croma encerrado quitados' % n)

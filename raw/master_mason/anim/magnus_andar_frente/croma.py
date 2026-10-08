"""Recorte de croma suave, para personajes pequenos en el cuadro.

fondo.ps1 (relleno desde el borde con radio) se come lo fino: en el andar de
espaldas (Hooded_figure_walking_forward, personaje de ~400 px de alto en 720p)
dejaba las piernas (~6 px) translucidas y el baston (~4 px) con ribete verde.
Aqui el alfa sale de cuanto domina el verde, d = g - max(r, b): el fondo esta
en ~155 y lo gris del personaje (capucha, piernas) anda por 0-5. Entre medias, alfa lineal, y
el color de esos pixeles de borde es el del pixel solido mas cercano (des-mezclar
con el fondo se disparaba con alfa pequeno y dejaba linea morada). A todo se le
quita el tinte verde (g <= 0,97 max(r, b)). La mancha mayor es el personaje.
Lee 03_seleccion/ y escribe _sin_normalizar/ (RGBA a tamano de video).
    python croma.py <job> [desde hasta]     (posiciones en 03_seleccion, desde 1)
"""
import glob, os, sys
import numpy as np
from PIL import Image
from scipy.ndimage import label, binary_dilation, distance_transform_edt

ANIM = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ANIM, sys.argv[1])
SAL = os.path.join(D, '_sin_normalizar'); os.makedirs(SAL, exist_ok=True)
DENTRO = 5.0     # d por debajo: personaje opaco (a 15 quedaba ribete oliva)
FS = sorted(glob.glob(os.path.join(D, '03_seleccion', '*.png')))
if len(sys.argv) > 3:
    FS = FS[int(sys.argv[2]) - 1:int(sys.argv[3])]
for f in FS:
    p = np.asarray(Image.open(f).convert('RGB')).astype(float)
    fondo = np.median(p[:40, :200].reshape(-1, 3), axis=0)
    fuera = fondo[1] - max(fondo[0], fondo[2]) - 15.0
    d = p[..., 1] - np.maximum(p[..., 0], p[..., 2])
    a = np.clip((fuera - d) / (fuera - DENTRO), 0, 1)
    lab, n = label(a > 0.5)
    mayor = np.bincount(lab.ravel())[1:].argmax() + 1
    a *= binary_dilation(lab == mayor, iterations=2)
    c = p.copy()
    # el baston es fino y la compresion del video (croma a media resolucion) le
    # mete verde hasta en el centro: el verde no pasa del mayor de rojo y azul
    c[..., 1] = np.minimum(c[..., 1], np.maximum(c[..., 0], c[..., 2]) * 0.97)
    # y en los tonos calidos (madera, oro de la garra, tunica: b < r - 25) el
    # verde no pasa del 80 % del rojo, que es donde estan de verdad (madera
    # 0,70-0,75, oro 0,78); el borde verdoso del baston era oliva (0,95)
    calido = c[..., 2] < c[..., 0] - 25
    c[..., 1][calido] = np.minimum(c[..., 1], c[..., 0] * 0.8)[calido]
    # borde (mezcla con el verde): des-mezclar con alfa pequeno se dispara (salia
    # una linea morada); se toma el color del pixel solido mas cercano
    solido = a >= 0.95
    _, (iy, ix) = distance_transform_edt(~solido, return_indices=True)
    borde = (a > 0) & ~solido
    c[borde] = c[iy[borde], ix[borde]]
    c[a == 0] = 0
    Image.fromarray(np.dstack([c, a * 255]).round().astype(np.uint8), 'RGBA').save(
        os.path.join(SAL, os.path.basename(f)))
print('listo', SAL)

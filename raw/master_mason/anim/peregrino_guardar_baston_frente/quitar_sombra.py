"""Aplana la sombra que Veo pinto en el suelo (fotogramas 2-189; el prompt decia
sin sombra): la idea de tools/anim/_sombra.py, con numpy (aquel va pixel a pixel
y tarda una eternidad con 192 fotogramas de 720p).

La sombra es el croma con menos luz: (r, g, b) = k (Rf, Gf, Bf). Con k = g / Gf,
residuo = max(|r - k Rf|, |b - k Bf|): fondo y sombra dan poco, el personaje
(pardos, grises, la barba) mucho. Se aplana (al color del fondo) solo lo que,
estando en esa recta, se alcanza desde el borde del cuadro por sitios anchos
(apertura de radio RADIO): la sombra es una mancha ancha; entre los dedos de los
pies o en un pliegue oscuro no entra.
Lee y escribe 03_seleccion/ (copia intacta en _con_sombra/, que no se pisa).
    python quitar_sombra.py
"""
import glob, os, shutil
import numpy as np
from PIL import Image
from scipy.ndimage import binary_opening, label

AQUI = os.path.dirname(os.path.abspath(__file__))
SEL = os.path.join(AQUI, '03_seleccion'); COPIA = os.path.join(AQUI, '_con_sombra')
TOL, RADIO = 25.0, 3
if not os.path.isdir(COPIA):
    shutil.copytree(SEL, COPIA)
yy, xx = np.mgrid[-RADIO:RADIO + 1, -RADIO:RADIO + 1]
DISCO = xx ** 2 + yy ** 2 <= RADIO ** 2
for f in sorted(glob.glob(os.path.join(COPIA, '*.png'))):
    p = np.asarray(Image.open(f).convert('RGB')).astype(float)
    fondo = np.median(np.concatenate([p[:40, :200], p[:40, -200:]]).reshape(-1, 3), axis=0)
    k = p[..., 1] / fondo[1]
    res = np.maximum(np.abs(p[..., 0] - k * fondo[0]), np.abs(p[..., 2] - k * fondo[2]))
    recta = (res <= TOL) & (k > 0.2) & (k < 1.15)
    ancho = binary_opening(recta, structure=DISCO)
    lab, n = label(ancho)
    borde = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    fuera = np.isin(lab, borde[borde > 0])
    q = p.copy(); q[fuera] = fondo
    Image.fromarray(q.round().astype(np.uint8), 'RGB').save(os.path.join(SEL, os.path.basename(f)))
print('sombra aplanada en', len(glob.glob(os.path.join(SEL, '*.png'))), 'fotogramas')

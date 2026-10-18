"""Montaje de los videos "en el sitio" del modo sin baston (2026-10-12): la vuelta,
el andar de espaldas y las carreras, pedidos con nuestras referencias (Flow, Frames
to Video: el sprite de master 1:1 con su casilla 584x800 en (668, 286) de 1920x1080).

montar.py (el de la secuencia) normaliza cada fotograma a capucha-pies 628 con el
suelo por una recta suelo ~ altura: vale con camara fija y el personaje acercandose
o alejandose, pero estos andan en el sitio (la altura casi no cambia) y la recta sale
mal condicionada (cada video se descoloca unos px: el final de la vuelta y el
principio del andar, que son la misma imagen, salian a 7 de diferencia). Aqui:
  - la transformacion FIJA de las referencias (x1,5 desde (445,33, 190,67) del video
    de 720p, como sacar / guardar): el primer fotograma cae donde estaba el sprite;
  - salvo --fijo (la vuelta, en el sitio de verdad), el tamano se lleva al del primer
    fotograma (capucha-pies medida por medir.py, suavizada como montar.py: mediana 11 +
    gaussiana 3) escalando alrededor de los pies, y el eje del tronco al del primero
    (suavizado: gaussiana 2): asi no encoge al alejarse un poco ni se va de lado.
Escribe <job>/_todos/c_001.. (casilla 584x800, como la secuencia) y <job>/medidas.json
(h: la del primero en todos; la escena no escala con estos: el avance lo pone
secuencia.py).
    python montar_en_sitio.py <job> [--fijo]
"""
import glob, json, os, sys
import numpy as np
from PIL import Image
from scipy.ndimage import median_filter, gaussian_filter1d

ANIM = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JOB = sys.argv[1]
FIJO = '--fijo' in sys.argv
D = os.path.join(ANIM, JOB)
CAS = (584, 800)
OX, OY, S = 668 * 2 / 3, 286 * 2 / 3, 1.5          # la casilla 584x800 en el video de 720p

r = np.array(json.load(open(os.path.join(D, 'medidas_crudas.json'))), float)   # i, top, pie, h, cx, barba
h = gaussian_filter1d(median_filter(r[:, 3], 11, mode='nearest'), 3, mode='nearest')
pie = gaussian_filter1d(median_filter(r[:, 2], 11, mode='nearest'), 3, mode='nearest')
cx = gaussian_filter1d(r[:, 4], 2, mode='nearest')
SAL = os.path.join(D, '_todos'); os.makedirs(SAL, exist_ok=True)
for f in glob.glob(os.path.join(SAL, '*.png')):
    os.remove(f)
fs = sorted(glob.glob(os.path.join(D, '_sin_normalizar', '*.png')))
for k, f in enumerate(fs):
    im = Image.open(f).convert('RGBa')               # premultiplicado: sin orla al escalar
    if FIJO:
        s, ax, ay, bx, by = 1.0, 0.0, 0.0, 0.0, 0.0
    else:
        # alrededor del ancla (eje, pies) del fotograma k, llevada a la del primero
        s = h[0] / h[k]
        ax, ay, bx, by = cx[k], pie[k], cx[0], pie[0]
    # casilla -> video: v = ((c / S + O) - B) / s + A   (A = ancla de k, B = la del primero)
    a = 1 / (S * s)
    tx = (OX - bx) / s + ax if not FIJO else OX
    ty = (OY - by) / s + ay if not FIJO else OY
    c = im.transform(CAS, Image.AFFINE, (a, 0, tx, 0, a, ty), resample=Image.BICUBIC)
    c.convert('RGBA').save(os.path.join(SAL, 'c_%03d.png' % (k + 1)))
json.dump({'h': [round(float(h[0]), 3)] * len(fs), 'fijo': FIJO,
           'escala': [round(float(h[0] / v), 4) for v in h]}, open(os.path.join(D, 'medidas.json'), 'w'))
print('%s: %d sprites a la casilla 584x800%s; capucha-pies %.0f..%.0f (corregido a %.0f)' % (
    JOB, len(fs), ' (transformacion fija)' if FIJO else '', h.min(), h.max(), h[0]))

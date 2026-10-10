"""Sacar / guardar el baston de frente: los 192 fotogramas a la casilla de master.

Los videos se pidieron con fotograma inicial y final sacados de la escena
(_fuentes/referencia_baston_espalda_frente.png y _mano_frente.png: 1920x1080, el
sprite de master 1:1 con su casilla 584x800 en (668, 286)) y Veo los devolvio a
1280x720 con el mismo encuadre al pixel (el primer y el ultimo fotograma calcan
la silueta de las referencias). La camara no se mueve y el personaje no se acerca:
no hace falta medir nada por fotograma, todo con la misma transformacion
(x1,5 desde (445,33, 190,67) del video), asi que casa con la escena sin el
temblor de normalizar fotograma a fotograma.
Casilla mas grande que la del reposo: +40 a cada lado y +104 arriba (el baston,
levantado, sube 76 px por encima de la de 800); el suelo, igual de lejos del
borde de abajo (43 px), y centrada igual. 904 de alto: la hoja (a la mitad)
tiene que medir multiplos de 4 (empaquetar.py, bloques de la compresion BC7).
    python montar.py <job>       (magnus_sacar_baston_frente | magnus_guardar_baston_frente)
Escribe <job>/_todos/c_001..c_192.png.
"""
import glob, os, sys
from PIL import Image

ANIM = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JOB = sys.argv[1] if len(sys.argv) > 1 else 'magnus_sacar_baston_frente'
D = os.path.join(ANIM, JOB)
OX, OY, S = 668 * 2 / 3, 286 * 2 / 3, 1.5      # la casilla 584x800 en el video
MX, MY = 40, 104                                # lo que se agranda la casilla (multiplo de 8: la hoja, de 4)
CAS = (584 + 2 * MX, 800 + MY)
SAL = os.path.join(D, '_todos'); os.makedirs(SAL, exist_ok=True)
for f in glob.glob(os.path.join(SAL, '*.png')):
    os.remove(f)
fs = sorted(glob.glob(os.path.join(D, '_sin_normalizar', '*.png')))
for k, f in enumerate(fs, 1):
    im = Image.open(f).convert('RGBa')         # premultiplicado: sin orla negra al escalar
    c = im.transform(CAS, Image.AFFINE, (1 / S, 0, OX - MX / S, 0, 1 / S, OY - MY / S), resample=Image.BICUBIC)
    c.convert('RGBA').save(os.path.join(SAL, 'c_%03d.png' % k))
print(JOB, len(fs), 'fotogramas a', CAS)

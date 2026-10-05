"""Lleva los fotogramas del video a la escala de Magnus y a un lienzo holgado.

El video (Flow, 1280x720) se hizo con el agachado del juego a tamano de master en
un fotograma de 1920x1080 (_fuentes/referencia_giro_video_inicio.png): a 720p
mide 2/3, asi que la escala es 1,5 justa (485 px de alto, como el agachado). La
camara no se mueve (pies en la fila 585 en los 240 fotogramas, mismo tamano).
Se recorta la zona del personaje, se escala y se pega en un lienzo de 1000x860
del verde del video con el suelo a 100 px del borde de abajo.
Lee de _sin_escalar/ (la seleccion tal cual) y escribe 03_seleccion/.
    python escalar.py
"""
import glob, os, shutil
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
SEL = os.path.join(AQUI, '03_seleccion'); ORIG = os.path.join(AQUI, '_sin_escalar')
RECORTE = (360, 160, 920, 620)     # x0, y0, x1, y1 del video
SUELO = 585
ESCALA = 1.5
LIENZO = (1000, 860)
if not os.path.isdir(ORIG):
    shutil.copytree(SEL, ORIG)
for f in sorted(glob.glob(os.path.join(ORIG, '*.png'))):
    im = Image.open(f).convert('RGB')
    verde = tuple(int(v) for v in np.median(np.asarray(im)[:20, :200].reshape(-1, 3), axis=0))
    c = im.crop(RECORTE)
    c = c.resize((round(c.width * ESCALA), round(c.height * ESCALA)), Image.LANCZOS)
    lienzo = Image.new('RGB', LIENZO, verde)
    lienzo.paste(c, ((LIENZO[0] - c.width) // 2, round(LIENZO[1] - 100 - (SUELO - RECORTE[1]) * ESCALA)))
    lienzo.save(os.path.join(SEL, os.path.basename(f)))
print('%d fotogramas a escala %.2f' % (len(glob.glob(os.path.join(ORIG, '*.png'))), ESCALA))

"""Lleva los fotogramas del andar en diagonal a la escala de Magnus.

El video (Flow, 720x1280 en vertical, fondo beis liso 230,226,218) anda en el
sitio de tres cuartos, de cara hacia la derecha; mide unos 1065 px de alto, asi
que la escala es 628/1065 = 0,59 (el reposo mide 628 de master). Se recorta la
zona del personaje, se escala y se pega en un lienzo de 1000x860 del color del
fondo con el suelo (pies, fila 1185 del video) a 100 px del borde de abajo.
Lee de _sin_escalar/ (la seleccion tal cual) y escribe 03_seleccion/.
    python escalar.py
"""
import glob, os, shutil
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
SEL = os.path.join(AQUI, '03_seleccion'); ORIG = os.path.join(AQUI, '_sin_escalar')
RECORTE = (60, 40, 700, 1240)      # x0, y0, x1, y1 del video
SUELO = 1185
ESCALA = 628 / 1065.0
LIENZO = (1000, 860)
if not os.path.isdir(ORIG):
    shutil.copytree(SEL, ORIG)
for f in sorted(glob.glob(os.path.join(ORIG, '*.png'))):
    im = Image.open(f).convert('RGB')
    fondo = tuple(int(v) for v in np.median(np.asarray(im)[:20, :200].reshape(-1, 3), axis=0))
    c = im.crop(RECORTE)
    c = c.resize((round(c.width * ESCALA), round(c.height * ESCALA)), Image.LANCZOS)
    lienzo = Image.new('RGB', LIENZO, fondo)
    lienzo.paste(c, ((LIENZO[0] - c.width) // 2, round(LIENZO[1] - 100 - (SUELO - RECORTE[1]) * ESCALA)))
    lienzo.save(os.path.join(SEL, os.path.basename(f)))
print('%d fotogramas a escala %.3f' % (len(glob.glob(os.path.join(ORIG, '*.png'))), ESCALA))

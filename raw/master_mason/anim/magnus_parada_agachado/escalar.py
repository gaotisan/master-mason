"""Lleva los fotogramas elegidos a la escala de Magnus y a un lienzo holgado.

El video viene en vertical (720x1280) y con el personaje al doble del tamano de
master: agachado mide 962 px de alto y 536 de ancho (video 229) y el agachado
del juego (magnus_agacharse c_062) 485 y 267. Escala 0,50 justa: 360x640.
Luego se pega en un lienzo de 1000x860 del color del fondo, con el suelo (fila
1190 del video, 595 escalado) a 100 px del borde de abajo: centrar.ps1 necesita
margen para desplazar la ventana de 584 (el video escalado solo mide 360).

Lee de _sin_escalar/ (la seleccion tal cual; se copia la primera vez) y
escribe 03_seleccion/.
    python escalar.py
"""
import glob, os, shutil
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
SEL = os.path.join(AQUI, '03_seleccion')
ORIG = os.path.join(AQUI, '_sin_escalar')
ESCALA = 0.5
LIENZO = (1000, 860)
SUELO = 595          # fila del suelo ya escalado
if not os.path.isdir(ORIG):
    shutil.copytree(SEL, ORIG)
for f in sorted(glob.glob(os.path.join(ORIG, '*.png'))):
    im = Image.open(f).convert('RGB')
    fondo = tuple(int(v) for v in np.median(np.asarray(im)[20:200, 20:120].reshape(-1, 3), axis=0))
    w, h = int(round(im.width * ESCALA)), int(round(im.height * ESCALA))
    im = im.resize((w, h), Image.LANCZOS)
    lienzo = Image.new('RGB', LIENZO, fondo)
    lienzo.paste(im, ((LIENZO[0] - w) // 2, LIENZO[1] - 100 - SUELO))
    lienzo.save(os.path.join(SEL, os.path.basename(f)))
print('%d fotogramas a %dx%d en un lienzo de %dx%d' % (len(glob.glob(os.path.join(ORIG, '*.png'))), w, h, *LIENZO))

"""Separa las 5 vistas de la hoja de Gemini y las deja a escala de Magnus.

La hoja (_fuentes/giro_agachado_2.jpeg, 3168x1344) trae el agachado de perfil
y girando hacia la camara hasta el frente, sobre croma verde. Las cinco miden lo
mismo (1100-1103 px) y pisan en la misma fila (1250): la escala es una sola. Se
saca encajando la de perfil contra el agachado del juego (magnus_agacharse
c_089): con 0,440 coinciden en un 96,4 % de la silueta y mide lo mismo, 485 px.
Cada vista se recorta a su caja (asi la vecina no se cuela al escalar), se
escala y se pega en un lienzo de 1000x860 del verde de la hoja con el suelo a
100 px del borde de abajo (centrar.ps1 necesita margen para mover la ventana).
    python separar.py      -> 01_frames/f_0001.png .. f_0005.png
"""
import os
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
HOJA = os.path.join(AQUI, '..', '_fuentes', 'giro_agachado_2.jpeg')
SALIDA = os.path.join(AQUI, '01_frames')
CAJAS = [(44, 148, 630, 1251), (665, 148, 1234, 1250), (1264, 148, 1864, 1251),
         (1946, 148, 2530, 1250), (2573, 151, 3065, 1251)]
MARGEN = 12          # px de la hoja alrededor de cada caja (todo verde)
SUELO = 1250         # fila de los pies en la hoja
ESCALA = 0.440
LIENZO = (1000, 860)

im = Image.open(HOJA).convert('RGB')
verde = tuple(int(v) for v in np.median(np.asarray(im)[:10].reshape(-1, 3), axis=0))
os.makedirs(SALIDA, exist_ok=True)
for k, (x0, y0, x1, y1) in enumerate(CAJAS):
    c = im.crop((x0 - MARGEN, y0 - MARGEN, x1 + MARGEN, y1 + MARGEN))
    w, h = round(c.width * ESCALA), round(c.height * ESCALA)
    c = c.resize((w, h), Image.LANCZOS)
    lienzo = Image.new('RGB', LIENZO, verde)
    suelo = (SUELO - (y0 - MARGEN)) * ESCALA          # fila del suelo dentro del recorte escalado
    lienzo.paste(c, ((LIENZO[0] - w) // 2, int(round(LIENZO[1] - 100 - suelo))))
    lienzo.save(os.path.join(SALIDA, 'f_%04d.png' % (k + 1)))
print('5 vistas a escala %.3f, fondo %s' % (ESCALA, verde))

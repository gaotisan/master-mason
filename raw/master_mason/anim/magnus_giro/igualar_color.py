"""Lleva el color de la tunica de los 5 sprites del giro al del reposo.

La hoja de rotacion salio con la tunica mas clara y mas roja que los videos
(medido sobre los pixeles calidos del abrigo, media RGB):
    reposo c_01 (95,70,62)   andar c_01 (96,70,63)
    giro c_01 (100,70,65)  c_02 (103,71,66)  c_03 (105,72,66)  c_04 (106,72,67)  c_05 (100,70,65)
o sea hasta un 11 % mas de valor y un 19 % mas de rojo sobre azul en el frontal:
al girar, el abrigo se encendia y volvia a apagarse. Capucha y barba NO estaban
desviadas (capucha 113-125 en el giro, 122-130 en reposo), asi que la ganancia se
aplica solo a lo calido: cada pixel se corrige en proporcion a su saturacion
(peso 0 por debajo de 0,08, 1 por encima de 0,20), para que no haya bordes entre
paneles corregidos y sin corregir, y solo por encima de la fila 640, que es
donde acaba el abrigo: los pies ya se igualaron aparte (ver como_se_hizo, A).
Ganancia por canal = media del reposo / media de la tunica del sprite.
Guarda copia en _sin_igualar_color/ y parte siempre de ella.
    python igualar_color.py
"""
import glob, os, shutil
import numpy as np
from PIL import Image
aqui = os.path.dirname(os.path.abspath(__file__))
carpeta = os.path.join(aqui, '04_limpios'); copia = os.path.join(aqui, '_sin_igualar_color')
REF = os.path.join(aqui, '..', 'magnus_respirando', '04_limpios', 'c_01.png')
FILA_PIES = 640

def tunica(rgb):
    mx = rgb.max(-1); mn = rgb.min(-1); s = (mx - mn) / np.maximum(mx, 1e-6)
    return (rgb[..., 0] > rgb[..., 1]) & (rgb[..., 1] >= rgb[..., 2] - 0.02) & (s > 0.12) & (mx > 0.15) & (mx < 0.85)

def media_tunica(f):
    im = np.asarray(Image.open(f).convert('RGBA')).astype(float) / 255
    m = (im[..., 3] > 0.8) & tunica(im[..., :3]); m[FILA_PIES:] = False
    return im[..., :3][m].mean(0)

if not os.path.isdir(copia):
    shutil.copytree(carpeta, copia)
ref = media_tunica(REF)
for f in sorted(glob.glob(os.path.join(copia, '*.png'))):
    im = np.asarray(Image.open(f).convert('RGBA')).astype(float) / 255
    rgb = im[..., :3]
    m = (im[..., 3] > 0.8) & tunica(rgb); m[FILA_PIES:] = False
    mx = rgb.max(-1); mn = rgb.min(-1); s = (mx - mn) / np.maximum(mx, 1e-6)
    peso = np.clip((s - 0.08) / 0.12, 0, 1) * (rgb[..., 0] > rgb[..., 2])   # solo lo calido
    peso[FILA_PIES:] = 0
    # Como el peso no es 1 en toda la tunica, la ganancia se afina en tres
    # pasadas hasta que la media corregida cae en la del reposo.
    ganancia = np.ones(3); nuevo = rgb
    for _ in range(3):
        ganancia = ganancia * ref / nuevo[m].mean(0)
        nuevo = np.clip(rgb * (1 + peso[..., None] * (ganancia - 1)), 0, 1)
    out = im.copy(); out[..., :3] = nuevo
    Image.fromarray((out * 255).round().astype(np.uint8)).save(os.path.join(carpeta, os.path.basename(f)))
    print('%s: ganancia (%.3f, %.3f, %.3f) -> tunica %s' % (os.path.basename(f), ganancia[0], ganancia[1], ganancia[2],
          tuple(int(v) for v in (media_tunica(os.path.join(carpeta, os.path.basename(f))) * 255).round())))
print('referencia reposo:', tuple(int(v) for v in (ref * 255).round()))

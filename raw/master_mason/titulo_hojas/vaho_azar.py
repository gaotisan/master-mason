"""Los valores del hash del vaho del titulo (title_reveal.gdshader), horneados
en una imagen para leerlos de una vez con el filtro lineal (2026-10-14: el
ruido calculado eran 32 hashes por pixel del vaho y el titulo iba a 28 fps en
la P520).

No vale un azar cualquiera: el vaho se mueve muy despacio sobre un punado de
puntos de la reticula, y con otros valores salia otro vaho (casi el doble de
cristal cubierto). Aqui van los MISMOS valores que daba el hash, para los
puntos de -128 a 127 (el shader lee en i + 128): con el desplazamiento del vaho
eso son mas de diez minutos de TIME; despues repite, sin que se note.

  python vaho_azar.py   ->  assets/intro/title_vaho_azar.png (256, gris)
"""
import os

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
DESTINO = os.path.normpath(os.path.join(AQUI, "..", "..", "..", "assets", "intro", "title_vaho_azar.png"))


def hash_vaho(x, y):
    """El hash de title_reveal.gdshader, en float32 como en la grafica."""
    f = np.float32
    px = (x.astype(f) * f(0.1031)) % f(1.0)
    py = (y.astype(f) * f(0.1030)) % f(1.0)
    d = px * (px + f(33.33)) + py * (py + f(33.33))
    px, py = px + d, py + d
    return ((px + py) * px) % f(1.0)


y, x = np.mgrid[0:256, 0:256]
v = hash_vaho(x - 128, y - 128)
Image.fromarray(np.round(v * 255).astype(np.uint8), "L").save(DESTINO)
print("ok", DESTINO)

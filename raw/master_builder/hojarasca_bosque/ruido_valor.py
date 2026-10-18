"""Azar para el ruido de valor de los shaders (fondo_haz.gdshader de la
hojarasca; title_hojas_viento.gdshader y title_reveal.gdshader del titulo).

Una celda por punto de la reticula con un valor al azar (0..1): el shader lee
la celda de cada punto con filtro lineal y salen los mismos degradados blandos
que con un hash, a una lectura por octava en vez de cuatro hashes
(2026-10-14: el fondo de la hojarasca costaba 5 ms en la grafica del portatil).
Repite cada 256 puntos: a la escala de los shaders no se ve.

  python ruido_valor.py   ->  assets/comun/ruido_valor.png (256, gris)
"""
import os
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
DESTINO = os.path.join(AQUI, "..", "..", "..", "assets", "comun", "ruido_valor.png")

azar = np.random.default_rng(2026).integers(0, 256, (256, 256), dtype=np.uint8)
Image.fromarray(azar, "L").save(os.path.normpath(DESTINO))
print("ok", os.path.normpath(DESTINO))

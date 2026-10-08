"""Pesos de los arbustos para el viento del titulo, precalculados.

El shader title_hojas_viento.gdshader reparte el desplazamiento de cada
arbusto (un muelle por arbusto, en viento_titulo.gd) por la imagen: cuanto
pertenece cada pixel a cada arbusto (gaussiana alrededor de su zona,
normalizada entre los seis) por cuanto se dobla ahi la rama (0 en la raiz, 1 en
la punta). Todo eso es fijo, asi que se hornea aqui en vez de calcularlo por
pixel y por fotograma (seis exp y seis pow por pixel; en la P520 frenada por
calor costaba 10-20 FPS).

Salida, a 1/4 de resolucion (es suave), sin alfa (al importar, Godot retoca
el color de los pixeles transparentes, y eso estropearia los pesos):
  title_viento_pesos_a.png  RGB = arbustos 0..2
  title_viento_pesos_b.png  RGB = arbustos 3..5

Los arbustos (raiz, centro, radio, largo) tienen que ser los mismos que en
ARBUSTOS de viento_titulo.gd.

Uso: python pesos_viento.py   (despues de componer.py, que hace la mascara)
"""
import os

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.normpath(os.path.join(AQUI, "..", "..", ".."))
INTRO = os.path.join(PROYECTO, "assets", "intro")
W, H = 2912, 1632
ESC = 4

ARBUSTOS = [
    ((0, 0), (480, 170), 520.0, 1050.0),
    ((2912, 0), (1950, 210), 620.0, 1500.0),
    ((0, 850), (270, 840), 330.0, 560.0),
    ((2912, 850), (2640, 840), 330.0, 560.0),
    ((0, 1632), (480, 1450), 560.0, 1050.0),
    ((2912, 1632), (2420, 1440), 620.0, 1150.0),
]


def main():
    w, h = W // ESC, H // ESC
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    p = np.stack([(xx + 0.5) * ESC, (yy + 0.5) * ESC], -1)
    pesos = []
    for raiz, centro, radio, largo in ARBUSTOS:
        q = (p - np.array(centro, np.float32)) / radio
        pesos.append(np.exp(-(q ** 2).sum(-1)))
    suma = np.maximum(sum(pesos), 1e-4)
    capas = []
    for (raiz, centro, radio, largo), w_ in zip(ARBUSTOS, pesos):
        l = np.linalg.norm(p - np.array(raiz, np.float32), axis=-1)
        flex = np.clip(l / largo, 0, 1) ** 1.4
        capas.append(w_ / suma * flex)
    a = np.dstack([capas[2], capas[1], capas[0]])   # BGR: R=0 G=1 B=2
    b = np.dstack([capas[5], capas[4], capas[3]])   # BGR: R=3 G=4 B=5
    for nombre, im in (("title_viento_pesos_a.png", a), ("title_viento_pesos_b.png", b)):
        cv2.imwrite(os.path.join(INTRO, nombre), np.round(np.clip(im, 0, 1) * 255).astype(np.uint8))
        print("escrito", nombre, w, "x", h)


if __name__ == "__main__":
    main()

"""Saca el sprite del baston para Godot desde la imagen de Gemini y escribe el
seguimiento. Todo a la escala de las hojas de Magnus (media escala).
  python exportar.py"""
import json
import numpy as np
from PIL import Image
import seguir
from celdas import PROY

FUENTE = "../_fuentes/baston_solo_gemini_v1.jpeg"
RECORTE = (1270, 280, 1520, 2170)        # x0, y0, x1, y1 en la imagen de Gemini
FONDO = np.array([39, 208, 52.])
ALTO_MAGNUS_GEMINI = 1995                 # px, medido en la misma imagen
ESCALA = 628 / ALTO_MAGNUS_GEMINI / 2 * 0.9   # a media escala y al 90 % (mas corto queda mejor a la espalda)
GARRA = (105 / 218, 125 / 1860)           # centro del hueco de la garra, en fraccion del sprite
PIVOTE = 40                               # px (ya escalado) desde la punta: el punto que sigue a la espalda
RECORTE_ABAJO = 0.13                      # se le quita esto por abajo: a la espalda esa parte va siempre
                                          # tapada, y mas corto cabe agachado sin asomar ni subirlo mucho
DESTINO = PROY / "assets/characters/baston"


def recortar():
    im = np.array(Image.open(FUENTE).convert("RGB")).astype(float)
    x0, y0, x1, y1 = RECORTE
    c = im[y0:y1, x0:x1].copy()
    dist = np.sqrt(((c - FONDO) ** 2).sum(2))
    a = np.clip((dist - 50) / 40, 0, 1)
    # la madera es naranja/marron (r > g): el verde que pase de r es del croma
    c[..., 1] = np.minimum(c[..., 1], c[..., 0] * 0.92)
    rgba = Image.fromarray(np.dstack([c, a * 255]).clip(0, 255).astype(np.uint8), "RGBA")
    caja = rgba.getbbox()
    return rgba.crop(caja), caja


if __name__ == "__main__":
    spr, caja = recortar()
    w, h = round(spr.width * ESCALA), round(spr.height * ESCALA)
    peq = spr.resize((w, h), Image.LANCZOS)
    gx, gy = GARRA[0] * w, GARRA[1] * h
    h = round(h * (1 - RECORTE_ABAJO))
    peq = peq.crop((0, 0, w, h))
    # la punta cortada en seco se veria; afinarla en los ultimos px
    a = np.array(peq)
    for i in range(8):
        a[h - 1 - i, :, 3] = (a[h - 1 - i, :, 3] * (i + 1) / 9).astype(np.uint8)
    peq = Image.fromarray(a)
    DESTINO.mkdir(parents=True, exist_ok=True)
    peq.save(DESTINO / "baston.png")
    info = {"ancho": w, "alto": h, "pivote": PIVOTE, "garra": [round(gx, 1), round(gy, 1)]}
    print("baston.png", info)
    import subprocess, sys
    subprocess.run([sys.executable, "seguir.py"], check=True)

"""Referencias 1920x1080 (16:9) para el BUCLE DEL ARRASTRE (prompt_arrastre_bucle.txt;
Flow, fotogramas a video; 2026-10-15). El arrastre del juego (peregrino_tumbarse,
c075-c123) es una brazada entera del video y al repetirse salta (el usuario: "da
un salto en cada avance"); el video nuevo de 2026-10-15
(peregrino_arrastrarse_v2/estudio.txt) no casa con el tumbarse ni con el levantarse.
Aqui se pide uno que empiece y acabe en el MISMO fotograma de nuestro arrastre,
c096 de peregrino_tumbarse/04_limpios (a mitad de brazada, donde mas deprisa va:
con uno quieto Flow arranca y frena en los extremos), el del final corrido
AVANCE px a la derecha (4 brazadas de 95 px de master, lo que hace el arrastre
del juego en 8 s). En el juego: tumbarse -> arrastre viejo hasta c096 -> este
bucle -> arrastre viejo desde c097 -> levantarse.

Escala de master 1:1 (la casilla de 920x720 tal cual), el suelo de la casilla
(raiz_fila de peregrino_tumbarse/raiz.json) en y=1040, croma #24D732.
  python referencias_arrastre_bucle.py [carpeta de salida; por defecto esta]"""
import json
import os
import sys

from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
JOB = os.path.join(AQUI, "..", "peregrino_tumbarse")
SALIDA = sys.argv[1] if len(sys.argv) > 1 else AQUI
CROMA = (0x24, 0xD7, 0x32, 255)
SUELO = 1040
AVANCE = 4 * 95
FOTOGRAMA = "c_096.png"

raiz_fila = json.load(open(os.path.join(JOB, "raiz.json")))["raiz_fila"]
peregrino = Image.open(os.path.join(JOB, "04_limpios", FOTOGRAMA)).convert("RGBA")
caja = peregrino.getbbox()
# centrado: del borde izquierdo al empezar al derecho al acabar
ancho = caja[2] - caja[0] + AVANCE
x0 = (1920 - ancho) // 2 - caja[0]
y0 = SUELO - raiz_fila
for nombre, dx in [("referencia_arrastre_inicio.png", 0), ("referencia_arrastre_fin.png", AVANCE)]:
    lienzo = Image.new("RGBA", (1920, 1080), CROMA)
    lienzo.alpha_composite(peregrino, (x0 + dx, y0))
    lienzo.convert("RGB").save(os.path.join(SALIDA, nombre))
    print(nombre, "peregrino en x", x0 + dx + caja[0], "..", x0 + dx + caja[2])

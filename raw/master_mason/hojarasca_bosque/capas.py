"""El bosque de la hojarasca partido en dos planos para el paralaje (2026-10-13).

Antes el paralaje salia de un mapa de profundidad muy desenfocado (canal B de
bosque_viento.png): casi todo el bosque quedaba como "cerca" y se movia de una
pieza, como un carton. Ahora hay dos capas de verdad que se deslizan una sobre
otra sin deformarse:

  bosque_cerca.png  los troncos oscuros de delante (y sus ramas gruesas), con
                    alfa. En la niebla, oscuro = cerca (perspectiva aerea).
  bosque_lejos.png  todo lo demas (niebla, troncos lejanos, el camino); debajo
                    de los troncos de delante, la niebla de alrededor rellenada
                    (push-pull): al moverse la camara asoma un borde de unos
                    pocos px, que tiene que ser niebla y no un tronco fantasma.

  vista_capas.png   (con --vista, en esta carpeta) lo que va delante marcado y
                    las dos capas desplazadas DESPLAZA_VISTA px una de otra, a
                    un lado y al otro, aclaradas, para revisar el corte.

Uso: python capas.py [--vista]
"""
import os
import sys

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.normpath(os.path.join(AQUI, "..", "..", ".."))
SALIDA = os.path.join(PROYECTO, "assets", "world", "hojarasca")

OSCURO = 0.07        # luminancia (suavizada) por debajo: tronco de delante
GRUESO_PX = 11       # lo mas fino que esto no siembra (ramitas, bordes)
CRECE_PX = 180       # cuanto se extiende la semilla por lo oscuro pegado a ella
CRECE_OSCURO = 0.07  # lo que se considera oscuro al extenderse
BORDE_PX = 3         # la capa de delante se lleva un pelin de su borde
HUECO_PX = 8         # lo que se rellena en la de detras (mas que el borde)
DESPLAZA_VISTA = 24


def luminancia(img):
	return 0.2126 * img[..., 2] + 0.7152 * img[..., 1] + 0.0722 * img[..., 0]


def disco(r):
	return cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1))


def mascara_cerca(img):
	lum = luminancia(img)
	l4 = cv2.GaussianBlur(lum, (0, 0), 4)
	semilla = (l4 < OSCURO).astype(np.uint8)
	# Solo lo grueso siembra: troncos y ramas principales.
	semilla = cv2.morphologyEx(semilla, cv2.MORPH_OPEN, disco(GRUESO_PX // 2))
	n, etiquetas, stats, _ = cv2.connectedComponentsWithStats(semilla)
	grande = np.zeros_like(semilla)
	for i in range(1, n):
		if stats[i, cv2.CC_STAT_AREA] > 6000:
			grande[etiquetas == i] = 1
	# Se extiende por lo oscuro que le toca (sus ramas, el borde del tronco),
	# poco a poco para no saltar a otro arbol por una rama que se cruza.
	oscuro = (cv2.GaussianBlur(lum, (0, 0), 1.5) < CRECE_OSCURO).astype(np.uint8)
	m = grande.copy()
	for _ in range(CRECE_PX // 3):
		m = cv2.dilate(m, disco(3)) & (oscuro | grande)
	m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, disco(4))
	return m


def rellenar(img, peso):
	"""Push-pull: lo que no tiene peso se rellena con lo de alrededor."""
	niveles = []
	p = img * peso[..., None]
	w = peso.copy()
	while min(w.shape) > 4:
		niveles.append((p, w))
		h, an = w.shape
		tam = ((an + 1) // 2, (h + 1) // 2)
		p = cv2.resize(p, tam, interpolation=cv2.INTER_AREA)
		w = cv2.resize(w, tam, interpolation=cv2.INTER_AREA)
	c = p / np.maximum(w, 1e-6)[..., None]
	for p, w in reversed(niveles):
		h, an = w.shape
		arriba = cv2.resize(c, (an, h), interpolation=cv2.INTER_LINEAR)
		c = p + (1.0 - w)[..., None] * arriba
		# p ya va multiplicado por w (cobertura 0..1).
	return c


def main():
	src = cv2.imread(os.path.join(SALIDA, "bosque_hojarasca.png"), cv2.IMREAD_COLOR)
	img = src.astype(np.float32) / 255.0
	m = mascara_cerca(img)
	alfa = cv2.GaussianBlur(cv2.dilate(m, disco(BORDE_PX)).astype(np.float32), (0, 0), 1.2)
	hueco = cv2.dilate(m, disco(HUECO_PX)).astype(np.float32)
	hueco = cv2.GaussianBlur(hueco, (0, 0), 2.0)
	lejos = rellenar(img, np.clip(1.0 - hueco, 0.0, 1.0))
	lejos = np.clip(lejos, 0.0, 1.0)

	cerca = np.concatenate([img, alfa[..., None]], -1)
	cv2.imwrite(os.path.join(SALIDA, "bosque_cerca.png"), (cerca * 255.0 + 0.5).astype(np.uint8))
	cv2.imwrite(os.path.join(SALIDA, "bosque_lejos.png"), (lejos * 255.0 + 0.5).astype(np.uint8))
	print("cerca: %.1f %% de la imagen" % (100.0 * m.mean()))
	if "--vista" in sys.argv:
		vista(img, m, alfa, lejos)


def vista(img, m, alfa, lejos):
	# En el juego van mucho mas oscuras: aclaradas para ver el corte.
	filas = []
	for d in (-DESPLAZA_VISTA, DESPLAZA_VISTA):
		mov = np.float32([[1, 0, d], [0, 1, 0]])
		h, an = alfa.shape
		c2 = cv2.warpAffine(img, mov, (an, h), borderMode=cv2.BORDER_REPLICATE)
		a2 = cv2.warpAffine(alfa, mov, (an, h), borderMode=cv2.BORDER_REPLICATE)[..., None]
		comp = lejos * (1.0 - a2) + c2 * a2
		filas.append(np.clip(comp * 2.2, 0.0, 1.0))
	hoja = np.concatenate(filas, 0)
	marca = img.copy()
	marca[m > 0] = marca[m > 0] * 0.4 + np.float32([0.1, 0.1, 0.9]) * 0.6
	hoja = np.concatenate([np.clip(marca * 2.2, 0.0, 1.0), hoja], 0)
	hoja = cv2.resize(hoja, (hoja.shape[1] // 2, hoja.shape[0] // 2), interpolation=cv2.INTER_AREA)
	cv2.imwrite(os.path.join(AQUI, "vista_capas.png"), (hoja * 255.0).astype(np.uint8))


if __name__ == "__main__":
	main()

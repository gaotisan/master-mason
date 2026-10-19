"""Fondo del cruce del bosque: la imagen de los tres caminos con la casa de
Dominus al fondo del camino central, y con el color del camino del bosque.

Fuentes (de Midjourney, 2912x1632):
  fondo_midjourney.png  el cruce: un camino central que se pierde en la niebla
                        entre dos robles viejos, uno a la izquierda que sale casi
                        de lado y otro a la derecha que sube entre rocas
  casa_midjourney.png   la casa de Dominus: castillo en la niebla tras una verja

LA CASA. Al fondo del camino central la imagen trae una mancha de niebla casi
vacia entre dos troncos finos. Ahi va la casa con su verja, lejos, como una
silueta en la bruma: de la imagen de la casa se toma lo que es mas oscuro (o
mas claro) que la niebla que tiene alrededor (casa / niebla, por pixel) y se
multiplica sobre la niebla del cruce, con menos contraste (perspectiva aerea:
esta mas lejos). Solo dentro del contorno de la casa y la verja (CONTORNO: los
arboles de alrededor no vienen) y solo donde el cruce es niebla clara (los
troncos y las ramas del cruce quedan delante).

EL COLOR. La imagen es mas clara y mas calida que la del camino del bosque
(mediana de luminancia 38 contra 21,5; rojo/azul 1,64 contra 1,29) y es el
contraplano: el corte saltaba. Se oscurece con una curva (gamma en la
luminancia, las luces casi igual) y se enfria hacia el camino, en la fraccion
IGUALAR de lo que haria falta para igualarlo del todo.

Salida: fondo_compuesto.png (lo lee mascaras.py, que le quita el grano).
Uso: python componer.py [--sin-color]
"""
import os
import sys

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
W, H = 2912, 1632

# --- La casa -------------------------------------------------------------
# Contorno de la casa y la verja en casa_midjourney.png (px): pilares, la verja
# entre ellos y el castillo con sus agujas, sin los arboles de los lados.
CONTORNO = [(1095, 1112), (1095, 640), (1232, 640), (1236, 480), (1290, 320),
			(1335, 230), (1375, 105), (1415, 230), (1470, 170), (1530, 300),
			(1600, 330), (1660, 420), (1712, 430), (1724, 640), (1855, 640),
			(1855, 1112)]
# Donde va en el cruce: centro de la base (el pie de la verja, en el fondo del
# camino) y ancho de la verja de pilar a pilar (en la imagen de la casa, 760 px).
BASE = (1497.0, 1046.0)
ANCHO = 330.0
# Contraste que conserva (1 = el de la imagen de la casa): la niebla se come
# parte de lo oscuro.
CONTRASTE = 0.62
# Lo que se aclaran sus luces (lo mas claro que la niebla): poco, que no brille.
LUCES = 0.35

# --- El color ------------------------------------------------------------
# Del camino del bosque (fondo_midjourney.png de camino_bosque), medidos.
MEDIANA_CAMINO = 21.5 / 255.0
ROJO_AZUL_CAMINO = 1.29
# Fraccion del camino hasta igualarlo (1 = igual; 0 = sin tocar).
IGUALAR = 0.7


def suave(a, b, x):
	t = np.clip((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def lum(rgb):
	return rgb @ np.array([0.3, 0.59, 0.11], np.float32)


def niebla_de(l, radio):
	"""La niebla de alrededor: lo oscuro (troncos, verja) fuera con un cierre y
	todo difuminado."""
	k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * radio + 1, 2 * radio + 1))
	cerrado = cv2.morphologyEx(l, cv2.MORPH_CLOSE, k)
	return cv2.GaussianBlur(cerrado, (0, 0), radio * 0.8)


def poner_casa(cruce):
	casa = cv2.cvtColor(cv2.imread(os.path.join(AQUI, "casa_midjourney.png")), cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
	assert casa.shape[:2] == (H, W), casa.shape
	lc = cv2.GaussianBlur(lum(casa), (0, 0), 0.8)
	# Lo que la casa oscurece o aclara la niebla (1 = nada).
	razon = lc / np.maximum(niebla_de(lc, 40), 0.03)
	mascara = np.zeros((H, W), np.float32)
	cv2.fillPoly(mascara, [np.array(CONTORNO, np.int32)], 1.0)
	mascara = cv2.GaussianBlur(mascara, (0, 0), 10.0)
	# Al cruce: escala y traslado (el pie de la verja a BASE).
	xs = [p[0] for p in CONTORNO]
	ys = [p[1] for p in CONTORNO]
	s = ANCHO / (max(xs) - min(xs))
	cx = 0.5 * (max(xs) + min(xs))
	m = np.float32([[s, 0, BASE[0] - cx * s], [0, s, BASE[1] - max(ys) * s]])
	razon_c = cv2.warpAffine(razon, m, (W, H), flags=cv2.INTER_AREA, borderValue=1.0)
	mascara_c = cv2.warpAffine(mascara, m, (W, H), flags=cv2.INTER_LINEAR, borderValue=0.0)
	# Perspectiva aerea: menos contraste; lo claro, solo un poco.
	efecto = np.where(razon_c < 1.0, 1.0 + (razon_c - 1.0) * CONTRASTE, 1.0 + (razon_c - 1.0) * LUCES)
	# Solo sobre la niebla clara del cruce (sus troncos y ramas, delante). La
	# referencia es la niebla de alrededor: lo que es mas oscuro que ella es rama.
	lx = cv2.GaussianBlur(lum(cruce), (0, 0), 1.0)
	nx = niebla_de(lx, 12)
	delante = suave(0.04, 0.12, nx - lx)
	donde = mascara_c * suave(0.35, 0.5, lx) * (1.0 - delante)
	# El pie se pierde en la bruma del suelo (no hay suelo debajo que lo sujete).
	y = np.mgrid[0:H, 0:W][0].astype(np.float32)
	donde *= 1.0 - 0.6 * suave(BASE[1] - 50.0, BASE[1] + 6.0, y)
	f = 1.0 + (efecto - 1.0) * donde
	return cruce * f[..., None]


def igualar_color(rgb):
	l = lum(rgb)
	mediana = float(np.median(l))
	# Gamma en la luminancia (lo que la deja con la mediana del camino), en la
	# fraccion IGUALAR; el color se escala con la luminancia (no cambia de tono).
	g_total = np.log(MEDIANA_CAMINO) / np.log(mediana)
	g = 1.0 + (g_total - 1.0) * IGUALAR
	nueva = np.power(np.clip(l, 1e-5, 1.0), g)
	out = rgb * (nueva / np.maximum(l, 1e-5))[..., None]
	# Enfriar: rojo/azul hacia el del camino, sin cambiar la luminancia.
	media = out.reshape(-1, 3).mean(0)
	ra = media[0] / media[2]
	objetivo = ra * (ROJO_AZUL_CAMINO / ra) ** IGUALAR
	k = np.sqrt(objetivo / ra)
	ganancia = np.array([k, 1.0, 1.0 / k], np.float32)
	ganancia /= float(np.dot(ganancia * media, [0.3, 0.59, 0.11]) / np.dot(media, [0.3, 0.59, 0.11]))
	out = out * ganancia
	print("  color: mediana %.1f -> %.1f, rojo/azul %.2f -> %.2f, gamma %.2f" % (
		mediana * 255, np.median(lum(out)) * 255, ra, (out.reshape(-1, 3).mean(0)[0] / out.reshape(-1, 3).mean(0)[2]), g))
	return np.clip(out, 0.0, 1.0)


def main():
	cruce = cv2.cvtColor(cv2.imread(os.path.join(AQUI, "fondo_midjourney.png")), cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
	assert cruce.shape[:2] == (H, W), cruce.shape
	out = poner_casa(cruce)
	if "--sin-color" not in sys.argv:
		out = igualar_color(out)
	cv2.imwrite(os.path.join(AQUI, "fondo_compuesto.png"),
				cv2.cvtColor((out * 255.0 + 0.5).astype(np.uint8), cv2.COLOR_RGB2BGR))
	print("  fondo_compuesto.png")


if __name__ == "__main__":
	main()

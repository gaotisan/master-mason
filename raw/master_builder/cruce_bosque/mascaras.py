"""Mascaras de la escena del cruce del bosque (el contraplano del camino).

Lo mismo que raw/master_builder/camino_bosque/mascaras.py (lee alli lo que
mide cada mascara y por que), con las medidas de esta imagen: usa sus funciones
y cambia solo los numeros. La fuente es fondo_compuesto.png (componer.py: el
cruce de Midjourney con la casa de Dominus al fondo del camino central y el
color del camino).

  fondo.png, detras.png, viento.png, medio.png, aire.png, profundidad.png y
  hojas_copa.json -> assets/world/cruce_bosque/ (las que se leen por pixel,
  ademas en pixeles/). El ruido y las hojas desenfocadas son las del camino.

PROFUNDIDAD (distinta de la del camino). Alli los lados eran paredes de troncos
cerca de la camara; aqui, bajo el horizonte, los lados son suelo con matas y
montones, y como paredes se movian mucho mas que el camino de al lado (el suelo
se despegaba de las matas). Aqui: el suelo es un plano bajo HORIZONTE (el del
peregrino) y lo que se levanta (robles, arboles, matas altas) esta a la
distancia de su pie, la del suelo en la fila BASE (una curva a lo ancho, medida
a ojo en los pies de los troncos); lo claro (la niebla), lejos.

Uso: python mascaras.py   (antes, python componer.py)
"""
import importlib.util
import json
import os

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.normpath(os.path.join(AQUI, "..", "..", ".."))
SALIDA = os.path.join(PROYECTO, "assets", "world", "cruce_bosque")

# Las funciones del camino (rayos, rellenar, envolver...), con estos numeros.
_spec = importlib.util.spec_from_file_location(
	"mascaras_camino", os.path.join(AQUI, "..", "camino_bosque", "mascaras.py"))
base = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(base)

W, H = base.W, base.H
# --- Medidas sobre la imagen (px) -------------------------------------------
# El resplandor: tras la casa, al fondo del camino central (maximo del brillo
# difuminado, un poco por encima: los rayos salen de la copa).
FUENTE = (1630.0, 560.0)
# La copa se mueve entera hasta y = 520 y nada desde y = 1000 (los pies de los
# troncos, las matas y el suelo).
COPA_Y = (520.0, 1000.0)
# El horizonte del peregrino (peregrino_cruce.gd): la fila del suelo a la
# distancia infinita. El camino central se pierde algo mas abajo (1046, el pie
# de la verja): baja hacia la casa.
HORIZONTE = 1000.0
W_LEJOS = 0.04
# Fila del pie de lo que se levanta, a lo ancho (x, y): los arboles de la
# izquierda tras el monton, las raices del roble izquierdo, el fondo, el roble
# derecho en su loma y las rocas de la derecha.
BASE = [(0, 1150), (600, 1120), (1100, 1090), (1300, 1050), (1500, 1046), (1700, 1050),
		(2000, 1020), (2400, 1080), (2912, 1150)]
GRANO_H = 7
# La copa del pasillo de luz, donde cuelgan hojas (x desde, x hasta; y hasta).
HOJAS_X = (1000, 2050)
HOJAS_Y = 760


def puntos_de_hojas(rama, tronco, altura):
	"""Como en el camino, con la copa de aqui (HOJAS_X / HOJAS_Y)."""
	fina = (rama > 0.5) & (tronco == 0) & (altura > 0.25)
	fina[:, :HOJAS_X[0]] = False
	fina[:, HOJAS_X[1]:] = False
	fina[HOJAS_Y:, :] = False
	ys, xs = np.nonzero(fina)
	rng = np.random.default_rng(7)
	celdas = set()
	puntos = []
	for i in rng.permutation(len(xs)):
		c = (int(xs[i]) // 28, int(ys[i]) // 28)
		if c in celdas:
			continue
		celdas.add(c)
		puntos.append([int(xs[i]), int(ys[i])])
	with open(os.path.join(SALIDA, "hojas_copa.json"), "w", encoding="utf-8") as f:
		json.dump(puntos, f)
	print("   hojas_copa.json", len(puntos), "puntos")


def profundidad(rgb, lum, x, y):
	"""w (1 cerca .. 0 fondo), w del fondo de alrededor y la imagen de detras."""
	w_suelo = np.clip((y - HORIZONTE) / (H - HORIZONTE), 0.0, 1.0)
	bx = np.array([p[0] for p in BASE], np.float32)
	by = np.array([p[1] for p in BASE], np.float32)
	w_pie = np.clip((np.interp(x[0], bx, by) - HORIZONTE) / (H - HORIZONTE), 0.0, 1.0)[None, :]
	claro = base.suave(0.10, 0.42, cv2.GaussianBlur(lum, (0, 0), 8))
	w_arriba = w_pie * (1.0 - claro) + W_LEJOS * claro
	w = cv2.GaussianBlur(np.maximum(w_suelo, w_arriba), (0, 0), 3)
	w_fondo = cv2.erode(w, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (81, 81)))
	# (solo sobre el horizonte: en el suelo, w crece fila a fila y todo saldria "delante")
	delante = ((w - w_fondo) > 0.05) & (y < HORIZONTE)
	delante = cv2.dilate(delante.astype(np.uint8), np.ones((7, 7))) > 0
	return w, w_fondo, base.rellenar(rgb, delante)


def main():
	for nombre, valor in [("SALIDA", SALIDA), ("FUENTE", FUENTE), ("COPA_Y", COPA_Y)]:
		setattr(base, nombre, valor)
	os.makedirs(SALIDA, exist_ok=True)
	bgr = cv2.imread(os.path.join(AQUI, "fondo_compuesto.png"), cv2.IMREAD_COLOR)
	assert bgr.shape[:2] == (H, W), bgr.shape
	limpio = cv2.fastNlMeansDenoisingColored(bgr, None, GRANO_H, GRANO_H, 7, 21)
	cv2.imwrite(os.path.join(SALIDA, "fondo.png"), limpio)
	rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
	rgb_limpio = cv2.cvtColor(limpio, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
	lum = rgb @ np.array([0.3, 0.59, 0.11], np.float32)
	ls = cv2.GaussianBlur(lum, (0, 0), 1.2)
	y, x = np.mgrid[0:H, 0:W].astype(np.float32)

	# Troncos, copa, luz: como en el camino.
	ancho = (cv2.GaussianBlur(ls, (0, 0), 25) - ls) > 0.03
	k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * base.TRONCO_R + 1, 2 * base.TRONCO_R + 1))
	tronco = cv2.morphologyEx(ancho.astype(np.uint8), cv2.MORPH_OPEN, k)
	grueso = base.envolver(tronco.astype(np.float32), 3, 4.0)
	lejos = cv2.distanceTransform((1 - tronco).astype(np.uint8), cv2.DIST_L2, 5)
	flex = base.suave(0.0, base.FLEX_PX, lejos)
	detalle = np.clip(cv2.GaussianBlur(ls, (0, 0), 8) - ls, 0.0, 1.0)
	claro = base.suave(0.05, 0.2, cv2.GaussianBlur(lum, (0, 0), 20))
	rama = base.suave(0.025, 0.08, detalle) * claro
	ramas = base.envolver(rama, 9, 5.0)
	altura = 1.0 - base.suave(COPA_Y[0], COPA_Y[1], y)
	copa = ramas * (1.0 - grueso) * flex * altura
	luz = base.suave(0.25, 0.65, cv2.GaussianBlur(lum, (0, 0), 50))
	medio = cv2.GaussianBlur(rgb, (0, 0), 28)

	w, w_fondo, detras = profundidad(rgb_limpio, lum, x, y)
	lum4 = cv2.resize(ls, (W // 4, H // 4), interpolation=cv2.INTER_AREA)
	haces = base.rayos(lum4, 4)
	tapa = cv2.GaussianBlur(tronco.astype(np.float32), (0, 0), 10)
	puntos_de_hojas(rama, tronco, altura)

	print("mascaras ->", SALIDA)
	base.guardar("profundidad.png", [w, w_fondo, np.zeros_like(w)], 2)
	cv2.imwrite(os.path.join(SALIDA, "detras.png"),
				cv2.cvtColor((np.clip(detras, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8), cv2.COLOR_RGB2BGR))
	print("   detras.png")
	base.guardar("viento.png", [copa, ramas * altura, 1.0 - w], 2)
	base.guardar("medio.png", [medio[..., 0], medio[..., 1], medio[..., 2], luz], 4)
	h4 = (H // 4, W // 4)
	base.guardar("aire.png", [cv2.resize(tapa, h4[::-1], interpolation=cv2.INTER_AREA),
							  0.5 + 0.5 * haces,
							  cv2.resize(luz, h4[::-1], interpolation=cv2.INTER_AREA)], 1)


if __name__ == "__main__":
	main()

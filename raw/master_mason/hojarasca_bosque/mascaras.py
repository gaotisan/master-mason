"""Mascaras del bosque de fondo de la hojarasca (2026-10-13).

El fondo es una sola imagen de Midjourney (bosque_hojarasca.png, 2912x1632,
"side view of the dark edge of a misty autumn forest at night...", con el
estilo del fondo de camino_bosque) y no se recorta: bosque_fondo.gdshader la
desplaza donde estas mascaras dicen, como camino_fondo.gdshader en la escena
del camino (de la que sale este script: raw/master_mason/camino_bosque/
mascaras.py). Asi el fondo deja de ser una foto plana: las ramas finas se
mecen con el viento y, cuando la camara respira, lo cercano se mueve mas que lo
lejano (paralaje).

  bosque_viento.png (1/2)  R copa: cuanto se mueve cada rama (0 en troncos y
                           suelo; mas en lo fino, lo alto y lo lejos del tronco)
                           G troncos (lo grueso y oscuro: no se mueve)
                           B profundidad: 0 cerca .. 1 lejos (en la niebla lo
                           lejano es lo claro); muy difuminada, para que en el
                           paralaje solo se estire niebla lisa en los cantos.
                           Ya no se usa: dejaba casi todo como "cerca" y el
                           bosque se movia de una pieza; el paralaje va ahora
                           en dos planos (capas.py)
  bosque_ruido.png  512    cuatro ruidos fbm que repiten sin costura

Uso: python mascaras.py
"""
import os

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.normpath(os.path.join(AQUI, "..", "..", ".."))
SALIDA = os.path.join(PROYECTO, "assets", "world", "hojarasca")
FUENTE = os.path.join(AQUI, "bosque_hojarasca.png")   # la fuente, aqui (el juego no la usa)
W, H = 2912, 1632

# La copa se mueve entera por encima de COPA_Y[0] y nada por debajo de
# COPA_Y[1] (la parte baja de los troncos, entre la bruma).
COPA_Y = (380.0, 980.0)
# Grosor a partir del cual una rama es tronco (radio de la apertura, px).
TRONCO_R = 9
# Distancia al tronco a la que la rama ya se dobla entera (px).
FLEX_PX = 90.0


def suave(a, b, x):
	t = np.clip((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def envolver(m, engorde, difuminado):
	"""Silueta engordada y difuminada (0..1)."""
	k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * engorde + 1, 2 * engorde + 1))
	return np.clip(cv2.GaussianBlur(cv2.dilate(m, k), (0, 0), difuminado), 0.0, 1.0)


def ruido_periodico(n, beta, semilla):
	"""fbm que repite sin costura: ruido blanco filtrado en frecuencia (1/f^beta)."""
	rng = np.random.default_rng(semilla)
	f = np.fft.fftfreq(n)
	fx, fy = np.meshgrid(f, f)
	r = np.sqrt(fx * fx + fy * fy)
	r[0, 0] = 1.0
	espectro = np.fft.fft2(rng.standard_normal((n, n))) / r ** beta
	espectro[0, 0] = 0.0
	espectro[r < 2.5 / n] = 0.0
	espectro *= np.exp(-(r * n / 40.0) ** 2)
	a = np.real(np.fft.ifft2(espectro))
	a = (a - a.mean()) / (a.std() * 4.0) + 0.5
	return np.clip(a, 0.0, 1.0)


def guardar(nombre, canales, escala):
	img = np.stack(canales, -1)
	if escala != 1:
		img = cv2.resize(img, (img.shape[1] // escala, img.shape[0] // escala), interpolation=cv2.INTER_AREA)
	img = (np.clip(img, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
	img = cv2.cvtColor(img, cv2.COLOR_RGBA2BGRA if img.shape[2] == 4 else cv2.COLOR_RGB2BGR)
	cv2.imwrite(os.path.join(SALIDA, nombre), img)
	print("  ", nombre, img.shape)


def main():
	bgr = cv2.imread(FUENTE, cv2.IMREAD_COLOR)
	assert bgr.shape[:2] == (H, W), bgr.shape
	rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
	lum = rgb @ np.array([0.3, 0.59, 0.11], np.float32)
	ls = cv2.GaussianBlur(lum, (0, 0), 1.2)
	y, x = np.mgrid[0:H, 0:W].astype(np.float32)

	# --- Troncos: lo oscuro y ancho sobre la niebla (sobrevive a abrir con un
	# disco de TRONCO_R px).
	ancho = (cv2.GaussianBlur(ls, (0, 0), 30) - ls) > 0.025
	k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * TRONCO_R + 1, 2 * TRONCO_R + 1))
	tronco = cv2.morphologyEx(ancho.astype(np.uint8), cv2.MORPH_OPEN, k)
	grueso = envolver(tronco.astype(np.float32), 3, 4.0)
	lejos_tronco = cv2.distanceTransform((1 - tronco).astype(np.uint8), cv2.DIST_L2, 5)
	flex = suave(0.0, FLEX_PX, lejos_tronco)

	# --- Copa: ramas finas oscuras recortadas contra la niebla. En lo negro no
	# se ven: ahi ni se miden.
	detalle = np.clip(cv2.GaussianBlur(ls, (0, 0), 8) - ls, 0.0, 1.0)
	claro = suave(0.04, 0.16, cv2.GaussianBlur(lum, (0, 0), 20))
	rama = suave(0.02, 0.07, detalle) * claro
	ramas = envolver(rama, 9, 5.0)
	altura = 1.0 - suave(COPA_Y[0], COPA_Y[1], y)
	copa = ramas * (1.0 - grueso) * flex * altura

	# --- Profundidad: perspectiva aerea (lo claro de la niebla, lejos; lo
	# oscuro de los troncos grandes, cerca). Muy difuminada.
	lejos = suave(0.05, 0.45, cv2.GaussianBlur(lum, (0, 0), 35))
	prof = cv2.GaussianBlur(lejos, (0, 0), 22)

	print("mascaras ->", SALIDA)
	guardar("bosque_viento.png", [copa, grueso, prof], 2)
	guardar("bosque_ruido.png", [ruido_periodico(512, 1.3, s) for s in (11, 23, 37, 51)], 1)


if __name__ == "__main__":
	main()

"""Quita el pico que rebota por detras de la capucha en los videos de Veo
(2026-10-19: el correr en diagonal acercandose, Old_pilgrim_running_on_green_
20261019145023, lo saca en ~la mitad de los fotogramas de la carrera).

Es un saliente fino pegado al contorno de la capucha, fuera de su linea: en lo
alto de la figura (ALTO, fraccion de su altura) se abre la silueta con un disco
de DISCO px (a la resolucion del video) y lo que sobresale, si es mas que
AREA_MIN px, fuera; despues, lo que quede suelto, fuera, y el canto del corte
suavizado. El fondo es croma, asi que detras no hay nada que rellenar.

DISCO 23 (probado a 720p): quita el pico entero en casi todos los fotogramas y a
la punta propia de la capucha solo le come ~50 px (no se nota). Con 17 quedaba
un munon; con 27 se redondeaba tambien la punta propia. Se aplica a TODOS los
fotogramas igual: si se aplicase solo a los que tienen pico, la punta de la
capucha cambiaria de un fotograma a otro.

  quitar(bgr) -> (alfa, alfa_sin_pico, px_quitados)
"""
import cv2
import numpy as np

DISCO = 23
ALTO = 0.22
AREA_MIN = 20


def mascara(bgr):
	"""Alfa del personaje sobre croma verde (solo la pieza grande)."""
	b, g, r = [bgr[..., k].astype(int) for k in range(3)]
	alfa = np.clip((60 - (g - np.maximum(r, b))) / 35.0, 0.0, 1.0)
	n, lab, st, _ = cv2.connectedComponentsWithStats((alfa > 0.5).astype(np.uint8), 8)
	k = np.argmax(st[1:, cv2.CC_STAT_AREA]) + 1
	return alfa * (cv2.dilate((lab == k).astype(np.uint8), np.ones((5, 5))) > 0)


def quitar(bgr, disco=DISCO):
	a = mascara(bgr)
	m = (a > 0.5).astype(np.uint8)
	ys, _ = np.nonzero(m)
	y0 = ys.min()
	zona = np.zeros_like(m)
	zona[y0:y0 + int(ALTO * (ys.max() - y0))] = 1
	abierta = cv2.morphologyEx(m, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (disco, disco)))
	sobra = (m & ~abierta & zona).astype(np.uint8)
	n, lab, st, _ = cv2.connectedComponentsWithStats(sobra, 8)
	q = np.zeros_like(m)
	for k in range(1, n):
		if st[k, cv2.CC_STAT_AREA] >= AREA_MIN:
			q |= (lab == k).astype(np.uint8)
	q = cv2.dilate(q, np.ones((3, 3)))
	m2 = m & ~q
	n, lab, st, _ = cv2.connectedComponentsWithStats(m2, 8)
	m2 = (lab == np.argmax(st[1:, cv2.CC_STAT_AREA]) + 1).astype(np.uint8)
	a2 = a * m2
	a2 = np.where(q > 0, cv2.GaussianBlur(a2, (0, 0), 0.8), a2)
	return a, a2, int((m - m2).sum())

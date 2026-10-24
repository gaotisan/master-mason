"""EL BLOQUE DE CORRER NUEVO del peregrino de perfil (2026-10-22): arranque, correr,
salto corriendo, aterrizaje y parada, TODO de un solo video
(_fuentes/Elderly_mystic_running_and_leaping_20261021222919.mp4: empieza y acaba en
nuestro reposo, corre, salta una piedra y se para). Asi la tunica es la misma en todo
el bloque y en sus enganches con el reposo (antes cada animacion era de un video y al
saltar corriendo cambiaban los parches).

Parte de ../peregrino_salto_corriendo_v2/01_todo (extraer.py: sin fondo, 680x800,
suelo en la fila 770, centrados en la capucha) y deja, por animacion:
  <anim>/04_limpios/c_NNN.png   master (casilla 584x720 o, el salto, 680x800)
  <anim>/hoja/c_NNN.png         a media escala, limpios (tools/anim/hojas: limpiar
                                y pies), lo que va a la hoja
Como las de antes (peregrino_comun.txt): alto de pie 628 (el video da 606), suelo a
30 px del borde de abajo, el eje del tronco (la franja del 35-45 % de la figura) en
la misma columna que las hojas viejas (-2 px de hoja del centro).

  python montar.py
"""
import os
import sys

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
PROYECTO = os.path.normpath(os.path.join(AQUI, '..', '..', '..', '..'))
sys.path.insert(0, os.path.join(PROYECTO, 'tools', 'anim', 'hojas'))
import limpiar  # noqa: E402
import pies  # noqa: E402

FUENTE = os.path.join(AQUI, '..', 'peregrino_salto_corriendo_v2', '01_todo')
SUELO = 770            # fila del suelo en 01_todo
ESCALA = 628 / 606     # alto de pie de las hojas / del video
EJE = -4               # px master del centro de la casilla al eje del tronco
PIE = (46, 36, 33)
# fotogramas del video, incluidos; casilla master
ANIMS = {
	'arranque_correr': (30, 56, (584, 720)),
	'correr': (83, 103, (584, 720)),
	'salto_correr': (109, 160, (680, 800)),
	'aterrizaje_correr': (161, 210, (584, 720)),
	'parada_correr': (167, 215, (584, 720)),
}


def eje(a):
	ys = np.nonzero((a > 128).any(1))[0]
	top, bot = ys.min(), ys.max()
	h = bot - top
	banda = a[int(top + 0.35 * h):int(top + 0.45 * h)] > 128
	return np.nonzero(banda)[1].mean()


def master(k, casilla):
	f = cv2.imread(os.path.join(FUENTE, 'c_%03d.png' % k), cv2.IMREAD_UNCHANGED)
	f = cv2.cvtColor(f, cv2.COLOR_BGRA2RGBA)
	# escala sobre el punto del suelo bajo el centro
	M = np.float32([[ESCALA, 0, 340 * (1 - ESCALA)], [0, ESCALA, SUELO * (1 - ESCALA)]])
	f = cv2.warpAffine(f, M, (680, 800), flags=cv2.INTER_CUBIC, borderValue=(0, 0, 0, 0))
	# eje del tronco a su columna
	dx = (340 + EJE) - eje(f[..., 3])
	M = np.float32([[1, 0, dx], [0, 1, 0]])
	f = cv2.warpAffine(f, M, (680, 800), flags=cv2.INTER_LINEAR, borderValue=(0, 0, 0, 0))
	W, H = casilla
	x0 = 340 - W // 2
	y0 = (SUELO + 30) - H
	f = f[y0:y0 + H, x0:x0 + W]
	# restos de las piedras pegados al pie (la de correr 0): al adelgazar la silueta se
	# separan del cuerpo; fuera lo que se separa cerca del suelo
	sol = (f[..., 3] > 128).astype(np.uint8)
	e = cv2.erode(sol, np.ones((5, 5), np.uint8))
	n, l, st, _ = cv2.connectedComponentsWithStats(e, 8)
	if n > 2:
		mayor = 1 + int(np.argmax(st[1:, 4]))
		for i in range(1, n):
			if i != mayor and st[i, 4] > 60 and st[i, 1] > H * 0.7:
				resto = cv2.dilate((l == i).astype(np.uint8), np.ones((9, 9), np.uint8)) > 0
				cuerpo = cv2.dilate((l == mayor).astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
				f[resto & ~cuerpo] = 0
	f[f[..., 3] == 0] = 0
	return f


def main():
	limpiar.escala(2)      # en master; la hoja se limpia a su escala (1)
	pies.reglas({'forma': True})
	for anim, (a, b, casilla) in ANIMS.items():
		d4 = os.path.join(AQUI, anim, '04_limpios')
		dh = os.path.join(AQUI, anim, 'hoja')
		os.makedirs(d4, exist_ok=True)
		os.makedirs(dh, exist_ok=True)
		for i, k in enumerate(range(a, b + 1)):
			m = master(k, casilla)
			cv2.imwrite(os.path.join(d4, 'c_%03d.png' % i), cv2.cvtColor(m, cv2.COLOR_RGBA2BGRA))
			h = cv2.resize(m, (casilla[0] // 2, casilla[1] // 2), interpolation=cv2.INTER_AREA)
			limpiar.escala(1)
			pies.escala(1)
			h, _, _, _ = limpiar.limpiar(h)
			h, _ = pies.pintar(h, PIE, libre=True)
			cv2.imwrite(os.path.join(dh, 'c_%03d.png' % i), cv2.cvtColor(h, cv2.COLOR_RGBA2BGRA))
		print('%-18s video %d-%d  %d fotogramas  casilla %s' % (anim, a, b, b - a + 1, casilla))


if __name__ == '__main__':
	main()

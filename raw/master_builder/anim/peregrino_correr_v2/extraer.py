"""Saca del video los fotogramas del peregrino sin fondo, en la casilla master del
salto corriendo (680x800, el suelo a 30 px del borde de abajo) y centrados en la
capucha (la camara de Veo va y viene; la capucha es lo que menos se mueve).

Croma: fuera lo verde (tambien la sombra, verde oscuro). El peregrino es la pieza
grande mas alta (la de la capucha): las piedras sueltas se quedan fuera.

  python extraer.py <video> <carpeta_salida> [desde hasta]
"""
import os
import sys

import cv2
import numpy as np

W, H, MARGEN_SUELO = 680, 800, 30


def personaje(f):
	g = f.astype(np.int32)
	verde = (g[..., 1] > g[..., 2] + 25) & (g[..., 1] > g[..., 0] + 25)
	n, l, st, _ = cv2.connectedComponentsWithStats((~verde).astype(np.uint8), 8)
	i = min([j for j in range(1, n) if st[j, 4] > 3000], key=lambda j: st[j, 1])
	al = (l == i).astype(np.float32)
	d = np.clip((np.minimum(g[..., 1] - g[..., 2], g[..., 1] - g[..., 0]) - 25) / 40.0, 0, 1)
	borde = cv2.dilate(al, np.ones((3, 3))) - al
	return np.where(borde > 0, 1 - d, al), st[i]


def main():
	video, salida = sys.argv[1], sys.argv[2]
	v = cv2.VideoCapture(video)
	n = int(v.get(7))
	desde, hasta = (int(sys.argv[3]), int(sys.argv[4])) if len(sys.argv) > 4 else (0, n - 1)
	os.makedirs(salida, exist_ok=True)
	# el suelo: lo mas bajo de los pies en los fotogramas de pie (primero y ultimo)
	suelo = 0
	for k in (0, n - 1):
		v.set(1, k)
		_, f = v.read()
		_, st = personaje(f)
		suelo = max(suelo, st[1] + st[3])
	for k in range(desde, hasta + 1):
		v.set(1, k)
		ok, f = v.read()
		if not ok:
			break
		a, st = personaje(f)
		ys, xs = np.nonzero(a > 0.5)
		cx = int(xs[ys < ys.min() + 60].mean())
		out = np.zeros((H, W, 4), np.uint8)
		x0, y0 = cx - W // 2, suelo + MARGEN_SUELO - H
		sx0, sy0 = max(x0, 0), max(y0, 0)
		sx1, sy1 = min(x0 + W, f.shape[1]), min(y0 + H, f.shape[0])
		out[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0, :3] = cv2.cvtColor(f, cv2.COLOR_BGR2RGB)[sy0:sy1, sx0:sx1]
		out[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0, 3] = (a[sy0:sy1, sx0:sx1] * 255).astype(np.uint8)
		out[out[..., 3] == 0] = 0
		cv2.imwrite(os.path.join(salida, 'c_%03d.png' % k), cv2.cvtColor(out, cv2.COLOR_RGBA2BGRA))
	print(salida, desde, '-', hasta, 'suelo', suelo)


if __name__ == '__main__':
	main()

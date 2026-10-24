"""Cierra GRIETAS y huecos pequenos (y repasa el borde de la garra) en la zona de
arriba de una animacion: la capucha y la garra de sacar / guardar el baston de
espaldas (2026-10-21) tenian rayas transparentes que dejaban ver el fondo y huecos
junto a la base de la garra, del repintado del baston.

  cierre: lo transparente mas estrecho que CIERRE px rodeado de personaje, y los
  huecos encerrados de hasta HUECO_MAX px (el interior de la garra y lo de entre sus
  puntas, mayores, no), con el color de alrededor (inpaint).
  garra: los dientes oscuros sueltos de su contorno fuera y el borde un pelo suave.

  python tools/anim/hojas/grietas.py <tres> <animacion> [--alto 0.55]
  (--alto: la parte de arriba del fotograma que se toca)
"""
import argparse
import os
import sys

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hoja import Hoja  # noqa: E402

CIERRE = 9          # px: grietas y huecos mas estrechos que esto se cierran
HUECO_MAX = 900     # px: huecos encerrados mayores no se tocan (dentro de la garra)


def madera(f):
	x = f.astype(np.float32)
	rgb = x[..., :3]
	mx, mn = rgb.max(-1), rgb.min(-1)
	sat = (mx - mn) / np.maximum(mx, 1)
	return (x[..., 3] > 60) & (rgb[..., 0] > rgb[..., 2] + 12) & (sat > 0.18) & (mx > 45)


def arreglar(f, zona):
	"""zona: mascara de donde se puede tocar (capucha y garra)."""
	x = f.astype(np.float32)
	a = x[..., 3]
	sol = (a > 128).astype(np.uint8)
	# 1) grietas y huecos pequenos: cierre morfologico + huecos encerrados pequenos
	cerr = cv2.morphologyEx(sol, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (CIERRE, CIERRE)))
	n, l, st, _ = cv2.connectedComponentsWithStats(1 - sol, 4)
	H, W = sol.shape
	enc = np.zeros(sol.shape, bool)
	for i in range(1, n):
		xx, yy, ww, hh, area = st[i]
		if area <= HUECO_MAX and xx > 0 and yy > 0 and xx + ww < W and yy + hh < H:
			enc |= l == i
	tapar = ((cerr > 0) | enc) & (sol == 0) & zona
	# no tapar lo que ya es fondo de verdad junto al contorno exterior: el cierre solo
	# vale si el pixel esta rodeado (lo tapado debe tener personaje a varios lados)
	out = x.copy()
	if tapar.any():
		rgb8 = np.clip(x[..., :3], 0, 255).astype(np.uint8)
		col = cv2.inpaint(rgb8, tapar.astype(np.uint8) * 255, 5, cv2.INPAINT_TELEA).astype(np.float32)
		out[..., :3][tapar] = col[tapar]
		out[..., 3][tapar] = 255
	# 2) el borde de la garra: dientes oscuros sueltos del contorno fuera, borde suave
	m = madera(out.astype(np.uint8)) & zona
	if m.any():
		mm = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
		cerca = cv2.dilate(mm, np.ones((7, 7), np.uint8)) > 0
		lum = out[..., :3].mean(-1)
		med = cv2.medianBlur(np.clip(out[..., :3], 0, 255).astype(np.uint8), 7).astype(np.float32)
		fuera = (out[..., 3] < 5).astype(np.uint8)
		borde = (cv2.distanceTransform(1 - fuera, cv2.DIST_L2, 3) <= 3) & (out[..., 3] > 0) & cerca & ~(cv2.dilate(((x[..., 3] > 128) & ~cerca).astype(np.uint8), np.ones((3, 3), np.uint8)) > 0)
		diente = borde & (lum < med.mean(-1) - 30)
		out[..., 3][diente] = 0
		# borde suave: el alfa de la garra, un pelo difuminado en su anillo
		al = out[..., 3]
		suave = cv2.GaussianBlur(al, (0, 0), 0.8)
		anillo = cerca & (cv2.distanceTransform((al < 5).astype(np.uint8) ^ 1, cv2.DIST_L2, 3) <= 2)
		al[anillo] = np.minimum(al[anillo], suave[anillo])
	out[out[..., 3] == 0] = 0
	return np.clip(out, 0, 255).round().astype(np.uint8)


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument('tres')
	ap.add_argument('anim')
	ap.add_argument('--alto', type=float, default=0.55)
	args = ap.parse_args()
	h = Hoja(args.tres)
	ids = h.animaciones[args.anim][0]
	nuevos = {}
	for c in ids:
		f = h.fotograma(c)
		zona = np.zeros(f.shape[:2], bool)
		zona[:int(f.shape[0] * args.alto)] = True
		nuevos[c] = arreglar(f, zona)
	tex = h.casillas[ids[0]][0]
	carpeta = os.path.dirname(h.ext[tex])
	h.reempaquetar(tex, nuevos, carpeta)
	h.escribir_tres(args.tres, carpeta)
	print('escrito', h.ext[tex], len(ids), 'fotogramas')


if __name__ == '__main__':
	main()

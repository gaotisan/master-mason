"""Quita los puntitos oscuros del CONTORNO EXTERIOR de la capucha (de frente sobre todo;
2026-10-21: la hoja frontal escalada los marcaba en el borde). Solo el anillo de fuera
(a BORDE px de lo transparente): la abertura oscura alrededor de la cara es legitima y
no se toca. Las manchas del anillo mucho mas oscuras que la capucha de al lado (su
color extendido desde dentro, sin mezclar el fondo) y PEQUENAS (hasta MANCHA px)
toman ese color: el ribete oscuro de la abertura llega al contorno por los lados y es
una banda larga, no se toca.

  python tools/anim/hojas/borde_capucha.py <tres> <animacion> [<animacion>...] [--prueba carpeta]
"""
import argparse
import os
import sys

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hoja import Hoja  # noqa: E402
from capucha import capucha  # noqa: E402
from limpiar import rellenar  # noqa: E402

BORDE = 9        # px desde lo transparente
OSCURO = 18      # cuanto mas oscuro que la capucha de al lado
MANCHA = 200     # px: las manchas mayores son el ribete de la abertura


def arreglar(f):
	m = capucha(f)
	if m.sum() < 500:
		return f, 0
	x = f.astype(np.float32)
	a = x[..., 3]
	fuera = (a < 20).astype(np.uint8)
	anillo = (cv2.distanceTransform(1 - fuera, cv2.DIST_L2, 3) <= BORDE) & (a > 0)
	zona = anillo & (cv2.dilate(m.astype(np.uint8), np.ones((11, 11), np.uint8)) > 0)
	# el color de la capucha extendido desde su interior (sin el anillo ni el fondo)
	dentro = m & ~anillo
	ref = rellenar(x[..., :3], dentro.astype(np.float32))
	oscuro = zona & (x[..., :3].mean(-1) < ref.mean(-1) - OSCURO)
	n, l, st, _ = cv2.connectedComponentsWithStats(oscuro.astype(np.uint8), 8)
	peq = st[:, 4] <= MANCHA
	peq[0] = False
	oscuro = peq[l]
	oscuro = (cv2.dilate(oscuro.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0) & zona
	x[..., :3][oscuro] = ref[oscuro]
	return np.clip(x, 0, 255).round().astype(np.uint8), int(oscuro.sum())


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument('tres')
	ap.add_argument('anims', nargs='+')
	ap.add_argument('--prueba')
	args = ap.parse_args()
	h = Hoja(args.tres)
	for anim in args.anims:
		ids = h.animaciones[anim][0]
		nuevos, total = {}, 0
		for c in ids:
			nuevos[c], n = arreglar(h.fotograma(c))
			total += n
		print('%s: %d px del borde de la capucha' % (anim, total), flush=True)
		if args.prueba:
			os.makedirs(args.prueba, exist_ok=True)
			for k in range(0, len(ids), max(1, len(ids) // 6)):
				fila = []
				for im in (h.fotograma(ids[k]), nuevos[ids[k]]):
					c = im[200:700, 250:750].astype(np.float32); al = c[..., 3:] / 255
					fila.append((c[..., :3] * al + np.array([60, 160, 60]) * (1 - al)).astype(np.uint8))
				cv2.imwrite(os.path.join(args.prueba, '%s_%03d.png' % (anim, k)), np.hstack(fila)[..., ::-1])
			continue
		tex = h.casillas[ids[0]][0]
		carpeta = os.path.dirname(h.ext[tex])
		h.reempaquetar(tex, nuevos, carpeta)
	if not args.prueba:
		h.escribir_tres(args.tres, carpeta)
		print('escrito', args.tres)


if __name__ == '__main__':
	main()

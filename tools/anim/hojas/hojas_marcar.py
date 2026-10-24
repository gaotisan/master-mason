"""Hojas para que el usuario MARQUE EN ROJO lo que vea mal: por animacion, todos sus
fotogramas en rejilla, a tamano real (1 px = 1 px de la hoja), sobre gris, con el
nombre y el numero de cada uno. Junto a cada PNG, un .json con la casilla de cada
fotograma en la imagen, para leer luego las marcas (leer_marcas.py) y saber a que
fotograma y a que pixeles corresponden.

  python tools/anim/hojas/hojas_marcar.py <tres> <carpeta_salida> [--agrupar prefijo,prefijo]
  --agrupar: las animaciones que empiezan por esos prefijos van juntas en una hoja
  (las transiciones cortas del frontal: pt_, ps_).
  --escala 0.5: a la mitad (las del frontal escalado pesan mucho y tardan en abrir);
  el .json lleva la escala para leer las marcas.
"""
import argparse
import json
import os
import sys

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hoja import Hoja  # noqa: E402

COLUMNAS = 8
FONDO = 128
RENGLON = 34
HUECO = 10


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument('tres')
	ap.add_argument('salida')
	ap.add_argument('--agrupar', default='')
	ap.add_argument('--escala', type=float, default=1.0)
	ap.add_argument('--solo', default='', help='solo estas animaciones (separadas por comas)')
	args = ap.parse_args()
	h = Hoja(args.tres)
	prefijos = [p for p in args.agrupar.split(',') if p]
	grupos = {}
	solo = [x for x in args.solo.split(',') if x]
	for anim, (ids, _, _) in h.animaciones.items():
		if solo and anim not in solo:
			continue
		g = next((p.rstrip('_') for p in prefijos if anim.startswith(p)), anim)
		grupos.setdefault(g, []).extend((anim, k, c) for k, c in enumerate(ids))
	os.makedirs(args.salida, exist_ok=True)
	for g, fots in grupos.items():
		# la caja comun de lo dibujado (en coordenadas del fotograma entero)
		caja = None
		for _, _, c in fots:
			_, (x, y, w, hh), (ml, mt, _, _) = h.casillas[c]
			b = (ml, mt, ml + w, mt + hh)
			caja = b if caja is None else (min(caja[0], b[0]), min(caja[1], b[1]), max(caja[2], b[2]), max(caja[3], b[3]))
		x0, y0, x1, y1 = caja[0] - 8, caja[1] - 8, caja[2] + 8, caja[3] + 8
		cw, ch = x1 - x0, y1 - y0
		filas = (len(fots) + COLUMNAS - 1) // COLUMNAS
		W, H = COLUMNAS * (cw + HUECO), filas * (ch + RENGLON + HUECO)
		img = np.full((H, W, 3), FONDO, np.uint8)
		mapa = []
		for i, (anim, k, c) in enumerate(fots):
			f = h.fotograma(c).astype(np.float32)
			X = (i % COLUMNAS) * (cw + HUECO)
			Y = (i // COLUMNAS) * (ch + RENGLON + HUECO) + RENGLON
			sub = np.zeros((ch, cw, 4), np.float32)
			fy0, fx0 = max(y0, 0), max(x0, 0)
			fy1, fx1 = min(y1, f.shape[0]), min(x1, f.shape[1])
			sub[fy0 - y0:fy1 - y0, fx0 - x0:fx1 - x0] = f[fy0:fy1, fx0:fx1]
			a = sub[..., 3:] / 255
			img[Y:Y + ch, X:X + cw] = (sub[..., :3] * a + FONDO * (1 - a)).round().astype(np.uint8)
			cv2.putText(img, '%s %d' % (anim, k), (X + 4, Y - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.75 / min(args.escala, 1.0) ** 0.5, (0, 0, 0), 2)
			mapa.append({'anim': anim, 'fotograma': k, 'casilla': c, 'x': X, 'y': Y, 'w': cw, 'h': ch, 'origen': [x0, y0]})
		nombre = os.path.join(args.salida, g)
		if args.escala != 1.0:
			img = cv2.resize(img, None, fx=args.escala, fy=args.escala, interpolation=cv2.INTER_AREA if args.escala < 1 else cv2.INTER_NEAREST)
		cv2.imwrite(nombre + '.png', img[..., ::-1])
		json.dump({'tres': args.tres, 'escala': args.escala, 'fotogramas': mapa}, open(nombre + '.json', 'w'), indent=1)
		print('%-28s %3d fotogramas  %dx%d' % (g, len(fots), W, H))


if __name__ == '__main__':
	main()

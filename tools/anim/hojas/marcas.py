"""Las MARCAS del usuario: cuadros rojos pintados sobre las hojas para marcar
(hojas_marcar.py) donde algo esta mal (2026-10-22: talones de piel que la regla de
pies no separa de la tela, porque tienen su mismo color).

  leer:    python tools/anim/hojas/marcas.py leer <hoja_marcada.png> [<ficha_marcas.json>]
           busca el rojo puro de la imagen (la del .json de al lado dice donde esta
           cada fotograma), saca la caja de cada marca, la pasa a coordenadas de la
           casilla y la guarda (se suma a lo que ya hubiera de esa animacion: se puede
           marcar por tandas). Por defecto en personajes/peregrino_perfil_marcas.json.
  aplicar: desde procesar.py (pasada "marcas"): dentro de cada caja marcada, lo fino
           de la silueta (piernas, talones) que no es oscuro y las caras del dibujo
           que caen casi enteras en la caja y no son malva (la tunica) se pintan como
           el pie (pies.pintar_mascara).
"""
import json
import os
import sys

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hoja import Hoja, PROYECTO  # noqa: E402
import pies  # noqa: E402

FICHA = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'personajes', 'peregrino_perfil_marcas.json')
OSCURO = 55          # lo mas oscuro que esto ya es pierna o tela oscura: se deja
GRUESO = 11          # lo que no cabe en este disco es fino (pierna, talon), no tunica


def leer(png, ficha=FICHA):
	img = cv2.imread(png)
	mapa = json.load(open(os.path.splitext(png)[0] + '.json', encoding='utf-8'))
	e = mapa.get('escala', 1.0)
	h = Hoja(mapa['tres'])
	b, g, r = img[..., 0].astype(int), img[..., 1].astype(int), img[..., 2].astype(int)
	rojo = ((r > 200) & (g < 70) & (b < 70)).astype(np.uint8)
	rojo = cv2.dilate(rojo, np.ones((3, 3), np.uint8))
	n, l, st, _ = cv2.connectedComponentsWithStats(rojo, 8)
	marcas = json.load(open(ficha, encoding='utf-8')) if os.path.exists(ficha) else {}
	cuenta = 0
	for i in range(1, n):
		x, y, w, hh, area = st[i]
		if area < 8:
			continue
		cx, cy = x + w / 2, y + hh / 2
		for f in mapa['fotogramas']:
			X, Y, W, H = f['x'] * e, f['y'] * e, f['w'] * e, f['h'] * e
			if X <= cx < X + W and Y - 40 <= cy < Y + H:
				ox, oy = f['origen']
				_, _, (ml, mt, _, _) = h.casillas[f['casilla']]
				x0 = (x - X) / e + ox - ml
				y0 = (y - Y) / e + oy - mt
				x1 = (x + w - X) / e + ox - ml
				y1 = (y + hh - Y) / e + oy - mt
				lista = marcas.setdefault(f['anim'], {}).setdefault(str(f['fotograma']), [])
				caja = [int(np.floor(x0)), int(np.floor(y0)), int(np.ceil(x1)), int(np.ceil(y1))]
				if caja not in lista:
					lista.append(caja)
					cuenta += 1
				break
	json.dump(marcas, open(ficha, 'w', encoding='utf-8'), indent=1)
	print('%s: %d marcas nuevas -> %s' % (os.path.basename(png), cuenta, ficha))


def aplicar(im, cajas, pintar):
	"""im: la casilla RGBA; cajas: [[x0, y0, x1, y1], ...] en coordenadas de la casilla;
	pintar(im, mascara) -> im con la mascara pintada como el pie."""
	if not cajas:
		return im
	f = im.astype(np.float32)
	a, rgb = f[..., 3], f[..., :3]
	L = rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114
	m = np.zeros(a.shape, bool)
	# solo lo fino de la silueta (piernas, talones): la tunica es ancha y sobrevive a
	# una apertura grande; pintarla dejaba parches cuadrados
	sil = (a > 20).astype(np.uint8)
	ancho = cv2.morphologyEx(sil, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (GRUESO, GRUESO)))
	ancho = cv2.dilate(ancho, np.ones((3, 3), np.uint8)) > 0
	fino = (sil > 0) & ~ancho
	# y las caras del dibujo que caen casi enteras en la caja y no son malva (la pierna
	# que asoma entre los paneles de la tunica, de frente en el giro)
	et = pies.facetas(im)
	lab = cv2.cvtColor(np.ascontiguousarray(im[..., :3]), cv2.COLOR_RGB2LAB).astype(np.float32)
	for x0, y0, x1, y1 in cajas:
		x0, y0 = max(x0, 0), max(y0, 0)
		zona = np.zeros(a.shape, bool)
		zona[y0:y1, x0:x1] = True
		m |= zona & fino & (L > OSCURO)
		for f in np.unique(et[zona & (et >= 0)]):
			q = et == f
			dentro = (q & zona).sum()
			if dentro < 0.6 * q.sum() or dentro < 4:
				continue
			A, B = lab[..., 1][q].mean() - 128, lab[..., 2][q].mean() - 128
			if np.degrees(np.arctan2(B, A)) > pies.HUE_MALVA:
				m |= q
	m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8)) > 0
	m &= a > 20
	# el borde suavizado entre caras, que quedaba como un aro claro
	for _ in range(2):
		vec = cv2.filter2D(m.astype(np.float32), -1, np.ones((3, 3), np.float32)) - m
		m |= ~m & (a > 20) & (vec >= 4)
	return pintar(im, m)


if __name__ == '__main__':
	if sys.argv[1] == 'leer':
		leer(sys.argv[2], *(sys.argv[3:4] or []))

"""Rehace la CAPUCHA de espaldas donde falta, con la de un fotograma bueno de la
misma animacion puesta DETRAS de lo que haya delante (la garra, la mano).

Por que (2026-10-21, sacar / guardar el baston de espaldas): al repintar el baston
con la garra de cuerna (peregrino_guardar_baston_espalda_a/arreglar.py) se borro el
palo del video y con el el trozo de capucha que tapaba: la capucha salia cortada en
vertical junto a la garra y entre sus dedos se veia el fondo. De espaldas la cabeza
casi no se mueve: se coge la capucha de un fotograma donde esta entera (REF), se le
quitan las rayitas oscuras, se busca en cada fotograma donde encaja su mitad
izquierda (la derecha la tapa la garra; la cabeza se va corriendo hasta 15 px) y se
pone debajo de todo lo que no es capucha. La capucha del fotograma se sustituye
(de paso se van los puntitos oscuros del borde).

La capucha: lo gris azulado poco saturado, la pieza MAS ALTA (de espaldas el parche
en V de la tunica es mayor). Si el arreglo se sale de la casilla del atlas, se
rehace la textura (Hoja.reempaquetar): solo vale para texturas de una animacion.

  python tools/anim/hojas/capucha.py <tres> <animacion> <desde> <hasta> <ref> [--prueba carpeta]
  (desde..hasta, incluidos: los fotogramas a arreglar; --prueba: no escribe, deja
  imagenes antes / despues)
"""
import argparse
import os
import sys

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hoja import Hoja  # noqa: E402

BUSCA = 40          # px que se busca la capucha alrededor de donde esta en la referencia


def capucha(f):
	x = f.astype(np.float32)
	rgb, a = x[..., :3], x[..., 3]
	mx, mn = rgb.max(-1), rgb.min(-1)
	sat = (mx - mn) / np.maximum(mx, 1)
	m = (a > 128) & (sat < 0.22) & (rgb[..., 2] >= rgb[..., 0] - 4) & (mx > 70)
	m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
	n, l, st, _ = cv2.connectedComponentsWithStats(m, 8)
	if n < 2:
		return m > 0
	grandes = [i for i in range(1, n) if st[i, 4] > 0.15 * st[1:, 4].max()]
	return l == min(grandes, key=lambda i: st[i, 1])


def limpiar_capucha(im, m):
	x = im.astype(np.float32)
	lum = x[..., :3].mean(-1)
	z = cv2.dilate(m.astype(np.uint8), np.ones((9, 9), np.uint8)) > 0
	med = cv2.medianBlur(im[..., :3], 15).astype(np.float32)
	oscuro = z & (x[..., 3] > 40) & (lum < med.mean(-1) - 18)
	oscuro = (cv2.dilate(oscuro.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0) & z
	x[..., :3][oscuro] = med[oscuro]
	return x.astype(np.uint8)


class Capucha:
	def __init__(self, ref):
		m = capucha(ref)
		self.ref = limpiar_capucha(ref, m)
		self.m = m
		ys, xs = np.nonzero(m)
		self.cy0, self.cy1, self.cx0, self.cx1 = ys.min(), ys.max(), xs.min(), xs.max()
		lleno = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (15, 15)))
		self.zona = cv2.dilate(lleno, np.ones((7, 7), np.uint8)) > 0
		self.zona[self.cy1 - 10:] = False      # no bajar a los hombros

	def alinear(self, f):
		def gris(x):
			x = x.astype(np.float32)
			return x[..., :3].mean(-1) * x[..., 3] / 255
		izq = slice(self.cx0, self.cx0 + (self.cx1 - self.cx0) // 2)
		m = np.zeros(self.m.shape, np.uint8)
		m[self.cy0 - 6:self.cy1 - 10, izq] = 1
		m = cv2.dilate(self.m.astype(np.uint8), np.ones((9, 9), np.uint8)) & m
		ys, xs = np.nonzero(m)
		ty0, ty1, tx0, tx1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
		pm = m[ty0:ty1, tx0:tx1].astype(np.float32)
		r = cv2.matchTemplate(gris(f)[ty0 - BUSCA:ty1 + BUSCA, tx0 - BUSCA:tx1 + BUSCA], gris(self.ref)[ty0:ty1, tx0:tx1], cv2.TM_SQDIFF, mask=pm)
		_, _, mn, _ = cv2.minMaxLoc(r)
		return mn[1] - BUSCA, mn[0] - BUSCA

	def arreglar(self, f):
		dy, dx = self.alinear(f)
		h, w = f.shape[:2]
		M = np.float32([[1, 0, dx], [0, 1, dy]])
		rx = cv2.warpAffine(self.ref, M, (w, h), flags=cv2.INTER_LINEAR, borderValue=(0, 0, 0, 0)).astype(np.float32)
		z = (cv2.warpAffine(self.zona.astype(np.uint8), M, (w, h), flags=cv2.INTER_NEAREST) > 0) & (rx[..., 3] > 0)
		fx = f.astype(np.float32)
		delante = (fx[..., 3] > 0) & ~(cv2.dilate(capucha(f).astype(np.uint8), np.ones((5, 5), np.uint8)) > 0)
		fa, ra = fx[..., 3:] / 255, rx[..., 3:] / 255
		enc = (delante & z)[..., None]
		col = np.where(enc, fx[..., :3] * fa + rx[..., :3] * ra * (1 - fa), rx[..., :3] * ra)
		al = np.where(enc[..., 0], np.maximum(fx[..., 3], rx[..., 3]), rx[..., 3])
		out = fx.copy()
		out[..., :3] = np.where(z[..., None], col / np.maximum(al[..., None] / 255, 1e-3), fx[..., :3])
		out[..., 3] = np.where(z, al, fx[..., 3])
		return np.clip(out, 0, 255).round().astype(np.uint8), (dy, dx)


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument('tres')
	ap.add_argument('anim')
	ap.add_argument('desde', type=int)
	ap.add_argument('hasta', type=int)
	ap.add_argument('ref', type=int)
	ap.add_argument('--prueba')
	args = ap.parse_args()
	h = Hoja(args.tres)
	ids = h.animaciones[args.anim][0]
	fr = [h.fotograma(c) for c in ids]
	cap = Capucha(fr[args.ref])
	nuevos = {}
	for k in range(args.desde, args.hasta + 1):
		nuevos[ids[k]], d = cap.arreglar(fr[k])
		print('%d desplazamiento %d,%d' % ((k,) + d), flush=True)
	if args.prueba:
		os.makedirs(args.prueba, exist_ok=True)
		for k in range(args.desde, args.hasta + 1, max(1, (args.hasta - args.desde) // 8)):
			fila = []
			for im in (fr[k], nuevos[ids[k]]):
				c = im[cap.cy0 - 40:cap.cy1 + 60, cap.cx0 - 60:cap.cx1 + 260].astype(np.float32)
				a = c[..., 3:] / 255
				fila.append((c[..., :3] * a + 128 * (1 - a)).astype(np.uint8))
			cv2.imwrite(os.path.join(args.prueba, '%s_%03d.png' % (args.anim, k)), np.hstack(fila)[..., ::-1])
		return
	tex = h.casillas[ids[0]][0]
	carpeta = os.path.dirname(h.ext[tex])
	h.reempaquetar(tex, nuevos, carpeta)
	h.escribir_tres(args.tres, carpeta)
	print('escrito', h.ext[tex], 'y', args.tres)


if __name__ == '__main__':
	main()

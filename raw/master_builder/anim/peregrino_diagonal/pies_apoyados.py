"""Donde estan los pies en cada fotograma montado: los dos trozos de pierna que
asoman bajo la tunica, su fila mas baja respecto al suelo de la casilla (SUELO) y
su x. Un pie esta APOYADO si su fila mas baja esta en el suelo (a TOL px) y no se
mueve respecto al fotograma anterior."""
import importlib.util, os, sys, json
import cv2, numpy as np
from PIL import Image
AQUI = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('m', os.path.join(AQUI, 'montar.py'))
MON = importlib.util.module_from_spec(spec); spec.loader.exec_module(MON)
TOL = 6


def pies(rgba):
	al = (rgba[..., 3] > 128).astype(np.uint8)
	ys = np.nonzero(al.any(1))[0]
	top, yb = ys.min(), ys.max()
	h = yb - top
	disco = max(9, int(0.06 * h) | 1)
	tela = cv2.morphologyEx(al, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (disco * 2 + 1,) * 2))
	filas = np.arange(al.shape[0])[:, None]
	bajo = np.where(tela.any(0), (tela * filas).max(0), 0)[None, :]
	piernas = (al > 0) & (filas > bajo + 2) & (filas > top + 0.7 * h)
	n, lab, st, _ = cv2.connectedComponentsWithStats(piernas.astype(np.uint8), 8)
	# solo lo que llega cerca del suelo (las manos y el baculo, fuera)
	trozos = sorted([(st[i, 4], i) for i in range(1, n) if st[i, 4] > 30 and st[i, 1] + st[i, 3] > yb - 0.12 * h], reverse=True)[:2]
	out = []
	for _, i in trozos:
		yy, xx = np.nonzero(lab == i)
		fondo = yy.max()
		out.append((float(np.median(xx[yy > fondo - 8])), int(fondo)))
	return sorted(out)


if __name__ == '__main__':
	clave = sys.argv[1]; a, b = int(sys.argv[2]), int(sys.argv[3])
	for k in range(a, b):
		im = np.asarray(Image.open(os.path.join(AQUI, clave, 'c_%03d.png' % k)).convert('RGBA'))
		p = pies(im)
		print(k, '  '.join('x %4.0f bajo %+3d' % (x, y - MON.SUELO) for x, y in p))

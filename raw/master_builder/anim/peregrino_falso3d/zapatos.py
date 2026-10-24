"""LOS ZAPATOS DE BUFON (2026-10-22): corriendo hacia la camara (06) Veo alarga la punta
del zapato, fina y picuda. Por cada pie (lo que hay bajo el bajo de la tunica en la
franja de abajo, separado en piezas): la pierna es la columna donde el pie sube; la
punta no pasa de LARGO (fraccion del alto de la figura) desde ella y se redondea con
un circulo del grueso del zapato. En la casilla de montar.py (capucha-pies ~628 px).

  zapatos(rgba) -> rgba        (casilla RGBA uint8)
"""
import cv2
import numpy as np

FRANJA = 0.075     # la franja de abajo donde estan los zapatos (fraccion del alto)
LARGO = 0.055      # lo mas que va la punta desde la pierna (de perfil el pie da ~0,05)
ZAPATO = 0.035     # el grueso de la franja del zapato (fraccion del alto)
TUNICA = 41        # disco: lo que sobrevive a una apertura asi es tunica, no pie


def zapatos(rgba):
	a = rgba[..., 3]
	op = (a > 40).astype(np.uint8)
	ys = np.nonzero(op.any(1))[0]
	if not len(ys):
		return rgba
	top, pie = int(ys.min()), int(ys.max())
	alto = pie - top
	tela = cv2.morphologyEx(op, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (TUNICA, TUNICA)))
	tela = cv2.dilate(tela, np.ones((5, 5), np.uint8))
	zona = np.zeros(op.shape, bool)
	y0 = int(pie - FRANJA * alto)
	zona[y0:] = True
	pies = (op > 0) & zona & (tela == 0)
	n, l, st, _ = cv2.connectedComponentsWithStats(pies.astype(np.uint8), 8)
	quitar = np.zeros(op.shape, bool)
	largo = LARGO * alto
	for i in range(1, n):
		x, y, w, h, area = st[i]
		if area < 40 or w < largo:
			continue
		m = l == i
		# el zapato: las filas de abajo de la pieza; la pierna, justo encima (el tobillo)
		filas = np.nonzero(m.any(1))[0]
		suela = int(filas.max())
		grueso = int(ZAPATO * alto)
		banda = np.zeros(op.shape, bool)
		banda[suela - grueso:suela + 1] = True
		tobillo = m[suela - grueso - int(0.4 * grueso):suela - grueso]
		xs_p = np.nonzero(tobillo)[1]
		if not len(xs_p):
			continue
		cx = float(np.median(xs_p))
		zap = m & banda
		xz = np.nonzero(zap)[1]
		izq, der = cx - xz.min(), xz.max() - cx
		sentido = 1 if der >= izq else -1
		if max(izq, der) <= largo:
			continue
		lim = cx + sentido * largo
		col = int(round(min(max(lim, xz.min()), xz.max())))
		filas_col = np.nonzero(zap[:, col])[0]
		r = max(3.0, (filas_col.max() - filas_col.min() + 1) / 2.0) if len(filas_col) else 4.0
		cy = (filas_col.max() + filas_col.min()) / 2.0 if len(filas_col) else float(suela - r)
		yy, xx = np.mgrid[0:op.shape[0], 0:op.shape[1]]
		centro = lim - sentido * r
		mas_alla = (xx - centro) * sentido > 0
		fuera = ((xx - centro) ** 2 + (yy - cy) ** 2) > r * r
		quitar |= zap & mas_alla & fuera
	if not quitar.any():
		return rgba
	# lo que se quita y el canto semitransparente que lo rodeaba; el corte, suavizado
	out = rgba.copy()
	cerca = cv2.dilate(quitar.astype(np.uint8), np.ones((9, 9), np.uint8)) > 0
	al = np.where(quitar | (cerca & (a < 160)), 0, a).astype(np.float32)
	borde = cv2.dilate(cerca.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
	suave = cv2.GaussianBlur(al, (0, 0), 0.7)
	out[..., 3] = np.where(borde, np.minimum(al, suave), al).astype(np.uint8)
	n2, l2, st2, _ = cv2.connectedComponentsWithStats((out[..., 3] > 40).astype(np.uint8), 8)
	if n2 > 2:
		mayor = 1 + int(np.argmax(st2[1:, 4]))
		for i in range(1, n2):
			if i != mayor and st2[i, 4] < 200 and st2[i, 1] > y0 - 10:
				out[..., 3][l2 == i] = 0
	out[out[..., 3] == 0] = 0
	return out

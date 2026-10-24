"""Repinta la GARRA del baston (la cornamenta) en una animacion de la hoja con una
textura limpia: la busca en cada fotograma (posicion, giro y tamano, partiendo del
anterior) y pone la nueva encima de la vieja.

Por que (2026-10-21): la garra salia de una textura de 98 px de ancho
(baston_espalda_master.png); al escalar las hojas a 1,5x se estiro y la IA la
relleno a pinceladas. La nueva es esa misma textura ampliada x3 con Real-ESRGAN
(x4plus-anime) y limpia; la misma que usara el juego para el baston a la espalda,
para que andando, parado, sacando y guardando sea la misma garra.

Composicion, pixel a pixel dentro de la garra nueva:
  - la mano (piel) siempre delante (los dedos que la cogen);
  - lo que en el fotograma es madera o fondo: la garra nueva;
  - capucha o tunica: con DELANTE (de espaldas: la garra va por delante del cuerpo)
    la garra nueva; si no (de frente: asoma detras de la cabeza), se queda lo del
    fotograma (la capucha tapa la garra).
Los restos de la garra vieja que sobresalen de la nueva: sobre fondo, fuera
(transparente); sobre la capucha, color de capucha; sobre la tunica se quedan (no
se distingue la madera de la tela).
Si en un fotograma el encaje es malo (error, 1 - correlacion, mayor que MALO) o la
garra no esta (fuera de cuadro), se deja como esta y se avisa.

  python tools/anim/hojas/garra.py <tres> <animacion> <textura_garra.png> [--delante] [--prueba carpeta]
  --oculta --desde N --hasta M: de frente, la garra detras de la capucha (busca por la madera
  fina: la tunica es del mismo marron) solo en esos fotogramas (el baston en la mano no).
"""
import argparse
import os
import sys

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hoja import Hoja  # noqa: E402

FILAS_GARRA = 300        # filas de arriba de la textura que son la garra (x3)
ESCALAS = (0.38, 0.41, 0.44, 0.47, 0.50, 0.53, 0.56)
MALO = 0.5         # error (1 - correlacion) por encima del cual el encaje no vale
BUSCA = 70               # px alrededor de donde estaba en el fotograma anterior


class Garra:
	def __init__(self, ruta):
		# RGBA, como las hojas (cv2 lee BGRA)
		self.tex = cv2.cvtColor(cv2.imread(ruta, cv2.IMREAD_UNCHANGED), cv2.COLOR_BGRA2RGBA)[:FILAS_GARRA]
		self._cache = {}

	def plantilla(self, escala, giro):
		clave = (round(escala, 3), round(giro, 2))
		if clave not in self._cache:
			g = cv2.resize(self.tex, None, fx=escala, fy=escala, interpolation=cv2.INTER_AREA)
			h, w = g.shape[:2]
			d = int(np.ceil(np.hypot(h, w))) + 4
			lienzo = np.zeros((d, d, 4), np.uint8)
			lienzo[(d - h) // 2:(d - h) // 2 + h, (d - w) // 2:(d - w) // 2 + w] = g
			M = cv2.getRotationMatrix2D((d / 2, d / 2), giro, 1.0)
			r = cv2.warpAffine(lienzo, M, (d, d), flags=cv2.INTER_LINEAR, borderValue=(0, 0, 0, 0))
			self._cache[clave] = r
		return self._cache[clave]


def gris(x):
	x = x.astype(np.float32)
	return x[..., :3].mean(-1) * x[..., 3] / 255


def buscar(garra, G, escalas, giros, caja, margen=220):
	"""Mejor (error, escala, giro, cx, cy). La imagen lleva un MARGEN vacio alrededor:
	con el baston en alto la garra roza o se sale por arriba del fotograma."""
	Gp = cv2.copyMakeBorder(G, margen, margen, margen, margen, cv2.BORDER_CONSTANT, value=0)
	x0, y0, x1, y1 = caja
	x0, y0 = max(int(x0) + margen, 0), max(int(y0) + margen, 0)
	x1, y1 = min(int(x1) + margen, Gp.shape[1]), min(int(y1) + margen, Gp.shape[0])
	zona = Gp[y0:y1, x0:x1]
	mejor = None
	for e in escalas:
		for g in giros:
			t = garra.plantilla(e, g)
			m = (t[..., 3] > 100).astype(np.float32)
			if t.shape[0] >= zona.shape[0] or t.shape[1] >= zona.shape[1]:
				continue
			# correlacion normalizada: la forma, no el brillo (con el baston en alto la
			# garra va a contraluz, mucho mas oscura que la plantilla)
			r = cv2.matchTemplate(zona, gris(t), cv2.TM_CCOEFF_NORMED, mask=m)
			# en zonas casi lisas la correlacion normalizada se dispara: fuera
			r[~np.isfinite(r) | (r > 1.0) | (r < -1.0)] = -1
			_, mx, _, loc = cv2.minMaxLoc(r)
			err = 1.0 - mx
			if mejor is None or err < mejor[0]:
				d = t.shape[0] / 2
				mejor = (err, e, g, x0 + loc[0] + d - margen, y0 + loc[1] + d - margen)
	return mejor


def buscar_madera(garra, f, escalas, giros, caja, margen=220):
	"""Como buscar, pero con la garra medio tapada (de frente asoma detras de la capucha):
	compara la silueta de la plantilla con lo que en el fotograma es madera; lo tapado
	solo resta, no confunde. Error = 1 - (madera cubierta / area de la plantilla) ajustado
	por lo que la plantilla pisa de fondo (si cae en vacio, no es ahi)."""
	_, capucha, madera = clases(f)
	# solo la madera FINA: la tunica es del mismo marron pero gruesa
	sol = (f[..., 3] > 128).astype(np.uint8)
	grueso = cv2.morphologyEx(sol, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (31, 31)))
	madera = madera & ~(cv2.dilate(grueso, np.ones((5, 5), np.uint8)) > 0)
	vacio = (f[..., 3] < 60).astype(np.float32)
	M = cv2.copyMakeBorder(madera.astype(np.float32), margen, margen, margen, margen, cv2.BORDER_CONSTANT, value=0)
	V = cv2.copyMakeBorder(vacio, margen, margen, margen, margen, cv2.BORDER_CONSTANT, value=1)
	x0, y0, x1, y1 = caja
	x0, y0 = max(int(x0) + margen, 0), max(int(y0) + margen, 0)
	x1, y1 = min(int(x1) + margen, M.shape[1]), min(int(y1) + margen, M.shape[0])
	zm, zv = M[y0:y1, x0:x1], V[y0:y1, x0:x1]
	mejor = None
	for e in escalas:
		for g in giros:
			t = garra.plantilla(e, g)
			m = (t[..., 3] > 100).astype(np.float32)
			if t.shape[0] >= zm.shape[0] or t.shape[1] >= zm.shape[1]:
				continue
			area = m.sum()
			bien = cv2.matchTemplate(zm, m, cv2.TM_CCORR)
			mal = cv2.matchTemplate(zv, m, cv2.TM_CCORR)
			r = (bien - 2.0 * mal) / area
			_, mx, _, loc = cv2.minMaxLoc(r)
			err = 1.0 - mx
			if mejor is None or err < mejor[0]:
				d = t.shape[0] / 2
				mejor = (err, e, g, x0 + loc[0] + d - margen, y0 + loc[1] + d - margen)
	return mejor


def clases(f):
	x = f.astype(np.float32)
	rgb, a = x[..., :3], x[..., 3]
	mx, mn = rgb.max(-1), rgb.min(-1)
	sat = (mx - mn) / np.maximum(mx, 1)
	lab = cv2.cvtColor(np.ascontiguousarray(f[..., :3]), cv2.COLOR_RGB2LAB).astype(np.float32)
	piel = (a > 60) & (lab[..., 1] - 128 > 9) & (lab[..., 0] > 120) & (rgb[..., 0] > rgb[..., 2] + 25)
	capucha = (a > 60) & (sat < 0.22) & (rgb[..., 2] >= rgb[..., 0] - 4) & (mx > 70)
	madera = (a > 60) & (rgb[..., 0] > rgb[..., 2] + 12) & (sat > 0.18) & ~piel
	return piel, capucha, madera


def componer(f, t, cx, cy, delante):
	h, w = f.shape[:2]
	d = t.shape[0]
	X, Y = int(round(cx - d / 2)), int(round(cy - d / 2))
	nueva = np.zeros((h, w, 4), np.float32)
	sx0, sy0 = max(-X, 0), max(-Y, 0)
	dx0, dy0 = max(X, 0), max(Y, 0)
	dx1, dy1 = min(X + d, w), min(Y + d, h)
	nueva[dy0:dy1, dx0:dx1] = t[sy0:sy0 + dy1 - dy0, sx0:sx0 + dx1 - dx0]
	na = nueva[..., 3] / 255
	nm = na > 0.02
	piel, capucha, madera = clases(f)
	fx = f.astype(np.float32)
	out = fx.copy()
	# restos de la vieja fuera de la nueva
	banda = (cv2.dilate(nm.astype(np.uint8), np.ones((17, 17), np.uint8)) > 0) & ~nm & madera
	if banda.any():
		vacio = (fx[..., 3] < 20).astype(np.float32)
		cerca_vacio = cv2.blur(vacio, (11, 11)) > 0.3
		cap_cerca = cv2.blur(capucha.astype(np.float32), (11, 11)) > 0.3
		quitar = banda & cerca_vacio
		out[quitar] = 0
		a_capucha = banda & ~quitar & cap_cerca
		if a_capucha.any():
			med = cv2.medianBlur(f[..., :3], 15).astype(np.float32)
			out[..., :3][a_capucha] = med[a_capucha]
	# la nueva: donde no hay mano, y (de espaldas) siempre / (de frente) solo sobre madera o fondo
	puede = nm & ~piel
	if not delante:
		puede &= madera | (fx[..., 3] < 128)
	a = (na * puede)[..., None]
	base_a = out[..., 3:] / 255
	col = nueva[..., :3] * a + out[..., :3] * base_a * (1 - a)
	al = a + base_a * (1 - a)
	out[..., :3] = np.where(al > 1e-3, col / np.maximum(al, 1e-3), out[..., :3])
	out[..., 3] = (al[..., 0] * 255)
	return np.clip(out, 0, 255).round().astype(np.uint8)


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument('tres')
	ap.add_argument('anim')
	ap.add_argument('textura')
	ap.add_argument('--delante', action='store_true')
	ap.add_argument('--oculta', action='store_true', help='la garra asoma tapada (de frente, detras de la capucha): busca por la madera fina')
	ap.add_argument('--desde', type=int, default=0)
	ap.add_argument('--hasta', type=int, default=-1)
	ap.add_argument('--prueba')
	args = ap.parse_args()
	h = Hoja(args.tres)
	ids = h.animaciones[args.anim][0]
	garra = Garra(args.textura)
	fr = [h.fotograma(c) for c in ids]
	H, W = fr[0].shape[:2]
	if args.oculta:
		hasta = args.hasta if args.hasta >= 0 else len(ids) - 1
		nuevos = {}
		for k in range(args.desde, hasta + 1):
			f = fr[k]
			q = buscar_madera(garra, f, ESCALAS, range(-70, 71, 6), (0, -100, W, int(H * 0.42)))
			q = buscar_madera(garra, f, [q[1]], np.arange(q[2] - 4, q[2] + 5, 1), (q[3] - 200, q[4] - 200, q[3] + 200, q[4] + 200))
			nuevos[ids[k]] = componer(f, garra.plantilla(q[1], q[2]), q[3], q[4], False)
		print('%s %d-%d: garra repintada (oculta)' % (args.anim, args.desde, hasta), flush=True)
		tex = h.casillas[ids[0]][0]
		carpeta = os.path.dirname(h.ext[tex])
		h.reempaquetar(tex, nuevos, carpeta)
		h.escribir_tres(args.tres, carpeta)
		print('escrito', h.ext[tex])
		return
	# el primero: busqueda amplia por la mitad de arriba
	G = gris(fr[0])
	p = buscar(garra, G, ESCALAS, range(-180, 180, 10), (-200, -200, W + 200, int(H * 0.6)))
	p = buscar(garra, G, ESCALAS, np.arange(p[2] - 8, p[2] + 9, 2), (p[3] - BUSCA * 2, p[4] - BUSCA * 2, p[3] + BUSCA * 2, p[4] + BUSCA * 2))
	pos = []
	for k, f in enumerate(fr):
		G = gris(f)
		_, e0, g0, x0, y0 = p
		gruesa = buscar(garra, G, [e for e in ESCALAS if abs(e - e0) < 0.04], np.arange(g0 - 15, g0 + 16, 3), (x0 - BUSCA - 150, y0 - BUSCA - 150, x0 + BUSCA + 150, y0 + BUSCA + 150))
		fina = buscar(garra, G, [gruesa[1]], np.arange(gruesa[2] - 2, gruesa[2] + 2.5, 1), (gruesa[3] - 160, gruesa[4] - 160, gruesa[3] + 160, gruesa[4] + 160))
		pos.append(fina)
		p = fina
	errs = np.array([q[0] for q in pos])
	med = float(np.median(errs))
	nuevos = {}
	malos = []
	for k, (f, q) in enumerate(zip(fr, pos)):
		if q[0] > MALO:
			malos.append(k)
			continue
		nuevos[ids[k]] = componer(f, garra.plantilla(q[1], q[2]), q[3], q[4], args.delante)
	print('%s: %d fotogramas, error mediano %.3f; sin tocar (encaje malo): %s' % (args.anim, len(fr), med, malos))
	if args.prueba:
		os.makedirs(args.prueba, exist_ok=True)
		for k in (list(range(0, 30, 3)) + list(range(30, len(fr), 9))):
			if ids[k] not in nuevos:
				continue
			q = pos[k]
			y0, y1 = int(max(q[4] - 260, 0)), int(min(q[4] + 260, H))
			x0, x1 = int(max(q[3] - 300, 0)), int(min(q[3] + 300, W))
			fila = []
			for im in (fr[k], nuevos[ids[k]]):
				c = im[y0:y1, x0:x1].astype(np.float32); al = c[..., 3:] / 255
				fila.append((c[..., :3] * al + np.array([60, 160, 60]) * (1 - al)).astype(np.uint8))
			t = np.hstack([fila[0], np.full((fila[0].shape[0], 6, 3), 255, np.uint8), fila[1]])
			t = cv2.copyMakeBorder(t, 26, 2, 2, 2, cv2.BORDER_CONSTANT, value=(20, 20, 20))
			cv2.putText(t, '%d  escala %.2f giro %.0f error %.3f' % (k, q[1], q[2], q[0]), (4, 19), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 1)
			cv2.imwrite(os.path.join(args.prueba, '%s_%03d.png' % (args.anim, k)), t[..., ::-1])
		return
	tex = h.casillas[ids[0]][0]
	carpeta = os.path.dirname(h.ext[tex])
	h.reempaquetar(tex, nuevos, carpeta)
	h.escribir_tres(args.tres, carpeta)
	print('escrito', h.ext[tex])


if __name__ == '__main__':
	main()

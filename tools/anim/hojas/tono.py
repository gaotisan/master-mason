"""Pasada de hojas: que el tono de la tunica no SALTE en los enganches.

Cada video de IA trae la tunica con su tono, y al pasar de una animacion a otra
se nota el cambio. No vale igualar cada animacion al reposo: andando o agachado
se ven otros parches con otra luz (es la postura, no el tono), y llevarlo todo al
reposo abria saltos donde no los habia (2026-10-21: el arranque del andar y el
andar casaban; igualados al reposo por separado, se separaban un 2,8 %).

Lo que se iguala son los ENGANCHES que hace el juego (de que fotograma de una
animacion a que fotograma de la siguiente: "enlaces" en la ficha, los de
tools/anim/revisar.py), donde los dos fotogramas tienen la misma postura. Cada
animacion lleva una ganancia por canal a la entrada y otra a la salida, de una a
otra a lo largo de la animacion (los bucles, una sola, para no romperlos); el
ancla ("ref") no cambia. Se resuelven todas a la vez por minimos cuadrados (en
logaritmos): que en cada enganche la tunica de los dos fotogramas sea igual, con
un freno suave (FRENO) para no apartarse del original sin necesidad y otro
(DENTRO) para no cambiar mucho de la entrada a la salida.

Se aplica en proporcion a la saturacion calida (como igualar_tono.py): capucha,
barba, pies, piel y madera casi no se tocan.

En la ficha: "tono": {"ref": "reposo", "enlaces": [[de, fotograma | null, a,
fotograma], ...]}; null: el fotograma de `de` que mas se parece al de `a`.
"""
import numpy as np

FRENO = 0.05
DENTRO = 0.3
VECINOS = 1      # se mide la tunica en el fotograma del enganche y sus VECINOS de cada lado


def tunica(rgb):
	"""rgb en 0-1."""
	mx = rgb.max(-1)
	mn = rgb.min(-1)
	s = (mx - mn) / np.maximum(mx, 1e-6)
	return (rgb[..., 0] > rgb[..., 1]) & (rgb[..., 1] >= rgb[..., 2] - 0.02) & (s > 0.12) & (mx > 0.15) & (mx < 0.85)


def media(ims):
	px = []
	for im in ims:
		f = im.astype(np.float32) / 255
		px.append(f[..., :3][(f[..., 3] > 0.8) & tunica(f[..., :3])])
	p = np.concatenate(px)
	return p.mean(0) if len(p) else np.ones(3, np.float32) * 0.3


def _premult(im):
	f = im.astype(np.float32) / 255
	return f[..., :3] * f[..., 3:]


def _mas_parecido(fotograma_de, ids_de, destino):
	d = _premult(destino)
	mejor, km = None, 0
	for k, c in enumerate(ids_de):
		p = _premult(fotograma_de(c))
		if p.shape != d.shape:
			continue
		v = float(np.abs(p - d).mean())
		if mejor is None or v < mejor:
			mejor, km = v, k
	return km


def ganancias(casilla_de, fotograma_de, animaciones, cfg):
	"""casilla_de(id) / fotograma_de(id) -> RGBA uint8 (ya limpia; la casilla, y el
	fotograma entero con su margen). Devuelve {anim: [ganancia RGB por fotograma]},
	un resumen {anim: (entrada %, salida %)} y los enganches antes / despues."""
	ref = cfg['ref']
	nombres = sorted({e[0] for e in cfg['enlaces']} | {e[2] for e in cfg['enlaces']})
	nombres = [n for n in nombres if n in animaciones]
	col = {}
	nvar = 0
	for n in nombres:
		if n == ref:
			continue
		col[(n, 'e')] = nvar
		if not animaciones[n][1]:
			nvar += 1
		col[(n, 's')] = nvar
		nvar += 1

	def tono_en(anim, k):
		ids = animaciones[anim][0]
		ks = [min(max(k + d, 0), len(ids) - 1) for d in range(-VECINOS, VECINOS + 1)]
		return np.log(media([casilla_de(ids[x]) for x in ks]))

	def fila(anim, k, signo, A):
		if anim == ref:
			return
		n = len(animaciones[anim][0])
		t = k / max(n - 1, 1)
		A[col[(anim, 'e')]] += signo * (1 - t)
		A[col[(anim, 's')]] += signo * t

	filas, lados, enganches = [], [], []
	for de, fd, a, fa in cfg['enlaces']:
		if de not in animaciones or a not in animaciones:
			continue
		ids_a = animaciones[a][0]
		fa = fa % len(ids_a)
		if fd is None:
			fd = _mas_parecido(fotograma_de, animaciones[de][0], fotograma_de(ids_a[fa]))
		fd = fd % len(animaciones[de][0])
		td, ta = tono_en(de, fd), tono_en(a, fa)
		A = np.zeros(nvar)
		fila(de, fd, 1.0, A)
		fila(a, fa, -1.0, A)
		filas.append(A)
		lados.append(ta - td)          # log g_de - log g_a = log t_a - log t_de
		enganches.append((de, fd, a, fa, td, ta))
	# frenos
	for v in range(nvar):
		A = np.zeros(nvar)
		A[v] = FRENO
		filas.append(A)
		lados.append(np.zeros(3))
	for n in nombres:
		if n != ref and not animaciones[n][1]:
			A = np.zeros(nvar)
			A[col[(n, 'e')]] = DENTRO
			A[col[(n, 's')]] = -DENTRO
			filas.append(A)
			lados.append(np.zeros(3))
	X, *_ = np.linalg.lstsq(np.array(filas), np.array(lados), rcond=None)   # nvar x 3 (log)
	out, resumen = {}, {}
	for n in nombres:
		if n == ref:
			continue
		ge, gs = np.exp(X[col[(n, 'e')]]), np.exp(X[col[(n, 's')]])
		k = len(animaciones[n][0])
		out[n] = [ge + (gs - ge) * (i / max(k - 1, 1)) for i in range(k)]
		resumen[n] = (float((ge.mean() - 1) * 100), float((gs.mean() - 1) * 100))
	informe = []
	for de, fd, a, fa, td, ta in enganches:
		gd = np.log(out[de][fd]) if de in out else 0
		ga = np.log(out[a][fa]) if a in out else 0
		antes = float((np.exp(ta - td).mean() - 1) * 100)
		despues = float((np.exp((ta + ga) - (td + gd)).mean() - 1) * 100)
		informe.append((de, fd, a, fa, antes, despues))
	return out, resumen, informe


def aplicar(im, g):
	f = im.astype(np.float32)
	rgb = f[..., :3] / 255
	mx = rgb.max(-1)
	s = (mx - rgb.min(-1)) / np.maximum(mx, 1e-6)
	w = np.clip((s - 0.10) / 0.15, 0, 1) * (rgb[..., 0] > rgb[..., 2])
	f[..., :3] = f[..., :3] * (1 + (np.asarray(g, np.float32) - 1) * w[..., None])
	return np.clip(f, 0, 255).round().astype(np.uint8)

"""Mide sobre las hojas nuevas (montar.py, <anim>/hoja) lo que peregrino.gd necesita
para el bloque de correr: enganches (en pasos normales del ciclo de correr), el avance
del pie plantado, las pisadas, el despegue y la toma del salto y su vuelo, y lo
escribe en correr_v2.json (assets/characters/peregrino/), que el script carga en
lugar de sus constantes cuando se usa esta hoja.

Distancia entre fotogramas: la de todo el proyecto (media de |A - B| en RGB
premultiplicado sobre la union de las siluetas), con las casillas alineadas por el
suelo y el centro. "Paso" = la mediana entre fotogramas seguidos del bucle de correr.
"""
import json
import os
import sys

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
PROYECTO = os.path.normpath(os.path.join(AQUI, '..', '..', '..', '..'))
sys.path.insert(0, os.path.join(PROYECTO, 'tools', 'anim', 'hojas'))
from hoja import Hoja  # noqa: E402

SUELO_MARGEN = 15        # px de hoja del suelo al borde de abajo
CONTACTO = 3             # px: un pie a esta altura del suelo esta apoyado


def leer(anim):
	d = os.path.join(AQUI, anim, 'hoja')
	return [cv2.cvtColor(cv2.imread(os.path.join(d, f), cv2.IMREAD_UNCHANGED), cv2.COLOR_BGRA2RGBA) for f in sorted(os.listdir(d))]


def lienzo(f, H=400, W=340):
	o = np.zeros((H, W, 4), np.uint8)
	x0 = (W - f.shape[1]) // 2
	o[H - f.shape[0]:, x0:x0 + f.shape[1]] = f
	return o


def P(f):
	x = lienzo(f).astype(np.float32) / 255
	return x[..., :3] * x[..., 3:]


def d(a, b):
	m = (a.sum(-1) > 0) | (b.sum(-1) > 0)
	return float(np.abs(a - b)[m].mean())


def pies_en_suelo(f):
	"""Columnas de lo apoyado (filas a CONTACTO px del suelo) y la altura del pie mas bajo."""
	a = f[..., 3] > 128
	suelo = f.shape[0] - SUELO_MARGEN
	ys = np.nonzero(a.any(1))[0]
	bajo = suelo - ys.max()
	franja = a[suelo - CONTACTO - 6:suelo + 3]
	xs = np.nonzero(franja.any(0))[0]
	return xs, bajo


def main():
	A = {n: leer(n) for n in ('arranque_correr', 'correr', 'salto_correr', 'aterrizaje_correr', 'parada_correr')}
	viejo = Hoja('resources/characters/peregrino_frames_limpio.tres')
	reposo = [viejo.fotograma(c) for c in viejo.animaciones['reposo'][0]]
	andar = [viejo.fotograma(c) for c in viejo.animaciones['andar'][0]]
	arr_andar = [viejo.fotograma(c) for c in viejo.animaciones['arranque_andar'][0]]
	C = [P(f) for f in A['correr']]
	n = len(C)
	paso = float(np.median([d(C[i], C[(i + 1) % n]) for i in range(n)]))
	r = {'_paso': paso}
	print('paso del ciclo %.4f; cierre del bucle %.2f pasos' % (paso, d(C[-1], C[0]) / paso))

	def mejor(f, lista, rango=None):
		p = P(f)
		ks = rango if rango is not None else range(len(lista))
		ds = [(d(p, P(lista[k]) if not isinstance(lista[k], np.ndarray) or lista[k].ndim == 3 and lista[k].shape[-1] == 4 else lista[k]) / paso, k) for k in ks]
		return min(ds)

	# reposo -> arranque: el primer fotograma del arranque aun quieto que mas se parece
	R0 = P(reposo[0])
	ar = [P(f) for f in A['arranque_correr']]
	dr = [d(R0, x) / paso for x in ar[:10]]
	print('reposo0 -> arranque 0-9:', [round(x, 2) for x in dr])
	# arranque -> correr: para cada corte del final, la mejor entrada
	cortes = []
	for c in range(len(ar) - 8, len(ar)):
		ds = [(d(ar[c], C[(j - 1) % n]) / paso, j) for j in range(n)]   # entrar por j: el fotograma que seguiria
		m = min(ds)
		cortes.append((round(m[0], 2), c, m[1]))
	cortes.sort()
	print('arranque corte -> entrada correr (pasos, corte, entrada):', cortes[:5])
	r['corte_arranque_correr'] = cortes[0][1]
	r['entrada_correr'] = cortes[0][2]
	# avance del pie plantado en el bucle (px de hoja por fotograma)
	desp = []
	for i in range(n):
		xa, ba = pies_en_suelo(A['correr'][i])
		xb, bb = pies_en_suelo(A['correr'][(i + 1) % n])
		if len(xa) and len(xb) and ba <= CONTACTO and bb <= CONTACTO:
			# el pie de atras del apoyo retrocede respecto al eje (el cuerpo avanza)
			desp.append(float(xa.min() - xb.min()))
	desp = [x for x in desp if 0 < x < 40]
	r['avance_correr'] = round(float(np.median(desp)), 2) if desp else None
	print('avance del pie plantado (px hoja/fotograma):', r['avance_correr'], 'muestras', [round(x, 1) for x in desp])
	# pisadas: fotograma en que un pie nuevo toca el suelo
	bajo = [pies_en_suelo(f)[1] for f in A['correr']]
	print('altura del pie mas bajo en el bucle:', bajo)
	# parada: distancia desde cada fotograma del bucle a la entrada de la parada
	pa = [P(f) for f in A['parada_correr']]
	r['dist_parada_correr'] = [round(d(C[j], pa[0]) / paso, 2) for j in range(n)]
	print('DIST_PARADA_CORRER', r['dist_parada_correr'])
	# salto: despegue y toca (pie mas bajo)
	sb = [pies_en_suelo(f)[1] for f in A['salto_correr']]
	print('salto, altura del pie mas bajo:', sb)
	desp_i = next(i for i in range(len(sb)) if sb[i] > 6)
	toca_i = next(i for i in range(desp_i + 3, len(sb)) if sb[i] <= 3)
	r['salto_correr_despegue'] = max(desp_i - 1, 0)
	r['salto_correr_toca'] = toca_i
	r['subida_salto_correr'] = float(max(sb))
	print('despegue', r['salto_correr_despegue'], 'toca', toca_i, 'subida', max(sb))
	# al tocar suelo, por que fotograma del bucle seguir
	S = [P(f) for f in A['salto_correr']]
	for t in range(toca_i, min(toca_i + 6, len(S))):
		m = min((d(S[t], C[j]) / paso, j) for j in range(n))
		print('  salto %d -> correr %d a %.2f' % (t, m[1], m[0]))
	m = min((d(S[toca_i], C[j]) / paso, j) for j in range(n))
	r['salto_correr_a_correr'] = m[1]
	# entradas al salto desde el bucle
	print('bucle -> salto 0:', [round(d(C[j], S[0]) / paso, 2) for j in range(n)])
	# finales contra el reposo
	for an in ('aterrizaje_correr', 'parada_correr'):
		x = P(A[an][-1])
		print('%s final -> reposo: %.2f pasos' % (an, min(d(x, P(f)) for f in reposo) / paso))
	# desde andar / arranque_andar al arranque de correr (el que mas se parece)
	r['pose_desde_andar'] = [min((d(P(f), ar[k]), k) for k in range(len(ar) - 6))[1] for f in andar]
	r['pose_desde_arranque_andar'] = [min((d(P(f), ar[k]), k) for k in range(len(ar) - 6))[1] for f in arr_andar]
	r['arranque_desde_reposo'] = int(np.argmin(dr[:6]))
	json.dump(r, open(os.path.join(AQUI, 'medidas.json'), 'w'), indent=1)
	print('medidas.json')


if __name__ == '__main__':
	main()

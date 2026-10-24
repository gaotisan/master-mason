"""El peregrino en DIAGONAL (los caminos de los lados del cruce del bosque): los
videos de Flow -> fotogramas limpios y a tamano fijo, como el frontal
(peregrino_secuencia_frontal/montar.py), para secuencia.py.

Videos (raw/master_builder/anim/_fuentes/; prompts y referencias en
_fuentes/prompt_diagonal.txt y referencias_diagonal.py; todos 1280x720, 24 fps):
  ida_sb       01 andar alejandose en diagonal a la derecha, baculo guardado
               (EL ANGULO: el cuerpo casi de espaldas, la diagonal la da el
               recorrido)
  vuelta_sb    02 la vuelta en la diagonal y volver hacia la camara
  correr_lejos_sb   03 correr alejandose (la camara va con el)
  correr_cerca_sb   04 correr acercandose (idem; pico en la capucha: fuera)
  ida_cb       05 andar alejandose con el baculo en la mano, a la derecha
  vuelta_cb    06 la vuelta y volver con el baculo
  ida_cb_izq   07 lo mismo por la izquierda (no se espeja: el baculo cambiaria
               de mano)
  vuelta_cb_izq 08 la vuelta por la izquierda (vale hasta ~110: luego se le echa
               encima a la camara y salta al fotograma final)
Con el baculo guardado la izquierda es la derecha espejada (no lleva nada en las
manos; el baculo de la espalda se pinta aqui, ver secuencia.py).

Por fotograma: alfa del croma (con el verde de cada video), sin lo que quede
suelto (motas; el baculo, aunque se separe del cuerpo, se queda), sin el pico de
la capucha (04: ../quitar_pico_capucha.py), piernas y pies al color de los
aceptados (Veo los saca grises, morados o claros: ver oscurecer_pies.py e
igualar_piernas.py del frontal). Tamano: capucha-pies medido SIN el baculo
(apertura que se come el palo), suavizado (mediana 11 + gaussiana 3) para no
meter el bote del paso; suelo por la recta suelo ~ altura (camara fija; en los
de correr la camara va con el y queda casi constante); eje del tronco suavizado.
A la casilla CAS con capucha-pies ALTO (2/3 del master del frontal: los videos
son de 720 y el personaje mide ~420 px; ampliarlo a 628 solo seria mas grande,
no mas nitido; el juego lo escala x1,5 mas).

    python montar.py [clave ...]     -> <clave>/c_###.png y <clave>/medidas.json
"""
import importlib.util
import json
import os
import sys

import cv2
import numpy as np
from scipy.ndimage import gaussian_filter1d, median_filter

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
FUENTES = os.path.join(ANIM, '_fuentes')

VIDEOS = {
	'ida_sb': 'Pilgrim_walking_away_from_camera_20261019102353.mp4',
	'vuelta_sb': 'Old_pilgrim_walking_toward_camera_20261019111933.mp4',
	'correr_lejos_sb': 'Pilgrim_running_on_green_screen_20261019130829.mp4',
	'correr_cerca_sb': 'Old_pilgrim_running_on_green_20261019145023.mp4',
	'ida_cb': 'Pilgrim_walking_away_from_camera_20261019145842.mp4',
	'vuelta_cb': 'Pilgrim_walking_toward_camera_20261019182318.mp4',
	'ida_cb_izq': 'Pilgrim_walking_with_staff_20261019181803.mp4',
	'vuelta_cb_izq': 'Pilgrim_walking_toward_camera_20261019182002.mp4',
}
CON_PICO = {'correr_cerca_sb'}
# Hasta donde vale cada video (fotograma, exclusivo): el 08 se le echa encima a la
# camara desde ~112 y sale cortado por abajo.
VALIDOS = {'vuelta_cb_izq': 112}

# La casilla: la del frontal (584x800, suelo 757, eje 292, capucha-pies 628) a 2/3.
# A la escala del master del frontal (2026-10-20: con las tomas en 1080p el
# personaje mide ~630 px, como alli; las que aun son de 720p se amplian x1,5,
# tan blandas como antes, hasta que se bajen en 1080p).
ESCALA = 1.0
CAS = (round(584 * ESCALA), round(800 * ESCALA))
SUELO = round(757 * ESCALA)
EJE = CAS[0] // 2
ALTO = 628.0 * ESCALA

# Piernas y pies: los de los aceptados del frontal (piernas casi negras, el pie
# marron oscuro; con (90,71,64) para todo, en el juego salian claras, color carne).
PIERNA = np.array([46.0, 36.0, 33.0])
PIE = np.array([73.0, 52.0, 47.0])

_spec = importlib.util.spec_from_file_location('quitar_pico_capucha', os.path.join(ANIM, 'quitar_pico_capucha.py'))
pico = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(pico)


# Las tomas bajadas en 1080p (la misma toma, con upscale de Flow): en
# _fuentes/hd_1080/<NN>_<nombre de la toma>.mp4; si estan, se usan esas.
HD = os.path.join(FUENTES, 'hd_1080')
NUMERO = {'ida_sb': '01', 'vuelta_sb': '02', 'correr_lejos_sb': '03', 'correr_cerca_sb': '04',
		  'ida_cb': '05', 'vuelta_cb': '06', 'ida_cb_izq': '07', 'vuelta_cb_izq': '08'}


def fuente(clave):
	hd = os.path.join(HD, '%s_%s' % (NUMERO[clave], VIDEOS[clave]))
	return hd if os.path.exists(hd) else os.path.join(FUENTES, VIDEOS[clave])


def leer_video(ruta):
	v = cv2.VideoCapture(ruta)
	fr = []
	while True:
		ok, f = v.read()
		if not ok:
			break
		fr.append(f)
	return fr


def alfa(bgr):
	"""Alfa del personaje sobre el croma: la pieza grande y lo que sea grande y
	este cerca (el baculo separado de la mano en algun fotograma); sin motas."""
	b, g, r = [bgr[..., k].astype(np.float32) for k in range(3)]
	a = np.clip((60.0 - (g - np.maximum(r, b))) / 35.0, 0.0, 1.0)
	m = (a > 0.5).astype(np.uint8)
	n, lab, st, _ = cv2.connectedComponentsWithStats(m, 8)
	if n <= 1:
		return a * 0
	k = np.argmax(st[1:, cv2.CC_STAT_AREA]) + 1
	x, y, w, h = st[k, :4]
	quedan = lab == k
	for i in range(1, n):
		if i == k or st[i, cv2.CC_STAT_AREA] < 150:
			continue
		xi, yi, wi, hi = st[i, :4]
		if xi < x + w + 40 and xi + wi > x - 40 and yi < y + h and yi + hi > y - 80:
			quedan |= lab == i
	return a * (cv2.dilate(quedan.astype(np.uint8), np.ones((5, 5))) > 0)


def sin_verde(bgr):
	b, g, r = [bgr[..., k].astype(np.float32) for k in range(3)]
	return np.dstack([b, np.minimum(g, np.maximum(r, b) * 1.05), r])


def medir(a):
	"""capucha-pies sin el baculo, fila de los pies y eje del tronco."""
	m = (a > 0.5).astype(np.uint8)
	r = max(13, int(13 * a.shape[1] / 1280) | 1)
	sin_palo = cv2.morphologyEx(m, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (r, r)))
	ys = np.nonzero(sin_palo.any(1))[0]
	top = int(ys.min())
	pies = int(np.nonzero(m.any(1))[0].max())
	h = pies - top
	banda = sin_palo[top + int(0.2 * h):top + int(0.5 * h)]
	xs = np.nonzero(banda)[1]
	return top, pies, h, float(np.median(xs))


def piernas(rgba):
	"""Lo fino que cuelga de la tunica (piernas) y la franja de los pies, al color
	PIE conservando el sombreado."""
	al = (rgba[..., 3] > 40).astype(np.uint8)
	ys = np.nonzero(al.any(1))[0]
	top, yb = ys.min(), ys.max()
	disco = max(9, int(0.06 * (yb - top)) | 1)
	ab = cv2.morphologyEx(al, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (disco, disco)))
	fino = (al > 0) & (ab == 0)
	fino[:int(top + 0.62 * (yb - top))] = False
	# el baculo tambien es fino: solo lo que cuelga cerca del eje del cuerpo
	banda = np.zeros(al.shape, bool)
	banda[yb - int(0.05 * (yb - top)):yb + 1] = True
	zona = (fino | (banda & (al > 0)))
	cuerpo = ab[int(top + 0.4 * (yb - top)):int(top + 0.7 * (yb - top))]
	xs = np.nonzero(cuerpo)[1]
	if len(xs):
		x0, x1 = np.percentile(xs, 3), np.percentile(xs, 97)
		zona[:, :int(x0) - 6] = False
		zona[:, int(x1) + 6:] = False
	# solo por debajo del bajo de la tunica (2026-10-20: un pico del bajo, fino,
	# entraba y salia una mancha oscura en la tela): por columna, lo que queda
	# bajo lo ultimo de la tunica gruesa (la silueta abierta con un disco ancho)
	tela = cv2.morphologyEx(al, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (disco * 2 + 1, disco * 2 + 1)))
	filas = np.arange(al.shape[0])[:, None]
	bajo = np.where(tela.any(0), (tela * filas).max(0), 0)[None, :]
	zona &= filas > bajo - 2
	# lo largo y delgado que va recto de arriba abajo lejos del cuerpo es el palo
	if not zona.any():
		return rgba
	rgb = rgba[..., :3].astype(np.float32)
	L = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
	ref = np.median(L[zona])
	f = np.clip((L / max(ref, 1.0)) ** 0.7, 0.55, 1.3)
	# la pierna casi negra y, en la franja de abajo (el pie), el marron del pie
	pie = np.zeros(al.shape, np.float32)
	pie[yb - int(0.035 * (yb - top)):yb + 1] = 1.0
	pie = cv2.GaussianBlur(pie, (0, 0), 2.0)[..., None]
	nuevo = (PIERNA[None, None, :] * (1 - pie) + PIE[None, None, :] * pie) * f[..., None]
	mezcla = cv2.GaussianBlur(zona.astype(np.float32), (0, 0), 1.0)[..., None]
	out = rgba.copy()
	out[..., :3] = np.clip(rgb * (1 - mezcla) + nuevo * mezcla, 0, 255).astype(np.uint8)
	return out


def sin_mancha_bajo(rgba):
	"""Quita la sombra que Veo pinta en el bajo de la tunica en algun fotograma de
	cada paso (el talon empujando la tela, 2026-10-20: en el reposo de ese pie se
	quedaba fija, una mancha oscura): lo mucho mas oscuro que la tela de alrededor
	(< 65 %), en el ultimo tercio de la figura, dentro de la tela gruesa y sin las
	costuras finas, se rellena con lo de alrededor."""
	al = (rgba[..., 3] > 200).astype(np.uint8)
	ys = np.nonzero(al.any(1))[0]
	top, yb = ys.min(), ys.max()
	h = yb - top
	disco = max(9, int(0.06 * h) | 1)
	tela = cv2.morphologyEx(al, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (disco * 2 + 1,) * 2))
	tela = cv2.erode(tela, np.ones((7, 7), np.uint8))
	L = rgba[..., :3].astype(np.float32) @ np.array([.299, .587, .114], np.float32)
	a = al.astype(np.float32)
	fondo = cv2.GaussianBlur(L * a, (0, 0), 18) / np.maximum(cv2.GaussianBlur(a, (0, 0), 18), 1e-3)
	zona = np.zeros_like(al)
	zona[top + int(0.65 * h):yb] = 1
	m = ((L < 0.65 * fondo) & (tela > 0) & (zona > 0)).astype(np.uint8)
	m = cv2.morphologyEx(m, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7)))
	n, lab, st, _ = cv2.connectedComponentsWithStats(m, 8)
	quita = np.zeros_like(m)
	for i in range(1, n):
		if st[i, cv2.CC_STAT_AREA] >= 0.0004 * h * h:
			quita |= (lab == i).astype(np.uint8)
	if not quita.any():
		return rgba
	quita = cv2.dilate(quita, np.ones((13, 13), np.uint8)) & tela
	out = rgba.copy()
	out[..., :3] = cv2.inpaint(np.ascontiguousarray(rgba[..., :3]), quita, 13, cv2.INPAINT_TELEA)
	return out


def montar(clave):
	ruta = fuente(clave)
	fr = leer_video(ruta)[:VALIDOS.get(clave)]
	ancho = fr[0].shape[1]
	alfas, meds = [], []
	for f in fr:
		if clave in CON_PICO:
			_, a, _ = pico.quitar(f, disco=int(pico.DISCO * ancho / 1280) | 1)
		else:
			a = alfa(f)
		alfas.append(a)
		meds.append(medir(a))
	r = np.array(meds, float)
	h = r[:, 2]
	pie = r[:, 1]
	cx = r[:, 3]
	hs = gaussian_filter1d(median_filter(h, 11, mode='nearest'), 3, mode='nearest')
	q = np.polyfit(hs, pie, 1)
	cxs = gaussian_filter1d(cx, 2, mode='nearest')
	sal = os.path.join(AQUI, clave)
	os.makedirs(sal, exist_ok=True)
	for k, (f, a) in enumerate(zip(fr, alfas)):
		s = ALTO / hs[k]
		rgb = sin_verde(f)
		rgba = np.dstack([rgb[..., 2], rgb[..., 1], rgb[..., 0], a * 255.0])
		# alfa premultiplicado al escalar (si no, el borde trae el verde)
		pre = rgba.copy()
		pre[..., :3] *= a[..., None]
		pre = cv2.resize(pre, (round(f.shape[1] * s), round(f.shape[0] * s)), interpolation=cv2.INTER_AREA if s < 1 else cv2.INTER_LANCZOS4)
		al = np.clip(pre[..., 3:4] / 255.0, 1e-4, 1.0)
		pre[..., :3] = pre[..., :3] / al
		pre = np.clip(pre, 0, 255).astype(np.uint8)
		c = np.zeros((CAS[1], CAS[0], 4), np.uint8)
		x0 = round(EJE - cxs[k] * s)
		y0 = round(SUELO - np.polyval(q, hs[k]) * s)
		# pegar recortando a la casilla
		sx0, sy0 = max(0, -x0), max(0, -y0)
		dx0, dy0 = max(0, x0), max(0, y0)
		w = min(pre.shape[1] - sx0, CAS[0] - dx0)
		hh = min(pre.shape[0] - sy0, CAS[1] - dy0)
		if w > 0 and hh > 0:
			c[dy0:dy0 + hh, dx0:dx0 + w] = pre[sy0:sy0 + hh, sx0:sx0 + w]
		c = piernas(sin_mancha_bajo(c))
		cv2.imwrite(os.path.join(sal, 'c_%03d.png' % k), cv2.cvtColor(c, cv2.COLOR_RGBA2BGRA))
	json.dump({'h': [round(float(v), 3) for v in hs], 'h_crudo': [int(v) for v in h],
			   'suelo': [round(float(q[1]), 3), round(float(q[0]), 5)], 'cx': [round(float(v), 1) for v in cxs],
			   'pie': [int(v) for v in pie], 'n': len(fr), 'ancho': ancho, 'fuente': os.path.basename(ruta)},
			  open(os.path.join(sal, 'medidas.json'), 'w'))
	print('%-16s %3d fotogramas; h %.0f..%.0f; suelo = %.1f + %.3f h' % (clave, len(fr), hs.min(), hs.max(), q[1], q[0]))


if __name__ == '__main__':
	for clave in (sys.argv[1:] or list(VIDEOS)):
		montar(clave)

"""PRUEBA DE FALSO 3D (2026-10-22): el peregrino en 8 direcciones, sin baculo. Las dos
diagonales salen de la tanda v2 (prompt ../_fuentes/prompt_diagonal_v2.txt), bajadas
en 1080p:
  alejarse  01: parado de espaldas recto, gira a la diagonal al echar a andar, se aleja
            hacia arriba a la izquierda (NO) y se para alla, en diagonal
  volver    02: parado alla en diagonal de espaldas, se da la vuelta, vuelve hacia
            abajo a la derecha (SE) y se para cerca, de tres cuartos de frente
Las otras dos diagonales (NE, SO) son su espejo (sin baculo en la mano no cambia nada).

Por fotograma, lo mismo que la primera diagonal (../peregrino_diagonal/montar.py: alfa
del croma, sin motas, sin la mancha del bajo, piernas al color de las aceptadas) y a
la misma casilla que el frontal (584x800, suelo 757, eje 292, capucha-pies 628).

    python montar.py [clave ...]     -> <clave>/c_###.png y <clave>/medidas.json
"""
import importlib.util
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import cv2
import numpy as np
from scipy.ndimage import gaussian_filter1d, median_filter

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
HD = os.path.join(ANIM, '_fuentes', 'hd_1080')
V3 = os.path.join(ANIM, '_fuentes', 'diagonal_v3')
VIDEOS = {
	'alejarse': os.path.join(HD, 'v2_01_Old_pilgrim_walking_away_1080p_20261022134015.mp4'),
	'volver': os.path.join(HD, 'v2_02_Old_pilgrim_walking_forward_1080p_20261022134057.mp4'),
	# la tercera tanda (2026-10-22, ../_fuentes/prompt_diagonal_v3.txt): el paso del frontal
	'v3_alejarse': os.path.join(V3, '01_andar_alejandose__gemini_generated_video_05fbf776.mp4'),
	'v3_acercarse': os.path.join(V3, '02_andar_acercandose__Old_pilgrim_walking_forward_20261022221235.mp4'),
	'v3_volverse_lejos': os.path.join(V3, '03_volverse_lejos_y_volver__Pilgrim_walking_on_green_background_20261022221517.mp4'),
	'v3_volverse_cerca': os.path.join(V3, '04_volverse_cerca_y_alejarse__Old_pilgrim_walking_away_20261022221736.mp4'),
	'v3_correr_alejandose': os.path.join(V3, '05_correr_alejandose__Old_pilgrim_running_on_green_20261022222341.mp4'),
	'v3_correr_acercandose': os.path.join(V3, '06_correr_acercandose__Old_pilgrim_running_on_green_20261022224625.mp4'),
	'v3_de_espaldas': os.path.join(V3, '07_de_espaldas_a_la_diagonal__Stylized_character_walking_away_20261022223816.mp4'),
}
# el pico de gnomo de la capucha (al girar de perfil y al correr): ../quitar_pico_capucha.py
CON_PICO = {'v3_volverse_lejos', 'v3_volverse_cerca', 'v3_correr_alejandose', 'v3_correr_acercandose', 'v3_de_espaldas'}
# los zapatos de bufon al correr hacia la camara: zapatos.py
ZAPATOS = {'v3_correr_acercandose'}
from zapatos import zapatos  # noqa: E402
# hasta donde vale (exclusivo): el 07 pega al final 11 fotogramas de otra imagen (salta al centro)
VALIDOS = {'v3_de_espaldas': 181}

_spec = importlib.util.spec_from_file_location('quitar_pico_capucha', os.path.join(ANIM, 'quitar_pico_capucha.py'))
PICO = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(PICO)

_spec = importlib.util.spec_from_file_location('montar_diagonal', os.path.join(ANIM, 'peregrino_diagonal', 'montar.py'))
MON = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(MON)
CAS, SUELO, EJE, ALTO = MON.CAS, MON.SUELO, MON.EJE, MON.ALTO


def montar(clave):
	ruta = VIDEOS[clave]
	fr = MON.leer_video(ruta)[:VALIDOS.get(clave)]
	alfas, meds = [], []
	for f in fr:
		if clave in CON_PICO:
			_, a, _ = PICO.quitar(f, disco=int(PICO.DISCO * f.shape[1] / 1280) | 1)
		else:
			a = MON.alfa(f)
		alfas.append(a)
		meds.append(MON.medir(a))
	r = np.array(meds, float)
	h, pie, cx = r[:, 2], r[:, 1], r[:, 3]
	hs = gaussian_filter1d(median_filter(h, 11, mode='nearest'), 3, mode='nearest')
	q = np.polyfit(hs, pie, 1)
	# sin los fotogramas que se salen de la recta (el 04 arranca en otro sitio y tamano)
	for _ in range(3):
		bien = np.abs(np.polyval(q, hs) - pie) < 12
		q = np.polyfit(hs[bien], pie[bien], 1)
	cxs = gaussian_filter1d(cx, 2, mode='nearest')
	sal = os.path.join(AQUI, clave)
	os.makedirs(sal, exist_ok=True)
	for k, (f, a) in enumerate(zip(fr, alfas)):
		s = ALTO / hs[k]
		rgb = MON.sin_verde(f)
		rgba = np.dstack([rgb[..., 2], rgb[..., 1], rgb[..., 0], a * 255.0])
		pre = rgba.copy()
		pre[..., :3] *= a[..., None]
		pre = cv2.resize(pre, (round(f.shape[1] * s), round(f.shape[0] * s)), interpolation=cv2.INTER_AREA if s < 1 else cv2.INTER_LANCZOS4)
		al = np.clip(pre[..., 3:4] / 255.0, 1e-4, 1.0)
		pre[..., :3] = pre[..., :3] / al
		pre = np.clip(pre, 0, 255).astype(np.uint8)
		c = np.zeros((CAS[1], CAS[0], 4), np.uint8)
		x0 = round(EJE - cxs[k] * s)
		y0 = round(SUELO - np.polyval(q, hs[k]) * s)
		sx0, sy0 = max(0, -x0), max(0, -y0)
		dx0, dy0 = max(0, x0), max(0, y0)
		w = min(pre.shape[1] - sx0, CAS[0] - dx0)
		hh = min(pre.shape[0] - sy0, CAS[1] - dy0)
		if w > 0 and hh > 0:
			c[dy0:dy0 + hh, dx0:dx0 + w] = pre[sy0:sy0 + hh, sx0:sx0 + w]
		c = MON.piernas(MON.sin_mancha_bajo(c))
		if clave in ZAPATOS:
			c = zapatos(c)
		cv2.imwrite(os.path.join(sal, 'c_%03d.png' % k), cv2.cvtColor(c, cv2.COLOR_RGBA2BGRA))
	json.dump({'h': [round(float(v), 3) for v in hs], 'h_crudo': [int(v) for v in h],
			   'suelo': [round(float(q[1]), 3), round(float(q[0]), 5)], 'cx': [round(float(v), 1) for v in cxs],
			   'pie': [int(v) for v in pie], 'n': len(fr), 'ancho': fr[0].shape[1], 'fuente': os.path.basename(ruta)},
			  open(os.path.join(sal, 'medidas.json'), 'w'))
	print('%-10s %3d fotogramas; h %.0f..%.0f; suelo = %.1f + %.3f h' % (clave, len(fr), hs.min(), hs.max(), q[1], q[0]), flush=True)


if __name__ == '__main__':
	for clave in (sys.argv[1:] or list(VIDEOS)):
		montar(clave)

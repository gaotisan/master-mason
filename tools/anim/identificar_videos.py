"""Que toma es cada video de Descargas: lo compara por la imagen (no por el
nombre: Flow pone en el nombre la fecha de la DESCARGA, no la de la generacion)
con todos los originales de raw/master_builder/anim/_fuentes, y dice cual es la
misma toma, a que resolucion viene y si es de las que el juego usa (USADOS).

La comparacion: varios fotogramas repartidos, reducidos a 320x180, diferencia
media; por debajo de MISMA es la misma toma (las de 1080p contra su original de
720p dan ~2; tomas distintas del mismo personaje, mas de 3).

  python tools/anim/identificar_videos.py [carpeta]   (por defecto, Descargas)
"""
import glob
import os
import sys

import cv2
import numpy as np

PROYECTO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
FUENTES = os.path.join(PROYECTO, 'raw', 'master_builder', 'anim', '_fuentes')
MISMA = 0.25
# Las tomas que usa el juego (de frente y de espaldas, y la diagonal) y que hay que
# pasar a 1080p: original -> lo que es.
USADOS = {
	'Pilgrim_walking_turning_full_20261008161217': 'frontal: todo con el baculo en la mano',
	'Pilgrim_walking_animation_sequence_20261008164615': 'frontal: sin baculo, reposo y andar de frente',
	'Pilgrim_draws_wooden_staff_20261009165324': 'frontal: sacar el baculo de frente',
	'Pilgrim_stowing_wooden_staff_20261009165938': 'frontal: guardar el baculo de frente',
	'Pilgrim_drawing_staff_on_green_20261011153220': 'frontal: sacar el baculo de espaldas',
	'Character_slinging_staff_animation_20261011153608': 'frontal: guardar el baculo de espaldas',
	'Pilgrim_turns_around_on_green_20261012094345': 'frontal: vuelta sin baculo',
	'Old_pilgrim_running_toward_camera_20261012094716': 'frontal: correr de frente',
	'Old_pilgrim_walking_away_20261012112519': 'frontal: andar de espaldas sin baculo',
	'Old_man_running_on_green_20261012112604': 'frontal: correr de espaldas',
	'Pilgrim_walking_away_from_camera_20261019102353': 'diagonal 01 (ya en 1080p)',
	'Old_pilgrim_walking_toward_camera_20261019111933': 'diagonal 02 (ya en 1080p)',
	'Pilgrim_running_on_green_screen_20261019130829': 'diagonal 03 correr alejandose',
	'Old_pilgrim_running_on_green_20261019145023': 'diagonal 04 correr acercandose',
	'Pilgrim_walking_away_from_camera_20261019145842': 'diagonal 05 con baculo, derecha',
	'Pilgrim_walking_toward_camera_20261019182318': 'diagonal 06 con baculo, derecha, vuelta',
	'Pilgrim_walking_with_staff_20261019181803': 'diagonal 07 con baculo, izquierda',
	'Pilgrim_walking_toward_camera_20261019182002': 'diagonal 08 con baculo, izquierda, vuelta',
}


def huella(ruta, n=6):
	v = cv2.VideoCapture(ruta)
	total = int(v.get(cv2.CAP_PROP_FRAME_COUNT))
	if total < 10:
		return None, total, 0
	out = []
	for k in np.linspace(3, total - 4, n).astype(int):
		v.set(cv2.CAP_PROP_POS_FRAMES, int(k))
		ok, f = v.read()
		if not ok:
			return None, total, 0
		f = cv2.resize(f, (320, 180), interpolation=cv2.INTER_AREA).astype(np.int16)
		b, g, r = f[..., 0], f[..., 1], f[..., 2]
		# la silueta (lo que no es croma): el verde, que es casi toda la imagen, no cuenta
		out.append(~((g > r + 40) & (g > b + 40)))
	return np.stack(out), total, int(v.get(cv2.CAP_PROP_FRAME_HEIGHT))


def distancia(a, b):
	"""1 - solape medio de las siluetas (0 = la misma toma)."""
	inter = (a & b).sum(axis=(1, 2))
	union = np.maximum((a | b).sum(axis=(1, 2)), 1)
	return float(1.0 - (inter / union).mean())


def main():
	carpeta = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.expanduser('~'), 'Downloads')
	originales = {}
	for p in glob.glob(os.path.join(FUENTES, '*.mp4')):
		h, n, _ = huella(p)
		if h is not None:
			originales[os.path.splitext(os.path.basename(p))[0]] = (h, n)
	for p in sorted(glob.glob(os.path.join(carpeta, '**', '*.mp4'), recursive=True), key=os.path.getmtime, reverse=True):
		h, n, alto = huella(p)
		if h is None:
			continue
		mejor = None
		for nombre, (ho, no) in originales.items():
			if no != n:
				continue
			d = distancia(h, ho)
			if mejor is None or d < mejor[0]:
				mejor = (d, nombre)
		que = '?'
		if mejor and mejor[0] < MISMA:
			que = '%s  ->  %s' % (mejor[1], USADOS.get(mejor[1], 'no lo usa el juego'))
		elif mejor:
			que = 'ninguna (la mas parecida, %s, a %.2f)' % (mejor[1], mejor[0])
		print('%-62s %5dp  %s' % (os.path.basename(p)[:62], alto, que))


if __name__ == '__main__':
	main()

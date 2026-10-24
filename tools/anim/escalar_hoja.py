"""Amplia con Real-ESRGAN (x4plus-anime) los fotogramas de un SpriteFrames .tres
ya montado, sin tocarlo: deja en `salida` cada casilla del atlas a ESCALA, en
RGBA, para rehacer la hoja despues. Asi se conservan los retoques a mano de las
hojas (no hace falta volver a los videos).

Por casilla: el color con el fondo rellenado del borde hacia fuera (si no, el
modelo pinta un halo oscuro) y el alfa aparte, los dos por el modelo a 4x y
bajados a ESCALA. Por tandas, para no llenar el disco con los 4x. Si se corta,
se relanza y sigue (salta lo ya hecho).

  python tools/anim/escalar_hoja.py <tres> <salida> <realesrgan-ncnn-vulkan.exe> [gpu] [inverso]
  gpu: el dispositivo Vulkan (en la P520: 1 la Quadro, 0 la Intel integrada, que es
  4 veces mas lenta pero no se cuelga); inverso: empieza por el final de lo pendiente
  (para lanzar dos a la vez, una por cada punta: solo se guarda lo que sale bien).

Medido el 2026-10-20 en el andar de frente: detalle 2,37 frente a 1,63 de la hoja
ampliada sin mas, y parpadeo en lo quieto 0,32 frente a 0,54 (no inventa: limpia).
"""
import json
import os
import re
import shutil
import subprocess
import sys

import cv2
import numpy as np

ESCALA = 1.5
MARGEN = 12      # px transparentes alrededor de cada casilla (el modelo mira vecinos)
TANDA = 10
# Trozos del modelo: con la grafica frenada por calor, Windows reinicia el driver si
# un envio tarda (vkQueueSubmit -4) y la casilla sale en negro SIN error; con trozos
# pequenos pasa menos, y cada casilla se comprueba contra la original (bien()).
TROZO = 128
RONDAS = 8
PROYECTO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))


def casillas(tres):
	t = open(os.path.join(PROYECTO, tres), encoding='utf-8').read()
	ext = dict((i, p) for p, i in re.findall(r'path="res://([^"]+)" id="([^"]+)"', t))
	for m in re.finditer(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\s*atlas = ExtResource\("([^"]+)"\)\s*region = Rect2\(([^)]*)\)', t):
		r = [int(round(float(v))) for v in m.group(3).split(',')]
		yield m.group(1), ext[m.group(2)], r


def rellenar(rgb, al):
	"""El color de dentro extendido hacia fuera (empuje-tira)."""
	acc, w = rgb * al[..., None], al.copy()
	capas = []
	for _ in range(7):
		capas.append((acc, w))
		acc, w = cv2.pyrDown(acc), cv2.pyrDown(w)
	c = acc / np.maximum(w, 1e-4)[..., None]
	for acc, w in reversed(capas):
		up = cv2.resize(c, (acc.shape[1], acc.shape[0]), interpolation=cv2.INTER_LINEAR)
		k = np.minimum(w * 4, 1)[..., None]
		c = np.where(w[..., None] > 1e-3, acc / np.maximum(w, 1e-4)[..., None], up) * k + up * (1 - k)
	return np.where(al[..., None] > 0.99, rgb, c)


def recorte(hoja, r):
	x, y, w, h = r
	return cv2.copyMakeBorder(hoja[y:y + h, x:x + w], MARGEN, MARGEN, MARGEN, MARGEN, cv2.BORDER_CONSTANT, value=(0, 0, 0, 0))


BLOQUE = 24      # px de la original: la comprobacion por trozos


def bien(hecha, hoja, r):
	"""La casilla ampliada, devuelta a su tamano, se parece a la original: en conjunto
	y trozo a trozo (2026-10-22: un trozo del modelo en negro, o transparente, en el bajo
	de la tunica no movia la media de la casilla y se colo en la hoja)."""
	x, y, w, h = r
	o = hoja[y:y + h, x:x + w].astype(np.float32)
	v = cv2.resize(hecha, (w, h), interpolation=cv2.INTER_AREA).astype(np.float32)
	m = o[..., 3] > 200
	if m.sum() < 50:
		return True
	if not (float(np.abs(v[..., 3] - o[..., 3]).mean()) < 12 and float(np.abs(v[..., :3] - o[..., :3])[m].mean()) < 14):
		return False
	for by in range(0, h, BLOQUE):
		for bx in range(0, w, BLOQUE):
			ob, vb = o[by:by + BLOQUE, bx:bx + BLOQUE], v[by:by + BLOQUE, bx:bx + BLOQUE]
			mb = ob[..., 3] > 200
			if float(np.abs(vb[..., 3] - ob[..., 3]).mean()) > 60:
				return False
			if mb.sum() > 40 and float(np.abs(vb[..., :3] - ob[..., :3])[mb].mean()) > 45:
				return False
	return True


def ampliar(pendientes, salida, trabajo, exe, modelos, hoja, gpu):
	for i in range(0, len(pendientes), TANDA):
		tanda = pendientes[i:i + TANDA]
		for d in ('rgb', 'alfa', 'rgb4', 'alfa4'):
			shutil.rmtree(os.path.join(trabajo, d), ignore_errors=True)
			os.makedirs(os.path.join(trabajo, d))
		tam = {}
		for ident, tex, r in tanda:
			w, h = r[2], r[3]
			c = recorte(hoja(tex), r)
			al = c[..., 3].astype(np.float32) / 255.0
			cv2.imwrite(os.path.join(trabajo, 'rgb', ident + '.png'), np.clip(rellenar(c[..., :3].astype(np.float32), al), 0, 255).astype(np.uint8))
			cv2.imwrite(os.path.join(trabajo, 'alfa', ident + '.png'), cv2.merge([c[..., 3]] * 3))
			tam[ident] = (w, h)
		for d in ('rgb', 'alfa'):
			subprocess.run([exe, '-i', os.path.join(trabajo, d), '-o', os.path.join(trabajo, d + '4'),
				'-n', 'realesrgan-x4plus-anime', '-s', '4', '-t', str(TROZO), '-g', str(gpu), '-m', modelos], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
		for ident, tex, r in tanda:
			w, h = r[2], r[3]
			W, H = round((w + 2 * MARGEN) * ESCALA), round((h + 2 * MARGEN) * ESCALA)
			if not os.path.exists(os.path.join(trabajo, 'alfa4', ident + '.png')):
				continue
			rgb = cv2.resize(cv2.imread(os.path.join(trabajo, 'rgb4', ident + '.png')), (W, H), interpolation=cv2.INTER_AREA)
			al = cv2.resize(cv2.imread(os.path.join(trabajo, 'alfa4', ident + '.png'))[..., 1], (W, H), interpolation=cv2.INTER_AREA)
			m = round(MARGEN * ESCALA)
			hecha = np.dstack([rgb, al])[m:H - m, m:W - m]
			# solo lo que sale bien: un envio colgado no pisa una casilla buena
			if bien(hecha, hoja(tex), r):
				cv2.imwrite(os.path.join(salida, ident + '.png'), hecha)
		print('%d/%d' % (min(i + TANDA, len(pendientes)), len(pendientes)), flush=True)


def main():
	tres, salida, exe = sys.argv[1], sys.argv[2], sys.argv[3]
	gpu = int(sys.argv[4]) if len(sys.argv) > 4 else 1
	inverso = len(sys.argv) > 5 and sys.argv[5] == 'inverso'
	modelos = os.path.join(os.path.dirname(exe), 'models')
	os.makedirs(salida, exist_ok=True)
	trabajo = os.path.join(salida, '_trabajo_g%d%s' % (gpu, '_inv' if inverso else ''))
	hojas = {}

	def hoja(tex):
		if tex not in hojas:
			hojas[tex] = cv2.imread(os.path.join(PROYECTO, tex), cv2.IMREAD_UNCHANGED)
		return hojas[tex]

	vistas = {}
	todas = []
	for ident, tex, r in casillas(tres):
		clave = (tex, tuple(r))
		if clave not in vistas:
			vistas[clave] = ident
			todas.append((ident, tex, r))
	for ronda in range(RONDAS):
		pendientes = []
		for ident, tex, r in todas:
			f = os.path.join(salida, ident + '.png')
			if not (os.path.exists(f) and bien(cv2.imread(f, cv2.IMREAD_UNCHANGED), hoja(tex), r)):
				pendientes.append((ident, tex, r))
		print('ronda %d: casillas por hacer %d de %d' % (ronda + 1, len(pendientes), len(todas)), flush=True)
		if not pendientes:
			break
		if inverso:
			pendientes.reverse()
		ampliar(pendientes, salida, trabajo, exe, modelos, hoja, gpu)
	# casillas repetidas (la misma region en dos animaciones): se copian al final
	repetidas = {}
	for ident, tex, r in casillas(tres):
		o = vistas[(tex, tuple(r))]
		if o != ident:
			repetidas[ident] = o
	shutil.rmtree(trabajo, ignore_errors=True)
	json.dump(repetidas, open(os.path.join(salida, 'repetidas.json'), 'w'))
	print('hecho', flush=True)


if __name__ == '__main__':
	main()

"""Mete el bloque de correr nuevo (<anim>/hoja de montar.py) en la hoja GEMELA del
perfil (resources/characters/peregrino_frames_limpio.tres): un atlas propio
(assets/characters/peregrino_limpio/peregrino_correr_v2.png, cada fotograma
recortado a lo dibujado y alineado a 4 por la compresion, como empaquetar.py) y las
cinco animaciones con sus fotogramas nuevos y su velocidad (la de correr_v2.json).
La hoja del juego (peregrino_frames.tres) no se toca.

Se vuelve a pasar despues de cada procesar.py del perfil (que rehace la gemela desde
la del juego). Se puede repetir: quita lo que metio la vez anterior.

  python integrar.py
"""
import json
import os
import re

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
PROYECTO = os.path.normpath(os.path.join(AQUI, '..', '..', '..', '..'))
TRES = os.path.join(PROYECTO, 'resources', 'characters', 'peregrino_frames_limpio.tres')
ATLAS = 'assets/characters/peregrino_limpio/peregrino_correr_v2.png'
FICHA = os.path.join(PROYECTO, 'assets', 'characters', 'peregrino', 'correr_v2.json')
ANIMS = ['arranque_correr', 'correr', 'salto_correr', 'aterrizaje_correr', 'parada_correr']
ANCHO = 4096
SEP = 8
ID_TEX = 'tex_correr_v2'


def main():
	fps = json.load(open(FICHA, encoding='utf-8'))['fps']
	piezas = []
	for an in ANIMS:
		d = os.path.join(AQUI, an, 'hoja')
		for i, f in enumerate(sorted(os.listdir(d))):
			im = cv2.imread(os.path.join(d, f), cv2.IMREAD_UNCHANGED)
			ys, xs = np.nonzero(im[..., 3] > 0)
			x0, y0 = (xs.min() // 4) * 4, (ys.min() // 4) * 4
			x1, y1 = min(-(-(xs.max() + 1) // 4) * 4, im.shape[1]), min(-(-(ys.max() + 1) // 4) * 4, im.shape[0])
			piezas.append((an, i, im, x0, y0, x1, y1))
	x = y = alto = 0
	sitio = []
	for an, i, im, x0, y0, x1, y1 in piezas:
		w, h = x1 - x0, y1 - y0
		if x + w > ANCHO:
			x, y, alto = 0, y + alto + SEP, 0
		sitio.append((x, y))
		x += w + SEP
		alto = max(alto, h)
	atlas = np.zeros((-(-(y + alto) // 4) * 4, ANCHO, 4), np.uint8)
	for (an, i, im, x0, y0, x1, y1), (X, Y) in zip(piezas, sitio):
		atlas[Y:Y + y1 - y0, X:X + x1 - x0] = im[y0:y1, x0:x1]
	cv2.imwrite(os.path.join(PROYECTO, ATLAS), atlas)
	imp = open(os.path.join(PROYECTO, 'assets/characters/peregrino_limpio/peregrino_corriendo.png.import'), encoding='utf-8').read()
	open(os.path.join(PROYECTO, ATLAS + '.import'), 'w', encoding='utf-8').write(
		'[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n' + imp[imp.index('[params]'):])

	t = open(TRES, encoding='utf-8').read()
	# lo de la vez anterior, fuera
	t = re.sub(r'\[ext_resource type="Texture2D" path="res://%s" id="%s"\]\n' % (re.escape(ATLAS), ID_TEX), '', t)
	t = re.sub(r'\[sub_resource type="AtlasTexture" id="cv2_\d+"\]\natlas = ExtResource\("%s"\)\nregion = Rect2\([^)]*\)\nmargin = Rect2\([^)]*\)\n\n' % ID_TEX, '', t)
	# la textura
	i = t.index('\n\n[sub_resource')
	t = t[:i] + '\n[ext_resource type="Texture2D" path="res://%s" id="%s"]' % (ATLAS, ID_TEX) + t[i:]
	# las casillas
	subs = []
	ids = {an: [] for an in ANIMS}
	for n, ((an, i, im, x0, y0, x1, y1), (X, Y)) in enumerate(zip(piezas, sitio)):
		H, W = im.shape[:2]
		ident = 'cv2_%d' % n
		subs.append('[sub_resource type="AtlasTexture" id="%s"]\natlas = ExtResource("%s")\nregion = Rect2(%d, %d, %d, %d)\nmargin = Rect2(%d, %d, %d, %d)\n\n' % (
			ident, ID_TEX, X, Y, x1 - x0, y1 - y0, x0, y0, W - (x1 - x0), H - (y1 - y0)))
		ids[an].append(ident)
	i = t.index('[resource]')
	t = t[:i] + ''.join(subs) + t[i:]
	# las animaciones
	for an in ANIMS:
		patron = re.compile(r'(\{\n"frames": \[)((?:(?!"name").)*?)(\],\n"loop": \w+,\n"name": &"%s",\n"speed": )([\d.]+)' % an, re.S)
		m = patron.search(t)
		assert m, an
		fr = ', '.join('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % k for k in ids[an])
		t = t[:m.start()] + m.group(1) + fr + m.group(3) + str(float(fps[an])) + t[m.end():]
	open(TRES, 'w', encoding='utf-8').write(t)
	print('atlas', atlas.shape, ' fotogramas', {an: len(v) for an, v in ids.items()})


if __name__ == '__main__':
	main()

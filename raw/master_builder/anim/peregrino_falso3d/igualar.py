"""PRUEBA DE FALSO 3D: COPIA de las animaciones que usa la prueba (frontal, perfil y
diagonales) con el color de la tunica IGUALADO (2026-10-22, el usuario: "las tunicas
tienen que coincidir todas en color ... mas parecidos a la de perfil y de frente, que
son los reales"). No toca ninguna hoja: escribe una hoja nueva solo para la prueba.

Medido en la tela marron (opaca, croma > 7, del 20 al 85 % del alto: sin capucha, barba,
parches grises ni piernas): perfil y frente casi iguales (L 81, a 10, b 9,5); espaldas
y las diagonales, menos rojas, mas amarillas y mas oscuras. Cada vista se acerca a la
media de perfil y frente: en LAB, por canal, la media y (con tope) la dispersion de su
tela (la luz entera, el color al 60 %: FUERZA); con un peso que solo coge lo marron (por croma y tono), asi la capucha gris, la
barba y los parches grises no se tocan. Una correccion por vista (no por fotograma):
no parpadea.

    python igualar.py
-> assets/characters/peregrino_falso3d_prueba/*.png, resources/characters/
   peregrino_falso3d_prueba.tres, assets/characters/peregrino/falso3d_prueba.json
"""
import io
import json
import os
import shutil
import sys

import cv2
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
PROYECTO = os.path.normpath(os.path.join(AQUI, '..', '..', '..', '..'))
sys.path.insert(0, os.path.join(PROYECTO, 'tools', 'anim', 'hojas'))
from hoja import Hoja  # noqa: E402

CARPETA = 'assets/characters/peregrino_falso3d_prueba'
TRES = 'resources/characters/peregrino_falso3d_prueba.tres'
FICHA = 'assets/characters/peregrino/falso3d_prueba.json'
FRONTAL = 'resources/characters/peregrino_frontal_hd.tres'
PERFIL = 'resources/characters/peregrino_frames_limpio.tres'
DIAG = 'resources/characters/peregrino_falso3d.tres'
# vista: (hoja, {clave de la prueba: animacion de la hoja})
VISTAS = {
	'frente': (FRONTAL, {'andar_s': 'andar_frente_sb', 'reposo_s': 'reposo_frente_sb'}),
	'espalda': (FRONTAL, {'andar_n': 'andar_espalda_sb', 'reposo_n': 'reposo_espalda_sb'}),
	'perfil': (PERFIL, {'andar_e': 'andar', 'reposo_e': 'reposo'}),
	'diag_se': (DIAG, {k: k for k in ('andar_se', 'reposo_se', 'arranque_se', 'parada_se', 'correr_se', 'parada_correr_se',
									 'a_correr_se', 'de_correr_se')}),
	'diag_no': (DIAG, {k: k for k in ('andar_no', 'reposo_no', 'arranque_no', 'parada_no', 'correr_no', 'parada_correr_no',
									 'a_correr_no', 'de_correr_no')}),
}
# las que pasan de una vista a otra: la media de las dos correcciones
MEZCLAS = {'vuelta_no_se': (DIAG, ('diag_no', 'diag_se')), 'vuelta_se_no': (DIAG, ('diag_se', 'diag_no')),
		   'esquina_n_no': (DIAG, ('espalda', 'diag_no'))}
# las que giran de una vista a otra: la correccion pasa de la primera a la segunda a lo
# largo de la animacion (el giro en el sitio: la vuelta del frontal, de frente a espaldas)
GRADUALES = {'giro': (FRONTAL, 'vuelta_sb', 'frente', 'espalda')}
# las animaciones con las que se mide cada vista (las de andar y quieto)
MEDIR = ('andar_', 'reposo_')
REFERENCIA = ('perfil', 'frente')
DISPERSION = (0.8, 1.2)     # tope de lo que se ensancha o estrecha cada canal
# cuanto se acerca cada canal (L, a, b): la luz entera; el color a medias (la espalda
# no tiene los parches rojos y ocres del pecho: llevada a su media salia rosada)
FUERZA = np.array([1.0, 0.6, 0.6], np.float32)
TONO = (5.0, 110.0)         # tono LAB de lo marron (grados)
PAGINA, SEP = 4096, 2


def lab(f):
	return cv2.cvtColor(np.ascontiguousarray(f[..., :3]), cv2.COLOR_RGB2LAB).astype(np.float32)


def tela(f):
	a = f[..., 3] > 220
	ys = np.nonzero(a.any(1))[0]
	top, pie = ys.min(), ys.max()
	h = pie - top
	x = lab(f)
	A, B = x[..., 1] - 128, x[..., 2] - 128
	zona = np.zeros(a.shape, bool)
	zona[top + int(0.2 * h):top + int(0.85 * h)] = True
	m = a & zona & (np.hypot(A, B) > 7) & (x[..., 0] > 25)
	return x[m]


def peso(x):
	"""Cuanto es tela marron cada pixel (0 la capucha gris, la barba, lo gris)."""
	A, B = x[..., 1] - 128, x[..., 2] - 128
	cr = np.hypot(A, B)
	hue = np.degrees(np.arctan2(B, A))
	w = np.clip((cr - 4.0) / 6.0, 0, 1)
	w *= np.clip((hue - TONO[0]) / 10.0, 0, 1) * np.clip((TONO[1] - hue) / 10.0, 0, 1)
	return w


# El frontal con el baculo a la espalda tal como lo pinta el juego (poses_baculo: los
# fotogramas de frente, espaldas y la vuelta, de scenes/dev/poses_frontal.tscn)
POSES_B = os.path.join(AQUI, 'poses_baculo')


def fotogramas(h, t, an):
	ids = h.animaciones[an][0]
	fs = [h.fotograma(c) for c in ids]
	if t == FRONTAL and os.path.exists(os.path.join(POSES_B, '%s_000.png' % an)):
		out = []
		for k, f in enumerate(fs):
			g = np.asarray(Image.open(os.path.join(POSES_B, '%s_%03d.png' % (an, k))).convert('RGBA'))
			H, W = f.shape[:2]
			# el render tiene los pies 13 px mas arriba que la hoja (medido): se baja
			out.append(np.ascontiguousarray(g[1100 - 770:1100 - 770 + H, 600 - 292:600 - 292 + W]))
		return out
	return fs


def main():
	hojas = {}
	frames, stats = {}, {}
	for vista, (t, anims) in VISTAS.items():
		h = hojas.setdefault(t, Hoja(t))
		px = []
		for clave, an in anims.items():
			if an not in h.animaciones:
				print('   (no hay %s)' % an)
				continue
			ids, loop, fps = h.animaciones[an]
			frames[clave] = (vista, fps, fotogramas(h, t, an))
			if clave.startswith(MEDIR):
				for f in frames[clave][2][::max(1, len(ids) // 10)]:
					px.append(tela(f))
		p = np.vstack(px)
		stats[vista] = (p.mean(0), p.std(0))
	ref_m = np.mean([stats[v][0] for v in REFERENCIA], 0)
	ref_s = np.mean([stats[v][1] for v in REFERENCIA], 0)
	ajuste = {}
	for vista, (m, s) in stats.items():
		k = 1 + (np.clip(ref_s / np.maximum(s, 1e-3), *DISPERSION) - 1) * FUERZA
		ajuste[vista] = (m, k, m + (ref_m - m) * FUERZA)
		print('%-8s L %5.1f a %5.2f b %5.2f  ->  L %5.1f a %5.2f b %5.2f   (dispersion x%s)' % (
			vista, m[0], m[1] - 128, m[2] - 128, ajuste[vista][2][0], ajuste[vista][2][1] - 128, ajuste[vista][2][2] - 128, np.round(k, 2)))
	for clave, (t, (v1, v2)) in MEZCLAS.items():
		h = hojas.setdefault(t, Hoja(t))
		if clave not in h.animaciones:
			continue
		ids, loop, fps = h.animaciones[clave]
		frames[clave] = ((v1, v2), fps, [h.fotograma(c) for c in ids])
	for clave, (t, an, v1, v2) in GRADUALES.items():
		h = hojas.setdefault(t, Hoja(t))
		ids, loop, fps = h.animaciones[an]
		frames[clave] = (('gradual', v1, v2), fps, fotogramas(h, t, an))
	salida = {}
	for clave, (vista, fps, fs) in frames.items():
		out = []
		for i, f in enumerate(fs):
			if isinstance(vista, tuple) and vista[0] == 'gradual':
				t = i / max(len(fs) - 1, 1)
				m, k, destino = [a * (1 - t) + b * t for a, b in zip(ajuste[vista[1]], ajuste[vista[2]])]
			elif isinstance(vista, tuple):
				m, k, destino = [(a + b) / 2 for a, b in zip(ajuste[vista[0]], ajuste[vista[1]])]
			else:
				m, k, destino = ajuste[vista]
			x = lab(f)
			nuevo = (x - m) * k + destino
			w = peso(x)[..., None]
			y = np.clip(x * (1 - w) + nuevo * w, 0, 255).astype(np.uint8)
			rgb = cv2.cvtColor(y, cv2.COLOR_LAB2RGB)
			g = f.copy()
			g[..., :3] = np.where(f[..., 3:] > 0, rgb, f[..., :3])
			out.append(g)
		salida[clave] = (fps, out)
	escribir(salida)


def escribir(salida):
	d = os.path.join(PROYECTO, CARPETA)
	if os.path.isdir(d):
		shutil.rmtree(d)
	os.makedirs(d)
	piezas = []
	for clave, (fps, fs) in salida.items():
		for j, f in enumerate(fs):
			ys, xs = np.nonzero(f[..., 3] > 0)
			x0, y0 = (xs.min() // 4) * 4, (ys.min() // 4) * 4
			x1, y1 = min(-(-(xs.max() + 1) // 4) * 4, f.shape[1]), min(-(-(ys.max() + 1) // 4) * 4, f.shape[0])
			piezas.append((clave, j, f, x0, y0, x1, y1))
	piezas.sort(key=lambda p: -(p[6] - p[4]))
	paginas, x, y, alto, pag = [[]], 0, 0, 0, 0
	sitio = {}
	for clave, j, f, x0, y0, x1, y1 in piezas:
		w, h = x1 - x0, y1 - y0
		if x + w > PAGINA:
			x, y, alto = 0, y + alto + SEP, 0
		if y + h > PAGINA:
			paginas.append([])
			pag, x, y, alto = pag + 1, 0, 0, 0
		sitio[(clave, j)] = (pag, x, y)
		paginas[pag].append((clave, j, f, x0, y0, x1, y1))
		x += w + SEP
		alto = max(alto, h)
	imp = open(os.path.join(PROYECTO, 'assets/characters/peregrino_falso3d/falso3d_0.png.import'), encoding='utf-8').read()
	imp = imp[imp.index('[params]'):]
	for p, lista in enumerate(paginas):
		W = max(sitio[(c, j)][1] + x1 - x0 for c, j, f, x0, y0, x1, y1 in lista)
		H = max(sitio[(c, j)][2] + y1 - y0 for c, j, f, x0, y0, x1, y1 in lista)
		atlas = np.zeros((-(-H // 4) * 4, -(-W // 4) * 4, 4), np.uint8)
		for c, j, f, x0, y0, x1, y1 in lista:
			_, X, Y = sitio[(c, j)]
			atlas[Y:Y + y1 - y0, X:X + x1 - x0] = f[y0:y1, x0:x1]
		nombre = 'prueba_%d.png' % p
		Image.fromarray(atlas).save(os.path.join(d, nombre), optimize=True)
		io.open(os.path.join(d, nombre + '.import'), 'w', encoding='utf-8', newline='\n').write(
			'[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n' + imp)
		print('  %s %dx%d %d fotogramas' % (nombre, atlas.shape[1], atlas.shape[0], len(lista)))
	porclave = {}
	for c, j, f, x0, y0, x1, y1 in piezas:
		porclave[(c, j)] = (f.shape, x0, y0, x1, y1)
	ext = ['[ext_resource type="Texture2D" path="res://%s/prueba_%d.png" id="t%d"]' % (CARPETA, p, p) for p in range(len(paginas))]
	sub, bloques = [], []
	for clave, (fps, fs) in salida.items():
		refs = []
		for j in range(len(fs)):
			(FH, FW, _), x0, y0, x1, y1 = porclave[(clave, j)]
			p, X, Y = sitio[(clave, j)]
			ida = '%s_%d' % (clave, j)
			sub.append('[sub_resource type="AtlasTexture" id="%s"]\natlas = ExtResource("t%d")\nregion = Rect2(%d, %d, %d, %d)\nmargin = Rect2(%d, %d, %d, %d)\n'
					   % (ida, p, X, Y, x1 - x0, y1 - y0, x0, y0, FW - (x1 - x0), FH - (y1 - y0)))
			refs.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % ida)
		bloques.append('{\n"frames": [%s],\n"loop": true,\n"name": &"%s",\n"speed": %s\n}' % (', '.join(refs), clave, float(fps)))
	txt = ('[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n' % (len(ext) + len(sub) + 1)
		   + '\n'.join(ext) + '\n\n' + '\n'.join(sub) + '\n[resource]\nanimations = [' + ', '.join(bloques) + ']\n')
	io.open(os.path.join(PROYECTO, TRES), 'w', encoding='utf-8', newline='\n').write(txt)
	print('->', TRES)


if __name__ == '__main__':
	main()

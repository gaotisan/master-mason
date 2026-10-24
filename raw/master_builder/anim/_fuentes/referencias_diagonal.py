"""Referencias 1920x1080 para los VIDEOS EN DIAGONAL del peregrino (Flow, fotogramas
a video; los prompts van en Descargas/peregrino_diagonal/, uno por carpeta, y
copia en prompt_diagonal.txt).

Por que (2026-10-19): en el cruce del bosque (scenes/game/cruce_bosque.tscn) los
caminos de los lados salen en diagonal (el de la izquierda ~35 grados de la linea
de la camara, el de la derecha ~25-30) y el peregrino los anda de espaldas con
deriva de lado: se nota. Hacen falta andares en diagonal alejandose y
acercandose, la vuelta en la diagonal, correr (con el baculo guardado) y sacar y
guardar visto de tres cuartos.

Fuentes, en HD (los masters, 1:1, ~640 px de la capucha a los pies):
  - GUARDADO (videos sin baculo ni correa: el juego se los pone, como en el
    frontal sin baston): los fotogramas limpios de peregrino_secuencia_frontal_sin
    (04_limpios): reposo de espaldas y de frente, y del giro el tres cuartos de
    espaldas (vuelta_sb 42, ~145 grados) y de frente (vuelta_sb 16, ~37).
  - CON EL BACULO EN LA MANO, y el guardado para sacar / guardar: lo que pinta el
    juego (garra de frente, correa vacia, baculo a la espalda), con
    scenes/dev/poses_frontal.tscn: reposo de espaldas y de frente con baston, el
    tres cuartos de espaldas con baston (vuelta_cb 27) y el guardado (vuelta_sb
    42) con el baculo en la correa.
Garra vacia (sin bola: la pone el juego). Croma #24D732. Pies en la fila 1040.
Las poses del juego se pintan con fondo transparente (sin ribete verde).

  python referencias_diagonal.py [--sin-godot]   (con Godot pinta antes las poses)
"""
import os
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
PROYECTO = os.path.normpath(os.path.join(ANIM, '..', '..', '..'))
GODOT = os.path.normpath(os.path.join(PROYECTO, '..', '..', 'engine', 'Godot_v4.6.2', 'Godot_v4.6.2-stable_win64_console.exe'))
POSES = os.path.join(AQUI, 'poses_diagonal')
DESCARGAS = os.path.join(os.path.expanduser('~'), 'Downloads', 'peregrino_diagonal')
VERDE = (36, 215, 50)
W, H = 1920, 1080
PIE_Y = 1040
# Donde empieza (y acaba la vuelta) por cada lado: fuera del centro, hacia el lado
# contrario al que se va, para que alejandose no se salga del cuadro.
X_DERECHA = 700
X_IZQUIERDA = 1220
X_CENTRO = 960

# Lo que pinta el juego (nombre: animacion, fotograma, con baston)
POSES_JUEGO = {
	'espalda_mano': ('reposo_espalda_cb', 0, 1),
	'frente_mano': ('reposo_frente_cb', 0, 1),
	'tq_espalda_mano': ('vuelta_cb', 27, 1),
	'tq_espalda_baculo_guardado': ('vuelta_sb', 42, 0),
	# para la hoja de angulos
	'ang_mano_0': ('vuelta_cb', 0, 1), 'ang_mano_1': ('vuelta_cb', 5, 1), 'ang_mano_2': ('vuelta_cb', 11, 1),
	'ang_mano_3': ('vuelta_cb', 27, 1), 'ang_mano_4': ('vuelta_cb', 32, 1),
	'ang_guardado_0': ('vuelta_sb', 5, 0), 'ang_guardado_1': ('vuelta_sb', 16, 0), 'ang_guardado_2': ('vuelta_sb', 28, 0),
	'ang_guardado_3': ('vuelta_sb', 42, 0), 'ang_guardado_4': ('vuelta_sb', 58, 0),
}
# Fotogramas limpios sin nada a la espalda (modo guardado)
LIMPIOS = {
	'espalda_guardado': 'peregrino_secuencia_frontal_sin/04_limpios/reposo_espalda_sb_000.png',
	'frente_guardado': 'peregrino_secuencia_frontal_sin/04_limpios/reposo_frente_sb_000.png',
	'tq_espalda_guardado': 'peregrino_secuencia_frontal_sin/04_limpios/vuelta_sb_046.png',
	'tq_frente_guardado': 'peregrino_secuencia_frontal_sin/04_limpios/vuelta_sb_012.png',
}

# EL ANGULO (2026-10-19): el de la toma buena del 01
# (Pilgrim_walking_away_from_camera_20261019102353): se aleja en diagonal pero
# con el cuerpo casi de espaldas, girado unos 10-15 grados (como vuelta_sb 46,
# 167). Es el unico angulo de diagonal: todas las tomas a el. Por eso los tres
# cuartos de correr son vuelta_sb 46 (de espaldas) y 12 (de frente, ~16), y
# sacar / guardar en diagonal sobran (09 y 10 fuera): con el cuerpo casi de
# espaldas valen los de espaldas que ya hay.
# Los videos: carpeta -> [(archivo, pose, x)]
VIDEOS = {
	'01_guardado_andar_ida_derecha': [('inicio.png', 'espalda_guardado', X_DERECHA)],
	# el inicio es el ultimo fotograma de la toma buena del 01
	# (Pilgrim_walking_away_from_camera_20261019102353, f239), limpio:
	# poses_diagonal/inicio_02_de_01_f239.png, se copia a mano
	'02_guardado_andar_vuelta_derecha': [('fin.png', 'frente_guardado', X_DERECHA)],
	'03_guardado_correr_alejandose': [('inicio_y_fin.png', 'tq_espalda_guardado', X_CENTRO)],
	'04_guardado_correr_acercandose': [('inicio_y_fin.png', 'tq_frente_guardado', X_CENTRO)],
	'05_mano_andar_ida_derecha': [('inicio.png', 'espalda_mano', X_DERECHA)],
	'06_mano_andar_vuelta_derecha': [('fin.png', 'frente_mano', X_DERECHA)],
	# el 07 con FINAL (2026-10-19: sin el, Veo apenas hacia diagonal y a veces
	# un humano realista): el mismo sprite, lejos, en el espejo de donde acabo el
	# 05 (Pilgrim_walking_away_from_camera_20261019145842: +554 px en x, pies de
	# 1040 a 855, tamano x0,76). Y ese mismo es el inicio del 08.
	'07_mano_andar_ida_izquierda': [('inicio.png', 'espalda_mano', X_IZQUIERDA),
									('fin.png', 'espalda_mano', X_IZQUIERDA - 554, 0.76, 855)],
	'08_mano_andar_vuelta_izquierda': [('inicio.png', 'espalda_mano', X_IZQUIERDA - 554, 0.76, 855),
									   ('fin.png', 'frente_mano', X_IZQUIERDA)],
}


def pintar_poses():
	os.makedirs(POSES, exist_ok=True)
	args = ['%s:%s:%d:%d' % (n, a, f, b) for n, (a, f, b) in POSES_JUEGO.items()]
	subprocess.run([GODOT, '--path', PROYECTO, 'res://scenes/dev/poses_frontal.tscn', '--', POSES] + args,
				   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=600)


def recorte(nombre):
	"""(RGBA del personaje, x de su eje, fila de sus pies) de una pose."""
	if nombre in LIMPIOS:
		im = Image.open(os.path.join(ANIM, LIMPIOS[nombre])).convert('RGBA')
		a = np.asarray(im)
		filas = np.nonzero((a[..., 3] > 128).any(1))[0]
		return im, im.width / 2.0, int(filas[-1])
	im = Image.open(os.path.join(POSES, nombre + '.png')).convert('RGBA')
	filas = np.nonzero((np.asarray(im)[..., 3] > 128).any(1))[0]
	return im, 600.0, int(filas[-1])


def referencia(nombre, x, escala=1.0, pie_y=PIE_Y):
	im, eje, pie = recorte(nombre)
	if escala != 1.0:
		im = im.resize((round(im.width * escala), round(im.height * escala)), Image.LANCZOS)
		eje, pie = eje * escala, pie * escala
	lienzo = Image.new('RGBA', (W, H), VERDE + (255,))
	lienzo.alpha_composite(im, (int(round(x - eje)), int(round(pie_y - pie))))
	return lienzo.convert('RGB')


def fuente(tam):
	for f in ['C:/Windows/Fonts/segoeui.ttf', 'C:/Windows/Fonts/arial.ttf']:
		if os.path.exists(f):
			return ImageFont.truetype(f, tam)
	return ImageFont.load_default()


def hoja_angulos(salida):
	"""Los angulos del personaje en HD (del giro del juego): de frente, tres cuartos,
	perfil, tres cuartos de espaldas y de espaldas; con el baculo y guardado."""
	celda = (520, 760)
	hoja = Image.new('RGB', (celda[0] * 5, celda[1] * 2 + 60), (70, 70, 70))
	d = ImageDraw.Draw(hoja)
	f = fuente(30)
	titulos = ['de frente', '3/4 de frente', 'perfil', '3/4 de espaldas', 'de espaldas']
	for fila, modo in enumerate(['mano', 'guardado']):
		for c in range(5):
			im, eje, pie = recorte('ang_%s_%d' % (modo, c))
			x0 = int(c * celda[0] + celda[0] / 2 - eje)
			y0 = 60 + fila * celda[1] + celda[1] - 30 - pie
			hoja.paste(im, (x0, y0), im)
			if fila == 0:
				d.text((c * celda[0] + 20, 12), titulos[c], fill=(235, 235, 235), font=f)
	d.text((10, 60 + celda[1] - 40), 'baculo en la mano', fill=(235, 235, 235), font=f)
	d.text((10, 60 + 2 * celda[1] - 40), 'baculo guardado (como lo pinta el juego)', fill=(235, 235, 235), font=f)
	hoja.save(os.path.join(salida, 'angulos_del_peregrino_HD.png'))


def hoja_referencias(salida):
	"""Todas las referencias en una hoja, con su video."""
	pequenas = []
	for carpeta, refs in VIDEOS.items():
		for archivo, *_ in refs:
			pequenas.append((carpeta + '/' + archivo, Image.open(os.path.join(salida, carpeta, archivo))))
	cols = 4
	tw, th = 640, 360
	filas = (len(pequenas) + cols - 1) // cols
	hoja = Image.new('RGB', (cols * tw, filas * (th + 44)), (40, 40, 40))
	d = ImageDraw.Draw(hoja)
	f = fuente(22)
	for i, (titulo, im) in enumerate(pequenas):
		x, y = (i % cols) * tw, (i // cols) * (th + 44)
		hoja.paste(im.resize((tw, th), Image.LANCZOS), (x, y + 44))
		d.text((x + 8, y + 10), titulo, fill=(235, 235, 235), font=f)
	hoja.save(os.path.join(salida, 'hoja_de_referencias.png'))


def prompts(salida):
	"""prompt_diagonal.txt partido: cada bloque "### <carpeta>" a su prompt.txt
	(y el LEEME arriba del todo)."""
	texto = open(os.path.join(AQUI, 'prompt_diagonal.txt'), encoding='utf-8').read()
	for bloque in texto.split('\n### ')[1:]:
		nombre, _, cuerpo = bloque.partition('\n')
		nombre = nombre.strip()
		ruta = os.path.join(salida, 'LEEME.txt') if nombre == 'LEEME' else os.path.join(salida, nombre, 'prompt.txt')
		with open(ruta, 'w', encoding='utf-8', newline='\r\n') as f:
			f.write(cuerpo.strip() + '\n')


def para_que_es(salida):
	"""El cruce (con la casa) y por donde van las diagonales: los caminos de
	peregrino_cruce.gd."""
	im = Image.open(os.path.join(ANIM, '..', 'cruce_bosque', 'fondo_compuesto.png')).convert('RGB')
	k = W / im.width
	im = im.resize((W, H), Image.LANCZOS)
	d = ImageDraw.Draw(im)
	caminos = {
		'centro (ya esta: de espaldas)': ([(1480, 1490), (1470, 1400), (1478, 1290), (1490, 1190), (1500, 1062)], (230, 230, 230)),
		'izquierda ~35 grados (07, 08 y la derecha espejada con el baculo guardado)':
			([(1480, 1490), (1420, 1430), (1200, 1350), (900, 1285), (600, 1225), (300, 1160), (60, 1105)], (255, 190, 60)),
		'derecha ~25-30 grados (01-06)':
			([(1480, 1490), (1560, 1430), (1790, 1355), (2040, 1275), (2240, 1195), (2410, 1105), (2530, 1015), (2610, 945)], (90, 200, 255)),
	}
	f = fuente(30)
	y = 20
	for nombre, (puntos, color) in caminos.items():
		pts = [(x * k, yy * k) for x, yy in puntos]
		d.line(pts, fill=color, width=7)
		(x1, y1), (x2, y2) = pts[-2], pts[-1]
		v = np.array([x2 - x1, y2 - y1])
		v = v / np.linalg.norm(v)
		n = np.array([-v[1], v[0]])
		p = np.array([x2, y2])
		d.polygon([tuple(p + v * 20), tuple(p - v * 18 + n * 16), tuple(p - v * 18 - n * 16)], fill=color)
		d.text((20, y), nombre, fill=color, font=f)
		y += 42
	im.save(os.path.join(salida, 'para_que_es.png'))


def main():
	if '--sin-godot' not in sys.argv:
		pintar_poses()
	os.makedirs(DESCARGAS, exist_ok=True)
	for carpeta, refs in VIDEOS.items():
		os.makedirs(os.path.join(DESCARGAS, carpeta), exist_ok=True)
		for archivo, pose, x, *lejos in refs:
			referencia(pose, x, *lejos).save(os.path.join(DESCARGAS, carpeta, archivo))
			print('  %s/%s  <- %s (x %d %s)' % (carpeta, archivo, pose, x, lejos))
	hoja_angulos(DESCARGAS)
	hoja_referencias(DESCARGAS)
	prompts(DESCARGAS)
	para_que_es(DESCARGAS)
	print('->', DESCARGAS)


if __name__ == '__main__':
	main()

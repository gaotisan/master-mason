"""Segunda tanda del peregrino en diagonal (prompt_diagonal_v2.txt): carpetas en
Descargas/peregrino_diagonal_v2/ con su prompt.txt, inicio.png y fin.png.

LAS REFERENCIAS VAN DONDE EMPIEZA Y ACABA EL MOVIMIENTO (2026-10-20, el usuario:
con el fin en el mismo sitio que el inicio, el 01 giraba "andando en el sitio" y
se quedaba ahi). Posicion y tamano, los de las tomas buenas en 1080p con esa
camara (peregrino_diagonal/ida_sb y vuelta_sb, medidas.json: capucha-pies, eje y
fila de los pies), espejadas en x: alejandose va hacia ARRIBA A LA IZQUIERDA, como
el camino izquierdo del cruce (ya no hay que espejar los videos).
  CERCA  capucha-pies 630, eje x 1225, pies en la fila 1037 (el principio del 01)
  LEJOS  capucha-pies 491, eje x  739, pies en la fila 871  (el 01 tras ~5 s andando)
  CENTRO (correr: la camara va con el, se queda en el sitio) 630, x 960, fila 1037
Las poses (los masters del juego, peregrino_secuencia_frontal_sin/04_limpios):
  espaldas  reposo_espalda_sb_000            de espaldas recto (nuestro reposo)
  frente    reposo_frente_sb_000             de frente recto
  tq_lejos  vuelta_sb_042 espejado (145 g)   parado de tres cuartos de espaldas,
                                             mirando arriba a la izquierda
  tq_cerca  vuelta_sb_015 (32 g)             parado de tres cuartos de frente,
                                             mirando abajo a la derecha
Croma #24D732, 1920x1080.

  python referencias_diagonal_v2.py
"""
import os
import shutil

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
DESCARGAS = os.path.join(os.path.expanduser('~'), 'Downloads', 'peregrino_diagonal_v2')
LIMPIOS = os.path.join(ANIM, 'peregrino_secuencia_frontal_sin', '04_limpios')
VERDE = (36, 215, 50)
W, H = 1920, 1080

POSES = {'espaldas': ('reposo_espalda_sb_000', False), 'frente': ('reposo_frente_sb_000', False),
		 'tq_lejos': ('vuelta_sb_042', True), 'tq_cerca': ('vuelta_sb_015', False)}
SITIOS = {'cerca': (1225, 1037, 630), 'lejos': (739, 871, 491), 'centro': (960, 1037, 630)}

# carpeta -> [(archivo, pose, sitio)]
VIDEOS = {
	'01_arrancar_de_espaldas_a_la_diagonal': [('inicio.png', 'espaldas', 'cerca'), ('fin.png', 'tq_lejos', 'lejos')],
	'02_volverse_y_volver_en_diagonal': [('inicio.png', 'tq_lejos', 'lejos'), ('fin.png', 'tq_cerca', 'cerca')],
	'03_andar_alejandose': [('inicio.png', 'tq_lejos', 'cerca'), ('fin.png', 'tq_lejos', 'lejos')],
	'04_andar_acercandose': [('inicio.png', 'tq_cerca', 'lejos'), ('fin.png', 'tq_cerca', 'cerca')],
	'05_correr_alejandose': [('inicio_y_fin.png', 'tq_lejos', 'centro')],
	'06_correr_acercandose': [('inicio_y_fin.png', 'tq_cerca', 'centro')],
}


def referencia(pose, sitio):
	nombre, espejo = POSES[pose]
	x, pie_y, alto = SITIOS[sitio]
	im = Image.open(os.path.join(LIMPIOS, nombre + '.png')).convert('RGBA')
	if espejo:
		im = im.transpose(Image.FLIP_LEFT_RIGHT)
	a = np.asarray(im)[..., 3] > 128
	ys = np.nonzero(a.any(1))[0]
	top, pie = int(ys.min()), int(ys.max())
	# el eje: el centro del tronco (como montar.py), no el de la casilla
	banda = a[top + int(0.2 * (pie - top)):top + int(0.5 * (pie - top))]
	eje = float(np.median(np.nonzero(banda)[1]))
	s = alto / float(pie - top)
	im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
	lienzo = Image.new('RGBA', (W, H), VERDE + (255,))
	lienzo.alpha_composite(im, (int(round(x - eje * s)), int(round(pie_y - pie * s))))
	return lienzo.convert('RGB')


def main():
	if os.path.isdir(DESCARGAS):
		for d in os.listdir(DESCARGAS):
			if d.startswith(('01_', '02_', '03_', '04_', '05_', '06_')):
				shutil.rmtree(os.path.join(DESCARGAS, d))
	for carpeta, refs in VIDEOS.items():
		os.makedirs(os.path.join(DESCARGAS, carpeta), exist_ok=True)
		for archivo, pose, sitio in refs:
			referencia(pose, sitio).save(os.path.join(DESCARGAS, carpeta, archivo))
	texto = open(os.path.join(AQUI, 'prompt_diagonal_v2.txt'), encoding='utf-8').read()
	for bloque in texto.split('\n### ')[1:]:
		nombre, _, cuerpo = bloque.partition('\n')
		nombre = nombre.strip()
		ruta = os.path.join(DESCARGAS, 'LEEME.txt') if nombre == 'LEEME' else os.path.join(DESCARGAS, nombre, 'prompt.txt')
		with open(ruta, 'w', encoding='utf-8', newline='\r\n') as f:
			f.write(cuerpo.strip() + '\n')
	# una hoja con todas, superpuestas inicio y fin, para revisar de un vistazo
	hoja = Image.new('RGB', (W // 2 * 3, H // 2 * 2))
	for i, (carpeta, refs) in enumerate(VIDEOS.items()):
		ims = [Image.open(os.path.join(DESCARGAS, carpeta, r[0])) for r in refs]
		m = ims[0] if len(ims) == 1 else Image.blend(ims[0], ims[1], 0.5)
		hoja.paste(m.resize((W // 2, H // 2)), ((i % 3) * W // 2, (i // 3) * H // 2))
	hoja.save(os.path.join(DESCARGAS, 'hoja_inicio_y_fin.png'))
	print('->', DESCARGAS)


if __name__ == '__main__':
	main()

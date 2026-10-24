"""PRUEBA DE FALSO 3D (2026-10-22): de los fotogramas de montar.py a las animaciones de
las dos diagonales (las otras dos son su espejo, en el juego):
  andar_no   el bucle de andar alejandose hacia arriba a la izquierda (alejarse)
  andar_se   el bucle de andar acercandose hacia abajo a la derecha (volver)
  reposo_no  quieto en diagonal de espaldas: la pose de pies juntos del bucle (el final
             del video queda casi de espaldas recto: al arrancar cambiaria de angulo),
             respirando
  reposo_se  quieto de tres cuartos de frente: el final del video (de pie, en el angulo
             del andar), respirando
Los bucles: el tramo que mejor cierra (periodo de dos pasos), cerrado por flujo optico
como en la primera diagonal (../peregrino_diagonal/secuencia.py, de donde salen
mezcla, pisadas, pies juntos y la respiracion). La ficha dice el avance (alturas de
persona por fotograma: la velocidad del video, para que los pies no patinen).

    python secuencia.py
-> assets/characters/peregrino_falso3d/falso3d_N.png, resources/characters/
   peregrino_falso3d.tres, assets/characters/peregrino/falso3d.json
"""
import importlib.util
import io
import json
import os
import shutil

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
PROYECTO = os.path.normpath(os.path.join(ANIM, '..', '..', '..'))
CARPETA = 'assets/characters/peregrino_falso3d'
SALIDA = os.path.join(PROYECTO, CARPETA)
TRES = os.path.join(PROYECTO, 'resources', 'characters', 'peregrino_falso3d.tres')
FICHA = os.path.join(PROYECTO, 'assets', 'characters', 'peregrino', 'falso3d.json')

_spec = importlib.util.spec_from_file_location('secuencia_diagonal', os.path.join(ANIM, 'peregrino_diagonal', 'secuencia.py'))
SEC = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(SEC)
_spec = importlib.util.spec_from_file_location('montar_falso3d', os.path.join(AQUI, 'montar.py'))
MON = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(MON)

FPS = 24
FPS_REPOSO = 12
M = 4
# Donde anda de verdad (velocidad estable), para buscar el bucle: (desde, hasta)
ANDA = {'alejarse': (50, 166), 'volver': (66, 162)}
PERIODO = (24, 52)          # dos pasos, en fotogramas (alejarse anda mas despacio: ~0,95 s el paso)
QUIETO_SE = ('volver', 186)

_cache = {}


def leer(clave, k):
	if (clave, k) not in _cache:
		_cache[(clave, k)] = Image.open(os.path.join(AQUI, clave, 'c_%03d.png' % k)).convert('RGBA')
	return _cache[(clave, k)]


def dif(A, B):
	return float(np.abs(SEC.pequeno(A) - SEC.pequeno(B)).mean())


def buscar_bucle(clave):
	"""(t, periodo) del tramo que mejor cierra: el fotograma t+P casi igual al t,
	comparado con lo que cambia de un fotograma al siguiente."""
	a, b = ANDA[clave]
	paso = np.mean([dif(leer(clave, k), leer(clave, k + 1)) for k in range(a, b)])
	mejor = None
	for P in range(PERIODO[0], PERIODO[1] + 1):
		for t in range(a, b - P + 1):
			d = dif(leer(clave, t), leer(clave, t + P))
			if mejor is None or d < mejor[0]:
				mejor = (d, t, P)
	print('%-9s bucle %d..%d (periodo %d): cierre %.4f, paso medio %.4f' % (clave, mejor[1], mejor[1] + mejor[2] - 1, mejor[2], mejor[0], paso))
	return mejor[1], mejor[2]


def bucle(clave, t, P):
	out = []
	for j in range(P):
		if j < M:
			out.append(SEC.mezcla(leer(clave, t + P + j), leer(clave, t + j), (j + 1) / (M + 1)))
		else:
			out.append(leer(clave, t + j))
	return out


def velocidad(clave, t, P):
	m = json.load(open(os.path.join(AQUI, clave, 'medidas.json')))
	cx, h = np.array(m['cx']), np.array(m['h'])
	w = float(m['ancho'])
	ts = np.arange(max(0, t - P // 2), min(len(h), t + P + P // 2))
	X = (cx[ts] - w / 2) / h[ts]
	Z = SEC.F_VIDEO * w / 1280 / h[ts]
	v = np.polyfit(np.arange(len(ts)), np.c_[X, Z], 1)[0]
	return float(np.hypot(*v))


def respira(base):
	ida = SEC.respiracion(base)
	return ida + ida[-2:0:-1]


def escribir(anims, fps):
	if os.path.isdir(SALIDA):
		shutil.rmtree(SALIDA)
	os.makedirs(SALIDA)
	todos = {(n, j): im for n, fr in anims.items() for j, im in enumerate(fr)}
	cajas = {k: SEC.recorte(im) for k, im in todos.items()}
	paginas, sitio = SEC.paginar(cajas)
	donde = {}
	for p, ks in enumerate(paginas):
		ancho = max(sitio[k][1] + cajas[k][2] for k in ks)
		alto = max(sitio[k][2] + cajas[k][3] for k in ks)
		ancho, alto = -(-ancho // SEC.BLOQUE) * SEC.BLOQUE, -(-alto // SEC.BLOQUE) * SEC.BLOQUE
		atlas = np.zeros((alto, ancho, 4), np.uint8)
		nombre = 'falso3d_%d' % p
		for k in ks:
			dx, dy, w, h = cajas[k]
			_, x, y = sitio[k]
			atlas[y:y + h, x:x + w] = np.asarray(todos[k])[dy:dy + h, dx:dx + w]
			donde[k] = (nombre, x, y, w, h, dx, dy)
		Image.fromarray(atlas).save(os.path.join(SALIDA, nombre + '.png'), optimize=True)
		lineas = ['[remap]', '', 'importer="texture"', 'type="CompressedTexture2D"', '', '[deps]', '',
				  'source_file="res://%s/%s.png"' % (CARPETA, nombre), '', '[params]', '']
		lineas += ['%s=%s' % kv for kv in SEC.IMPORT_HOJA]
		io.open(os.path.join(SALIDA, nombre + '.png.import'), 'w', encoding='utf-8', newline='\n').write('\n'.join(lineas) + '\n')
		print('   %-12s %5dx%-5d %3d fotogramas' % (nombre, ancho, alto, len(ks)))
	cw, ch = MON.CAS
	ext, sub, bloques, tex_de = [], [], [], {}
	for nombre, frames in anims.items():
		refs = []
		for j in range(len(frames)):
			png, x, y, w, h, dx, dy = donde[(nombre, j)]
			if png not in tex_de:
				tex_de[png] = 'tex_%d' % (len(tex_de) + 1)
				ext.append('[ext_resource type="Texture2D" path="res://%s/%s.png" id="%s"]' % (CARPETA, png, tex_de[png]))
			ida = 'a_%s_%d' % (nombre, j)
			sub.append('[sub_resource type="AtlasTexture" id="%s"]\natlas = ExtResource("%s")\n'
					   'region = Rect2(%d, %d, %d, %d)\nmargin = Rect2(%d, %d, %d, %d)\n'
					   % (ida, tex_de[png], x, y, w, h, dx, dy, cw - w, ch - h))
			refs.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % ida)
		bloques.append('{\n"frames": [%s],\n"loop": true,\n"name": &"%s",\n"speed": %.1f\n}'
					   % (', '.join(refs), nombre, fps[nombre]))
	txt = ('[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n' % (len(ext) + len(sub) + 1)
		   + '\n'.join(ext) + '\n\n' + '\n'.join(sub)
		   + '\n[resource]\nanimations = [' + ', '.join(bloques) + ']\n')
	io.open(TRES, 'w', encoding='utf-8', newline='\n').write(txt)
	print('->', TRES, '(%d fotogramas)' % len(todos))


def main():
	anims, fps = {}, {}
	ficha = {'fps': FPS, 'fps_reposo': FPS_REPOSO, 'casilla': list(MON.CAS), 'suelo': MON.SUELO, 'eje': MON.EJE,
			 'alto': MON.ALTO, 'anims': {}}

	def poner(nombre, frames, f=FPS, **datos):
		anims[nombre] = frames
		fps[nombre] = f
		ficha['anims'][nombre] = dict(n=len(frames), **datos)

	loops = {}
	for clave, dir_ in (('alejarse', 'no'), ('volver', 'se')):
		t, P = buscar_bucle(clave)
		fr = bucle(clave, t, P)
		loops[dir_] = fr
		v = velocidad(clave, t, P)
		poner('andar_' + dir_, fr, pisadas=SEC.pisadas(fr), juntos=SEC.pies_juntos(fr), avance=round(v, 5), video=[clave, t, P])
		print('andar_%s: %.4f alturas/fotograma, pisadas %s, juntos %s' % (dir_, v, ficha['anims']['andar_' + dir_]['pisadas'], ficha['anims']['andar_' + dir_]['juntos']))
	j0 = ficha['anims']['andar_no']['juntos'][0]
	poner('reposo_no', respira(loops['no'][j0]), FPS_REPOSO, base=['andar_no', j0])
	clave, k = QUIETO_SE
	poner('reposo_se', respira(leer(clave, k)), FPS_REPOSO, base=[clave, k])
	escribir(anims, fps)
	json.dump(ficha, open(FICHA, 'w'), indent=1)
	print('->', FICHA)


if __name__ == '__main__':
	main()

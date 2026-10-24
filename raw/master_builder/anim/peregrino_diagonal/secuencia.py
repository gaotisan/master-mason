"""El peregrino en TRES CUARTOS (el plano del camino izquierdo del cruce): de los
fotogramas de montar.py a todas sus animaciones (hojas, SpriteFrames y ficha),
para scripts/characters/peregrino_tres_cuartos.gd.

2026-10-20. Antes (2026-10-19) los bucles en diagonal eran una "piel" del
peregrino de frente dentro de un plano frontal: al pararse o girar volvia el de
frente y no quedaba profesional. Ahora la diagonal es un plano propio y el
peregrino de tres cuartos lo hace todo en el: quieto (respirando), arrancar,
andar, parar, darse la vuelta, correr (con el baculo guardado). Todo mira hacia
la IZQUIERDA de la pantalla al alejarse (el camino va de abajo a la derecha a
arriba a la izquierda):
  con baculo (cb)  07 ida_cb_izq y 08 vuelta_cb_izq, tal cual
  sin baculo (sb)  01 ida_sb, 02 vuelta_sb, 03 y 04 correr, ESPEJADOS (no llevan
                   nada en las manos); el baculo y la correa a la espalda se
                   pintan despues de espejar (lo que pinta el juego: scenes/dev/
                   poses_frontal.tscn con el cuerpo invisible), asi va al hombro
                   derecho como en todas las vistas.

Animaciones (m = cb / sb):
  reposo_lejos_m   quieto de tres cuartos de espaldas: el fotograma de pie del
                   principio de la vuelta (08 / 02, el 4) con la respiracion
                   dibujada (como el reposo de frente: sube hombros y pecho, 2,5 s)
  reposo_cerca_m   quieto hacia la camara: el fotograma "inv" de la vuelta (acabado
                   el giro, de pie), respirando
  arranque_lejos_m del reposo al bucle (flujo optico, 6), entra en "entra"
  andar_lejos_m / andar_cerca_m   los bucles (cerrados por flujo)
  parada_lejos_m_0 / _1   de los pies juntos del bucle al reposo (flujo, 6)
  parada_cerca_m_0 / _1   de los pies juntos del bucle de cerca al reposo (flujo, 6)
  vuelta_m         de quieto de espaldas a andando hacia la camara (el video: el
                   giro y los primeros pasos, hasta el bucle de cerca). Arrancar
                   hacia la camara desde quieto: la vuelta desde "inv"; volverse de
                   cerca a lejos: la vuelta AL REVES desde "inv" hasta el principio
  correr_lejos_sb / correr_cerca_sb   los bucles de correr; a_correr_X / de_correr_X
                   del andar al correr y al reves (flujo, 4)
La ficha dice por animacion: fps, pisadas, pies juntos, "avance" (alturas de
persona por fotograma a lo largo del camino: la velocidad del video, para que los
pies no patinen) y las entradas y salidas.

    python secuencia.py
"""
import importlib.util
import io
import json
import os
import shutil

import cv2
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
PROYECTO = os.path.normpath(os.path.join(ANIM, '..', '..', '..'))
SALIDA = os.path.join(PROYECTO, 'assets', 'characters', 'peregrino_diagonal')
TRES = os.path.join(PROYECTO, 'resources', 'characters', 'peregrino_diagonal.tres')
FICHA = os.path.join(PROYECTO, 'assets', 'characters', 'peregrino', 'diagonal.json')
POSES = os.path.join(ANIM, '_fuentes', 'poses_diagonal')
SIN = os.path.join(ANIM, 'peregrino_secuencia_frontal_sin', '04_limpios')

_spec = importlib.util.spec_from_file_location('montar_diagonal', os.path.join(AQUI, 'montar.py'))
MON = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(MON)
_spec = importlib.util.spec_from_file_location('puente', os.path.join(ANIM, 'peregrino_puentes_frontal', 'puente.py'))
P = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(P)

FPS = 24
FPS_REPOSO = 12
M = 4                 # fotogramas del principio del bucle cerrados por flujo
F_VIDEO = 1256.0      # focal de los videos (1280 de ancho, ~54 grados): para la velocidad
# Los bucles (video, desde, periodo), los de montar.py / la tanda anterior.
BUCLES = {
	'andar_lejos_cb': ('ida_cb_izq', 57, 28), 'andar_cerca_cb': ('vuelta_cb_izq', 75, 30),
	'andar_lejos_sb': ('ida_sb', 141, 29), 'andar_cerca_sb': ('vuelta_sb', 99, 33),
	'correr_lejos_sb': ('correr_lejos_sb', 85, 22), 'correr_cerca_sb': ('correr_cerca_sb', 105, 24),
}
ESPEJO = {'ida_sb', 'vuelta_sb', 'correr_lejos_sb', 'correr_cerca_sb'}
# Donde se para (y de donde arranca): los fotogramas del bucle con LOS DOS PIES
# APOYADOS, elegidos a ojo (pies_apoyados.py y una hoja de los pies de cada
# fotograma). 2026-10-20: los de pies_juntos() (pies mas juntos) dejaban un pie en
# el aire en la mitad de las paradas (el usuario: "se para con los pies en alto").
# LA PARADA DE VERDAD (2026-10-20, el usuario: parado en un fotograma del paso "no
# se para en pose de parado"): el final del video, que frena y se queda de pie, en
# diagonal (el 01: frena desde el 206, de pie con los pies juntos en el 232). Solo
# donde el video la tiene buena: el 07 salta al final a nuestro sprite de espaldas.
# (video, primer fotograma de la frenada, el de pie)
PARADAS = {'sb': ('ida_sb', 206, 232)}
APOYADOS = {'andar_lejos_sb': [13, 28], 'andar_cerca_sb': [0, 15],
			'andar_lejos_cb': [0, 7], 'andar_cerca_cb': [7, 19]}
# La vuelta: (video, primer fotograma (de pie), ultimo (justo antes del bucle de
# cerca), el fotograma "inv": acabado el giro, antes de los pasos hacia la camara)
VUELTAS = {'cb': ('vuelta_cb_izq', 10, 74, 62), 'sb': ('vuelta_sb', 13, 98, 66)}
# Velocidad de correr: el video va con la camara (no se mide); lo de andar por esto.
CORRER = 2.3
SEPARACION = 2
BLOQUE = 4
PAGINA = 4096
IMPORT_HOJA = [('compress/mode', '2'), ('compress/high_quality', 'true'), ('compress/lossy_quality', '0.7'),
			   ('compress/uastc_level', '0'), ('compress/rdo_quality_loss', '0.0'), ('compress/hdr_compression', '1'),
			   ('compress/normal_map', '0'), ('compress/channel_pack', '0'), ('mipmaps/generate', 'false'),
			   ('mipmaps/limit', '-1'), ('roughness/mode', '0'), ('roughness/src_normal', '""'),
			   ('process/channel_remap/red', '0'), ('process/channel_remap/green', '1'),
			   ('process/channel_remap/blue', '2'), ('process/channel_remap/alpha', '3'),
			   ('process/fix_alpha_border', 'true'), ('process/premult_alpha', 'false'),
			   ('process/normal_map_invert_y', 'false'), ('process/hdr_as_srgb', 'false'),
			   ('process/hdr_clamp_exposure', 'false'), ('process/size_limit', '0'), ('detect_3d/compress_to', '0')]

_cache = {}


def leer(clave, k):
	"""Fotograma k del video (espejado si toca), como PIL RGBA."""
	if (clave, k) not in _cache:
		im = Image.open(os.path.join(AQUI, clave, 'c_%03d.png' % k)).convert('RGBA')
		if clave in ESPEJO:
			im = im.transpose(Image.FLIP_LEFT_RIGHT)
		_cache[(clave, k)] = im
	return _cache[(clave, k)]


def mezcla(A, B, t):
	a, b = P.premul(A), P.premul(B)
	a8 = (a[..., :3] * 255).astype(np.uint8)
	b8 = (b[..., :3] * 255).astype(np.uint8)
	fab, fba = P.flujo(a8, b8), P.flujo(b8, a8)
	m = (1 - t) * P.deformar(a, fab, t) + t * P.deformar(b, fba, 1 - t)
	al = np.clip(m[..., 3:], 1e-4, 1)
	rgb = np.where(m[..., 3:] > 1e-4, m[..., :3] / al, 0)
	return Image.fromarray((np.dstack([rgb, m[..., 3]]) * 255).round().clip(0, 255).astype(np.uint8), 'RGBA')


def puente(A, B, n):
	"""n fotogramas de A a B (sin A ni B), por flujo optico."""
	return [mezcla(A, B, k / (n + 1)) for k in range(1, n + 1)]


def pequeno(im):
	a = np.asarray(im.resize((im.width // 3, im.height // 3), Image.BOX)).astype(np.float32) / 255
	a[..., :3] *= a[..., 3:]
	return a


def bucle(clave, t, Pn):
	out = []
	for j in range(Pn):
		if j < M:
			out.append(mezcla(leer(clave, t + Pn + j), leer(clave, t + j), (j + 1) / (M + 1)))
		else:
			out.append(leer(clave, t + j))
	return out


def pies(im):
	"""(separacion de los pies, diferencia de altura entre ellos) en la franja de abajo."""
	al = np.asarray(im)[..., 3] > 128
	ys = np.nonzero(al.any(1))[0]
	yb, top = ys.max(), ys.min()
	h = yb - top
	banda = al[yb - int(0.06 * h):yb + 1]
	xs = np.nonzero(banda.any(0))[0]
	cx = int(np.median(np.nonzero(al[top + int(0.3 * h):top + int(0.5 * h)])[1]))
	izq = np.nonzero(al[:, :cx].any(1))[0].max()
	der = np.nonzero(al[:, cx:].any(1))[0].max()
	return xs.max() - xs.min(), abs(int(izq) - int(der))


def pies_juntos(frames):
	"""Los dos fotogramas del ciclo con los pies mas juntos y en el suelo (uno por paso)."""
	v = np.array([s + 2 * d for s, d in (pies(im) for im in frames)], float)
	n = len(v)
	i1 = int(np.argmin(v))
	cerca = [(v[k % n], k % n) for k in range(i1 + n // 2 - n // 6, i1 + n // 2 + n // 6 + 1)]
	return [i1, min(cerca)[1]]


def pisadas(frames):
	"""Los dos fotogramas del ciclo con los pies mas separados (el pie que planta)."""
	v = np.array([s for s, _ in (pies(im) for im in frames)], float)
	n = len(v)
	i1 = int(np.argmax(v))
	cerca = [(-v[k % n], k % n) for k in range(i1 + n // 2 - n // 6, i1 + n // 2 + n // 6 + 1)]
	return sorted([i1, min(cerca)[1]])


def velocidad(clave, t, Pn):
	"""Alturas de persona por fotograma, en el suelo (X lateral y Z de profundidad del
	video, con su focal), en el tramo del bucle."""
	m = json.load(open(os.path.join(AQUI, clave, 'medidas.json')))
	cx, h = np.array(m['cx']), np.array(m['h'])
	w = float(m.get('ancho', 1280))
	n = len(h)
	ts = np.arange(max(0, t - Pn // 2), min(n, t + Pn + Pn // 2))
	X = (cx[ts] - w / 2) / h[ts]
	Z = F_VIDEO * w / 1280 / h[ts]
	v = np.polyfit(np.arange(len(ts)), np.c_[X, Z], 1)[0]
	return float(np.hypot(*v))


def avance_vuelta(clave, a, b):
	"""Lo que avanza por fotograma (alturas) en la vuelta: por el video, suavizado."""
	m = json.load(open(os.path.join(AQUI, clave, 'medidas.json')))
	cx, h = np.array(m['cx']), np.array(m['h'])
	w = float(m.get('ancho', 1280))
	X = (cx - w / 2) / h
	Z = F_VIDEO * w / 1280 / h
	d = np.hypot(np.diff(X), np.diff(Z))
	d = np.convolve(np.r_[d[0], d], np.ones(9) / 9, mode='same')
	return [round(float(d[k]), 5) for k in range(a, b + 1)]


# ------------------------------------------------------------------ respiracion
def respiracion(base, n=16, sube=3.5, ensancha=0.012):
	"""La mitad que inspira (n fotogramas, 0 = el base): de la cadera para arriba
	sube hasta `sube` px y el pecho se ensancha; solo en el ancho del cuerpo (el
	baculo en la mano, a un lado, no se mueve)."""
	a = P.premul(base)
	op = a[..., 3] > 0.5
	ys = np.nonzero(op.any(1))[0]
	top, pie = int(ys.min()), int(ys.max())
	alto = pie - top
	y_hom, y_cad = top + 0.24 * alto, top + 0.52 * alto
	banda = op[int(top + 0.30 * alto):int(top + 0.45 * alto)]
	xs = np.nonzero(banda)[1]
	cx = float(np.median(xs))
	semi = 0.5 * (np.percentile(xs, 92) - np.percentile(xs, 8))
	h, w = op.shape
	yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
	mascara = np.clip((semi * 1.15 - np.abs(xx - cx)) / 14.0, 0, 1)
	t = np.clip((y_cad - yy) / (y_cad - y_hom), 0, 1)
	sub = t * t * (3 - 2 * t)
	y0 = top + 0.20 * alto
	pecho = np.where((yy > y0) & (yy < top + 0.52 * alto), np.clip(np.sin(np.pi * (yy - y0) / (0.32 * alto)), 0, 1), 0)
	out = []
	for k in range(n):
		s_ = (1 - np.cos(np.pi * k / (n - 1))) / 2
		dy = -sube * sub * s_ * mascara
		dx = (xx - cx) * ensancha * pecho * s_ * mascara
		b = cv2.remap(a, (xx - dx).astype(np.float32), (yy - dy).astype(np.float32), cv2.INTER_LINEAR, borderValue=0)
		al = np.clip(b[..., 3:], 1e-4, 1)
		rgb = np.where(b[..., 3:] > 1e-4, b[..., :3] / al, 0)
		out.append(Image.fromarray((np.dstack([rgb, b[..., 3]]) * 255).round().clip(0, 255).astype(np.uint8), 'RGBA'))
	return out


# ------------------------------------------------------------------ el baculo a la espalda (sb)
def capucha(a):
	al = (a[..., 3] > 128).astype(np.uint8)
	sin_palo = cv2.morphologyEx(al, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (11, 11)))
	ys = np.nonzero(sin_palo.any(1))[0]
	top, pie = ys.min(), ys.max()
	hsv = cv2.cvtColor(np.ascontiguousarray(a[..., :3]), cv2.COLOR_RGB2HSV)
	gris = (sin_palo > 0) & (hsv[..., 1] < 50) & (hsv[..., 2] > 90)
	gris[int(top + 0.2 * (pie - top)):] = False
	xs = np.nonzero(gris)[1]
	return (float(np.median(xs)) if len(xs) else float(np.median(np.nonzero(sin_palo)[1]))), float(top)


def capa_del_baculo(cara):
	"""El baculo y la correa como los pinta el juego, solos, en la casilla de aqui, y
	donde estaba la capucha (de frente, solo lo que asoma fuera de la silueta)."""
	k, pose = (58, 'baculo_espalda_58') if cara == 'lejos' else (5, 'baculo_frente_5')
	juego = np.asarray(Image.open(os.path.join(POSES, pose + '.png')).convert('RGBA')).copy()
	juego = juego[1100 - 757:1100 - 757 + 800, 600 - 292:600 - 292 + 584].copy()
	sin = np.asarray(Image.open(os.path.join(SIN, 'vuelta_sb_%03d.png' % k)).convert('RGBA'))
	if cara == 'cerca':
		cuerpo = cv2.dilate((sin[..., 3] > 60).astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
		juego[..., 3] = np.where(cuerpo, 0, juego[..., 3])
	out = cv2.resize(juego, (MON.CAS[0], MON.CAS[1]), interpolation=cv2.INTER_AREA)
	ref = cv2.resize(sin, (MON.CAS[0], MON.CAS[1]), interpolation=cv2.INTER_AREA)
	return out, capucha(ref)


def con_baculo(im, capa, ancla, ancho=1.0):
	"""El baculo encima, en el sitio de la capucha; `ancho` < 1 lo estrecha (de canto,
	en la vuelta)."""
	a = np.asarray(im).copy()
	cx, top = capucha(a)
	m = np.float32([[ancho, 0, cx - ancla[0] * ancho], [0, 1, top - ancla[1]]])
	c = cv2.warpAffine(capa, m, (a.shape[1], a.shape[0]), flags=cv2.INTER_LINEAR, borderValue=0)
	fondo = Image.fromarray(a, 'RGBA')
	fondo.alpha_composite(Image.fromarray(c, 'RGBA'))
	return fondo


# ------------------------------------------------------------------ hojas
def recorte(im):
	a = np.asarray(im)
	ys, xs = np.nonzero(a[..., 3] > 0)
	return int(xs.min()), int(ys.min()), int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)


def paginar(cajas):
	paginas, sitio, actual = [], {}, []
	x = y = alto_balda = 0
	for k in sorted(cajas, key=lambda k: -cajas[k][3]):
		w, h = cajas[k][2], cajas[k][3]
		if x + w > PAGINA:
			x = 0
			y += alto_balda + SEPARACION
			alto_balda = 0
		if y + h > PAGINA:
			paginas.append(actual)
			actual, x, y, alto_balda = [], 0, 0, 0
		sitio[k] = (len(paginas), x, y)
		actual.append(k)
		x += w + SEPARACION
		alto_balda = max(alto_balda, h)
	paginas.append(actual)
	return paginas, sitio


def escribir(anims, fps):
	if os.path.isdir(SALIDA):
		shutil.rmtree(SALIDA)
	os.makedirs(SALIDA)
	todos = {(n, j): im for n, fr in anims.items() for j, im in enumerate(fr)}
	cajas = {k: recorte(im) for k, im in todos.items()}
	paginas, sitio = paginar(cajas)
	donde = {}
	for p, ks in enumerate(paginas):
		ancho = max(sitio[k][1] + cajas[k][2] for k in ks)
		alto = max(sitio[k][2] + cajas[k][3] for k in ks)
		ancho, alto = -(-ancho // BLOQUE) * BLOQUE, -(-alto // BLOQUE) * BLOQUE
		atlas = np.zeros((alto, ancho, 4), np.uint8)
		nombre = 'diagonal_%d' % p
		for k in ks:
			dx, dy, w, h = cajas[k]
			_, x, y = sitio[k]
			atlas[y:y + h, x:x + w] = np.asarray(todos[k])[dy:dy + h, dx:dx + w]
			donde[k] = (nombre, x, y, w, h, dx, dy)
		Image.fromarray(atlas).save(os.path.join(SALIDA, nombre + '.png'), optimize=True)
		lineas = ['[remap]', '', 'importer="texture"', 'type="CompressedTexture2D"', '', '[deps]', '',
				  'source_file="res://assets/characters/peregrino_diagonal/%s.png"' % nombre, '', '[params]', '']
		lineas += ['%s=%s' % kv for kv in IMPORT_HOJA]
		io.open(os.path.join(SALIDA, nombre + '.png.import'), 'w', encoding='utf-8', newline='\n').write('\n'.join(lineas) + '\n')
		print('   %-14s %5dx%-5d %3d fotogramas' % (nombre, ancho, alto, len(ks)))
	cw, ch = MON.CAS
	ext, sub, bloques, tex_de = [], [], [], {}
	for nombre, frames in anims.items():
		refs = []
		for j in range(len(frames)):
			png, x, y, w, h, dx, dy = donde[(nombre, j)]
			if png not in tex_de:
				tex_de[png] = 'tex_%d' % (len(tex_de) + 1)
				ext.append('[ext_resource type="Texture2D" path="res://assets/characters/peregrino_diagonal/%s.png" id="%s"]'
						   % (png, tex_de[png]))
			ida = 'a_%s_%d' % (nombre, j)
			sub.append('[sub_resource type="AtlasTexture" id="%s"]\natlas = ExtResource("%s")\n'
					   'region = Rect2(%d, %d, %d, %d)\nmargin = Rect2(%d, %d, %d, %d)\n'
					   % (ida, tex_de[png], x, y, w, h, dx, dy, cw - w, ch - h))
			refs.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % ida)
		bloques.append('{\n"frames": [%s],\n"loop": false,\n"name": &"%s",\n"speed": %.1f\n}'
					   % (', '.join(refs), nombre, fps[nombre]))
	txt = ('[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n' % (len(ext) + len(sub) + 1)
		   + '\n'.join(ext) + '\n\n' + '\n'.join(sub)
		   + '\n[resource]\nanimations = [' + ', '.join(bloques) + ']\n')
	io.open(TRES, 'w', encoding='utf-8', newline='\n').write(txt)
	print('->', TRES, '(%d fotogramas)' % len(todos))


def main():
	capas = {cara: capa_del_baculo(cara) for cara in ('lejos', 'cerca')}

	def baculo(frames, cara):
		capa, ancla = capas[cara]
		return [con_baculo(im, capa, ancla) for im in frames]

	anims, fps = {}, {}
	ficha = {'fps': FPS, 'fps_reposo': FPS_REPOSO, 'casilla': list(MON.CAS), 'suelo': MON.SUELO, 'eje': MON.EJE,
			 'alto': MON.ALTO, 'anims': {}}

	def poner(nombre, frames, f=FPS, **datos):
		anims[nombre] = frames
		fps[nombre] = f
		ficha['anims'][nombre] = dict(n=len(frames), **datos)

	for m in ('cb', 'sb'):
		sb = m == 'sb'
		loops = {}
		for cara in ('lejos', 'cerca'):
			clave, t, Pn = BUCLES['andar_%s_%s' % (cara, m)]
			fr = bucle(clave, t, Pn)
			if sb:
				fr = baculo(fr, cara)
			loops[cara] = fr
			v = velocidad(clave, t, Pn)
			poner('andar_%s_%s' % (cara, m), fr, pisadas=pisadas(fr), juntos=APOYADOS.get('andar_%s_%s' % (cara, m)) or pies_juntos(fr), avance=round(max(v, 0.012), 5))
			print('andar_%s_%s: %s %d..%d, %.4f alturas/fotograma, juntos %s' % (cara, m, clave, t, t + Pn - 1, v,
																			 ficha['anims']['andar_%s_%s' % (cara, m)]['juntos']))
		clave, a, b, inv = VUELTAS[m]
		vuelta = [leer(clave, k) for k in range(a, b + 1)]
		if sb:
			mitad = a + 0.5 * (inv - a)
			fr = []
			for k, im in zip(range(a, b + 1), vuelta):
				if k <= mitad:
					t = (k - a) / max(mitad - a, 1)
					fr.append(con_baculo(im, *capas['lejos'], ancho=max(1 - t, 0.08)))
				else:
					t = min((k - mitad) / max(inv - mitad, 1), 1.0)
					fr.append(con_baculo(im, *capas['cerca'], ancho=max(t, 0.08)))
			vuelta = fr
		# QUIETO EN DIAGONAL (2026-10-20, el usuario: al pararse "no vuelva a frente,
		# queda raro"). El reposo es la pose de pies juntos del propio bucle (de tres
		# cuartos, como anda), respirando; se para terminando el paso con los
		# fotogramas del bucle hasta esos pies juntos (sin fundidos inventados) y
		# arranca con los que siguen.
		bases = {}
		parada = None
		if m in PARADAS:
			# la cola del video: un ciclo de andar (para entrar desde cualquier fotograma
			# del bucle, por su fase) + la frenada hasta quedarse de pie
			pc, s0, fin = PARADAS[m]
			_, t0, Pn = BUCLES['andar_lejos_%s' % m]
			desde = s0 - Pn + 1
			cola = [leer(pc, k) for k in range(desde, fin + 1)]
			if sb:
				cola = baculo(cola, 'lejos')
			entrada = {}
			for i in range(Pn):
				entrada[str((desde + i - t0) % Pn)] = i
			d_l = ficha['anims']['andar_lejos_%s' % m]
			poner('parada_lejos_%s' % m, cola, entrada=entrada, frena=Pn - 1,
				  avance=avance_vuelta(pc, desde, fin), v_bucle=d_l['avance'], fase0=desde - t0)
			parada = cola[-1]
			print('parada_lejos_%s: %s %d..%d (frena desde %d)' % (m, pc, desde, fin, s0))
		for cara in ('lejos', 'cerca'):
			d = ficha['anims']['andar_%s_%s' % (cara, m)]
			n = len(loops[cara])
			if cara == 'lejos' and parada is not None:
				# quieto de pie (el final de la parada); arranca con un puente al
				# fotograma del bucle que mas se le parece
				def dif0(A, B):
					return float(np.abs(pequeno(A) - pequeno(B)).mean())
				jm = min(range(n), key=lambda j: dif0(parada, loops[cara][j]))
				for i in (0, 1):
					bases[(cara, i)] = parada
					poner('reposo_%s_%s_%d' % (cara, m, i), respiracion(parada), FPS_REPOSO)
					poner('arranque_%s_%s_%d' % (cara, m, i), puente(parada, loops[cara][jm], 6), entra=jm,
						  avance=[round(d['avance'] * (q + 1) / 7, 5) for q in range(6)])
				continue
			# dos reposos, uno por cada pose de pies juntos del ciclo (uno por pie): se
			# para en medio paso como mucho
			for i, j0 in enumerate(d['juntos']):
				bases[(cara, i)] = loops[cara][j0]
				poner('reposo_%s_%s_%d' % (cara, m, i), respiracion(loops[cara][j0]), FPS_REPOSO)
				k = 6
				poner('arranque_%s_%s_%d' % (cara, m, i), [loops[cara][(j0 + 1 + q) % n] for q in range(k)],
					  entra=(j0 + 1 + k) % n, avance=[round(d['avance'] * (q + 1) / (k + 1), 5) for q in range(k)])
		# LA VUELTA empieza (y acaba, al reves) en el fotograma del giro que mas se
		# parece al reposo de espaldas (k0) y al de cara (k1), con un puente corto de
		# flujo desde cada reposo; acabado el giro, si no se anda, al reposo de cara.
		def dif(A, B):
			return float(np.abs(pequeno(A) - pequeno(B)).mean())
		k0 = min(range(0, inv - a + 1), key=lambda k: dif(bases[('lejos', 0)], vuelta[k]))
		k1 = min(range(inv - a - 8, len(vuelta)), key=lambda k: dif(bases[('cerca', 0)], vuelta[k]))
		vuelta = vuelta[k0:]
		poner('vuelta_%s' % m, vuelta, inv=inv - a - k0, k1=k1 - k0, avance=avance_vuelta(clave, a + k0, b))
		for i in (0, 1):
			poner('a_vuelta_lejos_%s_%d' % (m, i), puente(bases[('lejos', i)], vuelta[0], 4))
			poner('a_vuelta_cerca_%s_%d' % (m, i), puente(bases[('cerca', i)], vuelta[k1 - k0], 4))
		poner('de_vuelta_lejos_%s' % m, puente(vuelta[0], bases[('lejos', 0)], 4))
		poner('de_vuelta_cerca_%s' % m, puente(vuelta[inv - a - k0], bases[('cerca', 0)], 4))
		print('vuelta_%s: desde %d (k0 %d), giro hasta %d, de cara k1 %d' % (m, a + k0, k0, inv, k1))
	for cara in ('lejos', 'cerca'):
		clave, t, Pn = BUCLES['correr_%s_sb' % cara]
		fr = baculo(bucle(clave, t, Pn), cara)
		v = ficha['anims']['andar_%s_sb' % cara]['avance'] * CORRER
		poner('correr_%s_sb' % cara, fr, pisadas=pisadas(fr), juntos=pies_juntos(fr), avance=round(v, 5))
		andar = anims['andar_%s_sb' % cara]
		ja = ficha['anims']['andar_%s_sb' % cara]['juntos'][0]
		jr = ficha['anims']['correr_%s_sb' % cara]['juntos'][0]
		poner('a_correr_%s_sb' % cara, puente(andar[ja], fr[jr], 4), desde=ja, entra=jr)
		poner('de_correr_%s_sb' % cara, puente(fr[jr], andar[ja], 4), desde=jr, entra=ja)
		print('correr_%s_sb: %s %d..%d, juntos %s' % (cara, clave, t, t + Pn - 1, ficha['anims']['correr_%s_sb' % cara]['juntos']))
	escribir(anims, fps)
	json.dump(ficha, open(FICHA, 'w'), indent=1)
	print('->', FICHA)


if __name__ == '__main__':
	main()

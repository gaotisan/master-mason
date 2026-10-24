"""Limpia una hoja de sprites YA MONTADA (un SpriteFrames .tres) de lo que dejan
el croma y el recorte, y escribe su gemela: mismas casillas en el mismo sitio,
texturas nuevas en otra carpeta, otro .tres. El original no se toca.

  python tools/anim/hojas/limpiar.py <tres> <tres_gemelo> <carpeta_texturas> [--informe carpeta]

Lo que hace, por casilla (y lo que NO hace):
  motas     piezas sueltas de MOTA px o menos, separadas del personaje: fuera.
            Las de mas de OBJETO px son objetos (lo que coge, el palo que lanza)
            y no se tocan; las de en medio solo se cuentan (a mirarlas a mano).
  agujeros  huecos transparentes de AGUJERO px o menos rodeados de personaje:
            se tapan con el color de alrededor.
  verde     el croma verde: en este personaje ningun color tiene mas verde que
            rojo y azul, asi que el verde de mas se quita (g = max(r, b)), en todo
            el dibujo. Es lo unico que puede cambiar dentro del personaje, ademas de:
  cian      lo verde-azulado SATURADO (g > r + CIAN, saturacion > CIAN_SAT: una raya
            del croma en la pierna de atras al correr; quitar solo el verde lo
            dejaba cian): toma el color del interior sano de alrededor. La capucha
            gris azulada no llega a esa saturacion.
            Verde y cian no tocan la TELA: una mancha verde de mas de TELA px, ANCHA
            (aguanta una apertura de ANCHO px) y que no va por el contorno es tela
            (levantarse lleva un parche verde oscuro en el pecho; tocarlo lo dejaba
            a manchas). Las rayas finas (la de la pierna al correr) si se limpian.
  magenta   el croma magenta (rojo y azul por encima del verde) en la franja del
            contorno (BANDA px): toma el color del interior sano de al lado.
  halo      pixeles semitransparentes del contorno mucho mas oscuros o claros que
            el interior de al lado (el fondo que se quedo mezclado): su color.
  linea     el anillo de fuera (ANILLO px), aunque sea opaco, si su color se aleja
            del interior de al lado mas de LINEA (la raya oliva / oscura que deja
            el croma alrededor de todo el personaje): su color.
  opaco     el interior que deja ver el fondo (piernas o barba semitransparentes,
            el croma que se comio parte del alfa): pixeles con alfa entre OPACO_MIN
            y 230 rodeados de personaje (a mas de OPACO_DIST px de lo que es casi
            transparente) pasan a opacos. El contorno guarda su suavizado y los
            huecos de verdad (entre las piernas) siguen transparentes.
  raya      manchas PEQUENAS (hasta RAYA px) y OSCURAS (luz < RAYA_LUZ) de verde azulado
            apagado (g y b por encima de r): la raya del croma en la pierna de atras
            (correr, andar); toman el color de alrededor. La capucha, del mismo tono,
            es clara y grande: no.
  Nunca cambia el alfa salvo en motas, agujeros y opaco. Donde no hay interior sano
  cerca (dedos, punta de la barba, el palo: todo contorno) no copia color: solo
  quita el verde.

El informe: por animacion, los defectos antes y despues y los pixeles tocados
(y una tira con las casillas mas tocadas, antes / despues / que se toco).
"""
import argparse
import json
import os
import sys

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hoja import Hoja  # noqa: E402

MOTA = 20
OBJETO = 80
AGUJERO = 6
BANDA = 2.5
HALO = 35.0
ANILLO = 1.5
CIAN = 15
CIAN_SAT = 0.2
TELA = 80
RAYA = 60
RAYA_LUZ = 100
ANCHO = 7
LINEA = 40.0
OPACO_MIN = 64
OPACO_DIST = 1.5
CERCA = 4.0         # px hasta el interior sano para copiar su color
PAD = 6
# Los px de arriba son de la hoja del perfil (a media escala del master). Para una
# hoja a otra escala (el frontal va al master: 2), escala(k) los ajusta.
_BASE = dict(MOTA=MOTA, OBJETO=OBJETO, AGUJERO=AGUJERO, BANDA=BANDA, ANILLO=ANILLO, TELA=TELA,
	ANCHO=ANCHO, OPACO_DIST=OPACO_DIST, CERCA=CERCA, PAD=PAD)


def escala(k):
	"""Px de la hoja respecto a los del perfil (areas por k^2, distancias por k)."""
	g = globals()
	for n in ('MOTA', 'OBJETO', 'AGUJERO', 'TELA'):
		g[n] = int(round(_BASE[n] * k * k))
	for n in ('BANDA', 'ANILLO', 'OPACO_DIST', 'CERCA'):
		g[n] = _BASE[n] * k
	g['ANCHO'] = int(round(_BASE['ANCHO'] * k)) | 1
	g['PAD'] = int(np.ceil(_BASE['PAD'] * k))


# Reglas que se pueden apagar desde la ficha ("limpieza": {"linea": false}): la raya
# del contorno es para el croma oliva del perfil; donde no lo hay solo podria
# aclarar sombras buenas del borde (las puntas de la cornamenta del frontal).
REGLAS = {'linea': True}


def reglas(cfg):
	REGLAS.update(cfg or {})


def lum(c):
	return c[..., 0] * 0.3 + c[..., 1] * 0.59 + c[..., 2] * 0.11


def rellenar(rgb, w):
	"""El color de los pixeles con peso w extendido a todo (empuje-tira)."""
	acc, w = rgb * w[..., None], w.astype(np.float32)
	capas = []
	for _ in range(6):
		capas.append((acc, w))
		acc, w = cv2.pyrDown(acc), cv2.pyrDown(w)
	c = acc / np.maximum(w, 1e-4)[..., None]
	for acc, w in reversed(capas):
		up = cv2.resize(c, (acc.shape[1], acc.shape[0]), interpolation=cv2.INTER_LINEAR)
		c = np.where(w[..., None] > 0.02, acc / np.maximum(w, 1e-4)[..., None], up)
	return c


def defectos(im):
	"""Recuento de defectos de una casilla RGBA uint8."""
	f = im.astype(np.float32)
	a, rgb = f[..., 3] / 255.0, f[..., :3]
	vis = a > 0.03
	mx = np.maximum(rgb[..., 0], rgb[..., 2])
	borde = vis & (cv2.erode((a > 0.5).astype(np.uint8), np.ones((5, 5))) == 0)
	n, lab, st, _ = cv2.connectedComponentsWithStats((im[..., 3] > 0).astype(np.uint8), 8)
	areas = sorted(st[1:, 4], reverse=True)
	nucleo = cv2.erode((a > 0.98).astype(np.uint8), np.ones((3, 3)))
	ref = rellenar(rgb, nucleo.astype(np.float32))
	d = lum(rgb) - lum(ref)
	return {
		'verde': int((vis & (rgb[..., 1] > mx + 10)).sum()),
		'cian': int((vis & (rgb[..., 1] > rgb[..., 0] + CIAN) & ((rgb.max(-1) - rgb.min(-1)) / np.maximum(rgb.max(-1), 1e-6) > CIAN_SAT)).sum()),
		'magenta': int((borde & (np.minimum(rgb[..., 0], rgb[..., 2]) > rgb[..., 1] + 15)).sum()),
		'halo': int((borde & (a < 0.9) & (np.abs(d) > HALO)).sum()),
		'motas': int(sum(1 for x in areas[1:] if x <= MOTA)),
		'piezas_dudosas': int(sum(1 for x in areas[1:] if MOTA < x <= OBJETO)),
	}


def limpiar(im):
	"""Una casilla RGBA uint8 -> (limpia, mascara de lo tocado, n agujeros, n motas)."""
	im = cv2.copyMakeBorder(im, PAD, PAD, PAD, PAD, cv2.BORDER_CONSTANT, value=(0, 0, 0, 0))
	f = im.astype(np.float32)
	a = f[..., 3].copy()
	rgb = f[..., :3].copy()
	# motas: piezas sueltas pequenas (todo lo que tenga algo de alfa)
	n, lab, st, _ = cv2.connectedComponentsWithStats((a > 0).astype(np.uint8), 8)
	motas = 0
	if n > 2:
		mayor = 1 + int(np.argmax(st[1:, 4]))
		for i in range(1, n):
			if i != mayor and st[i, 4] <= MOTA:
				a[lab == i] = 0.0
				motas += 1
	# opaco: el interior semitransparente
	casi = (a >= OPACO_MIN).astype(np.uint8)
	nucleo_semi = (cv2.distanceTransform(casi, cv2.DIST_L2, 3) > OPACO_DIST) & (a < 230)
	a[nucleo_semi] = 255.0
	# cian: lo verde-azulado saturado (antes de quitar el verde)
	mxc = rgb.max(-1)
	sat = (mxc - rgb.min(-1)) / np.maximum(mxc, 1e-6)
	cian = (a > 0) & (rgb[..., 1] > rgb[..., 0] + CIAN) & (sat > CIAN_SAT)
	# la tela verde: manchas verdes / cian grandes que no tocan el contorno
	verdoso = ((rgb[..., 1] > np.maximum(rgb[..., 0], rgb[..., 2]) + 8) | cian) & (a > 128)
	fuera0 = (a < 5).astype(np.uint8)
	contorno = cv2.distanceTransform(1 - fuera0, cv2.DIST_L2, 3) <= 3
	tela = np.zeros(a.shape, bool)
	n3, l3, s3, _ = cv2.connectedComponentsWithStats(verdoso.astype(np.uint8), 8)
	disco = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (ANCHO, ANCHO))
	for i in range(1, n3):
		if s3[i, 4] <= TELA:
			continue
		m = l3 == i
		ancha = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_OPEN, disco).sum() > s3[i, 4] * 0.5
		if ancha and not (m & contorno).sum() > s3[i, 4] * 0.5:
			tela |= m
	tela = cv2.dilate(tela.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
	cian &= ~tela
	# el interior sano (opaco, sin su anillo exterior, sin croma) y su color extendido
	nucleo = cv2.erode((a >= 250).astype(np.uint8), np.ones((3, 3))) & ~cian
	ref = rellenar(rgb, nucleo.astype(np.float32))
	rgb[cian] = ref[cian]
	# raya: manchas pequenas y oscuras de verde azulado apagado
	lumx = lum(rgb)
	teal = (a > 128) & (rgb[..., 1] - rgb[..., 0] > 8) & (rgb[..., 2] - rgb[..., 0] > 4) & (lumx < RAYA_LUZ)
	nt, lt, stt, _ = cv2.connectedComponentsWithStats(teal.astype(np.uint8), 8)
	peq = stt[:, 4] <= RAYA
	peq[0] = False
	raya = peq[lt]
	if raya.any():
		raya = cv2.dilate(raya.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
		raya &= a > 0
		sano = (a >= 250) & ~raya & ~teal
		alrededor = rellenar(rgb, sano.astype(np.float32))
		rgb[raya] = alrededor[raya]
	cerca = cv2.distanceTransform(1 - nucleo, cv2.DIST_L2, 3) <= CERCA
	# agujeros: huecos pequenos rodeados de personaje
	hueco = (a < 128).astype(np.uint8)
	n2, l2, s2, _ = cv2.connectedComponentsWithStats(hueco, 4)
	agujeros = 0
	H, W = a.shape
	for i in range(1, n2):
		x, y, w, h, area = s2[i]
		if area <= AGUJERO and x > 0 and y > 0 and x + w < W and y + h < H:
			m = l2 == i
			a[m] = 255.0
			rgb[m] = ref[m]
			agujeros += 1
	# verde: fuera el de mas, en todo el dibujo
	mx = np.maximum(rgb[..., 0], rgb[..., 2])
	rgb[..., 1] = np.where(tela, rgb[..., 1], np.minimum(rgb[..., 1], mx))
	# la franja del contorno
	fuera = (a < 5).astype(np.uint8)
	banda = (a > 0) & (cv2.distanceTransform(1 - fuera, cv2.DIST_L2, 3) <= BANDA)
	magenta = banda & (np.minimum(rgb[..., 0], rgb[..., 2]) > rgb[..., 1] + 15)
	halo = banda & (a < 230) & (np.abs(lum(rgb) - lum(ref)) > HALO)
	anillo = banda & (cv2.distanceTransform(1 - fuera, cv2.DIST_L2, 3) <= ANILLO)
	linea = anillo & (np.linalg.norm(rgb - ref, axis=2) > LINEA) & REGLAS['linea']
	copiar = (magenta | halo | linea) & cerca
	rgb[copiar] = ref[copiar]
	# magenta sin interior al lado: solo se le quita el tinte (a gris de su luz)
	solo = magenta & ~cerca
	rgb[solo] = lum(rgb[solo])[..., None]
	out = np.dstack([np.clip(rgb, 0, 255), np.clip(a, 0, 255)]).round().astype(np.uint8)
	# un pixel transparente no lleva color (como el original)
	out[out[..., 3] == 0] = 0
	tocado = np.any(out != im, axis=2)
	s = slice(PAD, -PAD)
	return out[s, s], tocado[s, s], agujeros, motas


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument('tres')
	ap.add_argument('gemelo')
	ap.add_argument('carpeta')
	ap.add_argument('--informe')
	args = ap.parse_args()
	h = Hoja(args.tres)
	nuevas = {tex: h.textura(tex).copy() for tex in h.ext if h.ext[tex].endswith('.png')}
	por_casilla = {}
	for c, (tex, (x, y, w, hh), _) in h.casillas.items():
		antes = h.recorte(c)
		limpia, tocado, ag, mo = limpiar(antes)
		nuevas[tex][y:y + hh, x:x + w] = limpia
		# dentro del personaje (a mas de 3 px del contorno) solo puede cambiar el verde
		fuera = (antes[..., 3] < 5).astype(np.uint8)
		dentro = cv2.distanceTransform(1 - fuera, cv2.DIST_L2, 3) > 3
		otros = dentro & np.any(limpia[..., [0, 2, 3]] != antes[..., [0, 2, 3]], axis=2)
		por_casilla[c] = {'antes': defectos(antes), 'despues': defectos(limpia), 'tocados': int(tocado.sum()),
			'dentro_no_verde': int(otros.sum()), 'agujeros': ag, 'motas_quitadas': mo}
	h.escribir_gemela(nuevas, args.gemelo, args.carpeta)
	# informe por animacion
	filas = {}
	for anim, (ids, _, _) in h.animaciones.items():
		s = {'fotogramas': len(ids)}
		for c in ids:
			p = por_casilla[c]
			for k in ('antes', 'despues'):
				for d, v in p[k].items():
					s[k + '_' + d] = s.get(k + '_' + d, 0) + v
			for k in ('tocados', 'dentro_no_verde', 'agujeros', 'motas_quitadas'):
				s[k] = s.get(k, 0) + p[k]
		filas[anim] = s
		print('%-20s %3d f  verde %5d>%-4d magenta %5d>%-4d halo %5d>%-4d motas %4d>%-3d dudosas %3d  agujeros %3d  tocados %6d  dentro(no verde) %d' % (
			anim, len(ids), s['antes_verde'], s['despues_verde'], s['antes_magenta'], s['despues_magenta'], s['antes_halo'], s['despues_halo'],
			s['antes_motas'], s['despues_motas'], s['despues_piezas_dudosas'], s['agujeros'], s['tocados'], s['dentro_no_verde']), flush=True)
	if args.informe:
		os.makedirs(args.informe, exist_ok=True)
		json.dump({'animaciones': filas, 'casillas': por_casilla}, open(os.path.join(args.informe, 'limpieza.json'), 'w'), indent=1)


if __name__ == '__main__':
	main()

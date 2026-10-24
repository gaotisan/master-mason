"""Pasa las pasadas de la ficha de un personaje por su hoja de sprites ya montada
y escribe la gemela (el original no se toca) y un informe.

  python tools/anim/hojas/procesar.py tools/anim/hojas/personajes/<ficha>.json [--informe carpeta]

Las pasadas, en este orden (la ficha dice cuales):
  limpieza  limpiar.py: croma, contorno, motas, agujeros, interior transparente
  tono      tono.py: el tono estandar de la tunica en los enganches de pie
  pies      pies.py: piernas y pies al color de calzas y calzado
Para otro personaje o vista: otra ficha (ver personajes/peregrino_perfil.json).
"""
import argparse
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import limpiar  # noqa: E402
import pies  # noqa: E402
import tono  # noqa: E402
from hoja import Hoja, PROYECTO  # noqa: E402


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument('ficha')
	ap.add_argument('--informe')
	ap.add_argument('--reusar', help='casillas limpias de una vez anterior (.npz), para no repetir la limpieza al ajustar lo demas')
	args = ap.parse_args()
	cfg = json.load(open(os.path.join(PROYECTO, args.ficha) if not os.path.isabs(args.ficha) else args.ficha, encoding='utf-8'))
	pasadas = cfg['pasadas']
	limpiar.escala(cfg.get('escala', 1.0))
	pies.escala(cfg.get('escala', 1.0))
	pies.reglas(cfg.get('pies'))
	limpiar.reglas(cfg.get('limpieza'))
	h = Hoja(cfg['tres'])
	if 'tono' not in pasadas:
		# sin tono cada casilla va por su cuenta: textura a textura, para no tener
		# todas en memoria (las del frontal escalado son ~400 MB cada una)
		return por_texturas(h, cfg, args)
	cas = {c: h.recorte(c).copy() for c in h.casillas}
	por = {c: {} for c in cas}
	if 'limpieza' in pasadas and args.reusar and os.path.exists(args.reusar):
		z = np.load(args.reusar, allow_pickle=True)
		cas = {c: z[c] for c in cas}
		por = z['__por__'].item()
		print('limpieza: la de', args.reusar, flush=True)
	elif 'limpieza' in pasadas:
		for c in cas:
			antes = cas[c]
			cas[c], tocado, ag, mo = limpiar.limpiar(antes)
			por[c].update(limpieza=int(tocado.sum()), agujeros=ag, motas=mo,
				antes=limpiar.defectos(antes), despues=limpiar.defectos(cas[c]))
		print('limpieza: hecha', flush=True)
		if args.reusar:
			np.savez(args.reusar, __por__=np.array(por, dtype=object), **cas)
	resumen_tono = {}
	if 'tono' in pasadas:
		def fotograma(c):
			_, (x, y, w, hh), (ml, mt, mw, mh) = h.casillas[c]
			f = np.zeros((hh + mh, w + mw, 4), np.uint8)
			f[mt:mt + hh, ml:ml + w] = cas[c]
			return f
		g, resumen_tono, enganches = tono.ganancias(lambda c: cas[c], fotograma, h.animaciones, cfg['tono'])
		por_casilla = {}
		for anim, gs in g.items():
			for c, gk in zip(h.animaciones[anim][0], gs):
				por_casilla.setdefault(c, []).append(gk)
		for c, lista in por_casilla.items():
			cas[c] = tono.aplicar(cas[c], np.mean(lista, axis=0))
			por[c]['tono'] = float((np.mean(lista, axis=0).mean() - 1) * 100)
		for anim, (e, s) in resumen_tono.items():
			if abs(e) > 0.5 or abs(s) > 0.5:
				print('tono: %-20s entrada %+5.1f%%  salida %+5.1f%%' % (anim, e, s), flush=True)
		for de, fd, a, fa, antes, despues in enganches:
			if abs(antes) > 1.5 or abs(despues) > 1.5:
				print('enganche %s %d -> %s %d: salto %+5.1f%% -> %+5.1f%%' % (de, fd, a, fa, antes, despues), flush=True)
	if 'pies' in pasadas:
		libres = set(cfg['pies'].get('libre', []))
		de_pie = {c for anim, (ids, _, _) in h.animaciones.items() if anim in libres for c in ids}
		for c in cas:
			cas[c], m = pies.pintar(cas[c], cfg['pies']['color'], libre=c in de_pie)
			por[c]['pies'] = int(m.sum())
		print('pies: hechos', flush=True)
	if 'marcas' in cfg:
		# las marcas del usuario (marcas.py): lo marcado se pinta como el pie
		import marcas
		mm = json.load(open(os.path.join(PROYECTO, cfg['marcas']), encoding='utf-8')) if os.path.exists(os.path.join(PROYECTO, cfg['marcas'])) else {}
		color = cfg.get('pies', {}).get('color', [46, 36, 33])
		hechas = 0
		for anim, fots in mm.items():
			ids = h.animaciones.get(anim, [[]])[0]
			for k, cajas in fots.items():
				if int(k) < len(ids):
					c = ids[int(k)]
					cas[c] = marcas.aplicar(cas[c], cajas, lambda im, m: pies.pintar_mascara(im, m, color))
					hechas += 1
		print('marcas: %d fotogramas' % hechas, flush=True)
	nuevas = {tex: h.textura(tex).copy() for tex in h.ext if h.ext[tex].endswith('.png')}
	for c, (tex, (x, y, w, hh), _) in h.casillas.items():
		nuevas[tex][y:y + hh, x:x + w] = cas[c]
	h.escribir_gemela(nuevas, cfg['gemelo'], cfg['texturas'])
	print('gemela escrita:', cfg['gemelo'], flush=True)
	if args.informe:
		os.makedirs(args.informe, exist_ok=True)
		json.dump({'casillas': por, 'tono': resumen_tono}, open(os.path.join(args.informe, 'procesar.json'), 'w'), indent=1)



def por_texturas(h, cfg, args):
	pasadas = cfg['pasadas']
	por = {}
	for tex in [t for t in h.ext if h.ext[t].endswith('.png')]:
		arr = h.textura(tex).copy()
		for c, (tx, (x, y, w, hh), _) in h.casillas.items():
			if tx != tex:
				continue
			im = arr[y:y + hh, x:x + w].copy()
			por[c] = {}
			if 'limpieza' in pasadas:
				antes = im
				im, tocado, ag, mo = limpiar.limpiar(antes)
				por[c].update(limpieza=int(tocado.sum()), agujeros=ag, motas=mo,
					antes=limpiar.defectos(antes), despues=limpiar.defectos(im))
			if 'pies' in pasadas:
				im, m = pies.pintar(im, cfg['pies']['color'])
				por[c]['pies'] = int(m.sum())
			arr[y:y + hh, x:x + w] = im
		h.escribir_textura(tex, arr, cfg['texturas'])
		h.soltar(tex)
		del arr
		print('textura hecha:', h.nombre_textura(tex), flush=True)
	h.escribir_tres(cfg['gemelo'], cfg['texturas'])
	print('gemela escrita:', cfg['gemelo'], flush=True)
	if args.informe:
		os.makedirs(args.informe, exist_ok=True)
		json.dump({'casillas': por}, open(os.path.join(args.informe, 'procesar.json'), 'w'), indent=1)


if __name__ == '__main__':
	main()

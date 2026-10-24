"""Las hojas de FLOTAR del peregrino de perfil (assets/characters/peregrino/flotar.json:
hojas en rejilla, fuera del SpriteFrames; peregrino.gd las anade en marcha) con las
mismas pasadas que la hoja del perfil: limpieza (limpiar.py) y pies (pies.py). Escribe
las hojas limpias en `carpeta` y una ficha gemela (flotar_limpio.json) que apunta a
ellas; el original no se toca. Se compara con H en prueba_perfil_limpio.bat
(hoja_alterna.gd cambia tambien la ficha de flotar).

Tono: no se iguala (flotar no engancha con el reposo de pie: sale de los saltos);
se mide y se informa.

  python tools/anim/hojas/flotar.py [--informe carpeta]
"""
import argparse
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import limpiar  # noqa: E402
import pies  # noqa: E402
import tono  # noqa: E402
from hoja import PROYECTO  # noqa: E402

FICHA = 'assets/characters/peregrino/flotar.json'
GEMELA = 'assets/characters/peregrino/flotar_limpio.json'
CARPETA = 'assets/characters/peregrino_limpio'
PIE = (46, 36, 33)


def res(p):
	return os.path.join(PROYECTO, p.replace('res://', ''))


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument('--informe')
	args = ap.parse_args()
	d = json.load(open(os.path.join(PROYECTO, FICHA), encoding='utf-8'))
	pies.reglas({'forma': True})
	os.makedirs(os.path.join(PROYECTO, CARPETA), exist_ok=True)
	informe = {}
	for nombre, f in d.items():
		if nombre.startswith('_') or not isinstance(f, dict) or 'hoja' not in f:
			continue
		hoja = np.array(Image.open(res(f['hoja'])).convert('RGBA'))
		w, h = f['casilla']
		cols, n = f['cols'], f['n']
		suma = {'antes': {}, 'despues': {}, 'tocados': 0, 'pies': 0}
		tonos = []
		for i in range(n):
			x, y = (i % cols) * w, (i // cols) * h
			c = hoja[y:y + h, x:x + w].copy()
			antes = limpiar.defectos(c)
			c, toc, _, _ = limpiar.limpiar(c)
			c, m = pies.pintar(c, PIE, libre=nombre != 'coger_baculo')
			despues = limpiar.defectos(c)
			for k in antes:
				suma['antes'][k] = suma['antes'].get(k, 0) + antes[k]
				suma['despues'][k] = suma['despues'].get(k, 0) + despues[k]
			suma['tocados'] += int(toc.sum())
			suma['pies'] += int(m.sum())
			hoja[y:y + h, x:x + w] = c
			try:
				tonos.append(tono.media([c]))
			except Exception:
				pass
		destino = CARPETA + '/' + os.path.basename(res(f['hoja']))
		Image.fromarray(hoja).save(os.path.join(PROYECTO, destino), compress_level=6)
		orig_imp = res(f['hoja']) + '.import'
		imp = open(orig_imp, encoding='utf-8').read()
		open(os.path.join(PROYECTO, destino + '.import'), 'w', encoding='utf-8').write(
			'[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n' + imp[imp.index('[params]'):])
		f['hoja'] = 'res://' + destino
		suma['tono'] = [round(float(v) * 255, 1) for v in np.mean(tonos, axis=0)] if tonos else None
		informe[nombre] = suma
		a, b = suma['antes'], suma['despues']
		print('%-16s %3d f  verde %5d>%-4d magenta %5d>%-4d halo %6d>%-5d motas %4d>%-3d  pies %6d px  tunica RGB %s' % (
			nombre, n, a['verde'], b['verde'], a['magenta'], b['magenta'], a['halo'], b['halo'], a['motas'], b['motas'], suma['pies'], suma['tono']), flush=True)
	open(os.path.join(PROYECTO, GEMELA), 'w', encoding='utf-8').write(json.dumps(d, indent=1, ensure_ascii=False))
	print('escrito', GEMELA)
	if args.informe:
		os.makedirs(args.informe, exist_ok=True)
		json.dump(informe, open(os.path.join(args.informe, 'flotar.json'), 'w'), indent=1)


if __name__ == '__main__':
	main()

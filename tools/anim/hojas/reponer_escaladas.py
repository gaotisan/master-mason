"""Repone en una hoja ESCALADA y en su gemela limpia unas casillas que se escalaron mal
(2026-10-22: la grafica dejo en negro, o transparente, un trozo de 9 casillas del
frontal; escalar_hoja.py ahora lo comprueba por trozos y las vuelve a hacer).

  python tools/anim/hojas/reponer_escaladas.py <ficha.json> <carpeta_escaladas> <casilla> [<casilla>...]

- La escalada (la `tres` de la ficha): la casilla entera, la nueva tal cual.
- La limpia (el `gemelo`): solo lo roto (lo negro macizo que la nueva no tiene, o lo
  transparente que la nueva si tiene), con la nueva pasada por las reglas de la
  ficha (limpieza y pies). Lo demas de la casilla se queda: los arreglos a mano
  (capucha, garra) no se pierden.
Escribe los PNG en su sitio (sin tocar su .import).
"""
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hoja import Hoja, PROYECTO  # noqa: E402
import limpiar  # noqa: E402
import pies  # noqa: E402

NEGRO = 25       # mas oscuro que esto en todos los canales y opaco: el trozo negro


def main():
	cfg = json.load(open(sys.argv[1], encoding='utf-8'))
	carpeta, ids = sys.argv[2], sys.argv[3:]
	limpiar.escala(cfg.get('escala', 1.0))
	pies.escala(cfg.get('escala', 1.0))
	pies.reglas(cfg.get('pies'))
	limpiar.reglas(cfg.get('limpieza'))
	E, L = Hoja(cfg['tres']), Hoja(cfg['gemelo'])
	for nombre, h in (('escalada', E), ('limpia', L)):
		cambios = {}
		for c in ids:
			nueva = cv2.imread(os.path.join(carpeta, c + '.png'), cv2.IMREAD_UNCHANGED)
			nueva = cv2.cvtColor(nueva, cv2.COLOR_BGRA2RGBA)
			tex, (x, y, w, hh), _ = h.casillas[c]
			if nueva.shape[:2] != (hh, w):
				nueva = cv2.resize(nueva, (w, hh), interpolation=cv2.INTER_AREA)
			if h is E:
				cambios.setdefault(tex, []).append((x, y, nueva))
				continue
			vieja = h.recorte(c)
			roto = ((vieja[..., :3].max(-1) < NEGRO) & (vieja[..., 3] > 128) & (nueva[..., :3].max(-1) >= NEGRO)) \
				| ((vieja[..., 3] < 20) & (nueva[..., 3] > 128))
			roto = cv2.dilate(roto.astype(np.uint8), np.ones((9, 9), np.uint8)) > 0
			if 'limpieza' in cfg['pasadas']:
				nueva, _, _, _ = limpiar.limpiar(nueva)
			if 'pies' in cfg['pasadas']:
				nueva, _ = pies.pintar(nueva, cfg['pies']['color'])
			hecha = vieja.copy()
			hecha[roto] = nueva[roto]
			cambios.setdefault(tex, []).append((x, y, hecha))
			print('%s %s: %d px repuestos' % (nombre, c, int(roto.sum())), flush=True)
		for tex, lista in cambios.items():
			arr = h.textura(tex).copy()
			for x, y, im in lista:
				arr[y:y + im.shape[0], x:x + im.shape[1]] = im
			Image.fromarray(arr).save(os.path.join(PROYECTO, h.ext[tex]), compress_level=6)
			h.soltar(tex)
			print('%s: %s escrita' % (nombre, h.ext[tex]), flush=True)


if __name__ == '__main__':
	main()

"""Monta las casillas que deja escalar_hoja.py en hojas nuevas y un SpriteFrames
nuevo, gemelo del original: la misma disposicion, todo por ESCALA (regiones,
margenes, tamano de las hojas), las mismas animaciones. No toca el original.

  python tools/anim/montar_hoja_escalada.py <tres> <casillas> <tres_nuevo> <carpeta_hojas_nueva>
  (rutas del proyecto, sin res://; casillas: la salida de escalar_hoja.py)

Quien lo use pone el sprite a escala 1/ESCALA de la de antes (PeregrinoFrontal: _k
de 0,5 a 0,5/ESCALA); los JSON siguen en px de hoja y no cambian.
"""
import json
import os
import re
import sys

from PIL import Image

ESCALA = 1.5
PROYECTO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))


def r15(v):
	return int(round(float(v) * ESCALA))


def main():
	tres, casillas, tres_nuevo, carpeta = sys.argv[1:5]
	t = open(os.path.join(PROYECTO, tres), encoding='utf-8').read()
	repetidas = json.load(open(os.path.join(casillas, 'repetidas.json')))
	ext = dict((i, p) for p, i in re.findall(r'path="res://([^"]+)" id="([^"]+)"', t))
	os.makedirs(os.path.join(PROYECTO, carpeta), exist_ok=True)
	hojas = {}
	for i, p in ext.items():
		if p.endswith('.png'):
			w, h = Image.open(os.path.join(PROYECTO, p)).size
			hojas[i] = Image.new('RGBA', (r15(w) + 2, r15(h) + 2), (0, 0, 0, 0))

	def casilla(m):
		ident, tex = m.group(1), m.group(2)
		x, y, w, h = [float(v) for v in m.group(3).split(',')]
		ml, mt, mw, mh = [float(v) for v in m.group(4).split(',')] if m.group(4) else (0, 0, 0, 0)
		im = Image.open(os.path.join(casillas, repetidas.get(ident, ident) + '.png'))
		X, Y = r15(x), r15(y)
		if ident not in repetidas:
			hojas[tex].paste(im, (X, Y))
		W, H = im.size
		# el fotograma entero (casilla + margenes), por ESCALA; el margen, lo que falte
		FW, FH = r15(w + mw), r15(h + mh)
		ML, MT = r15(ml), r15(mt)
		s = '[sub_resource type="AtlasTexture" id="%s"]\natlas = ExtResource("%s")\nregion = Rect2(%d, %d, %d, %d)' % (ident, tex, X, Y, W, H)
		if m.group(4) or FW != W or FH != H:
			s += '\nmargin = Rect2(%d, %d, %d, %d)' % (ML, MT, FW - W, FH - H)
		return s

	t = re.sub(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\s*atlas = ExtResource\("([^"]+)"\)\s*region = Rect2\(([^)]*)\)(?:\s*margin = Rect2\(([^)]*)\))?', casilla, t)
	for i, p in ext.items():
		if i not in hojas:
			continue
		nuevo = carpeta.rstrip('/') + '/' + os.path.basename(p)
		hojas[i].save(os.path.join(PROYECTO, nuevo), optimize=False, compress_level=6)
		# la importacion, la del original (BC7, sin mipmaps), sin su uid ni su destino
		imp = open(os.path.join(PROYECTO, p + '.import'), encoding='utf-8').read()
		params = imp[imp.index('[params]'):]
		open(os.path.join(PROYECTO, nuevo + '.import'), 'w', encoding='utf-8').write(
			'[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n' + params)
		t = t.replace('path="res://%s"' % p, 'path="res://%s"' % nuevo)
	# sin los uid del original (Godot los pone al importar)
	t = re.sub(r' uid="uid://[^"]+"', '', t)
	open(os.path.join(PROYECTO, tres_nuevo), 'w', encoding='utf-8').write(t)
	print('hojas:', {os.path.basename(ext[i]): h.size for i, h in hojas.items()})


if __name__ == '__main__':
	main()

"""Lo comun de las herramientas de hojas: leer un SpriteFrames .tres (texturas,
casillas del atlas con su margen y animaciones) y escribir su gemelo.

Trabajan sobre la hoja YA MONTADA, no sobre los videos ni sobre las etapas de
cada animacion: asi valen igual para el perfil, el frontal (muy retocado a mano),
el diagonal y los personajes que vengan. El gemelo tiene la misma disposicion
(las mismas casillas en el mismo sitio): solo cambian los pixeles y las rutas de
las texturas, y el original no se toca.
"""
import os
import re

import numpy as np
from PIL import Image

Image.MAX_IMAGE_PIXELS = None
PROYECTO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..'))


class Hoja:
	def __init__(self, tres):
		self.tres = tres
		self.texto = open(os.path.join(PROYECTO, tres), encoding='utf-8').read()
		t = self.texto
		self.ext = dict((i, p) for p, i in re.findall(r'path="res://([^"]+)" id="([^"]+)"', t))
		# casilla: (textura, (x, y, w, h), (ml, mt, mw, mh))
		self.casillas = {}
		for m in re.finditer(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\s*atlas = ExtResource\("([^"]+)"\)\s*region = Rect2\(([^)]*)\)(?:\s*margin = Rect2\(([^)]*)\))?', t):
			r = tuple(int(round(float(v))) for v in m.group(3).split(','))
			mg = tuple(int(round(float(v))) for v in (m.group(4) or '0,0,0,0').split(','))
			self.casillas[m.group(1)] = (m.group(2), r, mg)
		# animaciones: nombre -> (casillas en orden, bucle, velocidad)
		self.animaciones = {}
		for fr, loop, n, sp in re.findall(r'"frames": \[(.*?)\],\s*"loop": (\w+),\s*"name": &"([^"]+)",\s*"speed": ([\d.]+)', t, re.S):
			self.animaciones[n] = (re.findall(r'SubResource\("([^"]+)"\)', fr), loop == 'true', float(sp))
		self._tex = {}

	def textura(self, tex):
		"""La textura entera, RGBA uint8 (en cache)."""
		if tex not in self._tex:
			self._tex[tex] = np.array(Image.open(os.path.join(PROYECTO, self.ext[tex])).convert('RGBA'))
		return self._tex[tex]

	def recorte(self, casilla):
		"""Lo dibujado de la casilla (su region del atlas), RGBA."""
		tex, (x, y, w, h), _ = self.casillas[casilla]
		return self.textura(tex)[y:y + h, x:x + w]

	def fotograma(self, casilla):
		"""El fotograma como lo dibuja Godot: la region dentro de su margen."""
		tex, (x, y, w, h), (ml, mt, mw, mh) = self.casillas[casilla]
		f = np.zeros((h + mh, w + mw, 4), np.uint8)
		f[mt:mt + h, ml:ml + w] = self.recorte(casilla)
		return f

	def nombre_textura(self, tex):
		return os.path.basename(self.ext[tex])

	def soltar(self, tex):
		"""Libera de la cache una textura ya usada (las del frontal escalado pesan ~400 MB)."""
		self._tex.pop(tex, None)

	def escribir_textura(self, tex, arr, carpeta):
		"""Escribe una textura de la gemela en `carpeta`, con la importacion del original
		(sin uid ni destino: Godot los pone). Devuelve su ruta en el proyecto."""
		os.makedirs(os.path.join(PROYECTO, carpeta), exist_ok=True)
		orig = self.ext[tex]
		nuevo = carpeta.rstrip('/') + '/' + os.path.basename(orig)
		Image.fromarray(arr).save(os.path.join(PROYECTO, nuevo), compress_level=6)
		imp = open(os.path.join(PROYECTO, orig + '.import'), encoding='utf-8').read()
		open(os.path.join(PROYECTO, nuevo + '.import'), 'w', encoding='utf-8').write(
			'[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n' + imp[imp.index('[params]'):])
		return nuevo

	def escribir_tres(self, gemelo, carpeta):
		"""El .tres de la gemela: el original con las rutas de las texturas en `carpeta`."""
		t = self.texto
		for tex, orig in self.ext.items():
			if orig.endswith('.png'):
				t = t.replace('path="res://%s"' % orig, 'path="res://%s"' % (carpeta.rstrip('/') + '/' + os.path.basename(orig)))
		t = re.sub(r' uid="uid://[^"]+"', '', t)
		open(os.path.join(PROYECTO, gemelo), 'w', encoding='utf-8').write(t)

	def escribir_gemela(self, texturas, gemelo, carpeta):
		"""Escribe la gemela entera: las texturas nuevas ({id_textura: RGBA}) y el .tres."""
		for tex, arr in texturas.items():
			self.escribir_textura(tex, arr, carpeta)
		self.escribir_tres(gemelo, carpeta)

	def reempaquetar(self, tex, fotogramas, carpeta, separacion=12):
		"""Rehace el atlas de una textura con los fotogramas enteros dados ({casilla:
		RGBA del tamano del fotograma}; las que no se den, como estan): cada uno
		recortado a lo que tiene dibujado (alineado a 4, por la compresion) y colocado
		en filas. Para cuando un arreglo se sale de la casilla vieja (la capucha
		reconstruida). Cambia region y margin de esas casillas en self.texto y escribe
		la textura; despues, escribir_tres. Solo para texturas de UNA animacion."""
		casillas = [c for c, (t, _, _) in self.casillas.items() if t == tex]
		ancho = self.textura(tex).shape[1]
		piezas = []
		for c in casillas:
			f = fotogramas[c] if c in fotogramas else self.fotograma(c)
			ys, xs = np.nonzero(f[..., 3] > 0)
			x0, y0 = (xs.min() // 4) * 4, (ys.min() // 4) * 4
			x1, y1 = min(-(-(xs.max() + 1) // 4) * 4, f.shape[1]), min(-(-(ys.max() + 1) // 4) * 4, f.shape[0])
			piezas.append((c, f, x0, y0, x1, y1))
		x = y = alto_fila = 0
		sitio = {}
		for c, f, x0, y0, x1, y1 in piezas:
			w, h = x1 - x0, y1 - y0
			if x + w > ancho:
				x, y, alto_fila = 0, y + alto_fila + separacion, 0
			sitio[c] = (x, y)
			x += w + separacion
			alto_fila = max(alto_fila, h)
		atlas = np.zeros((-(-(y + alto_fila) // 4) * 4, ancho, 4), np.uint8)
		for c, f, x0, y0, x1, y1 in piezas:
			X, Y = sitio[c]
			atlas[Y:Y + y1 - y0, X:X + x1 - x0] = f[y0:y1, x0:x1]
			FW, FH = f.shape[1], f.shape[0]
			nuevo = '[sub_resource type="AtlasTexture" id="%s"]\natlas = ExtResource("%s")\nregion = Rect2(%d, %d, %d, %d)\nmargin = Rect2(%d, %d, %d, %d)' % (
				c, tex, X, Y, x1 - x0, y1 - y0, x0, y0, FW - (x1 - x0), FH - (y1 - y0))
			self.texto = re.sub(r'\[sub_resource type="AtlasTexture" id="%s"\]\s*atlas = ExtResource\("[^"]+"\)\s*region = Rect2\([^)]*\)(?:\s*margin = Rect2\([^)]*\))?' % re.escape(c), nuevo, self.texto)
			self.casillas[c] = (tex, (X, Y, x1 - x0, y1 - y0), (x0, y0, FW - (x1 - x0), FH - (y1 - y0)))
		self._tex[tex] = atlas
		return self.escribir_textura(tex, atlas, carpeta)

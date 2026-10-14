"""Mascaras de la escena del camino del bosque.

La escena es una sola imagen de Midjourney (fondo_midjourney.png, 2912x1632,
"dark misty autumn forest, a narrow leaf-covered path..."): un camino de hojas
entre troncos que lleva a una luz, detras de una copa de ramas finas a
contraluz. El shader camino_fondo.gdshader le da vida sin recortar nada:
desplaza la propia imagen donde estas mascaras dicen que hay rama fina, y
encima pone niebla, rayos y luz (camino_aire.gdshader). Todo sale de aqui,
medido sobre la imagen:

  viento.png (1/2)  R copa: cuanto se mueve cada rama (0 en troncos y suelo,
                    mas en lo fino, lo alto y lo lejos del tronco)
                    G ramas: donde hay copa (de ahi caen las hojas)
                    B profundidad: 0 cerca .. 1 lejos (1 - w, ver abajo)
  medio.png  (1/4)  RGB color medio de la zona (la niebla tira hacia el),
                    A luz (donde esta el resplandor)
  aire.png   (1/4)  R troncos (lo que tapa la niebla de lejos), G rayos (con
                    signo, 0,5 = nada), B luz
  ruido.png  512    cuatro ruidos fbm que repiten sin costura (uno por canal)
  hojas_desenfocadas.png  el atlas de la hojarasca desenfocado, para las hojas
                    que pasan pegadas a la camara (fuera de foco)
  hojas_copa.json   puntos sobre las ramitas finas de la copa (donde cuelgan
                    las hojas que aun quedan en los arboles), uno cada ~28 px
  profundidad.png (1/2)  R w (inversa de la distancia: 1 lo mas cerca, 0 el
                    fondo), G w del fondo de alrededor (lo mas lejano a ~40 px)
  detras.png        la imagen sin lo que esta claramente por delante de lo que
                    tiene alrededor (troncos sobre la niebla), rellenado: es lo
                    que se ve cuando la camara se mueve y un tronco cercano
                    deja al descubierto lo de detras

PROFUNDIDAD (camera projection, 2.5D). Sin modelo de IA (no cabia en el disco):
la geometria de la propia foto, como en matte painting. w es la inversa de la
distancia, que es lo que manda en el paralaje (una camara que se desplaza mueve
cada punto en proporcion a w):
  - suelo: un plano; por debajo del horizonte (HORIZONTE) w crece linealmente
    hacia abajo (es exacto para un plano visto desde una camara).
  - paredes de bosque a los lados del pasillo: w crece con la distancia en
    horizontal al punto de fuga (PUNTO_FUGA), como dos planos verticales.
  - lo claro (la niebla, los troncos lejanos lavados por la bruma) es lejos:
    perspectiva aerea. Se mezcla por el brillo local.
  - lo que se ve es lo mas cercano: w = max(suelo, pared).
El shader del fondo hace el paralaje con oclusion (busca a lo largo del
desplazamiento el punto mas cercano que cae en cada pixel), asi un tronco
cercano pasa por delante de la niebla sin estirarse; donde deja hueco se ve
detras.png.

El camino y el suelo no se mueven nunca: por ahi andara el peregrino.

Los rayos son los de verdad de la imagen: se dispersa la luz de los huecos de la
copa hacia fuera desde la fuente (desenfoque radial, como la luz en la bruma) y
se queda solo la parte en franjas (lo que cambia de un haz al de al lado). El
shader los anima: giran un pelin con la copa y la bruma corre por dentro.

Uso: python mascaras.py
"""
import json
import os

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.normpath(os.path.join(AQUI, "..", "..", ".."))
SALIDA = os.path.join(PROYECTO, "assets", "world", "camino_bosque")
W, H = 2912, 1632

# --- Medidas sobre la imagen (px) -------------------------------------------
# Fuente de luz: detras de la copa (maximo del brillo difuminado en lo alto;
# mas abajo hay otro, el de la bruma del pasillo, que es luz dispersa).
FUENTE = (1440.0, 380.0)
# La copa se mueve entera hasta y = 450 y nada desde y = 1050 (los pies de
# los troncos y el suelo).
COPA_Y = (450.0, 1050.0)
# Grosor a partir del cual una rama es tronco (radio de la apertura, px).
TRONCO_R = 8
# Profundidad: horizonte del suelo (donde se pierde el camino), punto de fuga
# del pasillo y w de lo mas lejano (la niebla del fondo).
HORIZONTE = 980.0
PUNTO_FUGA = (1440.0, 900.0)
W_LEJOS = 0.04
PARED_BASE = 0.12
# Distancia al tronco a la que la rama ya se dobla entera (px). La copa es
# densa: con mas, casi todo quedaba cerca de algun tronco y no se movia.
FLEX_PX = 70.0


def suave(a, b, x):
	t = np.clip((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def envolver(m, engorde, difuminado):
	"""Silueta engordada y difuminada (0..1)."""
	k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * engorde + 1, 2 * engorde + 1))
	return np.clip(cv2.GaussianBlur(cv2.dilate(m, k), (0, 0), difuminado), 0.0, 1.0)


def ruido_periodico(n, beta, semilla):
	"""fbm que repite sin costura: ruido blanco filtrado en frecuencia (1/f^beta)."""
	rng = np.random.default_rng(semilla)
	f = np.fft.fftfreq(n)
	fx, fy = np.meshgrid(f, f)
	r = np.sqrt(fx * fx + fy * fy)
	r[0, 0] = 1.0
	espectro = np.fft.fft2(rng.standard_normal((n, n))) / r ** beta
	espectro[0, 0] = 0.0
	# Sin las frecuencias mas bajas (que no haya manchas gigantes que delaten
	# la repeticion) ni lo mas fino.
	espectro[r < 2.5 / n] = 0.0
	espectro *= np.exp(-(r * n / 40.0) ** 2)
	a = np.real(np.fft.ifft2(espectro))
	a = (a - a.mean()) / (a.std() * 4.0) + 0.5
	return np.clip(a, 0.0, 1.0)


def rayos(lum4, escala):
	"""Haces de luz con signo (a 1/escala de resolucion)."""
	h, w = lum4.shape
	sx, sy = FUENTE[0] / escala, FUENTE[1] / escala
	# Lo que emite: lo claro de la copa, cerca de la fuente.
	y, x = np.mgrid[0:h, 0:w].astype(np.float32)
	cerca = np.exp(-((x - sx) ** 2 + (y - sy) ** 2) / (2.0 * (520.0 / escala) ** 2))
	emite = suave(0.45, 0.85, lum4) * cerca
	# Desenfoque radial: cada pixel junta lo que hay entre el y la fuente.
	n = 160
	acc = np.zeros_like(emite)
	peso = 0.0
	for k in range(n):
		t = k / n * 0.92
		mx = x + (sx - x) * t
		my = y + (sy - y) * t
		d = 0.985 ** k
		acc += cv2.remap(emite, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT) * d
		peso += d
	acc /= peso
	# Solo las franjas: relativo a lo que hay alrededor.
	base = cv2.GaussianBlur(acc, (0, 0), 10.0)
	franjas = (acc - base) / (base + 0.02)
	# Donde hay dispersion que ver (no en lo negro ni lejisimos).
	presencia = suave(0.005, 0.06, base)
	return np.clip(franjas * 1.6, -1.0, 1.0) * presencia


def guardar(nombre, canales, escala):
	img = np.stack(canales, -1)
	if escala != 1:
		img = cv2.resize(img, (img.shape[1] // escala, img.shape[0] // escala), interpolation=cv2.INTER_AREA)
	img = (np.clip(img, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
	if img.shape[2] == 4:
		img = cv2.cvtColor(img, cv2.COLOR_RGBA2BGRA)
	else:
		img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)
	cv2.imwrite(os.path.join(SALIDA, nombre), img)
	print("  ", nombre, img.shape)


def main():
	os.makedirs(SALIDA, exist_ok=True)
	bgr = cv2.imread(os.path.join(AQUI, "fondo_midjourney.png"), cv2.IMREAD_COLOR)
	assert bgr.shape[:2] == (H, W), bgr.shape
	cv2.imwrite(os.path.join(SALIDA, "fondo.png"), bgr)
	rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
	lum = rgb @ np.array([0.3, 0.59, 0.11], np.float32)
	# La imagen tiene un grano moteado por todas partes: fuera antes de medir.
	ls = cv2.GaussianBlur(lum, (0, 0), 1.2)
	y, x = np.mgrid[0:H, 0:W].astype(np.float32)

	# --- Troncos: lo oscuro y ancho sobre la niebla (sobrevive a abrir con un
	# disco de TRONCO_R px).
	ancho = (cv2.GaussianBlur(ls, (0, 0), 25) - ls) > 0.03
	k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * TRONCO_R + 1, 2 * TRONCO_R + 1))
	tronco = cv2.morphologyEx(ancho.astype(np.uint8), cv2.MORPH_OPEN, k)
	grueso = envolver(tronco.astype(np.float32), 3, 4.0)
	lejos = cv2.distanceTransform((1 - tronco).astype(np.uint8), cv2.DIST_L2, 5)
	flex = suave(0.0, FLEX_PX, lejos)

	# --- Copa: ramas finas oscuras recortadas contra lo claro. En lo oscuro de
	# los lados no se ven: ahi ni se miden.
	detalle = np.clip(cv2.GaussianBlur(ls, (0, 0), 8) - ls, 0.0, 1.0)
	# Tambien las ramitas que cuelgan delante de lo menos claro (a los lados del
	# pasillo de luz): ahi tambien se ve que se mueven.
	claro = suave(0.05, 0.2, cv2.GaussianBlur(lum, (0, 0), 20))
	rama = suave(0.025, 0.08, detalle) * claro
	ramas = envolver(rama, 9, 5.0)
	altura = 1.0 - suave(COPA_Y[0], COPA_Y[1], y)
	copa = ramas * (1.0 - grueso) * flex * altura

	luz = suave(0.25, 0.65, cv2.GaussianBlur(lum, (0, 0), 50))
	medio = cv2.GaussianBlur(rgb, (0, 0), 28)

	# --- Profundidad (w) y lo de detras.
	w, w_fondo, detras = profundidad(rgb, lum, x, y)
	prof = 1.0 - w
	lum4 = cv2.resize(ls, (W // 4, H // 4), interpolation=cv2.INTER_AREA)
	haces = rayos(lum4, 4)
	tapa = cv2.GaussianBlur(tronco.astype(np.float32), (0, 0), 10)

	puntos_de_hojas(rama, tronco, altura)

	print("mascaras ->", SALIDA)
	guardar("profundidad.png", [w, w_fondo, np.zeros_like(w)], 2)
	cv2.imwrite(os.path.join(SALIDA, "detras.png"),
				cv2.cvtColor((np.clip(detras, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8), cv2.COLOR_RGB2BGR))
	print("   detras.png")
	guardar("viento.png", [copa, ramas * altura, prof], 2)
	guardar("medio.png", [medio[..., 0], medio[..., 1], medio[..., 2], luz], 4)
	h4 = (H // 4, W // 4)
	guardar("aire.png", [cv2.resize(tapa, h4[::-1], interpolation=cv2.INTER_AREA),
						 0.5 + 0.5 * haces,
						 cv2.resize(luz, h4[::-1], interpolation=cv2.INTER_AREA)], 1)
	n = 512
	guardar("ruido.png", [ruido_periodico(n, 1.3, s) for s in (11, 23, 37, 51)], 1)
	hojas_desenfocadas()


def profundidad(rgb, lum, x, y):
	"""w (1 cerca .. 0 fondo), w del fondo de alrededor y la imagen de detras."""
	w_suelo = np.clip((y - HORIZONTE) / (H - HORIZONTE), 0.0, 1.0)
	# Las paredes de troncos oscuros empiezan ya algo cerca en el borde del
	# pasillo (PARED_BASE): si no, el tronco grande de la derecha del pasillo
	# salia casi tan lejos como la niebla y no se despegaba de ella.
	w_pared = np.clip(PARED_BASE + np.abs(x - PUNTO_FUGA[0]) / (W * 0.5) * 0.95, 0.0, 1.0)
	claro = suave(0.10, 0.42, cv2.GaussianBlur(lum, (0, 0), 8))
	w_arbol = w_pared * (1.0 - claro) + W_LEJOS * claro
	w = cv2.GaussianBlur(np.maximum(w_suelo, w_arbol), (0, 0), 3)
	w_fondo = cv2.erode(w, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (81, 81)))
	# Lo que esta claramente por delante de lo de alrededor, fuera y rellenado.
	delante = (w - w_fondo) > 0.12
	delante = cv2.dilate(delante.astype(np.uint8), np.ones((7, 7))) > 0
	return w, w_fondo, rellenar(rgb, delante)


def rellenar(im, hueco):
	"""Rellena el hueco con lo de alrededor (push-pull por piramide)."""
	conocido = (~hueco).astype(np.float32)
	pir = [(im * conocido[..., None], conocido)]
	while min(pir[-1][1].shape) > 8:
		c, k = pir[-1]
		pir.append((cv2.pyrDown(c), cv2.pyrDown(k)))
	c, k = pir[-1]
	lleno = c / np.maximum(k, 1e-4)[..., None]
	for c, k in reversed(pir[:-1]):
		arriba = cv2.resize(lleno, (k.shape[1], k.shape[0]), interpolation=cv2.INTER_LINEAR)
		lleno = np.where(k[..., None] > 0.999, c / np.maximum(k, 1e-4)[..., None], c + arriba * (1.0 - k[..., None]))
	return np.where(hueco[..., None], lleno, im)


def puntos_de_hojas(rama, tronco, altura):
	"""Donde cuelgan las hojas de la copa: pixeles de ramita fina (no tronco),
	en lo alto y recortados contra la luz, repartidos uno por celda de 28 px
	(sin amontonarse) y en orden aleatorio."""
	fina = (rama > 0.5) & (tronco == 0) & (altura > 0.25)
	# Solo la copa del pasillo: a los lados salian columnas pegadas al canto de
	# los troncos grandes.
	fina[:, :960] = False
	fina[:, 1900:] = False
	ys, xs = np.nonzero(fina)
	rng = np.random.default_rng(7)
	orden = rng.permutation(len(xs))
	celdas = set()
	puntos = []
	for i in orden:
		c = (int(xs[i]) // 28, int(ys[i]) // 28)
		if c in celdas:
			continue
		celdas.add(c)
		puntos.append([int(xs[i]), int(ys[i])])
	with open(os.path.join(SALIDA, "hojas_copa.json"), "w", encoding="utf-8") as f:
		json.dump(puntos, f)
	print("   hojas_copa.json", len(puntos), "puntos")


def hojas_desenfocadas():
	"""El atlas de la hojarasca fuera de foco (con alfa premultiplicado para
	que el borde no salga con halo oscuro). Las celdas son de 64x128 y la hoja
	no llega al borde, asi que no se mezclan entre si."""
	src = cv2.imread(os.path.join(PROYECTO, "assets", "world", "hojarasca", "hojas.png"), cv2.IMREAD_UNCHANGED)
	img = src.astype(np.float32) / 255.0
	a = img[..., 3:4]
	pre = img[..., :3] * a
	pre = cv2.GaussianBlur(pre, (0, 0), 4.0)
	a2 = cv2.GaussianBlur(a[..., 0], (0, 0), 4.0)[..., None]
	col = pre / np.maximum(a2, 1e-4)
	out = np.concatenate([col, a2], -1)
	out = (np.clip(out, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
	cv2.imwrite(os.path.join(SALIDA, "hojas_desenfocadas.png"), out)
	print("   hojas_desenfocadas.png", out.shape)


if __name__ == "__main__":
	main()

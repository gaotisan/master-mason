"""Un fondo de Midjourney -> las mascaras de una escena viva como el camino del
bosque (camino_bosque.gd / camino_fondo.gdshader / camino_aire.gdshader).

Es lo de cruce_bosque/mascaras.py hecho funcion, para los planos que vienen
detras (los caminos de los lados del cruce): cada uno llama a generar() con sus
medidas. Lo que mide cada mascara y por que, en camino_bosque/mascaras.py.

  generar(fuente_png, carpeta_salida, cfg)
    cfg: fuente (x, y) del resplandor; copa_y (y desde, y hasta) lo que se mueve
    con el viento; horizonte (la fila del suelo a distancia infinita: la del
    peregrino); base [(x, y)...] la fila del pie de lo que se levanta, a lo
    ancho; hojas_x (desde, hasta) y hojas_y (hasta) donde cuelgan hojas de la
    copa; igualar (True: el color, al del camino del bosque, como el cruce:
    cruce_bosque/componer.py igualar_color); sombra (por debajo, sin la curva).

La profundidad: el suelo, un plano bajo el horizonte; lo que se levanta, a la
distancia de su pie (base); lo claro (la niebla), lejos.
"""
import importlib.util
import json
import os

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))


def _modulo(nombre, ruta):
	spec = importlib.util.spec_from_file_location(nombre, ruta)
	m = importlib.util.module_from_spec(spec)
	spec.loader.exec_module(m)
	return m


base = _modulo("mascaras_camino", os.path.join(AQUI, "camino_bosque", "mascaras.py"))
color = _modulo("componer_cruce", os.path.join(AQUI, "cruce_bosque", "componer.py"))
W, H = base.W, base.H


def _puntos_de_hojas(rama, tronco, altura, cfg, salida):
	fina = (rama > 0.5) & (tronco == 0) & (altura > 0.25)
	fina[:, :cfg["hojas_x"][0]] = False
	fina[:, cfg["hojas_x"][1]:] = False
	fina[cfg["hojas_y"]:, :] = False
	ys, xs = np.nonzero(fina)
	rng = np.random.default_rng(7)
	celdas, puntos = set(), []
	for i in rng.permutation(len(xs)):
		c = (int(xs[i]) // 28, int(ys[i]) // 28)
		if c in celdas:
			continue
		celdas.add(c)
		puntos.append([int(xs[i]), int(ys[i])])
	with open(os.path.join(salida, "hojas_copa.json"), "w", encoding="utf-8") as f:
		json.dump(puntos, f)
	print("   hojas_copa.json", len(puntos), "puntos")


def _profundidad(rgb, lum, x, y, cfg):
	hz = cfg["horizonte"]
	w_suelo = np.clip((y - hz) / (H - hz), 0.0, 1.0)
	bx = np.array([p[0] for p in cfg["base"]], np.float32)
	by = np.array([p[1] for p in cfg["base"]], np.float32)
	w_pie = np.clip((np.interp(x[0], bx, by) - hz) / (H - hz), 0.0, 1.0)[None, :]
	claro = base.suave(0.10, 0.42, cv2.GaussianBlur(lum, (0, 0), 8))
	w_arriba = w_pie * (1.0 - claro) + 0.04 * claro
	w = cv2.GaussianBlur(np.maximum(w_suelo, w_arriba), (0, 0), 3)
	w_fondo = cv2.erode(w, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (81, 81)))
	delante = ((w - w_fondo) > 0.05) & (y < hz)
	delante = cv2.dilate(delante.astype(np.uint8), np.ones((7, 7))) > 0
	return w, w_fondo, base.rellenar(rgb, delante)


def generar(fuente_png, salida, cfg):
	base.SALIDA = salida
	base.FUENTE = tuple(cfg["fuente"])
	base.COPA_Y = tuple(cfg["copa_y"])
	os.makedirs(salida, exist_ok=True)
	bgr = cv2.imread(fuente_png, cv2.IMREAD_COLOR)
	assert bgr.shape[:2] == (H, W), bgr.shape
	if cfg.get("igualar", True):
		color.SOMBRA = cfg.get("sombra", color.SOMBRA)
		rgb0 = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
		rgb0 = color.igualar_color(rgb0)
		bgr = cv2.cvtColor((rgb0 * 255.0 + 0.5).astype(np.uint8), cv2.COLOR_RGB2BGR)
	limpio = cv2.fastNlMeansDenoisingColored(bgr, None, base.GRANO_H, base.GRANO_H, 7, 21)
	cv2.imwrite(os.path.join(salida, "fondo.png"), limpio)
	rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
	rgb_limpio = cv2.cvtColor(limpio, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
	lum = rgb @ np.array([0.3, 0.59, 0.11], np.float32)
	ls = cv2.GaussianBlur(lum, (0, 0), 1.2)
	y, x = np.mgrid[0:H, 0:W].astype(np.float32)

	ancho = (cv2.GaussianBlur(ls, (0, 0), 25) - ls) > 0.03
	k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * base.TRONCO_R + 1, 2 * base.TRONCO_R + 1))
	tronco = cv2.morphologyEx(ancho.astype(np.uint8), cv2.MORPH_OPEN, k)
	grueso = base.envolver(tronco.astype(np.float32), 3, 4.0)
	lejos = cv2.distanceTransform((1 - tronco).astype(np.uint8), cv2.DIST_L2, 5)
	flex = base.suave(0.0, base.FLEX_PX, lejos)
	detalle = np.clip(cv2.GaussianBlur(ls, (0, 0), 8) - ls, 0.0, 1.0)
	claro = base.suave(0.05, 0.2, cv2.GaussianBlur(lum, (0, 0), 20))
	rama = base.suave(0.025, 0.08, detalle) * claro
	ramas = base.envolver(rama, 9, 5.0)
	altura = 1.0 - base.suave(cfg["copa_y"][0], cfg["copa_y"][1], y)
	copa = ramas * (1.0 - grueso) * flex * altura
	luz = base.suave(0.25, 0.65, cv2.GaussianBlur(lum, (0, 0), 50))
	medio = cv2.GaussianBlur(rgb, (0, 0), 28)

	w, w_fondo, detras = _profundidad(rgb_limpio, lum, x, y, cfg)
	lum4 = cv2.resize(ls, (W // 4, H // 4), interpolation=cv2.INTER_AREA)
	haces = base.rayos(lum4, 4)
	tapa = cv2.GaussianBlur(tronco.astype(np.float32), (0, 0), 10)
	_puntos_de_hojas(rama, tronco, altura, cfg, salida)

	print("mascaras ->", salida)
	base.guardar("profundidad.png", [w, w_fondo, np.zeros_like(w)], 2)
	cv2.imwrite(os.path.join(salida, "detras.png"),
				cv2.cvtColor((np.clip(detras, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8), cv2.COLOR_RGB2BGR))
	print("   detras.png")
	base.guardar("viento.png", [copa, ramas * altura, 1.0 - w], 2)
	base.guardar("medio.png", [medio[..., 0], medio[..., 1], medio[..., 2], luz], 4)
	h4 = (H // 4, W // 4)
	base.guardar("aire.png", [cv2.resize(tapa, h4[::-1], interpolation=cv2.INTER_AREA),
							  0.5 + 0.5 * haces,
							  cv2.resize(luz, h4[::-1], interpolation=cv2.INTER_AREA)], 1)
	f = limpio.astype(np.float32) / 255
	L = f[..., 2] * .3 + f[..., 1] * .59 + f[..., 0] * .11
	print("   fondo: mediana %.3f, bajo 0,03 %.1f %%" % (np.median(L), (L < 0.03).mean() * 100))

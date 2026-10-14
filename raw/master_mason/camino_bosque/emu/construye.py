"""El emu del principio del camino: del video con croma a fotogramas para Godot.

Fuente: anim/_fuentes/Emu_charges_forward_aggressively_20261015011458.mp4
(1280x720, 24 fps, 10 s, croma verde liso, con sonido). Es la tercera version;
el usuario la eligio por el tono (pardo oscuro y saturado, mas pajaro) y porque
el sonido es mas amenazador. Que pasa en el video:

    1-4      la imagen de partida, gris (se quitan: el video IA arranca de
             ahi y en 4 fotogramas vira al pardo oscuro, saturacion 0,20->0,30)
    5-56     de perfil, mira; gira hacia la camara y da un paso
    57-150   de frente, mira; graznido fuerte en 115-127 (el del sonido)
    152-     carga hacia la camara: toca el borde de abajo (156), el de arriba
             (183) y el de la izquierda (187) y sale por la IZQUIERDA (las dos
             versiones anteriores salian por la derecha); a 209 ya no queda nada

Versiones anteriores (en _fuentes): Emu_charges_at_camera_... (gris; buena
carga, sale por la derecha) y Emu_glaring_and_rushing_camera_... (final malo:
casi no se acerca y se abalanza de golpe, cabeza deformada).

En la escena esta en primer plano a la izquierda del camino y se sale del
encuadre hacia la camara. El video va como una ventana (escena = o + s *
video) con su borde de abajo por debajo del de la pantalla: asi se sale por
abajo como en el video. Para los bordes de arriba y de la izquierda, en la
embestida la ventana crece hacia la camara desde un punto fijo de abajo a la
derecha (asi el borde izquierdo se va hacia fuera) y al final se va a la
izquierda acelerando. La trayectoria se calcula aqui y se comprueba con lo
que ocupa de verdad el emu en cada fotograma.
Se probo a ponerlo mas atras, en el entrante entre los dos troncos de la
izquierda (pies 920,1320, escala 0,77): quedaba pequeno y tragado por la
oscuridad y, para sacarlo del encuadre, la ventana tenia que crecer tan deprisa
mientras el andaba despacio que parecia que se hinchaba. El usuario lo vio
"fatal".

Por cada fotograma:
  1. Alfa por croma: lo verde que sobra sobre el mayor de rojo y azul.
  2. Quitar el verde del borde: se deshace la mezcla con el verde del fondo y
     se recorta el verde que quede por encima del mayor de rojo y azul.
  3. Tono: saturacion y ganancia por canal (TONO_*; con este video, neutro: el
     usuario quiere su tono).
  3b. Quitar la luz de estudio y guardar la textura: el video esta iluminado de
     frente y en la escena la luz viene de detras. La luminancia se separa en
     iluminacion (lo de baja frecuencia: un desenfoque dentro de la silueta) y
     detalle (las plumas: lo que queda al dividir). Se deja el detalle entero,
     la iluminacion casi plana (un FORMA de ella para que no pierda volumen) y
     todo a un nivel LUZ_REF; el shader le pone la luz de la escena (contraluz).
     Asi las patas grises de estudio dejan de ser claras sin que se pierdan las
     plumas (aplanar en el shader dejaba una mancha lisa).
  4. Recortar a lo opaco con margen y guardar a ESCALA (en la embestida, que
     se ve de cerca y movida, a ESCALA_CARGA), en premultiplicado.
  5. Sangrar el color hacia lo transparente (filtrado lineal sin halo).
Todo va a paginas de atlas (emu_0.png...) y una ficha (emu.json) con, por
fotograma: pagina y rectangulo en el atlas, rectangulo en el video, centro,
ventana (ox, oy, s), y los pies (o si ya se han salido por abajo).

La embestida va acelerada (VEL_CARGA, idea del usuario: el final del video,
con el emu enorme y emborronado saliendo despacio, dejaba ver las costuras) y al
final la ventana se desplaza (EMPUJE) para que salga antes, como algo que te
pasa rozando; los fotogramas en que ya esta fuera de la pantalla se quitan.

El sonido del video va aparte (emu_camino.ogg), sin los fotogramas quitados y
con la embestida acelerada igual (atempo: mas rapido sin cambiar el tono).

Uso: python construye.py
"""
import json
import os
import subprocess
import wave

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.normpath(os.path.join(AQUI, "..", "..", "..", ".."))
FFMPEG = os.path.join(PROYECTO, "tools", "ffmpeg", "bin", "ffmpeg.exe")
VIDEO = os.path.join(PROYECTO, "raw", "master_mason", "anim", "_fuentes", "Emu_charges_forward_aggressively_20261015011458.mp4")
SALIDA = os.path.join(PROYECTO, "assets", "world", "camino_bosque")
AUDIO = os.path.join(PROYECTO, "assets", "audio", "emu_camino.ogg")

W, H, FPS = 1280, 720, 24
PANT_W, PANT_H = 2912, 1632
DESDE = 5            # del 1 al 4, la imagen de partida (gris)
ESCALA = 1.0
CARGA = 170          # desde aqui, ESCALA_CARGA (de cerca y movido)
ESCALA_CARGA = 0.75
MARGEN = 8
PAGINA = 4096
VERDE_FONDO = 70.0
VERDE_EMU = 22.0
# Luz de estudio fuera: desenfoque de la iluminacion (fraccion del alto del emu,
# minimo en px), cuanto volumen se guarda y el nivel al que queda.
LUZ_SIGMA = (0.045, 14.0)
FORMA = 0.2
LUZ_REF = 0.24
# Tono: saturacion y ganancia por canal (neutro: el del video).
TONO_SATURACION = 1.0
TONO_GANANCIA = (1.0, 1.0, 1.0)

# --- Donde y como (px de pantalla; numeros de fotograma del video) ---------
PIES = (930.0, 1615.0)   # primer plano, a la izquierda del camino
ESCALA_PIE = 1.47        # ~980 px de alto: un emu de 1,77 m ahi (camara a 1,1 m)
EMBESTIDA = (150, 180)   # la ventana crece (antes de tocar arriba (183) y la izquierda (187))
VEL_CARGA = 1.6          # desde EMBESTIDA[0], los fotogramas van a esta velocidad
# Salida: de este fotograma a este la ventana se va a un lado (x: negativo, a
# la izquierda; y: un pelin abajo) y se acerca, acelerando (ease-in: se va cada
# vez mas deprisa, como algo que te pasa rozando; con un deslizamiento a
# velocidad constante parecia un carton plano).
EMPUJE = (188, 206, -1500.0, 160.0)
ESCALA_SALIDA = 3.0
ESCALA_FIN = 2.45
CENTRO_X = 1700.0        # desde donde crece (abajo, a la derecha: echa el borde izquierdo fuera)
HOLGURA = 30.0           # px que deben quedar fuera los bordes que toca (camara)


def suave(a, b, x):
	t = np.clip((x - a) / (b - a), 0.0, 1.0)
	return float(t * t * (3.0 - 2.0 * t))


def fotogramas():
	p = subprocess.Popen([FFMPEG, "-loglevel", "quiet", "-i", VIDEO, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
						 stdout=subprocess.PIPE)
	n = 0
	while True:
		buf = p.stdout.read(W * H * 3)
		if len(buf) < W * H * 3:
			break
		n += 1
		yield n, np.frombuffer(buf, np.uint8).reshape(H, W, 3).astype(np.float32) / 255.0
	p.wait()


def recortar(rgb, verde):
	"""RGB sin verde y alfa (rectos, sin premultiplicar)."""
	r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
	exceso = (g - np.maximum(r, b)) * 255.0
	a = 1.0 - np.clip((exceso - VERDE_EMU) / (VERDE_FONDO - VERDE_EMU), 0.0, 1.0)
	a = a * a * (3.0 - 2.0 * a)
	a[a < 0.03] = 0.0
	aa = np.maximum(a, 1e-3)[..., None]
	f = np.clip((rgb - (1.0 - aa) * verde) / aa, 0.0, 1.0)
	f[..., 1] = np.minimum(f[..., 1], np.maximum(f[..., 0], f[..., 2]) * 1.02)
	return f, a


def sangrar(col, a):
	"""Extiende el color de lo opaco a lo transparente (sin tocar el alfa)."""
	col = col.copy()
	hecho = a > 0.004
	pre = col * a[..., None]
	peso = a.copy()
	for _ in range(6):
		pre = cv2.blur(pre, (5, 5))
		peso = cv2.blur(peso, (5, 5))
		nuevo = (~hecho) & (peso > 1e-4)
		col[nuevo] = pre[nuevo] / peso[nuevo][:, None]
		hecho = hecho | nuevo
	return col


def sin_luz_de_estudio(col, a, alto):
	"""Quita la iluminacion de baja frecuencia y deja la textura (ver 3b)."""
	lum = col @ np.array([0.3, 0.59, 0.11], np.float32)
	sigma = max(LUZ_SIGMA[1], LUZ_SIGMA[0] * alto)
	num = cv2.GaussianBlur(lum * a, (0, 0), sigma)
	den = cv2.GaussianBlur(a, (0, 0), sigma)
	luz = num / np.maximum(den, 1e-4)
	detalle = lum / np.maximum(luz, 1e-3)
	media = np.median(luz[a > 0.9]) if np.any(a > 0.9) else LUZ_REF
	forma = np.power(np.maximum(luz, 1e-3) / media, FORMA)
	nueva = LUZ_REF * detalle * forma
	return np.clip(col * (nueva / np.maximum(lum, 1e-3))[..., None], 0.0, 1.0)


def ventana(n, pies_v):
	"""(ox, oy, s) de la ventana del video en el fotograma n: quieta y, en la
	embestida, crece desde un punto fijo en su borde de abajo (asi ese borde
	sigue fuera de la pantalla)."""
	s0 = ESCALA_PIE
	o0 = np.array([PIES[0] - pies_v[0] * s0, PIES[1] - pies_v[1] * s0])
	centro = np.array([CENTRO_X, o0[1] + H * s0])
	s = s0 + (ESCALA_FIN - s0) * suave(EMBESTIDA[0], EMBESTIDA[1], n)
	t = float(np.clip((n - EMPUJE[0]) / (EMPUJE[1] - EMPUJE[0]), 0.0, 1.0)) ** 2
	s2 = s * (1.0 + (ESCALA_SALIDA / ESCALA_FIN - 1.0) * t)
	o = centro + (o0 - centro) * (s2 / s0)
	o[0] += EMPUJE[2] * t
	o[1] += EMPUJE[3] * t
	return float(o[0]), float(o[1]), s2


def main():
	os.makedirs(SALIDA, exist_ok=True)
	verde = None
	medidas = []   # por fotograma: [n, rgb, alfa, caja, media de color]
	for n, rgb in fotogramas():
		if n < DESDE:
			continue
		if verde is None:
			verde = np.concatenate([rgb[:40, -40:].reshape(-1, 3), rgb[-40:, -40:].reshape(-1, 3)]).mean(0)
		col, a = recortar(rgb, verde)
		ys, xs = np.nonzero(a > 0.02)
		if len(xs) == 0:
			print("sin emu desde el fotograma", n)
			break
		opaco = a > 0.9
		medidas.append([n, col, a, (xs.min(), xs.max(), ys.min(), ys.max()), col[opaco].mean(0)])
	print(len(medidas), "fotogramas (%d-%d)" % (medidas[0][0], medidas[-1][0]))

	# Pies del primer fotograma usado: el ancla de la ventana.
	a0 = medidas[0][2]
	ys, xs = np.nonzero(a0 > 0.02)
	y1 = ys.max()
	pies_v = (float(xs[ys > y1 - 25].mean()), float(y1))
	print("pies en el video:", pies_v)

	# Cuales se usan: hasta la embestida todos; desde ahi, a VEL_CARGA.
	por_n = {m[0]: m for m in medidas}
	ultimo = medidas[-1][0]
	usar = [n for n in range(DESDE, EMBESTIDA[0])]
	k = 0
	while True:
		n = int(round(EMBESTIDA[0] + k * VEL_CARGA))
		if n > ultimo:
			break
		usar.append(n)
		k += 1
	piezas = []
	fallos = []
	for i, n in enumerate(usar):
		_, col, a, (x0, x1, y0, y1), _ = por_n[n]
		ox, oy, s = ventana(n, pies_v)
		# Ya fuera de la pantalla (por un lado o por abajo): se acaba aqui.
		if n > EMBESTIDA[0] and (ox + x0 * s > PANT_W or ox + x1 * s < 0 or oy + y0 * s > PANT_H):
			print("fuera de la pantalla desde el fotograma", n)
			break
		l = (col @ np.array([0.3, 0.59, 0.11], np.float32))[..., None]
		col = np.clip((l + (col - l) * TONO_SATURACION) * np.array(TONO_GANANCIA, np.float32), 0.0, 1.0)
		col = sin_luz_de_estudio(col, a, y1 - y0)
		# Comprobar: cada borde del video que toca el emu, fuera de la pantalla.
		if x0 <= 2 and ox > -HOLGURA:
			fallos.append((n, "izquierda", round(ox)))
		if x1 >= W - 3 and ox + W * s < PANT_W + HOLGURA:
			fallos.append((n, "derecha", round(ox + W * s)))
		if y0 <= 2 and oy > -HOLGURA:
			fallos.append((n, "arriba", round(oy)))
		if y1 >= H - 3 and oy + H * s < PANT_H + HOLGURA:
			fallos.append((n, "abajo", round(oy + H * s)))
		cx0, cx1 = max(0, x0 - MARGEN), min(W, x1 + 1 + MARGEN)
		cy0, cy1 = max(0, y0 - MARGEN), min(H, y1 + 1 + MARGEN)
		c = col[cy0:cy1, cx0:cx1]
		ca = a[cy0:cy1, cx0:cx1]
		e = ESCALA if n < CARGA else ESCALA_CARGA
		if e != 1.0:
			w = max(1, int(round((cx1 - cx0) * e)))
			h = max(1, int(round((cy1 - cy0) * e)))
			pre = cv2.resize(c * ca[..., None], (w, h), interpolation=cv2.INTER_AREA)
			ca = cv2.resize(ca, (w, h), interpolation=cv2.INTER_AREA)
			c = pre / np.maximum(ca, 1e-4)[..., None]
		c = sangrar(c, ca)
		yy, xx = np.nonzero(a > 0.02)
		abajo = yy > y1 - 25
		piezas.append({
			"img": np.concatenate([c, ca[..., None]], -1),
			"v": [int(cx0), int(cy0), int(cx1 - cx0), int(cy1 - cy0)],
			"centro": [round(float(xx.mean()), 1), round(float(yy.mean()), 1)],
			"ventana": [round(ox, 2), round(oy, 2), round(s, 4)],
			"pies": [round(float(xx[abajo].mean()), 1), int(y1), int(y1 < H - 3)],
		})
	if fallos:
		print("BORDES DENTRO DE LA PANTALLA:")
		for f in fallos:
			print("  ", f)
	else:
		print("bordes: ninguno de los que toca el emu cae dentro de la pantalla")

	# Empaquetado por estantes.
	paginas = [np.zeros((PAGINA, PAGINA, 4), np.float32)]
	x = y = alto = 0
	ficha = []
	for p in piezas:
		h, w = p["img"].shape[:2]
		if x + w > PAGINA:
			x, y, alto = 0, y + alto, 0
		if y + h > PAGINA:
			paginas.append(np.zeros((PAGINA, PAGINA, 4), np.float32))
			x = y = alto = 0
		paginas[-1][y:y + h, x:x + w] = p["img"]
		ficha.append([len(paginas) - 1, x, y, w, h] + p["v"] + p["centro"] + p["ventana"] + p["pies"])
		x += w
		alto = max(alto, h)
	paginas[-1] = paginas[-1][:max(1, y + alto)]
	for f in os.listdir(SALIDA):
		if f.startswith("emu_") and f.endswith(".png"):
			os.remove(os.path.join(SALIDA, f))
	for i, pg in enumerate(paginas):
		out = (np.clip(pg, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
		cv2.imwrite(os.path.join(SALIDA, "emu_%d.png" % i), cv2.cvtColor(out, cv2.COLOR_RGBA2BGRA))
		print("   emu_%d.png" % i, out.shape)
	with open(os.path.join(SALIDA, "emu.json"), "w", encoding="utf-8") as f:
		json.dump({"fps": FPS, "video": [W, H], "escala_pie": ESCALA_PIE, "escala_fin": ESCALA_FIN,
				   "paginas": len(paginas), "fotogramas": ficha}, f)
	print("   emu.json")

	# Sonido: sin el primer fotograma, con un fundido corto al final.
	tmp = os.path.join(AQUI, "_emu.wav")
	t0 = (EMBESTIDA[0] - DESDE) / FPS
	filtro = ("[0:a]atrim=0:%.4f,asetpts=PTS-STARTPTS[a1];[0:a]atrim=%.4f,asetpts=PTS-STARTPTS,atempo=%.3f[a2];"
			  "[a1][a2]concat=n=2:v=0:a=1[s]" % (t0, t0, VEL_CARGA))
	subprocess.run([FFMPEG, "-loglevel", "error", "-y", "-ss", "%.4f" % ((DESDE - 1) / FPS), "-i", VIDEO,
					"-filter_complex", filtro, "-map", "[s]", "-ac", "2", "-ar", "48000", tmp], check=True)
	with wave.open(tmp) as wv:
		sr = wv.getframerate()
		s = np.frombuffer(wv.readframes(wv.getnframes()), np.int16).reshape(-1, 2).astype(np.float32)
	t = np.arange(len(s)) / sr
	fin = min(len(s) / sr, len(piezas) / FPS + 0.6)
	s = s[:int(fin * sr)]
	t = t[:len(s)]
	s *= np.clip((fin - t) / 0.6, 0.0, 1.0)[:, None]
	with wave.open(tmp, "wb") as wv:
		wv.setnchannels(2)
		wv.setsampwidth(2)
		wv.setframerate(sr)
		wv.writeframes(np.clip(s, -32768, 32767).astype(np.int16).tobytes())
	subprocess.run([FFMPEG, "-loglevel", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", "6", AUDIO], check=True)
	os.remove(tmp)
	print("->", AUDIO)


if __name__ == "__main__":
	main()

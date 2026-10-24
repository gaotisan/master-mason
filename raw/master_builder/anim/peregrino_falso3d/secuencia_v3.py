"""LA DIAGONAL DE LA TERCERA TANDA (2026-10-22): de los fotogramas de montar.py (claves
v3_*) a las animaciones de la diagonal, sin baculo (el guardado lo pinta el juego
encima). no = alejandose hacia arriba a la izquierda; se = acercandose hacia abajo a la
derecha; las otras dos diagonales son su espejo (en el juego).

  andar_no / andar_se            bucles (el tramo que mejor cierra, cerrado por flujo)
  arranque_no / arranque_se      del quieto del principio del video al bucle
  parada_no / parada_se          un ciclo del bucle + la frenada del final del video:
                                 se entra por la fase en que vaya (entrada)
  reposo_no / reposo_se          el quieto del final, respirando
  vuelta_no_se                   03: de quieto alla, se vuelve y anda hacia aca hasta el bucle
  vuelta_se_no                   04: de quieto aca (puente desde el reposo: el video arranca en
                                 otra pose), se vuelve y se aleja hasta el bucle
  correr_no / correr_se          bucles de correr (la camara va con el)
  parada_correr_no / _se         del bucle de correr a quieto (la frenada del video)
  a_correr_no / _se, de_correr_no / _se   puentes cortos andar <-> correr (flujo)
  esquina_n_no                   07: de espaldas recto, echa a andar girando a la diagonal
                                 hasta el bucle de alejarse
La ficha (falso3d.json) dice por animacion lo que avanza cada fotograma respecto al
bucle (factor: 1 = como andando) y en que sentido (no / se), las entradas y el periodo.

    python secuencia_v3.py
"""
import importlib.util
import json
import os

import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
_spec = importlib.util.spec_from_file_location('secuencia_falso3d', os.path.join(AQUI, 'secuencia.py'))
F3 = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(F3)
SEC = F3.SEC

FPS = 24
PERIODO = (26, 44)      # andando: dos pasos
PERIODO_CORRER = (18, 30)
QUIETO = 0.0012        # alturas por fotograma por debajo de esto: quieto


def leer(clave, k):
	return F3.leer(clave, k)


def n_de(clave):
	return json.load(open(os.path.join(AQUI, clave, 'medidas.json')))['n']


def recorrido(clave):
	"""Lo que avanza cada fotograma (alturas, en el suelo del video), suavizado."""
	m = json.load(open(os.path.join(AQUI, clave, 'medidas.json')))
	cx, h = np.array(m['cx']), np.array(m['h'])
	w = float(m['ancho'])
	X = (cx - w / 2) / h
	Z = SEC.F_VIDEO * w / 1280 / h
	d = np.hypot(np.diff(X), np.diff(Z))
	d = np.convolve(np.r_[d[0], d], np.ones(9) / 9, mode='same')
	return d


def tramo_andando(clave):
	d = recorrido(clave)
	anda = np.nonzero(d > QUIETO)[0]
	return int(anda.min()), int(anda.max())


def actividad(clave):
	"""Lo que cambia el dibujo de un fotograma al siguiente (para los de correr, que
	no avanzan en pantalla)."""
	n = n_de(clave)
	a = np.array([F3.dif(leer(clave, k), leer(clave, k + 1)) for k in range(n - 1)])
	return np.convolve(np.r_[a, a[-1]], np.ones(7) / 7, mode='same')


def buscar_bucle(clave, a, b, periodo=PERIODO):
	mejor = None
	for P in range(periodo[0], periodo[1] + 1):
		for t in range(a, b - P + 1):
			d = F3.dif(leer(clave, t), leer(clave, t + P))
			if mejor is None or d < mejor[0]:
				mejor = (d, t, P)
	print('   %-22s bucle %d..%d (periodo %d), cierre %.4f' % (clave, mejor[1], mejor[1] + mejor[2] - 1, mejor[2], mejor[0]))
	return mejor[1], mejor[2]


def entra(frames, loop):
	"""El fotograma del bucle que mas se parece al ultimo de frames."""
	return min(range(len(loop)), key=lambda j: F3.dif(frames[-1], loop[j]))


def hasta_el_bucle(clave, a, desde, b, loop):
	"""Los fotogramas a..k del video, cortados en el PRIMER k (desde <= k <= b) que casa
	casi tan bien con el bucle como el mejor (hasta 1,25 veces su diferencia): asi se
	entra en el bucle en cuanto anda, no al final del video. (fotogramas, j del bucle)."""
	todos = [(F3.dif(leer(clave, k), loop[j]), k, j) for k in range(desde, b + 1) for j in range(len(loop))]
	m = min(t[0] for t in todos)
	_, k, j = min((t for t in todos if t[0] <= 1.25 * m), key=lambda t: t[1])
	return [leer(clave, q) for q in range(a, k)], j


# ------------------------------------------------------------------ el baculo a la espalda
# En el bosque siempre lo lleva (lo coge en la hojarasca): todas las de la diagonal lo
# llevan pintado, como lo pinta el juego en la vuelta del frontal en ese angulo
# (poses_baculo/solo_15 y solo_42: scenes/dev/poses_frontal.tscn, solo el baculo y la
# correa), pegado a la capucha. De tres cuartos de frente (se) va detras del cuerpo: solo
# lo que asoma de la silueta de la vuelta; de espaldas (no), delante, entero.
POSES_B = os.path.join(AQUI, 'poses_baculo')
_capas = {}


def capa(cara):
	if cara not in _capas:
		import cv2
		from PIL import Image
		k = 15 if cara == 'se' else 42
		juego = np.asarray(Image.open(os.path.join(POSES_B, 'solo_%d.png' % k)).convert('RGBA')).copy()
		cw, ch = F3.MON.CAS
		# el render tiene los pies 13 px mas arriba que la hoja del frontal (medido)
		juego = juego[1113 - F3.MON.SUELO:1113 - F3.MON.SUELO + ch, 600 - F3.MON.EJE:600 - F3.MON.EJE + cw].copy()
		import sys
		sys.path.insert(0, os.path.join(ANIM, '..', '..', '..', 'tools', 'anim', 'hojas'))
		from hoja import Hoja
		h = Hoja('resources/characters/peregrino_frontal_hd.tres')
		sin = h.fotograma(h.animaciones['vuelta_sb'][0][k])
		if cara == 'se':
			cuerpo = cv2.dilate((sin[..., 3] > 60).astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
			juego[..., 3] = np.where(cuerpo, 0, juego[..., 3])
		else:
			# la vuelta mira arriba a la derecha; la diagonal no, arriba a la izquierda
			juego = juego[:, ::-1].copy()
			sin = sin[:, ::-1].copy()
		_capas[cara] = (juego, SEC.capucha(sin))
	return _capas[cara]


def con_baculo(frames, cara):
	c, ancla = capa(cara)
	return [SEC.con_baculo(im, c, ancla) for im in frames]


def con_baculo_vuelta(frames, de, a, k_giro):
	"""Una vuelta de `de` a `a`: el baculo de `de` estrechandose (de canto) hasta la mitad
	del giro y el de `a` ensanchandose; desde k_giro, el de `a`."""
	out = []
	mitad = k_giro / 2.0
	for k, im in enumerate(frames):
		if k <= mitad:
			t = k / max(mitad, 1)
			c, ancla = capa(de)
			out.append(SEC.con_baculo(im, c, ancla, ancho=max(1 - t, 0.08)))
		else:
			t = min((k - mitad) / max(k_giro - mitad, 1), 1.0)
			c, ancla = capa(a)
			out.append(SEC.con_baculo(im, c, ancla, ancho=max(t, 0.08)))
	return out


def main():
	anims, fps, ficha = {}, {}, {'fps': FPS, 'fps_reposo': F3.FPS_REPOSO, 'casilla': list(F3.MON.CAS), 'suelo': F3.MON.SUELO,
								 'eje': F3.MON.EJE, 'alto': F3.MON.ALTO, 'anims': {}}

	def poner(nombre, frames, f=FPS, **datos):
		anims[nombre] = frames
		fps[nombre] = f
		ficha['anims'][nombre] = dict(n=len(frames), **datos)
		print('%-18s %3d fotogramas  %s' % (nombre, len(frames), {k: v for k, v in datos.items() if not isinstance(v, (list, dict))}))

	loops, v_loop, d_loop = {}, {}, {}
	for clave, dir_ in (('v3_alejarse', 'no'), ('v3_acercarse', 'se')):
		a, b = tramo_andando(clave)
		d = recorrido(clave)
		t, P = buscar_bucle(clave, a + 12, b - 10)
		loop = F3.bucle(clave, t, P)
		loops[dir_] = loop
		v = F3.velocidad(clave, t, P)
		d_loop[dir_] = float(np.mean(d[t:t + P]))
		v_loop[dir_] = v
		poner('andar_' + dir_, loop, pisadas=SEC.pisadas(loop), periodo=P, avance=round(v, 5), video=[clave, t, P])
		# arranque: del quieto (unos fotogramas antes de moverse) hasta que casa con el bucle
		ini = max(0, a - 6)
		arr, j = hasta_el_bucle(clave, ini, a + 12, a + 12 + P, loop)
		poner('arranque_' + dir_, arr, entra=j, sentido=dir_,
			  factor=[round(float(min(d[k] / d_loop[dir_], 1.5)), 3) for k in range(ini, ini + len(arr))])
		# parada: un ciclo del bucle y la frenada (desde donde frena de verdad), hasta quieto
		fin = min(b + 10, n_de(clave) - 1)
		frena = next((k for k in range(t + P, b + 1) if d[k] < 0.7 * d_loop[dir_]), b - 10)
		desde = max(frena - P + 1, t)
		cola = [leer(clave, k) for k in range(desde, fin + 1)]
		entrada = {str((desde + i - t) % P): i for i in range(P)}
		poner('parada_' + dir_, cola, entrada=entrada, sentido=dir_,
			  factor=[round(float(min(d[k] / d_loop[dir_], 1.5)), 3) for k in range(desde, fin + 1)])
		poner('reposo_' + dir_, F3.respira(cola[-1]), F3.FPS_REPOSO)
	# las vueltas: de quieto, el giro y los pasos hasta el bucle del otro sentido
	for clave, de, a_ in (('v3_volverse_lejos', 'no', 'se'), ('v3_volverse_cerca', 'se', 'no')):
		a, b = tramo_andando(clave)
		d = recorrido(clave)
		k0 = max(0, a - 10)
		fr, j = hasta_el_bucle(clave, k0, a + 30, b - 10, loops[a_])
		# el 04 arranca en otra pose y otro sitio: empieza en el fotograma que mas se parece
		# al reposo de aqui, con un puente corto desde el
		base = anims['reposo_' + de][0]
		i0 = min(range(min(len(fr), 40)), key=lambda i: F3.dif(base, fr[i]))
		fr = fr[i0:]
		puente = SEC.puente(base, fr[0], 4) if F3.dif(base, fr[0]) > 0.004 else []
		vu = puente + fr
		fac = [0.0] * len(puente) + [round(float(min(d[k] / d_loop[a_], 1.5)), 3) for k in range(k0 + i0, k0 + i0 + len(fr))]
		# hacia donde va cada fotograma: el giro acaba donde empieza a avanzar de verdad
		poner('vuelta_%s_%s' % (de, a_), vu, entra=j, sentido=a_, factor=fac, desde_reposo=len(puente))
	# correr: la camara va con el; el bucle donde mas se mueve el dibujo, y la frenada
	for clave, dir_ in (('v3_correr_alejandose', 'no'), ('v3_correr_acercandose', 'se')):
		ac = actividad(clave)
		n = len(ac)
		corre = np.nonzero(ac > 0.6 * np.percentile(ac, 90))[0]
		a, b = int(corre.min()), int(corre.max())
		t, P = buscar_bucle(clave, a + 10, b - 15, PERIODO_CORRER)
		loop = F3.bucle(clave, t, P)
		v = v_loop[dir_] * SEC.CORRER
		poner('correr_' + dir_, loop, pisadas=SEC.pisadas(loop), periodo=P, avance=round(v, 5), video=[clave, t, P])
		quieto = next((k for k in range(b, n) if ac[k] < 0.25 * np.percentile(ac, 90)), n - 1)
		desde = t + max(0, (b - 15 - t) // P - 1) * P + 1
		cola = [leer(clave, k) for k in range(desde, min(quieto + 6, n))]
		entrada = {str((desde + i - t) % P): i for i in range(P)}
		frena = [1.0] * P + list(np.round(np.linspace(1.0, 0.0, len(cola) - P), 3))
		poner('parada_correr_' + dir_, cola, entrada=entrada, sentido=dir_, factor_correr=[float(x) for x in frena])
		ja = SEC.pies_juntos(loops[dir_])[0]
		jr = SEC.pies_juntos(loop)[0]
		poner('a_correr_' + dir_, SEC.puente(loops[dir_][ja], loop[jr], 4), desde=ja, entra=jr)
		poner('de_correr_' + dir_, SEC.puente(loop[jr], loops[dir_][ja], 4), desde=jr, entra=ja)
	# la esquina: de espaldas recto a la diagonal de alejarse
	clave = 'v3_de_espaldas'
	a, b = tramo_andando(clave)
	d = recorrido(clave)
	fr, j = hasta_el_bucle(clave, max(0, a - 6), a + 24, b - 10, loops['no'])
	poner('esquina_n_no', fr, entra=j, sentido='no', factor=[round(float(min(d[k] / d_loop['no'], 1.5)), 3) for k in range(max(0, a - 6), max(0, a - 6) + len(fr))])
	# el baculo a la espalda en todas
	for nombre in list(anims):
		d = ficha['anims'][nombre]
		if nombre.startswith('vuelta_'):
			de, a = nombre.split('_')[1:3]
			fac = d.get('factor', [])
			k_giro = next((i for i, f in enumerate(fac) if f > 0.6), len(fac) // 2)
			anims[nombre] = con_baculo_vuelta(anims[nombre], de, a, k_giro)
		else:
			cara = 'no' if nombre.endswith('_no') else 'se'
			anims[nombre] = con_baculo(anims[nombre], cara)
	F3.CARPETA = 'assets/characters/peregrino_falso3d'
	F3.escribir(anims, fps)
	json.dump(ficha, open(F3.FICHA, 'w'), indent=1)
	print('->', F3.FICHA)


if __name__ == '__main__':
	main()

"""Pasada de hojas: piernas y pies al color de las calzas y el calzado.

Veo saca a veces al peregrino descalzo (pies color carne, dedos) y con las piernas
gris azuladas; el personaje lleva calzas y zapatos de cuero oscuros, de un solo
marron muy oscuro desde el bajo de la tunica hasta la punta del pie (como en los
prompts y en el frontal / diagonal: PIERNA (46, 36, 33)).

Que se pinta: lo FINO que cuelga del personaje (el alfa menos su apertura con un
disco de GRUESO px: piernas, pies, dedos, manos, punta de la barba, baston) y es
OSCURO y poco saturado (las piernas: el color no basta, piel y tunica tienen el
mismo tono), en piezas de al menos PIEZA px; y lo que se le pega dentro de lo fino
(el rosado del pie, las unas, el borde) si no es claro. Las manos y la cara no:
salen de la manga o de la capucha, que son gruesas, y no tocan pierna. El baston
tampoco (fino y oscuro como una pierna): una pieza solo es pierna si (1) llega
ABAJO (acaba en la cuarta parte de abajo de la figura: de pie, tumbado o colgado),
(2) SALE de la masa gruesa del cuerpo (la toca: los trozos sueltos de la madera junto
al suelo no) y (3) no es mas alta que ALTO_MAX de la figura (el tramo del baston de la
mano al suelo si). La cornamenta y lo alto del baston no llegan abajo.
Con COLGANDO (la ficha: "colgando": true; el frontal), ademas (4) CUELGA de la tunica:
justo encima de su punta de arriba esta el cuerpo (de espaldas el baston va pegado a
la tunica y encima tiene mas baston o la mano) y (5) va por DENTRO del bajo: su
centro cae en la parte central (sin el MARGEN de cada lado) del ancho de la tunica en
la cuarta parte de abajo (de espaldas la mano coge el baston a la altura de la cadera
y el tramo de abajo cuelga de la manga como una pierna, pero por el borde o por fuera).
En el perfil no: tumbado, las piernas salen de lado.
Con FORMA (la ficha: "forma": true; el perfil, 2026-10-21) la pierna arranca de un
tramo oscuro de pierna (como siempre, pero hasta ABAJO_F: la de atras corriendo va
levantada) y crece por TODO lo fino pegado a el, de cualquier color salvo lo claro
(la pierna de atras sale a veces rosada o con una raya gris del croma; lo blanco de
la barba no): una mano o la barba sueltas no tienen tramo oscuro y no se tocan.
En las animaciones DE PIE (la ficha: "libre": [animaciones]) las manos no bajan a la
mitad de abajo: ahi cualquier pieza fina que cuelga hasta ABAJO_F es pierna aunque no
tenga tramo oscuro (la de atras corriendo, rosada entera). pintar(..., libre=True). Ademas se pinta con el sombreado SUAVE (la luz
relativa recortada a SUAVE y difuminada): las rayitas claras entre los dedos y las
rayas de la pierna desaparecen y queda el volumen.
Se pinta con el color dado y el sombreado de cada pixel (su luz respecto a la
mediana de lo pintado en esa casilla), sin tocar el alfa.
"""
import cv2
import numpy as np

GRUESO = 13
PIEZA = 25
LUZ_PIERNA = 80
CROMA_PIERNA = 22
LUZ_PEGADO = 235     # las unas casi blancas tambien (pegadas a la pierna)
PASOS = 3            # anillos de lo pegado
ALTO_MAX = 0.4
ABAJO = 0.25
COLGANDO = False
ENCIMA = 6           # px por encima de la punta de arriba donde buscar la tunica
MARGEN = 0.15
FORMA = False
ABAJO_F = 0.28
LUZ_CRECE = 190
ABAJO_LIBRE = 0.3     # las piezas sin tramo oscuro: hasta el tercio de abajo
LARGO_LIBRE = 0.08    # y al menos esta altura de la figura (no las puntas del bajo)
LARGO_PALO = 0.3
GROSOR_PALO = 7.0
PICO = 15
SUAVE = (0.8, 1.25)
_BASE = dict(GRUESO=GRUESO, PIEZA=PIEZA, PASOS=PASOS)


def escala(k):
	"""Px de la hoja respecto a los del perfil (como limpiar.escala)."""
	g = globals()
	g['GRUESO'] = int(round(_BASE['GRUESO'] * k)) | 1
	g['PIEZA'] = int(round(_BASE['PIEZA'] * k * k))
	g['PASOS'] = int(round(_BASE['PASOS'] * k))
	g['ENCIMA'] = int(round(6 * k))
	g['GROSOR_PALO'] = 7.0 * k
	g['PICO'] = int(round(15 * k))
	g['TUNICA_DISCO'] = int(round(21 * k)) | 1
	g['PIE_MIN'] = int(round(25 * k * k))
	g['HUECO'] = int(round(20 * k * k))
	g['FACETA_MAX'] = int(round(600 * k * k))
	g['FACETA_PIEL'] = int(round(150 * k * k))


def reglas(cfg):
	globals()['COLGANDO'] = bool((cfg or {}).get('colgando', False))
	globals()['FORMA'] = bool((cfg or {}).get('forma', False))


def lum(c):
	return c[..., 0] * 0.299 + c[..., 1] * 0.587 + c[..., 2] * 0.114


def mascara(im, libre=False):
	f = im.astype(np.float32)
	a, rgb = f[..., 3], f[..., :3]
	if FORMA and libre:
		return _piernas_de_pie(im)
	lab = cv2.cvtColor(np.ascontiguousarray(im[..., :3]), cv2.COLOR_RGB2LAB).astype(np.float32)
	croma = np.hypot(lab[..., 1] - 128, lab[..., 2] - 128)
	sol = (a > 128).astype(np.uint8)
	grueso = cv2.morphologyEx(sol, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (GRUESO, GRUESO)))
	fino = (a > 20) & (cv2.dilate(grueso, np.ones((3, 3), np.uint8)) == 0)
	base = fino & (a > 128) & (lum(rgb) < LUZ_PIERNA) & (croma < CROMA_PIERNA)
	if FORMA and libre:
		base = fino & (a > 128) & (lum(rgb) < LUZ_CRECE)
	ys = np.nonzero((a > 128).any(1))[0]
	if len(ys) == 0:
		return np.zeros(a.shape, bool)
	alto = ys.max() - ys.min() + 1
	cuerpo = cv2.dilate(grueso, np.ones((5, 5), np.uint8)) > 0
	n, l, st, _ = cv2.connectedComponentsWithStats(base.astype(np.uint8), 8)
	m = np.zeros(a.shape, bool)
	for i in range(1, n):
		x, y, w, h, area = st[i]
		if area < PIEZA or h > ALTO_MAX * alto or y + h < ys.max() + 1 - (ABAJO_F if FORMA else ABAJO) * alto:
			continue
		if FORMA and libre:
			pz = l == i
			oscura = (base & (lum(rgb) < LUZ_PIERNA) & (croma < CROMA_PIERNA))[pz].mean() > 0.3
			# un pie suelto (agachado: solo asoma el pie): corto, de piel y tocando el suelo
			piel = ((lab[..., 1] - 128 > 6) & (lum(rgb) > 70))[pz].mean() > 0.5
			pie = piel and y + h >= ys.max() + 1 - PICO
			if not oscura and not pie and (h < LARGO_LIBRE * alto or y + h < ys.max() + 1 - ABAJO_LIBRE * alto):
				continue
		pieza = l == i
		if not (cv2.dilate(pieza.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0)[cuerpo].any():
			continue
		if COLGANDO:
			cols = np.nonzero(pieza[y:y + max(h // 8, 2)].any(0))[0]
			if not cuerpo[max(y - ENCIMA, 0):y + 2, cols].any(0).mean() > 0.5:
				continue
			bajo = np.nonzero(grueso[int(ys.max() + 1 - ABAJO * alto - ENCIMA * 4):ys.max() + 1].any(0))[0]
			if len(bajo):
				x0, x1 = bajo.min(), bajo.max()
				cx = x + w / 2
				if not (x0 + MARGEN * (x1 - x0) <= cx <= x1 - MARGEN * (x1 - x0)):
					continue
		m |= pieza
	pegable = fino & (lum(rgb) < LUZ_PEGADO)
	if FORMA and m.any():
		crece = fino & (a > 20) & (lum(rgb) < LUZ_CRECE)
		n2, l2 = cv2.connectedComponents((crece | m).astype(np.uint8), connectivity=8)
		ids = np.unique(l2[m])
		m |= np.isin(l2, ids[ids > 0]) & crece
		for _ in range(PASOS):
			m |= (cv2.dilate(m.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0) & pegable
		# fuera lo que no tiene forma de pierna con pie: lo largo y fino (el palo apoyado
		# en el suelo: 131 px de alto, menos de 6 de grosor; la pierna con su pie, 10-12)
		# y los piquitos del bajo de la tunica (menos de PICO px de alto)
		n3, l3, s3, _ = cv2.connectedComponentsWithStats(m.astype(np.uint8), 8)
		dt = cv2.distanceTransform(m.astype(np.uint8), cv2.DIST_L2, 3)
		for i in range(1, n3):
			g = l3 == i
			grosor = 2 * float(dt[g].max())
			es_piel = ((lab[..., 1] - 128 > 6) & (lum(rgb) > 70))[g].mean() > 0.5
			if (s3[i, 3] > LARGO_PALO * alto and grosor < GROSOR_PALO) or (s3[i, 3] < PICO and grosor < GROSOR_PALO and not es_piel):
				m &= ~g
	elif COLGANDO and m.any():
		# todo lo pegado a la pierna por debajo de donde arranca (el pie entero, que de
		# lado es largo), sin subir: las manos van mas arriba
		desde = int(np.nonzero(m.any(1))[0].min())
		# los pies juntos, de lado, son un bloque grueso: si va suelto (no es la tunica,
		# que es la masa mayor) y por debajo de donde arrancan las piernas, tambien es pie
		ng, lg, sg, _ = cv2.connectedComponentsWithStats(grueso, 8)
		if ng > 2:
			mayor = 1 + int(np.argmax(sg[1:, 4]))
			sueltos = [i for i in range(1, ng) if i != mayor and sg[i, 1] >= desde]
			if sueltos:
				bloque = cv2.dilate(np.isin(lg, sueltos).astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
				pegable |= bloque & (a > 20) & (lum(rgb) < LUZ_PEGADO)
		pegable[:desde] = False
		n2, l2 = cv2.connectedComponents((pegable | m).astype(np.uint8), connectivity=8)
		ids = np.unique(l2[m])
		m |= np.isin(l2, ids[ids > 0]) & pegable
	else:
		for _ in range(PASOS):
			m |= (cv2.dilate(m.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0) & pegable
	return m


def _piernas_de_pie(im):
	"""De pie (andar, correr, saltar...: libre), las piernas por FORMA, no por color (la
	piel de la pierna y la tela de la tunica tienen el mismo tono en estas hojas): en
	el tercio de abajo, cada pieza fina (fuera de la masa de la tunica) que es larga
	(LARGO_LIBRE de la figura) o llega a la franja del suelo (PIES_LIBRE) es pierna o
	pie, de cualquier color; las cortas que no llegan al suelo son puntas de la tunica.
	Y en la franja del suelo, los bultos sueltos que no son la tunica (el talon del pie
	apoyado es grueso). Antes la pierna de atras se quedaba sin pintar en unos
	fotogramas y parpadeaba (2026-10-22)."""
	f = im.astype(np.float32)
	a, rgb = f[..., 3], f[..., :3]
	sol = (a > 128).astype(np.uint8)
	grueso = cv2.morphologyEx(sol, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (GRUESO, GRUESO)))
	ys = np.nonzero((a > 128).any(1))[0]
	if len(ys) == 0:
		return np.zeros(a.shape, bool)
	alto = ys.max() - ys.min() + 1
	y_zona = int(ys.max() + 1 - ABAJO_LIBRE * alto)
	y_suelo = int(ys.max() + 1 - PIES_LIBRE * alto)
	# la tunica: la masa gruesa mayor; el resto de lo grueso de la franja del suelo, pie
	# la tunica, con un disco mayor (TUNICA_DISCO): agachado el talon apoyado es grueso
	# y con el disco de siempre quedaba pegado a la tunica (los pies iban "desnudos")
	grueso = cv2.morphologyEx(sol, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (TUNICA_DISCO, TUNICA_DISCO)))
	ng, lg, sg, _ = cv2.connectedComponentsWithStats(grueso, 8)
	tunica = np.zeros(a.shape, bool)
	if ng > 1:
		tunica = lg == 1 + int(np.argmax(sg[1:, 4]))
	tunica = cv2.dilate(tunica.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
	cand = (a > 20) & ~tunica & (lum(rgb) < LUZ_CRECE)
	xs = np.nonzero((a > 128).any(0))[0]
	ancho = xs.max() - xs.min() + 1
	if ancho > TUMBADO * alto:
		# TUMBADO (tumbarse, arrastrarse...): las piernas salen por el lado contrario a
		# la cabeza (lo mas alto de la figura); las manos van del lado de la cabeza
		arriba = np.nonzero((a > 128)[ys.min():ys.min() + max(int(0.15 * alto), 2)].any(0))[0]
		cabeza = arriba.mean()
		lejos = np.zeros(a.shape, bool)
		if cabeza > (xs.min() + xs.max()) / 2:
			lejos[:, :int(xs.min() + LADO_PIES * ancho)] = True
		else:
			lejos[:, int(xs.max() + 1 - LADO_PIES * ancho):] = True
		n, l, st, _ = cv2.connectedComponentsWithStats((cand & lejos).astype(np.uint8), 8)
		m = np.zeros(a.shape, bool)
		for i in range(1, n):
			if st[i, 4] >= 6:
				m |= l == i
		return m
	cand[:y_zona] = False
	n, l, st, _ = cv2.connectedComponentsWithStats(cand.astype(np.uint8), 8)
	m = np.zeros(a.shape, bool)
	x_izq, x_der = xs.min() + ESQUINA * ancho, xs.max() - ESQUINA * ancho
	lab = cv2.cvtColor(np.ascontiguousarray(im[..., :3]), cv2.COLOR_RGB2LAB).astype(np.float32)
	piel = (a > 20) & (lab[..., 0] > 70) & (lab[..., 1] - 128 >= 6) & (lab[..., 1] - 128 > (lab[..., 2] - 128) * 0.8)
	for i in range(1, n):
		x, y, w, h, area = st[i]
		if area < 6:
			continue
		# las esquinas de la tunica que tocan el suelo (agachado) no son pies: estan
		# en los extremos de la figura y pegadas a la tunica
		cx = x + w / 2.0
		if (cx < x_izq or cx > x_der) and h < LARGO_LIBRE * alto and ((piel & (l == i)).sum() < ESQUINA_PIEL * area or area < PIE_MIN):
			continue
		if y + h >= y_suelo or h >= LARGO_LIBRE * alto:
			m |= l == i
	if m.any():
		# el talon que queda pegado a la tunica, rosado (la piel; la tela es mas oscura
		# o amarillenta): se crece desde lo pintado, en la franja del suelo y nunca dentro
		# de la masa de la tunica (agachado, sus paneles claros tambien pasan por piel y
		# se pintaban a motas); salvo la piel anaranjada de verdad (los paneles claros
		# son malva) en el tercio de abajo: la pierna que entra bajo la tunica se quedaba
		# con un trozo rosado
		hue = np.degrees(np.arctan2(lab[..., 2] - 128, lab[..., 1] - 128))
		naranja = piel & (hue > HUE_PIEL) & (np.hypot(lab[..., 1] - 128, lab[..., 2] - 128) > 10)
		# a manchas, no a motas: suavizado y sin las sueltas pequenas
		naranja = (cv2.GaussianBlur(naranja.astype(np.float32), (0, 0), 1.5) > 0.6) & (a > 20)
		naranja[:y_zona] = False
		nn, ln, sn, _ = cv2.connectedComponentsWithStats(naranja.astype(np.uint8), 8)
		naranja = np.isin(ln, [i for i in range(1, nn) if sn[i, 4] >= 12])
		piel[:y_suelo - 4] = False
		piel = (piel & ~tunica) | naranja
		for _ in range(TALON):
			m |= (cv2.dilate(m.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0) & piel
		# el pie como un bloque: sin motas de piel sueltas entre lo pintado (agachado
		# los talones salian moteados); solo en la franja del suelo
		banda = np.zeros(a.shape, bool)
		banda[y_suelo - 6:] = True
		cerrado = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))) > 0
		m |= cerrado & banda & (a > 20) & ~tunica
		# y lo de piel que quede pegado al pie en esa franja
		n2, l2 = cv2.connectedComponents((m | (piel & banda)).astype(np.uint8), connectivity=8)
		ids = np.unique(l2[m])
		m |= np.isin(l2, ids[ids > 0]) & piel & banda
		# los agujeritos claros que quedan dentro de lo pintado (el talon agachado)
		nh, lh, sh, _ = cv2.connectedComponentsWithStats((~m).astype(np.uint8), 4)
		for i in range(1, nh):
			if sh[i, 4] <= HUECO:
				hueco = lh == i
				aro = (cv2.dilate(hueco.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0) & ~hueco
				if m[aro].all():
					m |= hueco
		m = _por_facetas(im, m, y_zona, x_izq, x_der)
	return m


FACETA_DE = 7.0      # dos pixeles vecinos con menos diferencia (LAB) son la misma faceta
FACETA_ENTERA = 0.7  # faceta pintada en mas de esta parte: entera
FACETA_SI = 0.4      # y en mas de esta, si no es malva (HUE_MALVA: tono LAB por debajo)
HUE_MALVA = 15
FACETA_NO = 0.25     # y en menos (y pocos pixeles): nada
FACETA_MAX = 600     # mas grande (en la zona) es que la pierna se ha unido a la tunica: no se toca


def facetas(im):
	"""Las caras planas del dibujo (low poly): pixeles opacos unidos a su vecino si el
	color apenas cambia. -> etiquetas (-1 lo transparente)."""
	from scipy.sparse import coo_matrix
	from scipy.sparse.csgraph import connected_components
	h, w = im.shape[:2]
	lab = cv2.cvtColor(cv2.medianBlur(np.ascontiguousarray(im[..., :3]), 3), cv2.COLOR_RGB2LAB).astype(np.float32)
	op = im[..., 3] > 128
	idx = np.arange(h * w).reshape(h, w)
	fil, col = [], []
	for dy, dx in ((0, 1), (1, 0)):
		A, B = lab[:h - dy, :w - dx], lab[dy:, dx:]
		ok = op[:h - dy, :w - dx] & op[dy:, dx:] & (np.linalg.norm(A - B, axis=2) < FACETA_DE)
		fil.append(idx[:h - dy, :w - dx][ok])
		col.append(idx[dy:, dx:][ok])
	fil, col = np.concatenate(fil), np.concatenate(col)
	g = coo_matrix((np.ones(len(fil), np.uint8), (fil, col)), shape=(h * w, h * w))
	_, et = connected_components(g, directed=False)
	et = et.reshape(h, w)
	et[~op] = -1
	return et


def _por_facetas(im, m, y_zona, x_izq=None, x_der=None):
	"""Lo pintado, a caras enteras: pixel a pixel la pierna salia a rayas donde la
	faceta del talon o de la espinilla quedaba medio pintada (agachado, 2026-10-22)."""
	et = facetas(im)
	zona = np.zeros(m.shape, bool)
	zona[y_zona:] = True
	sel = et[zona & (et >= 0)]
	if not len(sel):
		return m
	tot = np.bincount(sel)
	pin = np.bincount(et[zona & m & (et >= 0)], minlength=len(tot))
	lab = cv2.cvtColor(np.ascontiguousarray(im[..., :3]), cv2.COLOR_RGB2LAB).astype(np.float32)
	med = [np.bincount(sel, lab[..., c][zona & (et >= 0)], minlength=len(tot)) / np.maximum(tot, 1) for c in range(3)]
	A, B = med[1] - 128, med[2] - 128
	hue = np.degrees(np.arctan2(B, A))
	for f in np.nonzero(pin)[0]:
		fr = pin[f] / tot[f]
		# medio pintada: entera, salvo que sea malva (los paneles claros de la tunica)
		if tot[f] > FACETA_MAX:
			continue
		if fr >= FACETA_ENTERA or (fr >= FACETA_SI and hue[f] > HUE_MALVA):
			m |= (et == f) & zona
		elif fr < FACETA_NO and pin[f] < 25:
			m &= ~(et == f)
	# las caras vecinas que son piel clara de verdad (la espinilla que asoma bajo la
	# tunica, anaranjada; los paneles claros de la tunica son malva). Si ya estan algo
	# pintadas (tocan la bota) con un margen mas ancho: andando agachado la espinilla
	# salia clara en unos fotogramas y oscura en otros (parpadeaba); las sin tocar,
	# pequenas y con el estrecho (las esquinas amarillentas de la tunica, 53, no)
	toca = np.unique(et[(cv2.dilate(m.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0) & zona & ~m & (et >= 0)])
	if x_izq is not None:
		cx = np.bincount(sel, np.nonzero(zona & (et >= 0))[1], minlength=len(tot)) / np.maximum(tot, 1)
		# los extremos, medidos en la franja de abajo (arriba puede sobresalir el brazo)
		xb = np.nonzero((zona & (im[..., 3] > 128)).any(0))[0]
		x_izq = max(x_izq, xb.min() + ESQUINA * (xb.max() - xb.min() + 1))
		x_der = min(x_der, xb.max() - ESQUINA * (xb.max() - xb.min() + 1))
	for f in toca:
		if np.hypot(A[f], B[f]) <= 10 or hue[f] <= HUE_PIEL:
			continue
		if pin[f] > 0:
			if not (tot[f] <= FACETA_MAX and med[0][f] > 70 and hue[f] <= HUE_PIEL_TOCADA):
				continue
			# la esquina amarillenta de la tunica (paso agachado): pequena, apenas tocada
			# y mas amarilla que la piel; la espinilla tiene al menos una de las tres
			if tot[f] < FACETA_PIEL and pin[f] < 0.3 * tot[f] and hue[f] > HUE_PIEL_MAX:
				continue
		elif not (3 <= tot[f] <= FACETA_PIEL and med[0][f] > 80 and hue[f] <= HUE_PIEL_MAX):
			continue
		if x_izq is not None and not (x_izq <= cx[f] <= x_der):
			continue
		m |= (et == f) & zona
	# las costuras entre caras (el borde suavizado de una a otra) que quedan claras
	op = im[..., 3] > 20
	for _ in range(2):
		vec = cv2.filter2D(m.astype(np.float32), -1, np.ones((3, 3), np.float32)) - m
		m |= ~m & op & zona & (vec >= 5)
	return m


TUNICA_DISCO = 21
ESQUINA = 0.12      # de pie: la parte de cada extremo donde lo corto pegado al suelo es tunica
ESQUINA_PIEL = 0.5  # salvo que sea casi todo piel (un pie en la punta)
PIE_MIN = 25        # y no una mota
HUECO = 20          # agujeros dentro del pie pintado que se rellenan
HUE_PIEL = 30       # tono (LAB) de la piel clara; la tunica clara va de -15 a 5
HUE_PIEL_MAX = 50   # (las esquinas amarillentas de la tunica, 53)
HUE_PIEL_TOCADA = 56  # la piel ya tocada por lo pintado (la espinilla sobre la bota)
FACETA_PIEL = 150    # cara de piel sin tocar pegada al pie que se pinta: como mucho este area
TALON = 6
TUMBADO = 1.3       # mas ancho que alto por esto: tumbado
LADO_PIES = 0.35    # tumbado, la parte del lado de los pies donde se buscan
PIES_LIBRE = 0.1         # la franja de abajo donde todo lo suelto es pie
LUZ_FIJA = 45.0          # el sombreado, respecto a una luz fija (no la de cada fotograma)


def pintar(im, color, libre=False):
	"""Casilla RGBA uint8 -> (pintada, mascara)."""
	m = mascara(im, libre)
	if not m.any():
		return im, m
	f = im.astype(np.float32)
	L = lum(f[..., :3])
	if FORMA:
		# luz fija: el mismo tono en todos los fotogramas (con la mediana de cada uno la
		# pierna cambiaba de un fotograma a otro y parpadeaba)
		k = np.clip(L / LUZ_FIJA, 0.85, 1.2)
		k = np.where(m, k, 1.0).astype(np.float32)
		k = cv2.GaussianBlur(k * m, (0, 0), 1.2) / np.maximum(cv2.GaussianBlur(m.astype(np.float32), (0, 0), 1.2), 1e-3)
	else:
		k = np.clip(L / max(float(np.median(L[m])), 1.0), 0.55, 1.7)
	f[..., :3][m] = np.asarray(color, np.float32) * k[m][:, None]
	return np.clip(f, 0, 255).round().astype(np.uint8), m


def pintar_mascara(im, m, color=(46, 36, 33)):
	"""Pinta la mascara dada como el pie (las marcas del usuario: marcas.py)."""
	if not m.any():
		return im
	f = im.astype(np.float32)
	L = lum(f[..., :3])
	k = np.clip(L / LUZ_FIJA, 0.85, 1.2)
	f[..., :3][m] = np.asarray(color, np.float32) * k[m][:, None]
	return np.clip(f, 0, 255).round().astype(np.uint8)

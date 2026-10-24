"""TERCERA TANDA DE LA DIAGONAL (2026-10-22): el juego completo de la diagonal para el
mundo de Dominus (alli no se usa el perfil: frente, espaldas y la diagonal). Carpetas
en Descargas/peregrino_diagonal_v3/ con inicio.png, fin.png y prompt.txt; LEEME.txt y
hoja_inicio_y_fin.png para revisar. Copia de todos los prompts en prompt_diagonal_v3.txt.

Lo que cambia frente a la v2 (los 01 y 02 de la v2 valen de tunica y de angulo, pero
la diagonal de espaldas anda mucho mas despacio que el frontal: un paso cada 0,94 s
y pasos cortos): EL PASO DEL FRONTAL, un paso cada 0,65 s, con pasos normales.

EL ANGULO Y LOS SITIOS, los de la v2 (referencias_diagonal_v2.py): tres cuartos (unos
35 grados). Lado IZQ = el camino que se aleja hacia ARRIBA A LA IZQUIERDA (el de la v2);
lado DER = el que se aleja hacia arriba a la derecha (sitios espejados en x).
  sin baculo     IZQ: vuelta_sb 42 espejado (de espaldas) y vuelta_sb 15 (de frente),
                 como la v2; DER: no hace falta, es el espejo en el juego
  baculo en la mano (derecha)  IZQ: el giro con baculo pasa por los dos tres cuartos de
                 este lado (vuelta_cb 30 de espaldas, vuelta_cb 6 de frente, los mas
                 parecidos al angulo de la diagonal; pintadas por el juego, garra vacia). DER: no hay poses (espejar lo
                 pasaria a la mano izquierda): salen de los videos de SACAR del lado
                 derecho (sin fotograma final), y con ellas la tanda LUEGO.
  baculo a la espalda (sacar y guardar): la pose sin baculo (espejada si toca) con el
                 baculo en su correa como lo pinta el juego en la diagonal
                 (peregrino_diagonal/secuencia.py, con_baculo).

    python referencias_diagonal_v3.py
"""
import importlib.util
import os
import shutil
import sys

import numpy as np
import cv2
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
DESCARGAS = os.path.join(os.path.expanduser('~'), 'Downloads', 'peregrino_diagonal_v3')
LIMPIOS = os.path.join(ANIM, 'peregrino_secuencia_frontal_sin', '04_limpios')
POSES = os.path.join(AQUI, 'poses_diagonal')
VERDE = (36, 215, 50)
W, H = 1920, 1080

sys.path.insert(0, os.path.join(ANIM, '..', '..', '..', 'tools', 'anim', 'hojas'))
import pies  # noqa: E402

_spec = importlib.util.spec_from_file_location('secuencia_diagonal', os.path.join(ANIM, 'peregrino_diagonal', 'secuencia.py'))
SEC = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(SEC)

# sitios del lado IZQ (x del eje, fila de los pies, capucha-pies); DER: x espejada
SITIOS = {'cerca': (1225, 1037, 630), 'lejos': (739, 871, 491), 'centro': (960, 1037, 630)}


# ------------------------------------------------------------------ las poses
def limpio(nombre, espejo=False):
	im = Image.open(os.path.join(LIMPIOS, nombre + '.png')).convert('RGBA')
	return im.transpose(Image.FLIP_LEFT_RIGHT) if espejo else im


def pintada(nombre):
	return Image.open(os.path.join(POSES, nombre + '.png')).convert('RGBA')


_capas = {}


def a_la_espalda(im, cara):
	"""El baculo en su correa, como lo pinta el juego en la diagonal."""
	if cara not in _capas:
		_capas[cara] = SEC.capa_del_baculo(cara)
	capa, ancla = _capas[cara]
	return SEC.con_baculo(im, capa, ancla)


def pose(nombre, lado):
	"""La pose (RGBA) de una clave: tq_lejos / tq_cerca / espaldas / frente, con sufijo
	_sb (nada en las manos), _cb (baculo en la mano) o _bg (baculo guardado a la espalda)."""
	base, modo = nombre.rsplit('_', 1)
	izq = lado == 'izq'
	if modo == 'cb':
		assert izq or base in ('espaldas', 'frente'), 'con baculo del lado derecho: tanda LUEGO'
		return pintada({'tq_lejos': 'tq_lejos_mano_v3', 'tq_cerca': 'tq_cerca_mano_v3',
						'espaldas': 'espalda_mano', 'frente': 'frente_mano'}[base])
	if base == 'espaldas':
		im = limpio('reposo_espalda_sb_000')
	elif base == 'frente':
		im = limpio('reposo_frente_sb_000')
	elif base == 'tq_lejos':
		im = limpio('vuelta_sb_042', espejo=izq)      # el 42 mira arriba a la derecha
	else:
		im = limpio('vuelta_sb_015', espejo=not izq)  # el 15 mira abajo a la derecha
	if modo == 'bg':
		im = a_la_espalda(im, 'lejos' if base in ('tq_lejos', 'espaldas') else 'cerca')
	return im


def medir(im):
	"""(eje x del tronco, fila de los pies, capucha-pies) sin el baculo."""
	a = (np.asarray(im)[..., 3] > 128).astype(np.uint8)
	sin_palo = cv2.morphologyEx(a, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (17, 17)))
	n, l, st, _ = cv2.connectedComponentsWithStats(sin_palo, 8)
	cuerpo = l == 1 + int(np.argmax(st[1:, 4]))
	ys = np.nonzero(cuerpo.any(1))[0]
	top, pie = int(ys.min()), int(np.nonzero(a.any(1))[0].max())
	banda = cuerpo[top + int(0.2 * (pie - top)):top + int(0.5 * (pie - top))]
	return float(np.median(np.nonzero(banda)[1])), pie, pie - top


PIE = (46, 36, 33)


def calzado(im):
	"""Los pies y piernas oscuros (los de las hojas salen claros, casi descalzos, y Veo
	copia lo que ve): la regla del frontal (colgando: no pinta el baculo), a la escala del
	master (~630 px de alto, el doble que el perfil)."""
	pies.escala(2.0)
	pies.reglas({'colgando': True})
	a, _ = pies.pintar(np.asarray(im).copy(), PIE)
	return Image.fromarray(a, 'RGBA')


def referencia(nombre, sitio, lado):
	im = calzado(pose(nombre, lado))
	x, pie_y, alto = SITIOS[sitio]
	if lado == 'der':
		x = W - x
	eje, pie, h = medir(im)
	s = alto / float(h)
	im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
	lienzo = Image.new('RGBA', (W, H), VERDE + (255,))
	lienzo.alpha_composite(im, (int(round(x - eje * s)), int(round(pie_y - pie * s))))
	return lienzo.convert('RGB')


# ------------------------------------------------------------------ los textos
CAMARA = ("Locked-off static camera, no camera movement at all: no pan, no zoom, no dolly, no tilt, "
		  "no cuts; the camera never follows him. Flat pure chroma-key green background (#24D732) "
		  "filling the whole frame, evenly lit: absolutely no shadow anywhere, no cast shadow on the "
		  "ground, no floor, no floor line, no props, no text, no logos, no on-screen interface.")
CAMARA_SIGUE = ("Smooth tracking shot: the camera moves {como} at exactly his speed, keeping the same "
				"distance the whole video, so on screen he always stays the same size and in the same "
				"place; no pan, no zoom, no tilt, no shake, no cuts. Flat pure chroma-key green background "
				"(#24D732) filling the whole frame, evenly lit: absolutely no shadow anywhere, no cast "
				"shadow on the ground, no floor, no floor line, no props, no text, no logos, no on-screen "
				"interface.")
OBJETO = {
	'sb': "His hands are empty: he carries nothing, no staff, no stick, no bag, no strap.",
	'cb': ("He holds his tall gnarled wooden staff upright in his RIGHT hand, exactly as in the first "
		   "frame; at its top an open antler-shaped claw, EMPTY: no orb, no ball, no gem, no glow, no light."),
	'bg': ("He carries his long wooden staff on his back, slung diagonally in a short leather holder, "
		   "exactly as in the first frame; its top is an open antler-shaped claw, EMPTY: no orb, no "
		   "ball, no gem, no glow, no light."),
}
BACULO_ANDANDO = (" The staff stays in his RIGHT hand the whole video: as he walks he moves it forward "
				  "with each step like a walking stick, its tip touching the ground lightly; it never "
				  "changes hands, never floats, never bends, never disappears and never grows.")
ANDAR = ("The walk of an old man, unhurried but steady: calm, measured steps of normal length, about "
		 "one step every 0.65 seconds (three steps every two seconds), the same pace from the first "
		 "step to the last; the body slightly bent forward, {brazos}; no slow motion, no shuffling, no "
		 "tiny steps, no swagger, no strutting, no swinging of the hips or shoulders, no bouncing.")
BRAZOS = {'sb': "the arms hanging loosely", 'cb': "the right hand on the staff, the left arm hanging loosely"}
CORRER = ("the hurried run of an old man, determined but heavy, not an athlete: about one step every "
		  "0.4 seconds, body leaning forward, elbows bent, the long cloak flapping around his legs; "
		  "no swagger, no bouncing.")
FIGURA = ("His head is covered by the soft grey cloth hood of his cloak, exactly the shape of the first "
		  "frame: a loose, floppy cloth hood that follows the shape of his head, part of the cloak, with "
		  "a low rounded top that falls slightly back. It is NOT a pointed wizard hat: no tall point, no "
		  "cone, no stiff peak sticking up; it never grows, stiffens or stands up. Same character "
		  "throughout: white beard, brown faceted patchwork cloak closed down to his ankles, the grey "
		  "diamond patch on his chest and the large grey chevron patch on the upper back; no trousers, "
		  "no shirt, no belt, nothing purple. His legs and feet are dressed: thin legs in dark hose and "
		  "soft dark leather shoes that cover his whole feet, one single very dark brown from the hem of "
		  "the cloak down to the tips of his shoes. His feet are normal, small, human-sized and in "
		  "proportion with his body, always inside those dark shoes: the shoes never come off, never "
		  "turn into skin or toes and never grow bigger. Same colours and lighting as the first and last "
		  "frames, crisp frames with no motion blur, soft matte texture, no flicker.")
SONIDO = {'sb': "Sound: only his soft footsteps and the rustle of the cloak; no music, no voice.",
		  'cb': "Sound: only his soft footsteps, the light tap of the staff on the ground and the rustle of the cloak; no music, no voice.",
		  'correr': "Sound: only his quick footsteps, the flapping of the cloak and a short tired breath when he stops; no music, no voice.",
		  'baculo': "Sound: cloth rustle, the wood sliding in the leather and the dry knock of the staff tip on the ground; no music, no voice."}


def dirs(lado):
	i, d = ('left', 'right') if lado == 'izq' else ('right', 'left')
	return {'lejos': 'facing the upper %s of the screen' % i, 'cerca': 'facing the lower %s of the screen' % d,
			'aleja': 'toward the upper %s of the screen' % i, 'acerca': 'toward the lower %s of the screen' % d,
			# girando desde recto: de espaldas, arriba-izquierda es su izquierda; de frente,
			# abajo-derecha es su izquierda (y al reves en el lado derecho)
			'gira_esp': 'LEFT' if lado == 'izq' else 'RIGHT', 'vuelve_esp': 'RIGHT' if lado == 'izq' else 'LEFT',
			'gira_fre': 'LEFT' if lado == 'izq' else 'RIGHT', 'vuelve_fre': 'RIGHT' if lado == 'izq' else 'LEFT'}


def quieto(base, d, modo):
	brazos = "his right hand holding the staff, his left arm relaxed" if modo == 'cb' else "his arms relaxed at his sides"
	return {'tq_lejos': "standing still, seen three-quarters from behind, %s, %s" % (d['lejos'], brazos),
			'tq_cerca': "standing still, seen three-quarters from the front, %s, %s" % (d['cerca'], brazos),
			'espaldas': "standing still, seen exactly from behind, %s" % brazos,
			'frente': "standing still, facing the camera straight on, %s" % brazos}[base]


def texto(titulo, accion, ini, modo, lado, sonido=None, camara=CAMARA, con_fin=True):
	d = dirs(lado)
	quien = ("A stylized low-poly 3D video game character, exactly the one in the first%s frame%s: an old "
			 "pilgrim %s. %s He is not a real person: flat-shaded faceted geometry, hand-painted colours, "
			 "no photorealism." % (' and last' if con_fin else '', 's' if con_fin else '', quieto(ini, d, modo if modo != 'bg' else 'sb'), OBJETO[modo]))
	if modo == 'cb' and 'walk' in accion:
		quien += BACULO_ANDANDO
	figura = FIGURA if con_fin else FIGURA.replace(' and last frames', ' frame')
	return '\n\n'.join([titulo, camara, quien, 'Action, one continuous take, at natural speed, no slow motion:\n' + accion.format(**d), figura, sonido or SONIDO['cb' if modo == 'cb' else 'sb']])


def andar(modo):
	return ANDAR.format(brazos=BRAZOS['cb' if modo == 'cb' else 'sb'])


PARA = "- {t0} to {t1} s: he slows down over two short steps and stops with both feet together, exactly in the pose, place, size and angle of the last frame.\n- {t1} to 8 s: he stands completely still exactly as in the last frame."


def para(t0, t1):
	return PARA.replace('{t0}', t0).replace('{t1}', t1)


def acciones(modo):
	A = andar(modo).replace('{', '{{').replace('}', '}}')
	return {
		'andar_alejandose': (
			"- 0 to 1 s: he stands still exactly as in the first frame.\n"
			"- 1 to 2 s: he starts walking in the direction he faces.\n"
			"- 2 to 6 s: he walks away from the camera in one straight diagonal line {aleja}, getting smaller "
			"with the distance, keeping exactly the same three-quarters angle as in the first frame. " + A + "\n"
			+ para('6', '7') + "\nHe never turns toward the camera, never turns to face straight away from it and never leaves the frame."),
		'andar_acercandose': (
			"- 0 to 1 s: he stands still exactly as in the first frame.\n"
			"- 1 to 2 s: he starts walking in the direction he faces.\n"
			"- 2 to 6 s: he walks toward the camera in one straight diagonal line {acerca}, getting bigger as he "
			"comes closer, keeping exactly the same three-quarters angle as in the first frame. " + A + "\n"
			+ para('6', '7') + "\nHe never turns to face the camera straight on and never turns his back to it; he is always seen full-body and never leaves the frame."),
		'volverse_lejos_y_volver': (
			"- 0 to 1 s: he stands still exactly as in the first frame.\n"
			"- 1 to 2.5 s: he turns around slowly, with two small steps, until he is {cerca}, three-quarters toward the camera.\n"
			"- 2.5 to 6.5 s: he walks back toward the camera along the same straight diagonal, {acerca}, getting "
			"bigger as he comes closer, always in that three-quarters angle. " + A + "\n"
			+ para('6.5', '7.5') + "\nHe never faces the camera straight on; he is always seen full-body and never leaves the frame."),
		'volverse_cerca_y_alejarse': (
			"- 0 to 1 s: he stands still exactly as in the first frame.\n"
			"- 1 to 2.5 s: he turns around slowly, with two small steps, until he is {lejos}, three-quarters from behind.\n"
			"- 2.5 to 6.5 s: he walks away from the camera along the same straight diagonal, {aleja}, getting "
			"smaller with the distance, always in that three-quarters angle. " + A + "\n"
			+ para('6.5', '7.5') + "\nHe never turns to face straight away from the camera and never leaves the frame."),
		'de_espaldas_a_la_diagonal': (
			"- 0 to 1 s: he stands still exactly as in the first frame, seen exactly from behind.\n"
			"- 1 to 2 s: as he sets off with his first step, he turns his body about 35 degrees to his {gira_esp}, "
			"so from then on he is seen three-quarters from behind, {lejos}. He does not turn on the spot: he turns while he starts walking.\n"
			"- 2 to 6 s: he walks away from the camera in one straight diagonal line {aleja}, getting smaller with "
			"the distance, always in that three-quarters angle. " + A + "\n"
			+ para('6', '7') + "\nHe never turns toward the camera and never leaves the frame."),
		'de_la_diagonal_a_espaldas': (
			"- 0 to 1 s: he stands still exactly as in the first frame, seen three-quarters from behind.\n"
			"- 1 to 4 s: he walks away from the camera in a straight diagonal line {aleja}, getting smaller with the distance. " + A + "\n"
			"- 4 to 5 s: without stopping, he turns his body about 35 degrees to his {vuelve_esp} while he walks, so "
			"he now walks straight away from the camera, seen exactly from behind.\n"
			+ para('5.5', '7') + "\nHe never turns toward the camera and never leaves the frame."),
		'de_frente_a_la_diagonal': (
			"- 0 to 1 s: he stands still exactly as in the first frame, facing the camera straight on.\n"
			"- 1 to 2 s: as he sets off with his first step, he turns his body about 35 degrees to his {gira_fre}, "
			"so from then on he is seen three-quarters from the front, {cerca}. He does not turn on the spot: he turns while he starts walking.\n"
			"- 2 to 6 s: he walks toward the camera in one straight diagonal line {acerca}, getting bigger as he "
			"comes closer, always in that three-quarters angle. " + A + "\n"
			+ para('6', '7') + "\nHe never turns his back to the camera; he is always seen full-body and never leaves the frame."),
		'de_la_diagonal_a_frente': (
			"- 0 to 1 s: he stands still exactly as in the first frame, seen three-quarters from the front.\n"
			"- 1 to 4 s: he walks toward the camera in a straight diagonal line {acerca}, getting bigger as he comes closer. " + A + "\n"
			"- 4 to 5 s: without stopping, he turns his body about 35 degrees to his {vuelve_fre} while he walks, so "
			"he now walks straight toward the camera, facing it straight on.\n"
			+ para('5.5', '7') + "\nHe never turns his back to the camera; he is always seen full-body and never leaves the frame."),
		'correr_alejandose': (
			"- 0 to 1 s: he stands still exactly as in the first frame.\n"
			"- 1 to 2 s: he leans forward and breaks into a run in the direction he faces, speeding up over his first three steps.\n"
			"- 2 to 5 s: he runs at a steady pace, " + CORRER + " Always the same direction and the same three-quarters angle, {lejos}.\n"
			"- 5 to 6.5 s: he slows down over three or four shorter steps, catching his breath, and stops with his feet together, exactly in the pose and angle of the first frame.\n"
			"- 6.5 to 8 s: he stands completely still exactly as in the last frame.\n"
			"He never turns toward the camera and never turns to face straight away from it."),
		'correr_acercandose': (
			"- 0 to 1 s: he stands still exactly as in the first frame.\n"
			"- 1 to 2 s: he leans forward and breaks into a run in the direction he faces, speeding up over his first three steps.\n"
			"- 2 to 5 s: he runs at a steady pace, " + CORRER + " Always the same direction and the same three-quarters angle, {cerca}.\n"
			"- 5 to 6.5 s: he slows down over three or four shorter steps, catching his breath, and stops with his feet together, exactly in the pose and angle of the first frame.\n"
			"- 6.5 to 8 s: he stands completely still exactly as in the last frame.\n"
			"He never turns to face the camera straight on and never turns his back to it."),
	}


def sacar(cara, con_fin):
	vista = '{lejos}, seen three-quarters from behind' if cara == 'lejos' else '{cerca}, seen three-quarters from the front'
	fin = ("exactly as in the last frame, holding the staff upright in his right hand" if con_fin else
		   "holding the staff upright in his right hand, its tip on the ground beside his right foot, in the same three-quarters angle")
	return ("He stands in place the whole video, " + vista + "; he does not walk and does not turn.\n"
			"- 0 to 1 s: he stands still exactly as in the first frame.\n"
			"- 1 to 2.5 s: he raises his right hand over his right shoulder, grabs the staff just below the claw and pulls it up out of the holder on his back.\n"
			"- 2.5 to 4 s: he brings the staff over his shoulder and down to his right side, and plants its bottom tip on the ground beside his right foot.\n"
			"- 4 to 8 s: he stands still " + fin + ".\n"
			"His feet stay in place, at most a small shift of weight; his head stays at the same height. "
			"The whole staff stays inside the frame at all times, even when he lifts it above his head.")


def guardar(cara):
	vista = '{lejos}, seen three-quarters from behind' if cara == 'lejos' else '{cerca}, seen three-quarters from the front'
	return ("He stands in place the whole video, " + vista + "; he does not walk and does not turn.\n"
			"- 0 to 1 s: he stands still exactly as in the first frame.\n"
			"- 1 to 2.5 s: he lifts the staff off the ground and raises it up over his right shoulder.\n"
			"- 2.5 to 4 s: he slides it down behind his back into the leather holder, so that it hangs slung diagonally across his back, and lowers his empty hand.\n"
			"- 4 to 8 s: he stands still exactly as in the last frame, arms relaxed, hands empty.\n"
			"His feet stay in place, at most a small shift of weight; his head stays at the same height. "
			"The whole staff stays inside the frame at all times, even when he lifts it above his head.")


# carpeta -> (lado, modo de la figura, accion, [(archivo, pose, sitio)], nota)
def videos():
	v = {}
	pasos = [('01', 'andar_alejandose', [('inicio', 'tq_lejos', 'cerca'), ('fin', 'tq_lejos', 'lejos')]),
			 ('02', 'andar_acercandose', [('inicio', 'tq_cerca', 'lejos'), ('fin', 'tq_cerca', 'cerca')]),
			 ('03', 'volverse_lejos_y_volver', [('inicio', 'tq_lejos', 'lejos'), ('fin', 'tq_cerca', 'cerca')]),
			 ('04', 'volverse_cerca_y_alejarse', [('inicio', 'tq_cerca', 'cerca'), ('fin', 'tq_lejos', 'lejos')]),
			 ('05', 'correr_alejandose', [('inicio_y_fin', 'tq_lejos', 'centro')]),
			 ('06', 'correr_acercandose', [('inicio_y_fin', 'tq_cerca', 'centro')]),
			 ('07', 'de_espaldas_a_la_diagonal', [('inicio', 'espaldas', 'cerca'), ('fin', 'tq_lejos', 'lejos')]),
			 ('08', 'de_la_diagonal_a_espaldas', [('inicio', 'tq_lejos', 'cerca'), ('fin', 'espaldas', 'lejos')]),
			 ('09', 'de_frente_a_la_diagonal', [('inicio', 'frente', 'lejos'), ('fin', 'tq_cerca', 'cerca')]),
			 ('10', 'de_la_diagonal_a_frente', [('inicio', 'tq_cerca', 'lejos'), ('fin', 'frente', 'cerca')])]
	for n, acc, refs in pasos:
		v['1_sin_baculo/%s_%s' % (n, acc)] = ('izq', 'sb', acc, [(a, p + '_sb', s) for a, p, s in refs], None)
	for n, acc, refs in pasos:
		if acc.startswith('correr'):
			continue      # con el baculo en la mano no se corre (como en el frontal)
		v['2_con_baculo_izq/%s_%s' % (n, acc)] = ('izq', 'cb', acc, [(a, p + '_cb', s) for a, p, s in refs], None)
		v['4_LUEGO_con_baculo_der/%s_%s' % (n, acc)] = ('der', 'cb', acc, [(a, p + '_cb', s) for a, p, s in refs], 'luego')
	for lado in ('izq', 'der'):
		for cara in ('lejos', 'cerca'):
			tq = 'tq_' + cara
			hay_cb = lado == 'izq'
			v['3_sacar_guardar/%s_sacar_%s' % (lado, cara)] = (lado, 'bg', ('sacar', cara, hay_cb),
				[('inicio', tq + '_bg', 'centro')] + ([('fin', tq + '_cb', 'centro')] if hay_cb else []), None)
			v[('3_sacar_guardar/%s_guardar_%s' if hay_cb else '4_LUEGO_con_baculo_der/%s_guardar_%s') % (lado, cara)] = (
				lado, 'cb', ('guardar', cara), [('inicio', tq + '_cb', 'centro'), ('fin', tq + '_bg', 'centro')], None if hay_cb else 'luego')
	return v


TITULOS = {
	'andar_alejandose': 'ANDAR ALEJANDOSE EN DIAGONAL, ARRANCAR Y PARARSE', 'andar_acercandose': 'ANDAR ACERCANDOSE EN DIAGONAL, ARRANCAR Y PARARSE',
	'volverse_lejos_y_volver': 'VOLVERSE LEJOS Y VOLVER HACIA LA CAMARA', 'volverse_cerca_y_alejarse': 'VOLVERSE CERCA Y ALEJARSE',
	'correr_alejandose': 'CORRER ALEJANDOSE (la camara va con el)', 'correr_acercandose': 'CORRER ACERCANDOSE (la camara va con el)',
	'de_espaldas_a_la_diagonal': 'DE ESPALDAS RECTO A LA DIAGONAL (esquina con un plano de espaldas)',
	'de_la_diagonal_a_espaldas': 'DE LA DIAGONAL A ESPALDAS RECTO (esquina con un plano de espaldas)',
	'de_frente_a_la_diagonal': 'DE FRENTE RECTO A LA DIAGONAL (esquina con un plano de frente)',
	'de_la_diagonal_a_frente': 'DE LA DIAGONAL A FRENTE RECTO (esquina con un plano de frente)',
}
MODOS = {'sb': 'sin baculo', 'cb': 'con el baculo en la mano', 'bg': 'baculo a la espalda'}
LADOS = {'izq': 'lado IZQ: se aleja hacia arriba a la izquierda', 'der': 'lado DER: se aleja hacia arriba a la derecha'}


def prompt(carpeta, lado, modo, acc, refs):
	nombre = carpeta.split('/')[-1]
	fotos = ', '.join('%s.png' % a for a, _, _ in refs) if refs else 'solo inicio (ver FALTA.txt)'
	if isinstance(acc, tuple):
		con_fin = acc[0] == 'guardar' or acc[2]
		cuerpo = sacar(acc[1], acc[2]) if acc[0] == 'sacar' else guardar(acc[1])
		ini = 'tq_' + acc[1]
		titulo = '%s EL BACULO PARADO EN DIAGONAL, %s (%s)' % (acc[0].upper(), 'de tres cuartos de espaldas' if acc[1] == 'lejos' else 'de tres cuartos de frente', LADOS[lado])
		d = dirs(lado)
		t = texto(titulo.upper(), cuerpo, ini, modo, lado, SONIDO['baculo'], con_fin=con_fin)
		t = t.replace('{lejos}', d['lejos']).replace('{cerca}', d['cerca'])
	else:
		ini = refs[0][1].rsplit('_', 1)[0]
		correr = acc.startswith('correr')
		cam = CAMARA_SIGUE.format(como='behind him' if acc == 'correr_alejandose' else 'backward in front of him') if correr else CAMARA
		t = texto('%s %s (%s, %s)' % (nombre[:2], TITULOS[acc], MODOS[modo], LADOS[lado]), acciones(modo)[acc], ini, modo, lado,
				  SONIDO['correr'] if correr else None, camara=cam)
	return 'Imagenes: %s\n\n%s\n' % (fotos, t)


LEEME = """EL PEREGRINO EN DIAGONAL, TERCERA TANDA: EL JUEGO COMPLETO (2026-10-22)
=====================================================================
Para el mundo de Dominus (alli no hay perfil: frente, espaldas y diagonal). Una carpeta
por video, con su prompt.txt y sus fotogramas: inicio.png (y fin.png) donde empieza y
acaba el movimiento, con la camara y el angulo de los dos videos buenos de la v2.

LO QUE MAS IMPORTA ESTA VEZ: EL PASO. La v2 salio bien de tunica y de angulo, pero
alejandose anda mucho mas despacio que el frontal (un paso cada 0,94 s y pasos cortos).
Aqui todos piden el paso del frontal: un paso cada 0,65 s, pasos normales. Al revisar,
contad los pasos: en los 4 s que anda, unos 6 pasos.

LADOS: IZQ = el camino que se aleja hacia ARRIBA A LA IZQUIERDA (el de la v2); DER = el
que se aleja hacia arriba a la derecha. Sin baculo el DER es el espejo del IZQ (no hay
que pedirlo). Con el baculo en la mano NO (el espejo lo pasa a la mano izquierda): el
DER tiene sus propios videos.

CARPETAS Y ORDEN
  1_sin_baculo           (solo IZQ)
     01-04  andar alejandose / acercandose, volverse lejos / cerca      IMPRESCINDIBLES
     05-06  correr alejandose / acercandose                             si en Dominus se corre
     07-10  esquinas con un plano recto de espaldas o de frente         OPCIONALES: si en
            esa esquina hay corte de camara, no hacen falta
  2_con_baculo_izq       lo mismo con el baculo en la mano (sin correr)
  3_sacar_guardar        sacar y guardar parado en diagonal, de tres cuartos de espaldas
                         (lejos) y de frente (cerca), los dos lados. Los dos de SACAR del
                         lado DER van SIN fotograma final: no hay aun una pose con baculo
                         de ese lado. De la toma buena saco la pose final y con ella
                         preparo la tanda 4.
  4_LUEGO_con_baculo_der DESPUES de los sacar del lado DER: prompts listos, las imagenes
                         las pongo yo con esas tomas (ver FALTA.txt).

AJUSTES: 16:9, Veo 3.1 - Quality, 8 s, con audio; DESCARGAR EN 1080p (upscale).
2-4 tomas de cada uno.

AL REVISAR LAS TOMAS
  - El paso: unos 6 pasos en los 4 s que anda; ni pasitos ni camara lenta.
  - Inicio y fin, exactamente los fotogramas de referencia (pose, sitio, tamano).
  - Que ande por el suelo de verdad, sin pasitos en el sitio (salvo correr y sacar /
    guardar, que son en el sitio).
  - La tunica: el dibujo de la referencia (rombo gris del pecho, chevron de la espalda).
  - Los pies calzados y oscuros; la capucha blanda, nunca de mago.
  - Con baculo: siempre en la mano DERECHA, sin cambiar de mano ni desaparecer.
  - Sin sombra en el suelo; nada encima del personaje.
"""


def main():
	if os.path.isdir(DESCARGAS):
		shutil.rmtree(DESCARGAS)
	todos = []
	for carpeta, (lado, modo, acc, refs, nota) in videos().items():
		d = os.path.join(DESCARGAS, *carpeta.split('/'))
		os.makedirs(d)
		hechas = []
		for archivo, p, sitio in refs:
			if nota == 'luego' and p.endswith('_cb'):
				continue
			referencia(p, sitio, lado).save(os.path.join(d, archivo + '.png'))
			hechas.append((archivo, p, sitio))
		if nota == 'luego':
			open(os.path.join(d, 'FALTA.txt'), 'w', encoding='utf-8', newline='\r\n').write(
				'Las imagenes con el baculo en la mano del lado DER salen de las tomas buenas de\n'
				'3_sacar_guardar/der_sacar_lejos y der_sacar_cerca: pasamelas y las pongo aqui.\n'
				'Necesita: %s\n' % ', '.join('%s.png (%s, %s)' % (a, p, s) for a, p, s in refs))
		t = prompt(carpeta, lado, modo, acc, refs)
		open(os.path.join(d, 'prompt.txt'), 'w', encoding='utf-8', newline='\r\n').write(t)
		todos.append('### %s\n%s' % (carpeta, t))
		print('%-48s %s' % (carpeta, ', '.join(a for a, _, _ in hechas) or '(luego)'))
	open(os.path.join(DESCARGAS, 'LEEME.txt'), 'w', encoding='utf-8', newline='\r\n').write(LEEME)
	open(os.path.join(AQUI, 'prompt_diagonal_v3.txt'), 'w', encoding='utf-8').write(
		'PROMPTS: EL PEREGRINO EN DIAGONAL, TERCERA TANDA (2026-10-22). Las referencias las hace\n'
		'referencias_diagonal_v3.py en Descargas/peregrino_diagonal_v3/.\n\n### LEEME\n' + LEEME + '\n' + '\n'.join(todos))
	# hoja de revision: inicio y fin superpuestos, con el nombre
	cel = []
	for carpeta in sorted(videos()):
		d = os.path.join(DESCARGAS, *carpeta.split('/'))
		ims = [Image.open(os.path.join(d, f)) for f in ('inicio.png', 'fin.png', 'inicio_y_fin.png') if os.path.exists(os.path.join(d, f))]
		if not ims:
			continue
		m = ims[0]
		if len(ims) > 1:
			# las dos figuras enteras: la del fin donde no es croma
			x0, x1 = np.asarray(ims[0]).astype(int), np.asarray(ims[1]).astype(int)
			fig = np.abs(x1 - np.array(VERDE)).sum(-1) > 60
			m = Image.fromarray(np.where(fig[..., None], x1, x0).astype(np.uint8))
		c = cv2.cvtColor(np.asarray(m.resize((W // 4, H // 4))), cv2.COLOR_RGB2BGR)
		cv2.putText(c, carpeta.replace('/', ' '), (5, 18), cv2.FONT_HERSHEY_SIMPLEX, 0.42, (0, 0, 0), 1)
		cel.append(cv2.copyMakeBorder(c, 2, 2, 2, 2, cv2.BORDER_CONSTANT, value=(30, 30, 30)))
	filas = [np.hstack(cel[i:i + 4] + [np.zeros_like(cel[0])] * (4 - len(cel[i:i + 4]))) for i in range(0, len(cel), 4)]
	cv2.imwrite(os.path.join(DESCARGAS, 'hoja_inicio_y_fin.png'), np.vstack(filas))
	print('->', DESCARGAS)


if __name__ == '__main__':
	main()

"""Monta la secuencia con baston de frente / espaldas de UN solo video.

Sale de _todos/ (montar.py: los 240 fotogramas a la casilla 584x800, capucha-pies
628). Todo del mismo video: misma capucha, misma tunica, mismo baston (el usuario
pidio coherencia: la vuelta y los andares de videos distintos cambiaban el ancho
de la capucha). Animaciones (24 fps, las del video):

  reposo_frente_cb    el fotograma 18 con la respiracion dibujada (ver RESP), 2,5 s
  arranque_frente_cb  29-52: arranca y entra en el bucle por su fotograma 8
  andar_frente_cb     bucle 45-85 (41); los 8 primeros cerrados por flujo hacia
                      86-93 (lo que sigue al 85 en el video), asi 85 -> 45' casa
  vuelta_cb           121-153, de frente a espaldas (al reves, de espaldas a frente)
  arranque_espalda_cb 154-170, entra en el bucle de espaldas por su fotograma 6
  andar_espalda_cb    bucle 165-202 (38), 6 primeros cerrados hacia 203-208
  reposo_espalda_cb   el 229, igual (sin baston: 9 y 232, ver CONFIG)

y PUENTES por flujo optico entre fotogramas del propio video (sin fundidos, sin
doble imagen), "pt_<de>_<a>": paradas (pies juntos del andar -> reposo), salir
del reposo a andar, y entrar y salir de la vuelta desde el reposo y desde el
andar (pies juntos). Del reposo se sale siempre desde su fotograma base (la
escena exhala deprisa, 0,2 s como mucho, y entra en el puente).

Escribe 04_limpios/<anim>_<k>.png (lo que va a la hoja), animaciones.json (para
tools/anim/_spriteframes.py) y assets/characters/magnus/secuencia_frontal.json
(para la escena: bucles, pies juntos, salidas, puentes, paso, alturas y la bola).
    python secuencia.py
"""
import glob, importlib.util, json, os, shutil, sys
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
PROY = os.path.abspath(os.path.join(ANIM, '..', '..', '..'))
spec = importlib.util.spec_from_file_location('puente', os.path.join(ANIM, 'magnus_puentes_frontal', 'puente.py'))
P = importlib.util.module_from_spec(spec); spec.loader.exec_module(P)
spec = importlib.util.spec_from_file_location('igualar_capucha', os.path.join(ANIM, 'igualar_capucha.py'))
IC = importlib.util.module_from_spec(spec); spec.loader.exec_module(IC)

# Un video por modo. python secuencia.py [magnus_secuencia_frontal_sin]
#  con baston  _fuentes/Pilgrim_walking_turning_full_20261008161217.mp4
#  sin baston  _fuentes/Pilgrim_walking_animation_sequence_20261008164615.mp4 (mas
#              cerca de la camara; bucles casi perfectos: cierran a 0,033 y 0,051).
#              Lleva el baston a la espalda (en la funda de cuero) calculado por sprite.
CONFIG = {
    'magnus_secuencia_frontal': dict(
        suf='_cb', pre='pt_', json='secuencia_frontal.json', H1=460.0, a_espalda=False,
        FRENTE=dict(a=45, P=41, m=8), ESPALDA=dict(a=165, P=38, m=6),
        # reposo 14-22: en 1-13 asienta un pie y desde 23 lo levanta para arrancar
        # (de ida y vuelta, la pierna iba y venia)
        REPOSO_F=(14, 22), REPOSO_B=(223, 236), VUELTA=(121, 153), ARR_F0=29,
        BASE_F=18, BASE_B=229),
    'magnus_secuencia_frontal_sin': dict(
        suf='_sb', pre='ps_', json='secuencia_frontal_sin.json', H1=610.0, a_espalda=True,
        # al venir hacia la camara crece muy poco (617 -> 645 en 100 fotogramas;
        # alejandose, 649 -> 579 en 60): la camara retrocede con el. Andaria casi
        # en el sitio: el de frente avanza por ciclo lo mismo que el de espaldas.
        paso_frente_como_espalda=True,
        FRENTE=dict(a=38, P=31, m=8), ESPALDA=dict(a=170, P=36, m=6),
        REPOSO_F=(1, 17), REPOSO_B=(224, 240), VUELTA=(119, 152), ARR_F0=18,
        BASE_F=9, BASE_B=232),
}
JOB = sys.argv[1] if len(sys.argv) > 1 else 'magnus_secuencia_frontal'
C = CONFIG[JOB]
D = os.path.join(ANIM, JOB)
SUF, PRE = C['suf'], C['pre']
TODOS = os.path.join(D, '_todos'); SAL = os.path.join(D, '04_limpios')
# los puentes en otra hoja (todo junto no cabe en un atlas de 4096x4096)
JOB_PT = JOB + '_pt'
SAL_PT = os.path.join(ANIM, JOB_PT, '04_limpios')
JSON_ESCENA = os.path.join(PROY, 'assets', 'characters', 'magnus', C['json'])
MED = json.load(open(os.path.join(D, 'medidas.json')))
H = MED['h']                     # capucha-pies suavizada por fotograma
H1 = C['H1']                     # capucha-pies de video con la que la escena tiene escala 1
FPS = 24.0
FRENTE, ESPALDA = C['FRENTE'], C['ESPALDA']
REPOSO_F, REPOSO_B, VUELTA = C['REPOSO_F'], C['REPOSO_B'], C['VUELTA']
ARR_F = (C['ARR_F0'], FRENTE['a'] + FRENTE['m'] - 1)
ARR_B = (VUELTA[1] + 1, ESPALDA['a'] + ESPALDA['m'] - 1)     # sigue a la vuelta en el video
# EL REPOSO (2026-10-09): UN fotograma (BASE_F / BASE_B, los dos pies apoyados) y
# la respiracion dibujada encima deformandolo. Con los fotogramas del video, aun
# alineados, el usuario lo veia temblar: el tramo quieto no tiene respiracion de
# verdad (0,2-1 px sueltos sin direccion) y la textura del video "hierve" (0,04-0,07
# por fotograma aun compensando el movimiento), y en 9 fotogramas de ida y vuelta
# (0,67 s) todo eso va y viene 1,5 veces por segundo. En el perfil hierve igual pero
# lo tapa una respiracion amplia y lenta (2,5 s). Aqui: textura quieta (una sola
# imagen) y respiracion lenta: hombros y cabeza suben SUBE px de master y el pecho
# se ensancha ENSANCHA, de la cadera para arriba (la caida de la tunica quieta),
# en PERIODO s (el del reposo de perfil y su audio), a FPS_R fps, ida y vuelta con
# subida senoidal. El baston en la mano no se deforma (ni la mano que lo coge).
RESP = dict(PERIODO=2.5, FPS_R=12.0, SUBE=3.5, ENSANCHA=0.012)

_cache = {}


def F(k):
    if k not in _cache:
        _cache[k] = Image.open(os.path.join(TODOS, 'c_%03d.png' % k)).convert('RGBA')
    return _cache[k]


def mezcla(A, B, t):
    """A llevado hacia B una fraccion t por flujo, mezclado con B traido desde A."""
    a, b = P.premul(A), P.premul(B)
    a8 = (a[..., :3] * 255).astype(np.uint8); b8 = (b[..., :3] * 255).astype(np.uint8)
    fab, fba = P.flujo(a8, b8), P.flujo(b8, a8)
    m = (1 - t) * P.deformar(a, fab, t) + t * P.deformar(b, fba, 1 - t)
    al = np.clip(m[..., 3:], 1e-4, 1)
    rgb = np.where(m[..., 3:] > 1e-4, m[..., :3] / al, 0)
    return Image.fromarray((np.dstack([rgb, m[..., 3]]) * 255).round().clip(0, 255).astype(np.uint8), 'RGBA')


def respiracion(base, baston_x=None):
    """(imagenes de la mitad que inspira, s de cada una, geometria). Ver RESP arriba."""
    import cv2
    K = int(round(RESP['PERIODO'] * RESP['FPS_R'] / 2)) + 1
    a = P.premul(base)
    op = a[..., 3] > 0.5
    ys = np.nonzero(op.any(1))[0]; top, pie = int(ys.min()), int(ys.max()); alto = pie - top
    y_hom, y_cad = top + 0.24 * alto, top + 0.52 * alto
    banda = op[int(top + 0.30 * alto):int(top + 0.45 * alto)].copy()
    h, w = op.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    mascara = np.ones((h, w), np.float32)
    if baston_x is not None:
        # el palo (+-22 px) y, por encima de los hombros, la garra (mas ancha: +-50)
        media = 22.0 + 28.0 * np.clip((y_hom - yy) / 40.0, 0, 1)
        mascara = np.clip((np.abs(xx - baston_x) - media) / 20.0, 0, 1)
        banda[:, max(0, int(baston_x) - 30):int(baston_x) + 30] = False
    cx = float(np.median(np.nonzero(banda)[1]))
    t = np.clip((y_cad - yy) / (y_cad - y_hom), 0, 1); sube = t * t * (3 - 2 * t)
    y0 = top + 0.20 * alto
    pecho = np.where((yy > y0) & (yy < top + 0.52 * alto), np.clip(np.sin(np.pi * (yy - y0) / (0.32 * alto)), 0, 1), 0)
    out, ss = [], []
    for k in range(K):
        s_ = (1 - np.cos(np.pi * k / (K - 1))) / 2
        dy = -RESP['SUBE'] * sube * s_ * mascara
        dx = (xx - cx) * RESP['ENSANCHA'] * pecho * s_ * mascara
        b = cv2.remap(a, (xx - dx).astype(np.float32), (yy - dy).astype(np.float32), cv2.INTER_LINEAR, borderValue=0)
        al = np.clip(b[..., 3:], 1e-4, 1)
        rgb = np.where(b[..., 3:] > 1e-4, b[..., :3] / al, 0)
        out.append(Image.fromarray((np.dstack([rgb, b[..., 3]]) * 255).round().clip(0, 255).astype(np.uint8), 'RGBA'))
        ss.append(float(s_))
    return out, ss, (y_hom, y_cad)


def alinear(ims):
    """Fija el reposo: cada fotograma encajado (afin, ECC de OpenCV, subpixel) con
    el del medio. El usuario veia temblar al personaje parado: entre fotogramas del
    reposo se movia la figura entera (todos los contornos por igual, baston
    incluido: 1-2 px de master de la normalizacion por fotograma y del propio
    video), no la respiracion. Tras alinear solo queda lo que cambia de verdad."""
    import cv2
    ref = P.premul(ims[len(ims) // 2])
    g_ref = (ref[..., :3].mean(2) * 255).astype(np.float32)
    out = []
    for im in ims:
        a = P.premul(im)
        g = (a[..., :3].mean(2) * 255).astype(np.float32)
        w = np.eye(2, 3, dtype=np.float32)
        try:
            _, w = cv2.findTransformECC(g_ref, g, w, cv2.MOTION_AFFINE,
                                        (cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 200, 1e-6), None, 5)
        except cv2.error:
            pass
        h, wd = g.shape
        b = cv2.warpAffine(a, w, (wd, h), flags=cv2.INTER_LINEAR + cv2.WARP_INVERSE_MAP, borderValue=0)
        al = np.clip(b[..., 3:], 1e-4, 1)
        rgb = np.where(b[..., 3:] > 1e-4, b[..., :3] / al, 0)
        out.append(Image.fromarray((np.dstack([rgb, b[..., 3]]) * 255).round().clip(0, 255).astype(np.uint8), 'RGBA'))
    return out


def puente(A, B, n):
    return [mezcla(A, B, k / (n + 1)) for k in range(1, n + 1)]


def bucle(c):
    """Fotogramas del bucle a..a+P-1 con los m primeros cerrados por flujo: el j
    va de lo que sigue al ultimo (a+P+j) a su original (a+j)."""
    a, Pn, m = c['a'], c['P'], c['m']
    out = []
    for j in range(Pn):
        if j < m:
            out.append(mezcla(F(a + Pn + j), F(a + j), (j + 1) / (m + 1)))
        else:
            out.append(F(a + j))
    return out


def pies_juntos(frames):
    """Los dos fotogramas del ciclo con los pies mas juntos (uno por paso)."""
    v = []
    for im in frames:
        al = np.asarray(im)[..., 3] > 128
        ys = np.nonzero(al.any(1))[0]; yb = ys.max()
        cx = int(np.median(np.nonzero(al[yb - 300:yb - 150])[1]))
        banda = al[yb - 45:yb + 1, cx - 75:cx + 75]
        xs = np.nonzero(banda.any(0))[0]
        izq = np.nonzero(al[:, cx - 75:cx].any(1))[0].max(); der = np.nonzero(al[:, cx:cx + 75].any(1))[0].max()
        v.append((xs.max() - xs.min()) + 2 * abs(int(izq) - int(der)))
    v = np.array(v, float); n = len(v)
    i1 = int(np.argmin(v))
    lejos = [(v[k], k) for k in range(n) if min(abs(k - i1), n - abs(k - i1)) >= n // 3]
    i2 = min(lejos)[1]
    return sorted([i1, i2])


def bola(im):
    """Bola en el hueco de la garra (como frontal.py para la vuelta): lo saturado y
    calido (madera y oro; la capucha es gris) mas alto por encima de los hombros;
    centrada en sus 40 px de arriba, 0,43 anchos de garra bajo las puntas.
    En px de hoja respecto al centro de la casilla de 400."""
    a = np.asarray(im).astype(float); rgb = a[..., :3] / 255
    mx, mn = rgb.max(2), rgb.min(2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    m = (a[..., 3] > 128) & (sat > 0.35) & (rgb[..., 0] >= rgb[..., 1])
    m[330:] = False
    ys = np.nonzero(m.any(1))[0]
    if len(ys) == 0:
        return None
    top = int(ys.min()); cols = np.nonzero(m[top:top + 40])[1]
    return [(cols.min() + cols.max()) / 4 - 146, (top + 0.43 * 79) / 2 - 200]


# ---------------------------------------------------------------- piezas
anims = {}      # nombre -> lista de imagenes
BASE_F, BASE_B = C['BASE_F'], C['BASE_B']


def _baston_x(k):
    """Columna del baston en la mano (px de master), por la bola; None sin baston."""
    if C['a_espalda']:
        return None
    b = bola(F(k))
    return None if b is None else 2 * (b[0] + 146)


anims['reposo_frente'+SUF], S_RESP, GEO_F = respiracion(F(BASE_F), _baston_x(BASE_F))
anims['reposo_espalda'+SUF], _, GEO_B = respiracion(F(BASE_B), _baston_x(BASE_B))
K_RESP = len(S_RESP)
anims['arranque_frente'+SUF] = [F(k) for k in range(ARR_F[0], ARR_F[1] + 1)]
anims['arranque_espalda'+SUF] = [F(k) for k in range(ARR_B[0], ARR_B[1] + 1)]
anims['andar_frente'+SUF] = bucle(FRENTE)
anims['andar_espalda'+SUF] = bucle(ESPALDA)
anims['vuelta'+SUF] = [F(k) for k in range(VUELTA[0], VUELTA[1] + 1)]
pj_f = pies_juntos(anims['andar_frente'+SUF]); pj_b = pies_juntos(anims['andar_espalda'+SUF])
print('pies juntos: frente', pj_f, 'espalda', pj_b)


def ida_vuelta(n):
    return list(range(n)) + list(range(n - 2, 0, -1))


rf_orden = ida_vuelta(len(anims['reposo_frente'+SUF])); rb_orden = ida_vuelta(len(anims['reposo_espalda'+SUF]))
puentes = {}     # nombre -> {de: [anim, pos], a: [anim, pos], n}
REPOSO_ENTRADA = 0


def hacer(nombre, de, a, img_de, img_a, n):
    anims[nombre] = puente(img_de, img_a, n)
    puentes[nombre] = {'de': de, 'a': a, 'n': n}


VF0, VF1 = F(VUELTA[0]), F(VUELTA[1])
# del reposo se sale siempre desde el fotograma base (la escena antes exhala deprisa)
RF0, RB0 = anims['reposo_frente'+SUF][0], anims['reposo_espalda'+SUF][0]
hacer(PRE + 'rf_arr', ['reposo_frente'+SUF, 0], ['arranque_frente'+SUF, 0], RF0, anims['arranque_frente'+SUF][0], 3)
hacer(PRE + 'rf_vu', ['reposo_frente'+SUF, 0], ['vuelta'+SUF, 0], RF0, VF0, 4)
hacer(PRE + 'rb_arr', ['reposo_espalda'+SUF, 0], ['arranque_espalda'+SUF, 0], RB0, anims['arranque_espalda'+SUF][0], 3)
hacer(PRE + 'rb_vu', ['reposo_espalda'+SUF, 0], ['vuelta'+SUF, len(anims['vuelta'+SUF]) - 1], RB0, VF1, 4)
for j in pj_f:
    im = anims['andar_frente'+SUF][j]
    hacer(PRE + 'af%d_rf' % j, ['andar_frente'+SUF, j], ['reposo_frente'+SUF, REPOSO_ENTRADA], im, anims['reposo_frente'+SUF][0], 5)
    hacer(PRE + 'af%d_vu' % j, ['andar_frente'+SUF, j], ['vuelta'+SUF, 0], im, VF0, 4)
for j in pj_b:
    im = anims['andar_espalda'+SUF][j]
    hacer(PRE + 'ab%d_rb' % j, ['andar_espalda'+SUF, j], ['reposo_espalda'+SUF, REPOSO_ENTRADA], im, anims['reposo_espalda'+SUF][0], 5)
    hacer(PRE + 'ab%d_vu' % j, ['andar_espalda'+SUF, j], ['vuelta'+SUF, len(anims['vuelta'+SUF]) - 1], im, VF1, 4)
# salidas de la vuelta: hacia delante acaba de espaldas (153); al reves, de frente (121)
hacer(PRE + 'vu_rb', ['vuelta'+SUF, len(anims['vuelta'+SUF]) - 1], ['reposo_espalda'+SUF, REPOSO_ENTRADA], VF1, anims['reposo_espalda'+SUF][0], 4)
hacer(PRE + 'vu_rf', ['vuelta'+SUF, 0], ['reposo_frente'+SUF, REPOSO_ENTRADA], VF0, anims['reposo_frente'+SUF][0], 4)
hacer(PRE + 'vu_arrf', ['vuelta'+SUF, 0], ['arranque_frente'+SUF, 0], VF0, anims['arranque_frente'+SUF][0], 4)
# 153 -> 154 (arranque de espaldas) es seguido en el video: sin puente


# ---------------------------------------------------------------- para la escena
def h_de(rango):
    return [H[k - 1] for k in range(rango[0], rango[1] + 1)]


def paso(c):
    """Cambio de 1/escala por fotograma en el bucle (escala = h / H1): recta 1/h."""
    t = np.arange(c['a'], c['a'] + c['P']); hh = np.array([H[k - 1] for k in t])
    return float(np.polyfit(t, H1 / hh, 1)[0])


# EL BASTON A LA ESPALDA EN 3D (2026-10-09). Un segmento recto del hombro
# derecho (la bola: X_BOLA px de master a su derecha, 39 bajo la punta de la
# capucha) a la cadera izquierda (DX_PIE mas a su izquierda, DY_PIE mas abajo: la
# diagonal de 0,34 rad del concepto vista de espaldas). Para cada fotograma, el
# giro del cuerpo THETA (0 de frente, +-180 de espaldas; + mirando a la derecha
# de la pantalla) y se proyecta el segmento (posicion y angulo en pantalla).
# El baston va en un PLANO pegado por detras a la espalda: un palo recto apoyado
# en la espalda toca lo mas saliente (omoplatos, la tunica en la cadera), no
# sigue la curva. El plano es la recta tangente por detras al contorno del
# fotograma de perfil (de la bola al pie; la espalda se inclina hacia atras al
# bajar) y el palo va R_BASTON por detras (el medio grueso de la funda). Antes
# iba sobre una espalda eliptica y de perfil el palo y la funda caian dentro de
# la silueta, ENCIMA de la manga del brazo de este lado (el usuario: "la funda
# se ve sobre el brazo"); asi, de perfil, el palo y la funda asoman por detras
# de la espalda, como un carcaj.
# Delante o detras del cuerpo (la escena dibuja el baston entero detras y una
# copia delante recortada de arriba hasta "corte"): de espaldas a mas de 90 el
# plano mira a la camara y va entero delante; antes, detras (asoma lo que sale
# de la silueta), salvo la bola y la garra (CORTE_GARRA) desde THETA_BOLA: la
# bola, al lado de la capucha, queda mas cerca de la camara que el lado de la
# capucha desde tan(THETA) = fondo / (X_BOLA - semiancho de la capucha); antes
# la tapaba la punta de la capucha hasta los 90 y aparecia delante de golpe.
# La funda, un tubo aplastado: de canto se ve estrecha. Ancho |cos THETA|, sin
# bajar de FUNDA_CANTO (su grueso / su ancho).
# En la vuelta THETA sale de la anchura del torso a la altura del pecho (filas
# 220-260 bajo la punta de la capucha): |cos THETA| = raiz((a^2 - D^2)/(W^2 - D^2)),
# con W el de frente / de espaldas y D el minimo (el perfil); el signo, de hacia
# donde se adelanta la cabeza.
X_BOLA, DX_PIE, DY_PIE, DY_BOLA = 60.0, 142.0, 402.0, 39.0
L_BASTON = 24.0 + 189.0           # px de hoja de la bola al pie (baston.png, pivote a 24 bajo la bola)
T_FUNDA = 80.0 / L_BASTON         # la funda, 80 px de hoja bajo la bola
FUNDA_T = 56.0                    # su centro, px de hoja bajo el pivote (FUNDA_EN_BASTON de la escena)
R_BASTON = 10.0                   # px de master del eje del palo a la espalda
FUNDA_CANTO = 0.45
CORTE_GARRA = 42.0 / 229.0        # la garra en baston.png (la bola, a 16 de arriba)


def _medidas_cuerpo(im):
    a = np.asarray(im).astype(float); op = a[..., 3] > 128
    if not C['a_espalda']:
        # con el baston en la mano lo mas alto es la garra, no la capucha (la
        # funda vacia salia arriba y a la derecha, casi en el hombro): sin lo
        # fino (palo, garra; apertura horizontal de 15 px, como medir.py), la
        # mancha mayor
        from scipy.ndimage import binary_opening, label
        op = binary_opening(op, structure=np.ones((1, 15)))
        lab, n = label(op)
        op = lab == (np.bincount(lab.ravel())[1:].argmax() + 1)
    top = int(np.nonzero(op.any(1))[0].min())
    hc = float(np.nonzero(op[top:top + 60])[1].mean())
    if not C['a_espalda']:
        # y aun asi el nudo de la garra pasaba la apertura: al andar de espaldas la
        # "capucha" bailaba 59 px con el baston y la correa vacia se deslizaba por la
        # espalda hasta 44 px (el usuario: "se nota pegado y se mueve irreal"). La
        # capucha por su color (gris azulado; la madera es parda): baila 10 px.
        import cv2
        hsv = cv2.cvtColor(np.ascontiguousarray(a[..., :3].astype(np.uint8)), cv2.COLOR_RGB2HSV).astype(float)
        gris = op & (hsv[..., 1] < 0.25 * 255) & (a[..., 2] >= a[..., 0] - 8)
        filas = np.nonzero(gris.sum(1) >= 8)[0]
        if len(filas):
            top = int(filas.min())
            hc = float(np.nonzero(gris[top:top + 60])[1].mean())
    b = np.nonzero(op[top + 220:top + 260])[1]
    l, r = np.percentile(b, 3), np.percentile(b, 97)
    return top, hc, (l + r) / 2, (r - l) / 2


def giros_vuelta(ims):
    """THETA (grados) de cada fotograma de la vuelta, de 0 a +-180, y el cuerpo:
    la espalda de perfil (recta tangente por detras, ver arriba) y desde que
    THETA va la bola delante de la capucha."""
    m = np.array([_medidas_cuerpo(im) for im in ims])
    hw = m[:, 3]; k0 = int(np.argmin(hw)); D = float(hw[k0])
    wf, wb = float(np.median(hw[:3])), float(np.median(hw[-3:]))
    signo = 1.0 if np.mean(m[2:k0, 1] - m[2:k0, 2]) >= 0 else -1.0
    th = []
    for k, a_ in enumerate(hw):
        W = wf if k <= k0 else wb
        c = np.sqrt(np.clip((a_ ** 2 - D ** 2) / max(W ** 2 - D ** 2, 1.0), 0, 1))
        t = np.degrees(np.arccos(c))
        th.append(t if k <= k0 else 180.0 - t)
    # el giro no vuelve atras (la anchura medida baila un poco al final)
    th = np.maximum.accumulate(np.array(th))
    # la espalda en el de perfil: borde de atras (a la izquierda si mira a la
    # derecha) de la bola al pie y la recta que lo toca por detras con menos hueco
    top0, c0 = int(m[k0, 0]), float(m[k0, 2])
    op = np.asarray(ims[k0])[..., 3] > 128
    dys = np.arange(int(DY_BOLA), int(DY_BOLA + DY_PIE) + 1)
    borde = np.array([np.nonzero(op[top0 + d])[0].min() if signo > 0 else -np.nonzero(op[top0 + d])[0].max()
                      for d in dys], float)
    mejor = None
    for b in np.arange(-0.2, 0.2, 0.0005):
        a = float(np.min(borde - b * dys))
        hueco = float(np.mean(borde - a - b * dys))
        if mejor is None or hueco < mejor[0]:
            mejor = (hueco, a, b)
    _, ta, tb = mejor
    # fondo de la espalda bajo la punta de la capucha: del eje (c0) a la recta
    fondo = (signo * c0 - ta, -tb)
    # la bola delante de la capucha (semiancho de la capucha a su altura, de frente)
    fila = np.nonzero(np.asarray(ims[0])[..., 3][int(m[0, 0] + DY_BOLA)] > 128)[0]
    capucha = (fila.max() - fila.min()) / 2.0
    th_bola = float(np.degrees(np.arctan2(fondo[0] + fondo[1] * DY_BOLA + R_BASTON, X_BOLA - capucha)))
    print('vuelta: perfil en %d, espalda a %.1f%+.4f dy del eje, bola delante desde %.0f grados'
          % (k0, fondo[0], fondo[1], th_bola))
    return [float(signo * t) for t in th], dict(fondo=fondo, th_bola=th_bola)


def desfase_espalda(im):
    """De espaldas, cuanto hay que mover el baston para que la funda quede en la
    COLUMNA (2026-10-10). El baston va respecto al centro de la capucha, y de
    espaldas la capucha de estos videos no queda centrada sobre el cuerpo (unos
    10 px a la derecha sin baston y casi 30 con el): la funda salia a la derecha
    de la espalda, "como un pegote". Medido en el reposo de espaldas: centro del
    cuerpo a la altura de la funda menos donde caeria la funda."""
    top, hc, _, _ = _medidas_cuerpo(im)
    a = np.asarray(im).astype(float); op = a[..., 3] > 128
    if not C['a_espalda']:
        from scipy.ndimage import binary_opening
        op = binary_opening(op, structure=np.ones((1, 15)))
    d = 2 * (24.0 + FUNDA_T) / np.hypot(DX_PIE, DY_PIE)        # fraccion del palo de la bola a la funda
    fx, fy = hc + X_BOLA - DX_PIE * d, top + DY_BOLA + DY_PIE * d
    b = np.nonzero(op[int(fy) - 10:int(fy) + 10])[1]
    columna = (np.percentile(b, 3) + np.percentile(b, 97)) / 2
    return float(columna - fx)


def baston_espalda(ims, bucle_, thetas, cuerpo):
    """Filas [x, y, giro, corte, ancho]: pivote (px de hoja, centro de la casilla
    de 400), angulo, hasta que fraccion del alto de baston.png va delante del
    cuerpo (0 nada, 1 entero; la escena: copia delante recortada) y ancho de la
    funda (1 de frente o de espaldas)."""
    f0, f1 = cuerpo['fondo']
    filas = []
    for im, th in zip(ims, thetas):
        top, hc, c, hw = _medidas_cuerpo(im)
        r = np.radians(th)
        # centro: el de la capucha de frente/espaldas (estable), el del torso de
        # perfil; de espaldas, corrido para que la funda caiga en la columna
        cx = hc * np.cos(r) ** 2 + c * np.sin(r) ** 2
        if abs(th) > 90:
            cx += cuerpo.get('espalda', 0.0) * np.cos(r) ** 2
        def punto(xb, dy):
            # la correa vacia (con el baston en la mano) va pegada a la tela; el
            # palo, R_BASTON por detras (de perfil asoma como un carcaj)
            zb = -(f0 + f1 * dy + (R_BASTON if C['a_espalda'] else 0.0))
            return cx + xb * (-np.cos(r)) + zb * np.sin(r), top + dy
        bx, by = punto(X_BOLA, DY_BOLA)
        ex, ey = punto(X_BOLA - DX_PIE, DY_BOLA + DY_PIE)
        giro = float(np.arctan2(-(ex - bx), ey - by))
        corte = 1.0 if abs(th) > 90.0 else CORTE_GARRA if abs(th) > cuerpo['th_bola'] else 0.0
        # de canto: la funda / el tubo con el baston no baja de FUNDA_CANTO; la
        # correa vacia es plana: de perfil casi desaparece
        ancho = max(abs(float(np.cos(r))), FUNDA_CANTO) if C['a_espalda'] else abs(float(np.cos(r)))
        filas.append([bx, by, giro, corte, ancho])
    v = np.array(filas, float)
    for k in (0, 1, 2, 4):          # el corte no: delante o detras, sin medias tintas
        w = v[:, k].copy()
        if bucle_:
            v[:, k] = (np.roll(w, 1) + 2 * w + np.roll(w, -1)) / 4
        elif len(w) > 2:
            v[1:-1, k] = (w[:-2] + 2 * w[1:-1] + w[2:]) / 4
    out = []
    orbe = np.array([-0.6, -24.0]) * 2
    for bx, by, g, ct, an in v:
        cg, sg = np.cos(g), np.sin(g)
        px, py = bx - (cg * orbe[0] - sg * orbe[1]), by - (sg * orbe[0] + cg * orbe[1])
        out.append([round(px / 2 - 146, 2), round(py / 2 - 200, 2), round(float(g), 4), round(float(ct), 3),
                    round(float(an), 3)])
    return out


# ---------------------------------------------------------------- a disco
# LA CAPUCHA AL COLOR ESTANDAR (2026-10-09, igualar_capucha.py): cada video la
# pinta a su manera (sin baston salia azulada, casi turquesa: el doble de
# saturacion que con baston; al guardar el baston se notaba el cambio). Todo
# sprite se guarda con la capucha llevada a la del perfil (magnus_respirando),
# medida la de este video en su reposo de frente y en el de espaldas: cada video
# la pinta distinta de un lado y del otro (sin baston, de frente casi turquesa y
# de espaldas casi gris), y con un solo ajuste de frente la espalda quedaba gris
# y no casaba con la de con baston (de espaldas, B cambia de modo al momento).
# Cada sprite con la mezcla de los dos ajustes segun hacia donde mira: 0 de
# frente, 1 de espaldas, en la vuelta (1 - cos THETA) / 2.
CAPUCHA_F, CAPUCHA_B, CAPUCHA_D = IC.medir([F(BASE_F)]), IC.medir([F(BASE_B)]), IC.medir(IC.estandar())
TH_CAPUCHA = giros_vuelta(anims['vuelta' + SUF])[0]


def capucha(im, nombre, k):
    if nombre.startswith('vuelta'):
        t = (1 - np.cos(np.radians(TH_CAPUCHA[k]))) / 2
    else:
        t = 1.0 if ('espalda' in nombre or 'rb' in nombre or nombre.startswith(PRE + 'ab')) else 0.0
    fuente = tuple(a * (1 - t) + b * t for a, b in zip(CAPUCHA_F, CAPUCHA_B))
    return IC.aplicar(im, fuente, CAPUCHA_D)


lista = []
for carpeta, job, cuales in ((SAL, JOB, [n for n in sorted(anims) if not n.startswith(PRE)]),
                             (SAL_PT, JOB_PT, [n for n in sorted(anims) if n.startswith(PRE)])):
    os.makedirs(carpeta, exist_ok=True)
    for f in glob.glob(os.path.join(carpeta, '*.png')):
        os.remove(f)
    orden_hoja = []
    for nombre in cuales:
        for k, im in enumerate(anims[nombre]):
            capucha(im, nombre, k).save(os.path.join(carpeta, '%s_%03d.png' % (nombre, k))); orden_hoja.append((nombre, k))
    indice = {nk: i for i, nk in enumerate(orden_hoja)}
    for nombre in cuales:
        n = len(anims[nombre])
        orden = rf_orden if nombre == 'reposo_frente'+SUF else rb_orden if nombre == 'reposo_espalda'+SUF else range(n)
        idx = [indice[(nombre, k)] for k in orden]
        bucle_ = nombre.startswith('reposo') or nombre.startswith('andar')
        lista.append([nombre, job, len(idx), RESP['FPS_R'] if nombre.startswith('reposo') else FPS, bucle_, idx])
    print(job, len(orden_hoja), 'sprites')
json.dump(lista, open(os.path.join(D, 'animaciones.json'), 'w'))


orden_bola = {}
for nombre, ims in (() if C['a_espalda'] else anims.items()):
    seq = rf_orden if nombre == 'reposo_frente'+SUF else rb_orden if nombre == 'reposo_espalda'+SUF else range(len(ims))
    cache = {}
    filas = []
    for k in seq:
        if k not in cache:
            cache[k] = bola(ims[k])
        filas.append(cache[k])
    # huecos (garra tapada): el anterior
    for i in range(len(filas)):
        if filas[i] is None:
            filas[i] = filas[i - 1] if i else next(f for f in filas if f is not None)
    v = np.array(filas, float)
    if nombre.startswith('reposo'):
        # parado el baston no se mueve: la bola quieta (por color salia a saltos de medio pixel)
        v[:] = np.median(v, 0)
    else:
        # suavizada (1 2 1, dos pasadas); ciclica en los bucles
        for _ in range(2):
            if nombre.startswith('andar'):
                v = (np.roll(v, 1, 0) + 2 * v + np.roll(v, -1, 0)) / 4
            elif len(v) > 2:
                v[1:-1] = (v[:-2] + 2 * v[1:-1] + v[2:]) / 4
    orden_bola[nombre] = [[round(float(x), 2), round(float(y), 2)] for x, y in v]

escena = {
    'fps': FPS, 'baja': round(MED['suelo'][1] * 314, 1),
    'paso': {'andar_frente'+SUF: paso(FRENTE), 'andar_espalda'+SUF: paso(ESPALDA)},
    'h': {'arranque_frente'+SUF: h_de(ARR_F), 'arranque_espalda'+SUF: h_de(ARR_B)},
    'entra_bucle': {'arranque_frente'+SUF: ['andar_frente'+SUF, FRENTE['m']],
                    'arranque_espalda'+SUF: ['andar_espalda'+SUF, ESPALDA['m']]},
    'pies_juntos': {'andar_frente'+SUF: pj_f, 'andar_espalda'+SUF: pj_b},
    'puente_reposo': {'reposo_frente'+SUF: {'arr': PRE + 'rf_arr', 'vu': PRE + 'rf_vu'},
                      'reposo_espalda'+SUF: {'arr': PRE + 'rb_arr', 'vu': PRE + 'rb_vu'}},
    'k_reposo': K_RESP, 'fps_reposo': RESP['FPS_R'],
    'puentes': puentes, 'orbe': orden_bola, 'escala_bola': round(39.3 / 36.0, 3), 'h1': H1,
}
if C.get('paso_frente_como_espalda'):
    escena['paso']['andar_frente' + SUF] = -escena['paso']['andar_espalda' + SUF] * ESPALDA['P'] / FRENTE['P']
    escena['h']['arranque_frente' + SUF] = [H1] * len(escena['h']['arranque_frente' + SUF])   # sin acercarse
# Sin baston: el baston a la espalda en su funda ("baston_espalda"). Con baston
# (2026-10-10), lo mismo para la funda VACIA ("funda_espalda": se queda en la
# espalda al sacar el baston y se ve de espaldas y en la vuelta, como en el
# perfil; la escena solo dibuja la funda). Mismo modelo y mismas filas.
if True:
    CLAVE = 'baston_espalda' if C['a_espalda'] else 'funda_espalda'
    escena[CLAVE] = {}
    th_vu, CUERPO = giros_vuelta(anims['vuelta' + SUF])
    CUERPO['espalda'] = desfase_espalda(F(BASE_B))
    print('de espaldas, el baston %+.1f px para la funda en la columna' % CUERPO['espalda'])
    escena['giro_vuelta'] = [round(t, 1) for t in th_vu]
    escena['funda_corte'] = round((16.0 + L_BASTON * T_FUNDA) / 229.0, 3)
    for nombre, ims in anims.items():
        orden = rf_orden if nombre == 'reposo_frente' + SUF else rb_orden if nombre == 'reposo_espalda' + SUF else range(len(ims))
        if nombre.startswith('vuelta'):
            thetas = th_vu
        else:
            espalda = 'espalda' in nombre or 'rb' in nombre or nombre.startswith(PRE + 'ab')
            thetas = [180.0 if espalda else 0.0] * len(ims)
        filas = baston_espalda(ims, nombre.startswith('andar'), thetas, CUERPO)
        if nombre.startswith('reposo'):
            # el de la base, y sube con los hombros al respirar (va cosido a la tunica)
            m = np.median(np.array(filas, float), 0).tolist()
            y_hom, y_cad = GEO_F if 'frente' in nombre else GEO_B
            y_piv = (m[1] + 200) * 2
            t = min(max((y_cad - y_piv) / (y_cad - y_hom), 0.0), 1.0); sube = t * t * (3 - 2 * t)
            filas = [[round(m[0], 2), round(m[1] - RESP['SUBE'] * sube * S_RESP[k] / 2, 2), round(m[2], 4), round(m[3], 3),
                      round(m[4], 3)] for k in range(K_RESP)]
        escena[CLAVE][nombre] = [filas[k] for k in orden]
def correa_pegada_a_la_tela(escena):
    """La correa VACIA (con el baston en la mano) cosida a la tunica (2026-10-10).

    El usuario: con el baston dentro, que se balancee tiene sentido (pesa), pero
    vacia "se mueve mucho y queda como pegote"; que vaya fija a la tunica, al
    andar de espaldas y al girar. El modelo la pone respecto a la capucha, que al
    andar se mueve distinto que la espalda. Aqui la correa sigue a la TUNICA: como
    todo el modo sale de un video, cada fotograma del video (de la vuelta al
    reposo de espaldas) se encaja con el reposo de espaldas (BASE_B, con la
    postura del modelo: centrada en la columna) por el torso, ECC afin; la correa
    va con ese ajuste (la recta por sus puntos da su sitio y su giro). Encajando
    cada fotograma con el reposo, y no uno con el siguiente, no se acumula error.
    En la VUELTA no vale (el torso cambia demasiado al girar y la correa salia
    por encima de la capucha): ahi el modelo (pegada a la tela, de canto casi
    invisible), corrido poco a poco hasta casar con el arranque. En la vuelta, donde la espalda se ve casi de
    canto (por debajo de 125 grados) el seguimiento no es fiable: se pasa poco a
    poco al modelo. Los puentes de espaldas, de la postura de un extremo a la del
    otro. Delante / detras y lo ancha (de canto) siguen saliendo del modelo."""
    import cv2
    filas = escena['funda_espalda']
    cj = json.load(open(os.path.join(PROY, 'assets', 'characters', 'baston', 'correa.json')))
    L = cj['largo'] * cj['escala']; CY = 22.0 + L / 2           # px de hoja bajo el pivote (CORREA_INICIO = 22 en la escena)
    ts = np.linspace(22.0 + 0.15 * L, 22.0 + 0.95 * L, 9)       # puntos del eje (sin la punta de arriba, junto a la capucha)

    def puntos(f):
        x, y, g = f[:3]; px, py = 2 * (146 + x), 2 * (200 + y)
        return np.array([[px + 2 * (np.cos(g) - t * np.sin(g)), py + 2 * (np.sin(g) + t * np.cos(g))] for t in ts])

    def postura(p):
        c = p.mean(0); u, s_, vt = np.linalg.svd(p - c); d = vt[0] if vt[0][1] > 0 else -vt[0]
        g = float(np.arctan2(-d[0], d[1]))
        # el centro de los puntos esta a la mitad de ts bajo el pivote
        tm = float(ts.mean())
        px, py = c[0] - 2 * (np.cos(g) - tm * np.sin(g)), c[1] - 2 * (np.sin(g) + tm * np.cos(g))
        return np.array([px / 2 - 146, py / 2 - 200, g])

    th = escena['giro_vuelta']
    k_vis = VUELTA[0] + min(k for k, t in enumerate(th) if abs(t) > 90)     # primer fotograma del video con la correa a la vista
    # Cada fotograma se encaja DIRECTAMENTE con el reposo (sin encadenar: lo
    # encadenado acumulaba error y en la vuelta la correa acababa fuera de la
    # espalda): ECC afin del torso (hombros a caderas, sin los brazos ni el
    # baston), de lo que se saca donde cae cada punto del eje de la correa.
    from scipy.ndimage import binary_opening as _ap, label as _lab
    def torso(k):
        a = np.asarray(F(k)).astype(np.float32) / 255
        gr = cv2.cvtColor((a[..., :3] * a[..., 3:] * 255).astype(np.uint8), cv2.COLOR_RGB2GRAY).astype(np.float32)
        op = _ap(a[..., 3] > 0.5, structure=np.ones((1, 15))); lb, _ = _lab(op); op = lb == (np.bincount(lb.ravel())[1:].argmax() + 1)
        ys = np.nonzero(op.any(1))[0]; t0, p0 = ys.min(), ys.max(); h = p0 - t0
        m = np.zeros_like(op); m[int(t0 + 0.17 * h):int(t0 + 0.6 * h)] = True
        b = np.nonzero(op[int(t0 + 0.3 * h):int(t0 + 0.45 * h)])[1]
        cx, ancho = (np.percentile(b, 10) + np.percentile(b, 90)) / 2, (np.percentile(b, 90) - np.percentile(b, 10)) / 2
        xx = np.arange(op.shape[1])[None, :]
        m &= op & (np.abs(xx - cx) < 0.7 * ancho)
        return cv2.GaussianBlur(gr, (0, 0), 1.5), m.astype(np.uint8)
    plantilla, mascara = torso(BASE_B)
    p_ref = puntos(filas['reposo_espalda' + SUF][0])
    pos = {BASE_B: postura(p_ref)}
    w = np.eye(2, 3, dtype=np.float32)
    crit = (cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 200, 1e-5)
    for k in range(BASE_B - 1, ARR_B[0] - 1, -1):
        img, _ = torso(k)
        try:
            _, w = cv2.findTransformECC(plantilla, img, w.copy(), cv2.MOTION_AFFINE, crit, mascara, 5)
        except cv2.error:
            pass                                          # se queda el del fotograma de al lado
        p = np.c_[p_ref, np.ones(len(p_ref))] @ w.T     # de la plantilla (reposo) al fotograma k
        pos[k] = postura(p)

    def fila(base, p):
        return [round(float(p[0]), 2), round(float(p[1]), 2), round(float(p[2]), 4), base[3], base[4]]

    # la VUELTA (el usuario: al empezar a girar "se ve la funda deslizarse por la
    # espalda"; de lado no se ve, esta pegada a la espalda): oculta hasta
    # TH_VISIBLE grados (ancho 0: no se dibuja); de ahi a TH_ENTERA se va abriendo
    # de una raya a su ancho (rodea la espalda) y va COSIDA a la tela: flujo optico
    # encadenado solo en ese tramo corto, hacia atras desde el arranque (con pocos
    # fotogramas no acumula error; contra el reposo, el torso al girar no encaja).
    TH_VISIBLE, TH_ENTERA = 125.0, 150.0
    vu = filas['vuelta' + SUF]
    vis = [k for k in range(len(vu)) if abs(th[k]) >= TH_VISIBLE]
    def gris(k):
        a = np.asarray(F(k)).astype(np.float32) / 255
        return cv2.cvtColor((a[..., :3] * a[..., 3:] * 255).astype(np.uint8), cv2.COLOR_RGB2GRAY)
    dis = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
    pts = puntos(fila([0, 0, 0, 1, 1], pos[ARR_B[0]]))
    prev = gris(ARR_B[0])
    for kv in range(ARR_B[0] - 1, VUELTA[0] + min(vis) - 1, -1):
        cur = gris(kv)
        fl = dis.calc(prev, cur, None)                  # de kv+1 a kv
        nuevos = []
        for px, py in pts:
            xi, yi = int(round(px)), int(round(py))
            w_ = fl[max(yi - 5, 0):yi + 6, max(xi - 5, 0):xi + 6].reshape(-1, 2)
            nuevos.append((px + float(np.median(w_[:, 0])), py + float(np.median(w_[:, 1]))))
        pts = np.array(nuevos); pos[kv] = postura(pts); prev = cur
    for k in range(len(vu)):
        t = abs(th[k])
        if t < TH_VISIBLE:
            vu[k] = vu[k][:3] + [0.0, 0.0]               # de lado (o de frente): no se ve
        else:
            a_ = min(max((t - TH_VISIBLE) / (TH_ENTERA - TH_VISIBLE), 0.0), 1.0); a_ = a_ * a_ * (3 - 2 * a_)
            vu[k] = fila([0, 0, 0, 1.0, round(abs(float(np.cos(np.radians(t)))) * a_, 3)], pos[VUELTA[0] + k])
    print('vuelta: correa oculta hasta %.0f grados, cosida a la tela desde el fotograma %d' % (TH_VISIBLE, min(vis)))
    # el arranque de espaldas y el bucle de andar (sus primeros m, mezcla de dos fotogramas como las imagenes)
    ar = filas['arranque_espalda' + SUF]
    for k in range(len(ar)):
        ar[k] = fila(ar[k], pos[ARR_B[0] + k])
    an = filas['andar_espalda' + SUF]
    a, Pn, m = ESPALDA['a'], ESPALDA['P'], ESPALDA['m']
    v = []
    for j in range(Pn):
        if j < m:
            t = (j + 1) / (m + 1); v.append((1 - t) * pos[a + Pn + j] + t * pos[a + j])
        else:
            v.append(pos[a + j])
    v = np.array(v); v = (np.roll(v, 1, 0) + 2 * v + np.roll(v, -1, 0)) / 4
    for j in range(Pn):
        an[j] = fila(an[j], v[j])
    # puentes de espaldas: de un extremo al otro
    for nombre, pu in escena['puentes'].items():
        de, a_ = pu['de'], pu['a']
        if not any('espalda' in x[0] or (x[0].startswith('vuelta') and x[1] > 0) for x in (de, a_)):
            continue
        fd, fa = np.array(filas[de[0]][de[1]][:3]), np.array(filas[a_[0]][a_[1]][:3])
        if nombre in filas:
            filas[nombre] = [fila(filas[nombre][i], fd + (fa - fd) * (i + 1) / (pu['n'] + 1)) for i in range(len(filas[nombre]))]
    xs = np.array([r[0] for r in an]); print('correa vacia cosida a la tela: al andar se mueve %.1f px de lado a lado' % (2 * (xs.max() - xs.min())))


if not C['a_espalda']:
    correa_pegada_a_la_tela(escena)
json.dump(escena, open(JSON_ESCENA, 'w'), separators=(',', ':'))
print('%d animaciones, %d puentes' % (len(lista), len(puentes)))
print('paso frente %.5f espalda %.5f' % (escena['paso']['andar_frente'+SUF], escena['paso']['andar_espalda'+SUF]))

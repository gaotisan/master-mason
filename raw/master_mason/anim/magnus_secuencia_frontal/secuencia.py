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

# ---------------------------------------------------------------- a disco
lista = []
for carpeta, job, cuales in ((SAL, JOB, [n for n in sorted(anims) if not n.startswith(PRE)]),
                             (SAL_PT, JOB_PT, [n for n in sorted(anims) if n.startswith(PRE)])):
    os.makedirs(carpeta, exist_ok=True)
    for f in glob.glob(os.path.join(carpeta, '*.png')):
        os.remove(f)
    orden_hoja = []
    for nombre in cuales:
        for k, im in enumerate(anims[nombre]):
            im.save(os.path.join(carpeta, '%s_%03d.png' % (nombre, k))); orden_hoja.append((nombre, k))
    indice = {nk: i for i, nk in enumerate(orden_hoja)}
    for nombre in cuales:
        n = len(anims[nombre])
        orden = rf_orden if nombre == 'reposo_frente'+SUF else rb_orden if nombre == 'reposo_espalda'+SUF else range(n)
        idx = [indice[(nombre, k)] for k in orden]
        bucle_ = nombre.startswith('reposo') or nombre.startswith('andar')
        lista.append([nombre, job, len(idx), RESP['FPS_R'] if nombre.startswith('reposo') else FPS, bucle_, idx])
    print(job, len(orden_hoja), 'sprites')
json.dump(lista, open(os.path.join(D, 'animaciones.json'), 'w'))


# ---------------------------------------------------------------- para la escena
def h_de(rango):
    return [H[k - 1] for k in range(rango[0], rango[1] + 1)]


def paso(c):
    """Cambio de 1/escala por fotograma en el bucle (escala = h / H1): recta 1/h."""
    t = np.arange(c['a'], c['a'] + c['P']); hh = np.array([H[k - 1] for k in t])
    return float(np.polyfit(t, H1 / hh, 1)[0])


def baston_espalda(ims, bucle_):
    """El baston en la funda de cuero, a la espalda (como frontal.py para los andares
    sin baston): bola a 60 px de master del centro de la capucha hacia el hombro
    derecho del personaje y 39 bajo su punta, inclinado 0,34 rad; de frente detras
    del cuerpo, de espaldas delante (sin barba visible); de perfil, en la vuelta, la
    diagonal va en profundidad y el baston se pega a la espalda (p = -2,28 g).
    Filas [x, y, giro, delante, 0] del pivote, px de hoja, centro de la casilla de 400."""
    filas = []
    for im in ims:
        a = np.asarray(im).astype(float); op = a[..., 3] > 128
        top = int(np.nonzero(op.any(1))[0].min())
        hc = float(np.nonzero(op[top:top + 60])[1].mean())
        band = np.nonzero(op[top + 130:top + 170])[1]
        l, r = np.percentile(band, 3), np.percentile(band, 97); c, h = (l + r) / 2, (r - l) / 2
        p = float(np.clip(-2.28 * (hc - c) / h, -1.05, 1.05))
        barba = (op & (a[..., :3].min(2) > 175))[top:top + 300].sum()
        delante = 1 if barba < 150 else 0
        x = hc + (c + p * h - hc) * min(1.0, abs(p) / 0.5)
        lado = (1 - min(abs(p), 1.0)) * (1 if delante else -1)
        filas.append([x + 60.0 * lado, top + 39.0, 0.34 * lado, delante])
    v = np.array(filas, float)
    for k in range(3):
        w = v[:, k].copy()
        if bucle_:
            v[:, k] = (np.roll(w, 1) + 2 * w + np.roll(w, -1)) / 4
        elif len(w) > 2:
            v[1:-1, k] = (w[:-2] + 2 * w[1:-1] + w[2:]) / 4
    out = []
    orbe = np.array([-0.6, -24.0]) * 2
    for bx, by, g, dl in v:
        cg, sg = np.cos(g), np.sin(g)
        px, py = bx - (cg * orbe[0] - sg * orbe[1]), by - (sg * orbe[0] + cg * orbe[1])
        out.append([round(px / 2 - 146, 2), round(py / 2 - 200, 2), round(float(g), 4), int(dl), 0.0])
    return out


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
if C['a_espalda']:
    escena['baston_espalda'] = {}
    for nombre, ims in anims.items():
        orden = rf_orden if nombre == 'reposo_frente' + SUF else rb_orden if nombre == 'reposo_espalda' + SUF else range(len(ims))
        filas = baston_espalda(ims, nombre.startswith('andar'))
        if nombre.startswith('reposo'):
            # el de la base, y sube con los hombros al respirar (va cosido a la tunica)
            m = np.median(np.array(filas, float), 0).tolist()
            y_hom, y_cad = GEO_F if 'frente' in nombre else GEO_B
            y_piv = (m[1] + 200) * 2
            t = min(max((y_cad - y_piv) / (y_cad - y_hom), 0.0), 1.0); sube = t * t * (3 - 2 * t)
            filas = [[round(m[0], 2), round(m[1] - RESP['SUBE'] * sube * S_RESP[k] / 2, 2), round(m[2], 4), int(round(m[3])), 0.0]
                     for k in range(K_RESP)]
        escena['baston_espalda'][nombre] = [filas[k] for k in orden]
json.dump(escena, open(JSON_ESCENA, 'w'), separators=(',', ':'))
print('%d animaciones, %d puentes' % (len(lista), len(puentes)))
print('paso frente %.5f espalda %.5f' % (escena['paso']['andar_frente'+SUF], escena['paso']['andar_espalda'+SUF]))

"""Guardar el baston de espaldas con el video A (2026-10-12): la garra SIEMPRE arriba.

Video: _fuentes/Character_slinging_staff_animation_20261011153608.mp4 (144 fotogramas).
El gesto es el bueno (lo sube, se lo lleva por detras de la cabeza y lo baja a la
correa), pero Veo voltea el baston en el aire: desde el 44 gira la muneca, en el
53-56 lo pone tumbado sobre la cabeza, en el 57-61 la garra va ABAJO por la espalda
y del 62 al 75 aparece ya en la correa con la garra arriba mientras el extremo viejo
sigue saliendo de la mano hacia arriba (un segundo palo). Y en la capucha y la espalda
pinta las sombras de ese baston volteado.

Aqui:
  DESDE..HASTA (43-65): fuera el baston de Veo y en su lugar el NUESTRO: el mismo de
      Veo en reposo (c_FUENTE: garra de cuerna y tramo retorcido sin estirar, la vara
      con el final del tramo retorcido repetido), girado y llevado por el puno:
        43-49  sube con la mano y se inclina hacia fuera como el de Veo (en el 43, su
               bola y su pie): el pie, a la derecha, por fuera del cuerpo; la vara
               POR DETRAS de todo (solo asoma fuera de la silueta, fina: lejos);
        50-62  gira por detras de la espalda (el pie, de la derecha a la izquierda) por
               DELANTE de la espalda y DETRAS del brazo levantado (bajo la manga asoma
               poco a poco), y cae a la correa: la mano lo suelta un poco y la bola
               baja hacia ella;
        hasta llegar a la pose de Veo en la correa del LLEGA (66): su bola y el giro
        medido de su vara (-17,5; la plantilla de la garra decia -22, y no).
      La luz, de la de Veo levantado (oscuro, 0,73) a la de la correa (1,10). La garra
      nunca por encima de Y_MIN. Del 48 al 65 el cuerpo es el del BASE (47, quieto en
      el video: sin las sombras del baston volteado ni el fantasma doble de 62-64) y el
      brazo, el de cada fotograma; la mano, siempre encima.
  PALO (66-74): la garra de Veo trae el segundo palo saliendo de su punta derecha:
      fuera (y lo de dentro de su contorno) y la nuestra encima, fundida en su vara.
La bola: la de garra.py en lo de Veo (1-47 desde el reposo con baston, 144-62 desde
el de la correa) y la nuestra en DESDE..HASTA -> garra.json (casa 1.0).
Los fotogramas de Veo se guardan en _todos_veo/ la primera vez; se escribe en _todos/.
    python arreglar.py            -> _todos/ y garra.json
"""
import glob, importlib.util, json, os, shutil, sys
import numpy as np, cv2
from PIL import Image
from scipy.interpolate import PchipInterpolator
from scipy.ndimage import gaussian_filter1d

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
JOB = os.path.basename(AQUI)
TODOS, VEO = os.path.join(AQUI, '_todos'), os.path.join(AQUI, '_todos_veo')
_argv = sys.argv; sys.argv = [_argv[0]]          # garra.py mira --my en sys.argv
spec = importlib.util.spec_from_file_location('garra', os.path.join(ANIM, 'magnus_sacar_baston_frente', 'garra.py'))
G = importlib.util.module_from_spec(spec); spec.loader.exec_module(G)
sys.argv = _argv

FUENTE = 10                 # el baston de Veo en reposo: la plantilla
DESDE, HASTA = 43, 65       # nuestro baston entero
BASE = 47                   # el cuerpo de BASE+1..HASTA
DOBLE = 62                  # de aqui a HASTA Veo ya lo tiene en la espalda, pero doble (el baston y
                            # uno fantasma mas inclinado): el brazo, solo a la derecha de su vara
LLEGA = 66                  # la pose de Veo en la correa a la que se llega (ya una sola vara)
PALO = (66, 74)             # el segundo palo de Veo (sale de la punta derecha de la garra)
GARRA_HASTA = 60            # px bajo la bola: en PALO, nuestra garra hasta aqui (luego la vara de Veo)
GARRA_BASE = 28             # px bajo la bola: donde se juntan las puntas de la garra
Y_MIN = 56                  # la bola, nunca mas arriba (la garra sube hasta ~42 px sobre ella; la casilla
                            # empieza en 0 y la hoja pide margen: con 46 quedaban 2 px)
GIRO_DESDE, GIRO_HASTA = 46, 62     # el giro por detras de la espalda (el pie, de la derecha a la izquierda)
CAE_DESDE, CAE_HASTA = 52, 66       # la caida a la correa (la bola baja hacia la mano)
LARGO_CORREA = 437.0        # de la bola al pie en la correa (la capa de la escena)
GIRO_CORREA = -16.0         # la vara de Veo sobre la correa (70-100; en el 62-66 resbalando, -17 a -22)
CORTE = 168                 # px bajo la bola: hasta aqui la garra y su tramo retorcido (no se estiran;
                            # en reposo ese tramo va de 20 a 14 px de ancho y la vara de abajo, 11)
R_GARRA = 50                # px: lo que queda de la garra alrededor de la bola al borrar el palo
ZONA_Y = 470                # el baston de Veo, por encima de esta fila (las piernas, abajo)
HOMBRO_Y = 350              # por debajo, la espalda (quieta)
MANO_MARGEN = 22            # el brazo: a la derecha de la mano menos esto
PUNO = 24                   # px: lo alto de la piel de la mano (el puno, donde va el baston)
BRAZO_BASE = (390, 300)     # el brazo levantado de BASE: x >= 390 (a la derecha de la capucha), y < 300 (sobre el hombro)
BRAZO_Y = 305               # el brazo levantado, por encima de esta fila (donde se une al hombro)
ANCHO_SAL = 0.65            # la vara bajo la mano al principio (lejos, por detras del brazo: fina, como la de Veo)
ANCHO_HASTA = 56            # ...y entera desde aqui (ya por la espalda)
ESCONDE = 49                # hasta aqui la vara va por detras de todo el cuerpo (como la de Veo)...
PHI_FUERA = 22.0            # ...con el pie hacia fuera (a la derecha); luego, por delante de la espalda
BRAZO_FUNDE = 12            # px: bajo la manga, la vara se funde en 2x esto


def cargar(k):
    return np.asarray(Image.open(os.path.join(VEO, 'c_%03d.png' % k)).convert('RGBA'))


def suave(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3 - 2 * t)


def tramo(k, a, b):
    return suave((k - a) / float(b - a))


def piel(a):
    """La mano: rojiza (tono <= 10 de OpenCV), clara; la garra es mas amarilla y oscura."""
    hsv = cv2.cvtColor(np.ascontiguousarray(a[..., :3]), cv2.COLOR_RGB2HSV)
    h, s, v = hsv[..., 0].astype(int), hsv[..., 1].astype(int), hsv[..., 2].astype(int)
    return ((h <= 10) | (h >= 175)) & (s >= 45) & (s <= 140) & (v >= 125) & (a[..., 3] > 128)


def mano(a, cerca):
    """(el puno, la piel de la mano): la pieza de piel mas grande cerca de 'cerca'; el
    puno, lo de arriba de esa pieza (PUNO px: por debajo asoman la muneca y el antebrazo)."""
    m = piel(a)
    n, lab, st, cen = cv2.connectedComponentsWithStats(m.astype(np.uint8))
    cand = [(st[i, cv2.CC_STAT_AREA], i) for i in range(1, n)
            if np.hypot(*(cen[i] - cerca)) < 70 and st[i, cv2.CC_STAT_AREA] > 60]
    if not cand:
        return None, np.zeros_like(m)
    i = max(cand)[1]
    ys, xs = np.nonzero(lab == i)
    arriba = ys <= ys.min() + PUNO
    return np.array([xs[arriba].mean(), ys[arriba].mean()]), lab == i


def cuerpo(a):
    """El cuerpo (lo grueso, la mayor pieza), ensanchado 5 px."""
    al = (a[..., 3] > 128).astype(np.uint8)
    m = cv2.morphologyEx(al, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (19, 19)))
    n, lab, st, _ = cv2.connectedComponentsWithStats(m)
    c = lab == 1 + np.argmax(st[1:, cv2.CC_STAT_AREA])
    return cv2.dilate(c.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool)


def sin_baston_de_veo(a, quitar=None):
    """Fuera lo que el baston de Veo deja fuera del cuerpo (palo, garra y su orla) en la
    zona de arriba a la derecha; 'quitar' limita a una mascara."""
    fuera = (a[..., 3] > 0) & ~cuerpo(a)
    zona = np.zeros(fuera.shape, bool); zona[:ZONA_Y, 250:] = True
    q = fuera & zona
    if quitar is not None:
        q &= quitar
    o = a.copy(); o[q, 3] = 0
    return o


# ------------------------------------------------------------------ la plantilla
def plantilla(bola):
    """El baston de c_FUENTE recto (vara vertical), en una tira: (rgba, bola en la tira,
    fila del pie). La vara junto a la manga y bajo la mano (y < VARA_LIMPIA) se rehace
    con la de mas abajo, que va sola sobre el verde."""
    a = cargar(FUENTE).astype(np.float32)
    al = a[..., 3] > 128
    fat = cv2.morphologyEx(al.astype(np.uint8), cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (19, 19)))
    fino = al & (fat == 0)
    zona = np.zeros_like(fino); zona[520:880, 430:520] = True
    ys, xs = np.nonzero(fino & zona)
    m, c = np.polyfit(ys, xs, 1)
    pie = int(ys.max())
    ang = np.degrees(np.arctan(m))
    # enderezar alrededor de la bola
    M = cv2.getRotationMatrix2D((float(bola[0]), float(bola[1])), -ang, 1.0)
    r = cv2.warpAffine(a, M, (a.shape[1], a.shape[0]), flags=cv2.INTER_LINEAR, borderValue=0)
    eje = m * bola[1] + c                       # x de la vara a la altura de la bola
    eje = bola[0] + (eje - bola[0]) * np.cos(np.radians(ang))
    W = 96
    x0 = int(round(eje)) - W // 2
    tira = r[:, x0:x0 + W].copy()
    # la garra: solo su pieza (sin la tunica ni la mano), de 45 px sobre la bola a CORTE
    y_arr, y_cor = int(bola[1]) - 45, int(bola[1]) + CORTE
    g = tira[y_arr:y_cor]
    alg = (g[..., 3] > 40).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(alg)
    pb = (int(round(bola[0] - x0)), 45)
    ids = {lab[yy, xx] for yy in range(pb[1] - 30, pb[1] + 50) for xx in range(pb[0] - 6, pb[0] + 7)
           if 0 <= yy < lab.shape[0] and lab[yy, xx] > 0}
    keep = np.isin(lab, list(ids))
    keep = cv2.dilate(keep.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
    g[~keep] = 0
    # la vara: el final del tramo retorcido (RETORCIDO px antes de CORTE, ya de 14 px)
    # repetido hasta el pie. La de abajo del reposo es mas fina y oscura y lleva la orla
    # verde del croma; Veo la pinta retorcida y clara al subirla y en la correa.
    RETORCIDO = 56
    banda = np.zeros(tira.shape[:2], bool); banda[:, W // 2 - 9:W // 2 + 10] = True
    out = np.zeros_like(tira)
    out[y_arr:y_cor] = g
    trozo = (tira * banda[..., None])[y_cor - RETORCIDO:y_cor]
    for yy in range(y_cor, pie + 1):
        out[yy] = trozo[(yy - y_cor) % RETORCIDO]
    return out, np.array([bola[0] - x0, bola[1]], float), float(pie)


def capa(forma, T, tb, tpie, bola, phi, largo, ancho=1.0):
    """La tira T (bola en tb, pie en la fila tpie) con la bola en 'bola', girada phi
    grados (pie a la derecha positivo) y 'largo' px de la bola al pie: la garra sin
    estirar hasta CORTE, la vara estirada."""
    t = np.radians(phi)
    u = np.array([np.sin(t), np.cos(t)])          # de la bola al pie
    R = np.array([[u[1], u[0]], [-u[0], u[1]]])   # (0, 1) de la tira -> u
    h, w = forma
    bola = np.asarray(bola, float)
    M1 = np.hstack([R, (bola - R @ tb)[:, None]])
    garra = cv2.warpAffine(T, M1, (w, h), flags=cv2.INTER_LINEAR, borderValue=0)
    sy = (largo - CORTE) / (tpie - tb[1] - CORTE)
    A2 = R @ np.diag([ancho, sy])             # la vara, ademas, mas o menos gruesa (lejos: mas fina)
    pc = bola + u * CORTE
    M2 = np.hstack([A2, (pc - A2 @ np.array([tb[0], tb[1] + CORTE]))[:, None]])
    vara = cv2.warpAffine(T, M2, (w, h), flags=cv2.INTER_LINEAR, borderValue=0)
    ys, xs = np.mgrid[0:h, 0:w]
    s = (xs - bola[0]) * u[0] + (ys - bola[1]) * u[1]
    wv = np.clip((s - CORTE) / 3.0 + 0.5, 0, 1)[..., None]
    return garra * (1 - wv) + vara * wv


def encima(fondo, capa_):
    """capa_ sobre fondo (los dos RGBA; alfa premultiplicado para las orlas sobre transparente)."""
    ac = capa_[..., 3:] / 255.0
    f = fondo.astype(np.float32)
    af = f[..., 3:] / 255.0
    al = ac + af * (1 - ac)
    rgb = (capa_[..., :3] * ac + f[..., :3] * af * (1 - ac)) / np.maximum(al, 1e-4)
    return np.dstack([rgb, al * 255])


def mezclar(a, b, w):
    """a donde w = 0, b donde w = 1 (alfa premultiplicado)."""
    a = a.astype(np.float32); b = b.astype(np.float32); w = w[..., None]
    aa, ab = a[..., 3:] / 255.0, b[..., 3:] / 255.0
    al = aa * (1 - w) + ab * w
    rgb = (a[..., :3] * aa * (1 - w) + b[..., :3] * ab * w) / np.maximum(al, 1e-4)
    return np.dstack([rgb, al * 255])


def luz_garra(a, b, r=45, abajo=35):
    """Luminosidad (L de Lab, mediana) de la garra: lo de fuera del cuerpo alrededor de la bola."""
    fuera = (a[..., 3] > 200) & ~cuerpo(a)
    ys, xs = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    m = fuera & (np.hypot(xs - b[0], ys - b[1]) < r) & (ys < b[1] + abajo)
    px = np.ascontiguousarray(a[m][:, :3]).reshape(-1, 1, 3)
    return float(np.median(cv2.cvtColor(px, cv2.COLOR_RGB2LAB)[:, 0, 0]))


def iluminar(T, f):
    """La plantilla con la luminosidad (L de Lab) por f."""
    lab = cv2.cvtColor(np.ascontiguousarray(T[..., :3].clip(0, 255).astype(np.uint8)), cv2.COLOR_RGB2LAB).astype(np.float32)
    lab[..., 0] = np.clip(lab[..., 0] * f, 0, 255)
    rgb = cv2.cvtColor(lab.astype(np.uint8), cv2.COLOR_LAB2RGB).astype(np.float32)
    return np.dstack([rgb, T[..., 3]])


# ------------------------------------------------------------------ la pose de Veo
def vara_bajo_la_mano(a, h):
    """(angulo de la vara de Veo bajo la mano, pie): la recta por lo fino sobre el verde."""
    al = a[..., 3] > 128
    fat = cv2.morphologyEx(al.astype(np.uint8), cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (19, 19)))
    fino = al & (fat == 0)
    zona = np.zeros_like(fino); zona[int(h[1]) + 25:620, 445:600] = True
    n, lab, st, _ = cv2.connectedComponentsWithStats((fino & zona).astype(np.uint8))
    i = 1 + np.argmax(st[1:, cv2.CC_STAT_AREA])
    ys, xs = np.nonzero(lab == i)
    m, c = np.polyfit(ys, xs, 1)
    yb = ys.max()
    return np.degrees(np.arctan(m)), np.array([m * yb + c, yb], float)


def giro_vara(a, b, angs=np.arange(-26, -11.5, 0.5), s0=90, s1=380):
    """El giro de la vara de Veo en la espalda (pie a la izquierda: negativo): la recta
    desde la bola que va mas clara que lo que tiene a 9 px a cada lado (la vara y la
    correa, que va debajo, son mas claras que la tunica)."""
    L = cv2.cvtColor(np.ascontiguousarray(a[..., :3]), cv2.COLOR_RGB2LAB)[..., 0].astype(np.float32)
    ss = np.arange(s0, s1, 2.0)

    def cresta(phi):
        t = np.radians(phi); u = np.array([np.sin(t), np.cos(t)]); n_ = np.array([u[1], -u[0]])

        def media(off):
            p = np.asarray(b, float)[None, :] + ss[:, None] * u[None, :] + off * n_[None, :]
            return cv2.remap(L, p[:, 0].astype(np.float32)[None], p[:, 1].astype(np.float32)[None], cv2.INTER_LINEAR)[0]
        return float(np.mean(0.5 * media(0) + 0.25 * (media(-2.5) + media(2.5)) - 0.5 * (media(-9) + media(9))))
    return float(max(angs, key=cresta))


def seguir_veo():
    """La garra de Veo (garra.py --espalda) en lo que se queda: 1..DESDE-1 desde el
    reposo con baston y 144..DOBLE desde el de la correa, sobre los fotogramas de Veo."""
    G.celda = lambda job, k: cargar(k)
    b_sin, b_con = G.bolas_de_referencia_espalda()
    m_sin = G.madera(G.referencia('referencia_baston_espalda_espaldas.png'))
    m_con = G.madera(G.referencia('referencia_baston_mano_espaldas.png'))
    res = {}
    res.update(G.seguir(JOB, list(range(1, BASE + 1)), m_con, b_con))
    res.update(G.seguir(JOB, list(range(N, DOBLE - 1, -1)), m_sin, b_sin))
    return res


N = len(glob.glob(os.path.join(VEO, 'c_*.png'))) if os.path.isdir(VEO) else 0

if __name__ == '__main__':
    if not os.path.isdir(VEO):
        os.makedirs(VEO)
        for f in glob.glob(os.path.join(TODOS, '*.png')):
            shutil.copy2(f, VEO)
        N = len(glob.glob(os.path.join(VEO, 'c_*.png')))
    veo = seguir_veo()
    # la mano, 37..LLEGA
    manos, prev = {}, np.array([448.0, 291.0])
    for k in range(37, LLEGA + 1):
        c, _ = mano(cargar(k), prev)
        if c is not None:
            manos[k] = c; prev = c
    ks = sorted(manos)
    H = gaussian_filter1d(np.array([manos[k] for k in ks]), 1.0, axis=0, mode='nearest')
    H = {k: H[i] for i, k in enumerate(ks)}
    # la plantilla
    T, tb, tpie = plantilla(np.array(veo[FUENTE][:2]))
    # salida: la pose de Veo en DESDE (su bola; el eje de la bola al pie de su vara)
    _, pie = vara_bajo_la_mano(cargar(DESDE), H[DESDE])
    b_sal = np.array(veo[DESDE][:2]); d = pie - b_sal
    phi_sal, largo_sal = np.degrees(np.arctan2(d[0], d[1])), float(np.hypot(*d))
    # llegada: Veo en la correa (LLEGA): su bola y el giro de su vara (medido: el de la
    # plantilla de la garra no lo sigue)
    b_lleg = np.array(veo[LLEGA][:2])
    phi_lleg = giro_vara(cargar(LLEGA), b_lleg)
    giro_veo = {k: giro_vara(cargar(k), veo[k][:2]) for k in range(DOBLE, HASTA + 1)}
    print('vara de Veo: %s; en la llegada %.1f' % (', '.join('%d %.1f' % kv for kv in sorted(giro_veo.items())), phi_lleg))

    def agarre(b, phi, h):
        """La mano respecto al eje: s, de la bola a la mano por el eje; e, de lado (a la derecha)."""
        t = np.radians(phi); u = np.array([np.sin(t), np.cos(t)]); n_ = np.array([u[1], -u[0]])
        d = h - b
        return float(d @ u), float(d @ n_)
    s_sal, e_sal = agarre(b_sal, phi_sal, H[DESDE])
    s_lleg, e_lleg = agarre(b_lleg, phi_lleg, H[LLEGA])
    print('salida  %d: bola %s giro %.1f largo %.0f, mano a s %.0f e %.1f' % (DESDE, np.round(b_sal, 1), phi_sal, largo_sal, s_sal, e_sal))
    print('llegada %d: bola %s giro %.1f largo %.0f, mano a s %.0f e %.1f' % (LLEGA, np.round(b_lleg, 1), phi_lleg, LARGO_CORREA, s_lleg, e_lleg))
    ks = list(range(DESDE, HASTA + 1))
    # el giro: hasta BASE el de la vara de Veo (se inclina hacia fuera: el pie, a la
    # derecha, por fuera del cuerpo), hasta PHI_FUERA en ESCONDE y de ahi, por detras de
    # la espalda, al de la correa en GIRO_HASTA
    v_sal = vara_bajo_la_mano(cargar(DESDE), H[DESDE])[0]
    nudos = [(k, phi_sal + vara_bajo_la_mano(cargar(k), H[k])[0] - v_sal) for k in range(DESDE, BASE + 1)]
    nudos += [(ESCONDE, PHI_FUERA)]
    curva = PchipInterpolator([n_[0] for n_ in nudos], [n_[1] for n_ in nudos])
    phis = np.array([float(curva(k)) if k <= ESCONDE else
                     PHI_FUERA + (phi_lleg - PHI_FUERA) * tramo(k, ESCONDE, GIRO_HASTA) for k in ks])
    print('giro: ' + ', '.join('%d %.1f' % (k, p) for k, p in zip(ks, phis)))
    es = np.array([e_sal + (e_lleg - e_sal) * tramo(k, DESDE, LLEGA) for k in ks])
    # el agarre baja (la caida a la correa); y la garra no se sale por arriba: bola >= Y_MIN
    ss = np.array([s_sal + (s_lleg - s_sal) * tramo(k, CAE_DESDE, CAE_HASTA) for k in ks])
    tope = np.array([(H[k][1] + e * np.sin(np.radians(p)) - Y_MIN) / np.cos(np.radians(p)) for k, p, e in zip(ks, phis, es)])
    ss = np.minimum(ss, tope)
    ss[1:-1] = gaussian_filter1d(ss, 1.5, mode='nearest')[1:-1]
    ss = np.minimum(ss, tope)
    pose = {}
    for i, k in enumerate(ks):
        largo = largo_sal + (LARGO_CORREA - largo_sal) * tramo(k, DESDE, LLEGA)
        t = np.radians(phis[i]); u = np.array([np.sin(t), np.cos(t)]); n_ = np.array([u[1], -u[0]])
        pose[k] = (H[k] - ss[i] * u - es[i] * n_, phis[i], largo)
    # la luz: Veo oscurece el baston al subirlo y lo aclara en la correa; la nuestra va de
    # la de su garra antes de DESDE a la de despues de PALO
    l_t = luz_garra(cargar(FUENTE), veo[FUENTE][:2])
    luz_sal = luz_garra(cargar(DESDE - 1), veo[DESDE - 1][:2]) / l_t
    luz_lleg = luz_garra(cargar(PALO[1] + 1), veo[PALO[1] + 1][:2]) / l_t
    print('luz: %.2f -> %.2f' % (luz_sal, luz_lleg))
    luz = {k: luz_sal + (luz_lleg - luz_sal) * tramo(k, DESDE, LLEGA) for k in range(DESDE, PALO[1] + 1)}
    ancho = {k: ANCHO_SAL + (1 - ANCHO_SAL) * tramo(k, DESDE, ANCHO_HASTA) for k in range(DESDE, HASTA + 1)}
    # el cuerpo de BASE, sin su baston ni su brazo levantado (por encima del hombro y a la
    # derecha de la capucha): el brazo es siempre el de cada fotograma
    base = sin_baston_de_veo(cargar(BASE))
    base[:BRAZO_BASE[1], BRAZO_BASE[0]:, 3] = 0
    a_b = base.astype(np.float32)
    hsv_b = cv2.cvtColor(np.ascontiguousarray(base[..., :3]), cv2.COLOR_RGB2HSV)
    capucha_b = (hsv_b[..., 1] < 50) & (hsv_b[..., 2] > 50) & (base[..., 3] > 0)
    os.makedirs(TODOS, exist_ok=True)
    garra = {k: v for k, v in veo.items()}
    for k in range(1, N + 1):
        a = cargar(k)
        if DESDE <= k <= HASTA:
            vk = sin_baston_de_veo(a)
            _, piel_k = mano(a, H[k])
            if k > BASE:
                ys, xs = np.mgrid[0:a.shape[0], 0:a.shape[1]]
                if k < DOBLE:
                    z = (xs >= H[k][0] - MANO_MARGEN) & (ys < HOMBRO_Y) & ~capucha_b
                else:
                    # su baston (y el fantasma) baja de la mano hacia la izquierda: del
                    # fotograma, solo lo que queda a la derecha de su vara (brazo y hombro)
                    bv = np.array(veo[k][:2]); t = np.radians(giro_veo[k])
                    lado = (xs - bv[0]) * np.cos(t) - (ys - bv[1]) * np.sin(t)
                    z = (lado > 10) & (ys < H[k][1] + 110) & ~capucha_b
                z |= cv2.dilate(piel_k.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool)
                w = cv2.GaussianBlur(z.astype(np.float32), (0, 0), 1.5)
                fondo = mezclar(a_b, vk, w)
            else:
                ys, xs = np.mgrid[0:a.shape[0], 0:a.shape[1]]
                z = None
                fondo = vk.astype(np.float32)
            b, phi, largo = pose[k]
            c_ = capa(a.shape[:2], iluminar(T, luz[k]), tb, tpie, b, phi, largo, ancho[k])
            if k <= ESCONDE:
                # la vara, por detras de todo (el pie va por delante del cuerpo, al otro lado):
                # solo se ve fuera de la silueta, como la de Veo
                o = encima(c_, fondo)
            else:
                o = encima(fondo, c_)
            # el brazo levantado (manga y mano) por delante del baston, como en el video: la
            # vara pasa por detras del antebrazo (y por delante de la espalda)
            hsv_k = cv2.cvtColor(np.ascontiguousarray(a[..., :3]), cv2.COLOR_RGB2HSV)
            capucha_k = (hsv_k[..., 1] < 50) & (hsv_k[..., 2] > 50)
            if k < DOBLE:
                brazo = (xs >= H[k][0] - MANO_MARGEN) & (ys < BRAZO_Y + BRAZO_FUNDE)
            else:
                brazo = z & (ys < H[k][1] + 110)
            brazo &= (vk[..., 3] > 0) & ~capucha_k
            wb = cv2.GaussianBlur(brazo.astype(np.float32), (0, 0), 1.0)
            if k < DOBLE:      # bajo la manga la vara asoma poco a poco (no cortada en recto)
                wb *= np.clip((BRAZO_Y + BRAZO_FUNDE - ys) / (2.0 * BRAZO_FUNDE), 0, 1)
            o = mezclar(o, vk, wb)
            # la mano encima (con su orla)
            wm = cv2.GaussianBlur(cv2.dilate(piel_k.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(np.float32), (0, 0), 1.0)
            o = mezclar(o, a, wm)
            out = o.clip(0, 255).astype(np.uint8)
            garra[k] = (float(b[0]), float(b[1]), float(phi), 1.0)
        elif PALO[0] <= k <= PALO[1]:
            # la garra de Veo (con el segundo palo saliendo de su punta derecha) fuera: lo
            # de fuera del cuerpo por encima de la mano y, sobre la capucha, lo que es
            # madera junto a la bola (se pone la capucha de BASE); y la nuestra encima,
            # sobre su vara, con la luz de su garra en la correa
            bx, by = veo[k][:2]
            ys, xs = np.mgrid[0:a.shape[0], 0:a.shape[1]]
            zona = (ys < by + 30) & (xs > bx - 60)
            o = sin_baston_de_veo(a, zona).astype(np.float32)
            # sobre la capucha, todo lo que no sea capucha (la garra de Veo, tambien su
            # parte oscura) vuelve a la de BASE; la mano se pone encima despues
            difiere = np.abs(a[..., :3].astype(np.float32) - a_b[..., :3]).max(2) > 18
            sobre_cap = zona & capucha_b & (np.hypot(xs - bx, ys - by) < R_GARRA + 5) & difiere
            o[sobre_cap] = a_b[sobre_cap]
            # y la garra entera (pegada a la capucha y a la mano no sale como "fuera"): lo
            # de alrededor de la bola, salvo la mano, vuelve al fondo de BASE (verde o capucha)
            _, piel_k = mano(a, np.array([bx - 20, by + 60]))
            al = (a[..., 3] > 128).astype(np.uint8)
            bulto = cv2.morphologyEx(al, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (31, 31))).astype(bool)
            phi = phi_lleg + (GIRO_CORREA - phi_lleg) * tramo(k, LLEGA, PALO[1] - 4)
            c_ = capa(a.shape[:2], iluminar(T, luz[k]), tb, tpie, (bx, by), phi, LARGO_CORREA)
            t = np.radians(phi); u = np.array([np.sin(t), np.cos(t)])
            s = (xs - bx) * u[0] + (ys - by) * u[1]
            c_[..., 3] *= np.clip((GARRA_HASTA - s) / 12.0, 0, 1)          # se funde en la vara de Veo
            # dentro del contorno de nuestra garra (sus puntas, hasta la base) se ve lo de
            # detras (verde o capucha de BASE), no el arranque del palo de Veo
            puntas = ((c_[..., 3] > 30) & (s < GARRA_BASE)).astype(np.uint8)
            hull = np.zeros_like(puntas)
            cnts, _ = cv2.findContours(puntas, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            if cnts:
                cv2.fillPoly(hull, [cv2.convexHull(np.vstack(cnts))], 1)
            garra_v = ((np.hypot(xs - bx, ys - by) < R_GARRA + 8) & (ys < by + 10) & ~bulto) | hull.astype(bool)
            garra_v &= ~piel_k
            o[garra_v] = a_b[garra_v]
            o = encima(o, c_)
            wm =cv2.GaussianBlur(cv2.dilate(piel_k.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(np.float32), (0, 0), 1.0)
            out = mezclar(o, a, wm).clip(0, 255).astype(np.uint8)
        else:
            out = a
        Image.fromarray(out).save(os.path.join(TODOS, 'c_%03d.png' % k))
    json.dump({str(k): list(v) for k, v in sorted(garra.items())}, open(os.path.join(AQUI, 'garra.json'), 'w'), indent=0)
    for k in range(DESDE, HASTA + 1):
        b, phi, largo = pose[k]
        print('%3d bola (%6.1f, %6.1f) giro %6.1f largo %5.0f  mano (%6.1f, %6.1f)' % (k, b[0], b[1], phi, largo, H[k][0], H[k][1]))

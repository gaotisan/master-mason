"""Herramientas del puente perfil <-> frontal (ver como_se_hizo.txt).

Las imagenes van en float premultiplicado (h, w, 4) y en la ventana VENTANA de
las capturas (el origen del nodo, los pies, en ORIGEN de la captura)."""
import os

import cv2
import numpy as np
from PIL import Image
from scipy.interpolate import RBFInterpolator

AQUI = os.path.dirname(os.path.abspath(__file__))
CAP = os.path.join(AQUI, '_captura')
ORIGEN = (500, 900)                    # los pies en las capturas de 1000x1000
VENTANA = (340, 500, 660, 940)          # x0, y0, x1, y1: donde cabe el peregrino
PIES = (ORIGEN[0] - VENTANA[0], ORIGEN[1] - VENTANA[1])   # los pies en la ventana


def cargar(lado, nombre, dx=0.0):
    """Captura recortada a la VENTANA, premultiplicada, movida dx px."""
    im = np.asarray(Image.open(os.path.join(CAP, lado, nombre + '.png')).convert('RGBA')).astype(np.float32) / 255
    im[..., :3] *= im[..., 3:]
    if dx:
        m = np.float32([[1, 0, dx], [0, 1, 0]])
        im = cv2.warpAffine(im, m, (im.shape[1], im.shape[0]), flags=cv2.INTER_LINEAR, borderValue=0)
    x0, y0, x1, y1 = VENTANA
    return np.ascontiguousarray(im[y0:y1, x0:x1])


def a_imagen(m):
    al = np.clip(m[..., 3:], 1e-4, 1)
    rgb = np.where(m[..., 3:] > 1e-4, m[..., :3] / al, 0)
    return Image.fromarray((np.dstack([rgb, m[..., 3]]) * 255).round().clip(0, 255).astype(np.uint8), 'RGBA')


def sobre(arriba, abajo):
    return arriba + (1 - arriba[..., 3:]) * abajo


# ---------------------------------------------------------------- flujo (mismo video)

def guia(im):
    g = cv2.cvtColor((np.clip(im[..., :3], 0, 1) * 255).astype(np.uint8), cv2.COLOR_RGB2GRAY).astype(np.float32)
    a = cv2.GaussianBlur(im[..., 3], (0, 0), 1.5)
    return np.clip(0.7 * g + 0.3 * 255 * a, 0, 255).astype(np.uint8)


def flujo(a, b):
    """Flujo denso de a hacia b (en la rejilla de a: a(x) ~ b(x + f(x)))."""
    dis = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
    dis.setFinestScale(0)
    dis.setVariationalRefinementIterations(10)
    return dis.calc(guia(a), guia(b), None)


# ---------------------------------------------------------------- silueta

def contorno(alfa, umbral=0.5):
    m = (alfa > umbral).astype(np.uint8)
    cs, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    c = max(cs, key=cv2.contourArea)[:, 0, :].astype(np.float64)
    # sentido antihorario en pantalla (y hacia abajo): area con signo > 0
    x, y = c[:, 0], c[:, 1]
    if 0.5 * np.sum(x * np.roll(y, -1) - np.roll(x, -1) * y) < 0:
        c = c[::-1]
    return c


def remuestrear(c, n):
    d = np.r_[0, np.cumsum(np.hypot(*np.diff(c, axis=0).T))]
    t = np.linspace(0, d[-1], n)
    return np.c_[np.interp(t, d, c[:, 0]), np.interp(t, d, c[:, 1])]


def tramo(c, i, j):
    """De i a j por el contorno cerrado (incluidos)."""
    if j >= i:
        return c[i:j + 1]
    return np.r_[c[i:], c[:j + 1]]


def anclas(c, hacia=1):
    """Puntos del contorno que se corresponden en cualquier vista de pie (de perfil
    o de tres cuartos), en px de la ventana: lo mas alto (la capucha), la punta de
    la capucha delante, lo mas adelantado de la barba o el pecho, el bajo de la
    tunica delante, la punta del pie, el talon, el bajo de la tunica detras y la
    espalda. hacia = 1 mirando a la derecha."""
    x, y = c[:, 0] * hacia, c[:, 1]
    y0, y1 = y.min(), y.max()
    alto = y1 - y0

    def en(desde, hasta):
        return np.where((y >= y0 + desde * alto) & (y <= y0 + hasta * alto))[0]

    r = {}
    r['cima'] = int(np.argmin(y))
    b = en(0.0, 0.16)
    r['capucha'] = int(b[np.argmax(x[b])])
    b = en(0.18, 0.45)
    r['barba'] = int(b[np.argmax(x[b])])
    b = en(0.60, 0.93)
    r['bajo'] = int(b[np.argmax(x[b] + 0.7 * y[b])])
    b = en(0.96, 1.0)
    r['punta'] = int(b[np.argmax(x[b])])
    r['talon'] = int(b[np.argmin(x[b])])
    b = en(0.70, 0.95)
    r['bajo_atras'] = int(b[np.argmax(-x[b] + 0.7 * y[b])])
    b = en(0.30, 0.60)
    r['espalda'] = int(b[np.argmin(x[b])])
    return r


def correspondencia(ca, cb, ra, rb, por_tramo=40):
    """Puntos emparejados de dos contornos: tramo a tramo entre las anclas (las
    que tienen los dos, dict nombre -> indice), cada tramo remuestreado al mismo
    numero de puntos."""
    pa, pb = [], []
    nombres = [k for k in ra if k in rb]
    ia = [ra[k] for k in nombres]
    ib = [rb[k] for k in nombres]
    n = len(ia)
    # las anclas en el orden en que aparecen recorriendo el contorno
    oa = np.argsort([(i - ia[0]) % len(ca) for i in ia])
    ia = [ia[k] for k in oa]
    ib = [ib[k] for k in oa]
    for k in range(n):
        ta = tramo(ca, ia[k], ia[(k + 1) % n])
        tb = tramo(cb, ib[k], ib[(k + 1) % n])
        pa.append(remuestrear(ta, por_tramo)[:-1])
        pb.append(remuestrear(tb, por_tramo)[:-1])
    return np.vstack(pa), np.vstack(pb)


class TPS:
    """Mapa suave de puntos (rejilla de la ventana) dado por pares."""

    def __init__(self, desde, hasta, suavizado=2.0):
        self.f = RBFInterpolator(desde, hasta - desde, kernel='thin_plate_spline', smoothing=suavizado)

    def campo(self, h, w, paso=4):
        """Desplazamiento en toda la ventana (h, w, 2), calculado cada `paso` px."""
        ys, xs = np.mgrid[0:h:paso, 0:w:paso]
        p = np.c_[xs.ravel(), ys.ravel()].astype(np.float64)
        d = self.f(p).reshape(ys.shape + (2,)).astype(np.float32)
        return cv2.resize(d, (w, h), interpolation=cv2.INTER_LINEAR)


# ---------------------------------------------------------------- deformar

def rejilla(h, w):
    gx, gy = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    return gx, gy


def muestrear(img, mx, my):
    return cv2.remap(img, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)


def componer(f, g):
    """(f o g)(x) como desplazamientos: x -> x + g(x) -> + f(x + g(x))."""
    h, w = g.shape[:2]
    gx, gy = rejilla(h, w)
    fg = muestrear(f, gx + g[..., 0], gy + g[..., 1])
    return g + fg


def empujar(img, d, s, iteraciones=6):
    """La imagen con cada punto x llevado a x + s d(x) (d en la rejilla de img):
    se invierte por punto fijo (q = p - s d(q))."""
    h, w = d.shape[:2]
    gx, gy = rejilla(h, w)
    qx, qy = gx - s * d[..., 0], gy - s * d[..., 1]
    for _ in range(iteraciones):
        dq = muestrear(d, qx, qy)
        qx, qy = gx - s * dq[..., 0], gy - s * dq[..., 1]
    return muestrear(img, qx, qy)


def suave(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


def juntar(a, b, s, v, suavizar_a=0.0):
    """Un solo dibujo de dos ya deformados a la misma forma: la silueta es una
    (la mezcla de las dos por la forma s, afilada: sin orla doble) y el color, el
    de b en la proporcion v (por pixel); donde uno no cubre, el del otro. A a se
    le puede suavizar el dibujo (el frontal viene mas blando)."""
    if suavizar_a > 0.05:
        a = cv2.GaussianBlur(a, (0, 0), suavizar_a)
    aa, ab = a[..., 3], b[..., 3]
    ca = a[..., :3] / np.maximum(aa, 1e-3)[..., None]
    cb = b[..., :3] / np.maximum(ab, 1e-3)[..., None]
    # cada color solo donde su dibujo cubre de verdad; si no, el del otro
    wa = np.clip(aa / 0.6, 0, 1) * (1 - v)
    wb = np.clip(ab / 0.6, 0, 1) * v
    wa_, wb_ = wa + 1e-4 * (1 - v), wb + 1e-4 * v
    col = (ca * wa_[..., None] + cb * wb_[..., None]) / (wa_ + wb_)[..., None]
    alfa = (1 - s) * aa + s * ab
    alfa = np.clip((alfa - 0.5) * 1.6 + 0.5, 0, 1) * np.maximum(aa, ab).clip(0, 1) ** 0 
    return np.dstack([col * alfa[..., None], alfa]).astype(np.float32)


def mano(img):
    """Centro de la mano (la mancha de piel mas grande en la mitad de la figura),
    o None."""
    a = img[..., 3]
    col = img[..., :3] / np.maximum(a, 1e-3)[..., None]
    r, g, b = col[..., 0], col[..., 1], col[..., 2]
    piel = (a > 0.8) & (r > 0.45) & (r > g + 0.06) & (g > b + 0.02) & (r - b < 0.35)
    ys = np.nonzero(a.any(1) > 0)[0] if False else np.nonzero((a > 0.5).any(1))[0]
    y0, y1 = ys.min(), ys.max()
    banda = np.zeros_like(piel)
    banda[int(y0 + 0.40 * (y1 - y0)):int(y0 + 0.75 * (y1 - y0))] = True
    piel &= banda
    n, et, st, cen = cv2.connectedComponentsWithStats(piel.astype(np.uint8))
    if n <= 1:
        return None
    i = 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA]))
    if st[i, cv2.CC_STAT_AREA] < 25:
        return None
    return cen[i]


def mapas(A, B, por_tramo=40, suavizado=2.0):
    """Los dos mapas de forma entre dos cuerpos (contornos entre anclas y la
    mano): rejilla de A -> B y rejilla de B -> A."""
    h, w = A.shape[:2]
    ca, cb = contorno(A[..., 3]), contorno(B[..., 3])
    pa, pb = correspondencia(ca, cb, anclas(ca), anclas(cb), por_tramo)
    ma, mb = mano(A), mano(B)
    if ma is not None and mb is not None:
        pa = np.vstack([pa, ma]); pb = np.vstack([pb, mb])
    return TPS(pa, pb, suavizado).campo(h, w), TPS(pb, pa, suavizado).campo(h, w)


# ---------------------------------------------------------------- el baston pintado

def baston_pintado(img, ancho=7.0, garra_alto=58.0, garra_ancho=30.0, lado=None):
    """Mascara (0..1) del baston que viene pintado en el sprite (con el baston en
    la mano): las partes finas que salen del cuerpo dan la recta del palo
    (RANSAC); el palo es la franja de `ancho` a lo largo de ella, de la garra a la
    punta de abajo, y la garra lo que hay de figura en una caja en su extremo de
    arriba. Devuelve (mascara, (punta_arriba, punta_abajo)). lado: 'izq'/'der'
    para quedarse con las partes finas de ese lado de la figura."""
    a = (img[..., 3] > 0.5).astype(np.uint8)
    h, w = a.shape
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (13, 13))
    gordo = cv2.morphologyEx(a, cv2.MORPH_OPEN, k)
    fino = (a > 0) & (cv2.dilate(gordo, np.ones((3, 3), np.uint8)) == 0)
    ys, xs = np.nonzero(fino)
    if lado is not None:
        cx = np.nonzero(gordo.any(0))[0].mean()
        sel = xs < cx if lado == 'izq' else xs > cx
        xs, ys = xs[sel], ys[sel]
    p = np.c_[xs, ys].astype(np.float64)
    # RANSAC de una recta casi vertical
    rng = np.random.default_rng(1)
    mejor, mejor_n = None, -1
    for _ in range(400):
        i, j = rng.choice(len(p), 2, replace=False)
        d = p[j] - p[i]
        if np.hypot(*d) < 40 or abs(d[1]) < 2 * abs(d[0]):
            continue
        u = d / np.hypot(*d); nrm = np.r_[-u[1], u[0]]
        dist = np.abs((p - p[i]) @ nrm)
        n_in = int((dist < 3).sum())
        if n_in > mejor_n:
            mejor, mejor_n = (p[i], u), n_in
    p0, u = mejor
    nrm = np.r_[-u[1], u[0]]
    dentro = p[np.abs((p - p0) @ nrm) < 3]
    # recta afinada con los que caen en ella
    c = dentro.mean(0)
    _, _, vt = np.linalg.svd(dentro - c)
    u = vt[0] if vt[0][1] < 0 else -vt[0]       # hacia arriba
    nrm = np.r_[-u[1], u[0]]
    t = (dentro - c) @ u
    arriba, abajo = c + u * t.max(), c + u * t.min()
    # la figura entera a lo largo de la recta: hasta donde llega por arriba y abajo
    yy, xx = np.mgrid[0:h, 0:w]
    q = np.dstack([xx, yy]).astype(np.float64)
    dn = np.abs((q - c) @ nrm)
    dt = (q - c) @ u
    en_recta = (dn < ancho / 2) & (a > 0)
    ts = dt[en_recta]
    t_arr, t_aba = ts.max(), ts.min()
    arriba, abajo = c + u * t_arr, c + u * t_aba
    palo = (dn < ancho / 2 + 0.5) & (dt <= t_arr) & (dt >= t_aba)
    # en la garra, solo la madera (la capucha gris que asome detras, no)
    col = img[..., :3] / np.maximum(img[..., 3], 1e-3)[..., None]
    mx, mn = col.max(2), col.min(2)
    sat = (mx - mn) / np.maximum(mx, 1e-3)
    madera = (sat > 0.28) & (col[..., 0] >= col[..., 2])
    madera = cv2.dilate(madera.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    garra = (dn < garra_ancho) & (dt > t_arr - garra_alto) & (dt <= t_arr + 2) & madera
    m = (palo | garra) & (a > 0)
    m = cv2.GaussianBlur(m.astype(np.float32), (0, 0), 0.7)
    return np.clip(m * 1.4, 0, 1), (arriba, abajo)


def separar(img, lado=None):
    """Cuerpo y baston de un sprite con el baston pintado: (cuerpo, baston,
    delante). Lo que el palo tapaba del cuerpo se rellena (inpaint) con lo de
    alrededor; el baston va delante del cuerpo donde lo cruza."""
    m, _ = baston_pintado(img, lado=lado)
    a = img[..., 3]
    sin = (a > 0.5) & (m < 0.3)
    # el cuerpo continua por detras del palo: la silueta sin el palo, cerrada
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (15, 15))
    cuerpo_reg = cv2.morphologyEx(sin.astype(np.uint8), cv2.MORPH_CLOSE, k) > 0
    hueco = (m > 0.05) & cuerpo_reg
    col = (img[..., :3] / np.maximum(a, 1e-3)[..., None] * 255).clip(0, 255).astype(np.uint8)
    relleno = cv2.inpaint(col, (cv2.dilate(hueco.astype(np.uint8), np.ones((3, 3), np.uint8))), 4, cv2.INPAINT_TELEA)
    col = np.where(hueco[..., None], relleno, col).astype(np.float32) / 255
    alfa_c = np.where(hueco, 1.0, a * (1 - m)).astype(np.float32)
    cuerpo = np.dstack([col * alfa_c[..., None], alfa_c]).astype(np.float32)
    baston = (img * m[..., None]).astype(np.float32)
    delante = (m * cuerpo_reg).astype(np.float32)
    return cuerpo, baston, delante

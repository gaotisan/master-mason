"""Botas para las vistas de frente y de espaldas (2026-10-12).

De frente y de espaldas el peregrino parecia descalzo (pie marron con dedos, suelas
claras, piernas pardo-moradas); de perfil (magnus_andando, magnus_corriendo,
magnus_respirando) lleva calzas GRISES y un pie MARRON de un solo tono, como una
bota o un zapato. El usuario: "no rehacer el dibujo, solo cambiar el color de esa
parte para que parezcan botas". Medido en los de perfil (px de master, Lab de OpenCV):
  piernas  rgb ~(63, 60, 60), L 65 +- 13, a* +2, b* +0,5   (gris neutro)
  pies     rgb ~(89, 68, 62), L 77 +- 13, a* +7,5, b* +7   (marron)

Aqui, por fotograma: las piernas (lo fino que cuelga de la tunica y llega al suelo, o
largo y oscuro si va en el aire; ver igualar_piernas.mascara) SIN el baston (muy alto,
o de madera: pardo saturado) se pintan con el color de las de perfil; y la bota (el
pie y el tobillo: las ultimas BOTA filas de cada pierna, con un paso suave) con el
marron de los pies de perfil, de un solo tono: se queda el volumen suave y se van los
detalles finos (las rayas de los dedos), que es lo que hacia parecer un pie descalzo.
La forma no se toca.
    from botas import botas      # botas(rgba numpy) -> rgba numpy
"""
import os, sys
import numpy as np, cv2

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, 'magnus_secuencia_frontal'))
import igualar_piernas as IP                     # noqa: E402  (la mascara de las piernas)

PIERNA = dict(L=65.0, a=2.0, b=0.5)              # Lab de OpenCV (L 0-255, a y b sin el 128)
BOTA_COLOR = dict(L=77.0, a=7.5, b=7.0)
BOTA = 40                 # px de master: lo que sube la bota desde lo mas bajo de cada pierna
PASO = 5                  # px de transicion entre la calza y la bota
ALTO_BASTON = 200         # lo que mide mas que esto (dentro de lo fino) es el baston...
MADERA = 0.35             # ...y si una pierna va pegada a el, se separan por la madera (pardo saturado)
VOLUMEN, DETALLE = 0.5, 0.1      # bota: cuanto se queda del sombreado suave y del fino
# Una pieza CORTA tambien puede ser el baston: la mano o la tunica lo parten en trozos
# (el sacar de frente, 104-112: el palo bajo la mano salia gris). Madera media de las
# piezas: piernas y pies 0,04-0,20; trozos del palo 0,22-0,50 (estrechos y alargados).
MADERA_TROZO = 0.27
MADERA_TROZO_FINO = 0.20         # ...si ademas es estrecha (<= 25 px) y alargada (alto >= 2,5 ancho)
VOL_PIERNA, DET_PIERNA = 0.6, 0.5


def madera(rgba):
    """0..1: cuanto parece madera (pardo saturado); como garra.madera, sin desenfocar."""
    hsv = cv2.cvtColor(np.ascontiguousarray(rgba[..., :3]), cv2.COLOR_RGB2HSV).astype(np.float32)
    h, s = hsv[..., 0], hsv[..., 1] / 255
    return np.clip(1 - np.abs(h - 13) / 10, 0, 1) * np.clip((s - 0.25) / 0.25, 0, 1)


def mascara_piernas(a):
    """Piernas y pies, sin el baston. Lo que mide como el baston se quita; si dentro
    habia una pierna pegada a el, se recupera quitando la madera (solo ahi: en los pies,
    pardos, el filtro de madera por pixel dejaba motas sin pintar). Devuelve la mascara y
    las componentes (etiquetas)."""
    m = IP.mascara(a)
    md = madera(a)
    n, lab, st, _ = cv2.connectedComponentsWithStats(m.astype(np.uint8), 8)
    for i in range(1, n):
        c = lab == i
        w, h = st[i, cv2.CC_STAT_WIDTH], st[i, cv2.CC_STAT_HEIGHT]
        if h <= ALTO_BASTON:
            v = md[c].mean()
            if v > MADERA_TROZO or (v > MADERA_TROZO_FINO and w <= 25 and h >= 2.5 * w):
                m[c] = False          # un trozo del baston
            continue
        if h > ALTO_BASTON:
            m[c] = False
            resto = c & (md < MADERA)
            n2, lab2, st2, _ = cv2.connectedComponentsWithStats(resto.astype(np.uint8), 8)
            for j in range(1, n2):
                if st2[j, cv2.CC_STAT_HEIGHT] <= ALTO_BASTON * 0.6 and st2[j, cv2.CC_STAT_AREA] > 150:
                    m |= lab2 == j
    n, lab = cv2.connectedComponents(m.astype(np.uint8), connectivity=8)
    return m, lab, n


def _a_lab(rgb):
    return cv2.cvtColor(np.ascontiguousarray(rgb.reshape(-1, 1, 3).astype(np.uint8)), cv2.COLOR_RGB2LAB).reshape(-1, 3).astype(float)


def _a_rgb(x):
    return cv2.cvtColor(np.clip(x, 0, 255).astype(np.uint8).reshape(-1, 1, 3), cv2.COLOR_LAB2RGB).reshape(-1, 3)


def botas(a):
    a = np.asarray(a).copy()
    m, lab, n = mascara_piernas(a)
    if not m.any():
        return a
    alto = a.shape[0]
    # peso de bota: 1 en las ultimas BOTA filas de cada pierna, 0 por encima, paso suave
    peso = np.zeros(a.shape[:2], np.float32)
    filas = np.arange(alto, dtype=np.float32)[:, None]
    for i in range(1, n):
        c = lab == i
        yb = np.nonzero(c.any(1))[0].max()
        w = np.clip((filas - (yb - BOTA)) / PASO + 0.5, 0, 1)
        peso[c] = np.broadcast_to(w, c.shape)[c]
    X = cv2.cvtColor(np.ascontiguousarray(a[..., :3]), cv2.COLOR_RGB2LAB).astype(np.float32)
    L = X[..., 0]
    # sombreado suave (el volumen) y detalle fino (las rayas de los dedos), dentro de la mascara
    mf = m.astype(np.float32)
    suave = cv2.GaussianBlur(L * mf, (0, 0), 5) / np.maximum(cv2.GaussianBlur(mf, (0, 0), 5), 1e-3)
    fino = L - suave
    sel = m
    w = peso[sel]
    med_b = (suave[sel] * w).sum() / max(w.sum(), 1e-3)
    med_p = (suave[sel] * (1 - w)).sum() / max((1 - w).sum(), 1e-3)
    Lb = BOTA_COLOR['L'] + (suave[sel] - med_b) * VOLUMEN + fino[sel] * DETALLE
    Lp = PIERNA['L'] + (suave[sel] - med_p) * VOL_PIERNA + fino[sel] * DET_PIERNA
    ab_b = np.array([BOTA_COLOR['a'], BOTA_COLOR['b']]) + 128
    ab_p = np.array([PIERNA['a'], PIERNA['b']]) + 128
    Y = np.empty((sel.sum(), 3), np.float32)
    Y[:, 0] = Lb * w + Lp * (1 - w)
    Y[:, 1:] = ab_b[None, :] * w[:, None] + ab_p[None, :] * (1 - w[:, None])
    a[sel, :3] = _a_rgb(Y)
    return a

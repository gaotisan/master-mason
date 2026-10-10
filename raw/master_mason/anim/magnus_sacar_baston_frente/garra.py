"""Donde va la bola en cada fotograma de sacar / guardar (la garra del video va
vacia: la bola la pone la escena, como en el resto del modo con baston).

Se sigue la GARRA por su forma: plantilla girada y desplazada (matchTemplate
sobre un mapa de "madera": saturado y de tono pardo; la capucha es gris y el
fondo transparente). Las plantillas y la bola de partida salen de las propias
referencias que se le dieron a Veo, donde la bola se conoce al pixel:
  - sin baston (a la espalda): la garra de baston.png puesta por la escena; la
    bola, donde la pone baston_espalda (reposo_frente_sb).
  - con baston: la garra del video de la secuencia; la bola, la del "orbe" de
    reposo_frente_cb.
Cada tramo se sigue desde su extremo hacia dentro, fotograma a fotograma, con
la plantilla de ese extremo y la del fotograma anterior (la que mejor case), y
el angulo cerca del anterior. Donde la garra pasa por detras de la capucha no
se ve: ahi se interpola (la bola va detras del sprite: la tapa la capucha).
    python garra.py            -> <job>/garra.json y una hoja para revisar
"""
import json, os, sys
import numpy as np, cv2
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
PROY = os.path.abspath(os.path.join(ANIM, '..', '..', '..'))
MX, MY = 40, 104                      # casilla 664x904 (montar.py): la de 584x800 en (40, 104)
REF_ORIGEN = (668 - MX, 286 - MY)     # la casilla en las referencias de 1080p


def madera(rgba):
    """0..1: cuanto parece madera (pardo saturado), con el alfa."""
    a = rgba[..., 3].astype(np.float32) / 255
    hsv = cv2.cvtColor(np.ascontiguousarray(rgba[..., :3]), cv2.COLOR_RGB2HSV).astype(np.float32)
    h, s = hsv[..., 0], hsv[..., 1] / 255
    tono = np.clip(1 - np.abs(h - 13) / 10, 0, 1)
    m = tono * np.clip((s - 0.25) / 0.25, 0, 1) * a
    return cv2.GaussianBlur(m, (0, 0), 1.5)


def celda(job, k):
    return np.asarray(Image.open(os.path.join(ANIM, job, '_todos', 'c_%03d.png' % k)).convert('RGBA'))


def referencia(nombre):
    """La referencia de 1080p llevada a la casilla 664x900 (sobre transparente)."""
    p = np.asarray(Image.open(os.path.join(ANIM, '_fuentes', nombre)).convert('RGB')).astype(np.float32)
    x0, y0 = REF_ORIGEN
    p = p[y0:y0 + 900, x0:x0 + 664]
    verde = np.array([36, 215, 50], np.float32)
    a = np.clip((np.abs(p - verde).sum(2) - 40) / 60, 0, 1)
    return np.dstack([p, a * 255]).astype(np.uint8)


def bolas_de_referencia():
    sb = json.load(open(os.path.join(PROY, 'assets', 'characters', 'magnus', 'secuencia_frontal_sin.json')))
    cb = json.load(open(os.path.join(PROY, 'assets', 'characters', 'magnus', 'secuencia_frontal.json')))
    x, y, g = sb['baston_espalda']['reposo_frente_sb'][0][:3]
    # el Orbe en (-0,6, -24) del nodo Baston, girado: px de hoja desde el centro de la casilla de 400
    ox = x + np.cos(g) * -0.6 - np.sin(g) * -24
    oy = y + np.sin(g) * -0.6 + np.cos(g) * -24
    o = cb['orbe']['reposo_frente_cb'][0]
    a_celda = lambda px, py: (MX + 2 * (146 + px), MY + 2 * (200 + py))
    return a_celda(ox, oy), a_celda(o[0], o[1])


def plantilla(mapa, centro, lado=110):
    cx, cy = int(round(centro[0])), int(round(centro[1]))
    h = lado // 2
    t = mapa[cy - h:cy + h, cx - h:cx + h].copy()
    return t, (centro[0] - (cx - h), centro[1] - (cy - h))


def girar(t, piv, ang):
    M = cv2.getRotationMatrix2D(piv, ang, 1.0)
    return cv2.warpAffine(t, M, (t.shape[1], t.shape[0]), flags=cv2.INTER_LINEAR, borderValue=0)


def buscar(mapa, t, piv, cerca, ang0, radio=36, angs=range(-12, 13, 2)):
    """Mejor (posicion de la bola, angulo, puntuacion) de la plantilla girada alrededor de piv."""
    th, tw = t.shape
    x0 = int(round(cerca[0] - piv[0])) - radio; y0 = int(round(cerca[1] - piv[1])) - radio
    x0 = max(0, x0); y0 = max(0, y0)
    zona = mapa[y0:y0 + th + 2 * radio, x0:x0 + tw + 2 * radio]
    if zona.shape[0] < th or zona.shape[1] < tw or t.sum() < 1:
        return None
    mejor = None
    for da in angs:
        tr = girar(t, piv, ang0 + da)
        if tr.sum() < 1:
            continue
        r = cv2.matchTemplate(zona, tr, cv2.TM_CCORR_NORMED)
        _, v, _, (mx, my) = cv2.minMaxLoc(r)
        if mejor is None or v > mejor[2]:
            mejor = ((x0 + mx + piv[0], y0 + my + piv[1]), ang0 + da, v)
    return mejor


def seguir(job, ks, inicio_mapa, inicio_bola):
    """Sigue la garra por los fotogramas ks (en orden) desde la plantilla de inicio."""
    t0, piv0 = plantilla(inicio_mapa, inicio_bola)
    pos, ang = inicio_bola, 0.0
    tprev, pivprev, angprev = t0, piv0, 0.0
    out = {}
    for k in ks:
        m = madera(celda(job, k))
        a = buscar(m, t0, piv0, pos, ang)
        b = buscar(m, tprev, pivprev, pos, 0.0)
        if b is not None:
            b = (b[0], b[1] + angprev, b[2])
        r = max([x for x in (a, b) if x is not None], key=lambda x: x[2])
        pos, ang = r[0], r[1]
        out[k] = (float(pos[0]), float(pos[1]), float(ang), float(r[2]))
        tprev, pivprev = plantilla(m, pos)
        angprev = ang
    return out


if __name__ == '__main__':
    b_sin, b_con = bolas_de_referencia()
    m_sin = madera(referencia('referencia_baston_espalda_frente.png'))
    m_con = madera(referencia('referencia_baston_mano_frente.png'))
    print('bola de partida: sin baston %s, con baston %s' % (np.round(b_sin, 1), np.round(b_con, 1)))
    TRAMOS = json.loads(sys.argv[1]) if len(sys.argv) > 1 else None
    # [job, [tramo desde el extremo sin baston], [tramo desde el extremo con baston]]
    for job, desde_sin, desde_con in TRAMOS:
        res = {}
        res.update(seguir(job, list(range(desde_sin[0], desde_sin[1] + (1 if desde_sin[1] >= desde_sin[0] else -1),
                                            1 if desde_sin[1] >= desde_sin[0] else -1)), m_sin, b_sin))
        res.update(seguir(job, list(range(desde_con[0], desde_con[1] + (1 if desde_con[1] >= desde_con[0] else -1),
                                            1 if desde_con[1] >= desde_con[0] else -1)), m_con, b_con))
        json.dump({str(k): v for k, v in sorted(res.items())}, open(os.path.join(ANIM, job, 'garra.json'), 'w'), indent=0)
        print(job, len(res), 'fotogramas seguidos')

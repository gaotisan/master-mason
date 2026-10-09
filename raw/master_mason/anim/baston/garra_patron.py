"""Sigue la garra fotograma a fotograma en una transicion (sacar_baston,
guardar_baston) por patron: recorta la garra de un fotograma de referencia
con el centro del hueco medido a mano, y en cada fotograma busca donde encaja
girandola (el baston rota: de la espalda a la horizontal y a la mano), cerca
de donde estaba en el anterior. Devuelve el centro del hueco en cada
fotograma (casilla master) y la puntuacion del encaje.
  python garra_patron.py sacar     (escribe garra_sacar.json)"""
import json, math, sys
import cv2
import numpy as np
from PIL import Image
from celdas import PROY

ANIM = PROY / "raw/master_mason/anim"
CASOS = {
    # job, n fotogramas, fotograma de referencia, caja de la garra en el, centro del hueco
    "sacar": ("magnus_sacar_baston", 123, 0, (205, 55, 295, 150), (252, 98)),
    "guardar": ("magnus_guardar_baston", 93, 0, (338, 82, 418, 168), (377, 122)),
    "sacar_v3": ("magnus_sacar_baston_v3", 180, 0, (195, 65, 255, 150), (223, 107)),
}
FONDO = (60, 56, 54)
# Marcas a mano (2026-10-07) sobre rejilla en 04_limpios: fotograma -> (x, y,
# giro en grados, + = antihorario: la garra apunta arriba-izquierda / izquierda).
# None = la garra queda fuera de la imagen (el video corta el baston por arriba).
CLAVES = {
    "sacar": {0: (252, 98, 0), 8: (270, 100, 0), 16: (262, 95, 0), 20: (245, 75, 5),
              24: (235, 52, 5), 28: (212, 20, 10), 30: None, 58: None,
              60: (186, 40, 45), 64: (80, 75, 65), 68: (55, 115, 80), 72: (56, 155, 90),
              76: (50, 158, 90), 80: (62, 100, 70), 84: (118, 60, 45), 88: (252, 48, 8),
              92: (333, 80, 0), 96: (368, 100, 0), 100: (372, 120, 0), 104: (377, 122, 0),
              122: (377, 122, 0)},
    # video Character_drawing_staff_for_game_20261007173433 (2026-10-07): por
    # encima del hombro, horizontal, abajo a la izquierda, vuelta arriba y a la mano
    "sacar_v3": {0: (223, 107, 0), 8: (224, 107, 0), 12: (231, 108, 0), 16: (236, 105, 0),
                 20: (242, 106, 3), 24: (220, 99, 8), 28: (196, 69, 18), 32: (143, 46, 38),
                 36: (77, 90, 75), 40: (52, 169, 95), 44: (46, 256, 120), 48: (70, 299, 125),
                 52: (81, 302, 125), 56: (78, 293, 122), 60: (68, 258, 115), 64: (61, 211, 100),
                 68: (64, 154, 88), 72: (114, 98, 70), 76: (160, 56, 45), 80: (215, 46, 20),
                 84: (261, 34, 5), 88: (289, 34, -5), 92: (355, 45, -8), 96: (375, 56, -5),
                 100: (398, 66, 0), 104: (415, 66, 0), 108: (406, 79, 0), 112: (402, 79, 0),
                 116: (415, 82, 0), 120: (419, 89, 0), 124: (420, 108, 0), 128: (418, 117, 0),
                 132: (415, 127, 0), 136: (410, 138, 0), 140: (417, 132, 0), 152: (415, 135, 0),
                 164: (417, 133, 0), 179: (416, 133, 0)},
    "guardar": {0: (377, 122, 0), 8: (377, 124, 0), 20: (377, 124, 0), 24: (378, 122, 0),
                28: (380, 118, 0), 32: (352, 86, 8), 36: (334, 68, 15), 40: (290, 58, 20),
                44: (245, 48, 22), 48: (225, 55, 30), 52: (195, 65, 35), 56: (175, 80, 40),
                60: (165, 100, 50), 64: (167, 115, 45), 68: (195, 115, 30), 72: (210, 105, 15),
                76: (218, 100, 10), 80: (228, 100, 5), 84: (235, 108, 5), 88: (232, 108, 0),
                92: (226, 104, 0)},
}


def leer(job, i):
    carpeta = ANIM / job / "04_limpios"
    ruta = carpeta / f"c_{i + 1:03d}.png"
    if not ruta.exists():
        ruta = carpeta / f"c_{i + 1:02d}.png"
    a = np.array(Image.open(ruta).convert("RGBA")).astype(np.float32)
    al = a[..., 3:4] / 255
    rgb = a[..., :3] * al + np.array(FONDO, np.float32) * (1 - al)
    return rgb.astype(np.uint8), a[..., 3]


def patron_girado(tpl, alfa, centro, ang):
    h, w = alfa.shape
    M = cv2.getRotationMatrix2D(centro, ang, 1.0)
    cos, sin = abs(M[0, 0]), abs(M[0, 1])
    W, H = int(h * sin + w * cos) + 2, int(h * cos + w * sin) + 2
    M[0, 2] += W / 2 - w / 2
    M[1, 2] += H / 2 - h / 2
    t = cv2.warpAffine(tpl, M, (W, H), flags=cv2.INTER_LINEAR, borderValue=FONDO)
    m = cv2.warpAffine(alfa, M, (W, H), flags=cv2.INTER_LINEAR, borderValue=0)
    c = M @ np.array([centro[0], centro[1], 1.0])
    return t, m, (float(c[0]), float(c[1]))


def seguir(caso):
    job, n, ref, caja, hueco = CASOS[caso]
    rgb, al = leer(job, ref)
    x0, y0, x1, y1 = caja
    tpl = rgb[y0:y1, x0:x1].copy()
    alfa = (al[y0:y1, x0:x1] > 128).astype(np.float32)
    centro = (hueco[0] - x0, hueco[1] - y0)
    pos, ang = hueco, 0.0
    res = []
    for i in range(n):
        img, _ = leer(job, i)
        mejor = None
        for da in range(-18, 19, 3):
            a = ang + da
            t, m, c = patron_girado(tpl, alfa, centro, a)
            th, tw = m.shape
            # ventana de busqueda alrededor de la posicion anterior
            R = 70
            sx0 = int(max(0, pos[0] - c[0] - R)); sy0 = int(max(0, pos[1] - c[1] - R))
            sx1 = int(min(img.shape[1], pos[0] - c[0] + tw + R)); sy1 = int(min(img.shape[0], pos[1] - c[1] + th + R))
            zona = img[sy0:sy1, sx0:sx1]
            if zona.shape[0] < th or zona.shape[1] < tw:
                continue
            r = cv2.matchTemplate(zona, t, cv2.TM_CCORR_NORMED, mask=np.dstack([m] * 3))
            r = np.nan_to_num(r, nan=0, posinf=0, neginf=0)
            _, sc, _, loc = cv2.minMaxLoc(r)
            p = (sx0 + loc[0] + c[0], sy0 + loc[1] + c[1])
            if mejor is None or sc > mejor[0]:
                mejor = (sc, p, a)
        sc, p, a = mejor
        res.append({"i": i, "x": round(p[0], 1), "y": round(p[1], 1), "ang": a, "score": round(sc, 4)})
        pos, ang = p, a
    return res


def guia(caso, n):
    """Posicion y giro interpolados entre marcas; None donde la garra no se ve."""
    cl = CLAVES[caso]
    ks = sorted(cl)
    out = []
    for i in range(n):
        a = max(k for k in ks if k <= i)
        b = min((k for k in ks if k >= i), default=a)
        if cl[a] is None or cl[b] is None:
            out.append(None)
            continue
        t = 0 if a == b else (i - a) / (b - a)
        out.append(tuple(cl[a][j] + (cl[b][j] - cl[a][j]) * t for j in range(3)))
    return out


def afinar(caso):
    """Parte de la guia y afina con el patron en un radio corto (+-14 px,
    +-15 grados): asi no se escapa a la textura de la capa."""
    job, n, ref, caja, hueco = CASOS[caso]
    rgb, al = leer(job, ref)
    x0, y0, x1, y1 = caja
    tpl = rgb[y0:y1, x0:x1].copy()
    alfa = (al[y0:y1, x0:x1] > 128).astype(np.float32)
    centro = (hueco[0] - x0, hueco[1] - y0)
    res = []
    for i, g in enumerate(guia(caso, n)):
        if g is None:
            res.append(None)
            continue
        img, _ = leer(job, i)
        mejor = None
        for da in range(-15, 16, 3):
            t, m, c = patron_girado(tpl, alfa, centro, g[2] + da)
            th, tw = m.shape
            R = 14
            ox, oy = g[0] - c[0], g[1] - c[1]
            sx0, sy0 = int(ox - R), int(oy - R)
            pad = 300
            big = cv2.copyMakeBorder(img, pad, pad, pad, pad, cv2.BORDER_CONSTANT, value=FONDO)
            zona = big[sy0 + pad:sy0 + pad + th + 2 * R, sx0 + pad:sx0 + pad + tw + 2 * R]
            r = cv2.matchTemplate(zona, t, cv2.TM_CCOEFF_NORMED, mask=np.dstack([m] * 3))
            r = np.nan_to_num(r, nan=-1, posinf=-1, neginf=-1)
            _, sc, _, loc = cv2.minMaxLoc(r)
            p = (sx0 + loc[0] + c[0], sy0 + loc[1] + c[1])
            if mejor is None or sc > mejor[0]:
                mejor = (sc, p, g[2] + da)
        sc, p, a = mejor
        if sc < 0.45:          # garra medio tapada (detras de la capucha): manda la marca a mano
            p = (g[0], g[1])
        res.append({"x": round(p[0], 1), "y": round(p[1], 1), "ang": a, "score": round(float(sc), 3),
                    "guia": [round(g[0], 1), round(g[1], 1)]})
    return res


if __name__ == "__main__" and len(sys.argv) > 2 and sys.argv[2] == "afinar":
    r = afinar(sys.argv[1])
    (PROY / f"raw/master_mason/anim/baston/garra_{sys.argv[1]}.json").write_text(json.dumps(r))
    for i, e in enumerate(r):
        if e and i % 4 == 0:
            print(i, e)
    sys.exit()

if __name__ == "__main__":
    caso = sys.argv[1]
    r = seguir(caso)
    (PROY / f"raw/master_mason/anim/baston/garra_{caso}.json").write_text(json.dumps(r, indent=0))
    for e in r[::6]:
        print(e)

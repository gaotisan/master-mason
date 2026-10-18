"""Fondo del titulo SIN letras y el material de las letras para pintarlas por codigo.

El titulo se escribe en el juego (scripts/intro/titulo_letras.gd), traducible;
la imagen ya no lleva letras (2026-10-18, al pasar de Master Mason a The Master
Builder). De las letras pintadas que tenia se saca todo lo necesario para que
las de codigo se vean iguales:

  1. Mascaras de las letras de antes: lo que se aparta de la placa sin letras
     vieja (salida/title_placa_sin_letras_mason.png).
  2. El fondo sin letras: luz de baja frecuencia interpolada desde fuera, por
     escalas, y el detalle (grietas y grano) a parches de la placa limpia
     (Criminisi, en capas de cebolla).
  3. La forma: son Cinzel 650 apenas condensada (96,8 %); se midio con el ancho
     y el area de la tinta de MASTER y MASON.
  4. El material: color de la letra y su canto como funcion suave de la
     distancia al borde, la orientacion del borde (la luz del bisel), la altura
     en la letra y la posicion en la linea, por minimos cuadrados sobre MASTER y
     MASON. Va a assets/intro/titulo_material.png (curvas por distancia).
  5. El grano de la cara (lo que el modelo suave no explica, de bien dentro), en
     una tesela: assets/intro/titulo_grano.png.
  6. La sombra: sale de los pies de la letra, caida hacia abajo y difuminada;
     ajustada contra la placa ya limpia.
  Tamanos, bases y centros de cada linea, y la sombra: titulo_metricas.json.

Fuente: salida/title_background_hojas_mason.png, la imagen con MASTER MASON
(la de componer.py antes de este paso; esta en git en el commit 6bf6cc4:
assets/intro/title_background_hojas.png). Escribe el fondo sin letras en
assets/intro/title_background_hojas.png y la placa (el mismo recorte) en
assets/intro/title_placa_sin_letras.png.

Uso: python titulo_sin_letras.py [--solo-material]
"""
import argparse
import json
import os

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.normpath(os.path.join(AQUI, "..", "..", ".."))
ORIGEN = os.path.join(AQUI, "salida", "title_background_hojas_mason.png")
PLACA_VIEJA = os.path.join(AQUI, "salida", "title_placa_sin_letras_mason.png")
FONDO = os.path.join(PROYECTO, "assets", "intro", "title_background_hojas.png")
PLACA = os.path.join(PROYECTO, "assets", "intro", "title_placa_sin_letras.png")
MATERIAL = os.path.join(PROYECTO, "assets", "intro", "titulo_material.png")
GRANO = os.path.join(PROYECTO, "assets", "intro", "titulo_grano.png")
METRICAS = os.path.join(AQUI, "titulo_metricas.json")
FUENTE = os.path.join(PROYECTO, "assets", "fonts", "Cinzel-Variable.ttf")
DEPURAR = os.path.join(AQUI, "salida", "depurar")

# Recorte de la placa en la imagen (el mismo de PLACA_RECT del shader).
X0, Y0, W, H = 1000, 540, 740, 520
PESO = 650
ESTRECHO = 0.968         # las pintadas son Cinzel apenas condensada
SS = 4                   # supermuestreo de las formas


def lum(im):
    return 0.114 * im[..., 0] + 0.587 * im[..., 1] + 0.299 * im[..., 2]


# --- 1. letras de ahora ------------------------------------------------------

def letras_pintadas(A, P):
    """Mascara de la cara de las letras y sus componentes por palabra."""
    d = lum(A) - lum(P)
    abierta = cv2.morphologyEx((d > 25).astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    # la cerrada (sin los poros del grano) para la forma; la abierta para
    # separar letras, que al cerrar se tocan por las serifas
    cerrada = cv2.morphologyEx(abierta, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
    n, lab, st, _ = cv2.connectedComponentsWithStats(abierta)
    palabras = {"THE": [], "MASTER": [], "MASON": []}
    for i in range(1, n):
        x, y, w, h, area = st[i]
        if area < 60:
            continue
        cy = y + h / 2
        clave = "THE" if cy < 130 else ("MASTER" if cy < 290 else "MASON")
        palabras[clave].append(i)
    zonas = {k: cv2.dilate(np.isin(lab, v).astype(np.uint8), np.ones((5, 5), np.uint8)) for k, v in palabras.items()}
    mas = {k: cerrada * z for k, z in zonas.items()}
    cajas = {k: sorted([tuple(st[i][:4]) for i in v if st[i][3] > 40]) for k, v in palabras.items()}
    return mas, cajas


def campo_distancia(mascara_ss):
    """Distancia con signo (px de la imagen, + dentro) a partir de una mascara
    supermuestreada, en el centro de cada pixel."""
    m = mascara_ss.astype(np.uint8)
    dent = cv2.distanceTransform(m, cv2.DIST_L2, 5)
    fuera = cv2.distanceTransform(1 - m, cv2.DIST_L2, 5)
    sd = (dent - fuera) / SS
    h, w = m.shape
    return cv2.resize(sd, (w // SS, h // SS), interpolation=cv2.INTER_AREA)


def suavizar_ss(m):
    """Mascara pintada (1x, con dientes) a supermuestreada y suave."""
    up = cv2.resize(m.astype(np.float32), None, fx=SS, fy=SS, interpolation=cv2.INTER_LINEAR)
    up = cv2.GaussianBlur(up, (0, 0), SS * 0.7)
    return (up > 0.5).astype(np.uint8)


# --- formas de Cinzel --------------------------------------------------------

def fuente(px):
    f = ImageFont.truetype(FUENTE, px)
    f.set_variation_by_axes([PESO])
    return f


_TINTA = {}


def tinta(f, ch):
    """Caja de la tinta de una letra (l, t, r, b) respecto al origen en la linea
    base. font.getbbox da la caja del avance, con los margenes."""
    clave = (f.size, ch)
    if clave not in _TINTA:
        im = Image.new("L", (f.size * 3, f.size * 3))
        ox, oy = f.size, f.size * 2
        ImageDraw.Draw(im).text((ox, oy), ch, font=f, fill=255, anchor="ls")
        l, t_, r, b = im.point(lambda v: 255 if v > 127 else 0).getbbox()
        _TINTA[clave] = (l - ox, t_ - oy, r - ox, b - oy)
    return _TINTA[clave]


# --- 2. relleno de la placa --------------------------------------------------

def baja_frecuencia(img, conocido, sigma):
    """Luz suave con los huecos interpolados por escalas: cerca manda la escala
    fina; donde no llega (huecos grandes), la siguiente, mas ancha."""
    k = conocido.astype(np.float32)
    out = None
    for s in (sigma * 15, sigma * 6, sigma * 2.5, sigma):
        num = cv2.GaussianBlur(img * k[..., None], (0, 0), s)
        den = cv2.GaussianBlur(k, (0, 0), s)[..., None]
        est = num / np.maximum(den, 1e-6)
        if out is None:
            out = est
        else:
            peso = np.clip(den / 0.3, 0, 1)
            out = est * peso + out * (1 - peso)
    return out


def criminisi(D, hueco, fuente_ok, p=13, ventana=170, semilla=7):
    """Rellena D (detalle) en el hueco copiando parches de donde fuente_ok."""
    rng = np.random.default_rng(semilla)
    D = D.copy()
    h, w = hueco.shape
    r = p // 2
    falta = hueco.copy()
    conf = (~falta).astype(np.float32)
    # centros validos: parche entero en fuente_ok
    ok = cv2.erode(fuente_ok.astype(np.uint8), np.ones((p, p), np.uint8)).astype(bool)
    ok[:r, :] = ok[-r:, :] = False
    ok[:, :r] = ok[:, -r:] = False
    usados = np.zeros((h, w), np.float32)
    total = falta.sum()
    while falta.any():
        borde = falta & (cv2.dilate((~falta).astype(np.uint8), np.ones((3, 3), np.uint8)) > 0)
        ys, xs = np.nonzero(borde)
        # confianza del parche y termino de datos (isofotas que entran al hueco)
        cc = cv2.boxFilter(conf, -1, (p, p), normalize=True)
        g = lum(D) * (~falta)
        gx = cv2.Sobel(g, cv2.CV_32F, 1, 0, ksize=3)
        gy = cv2.Sobel(g, cv2.CV_32F, 0, 1, ksize=3)
        mf = cv2.GaussianBlur(falta.astype(np.float32), (0, 0), 1.5)
        nx = cv2.Sobel(mf, cv2.CV_32F, 1, 0, ksize=3)
        ny = cv2.Sobel(mf, cv2.CV_32F, 0, 1, ksize=3)
        nn = np.hypot(nx, ny) + 1e-6
        datos = np.abs(-gy * nx / nn + gx * ny / nn) / 255.0 + 0.001
        pri = cc[ys, xs] * (0.15 + np.minimum(datos[ys, xs], 0.3))
        k = int(np.argmax(pri))
        cy, cx = int(np.clip(ys[k], r, h - r - 1)), int(np.clip(xs[k], r, w - r - 1))
        t = D[cy - r:cy + r + 1, cx - r:cx + r + 1]
        mk = (~falta[cy - r:cy + r + 1, cx - r:cx + r + 1]).astype(np.float32)
        y0, y1 = max(0, cy - ventana), min(h, cy + ventana)
        x0, x1 = max(0, cx - ventana), min(w, cx + ventana)
        zona = D[y0:y1, x0:x1]
        res = cv2.matchTemplate(zona, t, cv2.TM_SQDIFF, mask=np.dstack([mk] * 3))
        valido = ok[y0 + r:y1 - r, x0 + r:x1 - r][:res.shape[0], :res.shape[1]]
        res = np.where(valido, res, np.inf)
        # un poco de castigo a reusar el mismo sitio, para que no se repita
        res = res + usados[y0 + r:y1 - r, x0 + r:x1 - r][:res.shape[0], :res.shape[1]] * (mk.sum() * 40.0)
        if not np.isfinite(res).any():
            ventana *= 2
            continue
        mejores = np.argsort(res, axis=None)[:4]
        sel = mejores[rng.integers(0, len(mejores))] if rng.random() < 0.4 else mejores[0]
        sy, sx = np.unravel_index(sel, res.shape)
        sy += y0 + r
        sx += x0 + r
        usados[max(0, sy - r):sy + r + 1, max(0, sx - r):sx + r + 1] += 1
        trozo = falta[cy - r:cy + r + 1, cx - r:cx + r + 1]
        D[cy - r:cy + r + 1, cx - r:cx + r + 1][trozo] = D[sy - r:sy + r + 1, sx - r:sx + r + 1][trozo]
        conf[cy - r:cy + r + 1, cx - r:cx + r + 1][trozo] = cc[cy, cx]
        falta[cy - r:cy + r + 1, cx - r:cx + r + 1][trozo] = False
    return D


def solo_placa():
    """Donde se puede copiar placa: sin el marco (arriba y abajo) ni la
    telarana de la esquina de abajo a la derecha."""
    z = np.zeros((H, W), bool)
    z[24:H - 30, 12:W - 12] = True
    yy, xx = np.mgrid[0:H, 0:W]
    z &= ~((xx > W - 230) & (yy > H - 140))
    z &= ~((xx < 120) & (yy > H - 60))
    return z


def rellenar(A, hueco, sin_letras):
    """Placa sin lo que haya en el hueco: luz baja interpolada + detalle copiado."""
    sin_letras = sin_letras & solo_placa()
    conocido = ~hueco
    baja = baja_frecuencia(A, conocido & sin_letras, 18)
    baja_hueco = baja_frecuencia(A, conocido, 18)
    D = A - baja_hueco
    D[hueco] = 0
    D = criminisi(D, hueco, sin_letras & conocido)
    out = A.copy()
    out[hueco] = (baja + D)[hueco]
    return out


# --- 3. material --------------------------------------------------------------

NUDOS = np.array([-4, -3, -2, -1.5, -1, -0.5, 0, 0.5, 1, 1.5, 2, 2.5, 3, 4, 5, 6.5, 8, 12], np.float32)


def geometria(sd):
    """Normal del borde (hacia dentro) a partir de la distancia con signo."""
    gy, gx = np.gradient(cv2.GaussianBlur(sd, (0, 0), 0.8))
    n = np.hypot(gx, gy) + 1e-6
    return gx / n, gy / n


def base_material(sd, nx, ny, v, u):
    """Columnas del modelo de color: un perfil por distancia al borde (rampas
    entre NUDOS), cada uno con la orientacion del borde (la luz del bisel), mas
    la altura en la letra y la posicion en la linea."""
    s = np.clip(sd, NUDOS[0], NUDOS[-1])
    cols = []
    cerca = np.exp(-np.maximum(s, 0) / 2.5)
    for k in range(len(NUDOS)):
        izq = NUDOS[k - 1] if k else NUDOS[0] - 1
        der = NUDOS[k + 1] if k + 1 < len(NUDOS) else NUDOS[-1] + 1
        h = np.where(s < NUDOS[k], (s - izq) / (NUDOS[k] - izq), (der - s) / (der - NUDOS[k]))
        h = np.clip(h, 0, 1)
        cols += [h, h * nx * cerca, h * ny * cerca, h * nx * ny * cerca, h * (nx * nx - ny * ny) * cerca]
    dentro = np.clip(sd, 0, 2) / 2
    cols += [v * dentro, v * v * dentro, u * dentro, u * u * dentro]
    return np.stack(cols, -1)


def coordenadas_linea(cajas_linea, forma):
    """v: altura dentro de la letra (0 arriba, 1 base); u: posicion en la linea."""
    top = min(c[1] for c in cajas_linea)
    base = max(c[1] + c[3] for c in cajas_linea)
    izq = min(c[0] for c in cajas_linea)
    der = max(c[0] + c[2] for c in cajas_linea)
    yy, xx = np.mgrid[0:forma[0], 0:forma[1]].astype(np.float32)
    v = (yy - top) / (base - top)
    u = (xx - (izq + der) / 2) / ((der - izq) / 2)
    return v, u


def campo_palabra(mas, cajas, pal):
    sd = campo_distancia(suavizar_ss(mas[pal]))
    v, u = coordenadas_linea(cajas[pal], sd.shape)
    nx, ny = geometria(sd)
    sel = sd > NUDOS[0]
    top = min(c[1] for c in cajas[pal]) - 8
    base = max(c[1] + c[3] for c in cajas[pal]) + 8
    sel[:top] = False
    sel[base:] = False
    return sd, nx, ny, v, u, sel


def ajustar_material(A, campos):
    """Color de la letra y su canto como funcion suave de la distancia al borde,
    la orientacion del borde y la posicion (minimos cuadrados con un poco de
    regularizacion)."""
    X, Y = [], []
    for sd, nx, ny, v, u, sel in campos:
        X.append(base_material(sd, nx, ny, v, u)[sel])
        Y.append(A[sel])
    X = np.concatenate(X)
    Y = np.concatenate(Y)
    coef = np.linalg.solve(X.T @ X + 1e-2 * len(X) * 1e-3 * np.eye(X.shape[1]), X.T @ Y)
    print(f"material: error medio {np.abs(X @ coef - Y).mean():.1f} /255 en {len(X)} px")
    return coef


def residuo_textura(A, coef, campos):
    """El grano de la cara: lo que el modelo suave no explica, sacado de bien dentro (se pone hasta el filo)."""
    R = np.zeros_like(A)
    ok = np.zeros(A.shape[:2], bool)
    for sd, nx, ny, v, u, sel in campos:
        m = sel & (sd > 1.0)
        R[m] = A[m] - base_material(sd, nx, ny, v, u)[m] @ coef
        ok |= m
    return R, ok


# --- 4. sombra ---------------------------------------------------------------

def pies(cara, v, desde):
    return cara.astype(np.float32) * (v > desde)


def ajustar_sombra(A, limpio, cara, zona, v):
    """1 - a*blur(cara, s1) - b*blur(cara desplazada (dx, dy), s2), contra la
    placa ya limpia (fuera de las letras)."""
    r = cv2.GaussianBlur(lum(A), (0, 0), 1.5) / np.maximum(cv2.GaussianBlur(lum(limpio), (0, 0), 1.5), 1)
    sel = zona & (cv2.dilate(cara, np.ones((7, 7), np.uint8)) == 0)
    Y = 1 - r[sel]
    mejor = None
    c = cara.astype(np.float32)
    for s1 in (1.5, 3, 5):
        b1 = cv2.GaussianBlur(c, (0, 0), s1)[sel]
        for desde in (0.0, 0.6, 0.75, 0.85):
            pc = pies(cara, v, desde)
            for s2 in (6, 8, 10, 12, 14):
                for dy in (10, 14, 17, 20, 23, 26):
                    for dx in (0, 2, 4):
                        M = np.float32([[1, 0, dx], [0, 1, dy]])
                        b2 = cv2.GaussianBlur(cv2.warpAffine(pc, M, c.shape[::-1]), (0, 0), s2)[sel]
                        X = np.stack([b1, b2], 1)
                        coef, *_ = np.linalg.lstsq(X, Y, rcond=None)
                        coef = np.maximum(coef, 0)
                        e = np.mean((Y - X @ coef) ** 2)
                        if mejor is None or e < mejor[0]:
                            mejor = (e, s1, s2, dy, dx, desde, coef)
    e, s1, s2, dy, dx, desde, coef = mejor
    print(f"sombra: s1={s1} s2={s2} dy={dy} dx={dx} pies>{desde} a={coef[0]:.3f} b={coef[1]:.3f} (ecm {e:.5f})")
    return s1, s2, dy, dx, desde, coef


# --- exportar para el shader ---------------------------------------------------

SD_MIN, SD_MAX, N_SD = -4.0, 12.0, 64


def curvas_material(coef):
    """Las columnas de base_material en una rejilla de distancias: fila 0 el
    color, filas 1-4 lo que suma cada termino de la orientacion del borde
    (ya con su caida hacia dentro), fila 5 los terminos de altura y linea."""
    sds = np.linspace(SD_MIN, SD_MAX, N_SD).astype(np.float32)
    s = np.clip(sds, NUDOS[0], NUDOS[-1])
    cerca = np.exp(-np.maximum(s, 0) / 2.5)
    filas = np.zeros((5, N_SD, 3), np.float32)
    for k in range(len(NUDOS)):
        izq = NUDOS[k - 1] if k else NUDOS[0] - 1
        der = NUDOS[k + 1] if k + 1 < len(NUDOS) else NUDOS[-1] + 1
        h = np.clip(np.where(s < NUDOS[k], (s - izq) / (NUDOS[k] - izq), (der - s) / (der - NUDOS[k])), 0, 1)
        for t in range(5):
            filas[t] += (h * (cerca if t else 1.0))[:, None] * coef[5 * k + t][None, :]
    globales = coef[5 * len(NUDOS):5 * len(NUDOS) + 4]       # v, v2, u, u2 (por dentro)
    return filas, globales


def exportar_material(coef, ruta):
    filas, globales = curvas_material(coef)
    img = np.zeros((6, N_SD, 3), np.float32)
    img[0] = filas[0]
    img[1:5] = 128 + filas[1:5]
    img[5, :4] = 128 + globales / 2
    img[5, 4:] = 128
    fuera = (img < 0) | (img > 255)
    if fuera.any():
        print(f"  aviso: {fuera.sum()} valores del material fuera de rango (se recortan)")
    cv2.imwrite(ruta, np.clip(np.round(img), 0, 255).astype(np.uint8))
    print("escrito", ruta)


def exportar_grano(R, ok, ruta, lado=256, semilla=21):
    """Tesela de grano de las caras pintadas (se lee en espejo, sin costuras)."""
    h, w = ok.shape
    lienzo_h = max(h, lado)
    D = np.zeros((lienzo_h, w + lado + 20, 3), np.float32)
    D[:h, :w] = R * ok[..., None]
    fuente_ok = np.zeros(D.shape[:2], bool)
    fuente_ok[:h, :w] = ok
    hueco = np.zeros(D.shape[:2], bool)
    x0 = w + 20
    hueco[:lado, x0:x0 + lado] = True
    # semilla: un parche de verdad en el centro del lienzo
    ys, xs = np.nonzero(cv2.erode(ok.astype(np.uint8), np.ones((9, 9), np.uint8)))
    i = len(ys) // 2
    cy, cx = lado // 2, x0 + lado // 2
    D[cy - 4:cy + 5, cx - 4:cx + 5] = R[ys[i] - 4:ys[i] + 5, xs[i] - 4:xs[i] + 5]
    hueco[cy - 4:cy + 5, cx - 4:cx + 5] = False
    T = criminisi(D, hueco, fuente_ok, p=9, ventana=2000, semilla=semilla)[:lado, x0:x0 + lado]
    T = T - cv2.GaussianBlur(T, (0, 0), 4)
    T = np.clip(T, -38, 38)
    cv2.imwrite(ruta, np.clip(np.round(128 + T * 2), 0, 255).astype(np.uint8))
    print("escrito", ruta)


def metricas(cajas, sombra_p):
    """Lo que necesita titulo_letras.gd: tamanos, bases y centros de cada linea
    (en px de la imagen) y la sombra."""
    f = fuente(1000)
    l, t, r, b = tinta(f, "M")
    cap_em = (b - t) / 1000
    lineas = []
    for pal in ("THE", "MASTER", "MASON"):
        c = cajas[pal]
        alto = c[0][3] if pal != "THE" else max(k[3] for k in c)
        base = max(k[1] + k[3] for k in c if k[3] >= alto - 3)
        izq = min(k[0] for k in c)
        der = max(k[0] + k[2] for k in c)
        lineas.append({"palabra": pal, "cap": int(alto), "tam": round(alto / cap_em, 1),
                       "base_y": int(base + Y0), "centro_x": round((izq + der) / 2 + X0, 1),
                       "ancho": int(der - izq)})
    s1, s2, dy, dx, desde, coef = sombra_p
    return {"cap_em": round(cap_em, 4), "peso": PESO, "estrecho": ESTRECHO, "lineas": lineas,
            "huecos_master": [int(cajas["MASTER"][i + 1][0] - cajas["MASTER"][i][0] - cajas["MASTER"][i][2])
                              for i in range(len(cajas["MASTER"]) - 1)],
            "sombra": {"sigma": s2, "dy": dy, "dx": dx, "pies_desde": desde, "fuerza": round(float(coef[1]), 3)}}


# --- montaje -----------------------------------------------------------------

def _zona(cajas_linea):
    z = np.zeros((H, W), bool)
    top = min(c[1] for c in cajas_linea) - 10
    base = max(c[1] + c[3] for c in cajas_linea) + 35
    izq = min(c[0] for c in cajas_linea) - 20
    der = max(c[0] + c[2] for c in cajas_linea) + 20
    z[top:base, izq:der] = True
    return z


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--solo-material", action="store_true", help="no rehace el fondo")
    args = ap.parse_args()
    os.makedirs(DEPURAR, exist_ok=True)

    img = cv2.imread(ORIGEN).astype(np.float32)
    A = img[Y0:Y0 + H, X0:X0 + W].copy()
    P = cv2.imread(PLACA_VIEJA).astype(np.float32)
    mas, cajas = letras_pintadas(A, P)
    for k, v in cajas.items():
        print(k, len(v), "letras")
    cara_todas = np.maximum.reduce([mas["THE"], mas["MASTER"], mas["MASON"]])

    def influencia(m):
        m = cv2.dilate(m.astype(np.uint8), np.ones((15, 15), np.uint8))
        abajo = cv2.warpAffine(m, np.float32([[1, 0, 0], [0, 1, 32]]), (W, H))
        return cv2.dilate(np.maximum(m, abajo), np.ones((11, 11), np.uint8)) > 0

    hueco = influencia(cara_todas)
    sin_letras = ~hueco
    placa = rellenar(A, hueco, sin_letras)
    v_master, _ = coordenadas_linea(cajas["MASTER"], (H, W))
    sombra_p = ajustar_sombra(A, placa, mas["MASTER"], _zona(cajas["MASTER"]), v_master)

    campos = [campo_palabra(mas, cajas, k) for k in ("MASTER", "MASON")]
    coef = ajustar_material(A, campos)
    R, ok = residuo_textura(A, coef, campos)
    exportar_material(coef, MATERIAL)
    exportar_grano(R, ok, GRANO)
    with open(METRICAS, "w", encoding="utf-8") as f:
        json.dump(metricas(cajas, sombra_p), f, indent=1, ensure_ascii=False)
    print("escrito", METRICAS)

    if args.solo_material:
        return
    suave = cv2.GaussianBlur(hueco.astype(np.float32), (0, 0), 3)[..., None]
    suave = np.where(cv2.erode(hueco.astype(np.uint8), np.ones((7, 7), np.uint8))[..., None] > 0, 1.0, suave)
    final_c = A * (1 - suave) + placa * suave
    out = img.copy()
    out[Y0:Y0 + H, X0:X0 + W] = final_c
    cv2.imwrite(FONDO, np.clip(np.round(out), 0, 255).astype(np.uint8))
    print("escrito", FONDO)
    # La placa de la salida de las letras es ya el mismo fondo.
    cv2.imwrite(PLACA, np.clip(np.round(final_c), 0, 255).astype(np.uint8))
    print("escrito", PLACA)


if __name__ == "__main__":
    main()

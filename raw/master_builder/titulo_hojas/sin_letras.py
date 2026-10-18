"""Fondo del titulo SIN las letras (las velas se quedan), para pintar el titulo
por codigo (2026-10-14: asi se puede cambiar el nombre del juego).

Las letras estan pintadas en el cristal del ataud. Debajo no hay nada que
recuperar: se rellena con el panel de la imagen de Gemini que el usuario saco
sin letras ni velas (raw/master_builder/titulo_hojas/gemini_sin_letras.jpeg). Es
la misma imagen rehecha: al subirla a 2912x1632 cae encima de la actual con
error de ~1 px y sus grietas siguen las de alrededor. Pero es mas oscura, mas
blanda y sin grano, asi que de ella solo se toma el dibujo (grietas y manchas,
lo que queda al quitarle el desenfoque de sigma 28) y:
  1. la luz es la de Gemini (la forma de la luz sin letras) corregida al tono
     de la actual: el cociente entre las dos en el panel libre, llevado suave
     por debajo de las letras;
  2. las grietas: en Gemini son blandas (la imagen es de 1372 px). Se buscan
     alli (black-hat), se adelgazan a un pixel y se dibujan a 2912 con la
     hondura de las de la actual (medida en el panel de alrededor);
  3. las manchas de Gemini (de sigma 6 a 28), solo en brillo y sin subir;
  4. el grano y el craquelado fino (sigma < 4, sin grietas) se traen de la
     actual, de sitios cercanos que no
     sean letra (con desplazamientos al azar, sin costuras).
Solo se toca el bloque del titulo; el resto de la imagen queda igual pixel a
pixel.

Uso: python sin_letras.py [--salida RUTA]
     (por defecto salida/title_background_sin_letras.png, para mirarla antes
     de cambiar la del juego)
"""
import argparse
import os

import cv2
import numpy as np

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.normpath(os.path.join(AQUI, "..", "..", ".."))
FONDO = os.path.join(PROYECTO, "assets", "intro", "title_background_hojas.png")
GEMINI = os.path.join(AQUI, "gemini_sin_letras.jpeg")

# Bloque del titulo (px de la imagen): las letras con su sombra y margen. Las
# velas (x 868 y 1852) quedan fuera.
X0, Y0, X1, Y1 = 1000, 520, 1740, 1060
SEMILLA = 3
# Black-hat (de Gemini subida) a partir del que hay grieta, y cuanto oscurece
# la grieta su sitio (0..1).
UMBRAL_GRIETA = 5.0
HONDURA_GRIETA = 0.8


def mascara_letras(gris):
    """Letras, su bisel y su sombra: lo que se aparta del panel de alrededor."""
    fondo = cv2.medianBlur(gris, 61)
    dif = np.abs(gris.astype(np.float32) - fondo.astype(np.float32))
    m = (cv2.GaussianBlur(dif, (0, 0), 2) > 16).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(m)
    keep = np.zeros_like(m)
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] > 900:
            keep[lab == i] = 1
    keep = cv2.morphologyEx(keep, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    keep = cv2.dilate(keep, np.ones((15, 15), np.uint8))
    sombra = np.zeros_like(keep)
    sombra[10:, 8:] = keep[:-10, :-8]
    return np.maximum(keep, sombra)


def adelgazar(b):
    """Zhang-Suen: deja las lineas de una mascara binaria en un pixel."""
    b = b.astype(np.uint8).copy()
    while True:
        cambio = False
        for paso in (0, 1):
            p = np.pad(b, 1)
            v = [p[:-2, 1:-1], p[:-2, 2:], p[1:-1, 2:], p[2:, 2:], p[2:, 1:-1], p[2:, :-2], p[1:-1, :-2], p[:-2, :-2]]
            n = sum(x.astype(int) for x in v)
            trans = sum(((v[i] == 0) & (v[(i + 1) % 8] == 1)).astype(int) for i in range(8))
            if paso == 0:
                c = (v[0] * v[2] * v[4] == 0) & (v[2] * v[4] * v[6] == 0)
            else:
                c = (v[0] * v[2] * v[6] == 0) & (v[0] * v[4] * v[6] == 0)
            quita = (b == 1) & (n >= 2) & (n <= 6) & (trans == 1) & c
            if quita.any():
                b[quita] = 0
                cambio = True
        if not cambio:
            return b


def alinear(gemini, actual):
    """Gemini subida a 2912x1632 y ajustada a la actual (homografia por SIFT,
    fuera del bloque del titulo y de las velas)."""
    g = cv2.resize(gemini, (actual.shape[1], actual.shape[0]), interpolation=cv2.INTER_CUBIC)
    gg = cv2.cvtColor(g, cv2.COLOR_BGR2GRAY)
    ag = cv2.cvtColor(actual, cv2.COLOR_BGR2GRAY)
    fuera = np.full_like(ag, 255)
    fuera[540:1060, 780:1940] = 0
    sift = cv2.SIFT_create(6000)
    k1, d1 = sift.detectAndCompute(gg, fuera)
    k2, d2 = sift.detectAndCompute(ag, fuera)
    pares = [a for a, b in cv2.BFMatcher().knnMatch(d1, d2, k=2) if a.distance < 0.7 * b.distance]
    p1 = np.float32([k1[a.queryIdx].pt for a in pares])
    p2 = np.float32([k2[a.trainIdx].pt for a in pares])
    hm, _ = cv2.findHomography(p1, p2, cv2.RANSAC, 3.0)
    return cv2.warpPerspective(g, hm, (actual.shape[1], actual.shape[0]), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REFLECT)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--salida", default=os.path.join(AQUI, "salida", "title_background_sin_letras.png"))
    args = ap.parse_args()

    im = cv2.imread(FONDO)
    gem = alinear(cv2.imread(GEMINI), im)
    f = im[Y0:Y1, X0:X1].astype(np.float32)
    g = gem[Y0:Y1, X0:X1].astype(np.float32)
    m = mascara_letras(cv2.cvtColor(im[Y0:Y1, X0:X1], cv2.COLOR_BGR2GRAY))
    # Solo alrededor de las letras (x 1095..1619, y 594..942 en la imagen): la
    # mediana tambien marca la moldura de arriba y cosas del panel.
    caja = np.zeros_like(m)
    caja[594 - 40 - Y0:942 + 50 - Y0, 1095 - 40 - X0:1619 + 50 - X0] = 1
    zona = cv2.dilate(m * caja, np.ones((9, 9), np.uint8))

    def media_libre(x, sigma, libre):
        """Media de x en el panel libre (sin letras), rellenando el hueco."""
        num = cv2.GaussianBlur(x * libre[..., None], (0, 0), sigma)
        den = cv2.GaussianBlur(libre, (0, 0), sigma)[..., None]
        return num / np.maximum(den, 1e-4)

    # 1. Luz: la de Gemini (sin letras, la forma buena de la luz) corregida al
    # tono de la actual: el cociente entre las dos, medido en el panel libre y
    # llevado suave por debajo de las letras.
    baja_g = cv2.GaussianBlur(g, (0, 0), 28)
    baja_f = cv2.GaussianBlur(f, (0, 0), 28)
    def corregir(zona):
        libre = (1 - zona).astype(np.float32)
        return media_libre(baja_f, 90, libre) / np.maximum(media_libre(baja_g, 90, libre), 1.0)
    # La mascara por mediana no coge entera la sombra blanda de las letras
    # (bajo THE quedaba una mancha): lo que mas se aparta de Gemini ya
    # corregida es letra, bisel, sombra o brillo, y las grietas mucho menos.
    cociente = corregir(zona)
    lum = lambda x: cv2.GaussianBlur(x, (0, 0), 3).mean(2)
    aparte = np.abs(lum(f) - lum(g * cociente)) > 14
    aparte = cv2.morphologyEx(aparte.astype(np.uint8), cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
    zona = cv2.dilate(np.maximum(zona, aparte * caja), np.ones((13, 13), np.uint8))
    zona = cv2.morphologyEx(zona, cv2.MORPH_CLOSE, np.ones((21, 21), np.uint8))
    libre = (1 - zona).astype(np.float32)
    cociente = corregir(zona)
    luz = baja_g * cociente

    # 2. Grietas: en Gemini (black-hat a su tamano, subido), adelgazadas a un
    # pixel y dibujadas finas.
    gg = cv2.cvtColor(g.astype(np.uint8), cv2.COLOR_BGR2GRAY)
    bh = cv2.morphologyEx(gg, cv2.MORPH_BLACKHAT, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (11, 11))).astype(np.float32)
    bh = cv2.GaussianBlur(bh, (0, 0), 1.2)
    linea = adelgazar(bh > UMBRAL_GRIETA)
    # fuera los trocitos sueltos (ruido de la jpeg)
    n, lab, st, _ = cv2.connectedComponentsWithStats(linea, connectivity=8)
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] < 25:
            linea[lab == i] = 0
    fuerza = np.clip(bh / (UMBRAL_GRIETA * 2.5), 0.4, 1.0)
    grieta = cv2.GaussianBlur(linea.astype(np.float32) * fuerza, (0, 0), 0.85)
    grieta /= max(grieta.max(), 1e-3)

    # 3. Manchas de Gemini (sigma 6 a 28), solo en brillo y sin subir: subidas
    # salian a parches.
    def banda(x):
        return cv2.GaussianBlur(x, (0, 0), 6) - cv2.GaussianBlur(x, (0, 0), 28)
    tono = luz / np.maximum(luz.mean(2, keepdims=True), 1.0)
    dibujo = banda(g).mean(2)[..., None] * tono

    # 4. Grano y craquelado fino de la actual (por debajo de sigma 4), traido
    # de sitios cercanos que no son letra. Sin las grietas (lo que el black-hat
    # marca como hondo se aplana): trasplantadas dejaban trozos sueltos.
    alta = f - cv2.GaussianBlur(f, (0, 0), 4)
    gf = cv2.cvtColor(f.astype(np.uint8), cv2.COLOR_BGR2GRAY)
    hondo_f = cv2.morphologyEx(gf, cv2.MORPH_BLACKHAT, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))).astype(np.float32)
    alta *= (1.0 - np.clip((hondo_f - 22.0) / 20.0, 0.0, 1.0))[..., None]
    prohibido = zona.astype(bool).copy()
    prohibido[:60], prohibido[-40:] = True, True
    rng = np.random.default_rng(SEMILLA)
    grano = np.zeros_like(alta)
    falta = zona.astype(bool).copy()
    for _ in range(80):
        dy, dx = rng.integers(-160, 161, 2)
        src = np.roll(np.roll(alta, dy, 0), dx, 1)
        ok = ~np.roll(np.roll(prohibido, dy, 0), dx, 1)
        usa = falta & ok
        grano[usa] = src[usa]
        falta &= ~usa
        if not falta.any():
            break

    nuevo = (luz + dibujo) * (1.0 - HONDURA_GRIETA * grieta[..., None]) + grano
    suave = cv2.GaussianBlur(zona.astype(np.float32), (0, 0), 5)[..., None]
    blq = nuevo * suave + f * (1 - suave)
    out = im.copy()
    out[Y0:Y1, X0:X1] = np.clip(np.round(blq), 0, 255).astype(np.uint8)
    os.makedirs(os.path.dirname(args.salida), exist_ok=True)
    cv2.imwrite(args.salida, out)
    cv2.imwrite(os.path.join(AQUI, "salida", "sin_letras_zona.png"), zona * 255)
    # Hondura de las grietas comparada con las de alrededor (black-hat).
    def hondo(x):
        gx = cv2.cvtColor(np.clip(x, 0, 255).astype(np.uint8), cv2.COLOR_BGR2GRAY)
        return cv2.morphologyEx(gx, cv2.MORPH_BLACKHAT, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))).astype(np.float32)
    dentro = zona.astype(bool)
    alrededor = (cv2.dilate(zona, np.ones((61, 61), np.uint8)) > 0) & ~dentro
    print("escrito", args.salida, "black-hat p95/p99 dentro %.0f/%.0f alrededor %.0f/%.0f" % (
        *np.percentile(hondo(blq)[dentro], [95, 99]), *np.percentile(hondo(f)[alrededor], [95, 99])))


if __name__ == "__main__":
    main()

"""Fondo del titulo con hojas.

Junta dos imagenes de 2912x1632:
  - fuente_actual.png: el fondo de siempre. De ahi sale el cristal del ataud con
    su marco, las letras, las velas y la telarana de la arana. Todas las medidas
    de la escena (window_rect, velas, titulo, posadas de la arana) estan tomadas
    sobre esta imagen, asi que esa parte se copia tal cual, pixel a pixel.
  - fuente_hojas.png: la version "extend" de Midjourney con follaje. De ahi sale
    todo lo de alrededor.

En la de hojas el cristal es ~100 px mas estrecho por la derecha (el extend
descentro el marco), asi que antes de juntar se estira en horizontal, con una
curva suave, para que su marco caiga encima del de la actual; luego cada pila
de molduras se ajusta fino (alineamiento dinamico de perfiles de brillo) para
que ranuras y cantos coincidan. Las columnas doradas de los bordes se borran
rellenando con follaje.

La union va por una costura de coste minimo pegada al canto del cristal (el
marco es el de la imagen de hojas, con las hojas que cuelgan por delante) y se
funde por bandas de frecuencia: el detalle corta limpio y el tono se reparte en
ancho. Dentro del cristal la diferencia con la actual queda en <= 8/255.

Uso: python componer.py [--salida RUTA]
"""
import argparse
import os

import cv2
import numpy as np
from scipy.interpolate import PchipInterpolator

AQUI = os.path.dirname(os.path.realpath(__file__))
PROYECTO = os.path.normpath(os.path.join(AQUI, "..", "..", ".."))

W, H = 2912, 1632

# Borde del cristal (moldura interior) medido en cada imagen con perfiles de brillo.
# Actual: x 640..2185, y 542..1112.  Hojas: x 630..2088, y 557..1112.
# Borde exterior del marco por la derecha: actual 2256, hojas 2142.
# Puntos de la curva destino -> origen (x en la imagen final -> x en la de hojas).
CURVA_X = [(0, 0), (1300, 1300), (2256, 2142), (2912, 2912)]

# Bandas donde puede ir cada costura (en coordenadas de la imagen final).
BANDA_IZQ = (556, 640)
BANDA_DER = (2186, 2290)
# Arriba y abajo la costura va pegada al canto del cristal: las molduras de la
# imagen de hojas ya caen encima de las de la actual (ver estirar) y asi se
# conservan las hojas que cuelgan por delante del marco.
BANDA_ARR = (528, 574)
BANDA_ABA = (1098, 1136)

# Cuanto se bajan las luces de fuera del cristal (0 = nada).
TEMPLAR_LUCES = 0.2

# Huecos a rehacer en la imagen de hojas (antes de estirar): x0, x1, y0, y1, y de
# donde se puede sacar follaje: fx0, fx1. A la izquierda, la columna y su sombra; a la
# derecha, la columna (con la sombra que echaba) y la franja casi negra con una
# raya que dejo el extend.
HUECO_IZQ = (0, 148, 360, 1632, 148, 600)
HUECO_DER = (2632, 2912, 0, 1632, 2290, 2632)
# Franjas de las vigas largas (y0, y1), que el viento no debe mover.
VIGAS_Y = ((400, 580), (1090, 1235))
SEMILLA = 8  # la que menos rectas verticales deja en los huecos (probadas 1..12)


def leer(nombre):
    im = cv2.imread(os.path.join(AQUI, nombre), cv2.IMREAD_COLOR)
    assert im is not None and im.shape[:2] == (H, W), nombre
    return im.astype(np.float32) / 255.0


def tejer(im, out, hueco, lado, rng, bloque=104, solape=28, margen_y=70):
    """Rellena el hueco con trozos de follaje del mismo lado (image quilting,
    Efros y Freeman). Se teje en rejilla, de dentro hacia el borde y de arriba
    abajo: cada bloque se elige entre los que mejor casan, en forma y en brillo,
    con lo que ya tiene al lado (hacia dentro) y encima, y se pega por el corte
    de menor diferencia, asi que no quedan rectas. Los trozos se buscan casi a
    la misma altura (margen_y) para que la luz y las vigas sigan en su sitio, y
    se castiga repetir trozo.
    lado = -1 si el hueco toca el borde izquierdo, +1 si toca el derecho."""
    x0, x1, y0, y1, fx0, fx1 = hueco
    paso = bloque - solape
    # Columnas de bloques, de dentro hacia fuera; cada una se mete 'solape' px
    # en lo que ya esta hecho (la imagen buena o la columna anterior).
    cols = []
    if lado < 0:
        bx1 = x1 + solape
        while bx1 - bloque > x0 - paso:
            cols.append(max(bx1 - bloque, 0))
            bx1 -= paso
    else:
        bx0 = x0 - solape
        while bx0 + solape < x1:
            cols.append(min(bx0, W - bloque))
            bx0 += paso
    fuente = im[:, fx0:fx1]
    usados = []
    for bx in cols:
        y = max(y0 - solape, 0)
        primero = True
        while y + solape < y1:
            h = min(bloque, H - y)
            if H - (y + h - solape) <= solape:
                h = H - y
            dest = out[y:y + h, bx:bx + bloque]
            arriba = not (primero and y0 == 0)
            ya, yb = max(0, y - margen_y), min(H - h, y + margen_y)
            zona = fuente[ya:yb + h]
            ny, nx = zona.shape[0] - h + 1, zona.shape[1] - bloque + 1
            # Diferencia en lo ya hecho: franja de dentro y franja de arriba,
            # cada una comparada sin mascara (mucho mas rapido).
            ox = bloque - solape if lado < 0 else 0
            res = cv2.matchTemplate(zona, np.ascontiguousarray(dest[:, ox:ox + solape]), cv2.TM_SQDIFF)[:ny, ox:ox + nx].copy()
            if arriba:
                res += cv2.matchTemplate(zona, np.ascontiguousarray(dest[:solape, :]), cv2.TM_SQDIFF)[:ny, :nx]
            gy, gx = np.mgrid[0:ny, 0:nx]
            for (uy, ux) in usados:
                d2 = ((gy + ya - uy) / 90.0) ** 2 + ((gx - ux) / 70.0) ** 2
                res *= 1 + 2.5 * np.exp(-d2)
            cand = np.argwhere(res <= res.min() * 1.12 + 1e-6)
            cy, cx = cand[rng.integers(len(cand))]
            usados.append((cy + ya, cx))
            trozo = zona[cy:cy + h, cx:cx + bloque]

            err = ((trozo - dest) ** 2).sum(2)
            m = np.ones((h, bloque), np.float32)
            idx = np.arange(bloque)[None, :]
            if lado < 0:
                c = costura(err[:, ox:], 0) + ox
                m[idx > c[:, None]] = 0
            else:
                c = costura(err[:, :solape], 0)
                m[idx < c[:, None]] = 0
            if arriba:
                c = costura(err[:solape, :], 1)
                m[np.arange(h)[:, None] < c[None, :]] = 0
            m = cv2.GaussianBlur(m, (0, 0), 1.2)
            out[y:y + h, bx:bx + bloque] = dest * (1 - m[..., None]) + trozo * m[..., None]
            y += h - solape
            primero = False


def borrar_columnas(im):
    """Quita las columnas doradas (y la franja negra del borde derecho) tejiendo
    follaje del mismo lado, y deja un apagado suave hacia los bordes."""
    rng = np.random.default_rng(SEMILLA)
    out = im.copy()
    tejer(im, out, HUECO_IZQ, -1, rng)
    tejer(im, out, HUECO_DER, +1, rng)

    # Apagado continuo hacia los dos bordes (sin escalones), como en el cuadro.
    xs = np.arange(W, dtype=np.float32)
    t = np.clip(np.minimum(xs, W - 1 - xs) / 260.0, 0, 1)
    t = t * t * (3 - 2 * t)
    out *= (0.45 + 0.55 * t)[None, :, None]

    # Hacia el borde la luz media solo puede bajar: cualquier franja mas clara o
    # surco que deje el tejido se lee como un corte. Se corrige solo la luz de
    # baja frecuencia (fila a fila, de dentro hacia fuera); el detalle no se toca.
    lum = cv2.cvtColor(out, cv2.COLOR_BGR2GRAY)
    baja = cv2.GaussianBlur(lum, (0, 0), 28) + 0.01
    gan = np.ones_like(baja)
    for xa, xb, rev in ((0, 620, True), (2280, W, False)):
        tramo = baja[:, xa:xb][:, ::-1] if rev else baja[:, xa:xb]
        mono = np.minimum.accumulate(tramo, axis=1)
        g = mono / tramo
        gan[:, xa:xb] = g[:, ::-1] if rev else g
    gan = cv2.GaussianBlur(gan, (0, 0), 12)
    out *= gan[..., None]
    return out


def remapear(im, mx, my):
    map_x = np.tile(mx.astype(np.float32)[None, :], (H, 1))
    map_y = np.tile(my.astype(np.float32)[:, None], (1, W))
    return cv2.remap(im, map_x, map_y, cv2.INTER_LANCZOS4, borderMode=cv2.BORDER_REFLECT)


def perfil(im, eje, a, b, c0, c1):
    """Brillo medio de las filas (eje 0) o columnas (eje 1) a..b, promediando
    sobre c0..c1 en la otra direccion. Se le quita la luz de gran escala para
    que solo cuenten las molduras: ranuras oscuras y cantos claros."""
    g = cv2.cvtColor(im, cv2.COLOR_BGR2GRAY)
    p = g[a:b, c0:c1].mean(1) if eje == 0 else g[c0:c1, a:b].mean(0)
    p = p - cv2.GaussianBlur(p.reshape(-1, 1), (0, 0), 25).ravel()
    return p / (p.std() + 1e-6)


def dtw(pa, pb, radio=40, castigo=0.4):
    """Alineamiento dinamico de dos perfiles de la misma longitud, con los
    extremos fijos. Devuelve, para cada indice de pa, el indice de pb que le
    corresponde (monotono, suavizado)."""
    n = len(pa)
    inf = np.inf
    D = np.full((n, n), inf)
    for i in range(n):
        lo, hi = max(0, i - radio), min(n, i + radio + 1)
        D[i, lo:hi] = np.abs(pa[i] - pb[lo:hi])
    A = np.full((n, n), inf)
    paso = np.zeros((n, n), np.int8)
    A[0, 0] = D[0, 0]
    for i in range(n):
        lo, hi = max(0, i - radio), min(n, i + radio + 1)
        for j in range(lo, hi):
            if i == 0 and j == 0:
                continue
            best, k = inf, 0
            if i > 0 and j > 0 and A[i - 1, j - 1] < best:
                best, k = A[i - 1, j - 1], 0
            if i > 0 and A[i - 1, j] + castigo < best:
                best, k = A[i - 1, j] + castigo, 1
            if j > 0 and A[i, j - 1] + castigo < best:
                best, k = A[i, j - 1] + castigo, 2
            A[i, j] = D[i, j] + best
            paso[i, j] = k
    i, j = n - 1, n - 1
    pares = [(i, j)]
    while i > 0 or j > 0:
        k = paso[i, j]
        if k == 0:
            i, j = i - 1, j - 1
        elif k == 1:
            i -= 1
        else:
            j -= 1
        pares.append((i, j))
    pares = np.array(pares[::-1], np.float64)
    m = np.zeros(n)
    cuenta = np.zeros(n)
    np.add.at(m, pares[:, 0].astype(int), pares[:, 1])
    np.add.at(cuenta, pares[:, 0].astype(int), 1)
    m /= cuenta
    m = cv2.GaussianBlur(m.reshape(-1, 1), (0, 0), 3).ravel()
    # Sin estirones: cada pixel puede crecer o encoger como mucho un 25 %, que
    # sobre una moldura no se nota pero evita que se emborrone a rayas.
    d = np.clip(np.diff(m), 0.8, 1.25)
    m = np.concatenate([[0.0], np.cumsum(d)])
    return m * (n - 1) / m[-1]


def ajustar(mapa, ref, mov, eje, a, b, c0, c1):
    """Corrige 'mapa' (destino -> origen) en el tramo a..b para que las molduras
    de 'mov' (ya remapeada con mapa) caigan sobre las de 'ref'. El tramo va de
    una zona lisa a otra, asi que los extremos no se mueven y no hay salto."""
    m = dtw(perfil(ref, eje, a, b, c0, c1), perfil(mov, eje, a, b, c0, c1))
    # m dice en que indice de 'mov' esta lo que en 'ref' esta en i; en origen:
    nuevo = mapa.copy()
    nuevo[a:b] = np.interp(a + m, np.arange(len(mapa)), mapa)
    return nuevo


def estirar(im, ref):
    """Estira la imagen de hojas para que su arquitectura caiga encima de la de
    la actual: una curva suave en x para el marco de la derecha, y luego un
    ajuste fino de cada pila de molduras, en x (lados) y en y (arriba, abajo)."""
    mx = PchipInterpolator(*zip(*CURVA_X))(np.arange(W))
    my = np.arange(H, dtype=np.float64)
    # Molduras de arriba y de abajo, medidas por donde no hay hojas encima.
    for (a, b, c0, c1) in ((400, 610, 800, 1600), (1060, 1260, 700, 1700)):
        mov = remapear(im, mx, my)
        my = ajustar(my, ref, mov, 0, a, b, c0, c1)
    # Marco de la derecha (el de la izquierda ya cae a 10 px y no se toca).
    for (a, b, c0, c1) in ((2110, 2330, 620, 1050),):
        mov = remapear(im, mx, my)
        mx = ajustar(mx, ref, mov, 1, a, b, c0, c1)
    return np.clip(remapear(im, mx, my), 0, 1)


def costura(coste, eje):
    """Camino de coste minimo que cruza 'coste' de arriba abajo (eje 0) o de
    izquierda a derecha (eje 1), moviendose como mucho un pixel por paso.
    Devuelve, por cada fila (o columna), el indice dentro de la banda."""
    c = coste if eje == 0 else coste.T
    n, m = c.shape
    acum = c.copy()
    for i in range(1, n):
        prev = acum[i - 1]
        izq = np.concatenate([[np.inf], prev[:-1]])
        der = np.concatenate([prev[1:], [np.inf]])
        acum[i] += np.minimum(np.minimum(izq, prev), der)
    camino = np.empty(n, np.int32)
    camino[-1] = int(np.argmin(acum[-1]))
    for i in range(n - 2, -1, -1):
        j = camino[i + 1]
        lo, hi = max(j - 1, 0), min(j + 2, m)
        camino[i] = lo + int(np.argmin(acum[i, lo:hi]))
    return camino


def mapa_coste(a, b):
    la = cv2.cvtColor(a, cv2.COLOR_BGR2GRAY)
    lb = cv2.cvtColor(b, cv2.COLOR_BGR2GRAY)
    d = np.abs(la - lb) + 0.5 * np.abs(cv2.Laplacian(la, cv2.CV_32F) - cv2.Laplacian(lb, cv2.CV_32F))
    return cv2.GaussianBlur(d, (0, 0), 1.5) + 1e-3


def mascara_cristal(a, b):
    """1 donde manda la imagen actual (el bloque del cristal), 0 fuera."""
    coste = mapa_coste(a, b)
    y_arr, y_aba = BANDA_ARR[0], BANDA_ABA[1]
    x_izq, x_der = BANDA_IZQ[0], BANDA_DER[1]

    izq = costura(coste[y_arr:y_aba, BANDA_IZQ[0]:BANDA_IZQ[1]], 0) + BANDA_IZQ[0]
    der = costura(coste[y_arr:y_aba, BANDA_DER[0]:BANDA_DER[1]], 0) + BANDA_DER[0]
    arr = costura(coste[BANDA_ARR[0]:BANDA_ARR[1], x_izq:x_der], 1) + BANDA_ARR[0]
    aba = costura(coste[BANDA_ABA[0]:BANDA_ABA[1], x_izq:x_der], 1) + BANDA_ABA[0]

    m = np.zeros((H, W), np.float32)
    ys = np.arange(y_arr, y_aba)
    xs = np.arange(x_izq, x_der)
    dentro_x = (xs[None, :] > izq[:, None]) & (xs[None, :] < der[:, None])
    dentro_y = (ys[:, None] > arr[None, :]) & (ys[:, None] < aba[None, :])
    m[y_arr:y_aba, x_izq:x_der] = (dentro_x & dentro_y).astype(np.float32)
    return m, (izq, der, arr, aba)


def fundir_bandas(a, b, m, niveles=6):
    """Fusion multibanda (piramide laplaciana): a donde m=1, b donde m=0."""
    def gauss(im):
        p = [im]
        for _ in range(niveles):
            p.append(cv2.pyrDown(p[-1]))
        return p

    def lap(im):
        g = gauss(im)
        out = []
        for i in range(niveles):
            up = cv2.pyrUp(g[i + 1], dstsize=(g[i].shape[1], g[i].shape[0]))
            out.append(g[i] - up)
        out.append(g[-1])
        return out

    # Un pixel de suavizado en la mascara base: el corte fino no deja escalon.
    gm = gauss(cv2.GaussianBlur(m, (0, 0), 1.0))
    la, lb = lap(a), lap(b)
    mezcla = [la[i] * gm[i][..., None] + lb[i] * (1 - gm[i][..., None]) for i in range(niveles + 1)]
    im = mezcla[-1]
    for i in range(niveles - 1, -1, -1):
        im = cv2.pyrUp(im, dstsize=(mezcla[i].shape[1], mezcla[i].shape[0])) + mezcla[i]
    return np.clip(im, 0, 1)


def mascara_hojas(im, m):
    """Mascara suave (0..1) de donde hay follaje, para que el shader de viento
    mueva solo las hojas. Se queda fuera:
      - la pared y la niebla iluminadas: en esta imagen sepia hoja y pared tienen
        el mismo tono; lo que las separa es lo cargado del color respecto a la
        luz (la pared clara esta lavada, la hoja no).
      - la arquitectura: vigas y molduras son rectas largas y una recta que
        ondula delata el truco; se buscan con Hough y se apartan.
      - el cristal entero, con margen.
    Va suavizada para que el desplazamiento no rasgue la imagen."""
    u8 = (np.clip(im, 0, 1) * 255).astype(np.uint8)
    lab = cv2.cvtColor(u8, cv2.COLOR_BGR2LAB).astype(np.float32)
    L, a, b = lab[..., 0], lab[..., 1] - 128, lab[..., 2] - 128
    ratio = np.sqrt(a * a + b * b) / (L + 8)
    hoja = np.clip((ratio - 0.36) / 0.12, 0, 1)
    hoja = cv2.GaussianBlur(hoja, (0, 0), 3)

    gris = cv2.GaussianBlur(cv2.cvtColor(u8, cv2.COLOR_BGR2GRAY), (0, 0), 1.5)
    bordes = cv2.Canny(gris, 30, 90)
    lineas = cv2.HoughLinesP(bordes, 1, np.pi / 360, 120, minLineLength=170, maxLineGap=6)
    arq = np.zeros((H, W), np.uint8)
    if lineas is not None:
        for x1, y1, x2, y2 in lineas.reshape(-1, 4):
            cv2.line(arq, (int(x1), int(y1)), (int(x2), int(y2)), 255, 16)
    arq = cv2.GaussianBlur(arq.astype(np.float32) / 255, (0, 0), 6)
    arq = np.clip(arq * 1.6, 0, 1)

    cristal = cv2.dilate((m > 0.5).astype(np.uint8), np.ones((61, 61), np.uint8)).astype(np.float32)
    cristal = cv2.GaussianBlur(cristal, (0, 0), 12)

    # Las dos vigas largas de arriba y abajo del marco cruzan todo el ancho y las
    # hojas las tapan a tramos, asi que Hough no las coge enteras: se apartan
    # por su sitio, que es fijo (mismas alturas que las molduras del cristal).
    yy = np.arange(H, dtype=np.float32)[:, None]
    vigas = np.zeros((H, 1), np.float32)
    for ya, yb in VIGAS_Y:
        vigas = np.maximum(vigas, np.clip((yy - ya) / 24, 0, 1) * np.clip((yb - yy) / 24, 0, 1))

    mask = hoja * (1 - arq) * (1 - cristal) * (1 - vigas)
    return cv2.GaussianBlur(mask, (0, 0), 5)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--salida", default=os.path.join(PROYECTO, "assets", "intro", "title_background_hojas.png"))
    ap.add_argument("--debug", default=None, help="carpeta donde dejar mascara y costuras")
    args = ap.parse_args()

    actual = leer("fuente_actual.png")
    hojas = estirar(borrar_columnas(leer("fuente_hojas.png")), actual)

    m, (izq, der, arr, aba) = mascara_cristal(actual, hojas)
    out = fundir_bandas(actual, hojas, m)

    # Dentro del cristal no se toca nada: las medidas de la escena son de ahi.
    # La fusion por bandas reparte el tono unos cuantos px hacia dentro; se vuelve
    # a la actual con una rampa de 40 px desde la costura, sin escalon.
    dentro = cv2.distanceTransform((m > 0.5).astype(np.uint8), cv2.DIST_L2, 5)
    w = np.clip((dentro - 4.0) / 40.0, 0, 1)
    w = w * w * (3 - 2 * w)
    out = out * (1 - w[..., None]) + actual * w[..., None]

    # Con la sala encendida las hojas mas claras (las doradas de las esquinas)
    # tiraban de la vista mas que el titulo. Se bajan solo las luces de fuera
    # del cristal; las sombras y el cristal quedan igual.
    lum = cv2.cvtColor(out.astype(np.float32), cv2.COLOR_BGR2GRAY)
    luces = np.clip((lum - 0.30) / 0.45, 0, 1)
    luces = luces * luces * (3 - 2 * luces)
    fuera = cv2.distanceTransform((m < 0.5).astype(np.uint8), cv2.DIST_L2, 5)
    fuera = np.clip(fuera / 40.0, 0, 1)
    out = out * (1 - TEMPLAR_LUCES * luces * fuera)[..., None]

    cv2.imwrite(args.salida, np.round(out * 255).astype(np.uint8))
    print("escrito", args.salida)

    # Mascara del viento, a media resolucion (es suave, no necesita mas).
    mask = mascara_hojas(out, m)
    ruta_m = os.path.join(os.path.dirname(args.salida), "title_hojas_mascara.png")
    cv2.imwrite(ruta_m, np.round(cv2.resize(mask, (W // 2, H // 2), interpolation=cv2.INTER_AREA) * 255).astype(np.uint8))
    print("escrito", ruta_m)

    if args.debug:
        os.makedirs(args.debug, exist_ok=True)
        vis = (out * 255).astype(np.uint8).copy()
        cnt, _ = cv2.findContours((m > 0.5).astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
        cv2.drawContours(vis, cnt, -1, (0, 255, 255), 2)
        cv2.imwrite(os.path.join(args.debug, "costura.png"), vis)
        cv2.imwrite(os.path.join(args.debug, "hojas_estirada.png"), (hojas * 255).astype(np.uint8))


if __name__ == "__main__":
    main()

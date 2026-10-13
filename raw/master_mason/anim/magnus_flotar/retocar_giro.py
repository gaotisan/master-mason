"""Retoque de la tunica del giro en el aire (-> 04_retocados).

Por que (2026-10-12). El video del giro en el aire (flotar_girar_*.mp4) se
invento un cinturon sobre la tunica, con un triangulo gris encima y otro
debajo, y la tunica cerrada. Al usuario: "aparece con una especie de cinturon
que esta sobre la tunica... si lo comparamos con el giro normal andando con el
baston guardado no casa; retocalo a mano y deja la tunica mas coherente con el
otro giro". El dibujo de frente del peregrino (giro de pie, andar de frente) es
un abrigo abierto, sin cinturon, con el peto gris hexagonal en el pecho y la
tunica oscura asomando entre los faldones.

Que hace. Del 22 al 38 del video del giro (de tres cuartos al frente: el 38 es
el frente de verdad, ver montar_flotar.py) la tela de delante se pinta con la
del giro de pie (magnus_giro_simetrico/04_giro) en el mismo punto del giro. El
punto del giro es donde cae la linea del centro de delante (el centro del peto
en el de pie, el del triangulo gris en el del aire), medida en cada fotograma y
pasada a seno del giro con el radio del tronco de cada uno (61 y 72 px): asi se
emparejan, y el de pie se coloca con su linea sobre la del aire (escala 72/61).
Del 22 al 25 entra poco a poco: el brazo tapa la cintura y solo se ve el pecho.

Se quedan las del aire: la silueta (los faldones al vuelo), la capucha, la
barba, y lo que va delante del pecho (a mano, por fotogramas clave): el
antebrazo y el puno de cerca (MANO_CERCA: el borde derecho del puno), con el
puno de la manga que le cuelga, y la manga de lejos (MANGA_LEJOS: su borde de
dentro). Por debajo de las mangas, los faldones: el de pie estirado por filas a
lo ancho de la silueta, con la abertura de la tunica en la linea del centro.
Las manos del de pie (colgando a los lados) no se copian.

  python retocar_giro.py            -> 04_retocados/c_159.png ... (f8-f38)
"""
import os

import numpy as np
from PIL import Image
from scipy import ndimage

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
LIMPIOS = os.path.join(AQUI, '04_limpios')
RETOCADOS = os.path.join(AQUI, '04_retocados')
SUELO = os.path.join(ANIM, 'magnus_giro_simetrico', '04_giro')

PRIMERO, ULTIMO = 8, 38          # fotogramas del video que van al giro
EJE = 292.0                      # eje del cuerpo en las dos casillas (x -> 584 - x)
R_AIRE, R_SUELO = 61.0, 72.0     # medio ancho del tronco de frente (entre las mangas)

# Linea del centro de delante (x en la casilla). Del aire, el triangulo gris
# de arriba (f27-f38; antes, la mano lo tapa: seguida a ojo); del de pie, el
# peto. Medidas con la media de lo gris en sus filas.
FRENTE_AIRE = {22: 334.0, 23: 333.0, 24: 332.0, 25: 330.5, 26: 329.0, 27: 327.0,
               28: 324.8, 29: 322.0, 30: 319.3, 31: 316.7, 32: 313.5, 33: 310.1,
               34: 306.4, 35: 302.7, 36: 299.2, 37: 295.2, 38: 291.1}
FRENTE_SUELO = {10: 341.5, 11: 341.1, 12: 339.7, 13: 337.1, 14: 333.9, 15: 330.2,
                16: 326.8, 17: 323.1, 18: 318.8, 19: 314.6, 20: 309.6, 21: 304.4,
                22: 298.7, 23: 292.9, 24: 286.6}
# A mano, en las rejillas: borde derecho del puno de cerca (lo que hay a su
# izquierda, en las filas del antebrazo y del puno de la manga, es brazo) y
# borde de dentro de la manga de lejos.
MANO_CERCA = {22: 335, 24: 330, 26: 320, 27: 310, 28: 300, 29: 290, 30: 285, 31: 275,
              32: 268, 33: 258, 36: 228, 38: 212}
MANGA_LEJOS = {22: 335, 24: 338, 26: 345, 28: 350, 38: 350}
BRAZO_FILAS = (278, 352)         # antebrazo, puno y puno de la manga (filas, de frente)
HOMBRO_X = 234                   # borde de dentro de la manga de cerca, por arriba
ENTRADA = {22: 0.2, 23: 0.4, 24: 0.6, 25: 0.8}   # peso del retoque al entrar

# Alturas que casan (y en la casilla, en el de frente; en los demas se corren
# con lo que se corre la capucha): punta de la barba, cintura (el cinturon del
# aire / el pico de abajo del peto del de pie) y bajo de la tunica (medido).
CINTURA_AIRE, CINTURA_SUELO = 298.0, 352.0
TOP_AIRE, TOP_SUELO = 40.0, 57.0


def clave(tabla, f):
    ks = sorted(tabla)
    return float(np.interp(f, ks, [tabla[k] for k in ks]))


def pareja(f):
    """La casilla del de pie en el mismo punto del giro."""
    s = (clave(FRENTE_AIRE, f) - EJE) / R_AIRE
    mejor = min(FRENTE_SUELO, key=lambda c: abs((FRENTE_SUELO[c] - EJE) / R_SUELO - s))
    return mejor


def bajo_tunica(al, top):
    ancho = al.sum(1)
    filas = np.nonzero(ancho > 70)[0]
    filas = filas[filas > top + 200]
    return int(filas.max())


def punta_barba(a, al):
    r, g, b = [a[..., i].astype(float) for i in range(3)]
    blanco = al & (r > 160) & (g > 160) & (b > 155) & (np.abs(r - b) < 50)
    blanco = ndimage.binary_opening(blanco, iterations=1)
    # la barba es la mancha blanca mas grande (algun brillo suelto mas abajo
    # pasaba por blanco y bajaba la punta 60 px)
    etiquetas, n = ndimage.label(blanco)
    if n > 1:
        tam = ndimage.sum(blanco, etiquetas, range(1, n + 1))
        blanco = etiquetas == (1 + int(np.argmax(tam)))
    ys = np.nonzero(blanco.any(1))[0]
    return blanco, int(ys.max())


def barba_llena(blanco):
    lleno = np.zeros_like(blanco)
    for y in np.nonzero(blanco.any(1))[0]:
        xs = np.nonzero(blanco[y])[0]
        lleno[y, xs.min():xs.max() + 1] = True
    return ndimage.binary_dilation(lleno, iterations=3)


def bordes(al, y0, y1):
    """Bordes de la silueta por filas, suavizados."""
    n = al.shape[0]
    x0 = np.full(n, np.nan)
    x1 = np.full(n, np.nan)
    for y in range(y0, y1 + 1):
        xs = np.nonzero(al[y])[0]
        if len(xs) >= 4:
            x0[y], x1[y] = xs.min(), xs.max()
    ys = np.arange(n)
    ok = ~np.isnan(x0)
    x0 = np.interp(ys, ys[ok], x0[ok])
    x1 = np.interp(ys, ys[ok], x1[ok])
    return (ndimage.gaussian_filter1d(ndimage.median_filter(x0, 21), 5),
            ndimage.gaussian_filter1d(ndimage.median_filter(x1, 21), 5))


def suave(x, a, b):
    return np.clip((x - a) / max(b - a, 1e-6), 0.0, 1.0)


def retocar(f):
    c = pareja(f)
    a = np.asarray(Image.open(os.path.join(LIMPIOS, 'c_%03d.png' % (151 + f))).convert('RGBA')).astype(float)
    s = np.asarray(Image.open(os.path.join(SUELO, 'c_%02d.png' % c)).convert('RGBA')).astype(float)
    al_a = a[..., 3] > 128
    al_s = s[..., 3] > 128
    top_a = np.nonzero(al_a.any(1))[0].min()
    top_s = np.nonzero(al_s.any(1))[0].min()
    bajo_a = bajo_tunica(al_a, top_a)
    bajo_s = bajo_tunica(al_s, top_s)
    blanco_a, punta_a = punta_barba(a, al_a)
    _, punta_s = punta_barba(s, al_s)
    da, ds = top_a - TOP_AIRE, top_s - TOP_SUELO
    # filas: hombros, punta de la barba, cintura, bajo
    hombro_a = top_a + 0.216 * (bajo_a - top_a)
    hombro_s = top_s + 0.217 * (bajo_s - top_s)
    marcas_a = [hombro_a, punta_a, CINTURA_AIRE + da, bajo_a]
    marcas_s = [hombro_s, punta_s, CINTURA_SUELO + ds, bajo_s]
    ax0, ax1 = bordes(al_a, top_a, bajo_a)
    sx0, sx1 = bordes(al_s, top_s, bajo_s)
    fa = clave(FRENTE_AIRE, f)
    fs = FRENTE_SUELO[c]
    k_pecho = R_SUELO / R_AIRE
    mano = clave(MANO_CERCA, f)
    manga = clave(MANGA_LEJOS, f)
    b0, b1 = BRAZO_FILAS[0] + da, BRAZO_FILAS[1] + da
    nuevo = a.copy()
    w = np.zeros(al_a.shape, float)
    y_ini = int(hombro_a)
    for y in range(y_ini, bajo_a + 1):
        ys = int(round(np.interp(y, marcas_a, marcas_s)))
        if ys < 0 or ys >= s.shape[0]:
            continue
        x = np.arange(int(ax0[y]), int(ax1[y]) + 1)
        # escala: la del tronco en el pecho; en los faldones, la de las siluetas
        k_falda = (sx1[ys] - sx0[ys]) / max(ax1[y] - ax0[y], 1.0)
        t_falda = suave(y, b1 - 4, b1 + 36)
        k = k_pecho + (k_falda - k_pecho) * t_falda
        # en los faldones la linea del centro va con el centro de la silueta
        # al bajar (los faldones no giran tanto como el pecho)
        xs_src = fs + (x - fa) * k
        xi = np.clip(np.floor(xs_src).astype(int), 0, s.shape[1] - 2)
        tt = (xs_src - xi)[:, None]
        nuevo[y, x, :3] = s[ys, xi, :3] * (1 - tt) + s[ys, xi + 1, :3] * tt
        valido = al_s[ys, xi] & al_s[ys, xi + 1]
        # manos del de pie (y el hueco entre brazo y abrigo): lo de los lados
        # en las filas en que cuelgan los brazos (de frente, manos en x
        # 176-204 y 392-420, filas 424-468)
        if 380 + ds <= ys <= 500 + ds:
            valido &= (xs_src > sx0[ys] + 50) & (xs_src < sx1[ys] - 50)
        # que se repinta: en el pecho, entre las mangas; en el antebrazo, a la
        # derecha del puno; por debajo, todo
        if y < b0:
            izq, der = HOMBRO_X + 0.0, manga
        elif y <= b1:
            izq, der = max(mano + 2.0, HOMBRO_X), manga
        else:
            izq, der = -1e9, 1e9
        banda = suave(x, izq, izq + 5) * (1.0 - suave(x, der - 5, der))
        banda *= suave(y, y_ini, y_ini + 14)
        w[y, x] = banda * valido
    w *= ~barba_llena(blanco_a)
    w = ndimage.gaussian_filter(w, 1.0) * al_a * ENTRADA.get(f, 1.0)
    out = a.copy()
    out[..., :3] = a[..., :3] * (1 - w[..., None]) + nuevo[..., :3] * w[..., None]
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)), c


def main():
    os.makedirs(RETOCADOS, exist_ok=True)
    for f in range(PRIMERO, ULTIMO + 1):
        if f in FRENTE_AIRE:
            im, c = retocar(f)
            print('f%d <- c_%02d' % (f, c))
        else:
            im = Image.open(os.path.join(LIMPIOS, 'c_%03d.png' % (151 + f))).convert('RGBA')
        im.save(os.path.join(RETOCADOS, 'c_%03d.png' % (151 + f)))


if __name__ == '__main__':
    main()

"""Giro con el baculo EN LA MANO, por delante y cambiando de mano (la animacion
"giro" de mano.json, la que pone baston.gd con el baculo sacado).

2026-10-10: video nuevo Pilgrim_turning_with_staff_20261010115731 (job
magnus_giro_baston_mano), pedido con _fuentes/prompt_baston_giro_mano.txt en Flow:
fotograma inicial = el reposo con el baculo en la mano (baston_ref_en_mano_1080)
y final = el mismo espejado (baston_ref_en_mano_izquierda_1080), con el baculo
en la otra mano. El de antes (Master_builder_walking_animation..._20261008163432,
job magnus_andar_giro_baston; ver el commit 35d3fe6) llegaba al cambio de mano
pero no a la pose final, y lo que faltaba se completaba espejando el principio
del giro y fundiendolo: en la union se veia borroso ("hace blur"). Este llega
solo, asi que se usa entero y en orden, a su ritmo (24 fps), con las piezas del
giro de pie sin baculo (magnus_giro_simetrico/giro_video.py):
  - tramo f046 -> f114 del video (antes, quieto; despues, ya asentado);
  - tono: el del reposo con el baculo (el que se ve antes y despues del giro);
  - colocacion: encaje con el reposo al empezar y con su espejo al acabar, con
    rampa suave entre medias;
  - extremos al reposo con el baculo y a su espejo (forma moviendo pixeles y un
    fundido corto con el hombre casi quieto): sin salto al entrar ni al salir;
  - sombra de la capucha en la cara de frente (la cara salia iluminada), sin
    tocar la garra si pasa por delante;
  - restos del croma.
La bola va donde la garra. Al empezar y al acabar, por patron (mano.garra_patron)
sobre los fotogramas ya llevados al reposo: desde el reposo hacia delante (0-13)
y, espejados, desde el reposo espejado hacia atras (40-68). En medio (14-39) la
garra pasa de canto por delante de la cara y cambia de mano, y ahi el patron se
pierde (las dos pasadas acababan a 200 px una de otra): MARCAS, puestas a mano
fotograma a fotograma (el eje del manojo de dedos cuando se ve de canto) y
comprobadas con una bola simulada detras del sprite. Todo, suavizado [1,2,1] dos
veces; en los extremos, la bola del reposo y su espejo.
La bola va DETRAS del sprite (baston.gd: los dedos de la garra le quedan
delante). Donde la garra cruza la cara de canto (20-24) la cara la taparia
entera: se abre en el sprite un hueco algo menor que la bola (R_HUECO) quitando
lo que no es el manojo de dedos (BANDAS, sus bordes a mano), y la bola se ve a
los dos lados del manojo, como si lo llevara dentro.
  python giro_mano.py   -> mano_giro.png y la entrada "giro" de mano.json"""
import json
import os
import sys
import numpy as np
from PIL import Image
from celdas import PROY
import mano

ANIM = PROY / "raw/master_mason/anim"
sys.path.insert(0, str(ANIM / "magnus_giro_simetrico"))
import giro_video as GV                  # sombra de la cara, campo_hacia (y E = espejo.py)
E = GV.E
_cabeza_video = GV.cabeza

JOB = "magnus_giro_baston_mano"
ORIGEN = ANIM / JOB / "04_limpios"       # c_01 = f001 (reposo), c_02..c_84 = f040..f122, c_85 = f192
REF_INI, REF_FIN = 1, 85
c_de = lambda f: f - 38
DESDE, HASTA = 46, 114
FPS = 24.0
N_INI, N_FIN, N_FUNDIDO = 10, 8, 5
# la bola (centro de la garra, px master) donde el patron no sirve; antes de
# PATRON_HASTA y despues de PATRON_DESDE, por patron
PATRON_HASTA, PATRON_DESDE = 13, 40
MARCAS = {14: (404, 100), 15: (393, 102), 16: (378, 100), 17: (366, 100), 18: (352, 97),
          19: (334, 97), 20: (309, 97), 21: (288, 97), 22: (271, 100), 23: (252, 100),
          24: (238, 100), 25: (228, 102), 26: (216, 105), 27: (206, 105), 28: (197, 105),
          29: (186, 105), 30: (176, 102), 31: (177, 99), 32: (175, 100), 33: (167, 99),
          34: (162, 98), 35: (153, 98), 36: (149, 96), 37: (145, 97), 38: (141, 99), 39: (141, 100)}
# el manojo de dedos de canto delante de la cara: (fila, x izquierda, x derecha)
# de sus bordes, de la punta hacia abajo (por debajo sigue como en la ultima)
BANDAS = {20: [(76, 305, 306), (80, 302, 309), (90, 301, 313), (100, 299, 317), (117, 296, 320)],
          21: [(75, 285, 286), (80, 282, 290), (90, 280, 294), (100, 279, 297), (117, 277, 300)],
          22: [(77, 268, 269), (82, 265, 272), (90, 263, 277), (100, 261, 280), (120, 259, 283)],
          23: [(78, 249, 250), (90, 246, 255), (97, 243, 260), (100, 241, 262), (110, 241, 264), (120, 240, 264)],
          24: [(80, 236, 237), (90, 230, 243), (100, 227, 248), (105, 226, 252), (110, 226, 255), (120, 226, 258)]}
# la bola: radio 0,34 de un cuadro de 44 px a escala 1,5 = 11,2 px de la hoja = 22,4
# master; el hueco, algo menos (borde suave de 2,5 px), para que nunca se vea el fondo
R_HUECO = 19.5
R_GARRA = 30                             # px (master) alrededor de la bola que la sombra de la cara no toca
# fotogramas en que la garra o el baston tapan la cabeza o la barba: ahi lo de
# frente que mira (por la barba) no vale y se interpola
CABEZA_TAPADA = range(16, 23)


def leer(c):
    return np.array(Image.open(ORIGEN / f"c_{c:02d}.png").convert("RGBA"))


def reposo_mano():
    """El primer fotograma del reposo con el baculo, en su sitio (como lo pone
    mano.py en mano_reposo.png, a tamano master), y su bola (px master)."""
    from scipy.ndimage import shift
    def P(k, job=None, off=0):
        a = np.asarray(Image.fromarray(mano.cargar(k, job)).reduce(2)).astype(np.float32)[..., 3] / 255
        return np.roll(a, off, 1)
    offr = min(range(-30, 31), key=lambda o: float(np.abs(P(mano.REPOSO_BUCLE[0], mano.REPOSO_JOB, o) - P(mano.REPOSO[0])).mean()))
    dx = mano.PIES_X - mano.pies_izq(mano.cargar(mano.REPOSO[0])) + 2 * offr
    r = mano.desplazar(mano.cargar(mano.REPOSO_BUCLE[0], mano.REPOSO_JOB), dx)
    o = json.loads((mano.DESTINO / "mano.json").read_text())["reposo"]["orbe"][0]
    return r, ((o[0] + 146) * 2, (o[1] + 180) * 2)


def capucha(a):
    """(fila de la punta de la capucha, columna del centro de la cabeza, lo de
    frente que mira, px de la capucha). Como giro_video.cabeza, pero por la
    capucha gris (con el baculo en la mano la garra puede quedar mas alta que la
    cabeza o a su lado): la mancha gris grande mas alta (de frente, el peto gris
    del pecho es mayor que la capucha). Si la garra la parte, sale menor."""
    from scipy import ndimage
    op = a[..., 3] > 200
    x = a[..., :3].astype(int)
    sat = x.max(-1) - x.min(-1)
    m = x.mean(-1)
    gris = op & (sat < 35) & (x[..., 2] >= x[..., 0] - 10) & (m > 85) & (m < 215)
    gris[300:] = False
    lab, n = ndimage.label(gris)
    tam = ndimage.sum(gris, lab, range(1, n + 1)) if n else []
    grandes = [k + 1 for k in range(n) if tam[k] >= 400]
    if not grandes:
        return _cabeza_video(a) + (0,)
    k = min(grandes, key=lambda k: int(np.where(lab == k)[0].min()))
    cap = lab == k
    ys, xs = np.where(cap)
    top = int(ys.min())
    centro = float(np.median(xs[ys < top + 60]))
    blanco = (x.min(-1) > 175) & op
    blanco[:top + 60] = False; blanco[top + 160:] = False
    blanco[:, :int(centro) - 60] = False; blanco[:, int(centro) + 60:] = False
    bx = np.where(blanco)[1]
    frente = 0.0 if len(bx) < 30 else float(np.clip(1 - abs(bx.mean() - centro) / 25, 0, 1))
    return top, int(round(centro)), frente, int(tam[k - 1])


def cabeza_baston(a):
    return capucha(a)[:3]


def zona_baston(ref, garra_ref):
    """Donde estan el baculo y la garra en ref (0-1, borde suave): columna de su
    centro fila a fila (el tramo opaco mas a la derecha) con la mano, y la garra.
    Ahi no se funde: en el video del giro, aun quieto el hombre, el baculo ya se
    mueve (la garra avanza 6-16 px en los primeros fotogramas) y fundirlo con el
    del reposo, que no se mueve, dejaba dos baculos."""
    import cv2
    h, w = ref.shape[:2]
    m = np.zeros((h, w), np.float32)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    y_garra = int(garra_ref[1]) + 40
    m[(np.hypot(xx - garra_ref[0], yy - garra_ref[1]) < 50) & (xx > garra_ref[0] - 40) & (yy < y_garra + 10)] = 1
    for y in range(y_garra, h):
        xs = np.where(ref[y, 380:, 3] > 128)[0] + 380
        if len(xs):
            tramo = np.split(xs, np.where(np.diff(xs) > 1)[0] + 1)[-1]
            m[y, max(int(tramo[0]) - 14, 0):int(tramo[-1]) + 15] = 1
    return cv2.GaussianBlur(m, (0, 0), 4)


def banda(nudos, h, w):
    """Cuanto de cada pixel es manojo de dedos (0-1, bordes de 1 px) segun sus
    bordes a mano: interpolados entre filas; por debajo, como en la ultima."""
    ys = [v[0] for v in nudos]
    m = np.zeros((h, w), np.float32)
    xs = np.arange(w, dtype=np.float32)
    for y in range(ys[0], h):
        L = np.interp(y, ys, [v[1] for v in nudos])
        R = np.interp(y, ys, [v[2] for v in nudos])
        m[y] = np.clip(np.minimum(xs + 0.5 - L, R + 0.5 - xs) + 0.5, 0, 1)
    return m


if __name__ == "__main__":
    rep, orbe_rep = reposo_mano()
    W = rep.shape[1]
    rep_e = E.espejo(rep)
    orbe_rep_e = (W - 1 - orbe_rep[0], orbe_rep[1])
    ini, fin = leer(REF_INI), leer(REF_FIN)
    dx0, dy0 = E.encaje(ini, rep)
    dx1, dy1 = E.encaje(fin, rep_e)
    print("encaje: al empezar dx %d dy %d; al acabar (espejado) dx %d dy %d" % (dx0, dy0, dx1, dy1))
    fs = list(range(DESDE, HASTA + 1))
    n = len(fs)

    def colocacion(i):
        t = E.suave(i / (n - 1))
        return dx0 + (dx1 - dx0) * t, dy0 + (dy1 - dy0) * t

    # tono: el del reposo con el baculo (lo que se ve antes y despues)
    objetivo = GV.tono.media([rep.astype(float) / 255])
    muestra = [E.mover(ini, dx0, dy0).astype(float) / 255]
    g = np.ones(3)
    for _ in range(5):
        g = g * objetivo / GV.tono.media([GV.tono.aplicar(im, g) for im in muestra])
    print("ganancia de tono (%.3f, %.3f, %.3f)" % tuple(g))

    def preparar(a, dx, dy):
        im = E.mover(a, dx, round(dy)).astype(float) / 255
        return E.quitar_verde((GV.tono.aplicar(im, g) * 255).round().astype(np.uint8))

    X = [preparar(leer(c_de(f)), *colocacion(i)) for i, f in enumerate(fs)]

    # los extremos, al reposo y a su espejo: forma por flujo (se apaga viajando
    # con el movimiento) y un fundido corto
    import cv2
    h, w = X[0].shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    Y = list(X)
    for (rango, ref, nn) in ((range(0, N_INI + 1), rep, N_INI), (range(n - 1, n - 2 - N_FIN, -1), rep_e, N_FIN)):
        rango = list(rango)
        d = GV.campo_hacia(X[rango[0]], ref)
        P = np.dstack([xx, yy])
        for j, i in enumerate(rango):
            if j > 0:
                f = E.flujo(X[i], X[rango[j - 1]])
                P = cv2.remap(P, xx + f[..., 0], yy + f[..., 1], cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
            wgt = 1 - E.suave(j / nn)
            if wgt > 0:
                Y[i] = E.deformar(Y[i], E.llevar(d, P, 0.0) * wgt)
    # al empezar, el baculo y la mano no se funden (ver zona_baston): en el 0 es
    # el reposo entero, y del 1 en adelante, el del video ya llevado al reposo
    # (al acabar el baculo ya esta quieto y coincide con el del reposo espejado)
    fuera = 1 - zona_baston(rep, orbe_rep)[..., None]
    for i in range(N_FUNDIDO):
        t = E.suave(1 - i / N_FUNDIDO)
        Y[i] = E.fundir(Y[i], rep, t if i == 0 else t * fuera)
        Y[n - 1 - i] = E.fundir(Y[n - 1 - i], rep_e, t)

    # la bola: por patron sobre los fotogramas ya llevados al reposo (la garra se
    # mueve con ellos), desde el reposo hacia delante y, espejados, desde el
    # reposo espejado hacia atras (la garra queda como en el reposo); en medio,
    # las MARCAS. Suavizado [1,2,1] dos veces, con los extremos en la bola del
    # reposo y en su espejo (el primero y el ultimo SON el reposo y su espejo)
    ida = mano.garra_patron([rep] + Y[:PATRON_HASTA + 1], rep)[1:]
    vuelta = mano.garra_patron([rep] + [E.espejo(a) for a in Y[:PATRON_DESDE - 1:-1]], rep)[1:][::-1]
    bruto = list(ida) + [MARCAS[i] for i in range(PATRON_HASTA + 1, PATRON_DESDE)] + [(W - 1 - x, y) for x, y in vuelta]
    gx = np.array([p[0] for p in bruto], float)
    gy = np.array([p[1] for p in bruto], float)
    (gx[0], gy[0]), (gx[-1], gy[-1]) = orbe_rep, orbe_rep_e
    for _ in range(2):
        gx[1:-1] = (gx[:-2] + 2 * gx[1:-1] + gx[2:]) / 4
        gy[1:-1] = (gy[:-2] + 2 * gy[1:-1] + gy[2:]) / 4
    garras = list(zip(gx, gy))
    print("bola: lo que mueve el suavizado (px master): " + " ".join(
        "%.0f" % np.hypot(gx[i] - bruto[i][0], gy[i] - bruto[i][1]) for i in range(n)))

    # sombra de la capucha en la cara, segun lo de frente que mira; sin tocar la
    # garra. Donde la garra o el baston tapan la cabeza o la barba
    # (CABEZA_TAPADA) o la garra parte la capucha (sale mucho menor), la cabeza
    # (punta, centro, lo de frente) se interpola de los vecinos: si no, la
    # sombra parpadea
    cab = np.array([capucha(a) for a in Y], float)
    fiable = np.array([i not in CABEZA_TAPADA and cab[i, 3] >= 0.6 * np.median(cab[:, 3]) for i in range(n)])
    idx = np.arange(n)
    for k in range(3):
        cab[~fiable, k] = np.interp(idx[~fiable], idx[fiable], cab[fiable, k])
    frente = np.convolve(np.pad(cab[:, 2], 2, mode="edge"), np.ones(5) / 5, mode="valid")
    fuerza = GV.SOMBRA * np.array([E.suave((f - 0.15) / 0.55) for f in frente])
    print("cabeza interpolada en: " + " ".join(str(i) for i in idx[~fiable]))
    print("sombra de la cara: " + " ".join("%.2f" % f for f in fuerza))
    bandas = {i: banda(BANDAS[i], h, w) for i in BANDAS}
    for i in range(n):
        if fuerza[i] <= 0:
            continue
        GV.cabeza = lambda a, c=(int(round(cab[i, 0])), int(round(cab[i, 1])), float(cab[i, 2])): c
        s = GV.sombra_cara(Y[i], fuerza[i])
        if i in bandas:
            libre = bandas[i] < 0.5
        else:
            libre = np.hypot(xx - garras[i][0], yy - garras[i][1]) > R_GARRA
        Y[i] = np.where(libre[..., None], s, Y[i])
    GV.cabeza = _cabeza_video

    # el hueco para la bola donde la garra cruza la cara de canto: en el disco
    # (algo menor que la bola), lo que no es el manojo de dedos
    for i, b in bandas.items():
        d = np.hypot(xx - garras[i][0], yy - garras[i][1])
        corte = np.clip((R_HUECO - d) / 2.5, 0, 1) * (1 - b)
        Y[i] = Y[i].copy()
        Y[i][..., 3] = np.round(Y[i][..., 3] * (1 - corte)).astype(np.uint8)

    # la hoja, la bola y las duraciones (como en mano.py)
    filas = (n + mano.COLS - 1) // mano.COLS
    hoja = Image.new("RGBA", (292 * mano.COLS, 360 * filas), (0, 0, 0, 0))
    orbe = []
    for i, (c, gg) in enumerate(zip(Y, garras)):
        hoja.paste(Image.fromarray(c).resize((292, 360), Image.LANCZOS), ((i % mano.COLS) * 292, (i // mano.COLS) * 360))
        orbe.append([round(float(gg[0]) / 2 - 146, 2), round(float(gg[1]) / 2 - 180, 2)])
    hoja.save(mano.DESTINO / "mano_giro.png")
    info = json.loads((mano.DESTINO / "mano.json").read_text())
    info["giro"] = {"hoja": "res://assets/characters/baston/mano_giro.png", "n": n, "cols": mano.COLS,
                    "fps": FPS, "bucle": False, "orbe": orbe, "duraciones": [1.0] * n}
    (mano.DESTINO / "mano.json").write_text(json.dumps(info, separators=(",", ":")), encoding="utf-8")
    np.save(ANIM / JOB / "garras.npy", np.array(garras))
    os.makedirs(ANIM / JOB / "04_giro", exist_ok=True)
    for f in (ANIM / JOB / "04_giro").glob("c_*.png"):
        f.unlink()
    for i, c in enumerate(Y):
        Image.fromarray(c).save(ANIM / JOB / "04_giro" / f"c_{i + 1:02d}.png")
    print("giro con el baculo en la mano: %d fotogramas (f%03d-f%03d), %.2f s a %g fps -> %s"
          % (n, DESDE, HASTA, n / FPS, FPS, mano.DESTINO / "mano_giro.png"))
    print("bola al empezar %s (reposo %s), al acabar %s (espejo %s)" % (
        orbe[0], [round(orbe_rep[0] / 2 - 146, 2), round(orbe_rep[1] / 2 - 180, 2)], orbe[-1],
        [round(orbe_rep_e[0] / 2 - 146, 2), round(orbe_rep_e[1] / 2 - 180, 2)]))

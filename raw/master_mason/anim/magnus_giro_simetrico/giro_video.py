"""Giro de pie por delante (animacion "giro"), del video entero a su ritmo (-> 04_giro).

Por que (2026-10-10). El giro anterior (magnus_giro_frente/espejo.py) salia de un
video de exhibicion lento (360 grados con paradas) que en el juego iba 2,5 veces
mas rapido: los pasos se veian "a trompicones". Y como la tunica tenia otro
dibujo y otra luz a cada lado, habia que usar solo la primera mitad, espejarla y
retocar mucho el frente (sastre, barba, brazos) para que casara con su espejo.
El usuario pidio un video nuevo, a la velocidad del juego y con la tunica igual a
los dos lados, "para no tener que hacer apanos": Pilgrim_turning_on_green_screen_
20261010091716.mp4 (prompt_giro_frente_simetrico.txt; Flow con fotograma inicial
el reposo y final el reposo espejado). De frente sale simetrico y acaba en el
reposo espejado, asi que aqui se usa TAL CUAL: todos los fotogramas del giro, en
orden, sin espejar ni retocar el dibujo. Solo:

  - Tramo: f050 -> f110 del video, a 24 fps como el video (2,5 s, como el giro
    agachado, que tambien va a su ritmo): de f050 empieza a volver la cabeza;
    de f058 a f088 los dos pasos; de ahi a f110 planta el pie y la capa se
    asienta (antes de f050 y despues de f110, quieto).
  - Tono estandar de la tunica (igualar_tono.py), medido en f001 (el reposo).
  - Colocacion: dx/dy del encaje con el reposo del juego al empezar y con el
    reposo espejado al acabar, con rampa suave entre medias.
  - Restos del croma: quitar_verde() de espejo.py.
  - Los dos extremos, al reposo del JUEGO (al empezar) y a su espejo (al acabar),
    que es lo que hay antes y despues del giro: mientras esta quieto el video se
    va desplazando (f050 ya esta a 3 pasos de su f001) y al final aun se asienta.
    Primero la forma, MOVIENDO PIXELES (flujo optico hasta el reposo; la
    correccion se apaga en N_INI fotogramas, o se enciende en N_FIN, viajando
    con el movimiento del video); y lo que queda (el dibujo del otro video, la
    respiracion) con un fundido de N_FUNDIDO fotogramas, con el hombre casi
    quieto: como en el giro anterior, cuyo arranque gustaba.

    python giro_video.py   (luego hoja.ps1 -Job magnus_giro_simetrico -Desde 04_giro -Fps 24 -Escala 2 -Cols 10)"""
import os, shutil, sys
import cv2
import numpy as np
from PIL import Image
from scipy import ndimage

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(AQUI), 'magnus_giro_frente'))
import espejo as E                      # las piezas comunes (mover, encaje, flujo, ...)
tono = E.tono

ORIGEN = os.path.join(AQUI, '_antes_de_alinear')     # recortado, sin fondo, pulido
DESTINO = os.path.join(AQUI, '04_giro')
REPOSO = E.REPOSO                                     # magnus_respirando/04_limpios/c_01.png
# en ORIGEN: c_01 = f001 (el reposo), c_02..c_84 = f040..f122, c_85 = f192 (reposo espejado)
REF_INI, REF_FIN = 1, 85
def c_de(f):
    return f - 38
DESDE, HASTA = 50, 110                 # fotogramas del video que se usan
N_INI, N_FIN = 10, 8                   # fotogramas en que se apaga / enciende la correccion de forma
N_FUNDIDO = 5                          # y el fundido con el reposo (casi quieto)
# Sombra de la capucha sobre la cara (0 = sin ella). El usuario pidio que de
# frente la capucha le tapara la cara "como pasa en la frontal" (el andar de
# frente: frente y ojos en sombra, solo asoma la nariz); el video la deja atras
# y la cara iluminada, con los ojos a la vista. Se oscurece lo que hay bajo el
# borde de delante de la capucha: SOMBRA en los primeros SOMBRA_LLENA px y luego
# menos (SOMBRA_CAIDA px), segun lo de frente que mira la cabeza (en el reposo,
# de perfil, nada: empieza y acaba igual que el reposo del juego).
SOMBRA, SOMBRA_LLENA, SOMBRA_CAIDA = 0.7, 4, 15


def leer(c):
    return np.asarray(Image.open(os.path.join(ORIGEN, 'c_%02d.png' % c)).convert('RGBA'))


def campo_hacia(a, ref):
    """Desplazamiento d (como en E.deformar) que lleva a sobre ref."""
    f = E.flujo(ref, a)                  # ref(x) ~ a(x + f(x))
    return cv2.GaussianBlur(-f, (0, 0), 3)


def cabeza(a):
    """(fila de la punta de la capucha, columna del centro de la cabeza, lo de
    frente que mira: 1 de frente, 0 de perfil). Lo de frente, por donde cuelga
    la barba respecto a la capucha: de perfil, a unos 25 px de su centro."""
    op = a[..., 3] > 200
    ys, xs = np.where(op)
    top = ys.min()
    cols = [np.where(op[y])[0] for y in range(top + 10, top + 60)]
    centro = np.mean([(c[0] + c[-1]) / 2 for c in cols if len(c) > 3])
    blanco = (a[..., :3].min(-1) > 175) & op
    blanco[:top + 60] = False; blanco[top + 160:] = False
    bx = np.where(blanco)[1]
    frente = 0.0 if len(bx) < 30 else float(np.clip(1 - abs(bx.mean() - centro) / 25, 0, 1))
    return top, int(round(centro)), frente


def sombra_cara(a, s):
    """Oscurece lo que hay bajo el borde de delante de la capucha (s = cuanto, en
    el borde): la frente y los ojos; la nariz y la barba casi no."""
    if s <= 0:
        return a
    op = a[..., 3] > 200
    x = a[..., :3].astype(int)
    sat = x.max(-1) - x.min(-1)
    m = x.mean(-1)
    tela = op & (sat < 35) & (x[..., 2] >= x[..., 0] - 10) & (m > 85) & (m < 215)
    top, cx, _ = cabeza(a)
    h, W = op.shape
    borde = np.full(W, np.nan)
    for c in range(max(0, cx - 60), min(W, cx + 61)):
        idx = np.where(tela[top:top + 130, c])[0]
        if len(idx) < 8:
            continue
        for y in range(idx[0] + 1, min(129, idx[0] + 110)):
            # el primer hueco (opaco, no tela) bajo un tramo de tela: el borde de delante
            if op[top + y, c] and not tela[top + y, c] and tela[top + y - 1, c]:
                if 25 <= y <= 100 and not tela[top + y:top + y + 6, c].all():
                    borde[c] = top + y
                break
    cols = np.where(~np.isnan(borde))[0]
    if len(cols) < 10:
        return a
    b = ndimage.median_filter(np.interp(np.arange(W), cols, borde[cols]), 9)
    d = np.arange(h, dtype=np.float32)[:, None] - b[None, :]
    campo = np.where(d >= -5, s * np.exp(-np.clip(d - SOMBRA_LLENA, 0, None) / SOMBRA_CAIDA), 0)
    # a lo ancho de la abertura, algo mas (que no queden claras las puntas de las cejas)
    lado = np.zeros(W, np.float32)
    lado[max(0, cols.min() - 10):cols.max() + 11] = 1
    campo = campo * ndimage.gaussian_filter1d(lado, 3)[None, :]
    campo = cv2.GaussianBlur(campo.astype(np.float32), (0, 0), 1.5) * (op & ~tela)
    out = a.copy()
    out[..., :3] = np.clip(a[..., :3] * (1 - campo[..., None]), 0, 255).astype(np.uint8)
    return out


if __name__ == '__main__':
    rep = np.asarray(Image.open(REPOSO).convert('RGBA'))
    ini, fin = leer(REF_INI), leer(REF_FIN)
    dx0, dy0 = E.encaje(ini, rep)
    dx1, dy1 = E.encaje(fin, E.espejo(rep))
    print('encaje con el reposo: al empezar dx %d dy %d; al acabar (espejado) dx %d dy %d' % (dx0, dy0, dx1, dy1))
    fs = list(range(DESDE, HASTA + 1))
    n = len(fs)

    def colocacion(i):
        t = E.suave(i / (n - 1))
        return dx0 + (dx1 - dx0) * t, dy0 + (dy1 - dy0) * t

    # tono estandar: ganancia medida en el reposo del video, ya colocado
    muestra = [E.mover(ini, dx0, dy0).astype(float) / 255]
    g = np.ones(3)
    for _ in range(5):
        g = g * tono.tono_reposo() / tono.media([tono.aplicar(im, g) for im in muestra])
    print('ganancia de tono (%.3f, %.3f, %.3f)' % tuple(g))

    def preparar(a, dx, dy):
        im = E.mover(a, dx, round(dy)).astype(float) / 255
        return E.quitar_verde((tono.aplicar(im, g) * 255).round().astype(np.uint8))

    X = [preparar(leer(c_de(f)), *colocacion(i)) for i, f in enumerate(fs)]
    # destino de los extremos: el reposo del juego y su espejo (ya con el tono estandar)
    R0 = rep
    R1 = E.espejo(rep)

    h, W = X[0].shape[:2]
    yy, xx = np.mgrid[0:h, 0:W].astype(np.float32)
    ident = np.dstack([xx, yy])
    # empiece: el primero, al reposo; la correccion se apaga en N_INI fotogramas
    d0 = campo_hacia(X[0], R0)
    P = ident
    Y = list(X)
    for i in range(0, N_INI + 1):
        if i > 0:
            f = E.flujo(X[i], X[i - 1])          # X[i](x) ~ X[i-1](x + f)
            P = cv2.remap(P, xx + f[..., 0], yy + f[..., 1], cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
        w = 1 - E.suave(i / N_INI)
        if w > 0:
            Y[i] = E.deformar(Y[i], E.llevar(d0, P, 0.0) * w)
    # final: el ultimo, al reposo espejado; la correccion se enciende en N_FIN fotogramas
    d1 = campo_hacia(X[-1], R1)
    P = ident
    for j in range(0, N_FIN + 1):
        i = n - 1 - j
        if j > 0:
            f = E.flujo(X[i], X[i + 1])
            P = cv2.remap(P, xx + f[..., 0], yy + f[..., 1], cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
        w = 1 - E.suave(j / N_FIN)
        if w > 0:
            Y[i] = E.deformar(Y[i], E.llevar(d1, P, 0.0) * w)
    # lo que queda, fundido con el reposo (empieza en el y acaba en su espejo)
    for i in range(N_FUNDIDO):
        t = E.suave(1 - i / N_FUNDIDO)
        Y[i] = E.fundir(Y[i], R0, t)
        Y[n - 1 - i] = E.fundir(Y[n - 1 - i], R1, t)

    # sombra de la capucha en la cara, segun lo de frente que mira (suavizado en
    # el tiempo: la medida de cada fotograma tiembla un poco)
    frente = np.array([cabeza(a)[2] for a in Y])
    frente = np.convolve(np.pad(frente, 2, mode='edge'), np.ones(5) / 5, mode='valid')
    fuerza = SOMBRA * np.array([E.suave((f - 0.15) / 0.55) for f in frente])
    print('sombra de la cara por fotograma: ' + ' '.join('%.2f' % f for f in fuerza))
    Y = [sombra_cara(a, s) for a, s in zip(Y, fuerza)]

    if os.path.isdir(DESTINO):
        shutil.rmtree(DESTINO)
    os.makedirs(DESTINO)
    for i, a in enumerate(Y):
        Image.fromarray(a, 'RGBA').save(os.path.join(DESTINO, 'c_%02d.png' % (i + 1)))
    print(n, "fotogramas (f%03d-f%03d): %.2f s a 24 fps" % (DESDE, HASTA, n / 24))

    # comprobacion: los extremos frente a la referencia y el cambio por fotograma
    def pm(x):
        x = x.astype(np.float32)
        return x[..., :3] * x[..., 3:] / 255
    pasos = np.array([np.abs(pm(Y[i + 1]) - pm(Y[i])).mean() for i in range(n - 1)])
    med = np.median(pasos)
    print('al empezar, frente al reposo: %.2f pasos (sin corregir %.2f)'
          % (np.abs(pm(Y[0]) - pm(R0)).mean() / med, np.abs(pm(X[0]) - pm(R0)).mean() / med))
    print('al acabar, frente al reposo espejado: %.2f pasos (sin corregir %.2f)'
          % (np.abs(pm(Y[-1]) - pm(R1)).mean() / med, np.abs(pm(X[-1]) - pm(R1)).mean() / med))
    print('reposo del juego frente al reposo del video colocado: %.2f pasos' % (np.abs(pm(rep) - pm(R0)).mean() / med))
    print('cambio por fotograma (pasos): max %.2f en %d; ' % (pasos.max() / med, pasos.argmax() + 1)
          + ' '.join('%.1f' % (p / med) for p in pasos))

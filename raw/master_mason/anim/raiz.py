"""Recorta las acciones que DESPLAZAN al peregrino (trepar, bajar, empujar) en
una casilla que lo sigue, y apunta cuanto se mueve: la RAIZ.

Los videos de estas acciones son de camara quieta y el peregrino cruza el
cuadro: sube 721 px de master al trepar el muro, baja otros tantos de un
saltito, avanza con el sillar al empujar. En el juego eso lo hace el nodo
(magnus.gd: la posicion del nodo es donde pisa), asi que aqui cada fotograma
se recorta en una casilla colocada en la raiz de ese fotograma y la raiz se
guarda: nodo + casilla = video, al pixel. Como el nodo hace el viaje, la
casilla no tiene que abarcar el recorrido entero, y la altura del salto o del
muro se puede retocar en el juego sin tocar el dibujo (ver "s" en raiz.json).

La raiz:
  - en el primer fotograma y en el ultimo, donde pisaria el reposo del juego
    (magnus_respirando c_01) encajado sobre el peregrino: linea de suelo de la
    casilla comun (fila 690, la planta en la 677) y eje en el centro;
  - entre medias, de la una a la otra al ritmo del cuerpo: por cada eje, lo que
    lleva recorrido el centro de la silueta respecto al total (0 a 1, sin
    volver atras), suavizado. Con --suelo-fijo la y no se mueve (empujar).

Escala: la de siempre (x1,5108), salvo que el video saque al peregrino de
otro tamano (--escala, o --escala auto: 627 px de alto en el primero).

Salida: <job>/04_limpios/c_NNN.png con el croma (para fondo.ps1 y pulir.py) y
<job>/raiz.json: escala, fotogramas, casilla, fila de la raiz en la casilla y,
por fotograma, la raiz (px de master en el video escalado) y su avance s (0..1
por eje). Si quitar_objeto.py siguio un objeto que se mueve, tambien donde
queda su borde de delante respecto a la raiz.

  python raiz.py <job> --desde F --hasta F [--escala 1.5108|auto] [--suelo-fijo]
"""
import argparse, json, os, shutil
import cv2
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

AQUI = os.path.dirname(os.path.abspath(__file__))
REPOSO = os.path.join(AQUI, 'magnus_respirando', '04_limpios', 'c_01.png')
CW0, CH0, RX0, RY0 = 584, 720, 292, 690      # casilla comun y su raiz
ALTO = 627                                    # alto del reposo (alfa > 128)
MARGEN = 30


def mascara(a, verde, umbral=60):
    """Silueta aproximada: lo que se aparta del verde, la mancha mayor y lo que
    la toca (manos o pies sueltos por un pixel)."""
    d = np.abs(a.astype(np.int16) - verde.astype(np.int16)).max(-1)
    m = d > umbral
    lab, n = ndi.label(m)
    if n == 0:
        return m
    tam = ndi.sum(m, lab, range(1, n + 1))
    grande = np.argmax(tam) + 1
    cerca = ndi.binary_dilation(lab == grande, iterations=6)
    ok = np.unique(lab[cerca & m])
    vale = np.zeros(n + 1, bool)
    vale[ok[ok > 0]] = True
    vale[1:] &= tam >= 30
    return vale[lab]


def encajar(m, rep, guia):
    """(X, Y): esquina de la casilla comun en el video escalado que mejor pone
    el reposo sobre la silueta m (del tronco a los pies, filas 300-720)."""
    gx, gy = guia
    mejor = None
    R = rep[300:].astype(np.float32)
    P = 100                                   # la casilla puede salirse del cuadro (pies junto al borde)
    mp = np.pad(m, P).astype(np.float32)
    for Y in range(gy - 16, gy + 17):
        for X in range(gx - 24, gx + 25):
            e = float(np.abs(mp[Y + P + 300:Y + P + CH0, X + P:X + P + CW0] - R).sum())
            if mejor is None or e < mejor[0]:
                mejor = (e, X, Y)
    return mejor[1], mejor[2]


def avance(c, total):
    """0..1 sin volver atras, suavizado, de una serie (centro de la silueta)."""
    if abs(total) < 1e-6:
        return np.linspace(0, 1, len(c))
    s = np.clip((c - c[0]) / total, 0, 1)
    s = np.maximum.accumulate(s)
    s = ndi.gaussian_filter1d(s, 1.5, mode='nearest')
    s = (s - s[0]) / max(s[-1] - s[0], 1e-6)
    return np.clip(s, 0, 1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('job')
    ap.add_argument('--desde', type=int, required=True)
    ap.add_argument('--hasta', type=int, required=True)
    ap.add_argument('--escala', default='1.5108')
    ap.add_argument('--suelo-fijo', action='store_true')
    ap.add_argument('--origen', default='01b_sin_objeto')
    a = ap.parse_args()

    carpeta = os.path.join(AQUI, a.job)
    ent = os.path.join(carpeta, a.origen)
    obj = json.load(open(os.path.join(carpeta, 'objeto.json'))) if os.path.exists(os.path.join(carpeta, 'objeto.json')) else {}
    nums = list(range(a.desde, a.hasta + 1))
    leer = lambda k: np.asarray(Image.open(os.path.join(ent, 'f_%04d.png' % k)).convert('RGB'))
    if 'verde' in obj:
        verde_v = np.array(obj['verde'], np.float32)
    else:
        # sin objeto que quitar: el verde del video, la mediana del borde del primero
        p = leer(a.desde)
        borde = np.concatenate([p[:8].reshape(-1, 3), p[-8:].reshape(-1, 3), p[:, :8].reshape(-1, 3), p[:, -8:].reshape(-1, 3)])
        verde_v = np.median(borde, 0).astype(np.float32)
        print('verde del video:', verde_v)

    if a.escala == 'auto':
        m1 = mascara(leer(a.desde), verde_v)
        ys = np.where(m1.any(1))[0]
        esc = ALTO / float(ys.max() - ys.min())
    else:
        esc = float(a.escala)
    h0, w0 = leer(a.desde).shape[:2]
    W, H = int(round(w0 * esc)), int(round(h0 * esc))
    print('%s: escala %.4f (%dx%d -> %dx%d), fotogramas f%03d-f%03d (%d)' % (a.job, esc, w0, h0, W, H, a.desde, a.hasta, len(nums)))

    def escalar(img):
        return cv2.resize(img, (W, H), interpolation=cv2.INTER_LANCZOS4)

    X = [escalar(leer(k)) for k in nums]
    M = [mascara(x, verde_v) for x in X]
    alto0 = np.ptp(np.where(M[0].any(1))[0])
    print('alto del peregrino en el primero, escalado: %d (el reposo, %d)' % (alto0, ALTO))

    rep = np.asarray(Image.open(REPOSO).convert('RGBA'))[..., 3] > 128

    def guia(m):
        ys, xs = np.where(m)
        ry, rx = np.where(rep)
        return int(round(xs.mean() - rx.mean())), int(ys.max() - ry.max())

    X0, Y0 = encajar(M[0], rep, guia(M[0]))
    X1, Y1 = encajar(M[-1], rep, guia(M[-1]))
    R0 = np.array([X0 + RX0, Y0 + RY0], float)
    R1 = np.array([X1 + RX0, Y1 + RY0], float)
    print('raiz al empezar %s, al acabar %s: viaje (%+d, %+d) px de master' % (R0, R1, R1[0] - R0[0], R1[1] - R0[1]))

    # avance por eje al ritmo del centro de la silueta
    cen = np.array([[np.where(m)[1].mean(), np.where(m)[0].mean()] for m in M])
    cen = ndi.gaussian_filter1d(cen, 2.0, axis=0, mode='nearest')
    viaje = R1 - R0
    sx = avance(cen[:, 0], cen[-1, 0] - cen[0, 0]) if abs(viaje[0]) > 8 else np.linspace(0, 1, len(nums))
    if a.suelo_fijo or abs(viaje[1]) <= 8:
        sy = np.linspace(0, 1, len(nums))
    else:
        sy = avance(cen[:, 1], cen[-1, 1] - cen[0, 1])
    raiz = np.round(np.stack([R0[0] + sx * viaje[0], R0[1] + sy * viaje[1]], 1)).astype(int)

    # casilla: lo que ocupa la silueta respecto a la raiz, simetrica en x
    izq = der = arr = aba = 0
    for m, r in zip(M, raiz):
        ys, xs = np.where(m)
        izq = max(izq, r[0] - xs.min()); der = max(der, xs.max() - r[0])
        arr = max(arr, r[1] - ys.min()); aba = max(aba, ys.max() - r[1])
    # medidas multiplo de 8: la hoja va a la mitad y empaquetar.py la quiere
    # multiplo de 4 (bloques de la compresion BC7); lo que sobra de alto, arriba
    semi = max(izq, der, CW0 // 2 - MARGEN) + MARGEN
    semi = int(np.ceil(semi / 4.0) * 4)
    arriba = max(arr + MARGEN, RY0)
    abajo = max(aba + MARGEN, CH0 - RY0)
    arriba = int(np.ceil(arriba / 2.0) * 2); abajo = int(np.ceil(abajo / 2.0) * 2)
    arriba += (-(arriba + abajo)) % 8
    CW, CH, RY = 2 * semi, arriba + abajo, arriba
    print('casilla %dx%d (raiz en la fila %d; la comun, 584x720 con la raiz en la 690)' % (CW, CH, RY))

    dest = os.path.join(carpeta, '04_limpios')
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    os.makedirs(dest)
    # el croma alrededor, del color del video
    fondo = np.empty((CH, CW, 3), np.uint8); fondo[:] = verde_v.round().astype(np.uint8)
    for i, (x, r) in enumerate(zip(X, raiz)):
        cel = fondo.copy()
        x0, y0 = r[0] - semi, r[1] - RY
        sx0, sy0 = max(0, x0), max(0, y0)
        sx1, sy1 = min(W, x0 + CW), min(H, y0 + CH)
        cel[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0] = x[sy0:sy1, sx0:sx1]
        Image.fromarray(cel).save(os.path.join(dest, 'c_%03d.png' % (i + 1)))

    datos = {'escala': round(esc, 5), 'desde': a.desde, 'hasta': a.hasta, 'casilla': [CW, CH], 'raiz_fila': RY,
             'raiz': raiz.tolist(), 's': [[round(float(u), 4), round(float(v), 4)] for u, v in zip(sx, sy)],
             'suelo_fijo': bool(a.suelo_fijo)}
    if obj.get('dx') and any(obj['dx']):
        # borde de delante (izquierdo) del objeto que se mueve, respecto a la raiz
        bx = obj['caja'][0]
        datos['objeto_borde'] = [round((bx + obj['dx'][k - 1]) * esc - r[0], 2) for k, r in zip(nums, raiz)]
        datos['objeto_caja'] = [round(v * esc, 1) for v in obj['caja']]
    json.dump(datos, open(os.path.join(carpeta, 'raiz.json'), 'w'), indent=1)
    print('escrito 04_limpios (%d) y raiz.json' % len(nums))


if __name__ == '__main__':
    main()

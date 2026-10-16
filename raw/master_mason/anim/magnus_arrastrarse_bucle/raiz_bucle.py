"""El BUCLE DEL ARRASTRE (2026-10-15): recorte y raiz de los fotogramas del bucle
del video de Flow (Hooded_pilgrim_crawling_rightward_20261015091727, de
_fuentes/prompt_arrastre_bucle.txt: empieza y acaba en el c096 del arrastre de
magnus_tumbarse, el del final corrido 4 brazadas).

El principio del video no vale (el usuario: "hace algo descompasado": ~3 s casi
en el sitio). Se coge el bucle desde el final: f133..f192 (60 fotogramas, dos
tirones). El f192 calca la referencia (el c096) a 0,46 pasos normales y el f132
calca al f192 a 1,2: tras el f192 viene el f133 como si fuera el siguiente (la
costura, 0,94 pasos normales; la del arrastre viejo, 2).

Como raiz.py, pero sin el reposo en los extremos: aqui los extremos son el c096
del arrastre viejo (la casilla de 920x720 de magnus_tumbarse, raiz en la fila
690). La escala y el sitio de la casilla del f192 salen de encajar su silueta
en la del c096; la del f132 (= el f192 una vuelta antes), de encajarla en la del
f192; entre medias, al ritmo del centro de la silueta. Asi nodo + casilla =
video, y el bucle empalma con el arrastre viejo al pixel.

Salida: 04_limpios/c_001..c_061 (f132..f192: el c_001 solo da la raiz de la
vuelta; el bucle es c_002..c_061) con el croma, y raiz.json.
  python raiz_bucle.py
"""
import json, os, shutil
import cv2
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

AQUI = os.path.dirname(os.path.abspath(__file__))
VIEJO = os.path.join(AQUI, '..', 'magnus_tumbarse')
DESDE, HASTA = 132, 192
CW, CH, RX, RY = 920, 720, 460, 690          # la casilla de magnus_tumbarse


def mascara(a, verde, umbral=60):
    d = np.abs(a.astype(np.int16) - verde.astype(np.int16)).max(-1)
    m = d > umbral
    lab, n = ndi.label(m)
    if n == 0:
        return m
    tam = ndi.sum(m, lab, range(1, n + 1))
    return ndi.binary_dilation(lab == np.argmax(tam) + 1, iterations=2) & m


def iou(a, b):
    return float((a & b).sum()) / max(float((a | b).sum()), 1.0)


def main():
    ent = os.path.join(AQUI, '01_frames')
    leer = lambda k: np.asarray(Image.open(os.path.join(ent, 'f_%04d.png' % k)).convert('RGB'))
    p = leer(HASTA)
    borde = np.concatenate([p[:8].reshape(-1, 3), p[:, :8].reshape(-1, 3), p[:, -8:].reshape(-1, 3)])
    verde = np.median(borde, 0).astype(np.float32)
    viejo = np.asarray(Image.open(os.path.join(VIEJO, '04_limpios', 'c_096.png')).convert('RGBA'))
    mv = viejo[..., 3] > 128
    yv, xv = np.where(mv)
    # escala: la que mejor encaja la silueta del f192 en la del c096
    mejor = None
    for esc in np.arange(1.47, 1.535, 0.005):
        img = cv2.resize(p, None, fx=esc, fy=esc, interpolation=cv2.INTER_AREA)
        m = mascara(img, verde)
        ys, xs = np.where(m)
        # casilla del c096 puesta de modo que los bordes de abajo y derecho casen
        gx = int(xs.max() - xv.max()); gy = int(ys.max() - yv.max())
        for Y in range(gy - 6, gy + 7, 2):
            for X in range(gx - 10, gx + 11, 2):
                sub = m[Y:Y + CH, X:X + CW]
                if sub.shape != (CH, CW):
                    continue
                v = iou(sub, mv)
                if mejor is None or v > mejor[0]:
                    mejor = (v, esc, X, Y)
    v, esc, X, Y = mejor
    # afinar el sitio a 1 px
    img = cv2.resize(p, None, fx=esc, fy=esc, interpolation=cv2.INTER_AREA)
    m192 = mascara(img, verde)
    for Y2 in range(Y - 2, Y + 3):
        for X2 in range(X - 2, X + 3):
            sub = m192[Y2:Y2 + CH, X2:X2 + CW]
            if sub.shape == (CH, CW) and iou(sub, mv) > v:
                v, X, Y = iou(sub, mv), X2, Y2
    print('escala %.3f: el f192 sobre el c096 con IoU %.3f' % (esc, v))
    nums = list(range(DESDE, HASTA + 1))
    IM = [cv2.resize(leer(k), None, fx=esc, fy=esc, interpolation=cv2.INTER_LANCZOS4) for k in nums]
    M = [mascara(x, verde) for x in IM]
    H, W = IM[0].shape[:2]
    r192 = np.array([X + RX, Y + RY], float)
    # la vuelta: el f132 encajado en el f192 (solo en x: el suelo es el mismo)
    a, b = M[0], M[-1]
    mejor = None
    cx = int(np.where(b)[1].mean() - np.where(a)[1].mean())
    for dx in range(cx - 40, cx + 41):
        v2 = iou(np.roll(a, dx, 1), b)
        if mejor is None or v2 > mejor[0]:
            mejor = (v2, dx)
    vuelta = mejor[1]
    print('vuelta: %d px de master (el f132 sobre el f192 con IoU %.3f)' % (vuelta, mejor[0]))
    r132 = r192 - np.array([vuelta, 0.0])
    cen = np.array([np.where(m)[1].mean() for m in M])
    cen = ndi.gaussian_filter1d(cen, 2.0, mode='nearest')
    s = np.clip((cen - cen[0]) / (cen[-1] - cen[0]), 0, 1)
    s = np.maximum.accumulate(s)
    s = ndi.gaussian_filter1d(s, 1.5, mode='nearest')
    s = np.clip((s - s[0]) / (s[-1] - s[0]), 0, 1)
    raiz = np.round(np.stack([r132[0] + s * vuelta, np.full(len(nums), r132[1])], 1)).astype(int)
    # que quepa en la casilla
    for m, r, k in zip(M, raiz, nums):
        ys, xs = np.where(m)
        if xs.min() < r[0] - RX + 4 or xs.max() > r[0] + RX - 4 or ys.min() < r[1] - RY + 4:
            print('OJO: el f%d se sale de la casilla' % k)
    dest = os.path.join(AQUI, '04_limpios')
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    os.makedirs(dest)
    fondo = np.empty((CH, CW, 3), np.uint8)
    fondo[:] = verde.round().astype(np.uint8)
    for i, (x, r) in enumerate(zip(IM, raiz)):
        cel = fondo.copy()
        x0, y0 = r[0] - RX, r[1] - RY
        sx0, sy0 = max(0, x0), max(0, y0)
        sx1, sy1 = min(W, x0 + CW), min(H, y0 + CH)
        cel[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0] = x[sy0:sy1, sx0:sx1]
        Image.fromarray(cel).save(os.path.join(dest, 'c_%03d.png' % (i + 1)))
    datos = {'escala': round(float(esc), 5), 'desde': DESDE, 'hasta': HASTA, 'casilla': [CW, CH], 'raiz_fila': RY,
             'raiz': raiz.tolist(), 's': [[round(float(u), 4), 0.0] for u in s], 'vuelta': int(vuelta),
             'encaje_c096': round(v, 3)}
    json.dump(datos, open(os.path.join(AQUI, 'raiz.json'), 'w'), indent=1)
    print('escrito 04_limpios (%d) y raiz.json; avance por fotograma %.2f px de master' % (len(nums), vuelta / 60.0))


if __name__ == '__main__':
    main()

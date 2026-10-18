"""El baston a la espalda del peregrino de frente/espaldas (PeregrinoFrontal), visto
de espaldas: el MISMO que lleva en la mano (2026-10-15).

Hasta ahora el baston guardado era baston.png (el del perfil: mas naranja, liso y con
otra garra) a 1,2 de ancho; los videos de sacar y guardar de espaldas pintan en la
correa el de la mano (marron, con la garra de cuerna y el tramo retorcido) y en los
puentes se transformaba de uno a otro (el usuario: "pasa ya al de la animacion, que
no es exacto"; "igualarlo todo a la vieja usanza, sin trucos").

Aqui, el de la mano del reposo de espaldas con baston (peregrino_secuencia_frontal,
reposo_espalda_cb_000, el que se ve parado y andando), recortado a mano: la garra y
el tramo retorcido (la pieza de arriba, suelta sobre el verde) y el palo liso (la de
abajo); en medio la mano y la manga lo tapan: ahi, el mismo palo liso. Enderezado
(la recta de su palo) y con la largura de la bola al pie que tiene en la correa
(LARGO, la de los videos: en la mano mide mas porque llega al suelo; se acorta el
palo liso, no se escala: la garra y el grosor, los de la mano). Sin la orla verde del
croma. A escala de hoja (la mitad del master), en premultiplicado.
(Se probo con la plantilla de arreglar.py, la de Veo en reposo: el palo, su tramo
retorcido repetido, salia el doble de grueso que el de la mano y que el de la correa.)

Sale assets/characters/baston/baston_espalda.png y baston_espalda.json (la bola en la
textura, px), y aqui baston_espalda_master.png/.json (a escala de master, para
repintar los fotogramas de sacar y guardar): el componente la pone con la bola donde iba la de baston.png
(ORBE_EN_MADERA del pivote), asi las filas de baston_espalda / funda_espalda valen.
    python raw/master_mason/anim/baston/baston_espalda.py
"""
import json, os
import numpy as np, cv2
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
PROY = os.path.abspath(os.path.join(ANIM, '..', '..', '..'))
SALIDA = os.path.join(PROY, 'assets', 'characters', 'baston')
FUENTE = os.path.join(ANIM, 'peregrino_secuencia_frontal', '04_limpios', 'reposo_espalda_cb_000.png')
SEC = os.path.join(PROY, 'assets', 'characters', 'peregrino', 'secuencia_frontal.json')
CASILLA = (292, 400)        # hoja; el master es el doble
LARGO = 437.0               # master: de la bola al pie en la correa (arreglar.py, LARGO_CORREA)
TRAMO = 176                 # master bajo la bola: hasta aqui la garra y el tramo retorcido (pieza de
                            # arriba; mas abajo se junta con la manga y sale mordida)
PALO = (480, 724)           # filas del palo liso de abajo (pieza suelta)
MARGEN = 6


def piezas(a):
    """(el baston fuera del cuerpo, el cuerpo)."""
    al = a[..., 3] > 40
    fat = cv2.morphologyEx((a[..., 3] > 128).astype(np.uint8), cv2.MORPH_OPEN,
                           cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (19, 19)))
    n, lab, st, _ = cv2.connectedComponentsWithStats(fat)
    cuerpo = lab == 1 + np.argmax(st[1:, cv2.CC_STAT_AREA])
    cuerpo = cv2.dilate(cuerpo.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
    fuera = al & ~cuerpo
    n, lab, st, _ = cv2.connectedComponentsWithStats(fuera.astype(np.uint8))
    # las del baston, a la derecha del cuerpo (las otras grandes son los pies)
    grandes = [i for i in range(1, n) if st[i, cv2.CC_STAT_AREA] > 1000 and st[i, cv2.CC_STAT_LEFT] > 360]
    return np.isin(lab, grandes), cuerpo


def main():
    a = np.asarray(Image.open(FUENTE).convert('RGBA')).astype(np.float32)
    sec = json.load(open(SEC))
    o = sec['orbe']['reposo_espalda_cb'][0]
    bola = np.array([(o[0] + CASILLA[0] / 2) * 2, (o[1] + CASILLA[1] / 2) * 2])
    baston, _ = piezas(a)
    # la recta del palo: el centro de cada fila del palo liso y del tramo de arriba
    filas = [y for y in range(PALO[0], PALO[1]) if baston[y].any()]
    filas += [y for y in range(int(bola[1]) + 120, int(bola[1]) + TRAMO) if baston[y].any()]
    cx = [np.nonzero(baston[y])[0].mean() for y in filas]
    m, c = np.polyfit(filas, cx, 1)
    ang = np.degrees(np.arctan(m))
    print('bola', bola, 'el palo se inclina %.2f grados' % ang)
    # solo el baston, con su alfa; sin la orla verde
    t = a.copy()
    t[~baston] = 0
    g = np.minimum(t[..., 1], np.maximum(t[..., 0], t[..., 2]))
    t[..., 1] = g
    # enderezar alrededor de la bola
    M = cv2.getRotationMatrix2D((float(bola[0]), float(bola[1])), -ang, 1.0)
    r = cv2.warpAffine(t, M, (a.shape[1], a.shape[0]), flags=cv2.INTER_LINEAR, borderValue=0)
    eje = int(round(bola[0]))
    W = 100
    tira = r[:, eje - W // 2:eje + W // 2]
    by = int(round(bola[1]))
    arriba = tira[:by + TRAMO]                       # la garra y el tramo retorcido
    palo = tira[PALO[0]:PALO[1]]                     # el palo liso, hasta el pie
    # lo que falta de palo (bajo el tramo retorcido) con las primeras filas del liso
    falta = int(LARGO) - TRAMO - palo.shape[0]
    # (de en medio del palo liso: sus primeras filas salen mordidas por la manga)
    trozo = palo[40:80]
    relleno = np.concatenate([trozo] * (falta // 40 + 1))[:max(falta, 0)] if falta > 0 else palo[:0]
    palo = palo[12:] if falta > 0 else palo
    relleno = np.concatenate([relleno, trozo[:12]]) if falta > 0 else relleno
    if falta < 0:
        palo = palo[-falta:]
    junto = np.concatenate([arriba, relleno, palo]).copy()
    # costuras: fundir 3 filas
    for y in (by + TRAMO, by + TRAMO + relleno.shape[0]):
        if 2 < y < junto.shape[0] - 3:
            junto[y - 1:y + 2] = (junto[y - 3:y] + junto[y + 1:y + 4]) / 2.0
    al = junto[..., 3] > 2
    ys, xs = np.nonzero(al)
    y0 = max(0, ys.min() - MARGEN)
    y1 = min(junto.shape[0], ys.max() + 1 + MARGEN)
    medio = max(W // 2 - (xs.min() - MARGEN), (xs.max() + 1 + MARGEN) - W // 2)
    x0, x1 = W // 2 - medio, W // 2 + medio
    if (y1 - y0) % 2:
        y1 += 1
    junto = junto[y0:y1, max(0, x0):min(W, x1)]
    b = np.array([W // 2 - max(0, x0), by - y0], float)
    # a escala de master, recto (bola arriba, pie abajo): para repintar los
    # fotogramas de sacar y guardar (peregrino_guardar_baston_espalda_a/arreglar.py)
    Image.fromarray(junto.clip(0, 255).astype(np.uint8), 'RGBA').save(os.path.join(AQUI, 'baston_espalda_master.png'))
    pie = int(np.nonzero(junto[..., 3] > 2)[0].max())
    json.dump({'bola': [float(b[0]), float(b[1])], 'pie': pie}, open(os.path.join(AQUI, 'baston_espalda_master.json'), 'w'))
    # a la mitad (hoja), en premultiplicado
    al = junto[..., 3:] / 255.0
    pre = np.dstack([junto[..., :3] * al, al])
    hh, ww = junto.shape[0] // 2, junto.shape[1] // 2
    pre = cv2.resize(pre, (ww, hh), interpolation=cv2.INTER_AREA)
    a2 = pre[..., 3:]
    rgb = pre[..., :3] / np.maximum(a2, 1e-4)
    out = np.dstack([rgb, a2 * 255]).clip(0, 255).astype(np.uint8)
    out[a2[..., 0] < 1e-3] = 0
    Image.fromarray(out, 'RGBA').save(os.path.join(SALIDA, 'baston_espalda.png'))
    bh = b / 2.0
    json.dump({'bola': [round(float(bh[0]), 2), round(float(bh[1]), 2)], 'tam': [int(ww), int(hh)],
               'largo': LARGO / 2.0}, open(os.path.join(SALIDA, 'baston_espalda.json'), 'w'), indent=1)
    print('baston_espalda.png', (ww, hh), 'bola', bh.tolist())


if __name__ == '__main__':
    main()

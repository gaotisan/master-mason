"""Pies oscuros en los videos que Veo saco descalzos (2026-10-12).

El prompt decia "thin dark legs and bare feet" y en la tanda de la espalda nueva Veo
pinto los pies color carne y con dedos (y unas claras). En la vuelta y en el correr de
frente las piernas siguen oscuras, como en lo aceptado: basta con llevar lo claro de los
pies al marron del pie del andar de frente aceptado (peregrino_secuencia_frontal_sin,
fotogramas del andar), conservando el sombreado. Las dos de espaldas (andar y correr)
tenian tambien las piernas color carne: esas se repiten con el prompt corregido.

Que se oscurece, por fotograma:
  - piernas: lo fino que cuelga de la tunica (el alfa menos su apertura con un disco de
    41 px, de cintura para abajo) que es LARGO (>= 60 px) y lleva pixeles oscuros de
    pierna; ahi, lo mas claro que el pie aceptado. Las puntas de la tunica son cortas:
    no se tocan (el color no las separa: piel y tunica tienen el mismo tono).
  - la franja de los pies (las ultimas 34 filas de la figura, adonde la tunica no
    llega): con los dos pies juntos el bloque es grueso y la apertura no lo ve fino.
  - las unas: lo casi blanco y poco saturado (croma Lab < 13) de lo fino en la parte
    baja; la tunica tostada tiene mas croma.
Los fotogramas de Veo se guardan en _todos_veo/ la primera vez; el arreglo se escribe
sobre _todos/ (lo que lee secuencia.py). Si se vuelve a montar (montar_en_sitio.py),
hay que volver a pasar esto.
    python oscurecer_pies.py peregrino_vuelta_sin_v2 peregrino_correr_frente
"""
import os, shutil, sys
import numpy as np, cv2
from PIL import Image

ANIM = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
ACEPTADO = ('peregrino_secuencia_frontal_sin', range(38, 69))   # el andar de frente aceptado (FRENTE a=38, P=31)
DISCO = 41
ALTO_PIERNA = 60
BANDA_PIES = 34


def lum(a):
    return a[..., :3].astype(float) @ [0.299, 0.587, 0.114]


def croma(a):
    x = cv2.cvtColor(np.ascontiguousarray(a[..., :3]), cv2.COLOR_RGB2LAB).astype(float)
    return np.hypot(x[..., 1] - 128, x[..., 2] - 128)


def leer(ruta):
    return np.asarray(Image.open(ruta).convert('RGBA'))


def pie_aceptado():
    """color (mediana) y luminancias (mediana, p90) de los pies del andar aceptado"""
    job, ks = ACEPTADO
    v = []
    for k in ks:
        a = leer(os.path.join(ANIM, job, '_todos', 'c_%03d.png' % k))
        al = a[..., 3] > 200
        yb = np.nonzero(al.any(1))[0].max()
        b = np.zeros(al.shape, bool)
        b[yb - 18:yb + 1] = True
        v.append(a[b & al][:, :3])
    v = np.concatenate(v).astype(float)
    L = v @ [0.299, 0.587, 0.114]
    return np.median(v, 0), np.median(L), np.percentile(L, 90)


def fino(a):
    al = (a[..., 3] > 40).astype(np.uint8)
    ys = np.nonzero(al.any(1))[0]
    top, yb = ys.min(), ys.max()
    ab = cv2.morphologyEx(al, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (DISCO, DISCO)))
    f = (al > 0) & (ab == 0)
    f[:int(top + 0.55 * (yb - top))] = False
    return f, top, yb


def piernas(a):
    f, top, yb = fino(a)
    n, lab, st, _ = cv2.connectedComponentsWithStats(f.astype(np.uint8), 8)
    L = lum(a)
    m = np.zeros(f.shape, bool)
    for i in range(1, n):
        c = lab == i
        if st[i, cv2.CC_STAT_AREA] > 150 and st[i, cv2.CC_STAT_HEIGHT] >= ALTO_PIERNA \
                and ((L < 75) & c & (a[..., 3] > 200)).sum() > 40:
            m |= c
    return m, f, top, yb


def oscurecer(a, col, l90):
    a = a.copy()
    m, f, top, yb = piernas(a)
    L = lum(a)
    al = a[..., 3]
    banda = np.zeros(f.shape, bool)
    banda[yb - BANDA_PIES:yb + 1] = True
    claro = (m | (banda & (al > 25))) & (L > l90)
    zona = m | (banda & (al > 0))
    claro = cv2.dilate(claro.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool) & zona
    baja = np.zeros(f.shape, bool)
    baja[int(top + 0.6 * (yb - top)):] = True
    unas = f & baja & (al > 25) & (L > 95) & (croma(a) < 13)
    unas = cv2.dilate(unas.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool) & f & (L > l90)
    t = claro | unas
    if t.any():
        ref = L[claro & (al > 200)].mean() if (claro & (al > 200)).any() else L[t].mean()
        fac = np.minimum((L[t] / max(ref, 1.0)) ** 0.6, 1.25)
        a[t, :3] = np.clip(col[None, :] * fac[:, None] * 1.05, 0, 255).astype(np.uint8)
    return a, int(t.sum())


def main(jobs):
    col, l0, l90 = pie_aceptado()
    print('pie aceptado: color %s, lum mediana %.0f, p90 %.0f' % (col.round(), l0, l90))
    for job in jobs:
        todos, veo = os.path.join(ANIM, job, '_todos'), os.path.join(ANIM, job, '_todos_veo')
        if not os.path.isdir(veo):
            shutil.copytree(todos, veo)
        nombres = sorted(n for n in os.listdir(veo) if n.endswith('.png'))
        total = 0
        for n in nombres:
            b, k = oscurecer(leer(os.path.join(veo, n)), col, l90)
            Image.fromarray(b).save(os.path.join(todos, n))
            total += k
        print('%s: %d fotogramas, %.0f px oscurecidos de media' % (job, len(nombres), total / max(len(nombres), 1)))


if __name__ == '__main__':
    main(sys.argv[1:] or ['peregrino_vuelta_sin_v2', 'peregrino_correr_frente'])

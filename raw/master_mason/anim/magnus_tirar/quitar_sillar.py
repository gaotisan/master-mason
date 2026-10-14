"""Tirar: quita el sillar de relleno (y su argolla) de los fotogramas, por COLOR.
El de este video se ladea a mitad (unos 10 grados hacia el 100) mientras lo
arrastra, asi que no vale restar su imagen como en empujar (quitar_objeto.py
--mueve, que lo sigue rigido). Aqui:
  - sillar: la mancha grande de piedra clara (poco saturada, clara) en cada
    fotograma, con sus huecos rellenos y algo engordada; las manos (piel) y la
    tunica no son de ese color;
  - argolla: lo oscuro que hay delante de su cara, a la altura de la cadera, que
    no es piel (la mano la agarra).
Deja 01b_sin_objeto/ y objeto.json como quitar_objeto.py, con el borde de
delante (izquierdo) del sillar por fotograma en "dx" (respecto al primero): con
eso raiz.py y montar_accion.py ponen el sillar del juego con las manos.
  python quitar_sillar.py"""
import json, os, shutil
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

AQUI = os.path.dirname(os.path.abspath(__file__))
ENT = os.path.join(AQUI, '01_frames')
SAL = os.path.join(AQUI, '01b_sin_objeto')


def main():
    nombres = sorted(f for f in os.listdir(ENT) if f.endswith('.png'))
    p0 = np.asarray(Image.open(os.path.join(ENT, nombres[0])).convert('RGB')).astype(int)
    borde = np.concatenate([p0[:8].reshape(-1, 3), p0[-8:].reshape(-1, 3)])
    verde = np.median(borde, 0)
    if os.path.isdir(SAL):
        shutil.rmtree(SAL)
    os.makedirs(SAL)
    izq, cajas = [], []
    for n in nombres:
        a = np.asarray(Image.open(os.path.join(ENT, n)).convert('RGB')).astype(int)
        mx, mn = a.max(-1), a.min(-1)
        es_verde = (a[..., 1] - a[..., 0] > 60) & (a[..., 1] - a[..., 2] > 50)
        # la piedra, tambien su pie en sombra (0,86 de la luz) y el filo con el croma
        piedra = (mn > 80) & (mx - mn < 52) & (a[..., 0] >= a[..., 2] - 6) & ~es_verde
        lab, k = ndi.label(piedra)
        if k == 0:
            izq.append(np.nan); cajas.append(None)
            Image.fromarray(a.astype(np.uint8)).save(os.path.join(SAL, n))
            continue
        tam = ndi.sum(piedra, lab, range(1, k + 1))
        sillar = lab == (np.argmax(tam) + 1)
        sillar = ndi.binary_fill_holes(ndi.binary_closing(sillar, iterations=3))
        ys, xs = np.where(sillar)
        y0, y1 = ys.min(), ys.max()
        # el borde de delante: la mediana del borde izquierdo en el tercio de en medio
        filas = range(y0 + (y1 - y0) // 3, y1 - (y1 - y0) // 3)
        bordes = [np.where(sillar[y])[0].min() for y in filas if sillar[y].any()]
        x_izq = float(np.median(bordes))
        izq.append(x_izq)
        cajas.append([int(xs.min()), int(y0), int(xs.max()), int(y1)])
        quita = ndi.binary_dilation(sillar, iterations=4)
        # la argolla: lo oscuro delante de su cara, a la altura de la cadera, que no sea piel
        oscuro = mx < 95
        piel = (a[..., 0] > a[..., 1] + 12) & (a[..., 1] > a[..., 2]) & (a[..., 0] > 95)
        caja = np.zeros(sillar.shape, bool)
        yc = int(y1 - 0.50 * (y1 - y0))           # la argolla, a 0,45 del alto del peregrino (la mitad del sillar)
        caja[max(0, yc - 40):yc + 40, max(0, int(x_izq) - 52):int(x_izq) + 8] = True
        argolla = caja & oscuro & ~piel
        argolla = ndi.binary_dilation(argolla, iterations=1) & caja & ~piel
        quita |= argolla
        a = a.copy()
        a[quita] = verde
        Image.fromarray(a.astype(np.uint8)).save(os.path.join(SAL, n))
    izq = np.array(izq)
    dx = (izq - izq[0]).round(2)
    caja0 = list(cajas[0])
    caja0[0] = int(round(izq[0]))                  # el borde de delante, el mismo que sigue dx
    json.dump({'caja': caja0, 'dx': [float(v) for v in dx], 'verde': [float(v) for v in verde],
               'umbral': None, 'placa': 'color', 'cajas': cajas},
              open(os.path.join(AQUI, 'objeto.json'), 'w'), indent=1)
    print('sillar: borde de delante de %.0f a %.0f (video px); %d fotogramas' % (izq[0], izq[-1], len(nombres)))


if __name__ == '__main__':
    main()

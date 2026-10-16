"""El pico de la capucha del video de flotar quieto (2026-10-15). El usuario: "el
problema es el pico del gorro, tendrias que cortarlo e igualarlo a otros". En
ese video la capucha remata arriba y atras en un pico que se dobla hacia arriba
(un cuerno); en la pose de flotar (c_38 del salto parado) y en el resto de
animaciones (giro, bajada, posarse) acaba limpia, en triangulo.

Por fotograma: la silueta de la cabeza de la pose (las filas de arriba de la
figura) se encaja sobre la del video por lo de abajo de la capucha y el
arranque de la barba (que casan: el pico es lo unico que sobra), probando
desplazamientos y un giro pequeno; lo del video que en la banda de la capucha
queda fuera de esa silueta (ensanchada ORLA px) se quita (alfa a 0, con borde
suave). Nada se pinta: la capucha sigue siendo la del video, con su luz y su
movimiento; solo pierde lo que sobresale.

  python recortar_capucha.py <carpeta con c_NNN.png> [<salida>] [fotogramas, p. ej. 41,118]
"""
import glob, os, sys
import cv2
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
sys.path.insert(0, AQUI)
import montar_flotar as M  # noqa: E402

CABEZA = 150       # filas de master desde lo mas alto de la figura: la capucha y el arranque de la barba
ENCAJE = (55, 150)  # filas (desde lo mas alto) con las que se encaja: la capucha baja y la barba, sin el pico
ORLA = 3           # px que se deja de margen fuera de la silueta de la pose
SUAVE = 1.2        # borde del corte


def pose_en_casilla():
    pose = np.asarray(Image.open(M.POSE).convert('RGBA'))
    lien = np.zeros((M.CASILLA_H, M.CASILLA_W, 4), np.uint8)
    lien[M.ARRIBA:M.ARRIBA + 720] = pose
    return lien


def cabeza(al):
    """(fila de arriba, columna central de la cabeza) de una silueta."""
    ys = np.nonzero(al.any(1))[0]
    top = int(ys.min())
    xs = np.nonzero(al[top:top + CABEZA].any(0))[0]
    return top, int(xs.mean())


def encajar(al_v, al_p):
    """Desplazamiento y giro que llevan la cabeza de la pose sobre la del video,
    midiendo solo las filas ENCAJE (sin el pico), en una ventana alrededor de la
    cabeza (la casilla entera era 13 s por fotograma). Devuelve la silueta de la
    pose ya movida, en el lienzo del video."""
    tv, cv = cabeza(al_v)
    tp, cp = cabeza(al_p)
    h, w = al_v.shape
    a0, a1 = tv + ENCAJE[0], tv + ENCAJE[1]
    x0, x1 = max(cv - 170, 0), min(cv + 170, w)
    zv = al_v[a0:a1, x0:x1]
    pf = al_p.astype(np.float32)
    def prueba(ang, dx, dy, rot):
        # la ventana del video, leida en la pose movida (dy, dx)
        ys0, xs0 = a0 - dy, x0 - dx
        zp = np.zeros_like(zv)
        sy0, sx0 = max(ys0, 0), max(xs0, 0)
        sy1, sx1 = min(ys0 + (a1 - a0), h), min(xs0 + (x1 - x0), w)
        zp[sy0 - ys0:sy1 - ys0, sx0 - xs0:sx1 - xs0] = rot[sy0:sy1, sx0:sx1]
        return (zv & zp).sum() / max((zv | zp).sum(), 1)
    mejor = None
    rots = {}
    for ang in (-6, -4, -2, 0, 2, 4, 6):
        Mrot = cv2.getRotationMatrix2D((float(cp), float(tp + 80)), ang, 1.0)
        rots[ang] = cv2.warpAffine(pf, Mrot, (w, h), flags=cv2.INTER_LINEAR) > 0.5
        for dy in range(tv - tp - 24, tv - tp + 25, 3):
            for dx in range(cv - cp - 24, cv - cp + 25, 3):
                v = prueba(ang, dx, dy, rots[ang])
                if mejor is None or v > mejor[0]:
                    mejor = (v, ang, dx, dy)
    # afinar a 1 px
    v0, ang, dx0, dy0 = mejor
    for dy in range(dy0 - 2, dy0 + 3):
        for dx in range(dx0 - 2, dx0 + 3):
            v = prueba(ang, dx, dy, rots[ang])
            if v > mejor[0]:
                mejor = (v, ang, dx, dy)
    v, ang, dx, dy = mejor
    m = np.roll(np.roll(rots[ang], dy, 0), dx, 1)
    return v, ang, dx, dy, m


def recortar(img, pose):
    al_v = img[..., 3] > 128
    al_p = pose[..., 3] > 128
    iou, ang, dx, dy, m = encajar(al_v, al_p)
    tv, _ = cabeza(al_v)
    # lo que se permite: la silueta de la pose ensanchada; solo en la banda de
    # la capucha (por debajo, el cuerpo del video manda)
    deja = cv2.dilate(m.astype(np.uint8), np.ones((2 * ORLA + 1, 2 * ORLA + 1), np.uint8)) > 0
    banda = np.zeros_like(al_v)
    banda[:tv + ENCAJE[0] + 20] = True
    quita = banda & ~deja
    w = cv2.GaussianBlur(quita.astype(np.float32), (0, 0), SUAVE)
    out = img.copy()
    out[..., 3] = (img[..., 3].astype(np.float32) * (1.0 - np.clip(w, 0, 1))).astype(np.uint8)
    out[..., 3][quita] = 0
    quitado = int(((img[..., 3] > 128) & quita).sum())
    return out, iou, ang, dx, dy, quitado


def main():
    ent = sys.argv[1]
    sal = sys.argv[2] if len(sys.argv) > 2 else ent
    os.makedirs(sal, exist_ok=True)
    pose = pose_en_casilla()
    fs = sorted(glob.glob(os.path.join(ent, 'c_*.png')))
    if len(sys.argv) > 3:
        quiero = {int(v) for v in sys.argv[3].split(',')}
        fs = [f for f in fs if int(os.path.basename(f)[2:5]) in quiero]
    for f in fs:
        img = np.asarray(Image.open(f).convert('RGBA'))
        out, iou, ang, dx, dy, q = recortar(img, pose)
        Image.fromarray(out).save(os.path.join(sal, os.path.basename(f)))
        print('%s: encaje %.3f (giro %d, %+d,%+d), quitado %d px' % (os.path.basename(f), iou, ang, dx, dy, q))


if __name__ == '__main__':
    main()

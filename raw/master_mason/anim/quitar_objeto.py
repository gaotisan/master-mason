"""Quita de los fotogramas de un job el objeto de relleno de las referencias (el
muro de trepar y bajar, el sillar de subirse o el de empujar) y deja en su
sitio el croma, para seguir con el flujo de siempre (centrar, fondo, pulir).

Los objetos de las referencias (referencias_empujar.py, referencias_trepar_bajar.py)
son piedra clara low-poly y en los videos salen tal cual: quietos (muro, sillar
de subirse) o deslizandose en recto (sillar de empujar). Se quitan RESTANDO SU
IMAGEN, no por color: la barba y la capucha estan demasiado cerca de la piedra.

  1. Placa: la mediana de unos fotogramas en los que el personaje no tapa el
     objeto (--placa), y la mascara del objeto, lo que no es verde dentro de
     --caja (en video px).
  2. Si el objeto se mueve (--mueve): su desplazamiento en x por fotograma,
     con subpixel, encajando la placa sobre la parte del objeto que el
     personaje no tapa nunca (--encaje, fraccion de la derecha del objeto).
  3. En cada fotograma, dentro de la mascara (algo engordada): es personaje lo
     que se aparta de la placa mas de --umbral; lo demas es objeto y pasa a
     croma. Las motas sueltas de "personaje" dentro del objeto (ruido de
     compresion) se quitan si no tocan al personaje de fuera.
  4. El borde del personaje que estaba delante de la piedra lleva mezcla con
     ella (no con el verde): se recompone sobre el verde con su alfa estimado
     (C = a F + (1 - a) P, con F el color del personaje de al lado y P el de la
     placa), para que fondo.ps1 lo deshaga como cualquier otro borde y no quede
     un filo claro.

Salida: <job>/01b_sin_objeto/ (mismos nombres) y <job>/objeto.json (caja de la
placa, desplazamiento por fotograma, umbral).

  python quitar_objeto.py <job> --placa 1-20 --caja x0,y0,x1,y1 [--mueve] [--umbral 30]
"""
import argparse, json, os, shutil
import cv2
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

AQUI = os.path.dirname(os.path.abspath(__file__))


def rango(txt):
    out = []
    for parte in txt.split(','):
        if '-' in parte:
            a, b = parte.split('-'); out += list(range(int(a), int(b) + 1))
        else:
            out.append(int(parte))
    return out


def es_verde(a):
    a = a.astype(np.int16)
    return (a[..., 1] > 140) & (a[..., 1] - a[..., 0] > 70) & (a[..., 1] - a[..., 2] > 60)


def desplazar(img, dx):
    """Mueve una imagen dx px en x (subpixel, bilineal); lo que entra, 0."""
    M = np.float32([[1, 0, dx], [0, 1, 0]])
    return cv2.warpAffine(img, M, (img.shape[1], img.shape[0]), flags=cv2.INTER_LINEAR,
                          borderMode=cv2.BORDER_CONSTANT, borderValue=0)


def seguir(frames, placa, masc, caja, encaje, maximo):
    """dx por fotograma (subpixel) del objeto respecto a la placa: diferencia
    media sobre la parte derecha del objeto (la que no tapa el personaje),
    buscando cerca del anterior y afinando con una parabola."""
    x0, y0, x1, y1 = caja
    xs = np.where(masc.any(0))[0]
    ox0, ox1 = xs.min(), xs.max()
    corte = int(ox1 - (ox1 - ox0) * encaje)
    zona = masc.copy()
    zona[:, :corte] = False
    zona = ndi.binary_erosion(zona, iterations=3)
    ys, xx = np.where(zona)
    P = placa.astype(np.float32)
    dxs = []
    previo = 0
    for k, a in enumerate(frames):
        a = a.astype(np.float32)
        errs = {}
        for d in range(previo - 3, previo + maximo + 1):
            xd = xx + d
            ok = (xd >= 0) & (xd < a.shape[1])
            errs[d] = float(np.abs(a[ys[ok], xd[ok]] - P[ys[ok], xx[ok]]).mean())
        mejor = min(errs, key=errs.get)
        # subpixel: parabola por los tres de alrededor
        e0, e1, e2 = errs.get(mejor - 1, errs[mejor]), errs[mejor], errs.get(mejor + 1, errs[mejor])
        den = e0 - 2 * e1 + e2
        fr = 0.5 * (e0 - e2) / den if den > 1e-6 else 0.0
        dxs.append(mejor + float(np.clip(fr, -0.5, 0.5)))
        previo = mejor
    return np.array(dxs), corte


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('job')
    ap.add_argument('--placa', required=True, help='fotogramas para la placa, "1-20"')
    ap.add_argument('--caja', required=True, help='x0,y0,x1,y1 del objeto en video px (en la placa)')
    ap.add_argument('--mueve', action='store_true', help='el objeto se desliza en x')
    ap.add_argument('--encaje', type=float, default=0.5, help='fraccion derecha del objeto para seguirlo')
    ap.add_argument('--maximo', type=int, default=8, help='px por fotograma que puede avanzar como mucho')
    ap.add_argument('--umbral', type=float, default=30.0)
    ap.add_argument('--motas', type=int, default=40, help='trozos de personaje dentro del objeto mas pequenos que esto, fuera')
    a = ap.parse_args()

    carpeta = os.path.join(AQUI, a.job)
    ent = os.path.join(carpeta, '01_frames')
    sal = os.path.join(carpeta, '01b_sin_objeto')
    nombres = sorted(f for f in os.listdir(ent) if f.endswith('.png'))
    leer = lambda n: np.asarray(Image.open(os.path.join(ent, n)).convert('RGB'))
    frames = [leer(n) for n in nombres]
    h, w = frames[0].shape[:2]

    placa = np.median(np.stack([frames[k - 1] for k in rango(a.placa)]), 0).astype(np.uint8)
    # el verde del propio video (no el #24D732 de la referencia: Flow lo cambia
    # un poco), para que lo rellenado no se distinga del fondo
    verde = np.median(placa[es_verde(placa)], 0).astype(np.float32)
    x0, y0, x1, y1 = map(int, a.caja.split(','))
    masc = np.zeros((h, w), bool)
    masc[y0:y1 + 1, x0:x1 + 1] = ~es_verde(placa[y0:y1 + 1, x0:x1 + 1])
    # el objeto es la mancha mas grande (fuera migas del borde de la caja)
    lab, n = ndi.label(masc)
    if n > 1:
        tam = ndi.sum(masc, lab, range(1, n + 1))
        masc = lab == (np.argmax(tam) + 1)
    masc = ndi.binary_fill_holes(masc)
    ys, xs = np.where(masc)
    print('%s: objeto %d px, caja x %d-%d y %d-%d' % (a.job, masc.sum(), xs.min(), xs.max(), ys.min(), ys.max()))

    if a.mueve:
        dxs, corte = seguir(frames, placa, masc, (x0, y0, x1, y1), a.encaje, a.maximo)
        print('desplazamiento: total %.1f px; por fotograma max %.2f' % (dxs[-1] - dxs[0], np.abs(np.diff(dxs)).max()))
    else:
        dxs = np.zeros(len(frames))

    if os.path.isdir(sal):
        shutil.rmtree(sal)
    os.makedirs(sal)
    placa_f = placa.astype(np.float32)
    masc_u8 = masc.astype(np.uint8) * 255
    resumen = []
    for k, (nombre, fr) in enumerate(zip(nombres, frames)):
        dx = float(dxs[k])
        P = desplazar(placa_f, dx) if dx else placa_f
        M = desplazar(masc_u8.astype(np.float32), dx) > 127 if dx else masc
        Mg = ndi.binary_dilation(M, iterations=2)
        F = fr.astype(np.float32)
        dif = np.abs(F - P).max(-1)
        pers = Mg & (dif > a.umbral) & ~es_verde(fr)
        # dentro del objeto, el personaje tiene que tocar al de fuera; las motas no
        fuera = ~Mg & ~es_verde(fr)
        lab, n = ndi.label(pers)
        if n:
            toca = np.unique(lab[ndi.binary_dilation(fuera, iterations=2) & pers])
            tam = ndi.sum(pers, lab, range(1, n + 1))
            vale = np.zeros(n + 1, bool)
            vale[toca[toca > 0]] = True
            vale[1:] |= tam >= a.motas * 4
            pers = vale[lab] & pers
        pers = ndi.binary_closing(pers, iterations=1) & Mg | (pers & Mg)
        objeto = Mg & ~pers
        out = F.copy()
        out[objeto] = verde
        # borde del personaje contra la piedra: recomponer sobre el verde
        borde = pers & ndi.binary_dilation(objeto, iterations=2)
        interior = pers & ~ndi.binary_dilation(objeto, iterations=3)
        interior |= fuera & ~ndi.binary_dilation(es_verde(fr), iterations=2)
        if borde.any() and interior.any():
            _, (iy, ix) = ndi.distance_transform_edt(~interior, return_indices=True)
            by, bx = np.where(borde)
            Fc = F[iy[by, bx], ix[by, bx]]
            Pc = P[by, bx]
            C = F[by, bx]
            d = Fc - Pc
            al = np.clip(((C - Pc) * d).sum(-1) / np.maximum((d * d).sum(-1), 1.0), 0, 1)
            al = np.where((d * d).sum(-1) < 400, (dif[by, bx] > a.umbral).astype(np.float32), al)
            out[by, bx] = al[:, None] * Fc + (1 - al[:, None]) * verde
        Image.fromarray(out.round().clip(0, 255).astype(np.uint8)).save(os.path.join(sal, nombre))
        resumen.append(int((Mg & pers).sum()))
    json.dump({'caja': [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())], 'verde': [round(float(v), 1) for v in verde],
               'dx': [round(float(v), 3) for v in dxs], 'umbral': a.umbral, 'placa': a.placa,
               'personaje_sobre_objeto': resumen},
              open(os.path.join(carpeta, 'objeto.json'), 'w'), indent=1)
    print('escrito %s (%d fotogramas); personaje sobre el objeto: max %d px' % (sal, len(nombres), max(resumen)))


if __name__ == '__main__':
    main()

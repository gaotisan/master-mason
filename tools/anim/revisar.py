"""Revisa las animaciones de Magnus tal como las ve el juego y avisa de defectos.

Lee las rejillas de 05_salida con la lista de _spriteframes.ANIMACIONES (los
mismos fotogramas y en el mismo orden que el SpriteFrames) y coloca cada
fotograma como lo dibuja Godot: todas las casillas acaban 15 px por debajo del
nodo (offset_comun y offset_salto_correr lo dejan asi) y estan centradas en x.
Todo en px de la hoja, que son px del juego.

Por animacion:
  saltos     pasos (distancia entre fotogramas seguidos) de mas de SALTO veces
             la mediana de esa animacion: un fotograma que no casa
  cierre     en los bucles, del ultimo al primero, en pasos
  suelo      lo mas bajo del dibujo: cambios de mas de SUELO px de un fotograma
             al siguiente (pies que se hunden o flotan de golpe)
  eje        el centro del tronco (40 % de arriba del dibujo): cambios de mas de
             EJE px de un fotograma al siguiente (tiembla o se desplaza)
  borde      dibujo tocando el borde de la casilla: recortado
  motas      manchas sueltas de menos de MOTA px aparte del personaje
  fondo      pixeles con color del croma (magenta o verde) que se quedaron
Y los enlaces entre animaciones que encadena magnus.gd, con los fotogramas por
los que entra: distancia en pasos de la mas movida de las dos, salto del suelo y
del eje, y cambio de color de la tunica.

Distancia: 10 x la media de |A - B| en RGB premultiplicado (0-1) sobre la caja
de los dos, la de todo el proyecto.

    python revisar.py                 informe
    python revisar.py --tiras carpeta ademas, una tira por animacion con los
                                      fotogramas marcados, para mirarlos
"""
import os, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _spriteframes as sf

SALTO = 2.5
SUELO = 3
EJE = 3
MOTA = 40
LIENZO = (420, 440)          # ancho, alto; el pie de las casillas en la fila BASE
BASE = 430


def fotogramas(anim):
    nombre, hoja, n, cols = anim[:4]
    casilla = tuple(anim[6]) if len(anim) > 6 and anim[6] else sf.CASILLA
    indices = list(anim[7]) if len(anim) > 7 and anim[7] else list(range(n))
    im = np.asarray(Image.open(sf._rejilla(hoja)).convert('RGBA'))
    cw, ch = casilla
    celdas = []
    for k in indices:
        c = im[(k // cols) * ch:(k // cols + 1) * ch, (k % cols) * cw:(k % cols + 1) * cw]
        lienzo = np.zeros((LIENZO[1], LIENZO[0], 4), np.uint8)
        x0, y0 = (LIENZO[0] - cw) // 2, BASE - ch
        lienzo[y0:y0 + ch, x0:x0 + cw] = c
        celdas.append((lienzo, c))
    return celdas


def pm(a):
    f = a.astype(float) / 255
    return np.concatenate([f[..., :3] * f[..., 3:], f[..., 3:]], 2)


def d(a, b):
    m = (a[..., 3] > 0) | (b[..., 3] > 0)
    ys, xs = np.where(m)
    c = (slice(ys.min(), ys.max() + 1), slice(xs.min(), xs.max() + 1))
    return 10 * np.abs(a[c][..., :3] - b[c][..., :3]).mean()


def medidas(lienzo):
    a = lienzo[..., 3] > 128
    ys, xs = np.where(a)
    alto = ys.max() - ys.min()
    tronco = (ys < ys.min() + 0.4 * alto)
    return int(ys.max()), float(xs[tronco].mean())


def tunica(lienzo):
    rgb = lienzo[..., :3].astype(float) / 255
    mx, mn = rgb.max(-1), rgb.min(-1)
    s = (mx - mn) / np.maximum(mx, 1e-6)
    t = (lienzo[..., 3] > 230) & (rgb[..., 0] > rgb[..., 1]) & (rgb[..., 1] >= rgb[..., 2] - 0.02) \
        & (s > 0.12) & (mx > 0.15) & (mx < 0.85)
    return rgb[t].mean(0) * 255 if t.any() else np.zeros(3)


def revisar_celda(c):
    """Borde, motas y restos de croma de una casilla."""
    al = c[..., 3]
    borde = bool(al[0].any() or al[-1].any() or al[:, 0].any() or al[:, -1].any())
    lab, n = ndimage.label(al > 0, structure=np.ones((3, 3)))
    motas = 0
    if n > 1:
        tam = ndimage.sum(al > 0, lab, range(1, n + 1))
        motas = int(sum(1 for t in tam if t < MOTA and t < tam.max()))
    r, g, b = [c[..., i].astype(int) for i in range(3)]
    croma = (al > 40) & (((r > 180) & (b > 140) & (g < r - 70)) | ((g > r + 50) & (g > b + 50)))
    return borde, motas, int(croma.sum())


# Enlaces de magnus.gd: (de, fotograma o None = cualquiera, a, fotograma, voltear)
ENLACES = [
    ('reposo', None, 'arranque_andar', 0, False),
    ('arranque_andar', 18, 'andar', 19, False),
    ('andar', None, 'parada_andar', 0, False),
    ('parada_andar', -1, 'reposo', 0, False),
    ('reposo', None, 'arranque_correr', 0, False),
    ('arranque_correr', 22, 'correr', 9, False),
    ('correr', None, 'parada_correr', 0, False),
    ('parada_correr', -1, 'reposo', 0, False),
    ('andar', None, 'saltar', 0, False),
    ('saltar', -1, 'reposo', 0, False),
    ('reposo', None, 'salto_parado', 0, False),
    ('salto_parado', -1, 'reposo', 0, False),
    ('correr', None, 'salto_correr', 0, False),
    ('salto_correr', -1, 'aterrizaje_correr', 0, False),
    ('aterrizaje_correr', -1, 'reposo', 0, False),
    ('reposo', None, 'giro', 0, False),
    ('giro', -1, 'reposo', 0, True),
    ('cayendo', None, 'caida', 0, False),
    ('caida', -1, 'tumbado', 0, False),
    ('tumbado', 0, 'levantarse', 0, False),
    ('levantarse', -1, 'reposo', 0, False),
    ('reposo', None, 'agacharse', 0, False),
    ('agacharse', -1, 'agachado', 12, False),
    ('agachado', 12, 'incorporarse', 0, False),
    ('incorporarse', -1, 'reposo', 0, False),
    ('agachado', None, 'arranque_agachado', 0, False),
    ('arranque_agachado', -1, 'andar_agachado', 21, False),
    ('andar_agachado', 41, 'parada_agachado', 0, False),
    ('parada_agachado', -1, 'agachado', 5, False),
    ('agachado', None, 'giro_agachado', 0, False),
    ('giro_agachado', -1, 'agachado', 12, True),
]


def main():
    tiras = sys.argv[sys.argv.index('--tiras') + 1] if '--tiras' in sys.argv else None
    if tiras:
        os.makedirs(tiras, exist_ok=True)
    datos = {}
    for anim in sf.ANIMACIONES:
        nombre, bucle = anim[0], anim[5]
        celdas = fotogramas(anim)
        P = [pm(l) for l, _ in celdas]
        M = [medidas(l) for l, _ in celdas]
        pasos = [d(P[i], P[i + 1]) for i in range(len(P) - 1)]
        med = float(np.median(pasos)) if pasos else 0.0
        datos[nombre] = (celdas, P, M, med)
        avisos = []
        for i, p in enumerate(pasos):
            if med > 0 and p > SALTO * med:
                avisos.append('salto %d->%d (%.1f pasos)' % (i, i + 1, p / med))
        if bucle and len(P) > 1:
            c = d(P[-1], P[0]) / med if med else 0
            if c > SALTO:
                avisos.append('cierre %.1f pasos' % c)
        for i in range(len(M) - 1 + (1 if bucle else 0)):
            j = (i + 1) % len(M)
            if abs(M[j][0] - M[i][0]) > SUELO:
                avisos.append('suelo %d->%d %+d px' % (i, j, M[j][0] - M[i][0]))
            if abs(M[j][1] - M[i][1]) > EJE:
                avisos.append('eje %d->%d %+.1f px' % (i, j, M[j][1] - M[i][1]))
        for i, (_, c) in enumerate(celdas):
            borde, motas, croma = revisar_celda(c)
            if borde:
                avisos.append('borde en %d' % i)
            if motas:
                avisos.append('%d motas en %d' % (motas, i))
            if croma > 3:
                avisos.append('%d px de croma en %d' % (croma, i))
        suelos = [m[0] for m in M]
        print('%-18s %3d f  paso %.3f  suelo %d-%d (pie de casilla %d)  %s' % (
            nombre, len(P), med, min(suelos), max(suelos), BASE,
            '; '.join(avisos) if avisos else 'bien'))
        if tiras:
            ancho = 110
            t = Image.new('RGB', (ancho * len(celdas), 150), (40, 44, 52))
            for i, (l, _) in enumerate(celdas):
                im = Image.new('RGBA', LIENZO, (40, 44, 52, 255))
                im.alpha_composite(Image.fromarray(l))
                t.paste(im.convert('RGB').resize((ancho, int(ancho * LIENZO[1] / LIENZO[0])))
                        .crop((0, 0, ancho, 150)), (i * ancho, 0))
                ImageDraw.Draw(t).text((i * ancho + 2, 2), str(i), fill=(255, 255, 0))
            t.save(os.path.join(tiras, nombre + '.png'))
    print()
    print('Enlaces (distancia en pasos de la mas movida de las dos; suelo y eje en px; tunica):')
    for de, fd, a, fa, voltear in ENLACES:
        if de not in datos or a not in datos:
            continue
        P1, M1 = datos[de][1], datos[de][2]
        P2, M2 = datos[a][1], datos[a][2]
        # En pasos de la mas movida de las dos: un bucle casi quieto (reposo,
        # agachado) tiene pasos minusculos y cualquier enlace saldria enorme.
        med = max(datos[de][3], datos[a][3])
        destino = P2[fa]
        if voltear:
            destino = destino[:, ::-1]
        if fd is None:
            ds = [d(p, destino) for p in P1]
            i = int(np.argmin(ds))
        else:
            i = fd % len(P1)
        v = d(P1[i], destino) / med if med else 0
        c1, c2 = tunica(datos[de][0][i][0]), tunica(datos[a][0][fa][0])
        dc = float(np.abs(c1 - c2).max())
        eje2 = (LIENZO[0] - 1 - M2[fa][1]) if voltear else M2[fa][1]
        marca = '  <-' if v > SALTO or abs(M2[fa][0] - M1[i][0]) > SUELO or abs(eje2 - M1[i][1]) > EJE or dc > 4 else ''
        print('  %-18s %3s -> %-18s %3d   %.1f pasos  suelo %+d  eje %+.1f  tunica %.1f%s' % (
            de, i, a, fa, v, M2[fa][0] - M1[i][0], eje2 - M1[i][1], dc, marca))


if __name__ == '__main__':
    main()

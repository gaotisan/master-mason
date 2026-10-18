"""Quita el destello de los pies al aterrizar (sprites 46-61) en 04_limpios.

Al caer, el video ilumina los pies de golpe: su brillo medio (luminancia de la
piel del pie) pasa de 65 en el sprite 45 a 99 en el 46 y a 123 en el 48, y
tarda hasta el 62 en volver a su 73 de reposo. El resto del cuerpo no se mueve
(capucha 127-128, abrigo 86-89 en todo el tramo): es cosa de los pies y del
polvo que les cae encima. A 60 fps son 0,27 s de pies encendidos: destellan.

Dos arreglos, siempre partiendo de _pies_sin_igualar/ (copia de 04_limpios de
antes de este script):

1. POLVO (46-52). Lo que dejo limpia_polvo.py: gris verdoso claro
   (r-g <= 10, g-b <= 14, luminancia > 72) y cualquier no-piel muy clara
   (luminancia > 95: la pierna es gris oscuro) alrededor de los pies. Por
   manchas conexas: la que queda por FUERA del cuerpo (la mayor parte de su
   borde da a transparente) se borra; la que cae encima del pie se repinta con
   lo opaco de alrededor. Lo que queda por encima del pie sin dar a fuera (el filo claro de
   la pierna) no se toca: esta en todos los sprites. El reborde oliva del bajo
   del abrigo (g-b de 17 a 24) no entra en el criterio.

2. BRILLO (46-61). Ganancia por canal sobre la piel del pie para llevar su
   media a una rampa entre la del sprite 45 y la del 62, que son los vecinos
   buenos. Pesa segun lo calido que es el pixel (r-g de 6 a 14), asi que el
   tobillo, que pasa a gris de pierna, se funde sin costura.

El pie se encuentra como las manchas de piel (r-g > 10) de las 40 filas de
abajo que llegan hasta el suelo y tocan la pierna (gris oscuro neutro): la
punta del abrigo, que en 53-58 baja casi hasta el suelo y es del mismo marron
que la piel, no toca la pierna y se descarta.

    python igualar_pies.py            # aplica
    python igualar_pies.py --medir    # solo mide, no escribe
"""
import glob, os, shutil, sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

aqui = os.path.dirname(os.path.abspath(__file__))
carpeta = os.path.join(aqui, '04_limpios')
copia = os.path.join(aqui, '_pies_sin_igualar')

POLVO = range(46, 53)
GANANCIA = range(46, 62)
ANTES, DESPUES = 45, 62          # vecinos buenos que marcan la rampa


def cargar(n):
    return np.asarray(Image.open(os.path.join(copia, f'c_{n:02d}.png')).convert('RGBA')).astype(float)


def pies_de(im):
    r, g, al = im[..., 0], im[..., 1], im[..., 3]
    ys, _ = np.where(al > 200)
    suelo = ys.max()
    filas = np.broadcast_to(np.arange(im.shape[0])[:, None], al.shape)
    tope = suelo - 40
    piel = (al > 0) & (r - g > 10) & (filas >= tope)
    lab, nl = ndi.label(piel)
    idx = np.arange(1, nl + 1)
    if not nl:
        return np.zeros_like(piel)
    abajo = ndi.maximum(filas, lab, idx)
    tam = ndi.sum(piel, lab, idx)
    b = im[..., 2]
    pierna = (al > 200) & (np.abs(r - g) <= 10) & (np.abs(g - b) <= 12) & (lum(im) < 80)
    toca = ndi.maximum(ndi.binary_dilation(pierna, iterations=2), lab, idx)
    buenas = [l for l, lo, t, tp in zip(idx, abajo, tam, toca) if lo >= suelo - 15 and t > 30 and tp]
    return np.isin(lab, buenas)


def media_pie(im, pies):
    m = pies & (im[..., 3] > 200)
    return im[m][:, :3].mean(0)


def lum(im):
    return 0.299 * im[..., 0] + 0.587 * im[..., 1] + 0.114 * im[..., 2]


def quitar_polvo(im, pies):
    r, g, b, al = im[..., 0], im[..., 1], im[..., 2], im[..., 3]
    ys, xs = np.where(pies)
    filas = np.arange(im.shape[0])[:, None]
    cols = np.arange(im.shape[1])[None, :]
    zona = (filas >= 600) & (cols >= xs.min() - 30) & (cols <= xs.max() + 70)
    claro = lum(im)
    cand = (al > 0) & zona & (r - g <= 10) & (((g - b <= 14) & (claro > 72)) | (claro > 95))
    lab, nl = ndi.label(cand, structure=np.ones((3, 3)))
    cerca_pie = ndi.binary_dilation(pies, iterations=3)
    fuera = np.zeros_like(cand)
    encima = np.zeros_like(cand)
    for l in range(1, nl + 1):
        m = lab == l
        aro = ndi.binary_dilation(m, structure=np.ones((3, 3))) & ~m
        transparente = (al[aro] == 0).mean() if aro.any() else 1.0
        if transparente > 0.5:
            fuera |= m
        elif (m & cerca_pie).sum() > 0.5 * m.sum():
            encima |= m
    # entre las piernas quedan motas muy claras (luminancia > 95) que no son ni
    # de fuera ni del pie; el filo claro normal de la pierna no pasa de 92
    encima |= cand & ~fuera & (claro > 95)
    im[..., 3][fuera] = 0
    return fuera, encima


def main():
    medir = '--medir' in sys.argv
    if not os.path.isdir(copia):
        shutil.copytree(carpeta, copia)
    c_antes = media_pie(cargar(ANTES), pies_de(cargar(ANTES)))
    c_despues = media_pie(cargar(DESPUES), pies_de(cargar(DESPUES)))
    for n in GANANCIA:
        im = cargar(n)
        pies = pies_de(im)
        antes = media_pie(im, pies)
        fuera = encima = np.zeros(pies.shape, bool)
        if n in POLVO:
            fuera, encima = quitar_polvo(im, pies)
            pies = pies & ~encima
        t = (n - ANTES) / (DESPUES - ANTES)
        objetivo = c_antes * (1 - t) + c_despues * t
        ganancia = objetivo / media_pie(im, pies)
        r, g = im[..., 0], im[..., 1]
        peso = np.clip((r - g - 6) / 8, 0, 1) * ndi.binary_dilation(pies, iterations=2)
        im[..., :3] = im[..., :3] * (1 + peso[..., None] * (ganancia - 1))
        if encima.any():
            # repintar el polvo que cae encima del pie con lo que tiene alrededor
            # (piel ya igualada, o gris de pierna en el tobillo), nunca con vacio
            fuente = (im[..., 3] > 200) & ~encima
            suma = np.stack([ndi.uniform_filter(im[..., c] * fuente, 9) for c in range(3)], -1)
            cuenta = ndi.uniform_filter(fuente.astype(float), 9)[..., None]
            relleno = suma / np.maximum(cuenta, 1e-6)
            im[..., :3][encima] = relleno[encima]
        despues = media_pie(im, pies_de(im))
        print(f'{n:2d}  pie antes {np.round(antes).astype(int)} lum {lum(antes[None, None])[0, 0]:5.1f}'
              f'  -> {np.round(despues).astype(int)} lum {lum(despues[None, None])[0, 0]:5.1f}'
              f'  (objetivo {lum(objetivo[None, None])[0, 0]:5.1f})  polvo fuera {fuera.sum()} encima {encima.sum()}')
        if not medir:
            Image.fromarray(np.clip(np.round(im), 0, 255).astype(np.uint8), 'RGBA').save(
                os.path.join(carpeta, f'c_{n:02d}.png'))


if __name__ == '__main__':
    main()

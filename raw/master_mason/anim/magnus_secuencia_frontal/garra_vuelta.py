"""La garra por delante de la bola en la vuelta con baston (2026-10-17).

El usuario: en la vuelta con el baston en la mano "la bola se vuelve transparente,
deja verse el azul de la capucha". En vuelta_cb 8-11 el baston pasa por delante de
la cara: el hueco de la garra del video deja ver la capucha, y la bola, que va
detras del sprite (los dedos de la garra, dibujados en el, le quedan delante), queda
tapada por ella.

En esos fotogramas PeregrinoFrontal pone delante del cuerpo una copia de la esfera
(sin halo) y, encima, este recorte del propio fotograma: lo que hay dentro del disco
de la bola salvo la capucha (y la barba, del mismo gris), o sea los dedos y la
sombra de la garra. Fuera del disco no hace falta: el sprite ya esta debajo.

Los fotogramas se eligen solos: los que tienen capucha dentro del disco de la bola.
Recortes a escala de hoja (la mitad del master, premultiplicado como hoja.ps1),
alineados con los texeles de la casilla (292x400).
Sale assets/characters/magnus/vuelta_garra/<anim>_NNN.png y vuelta_garra.json:
{anim: {fotograma: [x, y]}} esquina del recorte en px de hoja desde el centro de la
casilla.
    python raw/master_mason/anim/magnus_secuencia_frontal/garra_vuelta.py
"""
import json, os
import numpy as np, cv2
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
PROY = os.path.abspath(os.path.join(AQUI, '..', '..', '..', '..'))
SALIDA = os.path.join(PROY, 'assets', 'characters', 'magnus')
SEC = os.path.join(SALIDA, 'secuencia_frontal.json')
CASILLA = (292, 400)        # hoja
RADIO = 11.22               # la esfera del Orbe en px de hoja (orbe_cuadro 44 px x 1,5 x radio 0,34)
LADO = 40                   # el recorte (px de hoja)
MIN_CAPUCHA = 80            # px de master de capucha dentro del disco para tomar el fotograma
S_CAPUCHA = (40, 70)        # saturacion (OpenCV, 0-255): por debajo capucha / barba, por encima madera; entre, a medias
ANIMS = ['vuelta_cb']


def madera(a):
    """0..1: lo que es garra (pardo saturado, o sombra oscura) frente a capucha y barba
    (grises: poca saturacion y claros). Con el criterio de canales se colaban grises
    calidos de la capucha y salian encima de la bola como una mancha azulada."""
    hsv = cv2.cvtColor(np.ascontiguousarray(a[..., :3]).astype(np.uint8), cv2.COLOR_RGB2HSV)
    s, v = hsv[..., 1].astype(float), hsv[..., 2].astype(float)
    m = np.clip((s - S_CAPUCHA[0]) / (S_CAPUCHA[1] - S_CAPUCHA[0]), 0, 1)
    return np.maximum(m, (v < 60).astype(float))


def capucha(a):
    return (a[..., 3] > 128) & (madera(a) < 0.5)


def main():
    sec = json.load(open(SEC))
    e = float(sec['escala_bola'])
    datos = {}
    os.makedirs(os.path.join(SALIDA, 'vuelta_garra'), exist_ok=True)
    for anim in ANIMS:
        filas = sec['orbe'][anim]
        k = 0
        while True:
            f = os.path.join(AQUI, '04_limpios', '%s_%03d.png' % (anim, k))
            if not os.path.exists(f):
                break
            a = np.asarray(Image.open(f).convert('RGBA'))
            ox, oy = filas[min(k, len(filas) - 1)][:2]
            # en master
            mx, my = 2 * (ox + CASILLA[0] / 2), 2 * (oy + CASILLA[1] / 2)
            ys, xs = np.mgrid[0:a.shape[0], 0:a.shape[1]]
            disco = np.hypot(xs - mx, ys - my) < 2 * RADIO * e
            n = int((disco & capucha(a)).sum())
            if n >= MIN_CAPUCHA:
                # a hoja, premultiplicado (como hoja.ps1: area)
                al = a[..., 3:] / 255.0
                pre = np.dstack([a[..., :3] * al, al]).astype(np.float32)
                pre = cv2.resize(pre, (CASILLA[0], CASILLA[1]), interpolation=cv2.INTER_AREA)
                h = pre[..., 3:]
                rgb = pre[..., :3] / np.maximum(h, 1e-4)
                hoja = np.dstack([rgb, h * 255]).clip(0, 255)
                # el recorte, alineado con los texeles: esquina entera desde el centro
                x0 = int(np.floor(ox)) - LADO // 2
                y0 = int(np.floor(oy)) - LADO // 2
                c = hoja[y0 + CASILLA[1] // 2:y0 + CASILLA[1] // 2 + LADO, x0 + CASILLA[0] // 2:x0 + CASILLA[0] // 2 + LADO].copy()
                yy, xx = np.mgrid[0:LADO, 0:LADO]
                # centro de cada texel frente al de la bola
                dist = np.hypot(xx + x0 + 0.5 - ox, yy + y0 + 0.5 - oy)
                dentro = np.clip(RADIO * e + 1.0 - dist, 0.0, 1.0)           # borde de 1 px
                c[..., 3] *= dentro * madera(c)
                c[c[..., 3] < 1] = 0
                nombre = '%s_%03d.png' % (anim, k)
                Image.fromarray(c.astype(np.uint8), 'RGBA').save(os.path.join(SALIDA, 'vuelta_garra', nombre))
                datos.setdefault(anim, {})[str(k)] = [x0, y0]
                print(anim, k, 'capucha en el disco', n, 'px de master')
            k += 1
    json.dump(datos, open(os.path.join(SALIDA, 'vuelta_garra.json'), 'w'), indent=1)


if __name__ == '__main__':
    main()

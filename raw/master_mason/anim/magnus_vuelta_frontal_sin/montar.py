"""Lleva la vuelta SIN baston (de frente a de espaldas) a la casilla de Magnus.

Copia de magnus_vuelta_frontal/montar.py (ver alli el metodo): aqui el video es
_fuentes/Pilgrim_turns_around_on_green_20261008093222.mp4 (Veo, 1280x720, 24
fps, 240 f; referencias referencia_vuelta_sin_frente/espalda.png), registrado
contra andar_frente_sin y andar_espalda_sin, casilla comun 584x720.
03_seleccion = video 40-120.

--- (texto de la original) ---

Video: _fuentes/Old_pilgrim_turning_around_20261007230523.mp4 (Flow, 1280x720,
24 fps, 240 f), hecho con referencia_vuelta_frente.png (andar_frente c_018, con
la garra puesta) y referencia_vuelta_espalda.png (andar_espalda c_005) de
inicio y fin, a escala de master en 1920x1080 (video x1,5 ~ master). Camara
quieta, pero en los "dos segundos quieto" del principio da un pasito hacia la
camara (crece un 8 %), asi que no vale una escala fija.

Registro: el primer fotograma del tramo se encaja (escala y desplazamiento,
busqueda en rejilla) contra el andar de frente y el ultimo contra el de
espaldas, midiendo de la cintura para abajo (sin la punta del baston, que en
el andar de frente va con la garra puesta por encima). Entre medias, escala y
desplazamiento interpolados en el tiempo. (Medir tamano por el area o el suelo
por el pixel mas bajo fallaba: la contera del baston es lo mas bajo y el brazo
abierto infla el area.)
Lee _sin_normalizar/ (croma.py sobre 03_seleccion = video 30-120) y escribe
04_limpios/c_###.png.
    python montar.py <primero> <ultimo>    (fotogramas del video)
"""
import glob, os, sys
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
SEL0 = 40                                  # 03_seleccion empieza en el 30
A, B = int(sys.argv[1]), int(sys.argv[2])
X0, Y0 = 639.3, 590.0                      # punto del video que se lleva a (292, SUELO)
# casilla propia, mas alta que la comun (584x720): al empezar el giro la garra
# sube por encima y se cortaba. Mismo margen de suelo abajo (43 px).
ALTO = 720
SUELO = ALTO - 43


def video(i):
    return Image.open(os.path.join(AQUI, '_sin_normalizar', 'p_%02d.png' % (i - SEL0 + 1))).convert('RGBa')


def poner(im, esc, dx, dy, filtro=Image.LANCZOS):
    im = im.resize((round(im.width * esc), round(im.height * esc)), filtro)
    c = Image.new('RGBa', (584, ALTO), (0, 0, 0, 0))
    c.paste(im, (round(292 - X0 * esc + dx), round(SUELO - Y0 * esc + dy)))
    return c


def premult(p):
    """A media resolucion (el registro va a media; el montaje, entero)."""
    a = np.asarray(Image.open(p).convert('RGBa').resize((292, 360), Image.BILINEAR)).astype(np.float32) / 255
    return a


def dist(a, b):
    return 10 * abs(a[75:] - b[75:]).mean()


def registrar(im, destinos):
    """(distancia, escala, dx, dy, fotograma) del mejor encaje: rejilla gruesa y fina,
    todo a media resolucion (desplazamientos en px de master, de 2 en 2)."""
    peq = im.resize((im.width // 2, im.height // 2), Image.BILINEAR)

    def prueba(esc, dx, dy, js):
        r = peq.resize((round(peq.width * esc), round(peq.height * esc)), Image.BILINEAR)
        c = Image.new('RGBa', (292, 360), (0, 0, 0, 0))
        c.paste(r, (round(146 - X0 / 2 * esc + dx / 2), round(338.5 - Y0 / 2 * esc + dy / 2)))
        c = np.asarray(c).astype(np.float32) / 255
        return min((dist(c, destinos[j]), esc, dx, dy, j + 1) for j in js)
    todos = range(len(destinos))
    mejor = min(prueba(e, x, y, todos[::3]) for e in np.arange(1.36, 1.58, 0.02)
                for x in range(-20, 21, 4) for y in range(-24, 25, 4))
    _, e0, x0, y0, j0 = mejor
    return min(prueba(e, x, y, todos) for e in np.arange(e0 - 0.015, e0 + 0.016, 0.005)
               for x in range(x0 - 4, x0 + 5, 2) for y in range(y0 - 4, y0 + 5, 2))


FRENTE = [premult(p) for p in sorted(glob.glob(os.path.join(ANIM, 'magnus_andar_frente_sin', '04_limpios', 'c_*.png')))]
ESPALDA = [premult(p) for p in sorted(glob.glob(os.path.join(ANIM, 'magnus_andar_espalda_sin', '04_limpios', 'c_*.png')))]
ini = registrar(video(A), FRENTE)
fin = registrar(video(B), ESPALDA)
print('entrada: video %d ~ andar_frente_sin c_%03d a %.3f (escala %.3f, dx %d, dy %d)' % (A, ini[4], ini[0], ini[1], ini[2], ini[3]))
print('salida:  video %d ~ andar_espalda_sin c_%03d a %.3f (escala %.3f, dx %d, dy %d)' % (B, fin[4], fin[0], fin[1], fin[2], fin[3]))

SAL = os.path.join(AQUI, '04_limpios')
for f in glob.glob(os.path.join(SAL, '*.png')):
    os.remove(f)
for i in range(A, B + 1):
    t = (i - A) / max(1, B - A)
    esc, dx, dy = (ini[k] * (1 - t) + fin[k] * t for k in (1, 2, 3))
    poner(video(i), esc, dx, dy).convert('RGBA').save(os.path.join(SAL, 'c_%03d.png' % (i - A + 1)))
open(os.path.join(AQUI, 'enganches.txt'), 'w').write(
    'entrada %d c_%03d %.3f %.3f %d %d\nsalida %d c_%03d %.3f %.3f %d %d\n' % (A, *ini[4:], *ini[:4], B, *fin[4:], *fin[:4]))
print(B - A + 1, 'sprites en 04_limpios')

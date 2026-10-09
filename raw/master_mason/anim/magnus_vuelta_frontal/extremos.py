"""Registra los extremos del video de la vuelta (1-30 y 200-240) y busca por
donde empalmarlos con el giro (42-90) sin el rato quieto del medio.

El video se pidio con andar_frente c_018 (con la garra) de primer fotograma y
andar_espalda c_005 de ultimo: el 1 casa con c_018 a 0,067 y el 240 con c_005 a
0,054 (lo que cambia un fotograma normal). Entre medias Veo pasa poco a poco de
nuestro dibujo al suyo, sin doble imagen: eso es lo que se aprovecha para entrar
y salir de la vuelta sin fundido.

Cada fotograma se registra (escala y desplazamiento, media resolucion) contra
el anterior ya colocado (busqueda fina alrededor de sus parametros), arrancando
del 1 contra c_018 y del 240 contra c_005. Luego, distancia de cada uno de la
entrada con cada uno del arranque del giro (42-56) y de la salida con el final
(80-90). Escribe registro.json.
    python extremos.py
"""
import json, os
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
X0, Y0 = 639.3, 590.0
ENG = json.load(open(os.path.join(AQUI, 'registro_giro.json'))) if os.path.exists(os.path.join(AQUI, 'registro_giro.json')) else None


_PEQ = {}


def colocar(i, esc, dx, dy):
    if i not in _PEQ:
        im = Image.open(os.path.join(AQUI, '_sin_normalizar', 'p_%03d.png' % i)).convert('RGBa')
        _PEQ[i] = im.resize((im.width // 2, im.height // 2), Image.BILINEAR)
    peq = _PEQ[i]
    r = peq.resize((round(peq.width * esc), round(peq.height * esc)), Image.BILINEAR)
    c = Image.new('RGBa', (292, 360), (0, 0, 0, 0))
    c.paste(r, (round(146 - X0 / 2 * esc + dx / 2), round(338.5 - Y0 / 2 * esc + dy / 2)))
    return np.asarray(c).astype(np.float32) / 255


def pm(p):
    return np.asarray(Image.open(p).convert('RGBa').resize((292, 360), Image.BILINEAR)).astype(np.float32) / 255


def dist(a, b):
    return float(10 * abs(a[75:] - b[75:]).mean())


def fino(i, dest, e0, x0, y0, paso=2, r=4, re=0.015):
    return min((dist(colocar(i, e, x, y), dest), float(e), x, y)
               for e in np.arange(e0 - re, e0 + re + 1e-6, 0.005)
               for x in range(x0 - r, x0 + r + 1, paso) for y in range(y0 - r, y0 + r + 1, paso))


def cadena(frames, dest0, ini):
    """Registra frames en orden: el primero contra dest0, cada uno contra el anterior colocado."""
    out = {}
    prev = dest0; p = ini
    for i in frames:
        d, e, x, y = fino(i, prev, *p[1:])
        out[i] = (e, x, y)
        prev = colocar(i, e, x, y); p = (d, e, x, y)
    return out


F18 = pm(os.path.join(ANIM, 'magnus_andar_frente', '04_limpios', 'c_018.png'))
E5 = pm(os.path.join(ANIM, 'magnus_andar_espalda', '04_limpios', 'c_005.png'))
entrada = cadena(range(1, 31), F18, (0, 1.505, 0, 6))
salida = cadena(range(240, 199, -1), E5, (0, 1.495, -1, 5))
# el giro, con los parametros de montar.py (interpolados 42 -> 90)
g0, g1 = (1.425, 4, -20), (1.470, 2, -2)
giro = {i: tuple(g0[k] + (g1[k] - g0[k]) * (i - 42) / 48 for k in range(3)) for i in range(42, 91)}
GI = {i: colocar(i, *giro[i]) for i in list(range(42, 57)) + list(range(78, 91))}
print('entrada -> giro (mejor por fotograma de entrada):')
for i in range(4, 31, 2):
    a = colocar(i, *entrada[i]); m = min((dist(a, GI[j]), j) for j in range(42, 57))
    print('  %d -> %d  %.3f' % (i, m[1], m[0]))
print('giro -> salida:')
for i in range(200, 236, 2):
    a = colocar(i, *salida[i]); m = min((dist(a, GI[j]), j) for j in range(78, 91))
    print('  %d <- %d  %.3f' % (i, m[1], m[0]))
paso = np.median([dist(colocar(i, *entrada[i]), colocar(i + 1, *entrada[i + 1])) for i in range(1, 30)])
print('paso medio en la entrada %.3f' % paso)
json.dump({'entrada': entrada, 'salida': salida, 'giro': giro}, open(os.path.join(AQUI, 'registro.json'), 'w'))

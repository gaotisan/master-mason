"""Referencias 1920x1080 (16:9) para los videos de FLOTAR EN LA LUZ (Flow,
fotogramas a video; prompt_flotar_*.txt). Para jugar bajo el haz: flotar,
girarse en el aire, deslizarse de lado, impulsarse en una hoja y bajar flotando
hasta el suelo.

Todos parten de la misma POSE DE FLOTAR: el c_38 del salto parado (bajando
despues del apogeo: cuerpo erguido, piernas colgando, tunica abierta). Esa pose
ya esta dentro del salto del juego: el despegue (fotogramas 18 -> 38) llega a
ella y la bajada con la toma de suelo (38 -> 65) sale de ella, asi que los
videos nuevos empalman con lo que hay. Sprite de master 1:1, croma #24D732,
suelo (cuando lo hay) en y=1040, sin baston (el guardado lo pinta el juego).

  flotar     flota en el sitio: inicio = fin (bucle)
  girar      se da la vuelta en el aire: fin = la pose espejada
  avanzar    se desliza hacia delante (a la derecha): fin D mas alla
  rebote     una hoja flotando bajo los pies: se apoya y se impulsa hacia
             arriba; fin R mas arriba (la hoja, un poco hundida)
  aterrizar  baja flotando y se posa en el suelo: fin = el reposo del juego

  python referencias_flotar.py [carpeta de salida; por defecto esta y la de
                                Descargas]"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import referencias_empujar as E               # noqa: E402

PROYECTO = os.path.abspath(os.path.join(AQUI, '..', '..', '..', '..'))
DESCARGAS = os.path.join(os.path.expanduser('~'), 'Downloads', 'referencias_peregrino_flotar_en_la_luz')
SALIDAS = [sys.argv[1]] if len(sys.argv) > 1 else [AQUI, DESCARGAS]

rep, H, PIE_Y, ESPALDA, TALON, PUNTA, DELANTE = E.peregrino()
SUELO = 1040
flota = Image.open(os.path.join(E.ANIM, 'magnus_salto_parado', '04_limpios', 'c_38.png')).convert('RGBA')
op = np.asarray(flota)[..., 3] > 128
ys = np.where(op.any(1))[0]
F_ARRIBA, F_PIE = int(ys.min()), int(ys.max())        # fila de la capucha y de los pies en su casilla
CASILLA = flota.width
X0 = (1920 - CASILLA) // 2
D = round(0.45 * H)                                   # lo que avanza deslizandose
R = round(0.30 * H)                                   # lo que sube con el impulso en la hoja
A = round(0.50 * H)                                   # altura de los pies al empezar a bajar


def hoja():
    """Una hoja de la hojarasca del juego (el atlas de hojas), tumbada y algo
    inclinada, una vez y media el tamano que tiene en el juego respecto al
    peregrino (en el juego 0,38 de su celda de 64x128 a media escala): mas
    pequena, el video no la ve como algo donde apoyarse."""
    atlas = Image.open(os.path.join(PROYECTO, 'assets', 'world', 'hojarasca', 'hojas.png')).convert('RGBA')
    celda = atlas.crop((64 * 4, 128, 64 * 5, 256))       # una de las anchas (fila 2, columna 5)
    esc = 0.38 * 2.0 * 1.5                                # algo mayor que en el juego: que el video la lea
    celda = celda.resize((round(64 * esc), round(128 * esc)), Image.LANCZOS)
    return celda.rotate(84, expand=True, resample=Image.BICUBIC)


def lienzo():
    return Image.new('RGBA', (1920, 1080), E.VERDE)


def guardar(lien, nombre, nota=''):
    for carpeta in SALIDAS:
        os.makedirs(carpeta, exist_ok=True)
        lien.convert('RGB').save(os.path.join(carpeta, nombre))
    print('%-34s %s' % (nombre, nota))


def con_pies_en(celda_pie, y_pie):
    return y_pie - celda_pie


espejo = flota.transpose(Image.FLIP_LEFT_RIGHT)       # la casilla esta centrada en el eje del cuerpo
y_centro = (1080 - (F_PIE - F_ARRIBA)) // 2 - F_ARRIBA   # la pose centrada en alto

# 1. flotar: inicio = fin
for nombre in ('referencia_flotar_inicio.png', 'referencia_flotar_fin.png'):
    lien = lienzo()
    lien.alpha_composite(flota, (X0, y_centro))
    guardar(lien, nombre, 'pies en %d' % (y_centro + F_PIE))

# 2. girar: de mirar a la derecha a mirar a la izquierda, en el mismo sitio
for nombre, celda in (('referencia_girar_inicio.png', flota), ('referencia_girar_fin.png', espejo)):
    lien = lienzo()
    lien.alpha_composite(celda, (X0, y_centro))
    guardar(lien, nombre, 'mirando a la %s' % ('derecha' if celda is flota else 'izquierda'))

# 3. avanzar: se desliza D a la derecha
xa = (1920 - CASILLA - D) // 2
for nombre, dx in (('referencia_avanzar_inicio.png', 0), ('referencia_avanzar_fin.png', D)):
    lien = lienzo()
    lien.alpha_composite(flota, (xa + dx, y_centro))
    guardar(lien, nombre, 'x %d' % (xa + dx))

# 4. rebote: la hoja justo bajo los pies; acaba R mas arriba y la hoja algo hundida
h = hoja()
pie_a = 880
eje = X0 + CASILLA // 2
for nombre, dy, hundida in (('referencia_rebote_inicio.png', 0, 0), ('referencia_rebote_fin.png', -R, 14)):
    lien = lienzo()
    lien.alpha_composite(h, (eje - h.width // 2 + 6, pie_a + 2 + hundida - h.height // 3))
    lien.alpha_composite(flota, (X0, con_pies_en(F_PIE, pie_a + dy)))
    guardar(lien, nombre, 'pies en %d, hoja en %d' % (pie_a + dy, pie_a + 2 + hundida))

# 5. aterrizar: de flotar con los pies a A del suelo al reposo en el suelo, en el mismo eje
xr = X0 + CASILLA // 2 - rep.width // 2
for nombre, celda, x, y in (('referencia_aterrizar_inicio.png', flota, X0, con_pies_en(F_PIE, SUELO - A)),
                            ('referencia_aterrizar_fin.png', rep, xr, SUELO - PIE_Y)):
    lien = lienzo()
    lien.alpha_composite(celda, (x, y))
    guardar(lien, nombre, 'pies en %d' % (y + (F_PIE if celda is flota else PIE_Y)))

# 6. aterrizar_corto (2026-10-12): la misma bajada, pero a la velocidad del
#    juego (el primero bajaba en 3,4 s y en el juego hay ~1 s: pasarlo deprisa
#    hacia la tunica "tosca, a cortes"). Los pies a la altura que alcanzan en un
#    salto parado en la luz (177 px del juego = 354 de master).
A_CORTO = 354
for nombre, celda, x, y in (('referencia_aterrizar_corto_inicio.png', flota, X0, con_pies_en(F_PIE, SUELO - A_CORTO)),
                            ('referencia_aterrizar_corto_fin.png', rep, xr, SUELO - PIE_Y)):
    lien = lienzo()
    lien.alpha_composite(celda, (x, y))
    guardar(lien, nombre, 'pies en %d' % (y + (F_PIE if celda is flota else PIE_Y)))

# Hoja de indice: los pares, inicio -> fin, en pequeno
pares = ['flotar', 'girar', 'avanzar', 'rebote', 'aterrizar', 'aterrizar_corto']
mini = (384, 216)
indice = Image.new('RGB', (mini[0] * 2 + 60, (mini[1] + 34) * len(pares) + 10), (30, 30, 30))
d = ImageDraw.Draw(indice)
for i, p in enumerate(pares):
    y = 10 + i * (mini[1] + 34)
    d.text((10, y), '%d. %s   (inicio -> fin)' % (i + 1, p), fill=(240, 220, 120))
    for j, cual in enumerate(('inicio', 'fin')):
        im = Image.open(os.path.join(SALIDAS[0], 'referencia_%s_%s.png' % (p, cual))).resize(mini, Image.LANCZOS)
        indice.paste(im, (20 + j * (mini[0] + 20), y + 20))
for carpeta in SALIDAS:
    if carpeta != AQUI:
        indice.save(os.path.join(carpeta, '0_indice_de_referencias.png'))
print('H %d  D %d  R %d  A %d  pose: salto parado c_38 (filas %d-%d)' % (H, D, R, A, F_ARRIBA, F_PIE))

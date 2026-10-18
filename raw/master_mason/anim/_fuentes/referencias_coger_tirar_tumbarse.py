"""Referencias 1920x1080 (16:9) para los videos de COGER del suelo, COGER de una
mesa, TIRAR de un sillar (arrastrarlo) y TUMBARSE / ARRASTRARSE / LEVANTARSE
(prompt_coger_suelo.txt, prompt_coger_mesa.txt, prompt_tirar.txt,
prompt_tumbarse_arrastrarse.txt; Flow, fotogramas a video). Todos empiezan y
acaban en el reposo del juego (peregrino_respirando c_01, sin baston: el guardado lo
pinta el juego encima) a escala de master 1:1, pies en y=1040, croma #24D732.
Los objetos son de relleno (low-poly, piedra clara como el sillar de empujar) y
se quitan al montar:
  coger_suelo   una piedrecita en el suelo, delante del pie (cabe en la mano);
                al acabar ya no esta (la guarda en el abrigo)
  coger_mesa    la misma piedrecita encima de una mesa de piedra a la cintura
  tirar         el sillar alto del empuje v2 con una argolla de hierro a la
                altura de la cadera; al acabar, el y el sillar D a la izquierda
  tumbarse      solo el reposo: al acabar, D a la derecha (se tumba, se arrastra,
                para y se levanta; el "tumbado" del juego es de frente, de la
                caida del cielo, y no vale de perfil)
  golpe         un empujon sin caerse: al acabar, un paso mas atras
  derribo       un golpe fuerte lo tira de espaldas y se levanta: al acabar,
                0,6 del alto mas atras
  lanzar_palo   un palo en el suelo delante del pie (el de Argos); al acabar ya
                no esta (lo ha lanzado fuera del cuadro)
  derrumbarse   solo el inicio (el final, 10.6-10.7: se derrumba y se va
                arrastrando; acaba como acabe)
  aterrizaje    plan B de caer (si Flow bloquea el de la plataforma alta,
                prompt_caer.txt): SOLO EL ATERRIZAJE FUERTE, sin altura a la
                vista. Empieza en el aire con el c_41 del salto parado (bajando),
                mas alto que en el salto, y acaba en el reposo. Caer de algo alto
                = el aire del salto (lo que dure) + esto.
  python referencias_coger_tirar_tumbarse.py [carpeta de salida; por defecto esta]"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy.spatial import Delaunay

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import referencias_empujar as E               # noqa: E402

SALIDA = sys.argv[1] if len(sys.argv) > 1 else AQUI
SS = 3
rep, H, PIE_Y, ESPALDA, TALON, PUNTA, DELANTE = E.peregrino()
SUELO = 1040
Y0 = SUELO - PIE_Y
D = round(0.70 * H)                           # lo que se desplaza al tirar / arrastrarse y levantarse


def guijarro(semilla=3):
    """Piedrecita clara low-poly que cabe en la mano cerrada (0,06 del alto)."""
    rng = np.random.default_rng(semilla)
    w, h = round(0.06 * H), round(0.035 * H)
    W, Hh = w * SS, h * SS
    ang = np.sort(rng.uniform(0, 2 * np.pi, 9))
    borde = [(W / 2 + np.cos(t) * W / 2 * rng.uniform(0.85, 1.0),
              Hh / 2 + np.sin(t) * Hh / 2 * rng.uniform(0.85, 1.0)) for t in ang]
    borde = [(x, min(y, Hh - 1)) for x, y in borde]
    pts = np.array(borde + [(W * 0.45, Hh * 0.45), (W * 0.6, Hh * 0.55)])
    img = Image.new('RGBA', (W, Hh), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    base = np.array([205, 199, 184], float)
    mask = Image.new('L', (W, Hh), 0)
    ImageDraw.Draw(mask).polygon(borde, fill=255)
    for s in Delaunay(pts).simplices:
        p = pts[s]
        luz = 1.06 - 0.25 * p[:, 1].mean() / Hh + rng.uniform(-0.06, 0.06)
        d.polygon([tuple(q) for q in p], fill=tuple(int(v) for v in np.clip(base * luz, 0, 255)) + (255,))
    arr = np.asarray(img).copy()
    arr[..., 3] = np.minimum(arr[..., 3], np.asarray(mask))
    return Image.fromarray(arr).resize((w, h), Image.LANCZOS)


def argolla():
    """Argolla de hierro vista de lado, con su grapa: se agarra con las dos manos."""
    R, r = round(0.045 * H), round(0.03 * H)  # radios de fuera y de dentro (28 y 19)
    W, Hh = (2 * R + 12) * SS, (2 * R + 4) * SS
    img = Image.new('RGBA', (W, Hh), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = R * SS, (R + 2) * SS
    d.ellipse((cx - R * SS, cy - R * SS, cx + R * SS, cy + R * SS), fill=(58, 54, 52, 255))
    d.ellipse((cx - r * SS, cy - r * SS, cx + r * SS, cy + r * SS), fill=(0, 0, 0, 0))
    d.arc((cx - R * SS + 4, cy - R * SS + 4, cx + R * SS - 4, cy + R * SS - 4), 200, 290, fill=(96, 90, 86, 255), width=3 * SS)
    d.rectangle((cx + r * SS, cy - 9 * SS, W - 1, cy + 9 * SS), fill=(48, 45, 43, 255))   # la grapa, hasta la piedra
    return img.resize((W // SS, Hh // SS), Image.LANCZOS), R + 2


def lienzo():
    return Image.new('RGBA', (1920, 1080), E.VERDE)


def guardar(lien, nombre, x0, nota=''):
    lien.convert('RGB').save(os.path.join(SALIDA, nombre))
    print('%-34s peregrino x %d-%d  %s' % (nombre, x0 + ESPALDA, x0 + DELANTE, nota))


piedra = guijarro()

# 1. coger del suelo: la piedrecita delante de la punta del pie, a mano agachandose
X0 = (1920 - 584) // 2
xp = X0 + PUNTA + round(0.18 * H) - piedra.width // 2
for nombre, con in (('referencia_coger_suelo_inicio.png', True), ('referencia_coger_suelo_fin.png', False)):
    lien = lienzo()
    if con:
        lien.alpha_composite(piedra, (xp, SUELO - piedra.height + 1))
    lien.alpha_composite(rep, (X0, Y0))
    guardar(lien, nombre, X0, 'piedra x %d-%d' % (xp, xp + piedra.width) if con else '(sin piedra)')

# 2. coger de una mesa de piedra a la cintura: la piedrecita encima, cerca del filo
hm, wm = round(0.40 * H), round(0.34 * H)     # pie de la mesa
hl, wl = round(0.06 * H), round(0.44 * H)     # losa de encima (alto total 0,46)
pie_mesa = E.sillar(wm, hm, puntos=18, semilla=21)
losa = E.sillar(wl, hl, puntos=8, semilla=22)
HUECO_M = round(0.12 * H)                     # de la punta del pie a la losa
tramo = PUNTA + HUECO_M + wl - ESPALDA
X0 = (1920 - tramo) // 2 - ESPALDA
xl = X0 + PUNTA + HUECO_M                     # filo izquierdo de la losa
yl = SUELO - hm - hl + 1                      # fila de arriba de la losa
xpm = xl + round(0.10 * H) - piedra.width // 2
for nombre, con in (('referencia_coger_mesa_inicio.png', True), ('referencia_coger_mesa_fin.png', False)):
    lien = lienzo()
    lien.alpha_composite(pie_mesa, (xl + (wl - wm) // 2, SUELO - hm + 1))
    lien.alpha_composite(losa, (xl, yl))
    if con:
        lien.alpha_composite(piedra, (xpm, yl - piedra.height + 3))
    lien.alpha_composite(rep, (X0, Y0))
    guardar(lien, nombre, X0, 'mesa x %d-%d, arriba en %d' % (xl, xl + wl, yl))

# 3. tirar: el sillar alto del empuje v2 con una argolla a la altura de la cadera;
#    tira andando hacia atras y los dos acaban D a la izquierda
fb, fw, fh, recta, puntos, _ = E.VARIANTES['v2']
hb, wb, hueco = round(fb * H), round(fw * H), round(fh * H)
bloque = E.sillar(wb, hb, recta, puntos)
ring, ry = argolla()
tramo = (PUNTA + hueco + wb) - (ESPALDA - D)
X0 = (1920 - tramo) // 2 - ESPALDA + D
for nombre, dx in (('referencia_tirar_inicio.png', 0), ('referencia_tirar_fin.png', -D)):
    lien = lienzo()
    bx = X0 + PUNTA + hueco + dx
    lien.alpha_composite(bloque, (bx, SUELO - hb + 1))
    lien.alpha_composite(ring, (bx - ring.width + 2, SUELO - round(0.45 * H) - ry))
    lien.alpha_composite(rep, (X0 + dx, Y0))
    guardar(lien, nombre, X0 + dx, 'sillar x %d-%d, argolla a la altura %d' % (bx, bx + wb, round(0.45 * H)))

# 4. tumbarse, arrastrarse, pararse y levantarse: del reposo al reposo D mas alla
#    (tumbado y arrastrandose ocupa ~1,7 del alto por delante de los pies)
tramo = (TALON + round(1.7 * H)) - ESPALDA
X0 = (1920 - tramo) // 2 - ESPALDA
for nombre, dx in (('referencia_tumbarse_inicio.png', 0), ('referencia_tumbarse_fin.png', D)):
    lien = lienzo()
    lien.alpha_composite(rep, (X0 + dx, Y0))
    guardar(lien, nombre, X0 + dx)


def palo(semilla=5):
    """Palo de madera low-poly tumbado en el suelo (0,38 del alto de largo), algo
    torcido y mas fino hacia la punta: el que Argos trae y deja a sus pies."""
    rng = np.random.default_rng(semilla)
    w, h = round(0.38 * H), round(0.075 * H)  # alto con la ramita
    W, Hh = w * SS, h * SS
    g0 = round(0.035 * H) * SS                # grueso de la vara en la base
    n = 10
    xs_ = np.linspace(0, W - 1, n)
    centro = Hh - g0 / 2 - np.sin(np.linspace(0, np.pi, n)) * g0 * 0.45   # algo arqueado
    grueso = np.linspace(g0 * 0.45, g0 * 0.25, n) * rng.uniform(0.9, 1.0, n)
    arriba = [(x, c - g) for x, c, g in zip(xs_, centro, grueso)]
    abajo = [(x, c + g) for x, c, g in zip(xs_, centro, grueso)]
    img = Image.new('RGBA', (W, Hh), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    base = np.array([122, 88, 56], float)
    # una ramita que sale hacia arriba cerca del extremo grueso: que se lea como rama, no regla
    bx, by = xs_[2], centro[2] - grueso[2] * 0.6
    d.polygon([(bx - 2 * SS, by), (bx + 4 * SS, by), (bx + 16 * SS, by - Hh * 0.62), (bx + 12 * SS, by - Hh * 0.64)],
              fill=tuple(int(v) for v in base * 0.95) + (255,))
    for i in range(n - 1):                    # cada tramo, dos caras: la de arriba a la luz
        mid = [((arriba[i][0] + abajo[i][0]) / 2, centro[i]), ((arriba[i + 1][0] + abajo[i + 1][0]) / 2, centro[i + 1])]
        for cara, luz in (([arriba[i], arriba[i + 1], mid[1], mid[0]], 1.12), ([mid[0], mid[1], abajo[i + 1], abajo[i]], 0.82)):
            col = tuple(int(v) for v in np.clip(base * (luz + rng.uniform(-0.06, 0.06)), 0, 255)) + (255,)
            d.polygon(cara, fill=col)
    return img.resize((w, h), Image.LANCZOS)


# 5. golpe leve: un empujon sin caerse; acaba un paso mas atras
X0 = (1920 - 584) // 2
PASO = round(0.12 * H)
for nombre, dx in (('referencia_golpe_inicio.png', 0), ('referencia_golpe_fin.png', -PASO)):
    lien = lienzo()
    lien.alpha_composite(rep, (X0 + dx, Y0))
    guardar(lien, nombre, X0 + dx)

# 6. derribo: lo tira de espaldas hacia la izquierda, se levanta 0,6 del alto mas atras
#    (tumbado de espaldas ocupa ~1,5 del alto por detras del talon)
ATRAS = round(0.6 * H)
tramo = DELANTE - (TALON - round(1.5 * H))
X0 = (1920 - tramo) // 2 - (TALON - round(1.5 * H))
for nombre, dx in (('referencia_derribo_inicio.png', 0), ('referencia_derribo_fin.png', -ATRAS)):
    lien = lienzo()
    lien.alpha_composite(rep, (X0 + dx, Y0))
    guardar(lien, nombre, X0 + dx)

# 7. lanzar el palo: el palo en el suelo delante del pie; lo coge y lo lanza fuera
#    del cuadro por la derecha
vara = palo()
X0 = 560
xv = X0 + PUNTA + round(0.15 * H)
for nombre, con in (('referencia_lanzar_palo_inicio.png', True), ('referencia_lanzar_palo_fin.png', False)):
    lien = lienzo()
    if con:
        lien.alpha_composite(vara, (xv, SUELO - vara.height + 1))
    lien.alpha_composite(rep, (X0, Y0))
    guardar(lien, nombre, X0, 'palo x %d-%d' % (xv, xv + vara.width) if con else '(sin palo)')

# 8. derrumbarse (el final): solo el inicio, a la izquierda para que quepa tumbado
#    y arrastrandose hacia la derecha
tramo = TALON + round(1.75 * H) - ESPALDA
X0 = (1920 - tramo) // 2 - ESPALDA
lien = lienzo()
lien.alpha_composite(rep, (X0, Y0))
guardar(lien, 'referencia_derrumbarse_inicio.png', X0)

# 9. aterrizaje (plan B de caer): empieza con el c_41 del salto parado (bajando, las
#    piernas estirandose para tocar suelo), con los pies a ALTURA del suelo (en el
#    salto van a 62 px), y acaba en el reposo en el mismo sitio: el salto parado cae
#    donde despego, con la misma casilla
salto = Image.open(os.path.join(E.ANIM, 'peregrino_salto_parado', '04_limpios', 'c_41.png')).convert('RGBA')
pie_salto = int(np.where((np.asarray(salto)[..., 3] > 128).any(1))[0].max())   # 615
ALTURA = round(0.30 * H)
X0 = (1920 - 584) // 2
for nombre, celda, y0 in (('referencia_aterrizaje_inicio.png', salto, SUELO - ALTURA - pie_salto),
                          ('referencia_aterrizaje_fin.png', rep, Y0)):
    lien = lienzo()
    lien.alpha_composite(celda, (X0, y0))
    guardar(lien, nombre, X0, 'pies en %d' % (y0 + (pie_salto if celda is salto else PIE_Y)))
print('H %d  D %d' % (H, D))

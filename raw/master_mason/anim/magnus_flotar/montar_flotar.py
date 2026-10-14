"""FLOTAR EN LA LUZ: monta las animaciones del aire en la luz desde los videos de
Flow (_fuentes/flotar_*.mp4, prompts en _fuentes/prompt_flotar*.txt).

Paso 1 (`casillas`): del video, los fotogramas pedidos, sin el croma, a escala
de master y encajados sobre la pose de flotar del juego (el c_38 del salto
parado, que es el primer fotograma de los videos): misma escala y mismo sitio,
al pixel. Van a 04_limpios/ (c_NNN.png) para igualar el tono de la tunica
(igualar_tono.py) como todas.

Paso 2 (`hoja`): la hoja del juego (a media escala, como todas) y el json con,
por fotograma, la altura del cuerpo y de los pies sobre el origen del nodo (px
del juego): con eso el juego pone el cuerpo donde dice la fisica y sabe en que
fotograma tocan los pies el suelo.

  python montar_flotar.py casillas     (y luego igualar_tono.py magnus_flotar ...)
  python igualar_piernas.py            (piernas del color de las del salto)
  python retocar_giro.py               (la tunica del giro, como la del de pie)
  python montar_flotar.py puentes
  python montar_flotar.py hoja

Paso intermedio (`puentes`): la bajada del video son 3,4 s y en el juego un
salto en la luz baja en ~1 s; pasarla entera tan deprisa (saltandose
fotogramas) hacia la tunica "tosca, a cortes" (2026-10-12). Asi que hay
recorridos mas cortos dentro de ella, con un atajo: dos fotogramas (uno del
principio y otro del final) y entre medias unos pocos hechos con flujo optico
(se mueven los pixeles de uno hacia el otro, alineados por el cuerpo; no es un
fundido). El juego elige el recorrido que pueda ensenar a su ritmo, sin
saltarse ninguno (RECORRIDOS en el json).

Animaciones (ANIMS): nombre -> video, primer y ultimo fotograma del video (0-based).
  flotar_bajar   aterrizar 0-80: baja flotando desde la pose de flotar; el
                 ultimo, los pies en el suelo
  flotar_posarse aterrizar 80-115: se endereza hasta el reposo
"""
import glob
import json
import os
import subprocess
import sys

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
PROYECTO = os.path.abspath(os.path.join(ANIM, '..', '..', '..'))
FUENTES = os.path.join(ANIM, '_fuentes')
FFMPEG = os.path.join(PROYECTO, 'tools', 'ffmpeg', 'bin', 'ffmpeg.exe')
LIMPIOS = os.path.join(AQUI, '04_limpios')
RETOCADOS = os.path.join(AQUI, '04_retocados')   # retocar_giro.py: si estan, mandan
SALIDA = os.path.join(AQUI, '05_salida')
JUEGO = os.path.join(PROYECTO, 'assets', 'characters', 'magnus')
VW, VH = 1280, 720

# nombre: (video, desde, hasta, fps en el juego, bucle)
ANIMS = {
    'flotar_bajar': ('aterrizar', 0, 80, 24.0, False),
    'flotar_posarse': ('aterrizar', 80, 115, 24.0, False),
    # el rebote empieza en la pose de flotar arriba y en ~1 s baja a apoyar los
    # pies en la hoja, a su ritmo: la bajada de un salto normal
    'rebote_bajar': ('rebote', 0, 40, 24.0, False),
    # El giro en el aire, por delante: del 8 (aun en la pose de flotar) al 38
    # (de frente: la linea del centro del pecho pasa por el eje en el 38; en el
    # 39 ya se ha pasado y el espejo la hacia volver 6 px) y luego esos mismos
    # espejados y al reves (ESPEJO), a 60 fps como los saltos (un fotograma por
    # tick, sin saltarse ninguno): 61 fotogramas, 1,02 s. Del 22 al 38 con la
    # tunica retocada (retocar_giro.py -> 04_retocados: sin el cinturon que se
    # invento el video, con el peto y el abrigo abierto del giro de pie).
    # La segunda mitad del video (39-64) acaba ensenando el
    # otro costado (otro dibujo de la tunica) y no casa con la pose de flotar
    # espejada (solape 0,72-0,80); el video no vuelve a ella hasta el 188 (3 s
    # despues). Lo mismo que el giro del suelo (magnus-giro-espejo): con el
    # espejo el ultimo es la pose de flotar espejada, la que pone flip_h.
    'flotar_girar': ('girar', 8, 38, 60.0, False),
}
# Animaciones que siguen con su espejo al reves (sin repetir el del frente).
ESPEJO = {'flotar_girar'}
# Registradas pero aun fuera del juego (hoja no las saca).
SIN_USO = {'rebote_bajar'}

# La pose de flotar del juego, en su casilla de master (584x720, suelo en 690,
# planta del pie de pie en 677).
POSE = os.path.join(ANIM, 'magnus_salto_parado', '04_limpios', 'c_38.png')
CASILLA_W = 584
ARRIBA = 30           # filas de mas por arriba sobre la casilla del c_38
ABAJO = 330           # y por abajo: el video baja 314 px de master hasta el suelo
CASILLA_H = ARRIBA + 720 + ABAJO
PLANTA = 13           # la planta del pie de pie, sobre la linea de suelo (677 de 690)
PUENTES_DIR = os.path.join(AQUI, '04_puentes')
# Atajos de flotar_bajar: (desde, hasta, fotogramas nuevos entre medias), en
# fotogramas de la animacion (0-based). Los pares salen de buscar los mas
# parecidos entre el principio y el final (pasos 0,13 y 0,27 frente a 0,037 de
# un fotograma al siguiente).
# 2026-10-12: probados (26, 56, 5) y (12, 68, 8): con poses tan distintas el
# flujo no casa y los intermedios salen con doble imagen (piernas dobles,
# tunica emborronada). Fuera: se piden videos a la velocidad del juego
# (prompt_flotar_aterrizar_corto.txt y los _rapido). Se deja el codigo.
PUENTES = []


def fotogramas(ruta, desde, hasta):
    p = subprocess.Popen([FFMPEG, '-v', 'error', '-i', ruta, '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'],
                         stdout=subprocess.PIPE)
    i = 0
    while True:
        b = p.stdout.read(VW * VH * 3)
        if len(b) < VW * VH * 3:
            break
        if desde <= i <= hasta:
            yield i, np.frombuffer(b, np.uint8).reshape(VH, VW, 3)
        i += 1
    p.wait()


def sin_croma(f):
    """RGBA sin el verde: alfa por la distancia al color del fondo (medido en las
    esquinas), con un borde blando de 2-3 px, y sin el verde que se cuela en el
    borde (despill: el verde no pasa del mayor de rojo y azul)."""
    rgb = f.astype(float)
    fondo = np.median(np.concatenate([rgb[:20, :20].reshape(-1, 3), rgb[:20, -20:].reshape(-1, 3),
                                      rgb[-20:, :20].reshape(-1, 3), rgb[-20:, -20:].reshape(-1, 3)]), 0)
    d = np.sqrt(((rgb - fondo) ** 2).sum(-1))
    a = np.clip((d - 60.0) / 70.0, 0.0, 1.0)
    # despill en lo que no es macizo
    tope = np.maximum(rgb[..., 0], rgb[..., 2]) + 6.0
    g = np.where(a < 0.999, np.minimum(rgb[..., 1], tope), rgb[..., 1])
    rgb[..., 1] = np.where(rgb[..., 1] > tope + 20, np.minimum(rgb[..., 1], tope + 20), g)
    # Lo que no es el peregrino: la hoja del rebote (dorada y muy saturada, en
    # la banda de abajo; los pies son piel apagada o gris) y cualquier trozo
    # suelto: solo la pieza mayor.
    r, gg, b = f[..., 0].astype(float), f[..., 1].astype(float), f[..., 2].astype(float)
    hoja = (r > 130) & (r - b > 85) & (gg > b + 25)
    hoja[:VH * 3 // 4] = False
    a = np.where(hoja, 0.0, a)
    from scipy import ndimage
    lab, n = ndimage.label(a > 0.3)
    if n > 1:
        mayor = 1 + int(np.argmax(ndimage.sum(np.ones_like(a), lab, range(1, n + 1))))
        cerca = ndimage.binary_dilation(lab == mayor, iterations=3)
        a = np.where(cerca, a, 0.0)
    out = np.dstack([rgb, a * 255.0])
    return np.clip(out, 0, 255).astype(np.uint8)


def caja(alfa, umbral=128):
    ys, xs = np.where(alfa > umbral)
    return ys.min(), ys.max(), xs.min(), xs.max()


def registrar(primero):
    """Escala y desplazamiento que llevan el primer fotograma del video sobre el
    c_38 de su casilla: escala por el alto (capucha-pies), sitio por el mejor
    solape de las siluetas en +-12 px."""
    pose = np.asarray(Image.open(POSE).convert('RGBA'))
    py0, py1, px0, px1 = caja(pose[..., 3])
    vy0, vy1, vx0, vx1 = caja(primero[..., 3])
    s = (py1 - py0) / float(vy1 - vy0)
    im = Image.fromarray(primero).resize((round(VW * s), round(VH * s)), Image.LANCZOS)
    a = np.asarray(im)[..., 3] > 128
    ay0, ay1, ax0, ax1 = caja(np.asarray(im)[..., 3])
    dx0, dy0 = px0 - ax0, py0 - ay0
    objetivo = pose[..., 3] > 128
    mejor = None
    for dy in range(dy0 - 12, dy0 + 13):
        for dx in range(dx0 - 12, dx0 + 13):
            lien = np.zeros_like(objetivo)
            ys, xs = np.nonzero(a)
            ys2, xs2 = ys + dy, xs + dx
            ok = (ys2 >= 0) & (ys2 < objetivo.shape[0]) & (xs2 >= 0) & (xs2 < objetivo.shape[1])
            lien[ys2[ok], xs2[ok]] = True
            iou = (lien & objetivo).sum() / float((lien | objetivo).sum())
            if mejor is None or iou > mejor[0]:
                mejor = (iou, dx, dy)
    print('registro: escala %.4f, desplazamiento (%d, %d), solape %.3f' % (s, mejor[1], mejor[2], mejor[0]))
    return s, mejor[1], mejor[2]


def casillas():
    os.makedirs(LIMPIOS, exist_ok=True)
    for f in glob.glob(os.path.join(LIMPIOS, 'c_*.png')):
        os.remove(f)
    registros = {}
    k = 1
    indice = {}
    for nombre, (video, desde, hasta, fps, bucle) in ANIMS.items():
        ruta = glob.glob(os.path.join(FUENTES, 'flotar_%s_*.mp4' % video))[0]
        primera = k
        if video not in registros:
            # cada video, con su encaje: su primer fotograma es la pose de flotar
            for i, f in fotogramas(ruta, 0, 0):
                registros[video] = registrar(sin_croma(f))
        registro = registros[video]
        for i, f in fotogramas(ruta, desde, hasta):
            rgba = sin_croma(f)
            s, dx, dy = registro
            im = Image.fromarray(rgba).resize((round(VW * s), round(VH * s)), Image.LANCZOS)
            lien = Image.new('RGBA', (CASILLA_W, CASILLA_H), (0, 0, 0, 0))
            lien.alpha_composite(im, (dx, dy + ARRIBA))
            lien.save(os.path.join(LIMPIOS, 'c_%03d.png' % k))
            k += 1
        indice[nombre] = [primera, k - 1]
        print('%-16s video %s %d-%d -> c_%03d-c_%03d' % (nombre, video, desde, hasta, primera, k - 1))
    json.dump({'registros': registros, 'anims': indice}, open(os.path.join(AQUI, 'casillas.json'), 'w'), indent=1)


def _leer_pm(ruta):
    """RGBA en float con el color premultiplicado (el fondo, negro y transparente)."""
    a = np.asarray(Image.open(ruta).convert('RGBA')).astype(np.float32) / 255.0
    a[..., :3] *= a[..., 3:]
    return a


def _gris(a):
    g = a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11
    return np.clip(g * 255.0 + a[..., 3] * 40.0, 0, 255).astype(np.uint8)


def puentes():
    """Los fotogramas de los atajos (ver PUENTES): del fotograma desde al hasta,
    alineados por el centroide (el cuerpo lo pone la fisica), flujo optico en
    los dos sentidos, y cada intermedio con los dos llevados hasta su momento
    t y mezclados (al estar ya encima, la mezcla no emborrona). Su sitio en la
    casilla va del de uno al del otro."""
    import cv2
    datos = json.load(open(os.path.join(AQUI, 'casillas.json')))
    c0 = datos['anims']['flotar_bajar'][0]
    os.makedirs(PUENTES_DIR, exist_ok=True)
    for f in glob.glob(os.path.join(PUENTES_DIR, '*.png')):
        os.remove(f)
    dis = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
    for a, b, n in PUENTES:
        A = _leer_pm(os.path.join(LIMPIOS, 'c_%03d.png' % (c0 + a)))
        B = _leer_pm(os.path.join(LIMPIOS, 'c_%03d.png' % (c0 + b)))
        def centro(x):
            ys, xs = np.nonzero(x[..., 3] > 0.5)
            return ys.mean(), xs.mean()
        (ay, ax), (by, bx) = centro(A), centro(B)
        dy, dx = int(round(ay - by)), int(round(ax - bx))
        Bal = np.roll(np.roll(B, dy, 0), dx, 1)
        fab = dis.calc(_gris(A), _gris(Bal), None)
        fba = dis.calc(_gris(Bal), _gris(A), None)
        h, w = A.shape[:2]
        gx, gy = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
        for k in range(1, n + 1):
            t = k / float(n + 1)
            # el sitio: del de A al de B (en el marco de A, B esta (dy, dx) atras)
            sx, sy = t * dx, t * dy
            ia = cv2.remap(A, gx + sx - t * fab[..., 0], gy + sy - t * fab[..., 1], cv2.INTER_LINEAR,
                           borderMode=cv2.BORDER_CONSTANT, borderValue=0)
            ib = cv2.remap(Bal, gx + sx - (1 - t) * fba[..., 0], gy + sy - (1 - t) * fba[..., 1],
                           cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
            m = (1 - t) * ia + t * ib
            al = np.clip(m[..., 3:], 1e-6, 1.0)
            rgb = np.where(m[..., 3:] > 1e-4, m[..., :3] / al, 0.0)
            out = np.dstack([np.clip(rgb, 0, 1), np.clip(m[..., 3], 0, 1)])
            Image.fromarray((out * 255).astype(np.uint8)).save(
                os.path.join(PUENTES_DIR, 'p_%02d_%02d_%d.png' % (a, b, k)))
        print('puente %d -> %d: %d fotogramas (alineados %d, %d px)' % (a, b, n, dx, dy))


def medidas(a):
    """Fila de la capucha, del centroide y de los pies de una casilla (master)."""
    al = a[..., 3].astype(float) / 255.0
    ys = np.where((al > 0.5).any(1))[0]
    cy = (al * np.arange(al.shape[0])[:, None]).sum() / al.sum()
    return ys.min(), cy, ys.max()


def hoja():
    datos = json.load(open(os.path.join(AQUI, 'casillas.json')))
    # El suelo de las casillas: donde estan los pies al final (de pie).
    ultimo = np.asarray(Image.open(os.path.join(LIMPIOS, 'c_%03d.png' % datos['anims']['flotar_posarse'][1])))
    pie_de_pie = medidas(ultimo)[2]
    origen = pie_de_pie + PLANTA              # fila del origen del nodo (la linea de suelo)
    os.makedirs(SALIDA, exist_ok=True)
    salida = {}
    for nombre, (c0, c1) in datos['anims'].items():
        if nombre in SIN_USO:
            continue
        video, desde, hasta, fps, bucle = ANIMS[nombre]
        n = c1 - c0 + 1
        n = min(n, hasta - desde + 1)

        def casilla(k):
            r = os.path.join(RETOCADOS, 'c_%03d.png' % k)
            return r if os.path.exists(r) else os.path.join(LIMPIOS, 'c_%03d.png' % k)
        ims = [Image.open(casilla(c0 + j)).convert('RGBA') for j in range(n)]
        frente = None
        if nombre in ESPEJO:
            # el espejo respecto al eje del cuerpo (x 292: x -> 584 - x, lo que
            # hace flip_h con el offset volteado), sin repetir el del frente
            frente = n
            for j in range(n - 2, -1, -1):
                a = np.asarray(ims[j])[:, ::-1]
                ims.append(Image.fromarray(np.ascontiguousarray(np.roll(a, 1, axis=1))))
            n = len(ims)
        recorridos = {}
        if nombre == 'flotar_bajar':
            # los puentes van detras de los del video; los recorridos, en orden
            recorridos['completo'] = list(range(n))
            for a, b, m in PUENTES:
                desde_j = len(ims)
                for k in range(1, m + 1):
                    ims.append(Image.open(os.path.join(PUENTES_DIR, 'p_%02d_%02d_%d.png' % (a, b, k))).convert('RGBA'))
                recorridos['%d_%d' % (a, b)] = list(range(a + 1)) + list(range(desde_j, desde_j + m)) + list(range(b, n))
            n = len(ims)
        # La casilla de la hoja: lo que ocupan todos sus fotogramas (pares, para
        # la media escala), no la de 584x1080, casi toda vacia.
        y0 = x0 = 10 ** 6
        y1 = x1 = 0
        for im in ims:
            a = np.asarray(im)[..., 3] > 8
            ys, xs = np.where(a)
            y0, y1, x0, x1 = min(y0, ys.min()), max(y1, ys.max()), min(x0, xs.min()), max(x1, xs.max())
        y0, x0 = max(y0 - 4, 0) // 2 * 2, max(x0 - 4, 0) // 2 * 2
        y1, x1 = min(y1 + 6, CASILLA_H) // 2 * 2, min(x1 + 6, CASILLA_W) // 2 * 2
        y0, y1, x0, x1 = int(y0), int(y1), int(x0), int(x1)
        hw, hh = (x1 - x0) // 2, (y1 - y0) // 2
        cols = min(n, 12)
        filas = (n + cols - 1) // cols
        lamina = Image.new('RGBA', (cols * hw, filas * hh), (0, 0, 0, 0))
        cuerpo, pies = [], []
        for j, im in enumerate(ims):
            arriba, cy, abajo = medidas(np.asarray(im))
            # el cuerpo, como en VUELO de magnus.gd: media de capucha y centroide
            cuerpo.append(round((origen - (arriba + cy) / 2.0) / 2.0, 1))
            pies.append(round(max(origen - PLANTA - abajo, 0) / 2.0, 1))
            lamina.alpha_composite(im.crop((x0, y0, x1, y1)).resize((hw, hh), Image.LANCZOS),
                                   ((j % cols) * hw, (j // cols) * hh))
        archivo = 'magnus_%s.png' % nombre
        lamina.save(os.path.join(SALIDA, archivo))
        lamina.save(os.path.join(JUEGO, archivo))
        salida[nombre] = {
            'hoja': 'res://assets/characters/magnus/%s' % archivo,
            'n': n, 'cols': cols, 'casilla': [hw, hh], 'fps': fps, 'bucle': bucle,
            # el origen del nodo (eje del cuerpo, x 292 de la casilla de master;
            # linea de suelo) respecto al centro de la casilla recortada
            'offset': [-round(((CASILLA_W / 2.0 - x0) - (x1 - x0) / 2.0) / 2.0, 1),
                       -round(((origen - y0) - (y1 - y0) / 2.0) / 2.0, 1)],
            'cuerpo': cuerpo, 'pies': pies,
        }
        if frente is not None:
            # primer fotograma de la mitad espejada (ya de frente, hacia el otro lado)
            salida[nombre]['frente'] = frente
        if recorridos:
            salida[nombre]['recorridos'] = recorridos
            print('  recorridos: ' + ', '.join('%s %d' % (k, len(v)) for k, v in recorridos.items()))
        print('%-16s %d fotogramas, cuerpo %.1f -> %.1f, pies %.1f -> %.1f' % (
            nombre, n, cuerpo[0], cuerpo[-1], pies[0], pies[-1]))
    # La altura del cuerpo (la misma medida) en el despegue de cada salto del
    # juego, en su casilla (suelo en 690): enlaza la fisica del salto (alturas
    # sobre el despegue) con las casillas de aqui (alturas sobre el suelo).
    salida['_despegue'] = {}
    # (El corriendo, para el rebote: desde una hoja todo salto sigue como el de
    # parado, y su altura pasa de una medida a la otra.)
    for salto, job, d0 in (('salto_parado', 'magnus_salto_parado', 18), ('saltar', 'magnus_salto_andando', 13),
                           ('salto_correr', 'magnus_salto_corriendo', 2)):
        a = np.asarray(Image.open(os.path.join(ANIM, job, '04_limpios', 'c_%02d.png' % (d0 + 1))).convert('RGBA'))
        arriba, cy, abajo = medidas(a)
        salida['_despegue'][salto] = round((690 - (arriba + cy) / 2.0) / 2.0, 1)
    print('cuerpo en el despegue:', salida['_despegue'])
    # Las que montan otros jobs en este mismo json (flotar_pisar de
    # magnus_pisar_hoja, coger_baculo de magnus_coger_baculo): se conservan.
    ruta = os.path.join(JUEGO, 'flotar.json')
    if os.path.exists(ruta):
        for k, v in json.load(open(ruta)).items():
            if k not in salida and k not in ANIMS:
                salida[k] = v
    json.dump(salida, open(os.path.join(JUEGO, 'flotar.json'), 'w'), indent=1)
    json.dump(salida, open(os.path.join(SALIDA, 'flotar.json'), 'w'), indent=1)


if __name__ == '__main__':
    {'casillas': casillas, 'puentes': puentes, 'hoja': hoja}[sys.argv[1]]()

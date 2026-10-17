"""LLEGAR A LA HOJA Y DESPEGAR DE ELLA (2026-10-16): lo que va antes y despues de
flotar_pisar, desde y hasta la pose de flotar. El usuario: "entre que junta los
pies y salta, justo antes de saltar, la animacion no es fluida, queda rara"; y
luego, de la llegada: "el objetivo es hacer lo que sea con lo que tenemos para
que quede perfecto".

DESPEGAR. Medido: flotar_pisar acaba de pie, piernas rectas y juntas y la capa
abierta, y seguia el salto de parado 21,5 (piernas separadas, tunica recta, otro
video): silueta 0,24 y textura 1,16 contra un paso normal de 0,03-0,10 y
0,2-0,5. Ningun fotograma que hubiera casaba con el. Salir de pisar agachado
(13 -> salto 18,5) tambien se veia y despegaba sin empujar. Lo que casa:
  A  video de pisar 37-68: su propia subida tras el despegue (36); la capa se
     asienta sola y acaba de pie flotando
  B  video flotar_rebote 136-191: de pie flotando a la pose de flotar (su
     ultimo fotograma era la referencia, el c_38 del salto: es el 0 de
     flotar_bajar, solape 0,984 sin moverlo)
  A68 -> B136: silueta 0,05, textura 0,38 (el empalme aceptado salto c_38 ->
  flotar_bajar 0 da 0,03 y 0,28). El giro en el aire casa desde B177 (0,06/0,32).

LLEGAR. Se entraba en flotar_pisar desde la bajada (flotar_bajar, de otro
video) por el fotograma de altura parecida: 0,28 / 1,2. Pero el video de pisar
salio de la misma imagen que el de rebote (la pose de flotar: sus 27 primeros
fotogramas son casi el mismo, 0,018 / 0,12) y sus 0-13 bajan hasta la hoja
recogiendo y estirando las piernas; el 14 es el primero de flotar_pisar:
  L  video de pisar 0-13, que empieza en la pose de flotar (flotar_bajar 0-4 ->
     L0-1: 0,026 / 0,22; flotar_quieto solo cerca de su costura, 186-191 y 0-8)
Las tablas de entrada (de flotar_bajar y de flotar_quieto a L, y la calidad de
cada una) van en flotar.json: el juego sale del bucle quieto por donde casa.

Encaje: el lienzo de flotar_pisar (584x910, linea de la hoja en ORIGEN 900): A
y L con su registro; B con el de flotar (casillas.json de magnus_flotar, origen
935) bajado 35 px. En x, lo que pide cada empalme con el otro registro (12 px),
repartido a lo largo del tramo: B empieza donde A68 y acaba en flotar_bajar 0;
L empieza en flotar_bajar 0 y acaba donde flotar_pisar 0.

Tono: A con la ganancia que la lleva a los ultimos de pisar (ya igualados); B
de la del empalme con A a la de flotar_bajar 1-5; L de la de flotar_bajar 0-2 a
la de los primeros de pisar, fotograma a fotograma. Piernas y pies como en
pies.py de magnus_pisar_hoja (a las del salto en el aire y a los pies
aceptados), con las estadisticas de cada tramo.

  python montar.py casillas
  python montar.py tono
  python montar.py piernas
  python montar.py hoja        (flotar_despegar y flotar_llegar en flotar.json)
"""
import glob
import importlib.util
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
PROYECTO = os.path.abspath(os.path.join(ANIM, '..', '..', '..'))
sys.path.insert(0, ANIM)
sys.path.insert(0, os.path.join(ANIM, 'magnus_pisar_hoja'))
sys.path.insert(0, os.path.join(ANIM, 'magnus_flotar'))
# el montar.py de pisar se llama como este: por su ruta
_spec = importlib.util.spec_from_file_location('montar_pisar', os.path.join(ANIM, 'magnus_pisar_hoja', 'montar.py'))
pisar = importlib.util.module_from_spec(_spec)   # registro, VIDEO, ESCALA, lienzo
_spec.loader.exec_module(pisar)
import montar_flotar as mf      # noqa: E402  (fotogramas, sin_croma, medidas)
import igualar_tono as it       # noqa: E402
import pies                     # noqa: E402  (de magnus_pisar_hoja)

LIMPIOS = os.path.join(AQUI, '04_limpios')
SIN_TONO = os.path.join(AQUI, '_sin_igualar_tono')
SIN_PIERNAS = os.path.join(AQUI, '04_limpios_sin_piernas')
SALIDA = os.path.join(AQUI, '05_salida')
JUEGO = os.path.join(PROYECTO, 'assets', 'characters', 'magnus')
FLOTAR_JSON = os.path.join(JUEGO, 'flotar.json')
TRAMOS = os.path.join(AQUI, 'tramos.json')
FLOTAR_LIMPIOS = os.path.join(ANIM, 'magnus_flotar', '04_limpios')
PISAR_LIMPIOS = os.path.join(ANIM, 'magnus_pisar_hoja', '04_limpios')

A = (37, 68)                 # video de pisar: subida
B = (136, 191)               # video flotar_rebote: recoge las piernas
L = (0, 13)                  # video de pisar: llegada a la hoja
GIRO_DESDE_B = 177           # desde aqui casa con flotar_girar 0
FPS_A = 48.0                 # el de flotar_pisar (el mismo video, al mismo ritmo)
FPS_B = 60.0                 # un fotograma por tick (el video va lento: la tela se asienta)
FPS_L = 48.0
ORIGEN = pisar.ORIGEN        # 900
PLANTA = pisar.PLANTA
ORIGEN_FLOTAR = 935          # el de las casillas de flotar (medido: pie del ultimo de posarse + PLANTA)
EMPALME_DX = 12              # x de B136 sobre A68 (mejor solape), que se va a 0 en B191
ENTRADA_L = 4                # de L se entra por sus primeros (0-3: aun en la pose)
CASA = (0.07, 0.45)          # silueta y textura por debajo de las cuales un empalme no se ve


def _lienzo():
    return Image.new('RGBA', (pisar.CASILLA_W, pisar.CASILLA_H), (0, 0, 0, 0))


def _flotar_en_lienzo(ruta):
    """Una casilla de magnus_flotar (origen 935) en el lienzo de pisar (900)."""
    lien = _lienzo()
    lien.alpha_composite(Image.open(ruta).convert('RGBA'), (0, ORIGEN - ORIGEN_FLOTAR))
    return lien


def _desplazamiento(fijo, movil):
    """(dx, dy) que pone `movil` sobre `fijo` con mas solape de siluetas."""
    a = np.asarray(fijo)[..., 3] > 128
    b = np.asarray(movil)[..., 3] > 128
    ya, xa = np.nonzero(a)
    yb, xb = np.nonzero(b)
    cy, cx = int(round(ya.mean() - yb.mean())), int(round(xa.mean() - xb.mean()))
    mejor = (-1.0, 0, 0)
    for dy in range(cy - 12, cy + 13):
        for dx in range(cx - 20, cx + 21):
            y2, x2 = yb + dy, xb + dx
            ok = (y2 >= 0) & (y2 < a.shape[0]) & (x2 >= 0) & (x2 < a.shape[1])
            m = np.zeros_like(a)
            m[y2[ok], x2[ok]] = True
            iou = (m & a).sum() / float((m | a).sum())
            if iou > mejor[0]:
                mejor = (iou, dx, dy)
    return mejor[1], mejor[2]


def _video_pisar(desde, hasta):
    dx, dy = pisar.registro()
    for i, f in mf.fotogramas(pisar.VIDEO, desde, hasta):
        im = Image.fromarray(mf.sin_croma(f)).resize(
            (round(mf.VW * pisar.ESCALA), round(mf.VH * pisar.ESCALA)), Image.LANCZOS)
        lien = _lienzo()
        lien.alpha_composite(im, (dx, dy))
        yield i, lien


def casillas():
    for d in (LIMPIOS, SIN_TONO, SIN_PIERNAS):
        if os.path.isdir(d):
            shutil.rmtree(d)
    os.makedirs(LIMPIOS)
    k = 1
    for i, lien in _video_pisar(A[0], A[1]):
        lien.save(os.path.join(LIMPIOS, 'c_%03d.png' % k))
        k += 1
    n_a = k - 1
    s, fdx, fdy = json.load(open(os.path.join(ANIM, 'magnus_flotar', 'casillas.json')))['registros']['rebote']
    ruta = glob.glob(os.path.join(mf.FUENTES, 'flotar_rebote_*.mp4'))[0]
    for i, f in mf.fotogramas(ruta, B[0], B[1]):
        im = Image.fromarray(mf.sin_croma(f)).resize((round(mf.VW * s), round(mf.VH * s)), Image.LANCZOS)
        t = (i - B[0]) / float(B[1] - B[0])
        lien = _lienzo()
        lien.alpha_composite(im, (fdx + round(EMPALME_DX * (1.0 - t)), fdy + mf.ARRIBA + ORIGEN - ORIGEN_FLOTAR))
        lien.save(os.path.join(LIMPIOS, 'c_%03d.png' % k))
        k += 1
    n_b = k - 1
    # L: lo que pide su primero para caer sobre flotar_bajar 0, a 0 en el ultimo
    ls = list(_video_pisar(L[0], L[1]))
    dx0, _ = _desplazamiento(_flotar_en_lienzo(os.path.join(FLOTAR_LIMPIOS, 'c_001.png')), ls[0][1])
    for i, lien in ls:
        t = (i - L[0]) / float(L[1] - L[0])
        movido = _lienzo()
        movido.alpha_composite(lien, (round(dx0 * (1.0 - t)), 0))
        movido.save(os.path.join(LIMPIOS, 'c_%03d.png' % k))
        k += 1
    tramos = {'a': [1, n_a], 'b': [n_a + 1, n_b], 'l': [n_b + 1, k - 1],
              'giro_desde': n_a + 1 + GIRO_DESDE_B - B[0]}
    json.dump(tramos, open(TRAMOS, 'w'), indent=1)
    print('casillas: A pisar %d-%d -> c_001-c_%03d, B rebote %d-%d -> c_%03d-c_%03d, L pisar %d-%d -> c_%03d-c_%03d (x %+d)' % (
        A[0], A[1], n_a, B[0], B[1], n_a + 1, n_b, L[0], L[1], n_b + 1, k - 1, dx0))


def tono():
    """A: la ganancia que lleva su empalme (sus 4 primeros) a los 4 ultimos de
    pisar. B: de la que lleva su primero a lo que queda A al final, a la que
    lleva su ultimo a flotar_bajar 1-5, en linea. L: de la que lleva su primero
    a flotar_bajar 0-2 a la que lleva su ultimo a los primeros de pisar."""
    if not os.path.isdir(SIN_TONO):
        shutil.copytree(LIMPIOS, SIN_TONO)
    tr = json.load(open(TRAMOS))
    leer = lambda c: it.leer(os.path.join(SIN_TONO, 'c_%03d.png' % c))

    def ganancia(muestra, ref):
        g = np.ones(3)
        for _ in range(5):
            g = g * ref / it.media([it.aplicar(im, g) for im in muestra])
        return g

    def ref(carpeta, cs):
        return it.media([it.leer(os.path.join(carpeta, 'c_%03d.png' % c)) for c in cs])
    a0, a1 = tr['a']
    g_a = ganancia([leer(c) for c in range(a0, a0 + 4)], ref(PISAR_LIMPIOS, range(20, 24)))
    fin_a = it.media([it.aplicar(leer(c), g_a) for c in range(a1 - 3, a1 + 1)])
    b0, b1 = tr['b']
    g_b0 = ganancia([leer(c) for c in range(b0, b0 + 3)], fin_a)
    g_b1 = ganancia([leer(c) for c in range(b1 - 2, b1 + 1)], ref(FLOTAR_LIMPIOS, range(1, 6)))
    l0, l1 = tr['l']
    g_l0 = ganancia([leer(c) for c in range(l0, l0 + 3)], ref(FLOTAR_LIMPIOS, range(1, 4)))
    g_l1 = ganancia([leer(c) for c in range(l1 - 2, l1 + 1)], ref(PISAR_LIMPIOS, range(1, 4)))
    for c in range(a0, l1 + 1):
        if c <= a1:
            g = g_a
        elif c <= b1:
            t = (c - b0) / float(b1 - b0)
            g = g_b0 * (1 - t) + g_b1 * t
        else:
            t = (c - l0) / float(l1 - l0)
            g = g_l0 * (1 - t) + g_l1 * t
        Image.fromarray((it.aplicar(leer(c), g) * 255).round().astype(np.uint8)).save(
            os.path.join(LIMPIOS, 'c_%03d.png' % c))
    fmt = lambda g: str(tuple(round(float(v), 3) for v in g))
    print('tono: A %s; B %s -> %s; L %s -> %s' % (fmt(g_a), fmt(g_b0), fmt(g_b1), fmt(g_l0), fmt(g_l1)))


def piernas():
    """pies.py de magnus_pisar_hoja, tramo a tramo: sin hoja ni borde verde,
    piernas a las del salto en el aire y pies a los aceptados."""
    if not os.path.isdir(SIN_PIERNAS):
        shutil.copytree(LIMPIOS, SIN_PIERNAS)
    tr = json.load(open(TRAMOS))
    ip = pies.ip
    destino = ip.estadisticas(pies.muestras([pies.leer(os.path.join(pies.SALTO, 'c_%02d.png' % (f + 1)))
                                             for f in pies.REFERENCIA]))
    pies_dst = ip.estadisticas(pies.muestras_pies([pies.leer(r) for r in pies.PIES_ACEPTADOS]))
    for nombre in ('a', 'b', 'l'):
        c0, c1 = tr[nombre]
        rutas = [os.path.join(SIN_PIERNAS, 'c_%03d.png' % c) for c in range(c0, c1 + 1)]
        pasos = []
        for r in rutas:
            a = pies.quitar_hoja(pies.leer(r))
            pasos.append(pies.sin_verde(a, ip.mascara(a)))
        fuente = ip.estadisticas(pies.muestras(pasos))
        hechas = [pies.transferir(a, ip.mascara(a), fuente, destino) for a in pasos]
        pies_src = ip.estadisticas(np.concatenate(
            [b[pies.mascara_pies(b, ip.mascara(b)) & (b[..., 3] > 200)][:, :3] for b in hechas]))
        for r, b in zip(rutas, hechas):
            b = pies.transferir_pies(b, pies.mascara_pies(b, ip.mascara(b)), pies_src, pies_dst)
            Image.fromarray(b).save(os.path.join(LIMPIOS, os.path.basename(r)))
        print('piernas %s: L %.0f -> %.0f; pies L %.0f -> %.0f' % (
            nombre, fuente[0][0], destino[0][0], pies_src[0][0], pies_dst[0][0]))


# --- parecido entre fotogramas (el de los estudios: siluetas y textura) -----

def _pm(im):
    im = im.resize((im.width // 4, im.height // 4), Image.BOX)
    a = np.asarray(im).astype(np.float32) / 255.0
    return np.concatenate([a[..., :3] * a[..., 3:], a[..., 3:]], -1)


def _centrado(a, alto=300, ancho=180):
    ys, xs = np.where(a[..., 3] > 0.5)
    cy, cx = int(ys.mean()), int(xs.mean())
    out = np.zeros((alto, ancho, 4), np.float32)
    y0, x0 = alto // 2 - cy, ancho // 2 - cx
    sy0, sx0, dy0, dx0 = max(0, -y0), max(0, -x0), max(0, y0), max(0, x0)
    hh, ww = min(a.shape[0] - sy0, alto - dy0), min(a.shape[1] - sx0, ancho - dx0)
    out[dy0:dy0 + hh, dx0:dx0 + ww] = a[sy0:sy0 + hh, sx0:sx0 + ww]
    return out


def _parecido(a, b):
    """(silueta, textura): 1 - solape de siluetas y 10 x |A-B| medio sobre la
    union, en la mejor de unas posiciones cercanas (por silueta)."""
    mejor = (9.0, 9.0)
    for dy in range(-8, 9, 2):
        for dx in range(-8, 9, 2):
            bb = np.roll(np.roll(b, dy, 0), dx, 1)
            i = np.minimum(a[..., 3], bb[..., 3]).sum()
            u = np.maximum(a[..., 3], bb[..., 3]).sum()
            s = 1.0 - i / u
            if s < mejor[0]:
                m = np.maximum(a[..., 3], bb[..., 3]) > 0.1
                mejor = (s, 10.0 * np.abs(a[..., :3] - bb[..., :3]).sum(-1)[m].mean() / 3.0)
    return mejor


def _entradas(origenes, destinos):
    """Para cada origen, el destino que mas se le parece y si casa (CASA)."""
    out, casa = [], []
    for a in origenes:
        r = min((_parecido(a, b) + (k,) for k, b in enumerate(destinos)), key=lambda x: x[1] + 2.0 * x[0])
        out.append(int(r[2]))
        casa.append(bool(r[0] < CASA[0] and r[1] < CASA[1]))
    return out, casa


def hoja():
    tr = json.load(open(TRAMOS))
    datos = json.load(open(FLOTAR_JSON))
    todas = {c: Image.open(os.path.join(LIMPIOS, 'c_%03d.png' % c)).convert('RGBA')
             for c in range(1, tr['l'][1] + 1)}

    def lamina(nombre, cs, fps, extra):
        ims = [todas[c] for c in cs]
        n = len(ims)
        y0 = x0 = 10 ** 6
        y1 = x1 = 0
        for im in ims:
            ys, xs = np.where(np.asarray(im)[..., 3] > 8)
            y0, y1, x0, x1 = min(y0, ys.min()), max(y1, ys.max()), min(x0, xs.min()), max(x1, xs.max())
        y0, x0 = max(y0 - 4, 0) // 2 * 2, max(x0 - 4, 0) // 2 * 2
        y1, x1 = min(y1 + 6, pisar.CASILLA_H) // 2 * 2, min(x1 + 6, pisar.CASILLA_W) // 2 * 2
        y0, y1, x0, x1 = int(y0), int(y1), int(x0), int(x1)
        hw, hh = (x1 - x0) // 2, (y1 - y0) // 2
        cols = min(n, 12)
        filas = (n + cols - 1) // cols
        hoja_ = Image.new('RGBA', (cols * hw, filas * hh), (0, 0, 0, 0))
        cuerpo, pies_ = [], []
        for j, im in enumerate(ims):
            arriba, cy, abajo = mf.medidas(np.asarray(im))
            cuerpo.append(round((ORIGEN - (arriba + cy) / 2.0) / 2.0, 1))
            pies_.append(round(max(ORIGEN - PLANTA - abajo, 0) / 2.0, 1))
            hoja_.alpha_composite(im.crop((x0, y0, x1, y1)).resize((hw, hh), Image.LANCZOS),
                                  ((j % cols) * hw, (j // cols) * hh))
        os.makedirs(SALIDA, exist_ok=True)
        archivo = 'magnus_%s.png' % nombre
        hoja_.save(os.path.join(SALIDA, archivo))
        hoja_.save(os.path.join(JUEGO, archivo))
        entrada = {
            'hoja': 'res://assets/characters/magnus/%s' % archivo,
            'n': n, 'cols': cols, 'casilla': [hw, hh], 'fps': fps, 'bucle': False,
            'offset': [-round(((pisar.CASILLA_W / 2.0 - x0) - (x1 - x0) / 2.0) / 2.0, 1),
                       -round(((ORIGEN - y0) - (y1 - y0) / 2.0) / 2.0, 1)],
            'cuerpo': cuerpo, 'pies': pies_,
        }
        entrada.update(extra)
        datos[nombre] = entrada
        print('%s: %d fotogramas, cuerpo %.1f -> %.1f, pies %.1f -> %.1f' % (
            nombre, n, cuerpo[0], cuerpo[-1], pies_[0], pies_[-1]))

    a0, b1 = tr['a'][0], tr['b'][1]
    l0, l1 = tr['l']
    destinos = [_centrado(_pm(todas[c])) for c in range(l0, l0 + ENTRADA_L)]
    # (indices desde 0) donde empieza el tramo B, a que ritmo va, desde donde
    # casa con el principio de flotar_girar, y por donde se pasaria de cada uno
    # a la llegada (si la hoja siguiente esta cerca, sin acabar de recoger las
    # piernas: casa desde ~69)
    a_llegar, casa_llegar = _entradas([_centrado(_pm(todas[c])) for c in range(a0, b1 + 1)], destinos)
    lamina('flotar_despegar', range(a0, b1 + 1), FPS_A,
           {'tramo_b': tr['b'][0] - a0, 'fps_b': FPS_B, 'giro_desde': tr['giro_desde'] - a0,
            'a_llegar': a_llegar, 'casa_llegar': casa_llegar})
    print('  despegar -> llegar: casan %s' % [f for f, c in enumerate(casa_llegar) if c])
    # LLEGAR: por donde se entra desde la bajada (sus 13 primeros, aun en la
    # pose) y desde el bucle quieto, y si casa
    fb0 = datos['flotar_bajar']
    nq = int(datos['flotar_quieto']['n'])
    cas = json.load(open(os.path.join(ANIM, 'magnus_flotar', 'casillas.json')))['anims']
    bajar = [_centrado(_pm(_flotar_en_lienzo(os.path.join(FLOTAR_LIMPIOS, 'c_%03d.png' % (cas['flotar_bajar'][0] + j)))))
             for j in range(13)]
    quieto = [_centrado(_pm(_flotar_en_lienzo(os.path.join(FLOTAR_LIMPIOS, 'c_%03d.png' % (cas['flotar_quieto'][0] + q)))))
              for q in range(nq)]
    de_bajar, casa_bajar = _entradas(bajar, destinos)
    de_quieto, casa_quieto = _entradas(quieto, destinos)
    # del bucle quieto a la bajada (a_bajar, ya en flotar.json): si casa
    _, casa_quieto_bajar = zip(*[(0, bool(s < CASA[0] and t < CASA[1])) for s, t in
                                 (_parecido(quieto[q], bajar[datos['flotar_quieto']['a_bajar'][q]]) for q in range(nq))])
    lamina('flotar_llegar', range(l0, l1 + 1), FPS_L,
           {'de_bajar': de_bajar, 'casa_bajar': casa_bajar, 'de_quieto': de_quieto, 'casa_quieto': casa_quieto})
    datos['flotar_quieto']['casa_bajar'] = list(casa_quieto_bajar)
    # del bucle quieto al giro en el aire (su primero, la pose): si casa
    hg = Image.open(datos['flotar_girar']['hoja'].replace('res://', PROYECTO + '/')).convert('RGBA')
    gw, gh = datos['flotar_girar']['casilla']
    giro0 = _centrado(_pm(hg.crop((0, 0, gw, gh)).resize((gw * 2, gh * 2))))
    casa_giro = [bool(s < CASA[0] and t < CASA[1]) for s, t in (_parecido(quieto[q], giro0) for q in range(nq))]
    datos['flotar_quieto']['casa_giro'] = casa_giro
    # LA COSTURA: el tramo del bucle alrededor de su vuelta (191 -> 3) en el
    # que casa con la bajada y con la llegada (los dos), sin huecos de uno
    ambos = [casa_quieto_bajar[q] and casa_quieto[q] for q in range(nq)]
    vuelta = 3
    desde = nq - 1
    while desde - 1 > vuelta and (ambos[desde - 1] or ambos[desde - 2]):
        desde -= 1
    hasta = vuelta
    while hasta + 1 < nq and (ambos[hasta + 1] or ambos[min(hasta + 2, nq - 1)]):
        hasta += 1
    datos['flotar_quieto']['costura'] = [desde, hasta]
    print('  llegar desde bajar:', de_bajar, '(casan %s)' % [j for j, c in enumerate(casa_bajar) if c])
    print('  llegar desde quieto: casan %s' % [q for q, c in enumerate(casa_quieto) if c])
    print('  quieto -> bajar: casan %s' % [q for q, c in enumerate(casa_quieto_bajar) if c])
    print('  quieto -> giro: casan %s' % [q for q, c in enumerate(casa_giro) if c])
    print('  costura del bucle quieto: %d -> %d' % (desde, hasta))
    json.dump(datos, open(FLOTAR_JSON, 'w'), indent=1)
    json.dump(datos, open(os.path.join(ANIM, 'magnus_flotar', '05_salida', 'flotar.json'), 'w'), indent=1)


if __name__ == '__main__':
    {'casillas': casillas, 'tono': tono, 'piernas': piernas, 'hoja': hoja}[sys.argv[1]]()

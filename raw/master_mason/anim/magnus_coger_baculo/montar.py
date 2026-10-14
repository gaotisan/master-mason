"""COGER EL BACULO (2026-10-14): el peregrino llega arriba por las hojas, coge el
baculo que flota en la luz y baja con el hasta el suelo. Video de Flow del usuario
(_fuentes/Wizard_leaps_to_grab_staff_20261014022005.mp4, 24 fps, ya a la escala
de master: de pie mide lo mismo y pisa en la fila 677). "Es justo lo que nos
falta: cuando llega arriba y se acerca de cara al baston lo agarra, el baston
suelta un destello de magia, torbellino de hojas, se descarga, queda la bola
vacia sin magia y aparece el camino" (los efectos los pone caida_hojarasca.gd).

El video (a 24 fps):
  60-84  se agacha y salta hacia el baston (en el juego ya llega por el aire)
  86-92  las manos llegan al baston; 92 lo agarra (AGARRA)
  96-146 cuelga de el, agachado en el aire
 146-176 baja con el hasta el suelo (los pies tocan hacia el SUELO)
 176-204 se pone de pie con el baston
 204-236 de pie, quieto
Se usa del DESDE al HASTA. La garra se sigue con una plantilla (la del f30, con
el baston solo) y va en el json por fotograma: el juego pone ahi la bola, que
se descarga, porque el baston del video tiene la garra vacia.

Pies: con unas como unas oscuras en gancho en la punta de los dedos (el
usuario: "revisa los pies, tienen unas protuberancias raras"): es el borde
verde del croma en los dedos (sin_fleco). Probado tambien quitar lo oscuro de
la franja de los pies y llevar el color al de los aceptados: cortaba el bajo de
la tunica agachado y agrisaba las piernas, que ya estaban bien.

  python montar.py casillas
  python ../igualar_tono.py magnus_coger_baculo "1-10"
  python montar.py pies
  python montar.py hoja        (anade coger_baculo a flotar.json)
"""
import glob
import json
import os
import shutil
import sys

import cv2
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
PROYECTO = os.path.abspath(os.path.join(ANIM, '..', '..', '..'))
sys.path.insert(0, os.path.join(ANIM, 'magnus_flotar'))
sys.path.insert(0, os.path.join(ANIM, 'magnus_pisar_hoja'))
sys.path.insert(0, os.path.join(ANIM, 'magnus_secuencia_frontal'))
import montar_flotar as mf   # noqa: E402  (fotogramas, sin_croma, medidas)
import pies as pp            # noqa: E402  (sin_verde, transferencias)
import igualar_piernas as ip  # noqa: E402

VIDEO = os.path.join(ANIM, '_fuentes', 'Wizard_leaps_to_grab_staff_20261014022005.mp4')
LIMPIOS = os.path.join(AQUI, '04_limpios')
VEO = os.path.join(AQUI, '04_limpios_veo')
SALIDA = os.path.join(AQUI, '05_salida')
JUEGO = os.path.join(PROYECTO, 'assets', 'characters', 'magnus')
FLOTAR_JSON = os.path.join(JUEGO, 'flotar.json')

# Empieza en el agarre: el cambio de pose (de como llegue por el aire) y el del
# baston del juego al del video caen en el destello, que los tapa. Antes de eso
# (86-91, las manos llegando) se veian los dos bastones.
DESDE, HASTA = 92, 214
AGARRA = 92          # las manos se cierran en el baston: el destello
FPS = 24.0
ESCALA = 0.99        # de pie mide 625 en el video y 619 el reposo del juego
CASILLA_W = 744      # ancha: el salto y el baston se salen de la de 584
EJE = 372            # x del eje del cuerpo (origen del nodo) en la casilla
PIES_X = EJE + 20.5  # como el c_01 del salto: el centro de los pies 20,5 px por delante
CASILLA_H = 750
ORIGEN = 720         # linea de suelo (690 de master + 30 por arriba)
PLANTA = 13
AJUSTE_Y = -4
PIES_FINAL = None    # se mide: centro de los pies y planta en el ultimo fotograma
PLANTILLA = (30, 760, 50, 836, 150)   # fotograma y caja de la garra sola
ANCLA = (795, 105)   # el hueco de la garra (donde va la bola) en esa caja
FLECO_ALTO = 90      # filas del final de la figura donde se limpia el borde verde


def _no_verde(f):
    hsv = cv2.cvtColor(f, cv2.COLOR_RGB2HSV)
    return ~((hsv[..., 0] > 35) & (hsv[..., 0] < 85) & (hsv[..., 1] > 80))


def registro():
    """dx, dy: los pies del ultimo fotograma (de pie) en los del juego."""
    for i, f in mf.fotogramas(VIDEO, HASTA, HASTA):
        r = mf.sin_croma(f)
        al = r[..., 3] > 128
        al[:, 690:] = False            # sin el baston, que va delante
        ys = np.nonzero(al.any(1))[0]
        yb = ys.max()
        xs = np.nonzero(al[yb - 25:yb + 1].any(0))[0]
        cx = (xs.min() + xs.max()) / 2.0
    dx = round(PIES_X - cx * ESCALA)
    # AJUSTE_Y: con los pies en la planta, el cuerpo quedaba 4 px por debajo
    # del reposo con el baston en la mano (mano_reposo, lo que sigue): medido por
    # solape del cuerpo (0,893; en x ya casaba).
    dy = round((ORIGEN - PLANTA) - yb * ESCALA) + AJUSTE_Y
    return dx, dy


def garra():
    """Hueco de la garra por fotograma, en px del video (plantilla con mascara,
    buscando cerca de donde estaba)."""
    fs = dict(mf.fotogramas(VIDEO, 0, HASTA))
    k, x0, y0, x1, y1 = PLANTILLA
    T = fs[k][y0:y1, x0:x1].copy()
    Tm = (_no_verde(fs[k])[y0:y1, x0:x1].astype(np.uint8) * 255)
    Tm3 = cv2.merge([Tm, Tm, Tm])
    out = {}
    prev = None
    for i in range(DESDE - 6, HASTA + 1):
        r = cv2.matchTemplate(fs[i], T, cv2.TM_CCORR_NORMED, mask=Tm3)
        if prev is not None:
            sub = np.full_like(r, -1.0)
            ya, xa = max(prev[1] - 60, 0), max(prev[0] - 60, 0)
            sub[ya:prev[1] + 60, xa:prev[0] + 60] = r[ya:prev[1] + 60, xa:prev[0] + 60]
            r = sub
        _, mx, _, loc = cv2.minMaxLoc(r)
        prev = loc
        out[i] = (loc[0] + ANCLA[0] - x0, loc[1] + ANCLA[1] - y0, float(mx))
    return out


def casillas():
    os.makedirs(LIMPIOS, exist_ok=True)
    for f in glob.glob(os.path.join(LIMPIOS, 'c_*.png')):
        os.remove(f)
    if os.path.isdir(VEO):
        shutil.rmtree(VEO)
    dx, dy = registro()
    k = 1
    for i, f in mf.fotogramas(VIDEO, DESDE, HASTA):
        rgba = mf.sin_croma(f)
        im = Image.fromarray(rgba).resize((round(mf.VW * ESCALA), round(mf.VH * ESCALA)), Image.LANCZOS)
        lien = Image.new('RGBA', (CASILLA_W, CASILLA_H), (0, 0, 0, 0))
        lien.alpha_composite(im, (dx, dy))
        lien.save(os.path.join(LIMPIOS, 'c_%03d.png' % k))
        k += 1
    json.dump({'registro': [dx, dy]}, open(os.path.join(AQUI, 'casillas.json'), 'w'))
    print('casillas: video %d-%d -> c_001-c_%03d (registro %d, %d)' % (DESDE, HASTA, k - 1, dx, dy))


def sin_fleco(a):
    """Lo que parecian unas oscuras en gancho en la punta de los dedos es el
    borde verde del croma pegado a lo mas fino (los dedos): en la zona de
    piernas y pies (FLECO_ALTO filas del final de la figura) el verde no pasa
    del mayor de rojo y azul, y el borde que era verde y casi transparente se
    difumina. El color de piernas y pies del video ya era el de los aceptados
    (pardo morado apagado): no se toca."""
    b = a.astype(int)
    al = b[..., 3] > 8
    ys = np.nonzero(al.any(1))[0]
    zona = np.zeros(al.shape, bool)
    zona[ys.max() - FLECO_ALTO:ys.max() + 1] = True
    tope = np.maximum(b[..., 0], b[..., 2])
    exceso = b[..., 1] - tope
    verde = zona & (exceso > 0)
    b[..., 1] = np.where(verde, tope, b[..., 1])
    borde = verde & (exceso > 8) & (b[..., 3] < 235)
    b[..., 3] = np.where(borde, (b[..., 3] * 0.3).astype(int), b[..., 3])
    return np.clip(b, 0, 255).astype(np.uint8)


def pies():
    if not os.path.isdir(VEO):
        shutil.copytree(LIMPIOS, VEO)
    for r in sorted(glob.glob(os.path.join(VEO, 'c_*.png'))):
        Image.fromarray(sin_fleco(pp.leer(r))).save(os.path.join(LIMPIOS, os.path.basename(r)))


def hoja():
    dx, dy = json.load(open(os.path.join(AQUI, 'casillas.json')))['registro']
    tr = garra()
    rutas = sorted(glob.glob(os.path.join(LIMPIOS, 'c_*.png')))
    ims = [Image.open(r).convert('RGBA') for r in rutas]
    n = len(ims)
    y0 = x0 = 10 ** 6
    y1 = x1 = 0
    for im in ims:
        ys, xs = np.where(np.asarray(im)[..., 3] > 8)
        y0, y1, x0, x1 = min(y0, ys.min()), max(y1, ys.max()), min(x0, xs.min()), max(x1, xs.max())
    y0, x0 = max(y0 - 4, 0) // 2 * 2, max(x0 - 4, 0) // 2 * 2
    y1, x1 = min(y1 + 6, CASILLA_H) // 2 * 2, min(x1 + 6, CASILLA_W) // 2 * 2
    y0, y1, x0, x1 = int(y0), int(y1), int(x0), int(x1)
    hw, hh = (x1 - x0) // 2, (y1 - y0) // 2
    cols = min(n, 12)
    filas = (n + cols - 1) // cols
    lamina = Image.new('RGBA', (cols * hw, filas * hh), (0, 0, 0, 0))
    cuerpo, pies_, garras = [], [], []
    for j, im in enumerate(ims):
        a = np.asarray(im)
        # cuerpo y pies sin el baston (va delante, a la derecha del cuerpo)
        sin_baston = a.copy()
        gx = tr[DESDE + j][0] * ESCALA + dx
        sin_baston[:, int(gx) - 22:] = 0
        arriba, cy, abajo = mf.medidas(sin_baston)
        cuerpo.append(round((ORIGEN - (arriba + cy) / 2.0) / 2.0, 1))
        pies_.append(round(max(ORIGEN - PLANTA - abajo, 0) / 2.0, 1))
        gxv, gyv, _ = tr[DESDE + j]
        garras.append([round((gxv * ESCALA + dx - EJE) / 2.0, 1), round((gyv * ESCALA + dy - ORIGEN) / 2.0, 1)])
        lamina.alpha_composite(im.crop((x0, y0, x1, y1)).resize((hw, hh), Image.LANCZOS),
                               ((j % cols) * hw, (j // cols) * hh))
    # El suelo: el primer fotograma desde el que los pies se quedan abajo.
    suelo = n - 1
    for j in range(n - 1, -1, -1):
        if pies_[j] > 2.0:
            break
        suelo = j
    os.makedirs(SALIDA, exist_ok=True)
    archivo = 'magnus_coger_baculo.png'
    lamina.save(os.path.join(SALIDA, archivo))
    lamina.save(os.path.join(JUEGO, archivo))
    entrada = {
        'hoja': 'res://assets/characters/magnus/%s' % archivo,
        'n': n, 'cols': cols, 'casilla': [hw, hh], 'fps': FPS, 'bucle': False,
        'offset': [-round(((EJE - x0) - (x1 - x0) / 2.0) / 2.0, 1),
                   -round(((ORIGEN - y0) - (y1 - y0) / 2.0) / 2.0, 1)],
        'cuerpo': cuerpo, 'pies': pies_,
        # el hueco de la garra (donde va la bola) respecto al origen del nodo
        'garra': garras,
        'agarra': AGARRA - DESDE,
        'suelo': suelo,
    }
    datos = json.load(open(FLOTAR_JSON))
    datos['coger_baculo'] = entrada
    json.dump(datos, open(FLOTAR_JSON, 'w'), indent=1)
    json.dump(datos, open(os.path.join(ANIM, 'magnus_flotar', '05_salida', 'flotar.json'), 'w'), indent=1)
    print('coger_baculo: %d fotogramas a %.0f fps (%.1f s), agarra en %d, suelo en %d; pies %.1f -> %.1f; garra %s -> %s' % (
        n, FPS, n / FPS, AGARRA - DESDE, suelo, pies_[0], pies_[-1], garras[0], garras[-1]))


if __name__ == '__main__':
    {'casillas': casillas, 'pies': pies, 'hoja': hoja}[sys.argv[1]]()

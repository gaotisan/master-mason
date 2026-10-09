"""Puentes por flujo optico entre los andares de frente/espaldas y la vuelta con baston.

Por que (2026-10-08): la vuelta (vuelta_frontal) sale de otro video que los
andares: la tunica esta redibujada (parches en otro sitio) y el baston en otra
postura. Enlazar con un fundido de opacidad dejaba DOS dibujos superpuestos
(piernas y baston dobles): el usuario lo veia como un emborronado al girar.
Cortar sin fundido tampoco: el mejor enganche esta a 0,185 (unos 4 cambios
normales de fotograma).

Un puente son N fotogramas intermedios que DEFORMAN un dibujo hacia el otro
(flujo optico DIS de OpenCV en los dos sentidos: cada intermedio es la mezcla
de A llevado hacia B y B traido desde A, en el mismo sitio), asi no hay doble
imagen: es lo que hace Veo entre sus fotogramas.

Puentes (A -> B; el mismo al reves sirve para el otro sentido):
  puente_frente     andar_frente c_005 (con la garra pegada, como la pinta la
                    escena) -> vuelta c_001
  puente_frente_b   andar_frente c_026 (el otro pie) -> vuelta c_001
  puente_espalda    vuelta c_049 -> andar_espalda c_014 (pies juntos)
  puente_espalda_b  andar_espalda c_028 (el otro pie) -> vuelta c_049
Todos en la casilla de la vuelta (584x800, mismo suelo: los andares bajan 80).
Escribe 04_limpios/<puente>_<k>.png y bola.json (la bola, interpolada entre
la de los extremos, px de hoja respecto al centro de la casilla de 400).
    python puente.py
"""
import glob, json, os
import cv2
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
PROY = os.path.abspath(os.path.join(ANIM, '..', '..', '..'))
BASTON = os.path.join(PROY, 'assets', 'characters', 'baston')
N = 4                      # intermedios por puente
ALTO = 800                 # casilla de la vuelta
SUBE = ALTO - 720          # lo que bajan los sprites de los andares en ella

FRONTAL = json.load(open(os.path.join(BASTON, 'frontal.json')))


def andar(job, k):
    a = Image.open(os.path.join(ANIM, job, '04_limpios', 'c_%03d.png' % k)).convert('RGBA')
    c = Image.new('RGBA', (584, ALTO), (0, 0, 0, 0)); c.paste(a, (0, SUBE))
    return c


def con_garra(img, k):
    """La garra pegada del andar de frente, como la pone la escena."""
    d = FRONTAL['andar_frente']
    gx, gy, giro = d['garra'][k - 1]
    tex = Image.open(os.path.join(BASTON, 'garra_frente.png')).convert('RGBA')
    tex = tex.resize((tex.width // 2, tex.height // 2), Image.LANCZOS)          # 2x master -> master
    px, py = d['garra_pivote'][0] / 2, d['garra_pivote'][1] / 2
    lado = 2 * int(max(tex.size) + 10)
    lienzo = Image.new('RGBA', (lado, lado), (0, 0, 0, 0))
    lienzo.paste(tex, (round(lado / 2 - px), round(lado / 2 - py)))
    lienzo = lienzo.rotate(-np.degrees(giro), resample=Image.BICUBIC, center=(lado / 2, lado / 2))
    capa = Image.new('RGBA', img.size, (0, 0, 0, 0))
    capa.paste(lienzo, (round((gx + 146) * 2 - lado / 2), round((gy + 180) * 2 + SUBE - lado / 2)))
    out = img.copy(); out.alpha_composite(capa)
    return out


def vuelta(k):
    return Image.open(os.path.join(ANIM, 'magnus_vuelta_frontal', '04_limpios', 'c_%03d.png' % k)).convert('RGBA')


def flujo(a, b):
    ga = cv2.cvtColor(a, cv2.COLOR_RGB2GRAY); gb = cv2.cvtColor(b, cv2.COLOR_RGB2GRAY)
    dis = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
    return dis.calc(ga, gb, None)


def deformar(img, f, t):
    """img(y - t f(y)): lleva img una fraccion t a lo largo del flujo f."""
    h, w = f.shape[:2]
    gx, gy = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    return cv2.remap(img, gx - t * f[..., 0], gy - t * f[..., 1], cv2.INTER_LINEAR, borderValue=0)


def premul(im):
    a = np.asarray(im).astype(np.float32) / 255
    a[..., :3] *= a[..., 3:]
    return a


def puente(A, B):
    a, b = premul(A), premul(B)
    # el flujo se mide sobre el dibujo encima de negro (el fondo de la escena es oscuro)
    a8 = (a[..., :3] * 255).astype(np.uint8); b8 = (b[..., :3] * 255).astype(np.uint8)
    fab, fba = flujo(a8, b8), flujo(b8, a8)
    out = []
    for k in range(1, N + 1):
        t = k / (N + 1)
        at = deformar(a, fab, t)              # A llevado una fraccion t hacia B
        bt = deformar(b, fba, 1 - t)          # B traido desde A
        m = (1 - t) * at + t * bt
        al = np.clip(m[..., 3:], 1e-4, 1)
        rgb = np.where(m[..., 3:] > 1e-4, m[..., :3] / al, 0)
        out.append(Image.fromarray((np.dstack([rgb, m[..., 3]]) * 255).round().clip(0, 255).astype(np.uint8), 'RGBA'))
    return out


def bola(anim, k):
    """Bola del extremo, en px de hoja respecto al centro de la casilla de 400."""
    d = FRONTAL[anim]
    x, y = d['orbe'][k - 1]
    if anim != 'vuelta_frontal':
        y += (ALTO - 720) / 4         # el centro de la de 400 esta 20 px de hoja mas arriba
    return x, y, d['escala_bola']


if __name__ == '__main__':
    PUENTES = {
        'puente_frente':    ((lambda: con_garra(andar('magnus_andar_frente', 5), 5)), ('andar_frente', 5),
                             (lambda: vuelta(1)), ('vuelta_frontal', 1)),
        'puente_frente_b':  ((lambda: con_garra(andar('magnus_andar_frente', 26), 26)), ('andar_frente', 26),
                             (lambda: vuelta(1)), ('vuelta_frontal', 1)),
        'puente_espalda':   ((lambda: vuelta(49)), ('vuelta_frontal', 49),
                             (lambda: andar('magnus_andar_espalda', 14)), ('andar_espalda', 14)),
        'puente_espalda_b': ((lambda: andar('magnus_andar_espalda', 28)), ('andar_espalda', 28),
                             (lambda: vuelta(49)), ('vuelta_frontal', 49)),
    }
    SAL = os.path.join(AQUI, '04_limpios'); os.makedirs(SAL, exist_ok=True)
    for f in glob.glob(os.path.join(SAL, '*.png')):
        os.remove(f)
    bolas = {}
    for nombre, (fa, ea, fb, eb) in PUENTES.items():
        frames = puente(fa(), fb())
        ba, bb = bola(*ea), bola(*eb)
        bolas[nombre] = []
        for k, im in enumerate(frames, 1):
            im.save(os.path.join(SAL, '%s_%d.png' % (nombre, k)))
            t = k / (N + 1)
            bolas[nombre].append([round(ba[i] * (1 - t) + bb[i] * t, 3) for i in range(3)])
        print(nombre, len(frames), 'intermedios')
    json.dump(bolas, open(os.path.join(AQUI, 'bola.json'), 'w'), indent=1)

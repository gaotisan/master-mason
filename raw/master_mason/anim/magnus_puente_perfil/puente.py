"""Puentes perfil <-> frontal: los fotogramas que pasan del peregrino de perfil
(magnus.tscn con baston.gd) al de frente/espaldas (PeregrinoFrontal) sin corte.
Ver como_se_hizo.txt.

Cada puente va de A (un fotograma del de perfil, quieto) a la secuencia B (los
fotogramas del frontal que siguen, en movimiento): el fotograma k del puente es
A llevado hacia B_k. Por piezas, como lo haria un animador:
  - CUERPO: la forma de A pasa a la de B_k por la silueta (contornos emparejados
    entre anclas: capucha, barba, bajo de la tunica, pies, espalda -> un mapa
    suave, TPS) y el movimiento propio de B (flujo entre fotogramas del mismo
    video). El dibujo de la tunica cambia con un barrido que entra por el lado
    que gira hacia la camara, no con un fundido de golpe.
  - BASTON: pieza rigida. Su postura (garra, eje, largo) va de la de A a la de
    B_k; las dos texturas (la del perfil y la del frontal) se cruzan en el
    camino. Detras del cuerpo, salvo lo que en B ya va delante.
    python puente.py [nombre ...]"""
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image

import morph as M

AQUI = os.path.dirname(os.path.abspath(__file__))
SALIDA = os.path.join(AQUI, '04_limpios')
PREVIA = os.path.join(AQUI, '_previa')

# nombre: lado y fotograma de A, lado de B, animacion y primer fotograma de B
# (el que sigue al puente es b0 + n + 1), intermedios, dx del frontal respecto
# al de perfil (px; salida_dx de la hojarasca), barrido del dibujo (de la parte
# t0..t1 del puente) y hacia donde entra el dibujo nuevo (-1: por la izquierda).
PUENTES = {
    # la ida, del perfil a espaldas (al reves, la vuelta de espaldas al perfil)
    'ida_sb': dict(variantes=[0, 10, 20], a=('lat_sb', 'reposo_000', None), b=('fr_sb', 'vuelta_sb', None), b0=26, n=9,
                   dx_a=0.0, dx_b=6.0, barrido=(0.2, 0.9), entra=-1),
    'ida_cb': dict(variantes=[0, 15, 30, 45, 60], a=('lat_mano', 'reposo_000', 'der'), b=('fr_cb', 'vuelta_cb', 'todo'), b0=20, n=8,
                   dx_a=0.0, dx_b=6.0, barrido=(0.2, 0.9), entra=-1),
    # de frente al perfil: del reposo de frente al giro del de perfil (ENTRADA_GIRO
    # de la hojarasca: el de perfil va giro[1] px al lado)
    'frente_sb': dict(a=('fr_sb', 'reposo_frente_sb_000', None), b=('lat_sb', 'giro', None), b0=24, n=9,
                      dx_a=0.0, dx_b=0.0, barrido=(0.2, 0.9), entra=1),
    'frente_cb': dict(a=('fr_cb', 'reposo_frente_cb_000', 'izq'), b=('lat_mano', 'giro', 'izq'), b0=32, n=9,
                      dx_a=0.0, dx_b=8.0, barrido=(0.2, 0.9), entra=1),
}


def piezas(lado, nombre, dx, pintado):
    """(entero, cuerpo, baston, delante) de una captura. pintado: None si el
    baston es capa aparte (capturas _cuerpo / _baston); si viene pintado en el
    sprite, de que lado de la figura va ('izq', 'der' o 'todo')."""
    F = M.cargar(lado, nombre, dx)
    if pintado is None:
        C = M.cargar(lado + '_cuerpo', nombre, dx)
        B = M.cargar(lado + '_baston', nombre, dx)
        d = np.abs(F - M.sobre(C, B)).sum(2)
        dl = np.clip((d - 0.05) / 0.2, 0, 1) * (C[..., 3] > 0.3) * B[..., 3]
        return F, C, B, dl.astype(np.float32)
    C, B, dl = M.separar(F, None if pintado == 'todo' else pintado)
    return F, C, B, dl


# ---------------------------------------------------------------- el baston

def postura(alfa):
    """Del baston (alfa de su capa): garra (centro de lo de arriba), direccion de
    abajo a arriba (unitaria) y largo."""
    ys, xs = np.nonzero(alfa > 0.5)
    p = np.c_[xs, ys].astype(np.float64)
    c = p.mean(0)
    u, s, vt = np.linalg.svd(p - c, full_matrices=False)
    eje = vt[0]
    if eje[1] > 0:               # hacia arriba (y pantalla hacia abajo)
        eje = -eje
    proy = (p - c) @ eje
    largo = proy.max() - proy.min()
    arriba = p[proy > proy.max() - 70]           # la garra: los 70 px de arriba
    garra = arriba.mean(0)
    # su tamano: el ancho de la garra de traves al eje (el largo no vale: el palo
    # del de perfil se corta en el hombro)
    normal = np.r_[-eje[1], eje[0]]
    t = (arriba - garra) @ normal
    ancho = np.percentile(t, 95) - np.percentile(t, 5)
    return garra, eje, ancho


def semejanza(pa, pb, s):
    """Matriz 2x3 que lleva la postura pa una fraccion s hacia pb (giro y escala
    alrededor de la garra, que viaja en recta)."""
    ga, ea, la = pa
    gb, eb, lb = pb
    ang = np.arctan2(eb[1], eb[0]) - np.arctan2(ea[1], ea[0])
    ang = (ang + np.pi) % (2 * np.pi) - np.pi
    a = s * ang
    # misma escala: los dos lados pintan el baston igual de grande (el ancho de la
    # garra cambia con el angulo de vista y lo estiraba)
    k = 1.0
    g = ga + s * (gb - ga)
    c, sn = np.cos(a) * k, np.sin(a) * k
    # x' = R (x - ga) + g
    return np.float64([[c, -sn, g[0] - c * ga[0] + sn * ga[1]],
                       [sn, c, g[1] - sn * ga[0] - c * ga[1]]])


def mover(img, m):
    h, w = img.shape[:2]
    return cv2.warpAffine(img, m, (w, h), flags=cv2.INTER_LINEAR, borderValue=0)


def inversa(pa, pb, s):
    """De la postura pb a la intermedia (la de pa llevada s hacia pb)."""
    mi = semejanza(pa, pb, s)
    mb = semejanza(pa, pb, 1.0)
    # intermedia = mi o mb^-1
    mb3 = np.vstack([mb, [0, 0, 1]])
    mi3 = np.vstack([mi, [0, 0, 1]])
    return (mi3 @ np.linalg.inv(mb3))[:2]


# ---------------------------------------------------------------- un puente

def delante(lado, nombre, dx):
    """Lo del baston que va delante del cuerpo en esa captura (0..1)."""
    F = M.cargar(lado, nombre, dx)
    C = M.cargar(lado + '_cuerpo', nombre, dx)
    B = M.cargar(lado + '_baston', nombre, dx)
    d = np.abs(F - M.sobre(C, B)).sum(2)
    return np.clip((d - 0.05) / 0.2, 0, 1) * (C[..., 3] > 0.3) * B[..., 3]


def barrido(alfa_union, t, t0, t1, entra, ancho=0.45):
    """0..1 por pixel: cuanto dibujo de B. Un frente que cruza la figura de lado
    a lado (entra = -1: de izquierda a derecha) entre t0 y t1 del puente."""
    xs = np.nonzero(alfa_union.any(0))[0]
    x0, x1 = xs.min(), xs.max()
    h, w = alfa_union.shape
    xn = (np.arange(w) - x0) / max(x1 - x0, 1)
    if entra > 0:
        xn = 1 - xn
    u = (t - t0) / (t1 - t0)                     # 0..1 del barrido
    frente = -ancho + u * (1 + 2 * ancho)
    v = np.clip((frente - xn) / ancho + 0.5, 0, 1)
    v = v * v * (3 - 2 * v)
    return np.broadcast_to(v[None, :], (h, w)).astype(np.float32)


def hacer(nombre, cfg):
    la, na, pa_ = cfg['a']
    lb, anim, pb_ = cfg['b']
    b0, n = cfg['b0'], cfg['n']
    _, A_c, A_b, A_d = piezas(la, na, cfg['dx_a'], pa_)
    pos_a = postura(A_b[..., 3])
    cuadros, garras = [], []
    for k in range(1, n + 1):
        t = k / (n + 1)
        s = M.suave(t)
        _, B_c, B_b, B_d = piezas(lb, '%s_%03d' % (anim, b0 + k), cfg['dx_b'], pb_)
        # el cuerpo: la forma, A <-> B_k por sus contornos; el dibujo, con el barrido
        g_a, g_b = M.mapas(A_c, B_c)
        ca_k = M.empujar(A_c, g_a, s)
        cb_k = M.empujar(B_c, g_b, 1 - s)
        v = barrido((ca_k[..., 3] > 0.05) | (cb_k[..., 3] > 0.05), t, *cfg['barrido'], cfg['entra'])
        cuerpo = M.juntar(ca_k, cb_k, s, v, suavizar_a=0.6 * s)
        # el baston, rigido
        pos_b = postura(B_b[..., 3])
        ma = semejanza(pos_a, pos_b, s)
        mb = inversa(pos_a, pos_b, s)
        vb = M.suave((t - 0.2) / 0.6)
        baston = (1 - vb) * mover(A_b, ma) + vb * mover(B_b, mb)
        # lo de delante solo cerca de cada extremo: a medio camino el baston va por
        # detras (si no, el tramo del hombro de B rayaba la capucha)
        dl = ((1 - vb) * (1 - M.suave(t / 0.3)) * mover(A_d, ma)
              + vb * M.suave((t - 0.7) / 0.3) * mover(B_d, mb))[..., None]
        # detras del cuerpo; encima, lo que ya va delante
        cuadros.append(M.sobre(baston * dl, M.sobre(cuerpo, baston)))
        g = ma @ np.r_[pos_a[0], 1]
        garras.append([float(g[0]), float(g[1])])
    return cuadros, garras


def previa(nombre, cfg, cuadros):
    """Tira y medidas: A, el puente y lo que sigue, sobre el fondo oscuro."""
    la, na, _ = cfg['a']
    lb, anim, _ = cfg['b']
    sigue = ['%s_%03d' % (anim, cfg['b0'] + cfg['n'] + j) for j in range(1, 7)]
    sigue = [x for x in sigue if os.path.exists(os.path.join(M.CAP, lb, x + '.png'))]
    seq = [M.cargar(la, na, cfg['dx_a'])] * 2 + cuadros + [M.cargar(lb, x, cfg['dx_b']) for x in sigue]
    fondo = np.zeros_like(seq[0]); fondo[..., :3] = (0.16, 0.13, 0.11); fondo[..., 3] = 1
    os.makedirs(os.path.join(PREVIA, nombre), exist_ok=True)
    ims = []
    for j, m in enumerate(seq):
        im = M.a_imagen(M.sobre(m, fondo)).convert('RGB')
        im.save(os.path.join(PREVIA, nombre, 'f%03d.png' % j))
        ims.append(np.asarray(im).astype(np.float32))
    cambio = []
    for j in range(1, len(ims)):
        m = (np.abs(ims[j] - ims[j][1, 1]).sum(2) > 20) | (np.abs(ims[j - 1] - ims[j][1, 1]).sum(2) > 20)
        cambio.append(np.abs(ims[j] - ims[j - 1]).sum(2)[m].mean())
    print(nombre, 'cambio por fotograma:', ' '.join('%.0f' % c for c in cambio))


DESTINO = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(AQUI)))),
                       'assets', 'characters', 'magnus', 'puente_perfil')


def exportar(nombre, cfg, cuadros, ficha):
    """Hoja (una fila por puente) recortada a lo que ocupan sus fotogramas, y su
    ficha: tamano de casilla, donde van los pies en ella, y el empalme (b0, n, dx
    del otro lado)."""
    ims = [M.a_imagen(c) for c in cuadros]
    caja = None
    for im in ims:
        b = im.getbbox()
        caja = b if caja is None else (min(caja[0], b[0]), min(caja[1], b[1]), max(caja[2], b[2]), max(caja[3], b[3]))
    x0, y0, x1, y1 = caja[0] - 2, caja[1] - 2, caja[2] + 2, caja[3] + 2
    w, h = x1 - x0, y1 - y0
    hoja = Image.new('RGBA', (w * len(ims), h), (0, 0, 0, 0))
    for k, im in enumerate(ims):
        hoja.paste(im.crop((x0, y0, x1, y1)), (k * w, 0))
    os.makedirs(DESTINO, exist_ok=True)
    hoja.save(os.path.join(DESTINO, nombre + '.png'))
    ficha[nombre] = {'hoja': 'res://assets/characters/magnus/puente_perfil/%s.png' % nombre,
                     'n': len(ims), 'casilla': [w, h], 'pies': [M.PIES[0] - x0, M.PIES[1] - y0],
                     'b0': cfg['b0'], 'sigue': cfg['b0'] + cfg['n'] + 1, 'dx': cfg['dx_b']}


if __name__ == '__main__':
    ficha = {}
    for nombre in sys.argv[1:] or list(PUENTES):
        cfg = PUENTES[nombre]
        for v in cfg.get('variantes', [None]):
            c = dict(cfg)
            nom = nombre
            if v is not None:
                c['a'] = (cfg['a'][0], 'reposo_%03d' % v, cfg['a'][2])
                nom = '%s_r%02d' % (nombre, v)
            cuadros, garras = hacer(nom, c)
            previa(nom, c, cuadros)
            exportar(nom, c, cuadros, ficha)
    ruta = os.path.join(DESTINO, 'puente_perfil.json')
    viejo = json.load(open(ruta)) if os.path.exists(ruta) else {}
    viejo.update(ficha)
    json.dump(viejo, open(ruta, 'w'), indent=1)

"""Monta una accion de perfil que desplaza al peregrino (trepar, bajar, empujar),
de 04_limpios (recortado por raiz.py, sin fondo, pulido) a 04_acciones/ y al
json que lee el juego.

  - Tono estandar de la tunica (igualar_tono.py), medido en el primer fotograma
    (el reposo del video).
  - Restos del croma: quitar_verde() de peregrino_giro_frente/espejo.py.
  - El primer fotograma y el ultimo, al reposo del juego (peregrino_respirando
    c_01), que es lo que hay antes y despues: primero la forma, moviendo pixeles
    (flujo optico hasta el reposo, que se apaga en N_EXT fotogramas viajando con
    el movimiento del video) y lo que queda con un fundido de N_FUNDIDO, con el
    hombre aun quieto. Como en los giros (giro_video.py).
  - Tramos: una accion de una pasada es un tramo; empujar son tres (entrada,
    ciclo y salida) sacados del mismo video, el ciclo sin tocar (ni fundidos ni
    flujo: sus costuras son las del video).

Todo va en una sola hoja por job (04_acciones/, c_001.. en orden); los tramos
son rangos de casillas (indices en _spriteframes.py). El json (<job>/accion.json,
y todos juntos en assets/characters/peregrino/acciones_perfil.json) lleva, por
animacion y en px de la hoja (los del juego): la casilla y el offset del sprite
(la raiz en el origen del nodo, como offset_comun), la raiz de cada fotograma
respecto al primero del tramo, lo que avanza cada eje (s, 0..1: para cambiar en
el juego la altura del muro o del salto sin tocar el dibujo) y, si empuja, donde
va la cara del objeto respecto a la raiz.

  python montar_accion.py <job>
  python montar_accion.py <job> --buscar-ciclo DESDE HASTA   (empujar: candidatos de ciclo)
"""
import argparse, json, os, shutil, sys
import cv2
import numpy as np
from PIL import Image
from scipy import ndimage

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(AQUI, 'peregrino_giro_frente'))
import espejo as E                      # mover, flujo, deformar, llevar, fundir, quitar_verde, suave
tono = E.tono

REPOSO = os.path.join(AQUI, 'peregrino_respirando', '04_limpios', 'c_01.png')
JUEGO = os.path.abspath(os.path.join(AQUI, '..', '..', '..', 'assets', 'characters', 'peregrino', 'acciones_perfil.json'))
N_EXT, N_FUNDIDO = 8, 5
FPS = 24.0

# Tramos por job: (animacion, primera casilla, ultima casilla) de 04_limpios,
# 1-based e inclusivas; None = hasta el final. 'bucle': el tramo que se repite.
# 'cara': el lado del objeto de relleno (objeto.json) donde empieza la accion:
# la cara izquierda del muro o del sillar al trepar, el borde derecho al bajar.
#
# 'pies': la raiz en x sale del pie apoyado y no del video. En los dos empujes
# los pies apoyados resbalan hacia atras (en el v1 ~3 px de master por
# fotograma mientras el cuerpo avanza 4; en el v2 el cuerpo casi no avanza y
# anda en el sitio, con los dos pies resbalando a la vez): el nodo avanza lo
# que el pie apoyado se va hacia atras en la casilla, asi el pie queda quieto
# en el suelo, y el sillar va con las manos (su cara respecto a la casilla es
# la del video). Empuja mas lejos que en el video, a su paso.
# Ninguno trae un ciclo que cierre (la mejor costura, a mas de 2 pasos
# normales): de momento cada empuje es una pasada entera (entrada, empuje y
# salida); para repetirlo hace falta un video con inicio = fin = un fotograma
# del empuje, como el del andar con el baston.
ACCIONES = {
    'peregrino_trepar': {'tramos': [('trepar', 1, None)], 'cara': 'izquierda'},
    'peregrino_trepar_mediano': {'tramos': [('trepar_mediano', 1, None)], 'cara': 'izquierda'},
    'peregrino_bajar': {'tramos': [('bajar', 1, None)], 'cara': 'derecha', 'polvo': True,
                     'tapar': [(70, 73, (350, 570, 400, 620))],      # el agujero de la cadera al levantarse
                     'rehacer_bajo': [(69, (200, 663, 362, 743)), (70, (245, 663, 362, 743))]},
    'peregrino_empujar': {'tramos': [('empujar', 1, None)], 'pies': True},
    'peregrino_empujar_v2': {'tramos': [('empujar_v2', 1, None)], 'pies': True},
    # segunda tanda (2026-10-12): sin objeto que se mueva. Lo pequeno que coge o
    # lanza (piedrecita, palo) y el baculo clavado van en el dibujo (el juego
    # esconde los suyos mientras dura); la mesa se quita (quitar_objeto.py).
    'peregrino_golpe': {'tramos': [('golpe', 1, None)]},
    'peregrino_derribo': {'tramos': [('derribo', 1, None)]},
    'peregrino_coger_suelo': {'tramos': [('coger_suelo', 1, None)]},
    'peregrino_coger_mesa': {'tramos': [('coger_mesa', 1, None)], 'cara': 'izquierda'},
    'peregrino_lanzar_palo': {'tramos': [('lanzar_palo', 1, None)], 'lanza': True},
    # arrancar acaba en el reposo con el baston en la mano; clavar es arrancar
    # del reves (las mismas casillas en orden inverso), hasta que haya video.
    # 'garra': donde va la bola en cada fotograma (el baculo del video no la
    # lleva; la pone el juego, como con el baston en la mano)
    'peregrino_arrancar': {'tramos': [('arrancar', 1, None)], 'ref_fin': 'mano', 'reverso': {'arrancar': 'clavar'},
                        'garra': True},
    # tumbarse: se tumba (c1-c74), se arrastra (c75-c123, el arrastre: vuelve a
    # empezar en el c75, que es el mas parecido al c124, a 1,8 pasos) y se
    # levanta (c124-). Tumbado se queda en el ultimo de tumbarse o del arrastre.
    'peregrino_tumbarse': {'tramos': [('tumbarse', 1, 74), ('arrastrarse', 75, 123), ('levantarse_tumbado', 124, None)],
                        'bucle': 'arrastrarse'},
    # tirar: el sillar (quitado por color, se ladea en el video) va con las manos
    'peregrino_tirar': {'tramos': [('tirar', 1, None)], 'pies': 'tira'},
}
PLANTA = 13          # la planta del pie, px de master sobre la linea de suelo (677 de 690)


def pies_apoyados(a, ry):
    """(x de la suela de cada pie que puede pisar, fila del suelo) en la casilla.
    El suelo de cada fotograma es su fila mas baja (los videos no pisan siempre
    a la misma altura: empujando, hasta ~10 px por encima del reposo). Pies:
    grupos de columnas en los 40 px de abajo cuya parte de abajo queda a menos
    de 16 px del suelo (el pie de detras de la pierna se dibuja algo mas alto,
    por la perspectiva: no vale "el mas bajo")."""
    op = a[..., 3] > 128
    filas = np.where(op[:ry + 30].any(1))[0]
    suelo = int(filas.max())
    banda = op[suelo - 40:suelo + 1]
    lab, n = ndimage.label(banda.any(0))
    out = []
    for i in range(1, n + 1):
        xs = np.where(lab == i)[0]
        if len(xs) < 5:
            continue
        sub = banda[:, xs]
        fondo = np.where(sub.any(1))[0].max()
        if fondo < 40 - 16:
            continue                               # en el aire
        yy, xx = np.where(sub[max(0, fondo - 6):fondo + 1])
        out.append(float(xs[xx].mean()))
    return out, suelo


def raiz_por_pies(Y, ry, x_video, empuja=None, atras=False):
    """x de la raiz (px de master) con el pie apoyado quieto en el suelo. En cada
    paso, de los pies que pueden pisar en los dos fotogramas, el que menos se
    mueve EN EL VIDEO (casilla + raiz del video) es el que pisa; lo que ese pie
    resbale se le quita al avance: raiz = la del video menos lo resbalado. Un
    pie quieto en el video no cambia nada; los dos resbalando hacia atras (el
    empuje v2, andando en el sitio) hacen avanzar al nodo. El otro pie, si
    arrastra o da el paso, se mueve mas y no cuenta."""
    medidas = [pies_apoyados(y, ry) for y in Y]
    pies = [m[0] for m in medidas]
    resb = np.zeros(len(Y))
    for i in range(1, len(Y)):
        dr = x_video[i] - x_video[i - 1]
        mov = []
        for p in pies[i]:
            cerca = [q for q in pies[i - 1] if abs((p + dr) - q) < 20]   # en el mundo del video
            if cerca:
                q = min(cerca, key=lambda q: abs((p + dr) - q))
                mov.append(p + dr - q)
        if mov:
            resb[i] = min(mov, key=abs)
    resb = ndimage.uniform_filter1d(resb, 3, mode='nearest')
    resb[np.abs(resb) < 0.3] = 0.0                  # quieto es quieto
    # empujando, un pie solo resbala hacia atras; hacia delante es un pie mal
    # cogido (el que esta posandose). Y solo mientras el sillar anda en el video:
    # antes de tocarlo y despues de soltarlo, como el video (si no, el sillar
    # retrocederia).
    # (tirando va hacia atras: el pie resbala hacia delante)
    resb = np.maximum(resb, 0.0) if atras else np.minimum(resb, 0.0)
    if empuja is not None:
        resb[~empuja] = 0.0
    # el suelo de cada fotograma, suavizado: lo que pisa por encima de la planta
    # de la casilla comun (ry - PLANTA) se baja con la raiz
    suelo = ndimage.median_filter(np.array([m[1] for m in medidas], float), 9, mode='nearest')
    suelo = ndimage.uniform_filter1d(suelo, 5, mode='nearest')
    return x_video - np.cumsum(resb), (ry - PLANTA) - suelo


def leer(carpeta, k):
    return np.asarray(Image.open(os.path.join(carpeta, 'c_%03d.png' % k)).convert('RGBA'))


def pm(x):
    x = x.astype(np.float32)
    return x[..., :3] * x[..., 3:] / 255


def reposo_mano():
    """El reposo con el baston en la mano del juego (584x720, como el comun; la
    garra vacia: la bola la pone el juego). El de la referencia de clavar."""
    cwd = os.getcwd()
    sys.path.insert(0, os.path.join(AQUI, 'baston'))
    os.chdir(os.path.join(AQUI, 'baston'))
    try:
        import giro_mano as G
        return np.ascontiguousarray(G.reposo_mano()[0])
    finally:
        os.chdir(cwd)


def reposo_en_casilla(cw, ch, ry, cual='reposo'):
    rep = np.asarray(Image.open(REPOSO).convert('RGBA')) if cual == 'reposo' else reposo_mano()
    out = np.zeros((ch, cw, 4), np.uint8)
    x0, y0 = cw // 2 - 292, ry - 690
    out[y0:y0 + 720, x0:x0 + 584] = rep
    return out


def con_objetos(R, x, cuerpo_min=4000):
    """R con lo que en el fotograma x no es el cuerpo (la piedrecita o el palo en
    el suelo, el baculo clavado): asi el extremo se lleva al reposo sin borrar
    los objetos que el video trae dibujados."""
    op = x[..., 3] > 40
    lab, n = ndimage.label(op)
    if n <= 1:
        return R
    tam = ndimage.sum(op, lab, range(1, n + 1))
    cuerpo = np.argmax(tam) + 1
    resto = op & (lab != cuerpo) & np.isin(lab, np.where(tam >= 40)[0] + 1)
    if not resto.any():
        return R
    out = R.copy()
    out[resto] = x[resto]
    return out


def quitar_polvo(Y, ry):
    """Bajar: al caer la IA pinta polvo en los pies y en el bajo de la tunica
    (en el juego, una mancha blanca que se va al moverse la tunica). Fuera lo
    blanco junto al suelo y, en los fotogramas del aterrizaje (donde hay mucho),
    tambien el polvo difuminado: claro y poco saturado (beis, lila), en grupos
    (la barba va siempre mucho mas arriba; la tunica es parda y saturada; los
    pies, oscuros: alguna luz suelta en los dedos no llega al minimo)."""
    total = 0
    yy_, xx_ = np.ogrid[-20:21, -20:21]
    disco = xx_ ** 2 + yy_ ** 2 <= 400

    def grupos(m, minimo):
        lab, k = ndimage.label(m)
        if k == 0:
            return m
        tam = ndimage.sum(m, lab, range(1, k + 1))
        return np.isin(lab, np.where(tam >= minimo)[0] + 1)
    for i, y in enumerate(Y):
        x = y[..., :3].astype(int)
        op = y[..., 3] > 0
        polvo = op & (x.min(-1) > 150) & (np.ptp(x, axis=-1) < 45)
        polvo[:ry - 60] = False
        mx = x.max(-1)
        sat = np.ptp(x, axis=-1) / np.maximum(mx, 1)
        semilla = op & (mx > 115) & (sat < 0.25)
        semilla[:ry - 100] = False
        semilla = grupos(semilla, 10)
        if semilla.sum() > 40:
            # el aterrizaje: tambien el polvo mas apagado (V ~100, beis), pero
            # solo pegado al suelo (las facetas gris claro de la tunica van mas
            # arriba) y en grupos grandes (no las luces de los dedos)
            apagado = op & (mx > 95) & (sat < 0.25)
            apagado[:ry - 45] = False
            polvo |= semilla | grupos(apagado, 40)
        if polvo.sum() <= 20:
            continue
        # se funde con la tunica en un aro mas oscuro (V ~90; el bajo de la
        # tunica no pasa de ~80): crece por lo claro, hasta 6 px
        claro = op & (mx > 88)
        claro[:ry - 100] = False
        for _ in range(6):
            polvo |= ndimage.binary_dilation(polvo) & claro
        # lo que tapaba de la tunica (el bajo, cerrado sin el polvo) se rellena
        # con lo de alrededor; lo de fuera, transparente
        resto = op & ~polvo
        dentro = polvo & ndimage.binary_closing(resto, structure=disco)
        y = y.copy()
        if dentro.any():
            ys, xs = np.where(polvo)
            y0, y1 = max(0, ys.min() - 20), min(y.shape[0], ys.max() + 21)
            x0, x1 = max(0, xs.min() - 20), min(y.shape[1], xs.max() + 21)
            trozo = np.ascontiguousarray(y[y0:y1, x0:x1, :3])
            relleno = cv2.inpaint(trozo, (polvo | ~op)[y0:y1, x0:x1].astype(np.uint8), 5, cv2.INPAINT_TELEA)
            d = dentro[y0:y1, x0:x1]
            y[y0:y1, x0:x1][d, :3] = relleno[d]
        y[polvo & ~dentro, 3] = 0
        Y[i] = y
        total += int(polvo.sum())
    return total


def rehacer_bajo(Y, cajas, primero=0):
    """Bajar, 69-70: la nube de polvo tapaba el bajo entero y al quitarla queda
    un bocado y algo de polvo apagado. En la caja (el bajo, sin llegar a las
    piernas, x 375-390): la forma del bajo es la tunica oscura cerrada (disco de
    35 px); lo de dentro que no es tunica se rellena con su color y lo claro de
    fuera, transparente. cajas: [(fotograma 1-based, (x0, y0, x1, y1))]."""
    yy_, xx_ = np.ogrid[-35:36, -35:36]
    disco = xx_ ** 2 + yy_ ** 2 <= 35 * 35
    total = 0
    for f, (x0, y0, x1, y1) in cajas:
        i = primero + f - 1
        y = Y[i].copy()
        x = y[..., :3].astype(int)
        op = y[..., 3] > 30
        mx = x.max(-1)
        sat = np.ptp(x, axis=-1) / np.maximum(mx, 1)
        caja = np.zeros(op.shape, bool)
        caja[y0:y1, x0:x1] = True
        oscura = op & (mx < 85) & (sat > 0.12)
        banda = np.zeros(op.shape, bool)
        banda[y0 - 60:y1] = True
        forma = ndimage.binary_closing(oscura & banda, structure=disco) & caja
        rellenar = forma & ~oscura
        if rellenar.any():
            r0, r1, c0, c1 = max(0, y0 - 40), y1, max(0, x0 - 20), min(y.shape[1], x1 + 20)
            trozo = np.ascontiguousarray(y[r0:r1, c0:c1, :3])
            relleno = cv2.inpaint(trozo, (~oscura)[r0:r1, c0:c1].astype(np.uint8), 5, cv2.INPAINT_TELEA)
            d = rellenar[r0:r1, c0:c1]
            y[r0:r1, c0:c1][d, :3] = relleno[d]
            y[rellenar, 3] = 255
        fuera = caja & ~forma & op & ~oscura
        y[fuera, 3] = 0
        Y[i] = y
        total += int(rellenar.sum() + fuera.sum())
    return total


def tapar_huecos(Y, cajas, primero=0):
    """Agujeros que deja el croma en la tunica (una sombra verdosa entre dos
    pliegues): lo transparente encerrado que toca la caja, en esos fotogramas,
    se rellena con lo de alrededor. cajas: [(desde, hasta, (x0, y0, x1, y1))],
    fotogramas de la accion 1-based (los de 04_acciones, que empiezan en
    Y[primero]). Los huecos de verdad (entre las piernas, entre la barba y el
    pecho) quedan fuera de las cajas."""
    total = 0
    for f0, f1, (x0, y0, x1, y1) in cajas:
        for i in range(primero + f0 - 1, primero + f1):
            y = Y[i]
            op = y[..., 3] > 30
            h = ndimage.binary_fill_holes(op) & ~op
            lab, k = ndimage.label(h)
            m = np.zeros_like(h)
            for j in np.unique(lab[y0:y1, x0:x1]):
                if j:
                    m |= lab == j
            if not m.any():
                continue
            y = y.copy()
            y[..., :3] = cv2.inpaint(np.ascontiguousarray(y[..., :3]), m.astype(np.uint8), 4, cv2.INPAINT_TELEA)
            y[m, 3] = 255
            Y[i] = y
            total += int(m.sum())
    return total


def quitar_lanzado(Y, ry):
    """Lanzar el palo: el palo vuela fuera de la casilla y ahi se cortaria; se
    quita del dibujo en cuanto se separa de la mano (el vuelo lo hace el juego).
    Fases: en el suelo (suelto, abajo) -> en la mano (pegado al cuerpo) -> en el
    aire (suelto, arriba). Devuelve el fotograma en que se suelta y la posicion
    y velocidad del palo ahi (px de master en la casilla, por fotograma)."""
    fase, suelta, pos = 0, None, []
    for i, y in enumerate(Y):
        op = y[..., 3] > 40
        lab, n = ndimage.label(op)
        tam = ndimage.sum(op, lab, range(1, n + 1)) if n else []
        cuerpo = np.argmax(tam) + 1 if n else 0
        sueltos = [k + 1 for k in range(n) if k + 1 != cuerpo and tam[k] >= 60]
        en_suelo = [k for k in sueltos if np.where(lab == k)[0].max() >= ry - 40]
        en_aire = [k for k in sueltos if k not in en_suelo]
        if fase == 0 and not en_suelo:
            fase = 1                                      # ya lo tiene en la mano
        if fase >= 1 and en_aire:
            if fase == 1:
                suelta = i
            fase = 2
            m = np.isin(lab, en_aire)
            yy, xx = np.where(m)
            pos.append((float(xx.mean()), float(yy.mean())))
            y = y.copy()
            y[ndimage.binary_dilation(m, iterations=2)] = 0
            Y[i] = y
    if suelta is None:
        return None
    v = (np.array(pos[min(2, len(pos) - 1)]) - np.array(pos[0])) / max(1, min(2, len(pos) - 1))
    return {'f': suelta, 'pos': pos[0], 'vel': v.tolist()}


MANO = os.path.abspath(os.path.join(AQUI, '..', '..', '..', 'assets', 'characters', 'baston', 'mano.json'))
FONDO_GARRA = np.array([60, 56, 54], np.float32)


def hueco_garra(a, cx, cy, R=40):
    """Centro del hueco de la garra cerca de (cx, cy): lo transparente dentro
    del casco convexo de lo opaco de alrededor (la garra), el grupo mayor. En el
    reposo con el baston en la mano da la bola del juego a 0,6 px de master."""
    x0, y0 = int(cx) - R, int(cy) - R
    op = a[y0:y0 + 2 * R, x0:x0 + 2 * R, 3] > 128
    m = np.zeros(op.shape, np.uint8)
    cv2.fillConvexPoly(m, cv2.convexHull(np.argwhere(op)[:, ::-1].astype(np.int32)), 1)
    h = ndimage.binary_opening((m > 0) & ~op, iterations=2)
    lab, k = ndimage.label(h)
    if k == 0:
        return float(cx), float(cy)
    yy, xx = np.where(lab == int(np.argmax(ndimage.sum(h, lab, range(1, k + 1)))) + 1)
    return x0 + float(xx.mean()), y0 + float(yy.mean())


def seguir_garra(Y, idx, fin=None):
    """La garra del baculo en cada fotograma de idx (arrancar: clavado, en alto,
    en la mano), para poner ahi la bola por codigo: el baculo del video lleva la
    garra vacia. Por patron, como garra_patron de baston/mano.py pero con mas
    giro (al arrancarlo se inclina mas de 20 grados) y mas recorrido (sube ~25 px
    de master por fotograma): la garra del primero (el baculo clavado, la pieza
    mayor que no es el cuerpo; centro, su hueco) se busca en cada uno girada
    +-45 grados cerca de donde estaba en el anterior. Al final se lleva a 'fin'
    (la bola del juego en el reposo con el baston en la mano: ahi acaba) en lo
    que dura el paso al reposo, y se suaviza [1,2,1]. Px de master en la casilla."""
    a0 = Y[idx[0]]
    op = a0[..., 3] > 40
    lab, k = ndimage.label(op)
    tam = ndimage.sum(op, lab, range(1, k + 1))
    cuerpo = int(np.argmax(tam)) + 1
    baculo = max((i + 1 for i in range(k) if i + 1 != cuerpo and tam[i] >= 40), key=lambda i: tam[i - 1])
    ys, xs = np.where(lab == baculo)
    arriba = ys < ys.min() + 80
    c0 = hueco_garra(a0, xs[arriba].mean(), ys.min() + 34)

    def plano(a):
        al = a[..., 3:4].astype(np.float32) / 255
        return (a[..., :3] * al + FONDO_GARRA * (1 - al)).astype(np.float32)

    R, B = 44, 48
    tx0, ty0 = int(round(c0[0])) - R, int(round(c0[1])) - R
    tpl = plano(a0)[ty0:ty0 + 2 * R, tx0:tx0 + 2 * R]
    msk = (a0[ty0:ty0 + 2 * R, tx0:tx0 + 2 * R, 3] > 128).astype(np.float32)
    centro = (c0[0] - tx0, c0[1] - ty0)
    pos, pts = c0, []
    for i in idx:
        img = plano(Y[i])
        mejor = None
        for ang in range(-45, 46, 3):
            M = cv2.getRotationMatrix2D(centro, ang, 1.0)
            t = cv2.warpAffine(tpl, M, (2 * R, 2 * R), borderValue=tuple(float(v) for v in FONDO_GARRA))
            m = cv2.warpAffine(msk, M, (2 * R, 2 * R))
            sx, sy = int(pos[0] - centro[0]) - B, int(pos[1] - centro[1]) - B
            zona = img[max(sy, 0):sy + 2 * R + 2 * B, max(sx, 0):sx + 2 * R + 2 * B]
            r = np.nan_to_num(cv2.matchTemplate(zona, t, cv2.TM_CCORR_NORMED, mask=np.dstack([m] * 3)),
                              nan=0, posinf=0, neginf=0)
            _, sc, _, (lx, ly) = cv2.minMaxLoc(r)
            if mejor is None or sc > mejor[0]:
                def sub(v0, v1, v2):                       # subpixel: parabola sobre el maximo
                    dd = v0 - 2 * v1 + v2
                    return 0.0 if abs(dd) < 1e-9 else 0.5 * (v0 - v2) / dd
                fx = sub(r[ly, lx - 1], r[ly, lx], r[ly, lx + 1]) if 0 < lx < r.shape[1] - 1 else 0.0
                fy = sub(r[ly - 1, lx], r[ly, lx], r[ly + 1, lx]) if 0 < ly < r.shape[0] - 1 else 0.0
                mejor = (sc, (max(sx, 0) + lx + fx + centro[0], max(sy, 0) + ly + fy + centro[1]))
        pos = mejor[1]
        pts.append(pos)
    p = np.array(pts, float)
    if fin is not None:
        for j in range(N_EXT + 1):
            w = 1 - E.suave(j / N_EXT)
            p[-1 - j] = p[-1 - j] * (1 - w) + np.array(fin) * w
    k3 = np.array([1, 2, 1], float) / 4
    for c in (0, 1):
        p[:, c] = np.convolve(np.pad(p[:, c], 1, mode='edge'), k3, mode='valid')
    p[0] = c0
    if fin is not None:
        p[-1] = fin
    return p


def bola_reposo_mano(CW, RY):
    """La bola del juego en el reposo con el baston en la mano (mano.json, su
    primer fotograma), en px de master de la casilla (reposo_en_casilla)."""
    ox, oy = json.load(open(MANO))['reposo']['orbe'][0]
    return CW // 2 + 2 * ox, RY - 690 + 360 + 2 * oy


def campo_hacia(a, ref):
    f = E.flujo(ref, a)                  # ref(x) ~ a(x + f(x))
    return cv2.GaussianBlur(-f, (0, 0), 3)


def al_reposo(Y, X, idx, R, hacia_atras):
    """Lleva el fotograma idx[0] al reposo R y apaga la correccion en N_EXT
    fotogramas (idx en orden: del extremo hacia dentro), y luego funde
    N_FUNDIDO con R."""
    h, W = X[idx[0]].shape[:2]
    yy, xx = np.mgrid[0:h, 0:W].astype(np.float32)
    d0 = campo_hacia(X[idx[0]], R)
    P = np.dstack([xx, yy])
    for j, i in enumerate(idx[:N_EXT + 1]):
        if j > 0:
            f = E.flujo(X[i], X[idx[j - 1]])
            P = cv2.remap(P, xx + f[..., 0], yy + f[..., 1], cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
        w = 1 - E.suave(j / N_EXT)
        if w > 0:
            Y[i] = E.deformar(Y[i], E.llevar(d0, P, 0.0) * w)
    for j, i in enumerate(idx[:N_FUNDIDO]):
        Y[i] = E.fundir(Y[i], R, E.suave(1 - j / N_FUNDIDO))


def buscar_ciclo(carpeta, desde, hasta):
    """Distancia de pose entre fotogramas del tramo de empuje (a 1/4, con un
    encaje de +-3 px) en pasos normales: los pares (a, b) con a ~ b son
    candidatos a ciclo (a..b-1 y se vuelve a a)."""
    ims = []
    for k in range(desde, hasta + 1):
        a = leer(carpeta, k)
        p = pm(a)
        ims.append(cv2.resize(p, (p.shape[1] // 4, p.shape[0] // 4), interpolation=cv2.INTER_AREA))
    ims = np.stack(ims)
    paso = np.median([np.abs(ims[i + 1] - ims[i]).mean() for i in range(len(ims) - 1)])

    def d(i, j):
        best = 1e9
        for dx in (-1, 0, 1):
            best = min(best, float(np.abs(np.roll(ims[i], dx, 1) - ims[j]).mean()))
        return best / paso
    out = []
    for i in range(len(ims)):
        for j in range(i + 24, min(len(ims), i + 80)):
            out.append((d(i, j), desde + i, desde + j))
    out.sort()
    print('paso normal %.3f; mejores (distancia en pasos, a, b: ciclo a..b-1):' % paso)
    for v, a, b in out[:25]:
        print('  %.2f  %d -> %d  (%d fotogramas)' % (v, a, b, b - a))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('job')
    ap.add_argument('--buscar-ciclo', nargs=2, type=int)
    a = ap.parse_args()
    carpeta = os.path.join(AQUI, a.job)
    limpios = os.path.join(carpeta, '04_limpios')
    if a.buscar_ciclo:
        buscar_ciclo(limpios, *a.buscar_ciclo)
        return
    cfg = ACCIONES[a.job]
    rz = json.load(open(os.path.join(carpeta, 'raiz.json')))
    CW, CH = rz['casilla']
    RY = rz['raiz_fila']
    n = len(rz['raiz'])
    X = [leer(limpios, k) for k in range(1, n + 1)]
    R = reposo_en_casilla(CW, CH, RY, cfg.get('ref_inicio', 'reposo'))
    R_fin = reposo_en_casilla(CW, CH, RY, cfg.get('ref_fin', 'reposo'))

    # tono estandar, medido en el primero (el reposo del video)
    g = np.ones(3)
    muestra = [X[0].astype(float) / 255]
    for _ in range(5):
        g = g * tono.tono_reposo() / tono.media([tono.aplicar(im, g) for im in muestra])
    print('%s: %d fotogramas, casilla %dx%d, ganancia de tono (%.3f, %.3f, %.3f)' % (a.job, n, CW, CH, *g))
    X = [E.quitar_verde((tono.aplicar(x.astype(float) / 255, g) * 255).round().astype(np.uint8)) for x in X]
    Y = list(X)

    tramos = [(nom, i0 - 1, (n if i1 is None else i1) - 1) for nom, i0, i1 in cfg['tramos']]
    # extremos: el primero de la accion y el ultimo, al reposo del juego (con
    # los objetos que traiga dibujados ese fotograma)
    primero, ultimo = tramos[0][1], tramos[-1][2]
    R = con_objetos(R, X[primero])
    R_fin = con_objetos(R_fin, X[ultimo])
    antes = (np.abs(pm(X[primero]) - pm(R)).mean(), np.abs(pm(X[ultimo]) - pm(R_fin)).mean())
    al_reposo(Y, X, list(range(primero, ultimo + 1)), R, False)
    al_reposo(Y, X, list(range(ultimo, primero - 1, -1)), R_fin, True)
    suelta = quitar_lanzado(Y, RY) if cfg.get('lanza') else None
    if cfg.get('polvo'):
        print('polvo de la caida quitado: %d px' % quitar_polvo(Y, RY))
    if cfg.get('rehacer_bajo'):
        print('bajo de la tunica rehecho donde lo tapaba el polvo: %d px' % rehacer_bajo(Y, cfg['rehacer_bajo'], primero))
    if cfg.get('tapar'):
        print('agujeros de la tunica tapados: %d px' % tapar_huecos(Y, cfg['tapar'], primero))
    if suelta:
        print('suelta el palo en el %d (de %d), en %s, a %s px de master por fotograma'
              % (suelta['f'] + 1, n, [round(v) for v in suelta['pos']], [round(v, 1) for v in suelta['vel']]))
    garra = None
    if cfg.get('garra'):
        fin = bola_reposo_mano(CW, RY) if cfg.get('ref_fin') == 'mano' else None
        garra = seguir_garra(Y, list(range(primero, ultimo + 1)), fin)
        print('garra (la bola): al empezar en (%.1f, %.1f), lo mas alto %.1f, al acabar en (%.1f, %.1f) px de master'
              % (garra[0, 0], garra[0, 1], garra[:, 1].min(), garra[-1, 0], garra[-1, 1]))

    dest = os.path.join(carpeta, '04_acciones')
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    os.makedirs(dest)
    for i, y in enumerate(Y[primero:ultimo + 1]):
        Image.fromarray(y, 'RGBA').save(os.path.join(dest, 'c_%03d.png' % (i + 1)))

    pasos = np.array([np.abs(pm(Y[i + 1]) - pm(Y[i])).mean() for i in range(primero, ultimo)])
    med = np.median(pasos)
    print('extremos frente al reposo (pasos normales): al empezar %.2f (sin corregir %.2f), al acabar %.2f (sin corregir %.2f)'
          % (np.abs(pm(Y[primero]) - pm(R)).mean() / med, antes[0] / med, np.abs(pm(Y[ultimo]) - pm(R_fin)).mean() / med, antes[1] / med))
    print('cambio por fotograma (pasos): max %.2f en %d' % (pasos.max() / med, pasos.argmax() + 1))

    # json para el juego (px de la hoja = master / 2)
    raiz = np.array(rz['raiz'], float)
    s = np.array(rz['s'], float)
    if cfg.get('pies'):
        x_video = raiz[:, 0].copy()
        empuja = None
        if 'objeto_borde' in rz:
            sillar = x_video + np.array(rz['objeto_borde'], float)      # la cara del sillar en el video
            anda = np.abs(np.gradient(ndimage.uniform_filter1d(sillar, 5, mode='nearest'))) > 0.25
            empuja = ndimage.binary_dilation(anda, iterations=2)
        raiz[:, 0], bajar_y = raiz_por_pies(Y, RY, x_video, empuja, cfg.get('pies') == 'tira')
        raiz[:, 1] += bajar_y
        print('suelo: se baja la raiz hasta %.1f px de master (lo que el video pisa por encima)' % bajar_y.max())
        tot = raiz[-1, 0] - raiz[0, 0]
        s[:, 0] = (raiz[:, 0] - raiz[0, 0]) / tot if abs(tot) > 1 else np.linspace(0, 1, len(raiz))
        print('raiz por los pies: avanza %.0f px de master (el video, %.0f)' % (tot, x_video[-1] - x_video[0]))
    oy = (CH / 2.0 - RY) / 2.0
    ruta_obj = os.path.join(carpeta, 'objeto.json')
    obj = json.load(open(ruta_obj)) if os.path.exists(ruta_obj) else {}
    esc = rz['escala']

    def sueltos(y):
        """Cajas (px de juego, respecto a la raiz) de lo que no es el cuerpo."""
        op = y[..., 3] > 40
        lab, k = ndimage.label(op)
        if k <= 1:
            return []
        tam = ndimage.sum(op, lab, range(1, k + 1))
        cuerpo = np.argmax(tam) + 1
        out = []
        for i, sl in enumerate(ndimage.find_objects(lab)):
            if i + 1 != cuerpo and tam[i] >= 40:
                out.append([round((sl[1].start - CW / 2) / 2, 1), round((sl[0].start - RY) / 2, 1),
                            round((sl[1].stop - CW / 2) / 2, 1), round((sl[0].stop - RY) / 2, 1)])
        return out
    borde = np.array(rz['objeto_borde'], float) if 'objeto_borde' in rz else None
    # cara del objeto quieto (trepar, bajar), en px de master del video escalado
    cara_x = None
    if borde is None and 'cara' in cfg:
        cara_x = obj['caja'][0] * esc if cfg['cara'] == 'izquierda' else (obj['caja'][2] + 1) * esc
    datos = {}
    for nom, i0, i1 in tramos:
        r = (raiz[i0:i1 + 1] - raiz[i0]) / 2.0
        sig = i1 + 1 if i1 + 1 < n else i1          # primer fotograma del tramo siguiente
        d = {'hoja': a.job, 'desde': i0 - primero, 'n': i1 - i0 + 1, 'fps': FPS,
             'casilla': [CW // 2, CH // 2], 'offset': [0.0, oy],
             'raiz': [[round(float(u), 2), round(float(v), 2)] for u, v in r],
             'viaje': [round(float(v), 2) for v in (raiz[i1] - raiz[i0]) / 2.0],
             'siguiente': [round(float(v), 2) for v in (raiz[sig] - raiz[i0]) / 2.0],
             's': [[round(float(u), 4), round(float(v), 4)] for u, v in s[i0:i1 + 1]]}
        if cara_x is not None:
            # de la raiz del primero a la cara (delante, +) y de la cara a la del ultimo
            d['cara'] = round((cara_x - raiz[i0, 0]) / 2.0, 2)
            d['cara_fin'] = round((raiz[i1, 0] - cara_x) / 2.0, 2)
        if nom == cfg.get('bucle'):
            # lo que avanza una vuelta: hasta el fotograma que sigue al ultimo
            d['bucle'] = True
            d['vuelta'] = [round(float(v), 2) for v in (raiz[i1 + 1] - raiz[i0]) / 2.0]
        if borde is not None:
            # cara del sillar respecto a la raiz, y cuanto anda el sillar
            mov = raiz[:, 0] + borde                   # cara del sillar en el video
            d['objeto'] = [round(float(v) / 2.0, 2) for v in borde[i0:i1 + 1]]
            d['cara'] = round(float(borde[i0]) / 2.0, 2)
            d['bloque_siguiente'] = round(float(mov[sig] - mov[i0]) / 2.0, 2)
            # el primer fotograma en que el sillar anda de verdad (suavizado: el
            # seguimiento tiembla ~1 px; hacia delante al empujar, atras al tirar)
            ms = ndimage.uniform_filter1d(mov[i0:i1 + 1], 5, mode='nearest')
            anda = np.where(np.abs(ms - ms[0]) > 3.0)[0]
            d['contacto'] = int(max(0, anda[0] - 2)) if len(anda) else 0
        # objetos dibujados al empezar y al acabar (la piedrecita, el palo, el
        # baculo clavado): donde los pone el juego antes y despues
        d['objetos_ini'] = sueltos(Y[i0])
        d['objetos_fin'] = sueltos(Y[i1])
        if suelta and i0 <= suelta['f'] <= i1:
            px, py = suelta['pos']
            d['suelta'] = {'f': suelta['f'] - i0,
                           'pos': [round((px - CW / 2) / 2, 1), round((py - RY) / 2, 1)],
                           'vel': [round(v / 2 * FPS, 1) for v in suelta['vel']]}       # px de juego por segundo
        if garra is not None:
            # la bola, respecto al centro de la casilla (como "orbe" en mano.json)
            d['orbe'] = [[round((x - CW / 2) / 2, 2), round((y - CH / 2) / 2, 2)]
                         for x, y in garra[i0 - primero:i1 - primero + 1]]
        datos[nom] = d
        # el mismo tramo al reves (clavar = arrancar del reves): las mismas
        # casillas en orden inverso (indices en _spriteframes.py)
        reverso = cfg.get('reverso', {}).get(nom)
        if reverso:
            rr = (raiz[i0:i1 + 1][::-1] - raiz[i1]) / 2.0
            datos[reverso] = dict(d, raiz=[[round(float(u), 2), round(float(v), 2)] for u, v in rr],
                                  viaje=[round(float(v), 2) for v in (raiz[i0] - raiz[i1]) / 2.0],
                                  s=[[round(1 - float(u), 4), round(1 - float(v), 4)] for u, v in s[i0:i1 + 1][::-1]],
                                  objetos_ini=d['objetos_fin'], objetos_fin=d['objetos_ini'], reverso=True)
            datos[reverso].pop('suelta', None)
            if 'orbe' in d:
                datos[reverso]['orbe'] = d['orbe'][::-1]
    json.dump(datos, open(os.path.join(carpeta, 'accion.json'), 'w'), indent=1)
    todo = json.load(open(JUEGO)) if os.path.exists(JUEGO) else {}
    todo.update(datos)
    json.dump(todo, open(JUEGO, 'w'), separators=(',', ':'))
    print('escrito 04_acciones (%d), accion.json y %s' % (ultimo - primero + 1, os.path.relpath(JUEGO, AQUI)))
    print('hoja:  .\\hoja.ps1 -Job %s -Desde 04_acciones -Fps 24 -Escala 2 -Cols 10' % a.job)


if __name__ == '__main__':
    main()

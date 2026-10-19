"""Las dos animaciones de frente: sacar_baston_frente y guardar_baston_frente.

  sacar   reposo_frente_sb (fotograma base) -> 3 de puente -> video 20..146 -> 4 de
          puente -> reposo_frente_cb (base)
  guardar reposo_frente_cb (base) -> 3 de puente -> video 9..135 -> 4 de puente ->
          reposo_frente_sb (base)
Tramos: el video empieza a moverse en el 21 (sacar) y en el 9 (guardar: antes
esta quieto); acaba de asentarse en el 146 (sacar: tras plantar el baston se
balancea y vuelve, al 96 % de la silueta del reposo con baston) y en el 135
(guardar, al 97 % del reposo sin baston). Los puentes, por flujo optico como en
la secuencia (secuencia.py, mezcla): sin fundidos ni doble imagen.

La bola (la garra del video va vacia): garra.json (garra.py) con los huecos donde
la garra pasa por detras de la capucha interpolados, suavizada, y en los
puentes de la bola del reposo a la del video. Filas [x, y, escala, giro]: px de
hoja desde el centro de la casilla (332x452), escala relativa a la de la escena
(sin baston la bola va a 1, con baston a escala_bola = 1,092) y giro del nodo
(a la espalda va girada como el baston, -0,34 rad; en la mano, 0): se pasa de uno
a otro mientras la garra se mueve.
La capucha, al color estandar (../igualar_capucha.py; ver capucha_estandar).
Escribe <job>/04_limpios/<anim>_NNN.png, <job>/animaciones.json y
assets/characters/peregrino/baston_frente.json.
    python animar.py
    (2026-10-18/19) Con la garra nueva de la escena (baston_espalda.png tambien de frente;
    capa baston_espalda_reposo.png, de capa_espalda.gd con prueba_frontal) y la garra de
    Veo repintada (repintar_garra). Hasta el 2026-10-19 era la opcion --gu (<anim>_gu en
    <job>_gu); ahora es lo unico.
"""
import glob, importlib.util, json, os, sys
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
PROY = os.path.abspath(os.path.join(ANIM, '..', '..', '..'))
spec = importlib.util.spec_from_file_location('puente', os.path.join(ANIM, 'peregrino_puentes_frontal', 'puente.py'))
P = importlib.util.module_from_spec(spec); spec.loader.exec_module(P)
spec = importlib.util.spec_from_file_location('garra', os.path.join(AQUI, 'garra.py'))
G = importlib.util.module_from_spec(spec); spec.loader.exec_module(G)
spec = importlib.util.spec_from_file_location('igualar_capucha', os.path.join(ANIM, 'igualar_capucha.py'))
IC = importlib.util.module_from_spec(spec); spec.loader.exec_module(IC)
# (2026-10-12) calzas grises y botas como de perfil, al guardar cada sprite (botas.py)
spec = importlib.util.spec_from_file_location('botas', os.path.join(ANIM, 'botas.py'))
BOT = importlib.util.module_from_spec(spec); spec.loader.exec_module(BOT)


def con_botas(im):
    return Image.fromarray(BOT.botas(np.asarray(im.convert('RGBA'))))
ESTANDAR = IC.medir(IC.estandar())
MX, MY = 40, 104
CAS = (584 + 2 * MX, 800 + MY)
FPS = 24.0
ESCALA_CON = json.load(open(os.path.join(PROY, 'assets', 'characters', 'peregrino', 'secuencia_frontal.json')))['escala_bola']
SB = json.load(open(os.path.join(PROY, 'assets', 'characters', 'peregrino', 'secuencia_frontal_sin.json')))
GIRO_SIN = SB['baston_espalda']['reposo_frente_sb'][0][2]
GU = True       # la garra nueva y el repintado (antes, opcion --gu): siempre
CAPA = 'baston_espalda_reposo.png'


def deformar(img, f, t):
    """Como puente.deformar pero con interpolacion cubica: la lineal emborronaba
    cada fotograma deformado (desplazamientos de fraccion de pixel)."""
    import cv2
    h, w = f.shape[:2]
    gx, gy = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    return np.clip(cv2.remap(img, gx - t * f[..., 0], gy - t * f[..., 1], cv2.INTER_CUBIC, borderValue=0), 0, 1)


SIGMA_DETALLE = 3.0       # px de master: por debajo, "detalle" (pinceladas y bordes de los parches)


def mezcla(A, B, t):
    """A llevado hacia B una fraccion t por flujo, mezclado con B traido desde A.

    Sin promediar el DETALLE (2026-10-10): el usuario veia un emborronado al
    empezar y al acabar sacar / guardar. Medido (laplaciano en el cuerpo): el
    video y los reposos andan en 15-18 y los puentes bajaban a 13,5-14,5. Es
    nuestro reposo y el redibujo de Veo, que no casan en lo fino: al
    promediarlos, lo fino se emborrona. La forma y el color grueso (por encima
    de SIGMA_DETALLE) se mezclan suave; el detalle se toma de uno o del otro y
    cambia de golpe a mitad del puente (entre dos fotogramas, tapado por lo
    grueso)."""
    import cv2
    a, b = P.premul(A), P.premul(B)
    a8 = (a[..., :3] * 255).astype(np.uint8); b8 = (b[..., :3] * 255).astype(np.uint8)
    fab, fba = P.flujo(a8, b8), P.flujo(b8, a8)
    at, bt = deformar(a, fab, t), deformar(b, fba, 1 - t)
    grueso = lambda x: cv2.GaussianBlur(x.astype(np.float32), (0, 0), SIGMA_DETALLE)
    ga, gb = grueso(at), grueso(bt)
    w = 0.0 if t < 0.5 else 1.0                          # el detalle: de A hasta la mitad, luego de B (sin promediar)
    m = (1 - t) * ga + t * gb + (1 - w) * (at - ga) + w * (bt - gb)
    m[..., 3] = (1 - t) * at[..., 3] + t * bt[..., 3]  # la silueta, suave
    m = np.clip(m, 0, 1)
    al = np.clip(m[..., 3:], 1e-4, 1)
    rgb = np.where(m[..., 3:] > 1e-4, m[..., :3] / al, 0)
    return Image.fromarray((np.dstack([rgb, m[..., 3]]) * 255).round().clip(0, 255).astype(np.uint8), 'RGBA')


def reposo(job, nombre):
    """El fotograma base del reposo en la casilla grande. El de sin baston, con el
    baston que le pone la escena por detras (baston_espalda_reposo.png, de
    capa_espalda.gd: de frente solo asoma la garra): el video lo lleva dibujado y
    sin el, en el puente la garra se desvanecia y volvia a aparecer al llegar al
    reposo."""
    c = Image.new('RGBA', CAS, (0, 0, 0, 0))
    if job.endswith('_sin'):
        c.alpha_composite(Image.open(os.path.join(AQUI, CAPA)).convert('RGBA'))
    c.alpha_composite(Image.open(os.path.join(ANIM, job, '04_limpios', nombre)).convert('RGBA'), (MX, MY))
    return c


def video(job, k):
    return Image.open(os.path.join(ANIM, job, '_todos', 'c_%03d.png' % k)).convert('RGBA')


def capucha_estandar(job, a, b):
    """Los fotogramas a..b del video con la capucha al color estandar (igualar_capucha.py,
    como las secuencias: los reposos de las puntas ya lo llevan). Veo la va
    cambiando un poco por el camino (al guardar, de gris a algo azulada): se mide
    en cada fotograma y se suaviza en el tiempo (sin parpadeo)."""
    ims = {k: video(job, k) for k in range(a, b + 1)}
    med = np.array([np.concatenate(IC.medir([ims[k]])) for k in range(a, b + 1)])
    from scipy.ndimage import gaussian_filter1d
    med = gaussian_filter1d(med, 4, axis=0, mode='nearest')
    return {k: IC.aplicar(ims[k], (med[i, :3], med[i, 3:]), ESTANDAR) for i, k in enumerate(range(a, b + 1))}


def suave(v, veces=2):
    v = np.array(v, float)
    for _ in range(veces):
        v[1:-1] = (v[:-2] + 2 * v[1:-1] + v[2:]) / 4
    return v


def bola_video(job, a, b, mano_antes=None):
    """Posicion de la bola en los fotogramas a..b del video (px de master de la casilla).

    (2026-10-17) garra.json se siguio en dos tramos, cada uno desde su extremo: el de
    la mano (bola de la referencia con el baston en la mano) y el de la espalda (bola
    de la escena, que encaja en la garra de baston.png, mas grande que la del video).
    No casan: en el tramo de espalda la bola iba 15-17 px de master MAS BAJA que la
    garra del video (el usuario: "se cae del receptaculo de garras" al final del
    guardar), y el hueco de en medio (la garra por detras de la capucha) se
    interpolaba en recta. Ahora, con mano_antes (True: la mano en los primeros
    fotogramas, el guardar; False: en los ultimos, el sacar), el hueco se sigue desde
    el lado de la mano (garra.seguir) y el tramo de espalda se corrige con lo que
    difieren en la costura; los puentes llevan la bola de ahi a la de la escena,
    mientras la garra del video pasa a la de la escena."""
    g = {int(k): v for k, v in json.load(open(os.path.join(ANIM, job, 'garra.json'))).items()}
    ks = list(range(a, b + 1))
    hueco = [k for k in ks if k not in g]
    if mano_antes is not None and hueco:
        h0, h1 = min(hueco), max(hueco)
        if mano_antes:
            k0, sigue, costura = h0 - 1, list(range(h0, h1 + 5)), list(range(h1 + 1, h1 + 5))
        else:
            k0, sigue, costura = h1 + 1, list(range(h1, h0 - 5, -1)), list(range(h0 - 4, h0))
        t = G.seguir(job, sigue, G.madera(G.celda(job, k0)), g[k0][:2])
        d = np.mean([np.array(t[k][:2]) - np.array(g[k][:2]) for k in costura], axis=0)
        print('%s: hueco %d-%d seguido desde la mano; tramo de espalda corregido %s px' % (job, h0, h1, np.round(d, 1)))
        for k in hueco:
            g[k] = list(t[k])
        for k in list(g):
            if (mano_antes and k > h1) or (not mano_antes and k < h0):
                g[k] = [g[k][0] + d[0], g[k][1] + d[1]] + list(g[k][2:])
    con = [k for k in ks if k in g]
    xs = np.interp(ks, con, [g[k][0] for k in con]); ys = np.interp(ks, con, [g[k][1] for k in con])
    return np.stack([suave(xs), suave(ys)], 1)


# (--gu, 2026-10-18) Sacar de frente: hasta este fotograma del video la garra sigue a la
# espalda (asomando por encima del hombro, tambien en el "hueco" 47-57, que no esta
# tapado: ahi solo fallo el seguimiento); en el 58 sube de golpe y ya va en la mano.
REPINTAR_SACAR = 57
# Guardar de frente: la garra baja por detras de la capucha (64-73) y desde el 74 queda
# a la espalda (la pequena de Veo) hasta el final; ahi la anclada es la ultima.
REPINTAR_GUARDAR = 74
GARRA_RADIO = 62          # px de master alrededor de la bola de Veo donde se busca su garra


def repintar_garra(job, V, pv, a, desde, hasta, ancla, bola_reposo, limpio):
    """La garra que Veo pinto a la espalda es la de la referencia (baston.png: pequena y
    16 px mas baja que la de la escena); con garra_unica la escena pone baston_espalda.png
    y en el puente la cabeza del baculo cambiaba y la bola subia (el usuario lo vio al
    empezar el sacar). Aqui, en los fotogramas a..hasta del video: fuera la garra de Veo
    (madera cerca de su bola, sus sombras y, fuera de la capucha y por encima del hombro,
    todo lo que no sea la mano: piel en manchas grandes) y por detras la capa de la
    escena (CAPA), movida y girada lo que se mueve la garra de Veo (garra.json; el hueco,
    quieta como en el 46). Donde la garra de Veo pisaba la capucha, la del reposo limpio
    (`limpio`, alineado por traslacion con lo gris de la capucha) con borde suave: con
    inpaint o mezclando bordes quedaban mordiscos y escalones. La bola, en la de la escena
    con ese mismo movimiento. Cambia V y pv en su sitio."""
    capa = Image.open(os.path.join(AQUI, CAPA)).convert('RGBA')
    cp = np.asarray(capa).astype(np.float32) / 255
    cp = np.dstack([cp[..., :3] * cp[..., 3:], cp[..., 3:]])
    g = {int(k): v for k, v in json.load(open(os.path.join(ANIM, job, 'garra.json'))).items()}
    # seguidos sin huecos desde el anclado (el que va en el sitio del reposo: el primero
    # al sacar, el ultimo al guardar); mas alla, quieta como en el ultimo seguido
    paso = 1 if ancla == desde else -1
    ultimo = ancla
    while desde <= ultimo + paso <= hasta and ultimo + paso in g:
        ultimo += paso
    cual = lambda k: max(min(k, max(ancla, ultimo)), min(ancla, ultimo))
    p0 = np.array(pv, float)      # la bola de Veo (pv se cambia al final)
    ys, xs = np.mgrid[0:CAS[1], 0:CAS[0]]
    import cv2
    # el cuerpo limpio del reposo (sin baculo), para la capucha que tapaba la garra de Veo
    rl = np.asarray(limpio.convert('RGBA')).astype(np.float32)
    caja = (slice(140, 340), slice(230, 430))          # la capucha (y, x)
    gris = lambda im: cv2.cvtColor(np.ascontiguousarray(im[..., :3]).astype(np.float32), cv2.COLOR_RGB2GRAY) * (im[..., 3] / 255.0)
    vent = cv2.createHanningWindow((caja[1].stop - caja[1].start, caja[0].stop - caja[0].start), cv2.CV_32F)
    for k in range(desde, hasta + 1):
        i = cual(k) - a
        d = p0[i] - p0[ancla - a]
        ang = g[cual(k)][2] - g[ancla][2]
        M = cv2.getRotationMatrix2D((float(bola_reposo[0]), float(bola_reposo[1])), float(ang), 1.0)
        M[:, 2] += d
        w = cv2.warpAffine(cp, M, CAS, flags=cv2.INTER_CUBIC, borderValue=0)
        w = np.clip(w, 0, 1)
        fr = np.asarray(V[k].convert('RGBA')).copy()
        hsv = cv2.cvtColor(np.ascontiguousarray(fr[..., :3]), cv2.COLOR_RGB2HSV).astype(np.int32)
        h, sa, va = hsv[..., 0], hsv[..., 1], hsv[..., 2]
        cerca = (xs - p0[i][0]) ** 2 + (ys - p0[i][1]) ** 2 < GARRA_RADIO ** 2
        # el reposo limpio llevado a la capucha de este fotograma (solo traslacion,
        # medida en lo gris de la capucha: sin la garra de Veo, que la desviaba)
        gr = lambda im, hs: gris(im) * ((hs[..., 1] < 70) & (hs[..., 2] > 100))
        hsr = cv2.cvtColor(np.ascontiguousarray(rl[..., :3]).astype(np.uint8), cv2.COLOR_RGB2HSV).astype(np.int32)
        (dx, dy), _ = cv2.phaseCorrelate(gr(rl, hsr)[caja].astype(np.float32), gr(fr.astype(np.float32), hsv)[caja].astype(np.float32), vent)
        # y afinado con giro (la cabeza se inclina: al guardar, 74-81, con solo traslacion
        # la capucha del reposo no casaba y quedaba un parche): ECC euclideo sobre la
        # silueta de lo gris de la capucha, sin la garra de Veo
        T = np.float32([[1, 0, dx], [0, 1, dy]])
        sil_v = ((hsv[..., 1] < 70) & (hsv[..., 2] > 100) & (fr[..., 3] > 128)).astype(np.float32)
        sil_r = ((hsr[..., 1] < 70) & (hsr[..., 2] > 100) & (rl[..., 3] > 128)).astype(np.float32)
        sin_garra = ~(cv2.dilate((cerca & (h >= 5) & (h <= 30) & (sa >= 50) & (fr[..., 3] > 0)).astype(np.uint8),
                                 np.ones((9, 9), np.uint8)) > 0)
        mascara = np.zeros(sil_v.shape, np.uint8)
        mascara[caja] = 1
        mascara &= sin_garra.astype(np.uint8)
        try:
            Wi = np.float32([[1, 0, -dx], [0, 1, -dy]])        # del video al reposo (lo que pide ECC)
            _, Wi = cv2.findTransformECC(cv2.GaussianBlur(sil_v, (0, 0), 2), cv2.GaussianBlur(sil_r, (0, 0), 2), Wi,
                                         cv2.MOTION_EUCLIDEAN,
                                         (cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 100, 1e-5), mascara, 5)
            rk = cv2.warpAffine(rl, Wi, CAS, flags=cv2.INTER_CUBIC | cv2.WARP_INVERSE_MAP, borderValue=0)
        except cv2.error:
            rk = cv2.warpAffine(rl, T, CAS, flags=cv2.INTER_CUBIC, borderValue=0)
        capucha = rk[..., 3] > 128
        # la garra de Veo: madera cerca de su bola; sobre la capucha (gris), tambien lo
        # pardo flojo; y sus sombras (lineas oscuras entre los cuernos), pegadas a ella
        veo = cerca & (h >= 9) & (h <= 25) & (sa >= 75) & (va <= 165) & (fr[..., 3] > 0)
        veo |= cerca & capucha & (h >= 5) & (h <= 30) & (sa >= 50) & (fr[..., 3] > 0)
        junto = cv2.dilate(veo.astype(np.uint8), np.ones((7, 7), np.uint8)) > 0
        veo |= junto & cerca & (va < 95) & (fr[..., 3] > 0)
        # la mano: piel (rosada y clara) en manchas grandes (los brillos de la garra de
        # Veo tambien dan "piel" sueltos: fuera)
        piel = ((h < 9) | (h > 170)) & (va > 140) & (sa > 40) & (fr[..., 3] > 0)
        n, et, st, _ = cv2.connectedComponentsWithStats(piel.astype(np.uint8), 8)
        grandes = [j for j in range(1, n) if st[j, cv2.CC_STAT_AREA] >= 150]
        piel = np.isin(et, grandes)
        piel = cv2.dilate(piel.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
        # y fuera de la capucha, por encima del hombro, todo lo que no sea la mano: ahi
        # solo puede haber garra (al agarrarla, Veo la emborrona y queda gris)
        fuera = ~(cv2.dilate(capucha.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0)
        veo |= cerca & fuera & (ys < p0[i][1] + 30) & (fr[..., 3] > 0)
        veo = cv2.dilate(veo.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
        veo &= cerca & ~piel
        # donde estaba la garra de Veo, el reposo limpio (la capucha con su borde y su
        # alfa; fuera de la capucha, transparente: ahi se ve la garra de la escena), con
        # el borde suave para que no quede escalon entre una capucha y otra
        zona = cv2.GaussianBlur(veo.astype(np.float32), (0, 0), 2.0)
        zona = np.clip(np.maximum(zona * 1.6, veo), 0, 1)
        zona = np.where(piel, 0, zona)[..., None]
        f0 = fr.astype(np.float32)
        pf = np.dstack([f0[..., :3] * f0[..., 3:] / 255, f0[..., 3:]])
        pr = np.dstack([rk[..., :3] * rk[..., 3:] / 255, rk[..., 3:]])
        m = pf * (1 - zona) + pr * zona
        al = m[..., 3:]
        fr = np.dstack([np.where(al > 1e-3, m[..., :3] * 255 / np.maximum(al, 1e-3), 0), al]).round().clip(0, 255).astype(np.uint8)
        # si la cabeza del video va girada, la capucha del reposo no casa y donde estaba
        # la garra de Veo quedaba un mordisco (guardar 74-82): lo que quede dentro de la
        # silueta cerrada, solo ahi, con el color de alrededor
        sil = (fr[..., 3] > 128).astype(np.uint8)
        cerr = cv2.morphologyEx(sil, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (15, 15))) > 0
        hueco = cerr & (sil == 0) & veo
        if hueco.any():
            fr[..., :3] = cv2.inpaint(np.ascontiguousarray(fr[..., :3]), ((sil == 0) & veo).astype(np.uint8), 5, cv2.INPAINT_TELEA)
            fr[..., 3] = np.where(hueco, 255, fr[..., 3])
        f = fr.astype(np.float32) / 255
        fa = f[..., 3:]
        rgb = f[..., :3] * fa + w[..., :3] * (1 - fa)
        al = fa + w[..., 3:] * (1 - fa)
        rgb = np.where(al > 1e-4, rgb / np.maximum(al, 1e-4), 0)
        V[k] = Image.fromarray((np.dstack([rgb, al]) * 255).round().clip(0, 255).astype(np.uint8), 'RGBA')
    for k in range(desde, hasta + 1):
        i = cual(k) - a
        pv[k - a] = np.array(bola_reposo, float) + (p0[i] - p0[ancla - a])
    print('%s: garra repintada %d-%d (anclada en el %d, seguida hasta el %d)' % (job, desde, hasta, ancla, ultimo))


def giro_mientras_se_mueve(pos, desde, hasta):
    """De desde a hasta segun lo recorrido por la garra (no por el tiempo)."""
    d = np.r_[0, np.cumsum(np.hypot(*np.diff(pos, axis=0).T))]
    t = d / max(d[-1], 1e-6); t = t * t * (3 - 2 * t)
    return desde + (hasta - desde) * t


if __name__ == '__main__':
    # (importable: las de espaldas, peregrino_sacar_baston_espalda_v2/animar.py, usan mezcla y demas)
    b_sin, b_con = G.bolas_de_referencia()
    ANIMS = {
        # nombre: job, tramo del video, (reposo de entrada), (reposo de salida), de, a
        'sacar_baston_frente': ('peregrino_sacar_baston_frente', (20, 146),
                                ('peregrino_secuencia_frontal_sin', 'reposo_frente_sb_000.png', b_sin, 1.0, GIRO_SIN),
                                ('peregrino_secuencia_frontal', 'reposo_frente_cb_000.png', b_con, ESCALA_CON, 0.0),
                                'reposo_frente_sb', 'reposo_frente_cb'),
        'guardar_baston_frente': ('peregrino_guardar_baston_frente', (9, 135),
                                  ('peregrino_secuencia_frontal', 'reposo_frente_cb_000.png', b_con, ESCALA_CON, 0.0),
                                  ('peregrino_secuencia_frontal_sin', 'reposo_frente_sb_000.png', b_sin, 1.0, GIRO_SIN),
                                  'reposo_frente_cb', 'reposo_frente_sb'),
    }
    N_ENTRA, N_SALE = 3, 4
    escena = {'fps': FPS, 'casilla': [CAS[0] // 2, CAS[1] // 2]}
    for nombre, (job, (a, b), ent, sal, de, hacia) in ANIMS.items():
        salida = job
        R0, R1 = reposo(ent[0], ent[1]), reposo(sal[0], sal[1])
        V = capucha_estandar(job, a, b)
        pv = bola_video(job, a, b, mano_antes=nombre.startswith('guardar'))
        if GU:
            # el lado sin baston: el reposo de entrada al sacar, el de salida al guardar
            sin = ent if nombre.startswith('sacar') else sal
            limpio = Image.new('RGBA', CAS, (0, 0, 0, 0))
            limpio.alpha_composite(Image.open(os.path.join(ANIM, sin[0], '04_limpios', sin[1])).convert('RGBA'), (MX, MY))
            if nombre.startswith('sacar'):
                repintar_garra(job, V, pv, a, a, REPINTAR_SACAR, a, sin[2], limpio)
            else:
                repintar_garra(job, V, pv, a, REPINTAR_GUARDAR, b, b, sin[2], limpio)
        V0, V1 = V[a], V[b]
        frames = [mezcla(R0, V0, k / (N_ENTRA + 1)) for k in range(1, N_ENTRA + 1)]
        frames += [V[k] for k in range(a, b + 1)]
        frames += [mezcla(V1, R1, k / (N_SALE + 1)) for k in range(1, N_SALE + 1)]
        p_ent = [np.array(ent[2]) + (pv[0] - np.array(ent[2])) * k / (N_ENTRA + 1) for k in range(1, N_ENTRA + 1)]
        p_sal = [pv[-1] + (np.array(sal[2]) - pv[-1]) * k / (N_SALE + 1) for k in range(1, N_SALE + 1)]
        pos = np.array(p_ent + list(pv) + p_sal)
        esc = giro_mientras_se_mueve(pos, ent[3], sal[3]); gir = giro_mientras_se_mueve(pos, ent[4], sal[4])
        filas = [[round(float(x) / 2 - CAS[0] / 4, 2), round(float(y) / 2 - CAS[1] / 4, 2), round(float(e), 4), round(float(g), 4)]
                 for (x, y), e, g in zip(pos, esc, gir)]
        carpeta = os.path.join(ANIM, salida, '04_limpios'); os.makedirs(carpeta, exist_ok=True)
        for f in glob.glob(os.path.join(carpeta, '*.png')):
            os.remove(f)
        for k, im in enumerate(frames):
            con_botas(im).save(os.path.join(carpeta, '%s_%03d.png' % (nombre, k)))
        json.dump([[nombre, salida, len(frames), FPS, False, list(range(len(frames)))]], open(os.path.join(ANIM, salida, 'animaciones.json'), 'w'))
        escena[nombre] = {'de': de, 'a': hacia, 'orbe': filas}
        print(nombre, len(frames), 'fotogramas (%d de puente, video %d-%d, %d de puente)' % (N_ENTRA, a, b, N_SALE))
    json.dump(escena, open(os.path.join(PROY, 'assets', 'characters', 'peregrino', 'baston_frente.json'), 'w'),
              separators=(',', ':'))

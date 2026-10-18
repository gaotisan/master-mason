"""Sacar el baston de espaldas con NUESTRO baston de principio a fin (2026-10-15).

El video (Pilgrim_drawing_staff_on_green) empieza en la referencia con el baston en la
correa (la capa de la escena, que entonces era baston.png) y Veo lo repinta a su
manera todo el rato: el de la mano, con la garra mas estrecha. La escena pone ahora a
la espalda el de la mano (assets/characters/baston/baston_espalda.png) y el usuario
quiere un solo baston ("igualarlo todo, a la vieja usanza"): aqui, el de Veo fuera
en cada fotograma y el nuestro (baston_espalda_master.png, la plantilla del guardar)
siguiendo su garra (garra.json, seguida) y el giro de su vara (medido en lo fino que
asoma fuera del cuerpo). Lo que hace en el video:
  1..QUIETO          en la correa: la capa de la escena (como el final del guardar:
                     en_la_correa de peregrino_guardar_baston_espalda_a/arreglar.py).
  QUIETO+1..PIVOTA   la mano llega y tira de la garra hacia un lado: el pie se queda
                     en la presilla de abajo (el baston pivota sobre el).
  ..SALE             lo saca hacia arriba por delante de la espalda, resbalando por
                     las presillas (que van encima): sobre la espalda limpia y la
                     correa vacia (la de la escena), el baston y encima las presillas;
                     el brazo y la mano, delante.
  DETRAS..           pasa por encima de la cabeza y baja por el otro lado del cuerpo:
                     por detras de todo (solo asoma fuera de la silueta: la garra
                     arriba a la derecha, el pie a la izquierda) hasta quedar derecho a
                     la derecha, en la mano, como el reposo con baston. La mano encima.
Largura: la de la correa (LARGO_CORREA) mientras sale; la de la mano (LARGO_MANO, la
del reposo) desde que va por detras. Casilla de 952 (montar.py --my 152): las capas
(904) van BAJA px mas abajo.
Los fotogramas de Veo se guardan en _todos_veo/ la primera vez; se escribe en _todos/.
    python arreglar.py      (antes que animar.py)
Las capas de la correa vacia (capas/correa_vacia_atras.png y _delante.png) las pinta
la escena: CAPTURA_CON=1 CAPTURA_ANIM=reposo_espalda_cb CAPTURA_SOLO=atras|delante con
peregrino_sacar_baston_frente/capa_espalda.gd.
"""
import glob, importlib.util, json, os, shutil, sys
import numpy as np, cv2
from PIL import Image
from scipy.ndimage import gaussian_filter1d

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
TODOS, VEO = os.path.join(AQUI, '_todos'), os.path.join(AQUI, '_todos_veo')
_argv = sys.argv; sys.argv = [_argv[0]]
spec = importlib.util.spec_from_file_location('arreglar_guardar', os.path.join(ANIM, 'peregrino_guardar_baston_espalda_a', 'arreglar.py'))
R = importlib.util.module_from_spec(spec); spec.loader.exec_module(R)
sys.argv = _argv

QUIETO = 24                 # hasta aqui en la correa, quieto
PIVOTA = 40                 # hasta aqui la mano tira de la garra y el pie se queda
SALE = 68                   # hasta aqui sale por delante de la espalda (en el video, el palo cruza la
                            # espalda hasta el 68 y en el 69 asoma el pie por abajo a la izquierda,
                            # por detras: con 62 desaparecia de la espalda 6 fotogramas antes)
CRECE = (48, 58)            # saliendo de la correa pasa a verse entero (la largura de la mano: en el
                            # video, sacandolo, el pie llega abajo de la espalda) mientras la mano lo
                            # sube (asi el pie sube un poco, como si resbalara); antes el pie se salia
                            # por debajo de la tunica
DETRAS = SALE + 1           # desde aqui, por detras del cuerpo
HASTA = 110                 # el video que se usa llega al 100 (animar.py)
BAJA = 48                   # la casilla de 952 frente a la de 904
LARGO_MANO = 572.0          # de la bola al pie en la mano (el del final del video; el reposo, 575)
MEDIDO = (54, HASTA)        # aqui el giro de la vara se mide (asoma fuera del cuerpo)
ZONA = 16                   # px a cada lado de la vara de Veo que se quitan
HOMBRO_Y = 345              # sobre la espalda solo se repone por debajo (arriba, la capucha: Veo la
                            # mueve con la cabeza y la de la espalda limpia salia doble)
R_GARRA = 58                # y alrededor de su bola


def bajar(ruta):
    c = Image.new('RGBA', (664, 904 + BAJA), (0, 0, 0, 0))
    c.alpha_composite(Image.open(ruta).convert('RGBA'), (0, BAJA))
    return np.asarray(c).astype(np.float32)


def cargar(k):
    return np.asarray(Image.open(os.path.join(VEO, 'c_%03d.png' % k)).convert('RGBA'))


def u_de(phi):
    t = np.radians(phi)
    return np.array([np.sin(t), np.cos(t)])


def medir_giro(a, b):
    """(giro, cuantos px) de la vara de Veo: lo fino fuera del cuerpo a 75-650 px de la
    bola, por direcciones (la mas votada). Sin las piernas (y > 800)."""
    al = a[..., 3] > 128
    gordo = cv2.morphologyEx(al.astype(np.uint8), cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (19, 19)))
    fino = al & ~cv2.dilate(gordo, np.ones((3, 3), np.uint8)).astype(bool)
    fino[800:] = False
    ys, xs = np.nonzero(fino)
    dx, dy = xs - b[0], ys - b[1]
    r = np.hypot(dx, dy)
    m = (r > 75) & (r < 650)
    if m.sum() < 20:
        return None, 0
    th = np.degrees(np.arctan2(dx[m], dy[m]))
    h, e = np.histogram(th, bins=np.arange(-180, 181, 2))
    i = np.argmax(h)
    pico = (e[i] + e[i + 1]) / 2
    sel = np.abs(((th - pico + 180) % 360) - 180) < 4
    return float(np.median(th[sel])), int(sel.sum())


def mano(a, b):
    """La mano (la pieza de piel mas grande cerca de la bola), con su orla."""
    ys, xs = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    p = (R.piel(a) & (np.hypot(xs - b[0], ys - b[1]) < 260)).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(p)
    if n < 2:
        return np.zeros(a.shape[:2], bool)
    m = lab == 1 + np.argmax(st[1:, cv2.CC_STAT_AREA])
    return cv2.dilate(m.astype(np.uint8), np.ones((7, 7), np.uint8)).astype(bool) & (a[..., 3] > 0)


def poses(garra, n, desp):
    """{k: (bola, giro, largo)} de QUIETO+1 a n. desp: el cuerpo desplazado (el pie va en
    la presilla de abajo, que se mueve con el)."""
    b0 = np.array(R.B_CORREA, float)          # (ya en la casilla de 952: main la baja)
    ks = list(range(QUIETO + 1, n + 1))
    bolas = np.array([garra[k][:2] for k in ks], float)
    bolas[:, 0] = gaussian_filter1d(bolas[:, 0], 1.0, mode='nearest')
    bolas[:, 1] = gaussian_filter1d(bolas[:, 1], 1.0, mode='nearest')
    # el giro: pivotando sobre el pie hasta PIVOTA; medido desde MEDIDO[0]; en medio,
    # de uno al otro
    giro, largo = {}, {}
    for i, k in enumerate(ks):
        if k <= PIVOTA:
            pie0 = b0 + desp[k] + R.LARGO_CORREA * u_de(R.PHI_CORREA)
            d = pie0 - bolas[i]
            giro[k] = float(np.degrees(np.arctan2(d[0], d[1])))
            largo[k] = float(np.hypot(*d))
    medidos = {}
    for i, k in enumerate(ks):
        if MEDIDO[0] <= k <= MEDIDO[1]:
            g, cuantos = medir_giro(cargar(k), bolas[i])
            if g is not None and cuantos >= 250:
                medidos[k] = g
    nudos = sorted([(k, v) for k, v in giro.items()] + list(medidos.items()))
    xs_, ys_ = np.array([k for k, _ in nudos], float), np.array([v for _, v in nudos])
    g_todo = np.interp(ks, xs_, ys_)
    g_todo[ks.index(PIVOTA) + 1:] = gaussian_filter1d(g_todo, 1.2, mode='nearest')[ks.index(PIVOTA) + 1:]
    l_sale = largo[PIVOTA]
    res = {}
    for i, k in enumerate(ks):
        if k <= PIVOTA:
            L = largo[k]
        else:
            L = l_sale + (LARGO_MANO - l_sale) * R.tramo(k, CRECE[0], CRECE[1])
        res[k] = (bolas[i], float(g_todo[i]), float(L))
    return res


if __name__ == '__main__':
    if not os.path.isdir(VEO):
        os.makedirs(VEO)
        for f in glob.glob(os.path.join(TODOS, '*.png')):
            shutil.copy2(f, VEO)
    N = len(glob.glob(os.path.join(VEO, 'c_*.png')))
    # en la correa: lo del guardar, con las capas bajadas a la casilla de 952
    tmp = os.path.join(AQUI, '_capas_952')
    os.makedirs(tmp, exist_ok=True)
    for nombre, ruta in [('nueva', R.CORREA_NUEVA), ('veo', R.CORREA_VEO)]:
        Image.fromarray(bajar(ruta).astype(np.uint8)).save(os.path.join(tmp, nombre + '.png'))
    capa_veo = bajar(R.CORREA_VEO)[..., 3] > 30
    R.CORREA_NUEVA = os.path.join(tmp, 'nueva.png')
    R.CORREA_VEO = os.path.join(tmp, 'veo.png')
    R.MY = R.MY + BAJA
    R.RESBALA = -1
    R.B_CORREA = (R.B_CORREA[0], R.B_CORREA[1] + BAJA)
    garra = {int(k): v for k, v in json.load(open(os.path.join(AQUI, 'garra.json'))).items()}
    # el cuerpo de Veo desplazado frente a la espalda limpia, hasta que el baston va por
    # detras (luego no se repone nada sobre el cuerpo); sin la correa, el baston (de la
    # garra hacia la presilla de abajo), la mano ni el brazo
    R._cargador = cargar
    R.en_la_correa(cargar(1), 1, garra, d=np.zeros(2))       # (carga las capas)
    zv = cv2.dilate(R._capas['zona'].astype(np.uint8), np.ones((9, 9), np.uint8)).astype(bool)
    esp0 = R._capas['espalda']

    def quitar(k, a):
        b = np.array(garra[k][:2], float)
        q = zv | R.piel(a) | R.banda(a.shape[:2], b, -17.0, 520.0, 22) | R.banda(a.shape[:2], b, 0.0, 520.0, 22)
        dif = (np.abs(a[..., :3].astype(np.float32) - esp0[..., :3]).max(2) > 40) & (a[..., 3] > 128)
        brazo = cv2.morphologyEx(dif.astype(np.uint8), cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (19, 19))).astype(bool)
        return q | brazo
    desp = R.desplazamientos(list(range(1, SALE + 1)), quitar)
    for k in range(SALE + 1, HASTA + 1):
        desp[k] = desp[SALE]
    print('cuerpo desplazado: ' + ', '.join('%d (%.1f, %.1f)' % (k, *desp[k]) for k in range(1, SALE + 1, 6)))
    for k in range(1, QUIETO + 1):
        a = cargar(k)
        out = R.en_la_correa(a, k, garra, desp[k]).clip(0, 255).astype(np.uint8)
        Image.fromarray(out).save(os.path.join(TODOS, 'c_%03d.png' % k))
    # luego, siguiendo la garra de Veo
    T, tb, tpie = R.plantilla_mano()
    esp = Image.new('RGBA', (664, 904 + BAJA), (0, 0, 0, 0))
    esp.alpha_composite(Image.open(R.ESPALDA).convert('RGBA'), (R.MX, R.MY))
    espalda = np.asarray(esp).astype(np.float32)
    atras = bajar(os.path.join(AQUI, 'capas', 'correa_vacia_atras.png'))
    delante = bajar(os.path.join(AQUI, 'capas', 'correa_vacia_delante.png'))
    limpia = R.encima(espalda, atras)          # la espalda con la correa (sin presillas)
    zona_correa = cv2.dilate(capa_veo.astype(np.uint8), cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (23, 23))).astype(bool)
    n = min(N, HASTA)
    pose = poses(garra, n, desp)
    dentro = espalda[..., 3] > 60
    ys, xs = np.mgrid[0:espalda.shape[0], 0:espalda.shape[1]]
    limpia0, delante0, zona_correa0, espalda0 = limpia, delante, zona_correa, espalda
    for k in range(QUIETO + 1, n + 1):
        a = cargar(k)
        b, phi, L = pose[k]
        # la espalda, la correa y las presillas, pegadas al cuerpo de este fotograma
        limpia = R.mover(limpia0, desp[k])
        delante = R.mover(delante0, desp[k])
        espalda = R.mover(espalda0, desp[k])
        zona_correa = R.mover(zona_correa0.astype(np.uint8), desp[k]).astype(bool)
        dentro = espalda[..., 3] > 60
        piel_k = mano(a, b)
        al = a[..., 3] > 128
        gordo = cv2.morphologyEx(al.astype(np.uint8), cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (19, 19))).astype(bool)
        # lo que difiere de la espalda limpia y es gordo: el brazo y la mano (la vara es fina)
        dif = (np.abs(a[..., :3].astype(np.float32) - limpia[..., :3]).max(2) > 30) & al
        brazo = cv2.morphologyEx(dif.astype(np.uint8), cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (19, 19))).astype(bool)
        brazo |= gordo & ~dentro
        # donde esta lo de Veo: a lo largo de su vara y alrededor de su garra
        zona = R.banda(a.shape[:2], b, phi, L + 40, ZONA) | (np.hypot(xs - b[0], ys - b[1]) < R_GARRA)
        if k <= SALE:
            zona |= zona_correa
        o = a.astype(np.float32).copy()
        # fuera de la silueta: lo fino (la vara y la garra de Veo), fuera
        fuera = zona & ~dentro & ~gordo & ~piel_k
        o[fuera] = 0
        # dentro (sobre la espalda): la espalda limpia con su correa, salvo brazo y mano
        # (solo mientras va por delante: luego la vara de Veo va por detras del cuerpo
        # y sobre el no hay nada que quitar; reponer ahi la espalda limpia dejaba una cuna)
        cambia = zona & dentro & ~brazo & ~piel_k & (ys > HOMBRO_Y) & (k <= SALE)
        w = cv2.GaussianBlur(cambia.astype(np.float32), (0, 0), 1.2)
        o = R.mezclar(o, limpia, w)
        c_ = R.capa(a.shape[:2], T, tb, tpie, b, phi, L)
        if k <= SALE:
            # por delante de la espalda, con las presillas encima; el brazo y la mano, delante
            o = R.encima(o, c_)
            o = R.encima(o, delante)
            wb = cv2.GaussianBlur((brazo | piel_k).astype(np.float32), (0, 0), 1.0)
            o = R.mezclar(o, a, wb)
        else:
            # por detras de todo; la mano, encima. (Veo deja el cuerpo semitransparente
            # a trozos: lo gordo, opaco, o el baston se transparentaba)
            o[gordo, 3] = 255.0
            o = R.encima(c_, o)
            wm = cv2.GaussianBlur(piel_k.astype(np.float32), (0, 0), 1.0)
            o = R.mezclar(o, a, wm)
        Image.fromarray(o.clip(0, 255).astype(np.uint8)).save(os.path.join(TODOS, 'c_%03d.png' % k))
    print('hecho: 1..%d' % n)
    for k in range(QUIETO + 1, n + 1, 4):
        b, phi, L = pose[k]
        print('%3d bola (%6.1f, %6.1f) giro %6.1f largo %5.0f' % (k, b[0], b[1], phi, L))

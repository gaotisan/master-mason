"""Guardar el baston de espaldas (video B, Pilgrim_slinging_staff_on_back): que el
baston no atraviese al peregrino.

Veo lo inclina con la garra sobre el hombro derecho y deja la mitad de abajo
DENTRO del cuerpo (como si fuera por delante de el; asoma la punta por la
izquierda) y en c_062-c_066 la pasa a la espalda atravesandolo. Aqui, en
DESDE..HASTA, el palo va POR ENCIMA de la espalda: se lo cruza por la espalda y lo
encaja en la correa, sin atravesar nada (lo que Veo ya tiene en la espalda desde
el c_066).

Por fotograma, el eje del baston sale de la garra seguida (garra.py --espalda: la
bola y el giro de la plantilla; suavizados en el tiempo). De Veo se quedan la
garra y el palo hasta la mano; lo que asoma fuera del cuerpo mas abajo (el palo
junto al cuerpo al principio, la punta suelta por la izquierda despues) se borra,
y el palo se pinta con NUESTRA textura (assets/characters/baston/baston.png, la
del baston de la escena, que es la que copio Veo) desde un poco por debajo de la
mano hasta el pie, encima de la tunica y de la correa; la mano se vuelve a poner
encima. Largo de la bola al pie: el de la mano (BOLA_AL_PIE, c_001) va bajando
hasta el de Veo al entrar en la correa (LARGO_HASTA, c_066): Veo lo encoge al
meterlo (el de la espalda de la escena es mas corto: recortado para el agachado).
Los fotogramas de Veo se guardan en _todos_veo/ la primera vez; el arreglo se
escribe sobre _todos/ (lo que lee el montaje).
    python arreglar.py
"""
import glob, json, os, shutil
import numpy as np, cv2
from PIL import Image
from scipy.ndimage import gaussian_filter1d

AQUI = os.path.dirname(os.path.abspath(__file__))
PROY = os.path.abspath(os.path.join(AQUI, '..', '..', '..', '..'))
TODOS, VEO = os.path.join(AQUI, '_todos'), os.path.join(AQUI, '_todos_veo')
DESDE, HASTA = 49, 65
SIN_DESDE = 61              # garra.py siguio desde el final (plantilla sin baston) hasta aqui
BOLA_AL_PIE = 597.0         # px de master, de la bola al pie del baston en la mano (c_001)
LARGO_HASTA = 450.0         # el de Veo ya en la correa (c_066-c_076, ~430-440)
ACORTA_DESDE = 61           # de aqui a HASTA se acorta hasta LARGO_HASTA
BAJO_LA_MANO = 18.0         # el palo pintado empieza aqui por debajo de donde entra en el cuerpo
MANO_IZQ = (165, 595, 215, 650)   # la mano izquierda, quieta: no es el baston

TEX = np.asarray(Image.open(os.path.join(PROY, 'assets', 'characters', 'baston', 'baston.png')).convert('RGBA')).astype(np.float32)
TEX_BOLA = np.array([TEX.shape[1] / 2 - 0.6, TEX.shape[0] / 2 - 74.5 - 24])   # el Orbe del nodo, en la textura
TEX_PIE = 220.0             # ultima fila opaca de la textura
TEX[int(TEX_PIE) + 1:, :, 3] = 0   # debajo, una cola casi transparente (alfa 28) que sobre verde se ve verdosa

if not os.path.isdir(VEO):
    os.makedirs(VEO)
    for f in glob.glob(os.path.join(TODOS, '*.png')):
        shutil.copy2(f, VEO)


def cargar(k):
    return np.asarray(Image.open(os.path.join(VEO, 'c_%03d.png' % k)).convert('RGBA'))


def eje(k, garra):
    """(bola, direccion hacia el pie): la plantilla de con baston (en pie) hasta
    SIN_DESDE, la de sin baston (en la correa, a 19,46 grados) desde ahi."""
    x, y, ang = garra[str(k)][:3]
    phi = np.radians(19.46) if k >= SIN_DESDE else 0.0
    v = np.array([-np.sin(phi), np.cos(phi)])
    a = np.radians(ang)
    return np.array([x, y]), np.array([np.cos(a) * v[0] + np.sin(a) * v[1], -np.sin(a) * v[0] + np.cos(a) * v[1]])


def cuerpo_y_fuera(a):
    al = (a[..., 3] > 128).astype(np.uint8)
    m = cv2.morphologyEx(al, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (19, 19)))
    n, lab, st, _ = cv2.connectedComponentsWithStats(m)
    cuerpo = lab == 1 + np.argmax(st[1:, cv2.CC_STAT_AREA])
    fuera = (a[..., 3] > 0) & ~cv2.dilate(cuerpo.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool)
    fuera[740:, 230:400] = False                               # piernas y pies
    fuera[MANO_IZQ[1]:MANO_IZQ[3], MANO_IZQ[0]:MANO_IZQ[2]] = False
    return cuerpo, fuera


def pintar_palo(img, bola, v, largo, desde):
    """Nuestro baston, de 'desde' px por debajo de la bola hasta el pie (a 'largo')."""
    sy = largo / (2 * (TEX_PIE - TEX_BOLA[1]))
    R = np.array([[v[1], v[0]], [-v[0], v[1]]])              # (0, 1) de la textura -> v
    A = R @ np.diag([2.0, 2.0 * sy])
    M = np.hstack([A, (bola - A @ TEX_BOLA)[:, None]])
    capa = cv2.warpAffine(TEX, M, (img.shape[1], img.shape[0]), flags=cv2.INTER_LINEAR, borderValue=0)
    ys, xs = np.mgrid[0:img.shape[0], 0:img.shape[1]]
    s = (xs - bola[0]) * v[0] + (ys - bola[1]) * v[1]          # distancia por el eje
    capa[..., 3] *= np.clip((s - desde) / 3.0, 0, 1)
    al = capa[..., 3:] / 255.0
    out = img.copy()
    out[..., :3] = capa[..., :3] * al + img[..., :3] * (1 - al)
    out[..., 3] = np.maximum(img[..., 3], capa[..., 3])
    return out


def piel(a, cerca, radio=40):
    r, g, b = [a[..., i].astype(int) for i in range(3)]
    m = (r > 160) & (g > 115) & (r - b > 25) & (r - b < 95) & (a[..., 3] > 128)
    ys, xs = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    return m & (np.hypot(xs - cerca[0], ys - cerca[1]) < radio)


def punta_de_veo(a, bola):
    """La punta del baston de Veo que asoma por la izquierda (o None)."""
    cuerpo, fuera = cuerpo_y_fuera(a)
    n, lab, st, _ = cv2.connectedComponentsWithStats((fuera & (a[..., 3] > 100)).astype(np.uint8))
    mejor = None
    for j in range(1, n):
        x, y, w, h, area = st[j]
        if x < 200 and y > 300 and h > 25 and area > 60:
            ys, xs = np.nonzero(lab == j)
            d = np.hypot(xs - bola[0], ys - bola[1]); m = np.argmax(d)
            if mejor is None or d[m] > mejor[1]:
                mejor = (np.array([xs[m], ys[m]], float), d[m])
    return None if mejor is None else mejor[0]


if __name__ == '__main__':
    garra = json.load(open(os.path.join(AQUI, 'garra.json')))
    ks = list(range(DESDE, HASTA + 1))
    bolas = gaussian_filter1d(np.array([eje(k, garra)[0] for k in ks]), 1.0, axis=0, mode='nearest')
    # el eje: de la bola a la punta de Veo donde asoma (su baston de verdad: el giro
    # de la plantilla de la garra no lo sigue bien al cruzarlo); donde no asoma, el
    # de la garra, con el largo de la mano bajando hasta el primero con punta
    puntas = {k: punta_de_veo(cargar(k), bolas[i]) for i, k in enumerate(ks)}
    con_punta = [i for i, k in enumerate(ks) if puntas[ks[i]] is not None]
    fin = np.zeros((len(ks), 2))
    for i, k in enumerate(ks):
        if puntas[k] is not None:
            fin[i] = puntas[k]
    i0 = con_punta[0]
    l0 = np.hypot(*(fin[i0] - bolas[i0]))
    for i in range(i0):
        t_ = i / max(i0, 1); t_ = t_ * t_ * (3 - 2 * t_)
        fin[i] = bolas[i] + eje(ks[i], garra)[1] * (BOLA_AL_PIE + (l0 - BOLA_AL_PIE) * t_)
    fin = gaussian_filter1d(fin, 1.0, axis=0, mode='nearest')
    # al final, Veo lo pasa de golpe del largo de la mano (~565) al de la correa (~440,
    # c_066): aqui se va acortando desde ACORTA_DESDE, como si entrara en las presillas
    for i, k in enumerate(ks):
        if k >= ACORTA_DESDE:
            t_ = (k - ACORTA_DESDE) / (HASTA - ACORTA_DESDE); t_ = t_ * t_ * (3 - 2 * t_)
            d = fin[i] - bolas[i]; l = np.hypot(*d)
            fin[i] = bolas[i] + d / l * (l + (LARGO_HASTA - l) * t_)
    for i, k in enumerate(ks):
        a = cargar(k)
        bola = bolas[i]
        largo = float(np.hypot(*(fin[i] - bola))); v = (fin[i] - bola) / largo
        cuerpo, fuera = cuerpo_y_fuera(a)
        entra = next((s for s in range(40, int(largo)) if cuerpo[int(bola[1] + v[1] * s), int(bola[0] + v[0] * s)]), 60)
        # de Veo, fuera del cuerpo, lo que quede por debajo de la mano (la semilla, lo
        # opaco; su orla, solo lejos del borde de la tunica)
        ys, xs = np.mgrid[0:a.shape[0], 0:a.shape[1]]
        s = (xs - bola[0]) * v[0] + (ys - bola[1]) * v[1]
        quitar = fuera & (a[..., 3] > 100) & (s > entra + 8)
        cerca_cuerpo = cv2.dilate(cuerpo.astype(np.uint8), np.ones((7, 7), np.uint8)).astype(bool)
        quitar = cv2.dilate(quitar.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool) & ~cerca_cuerpo | quitar
        quitar |= fuera & (a[..., 3] <= 100) & (s > entra + 8) & ~cerca_cuerpo   # orlas sueltas de su punta
        b = a.astype(np.float32).copy(); b[quitar] = 0
        img = pintar_palo(b, bola, v, largo, entra + BAJO_LA_MANO)
        mano = piel(a, bola + v * entra)
        img[mano] = a[mano]
        Image.fromarray(img.round().clip(0, 255).astype(np.uint8), 'RGBA').save(os.path.join(TODOS, 'c_%03d.png' % k))
        print('c_%03d  bola (%d,%d)  %.0f grados  largo %d%s  entra a %d px  quitado %d px  mano %d px' % (
            k, bola[0], bola[1], np.degrees(np.arctan2(-v[0], v[1])), largo, '' if puntas[k] is not None else ' (sin punta: garra)',
            entra, quitar.sum(), mano.sum()))

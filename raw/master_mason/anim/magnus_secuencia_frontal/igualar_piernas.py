"""Piernas y pies de espaldas del color del reposo sin baston (2026-10-12).

El andar de espaldas v3 y el correr de espaldas v2 se repitieron con el prompt de los
pies oscuros y Veo los saco con calzas grises (el correr, gris casi neutro y con
brillos claros): sobre el fondo oscuro de la escena se veian palidos, y no casaban con
el reposo de espaldas del que salen y al que vuelven (magnus_espalda_sin_baston: el del
video de con baston, piernas pardo-moradas oscuras como las de frente).

Aqui, transferencia de color en Lab (media y desviacion) de las piernas y los pies de
cada video a las del reposo, con las estadisticas de TODO el video (no de cada
fotograma: asi no parpadea). El tono (a*, b*) entero; la luz (L) casi entera (PESO_L)
y los brillos comprimidos por encima de la rodilla (RODILLA, PENDIENTE): la espinilla
gris casi blanca del correr. Mascara: lo fino que cuelga de la tunica y llega a la
franja de los pies o, en el aire, lo largo con pixeles oscuros de pierna, mas la
franja de los pies (la apertura, a media resolucion para que no tarde).

Y mas finas (ADELGAZAR): Veo las hizo gruesas. Espinilla y pie, en px de master:
andar aceptado 12 y 29; andar v3 15 y 32; correr v2 18 y 38 (el usuario: "los pies son
algo anchos"). Cada tramo de cada fila de la mascara (una pierna o un pie) se estrecha
alrededor de su centro; lo que queda libre, transparente (detras no hay nada). El
factor, por fotograma, el que deja la espinilla mas fina en ESPINILLA (suavizado en el
tiempo): con uno fijo, de pie (que no estaba gruesa) los pies quedaban mas estrechos que
los del reposo y en el puente al reposo se ensanchaban.
Los fotogramas de Veo se guardan en _todos_veo/ la primera vez; el arreglo sale siempre
de ellos y se escribe sobre _todos/ (lo que lee secuencia.py). Si se vuelve a montar,
volver a pasarlo.
    python igualar_piernas.py magnus_andar_espalda_sin_v3 magnus_correr_espalda_v2
"""
import os, shutil, sys
import numpy as np, cv2
from PIL import Image

ANIM = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
REFERENCIA = os.path.join(ANIM, 'magnus_espalda_sin_baston', 'espalda_sin_baston.png')
DISCO = 41               # px de master; la apertura va a la mitad
ALTO_PIERNA = 60
BANDA_PIES = 34
PESO_L = 0.8             # cuanto se acerca la luz a la del reposo (el tono va entero)
RODILLA = 0.0            # brillos: por encima de media + RODILLA desviaciones del reposo...
PENDIENTE = 0.2          # ...la luz sube solo a este ritmo (la espinilla gris casi blanca del correr;
                         # con 1,0 y 0,3 en el juego, sobre el fondo oscuro, aun se veia clara: L* 31 %,
                         # contra 24 % las piernas de frente y 18 % las del reposo)
ADELGAZAR = ('magnus_correr_espalda_v2', 'magnus_andar_espalda_sin_v3')
ESPINILLA = 12.5         # px de master: la del andar aceptado y el reposo (12)
S_MIN = 0.62             # lo que mas se estrecha
SUAVE = 2.5              # el factor de cada fotograma, suavizado en el tiempo (gaussiana)


def leer(ruta):
    return np.asarray(Image.open(ruta).convert('RGBA'))


def fino(a, desde=0.55):
    al = (a[..., 3] > 40).astype(np.uint8)
    ys = np.nonzero(al.any(1))[0]
    top, yb = ys.min(), ys.max()
    h, w = al.shape
    peq = cv2.resize(al, (w // 2, h // 2), interpolation=cv2.INTER_AREA)
    d = DISCO // 2 | 1
    ab = cv2.morphologyEx(peq, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (d, d)))
    ab = cv2.resize(ab, (w, h), interpolation=cv2.INTER_NEAREST)
    f = (al > 0) & (ab == 0)
    f[:int(top + desde * (yb - top))] = False
    return f, top, yb


def mascara(a, largas=True):
    """Piernas: lo fino que llega a la franja de los pies (de espaldas, la pierna gris
    clara del correr no tiene pixeles oscuros; las manos no bajan tanto) o, si va en el
    aire, lo largo con pixeles oscuros de pierna; y la franja de los pies."""
    f, top, yb = fino(a)
    L = a[..., :3].astype(float) @ [0.299, 0.587, 0.114]
    banda = np.zeros(f.shape, bool)
    banda[yb - BANDA_PIES:yb + 1] = True
    m = np.zeros(f.shape, bool)
    n, lab, st, _ = cv2.connectedComponentsWithStats(f.astype(np.uint8), 8)
    for i in range(1, n):
        c = lab == i
        if st[i, cv2.CC_STAT_AREA] <= 150:
            continue
        if not largas or (c & banda).any() or (st[i, cv2.CC_STAT_HEIGHT] >= ALTO_PIERNA
                                               and ((L < 75) & c & (a[..., 3] > 200)).sum() > 40):
            m |= c
    z = m | (banda & (a[..., 3] > 0))
    return cv2.dilate(z.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool) & (a[..., 3] > 0)


def lab(rgb):
    return cv2.cvtColor(np.ascontiguousarray(rgb.reshape(-1, 1, 3).astype(np.uint8)),
                        cv2.COLOR_RGB2LAB).reshape(-1, 3).astype(float)


def rgb(x):
    return cv2.cvtColor(np.clip(x, 0, 255).astype(np.uint8).reshape(-1, 1, 3), cv2.COLOR_LAB2RGB).reshape(-1, 3)


def estadisticas(pixeles):
    X = lab(pixeles)
    return X.mean(0), X.std(0) + 1e-6


def objetivo():
    a = leer(REFERENCIA)
    m = mascara(a, largas=False) & (a[..., 3] > 200)
    return estadisticas(a[m][:, :3])


def transferir(a, m, fuente, destino):
    (mu_s, sd_s), (mu_t, sd_t) = fuente, destino
    b = a.copy()
    X = lab(a[m][:, :3])
    Y = (X - mu_s) * (sd_t / sd_s) + mu_t
    # la luz: el contraste del reposo, pero la media la del video si es mas oscura (la
    # del reposo cuenta sus pies, mas claros: subirla aclaraba las piernas del andar y
    # volvia a parecer piel)
    Y[:, 0] = (X[:, 0] - mu_s[0]) * (sd_t[0] / sd_s[0]) + min(mu_s[0], mu_t[0])
    Y[:, 0] = X[:, 0] * (1 - PESO_L) + Y[:, 0] * PESO_L
    rodilla = mu_t[0] + RODILLA * sd_t[0]
    Y[:, 0] = np.where(Y[:, 0] > rodilla, rodilla + (Y[:, 0] - rodilla) * PENDIENTE, Y[:, 0])
    b[m, :3] = rgb(Y)
    return b


def adelgazar(a, m, s):
    """Cada tramo de cada fila de m (una pierna o un pie) a s de su ancho, alrededor de su
    centro, muestreando la fila original (premultiplicada); fuera de m no se toca."""
    a = a.astype(float)
    pm = a.copy()
    pm[..., :3] *= pm[..., 3:4] / 255.0
    out = pm.copy()
    w = m.shape[1]
    for y in np.nonzero(m.any(1))[0]:
        xs = np.nonzero(m[y])[0]
        for seg in np.split(xs, np.nonzero(np.diff(xs) > 1)[0] + 1):
            x0, x1 = seg[0], seg[-1]
            c = (x0 + x1) / 2.0
            nx = np.arange(x0, x1 + 1)
            fuente = c + (nx - c) / s
            dentro = (fuente >= x0 - 0.5) & (fuente <= x1 + 0.5)
            f0 = np.clip(np.floor(fuente).astype(int), 0, w - 1)
            f1 = np.clip(f0 + 1, 0, w - 1)
            t = (fuente - np.floor(fuente))[:, None]
            val = pm[y, f0] * (1 - t) + pm[y, f1] * t
            val[~dentro] = 0
            out[y, x0:x1 + 1] = val
    al = out[..., 3:4]
    rgb_ = np.where(al > 0, out[..., :3] * 255.0 / np.maximum(al, 1e-6), 0)
    res = np.dstack([rgb_, al[..., 0]])
    res[~m] = a[~m]
    return np.clip(np.round(res), 0, 255).astype(np.uint8)


def espinilla(a, m):
    """Ancho de la pierna mas fina (mediana de sus filas) de 75 a 45 px sobre el suelo:
    la espinilla del pie de apoyo; nan si no se ve."""
    al = a[..., 3] > 128
    yb = np.nonzero(al.any(1))[0].max()
    zona = np.zeros(al.shape, bool)
    zona[yb - 75:yb - 44] = True
    n, lab, st, _ = cv2.connectedComponentsWithStats((m & al & zona).astype(np.uint8), 8)
    w = []
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] > 30:
            c = lab == i
            w.append(np.median([np.count_nonzero(c[y]) for y in range(yb - 75, yb - 44) if np.count_nonzero(c[y])]))
    return min(w) if w else np.nan


def factores(anchos):
    """Por fotograma, lo que hay que estrechar para dejar la espinilla en ESPINILLA,
    suavizado en el tiempo (sin medida: interpolado)."""
    from scipy.ndimage import gaussian_filter1d
    w = np.array(anchos, float)
    ok = ~np.isnan(w)
    w = np.interp(np.arange(len(w)), np.nonzero(ok)[0], w[ok])
    return np.clip(ESPINILLA / gaussian_filter1d(w, SUAVE, mode='nearest'), S_MIN, 1.0)


def main(jobs):
    destino = objetivo()
    print('reposo: L %.0f +- %.0f, a* %+.1f, b* %+.1f' % (destino[0][0], destino[1][0], destino[0][1] - 128, destino[0][2] - 128))
    for job in jobs:
        todos, veo = os.path.join(ANIM, job, '_todos'), os.path.join(ANIM, job, '_todos_veo')
        if not os.path.isdir(veo):
            shutil.copytree(todos, veo)
        nombres = sorted(n for n in os.listdir(veo) if n.endswith('.png'))
        muestras = []
        for n in nombres[::3]:
            a = leer(os.path.join(veo, n))
            muestras.append(a[mascara(a) & (a[..., 3] > 200)][:, :3])
        fuente = estadisticas(np.concatenate(muestras))
        print('%s: L %.0f +- %.0f, a* %+.1f, b* %+.1f' % (job, fuente[0][0], fuente[1][0], fuente[0][1] - 128, fuente[0][2] - 128))
        mascaras = {}
        anchos = []
        for n in nombres:
            a = leer(os.path.join(veo, n))
            mascaras[n] = mascara(a)
            anchos.append(espinilla(a, mascaras[n]))
        s = factores(anchos) if job in ADELGAZAR else np.ones(len(nombres))
        for n, s_k in zip(nombres, s):
            a = leer(os.path.join(veo, n))
            b = transferir(a, mascaras[n], fuente, destino)
            if s_k < 0.995:
                b = adelgazar(b, mascaras[n], s_k)
            Image.fromarray(b).save(os.path.join(todos, n))
        print('   %d fotogramas; ancho x%.2f..x%.2f (mediana x%.2f)' % (len(nombres), s.min(), s.max(), np.median(s)))


if __name__ == '__main__':
    main(sys.argv[1:] or ['magnus_andar_espalda_sin_v3', 'magnus_correr_espalda_v2'])

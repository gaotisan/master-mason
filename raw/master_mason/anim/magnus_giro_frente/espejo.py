"""Giro por delante: primera mitad del video y su ESPEJO al reves (-> 04_espejo).

Por que (2026-10-09). El juego no tiene sprites mirando a la izquierda: son los
de la derecha volteados (flip_h). El reposo al acabar el giro es el reposo
espejado, que ensena el MISMO costado del personaje volteado. La segunda mitad
del video, en cambio, ensena el otro costado (el otro brazo, otro dibujo de la
tunica), y por eso no casaba al acabar: el usuario veia "un saltazo" y luego,
con un morphing al final (descartado), "una metamorfosis". La primera mitad (de
perfil al frente) si casa con el reposo. Idea del usuario: sacar la segunda
mitad de la primera.

  - Primera mitad: c_007-c_052 (video 26-71). Las seis primeras se quitan: casi
    quietas, alargaban el giro sin girar. Total 92 fotogramas, 1,53 s a 60 fps.
  - Segunda mitad: las mismas espejadas respecto al centro de la casilla y al
    reves. El frente exacto cae entre c_052 y c_053 (c_052 es casi el espejo de
    c_053 y al reves: 1,47 pasos normales de silueta), asi que tras c_052 viene
    su espejo, que hace de c_053, sin repetir ninguno.
  - El ultimo fotograma es el espejo del primero, y el primero ES el reposo
    (fundido de N_INI desde el): acaba exactamente en el reposo espejado, que
    es lo que pone magnus.gd al voltear.
  - En el frente el dibujo de la tunica se invierte (la silueta casi no
    cambia). Para que los paneles no cambien de golpe, en VENTANA fotogramas a
    cada lado se funde cada uno con la imagen del otro lado al mismo angulo (el
    video tras el frente, espejado o no): mismas siluetas (1,4-1,5 pasos), solo
    cambia el dibujo.
  - Colocacion: dy fijo (el del encaje con el reposo); dx del encaje con el
    reposo en c_007 a 0 en el frente (alli el eje de simetria cae en el centro
    de la casilla), con rampa suave.
  - Tono de la tunica: el estandar (igualar_tono.py), medido en c_007-c_009.
    python espejo.py   (luego hoja.ps1 -Job magnus_giro_frente -Desde 04_espejo)"""
import glob, os, shutil, sys
import numpy as np
from PIL import Image, ImageOps

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(AQUI))
import igualar_tono as tono

ORIGEN = os.path.join(AQUI, '_antes_de_alinear')      # recortado, sin fondo, pulido; sin mover ni tono
DESTINO = os.path.join(AQUI, '04_espejo')
REPOSO = os.path.join(AQUI, '..', 'magnus_respirando', '04_limpios', 'c_01.png')
DESDE, FRENTE = 7, 52      # primera mitad c_007 .. c_052; el frente, entre c_052 y c_053
N_INI = 5                  # fundido desde el reposo al empezar (y, por el espejo, al acabar)
VENTANA = 3                # fotogramas a cada lado del frente con el dibujo fundido
HOMBROS = 230              # fila (casilla master) desde la que se encajan manos y mangas al fundir


def leer(k):
    return np.asarray(Image.open(os.path.join(ORIGEN, 'c_%02d.png' % k)).convert('RGBA'))


def mover(a, dx, dy):
    """Desplaza con subpixel en x (bilineal) y entero en y."""
    out = np.zeros_like(a, dtype=np.float32)
    a = a.astype(np.float32)
    a = np.roll(a, int(dy), 0)
    if int(dy) > 0:
        a[:int(dy)] = 0
    elif int(dy) < 0:
        a[int(dy):] = 0
    xi = int(np.floor(dx)); fr = dx - xi
    for paso, peso in ((xi, 1 - fr), (xi + 1, fr)):
        if peso == 0:
            continue
        b = np.roll(a, paso, 1)
        if paso > 0:
            b[:, :paso] = 0
        elif paso < 0:
            b[:, paso:] = 0
        out += b * peso
    return out.round().clip(0, 255).astype(np.uint8)


def espejo(a):
    return np.asarray(ImageOps.mirror(Image.fromarray(a, 'RGBA')))


def fundir(a, b, t):
    """Mezcla RGBA con alfa premultiplicado (sin halos en los bordes)."""
    a = a.astype(float); b = b.astype(float)
    pa, pb = a[..., :3] * a[..., 3:] / 255, b[..., :3] * b[..., 3:] / 255
    al = a[..., 3:] + (b[..., 3:] - a[..., 3:]) * t
    rgb = (pa + (pb - pa) * t) * 255 / np.maximum(al, 1e-6)
    return np.dstack([rgb, al]).clip(0, 255).round().astype(np.uint8)


def estructura(a):
    """Lo que tiene que casar al fundir el frente, sin el dibujo de la tunica:
    silueta y manos (piel). La tunica queda lisa, asi el flujo optico no intenta
    encajar paneles distintos entre si. La barba no: no es simetrica y al
    encajarla se retorcia."""
    import cv2
    x = a.astype(np.float32)
    r, g, b, al = x[..., 0], x[..., 1], x[..., 2], x[..., 3] / 255
    piel = (r > g + 12) & (g > b + 5) & (r > 140) & (r - b > 45) & (al > 0.5)
    e = 0.5 * al + 0.5 * piel
    return cv2.GaussianBlur((e * 255).astype(np.uint8), (0, 0), 1.5)


def morfar(u, v, t):
    """u -> v al punto t: los dos se deforman hacia el punto intermedio con el
    flujo optico de su estructura (suavizado: mueve manos y contorno enteros,
    no pixeles sueltos) y luego se mezclan. Sin esto los dedos salian dobles."""
    import cv2
    dis = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
    f = dis.calc(estructura(u), estructura(v), None)
    f = cv2.GaussianBlur(f, (0, 0), 4)
    h, w = u.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    # solo de los hombros para abajo (manos, mangas, pies): la cabeza se funde
    # tal cual, que al deformarla la barba y la capucha salian movidas
    f *= np.clip((yy - HOMBROS) / 80, 0, 1)[..., None]
    uw = cv2.remap(u, xx - t * f[..., 0], yy - t * f[..., 1], cv2.INTER_LINEAR, borderValue=0)
    vw = cv2.remap(v, xx + (1 - t) * f[..., 0], yy + (1 - t) * f[..., 1], cv2.INTER_LINEAR, borderValue=0)
    return fundir(uw, vw, t)


def encaje(a, ref):
    """(dx, dy) que lleva la silueta de a sobre la de ref (tronco y piernas)."""
    aa = a[..., 3].astype(np.float32) / 255
    rr = ref[..., 3].astype(np.float32) / 255
    mejor = None
    for dy in range(-12, 3):
        for dx in range(-12, 9):
            e = float(np.abs(np.roll(np.roll(aa, dy, 0), dx, 1) - rr)[300:].sum())
            if mejor is None or e < mejor[0]:
                mejor = (e, dx, dy)
    return mejor[1], mejor[2]


def suave(t):
    return t * t * (3 - 2 * t)


if __name__ == '__main__':
    rep = np.asarray(Image.open(REPOSO).convert('RGBA'))
    dx0, dy = encaje(leer(DESDE), rep)
    print('encaje de c_%03d con el reposo: dx %d dy %d' % (DESDE, dx0, dy))

    def dx_de(k):
        """dx de la primera mitad (y de su continuacion tras el frente, 0)."""
        if k >= FRENTE:
            return 0.0
        return dx0 * (1 - suave((k - DESDE) / (FRENTE - DESDE)))

    # tono estandar: ganancia medida en el arranque ya colocado
    muestra = [mover(leer(k), dx_de(k), dy).astype(float) / 255 for k in (DESDE, DESDE + 1, DESDE + 2)]
    g = np.ones(3)
    ref = tono.tono_reposo()
    for _ in range(5):
        g = g * ref / tono.media([tono.aplicar(im, g) for im in muestra])
    print('ganancia de tono (%.3f, %.3f, %.3f)' % tuple(g))

    cache = {}

    def A(k):
        """Fotograma k del video, colocado y con el tono estandar."""
        if k not in cache:
            im = mover(leer(k), dx_de(k), dy).astype(float) / 255
            cache[k] = (tono.aplicar(im, g) * 255).round().astype(np.uint8)
        return cache[k]

    # primera mitad, con el fundido desde el reposo
    H = []
    for i, k in enumerate(range(DESDE, FRENTE + 1)):
        a = A(k)
        if i < N_INI:
            a = fundir(a, rep, suave(1 - i / N_INI))
        H.append(a)
    n = len(H)
    sec = H + [espejo(H[j]) for j in range(n - 1, -1, -1)]
    # el frente: posicion p = -1 es c_052 (H[n-1]) y p = +1 su espejo (sec[n])
    w_total = 2 * VENTANA + 1
    for orden, p in enumerate(list(range(-VENTANA, 0)) + list(range(1, VENTANA + 1))):
        w = (orden + 1) / w_total
        if p < 0:
            i = n + p                                  # indice en sec (= en H)
            u = sec[i]                                 # el video, antes del frente
            v = espejo(A(FRENTE - p))                  # mismo angulo desde el otro lado: p=-1 -> espejo de c_053
        else:
            i = n - 1 + p
            v = sec[i]                                 # el espejo, despues del frente
            u = A(FRENTE + p)                          # p=1 -> c_053, 2 -> c_054...
        sec[i] = morfar(u, v, w)
    if os.path.isdir(DESTINO):
        shutil.rmtree(DESTINO)
    os.makedirs(DESTINO)
    for i, a in enumerate(sec):
        Image.fromarray(a, 'RGBA').save(os.path.join(DESTINO, 'c_%02d.png' % (i + 1)))
    print(len(sec), 'fotogramas (%.2f s a 60 fps) en %s' % (len(sec) / 60, DESTINO))
    # comprobaciones
    fin = np.asarray(Image.open(os.path.join(DESTINO, 'c_%02d.png' % len(sec))))
    print('el ultimo es el reposo espejado:', bool((fin == espejo(rep)).all()))

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
    reves. El frente cae entre c_052 y c_053: tras c_052 viene su espejo, que
    hace de c_053, sin repetir ninguno. CORTE DIRECTO, sin fundido.
  - El primero ES el reposo (fundido de N_INI desde el: los dos estan quietos y
    casan en silueta) y el ultimo, por el espejo, el reposo espejado, que es lo
    que pone magnus.gd al voltear.
  - Colocacion: dy fijo (el del encaje con el reposo); dx del encaje con el
    reposo en c_007 a 0 en el frente, con rampa suave.
  - Tono de la tunica: el estandar (igualar_tono.py), medido en c_007-c_009.
  - Restos del croma (quitar_verde()): ningun pixel con mas verde que rojo y que
    azul (huecos entre brazo y cuerpo) y, en el borde, ninguno con menos verde
    que los dos (el filo morado de la capucha, que con el espejo salia doble).

Medido en el video: la tunica deja de girar en c_050 (de ahi a c_055 el cuerpo
solo se balancea a la derecha: la tela 0,6 px y la cabeza 1,6 px por fotograma)
y cabeza y cuerpo miran de frente hacia c_052-053; a mitad del giro la cabeza va
unos 5 fotogramas por delante del cuerpo. Para que en el corte no cambie nada,
el fotograma del frente tiene que ser su espejo movido lo que avanza cada parte
en un fotograma, y no lo era: la tunica tiene otro dibujo de paneles a cada
lado, el video esta iluminado desde la derecha (la mitad derecha un 20 % mas
clara, hasta un 40 % en los costados), la capucha deja ver mas sombra por dentro
a un lado, la barba y las cejas no son iguales y el pie derecho es mas grande y
mas claro. Ademas el centro del DIBUJO del pecho (la V de las solapas, el borde
del peto) esta, de frente, 7 px a la izquierda del centro de la silueta, y la
barba cuelga ladeada hacia alli. Los fundidos para taparlo se veian como "un
blur raro"; con el sastre a una costura que no era el centro del dibujo, las
solapas "no encajaban", "un pegote" (una V doble y una tira naranja junto a la
barba). Ahora, en este orden:

  1. DIBUJO CORRIDO (desplazar_dibujo()): de DE_FRENTE al frente, el dibujo de
     la TELA se corre poco a poco (hasta 7 px en el centro del cuerpo, menos
     hacia los bordes, como un leve giro sobre el cilindro) para que su centro
     caiga en el eje; la silueta, la cabeza y las manos no se mueven.
  2. CABEZA (con la barba) simetrica, ANTES del sastre (ver 4 y 5): asi, de
     frente, la barba ya cuelga recta en su sitio y lo que el sastre pinta a
     su lado casa con lo del otro lado. Sus campos se miden en el frente con un
     sastre previo (la tela de alrededor ya simetrica: el flujo no se lia).
  3. TUNICA "de sastre" (cuerpo()): el costado de detras (a la derecha de la
     costura, el izquierdo del personaje) se pinta SIEMPRE con el de delante
     espejado sobre un cilindro por fila: cada punto toma el color de su
     simetrico en la superficie del cuerpo. La costura es la linea del centro
     del DIBUJO, SEGUIDA con el flujo optico de la tela desde el frente hacia
     atras y POR ALTURAS (seguir_costura()): el cuerpo va torcido (a mitad del
     giro las solapas ya miran de frente y la falda aun gira); hasta TORSION,
     todas con la falda. Desde los hombros, sin cabeza (capucha, barba y la
     piel que viene de la cara) ni manos (con su lado en sombra:
     mano_entera()). Donde el simetrico cae debajo de la cabeza, tela del
     costado de delante rellenada (tela_rellena(), inpaint); dejar ahi la tela
     del video dejaba tiras de otro dibujo. Cerca del frente el centro del
     cilindro va a la costura: espejo puro (si no, las mangas saltaban).
  4. CABEZA, PIES Y MANGAS, FORMA Y LUZ (simetrizar(), ganancia_luz()): en el
     frente un campo de ganancia suave iguala su luz con la de su espejo y, con
     la luz ya igualada, el flujo optico hasta su espejo los lleva al punto
     medio moviendo pixeles (iterado). Hacia atras (SIMETRIA -> frente) los
     campos se llevan con el flujo del video a donde esta cada parte en cada
     fotograma y entran poco a poco. (Pies y mangas, despues del sastre.)
  5. CABEZA, PIES Y MANGAS, DIBUJO FINO (mitad_espejada()): lo que mover
     pixeles no iguala sin deformar (las facetas de la barba, las cejas, el
     contorno fino; forzarlo con flujo fino dejaba la barba "liquida"): su lado
     derecho va, desde DETALLE y con la diferencia pegada a la parte, al
     izquierdo espejado. Cada parte respecto a su eje en el corte: medio paso
     de los suyos antes del de la casilla (la cabeza a 0,8 px: centrada se
     pararia un fotograma, en su sitio saltaba 4 px). Las MANOS no se tocan:
     llevarlas a su espejo les ponia una manopla marron y dedos fantasma; las
     del video son limpias y en el corte cambian 1,7 veces su movimiento normal.

Medido (cambio en el corte / el de un fotograma normal, por zonas): cabeza 3,5 /
5,2, hombros 3,4 / 5,1, tronco 1,4 / 2,4, mangas 1,5 / 4,7, pies 0,0 / 0,7
(quietos), manos 10,4 / 6,3 (las del video, sin tocar). Antes: cabeza 9,1 /
7,2, pies 3,7 / 0,5, y el tronco se paraba en el corte.

    python espejo.py   (luego hoja.ps1 -Job magnus_giro_frente -Desde 04_espejo)"""
import os, shutil, sys
import cv2
import numpy as np
from PIL import Image, ImageOps
from scipy import ndimage

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(AQUI))
import igualar_tono as tono

ORIGEN = os.path.join(AQUI, '_antes_de_alinear')      # recortado, sin fondo, pulido; sin mover ni tono
DESTINO = os.path.join(AQUI, '04_espejo')
REPOSO = os.path.join(AQUI, '..', 'magnus_respirando', '04_limpios', 'c_01.png')
DESDE, FRENTE = 7, 52      # primera mitad c_007 .. c_052; el frente, entre c_052 y c_053
N_INI = 5                  # fundido desde el reposo al empezar (y, por el espejo, al acabar)
EJE = 291.5                # eje de simetria de frente (centro de la casilla)
Y_HOMBROS = 150            # por encima, todo es cabeza; por debajo, tunica (menos capucha y barba)
DE_FRENTE = 40             # desde aqui el centro del cilindro de la tunica va a la costura
SIMETRIA = 38              # desde aqui cabeza y pies van poco a poco a su forma y luz simetricas
DETALLE = 44               # y desde aqui, su dibujo fino (ya casi de frente)


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


def espejo_en(x, eje):
    """Espejo respecto a la columna eje (con subpixel)."""
    h, W = x.shape[:2]
    mx = (2 * float(eje) - np.arange(W, dtype=np.float32))[None, :].repeat(h, 0).astype(np.float32)
    my = np.arange(h, dtype=np.float32)[:, None].repeat(W, 1)
    return cv2.remap(x, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)


def fundir(a, b, t):
    """Mezcla RGBA con alfa premultiplicado (sin halos en los bordes)."""
    a = a.astype(float); b = b.astype(float)
    pa, pb = a[..., :3] * a[..., 3:] / 255, b[..., :3] * b[..., 3:] / 255
    al = a[..., 3:] + (b[..., 3:] - a[..., 3:]) * t
    rgb = (pa + (pb - pa) * t) * 255 / np.maximum(al, 1e-6)
    return np.dstack([rgb, al]).clip(0, 255).round().astype(np.uint8)


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
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def quitar_verde(a):
    """Restos del croma: ningun pixel con mas verde que rojo y que azul (sobre
    todo en los huecos entre brazo y cuerpo, con alfa a medias), ni verde
    oliva en las sombras de las manos y, en el borde de la silueta, ninguno con
    menos verde que los dos (el filo morado que dejo el quitar el verde, en la
    capucha; con el espejo salia a los dos lados)."""
    out = a.copy()
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    # en lo poco saturado (sombras de las manos, huecos) el verde no pasa de la
    # media de rojo y azul: el oliva de las sombras entre los dedos queda marron;
    # los ocres y tostados de la tunica (muy saturados) no se tocan
    sat = np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)
    tope = np.where(sat < 60, (r + b) // 2, np.maximum(r, b))
    out[..., 1] = np.minimum(g, np.maximum(tope, 0)).astype(np.uint8)
    borde = ndimage.binary_dilation(a[..., 3] < 200, iterations=2) & (a[..., 3] > 0)
    out[..., 1] = np.where(borde, np.maximum(out[..., 1], np.minimum(r, b)), out[..., 1])
    return out


def manos(a):
    """Las manos: piel rojiza con el verde cerca del azul (g-b ~14) y bastante
    azul (~114); los paneles ocres claros tienen g-b ~28 y azul ~82. Solo abajo
    (y > 375): arriba saltaban pixeles sueltos de los paneles iluminados."""
    op = a[..., 3] > 128
    r, g, b = [a[..., i].astype(int) for i in range(3)]
    piel = op & (r > 140) & (b > 90) & (g - b < 22) & (r - g > 18)
    piel[:375] = False
    piel = ndimage.binary_opening(piel, iterations=1)
    lab, n = ndimage.label(piel)
    if n:
        tam = ndimage.sum(piel, lab, range(1, n + 1))
        piel = np.isin(lab, np.where(tam >= 40)[0] + 1)
    # y, pegado a esas manos, su lado en sombra y los dedos sueltos (tostado,
    # g-b ~24, r ~150, azul ~100: suelto por la tunica daria falsos positivos)
    tenue = op & (r > 120) & (b > 88) & (g - b < 28) & (r - g > 15)
    piel |= tenue & ndimage.binary_dilation(piel, iterations=15)
    return ndimage.binary_dilation(piel, iterations=3)


def mano_entera(a):
    """La mano con su lado en sombra (que no pasa por piel y el sastre pintaba de
    tunica, una rayita oscura): el contorno convexo de cada mano, con margen."""
    m = manos(a)
    lab, n = ndimage.label(ndimage.binary_dilation(m, iterations=2))
    out = np.zeros(m.shape, np.uint8)
    for i in range(1, n + 1):
        ys, xs = np.where(lab == i)
        if len(xs) >= 3:
            cv2.fillConvexPoly(out, cv2.convexHull(np.stack([xs, ys], 1).astype(np.int32)), 1)
    return out.astype(bool) | m


def barba(a):
    op = a[..., 3] > 128
    return ndimage.binary_dilation((a[..., :3].min(-1) > 160) & op, iterations=4)


def piel(a):
    """Piel (cara, cuello, manos): rojiza con bastante azul; los paneles marrones
    tienen poco azul y los ocres el verde lejos del azul."""
    r, g, b = [a[..., i].astype(int) for i in range(3)]
    return (a[..., 3] > 128) & (r > 120) & (b > 90) & (g - b < 22) & (r - g > 15)


def capucha(a):
    """La cabeza por debajo de Y_HOMBROS: capucha (gris frio), su sombra por
    dentro (oscura y no rojiza), la barba y la piel del cuello, lo que esta
    unido a la cabeza."""
    op = a[..., 3] > 128
    x = a[..., :3].astype(int)
    r, b = x[..., 0], x[..., 2]
    sat = x.max(-1) - x.min(-1)
    gris = (sat < 40) & (b >= r - 8)
    oscuro = (x.mean(-1) < 75) & (r - b < 15)
    # la piel solo si viene de la cara (los paneles tostados del hombro dan el
    # mismo color: pegados a la cabeza quedaban sin coser, una L naranja)
    pc = piel(a)
    pc[270:] = False
    lab, n = ndimage.label(pc)
    if n:
        pc = np.isin(lab, np.unique(lab[:Y_HOMBROS])[1:])
    cand = op & (gris | oscuro | barba(a) | pc)
    cand[:Y_HOMBROS] |= op[:Y_HOMBROS]
    cand[270:] = False
    lab, n = ndimage.label(cand)
    if not n:
        return cand
    arriba = np.unique(lab[:Y_HOMBROS])
    return np.isin(lab, arriba[arriba > 0])


def brazos(a):
    """Mangas: lo que cuelga a los lados del tronco (de frente), sin las manos
    (a las manos, llevarlas a su espejo les ponia una manopla marron y dedos
    fantasma; las del video son limpias y ya se parecen)."""
    op = a[..., 3] > 128
    z = np.zeros_like(op)
    fuera_tronco = np.abs(np.arange(a.shape[1]) - EJE)[None, :] > 72
    z[280:400] = (op & fuera_tronco)[280:400]
    return z & ~ndimage.binary_dilation(manos(a), iterations=8)


def pies(a):
    """Piernas y pies: lo que queda por debajo del bajo de la tunica."""
    op = a[..., 3] > 128
    ancho = op.sum(1)
    bajo = np.where(ancho > 120)[0][-1]
    z = np.zeros_like(op)
    z[bajo + 3:] = op[bajo + 3:]
    return z


def zona_suave(m, sigma=3):
    z = ndimage.binary_dilation(m, iterations=2).astype(np.float32)
    return np.clip(cv2.GaussianBlur(z, (0, 0), sigma) * 1.5, 0, 1)


def eje_de(m):
    """Columna que mejor deja la mascara igual a su espejo."""
    f = m.astype(np.float32)
    return min((float(np.abs(espejo_en(f, e) - f).sum()), e)
               for e in np.arange(EJE - 12, EJE + 12.01, 0.25))[1]


def extremos(a, y0):
    """Bordes izquierdo y derecho de la silueta por fila, suavizados en vertical:
    siguen la forma grande (la tunica se abre abajo), sin dientes de una fila a
    otra por los brazos y los huecos entre brazo y cuerpo."""
    op = a[..., 3] > 128
    h = a.shape[0]
    xl = np.full(h, np.nan); xr = np.full(h, np.nan)
    for y in range(y0, h):
        c = np.where(op[y])[0]
        if len(c) > 8:
            xl[y], xr[y] = c[0], c[-1]
    ok = ~np.isnan(xl)
    yy = np.arange(h)
    xl = np.interp(yy, yy[ok], xl[ok]); xr = np.interp(yy, yy[ok], xr[ok])
    xl = ndimage.gaussian_filter1d(ndimage.minimum_filter1d(xl, 31), 12)
    xr = ndimage.gaussian_filter1d(ndimage.maximum_filter1d(xr, 31), 12)
    return xl, xr


def gris(x):
    al = x[..., 3:4].astype(np.float32) / 255
    return cv2.cvtColor((x[..., :3] * al + 30 * (1 - al)).astype(np.uint8), cv2.COLOR_RGB2GRAY)


def flujo(a, b):
    """Flujo optico de a a b: a(x) ~ b(x + f(x))."""
    dis = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
    return dis.calc(gris(a), gris(b), None)


def velocidad(zona_de, *fotos):
    """Velocidad horizontal (px por fotograma) de una zona: mediana del flujo,
    media de los pasos entre las fotos dadas."""
    vs = []
    for p, q in zip(fotos[:-1], fotos[1:]):
        vs.append(float(np.median(flujo(p, q)[..., 0][zona_de(p)])))
    return float(np.mean(vs))


def zona_tronco(a):
    z = (a[..., 3] > 200) & ~manos(a) & ~barba(a)
    z[:320] = False; z[600:] = False
    z[:, :int(EJE) - 30] = False; z[:, int(EJE) + 30:] = False
    return z


def zona_cara(a):
    z = capucha(a) & (a[..., 3] > 200)
    z[:60] = False; z[150:] = False
    return z


def eje_dibujo(a):
    """Centro del dibujo del pecho (las solapas, la punta de su V): el eje que
    deja simetricas las LINEAS de los paneles (los colores no lo son: gris a un
    lado del peto, rosado al otro)."""
    L = cv2.GaussianBlur(cv2.cvtColor(a[..., :3], cv2.COLOR_RGB2GRAY).astype(np.float32), (0, 0), 1.2)
    G = np.hypot(cv2.Sobel(L, cv2.CV_32F, 1, 0), cv2.Sobel(L, cv2.CV_32F, 0, 1))
    malo = ndimage.binary_dilation(capucha(a) | manos(a) | (a[..., 3] < 220), iterations=3)
    G[malo] = 0
    mejor = None
    for e in np.arange(EJE - 25, EJE + 15.01, 0.25):
        m = espejo_en(G, e)
        ok = (espejo_en((~malo).astype(np.float32), e) > 0.5) & ~malo
        ok[:250] = False; ok[330:] = False
        ok[:, :int(e) - 35] = False; ok[:, int(e) + 35:] = False
        p = (np.minimum(m, G) * ok).sum() / ((np.maximum(m, G) * ok).sum() + 1e-6)
        if mejor is None or p > mejor[0]:
            mejor = (p, float(e))
    return mejor[1]


FRANJAS = ((250, 330), (330, 430), (430, 530), (530, 640))   # solapas, peto, falda, bajo
TORSION = 30               # desde aqui cada altura lleva su costura (antes, la de la falda)


def seguir_costura(C, ks, frente):
    """La linea del centro del dibujo en cada fotograma, POR ALTURAS: en el
    frente, la dada; hacia atras, donde estaba cada trozo de esa linea segun el
    flujo de la tela a su altura. El cuerpo va torcido: a mitad del giro las
    solapas ya miran de frente (su V apenas se mueve de c_040 a c_052) y la
    falda sigue girando; con una sola costura vertical seguida por la falda,
    arriba quedaba 10 px desviada (V doble y parche junto a la barba).
    Devuelve, por fotograma, la costura de cada fila."""
    s = {ks[-1]: [frente] * len(FRANJAS)}
    for k in ks[-2::-1]:
        a, b = C[k + 1], C[k]
        f = flujo(a, b)                       # de k+1 a k
        ok = (a[..., 3] > 200) & ~mano_entera(a) & ~capucha(a)
        vs = []
        for (y0, y1), x in zip(FRANJAS, s[k + 1]):
            xi = int(round(x))
            filas = [y for y in range(y0, y1) if 2 <= xi < a.shape[1] - 2 and ok[y, xi]]
            vs.append(float(np.median([f[y, xi - 2:xi + 3, 0].mean() for y in filas])) if len(filas) > 10 else None)
        # una franja sin tela a la vista (de perfil la barba tapa las solapas)
        # va con la de debajo: si no, se quedaba parada dentro del perfil
        for i in range(len(vs) - 2, -1, -1):
            if vs[i] is None:
                vs[i] = vs[i + 1]
        s[k] = [x + (v or 0.0) for x, v in zip(s[k + 1], vs)]
    # al principio (de perfil) aun no hay torsion: las solapas, tapadas por la
    # barba, se quedaban paradas dentro del perfil y el sastre lo cambiaba (el
    # perfil gustaba como estaba). Hasta TORSION todas las alturas van con la
    # falda, con una rampa suave hasta ahi (en c_027 las franjas ya casi coinciden)
    for k in ks:
        t = suave((k - (TORSION - 6)) / 6)
        falda = s[k][2]
        s[k] = [falda + (x - falda) * t for x in s[k]]
    h = C[ks[-1]].shape[0]
    centros = [(y0 + y1) / 2 for y0, y1 in FRANJAS]
    return {k: ndimage.gaussian_filter1d(np.interp(np.arange(h), centros, v), 20) for k, v in s.items()}


def desplazar_dibujo(a, d, xl, xr):
    """Corre el dibujo de la tunica d px a la derecha en el centro del cuerpo y
    menos hacia los bordes (como un leve giro sobre el cilindro), sin mover la
    silueta, la cabeza ni las manos. En el video, de frente, el centro del
    dibujo esta 7 px a la izquierda del de la silueta: asi llega al eje."""
    if abs(d) < 0.01:
        return a
    h, W = a.shape[:2]
    c = (xl + xr) / 2
    R = np.maximum((xr - xl) / 2, 10)
    xx = np.arange(W, dtype=np.float32)[None, :].repeat(h, 0)
    yy = np.arange(h, dtype=np.float32)[:, None].repeat(W, 1)
    s = (d * np.cos(np.arcsin(np.clip((xx - c[:, None]) / R[:, None], -1, 1)))).astype(np.float32)
    # solo la tela: la cabeza (con la barba) y las manos se quedan; a la barba la
    # lleva luego a su sitio la simetria de la cabeza. (Corrida aqui con la tela,
    # entre la barba movida y lo de la cabeza que no se movia se abrian rajas,
    # rellenas de mechones sueltos.) Lo que asoma de debajo de la cabeza al
    # correrse, tela rellenada.
    tela = (a[..., 3] > 200) & ~mano_entera(a) & ~capucha(a)
    movido = cv2.remap(tela_rellena(a, tela), xx - s, yy, cv2.INTER_LINEAR,
                       borderMode=cv2.BORDER_REPLICATE)
    out = a.astype(np.float32).copy()
    out[..., :3] = np.where(tela[..., None], movido, out[..., :3])
    return out.round().clip(0, 255).astype(np.uint8)


def tela_rellena(a, valido):
    """Los colores de la tela con lo demas rellenado: fuera de la silueta, con el
    pixel valido mas cercano; dentro (debajo de la cabeza y de las manos), con
    inpaint, que sigue la tela de alrededor sin las rayas del pixel mas cercano."""
    _, (iy, ix) = ndimage.distance_transform_edt(~valido, return_indices=True)
    base = np.ascontiguousarray(a[iy, ix, :3])
    hueco = (~valido & (a[..., 3] > 0)).astype(np.uint8)
    return cv2.inpaint(base, hueco, 5, cv2.INPAINT_TELEA).astype(np.float32)


def cuerpo(a, costura, xl, xr, de_frente):
    """La tunica simetrica: a la derecha de la costura, el costado de delante
    espejado sobre un cilindro por fila (radio de la silueta de esa fila; centro
    el de la silueta y, hacia el frente, la costura: de frente la linea del
    pecho esta en el eje del cuerpo). Un punto del costado de detras a un angulo
    t de la costura toma el color del de delante a -t; de frente, es un espejo
    puro respecto a la costura (con el centro de la silueta, que los brazos
    tuercen, las mangas no casaban con su espejo y saltaban en el corte)."""
    h, W = a.shape[:2]
    costura = np.broadcast_to(np.asarray(costura, dtype=float), (h,))     # una por fila
    c = (xl + xr) / 2 * (1 - de_frente) + costura * de_frente
    radio = np.maximum((xr - xl) / 2, 10)
    phi = np.arcsin(np.clip((costura - c) / radio, -0.98, 0.98))
    xx = np.arange(W, dtype=np.float32)[None, :].repeat(h, 0)
    yy = np.arange(h, dtype=np.float32)[:, None].repeat(W, 1)
    th = np.arcsin(np.clip((xx - c[:, None]) / radio[:, None], -1, 1))
    xs = c[:, None] + radio[:, None] * np.sin(np.clip(2 * phi[:, None] - th, -np.pi / 2, np.pi / 2))
    mapx = np.where(xx > costura[:, None], xs, xx).astype(np.float32)
    cab = capucha(a)
    fuera = mano_entera(a) | cab
    # fuente: los colores de la tunica, sin borde de la silueta, sin cabeza ni
    # manos (lo verdoso ya lo quito quitar_verde); debajo de la cabeza y de las
    # manos, tela rellenada (tela_rellena)
    valido = (a[..., 3] > 200) & ~fuera
    valido = ndimage.binary_erosion(valido, iterations=2)
    valido[:Y_HOMBROS] = False
    # (solo se copia del costado de delante: rellenando debajo de la barba con
    # los dos costados entraba el color del de detras, una mancha con brillo)
    delante = valido & (xx <= costura[:, None])
    espejado = cv2.remap(tela_rellena(a, delante), mapx, yy, cv2.INTER_LINEAR,
                         borderMode=cv2.BORDER_REPLICATE)
    # Donde el simetrico cae debajo de la cabeza (de tres cuartos, junto a la
    # barba) se pinta con esa tela rellenada: dejar ahi la tela del video (antes)
    # dejaba tiras de otro dibujo junto a lo pintado (una tira naranja junto a
    # la barba, "un pegote"); con el pixel mas cercano salian rayas. Ni en lo
    # semitransparente (sombras del hueco entre mano y tunica, bordes)
    m = (np.clip((xx - costura[:, None]) / 3 + 0.5, 0, 1) * ~fuera * np.clip((yy - Y_HOMBROS) / 5, 0, 1)
         * np.clip((a[..., 3].astype(np.float32) - 200) / 40, 0, 1))
    out = a.astype(np.float32).copy()
    out[..., :3] = out[..., :3] * (1 - m[..., None]) + espejado * m[..., None]
    return out.round().clip(0, 255).astype(np.uint8)


def luminancia(x):
    return 0.299 * x[..., 0] + 0.587 * x[..., 1] + 0.114 * x[..., 2]


def ganancia_luz(frente, zona, eje, sigma=14):
    """Campo de ganancia suave que deja la luz de la zona igual a la de su espejo
    respecto a eje: la media de las dos, a escala grande (sin tocar el detalle)."""
    a = frente.astype(np.float32)
    al = a[..., 3] / 255
    w = cv2.GaussianBlur(al, (0, 0), sigma) + 1e-3
    lb = (cv2.GaussianBlur(luminancia(a) * al, (0, 0), sigma) / w).astype(np.float32)
    g = np.where(al > 0.05, 0.5 * (lb + espejo_en(lb, eje)) / np.maximum(lb, 1), 1.0)
    return 1 + (np.clip(g, 0.6, 1.6) - 1) * zona


def con_ganancia(a, g, r):
    out = a.astype(np.float32).copy()
    out[..., :3] = np.clip(out[..., :3] * (1 + (g - 1) * r)[..., None], 0, 255)
    return out.round().astype(np.uint8)


def deformar(a, d):
    """Mueve los pixeles (sale(x) = entra(x - d(x))), sin mezclar imagenes."""
    h, W = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:W].astype(np.float32)
    return cv2.remap(a, xx - d[..., 0], yy - d[..., 1], cv2.INTER_LINEAR, borderValue=0)


def simetrizar(frente, zona, eje, pasadas=4):
    """Desplazamiento d (como en deformar) que lleva la zona al punto medio con su
    espejo respecto a eje: la mitad del flujo hasta el espejo, suavizado; cada
    pasada deja la mitad de diferencia."""
    h, W = frente.shape[:2]
    yy, xx = np.mgrid[0:h, 0:W].astype(np.float32)
    mx, my = xx.copy(), yy.copy()
    w = frente
    for _ in range(pasadas):
        f = cv2.GaussianBlur(flujo(w, espejo_en(w, eje)), (0, 0), 3) * zona[..., None] * 0.5
        mx = cv2.remap(mx, xx - f[..., 0], yy - f[..., 1], cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
        my = cv2.remap(my, xx - f[..., 0], yy - f[..., 1], cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
        w = cv2.remap(frente, mx, my, cv2.INTER_LINEAR, borderValue=0)
    return np.dstack([xx - mx, yy - my])


def llevar(campo, P, fuera):
    """Un campo del frente visto desde otro fotograma (P: donde cae cada pixel
    de ese fotograma en el frente)."""
    return cv2.remap(campo, P[..., 0], P[..., 1], cv2.INTER_LINEAR,
                     borderMode=cv2.BORDER_CONSTANT, borderValue=fuera)


def premult(a):
    a = a.astype(np.float32)
    return np.dstack([a[..., :3] * a[..., 3:] / 255, a[..., 3:]])


def despremult(p):
    al = np.clip(p[..., 3:], 0, 255)
    rgb = np.clip(p[..., :3] * 255 / np.maximum(al, 1e-3), 0, 255)
    return np.dstack([rgb, al]).round().astype(np.uint8)


def mitad_espejada(a, m, eje):
    """a con la parte de la mascara (y de su espejo) a la derecha del eje
    sustituida por la de la izquierda espejada; borde suave."""
    h, W = a.shape[:2]
    u = m | (espejo_en(m.astype(np.uint8), eje) > 0)
    u = ndimage.binary_dilation(u, iterations=3).astype(np.float32)
    u = cv2.GaussianBlur(u, (0, 0), 1.5) * (np.arange(W)[None, :] > eje)
    pa, pm_ = premult(a), premult(espejo_en(a, eje))
    return despremult(pa + (pm_ - pa) * u[..., None])


if __name__ == '__main__':
    rep = np.asarray(Image.open(REPOSO).convert('RGBA'))
    dx0, dy = encaje(leer(DESDE), rep)
    print('encaje de c_%03d con el reposo: dx %d dy %d' % (DESDE, dx0, dy))

    def dx_de(k):
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

    def colocado(k):
        im = mover(leer(k), dx_de(k), dy).astype(float) / 255
        return quitar_verde((tono.aplicar(im, g) * 255).round().astype(np.uint8))

    ks = list(range(DESDE, FRENTE + 1))
    C = {k: colocado(k) for k in ks}
    # en el corte, cada parte tiene que avanzar lo que avanza sola en el video
    # (la tela del pecho ~0,6 px, la cabeza ~1,6 px por fotograma, hacia la
    # derecha: se balancea): su eje en el frente, medio paso antes del de la casilla
    tras = colocado(FRENTE + 1)
    v_tela = velocidad(zona_tronco, C[FRENTE - 1], C[FRENTE], tras)
    v_cara = velocidad(zona_cara, C[FRENTE - 1], C[FRENTE], tras)
    print('velocidad en el frente: tela %.2f px, cabeza %.2f px por fotograma' % (v_tela, v_cara))

    # 1. el dibujo de la tela se corre poco a poco (de DE_FRENTE al frente) hasta
    #    que su centro cae medio paso antes del eje; la costura del sastre, seguida
    #    con la tela por alturas desde ese centro, se corre con el
    centro = eje_dibujo(C[FRENTE])
    corre = (EJE - v_tela / 2) - centro
    print('centro del dibujo en el frente %.2f: se corre %.2f px' % (centro, corre))
    costura = seguir_costura(C, ks, centro)
    ext = {k: extremos(C[k], Y_HOMBROS) for k in ks}
    XLR, B, RF = {}, {}, {}
    for k in ks:
        vec = [j for j in range(k - 2, k + 3) if j in ext]      # cilindro suavizado en el tiempo
        xl, xr = np.mean([ext[j][0] for j in vec], 0), np.mean([ext[j][1] for j in vec], 0)
        XLR[k] = (xl, xr)
        RF[k] = suave((k - DE_FRENTE) / (FRENTE - DE_FRENTE))
        B[k] = desplazar_dibujo(C[k], corre * RF[k], xl, xr)
        cos_c = np.cos(np.arcsin(np.clip((costura[k] - (xl + xr) / 2) / np.maximum((xr - xl) / 2, 10), -1, 1)))
        costura[k] = costura[k] + corre * RF[k] * cos_c
    print('costura (solapas / falda): ' + ' '.join('%d:%.0f/%.0f' % (k, costura[k][290], costura[k][585])
                                                   for k in ks[::5] + [FRENTE]))

    # hacia atras, los campos medidos en el frente van con cada parte (flujo del
    # video encadenado: P[k] = donde cae en el frente cada pixel del fotograma k)
    h, W = C[FRENTE].shape[:2]
    yy, xx = np.mgrid[0:h, 0:W].astype(np.float32)
    P = {FRENTE: np.dstack([xx, yy])}
    for k in range(FRENTE - 1, SIMETRIA - 1, -1):
        f = flujo(C[k], C[k + 1])
        P[k] = cv2.remap(P[k + 1], xx + f[..., 0], yy + f[..., 1], cv2.INTER_LINEAR,
                         borderMode=cv2.BORDER_REPLICATE)

    def campos(F, partes):
        """Luz (gl), forma (D) y dibujo fino (R) simetricos de unas partes del
        frente, cada una respecto a su eje."""
        gl = 1 + sum(ganancia_luz(F, z, e) - 1 for _, e, z in partes)
        G = con_ganancia(F, gl, 1.0)
        D = sum(simetrizar(G, z, e) for _, e, z in partes)
        Wf = deformar(G, D)
        T = Wf
        for m, e, _ in partes:
            T = mitad_espejada(T, m, e)
        return gl, D, premult(T) - premult(Wf)

    def aplicar(X, gl, D, R):
        for k in ks:
            r = suave((k - SIMETRIA) / (FRENTE - SIMETRIA))
            if r > 0:
                X[k] = deformar(con_ganancia(X[k], llevar(gl, P[k], 1.0), r), llevar(D, P[k], 0.0) * r)
            w = suave((k - DETALLE) / (FRENTE - DETALLE))
            if w > 0:
                X[k] = despremult(premult(X[k]) + llevar(R, P[k], 0.0) * w)

    def partes_de(lista):
        return [(m, eje_de(m) if e is None else e, zona_suave(m)) for m, e in lista]

    # 2. la CABEZA (con la barba) simetrica ANTES del sastre: asi, de frente, la
    #    barba esta ya en su sitio y lo que el sastre pinta a su lado casa con lo
    #    del otro lado. Los campos se miden en el frente con un sastre previo (la
    #    tela de alrededor ya simetrica: el flujo no se lia con ella).
    F0 = cuerpo(B[FRENTE], costura[FRENTE], *XLR[FRENTE], 1.0)
    cabeza = partes_de([(capucha(F0), EJE - v_cara / 2)])      # va con su balanceo
    print('eje de la cabeza en el frente %.2f (casilla %.1f)' % (cabeza[0][1], EJE))
    aplicar(B, *campos(F0, cabeza))

    # 3. tunica de sastre
    X = {k: cuerpo(B[k], costura[k], *XLR[k], RF[k]) for k in ks}

    # 4. pies y mangas, medidos en el frente ya cosido
    F = X[FRENTE]
    resto = partes_de([(pies(F), None),                                        # quietos
                       (brazos(F), float(np.median(costura[FRENTE][280:400])))])  # con la tela
    print('ejes en el frente: pies %.2f, mangas %.2f' % (resto[0][1], resto[1][1]))
    aplicar(X, *campos(F, resto))

    if os.environ.get('ESPEJO_DEPURAR'):     # ruta .npz: guarda los pasos del final del giro
        np.savez_compressed(os.environ['ESPEJO_DEPURAR'], **{'B%d' % k: B[k] for k in ks if k >= 36},
                            **{'X%d' % k: X[k] for k in ks if k >= 36})

    # primera mitad, con el fundido desde el reposo; luego su espejo al reves
    H = []
    for i, k in enumerate(ks):
        a = X[k]
        if i < N_INI:
            a = fundir(a, rep, suave(1 - i / N_INI))
        H.append(a)
    sec = H + [espejo(a) for a in H[::-1]]
    if os.path.isdir(DESTINO):
        shutil.rmtree(DESTINO)
    os.makedirs(DESTINO)
    for i, a in enumerate(sec):
        Image.fromarray(a, 'RGBA').save(os.path.join(DESTINO, 'c_%02d.png' % (i + 1)))
    print(len(sec), 'fotogramas (%.2f s a 60 fps) en %s' % (len(sec) / 60, DESTINO))

    # comprobacion: cuanto cambia cada fotograma (en pasos normales), por zonas en el corte
    def pm(x):
        x = x.astype(np.float32)
        return x[..., :3] * x[..., 3:] / 255
    d = np.array([np.abs(pm(sec[i + 1]) - pm(sec[i])).mean() for i in range(len(sec) - 1)])
    med = np.median(d)
    print('cambio por fotograma: maximo %.2f pasos (en %d); en el corte del frente %.2f'
          % (d.max() / med, d.argmax() + 1, d[len(H) - 1] / med))
    zonas = {'cabeza': (30, 150, 200, 390), 'hombros': (150, 300, 150, 435),
             'tronco': (300, 620, 215, 368), 'mangas': (280, 405, 120, 460),
             'manos': (405, 500, 140, 445), 'pies': (625, 700, 200, 390)}
    for nombre, (y0, y1, x0, x1) in zonas.items():
        z = [np.abs(pm(sec[i + 1]) - pm(sec[i]))[y0:y1, x0:x1].mean() for i in range(len(H) - 4, len(H) + 3)]
        print('  %-8s' % nombre + ' '.join('%5.2f' % v for v in z) + '   (el corte es el cuarto)')

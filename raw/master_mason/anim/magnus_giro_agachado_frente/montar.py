"""Giro agachado POR DELANTE: del perfil al frente del video y su espejo.

Fuente: el mismo video que magnus_giro_agachado_video (Wizard_turning_in_place,
Flow), su primera mitad: 1-31 quieto de perfil (el 1 es la referencia, el
agachado del juego), 31-70 gira hacia la camara hasta el frente. El usuario
pidio girar como el video del giro de pie (_fuentes/Wizard_rotating_on_green_
background_20261005182314.mp4): siempre hacia la camara, mas pausado, y sin los
saltitos del giro por detras (alli los pies dan pasitos de 6 px).
Sprites: el agachado del juego, 29 fotogramas del video entre el 28 y el 70
elegidos a paso visual constante (ver abajo), los mismos espejados de vuelta y
el agachado espejado: 59 a 60 fps, 1 s. De tres en tres fijo (31 a 30 fps) el
paso iba de 0,3 al principio a 0,8 al pasar por delante: se veia a tirones.
El espejo va contra el centro de la casilla (flip_h): en el frente (69-70) el
sprite y su espejo se parecen a 0,73, menos que lo que cambia cada paso ahi (de
tres en tres), asi que el empalme no se ve.
HUNDIMIENTO: la IA lo hunde mientras se prepara: el alto pasa de 485 (el 1, igual
que el agachado del juego) a 473 en el 25, y ya no lo recupera. Si se dejara, la
cabeza bajaria 6 px de pantalla al empezar a girar y subiria al acabar (el click
que el usuario no quiere). Se escala cada sprite sobre los pies por 485 / alto
suavizado hasta el fotograma 40 (donde aun no gira); de ahi en adelante se
mantiene la del 40. Casi de frente la capucha sube unos px: es geometria, no
hundimiento, y no se toca.
Ademas se mueve lo que mejor encaja el 1 con el agachado del juego, y una ganancia
por zonas (tunica, capucha, pies) de ese mismo encaje (ver
magnus_giro_agachado/igualar_color.py).
Lee de _todos/ (75 sprites, video 1-75, centrados y sin fondo) y escribe 04_limpios/.
    python montar.py
"""
import glob, os, shutil
import numpy as np
from PIL import Image
from scipy import ndimage

AQUI = os.path.dirname(os.path.abspath(__file__))
TODOS = os.path.join(AQUI, '_todos'); SALIDA = os.path.join(AQUI, '04_limpios')
DESDE, HASTA = 28, 70                           # perfil (empieza a girar) .. frente
POR_MITAD = 29                                  # sprites del video en cada mitad
HASTA_ESCALA = 40
ALTO = 485.0
AGACHADO = os.path.join(AQUI, '..', 'magnus_agacharse', '04_limpios', 'c_089.png')
src = open(os.path.join(AQUI, '..', 'magnus_giro_agachado', 'igualar_color.py'), encoding='utf-8').read()
z = {'__file__': os.path.join(AQUI, '..', 'magnus_giro_agachado', 'igualar_color.py')}
exec(src[:src.index('if not os.path.isdir(COPIA)')], z)

if not os.path.isdir(TODOS):
    shutil.copytree(SALIDA, TODOS)


CON_FONDO = os.path.join(AQUI, '_con_fondo', '04_limpios')


def rgba(n):
    """El sprite sin las bolsas de croma que fondo.ps1 no alcanzo.

    fondo.ps1 inunda el verde desde el borde: el que queda encerrado entre
    piernas y brazos (de frente, 41-70: hasta 1200 px de master) se queda,
    despintado a verde azulado. Se busca en el fotograma con fondo (el verde que
    no toca el borde) y se borra, con su orla de 2 px si es verdosa (g > r). Por
    color no se puede: la capucha es gris azulada."""
    im = np.asarray(Image.open(os.path.join(TODOS, 'c_%02d.png' % n)).convert('RGBA')).copy()
    src = np.asarray(Image.open(os.path.join(CON_FONDO, 'c_%02d.png' % n)).convert('RGB')).astype(int)
    r, g, b = src[..., 0], src[..., 1], src[..., 2]
    croma = (g > r + 50) & (g > b + 40)
    lab, _ = ndimage.label(croma)
    borde = set(np.unique(np.r_[lab[0], lab[-1], lab[:, 0], lab[:, -1]])) - {0}
    bolsa = croma & ~np.isin(lab, list(borde))
    orla = ndimage.binary_dilation(bolsa, iterations=2) & ~bolsa & (im[..., 1].astype(int) > im[..., 0])
    im[bolsa | orla] = 0
    return Image.fromarray(im)


def alto(im):
    ys = np.where((np.asarray(im)[..., 3] > 128).any(1))[0]
    return ys.max() - ys.min()


altos = np.array([alto(rgba(n)) for n in range(1, HASTA_ESCALA + 4)], float)
suave = np.convolve(np.r_[[altos[0]] * 3, altos, [altos[-1]] * 3], np.ones(7) / 7, 'valid')


def escala(n):
    k = min(n, HASTA_ESCALA) - 1
    return float(np.clip(ALTO / suave[k], 1.0, 1.04))


def escalar(im, s):
    a = np.asarray(im)[..., 3] > 128
    ys, xs = np.where(a)
    cx, by = (xs.min() + xs.max()) / 2.0, float(ys.max())
    w, h = im.size
    r = im.convert('RGBa').resize((round(w * s), round(h * s)), Image.LANCZOS)
    out = Image.new('RGBa', (w, h), (0, 0, 0, 0))
    out.paste(r, (round(cx - cx * s), round(by - by * s)))
    return np.asarray(out.convert('RGBA')).astype(float) / 255


def mover(a, dx, dy):
    out = np.zeros_like(a); h, w = a.shape[:2]
    out[max(dy, 0):h + min(dy, 0), max(dx, 0):w + min(dx, 0)] = a[max(-dy, 0):h - max(dy, 0), max(-dx, 0):w - max(dx, 0)]
    return out


def pm(a):
    return np.concatenate([a[..., :3] * a[..., 3:], a[..., 3:]], 2)


def d(a, b):
    m = (a[..., 3] > 0) | (b[..., 3] > 0); ys, xs = np.where(m)
    c = (slice(ys.min(), ys.max() + 1), slice(xs.min(), xs.max() + 1))
    return 10 * np.abs(a[c][..., :3] - b[c][..., :3]).mean()


ag = z['leer'](AGACHADO)
uno = escalar(rgba(1), escala(1))
_, DX, DY = min((d(pm(mover(uno, dx, dy)), pm(ag)), dx, dy) for dx in range(-8, 9) for dy in range(-20, 1))
ref = {k: np.mean([z['medias'](z['leer'](f))[k] for f in z['REF']], 0) for k in ('tunica', 'capucha', 'pies')}
m1 = z['medias'](uno)
gan = {k: ref[k] / m1[k] for k in ref}


def sprite(n):
    return mover(z['aplicar'](escalar(rgba(n), escala(n)), gan), DX, DY)


# A paso visual constante: en el video el giro va despacio al principio y deprisa
# al pasar por delante (0,1 frente a 0,5 por fotograma). Se recorre la distancia
# acumulada entre fotogramas seguidos y se coge uno cada vez que se ha andado lo
# mismo: mas seguidos donde gira deprisa, mas espaciados donde va despacio.
cache = {n: sprite(n) for n in range(DESDE, HASTA + 1)}
acum = [0.0]
for n in range(DESDE, HASTA):
    acum.append(acum[-1] + d(pm(cache[n]), pm(cache[n + 1])))
objetivos = np.linspace(0, acum[-1], POR_MITAD)
IDA = []
for o in objetivos:
    n = DESDE + int(np.argmin([abs(a - o) for a in acum]))
    if not IDA or n != IDA[-1]:
        IDA.append(n)
# El frente del video no es simetrico (el 70 y su espejo, a 0,74): empalmar la ida
# con su espejo era el paso mas grande (0,77). En el centro va la media del frente
# y su espejo (premultiplicado): el empalme se reparte en dos pasos pequenos, y a
# 60 fps un solo fotograma de mezcla no se ve.
frente = cache[IDA[-1]]
fp, fm = pm(frente), pm(frente[:, ::-1])
mezcla = (fp + fm) / 2
al = mezcla[..., 3:]
centro = np.concatenate([np.where(al > 0, mezcla[..., :3] / np.maximum(al, 1e-6), 0), al], 2)
VUELTA = IDA[-2::-1]
sprites = [ag] + [cache[n] for n in IDA[:-1]] + [centro] + [cache[n][:, ::-1] for n in VUELTA] + [ag[:, ::-1]]


# Cabeza suave: en el video sube y baja algun pixel suelto de un fotograma a otro
# (hasta 6 px de master). Se lleva la punta de la capucha a una curva suavizada
# escalando cada sprite sobre sus pies (+-1 %): la cabeza no da saltitos y los
# pies no se mueven. El primero y el ultimo (el agachado del juego) no se tocan.
def arriba_abajo(a):
    ys = np.where((a[..., 3] > 0.5).any(1))[0]
    return ys.min(), ys.max()


def a_escala(a, s):
    im = Image.fromarray((np.ascontiguousarray(a) * 255).round().astype(np.uint8))
    return escalar(im, s)


tops = np.array([arriba_abajo(a)[0] for a in sprites], float)
bots = np.array([arriba_abajo(a)[1] for a in sprites], float)
suave_top = tops.copy()
for _ in range(3):
    suave_top[1:-1] = (suave_top[:-2] + 2 * suave_top[1:-1] + suave_top[2:]) / 4
for i in range(1, len(sprites) - 1):
    s_i = (bots[i] - suave_top[i]) / (bots[i] - tops[i])
    if abs(s_i - 1) > 0.002:
        sprites[i] = a_escala(sprites[i], float(np.clip(s_i, 0.985, 1.015)))
for f in glob.glob(os.path.join(SALIDA, '*.png')):
    os.remove(f)
for k, s in enumerate(sprites):
    Image.fromarray((np.ascontiguousarray(s) * 255).round().astype(np.uint8)).save(os.path.join(SALIDA, 'c_%02d.png' % (k + 1)))
print('video: %s' % IDA)
print('%d sprites; encaje del 1 con el agachado: dx %+d dy %+d; escala %.3f -> %.3f; ganancias %s' % (
    len(sprites), DX, DY, escala(IDA[0]), escala(IDA[-1]), {k: tuple(np.round(v, 3)) for k, v in gan.items()}))

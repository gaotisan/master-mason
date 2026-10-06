"""Monta el agacharse del juego a partir del video de Flow en 04_limpios.

El video (_fuentes/Pilgrim_crouching_down_20261006163053.mp4) se pidio con
prompt_agacharse_video.txt, plan A: fotograma inicial nuestro reposo y final
nuestro agachado (agacharse_claves/01_reposo y 04_agachado). Esta de pie quieto
(1-46), baja seguido (46-88; la cabeza de la 63 a la 219 de master), se pasa un
poco y sube despacio hasta quedarse (88-110, cabeza en la 204) y quieto en
nuestro agachado hasta el final.

El rebote no se puede quitar: a media bajada el cuerpo todavia no tiene la pose
final (0,40-0,59 de ella, tres pasos), asi que cortar ahi seria un golpe. Pero es
mucho mas suave que el del video viejo (que bajaba, subia y volvia a caer): aqui
solo se pasa y sube despacio, en un sentido. Se usa tal cual:
  - el reposo del juego (magnus_respirando c_01), uno de fundido, TODOS los
    fotogramas del 44 al 110, uno de fundido y el agachado del juego (c_089 de
    magnus_agacharse, el del bucle): enlaces exactos con el reposo, con el
    agachado y con todo lo que sale de el (andar agachado, giro);
  - las duraciones (en _spriteframes.py) llevan la bajada a 60 fps y el
    asentarse mas despacio, para que se lea como recolocarse y no como un bote.
Cada sprite: sin las bolsas de croma (lo que era croma en el fotograma con fondo
y fondo.ps1 dejo opaco), movido en rampa de lo que mejor casa con el reposo a lo
que mejor casa con el agachado, y con una ganancia por zonas (tunica, capucha,
pies) tambien en rampa: al principio contra el reposo, al final contra el bucle
del agachado (c_077-c_089).
Lee de _todos/ (111 sprites, video 30-140, centrados y sin fondo) y escribe
04_limpios/.
    python montar.py
"""
import glob, os, shutil
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
TODOS = os.path.join(AQUI, '_todos'); SALIDA = os.path.join(AQUI, '04_limpios')
CON_FONDO = os.path.join(AQUI, '_con_fondo', '04_limpios')
PRIMERO = 30
INICIO, FIN = 44, 110
REPOSO = os.path.join(AQUI, '..', 'magnus_respirando', '04_limpios', 'c_01.png')
REPOSOS = sorted(glob.glob(os.path.join(AQUI, '..', 'magnus_respirando', '04_limpios', '*.png')))[:29]
AGACHADO = os.path.join(AQUI, '..', 'magnus_agacharse', '04_limpios', 'c_089.png')
src = open(os.path.join(AQUI, '..', 'magnus_giro_agachado', 'igualar_color.py'), encoding='utf-8').read()
z = {'__file__': os.path.join(AQUI, '..', 'magnus_giro_agachado', 'igualar_color.py')}
exec(src[:src.index('if not os.path.isdir(COPIA)')], z)              # leer, medias, aplicar, REF

if not os.path.isdir(TODOS):
    shutil.copytree(SALIDA, TODOS)


def video(n):
    """Fotograma n del video, sin bolsas de croma."""
    k = n - PRIMERO + 1
    im = np.asarray(Image.open(os.path.join(TODOS, 'c_%03d.png' % k)).convert('RGBA')).copy()
    s = np.asarray(Image.open(os.path.join(CON_FONDO, 'c_%03d.png' % k)).convert('RGB')).astype(int)
    r, g, b = s[..., 0], s[..., 1], s[..., 2]
    # Solo lo que quedo opaco del todo: el borde suave de la silueta (alfa parcial)
    # tambien es verde en el original y no hay que tocarlo.
    bolsa = (g > r + 50) & (g > b + 40) & (im[..., 3] >= 250)
    from scipy import ndimage
    orla = ndimage.binary_dilation(bolsa, iterations=2) & ~bolsa & (im[..., 1].astype(int) > im[..., 0])
    im[bolsa | orla] = 0
    return im.astype(float) / 255


def mover(a, dx, dy=0):
    out = np.zeros_like(a); h, w = a.shape[:2]
    out[max(dy, 0):h + min(dy, 0), max(dx, 0):w + min(dx, 0)] = a[max(-dy, 0):h - max(dy, 0), max(-dx, 0):w - max(dx, 0)]
    return out


def fundir(a, b, t):
    pa = np.concatenate([a[..., :3] * a[..., 3:], a[..., 3:]], 2)
    pb = np.concatenate([b[..., :3] * b[..., 3:], b[..., 3:]], 2)
    m = (1 - t) * pa + t * pb
    al = m[..., 3:]
    return np.concatenate([np.where(al > 0, m[..., :3] / np.maximum(al, 1e-6), 0), al], 2)


def dist(a, b):
    pa, pb = a[..., :3] * a[..., 3:], b[..., :3] * b[..., 3:]
    m = (a[..., 3] > 0) | (b[..., 3] > 0)
    ys, xs = np.where(m)
    c = (slice(ys.min(), ys.max() + 1), slice(xs.min(), xs.max() + 1))
    return 10 * np.abs(pa[c] - pb[c]).mean()


def encaje(a, b):
    return min((dist(mover(a, dx, dy), b), dx, dy) for dx in range(-8, 9) for dy in range(-18, -7))


ns = list(range(INICIO, FIN + 1))
crudos = {n: video(n) for n in ns}
rep, ag = z['leer'](REPOSO), z['leer'](AGACHADO)
_, DX0, DY0 = encaje(crudos[INICIO], rep)
_, DX1, DY1 = encaje(crudos[FIN], ag)
# En vertical manda el suelo: los pies no se mueven en todo el video, asi que un
# solo desplazamiento que los deja en la fila del juego (677), como el reposo y
# el agachado. (El encaje por la pose subia 2 px los primeros.)
SUELO = 677
pies_video = int(np.median([np.where(crudos[n][..., 3] > 0.5)[0].max() for n in ns]))
DY0 = DY1 = SUELO - pies_video
ref0 = {k: np.mean([z['medias'](z['leer'](p))[k] for p in REPOSOS], 0) for k in ('tunica', 'capucha', 'pies')}
ref1 = {k: np.mean([z['medias'](z['leer'](p))[k] for p in z['REF']], 0) for k in ('tunica', 'capucha', 'pies')}
e0 = z['medias'](mover(crudos[INICIO], DX0, DY0)); e1 = z['medias'](mover(crudos[FIN], DX1, DY1))
g0 = {k: ref0[k] / e0[k] for k in ref0}; g1 = {k: ref1[k] / e1[k] for k in ref1}


def sprite(n):
    t = (n - INICIO) / float(FIN - INICIO)
    gan = {k: g0[k] * (1 - t) + g1[k] * t for k in g0}
    return z['aplicar'](mover(crudos[n], int(round(DX0 + t * (DX1 - DX0))), int(round(DY0 + t * (DY1 - DY0)))), gan)


bajada = [sprite(n) for n in ns]
# Nitidez: el video de Flow (720p ampliado 1,5) es algo mas blando que los sprites
# del juego; se enfoca con la fuerza que deja el ultimo (la pose que se queda)
# tan nitido como el agachado del juego, para que al acabar no cambie de blando a
# nitido. (Mismo enfoque que magnus_giro_agachado_video/montar.py.)
from scipy import ndimage as _nd


def nitidez(im):
    """Laplaciano medio a tamano de hoja (la mitad), que es lo que se ve."""
    pre = im[..., :3] * im[..., 3:]
    h, w = (im.shape[0] // 2) * 2, (im.shape[1] // 2) * 2
    g = pre[:h, :w].mean(2).reshape(h // 2, 2, w // 2, 2).mean((1, 3))
    a = im[:h, :w, 3].reshape(h // 2, 2, w // 2, 2).mean((1, 3))
    return float(np.abs(_nd.laplace(g)[a > 0.78]).mean() * 1000)


def enfocar(im, k, sigma=2.0):
    """Mascara de desenfoque ponderada por el alfa (el fondo no entra)."""
    a = im[..., 3]
    if k <= 0:
        return im
    rgb = im[..., :3]
    peso = _nd.gaussian_filter(a, sigma)
    borroso = np.stack([_nd.gaussian_filter(rgb[..., c] * a, sigma) for c in range(3)], -1) / np.maximum(peso, 1e-6)[..., None]
    out = np.clip(rgb + k * (rgb - borroso), 0, 1)
    return np.concatenate([np.where(a[..., None] > 0, out, 0), a[..., None]], 2)


def calibrar(im, objetivo):
    return min(np.arange(0, 3.01, 0.05), key=lambda k: abs(nitidez(enfocar(im, k)) - objetivo))


# La fuerza va en rampa: la del primero contra el reposo y la del ultimo (la pose
# que se queda) contra el agachado del juego.
K0, K1 = calibrar(bajada[0], nitidez(rep)), calibrar(bajada[-1], nitidez(ag))
bajada = [enfocar(s, K0 + (K1 - K0) * i / (len(bajada) - 1.0)) for i, s in enumerate(bajada)]
print('enfoque %.2f -> %.2f: reposo %.1f, primero %.1f, ultimo %.1f, agachado %.1f' % (
    K0, K1, nitidez(rep), nitidez(bajada[0]), nitidez(bajada[-1]), nitidez(ag)))
sprites = [rep, fundir(rep, bajada[0], 0.5)] + bajada + [fundir(bajada[-1], ag, 0.5), ag]
for p in glob.glob(os.path.join(SALIDA, '*.png')):
    os.remove(p)
for k, s in enumerate(sprites):
    Image.fromarray((np.ascontiguousarray(s) * 255).round().astype(np.uint8)).save(os.path.join(SALIDA, 'c_%03d.png' % (k + 1)))
pasos = [dist(a, b) for a, b in zip(sprites, sprites[1:])]
cab = [int(np.where(s[..., 3] > 0.5)[0].min()) for s in sprites]
pies = [int(np.where(s[..., 3] > 0.5)[0].max()) for s in sprites]
print('%d sprites; dx %d -> %d, dy %d (pies del video en la %d)' % (len(sprites), DX0, DX1, DY0, pies_video))
print('pasos %s' % ' '.join('%.2f' % q for q in pasos))
print('cabeza %s' % cab)
print('pies %s' % sorted(set(pies)))

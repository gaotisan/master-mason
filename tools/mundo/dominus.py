"""Dominus sentado a su mesa: genera las piezas del recorte en el estilo facetado
de Magnus (low-poly pintado: facetas triangulares planas, colores apagados,
bordes pintados y sin contorno).

    python dominus.py <carpeta_png> [--escena <ruta_tscn>] [--preview <png>]

Cada pieza se define como una o varias CAPAS (poligono + material). Cada capa
se triangula por su cuenta (Delaunay sobre el contorno y unos puntos interiores
repartidos con disco de Poisson), cada faceta se sombrea con una normal inventada
-- la de una cupula sacada de la distancia al borde, mas una inclinacion al azar
por faceta -- y la luz puntual de la vela. Se pinta a SS aumentos y se reduce
con Lanczos (en alfa premultiplicado, para que no salgan bordes oscuros).

COORDENADAS: todo se dibuja en coordenadas de PERSONAJE, en px de juego. El
origen es el punto del suelo bajo el centro del asiento; y crece hacia abajo,
asi que lo que esta por encima del suelo tiene y negativa. Cada pieza se dibuja
EN SU POSE DE REPOSO, y cada PNG se guarda con la esquina de arriba a la
izquierda de su caja en esas coordenadas. Por eso el rig se monta sin tocar
nada a ojo: cada Sprite2D va colgado de un nodo en su pivote y lleva de offset
(esquina - pivote). Rotacion 0 = la pose de reposo.

El .tscn lo escribe este mismo script (--escena) con esos numeros: si se
retoca una pieza, se regenera todo y el rig sigue cuadrando. OJO: eso pisa el
.tscn entero, asi que los retoques hechos a mano en la escena se pierden; lo
que la casa necesite cambiar se hace con los @export de dominus.gd o desde la
escena que lo instancia. Con --solo-escena no se pinta nada: se reescribe el
.tscn con el dominus_rig.json de la ultima vez (sirve tras la primera
importacion, para que las texturas nuevas entren con su uid).

    python dominus.py <carpeta_png> --solo-escena --escena <ruta_tscn>

COLOR. El estilo de Magnus es apagado (saturacion media ~0,30). La luz de la
vela aporta calor sobre todo con el VALOR, no con el croma: el color de la luz
esta tirado hacia su luminancia y cada material lleva un 'sat' que desatura la
faceta ya sombreada. La casa pone su propio tono encima (el fuego, el modulate
de Magnus); si el recorte ya viniera naranja, se doblaria.
"""
from __future__ import annotations

import json
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage
from scipy.spatial import Delaunay

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pincel import grano, ruido_valor  # noqa: E402  (solo se reutiliza, no se toca)

SS = 4  # sobremuestreo

# --------------------------------------------------------------------------
# Luz. La vela esta sobre la mesa, delante y a la izquierda de Dominus; la z
# positiva sale hacia la camara (la mesa esta entre la camara y el).
# --------------------------------------------------------------------------
VELA_X, VELA_BASE = -205.0, -157.0
LLAMA = (-205.0, -207.0)
LUZ_POS = np.array([LLAMA[0], LLAMA[1], 45.0])
# Color de vela (1, .77, .54) tirado un 40 % hacia su luminancia: con el
# original la piel salia a saturacion 0,49 y la mesa a 0,6, el doble que Magnus.
_LUZ_VELA = np.array([1.0, 0.77, 0.54])
_LUM = float(_LUZ_VELA @ np.array([0.2126, 0.7152, 0.0722]))
LUZ_COLOR = _LUZ_VELA + (_LUM - _LUZ_VELA) * 0.40
LUZ_INTENSIDAD = 1.40
LUZ_RADIO = 250.0           # a esta distancia la luz ha caido a la mitad
AMBIENTE = np.array([0.41, 0.38, 0.39])
# Contraluz frio y flojo desde atras a la derecha: separa la toga negra de la
# pared sin que se note de donde viene.
RIM_DIR = np.array([0.88, -0.30, 0.36]); RIM_DIR /= np.linalg.norm(RIM_DIR)
RIM_COLOR = np.array([0.42, 0.46, 0.60])


def rgb(h: str) -> tuple[float, float, float]:
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


# --------------------------------------------------------------------------
# Materiales: lista de colores base (el "parcheado" del estilo) con pesos.
# --------------------------------------------------------------------------
MAT = {
    # Toga: casi negra, con facetas de marron profundo e indigo.
    'toga': dict(colores=[rgb('#2f2629'), rgb('#37271f'), rgb('#282536'), rgb('#1e1b1f'), rgb('#3d2b22'),
                          rgb('#2b2937')],
                 pesos=[3, 2.2, 1.0, 3, 1.2, 0.7], var=0.06, rim=0.16, sat=0.9),
    'toga_sombra': dict(colores=[rgb('#221c20'), rgb('#281d17'), rgb('#1d1b27'), rgb('#161416')],
                        pesos=[3, 3, 2, 2], var=0.06, rim=0.06, sat=0.9),
    # Piel: la base ya es apagada; el calor lo ponia la luz. Con 'sat' 0,72 queda
    # en ~0,33 de saturacion media, como el bajo del abrigo de Magnus.
    'piel': dict(colores=[rgb('#bda296'), rgb('#b3988d'), rgb('#c4a899'), rgb('#ab918a')],
                 pesos=[3, 2, 2, 1], var=0.035, rim=0.10, sat=0.72,
                 # sombras de la piel calientes: con el ambiente general salian malva
                 amb=(0.45, 0.39, 0.36)),
    # Pelo: valores bajados. Lo mas claro (lado de la vela) ronda #d8d0c4 y la
    # mitad de atras #9c968f; antes era lo mas brillante de la pantalla tras la
    # llama y se leia como una peluca.
    'pelo': dict(colores=[rgb('#bdb5a8'), rgb('#afa9a0'), rgb('#c6beb0'), rgb('#a39d96'), rgb('#b6ad9f')],
                 pesos=[3, 2, 2, 1.2, 2], var=0.05, rim=0.14, sat=0.8),
    'pelo_sombra': dict(colores=[rgb('#9c968f'), rgb('#908b86'), rgb('#a39c93')],
                        pesos=[2, 2, 1], var=0.05, rim=0.12, sat=0.8),
    'mesa': dict(colores=[rgb('#4a3a2e'), rgb('#403228'), rgb('#56443a'), rgb('#3a2e25'), rgb('#4d3d31')],
                 pesos=[3, 3, 1.5, 2, 2], var=0.06, rim=0.05, sat=0.85),
    'mesa_oscura': dict(colores=[rgb('#2e241c'), rgb('#281f18'), rgb('#33291f')],
                        pesos=[2, 2, 1], var=0.05, rim=0.0, sat=0.85),
    'cuenco': dict(colores=[rgb('#735a45'), rgb('#68523f'), rgb('#7e644d')],
                   pesos=[2, 2, 1], var=0.05, rim=0.05, sat=0.85),
    'cuenco_dentro': dict(colores=[rgb('#483629'), rgb('#3e2f24')], pesos=[1, 1], var=0.04, rim=0.0, sat=0.85),
    'sopa': dict(colores=[rgb('#6b5f40'), rgb('#62573b'), rgb('#736644')], pesos=[2, 2, 1], var=0.05, rim=0.0,
                 sat=0.85),
    'cuchara': dict(colores=[rgb('#9c8062'), rgb('#90765a')], pesos=[1, 1], var=0.04, rim=0.1, sat=0.85),
    'cera': dict(colores=[rgb('#e6dcc2'), rgb('#ddd2b6'), rgb('#ebe2ca')], pesos=[2, 2, 1], var=0.03, rim=0.1),
    'hierro': dict(colores=[rgb('#3d3835'), rgb('#34302e'), rgb('#46403b')], pesos=[2, 2, 1], var=0.05, rim=0.2),
    'taburete': dict(colores=[rgb('#43362b'), rgb('#3a2f25'), rgb('#4b3d31')], pesos=[2, 2, 1], var=0.05, rim=0.05,
                     sat=0.85),
    'zapatilla': dict(colores=[rgb('#211915'), rgb('#1c1512')], pesos=[1, 1], var=0.04, rim=0.05),
}


# --------------------------------------------------------------------------
# Lienzo de una pieza, en alfa premultiplicado, a SS aumentos.
# --------------------------------------------------------------------------
class Pieza:
    def __init__(self, nombre: str, caja: tuple[float, float, float, float], pivote: tuple[float, float],
                 semilla: int):
        self.nombre = nombre
        x0, y0, x1, y1 = caja
        self.x0, self.y0 = int(math.floor(x0)), int(math.floor(y0))
        self.w, self.h = int(math.ceil(x1)) - self.x0, int(math.ceil(y1)) - self.y0
        self.pivote = pivote
        self.rgb = np.zeros((self.h * SS, self.w * SS, 3), np.float32)   # premultiplicado
        self.a = np.zeros((self.h * SS, self.w * SS), np.float32)
        self.rng = random.Random(semilla)
        self.nrng = np.random.default_rng(semilla)
        self.semilla = semilla

    # coordenadas de personaje -> pixel del lienzo grande
    def px(self, pts):
        return [((x - self.x0) * SS, (y - self.y0) * SS) for x, y in pts]

    def mascara(self, pts, suave: float = 0.0) -> np.ndarray:
        im = Image.new('L', (self.w * SS, self.h * SS), 0)
        ImageDraw.Draw(im).polygon(self.px(pts), fill=255)
        if suave > 0:
            im = im.filter(ImageFilter.GaussianBlur(suave * SS))
        return np.asarray(im, np.float32) / 255.0

    def componer(self, color: np.ndarray, alfa: np.ndarray) -> None:
        """color: (H,W,3) sin premultiplicar, o un color suelto."""
        a = alfa[..., None]
        self.rgb = color * a + self.rgb * (1 - a)
        self.a = alfa + self.a * (1 - alfa)

    def pintar(self, pts, color, alfa: float = 1.0, suave: float = 0.25) -> None:
        m = self.mascara(pts, suave) * alfa
        self.componer(np.array(color, np.float32)[None, None, :], m)

    def oscurecer(self, pts, factor: float, suave: float = 0.35, sobre_existente: bool = True) -> None:
        """Multiplica lo ya pintado dentro del poligono (una faceta mas oscura)."""
        m = self.mascara(pts, suave)
        f = 1 - m * (1 - factor)
        self.rgb *= f[..., None]

    def matizar(self, pts, color, fuerza: float, suave: float = 0.35) -> None:
        """Mezcla el color dentro del poligono sin tocar el alfa (para brillos)."""
        m = self.mascara(pts, suave)[..., None] * fuerza
        c = np.array(color, np.float32)[None, None, :]
        self.rgb = self.rgb * (1 - m) + c * self.a[..., None] * m

    def linea(self, pts, ancho: float, color, alfa: float, suave: float = 0.3) -> None:
        im = Image.new('L', (self.w * SS, self.h * SS), 0)
        d = ImageDraw.Draw(im)
        p = self.px(pts)
        d.line(p, fill=255, width=max(1, int(round(ancho * SS))), joint='curve')
        if suave > 0:
            im = im.filter(ImageFilter.GaussianBlur(suave * SS))
        m = np.asarray(im, np.float32) / 255.0 * alfa
        m *= (self.a > 0.01)                       # solo encima de lo pintado
        c = np.array(color, np.float32)[None, None, :]
        self.rgb = self.rgb * (1 - m[..., None]) + c * self.a[..., None] * m[..., None]

    def circulo(self, cx, cy, r, color, alfa=1.0, suave=0.2) -> None:
        pts = [(cx + r * math.cos(t), cy + r * math.sin(t)) for t in np.linspace(0, 2 * math.pi, 24, endpoint=False)]
        self.pintar(pts, color, alfa, suave)

    def recortar(self, pts, suave: float = 0.2) -> None:
        """Deja solo lo que cae dentro del poligono (para partir una pieza en dos)."""
        m = self.mascara(pts, suave)
        self.rgb *= m[..., None]
        self.a *= m

    def quitar(self, pts, suave: float = 0.2) -> None:
        m = 1 - self.mascara(pts, suave)
        self.rgb *= m[..., None]
        self.a *= m

    def copia(self, nombre: str, pivote=None) -> 'Pieza':
        p = Pieza.__new__(Pieza)
        p.__dict__.update(self.__dict__)
        p.nombre = nombre
        p.pivote = pivote if pivote is not None else self.pivote
        p.rgb = self.rgb.copy()
        p.a = self.a.copy()
        return p

    def final(self) -> Image.Image:
        """Reduce a tamano de juego en premultiplicado y despremultiplica."""
        chans = []
        for i in range(3):
            chans.append(Image.fromarray(self.rgb[..., i].astype(np.float32), 'F').resize((self.w, self.h),
                                                                                         Image.LANCZOS))
        al = Image.fromarray(self.a.astype(np.float32), 'F').resize((self.w, self.h), Image.LANCZOS)
        a = np.clip(np.asarray(al, np.float32), 0, 1)
        c = np.stack([np.asarray(ch, np.float32) for ch in chans], -1)
        c = np.where(a[..., None] > 1e-4, c / np.maximum(a[..., None], 1e-4), 0)
        out = np.zeros((self.h, self.w, 4), np.uint8)
        out[..., :3] = (np.clip(c, 0, 1) * 255 + 0.5).astype(np.uint8)
        out[..., 3] = (a * 255 + 0.5).astype(np.uint8)
        return Image.fromarray(out, 'RGBA')

    def guardar(self, carpeta: str, registro: dict) -> None:
        img = self.final()
        # Recorta el margen vacio para no gastar textura, conservando la esquina.
        bb = img.getbbox()
        if bb is None:
            bb = (0, 0, 1, 1)
        l, t, r, b = max(bb[0] - 2, 0), max(bb[1] - 2, 0), min(bb[2] + 2, self.w), min(bb[3] + 2, self.h)
        img = img.crop((l, t, r, b))
        ruta = os.path.join(carpeta, f'{self.nombre}.png')
        img.save(ruta, optimize=True)
        registro[self.nombre] = dict(archivo=f'{self.nombre}.png', x0=self.x0 + l, y0=self.y0 + t,
                                     w=img.width, h=img.height, pivote=list(self.pivote))


# --------------------------------------------------------------------------
# Facetado
# --------------------------------------------------------------------------
def remuestrear(poli, paso: float, rng: random.Random, var: float = 0.3,
                aniso=(1.0, 1.0)) -> list[tuple[float, float]]:
    """Puntos sobre el contorno cada ~paso px (con algo de azar), mas los vertices.
    Con aniso el paso se estira en la direccion del lado: un lado horizontal con
    aniso (4, 1) lleva cuatro veces menos puntos, o saldrian dientes de sierra."""
    out = []
    n = len(poli)
    ax, ay = aniso
    for i in range(n):
        (x0, y0), (x1, y1) = poli[i], poli[(i + 1) % n]
        out.append((x0, y0))
        L = math.hypot(x1 - x0, y1 - y0)
        if L < 1e-6:
            continue
        ux, uy = (x1 - x0) / L, (y1 - y0) / L
        p = paso * math.hypot(ux * ax, uy * ay)
        k = int(L / p)
        for j in range(k):
            t = (j + 1) / (k + 1) + rng.uniform(-var, var) / (k + 1)
            out.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t))
    return out


def poisson(mask1: np.ndarray, ox: int, oy: int, r: float, aniso: tuple[float, float], rng: random.Random,
            margen: float, variar: float = 0.35, semilla: int = 0) -> list[tuple[float, float]]:
    """Disco de Poisson por lanzamiento de dardos dentro de la mascara (a 1x).
    aniso estira la distancia: (1, 2) da facetas el doble de largas en vertical.
    variar hace que el radio cambie de una zona a otra (ruido suave), para que
    no salga la malla regular del 'low poly' generico: en Magnus conviven
    facetas grandes y pequenas."""
    dist = ndimage.distance_transform_edt(mask1 > 0.5)
    h, w = mask1.shape
    campo = ruido_valor(max(w, 4), max(h, 4), max(r * 3, 8), 2, semilla, periodico_x=False)
    ax, ay = aniso
    pts: list[tuple[float, float, float]] = []
    intentos = int(w * h / (r * r) * 30) + 50
    for _ in range(intentos):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        xi, yi = min(int(x), w - 1), min(int(y), h - 1)
        if dist[yi, xi] < margen:
            continue
        ri = r * (1 + (campo[yi, xi] - 0.5) * 2 * variar)
        ok = True
        for (px, py, pr) in pts:
            rr = (ri + pr) * 0.5
            if ((px - x) / ax) ** 2 + ((py - y) / ay) ** 2 < rr * rr:
                ok = False
                break
        if ok:
            pts.append((x, y, ri))
    return [(x + ox, y + oy) for x, y, _ in pts]


def facetar(pz: Pieza, poli, mat: str, esp: float, *, aniso=(1.0, 1.0), extra=(), sesgo=(0.0, 0.0, 0.0),
            relieve: float = 1.0, inclinacion: float = 0.16, costuras: float = 0.14, borde_jitter: float = 0.3,
            borde_suave: float = 0.18, gradiente: float = 0.05, ruido: float = 0.045, brillo: float = 1.0,
            luz_extra: float = 1.0, capa_alfa: float = 1.0, z_base: float = 0.0, fusion: float = 0.45,
            auto: bool = True, paso_borde: float | None = None, rim: float | None = None,
            sat: float | None = None) -> None:
    """Pinta una capa facetada en la pieza. esp = tamano medio de faceta (px de juego).

    auto=False no reparte puntos al azar: solo los vertices del poligono y los
    'extra' puestos a mano (para la cara, donde cada plano tiene que caer en su
    sitio). fusion = probabilidad de que un triangulo se funda con un vecino y
    formen un cuadrilatero del mismo color: rompe la malla de triangulos y se
    parece mas al parcheado de Magnus."""
    rng = pz.rng
    m = MAT[mat]
    k_rim = m['rim'] if rim is None else rim
    # --- contorno con un temblor de pincel (muy poco: el estilo es de aristas rectas)
    cont = []
    n = len(poli)
    for i in range(n):
        (x0, y0), (x1, y1) = poli[i], poli[(i + 1) % n]
        L = math.hypot(x1 - x0, y1 - y0)
        k = max(1, int(L / 2.0))
        for j in range(k):
            t = j / k
            cont.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t))
    if borde_jitter > 0:
        fase = rng.uniform(0, 100)
        nuevo = []
        for idx, (x, y) in enumerate(cont):
            s = idx * 0.35 + fase
            nuevo.append((x + borde_jitter * math.sin(s * 1.7) * math.cos(s * 0.61),
                          y + borde_jitter * math.cos(s * 1.3) * math.sin(s * 0.83)))
        cont = nuevo
    mascara = pz.mascara(cont, borde_suave)
    # --- mascara a 1x para el reparto de puntos y la cupula de relieve
    m1 = np.asarray(Image.fromarray((mascara * 255).astype(np.uint8)).resize((pz.w, pz.h), Image.BILINEAR),
                    np.float32) / 255.0
    if auto:
        borde = remuestrear(poli, paso_borde or esp * 1.05, rng, aniso=aniso)
        interior = poisson(m1, pz.x0, pz.y0, esp, aniso, rng, margen=esp * 0.5, semilla=pz.semilla + len(poli))
    else:
        borde = list(poli) if paso_borde is None else remuestrear(poli, paso_borde, rng, aniso=aniso)
        interior = []
    pts = borde + interior + list(extra)
    # Anillo exterior para que todo pixel de la mascara caiga en algun triangulo.
    x0, y0, x1, y1 = pz.x0 - 30, pz.y0 - 30, pz.x0 + pz.w + 30, pz.y0 + pz.h + 30
    for t in np.linspace(0, 1, 7):
        pts += [(x0 + (x1 - x0) * t, y0), (x0 + (x1 - x0) * t, y1), (x0, y0 + (y1 - y0) * t),
                (x1, y0 + (y1 - y0) * t)]
    P = np.array(pts, np.float64)
    tri = Delaunay(P)
    T = tri.simplices
    cents = P[T].mean(axis=1)
    # --- fusion de triangulos vecinos en poligonos
    grupo = np.arange(len(T))
    tomado = np.zeros(len(T), bool)
    orden = list(range(len(T)))
    rng.shuffle(orden)
    for i in orden:
        if tomado[i] or rng.random() > fusion:
            continue
        vec = [j for j in tri.neighbors[i] if j >= 0 and not tomado[j]]
        if not vec:
            continue
        j = rng.choice(vec)
        grupo[j] = i
        tomado[i] = tomado[j] = True
    # --- relieve: cupula de seccion circular sacada de la distancia al borde
    d = ndimage.distance_transform_edt(m1 > 0.5).astype(np.float32)
    R = max(float(d.max()), 1.0)
    hcamp = np.sqrt(np.maximum(0.0, R * R - (R - np.minimum(d, R)) ** 2)) * relieve
    hcamp = ndimage.gaussian_filter(hcamp, R * 0.25 + 0.5)
    gy, gx = np.gradient(hcamp)
    # --- color de cada grupo (se calcula en el centro del grupo)
    cols = np.zeros((len(T), 3), np.float32)
    grads = np.zeros((len(T), 2), np.float32)
    gcent = np.zeros((len(T), 2), np.float32)
    pesos = np.array(m['pesos'], np.float64)
    pesos /= pesos.sum()
    for gidx in np.unique(grupo):
        miembros = np.where(grupo == gidx)[0]
        cx, cy = cents[miembros].mean(axis=0)
        xi = int(np.clip(cx - pz.x0, 0, pz.w - 1))
        yi = int(np.clip(cy - pz.y0, 0, pz.h - 1))
        nrm = np.array([-gx[yi, xi], -gy[yi, xi], 1.0])
        nrm /= np.linalg.norm(nrm)
        nrm = nrm + np.array(sesgo) + np.array([rng.gauss(0, inclinacion), rng.gauss(0, inclinacion), 0.0])
        nrm /= np.linalg.norm(nrm)
        p3 = np.array([cx, cy, z_base + hcamp[yi, xi]])
        lv = LUZ_POS - p3
        dist = np.linalg.norm(lv)
        lv /= dist
        dif = max(0.0, float(nrm @ lv))
        at = 1.0 / (1.0 + (dist / LUZ_RADIO) ** 2)
        rim_v = max(0.0, float(nrm @ RIM_DIR)) ** 2 * k_rim
        bi = pz.nrng.choice(len(m['colores']), p=pesos)
        base = np.array(m['colores'][bi], np.float32) * (1 + rng.uniform(-m['var'], m['var']))
        luz = np.array(m.get('amb', AMBIENTE)) + LUZ_COLOR * (LUZ_INTENSIDAD * dif * at * luz_extra)
        c = base * luz * brillo + RIM_COLOR * rim_v * 0.5
        # Desatura la faceta ya iluminada hacia su luminancia: el calor de la
        # vela se queda en el valor y no dispara el croma.
        k_sat = m.get('sat', 1.0) if sat is None else sat
        if k_sat != 1.0:
            lum = float(c @ np.array([0.2126, 0.7152, 0.0722]))
            c = lum + (c - lum) * k_sat
        ang = rng.uniform(0, 2 * math.pi)
        cols[miembros] = c
        grads[miembros] = (math.cos(ang) * gradiente, math.sin(ang) * gradiente)
        gcent[miembros] = (cx, cy)
    # --- pintar indices de triangulo
    idx_im = Image.new('I', (pz.w * SS, pz.h * SS), 0)
    dr = ImageDraw.Draw(idx_im)
    for i, t in enumerate(T):
        dr.polygon(pz.px(P[t]), fill=i + 1)
    idx = np.maximum(np.asarray(idx_im, np.int32) - 1, 0)
    H, W = idx.shape
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    xx = xx / SS + pz.x0
    yy = yy / SS + pz.y0
    c = cols[idx]
    rel = (xx - gcent[idx, 0]) * grads[idx, 0] + (yy - gcent[idx, 1]) * grads[idx, 1]
    c = c * (1 + rel[..., None] / max(esp, 4.0))
    # --- costuras: algunas aristas entre grupos un pelo mas oscuras
    if costuras > 0:
        cos_im = Image.new('L', (W, H), 0)
        dc = ImageDraw.Draw(cos_im)
        vistas = set()
        for i, t in enumerate(T):
            for k_, j in enumerate(tri.neighbors[i]):
                if j < 0 or grupo[j] == grupo[i]:
                    continue
                a_, b_ = t[(k_ + 1) % 3], t[(k_ + 2) % 3]
                clave = (min(a_, b_), max(a_, b_))
                if clave in vistas:
                    continue
                vistas.add(clave)
                if rng.random() < 0.45:
                    continue
                v = int(255 * rng.uniform(0.4, 1.0))
                dc.line(pz.px([P[a_], P[b_]]), fill=v, width=max(1, int(0.8 * SS)))
        cos_im = cos_im.filter(ImageFilter.GaussianBlur(0.5 * SS))
        cs = np.asarray(cos_im, np.float32) / 255.0
        c = c * (1 - cs[..., None] * costuras)
    # --- textura de papel: manchas suaves y grano
    if ruido > 0:
        rv = ruido_valor(max(W // 4, 8), max(H // 4, 8), 18.0, 3, pz.semilla + len(pts), periodico_x=False)
        rv = np.asarray(Image.fromarray((rv * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC),
                        np.float32) / 255.0
        g = grano(W, H, pz.semilla + 7, 1.0)
        c = c * (1 + (rv - 0.5) * 2 * ruido + g * ruido * 0.35)[..., None]
    c = np.clip(c, 0, 1)
    pz.componer(c, mascara * capa_alfa)


# --------------------------------------------------------------------------
# Piezas
# --------------------------------------------------------------------------
# Pivotes (coordenadas de personaje). Deben casar con dominus.gd a traves del
# .tscn, que se escribe desde aqui.
CADERA = (10.0, -100.0)      # Cuerpo: inclinarse y respirar giran aqui
CUELLO = (-8.0, -222.0)      # Cabeza
MANDIBULA = (-9.0, -247.0)   # bisagra de la mandibula, bajo la oreja
HOMBRO = (6.0, -207.0)       # hombro cercano
CODO = (-13.0, -160.0)
MUNECA = (-57.0, -177.0)
AGARRE = (-65.0, -180.0)     # por donde la mano coge la cuchara
PUNTA_CUCHARA = (-92.0, -165.5)
HOMBRO_LEJANO = (-32.0, -207.0)
# Fin de la manga lejana = donde empieza el puno de la mano lejana. La mano
# (mano_lejana.png) va clavada en la mesa, fuera del Cuerpo; la manga gira sobre
# el hombro para seguir apuntando aqui cuando el tronco se inclina.
FIN_MANGA = (-117.0, -171.5)
CUENCO_BASE = (-92.0, -157.0)
LABIOS = (-41.5, -238.3)
OJO = (-32.6, -255.8)
CORONILLA = (-4.0, -291.5)
MESA_Y = -150.0              # canto delantero del tablero (el "alto de la mesa")
MESA_FONDO = -164.0          # canto trasero: el tablero se ve como una franja
APOYO = -157.0               # donde se apoyan las cosas (mitad de la franja)


def pieza_taburete():
    pz = Pieza('taburete', (-40, -110, 75, 2), (0, 0), 11)
    facetar(pz, [(14, -91), (22, -91), (23, -10), (15, -10)], 'taburete', 10, aniso=(1, 5), brillo=0.6)
    facetar(pz, [(-22, -44), (60, -44), (60, -38), (-22, -38)], 'taburete', 10, aniso=(5, 1), brillo=0.75)
    facetar(pz, [(-20, -92), (-11, -92), (-18, 0), (-28, 0)], 'taburete', 10, aniso=(1, 5))
    facetar(pz, [(47, -92), (56, -92), (65, 0), (56, 0)], 'taburete', 10, aniso=(1, 5), brillo=0.8)
    facetar(pz, [(-28, -101), (-20, -104), (56, -104), (61, -100), (60, -91), (-28, -91)], 'taburete', 10,
            aniso=(5, 1))
    return pz


def pieza_piernas():
    pz = Pieza('piernas', (-115, -125, 60, 2), (0, 0), 12)
    # pierna lejana, un poco adelantada y mas oscura
    lejana = [(20, -112), (-30, -116), (-70, -114), (-86, -108), (-92, -96), (-91, -60), (-88, -22), (-80, -16),
              (-62, -16), (-60, -60), (-56, -92), (20, -94)]
    facetar(pz, lejana, 'toga_sombra', 27, brillo=0.8)
    facetar(pz, [(-90, -17), (-106, -12), (-110, -4), (-106, 0), (-74, 0), (-74, -14)], 'zapatilla', 12, brillo=0.8)
    cerca = [(46, -96), (40, -110), (0, -115), (-40, -114), (-62, -110), (-74, -104), (-78, -94), (-80, -60),
             (-79, -22), (-82, -14), (-56, -12), (-50, -14), (-46, -50), (-40, -80), (-30, -91), (46, -90)]
    facetar(pz, cerca, 'toga', 27, relieve=1.0)
    facetar(pz, [(-80, -15), (-96, -11), (-100, -4), (-96, 0), (-62, 0), (-60, -12)], 'zapatilla', 12)
    # pliegue de la toga entre la rodilla y el tobillo
    pz.linea([(-70, -100), (-66, -60), (-62, -18)], 1.0, (0.05, 0.04, 0.05), 0.35, 0.6)
    return pz


def pieza_torso():
    pz = Pieza('torso_toga', (-55, -232, 70, -86), CADERA, 21)
    poli = [(-18, -215), (-28, -212), (-38, -204), (-44, -189), (-47, -170), (-47, -150), (-44, -128),
            (-40, -108), (-36, -90), (52, -90), (57, -110), (61, -135), (62, -160), (58, -183), (50, -202),
            (37, -215), (20, -222), (4, -224), (-6, -221)]
    facetar(pz, poli, 'toga', 25, extra=[(-32, -198), (-40, -176), (32, -204), (48, -172), (-12, -205)],
            sesgo=(-0.05, 0, 0), fusion=0.5)
    # cuello de la toga: un pliegue que abraza el cuello
    pz.oscurecer([(-20, -216), (-8, -222), (4, -224), (6, -218), (-6, -214), (-18, -211)], 0.7)
    pz.linea([(-22, -212), (-8, -216), (6, -219)], 1.0, rgb('#4a362b'), 0.55, 0.4)
    # Sombra que arroja el brazo cercano sobre el costado: sin ella la manga se
    # funde con la toga y se lee como una banda, no como un brazo.
    pz.oscurecer([(20, -219), (27, -212), (28, -196), (22, -176), (14, -160), (4, -150), (-2, -156), (12, -172),
                  (18, -190), (19, -207)], 0.55, 2.0)
    return pz


def pieza_brazo_lejano():
    pz = Pieza('brazo_lejano', (-150, -222, -18, -150), HOMBRO_LEJANO, 31)
    manga = [(-40, -216), (-24, -214), (-24, -196), (-36, -178), (-52, -164), (-64, -158), (-78, -158),
             (-104, -160), (-108, -164), (-109, -173), (-103, -177), (-82, -176), (-70, -176), (-60, -184),
             (-50, -198)]
    facetar(pz, manga, 'toga_sombra', 16, extra=[(-44, -196), (-60, -170), (-90, -168)], fusion=0.5)
    # mano huesuda apoyada, con los dedos largos estirados hacia la izquierda
    dorso = [(-104, -174.5), (-111, -176.5), (-118, -175.5), (-121, -171.5), (-120, -166), (-112, -164.5),
             (-105, -165.5)]
    facetar(pz, dorso, 'piel', 8, auto=False, extra=[(-112, -170.5)], relieve=0.6, brillo=0.8, inclinacion=0.1,
            rim=0.0, luz_extra=0.8)
    for k, (yb, largo) in enumerate(((-174.2, 17), (-171.8, 19), (-169.4, 18), (-167.0, 14))):
        x0 = -119.5 + k * 0.4
        dedo = [(x0, yb - 1.1), (x0 - largo * 0.55, yb - 1.0), (x0 - largo, yb + 0.4), (x0 - largo + 0.5, yb + 1.3),
                (x0 - largo * 0.55, yb + 1.1), (x0, yb + 1.1)]
        facetar(pz, dedo, 'piel', 6, auto=False, extra=[(x0 - largo * 0.5, yb)], relieve=0.4, brillo=0.8,
                inclinacion=0.1, costuras=0.0, borde_jitter=0.05, rim=0.0, luz_extra=0.8)
    pz.linea([(-120, -166.2), (-133, -165.6)], 0.5, (0.25, 0.15, 0.12), 0.3, 0.2)
    return pz


def pieza_brazo_sup():
    pz = Pieza('brazo_sup', (-30, -232, 32, -144), HOMBRO, 41)
    poli = [(-12, -214), (-4, -222), (8, -224), (18, -219), (22, -207), (20, -190), (13, -173), (5, -160),
            (-4, -151), (-15, -152), (-23, -160), (-22, -176), (-19, -194), (-16, -207)]
    facetar(pz, poli, 'toga', 18, extra=[(2, -210), (-8, -186), (6, -186), (-10, -166)], sesgo=(-0.1, 0, 0.05),
            fusion=0.5)
    # canto delantero con la luz de la vela y el trasero hundido en sombra:
    # dibujan el volumen de la manga
    pz.linea([(-13, -213), (-17.5, -200), (-20, -184), (-21.5, -168), (-20, -158)], 1.1, rgb('#8a6048'), 0.55, 0.5)
    pz.linea([(19.5, -214), (21, -204), (18.5, -188), (11.5, -172), (3.5, -160)], 1.6, rgb('#0e0b0d'), 0.6, 0.8)
    return pz


def pieza_antebrazo():
    pz = Pieza('antebrazo', (-70, -198, 6, -142), CODO, 51)
    poli = [(-1, -163), (-3, -154), (-12, -150), (-26, -153), (-40, -158), (-52, -162), (-59, -169), (-62, -178),
            (-60, -186), (-53, -189), (-40, -181), (-26, -174), (-13, -170), (-4, -168)]
    facetar(pz, poli, 'toga', 14, extra=[(-14, -160), (-34, -166), (-50, -175)], sesgo=(-0.08, -0.05, 0.05),
            fusion=0.5)
    # boca de la manga: el hueco oscuro por el que sale la mano
    pz.oscurecer([(-60, -171), (-62, -178), (-60, -185), (-57, -183), (-56, -176)], 0.45)
    return pz


def pieza_mano():
    """Puno cerrado sobre el mango, nudillos hacia la izquierda y el pulgar
    montado encima. A escala de juego son 13 px: lo que se tiene que leer es un
    bloque con la esquina de los nudillos, no una bola."""
    pz = Pieza('mano', (-78, -192, -50, -166), MUNECA, 61)
    poli = [(-55.5, -182.5), (-60, -186.2), (-66, -187.6), (-70.6, -185.8), (-72.2, -181.2), (-71.4, -176.4),
            (-68.4, -172.8), (-63.2, -172.0), (-59.4, -173.6), (-55.2, -174.4)]
    facetar(pz, poli, 'piel', 6, auto=False, relieve=0.8, extra=[(-63.5, -181), (-68.2, -179), (-60, -177.5)],
            inclinacion=0.1, sesgo=(-0.12, -0.04, 0), fusion=0.25, luz_extra=0.8)
    # pulgar encima del mango, algo mas claro
    pz.matizar([(-60.5, -186.0), (-66.5, -187.2), (-70.0, -184.4), (-65.0, -184.2), (-61.0, -184.4)],
               rgb('#e9c7a6'), 0.30, 0.25)
    pz.linea([(-61.0, -184.3), (-65.2, -184.0), (-69.6, -184.2)], 0.45, (0.40, 0.25, 0.20), 0.45, 0.2)
    # dedos doblados: dos separaciones cortas en el frente del puno
    pz.linea([(-71.8, -180.4), (-68.8, -180.8)], 0.45, (0.36, 0.22, 0.18), 0.5, 0.2)
    pz.linea([(-71.4, -177.6), (-68.6, -178.0)], 0.45, (0.36, 0.22, 0.18), 0.45, 0.2)
    # arista de los nudillos con la luz de la vela
    pz.linea([(-70.4, -185.4), (-72.0, -181.2), (-71.3, -176.6)], 0.6, rgb('#f0cda8'), 0.35, 0.25)
    # la muneca se mete en la manga: sombra
    pz.oscurecer([(-55.5, -182.5), (-58.5, -184.6), (-58.2, -174.0), (-55.2, -174.4)], 0.6, 0.6)
    return pz


def pieza_cuchara():
    pz = Pieza('cuchara', (-98, -194, -48, -158), AGARRE, 71)
    ang = math.atan2(PUNTA_CUCHARA[1] - AGARRE[1], PUNTA_CUCHARA[0] - AGARRE[0])
    ux, uy = math.cos(ang), math.sin(ang)
    nx, ny = -uy, ux
    atras = (AGARRE[0] - ux * 13, AGARRE[1] - uy * 13)
    cuello = (AGARRE[0] + ux * 16, AGARRE[1] + uy * 16)
    w0, w1 = 1.5, 1.0
    mango = [(atras[0] + nx * w0, atras[1] + ny * w0), (cuello[0] + nx * w1, cuello[1] + ny * w1),
             (cuello[0] - nx * w1, cuello[1] - ny * w1), (atras[0] - nx * w0, atras[1] - ny * w0)]
    facetar(pz, mango, 'cuchara', 10, auto=False, relieve=0.4, costuras=0.0, borde_jitter=0.05)
    cx = (cuello[0] + PUNTA_CUCHARA[0]) / 2 + ux * 1
    cy = (cuello[1] + PUNTA_CUCHARA[1]) / 2 + uy * 1
    L = math.hypot(PUNTA_CUCHARA[0] - cuello[0], PUNTA_CUCHARA[1] - cuello[1]) / 2 + 1
    pala = []
    for k in range(8):
        t = 2 * math.pi * k / 8
        a, b = L * math.cos(t), 3.0 * math.sin(t)
        pala.append((cx + ux * a + nx * b, cy + uy * a + ny * b))
    facetar(pz, pala, 'cuchara', 6, auto=False, extra=[(cx, cy)], relieve=0.5, costuras=0.08, borde_jitter=0.05)
    pz.oscurecer([(cx + ux * (L * 0.6) + nx * 1.6, cy + uy * (L * 0.6) + ny * 1.6),
                  (cx - ux * (L * 0.5) + nx * 1.4, cy - uy * (L * 0.5) + ny * 1.4),
                  (cx - ux * (L * 0.4), cy - uy * (L * 0.4)), (cx + ux * (L * 0.5), cy + uy * (L * 0.5))], 0.72)
    return pz


def pieza_cabeza():
    """Cara de perfil mirando a la izquierda, pelo por encima, y la mandibula
    cortada aparte (para insinuar que habla). Devuelve (cabeza, mandibula,
    parpado).

    La cara NO se reparte al azar: cada vertice esta puesto a mano para que los
    planos caigan donde tienen que caer (frente, arco de la ceja, puente y punta
    de la nariz, pomulo con luz, mejilla hundida, mandibula, barbilla). A este
    tamano -- 50 px de cara, 27 en una pantalla de portatil -- una faceta mal
    puesta es una mueca."""
    pz = Pieza('cabeza', (-56, -300, 30, -186), CUELLO, 81)
    piel = [(-27, -281), (-33.5, -274), (-37.2, -267), (-39.6, -260.5), (-38.2, -257.2), (-41.5, -252.5),
            (-45.5, -248), (-48.4, -244.9), (-46.2, -243.1), (-42.2, -242.8), (-39.8, -242.0), (-40.9, -240.0),
            (-40.3, -238.3), (-40.8, -237.0), (-39.3, -235.0), (-40.2, -231.8), (-37.8, -228.2), (-30, -226.5),
            (-23, -225.2), (-21, -217), (-19.5, -209), (0, -209), (2, -228), (4, -248), (2, -264), (-6, -279),
            (-15, -285)]
    extra = [(-30, -273), (-22, -270), (-34, -263), (-26, -263.5), (-31, -256.5), (-25.5, -255.5),
             (-17, -262), (-38.5, -249), (-30.5, -250.5), (-22, -251.5), (-28.5, -243.5), (-20.5, -243),
             (-36, -243.5), (-35.2, -237.8), (-25, -236.5), (-14, -240), (-12, -231), (-34.5, -231.5),
             (-9, -250), (-13, -219), (-7, -213), (-8, -262), (-14, -273)]
    facetar(pz, piel, 'piel', 9, auto=False, extra=extra, sesgo=(-0.12, 0.03, 0.0), inclinacion=0.10,
            relieve=1.1, costuras=0.10, fusion=0.35, luz_extra=0.9, gradiente=0.04)
    # cuello en sombra bajo la barbilla
    pz.oscurecer([(-37, -228.4), (-23, -225.6), (-21, -217), (-19.5, -209), (-6, -209), (-5, -224), (-18, -229.5)],
                 0.70, 0.6)
    # cuenca del ojo, pomulo con luz y mejilla hundida (lo que le hace flaco)
    pz.oscurecer([(-37.5, -258.6), (-27, -260.0), (-24.5, -254.6), (-30, -252.4), (-36, -253.8)], 0.74, 0.4)
    pz.matizar([(-36.5, -252.0), (-27, -252.6), (-23.5, -248.8), (-35, -248.2)], rgb('#f2d2b4'), 0.26, 0.4)
    pz.oscurecer([(-33.5, -247.0), (-24, -246.6), (-18.5, -240.6), (-25.5, -236.4), (-32.5, -239.2)], 0.76, 0.6)
    # ojo: una almendra minima, iris oscuro. El brillo va en su propio Sprite.
    pz.pintar([(-35.6, -255.7), (-32.8, -257.1), (-29.6, -256.1), (-32.6, -254.6)], rgb('#b3a397'), 0.9, 0.15)
    pz.circulo(OJO[0] - 0.3, OJO[1] + 0.1, 1.25, rgb('#1a120f'), 1.0, 0.12)
    pz.linea([(-36, -256.4), (-32.6, -257.6), (-29.4, -256.6)], 0.55, rgb('#3a2620'), 0.75, 0.15)   # parpado sup.
    # ceja canosa y espesa, con la cola levantada
    pz.pintar([(-40.0, -260.6), (-35.5, -262.6), (-29.5, -262.9), (-25.0, -262.0), (-28.5, -261.5),
               (-35, -260.6)], rgb('#c9c1b6'), 0.85, 0.25)
    # nariz: aleta y su sombra
    pz.circulo(-41.8, -243.6, 0.8, rgb('#4a2c24'), 0.8, 0.2)
    pz.linea([(-39.5, -245.8), (-41.8, -245.0)], 0.5, rgb('#6e4436'), 0.45, 0.2)
    # arrugas: surco nasogeniano, patas de gallo, frente
    pz.linea([(-38.4, -244.4), (-36.4, -240.4), (-35.0, -236.5)], 0.65, rgb('#5a3a30'), 0.5, 0.25)
    pz.linea([(-26.5, -256.4), (-23.0, -257.4)], 0.45, rgb('#5a3a30'), 0.35, 0.2)
    pz.linea([(-26.5, -255.0), (-23.2, -254.2)], 0.45, rgb('#5a3a30'), 0.3, 0.2)
    pz.linea([(-34.5, -271.2), (-26.5, -272.4)], 0.45, rgb('#6a473a'), 0.28, 0.25)
    pz.linea([(-36.0, -267.8), (-28, -268.6)], 0.45, rgb('#6a473a'), 0.25, 0.25)
    # boca: una linea fina, labios de viejo
    pz.linea([(-40.4, -238.3), (-37.5, -237.9), (-35.2, -237.5)], 0.75, rgb('#2e1b17'), 0.85, 0.15)
    pz.linea([(-40.0, -236.9), (-36.5, -236.6)], 0.5, rgb('#7a4a3e'), 0.4, 0.2)
    # --- pelo: largo, canoso, ondulado; tapa la oreja y cae por detras a los hombros
    pelo = [(-28.5, -279.5), (-24, -285.5), (-14, -290), (-2, -291.8), (8, -288.5), (13.5, -281), (15, -269),
            (13.8, -259), (18.2, -249), (16.6, -239), (21.6, -229), (19.2, -219), (23.6, -209), (21.4, -200),
            (24.6, -191.5), (18.8, -196.5), (15.6, -189.5), (12.2, -197.5), (8.4, -191.8), (5.2, -199.5),
            (1.8, -195.5), (-0.8, -204), (-2.4, -213), (-5.4, -224), (-4.2, -230), (-8.2, -237), (-11.6, -247),
            (-16, -256), (-21, -265), (-25.5, -272.5)]
    facetar(pz, pelo, 'pelo', 8, aniso=(1.0, 2.4), sesgo=(0.0, -0.05, 0.0), inclinacion=0.14, relieve=1.0,
            costuras=0.20, fusion=0.4, extra=[(-12, -283), (2, -284), (8, -270), (6, -250), (9, -232), (12, -214)])
    # separaciones entre mechones: cunas oscuras que siguen la caida y dejan
    # leer la melena ondulada en vez de un casco
    for (xa, ya, xb, yb, w) in ((4.5, -236, 8.4, -196, 1.3), (11, -242, 15.2, -193, 1.2), (16.5, -226, 20.5, -198, 1.0),
                                (-1.5, -226, 2.2, -200, 0.9), (0.5, -262, 4.5, -238, 0.8)):
        mx = (xa + xb) / 2 + 1.6
        pz.oscurecer([(xa, ya), (mx + w, (ya + yb) / 2), (xb + 0.4, yb), (mx - w * 0.3, (ya + yb) / 2)], 0.62, 0.35)
    # mechones: trazos finos siguiendo la caida, unos mas claros y otros mas grises
    rng = pz.rng
    for k in range(9):
        x0 = rng.uniform(-18, 10)
        y0 = -288 + abs(x0) * 0.08
        pts = []
        for j in range(8):
            t = j / 7
            y = y0 + t * rng.uniform(70, 92)
            x = x0 + t * (15 - x0) * 0.75 + math.sin(t * 7 + k) * 2.0 * t
            pts.append((x, y))
        col = rgb('#7e7a80') if k % 2 else rgb('#fbf4e8')
        pz.linea(pts, 0.5, col, 0.34 if k % 2 else 0.30, 0.3)
    # brillo calido en el pelo del lado de la vela (sobre la sien y la frente)
    pz.matizar([(-27, -276), (-20, -284), (-12, -287), (-14, -276), (-19, -266), (-24, -270)], rgb('#f6d8b0'), 0.25, 1.0)
    # la sien queda en la sombra del pelo
    pz.oscurecer([(-21, -265), (-16, -256), (-11.6, -247), (-8.2, -237), (-4.2, -230), (-5.4, -224),
                  (-2.4, -213), (-0.8, -204), (5, -206), (1, -230), (-5, -250), (-13, -262)], 0.80, 0.8)
    # --- mandibula: la parte de la cara bajo la boca, en su propia pieza
    mand_poli = [(-41.6, -238.4), (-40.8, -237.0), (-39.3, -235.0), (-40.2, -231.8), (-37.8, -228.2),
                 (-30, -226.5), (-23, -225.6), (-15, -229), (-10.5, -236), (-12, -240.2), (-22, -239.4),
                 (-30, -238.8), (-35.2, -237.9)]
    mand = pz.copia('mandibula', MANDIBULA)
    mand.recortar(mand_poli, 0.15)
    # Bajo la mandibula, en la cabeza, el hueco oscuro de la boca: solo se ve
    # cuando la mandibula baja un pelin al hablar.
    pz.pintar([(-40.5, -238.4), (-35.2, -238.0), (-30, -238.8), (-30.5, -236.4), (-36, -235.6),
               (-40.4, -236.1)], rgb('#1e110e'), 1.0, 0.1)
    # --- parpado para el parpadeo: la almendra tapada del color de la cuenca
    parp = Pieza('parpado', (-38, -260, -27, -252), CUELLO, 83)
    parp.pintar([(-35.9, -255.5), (-32.8, -257.5), (-29.2, -256.3), (-32.4, -254.3)], rgb('#8a6252'), 1.0, 0.12)
    parp.pintar([(-35.9, -255.4), (-32.4, -254.5), (-29.3, -255.6), (-32.4, -255.0)], rgb('#3a2620'), 0.8, 0.1)
    return pz, mand, parp


def pieza_pelo_espalda():
    pz = Pieza('pelo_espalda', (-6, -276, 40, -184), CUELLO, 91)
    poli = [(2, -266), (12, -271), (19, -258), (22, -246), (26.5, -236), (25.5, -226), (30, -215), (29, -205),
            (32, -196), (28, -192), (27, -185.5), (22, -191), (18.5, -186.5), (14, -193), (9, -189), (4, -198),
            (1, -212), (0, -232), (0, -250)]
    facetar(pz, poli, 'pelo_sombra', 8, aniso=(1.0, 2.4), costuras=0.2, brillo=0.85, fusion=0.4)
    return pz


def pieza_mesa():
    pz = Pieza('mesa', (-412, -170, 170, 2), (0, 0), 101)
    # sombra bajo la mesa: oscurece las piernas y el taburete que quedan detras
    sombra = pz.mascara([(-374, -130), (132, -130), (130, 0), (-372, 0)], 5.0)
    yy = (np.arange(pz.h * SS, dtype=np.float32) / SS + pz.y0)[:, None]
    grad = np.clip(0.55 - (yy + 130) / 130 * 0.25, 0.25, 0.55)
    pz.componer(np.array(rgb('#0b0706'), np.float32)[None, None, :], sombra * grad)
    # patas traseras (mas oscuras, asoman por dentro de las delanteras)
    facetar(pz, [(-372, -130), (-357, -130), (-358, -12), (-370, -12)], 'mesa_oscura', 12, aniso=(1, 5))
    facetar(pz, [(114, -130), (129, -130), (128, -12), (116, -12)], 'mesa_oscura', 12, aniso=(1, 5))
    # faldon, un poco metido
    facetar(pz, [(-392, -142), (150, -142), (150, -128), (-392, -128)], 'mesa_oscura', 14, aniso=(5, 1),
            luz_extra=1.2, inclinacion=0.1)
    # patas delanteras: cuadradas, con el chaflan de la arista
    for (xa, xb) in ((-393, -372), (130, 151)):
        facetar(pz, [(xa, -130), (xb, -130), (xb - 2, 0), (xa + 2, 0)], 'mesa', 12, aniso=(1, 5),
                sesgo=(-0.1, 0, 0), inclinacion=0.1)
        pz.matizar([(xa, -130), (xa + 4, -130), (xa + 5, 0), (xa + 2, 0)], rgb('#6e4a34'), 0.22, 0.4)
    # grueso del tablero (canto delantero)
    facetar(pz, [(-405, -150), (163, -150), (163, -141), (-405, -141)], 'mesa', 12, aniso=(6, 1),
            sesgo=(0, 0.1, 0.3), luz_extra=1.2, inclinacion=0.1)
    # tablero: la franja de arriba, a tablones
    facetar(pz, [(-400, -164), (157, -164), (163, -150), (-405, -150)], 'mesa', 12, aniso=(6, 1),
            sesgo=(0, -0.55, 0.2), luz_extra=1.25, inclinacion=0.1)
    # junta entre tablones y vetas
    pz.linea([(-402, -157.5), (160, -157.2)], 0.6, (0.10, 0.06, 0.04), 0.4, 0.3)
    rng = pz.rng
    for k in range(16):
        x = rng.uniform(-395, 150)
        y = rng.choice((-161.0, -154.0, -146.0, -135.0)) + rng.uniform(-1.2, 1.2)
        L = rng.uniform(20, 70)
        pz.linea([(x, y), (x + L * 0.5, y + rng.uniform(-0.5, 0.5)), (x + L, y + rng.uniform(-0.6, 0.6))], 0.45,
                 (0.12, 0.07, 0.05), rng.uniform(0.12, 0.25), 0.3)
    # rozaduras claras (desgaste) cerca de donde se come
    for k in range(7):
        x = rng.uniform(-150, 10)
        y = rng.uniform(-162, -152)
        pz.linea([(x, y), (x + rng.uniform(4, 12), y + rng.uniform(-0.8, 0.8))], 0.4, (0.62, 0.45, 0.32), 0.16, 0.2)
    # arista delantera iluminada por la vela: mas viva cerca de ella
    xs = np.linspace(-404, 162, 60)
    for i in range(len(xs) - 1):
        xm = (xs[i] + xs[i + 1]) / 2
        f = math.exp(-((xm - VELA_X) / 170.0) ** 2)
        if f > 0.03:
            pz.linea([(xs[i], -150.3), (xs[i + 1], -150.3)], 0.9, (0.95, 0.70, 0.46), 0.5 * f, 0.35)
    # charco de luz de la vela sobre el tablero
    luz = pz.mascara([(-300, -164), (-110, -164), (-105, -150), (-305, -150)], 0.0)
    xx = (np.arange(pz.w * SS, dtype=np.float32) / SS + pz.x0)[None, :]
    f = np.exp(-((xx - VELA_X) / 75.0) ** 2) * luz
    pz.rgb = pz.rgb * (1 - f[..., None] * 0.3) + np.array([0.60, 0.42, 0.27])[None, None, :] * pz.a[..., None] * f[
        ..., None] * 0.3
    # cera derramada al pie de la vela
    pz.pintar([(-218, -156.5), (-192, -156.8), (-188, -155.2), (-196, -154.4), (-214, -154.6)], rgb('#cdbf9f'), 0.5,
              0.3)
    return pz


def pieza_cuenco():
    """Cuenco entero (detras de la cuchara) y su pared delantera (delante)."""
    bx, by = CUENCO_BASE
    cy_borde = by - 24.0
    rx, ry = 27.0, 5.0
    pz = Pieza('cuenco', (bx - 34, by - 34, bx + 34, by + 3), CUENCO_BASE, 111)
    cuerpo = [(bx - rx, cy_borde), (bx - rx + 3, cy_borde + 9), (bx - 16, cy_borde + 18), (bx - 8, cy_borde + 21.5),
              (bx - 8, by), (bx + 8, by), (bx + 8, cy_borde + 21.5), (bx + 16, cy_borde + 18),
              (bx + rx - 3, cy_borde + 9), (bx + rx, cy_borde)]
    borde = [(bx + rx * math.cos(t), cy_borde + ry * math.sin(t)) for t in np.linspace(0, 2 * math.pi, 14,
                                                                                         endpoint=False)]
    facetar(pz, borde, 'cuenco_dentro', 10, auto=False, relieve=0.3, costuras=0.1)
    sopa = [(bx + (rx - 3.5) * math.cos(t), cy_borde + 1.2 + (ry - 1.6) * math.sin(t))
            for t in np.linspace(0, 2 * math.pi, 12, endpoint=False)]
    facetar(pz, sopa, 'sopa', 9, auto=False, extra=[(bx - 6, cy_borde + 1), (bx + 8, cy_borde + 1.5)], relieve=0.2,
            costuras=0.06, sesgo=(0, -0.6, 0.4))
    # un reflejo de la vela en el caldo
    pz.matizar([(bx - 14, cy_borde + 0.2), (bx - 5, cy_borde - 0.4), (bx - 4, cy_borde + 1.2),
                (bx - 13, cy_borde + 1.6)], rgb('#e0b070'), 0.35, 0.4)
    # pared delantera = cuerpo por debajo de la mitad delantera del borde
    frente = [(bx + rx * math.cos(t), cy_borde + ry * math.sin(t)) for t in np.linspace(0, math.pi, 9)]
    frente = frente + cuerpo[1:-1][::-1]
    facetar(pz, frente, 'cuenco', 10, auto=False, extra=[(bx - 14, cy_borde + 11), (bx + 2, cy_borde + 14),
                                                         (bx + 14, cy_borde + 10)],
            relieve=1.0, sesgo=(-0.1, 0.05, 0.1), luz_extra=1.2, fusion=0.3)
    # labio del borde con la luz
    pz.linea([(bx - rx + 0.5, cy_borde + 0.6), (bx - rx * 0.7, cy_borde + ry * 0.72), (bx - rx * 0.2, cy_borde + ry),
              (bx + rx * 0.3, cy_borde + ry * 0.95)], 0.8, (0.93, 0.72, 0.50), 0.45, 0.3)
    fr = pz.copia('cuenco_frente')
    fr.recortar(frente, 0.12)
    return pz, fr


def pieza_vela():
    pz = Pieza('vela', (VELA_X - 20, -206, VELA_X + 20, -151), (VELA_X, VELA_BASE), 121)
    x, b = VELA_X, VELA_BASE
    # platillo de hierro con su asa
    facetar(pz, [(x - 16, b - 4), (x + 16, b - 4), (x + 13, b + 1), (x - 13, b + 1)], 'hierro', 8, aniso=(3, 1),
            sesgo=(0, -0.3, 0))
    pz.linea([(x + 15, b - 3), (x + 19, b - 5), (x + 18, b - 1), (x + 14, b)], 1.0, rgb('#3a3431'), 0.9, 0.2)
    facetar(pz, [(x - 7, b - 7), (x + 7, b - 7), (x + 6, b - 3), (x - 6, b - 3)], 'hierro', 8, auto=False)
    # cirio de cera, con el borde de arriba derretido y goterones
    cirio = [(x - 5.5, b - 6), (x - 5.5, b - 35), (x - 3, b - 38.5), (x - 0.5, b - 37.2), (x + 2.5, b - 39.2),
             (x + 5.5, b - 36.5), (x + 5.5, b - 6)]
    facetar(pz, cirio, 'cera', 6, aniso=(1, 2.5), relieve=0.8, luz_extra=1.3, costuras=0.08)
    pz.pintar([(x - 5.8, b - 33), (x - 7, b - 26), (x - 6.8, b - 18), (x - 5.6, b - 17)], rgb('#efe6cf'), 0.9, 0.25)
    pz.pintar([(x + 5.6, b - 30), (x + 6.6, b - 24), (x + 5.6, b - 22)], rgb('#d8ccb0'), 0.8, 0.25)
    # la parte de arriba transluce con la llama
    luz = pz.mascara([(x - 6, b - 40), (x + 6, b - 40), (x + 6, b - 26), (x - 6, b - 26)], 2.0)
    pz.rgb = pz.rgb + np.array([0.25, 0.14, 0.04])[None, None, :] * (luz * pz.a)[..., None]
    pz.linea([(x, b - 37.5), (x + 0.3, b - 41.5)], 0.7, rgb('#1a1210'), 1.0, 0.1)   # pabilo
    pz.rgb = np.clip(pz.rgb, 0, 1)
    return pz


def pieza_llama():
    fx, fy = VELA_X + 0.3, VELA_BASE - 41.5
    pz = Pieza('llama', (fx - 5, fy - 18, fx + 5, fy + 2), (fx, fy), 131)
    exterior = [(fx, fy - 16), (fx + 1.6, fy - 11), (fx + 2.9, fy - 5), (fx + 2.4, fy - 1.2), (fx, fy + 0.6),
                (fx - 2.4, fy - 1.2), (fx - 2.9, fy - 5), (fx - 1.6, fy - 11)]
    pz.pintar(exterior, rgb('#ff9a3c'), 0.85, 0.35)
    pz.pintar([(fx, fy - 12), (fx + 1.6, fy - 5), (fx + 1.2, fy - 1.8), (fx, fy - 1), (fx - 1.2, fy - 1.8),
               (fx - 1.6, fy - 5)], rgb('#ffd68a'), 0.95, 0.3)
    pz.pintar([(fx, fy - 8), (fx + 0.9, fy - 4), (fx, fy - 2.4), (fx - 0.9, fy - 4)], rgb('#fff6dc'), 1.0, 0.25)
    pz.pintar([(fx - 1.2, fy - 1.4), (fx + 1.2, fy - 1.4), (fx + 0.6, fy + 0.4), (fx - 0.6, fy + 0.4)],
              rgb('#6a7cc0'), 0.5, 0.3)
    return pz


def textura_brillo(carpeta: str, registro: dict) -> None:
    """Brillo del ojo: un punto tibio de 1 px con un pelin de halo."""
    n = 7
    y, x = np.mgrid[0:n, 0:n].astype(np.float32) - (n - 1) / 2
    r = np.sqrt(x * x + y * y)
    a = np.clip(1.0 - r / 1.25, 0, 1) ** 1.2 + np.exp(-(r / 1.6) ** 2) * 0.25
    a = np.clip(a, 0, 1)
    out = np.zeros((n, n, 4), np.uint8)
    out[..., 0], out[..., 1], out[..., 2] = 255, 244, 222
    out[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(out, 'RGBA').save(os.path.join(carpeta, 'brillo_ojo.png'))
    registro['brillo_ojo'] = dict(archivo='brillo_ojo.png', centro=list(OJO), w=n, h=n)


def textura_halo(carpeta: str, registro: dict) -> None:
    """Halo aditivo de la vela: caida suave, sin anillo ni borde."""
    n = 256
    y, x = np.mgrid[0:n, 0:n].astype(np.float32) - (n - 1) / 2
    r = np.sqrt(x * x + y * y) / (n / 2)
    v = np.clip(1 - r, 0, 1) ** 2.2
    out = np.zeros((n, n, 4), np.uint8)
    out[..., :3] = (v[..., None] * 255).astype(np.uint8)
    out[..., 3] = (v * 255).astype(np.uint8)
    Image.fromarray(out, 'RGBA').save(os.path.join(carpeta, 'halo_vela.png'))
    registro['halo_vela'] = dict(archivo='halo_vela.png', w=n, h=n)


def generar(carpeta: str) -> dict:
    os.makedirs(carpeta, exist_ok=True)
    reg: dict = {}
    cab, mand, parp = pieza_cabeza()
    cuenco, frente = pieza_cuenco()
    piezas = [pieza_taburete(), pieza_piernas(), pieza_pelo_espalda(), pieza_brazo_lejano(), pieza_torso(),
              pieza_brazo_sup(), cab, mand, parp, pieza_mesa(), pieza_vela(), pieza_llama(), cuenco,
              pieza_antebrazo(), pieza_mano(), pieza_cuchara(), frente]
    for p in piezas:
        p.guardar(carpeta, reg)
        print(f'{p.nombre:16s} {reg[p.nombre]["w"]:4d}x{reg[p.nombre]["h"]:<4d} en ({reg[p.nombre]["x0"]}, '
              f'{reg[p.nombre]["y0"]})')
    textura_brillo(carpeta, reg)
    textura_halo(carpeta, reg)
    reg['_puntos'] = dict(fin_manga=FIN_MANGA, cadera=CADERA, cuello=CUELLO, mandibula=MANDIBULA, hombro=HOMBRO, codo=CODO,
                          muneca=MUNECA, agarre=AGARRE, punta_cuchara=PUNTA_CUCHARA, hombro_lejano=HOMBRO_LEJANO,
                          cuenco=CUENCO_BASE, labios=LABIOS, ojo=OJO, coronilla=CORONILLA, llama=LLAMA,
                          vela=(VELA_X, VELA_BASE))
    # El registro va junto al script, no junto a los PNG: la carpeta de los PNG
    # es la del repo y ahi solo tienen que ir las texturas.
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'dominus_rig.json'), 'w',
              encoding='utf-8') as f:
        json.dump(reg, f, indent=1)
    return reg


# --------------------------------------------------------------------------
# Previsualizacion en reposo (sin Godot)
# --------------------------------------------------------------------------
ORDEN_PREVIEW = ['taburete', 'piernas', 'pelo_espalda', 'brazo_lejano', 'torso_toga', 'brazo_sup', 'cabeza',
                 'mandibula', 'mesa', 'vela', 'llama', 'cuenco', 'antebrazo', 'cuchara', 'mano', 'cuenco_frente']


def componer_reposo(carpeta: str, reg: dict, fondo: Image.Image, ox: int, oy: int) -> None:
    for n in ORDEN_PREVIEW:
        r = reg[n]
        im = Image.open(os.path.join(carpeta, r['archivo'])).convert('RGBA')
        fondo.alpha_composite(im, (ox + r['x0'], oy + r['y0']))
    b = reg['brillo_ojo']
    im = Image.open(os.path.join(carpeta, b['archivo']))
    fondo.alpha_composite(im, (int(round(ox + b['centro'][0] - b['w'] / 2 + 0.5)),
                               int(round(oy + b['centro'][1] - b['h'] / 2 + 0.5))))


# --------------------------------------------------------------------------
# Escena de Godot
# --------------------------------------------------------------------------
def escribir_escena(reg: dict, ruta: str, res_png: str = 'res://assets/characters/dominus') -> None:
    P = reg['_puntos']

    def v(x, y):
        return f'Vector2({x:g}, {y:g})'

    def rel(a, b):
        return v(round(a[0] - b[0], 3), round(a[1] - b[1], 3))

    def off(nombre, piv):
        r = reg[nombre]
        return v(r['x0'] - piv[0], r['y0'] - piv[1])

    texturas = ['taburete', 'piernas', 'pelo_espalda', 'brazo_lejano', 'torso_toga', 'brazo_sup', 'cabeza',
                'mandibula', 'parpado', 'brillo_ojo', 'mesa', 'vela', 'llama', 'cuenco', 'antebrazo', 'mano', 'cuchara',
                'cuenco_frente', 'halo_vela']
    ids = {t: f'{i + 3}_{t}' for i, t in enumerate(texturas)}
    L = ['[gd_scene load_steps=%d format=3]' % (len(texturas) + 4), '',
         '[ext_resource type="Script" path="res://scripts/characters/dominus.gd" id="1_dominus"]',
         '[ext_resource type="Script" path="res://scripts/flicker_glow.gd" id="2_glow"]']
    for t in texturas:
        L.append(f'[ext_resource type="Texture2D" path="{res_png}/{reg[t]["archivo"]}" id="{ids[t]}"]')
    L += ['', '[sub_resource type="CanvasItemMaterial" id="CanvasItemMaterial_suma"]', 'blend_mode = 1', '']

    def sprite(nombre, padre, tex, pos=None, offset=None, extra=()):
        s = [f'[node name="{nombre}" type="Sprite2D" parent="{padre}"]']
        if pos is not None:
            s.append(f'position = {pos}')
        s.append(f'texture = ExtResource("{ids[tex]}")')
        if offset is not None:
            s.append('centered = false')
            s.append(f'offset = {offset}')
        s += list(extra)
        return s + ['']

    def nodo(nombre, padre, tipo='Node2D', pos=None, extra=()):
        s = [f'[node name="{nombre}" type="{tipo}" parent="{padre}"]']
        if pos is not None:
            s.append(f'position = {pos}')
        s += list(extra)
        return s + ['']

    L += ['[node name="Dominus" type="Node2D"]', 'script = ExtResource("1_dominus")', '']
    L += sprite('Taburete', '.', 'taburete', offset=off('taburete', (0, 0)))
    L += sprite('Piernas', '.', 'piernas', offset=off('piernas', (0, 0)))
    L += nodo('Cuerpo', '.', pos=v(*P['cadera']))
    L += nodo('PeloEspalda', 'Cuerpo', pos=rel(P['cuello'], P['cadera']))
    L += sprite('Sprite', 'Cuerpo/PeloEspalda', 'pelo_espalda', offset=off('pelo_espalda', P['cuello']))
    L += nodo('BrazoLejano', 'Cuerpo', pos=rel(P['hombro_lejano'], P['cadera']))
    L += sprite('Sprite', 'Cuerpo/BrazoLejano', 'brazo_lejano', offset=off('brazo_lejano', P['hombro_lejano']))
    L += nodo('ManoLejana', 'Cuerpo/BrazoLejano', 'Marker2D', pos=rel(P['mano_lejana'], P['hombro_lejano']))
    L += sprite('Torso', 'Cuerpo', 'torso_toga', offset=off('torso_toga', P['cadera']))
    L += nodo('Hombro', 'Cuerpo', pos=rel(P['hombro'], P['cadera']))
    L += sprite('BrazoSup', 'Cuerpo/Hombro', 'brazo_sup', offset=off('brazo_sup', P['hombro']))
    L += nodo('Codo', 'Cuerpo/Hombro', pos=rel(P['codo'], P['hombro']))
    L += nodo('RemotoAntebrazo', 'Cuerpo/Hombro/Codo', 'RemoteTransform2D',
              extra=['remote_path = NodePath("../../../../BrazoCerca/Antebrazo")', 'update_scale = false'])
    L += nodo('Muneca', 'Cuerpo/Hombro/Codo', pos=rel(P['muneca'], P['codo']))
    L += nodo('RemotoMano', 'Cuerpo/Hombro/Codo/Muneca', 'RemoteTransform2D',
              extra=['remote_path = NodePath("../../../../../BrazoCerca/Mano")', 'update_scale = false'])
    L += nodo('Punta', 'Cuerpo/Hombro/Codo/Muneca', 'Marker2D', pos=rel(P['punta_cuchara'], P['muneca']))
    L += nodo('Cabeza', 'Cuerpo', pos=rel(P['cuello'], P['cadera']))
    L += sprite('Sprite', 'Cuerpo/Cabeza', 'cabeza', offset=off('cabeza', P['cuello']))
    L += nodo('Mandibula', 'Cuerpo/Cabeza', pos=rel(P['mandibula'], P['cuello']))
    L += sprite('Sprite', 'Cuerpo/Cabeza/Mandibula', 'mandibula', offset=off('mandibula', P['mandibula']))
    L += sprite('Parpado', 'Cuerpo/Cabeza', 'parpado', offset=off('parpado', P['cuello']), extra=['visible = false'])
    L += sprite('Brillo', 'Cuerpo/Cabeza', 'brillo_ojo', pos=rel(P['ojo'], P['cuello']))
    L += nodo('Labios', 'Cuerpo/Cabeza', 'Marker2D', pos=rel(P['labios'], P['cuello']))
    L += nodo('Coronilla', 'Cuerpo/Cabeza', 'Marker2D', pos=rel(P['coronilla'], P['cuello']))
    L += sprite('Mesa', '.', 'mesa', offset=off('mesa', (0, 0)))
    L += nodo('Vela', '.', pos=v(*P['vela']))
    L += sprite('Sprite', 'Vela', 'vela', offset=off('vela', P['vela']))
    llama_piv = reg['llama']['pivote']
    L += nodo('Llama', 'Vela', pos=rel(llama_piv, P['vela']))
    L += sprite('Sprite', 'Vela/Llama', 'llama', offset=off('llama', llama_piv))
    L += nodo('Cuenco', '.', pos=v(*P['cuenco']))
    L += sprite('Sprite', 'Cuenco', 'cuenco', offset=off('cuenco', P['cuenco']))
    L += nodo('BrazoCerca', '.')
    L += sprite('Antebrazo', 'BrazoCerca', 'antebrazo', pos=v(*P['codo']), offset=off('antebrazo', P['codo']))
    L += sprite('Mano', 'BrazoCerca', 'mano', pos=v(*P['muneca']), offset=off('mano', P['muneca']))
    # La cuchara cuelga de un eje girado a lo largo del mango: escalar ese eje
    # en x la acorta en SU direccion, que es como se ve girar una cuchara de
    # perfil (pasa por un punto y sale del otro lado). El Sprite lleva el giro
    # contrario para quedarse dibujado tal cual.
    ang = math.atan2(P['punta_cuchara'][1] - P['agarre'][1], P['punta_cuchara'][0] - P['agarre'][0])
    L += nodo('EjeCuchara', 'BrazoCerca/Mano', pos=rel(P['agarre'], P['muneca']),
              extra=[f'rotation = {ang:.6f}', 'show_behind_parent = true'])
    L += sprite('Cuchara', 'BrazoCerca/Mano/EjeCuchara', 'cuchara', offset=off('cuchara', P['agarre']),
                extra=[f'rotation = {-ang:.6f}'])
    L += sprite('CuencoFrente', '.', 'cuenco_frente', pos=v(*P['cuenco']), offset=off('cuenco_frente', P['cuenco']))
    L += sprite('Halo', '.', 'halo_vela', pos=v(P['llama'][0], P['llama'][1] + 2),
                extra=['material = SubResource("CanvasItemMaterial_suma")', 'scale = Vector2(1.5, 1.5)',
                       'modulate = Color(1, 0.72, 0.42, 0.3)', 'script = ExtResource("2_glow")', 'noise_seed = 71',
                       'position_vibration = 1.5', 'base_alpha = 0.26'])
    with open(ruta, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(L))
    print('escena ->', ruta)


MAGNUS_HOJA = os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', '..', 'assets', 'characters', 'magnus',
                           'magnus_respirando.png')


def preview_estatico(carpeta: str, reg: dict, ruta: str) -> None:
    """Dominus en reposo junto a un fotograma de Magnus en reposo, los dos sobre
    la misma linea de suelo y a escala de juego, sobre un fondo ambar oscuro
    como el del titulo. Guarda tambien la version a 0,53 (lo que se ve en una
    pantalla de 1536x864)."""
    W, H, SUELO = 1320, 560, 500
    y = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    fondo = (np.array(rgb('#2e2016'))[None, None, :] * (1 - y) + np.array(rgb('#1c130d'))[None, None, :] * y)         * np.ones((H, W, 1), np.float32)
    xx, yy = np.meshgrid(np.arange(W, dtype=np.float32), np.arange(H, dtype=np.float32))
    ox = 930
    fx, fy = ox + LLAMA[0], SUELO + LLAMA[1]
    d = np.sqrt(((xx - fx) / 420) ** 2 + ((yy - fy) / 300) ** 2)
    fondo += np.array([0.20, 0.12, 0.05])[None, None, :] * np.exp(-d * d * 2.2)[..., None]
    fondo[SUELO:] = fondo[SUELO:] * 0.55
    fondo[SUELO:SUELO + 2] *= 0.7
    img = Image.fromarray((np.clip(fondo, 0, 1) * 255).astype(np.uint8), 'RGB').convert('RGBA')
    # Magnus: casilla de 292x360 con el sprite desplazado -165 (pies en el origen)
    hoja = Image.open(MAGNUS_HOJA).convert('RGBA')
    mag = hoja.crop((0, 0, 292, 360))
    mx = 250
    img.alpha_composite(mag, (mx - 146, SUELO - 345))
    componer_reposo(carpeta, reg, img, ox, SUELO)
    # halo aditivo de la vela, como en Godot (modulate 1, .72, .42 a ~0.3)
    arr = np.asarray(img, np.float32) / 255.0
    d = np.sqrt((xx - fx) ** 2 + (yy - fy - 2) ** 2) / (128 * 1.5)
    halo = np.clip(1 - d, 0, 1) ** 2.2 * 0.3
    arr[..., :3] += halo[..., None] * np.array([1.0, 0.72, 0.42])[None, None, :] * halo[..., None] ** 0
    img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), 'RGBA')
    img.save(ruta)
    img.resize((int(W * 0.53), int(H * 0.53)), Image.LANCZOS).save(ruta.replace('.png', '_053.png'))
    print('preview ->', ruta)


if __name__ == '__main__':
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(1)
    carpeta = args[0]
    reg = generar(carpeta)
    if '--escena' in args:
        escribir_escena(reg, args[args.index('--escena') + 1])
    if '--preview' in args:
        preview_estatico(carpeta, reg, args[args.index('--preview') + 1])

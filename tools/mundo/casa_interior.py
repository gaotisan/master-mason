"""Casa de Dominus, interior: la sala pequena y abarrotada del relato.

    python casa_interior.py <carpeta_salida> [--solo-sprites]

(la carpeta de salida es assets/world/casa_interior del proyecto)

Genera el decorado de una sola pantalla (2912x1632, camara fija) y las piezas
que se mueven por separado. Todo lo quieto va horneado en el fondo; lo que se
anima (puerta, pendulo, humo, fuego, burbujas, halos) sale en PNG pequenos.

COMO SE PINTA. No es un render 3D ni un collage: son poligonos planos, como
las facetas del abrigo de Magnus, pero iluminados como un cuadro.

  1. Cada objeto se rellena con FACETAS: una triangulacion de Delaunay sobre
     puntos en rejilla temblada, y cada triangulo se colorea con el color base
     mas una pizca de azar y un sombreado segun su "normal" fingida (esfera,
     cilindro, plano...). Es lo que hace que el decorado case con el personaje
     de poligonos en vez de parecer una foto pegada detras.
  2. Se pinta a S veces el tamano y se reduce con Lanczos: antialias.
  3. Luego se ilumina por pixel con las luces de la sala (chimenea, brasero,
     velas, luna por la puerta): charcos de luz de caida suave, de pintor. La luz de
     cada pixel multiplica al color; la de cada faceta solo la matiza. Asi la
     luz es continua y el poligono se sigue leyendo.
  4. Texturas por material (yeso con grietas, veta de madera, piedra), sombras
     de contacto, resplandor (bloom) de lo que emite, vineta y grano.

Las mismas luces viven tambien en el script de Godot (tono_luz) para que el
nivel pueda tintar a los personajes igual que al decorado.

Coordenadas: las de la pantalla. Suelo de los personajes en y = 1200; la
union pared-suelo esta algo mas arriba (PARED_Y) para que lo que se apoya en
la pared quede DETRAS de los pies de Magnus y no a su altura.
"""
from __future__ import annotations

import math
import os
import random
import sys
from dataclasses import dataclass

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage
from scipy.spatial import Delaunay

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pincel import EstiloArbol, generar_arbol, ruido_valor  # noqa: E402

W, H = 2912, 1632
S = 2                  # sobremuestreo de los poligonos
PARED_Y = 1150         # union pared-suelo (los muebles de pared apoyan aqui)
SUELO_Y = 1200         # linea de pies de los personajes
TECHO_Y = 196          # donde acaba la viga y empieza la pared
FUGA = (1456.0, -1300.0)   # punto de fuga de las tablas del suelo: perspectiva suave
PIVOTE = (1450.0, 40.0)    # pendulo
LARGO_PENDULO = 850.0


# --------------------------------------------------------------------------
# Color y materiales
# --------------------------------------------------------------------------

def c(h: str, k: float = 1.0) -> np.ndarray:
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32) * k


def a255(col) -> tuple[int, int, int]:
    col = np.clip(np.asarray(col, np.float32), 0, 1)
    return tuple(int(round(v * 255)) for v in col)


# Materiales: deciden textura y respuesta a la luz.
M_NADA, M_YESO, M_MADERA, M_MADERA_V, M_HIERRO, M_COBRE, M_PIEDRA, M_SUELO, \
    M_TELA, M_CRISTAL, M_PAPEL, M_TECHO, M_EXTERIOR, M_CERA, M_HOLLIN = range(15)

YESO = c('#9a7550')
MADERA = c('#6a4428')
MADERA_OSC = c('#3e2616')
HIERRO = c('#2e2a28')
COBRE = c('#b0673a')
LATON = c('#a8844a')
PIEDRA = c('#5a4c3e')
SUELO_COL = c('#5a3c24')
CERA = c('#e8d6a8')



# --------------------------------------------------------------------------
# Luces (tambien en casa_interior_decorado.gd; si se tocan aqui, alli igual)
# --------------------------------------------------------------------------

@dataclass
class Luz:
    nombre: str
    x: float
    y: float
    z: float           # hacia la camara, para el sombreado de las facetas
    color: np.ndarray
    potencia: float
    radio: float       # donde la luz cae a la mitad


LUCES = [
    Luz('chimenea', 2790, 1030, 90, c('#ff9a4a'), 2.7, 400),
    Luz('brasero', 2548, 1085, 140, c('#ff7a36'), 1.5, 200),
    Luz('vela_organo_i', 455, 792, 50, c('#ffc27a'), 1.05, 150),
    Luz('vela_organo_d', 785, 792, 50, c('#ffc27a'), 1.05, 150),
    Luz('candil', 1180, 668, 40, c('#ffbf78'), 0.95, 140),
    Luz('lamparilla', 1312, 1000, 60, c('#ffb870'), 0.7, 90),
    Luz('vela_manto_i', 2676, 640, 50, c('#ffc27a'), 0.8, 140),
    Luz('vela_manto_d', 2846, 640, 50, c('#ffc27a'), 0.8, 140),
    # Luz de la mesa: la pone el otro decorado (vela sobre la mesa), pero la
    # pared de detras tiene que estar ya iluminada para que Dominus se lea.
    Luz('mesa', 2150, 940, 220, c('#ffb468'), 1.05, 280),
    Luz('luna', 245, 990, 60, c('#7d9fe0'), 0.45, 160),
]
AMBIENTE = c('#2a1c14') * 0.38
CAIDA = 1.6   # exponente de la caida: mas alto = charcos de luz mas cerrados
EXPOSICION = 1.45   # curva de tono final: 1 - exp(-luz * EXPOSICION)


def luz_rgb(x: np.ndarray, y: np.ndarray) -> np.ndarray:
    """Luz que llega a cada pixel (x, y). Caida r^2 / (r^2 + d^2) con
    exponente 1,3: cola larga, como la luz pintada, sin el pinchazo del
    inverso del cuadrado."""
    out = np.zeros(x.shape + (3,), np.float32) + AMBIENTE
    for l in LUCES:
        d2 = (x - l.x) ** 2 + (y - l.y) ** 2
        f = l.potencia * (l.radio ** 2 / (l.radio ** 2 + d2)) ** CAIDA
        out += f[..., None] * l.color
    return out


def intensidad_luces(cx: float, cy: float) -> list[float]:
    res = []
    for l in LUCES:
        d2 = (cx - l.x) ** 2 + (cy - l.y) ** 2
        res.append(l.potencia * (l.radio ** 2 / (l.radio ** 2 + d2)) ** CAIDA)
    return res


def factor_faceta(n, cx: float, cy: float, brillo: float = 0.0, dureza: float = 10.0) -> float:
    """Cuanto mas (o menos) luz recibe una faceta de normal n que una de cara a
    la camara en el mismo sitio. Half-Lambert para que lo que mira de lado no
    se vaya a negro de golpe.

    brillo > 0 anade un reflejo especular (Blinn) POR FACETA: en el metal solo
    se encienden las facetas que miran entre la luz y la camara, y el resto se
    queda oscuro. Un brillo uniforme sobre todo el objeto lo aplana y el hierro
    parece piedra gris."""
    n = np.asarray(n, np.float32)
    n = n / (np.linalg.norm(n) + 1e-6)
    num = den = 1e-6
    esp = 0.0
    for l, w in zip(LUCES, intensidad_luces(cx, cy)):
        d = np.array([l.x - cx, l.y - cy, l.z], np.float32)
        d /= np.linalg.norm(d) + 1e-6
        hl = (float(np.dot(n, d)) * 0.5 + 0.5) ** 2
        h0 = (float(d[2]) * 0.5 + 0.5) ** 2
        num += w * hl
        den += w * h0
        if brillo:
            mitad = d + np.array([0, 0, 1], np.float32)
            mitad /= np.linalg.norm(mitad) + 1e-6
            esp += w * max(0.0, float(np.dot(n, mitad))) ** dureza
    f = num / den
    if brillo:
        f = f + brillo * esp / den
        return float(np.clip(f, 0.2, 4.0))
    return float(np.clip(f, 0.3, 2.2))


BRILLO_MAT = {M_HIERRO: 1.1, M_COBRE: 1.4, M_CRISTAL: 0.8}


# Normales fingidas
def n_plano(x, y):
    return (0.0, 0.0, 1.0)


def n_esfera(cx, cy, rx, ry):
    def f(x, y):
        u, v = (x - cx) / rx, (y - cy) / ry
        r2 = min(u * u + v * v, 0.98)
        return (u, v, math.sqrt(1 - r2))
    return f


def n_cil_v(cx, rx, inclina=0.0):
    def f(x, y):
        u = max(-0.99, min(0.99, (x - cx) / rx))
        return (u, inclina, math.sqrt(1 - u * u))
    return f


def n_cil_h(cy, ry):
    def f(x, y):
        v = max(-0.99, min(0.99, (y - cy) / ry))
        return (0.0, v, math.sqrt(1 - v * v))
    return f


def n_fija(nx, ny, nz):
    return lambda x, y: (nx, ny, nz)


# --------------------------------------------------------------------------
# Lienzo de pintura
# --------------------------------------------------------------------------

class Pintor:
    """Capas a S veces el tamano:
      alb   color de superficie ya matizado por faceta (antes de la luz)
      mat   material
      emi   lo que brilla por si solo (llama, brasa, cristal con luz detras)
      alto  cuanto sobresale de la pared (para las sombras de contacto)
      cob   cobertura (alfa, para los sprites)
    ox, oy: donde cae el pixel (0,0) de este lienzo en coordenadas de pantalla.
    Todas las funciones de dibujo reciben coordenadas de PANTALLA."""

    def __init__(self, w: int, h: int, ox: float = 0, oy: float = 0, semilla: int = 1):
        self.w, self.h, self.ox, self.oy = w, h, ox, oy
        size = (w * S, h * S)
        self.alb = Image.new('RGB', size, (0, 0, 0))
        self.mat = Image.new('L', size, 0)
        self.emi = Image.new('RGB', size, (0, 0, 0))
        self.alto = Image.new('L', size, 0)
        self.cob = Image.new('L', size, 0)
        self.d = {k: ImageDraw.Draw(getattr(self, k)) for k in ('alb', 'mat', 'emi', 'alto', 'cob')}
        self.rnd = random.Random(semilla)

    def _p(self, pts):
        return [((x - self.ox) * S, (y - self.oy) * S) for x, y in pts]

    # -- primitivas planas ---------------------------------------------------
    def poli(self, pts, col, mat=M_MADERA, emi=None, alto=None, luz_local=True, normal=None):
        """Poligono de un solo color. Si luz_local, se matiza con la normal (plano
        por defecto) en su centro."""
        P = self._p(pts)
        if luz_local and normal is not None:
            cx = sum(p[0] for p in pts) / len(pts)
            cy = sum(p[1] for p in pts) / len(pts)
            col = np.asarray(col) * factor_faceta(normal(cx, cy), cx, cy, BRILLO_MAT.get(mat, 0.0))
        self.d['alb'].polygon(P, fill=a255(col))
        self.d['mat'].polygon(P, fill=mat)
        self.d['emi'].polygon(P, fill=a255(emi) if emi is not None else (0, 0, 0))
        if alto is not None:
            self.d['alto'].polygon(P, fill=int(alto))
        self.d['cob'].polygon(P, fill=255)

    def elipse(self, cx, cy, rx, ry, col, mat=M_MADERA, emi=None, alto=None):
        pts = [(cx + rx * math.cos(t), cy + ry * math.sin(t)) for t in np.linspace(0, 2 * math.pi, 48, endpoint=False)]
        self.poli(pts, col, mat, emi, alto, luz_local=False)

    def linea(self, pts, ancho, col, mat=M_MADERA, emi=None, alto=None):
        P = self._p(pts)
        wpx = max(1, int(round(ancho * S)))
        self.d['alb'].line(P, fill=a255(col), width=wpx, joint='curve')
        self.d['mat'].line(P, fill=mat, width=wpx, joint='curve')
        self.d['emi'].line(P, fill=a255(emi) if emi is not None else (0, 0, 0), width=wpx, joint='curve')
        if alto is not None:
            self.d['alto'].line(P, fill=int(alto), width=wpx, joint='curve')
        self.d['cob'].line(P, fill=255, width=wpx, joint='curve')

    def cadena(self, x0, y0, x1, y1, eslabon=9, grueso=2.2, col=HIERRO):
        """Cadena: elipses alternas (de frente y de canto) a lo largo del tramo."""
        largo = math.hypot(x1 - x0, y1 - y0)
        n = max(2, int(largo / eslabon))
        ang = math.atan2(y1 - y0, x1 - x0)
        for i in range(n):
            t = (i + 0.5) / n
            px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            a = eslabon * 0.62
            b = eslabon * (0.34 if i % 2 == 0 else 0.12)
            pts = [(px + math.cos(ang) * a * math.cos(u) - math.sin(ang) * b * math.sin(u),
                    py + math.sin(ang) * a * math.cos(u) + math.cos(ang) * b * math.sin(u))
                   for u in np.linspace(0, 2 * math.pi, 14)]
            k = 1.25 if i % 2 == 0 else 0.8
            self.linea(pts, grueso, np.asarray(col) * k, M_HIERRO)

    # -- facetas ---------------------------------------------------------------
    def facetas(self, pts, col, mat=M_MADERA, tam=40.0, var=0.05, normal=n_plano,
                emi=None, alto=None, dir_var=None, tono_var=0.0, brillo=None, dureza=10.0):
        """Rellena el poligono con triangulos de Delaunay, cada uno con su tono.
        tam: lado medio de faceta en px de pantalla. var: azar de valor.
        tono_var: azar de matiz (hacia rojo/amarillo), para el abrigo de retales."""
        if brillo is None:
            brillo = BRILLO_MAT.get(mat, 0.0)
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        x0, y0 = math.floor(min(xs)) - 2, math.floor(min(ys)) - 2
        x1, y1 = math.ceil(max(xs)) + 2, math.ceil(max(ys)) + 2
        w, h = int(x1 - x0), int(y1 - y0)
        if w <= 0 or h <= 0:
            return
        if min(w, h) < tam * 1.6:
            # franja estrecha: con el azar entero las facetas alternan claro y
            # oscuro a lo largo del borde y sale un diente de sierra
            var *= 0.45
            tono_var *= 0.45
        mask = Image.new('L', (w * S, h * S), 0)
        ImageDraw.Draw(mask).polygon([((x - x0) * S, (y - y0) * S) for x, y in pts], fill=255)
        capa = Image.new('RGB', (w * S, h * S), a255(col))
        dcap = ImageDraw.Draw(capa)
        rnd = self.rnd
        # Rejilla temblada: facetas de tamano parecido, como las del abrigo.
        puntos = []
        paso = max(tam, 6.0)
        ny_, nx_ = int(h / (paso * 0.87)) + 2, int(w / paso) + 2
        for j in range(ny_ + 1):
            for i in range(nx_ + 1):
                px = x0 + (i + (0.5 if j % 2 else 0.0)) * paso + rnd.uniform(-0.38, 0.38) * paso
                py = y0 + j * paso * 0.87 + rnd.uniform(-0.38, 0.38) * paso
                puntos.append((px, py))
        puntos += [(x0 - 2, y0 - 2), (x1 + 2, y0 - 2), (x0 - 2, y1 + 2), (x1 + 2, y1 + 2)]
        tri = Delaunay(np.array(puntos))
        P = tri.points
        for s in tri.simplices:
            a, b, cc = P[s[0]], P[s[1]], P[s[2]]
            cx, cy = (a[0] + b[0] + cc[0]) / 3, (a[1] + b[1] + cc[1]) / 3
            k = 1.0 + rnd.gauss(0, var)
            colt = np.asarray(col, np.float32) * k
            if tono_var:
                t = rnd.gauss(0, tono_var)
                colt = colt * np.array([1 + t, 1 + t * 0.4, 1 - t * 0.6], np.float32)
            colt = colt * factor_faceta(normal(cx, cy), cx, cy, brillo, dureza)
            dcap.polygon([((q[0] - x0) * S, (q[1] - y0) * S) for q in (a, b, cc)], fill=a255(colt))
        off = (int(round((x0 - self.ox) * S)), int(round((y0 - self.oy) * S)))
        self.alb.paste(capa, off, mask)
        self.mat.paste(Image.new('L', mask.size, mat), off, mask)
        self.emi.paste(Image.new('RGB', mask.size, a255(emi) if emi is not None else (0, 0, 0)), off, mask)
        if alto is not None:
            self.alto.paste(Image.new('L', mask.size, int(alto)), off, mask)
        self.cob.paste(Image.new('L', mask.size, 255), off, mask)

    def rect(self, x0, y0, x1, y1, col, mat=M_MADERA, tam=30, var=0.05, normal=n_plano, **kw):
        self.facetas([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], col, mat, tam, var, normal, **kw)

    # -- revelado ----------------------------------------------------------
    def reducir(self):
        """Pasa las capas a tamano final: float32."""
        def red(img, filtro=Image.LANCZOS):
            return img.resize((self.w, self.h), filtro)
        alb = np.asarray(red(self.alb), np.float32) / 255.0
        emi = np.asarray(red(self.emi), np.float32) / 255.0
        mat = np.asarray(self.mat.resize((self.w, self.h), Image.NEAREST), np.int32)
        alto = np.asarray(red(self.alto, Image.BILINEAR), np.float32) / 255.0
        cob = np.asarray(red(self.cob), np.float32) / 255.0
        return alb, emi, mat, alto, cob


# --------------------------------------------------------------------------
# Utilidades de forma
# --------------------------------------------------------------------------

def arco(cx, cy, rx, ry, a0, a1, n=24):
    return [(cx + rx * math.cos(t), cy + ry * math.sin(t)) for t in np.linspace(a0, a1, n)]


def puerta_tablas(p: Pintor, x0, y0, x1, y1, col=MADERA_OSC, tablas=4, arco_sup=0.0,
                  herrajes=True, anilla=True, lado_bisagra='izq', tam=26):
    """Hoja de puerta de tablas verticales, con remate en arco apuntado si
    arco_sup > 0 (alto del arco en px)."""
    ancho = x1 - x0
    for i in range(tablas):
        a, b = x0 + ancho * i / tablas, x0 + ancho * (i + 1) / tablas
        k = 1.0 + (0.07 if i % 2 else -0.04) + p.rnd.uniform(-0.03, 0.03)
        if arco_sup > 0:
            # altura de la tabla segun el arco apuntado (dos arcos que se cortan)
            def ytop(x):
                u = (x - x0) / ancho
                return y0 + arco_sup * (1 - math.sqrt(max(0.0, 1 - (1 - 2 * abs(u - 0.5)) ** 2 * 0.0 - (2 * abs(u - 0.5)) ** 2)))
            pts = [(a, ytop(a))] + [(x, ytop(x)) for x in np.linspace(a, b, 6)] + [(b, y1), (a, y1)]
        else:
            pts = [(a, y0), (b, y0), (b, y1), (a, y1)]
        p.facetas(pts, col * k, M_MADERA_V, tam=tam, var=0.05)
        p.linea([(a, y0 + (arco_sup if arco_sup else 0) * 0.3), (a, y1)], 1.6, col * 0.45, M_MADERA_V)
    if herrajes:
        for fy in (0.22, 0.78):
            yy = y0 + (y1 - y0) * fy
            if lado_bisagra == 'izq':
                xa, xb = x0, x0 + ancho * 0.62
            else:
                xa, xb = x1 - ancho * 0.62, x1
            g = max(4.0, (y1 - y0) * 0.022)
            p.poli([(xa, yy - g), (xb, yy - g * 0.6), (xb + g, yy), (xb, yy + g * 0.6), (xa, yy + g)],
                   HIERRO * 1.1, M_HIERRO, alto=40)
            for k2 in range(3):
                cx = xa + (xb - xa) * (0.15 + 0.3 * k2)
                p.elipse(cx, yy, g * 0.28, g * 0.28, HIERRO * 1.8, M_HIERRO)
    if anilla:
        ax = x1 - ancho * 0.18 if lado_bisagra == 'izq' else x0 + ancho * 0.18
        ay = y0 + (y1 - y0) * 0.55
        r = max(5.0, ancho * 0.06)
        p.elipse(ax, ay - r * 0.9, r * 0.35, r * 0.35, HIERRO * 1.4, M_HIERRO)
        p.linea(arco(ax, ay, r, r * 1.05, 0, 2 * math.pi, 20), max(1.8, r * 0.28), HIERRO * 1.6, M_HIERRO, alto=40)


def marco(p: Pintor, x0, y0, x1, y1, g, col=MADERA, alto=80, dintel_extra=0):
    """Marco de madera alrededor de un hueco (x0..x1, y0..y1) con grosor g."""
    p.rect(x0 - g, y0, x0, y1, col * 0.9, M_MADERA_V, tam=22, alto=alto)
    p.rect(x1, y0, x1 + g, y1, col * 0.8, M_MADERA_V, tam=22, alto=alto)
    p.rect(x0 - g - dintel_extra, y0 - g, x1 + g + dintel_extra, y0, col * 1.05, M_MADERA, tam=22, alto=alto)


# --------------------------------------------------------------------------
# Piezas del decorado
# --------------------------------------------------------------------------

def pintar_techo(p: Pintor):
    rnd = p.rnd
    p.rect(0, 0, W, TECHO_Y, MADERA_OSC * 0.7, M_TECHO, tam=70, var=0.07)
    # Tablas del techo (se ven de canto, lineas horizontales oscuras)
    for y in (22, 48, 76, 100):
        p.linea([(0, y), (W, y + rnd.uniform(-3, 3))], 2.0, MADERA_OSC * 0.35, M_TECHO)
    # Cabezas de las vigas que vienen hacia nosotros: rectangulos de testa
    x = 60
    while x < W:
        w = rnd.uniform(40, 66)
        y0 = rnd.uniform(88, 120)
        p.rect(x, y0, x + w, TECHO_Y - 36, MADERA * rnd.uniform(0.5, 0.75), M_MADERA, tam=16, var=0.08,
               normal=n_fija(0.0, 0.25, 1.0), alto=120)
        p.linea([(x, TECHO_Y - 37), (x + w, TECHO_Y - 37)], 3, MADERA_OSC * 0.4, M_MADERA)
        x += rnd.uniform(150, 260)
    # Viga maestra encima de la pared
    p.rect(0, TECHO_Y - 38, W, TECHO_Y, MADERA * 1.05, M_MADERA, tam=30, var=0.06,
           normal=n_cil_h(TECHO_Y - 19, 30), alto=150)
    p.linea([(0, TECHO_Y), (W, TECHO_Y)], 3, MADERA_OSC * 0.3, M_MADERA)


def pintar_pared(p: Pintor):
    p.rect(0, TECHO_Y, W, PARED_Y, YESO, M_YESO, tam=95, var=0.045, tono_var=0.02)
    # Entramado: postes y tornapuntas. Uno de ellos no apoya en nada.
    for x0, x1 in ((378, 404), (1858, 1886), (2632, 2660)):
        p.rect(x0, TECHO_Y, x1, PARED_Y, MADERA * 0.85, M_MADERA_V, tam=24, var=0.06, alto=60)
    p.poli([(1886, 520), (1886, 470), (2070, TECHO_Y), (2106, TECHO_Y)], MADERA * 0.8, M_MADERA, alto=60)
    # Tornapunta que nace del poste y muere en mitad de la pared (mal)
    p.poli([(404, 640), (404, 600), (470, 540), (484, 556)], MADERA * 0.8, M_MADERA, alto=60)
    # Rodapie
    p.rect(0, PARED_Y - 26, W, PARED_Y, MADERA_OSC * 0.9, M_MADERA, tam=24, alto=50)


def pintar_exterior(p: Pintor, x0, y0, x1, y1):
    """Lo que se ve por la puerta: la noche del bosque, en los mismos azules
    que las capas de siluetas del exterior."""
    rnd = random.Random(31)
    h = y1 - y0
    for i in range(24):
        ya = y0 + h * i / 24
        yb = y0 + h * (i + 1) / 24 + 1
        t = min(1.0, (i / 24) / 0.62) ** 1.4
        col = c('#16213d') * (1 - t) + c('#4a6a9a') * t
        p.poli([(x0, ya), (x1, ya), (x1, yb), (x0, yb)], col, M_EXTERIOR, emi=col * 0.9, luz_local=False)
    # Arboles lejanos y cercanos en silueta
    for capa, (col, base, alto, grosor) in enumerate([(c('#384b71'), y0 + h * 0.72, h * 0.62, 5),
                                                     (c('#232f4c'), y0 + h * 0.78, h * 0.85, 8)]):
        lz = Image.new('L', ((x1 - x0) * S, (y1 - y0) * S), 0)
        dz = ImageDraw.Draw(lz)
        x = x0 + rnd.uniform(-20, 30)
        while x < x1 + 30:
            ramas = generar_arbol(x - x0, base - y0, alto * rnd.uniform(0.7, 1.05), grosor,
                                  EstiloArbol(niveles=5, copa_estrecha=0.8), rnd)
            for r in ramas:
                dz.line([(r.x0 * S, r.y0 * S), (r.x1 * S, r.y1 * S)], fill=255, width=max(1, int(r.w0 * S)))
            x += rnd.uniform(45, 90) * (1 + capa * 0.5)
        dz.rectangle((0, (base - y0) * S, (x1 - x0) * S, (y1 - y0) * S), fill=255)
        off = (int((x0 - p.ox) * S), int((y0 - p.oy) * S))
        p.alb.paste(Image.new('RGB', lz.size, a255(col)), off, lz)
        p.emi.paste(Image.new('RGB', lz.size, a255(col * 0.9)), off, lz)
    # Suelo cercano, casi negro
    p.poli([(x0, y0 + h * 0.84), (x1, y0 + h * 0.8), (x1, y1), (x0, y1)], c('#0c1020'), M_EXTERIOR,
           emi=c('#0c1020'), luz_local=False)
    # Las bombillas azules de las plantitas (las de la referencia)
    for (bx, by) in ((x0 + 36, y0 + h * 0.86), (x0 + 58, y0 + h * 0.82), (x1 - 40, y0 + h * 0.85)):
        p.linea([(bx, y1), (bx + rnd.uniform(-4, 4), by)], 1.4, c('#0c1020'), M_EXTERIOR, emi=c('#0c1020'))
        p.elipse(bx, by, 3.2, 3.6, c('#9fd0ff'), M_EXTERIOR, emi=c('#9fd0ff'))


def pintar_entrada(p: Pintor):
    """Puerta de entrada (hueco 140..340 x 750..1150). La hoja va aparte."""
    X0, X1, Y0, Y1 = 140, 340, 750, PARED_Y
    # Hueco: el exterior, visto por un vano algo mas pequeno (grosor del muro)
    pintar_exterior(p, X0 + 20, Y0 + 6, X1, Y1 - 10)
    # Mocheta izquierda (el grosor del muro), la que se ve desde el centro
    p.facetas([(X0, Y0), (X0 + 22, Y0 + 7), (X0 + 22, Y1 - 10), (X0, Y1)], YESO * 0.55, M_YESO, tam=20)
    p.facetas([(X0, Y0), (X1, Y0), (X1, Y0 + 7), (X0 + 22, Y0 + 7)], YESO * 0.35, M_YESO, tam=20)
    # Umbral de piedra (se ve su cara de arriba)
    p.facetas([(X0 + 22, Y1 - 10), (X1, Y1 - 10), (X1 + 8, Y1 + 6), (X0 - 10, Y1 + 6)], PIEDRA * 0.9,
              M_PIEDRA, tam=16, normal=n_fija(0, -0.6, 1))
    marco(p, X0, Y0, X1, Y1, 26, MADERA, dintel_extra=10)
    # Ojo de buey encima: cristal con la noche
    cx, cy, r = 240, 470, 50
    p.facetas(arco(cx, cy, r + 16, r + 16, 0, 2 * math.pi, 28), PIEDRA * 0.85, M_PIEDRA, tam=14, alto=60)
    p.poli(arco(cx, cy, r, r, 0, 2 * math.pi, 40), c('#22335a'), M_EXTERIOR, emi=c('#2c4272'), luz_local=False)
    p.elipse(cx + 16, cy - 14, 9, 9, c('#b8c8e8'), M_EXTERIOR, emi=c('#a8bce0') * 0.9)   # luna
    p.linea([(cx - r, cy), (cx + r, cy)], 5, MADERA_OSC, M_MADERA)
    p.linea([(cx, cy - r), (cx, cy + r)], 5, MADERA_OSC, M_MADERA)


def pintar_libros(p: Pintor, x, y_base):
    cols = [c('#5a2a20'), c('#2e3a2a'), c('#6a4a2a'), c('#3a2430'), c('#7a5a34')]
    y = y_base
    for i, col in enumerate(cols):
        h = p.rnd.uniform(12, 18)
        w = p.rnd.uniform(40, 56)
        dx = p.rnd.uniform(-6, 6)
        p.rect(x + dx, y - h, x + dx + w, y, col, M_TELA, tam=10, var=0.06, normal=n_cil_h(y - h / 2, h), alto=120)
        p.linea([(x + dx + w - 3, y - h + 2), (x + dx + w - 3, y - 2)], 2, c('#d8c8a0') * 0.8, M_PAPEL)
        y -= h
    # un rollo encima
    p.facetas(arco(x + 30, y - 7, 26, 7, 0, 2 * math.pi, 16), c('#cdb88a'), M_PAPEL, tam=8,
              normal=n_cil_h(y - 7, 7), alto=120)


def pintar_organo(p: Pintor):
    rnd = p.rnd
    X0, X1 = 418, 822
    cx = (X0 + X1) / 2
    # Caja trasera
    p.rect(X0 + 8, 330, X1 - 8, 860, MADERA_OSC * 0.55, M_MADERA_V, tam=40, alto=90)
    # Coronas: torre central apuntada y castillos laterales
    p.facetas([(556, 300), (cx, 200), (684, 300), (684, 330), (556, 330)], MADERA * 0.9, M_MADERA, tam=20, alto=110)
    for (a, b) in ((X0, 552), (688, X1)):
        p.facetas([(a, 372), (b, 346), (b, 372), (a, 396)] if a < cx else [(a, 346), (b, 372), (b, 396), (a, 372)],
                  MADERA * 0.9, M_MADERA, tam=20, alto=110)
    # pinaculos
    for px, py in ((X0 + 6, 372), (552, 346), (556, 300), (684, 300), (688, 346), (X1 - 6, 372), (cx, 200)):
        p.poli([(px - 7, py), (px, py - 34), (px + 7, py)], MADERA * 1.1, M_MADERA, alto=110, normal=n_plano)
    # Tubos: de atras (finos y oscuros) y de fachada
    def tubo(x, w, ytop, ybase, k=1.0):
        pie = ybase + 46
        cols = 4
        for i in range(cols):
            a, b = x + w * i / cols, x + w * (i + 1) / cols
            u = (i + 0.5) / cols * 2 - 1
            f = factor_faceta((u, 0, math.sqrt(1 - u * u * 0.9)), x + w / 2, (ytop + ybase) / 2, 1.2, 8)
            p.poli([(a, ytop + 4), (b, ytop + 4), (b, ybase), (a, ybase)], LATON * k * f, M_COBRE, luz_local=False, alto=100)
        # labio superior
        p.poli([(x - 1, ytop), (x + w + 1, ytop), (x + w + 1, ytop + 5), (x - 1, ytop + 5)], LATON * 0.5 * k, M_COBRE, luz_local=False)
        # pie conico
        p.facetas([(x, ybase), (x + w, ybase), (x + w / 2 + 2.5, pie), (x + w / 2 - 2.5, pie)], LATON * 0.8 * k,
                  M_COBRE, tam=8, normal=n_cil_v(x + w / 2, w / 2), alto=100)
        # boca
        by = ybase - w * 0.9
        p.poli([(x + w * 0.22, by), (x + w * 0.78, by), (x + w * 0.78, by + w * 0.45), (x + w * 0.5, by + w * 0.62),
                (x + w * 0.22, by + w * 0.45)], c('#140c08'), M_HIERRO, luz_local=False)
        p.poli([(x + w * 0.22, by - 3), (x + w * 0.78, by - 3), (x + w * 0.5, by - w * 0.35)], LATON * 0.55 * k, M_COBRE, luz_local=False)

    for i in range(12):
        x = X0 + 22 + i * 31
        tubo(x, 14, 380 + abs(i - 5.5) * 12 + rnd.uniform(-6, 6), 780, 0.42)
    base = 800
    for i, top in enumerate((300, 272, 246, 272, 300)):
        tubo(560 + i * 25, 22, top, base, 1.0)
    for i, top in enumerate((470, 446, 424, 404, 388)):
        tubo(440 + i * 22.5, 19, top, base, 0.9)
        tubo(X1 - 22 - 19 - i * 22.5, 19, top, base, 0.9)
    # Imposta donde asientan los tubos
    p.rect(X0 - 4, 846, X1 + 4, 870, MADERA * 1.0, M_MADERA, tam=16, normal=n_cil_h(858, 14), alto=130)
    # Consola
    p.rect(X0 + 10, 870, X1 - 10, PARED_Y - 6, MADERA_OSC * 0.75, M_MADERA_V, tam=34, alto=130)
    # paneles tallados de la consola
    for a, b in ((X0 + 30, X0 + 140), (X1 - 140, X1 - 30)):
        p.rect(a, 1000, b, 1120, MADERA_OSC * 0.6, M_MADERA_V, tam=24, alto=130)
        p.linea([(a, 1000), (b, 1000), (b, 1120)], 2, MADERA * 0.9, M_MADERA)
    # Atril con partitura
    p.facetas([(548, 872), (692, 872), (700, 930), (540, 930)], MADERA * 0.8, M_MADERA, tam=18, alto=140)
    p.facetas([(566, 866), (674, 866), (680, 922), (560, 922)], c('#d9c79a'), M_PAPEL, tam=14, var=0.03, alto=140)
    for k in range(5):
        yy = 878 + k * 9
        p.linea([(570, yy), (670, yy)], 1, c('#6a5a40'), M_PAPEL)
    # Registros (tiradores) a los lados
    for sx in (X0 + 42, X1 - 42):
        for k in range(4):
            p.elipse(sx + (k % 2) * 16 - 8, 896 + k * 14, 5, 5, c('#e0cfa0'), M_PAPEL, alto=140)
    # Teclados: dos manuales
    for (ya, yb, a, b) in ((932, 946, 484, 756), (952, 970, 470, 770)):
        p.rect(a - 6, yb, b + 6, yb + 10, MADERA_OSC, M_MADERA, tam=12, alto=150)
        p.poli([(a, ya), (b, ya), (b, yb), (a, yb)], c('#e6d7ae'), M_PAPEL, luz_local=False, alto=150)
        k = 0
        x = a + 4
        while x < b - 6:
            if k % 7 not in (2, 6):
                p.poli([(x + 3, ya), (x + 7, ya), (x + 7, ya + (yb - ya) * 0.6), (x + 3, ya + (yb - ya) * 0.6)],
                       c('#1a120c'), M_MADERA, luz_local=False)
            x += 7.6
            k += 1
    # Velas en las esquinas de la consola
    for vx in (455, 785):
        vela(p, vx, 846, 44)
    # Banqueta
    p.rect(508, 1082, 732, 1100, MADERA * 0.95, M_MADERA, tam=16, normal=n_cil_h(1091, 9), alto=200)
    for lx in (520, 704):
        p.rect(lx, 1100, lx + 16, 1170, MADERA * 0.7, M_MADERA_V, tam=12, normal=n_cil_v(lx + 8, 8), alto=200)
    # Pedalero
    p.rect(488, 1140, 752, 1160, MADERA_OSC * 0.8, M_MADERA, tam=14, alto=180)
    for k in range(12):
        x = 494 + k * 21.5
        p.poli([(x, 1142), (x + 14, 1142), (x + 14, 1148), (x, 1148)], MADERA * 1.1, M_MADERA, luz_local=False)


def vela(p: Pintor, x, y_base, alto, grueso=11, platillo=True):
    """Vela de cera con su chorreon. La llama va en Godot (sprite)."""
    if platillo:
        p.facetas(arco(x, y_base, grueso * 1.6, 4.5, 0, 2 * math.pi, 16), LATON * 0.9, M_COBRE, tam=6,
                  normal=n_cil_h(y_base, 5), alto=160)
    p.rect(x - grueso / 2, y_base - alto, x + grueso / 2, y_base - 2, CERA, M_CERA, tam=6, var=0.03,
           normal=n_cil_v(x, grueso / 2), alto=160)
    p.poli([(x - grueso / 2, y_base - alto), (x + grueso / 2, y_base - alto), (x + grueso / 2 - 1, y_base - alto + 3),
            (x - grueso / 2 + 1, y_base - alto + 3)], CERA * 1.1, M_CERA, luz_local=False)
    # chorreon
    lado = p.rnd.choice((-1, 1))
    p.poli([(x + lado * grueso / 2, y_base - alto + 2), (x + lado * (grueso / 2 + 2.5), y_base - alto + 10),
            (x + lado * (grueso / 2 + 1.5), y_base - alto * 0.45), (x + lado * grueso * 0.3, y_base - alto * 0.5)],
           CERA * 0.95, M_CERA, luz_local=False)
    # pabilo
    p.linea([(x, y_base - alto), (x + 0.5, y_base - alto - 6)], 1.6, c('#1a1008'), M_HIERRO)


def pintar_potro(p: Pintor):
    """Potro de tortura visto de lado: bancada larga, patas, rodillo con rueda."""
    madera = c('#5e3c22')
    # patas traseras (mas oscuras, un pelo desplazadas)
    for lx in (896, 1214):
        p.rect(lx, 1000, lx + 24, 1166, madera * 0.5, M_MADERA_V, tam=14, alto=120)
    p.rect(900, 1100, 1230, 1114, madera * 0.45, M_MADERA, tam=14, alto=120)
    # bancada (se ve su cara de arriba y el canto)
    p.facetas([(862, 970), (1238, 970), (1246, 984), (854, 984)], madera * 1.25, M_MADERA, tam=16,
              normal=n_fija(0, -0.8, 0.6), alto=200)
    for k in range(9):
        x = 868 + k * 42
        p.linea([(x, 971), (x - 3, 983)], 1.5, madera * 0.5, M_MADERA)
    p.rect(852, 984, 1248, 1020, madera, M_MADERA, tam=20, normal=n_cil_h(1002, 22), alto=200)
    # patas delanteras
    for lx in (874, 1196):
        p.facetas([(lx, 1020), (lx + 28, 1020), (lx + 30, 1172), (lx - 2, 1172)], madera * 0.95, M_MADERA_V, tam=14,
                  normal=n_cil_v(lx + 14, 15), alto=200)
    p.rect(900, 1112, 1196, 1128, madera * 0.8, M_MADERA, tam=14, normal=n_cil_h(1120, 8), alto=200)
    # Rodillo izquierdo con aspas cortas
    cxi, cyi = 880, 996
    p.facetas(arco(cxi, cyi, 21, 21, 0, 2 * math.pi, 20), madera * 1.1, M_MADERA, tam=8, normal=n_esfera(cxi, cyi, 22, 22), alto=220)
    for k in range(4):
        a = k * math.pi / 2 + 0.4
        p.linea([(cxi, cyi), (cxi + math.cos(a) * 44, cyi + math.sin(a) * 44)], 7, madera * 0.9, M_MADERA, alto=220)
    p.elipse(cxi, cyi, 7, 7, HIERRO * 1.5, M_HIERRO)
    # Rueda grande a la derecha: aro, radios y manijas
    cxd, cyd, R = 1226, 986, 62
    for k in range(6):
        a = k * math.pi / 3 + 0.25
        p.linea([(cxd, cyd), (cxd + math.cos(a) * R, cyd + math.sin(a) * R)], 6, madera * 0.9, M_MADERA, alto=220)
        mx, my = cxd + math.cos(a) * (R + 22), cyd + math.sin(a) * (R + 22)
        p.linea([(cxd + math.cos(a) * R, cyd + math.sin(a) * R), (mx, my)], 9, madera * 1.05, M_MADERA, alto=220)
        p.elipse(mx, my, 5.5, 5.5, madera * 1.3, M_MADERA, alto=220)
    p.linea(arco(cxd, cyd, R, R, 0, 2 * math.pi, 40), 9, madera * 1.1, M_MADERA, alto=220)
    p.facetas(arco(cxd, cyd, 18, 18, 0, 2 * math.pi, 20), madera * 1.15, M_MADERA, tam=8, normal=n_esfera(cxd, cyd, 18, 18), alto=220)
    p.elipse(cxd, cyd, 6, 6, HIERRO * 1.6, M_HIERRO)
    # Cuerdas con grilletes, un poco combadas
    cuerda = c('#c8a878')
    for (xa, ya), (xb, yb) in (((cxi + 14, cyi - 10), (1000, 966)), ((cxd - 14, cyd - 12), (1104, 966))):
        pts = [(xa + (xb - xa) * t, ya + (yb - ya) * t + math.sin(t * math.pi) * 6) for t in np.linspace(0, 1, 12)]
        p.linea(pts, 5.5, cuerda, M_TELA, alto=230)
        p.linea([(x, y - 1.5) for x, y in pts], 1.5, cuerda * 1.35, M_TELA)
        p.linea(arco(xb + (8 if xb < 1050 else -8), yb + 1, 10, 4.5, 0, 2 * math.pi, 18), 3, HIERRO * 1.5, M_HIERRO, alto=230)
    # Cadenas colgando de la pared encima del potro, con grillete
    p.cadena(880, 760, 880, 900, 11, 2.6)
    p.linea(arco(880, 912, 10, 12, 0, 2 * math.pi, 18), 3.5, HIERRO * 1.4, M_HIERRO, alto=60)
    p.elipse(880, 757, 6, 6, HIERRO * 1.6, M_HIERRO)


def pintar_alambique(p: Pintor):
    madera = c('#5a3a22')
    # Banco
    p.rect(1260, 1026, 1414, 1044, madera * 1.1, M_MADERA, tam=16, normal=n_cil_h(1035, 9), alto=200)
    for lx in (1270, 1390):
        p.rect(lx, 1044, lx + 14, 1170, madera * 0.8, M_MADERA_V, tam=12, normal=n_cil_v(lx + 7, 7), alto=200)
    p.rect(1276, 1118, 1398, 1128, madera * 0.7, M_MADERA, tam=12, alto=200)
    # tarros en la balda de abajo
    for (x, w, h, col) in ((1292, 22, 30, c('#3b4a30')), (1322, 18, 24, c('#6a4a2a')), (1350, 26, 34, c('#403040'))):
        p.facetas([(x, 1118 - h + 6), (x + w, 1118 - h + 6), (x + w, 1118), (x, 1118)], col, M_CRISTAL, tam=8,
                  normal=n_cil_v(x + w / 2, w / 2), alto=200)
        p.rect(x + 3, 1118 - h, x + w - 3, 1118 - h + 6, c('#8a6a44'), M_MADERA, tam=6)
    # Lamparilla de aceite
    p.facetas([(1294, 1026), (1330, 1026), (1324, 1012), (1300, 1012)], LATON, M_COBRE, tam=8,
              normal=n_cil_v(1312, 18), alto=210)
    p.linea([(1312, 1012), (1312, 1004)], 1.5, c('#1a1008'), M_HIERRO)
    # Tripode con aro
    for a, b in (((1284, 1026), (1290, 994)), ((1340, 1026), (1334, 994)), ((1312, 1026), (1312, 998))):
        p.linea([a, b], 3, HIERRO * 1.3, M_HIERRO, alto=210)
    p.linea(arco(1312, 996, 30, 4, 0, 2 * math.pi, 20), 3, HIERRO * 1.4, M_HIERRO, alto=210)
    # Marmita de cobre
    cxp, cyp = 1312, 960
    p.facetas(arco(cxp, cyp, 38, 35, 0, 2 * math.pi, 28), COBRE, M_COBRE, tam=11, var=0.06,
              normal=n_esfera(cxp, cyp, 40, 37), alto=220)
    # cuello y capitel
    p.facetas([(1302, 928), (1322, 928), (1320, 906), (1304, 906)], COBRE * 0.95, M_COBRE, tam=8,
              normal=n_cil_v(1312, 10), alto=220)
    cap = arco(1312, 894, 27, 17, 0, math.pi, 14) + [(1300, 876), (1312, 858), (1324, 876)]
    p.facetas(cap[:14] + [(1285, 894), (1296, 880), (1312, 862), (1328, 880), (1339, 894)][::-1] if False else
              [(1285, 894), (1293, 881), (1312, 864), (1331, 881), (1339, 894), (1330, 906), (1312, 911), (1294, 906)],
              COBRE * 1.05, M_COBRE, tam=9, normal=n_esfera(1312, 892, 28, 22), alto=220)
    # valvula que silba
    p.rect(1309, 850, 1315, 864, LATON * 1.1, M_COBRE, tam=4, normal=n_cil_v(1312, 3), alto=220)
    p.rect(1305, 847, 1319, 851, LATON * 0.9, M_COBRE, tam=4, alto=220)
    # Pico: tubo que baja al recipiente
    pts = []
    for t in np.linspace(0, 1, 14):
        x = 1334 + (1392 - 1334) * t
        y = 892 + (978 - 892) * (t ** 1.3)
        pts.append((x, y))
    p.linea(pts, 8, COBRE * 0.9, M_COBRE, alto=220)
    p.linea([(x, y - 2) for x, y in pts], 2.2, COBRE * 1.6, M_COBRE)
    # Recipiente de cristal
    cxr, cyr = 1392, 1004
    p.facetas(arco(cxr, cyr, 22, 21, 0, 2 * math.pi, 24), c('#5a6450'), M_CRISTAL, tam=8,
              normal=n_esfera(cxr, cyr, 23, 22), alto=220)
    p.facetas(arco(cxr, cyr + 6, 19, 14, 0.15, math.pi - 0.15, 12), c('#a8662a'), M_CRISTAL, tam=7,
              normal=n_esfera(cxr, cyr, 23, 22), alto=220, emi=c('#301204'))
    p.rect(cxr - 5, 976, cxr + 5, 986, c('#6a7460'), M_CRISTAL, tam=4, alto=220)
    p.linea(arco(cxr - 6, cyr - 6, 12, 12, math.pi * 1.1, math.pi * 1.5, 8), 2, c('#d8e0c8'), M_CRISTAL, emi=c('#302a20'))


def pintar_puertas_pared(p: Pintor):
    """La pared de las puertas imposibles."""
    # 1. Puerta alta, sin escalera, sobre el potro (arco apuntado)
    X0, X1, Y0, Y1 = 950, 1080, 380, 660
    p.facetas([(X0 - 18, Y1), (X0 - 18, Y0 + 40), (X0 + (X1 - X0) / 2, Y0 - 28), (X1 + 18, Y0 + 40), (X1 + 18, Y1)],
              PIEDRA * 0.8, M_PIEDRA, tam=18, alto=50)
    puerta_tablas(p, X0, Y0, X1, Y1, MADERA_OSC * 1.05, tablas=4, arco_sup=60, lado_bisagra='izq')
    p.facetas([(X0 - 26, Y1), (X1 + 26, Y1), (X1 + 32, Y1 + 12), (X0 - 32, Y1 + 12)], PIEDRA, M_PIEDRA, tam=12,
              normal=n_fija(0, -0.7, 0.7), alto=90)
    p.rect(X0 - 32, Y1 + 12, X1 + 32, Y1 + 22, PIEDRA * 0.6, M_PIEDRA, tam=12, alto=90)
    # 2. Trampilla torcida, pequena
    ang = math.radians(5)
    cxh, cyh, s = 1180, 510, 36
    def rot(x, y):
        return (cxh + (x * math.cos(ang) - y * math.sin(ang)), cyh + (x * math.sin(ang) + y * math.cos(ang)))
    p.facetas([rot(-s - 8, -s - 8), rot(s + 8, -s - 8), rot(s + 8, s + 8), rot(-s - 8, s + 8)], MADERA * 0.9, M_MADERA, tam=12, alto=50)
    p.facetas([rot(-s, -s), rot(s, -s), rot(s, s), rot(-s, s)], MADERA_OSC * 1.1, M_MADERA_V, tam=12, alto=40)
    for k in (-1, 0, 1):
        p.linea([rot(k * s * 0.5, -s), rot(k * s * 0.5, s)], 1.5, MADERA_OSC * 0.4, M_MADERA)
    ax, ay = rot(0, s * 0.3)
    p.linea(arco(ax, ay, 8, 8.5, 0, 2 * math.pi, 16), 2.4, HIERRO * 1.6, M_HIERRO, alto=40)
    # 3. Candil de pared entre ambas
    p.linea([(1180, 720), (1180, 704), (1166, 700)], 4, HIERRO * 1.3, M_HIERRO, alto=80)
    p.linea([(1160, 708), (1200, 708)], 3, HIERRO * 1.2, M_HIERRO, alto=80)
    vela(p, 1180, 704, 30, 10, platillo=True)
    # 4. Puertecita a ras de suelo, con luz por debajo
    X0, X1, Y0, Y1 = 1490, 1546, 1060, PARED_Y - 3
    r = (X1 - X0) / 2
    p.facetas([(X0 - 10, Y1)] + arco(X0 + r, Y0 + r, r + 10, r + 10, math.pi, 2 * math.pi, 16) + [(X1 + 10, Y1)],
              MADERA * 0.85, M_MADERA, tam=10, alto=40)
    p.facetas([(X0, Y1)] + arco(X0 + r, Y0 + r, r, r, math.pi, 2 * math.pi, 16) + [(X1, Y1)],
              MADERA_OSC * 1.1, M_MADERA_V, tam=10, alto=30)
    for k in (1, 2):
        xx = X0 + (X1 - X0) * k / 3
        p.linea([(xx, Y0 + 4), (xx, Y1)], 1.3, MADERA_OSC * 0.4, M_MADERA)
    p.elipse(X1 - 10, Y0 + 50, 3.2, 3.2, LATON * 1.3, M_COBRE)
    p.poli([(X0 + 1, Y1 - 4), (X1 - 1, Y1 - 4), (X1 - 1, Y1 + 1), (X0 + 1, Y1 + 1)], c('#ffb060'), M_NADA,
           emi=c('#ffb060') * 1.2, luz_local=False)
    # 5. Puerta con la perspectiva equivocada: como vista desde otra habitacion
    L, R = 1602, 1778
    tl, bl = 706, PARED_Y - 4       # borde izquierdo (alto)
    tr, br = 760, PARED_Y - 34      # borde derecho (mas corto: "se aleja")
    # mocheta visible por el lado que NO toca (lado derecho, pero vista desde la izquierda)
    p.facetas([(L - 22, tl - 22), (R + 10, tr - 16), (R + 10, br + 16), (L - 22, bl + 4)], MADERA * 0.9, M_MADERA, tam=16, alto=50)
    p.facetas([(L, tl), (R, tr), (R, br), (L, bl)], MADERA_OSC * 1.15, M_MADERA_V, tam=18)
    for k in range(1, 4):
        t = k / 4
        xa = L + (R - L) * t
        p.linea([(xa, tl + (tr - tl) * t), (xa, bl + (br - bl) * t)], 1.6, MADERA_OSC * 0.45, M_MADERA)
    for fy in (0.25, 0.75):
        ya, yb = tl + (bl - tl) * fy, tr + (br - tr) * fy
        p.linea([(L, ya), (L + (R - L) * 0.6, ya + (yb - ya) * 0.6)], 7, HIERRO * 1.1, M_HIERRO, alto=40)
    p.elipse(R - 26, (tr + br) / 2 + 8, 5, 6, LATON * 1.2, M_COBRE, alto=40)
    # 6. Mampara acristalada de dos hojas, con luz de otra sala detras
    X0, X1, Y0, Y1 = 1912, 2092, 560, PARED_Y - 4
    p.rect(X0 - 16, Y0 - 16, X1 + 16, Y1, MADERA * 0.85, M_MADERA_V, tam=20, alto=60)
    rnd = random.Random(5)
    for hoja in range(2):
        a = X0 + (X1 - X0) * hoja / 2 + 6
        b = X0 + (X1 - X0) * (hoja + 1) / 2 - 6
        cols, filas = 3, 7
        pw, ph = (b - a) / cols, (Y1 - Y0 - 60) / filas
        p.rect(a - 4, Y0, b + 4, Y1, MADERA_OSC * 1.0, M_MADERA_V, tam=16, alto=50)
        for i in range(cols):
            for j in range(filas):
                xa, ya = a + i * pw + 3, Y0 + 8 + j * ph + 3
                xb, yb = xa + pw - 6, ya + ph - 6
                calor = rnd.uniform(0.35, 1.0) * (1 - j / filas * 0.5)
                if (i, j, hoja) in ((1, 2, 1), (0, 4, 0)):
                    calor = 0.05   # cortina o cristal tapado
                col = c('#7a4a22') * (0.4 + calor * 0.6)
                p.poli([(xa, ya), (xb, ya), (xb, yb), (xa, yb)], col, M_CRISTAL, emi=c('#ff9a48') * calor * 0.32,
                       luz_local=False)
                # reflejo en diagonal
                p.linea([(xa + 3, yb - 4), (xa + pw * 0.4, ya + 3)], 1.2, c('#c89a6a'), M_CRISTAL, emi=c('#402414') * calor)
        # zocalo de madera
        p.rect(a, Y1 - 52, b, Y1, MADERA_OSC * 0.9, M_MADERA_V, tam=14, alto=50)
        p.elipse(b - 10 if hoja == 0 else a + 10, (Y0 + Y1) / 2 + 40, 4, 4, LATON * 1.2, M_COBRE)
    # 7. Puerta chica alta con escalera que acaba en el aire
    X0, X1, Y0, Y1 = 2236, 2324, 220, 340
    marco(p, X0, Y0, X1, Y1, 12, MADERA * 0.9, alto=60)
    puerta_tablas(p, X0, Y0, X1, Y1, MADERA_OSC, tablas=3, herrajes=False, lado_bisagra='der', tam=14)
    escalones = [(2196, 340), (2156, 372), (2116, 404), (2076, 436)]
    for k, (ex, ey) in enumerate(escalones):
        p.facetas([(ex, ey), (ex + 40, ey), (ex + 44, ey - 6), (ex + 4, ey - 6)], MADERA * 1.2, M_MADERA, tam=10,
                  normal=n_fija(0, -0.8, 0.6), alto=120)
        p.rect(ex, ey, ex + 40, ey + 32, MADERA * 0.85, M_MADERA, tam=12, alto=120)
    p.facetas([(2076, 468), (2076, 450), (2236, 350), (2236, 372)], MADERA * 0.6, M_MADERA, tam=12, alto=110)


def pintar_chimenea(p: Pintor):
    rnd = p.rnd
    X0, X1 = 2656, W
    HX0, HX1 = 2716, 2870     # boca
    MY0, MY1 = 690, 730       # repisa
    # Campana: trapecio de yeso con hollin
    p.facetas([(2700, TECHO_Y), (W, TECHO_Y), (W, MY0), (2644, MY0)], YESO * 0.8, M_YESO, tam=40, var=0.05, alto=110)
    # Repisa
    p.rect(2626, MY0, W, MY1, MADERA * 1.05, M_MADERA, tam=18, normal=n_cil_h((MY0 + MY1) / 2, 22), alto=180)
    p.facetas([(2626, MY0), (W, MY0), (W, MY0 - 8), (2632, MY0 - 8)], MADERA * 1.3, M_MADERA, tam=14,
              normal=n_fija(0, -0.8, 0.6), alto=180)
    # Jambas de sillares
    def sillares(x0, x1, y0, y1):
        y = y0
        k = 0
        while y < y1:
            h = rnd.uniform(52, 70)
            yb = min(y + h, y1)
            off = 6 if k % 2 else 0
            p.rect(x0, y, x1, yb, PIEDRA * 0.4, M_PIEDRA, tam=40, var=0.0, alto=150)   # llaga
            p.facetas([(x0 + off + 2, y + 3), (x1 - 2, y + 3), (x1 - 2, yb - 3), (x0 + off + 2, yb - 3)],
                      PIEDRA * rnd.uniform(0.62, 0.8), M_PIEDRA, tam=24, var=0.035, alto=150,
                      normal=n_esfera((x0 + x1) / 2, (y + yb) / 2, (x1 - x0) * 1.2, (yb - y) * 1.6))
            y = yb
            k += 1
    # Interior del hogar: hollin y ladrillo
    p.rect(HX0, MY1, HX1, PARED_Y, c('#1c120c'), M_HOLLIN, tam=24, var=0.1)
    for k in range(19):
        yy = MY1 + 8 + k * 22
        p.linea([(HX0, yy), (HX1, yy)], 1.2, c('#0e0806'), M_HOLLIN)
        off = 0 if k % 2 else 26
        for xx in np.arange(HX0 + off, HX1, 52):
            p.linea([(xx, yy), (xx, yy + 22)], 1.2, c('#0e0806'), M_HOLLIN)
    # el fondo del hogar reverbera naranja cerca de las brasas y se ennegrece arriba
    for k in range(12):
        ya = 1000 + k * 12.5
        t = k / 11
        p.poli([(HX0 + 4, ya), (HX1 - 4, ya), (HX1 - 4, ya + 13), (HX0 + 4, ya + 13)], c('#24140c') * (0.7 + 0.5 * t),
               M_HOLLIN, emi=c('#ff6a24') * (t ** 2.5) * 0.28, luz_local=False)
    # Mocheta derecha interior (se ve desde la izquierda)
    p.facetas([(HX1 - 34, MY1 + 20), (HX1, MY1), (HX1, PARED_Y), (HX1 - 34, PARED_Y - 18)], PIEDRA * 0.5, M_PIEDRA, tam=16)
    sillares(X0, HX0, MY1, PARED_Y)
    sillares(HX1, X1, MY1, PARED_Y)
    # Solera
    p.facetas([(HX0, PARED_Y - 24), (HX1 - 20, PARED_Y - 24), (HX1, PARED_Y), (HX0, PARED_Y)], PIEDRA * 0.7, M_PIEDRA, tam=14)
    p.facetas([(2636, PARED_Y), (W, PARED_Y), (W, PARED_Y + 24), (2624, PARED_Y + 24)], PIEDRA * 0.9, M_PIEDRA, tam=14,
              normal=n_fija(0, -0.7, 0.7), alto=60)
    # Morillos y lenos
    for mx in (2744, 2840):
        p.linea([(mx, PARED_Y - 4), (mx, 1088), (mx - 8, 1078)], 7, HIERRO, M_HIERRO, alto=100)
        p.elipse(mx - 9, 1076, 6, 6, HIERRO * 1.4, M_HIERRO)
    for (xa, ya, xb, yb, g) in ((2724, 1112, 2862, 1100, 22), (2736, 1092, 2850, 1112, 18), (2760, 1080, 2830, 1070, 14)):
        ang = math.atan2(yb - ya, xb - xa)
        nx, ny = -math.sin(ang) * g / 2, math.cos(ang) * g / 2
        p.facetas([(xa + nx, ya + ny), (xb + nx, yb + ny), (xb - nx, yb - ny), (xa - nx, ya - ny)], c('#2a1a10'), M_MADERA,
                  tam=10, var=0.1, alto=110)
        # grietas de brasa
        for k in range(4):
            t = rnd.uniform(0.1, 0.9)
            px, py = xa + (xb - xa) * t, ya + (yb - ya) * t
            p.linea([(px - 5, py + ny * 0.3), (px + 6, py - ny * 0.2)], 2, c('#ff6a20'), M_NADA, emi=c('#ff7a28') * 1.3)
    # Hollin sobre la boca
    # (se aplica en el revelado como mancha oscura: ver 'hollin' en revelar)
    # Objetos de la repisa
    vela(p, 2676, MY0 - 8, 42)
    vela(p, 2846, MY0 - 8, 36)
    # reloj de arena
    rx, ry = 2762, MY0 - 8
    p.rect(rx - 16, ry - 6, rx + 16, ry, MADERA, M_MADERA, tam=8, alto=190)
    p.rect(rx - 16, ry - 58, rx + 16, ry - 52, MADERA, M_MADERA, tam=8, alto=190)
    p.facetas([(rx - 12, ry - 52), (rx + 12, ry - 52), (rx + 2, ry - 30), (rx + 12, ry - 6), (rx - 12, ry - 6), (rx - 2, ry - 30)],
              c('#8a8a70'), M_CRISTAL, tam=6, alto=190)
    p.poli([(rx - 10, ry - 7), (rx + 10, ry - 7), (rx, ry - 20)], c('#c8a060'), M_PAPEL, luz_local=False)
    for sx in (rx - 15, rx + 13):
        p.rect(sx, ry - 54, sx + 2.5, ry - 4, MADERA * 0.8, M_MADERA, tam=6)
    # tarro
    p.facetas(arco(2800, MY0 - 26, 14, 18, 0, 2 * math.pi, 16), c('#4a3a2a'), M_CRISTAL, tam=7,
              normal=n_esfera(2800, MY0 - 26, 15, 19), alto=190)


def pintar_caldero(p: Pintor):
    cx = 2548
    # Brasero: cuenco y tres patas
    p.linea([(cx, 1110), (cx + 4, 1164)], 7, HIERRO * 0.6, M_HIERRO, alto=160)
    for (xa, xb) in ((cx - 50, cx - 80), (cx + 50, cx + 80)):
        p.linea([(xa, 1104), (xb, 1170)], 9, HIERRO * 1.1, M_HIERRO, alto=180)
        p.elipse(xb, 1170, 8, 3, HIERRO, M_HIERRO)
    cuenco = [(cx - 96, 1062), (cx + 96, 1062), (cx + 78, 1094), (cx + 44, 1112), (cx - 44, 1112), (cx - 78, 1094)]
    p.facetas(cuenco, HIERRO * 0.6, M_HIERRO, tam=14, normal=n_esfera(cx, 1060, 100, 55), alto=180)
    # brasas visibles entre el cuenco y el caldero
    rnd = random.Random(12)
    p.poli([(cx - 92, 1062), (cx + 92, 1062), (cx + 84, 1052), (cx - 84, 1052)], c('#3a140a'), M_HOLLIN,
           emi=c('#ff5a1a') * 0.5, luz_local=False)
    for k in range(26):
        bx = cx + rnd.uniform(-86, 86)
        by = rnd.uniform(1050, 1062)
        r = rnd.uniform(4, 9)
        cal = rnd.uniform(0.4, 1.0)
        p.poli([(bx - r, by + 2), (bx - r * 0.3, by - r * 0.6), (bx + r, by - r * 0.2), (bx + r * 0.6, by + 3)],
               c('#5a2010'), M_HOLLIN, emi=c('#ff6a22') * cal * 1.2, luz_local=False)
    p.linea([(cx - 96, 1062), (cx + 96, 1062)], 5, HIERRO * 1.3, M_HIERRO)
    # Caldero: cuerpo redondo de hierro
    cy, rx, ry = 946, 124, 102
    cuerpo = [(cx + rx * math.cos(t), cy + ry * math.sin(t) * (0.85 if math.sin(t) < 0 else 1.0))
              for t in np.linspace(math.pi * 1.06, math.pi * 1.94 + math.pi * 1.0, 40)]
    cuerpo = [(cx - 118, 890), (cx + 118, 890)] + [(cx + rx * math.cos(t), cy + ry * math.sin(t))
                                                  for t in np.linspace(-0.55, math.pi + 0.55, 36)]
    cuerpo = cuerpo[:2] + cuerpo[2:]
    p.facetas(cuerpo, c('#141110'), M_HIERRO, tam=26, var=0.035, normal=n_esfera(cx, 930, 132, 125), alto=240)
    # filo de luz de la chimenea por el lado derecho, y reflejo rojo del brasero abajo
    p.linea([(cx + rx * math.cos(t), cy + ry * math.sin(t)) for t in np.linspace(-0.45, 0.9, 16)], 3.5,
            c('#c07040'), M_COBRE)
    p.linea([(cx + (rx - 6) * math.cos(t), cy + (ry - 4) * math.sin(t)) for t in np.linspace(1.1, 2.1, 12)], 3,
            c('#a04418'), M_COBRE, emi=c('#401404'))
    # asas
    for sx in (-1, 1):
        p.linea(arco(cx + sx * 128, 912, 14, 12, -math.pi / 2, math.pi / 2, 12) if sx > 0 else
                arco(cx + sx * 128, 912, 14, 12, math.pi / 2, math.pi * 1.5, 12), 5, HIERRO * 1.2, M_HIERRO, alto=240)
    # boca: labio y superficie del caldo
    p.facetas(arco(cx, 884, 128, 16, 0, 2 * math.pi, 40), c('#2a2522'), M_HIERRO, tam=12,
              normal=n_fija(0, -0.8, 0.6), alto=240)
    p.facetas(arco(cx, 883, 112, 11, 0, 2 * math.pi, 40), c('#4a3418'), M_TELA, tam=14, var=0.08,
              normal=n_fija(0, -1, 0.3), alto=240, emi=c('#1a0c04'))
    p.linea(arco(cx, 884, 128, 16, math.pi * 0.05, math.pi * 0.95, 20), 3, c('#1a1614'), M_HIERRO)
    p.linea(arco(cx, 884, 127, 15, -math.pi * 0.45, math.pi * 0.05, 14), 2.5, c('#d08850'), M_COBRE)
    # cucharon
    p.linea([(cx - 60, 880), (cx - 128, 748)], 9, MADERA * 1.1, M_MADERA, alto=250)
    p.linea([(cx - 62, 878), (cx - 129, 750)], 2.5, MADERA * 1.6, M_MADERA)


def pintar_hacha(p: Pintor):
    # mango apoyado en la jamba derecha de la chimenea
    xa, ya, xb, yb = 2884, 918, 2902, 1170
    p.linea([(xa, ya), (xb, yb)], 11, c('#7a5634'), M_MADERA, alto=230)
    p.linea([(xa - 3, ya + 6), (xb - 3, yb - 4)], 2.5, c('#a07a50'), M_MADERA)
    # cabeza: hoja hacia la izquierda, con el filo brillante
    hoja = [(2892, 912), (2892, 944), (2870, 942), (2838, 966), (2830, 918), (2836, 890), (2868, 916)]
    p.facetas(hoja, HIERRO * 1.3, M_HIERRO, tam=10, normal=n_fija(0.3, -0.2, 1), alto=240)
    p.linea([(2836, 891), (2830, 918), (2838, 965)], 3, c('#e8d8c0'), M_HIERRO)
    p.rect(2888, 906, 2900, 948, HIERRO * 0.9, M_HIERRO, tam=6, alto=240)


def pintar_suelo(p: Pintor):
    """Tablas que se van hacia el punto de fuga, juntas escalonadas y la
    trampilla con su anilla oxidada."""
    rnd = random.Random(8)
    fx, fy = FUGA

    def x_en(xb, y):
        # xb: donde corta la linea al borde inferior; recta hacia la fuga
        t = (y - fy) / (H - fy)
        return fx + (xb - fx) * t

    ancho_b = 150
    xb = fx - ancho_b * 14
    tablas = []
    while xb < fx + ancho_b * 14:
        tablas.append((xb, xb + ancho_b))
        xb += ancho_b
    # juntas: filas en y con perspectiva (mas juntas al fondo)
    filas = [PARED_Y + (H - PARED_Y) * ((k / 7) ** 1.35) for k in range(8)]
    for i, (a, b) in enumerate(tablas):
        base = SUELO_COL * (1.0 + (0.06 if i % 2 else -0.05) + rnd.uniform(-0.04, 0.04))
        cortes = [PARED_Y]
        y = PARED_Y + rnd.uniform(20, 140)
        while y < H:
            cortes.append(y)
            y += rnd.uniform(160, 300) * (0.6 + 0.4 * (y - PARED_Y) / (H - PARED_Y))
        cortes.append(H + 2)
        for j in range(len(cortes) - 1):
            ya, yb = cortes[j], cortes[j + 1]
            if x_en(b, ya) < -10 and x_en(b, yb) < -10:
                continue
            if x_en(a, ya) > W + 10 and x_en(a, yb) > W + 10:
                continue
            col = base * (1 + rnd.uniform(-0.05, 0.05))
            pts = [(x_en(a, ya), ya), (x_en(b, ya), ya), (x_en(b, yb), yb), (x_en(a, yb), yb)]
            p.facetas(pts, col, M_SUELO, tam=46, var=0.04, normal=n_fija(0, -1, 0.35))
            p.linea([(x_en(a, ya), ya), (x_en(b, ya), ya)], 2.0, SUELO_COL * 0.3, M_SUELO)
        p.linea([(x_en(a, PARED_Y), PARED_Y), (x_en(a, H), H)], 2.4, SUELO_COL * 0.25, M_SUELO)
        # clavos
        for y in cortes[1:-1]:
            for xx in (a + 16, b - 16):
                p.elipse(x_en(xx, y + 7), y + 7, 1.8, 1.2, HIERRO * 0.6, M_HIERRO)


def pintar_trampilla(p: Pintor):
    """Trampilla del suelo con anilla oxidada. Quedara medio bajo la mesa."""
    fx, fy = FUGA

    def x_en(xw, y):
        # xw: coordenada x que tendria en la linea de la pared (PARED_Y)
        t0 = (PARED_Y - fy)
        t = (y - fy) / t0
        return fx + (xw - fx) * t

    ya, yb = 1258, 1334
    xa, xb = 2030, 2170
    marco_pts = [(x_en(xa - 8, ya - 5), ya - 5), (x_en(xb + 8, ya - 5), ya - 5), (x_en(xb + 8, yb + 6), yb + 6), (x_en(xa - 8, yb + 6), yb + 6)]
    p.poli(marco_pts, SUELO_COL * 0.25, M_SUELO, luz_local=False)
    n = 4
    for k in range(n):
        y0 = ya + (yb - ya) * k / n
        y1 = ya + (yb - ya) * (k + 1) / n - 1.5
        col = SUELO_COL * (0.82 + 0.06 * (k % 2))
        p.facetas([(x_en(xa, y0), y0), (x_en(xb, y0), y0), (x_en(xb, y1), y1), (x_en(xa, y1), y1)], col, M_SUELO,
                  tam=20, var=0.05, normal=n_fija(0, -1, 0.35))
    # flejes de hierro
    for xw in (xa + 26, xb - 26):
        p.poli([(x_en(xw - 5, ya), ya), (x_en(xw + 5, ya), ya), (x_en(xw + 5, yb), yb), (x_en(xw - 5, yb), yb)],
               HIERRO * 0.8, M_HIERRO, luz_local=False)
    # anilla oxidada, tumbada, con su chapa
    cx, cy = x_en((xa + xb) / 2, (ya + yb) / 2 + 6), (ya + yb) / 2 + 6
    p.poli([(cx - 9, cy - 16), (cx + 9, cy - 16), (cx + 9, cy - 8), (cx - 9, cy - 8)], c('#5a3018'), M_HIERRO, luz_local=False)
    p.linea(arco(cx, cy, 22, 9, 0, 2 * math.pi, 28), 5, c('#7a3a18'), M_HIERRO)
    p.linea(arco(cx, cy - 1, 22, 9, math.pi * 1.1, math.pi * 1.9, 12), 2, c('#b06a36'), M_HIERRO)


def pintar_alfombra(p: Pintor):
    """Alfombra gastada delante del organo y el potro: rompe la extension de
    tablas y calienta el suelo. En perspectiva, como las tablas."""
    fx, fy = FUGA

    def pt(xw, y):
        t = (y - fy) / (PARED_Y - fy)
        return (fx + (xw - fx) * t, y)

    ya, yb = 1232, 1392
    xa, xb = 540, 1300
    def quad(x0, y0, x1, y1):
        return [pt(x0, y0), pt(x1, y0), pt(x1, y1), pt(x0, y1)]
    p.facetas(quad(xa, ya, xb, yb), c('#4a2016'), M_TELA, tam=34, var=0.06, normal=n_fija(0, -1, 0.35))
    # cenefa
    g = 22
    for (x0, y0, x1, y1) in ((xa, ya, xb, ya + g * 0.7), (xa, yb - g, xb, yb), (xa, ya, xa + g * 1.4, yb), (xb - g * 1.4, ya, xb, yb)):
        p.facetas(quad(x0, y0, x1, y1), c('#7a5a2c'), M_TELA, tam=14, var=0.07, normal=n_fija(0, -1, 0.35))
    # rombos del centro
    cy = (ya + yb) / 2
    for k in range(5):
        cxw = xa + 130 + k * (xb - xa - 260) / 4
        r, ry = 58, 38
        p.facetas([pt(cxw - r, cy), pt(cxw, cy - ry), pt(cxw + r, cy), pt(cxw, cy + ry)], c('#6a3a1c'), M_TELA, tam=16,
                  var=0.06, normal=n_fija(0, -1, 0.35))
        p.facetas([pt(cxw - r * 0.45, cy), pt(cxw, cy - ry * 0.45), pt(cxw + r * 0.45, cy), pt(cxw, cy + ry * 0.45)],
                  c('#8a6a3a'), M_TELA, tam=10, var=0.06, normal=n_fija(0, -1, 0.35))
    # flecos
    for k in range(60):
        xw = xa + 8 + k * (xb - xa - 16) / 59
        for (y, d) in ((ya, -9), (yb, 9)):
            x0, y0 = pt(xw, y)
            p.linea([(x0, y0), (x0 + 0.5, y0 + d)], 1.4, c('#8a7050'), M_TELA)


def pintar_colgajos(p: Pintor):
    """Lo que cuelga de la viga: hierbas secas, una jaula vacia, cadenas."""
    rnd = random.Random(21)
    # manojos de hierbas
    for (x, largo) in ((300, 120), (1330, 100), (2470, 105), (1990, 90)):
        p.linea([(x, TECHO_Y), (x, TECHO_Y + largo * 0.35)], 2, c('#8a7050'), M_TELA)
        for k in range(14):
            a = rnd.uniform(-0.5, 0.5)
            l = largo * rnd.uniform(0.6, 1.0)
            x0, y0 = x + rnd.uniform(-4, 4), TECHO_Y + largo * 0.3
            p.linea([(x0, y0), (x0 + math.sin(a) * l * 0.6, y0 + l * 0.7), (x0 + math.sin(a) * l, y0 + l)],
                    rnd.uniform(1.5, 3.2), c('#6a6038') * rnd.uniform(0.7, 1.2), M_TELA, alto=90)
        p.rect(x - 8, TECHO_Y + largo * 0.28, x + 8, TECHO_Y + largo * 0.36, c('#9a7a50'), M_TELA, tam=6, alto=90)
    # jaula vacia
    jx, jtop, jbot, jr = 1740, 262, 352, 34
    p.cadena(jx, TECHO_Y, jx, jtop - 18, 10, 2.2)
    p.linea(arco(jx, jtop - 12, 6, 6, 0, 2 * math.pi, 12), 2, LATON, M_COBRE, alto=90)
    for k in range(9):
        t = k / 8
        xx = jx - jr + 2 * jr * t
        p.linea([(jx, jtop - 6), (xx, jtop + 20), (xx, jbot)], 1.6, LATON * 0.9, M_COBRE, alto=90)
    p.linea(arco(jx, jbot, jr, 6, 0, 2 * math.pi, 24), 3, LATON, M_COBRE, alto=90)
    p.linea(arco(jx, jtop + 22, jr, 5, 0, 2 * math.pi, 24), 2, LATON * 0.9, M_COBRE, alto=90)
    p.linea([(jx - 14, jtop + 56), (jx + 14, jtop + 56)], 2, LATON * 0.8, M_COBRE)   # palito
    # cadena con gancho
    p.cadena(1000, TECHO_Y, 1000, 330, 11, 2.4)
    p.linea(arco(1000, 344, 10, 12, -math.pi * 0.5, math.pi * 0.9, 12), 3.5, HIERRO * 1.4, M_HIERRO, alto=90)
    # ristra de ajos
    x = 2400
    p.linea([(x, TECHO_Y), (x, TECHO_Y + 30)], 2, c('#8a7050'), M_TELA)
    for k in range(7):
        yy = TECHO_Y + 40 + k * 16
        xx = x + (7 if k % 2 else -7)
        p.facetas(arco(xx, yy, 10, 9, 0, 2 * math.pi, 12), c('#d8ccb0'), M_PAPEL, tam=6,
                  normal=n_esfera(xx, yy, 10, 9), alto=90)


def pintar_botellas(p: Pintor):
    for (x, h, w, col) in ((1428, 64, 20, c('#23321f')), (1452, 50, 17, c('#3a2418'))):
        cuerpo = [(x, PARED_Y + 12 - h * 0.62), (x + w, PARED_Y + 12 - h * 0.62), (x + w, PARED_Y + 12), (x, PARED_Y + 12)]
        p.facetas(cuerpo, col, M_CRISTAL, tam=8, normal=n_cil_v(x + w / 2, w / 2), alto=180)
        p.facetas([(x + 2, PARED_Y + 12 - h * 0.62), (x + w / 2 - 3, PARED_Y + 12 - h), (x + w / 2 + 3, PARED_Y + 12 - h),
                   (x + w - 2, PARED_Y + 12 - h * 0.62)], col, M_CRISTAL, tam=6, normal=n_cil_v(x + w / 2, w / 2), alto=180)
        p.linea([(x + 4, PARED_Y + 12 - h * 0.55), (x + 4, PARED_Y + 6)], 1.5, col * 3.5, M_CRISTAL)
    # una tumbada
    p.facetas(arco(1484, PARED_Y + 14, 22, 8, 0, 2 * math.pi, 16), c('#2a3a26'), M_CRISTAL, tam=7,
              normal=n_cil_h(PARED_Y + 14, 8), alto=180)


def calavera(p: Pintor, x, y_base, r=13):
    """Calavera pequena de perfil tres cuartos."""
    hueso = c('#d6c7a2')
    p.facetas(arco(x, y_base - r * 1.25, r, r * 0.95, 0, 2 * math.pi, 18), hueso, M_PAPEL, tam=6,
              normal=n_esfera(x, y_base - r * 1.25, r, r), alto=150)
    p.facetas([(x - r * 0.7, y_base - r * 0.6), (x + r * 0.75, y_base - r * 0.6), (x + r * 0.55, y_base),
               (x - r * 0.45, y_base)], hueso * 0.9, M_PAPEL, tam=5, alto=150)
    for ox in (-0.38, 0.4):
        p.elipse(x + r * ox, y_base - r * 1.05, r * 0.26, r * 0.3, c('#140c08'), M_HIERRO)
    p.poli([(x, y_base - r * 0.72), (x - r * 0.12, y_base - r * 0.5), (x + r * 0.12, y_base - r * 0.5)], c('#140c08'), M_HIERRO,
           luz_local=False)
    for k in range(4):
        xx = x - r * 0.3 + k * r * 0.2
        p.linea([(xx, y_base - r * 0.35), (xx, y_base - 1)], 1, c('#3a2a1a'), M_PAPEL)


def pintar_estante(p: Pintor):
    """Balda larga entre el potro y la puerta torcida: tarros, libros, una
    calavera. Lo de 'toda suerte de artilugios'."""
    y, x0, x1 = 604, 1262, 1580
    rnd = random.Random(44)
    for bx in (1284, 1556):
        p.poli([(bx, y + 12), (bx + 12, y + 12), (bx + 12, y + 60), (bx + 6, y + 60)], MADERA * 0.8, M_MADERA, alto=120)
    # objetos (base en y)
    x = x0 + 8
    objetos = ['tarro', 'libros', 'tarro', 'calavera', 'tarro', 'libros', 'vela', 'tarro', 'tarro']
    for o in objetos:
        if o == 'tarro':
            w, hh = rnd.uniform(18, 30), rnd.uniform(26, 48)
            col = [c('#3b4a30'), c('#5a3a22'), c('#40304a'), c('#6a5a3a'), c('#2e3e44')][rnd.randrange(5)]
            p.facetas([(x, y - hh), (x + w, y - hh), (x + w, y), (x, y)], col, M_CRISTAL, tam=8,
                      normal=n_cil_v(x + w / 2, w / 2), alto=140)
            p.rect(x - 1, y - hh - 6, x + w + 1, y - hh, c('#8a6a44'), M_MADERA, tam=6, alto=140)
            # algo dentro: una silueta clara (raiz, ojo, bicho)
            if rnd.random() < 0.6:
                p.elipse(x + w / 2, y - hh * 0.45, w * 0.22, hh * 0.18, col * 2.2, M_CRISTAL)
            p.linea([(x + 3, y - hh + 4), (x + 3, y - 4)], 1.4, col * 3.0, M_CRISTAL)
            x += w + rnd.uniform(4, 10)
        elif o == 'libros':
            for k in range(rnd.randint(3, 5)):
                w, hh = rnd.uniform(8, 13), rnd.uniform(40, 58)
                col = [c('#5a2a20'), c('#2e3a2a'), c('#6a4a2a'), c('#3a2430')][rnd.randrange(4)]
                p.rect(x, y - hh, x + w, y, col, M_TELA, tam=6, normal=n_cil_v(x + w / 2, w / 2), alto=140)
                p.linea([(x + 1, y - hh * 0.8), (x + w - 1, y - hh * 0.8)], 1.3, c('#c8a860') * 0.8, M_PAPEL)
                x += w + 1
            # uno inclinado apoyado
            p.poli([(x, y), (x + 11, y), (x + 30, y - 50), (x + 19, y - 54)], c('#4a3020'), M_TELA, alto=140, normal=n_plano)
            x += 34
        elif o == 'calavera':
            calavera(p, x + 16, y, 14)
            x += 36
        elif o == 'vela':
            vela(p, x + 8, y, 26, 9, platillo=False)
            x += 20
    p.rect(x0, y, x1, y + 12, MADERA * 1.1, M_MADERA, tam=14, normal=n_cil_h(y + 6, 6), alto=150)


def pintar_reloj(p: Pintor):
    """Esfera de reloj sin agujas, junto al pendulo que no mueve nada."""
    cx, cy, r = 1690, 500, 50
    p.facetas([(cx + (r + 16) * math.cos(a), cy + (r + 16) * math.sin(a)) for a in np.linspace(math.pi / 8, math.tau + math.pi / 8, 8, endpoint=False)],
              MADERA * 0.9, M_MADERA, tam=14, alto=80)
    p.facetas(arco(cx, cy, r, r, 0, math.tau, 36), c('#cdbb8e'), M_PAPEL, tam=14, var=0.03)
    p.linea(arco(cx, cy, r - 2, r - 2, 0, math.tau, 36), 2.5, LATON, M_COBRE)
    for k in range(12):
        a = k * math.tau / 12
        l = 9 if k % 3 == 0 else 5
        p.linea([(cx + math.cos(a) * (r - 6), cy + math.sin(a) * (r - 6)),
                 (cx + math.cos(a) * (r - 6 - l), cy + math.sin(a) * (r - 6 - l))], 2.4 if k % 3 == 0 else 1.4,
                c('#2a1a10'), M_PAPEL)
    p.elipse(cx, cy, 3, 3, c('#2a1a10'), M_HIERRO)   # el eje, sin agujas


def pintar_retrato(p: Pintor):
    """Retrato ovalado de un nino, casi perdido en la penumbra. Es Dominus de
    pequeno (el relato: encerrado en un sarcofago de nino), pero no se dice."""
    cx, cy, rx, ry = 2512, 430, 60, 78
    p.facetas(arco(cx, cy, rx + 14, ry + 14, 0, math.tau, 32), c('#8a6a34'), M_COBRE, tam=12, var=0.08,
              normal=n_esfera(cx, cy, rx + 30, ry + 30), alto=70)
    p.facetas(arco(cx, cy, rx, ry, 0, math.tau, 32), c('#231a14'), M_TELA, tam=18, var=0.06)
    # cara palida, pelo oscuro, cuello blanco
    p.facetas(arco(cx, cy - 6, 20, 26, 0, math.tau, 20), c('#5e4c3e'), M_TELA, tam=8, var=0.04,
              normal=n_esfera(cx, cy - 6, 22, 28))
    p.facetas(arco(cx, cy - 22, 24, 16, math.pi, math.tau, 12) + [(cx + 24, cy - 12), (cx - 24, cy - 12)],
              c('#1a120c'), M_TELA, tam=8)
    for ox in (-8, 8):
        p.elipse(cx + ox, cy - 6, 2.6, 2.0, c('#0c0806'), M_TELA)
    p.facetas([(cx - 36, ry + cy - 14), (cx - 16, cy + 22), (cx + 16, cy + 22), (cx + 36, ry + cy - 14)],
              c('#3a2c22'), M_TELA, tam=10)
    p.poli([(cx - 14, cy + 20), (cx + 14, cy + 20), (cx, cy + 32)], c('#7a705c'), M_PAPEL, luz_local=False)


def pintar_capa(p: Pintor):
    """Una capa oscura colgada de un clavo a la izquierda de la entrada."""
    x = 62
    p.elipse(x, 690, 5, 5, HIERRO * 1.5, M_HIERRO)
    capa = [(x - 8, 692), (x + 10, 692), (x + 34, 760), (x + 44, 900), (x + 30, 1010), (x - 10, 1030), (x - 36, 1000),
            (x - 30, 860), (x - 20, 760)]
    p.facetas(capa, c('#2a2622'), M_TELA, tam=26, var=0.08, normal=n_cil_v(x, 40), alto=120)
    for k in range(3):
        xx = x - 12 + k * 14
        p.linea([(xx, 720), (xx + (k - 1) * 8, 1000)], 1.5, c('#141210'), M_TELA)


def telarana(p: Pintor, x, y, r, a0, a1, semilla, radios=9):
    """Telarana de rincon: radios desde la esquina y hilos combados entre ellos.
    Lineas de medio pixel (1 px a tamano S): salen translucidas al reducir,
    como las del titulo."""
    rnd = random.Random(semilla)
    angs = sorted(a0 + (a1 - a0) * (i + rnd.uniform(-0.3, 0.3)) / (radios - 1) for i in range(radios))
    largos = [r * rnd.uniform(0.7, 1.05) for _ in angs]
    col = c('#d8ccb8')
    d = p.d
    def lin(pts):
        P = p._p(pts)
        d['alb'].line(P, fill=a255(col), width=1)
        d['mat'].line(P, fill=M_TELA, width=1)
        d['emi'].line(P, fill=(0, 0, 0), width=1)
        d['cob'].line(P, fill=160, width=1)
    for a, l in zip(angs, largos):
        lin([(x, y), (x + math.cos(a) * l, y + math.sin(a) * l)])
    k = 0.12
    while k < 1.0:
        for i in range(len(angs) - 1):
            if rnd.random() < 0.12:
                continue
            a, b = angs[i], angs[i + 1]
            la, lb = largos[i] * k, largos[i + 1] * k
            pa = (x + math.cos(a) * la, y + math.sin(a) * la)
            pb = (x + math.cos(b) * lb, y + math.sin(b) * lb)
            mx, my = (pa[0] + pb[0]) / 2, (pa[1] + pb[1]) / 2
            # comba hacia la esquina
            mx += (x - mx) * 0.12
            my += (y - my) * 0.12
            lin([pa, (mx, my), pb])
        k += rnd.uniform(0.07, 0.14)
    # hilos sueltos que cuelgan
    for _ in range(3):
        a = rnd.uniform(a0, a1)
        l = r * rnd.uniform(0.3, 0.9)
        px, py = x + math.cos(a) * l, y + math.sin(a) * l
        lin([(px, py), (px + rnd.uniform(-6, 6), py + rnd.uniform(30, 90))])


def pintar_telaranas(p: Pintor):
    telarana(p, 0, TECHO_Y, 190, 0.0, math.pi / 2, 1)
    telarana(p, 404, TECHO_Y, 130, 0.0, math.pi / 2, 2, 7)
    telarana(p, 1858, TECHO_Y, 150, math.pi / 2, math.pi, 3, 7)
    telarana(p, 1886, TECHO_Y, 120, 0.0, math.pi / 2, 4, 6)
    telarana(p, 2700, TECHO_Y, 110, math.pi / 2, math.pi * 0.95, 5, 6)
    telarana(p, 822, 372, 90, -math.pi * 0.1, math.pi * 0.55, 6, 6)      # esquina del organo


# --------------------------------------------------------------------------
# Revelado
# --------------------------------------------------------------------------

def ruido_estirado(w, h, ex, ey, semilla, octavas=3):
    """Ruido de valor estirado: ex, ey = tamano del grano en x y en y."""
    n = ruido_valor(max(4, int(w / ex * 8)), max(4, int(h / ey * 8)), 8, octavas, semilla, False)
    img = Image.fromarray((n * 255).astype(np.uint8), 'L').resize((w, h), Image.BICUBIC)
    return np.asarray(img, np.float32) / 255.0


def grietas(w, h, n, semilla, zona=None):
    """Grietas finas de yeso: paseos aleatorios que se ramifican."""
    rnd = random.Random(semilla)
    img = Image.new('L', (w * S, h * S), 0)
    d = ImageDraw.Draw(img)
    for _ in range(n):
        if zona:
            x, y = rnd.uniform(zona[0], zona[2]), rnd.uniform(zona[1], zona[3])
        else:
            x, y = rnd.uniform(0, w), rnd.uniform(0, h)
        a = rnd.uniform(0, math.tau)
        pilas = [(x, y, a, rnd.uniform(60, 220), 1.6)]
        while pilas:
            x, y, a, largo, g = pilas.pop()
            pasos = int(largo / 7)
            for _ in range(pasos):
                a += rnd.gauss(0, 0.45)
                nx, ny = x + math.cos(a) * 7, y + math.sin(a) * 7
                d.line([(x * S, y * S), (nx * S, ny * S)], fill=int(90 + 120 * g / 1.6), width=max(1, int(g * S * 0.8)))
                x, y = nx, ny
                if rnd.random() < 0.07 and g > 0.6:
                    pilas.append((x, y, a + rnd.choice((-1, 1)) * rnd.uniform(0.5, 1.2), largo * 0.5, g * 0.7))
                g = max(0.5, g * 0.985)
    return np.asarray(img.resize((w, h), Image.LANCZOS), np.float32) / 255.0


def revelar(p: Pintor, fondo=True, luz_fija=None, semilla=3):
    """Aplica texturas, sombras, luz, resplandor, vineta y grano.
    fondo=True: la pantalla entera (opaca). False: un sprite (devuelve RGBA).
    luz_fija: para piezas que se mueven (pendulo), la luz de un punto fijo."""
    alb, emi, mat, alto, cob = p.reducir()
    h, w = alb.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    X = xx + p.ox
    Y = yy + p.oy

    # --- texturas -----------------------------------------------------------
    n_medio = ruido_valor(w, h, 60, 4, semilla + 1, False)
    n_bajo = ruido_valor(w, h, 420, 4, semilla + 2, False)
    tex = np.ones((h, w), np.float32)
    es = lambda *ms: np.isin(mat, ms)
    tex *= 0.94 + 0.12 * n_medio
    yeso = es(M_YESO)
    if yeso.any():
        manchas = 0.78 + 0.34 * n_bajo
        gr = grietas(w, h, 70 if fondo else 0, semilla + 5) if fondo else np.zeros((h, w), np.float32)
        tex = np.where(yeso, tex * manchas * (1 - 0.4 * gr), tex)
        # humedad que baja desde la viga
        chorreo = ruido_estirado(w, h, 40, 260, semilla + 6)
        cerca_techo = np.clip(1 - (Y - TECHO_Y) / 420, 0, 1)
        tex = np.where(yeso, tex * (1 - 0.22 * cerca_techo * chorreo), tex)
    madera_h = es(M_MADERA, M_TECHO)
    madera_v = es(M_MADERA_V)
    if madera_h.any():
        veta = ruido_estirado(w, h, 220, 5, semilla + 7)
        tex = np.where(madera_h, tex * (0.84 + 0.3 * veta), tex)
    if madera_v.any():
        veta = ruido_estirado(w, h, 5, 220, semilla + 8)
        tex = np.where(madera_v, tex * (0.84 + 0.3 * veta), tex)
    suelo = es(M_SUELO)
    if suelo.any():
        veta = ruido_estirado(w, h, 6, 160, semilla + 9)
        gastado = np.exp(-((Y - 1330) / 140) ** 2) * np.clip(1 - np.abs(X - 1100) / 1200, 0, 1)
        tex = np.where(suelo, tex * (0.82 + 0.3 * veta) * (1 + 0.12 * gastado) * (0.85 + 0.25 * n_bajo), tex)
    piedra = es(M_PIEDRA)
    if piedra.any():
        n_fino = ruido_valor(w, h, 14, 3, semilla + 10, False)
        tex = np.where(piedra, tex * (0.8 + 0.35 * n_fino), tex)
    metal = es(M_HIERRO, M_COBRE)
    if metal.any():
        n_fino = ruido_valor(w, h, 10, 2, semilla + 11, False)
        tex = np.where(metal, tex * (0.9 + 0.2 * n_fino), tex)
    col = alb * tex[..., None]

    # --- hollin de la chimenea ----------------------------------------------
    if fondo:
        hollin = np.exp(-(((X - 2793) / 120) ** 2 + ((Y - 700) / 260) ** 2) * 1.0) * (Y < 740) * (Y > TECHO_Y)
        col *= (1 - 0.7 * hollin)[..., None]

    # --- sombras de contacto --------------------------------------------------
    if fondo:
        occ = ndimage.gaussian_filter(alto, 22)
        sombra = ndimage.shift(ndimage.gaussian_filter(alto, 16), (10, -24), order=1, mode='constant')
        recibe = es(M_YESO, M_SUELO, M_PIEDRA, M_MADERA_V, M_MADERA)
        # lo que sobresale no se sombrea a si mismo
        propio = np.clip(alto * 1.6, 0, 1)
        fuerza = (0.55 * sombra + 0.35 * occ) * (1 - propio)
        col = np.where(recibe[..., None], col * (1 - np.clip(fuerza, 0, 0.75))[..., None], col)
        # contacto con el suelo justo debajo de la pared
        pie = np.exp(-np.clip(Y - PARED_Y, 0, None) / 26) * (Y >= PARED_Y)
        col *= (1 - 0.45 * pie)[..., None]

    # --- luz ---------------------------------------------------------------
    if luz_fija is not None:
        L = luz_rgb(np.array([[luz_fija[0]]], np.float32), np.array([[luz_fija[1]]], np.float32))
        L = np.broadcast_to(L, (h, w, 3))
        # variacion vertical leve: la parte de abajo recibe algo mas de la chimenea
        L = L * (0.9 + 0.2 * (yy / max(h, 1)))[..., None]
    else:
        L = luz_rgb(X, Y)
    exterior = es(M_EXTERIOR, M_NADA)
    lit = col * L
    # brillo especular en metal: la luz alta se refleja
    lum = L.mean(axis=2, keepdims=True)
    # (el reflejo del metal va por faceta, en factor_faceta; aqui solo un toque)
    spec = np.where(es(M_COBRE, M_HIERRO)[..., None], 0.12, 0.0)
    lit = lit + spec * alb.mean(axis=2, keepdims=True) * L * np.clip(lum - 0.8, 0, None)
    lit = np.where(exterior[..., None], col * 0.0, lit)
    # el interior del hogar no recibe de lleno su propio fuego: esta detras
    lit = np.where(es(M_HOLLIN)[..., None], lit * 0.4, lit)
    out = lit + emi

    # --- resplandor -------------------------------------------------------
    brillo = emi.copy()
    b1 = np.stack([ndimage.gaussian_filter(brillo[..., k], 6) for k in range(3)], -1)
    b2 = np.stack([ndimage.gaussian_filter(brillo[..., k], 28) for k in range(3)], -1)
    out = out + b1 * 0.35 + b2 * 0.45
    if fondo:
        # halo calido en el aire alrededor de las luces fuertes: la calina
        calina = np.zeros_like(out)
        for l in LUCES:
            if l.nombre == 'luna':
                continue
            d2 = ((X - l.x) ** 2 + (Y - l.y) ** 2) / (l.radio * 0.9) ** 2
            calina += (l.potencia * np.exp(-d2))[..., None] * l.color
        out = out + calina * 0.05

    # --- tono ----------------------------------------------------------------
    out = 1.0 - np.exp(-out * EXPOSICION)
    # sombras hacia marron muy oscuro, no hacia gris
    lumo = out.mean(axis=2, keepdims=True)
    # desaturar un 15%: el naranja puro de la luz calida chilla; el titulo es ambar apagado
    out = lumo + (out - lumo) * 0.85
    # sombras hacia un pardo algo violaceo (como el ataud), luces hacia el ambar
    sombra_t = np.array([0.95, 0.92, 1.02], np.float32)
    luz_t = np.array([1.04, 1.0, 0.92], np.float32)
    k = np.clip(lumo * 2.2, 0, 1)
    out = out * (sombra_t * (1 - k) + luz_t * k)
    if fondo:
        vx = (X - W * 0.55) / (W * 0.62)
        vy = (Y - H * 0.52) / (H * 0.68)
        v = np.clip(np.sqrt(vx ** 2 + vy ** 2), 0, 1.6)
        vin = 1 - 0.76 * np.clip((v - 0.45) / 0.85, 0, 1) ** 1.6
        # techo y parte baja mas oscuros: el foco es la franja de los personajes
        vin *= 1 - 0.45 * np.clip((TECHO_Y + 60 - Y) / 260, 0, 1)
        vin *= 1 - 0.55 * np.clip((Y - 1260) / 372, 0, 1) ** 1.2
        out *= vin[..., None]
    if fondo:
        # papel de acuarela: manchas grandes y fibra, como la referencia del bosque
        manchas_p = ruido_valor(w, h, 240, 5, semilla + 20, False)
        fibra = ruido_estirado(w, h, 3, 40, semilla + 21, 2)
        out *= (0.93 + 0.12 * manchas_p + 0.04 * (fibra - 0.5))[..., None]
    g = np.random.default_rng(semilla).normal(0, 1, (h, w)).astype(np.float32)
    g = ndimage.gaussian_filter(g, 0.6)
    out += (g * 0.012)[..., None]
    out = np.clip(out, 0, 1)
    if fondo:
        return out
    return np.concatenate([out, cob[..., None]], axis=-1)


def guardar_rgb(arr, ruta):
    Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGB').save(ruta, optimize=True)


def guardar_rgba(arr, ruta):
    Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA').save(ruta, optimize=True)


# --------------------------------------------------------------------------
# Fondo completo
# --------------------------------------------------------------------------

def fondo() -> np.ndarray:
    p = Pintor(W, H, semilla=11)
    pintar_techo(p)
    pintar_pared(p)
    pintar_entrada(p)
    pintar_puertas_pared(p)
    pintar_estante(p)
    pintar_reloj(p)
    pintar_retrato(p)
    pintar_capa(p)
    pintar_chimenea(p)
    pintar_suelo(p)
    pintar_trampilla(p)
    pintar_alfombra(p)
    pintar_libros(p, 1796, PARED_Y + 6)
    pintar_organo(p)
    pintar_potro(p)
    pintar_alambique(p)
    pintar_botellas(p)
    pintar_caldero(p)
    pintar_hacha(p)
    pintar_colgajos(p)
    pintar_telaranas(p)
    return revelar(p, fondo=True)


# --------------------------------------------------------------------------
# Piezas que se mueven
# --------------------------------------------------------------------------

PUERTA = (140, 750, 340, PARED_Y)   # hueco de la entrada: x0, y0, x1, y1
# Pendulo: la vara acaba en ENGANCHE (px bajo el pivote) y de ahi cuelga el
# incensario con tres cadenas. El total ronda LARGO_PENDULO.
ENGANCHE = 760.0
INCENSARIO_ALTO = 150      # del aro de las cadenas al pie


def sprite_puerta() -> np.ndarray:
    """Hoja de la puerta de entrada, cara de dentro, del tamano del hueco."""
    x0, y0, x1, y1 = PUERTA
    p = Pintor(x1 - x0, y1 - y0, x0, y0, semilla=71)
    puerta_tablas(p, x0, y0, x1, y1, MADERA_OSC * 1.25, tablas=5, lado_bisagra='izq', tam=30)
    # travesanos y cruz de refuerzo por dentro
    for yy in (y0 + 70, y1 - 70):
        p.rect(x0 + 4, yy - 12, x1 - 4, yy + 12, MADERA * 0.8, M_MADERA, tam=16, normal=n_cil_h(yy, 12))
    p.poli([(x0 + 10, y1 - 82), (x0 + 30, y1 - 82), (x1 - 10, y0 + 82), (x1 - 30, y0 + 82)], MADERA * 0.7, M_MADERA,
           normal=n_plano)
    # mirilla con rejilla
    p.rect(x0 + 80, y0 + 110, x0 + 124, y0 + 150, c('#101828'), M_EXTERIOR, tam=10, emi=c('#1a2848'))
    for k in range(3):
        xx = x0 + 88 + k * 14
        p.linea([(xx, y0 + 108), (xx, y0 + 152)], 3, HIERRO * 1.3, M_HIERRO)
    img = revelar(p, fondo=False, semilla=12)
    # borde de luna por la rendija de la derecha (es por donde se abre)
    h, w = img.shape[:2]
    borde = np.clip(1 - np.arange(w)[::-1] / 6.0, 0, 1)[None, :, None] * 0.18
    img[..., :3] += borde * c('#7d9fe0')
    return img


def sprite_vara() -> np.ndarray:
    """Vara del pendulo, del pivote al enganche. Sin mecanismo arriba: se
    pierde en la oscuridad del techo."""
    ancho = 36
    ox, oy = PIVOTE[0] - ancho / 2, PIVOTE[1]
    largo = int(ENGANCHE) + 10
    p = Pintor(ancho, largo, ox, oy, semilla=81)
    cx = PIVOTE[0]
    y_ini, y_fin = PIVOTE[1], PIVOTE[1] + ENGANCHE
    p.facetas([(cx - 4, y_ini), (cx + 4, y_ini), (cx + 3.5, y_fin), (cx - 3.5, y_fin)], HIERRO * 1.2, M_HIERRO,
              tam=6, normal=n_cil_v(cx, 4.5))
    # collarines a lo largo, como en un pendulo de reloj de torre
    for yy, r in ((y_ini + 300, 7), (y_ini + 520, 8), (y_fin - 60, 9)):
        p.facetas([(cx - r, yy - 5), (cx + r, yy - 5), (cx + r, yy + 5), (cx - r, yy + 5)], LATON * 0.9, M_COBRE,
                  tam=5, normal=n_cil_v(cx, r))
    # rombo ornamental antes del enganche
    yy = y_fin - 26
    p.facetas([(cx, yy - 22), (cx + 13, yy), (cx, yy + 22), (cx - 13, yy)], LATON, M_COBRE, tam=6,
              normal=n_esfera(cx, yy, 14, 24))
    # aro del enganche
    p.linea(arco(cx, y_fin, 7, 7, 0, math.tau, 16), 3, LATON * 1.1, M_COBRE)
    img = revelar(p, fondo=False, luz_fija=(1450, 760), semilla=13)
    # arriba se funde con la oscuridad del techo
    h = img.shape[0]
    osc = np.clip((np.arange(h) - 40) / 360.0, 0.08, 1.0) ** 1.4
    img[..., :3] *= osc[:, None, None]
    return img


def sprite_incensario() -> np.ndarray:
    """Incensario de laton: aro, tres cadenas, tapa calada con brasa dentro,
    cuenco y pie. Arriba del sprite esta el aro, que cuelga del enganche."""
    ancho, alto = 130, INCENSARIO_ALTO + 10
    cx = 1450.0
    top = PIVOTE[1] + ENGANCHE             # coordenada de pantalla en reposo
    p = Pintor(ancho, alto, cx - ancho / 2, top - 6, semilla=91)
    y_tapa = top + 62                       # borde de la tapa
    y_cuenco = y_tapa + 6
    # cadenas: del aro a tres puntos del borde (la de atras mas oscura)
    p.cadena(cx, top + 4, cx, y_tapa - 30, 7, 1.6, HIERRO * 0.7)
    p.cadena(cx, top + 4, cx - 40, y_tapa, 7, 1.8, LATON * 0.8)
    p.cadena(cx, top + 4, cx + 40, y_tapa, 7, 1.8, LATON * 0.8)
    p.linea(arco(cx, top + 2, 6, 6, 0, math.tau, 14), 2.5, LATON * 1.1, M_COBRE)
    # tapa: cupula con remate
    tapa = [(cx - 42, y_tapa)] + arco(cx, y_tapa, 42, 44, math.pi, math.tau, 18) + [(cx + 42, y_tapa)]
    p.facetas(tapa, LATON, M_COBRE, tam=9, var=0.06, normal=n_esfera(cx, y_tapa, 44, 48))
    p.facetas([(cx - 6, y_tapa - 42), (cx + 6, y_tapa - 42), (cx + 3, y_tapa - 56), (cx - 3, y_tapa - 56)], LATON * 1.1,
              M_COBRE, tam=4, normal=n_cil_v(cx, 6))
    p.elipse(cx, y_tapa - 58, 5, 5, LATON * 1.2, M_COBRE)
    # calados de la tapa: la brasa se ve por dentro
    rnd = random.Random(3)
    for fila, (ry, n, rr) in enumerate(((y_tapa - 10, 7, 4.2), (y_tapa - 24, 5, 3.6), (y_tapa - 35, 3, 3.0))):
        semi = math.sqrt(max(0.0, 1 - ((ry - y_tapa) / 44) ** 2)) * 38
        for k in range(n):
            xx = cx - semi + (2 * semi) * (k + 0.5) / n
            cal = rnd.uniform(0.6, 1.0) * (1.0 - fila * 0.2)
            p.poli([(xx, ry - rr), (xx + rr * 0.8, ry + rr * 0.6), (xx - rr * 0.8, ry + rr * 0.6)], c('#3a1206'), M_NADA,
                   emi=c('#ff7a2a') * cal * 1.3, luz_local=False)
    # aro del borde
    p.facetas([(cx - 46, y_tapa - 3), (cx + 46, y_tapa - 3), (cx + 46, y_cuenco), (cx - 46, y_cuenco)], LATON * 1.1,
              M_COBRE, tam=6, normal=n_cil_v(cx, 46))
    # cuenco
    cuenco = [(cx + 44 * math.cos(t), y_cuenco + 40 * math.sin(t)) for t in np.linspace(0, math.pi, 20)]
    p.facetas(cuenco, LATON * 0.85, M_COBRE, tam=9, var=0.06, normal=n_esfera(cx, y_cuenco - 6, 46, 50))
    # banda grabada
    p.linea([(cx + 42 * math.cos(t), y_cuenco + 14 + 4.4 * math.sin(t)) for t in np.linspace(0.25, math.pi - 0.25, 14)],
            2, LATON * 0.5, M_COBRE)
    # pie
    p.facetas([(cx - 12, y_cuenco + 38), (cx + 12, y_cuenco + 38), (cx + 20, y_cuenco + 52), (cx - 20, y_cuenco + 52)],
              LATON * 0.9, M_COBRE, tam=6, normal=n_cil_v(cx, 20))
    return revelar(p, fondo=False, luz_fija=(1450, 880), semilla=14)


def textura_humo(n=128, semilla=4) -> np.ndarray:
    """Bocanada blanda, no un circulo perfecto: borde deshilachado con ruido."""
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.sqrt((xx - n / 2) ** 2 + (yy - n / 2) ** 2) / (n / 2)
    rui = ruido_valor(n, n, 22, 4, semilla, True)
    a = np.clip(1 - r * (0.85 + 0.5 * rui), 0, 1) ** 1.8
    a = ndimage.gaussian_filter(a, 1.5)
    out = np.ones((n, n, 4), np.float32)
    out[..., 3] = a / a.max()
    return out


def textura_halo(n=256) -> np.ndarray:
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.sqrt((xx - n / 2 + 0.5) ** 2 + (yy - n / 2 + 0.5) ** 2) / (n / 2)
    a = np.exp(-(r ** 2) * 4.0) * np.clip(1 - r, 0, 1) ** 0.5
    out = np.ones((n, n, 4), np.float32)
    out[..., 3] = a
    return out


def textura_punto(n=32) -> np.ndarray:
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.sqrt((xx - n / 2 + 0.5) ** 2 + (yy - n / 2 + 0.5) ** 2) / (n / 2)
    out = np.ones((n, n, 4), np.float32)
    out[..., 3] = np.clip(1 - r, 0, 1) ** 1.6
    return out


def textura_burbuja(n=32) -> np.ndarray:
    """Burbuja del caldo: cupula con brillo arriba. Blanca: el tono lo da Godot."""
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.sqrt((xx - n / 2 + 0.5) ** 2 + (yy - n / 2 + 0.5) ** 2) / (n / 2 - 1)
    aro = np.clip(1 - np.abs(r - 0.82) / 0.16, 0, 1)
    dentro = np.clip(1 - r, 0, 1) * 0.35
    brillo = np.exp(-(((xx - n * 0.38) / (n * 0.1)) ** 2 + ((yy - n * 0.32) / (n * 0.08)) ** 2))
    out = np.ones((n, n, 4), np.float32)
    v = np.clip(0.55 + 0.45 * brillo, 0, 1)
    out[..., 0] = out[..., 1] = out[..., 2] = v
    out[..., 3] = np.clip(np.maximum(aro * 0.8, dentro) + brillo * 0.9, 0, 1) * (r < 1.05)
    return out


def textura_llama(w=32, h=80) -> np.ndarray:
    """Llama de vela en gota: nucleo casi blanco, borde naranja, pie azulado."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    v = yy / (h - 1)                        # 0 arriba, 1 abajo
    base = 0.78
    anchura = np.where(v < base, (v / base) ** 0.7, np.clip(1 - (v - base) / (1 - base), 0, 1) ** 0.6) * 0.46
    d = np.abs(xx - w / 2 + 0.5) / (w / 2)
    a = np.clip(1 - d / np.maximum(anchura, 1e-3), 0, 1) ** 0.9
    a = ndimage.gaussian_filter(a, 0.8)
    nucleo = np.clip(1 - d / np.maximum(anchura * 0.45, 1e-3), 0, 1) * np.clip((v - 0.35) / 0.4, 0, 1)
    naranja, amarillo, blanco, azul = c('#ff8a2a'), c('#ffd27a'), c('#fff6e0'), c('#6a7aff')
    t = np.clip(a * 1.3, 0, 1)[..., None]
    col = naranja * (1 - t) + amarillo * t
    col = col * (1 - nucleo[..., None]) + blanco * nucleo[..., None]
    pie = np.clip((v - 0.84) / 0.12, 0, 1)[..., None] * 0.6
    col = col * (1 - pie) + azul * pie
    return np.concatenate([col, a[..., None]], -1)


def textura_ruido_fuego(n=128, semilla=9) -> np.ndarray:
    """Ruido que se repite en x y en y (filtrado en frecuencia), para que el
    fuego pueda desplazarlo hacia arriba sin costuras."""
    rs = np.random.default_rng(semilla)
    blanco = rs.normal(0, 1, (n, n))
    f = np.fft.fft2(blanco)
    ky = np.fft.fftfreq(n)[:, None]
    kx = np.fft.fftfreq(n)[None, :]
    k = np.sqrt(kx ** 2 + ky ** 2) + 1e-6
    f *= k ** -1.5 * (k < 0.25)
    r = np.real(np.fft.ifft2(f))
    r = (r - r.min()) / (r.max() - r.min())
    out = np.ones((n, n, 4), np.float32)
    out[..., 0] = out[..., 1] = out[..., 2] = r
    return out


def sprite_viga_frente() -> np.ndarray:
    """Viga de primer plano, casi negra, con el canto de abajo tocado de luz,
    y una cuerda y una cadena que cuelgan. Tapa el pivote del pendulo: no hay
    mecanismo que ver."""
    alto = 300
    p = Pintor(W, alto, 0, 0, semilla=101)
    borde = [(x, 64 + 7 * math.sin(x / 310.0) + 3 * math.sin(x / 57.0)) for x in np.linspace(0, W, 60)]
    p.facetas([(0, 0), (W, 0)] + borde[::-1], MADERA_OSC * 0.35, M_TECHO, tam=40, var=0.1)
    p.linea(borde, 3, MADERA * 0.9, M_MADERA)
    p.linea([(2380, 60), (2384, 180), (2378, 250)], 5, c('#3a3026'), M_TELA)
    p.elipse(2380, 186, 7, 9, c('#3a3026'), M_TELA)
    p.cadena(620, 60, 620, 150, 13, 3.2, HIERRO * 0.6)
    p.linea(arco(620, 164, 12, 14, -math.pi * 0.5, math.pi * 0.9, 12), 4.5, HIERRO * 0.7, M_HIERRO)
    img = revelar(p, fondo=False, luz_fija=(1456, 500), semilla=15)
    img[..., :3] *= 0.45
    # desenfoque leve: esta mucho mas cerca que el foco
    for k in range(4):
        img[..., k] = ndimage.gaussian_filter(img[..., k], 1.4)
    return img


def _silueta(p: Pintor, luz, oscuro=0.32, desenfoque=1.8) -> np.ndarray:
    """Revela un sprite de primer plano: mucho mas oscuro que el foco y algo
    desenfocado, porque esta pegado a la camara."""
    img = revelar(p, fondo=False, luz_fija=luz, semilla=16)
    img[..., :3] *= oscuro
    for k in range(4):
        img[..., k] = ndimage.gaussian_filter(img[..., k], desenfoque)
    return img


ESQ_IZQ = (0, 1236, 440, 396)      # x, y, ancho, alto en pantalla
ESQ_DER = (2500, 1380, 412, 252)


def sprite_esquina_izq() -> np.ndarray:
    """Respaldo de un sillon de brazos visto por detras, pegado a la camara:
    enmarca la esquina y quita suelo vacio. Queda por debajo de los pies de
    Magnus (y = 1200), asi que nunca lo tapa. Canto azul de luna por la
    izquierda (la puerta) y calido por la derecha."""
    x0, y0, w, h = ESQ_IZQ
    p = Pintor(w, h, x0, y0, semilla=111)
    madera = MADERA_OSC * 0.9
    p.facetas([(46, 1632), (46, 1330), (72, 1280), (104, 1330), (104, 1632)], madera, M_MADERA_V, tam=22)
    p.facetas([(318, 1632), (318, 1340), (342, 1296), (370, 1340), (370, 1632)], madera, M_MADERA_V, tam=22)
    p.facetas([(72, 1330), (200, 1284), (344, 1340), (344, 1388), (200, 1338), (72, 1380)], madera * 1.1, M_MADERA, tam=20)
    p.facetas([(104, 1392), (318, 1400), (318, 1632), (104, 1632)], c('#3a1c16'), M_TELA, tam=34, var=0.07,
              normal=n_cil_v(211, 150))
    for k in range(7):
        p.elipse(118 + k * 32, 1404, 4.5, 4.5, LATON * 0.8, M_COBRE)
    p.facetas([(370, 1480), (436, 1462), (440, 1492), (374, 1516)], madera, M_MADERA, tam=16)
    # cantos de luz
    p.linea([(46, 1632), (46, 1330), (72, 1280)], 3, c('#6a86c0') * 1.6, M_NADA, emi=c('#3a4a70'))
    p.linea([(72, 1330), (200, 1284), (344, 1340)], 2.5, c('#c08050'), M_NADA, emi=c('#40220e'))
    p.linea([(342, 1296), (370, 1340), (370, 1632)], 2.5, c('#c08050'), M_NADA, emi=c('#301a0a'))
    return _silueta(p, (380, 1100), oscuro=0.4)


def sprite_esquina_der() -> np.ndarray:
    """Tonel pegado a la camara en la esquina de la chimenea, cortado por el
    borde: duelas, dos aros de hierro y la tapa vista desde arriba, con el
    canto encendido por el fuego. (Un monton de lenos redondos parecia balas
    de canon, y partidos un estampado de lunares.)"""
    x0, y0, w, h = ESQ_DER
    p = Pintor(w, h, x0, y0, semilla=121)
    cx, ytapa, rx, ry = 2790, 1452, 176, 40
    duela = c('#4a3020')

    def ancho(y):   # el tonel se abomba hacia abajo
        t = (y - ytapa) / 300.0
        return rx * (1.0 + 0.1 * math.sin(min(t, 1.0) * math.pi))
    cuerpo = [(cx - ancho(y), y) for y in np.linspace(ytapa, 1640, 10)] +              [(cx + ancho(y), y) for y in np.linspace(1640, ytapa, 10)]
    p.facetas(cuerpo, duela, M_MADERA_V, tam=26, var=0.06, normal=n_cil_v(cx, rx * 1.1))
    for k in range(-5, 6):
        u = k / 6.0
        p.linea([(cx + ancho(y) * u, y + ry * math.sqrt(max(0.0, 1 - u * u))) for y in np.linspace(ytapa, 1640, 8)],
                2, duela * 0.45, M_MADERA_V)
    for yh in (1500, 1600):
        pts = arco(cx, yh, ancho(yh) + 2, ry, 0.0, math.pi, 20)
        p.linea(pts, 12, HIERRO * 0.9, M_HIERRO)
        p.linea([(x, y - 4) for x, y in pts[:8]], 2.5, c('#c07a44'), M_NADA, emi=c('#3a1a08'))
    # tapa de tablas
    p.facetas(arco(cx, ytapa, rx + 6, ry + 4, 0, math.tau, 36), duela * 0.7, M_MADERA, tam=20)
    p.facetas(arco(cx, ytapa, rx - 8, ry - 6, 0, math.tau, 36), c('#5a3c26'), M_MADERA, tam=22, var=0.06,
              normal=n_fija(0.2, -0.9, 0.5))
    for k in (-2, -1, 0, 1, 2):
        xx = cx + k * 58
        yy = ry * math.sqrt(max(0.0, 1 - ((xx - cx) / rx) ** 2))
        p.linea([(xx, ytapa - yy + 6), (xx, ytapa + yy - 6)], 1.6, c('#2a1a10'), M_MADERA)
    # filo de luz de la chimenea en el borde de la tapa (lado del fuego)
    p.linea(arco(cx, ytapa, rx + 5, ry + 3, math.pi * 1.1, math.pi * 1.75, 16), 3, c('#e09050'), M_NADA,
            emi=c('#5a2a0e'))
    return _silueta(p, (2700, 1350), oscuro=0.3, desenfoque=1.6)


def textura_luz_puerta(w=512, h=256) -> np.ndarray:
    """Charco de luna en el suelo al abrir la puerta: se abre hacia la camara."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    v = yy / (h - 1)
    x_rel = (xx - w * 0.3) / (w * 0.5)
    ancho = 0.28 + 0.55 * v
    centro = 0.5 * v
    d = np.abs(x_rel - centro) / ancho
    a = np.clip(1 - d, 0, 1) ** 1.5 * np.clip(1 - v, 0, 1) ** 0.8 * np.clip(v * 6, 0, 1)
    a = ndimage.gaussian_filter(a, 6)
    out = np.ones((h, w, 4), np.float32)
    out[..., 3] = a / max(a.max(), 1e-6)
    return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    out = args[0] if args else '.'
    solo_sprites = '--solo-sprites' in sys.argv
    os.makedirs(out, exist_ok=True)
    j = lambda n: os.path.join(out, n)
    if not solo_sprites:
        guardar_rgb(fondo(), j('sala_fondo.png'))
        print('fondo ok')
    guardar_rgba(sprite_puerta(), j('puerta_hoja.png'))
    guardar_rgba(sprite_vara(), j('pendulo_vara.png'))
    guardar_rgba(sprite_incensario(), j('incensario.png'))
    guardar_rgba(sprite_viga_frente(), j('viga_frente.png'))
    guardar_rgba(sprite_esquina_izq(), j('esquina_izq.png'))
    guardar_rgba(sprite_esquina_der(), j('esquina_der.png'))
    guardar_rgba(textura_humo(), j('humo.png'))
    guardar_rgba(textura_halo(), j('halo.png'))
    guardar_rgba(textura_punto(), j('punto.png'))
    guardar_rgba(textura_burbuja(), j('burbuja.png'))
    guardar_rgba(textura_llama(), j('llama.png'))
    guardar_rgba(textura_ruido_fuego(), j('ruido_fuego.png'))
    guardar_rgba(textura_luz_puerta(), j('luz_puerta.png'))
    print('sprites ok')


if __name__ == '__main__':
    main()

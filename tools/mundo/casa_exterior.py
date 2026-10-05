"""Casa de Dominus, vista desde fuera, de noche, al final del bosque.

"Su arquitectura recordaba a la de una ciudadela en miniatura, con altos
torreones, ventanales abuhardillados y osados arbotantes que surcaban el
entramado de un extremo a otro, amen de otras formas caoticas que parecian
atentar contra los canones de la belleza y el equilibrio."

Sale como el bosque: SILUETA. El cuerpo de la casa es una mascara blanca con
alfa, con un poco de variacion de valor dentro (0,8 - 1,0) para que se lean los
volumenes, la piedra, las tejas y el entramado; el color lo pone Godot con
modulate segun la hora (de noche ~#1a2138). La luz va aparte, en una capa del
mismo tamano y origen que se suma encima (blend_add), para que el nivel pueda
encenderla desde lejos y el shader la haga temblar.

Genera en assets/world/casa_exterior/ (o en la carpeta que se pase):

  casa_silueta.png   mascara blanca de la casa (valor 0,8-1,0, alfa = cobertura)
  casa_ventanas.png  luz calida de ventanas y del vano de la puerta, con halo
  puerta.png         la hoja de la puerta, mascara blanca con tablones y herrajes
  luz_puerta.png     halo del vano + abanico de luz en el suelo (aditivo)
  humo.png           bocanada blanda para las particulas de las chimeneas
  casa_meta.json     puerta, ventanas y chimeneas en coordenadas de ESCENA

Coordenadas de escena: origen = punto del suelo en el centro de la puerta.
En la imagen el suelo esta en y = SUELO y la puerta centrada en x = PUERTA_X,
asi que escena = imagen - (PUERTA_X, SUELO).

    python casa_exterior.py [carpeta_salida] [--preview carpeta_previews]

Usa pincel.py para el ruido y los matorrales, pero no lo toca.
"""
from __future__ import annotations

import argparse
import json
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pincel as pc  # noqa: E402

# --------------------------------------------------------------------------
# Lienzo
# --------------------------------------------------------------------------

W, H = 2600, 1240
SUELO = 1200          # y del suelo en la imagen
PUERTA_X = 800        # centro de la puerta en la imagen
SS = 2                # el lienzo de valor va a SS veces el tamano final
AA = 4                # y cada forma se rasteriza a AA veces mas, en su caja

# Puerta: vano apuntado. El nivel pide ~220 x 390; Magnus mide 330.
PUERTA_ANCHO = 220
PUERTA_ALTO = 390
PUERTA_ARRANQUE = 225  # altura a la que empieza el arco apuntado


def Y(h: float) -> float:
    """Alto sobre el suelo -> y de la imagen."""
    return SUELO - h


def rotar(poly, pivote, grados):
    """Gira un poligono (en px de imagen) alrededor de un pivote. Positivo =
    horario en pantalla (y hacia abajo), o sea que la torre se va a la derecha."""
    a = math.radians(grados)
    ca, sa = math.cos(a), math.sin(a)
    px, py = pivote
    return [(px + (x - px) * ca - (y - py) * sa, py + (x - px) * sa + (y - py) * ca) for x, y in poly]


def elipse(cx, cy, rx, ry, n=48):
    return [(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n)]


def bezier(p0, p1, p2, n=40):
    out = []
    for i in range(n + 1):
        t = i / n
        a, b, c = (1 - t) ** 2, 2 * (1 - t) * t, t * t
        out.append((a * p0[0] + b * p1[0] + c * p2[0], a * p0[1] + b * p1[1] + c * p2[1]))
    return out


def hash2(a, b):
    """Hash 0..1 para numpy (enteros o flotantes)."""
    return np.modf(np.abs(np.sin(a * 12.9898 + b * 78.233) * 43758.5453))[0]


def rasterizar(items, pad=0):
    """items: lista de (poligono, relleno) con relleno 1 (suma) o 0 (hueco).
    Devuelve (x0, y0, cobertura) en px del lienzo SS, recortado al lienzo."""
    pts = np.concatenate([np.asarray(p, np.float64) for p, _ in items])
    x0 = int(math.floor(pts[:, 0].min() * SS)) - 2 - pad
    y0 = int(math.floor(pts[:, 1].min() * SS)) - 2 - pad
    x1 = int(math.ceil(pts[:, 0].max() * SS)) + 2 + pad
    y1 = int(math.ceil(pts[:, 1].max() * SS)) + 2 + pad
    x0c, y0c = max(x0, 0), max(y0, 0)
    x1c, y1c = min(x1, W * SS), min(y1, H * SS)
    if x1c <= x0c or y1c <= y0c:
        return x0c, y0c, np.zeros((0, 0), np.float32)
    img = Image.new('L', ((x1c - x0c) * AA, (y1c - y0c) * AA), 0)
    d = ImageDraw.Draw(img)
    for p, relleno in items:
        d.polygon([((x * SS - x0c) * AA, (y * SS - y0c) * AA) for x, y in p], fill=255 if relleno else 0)
    cov = np.asarray(img.resize((x1c - x0c, y1c - y0c), Image.BOX), np.float32) / 255.0
    return x0c, y0c, cov


def desplazar(a, dx, dy):
    """Mueve un array dx, dy celdas rellenando con 0."""
    out = np.zeros_like(a)
    h, w = a.shape
    xs0, xs1 = max(0, -dx), min(w, w - dx)
    ys0, ys1 = max(0, -dy), min(h, h - dy)
    if xs1 > xs0 and ys1 > ys0:
        out[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx] = a[ys0:ys1, xs0:xs1]
    return out


class Silueta:
    """Mascara con valor. Se guarda premultiplicado (P = valor * alfa) para que
    los bordes con antialias no se oscurezcan al reducir."""

    def __init__(self):
        self.A = np.zeros((H * SS, W * SS), np.float32)
        self.P = np.zeros((H * SS, W * SS), np.float32)
        # Ruido comun: la misma mancha atraviesa volumenes vecinos, como una
        # aguada que no sabe donde acaba un muro.
        self.ruido_g = pc.ruido_valor(W * SS // 2, H * SS // 2, 160, 4, 11, False)
        self.ruido_g = np.asarray(Image.fromarray((self.ruido_g * 255).astype(np.uint8))
                                  .resize((W * SS, H * SS), Image.BICUBIC), np.float32) / 255.0
        self.ruido_f = pc.ruido_valor(W * SS // 2, H * SS // 2, 18, 3, 12, False)
        self.ruido_f = np.asarray(Image.fromarray((self.ruido_f * 255).astype(np.uint8))
                                  .resize((W * SS, H * SS), Image.BICUBIC), np.float32) / 255.0

    def rejilla(self, x0, y0, h, w):
        xs = (np.arange(x0, x0 + w, dtype=np.float32) + 0.5) / SS
        ys = (np.arange(y0, y0 + h, dtype=np.float32) + 0.5) / SS
        return np.meshgrid(xs, ys)

    def forma(self, items, material, prof, borde=0.07, sombra=0.07):
        """Pinta una forma opaca encima de lo que haya.

        prof: 0 = al fondo (valor alto, mas "niebla"), 1 = delante (mas oscuro).
        borde: aclara el filo de arriba a la izquierda (la luna esta alli).
        sombra: oscurece lo que queda debajo alrededor de la forma, para que
        un volumen delante de otro se despegue sin necesidad de linea."""
        if isinstance(items[0], tuple) and isinstance(items[0][0], (tuple, list)) and len(items[0]) == 2 \
                and isinstance(items[0][1], (int, bool)):
            pass
        else:
            items = [(items, 1)]
        pad = int(14 * SS) if sombra else 4
        x0, y0, cov = rasterizar(items, pad)
        if cov.size == 0:
            return
        h, w = cov.shape
        X, Yg = self.rejilla(x0, y0, h, w)
        base = 0.975 - 0.13 * prof
        val = material(X, Yg, base) if material else np.full_like(cov, base)
        val = val + (self.ruido_g[y0:y0 + h, x0:x0 + w] - 0.5) * 0.05 \
            + (self.ruido_f[y0:y0 + h, x0:x0 + w] - 0.5) * 0.025
        if borde:
            d = int(3 * SS)
            fuera = 1.0 - desplazar(cov, d, d)   # lo que hay arriba-izquierda
            rim = ndimage.gaussian_filter(cov * fuera, 1.0 * SS)
            val = val + borde * np.clip(rim * 1.6, 0, 1)
        sl = (slice(y0, y0 + h), slice(x0, x0 + w))
        if sombra:
            sm = ndimage.gaussian_filter(desplazar(cov, int(3 * SS), int(4 * SS)), 7 * SS)
            self.P[sl] *= 1.0 - sombra * sm * (1.0 - cov)
        self.P[sl] = self.P[sl] * (1 - cov) + val * cov
        self.A[sl] = self.A[sl] * (1 - cov) + cov

    def detalle(self, items, delta, blando=0.0):
        """Suma (o resta) valor dentro de lo ya pintado, sin tocar el alfa:
        vigas, marcos, ventanas a oscuras, juntas."""
        if isinstance(items[0], tuple) and len(items[0]) == 2 and isinstance(items[0][1], (int, bool)) \
                and isinstance(items[0][0], (tuple, list)):
            pass
        else:
            items = [(items, 1)]
        pad = int(blando * SS * 3) + 2
        x0, y0, cov = rasterizar(items, pad)
        if cov.size == 0:
            return
        if blando:
            cov = ndimage.gaussian_filter(cov, blando * SS)
        h, w = cov.shape
        sl = (slice(y0, y0 + h), slice(x0, x0 + w))
        self.P[sl] += delta * cov * self.A[sl]

    def final(self):
        """Reduce a tamano final. Devuelve (alfa, valor)."""
        a = self.A.reshape(H, SS, W, SS).mean(axis=(1, 3))
        p = self.P.reshape(H, SS, W, SS).mean(axis=(1, 3))
        v = np.where(a > 1e-4, p / np.maximum(a, 1e-4), 1.0)
        return a, v


# --------------------------------------------------------------------------
# Materiales: valor segun la posicion. X, Yg en px de imagen.
# --------------------------------------------------------------------------

def mat_piedra(curso=26.0, sillar=58.0, fuerza=1.0):
    def f(X, Yg, base):
        hy = (SUELO - Yg) / curso
        fila = np.floor(hy)
        fy = hy - fila
        jh = np.clip(1.0 - np.minimum(fy, 1 - fy) * curso / 1.4, 0, 1)
        off = hash2(fila, 3.0) * sillar
        largo = sillar * (0.8 + 0.4 * hash2(fila, 7.0))
        hx = (X + off) / largo
        idx = np.floor(hx)
        fx = hx - idx
        jv = np.clip(1.0 - np.minimum(fx, 1 - fx) * largo / 1.3, 0, 1)
        tono = (hash2(fila * 1.7, idx) - 0.5) * 0.035
        return base + fuerza * (tono - 0.04 * np.maximum(jh, jv))
    return f


def mat_tejas(fila_alto=15.0, teja=21.0, pandeo=None):
    """Tejas planas en hiladas. pandeo(X) -> desplazamiento en y de la hilada
    (para que el caballete se combe)."""
    def f(X, Yg, base):
        yy = Yg + (pandeo(X) if pandeo else 0.0)
        hy = yy / fila_alto
        fila = np.floor(hy)
        fy = hy - fila
        off = (fila % 2) * teja * 0.5
        hx = (X + off) / teja
        fx = hx - np.floor(hx)
        # borde inferior de cada teja, redondeado: la junta baja en el centro
        curva = 0.18 * (1 - (2 * fx - 1) ** 2)
        jh = np.clip(1.0 - np.abs(fy - (0.92 - curva)) * fila_alto / 1.3, 0, 1)
        jv = np.clip(1.0 - np.minimum(fx, 1 - fx) * teja / 1.0, 0, 1) * (fy > 0.15)
        tono = (hash2(fila, np.floor(hx)) - 0.5) * 0.03
        return base + tono - 0.045 * np.maximum(jh, jv * 0.6)
    return f


def mat_cono(cx, h_base, h_punta, ancho, fila_alto=13.0):
    """Tejas de un cono visto un poco desde abajo: las hiladas se arquean hacia
    arriba en el centro. Mas claro a la izquierda (luna) y oscuro al filo
    derecho: con eso el cono ya tiene bulto."""
    y_p, y_b = Y(h_punta), Y(h_base)

    def f(X, Yg, base):
        t = np.clip((Yg - y_p) / max(y_b - y_p, 1), 0, 1)
        hw = np.maximum(ancho / 2 * t, 1)
        u = np.clip((X - cx) / hw, -1.2, 1.2)
        r = (Yg - y_p) - 9.0 * t * u * u
        hy = r / fila_alto
        fy = hy - np.floor(hy)
        jh = np.clip(1.0 - np.minimum(fy, 1 - fy) * fila_alto / 1.2, 0, 1)
        vol = 0.055 * np.clip(1 - ((u + 0.4) / 0.75) ** 2, 0, 1) - 0.045 * np.clip((u - 0.45) / 0.55, 0, 1)
        return base + vol - 0.04 * jh
    return f


def mat_cilindro(cx, ancho, interior=None):
    """Torre redonda: el mismo bulto que el cono, sobre otro material."""
    def f(X, Yg, base):
        v = interior(X, Yg, base) if interior else np.full_like(X, base)
        u = np.clip((X - cx) / (ancho / 2), -1.2, 1.2)
        return v + 0.05 * np.clip(1 - ((u + 0.4) / 0.75) ** 2, 0, 1) - 0.045 * np.clip((u - 0.45) / 0.55, 0, 1)
    return f


def mat_revoque(fuerza=0.03):
    """Relleno de entramado: yeso liso con manchas."""
    def f(X, Yg, base):
        return base + 0.02 + (hash2(np.floor(X / 3), np.floor(Yg / 3)) - 0.5) * fuerza * 0.4
    return f


def mat_madera(tabla=44.0):
    def f(X, Yg, base):
        hx = X / tabla
        fx = hx - np.floor(hx)
        j = np.clip(1.0 - np.minimum(fx, 1 - fx) * tabla / 1.6, 0, 1)
        veta = np.sin(Yg * 0.21 + np.floor(hx) * 5.0 + np.sin(Yg * 0.037) * 3) * 0.012
        tono = (hash2(np.floor(hx), 5.0) - 0.5) * 0.04
        return base + tono + veta - 0.07 * j
    return f


# --------------------------------------------------------------------------
# Piezas de arquitectura
# --------------------------------------------------------------------------

def rect(x0, x1, h0, h1, talud=0.0):
    """Muro: talud = cuanto se ensancha la base por cada lado."""
    return [(x0 - talud, Y(h0)), (x1 + talud, Y(h0)), (x1, Y(h1)), (x0, Y(h1))]


def cono(cx, h_base, ancho, h_punta, vuelo=12.0, concavo=0.35, n=48):
    """Tejado de sombrero de bruja: faldones concavos y alero que se abre."""
    izq = [(cx - ancho / 2 - vuelo, Y(h_base - 6))]
    for i in range(n + 1):
        t = i / n
        hw = (ancho / 2) * (1 - t) ** (1 + concavo) + vuelo * max(0.0, 1 - t / 0.1) ** 2
        izq.append((cx - hw, Y(h_base + (h_punta - h_base) * t)))
    der = [(2 * cx - x, y) for x, y in reversed(izq)]
    return izq + der


def remate(cx, h, alto=42.0, bola=5.5):
    """Pincho de hierro con bola en la punta de los tejados."""
    return [
        [(cx - 2.6, Y(h - 4)), (cx + 2.6, Y(h - 4)), (cx + 1.0, Y(h + alto)), (cx - 1.0, Y(h + alto))],
        elipse(cx, Y(h + alto * 0.45), bola, bola * 1.15, 20),
    ]


def doblar(poly, h0, h1, dx):
    """Tuerce hacia un lado lo que queda por encima de h0: dx en h1, curva
    cuadratica. Para las puntas de tejado que se vencen."""
    out = []
    for x, y in poly:
        h = SUELO - y
        t = max(0.0, (h - h0) / (h1 - h0))
        out.append((x + dx * t * t, y + abs(dx) * 0.12 * t * t))
    return out


def piramide(cx, h_base, ancho, h_punta):
    return [(cx - ancho / 2, Y(h_base)), (cx + ancho / 2, Y(h_base)), (cx, Y(h_punta))]


def banda(ext, intr):
    """Poligono entre dos polilineas que van en el mismo sentido."""
    return list(ext) + list(reversed(intr))


def arbotante(muro, pilar, grosor_muro, grosor_pilar, curva=0.55, n=48):
    """Arbotante clasico: lomo recto del pilar al muro e intrados curvo que sale
    casi vertical del pilar y llega casi horizontal al muro. muro y pilar son
    los puntos del LOMO (px de imagen)."""
    ext = [(pilar[0] + (muro[0] - pilar[0]) * i / n, pilar[1] + (muro[1] - pilar[1]) * i / n) for i in range(n + 1)]
    b0 = (pilar[0], pilar[1] + grosor_pilar)
    b2 = (muro[0], muro[1] + grosor_muro)
    esquina = (b0[0], b2[1])
    medio = ((b0[0] + b2[0]) / 2, (b0[1] + b2[1]) / 2)
    ctrl = (medio[0] + (esquina[0] - medio[0]) * curva, medio[1] + (esquina[1] - medio[1]) * curva)
    intr = bezier(b0, ctrl, b2, n)
    # nunca mas fino que 9 px
    intr = [(x, max(y, ey + 9)) for (x, y), (_, ey) in zip(intr, ext)]
    return banda(ext, intr)


def arco_puente(p0, p2, flecha, g0, gm, g2, n=64):
    """Arco osado entre dos puntos: linea media curva (sube 'flecha' px) y
    grosor que adelgaza hacia el centro."""
    mx, my = (p0[0] + p2[0]) / 2, (p0[1] + p2[1]) / 2 - flecha * 2
    med = bezier(p0, (mx, my), p2, n)
    ext, intr = [], []
    for i, (x, y) in enumerate(med):
        s = i / n
        a = med[min(i + 1, n)]
        b = med[max(i - 1, 0)]
        tx, ty = a[0] - b[0], a[1] - b[1]
        ln = math.hypot(tx, ty) or 1
        nx, ny = ty / ln, -tx / ln          # normal hacia arriba
        g = gm + (g0 - gm) * (1 - s) ** 3 + (g2 - gm) * s ** 3
        ext.append((x + nx * g * 0.45, y + ny * g * 0.45))
        intr.append((x - nx * g * 0.55, y - ny * g * 0.55))
    return banda(ext, intr), med


def arco_apuntado(cx, h_base, ancho, h_arranque, h_punta, n=24):
    """Vano apuntado (ojival): rectangulo hasta h_arranque y dos arcos que se
    cortan en h_punta."""
    x0, x1 = cx - ancho / 2, cx + ancho / 2
    alto_arco = h_punta - h_arranque
    # radio de dos circulos centrados en la linea de arranque que se cortan en la punta
    # (x - c)^2 + alto^2 = r^2 con c = x1 - r (circulo izquierdo pasa por x0? no: el
    # izquierdo tiene el centro a la derecha)
    half = ancho / 2
    r = (half ** 2 + alto_arco ** 2) / (2 * half)
    pts = [(x0, Y(h_base)), (x1, Y(h_base)), (x1, Y(h_arranque))]
    cxr = x1 - r      # centro del arco derecho
    for i in range(1, n + 1):
        ang0 = 0.0
        ang1 = math.atan2(alto_arco, cx - cxr)
        a = ang0 + (ang1 - ang0) * i / n
        pts.append((cxr + r * math.cos(a), Y(h_arranque + r * math.sin(a))))
    cxl = x0 + r
    for i in range(n, -1, -1):
        ang1 = math.atan2(alto_arco, cxl - cx)
        a = ang1 * i / n
        pts.append((cxl - r * math.cos(a), Y(h_arranque + r * math.sin(a))))
    return pts


def arco_medio_punto(cx, h_base, ancho, h_arranque, n=24):
    x0, x1 = cx - ancho / 2, cx + ancho / 2
    r = ancho / 2
    pts = [(x0, Y(h_base)), (x1, Y(h_base))]
    for i in range(n + 1):
        a = math.pi * i / n
        pts.append((cx + r * math.cos(a), Y(h_arranque + r * math.sin(a))))
    return pts


# --------------------------------------------------------------------------
# Ventanas
# --------------------------------------------------------------------------

class Ventana:
    """Un hueco. forma: 'ojiva', 'rect', 'redonda', 'ranura', 'medio'.
    parteluz: 'cruz', 'vertical', 'ninguno'. luz: 0 = a oscuras, 1 = vela
    entera; la tenue (~0,55) queda mas naranja. giro: (pivote, grados) si esta
    en un volumen torcido."""

    def __init__(self, cx, h0, ancho, alto, forma='rect', parteluz='ninguno', luz=0.0, giro=None, nombre='',
                 cortina=None):
        self.cortina = cortina
        self.cx, self.h0, self.ancho, self.alto = cx, h0, ancho, alto
        self.forma, self.parteluz, self.luz, self.giro, self.nombre = forma, parteluz, luz, giro, nombre

    def _g(self, poly):
        return rotar(poly, *self.giro) if self.giro else poly

    def contorno(self, crecer=0.0):
        cx, h0, w, a = self.cx, self.h0 - crecer, self.ancho + 2 * crecer, self.alto + 2 * crecer
        if self.forma == 'ojiva':
            p = arco_apuntado(cx, h0, w, h0 + a - w * 0.75, h0 + a)
        elif self.forma == 'medio':
            p = arco_medio_punto(cx, h0, w, h0 + a - w / 2)
        elif self.forma == 'redonda':
            p = elipse(cx, Y(h0 + a / 2), w / 2, a / 2, 40)
        elif self.forma == 'farol':
            # cristal de farol: mas ancho arriba que abajo
            p = [(cx - w * 0.36, Y(h0)), (cx + w * 0.36, Y(h0)), (cx + w / 2, Y(h0 + a)), (cx - w / 2, Y(h0 + a))]
        elif self.forma == 'ranura':
            p = arco_apuntado(cx, h0, w, h0 + a - w * 0.9, h0 + a)
        else:
            p = rect(cx - w / 2, cx + w / 2, h0, h0 + a)
        return self._g(p)

    def barrotes(self):
        """Parteluces como poligonos (se restan del cristal)."""
        cx, h0, w, a = self.cx, self.h0, self.ancho, self.alto
        g = max(4.0, w * 0.075)
        out = []
        if self.parteluz in ('cruz', 'vertical'):
            out.append(rect(cx - g / 2, cx + g / 2, h0 - 2, h0 + a + 2))
        if self.parteluz == 'cruz':
            hm = h0 + a * (0.62 if self.forma == 'rect' else 0.5)
            out.append(rect(cx - w / 2 - 2, cx + w / 2 + 2, hm - g / 2, hm + g / 2))
        return [self._g(p) for p in out]

    def rect_escena(self):
        pts = np.asarray(self.contorno())
        x0, y0 = pts.min(axis=0)
        x1, y1 = pts.max(axis=0)
        return [round(float(x0 - PUERTA_X), 1), round(float(y0 - SUELO), 1),
                round(float(x1 - x0), 1), round(float(y1 - y0), 1)]


# --------------------------------------------------------------------------
# La casa
# --------------------------------------------------------------------------

def construir(rnd: random.Random):
    """Devuelve (silueta, ventanas, chimeneas, extras) con la casa entera."""
    s = Silueta()
    V: list[Ventana] = []
    chimeneas: list[tuple[float, float]] = []

    piedra = mat_piedra()
    piedra_fina = mat_piedra(curso=20, sillar=40)

    # ---- 0. Fondo: volumen alto detras de la torre fina (hastial de cara) ----
    # Es lo mas lejano: sale mas claro y sin sombra propia, y da capas a la
    # silueta por detras de las almenas.
    s.forma(rect(1560, 1765, 0, 760), piedra_fina, prof=0.05, sombra=0)
    s.forma([(1540, Y(752)), (1785, Y(752)), (1662, Y(905))], mat_tejas(13, 18), prof=0.05, sombra=0)
    s.forma(remate(1662, 900, 30, 4.5)[0], None, prof=0.05, sombra=0, borde=0)
    s.forma(remate(1662, 900, 30, 4.5)[1], None, prof=0.05, sombra=0, borde=0)
    V.append(Ventana(1662, 790, 44, 44, 'redonda', 'cruz', 0.0, nombre='oculo_fondo'))

    # ---- 1. Torre fina: un palo encima del bloque ancho, con linterna ----
    # "una muy delgada encima de un volumen mas ancho": 62 px de fuste para
    # sostener una linterna y la aguja mas alta de la casa. No deberia aguantar.
    tf_cx = 1432
    s.forma(rect(tf_cx - 31, tf_cx + 31, 600, 935), mat_cilindro(tf_cx, 62, piedra_fina), prof=0.2, sombra=0.05)
    # mensula que abre la linterna
    s.forma([(tf_cx - 31, Y(900)), (tf_cx + 31, Y(900)), (tf_cx + 54, Y(936)), (tf_cx - 54, Y(936))],
            None, prof=0.2, sombra=0)
    s.forma(rect(tf_cx - 52, tf_cx + 52, 934, 1010), mat_cilindro(tf_cx, 104, piedra_fina), prof=0.2, sombra=0)
    s.forma(rect(tf_cx - 58, tf_cx + 58, 1004, 1016), None, prof=0.2, sombra=0)
    s.forma(cono(tf_cx, 1014, 108, 1118, vuelo=8, concavo=0.55), mat_cono(tf_cx, 1014, 1118, 108), prof=0.2, sombra=0)
    for p in remate(tf_cx, 1116, 34, 4.5):
        s.forma(p, None, prof=0.2, sombra=0, borde=0)
    # pasarela colgada de la torre fina al hastial del fondo: un tablero con
    # barandilla sobre un arco rebajado. No lleva a ninguna puerta.
    s.forma(rect(tf_cx + 30, 1562, 846, 856), None, prof=0.15, sombra=0, borde=0.04)
    s.forma(rect(tf_cx + 30, 1562, 880, 884), None, prof=0.15, sombra=0, borde=0)
    bal = [rect(x - 1.5, x + 1.5, 856, 882) for x in range(tf_cx + 38, 1560, 14)]
    s.forma([(p, 1) for p in bal], None, prof=0.15, sombra=0, borde=0)
    arq, _ = arco_puente((tf_cx + 30, Y(826)), (1562, Y(826)), -12, 22, 8, 22, n=24)
    s.forma(arq, None, prof=0.15, sombra=0, borde=0)
    V.append(Ventana(tf_cx, 948, 38, 50, 'ojiva', 'vertical', 0.9, nombre='linterna'))
    V.append(Ventana(tf_cx, 790, 12, 40, 'ranura', 'ninguno', 0.0, nombre='fuste'))

    # ---- 2. Bloque ancho y achaparrado con almenas y garitas ----
    bx0, bx1 = 1170, 1650
    s.forma(rect(bx0, bx1, 0, 612, talud=-9), piedra, prof=0.45)
    # parapeto volado sobre canecillos (matacanes)
    s.forma(rect(bx0 - 14, bx1 + 14, 612, 646), piedra_fina, prof=0.45, sombra=0.04)
    canes = []
    x = bx0 - 10
    while x < bx1 + 6:
        canes.append([(x, Y(612)), (x + 16, Y(612)), (x + 13, Y(592)), (x + 3, Y(592))])
        x += 30
    s.forma([(p, 1) for p in canes], None, prof=0.45, sombra=0, borde=0)
    almenas = []
    x = bx0 - 14
    ra = random.Random(4)
    i = 0
    while x < bx1 + 8:
        # alguna se ha caido, otras crecen; ninguna mide lo mismo
        if i != 4:
            ancho = ra.uniform(24, 36)
            almenas.append(rect(x, min(x + ancho, bx1 + 14), 644, 644 + ra.uniform(30, 52)))
        x += ra.uniform(48, 60)
        i += 1
    s.forma([(p, 1) for p in almenas], piedra_fina, prof=0.45, sombra=0)
    # garitas voladas en las esquinas (una mas alta que la otra: nada es simetrico)
    for gx, gh, gr in ((bx0 + 6, 560, 0.0), (bx1 - 4, 590, 0.0)):
        s.forma([(gx - 34, Y(gh)), (gx + 34, Y(gh)), (gx, Y(gh - 70))], mat_cilindro(gx, 68), prof=0.5, sombra=0.05)
        s.forma(rect(gx - 34, gx + 34, gh, gh + 130), mat_cilindro(gx, 68, piedra_fina), prof=0.5, sombra=0.05)
        s.forma(cono(gx, gh + 130, 74, gh + 250, vuelo=7), mat_cono(gx, gh + 130, gh + 250, 74), prof=0.5, sombra=0)
        for p in remate(gx, gh + 248, 26, 4):
            s.forma(p, None, prof=0.5, sombra=0, borde=0)
    V.append(Ventana(bx0 + 6, 620, 12, 46, 'ranura', luz=0.0, nombre='garita_izq'))
    V.append(Ventana(bx1 - 4, 650, 12, 46, 'ranura', luz=0.0, nombre='garita_der'))
    # el ventanal grande del bloque
    V.append(Ventana(1330, 250, 92, 230, 'ojiva', 'cruz', 1.0, nombre='ventanal', cortina='izq'))
    V.append(Ventana(1540, 110, 50, 84, 'medio', 'vertical', 0.0, nombre='bloque_bajo'))
    V.append(Ventana(1480, 470, 14, 50, 'ranura', luz=0.0, nombre='bloque_saetera'))

    # ---- 3. Torre inclinada, apuntalada por un arbotante ----
    ti_cx, ti_ancho, ti_gr = 1790, 176, 6.5
    piv = (ti_cx, Y(0))

    def ti(poly):
        return rotar(poly, piv, ti_gr)

    s.forma(ti(rect(ti_cx - ti_ancho / 2, ti_cx + ti_ancho / 2, -30, 820, talud=10)),
            mat_cilindro(ti_cx + 40, ti_ancho, piedra), prof=0.55)
    # balconcillo volado
    s.forma(ti(rect(ti_cx - ti_ancho / 2 - 22, ti_cx - ti_ancho / 2 + 20, 560, 574)), None, prof=0.55, sombra=0)
    s.forma(ti([(ti_cx - ti_ancho / 2 - 22, Y(560)), (ti_cx - ti_ancho / 2, Y(560)),
                (ti_cx - ti_ancho / 2, Y(520))]), None, prof=0.55, sombra=0)
    s.forma(ti(rect(ti_cx - ti_ancho / 2 - 20, ti_cx - ti_ancho / 2 - 15, 574, 612)), None, prof=0.55, sombra=0,
            borde=0)
    s.forma(ti(rect(ti_cx - ti_ancho / 2 - 20, ti_cx - ti_ancho / 2 + 18, 608, 613)), None, prof=0.55, sombra=0,
            borde=0)
    # corona volada y cono
    s.forma(ti(rect(ti_cx - ti_ancho / 2 - 10, ti_cx + ti_ancho / 2 + 10, 790, 826)), piedra_fina, prof=0.55,
            sombra=0.04)
    s.forma(ti(cono(ti_cx, 826, ti_ancho + 22, 1060, vuelo=12, concavo=0.4)),
            mat_cono(ti_cx + 120, 826, 1060, ti_ancho + 80), prof=0.55, sombra=0)
    # veleta torcida
    vx, vh = ti_cx, 1058
    s.forma(ti([(vx - 2, Y(vh)), (vx + 2, Y(vh)), (vx + 1.2, Y(vh + 70)), (vx - 1.2, Y(vh + 70))]), None, prof=0.55,
            sombra=0, borde=0)
    s.forma(rotar(ti([(vx - 30, Y(vh + 50)), (vx + 18, Y(vh + 50)), (vx + 18, Y(vh + 56)), (vx - 30, Y(vh + 56))]),
                  ti([(vx, Y(vh + 53))])[0], -12), None, prof=0.55, sombra=0, borde=0)
    s.forma(rotar(ti([(vx + 18, Y(vh + 46)), (vx + 34, Y(vh + 53)), (vx + 18, Y(vh + 60))]),
                  ti([(vx, Y(vh + 53))])[0], -12), None, prof=0.55, sombra=0, borde=0)
    s.forma(rotar(ti([(vx - 30, Y(vh + 53)), (vx - 40, Y(vh + 64)), (vx - 22, Y(vh + 64)), (vx - 22, Y(vh + 44)),
                      (vx - 40, Y(vh + 44))]), ti([(vx, Y(vh + 53))])[0], -12), None, prof=0.55, sombra=0, borde=0)
    V.append(Ventana(ti_cx - 10, 360, 20, 84, 'ranura', luz=0.5, giro=(piv, ti_gr), nombre='torcida_saetera'))
    V.append(Ventana(ti_cx + 6, 640, 52, 96, 'ojiva', 'vertical', 0.95, giro=(piv, ti_gr), nombre='torcida_alta'))
    V.append(Ventana(ti_cx + 20, 170, 36, 60, 'medio', luz=0.0, giro=(piv, ti_gr), nombre='torcida_baja'))

    # ---- 4. Pilar de arbotantes entre la torre inclinada y el bloque derecho ----
    px_c, pw = 2110, 52
    s.forma(rect(px_c - pw / 2, px_c + pw / 2, 0, 470, talud=12), piedra_fina, prof=0.6)
    s.forma([(px_c - pw / 2 - 6, Y(470)), (px_c + pw / 2 + 6, Y(470)), (px_c + pw / 2, Y(500)), (px_c - pw / 2, Y(500))],
            None, prof=0.6, sombra=0)
    s.forma(rect(px_c - 18, px_c + 18, 500, 560), None, prof=0.6, sombra=0)
    s.forma(piramide(px_c, 558, 46, 680), mat_cono(px_c, 558, 680, 46), prof=0.6, sombra=0)
    for p in remate(px_c, 678, 22, 3.5):
        s.forma(p, None, prof=0.6, sombra=0, borde=0)
    # arbotante hacia la torre: el lomo toca la torre ya girada
    muro_t = ti([(ti_cx + ti_ancho / 2, Y(700))])[0]
    s.forma(arbotante(muro_t, (px_c - 8, Y(492)), 46, 150, curva=0.6), None, prof=0.62, sombra=0.06)

    # ---- 5. Bloque derecho: volumenes apilados que no casan ----
    # Un pie de piedra estrecho que carga con un piso el doble de ancho, sobre
    # cuatro tornapuntas flacas. Es el volumen que peor aguanta de la casa.
    s.forma(rect(2300, 2462, 0, 330, talud=6), piedra, prof=0.8)
    puntales = []
    for (xm, hm, xv) in ((2300, 170, 2226), (2300, 250, 2262), (2462, 160, 2548), (2462, 245, 2506)):
        dx, dy = xv - xm, -(330 - hm)
        ln = math.hypot(dx, dy)
        nx, ny = -dy / ln * 6, dx / ln * 6
        puntales.append([(xm + nx, Y(hm) + ny), (xm - nx, Y(hm) - ny), (xv - nx, Y(330) - ny), (xv + nx, Y(330) + ny)])
    s.forma([(p, 1) for p in puntales], None, prof=0.8, sombra=0.03, borde=0.04)
    s.forma(rect(2216, 2558, 328, 506), mat_revoque(), prof=0.8)
    s.forma(rect(2210, 2564, 324, 338), None, prof=0.8, sombra=0.03)
    # cabana torcida arriba, con su tejado a dos aguas de cara
    cab_piv = (2390, Y(506))
    cab = rect(2300, 2476, 500, 640)
    s.forma(rotar(cab, cab_piv, -5), piedra_fina, prof=0.78)
    s.forma(rotar([(2282, Y(636)), (2494, Y(636)), (2396, Y(760))], cab_piv, -5), mat_tejas(12, 17), prof=0.78,
            sombra=0.04)
    for p in remate(2396, 758, 26, 4):
        s.forma(rotar(p, cab_piv, -5), None, prof=0.78, sombra=0, borde=0)
    # chimenea en la cabana, torcida hacia el otro lado
    chim = rotar(rect(2444, 2476, 640, 812), (2460, Y(640)), 4)
    s.forma(rotar(chim, cab_piv, -5), piedra_fina, prof=0.76, sombra=0.04)
    tapa = rotar(rotar(rect(2438, 2482, 806, 820), (2460, Y(640)), 4), cab_piv, -5)
    s.forma(tapa, None, prof=0.76, sombra=0)
    ch = np.mean(np.asarray(tapa), axis=0)
    chimeneas.append((float(ch[0]), float(np.asarray(tapa)[:, 1].min())))
    # arbotante del pilar al piso volado
    s.forma(arbotante((2216, Y(468)), (px_c + 10, Y(492)), 40, 120, curva=0.5), None, prof=0.63, sombra=0.06)
    V.append(Ventana(2381, 110, 70, 100, 'rect', 'cruz', 0.6, nombre='derecha_baja', cortina='der'))
    V.append(Ventana(2290, 372, 56, 80, 'rect', 'vertical', 0.0, nombre='volado_izq'))
    V.append(Ventana(2490, 372, 56, 80, 'rect', 'cruz', 0.0, nombre='volado_der'))
    V.append(Ventana(2370, 540, 40, 52, 'rect', luz=0.0, giro=(cab_piv, -5), nombre='cabana'))

    # ---- 6. Torre redonda de la izquierda ----
    tl_cx, tl_w = 215, 200
    s.forma(rect(tl_cx - tl_w / 2, tl_cx + tl_w / 2, 0, 600, talud=10), mat_cilindro(tl_cx, tl_w, piedra), prof=0.72)
    s.forma([(tl_cx - tl_w / 2, Y(582)), (tl_cx + tl_w / 2, Y(582)), (tl_cx + tl_w / 2 + 14, Y(610)),
             (tl_cx - tl_w / 2 - 14, Y(610))], None, prof=0.72, sombra=0)
    s.forma(rect(tl_cx - tl_w / 2 - 14, tl_cx + tl_w / 2 + 14, 608, 642),
            mat_cilindro(tl_cx, tl_w + 28, piedra_fina), prof=0.72, sombra=0.03)
    # la punta se dobla como un gorro viejo
    s.forma(doblar(cono(tl_cx, 640, tl_w + 36, 960, vuelo=14, concavo=0.45), 720, 960, -78),
            mat_cono(tl_cx, 640, 960, tl_w + 36), prof=0.72, sombra=0)
    for p in remate(tl_cx, 956, 30, 4.5):
        s.forma(doblar(p, 720, 960, -78), None, prof=0.72, sombra=0, borde=0)
    # cuartito colgado del costado izquierdo, sobre una tornapunta
    cx0 = tl_cx - tl_w / 2
    s.forma(rect(cx0 - 58, cx0 + 6, 436, 520), piedra_fina, prof=0.76, sombra=0.05)
    s.forma([(cx0 - 58, Y(436)), (cx0, Y(436)), (cx0, Y(380))], None, prof=0.76, sombra=0)
    s.forma([(cx0 - 70, Y(516)), (cx0 + 8, Y(516)), (cx0 + 8, Y(580)), (cx0 - 8, Y(580))], mat_tejas(10, 14),
            prof=0.76, sombra=0.03)
    V.append(Ventana(cx0 - 28, 456, 26, 40, 'rect', 'vertical', 0.0, nombre='cuartito'))
    # buhardilla en el cono
    s.forma(rect(tl_cx - 26, tl_cx + 26, 690, 756), None, prof=0.74, sombra=0.05)
    s.forma([(tl_cx - 36, Y(752)), (tl_cx + 36, Y(752)), (tl_cx, Y(802))], mat_tejas(10, 14), prof=0.74, sombra=0)
    V.append(Ventana(tl_cx, 702, 30, 40, 'medio', luz=0.0, nombre='cono_izq'))
    V.append(Ventana(tl_cx - 18, 270, 22, 92, 'ranura', luz=0.7, nombre='torre_izq'))
    V.append(Ventana(tl_cx + 10, 470, 36, 36, 'redonda', luz=0.0, nombre='torre_izq_oculo'))

    # ---- 7. Pilar solitario a la izquierda y su arbotante a la torre ----
    s.forma(rect(44, 88, 0, 300, talud=10), piedra_fina, prof=0.86)
    s.forma(piramide(66, 298, 50, 400), mat_cono(66, 298, 400, 50), prof=0.86, sombra=0)
    for p in remate(66, 398, 20, 3.5):
        s.forma(p, None, prof=0.86, sombra=0, borde=0)
    s.forma(arbotante((tl_cx - tl_w / 2 + 2, Y(380)), (80, Y(290)), 34, 110, curva=0.5), None, prof=0.84,
            sombra=0.05)

    # ---- 8. La nave principal (la de la puerta) ----
    nx0, nx1 = 300, 1175
    # tejado a cuatro aguas, alto, con el caballete combado
    def pandeo(X):
        return -10.0 * np.sin(np.clip((X - 430) / 580, 0, 1) * math.pi)
    techo = [(nx0 - 70, Y(500)), (nx1 + 72, Y(500))]
    techo += [(1022, Y(688))]
    techo += [(x, float(Y(690) + 10.0 * math.sin((x - 430) / 592 * math.pi))) for x in range(1022, 429, -12)]
    techo += [(430, Y(690))]
    s.forma(techo, mat_tejas(15, 21, pandeo=lambda X: 0.0), prof=0.92)
    # cresteria de hierro en el caballete
    crest = []
    for x in range(446, 1010, 36):
        yb = Y(690) + 10.0 * math.sin((x - 430) / 592 * math.pi)
        crest.append([(x - 2, yb + 2), (x + 2, yb + 2), (x + 0.8, yb - 16), (x - 0.8, yb - 16)])
        crest.append(elipse(x, yb - 9, 3.2, 3.2, 12))
    s.forma([(p, 1) for p in crest], None, prof=0.92, sombra=0, borde=0)
    # chimenea de la nave
    s.forma(rect(512, 556, 600, 792, talud=2), piedra_fina, prof=0.9, sombra=0.04)
    s.forma(rect(504, 564, 788, 804), None, prof=0.9, sombra=0)
    s.forma(rect(516, 552, 804, 814), None, prof=0.9, sombra=0, borde=0)
    chimeneas.append((534.0, Y(814)))
    # buhardillas (ventanales abuhardillados): tres, distintas, una torcida
    for (dx, dh, dw, gr, luz, forma) in ((640, 560, 92, 0.0, 0.9, 'ojiva'), (812, 572, 80, -3.0, 0.0, 'medio'),
                                         (962, 556, 90, 2.0, 0.0, 'rect')):
        dp = (dx, Y(dh))
        cuerpo = rect(dx - dw / 2, dx + dw / 2, dh - 40, dh + 118)
        s.forma(rotar(cuerpo, dp, gr), piedra_fina, prof=0.94, sombra=0.06)
        tej = [(dx - dw / 2 - 16, Y(dh + 112)), (dx + dw / 2 + 16, Y(dh + 112)), (dx, Y(dh + 112 + dw * 0.95))]
        s.forma(rotar(tej, dp, gr), mat_tejas(11, 15), prof=0.94, sombra=0)
        for p in remate(dx, dh + 110 + dw * 0.95, 26, 3.8):
            s.forma(rotar(p, dp, gr), None, prof=0.94, sombra=0, borde=0)
        V.append(Ventana(dx, dh + 10, dw * 0.5, 88, forma, 'cruz' if forma == 'rect' else 'vertical', luz,
                         giro=(dp, gr) if gr else None, nombre=f'buhardilla_{dx}'))
    # piso alto de entramado, volado sobre la planta baja
    s.forma(rect(nx0 - 34, nx1 + 36, 300, 500), mat_revoque(), prof=0.95)
    # planta baja de piedra
    s.forma(rect(nx0, nx1, 0, 304, talud=5), piedra, prof=0.97, sombra=0.08)
    # tornapuntas del vuelo (se ven en silueta en los dos extremos)
    for x_muro, x_vuelo in ((nx0, nx0 - 34), (nx1, nx1 + 36)):
        s.forma([(x_muro, Y(236)), (x_muro, Y(300)), (x_vuelo, Y(300)), (x_vuelo + (x_muro - x_vuelo) * 0.35, Y(292))],
                None, prof=0.97, sombra=0)
    # entramado: vigas mas oscuras sobre el revoque
    vigas = [rect(nx0 - 34, nx1 + 36, 300, 316), rect(nx0 - 34, nx1 + 36, 486, 500), rect(nx0 - 34, nx1 + 36, 392, 402)]
    xs_post = list(range(nx0 - 30, nx1 + 40, 70))
    for i, x in enumerate(xs_post):
        vigas.append(rect(x - 6, x + 6, 300, 500))
        if i + 1 < len(xs_post) and i % 3 != 1:
            x2 = xs_post[i + 1]
            # cruz de San Andres en los panos de abajo, tornapunta simple arriba
            if i % 2 == 0:
                vigas.append([(x + 6, Y(316)), (x + 16, Y(316)), (x2 - 6, Y(386)), (x2 - 6, Y(392)), (x2 - 16, Y(392)),
                              (x + 6, Y(322))])
                vigas.append([(x2 - 6, Y(316)), (x2 - 16, Y(316)), (x + 6, Y(386)), (x + 6, Y(392)), (x + 16, Y(392)),
                              (x2 - 6, Y(322))])
            else:
                vigas.append([(x + 6, Y(402)), (x + 14, Y(402)), (x2 - 6, Y(480)), (x2 - 6, Y(486)), (x2 - 12, Y(486)),
                              (x + 6, Y(408))])
    s.detalle([(p, 1) for p in vigas], -0.075)
    V.append(Ventana(430, 412, 64, 64, 'rect', 'cruz', 0.8, nombre='entramado_1', cortina='der'))
    V.append(Ventana(570, 412, 64, 64, 'rect', 'cruz', 0.0, nombre='entramado_2'))
    V.append(Ventana(1010, 412, 64, 64, 'rect', 'cruz', 0.0, nombre='entramado_3'))
    V.append(Ventana(1115, 330, 40, 50, 'rect', luz=0.0, nombre='entramado_4'))
    V.append(Ventana(470, 110, 62, 130, 'ojiva', 'vertical', 1.0, nombre='baja_izq'))
    V.append(Ventana(1060, 110, 62, 130, 'ojiva', 'vertical', 0.0, nombre='baja_der'))

    # ---- 9. Arbotante largo sobre el tejado: de la torre izquierda al bloque ----
    # El que "surca el entramado de un extremo a otro". Va por delante de la
    # nave en profundidad para que su vientre se lea contra el cielo.
    arco, med = arco_puente((tl_cx + tl_w / 2 - 4, Y(560)), (bx0 - 22, Y(640)), 200, 84, 34, 86)
    # lobulos en el vientre: arquillos que muerden el intrados, como en una
    # traceria. Asi se lee piedra labrada y no una tuberia.
    lob = []
    n = len(med) - 1
    for i in range(int(n * 0.28), int(n * 0.8), 3):
        x, y = med[i]
        a, b = med[i + 1], med[i - 1]
        tx, ty = a[0] - b[0], a[1] - b[1]
        ln = math.hypot(tx, ty) or 1
        nx, ny = ty / ln, -tx / ln
        s_ = i / n
        g = 34 + (84 - 34) * (1 - s_) ** 3 + (86 - 34) * s_ ** 3
        lob.append((elipse(x - nx * g * 0.62, y - ny * g * 0.62, 17, 17, 24), 0))
    s.forma([(arco, 1)] + lob, piedra_fina, prof=0.66, sombra=0.05)
    # crestas (pinaculitos) sobre el lomo
    _, med = arco_puente((tl_cx + tl_w / 2 - 4, Y(560)), (bx0 - 22, Y(640)), 200, 60, 22, 64, n=18)
    pin = []
    for (x, y) in med[3:-3]:
        pin.append([(x - 5, y - 12), (x + 5, y - 12), (x + 1.5, y - 30), (x, y - 36), (x - 1.5, y - 30)])
    s.forma([(p, 1) for p in pin], None, prof=0.66, sombra=0, borde=0)

    # ---- 10. La puerta ----
    # jambas y archivolta en piedra clara, vano oscuro
    s.forma(arco_apuntado(PUERTA_X, 0, PUERTA_ANCHO + 70, PUERTA_ARRANQUE, PUERTA_ALTO + 46), piedra_fina,
            prof=0.93, sombra=0.06, borde=0.09)
    s.detalle(arco_apuntado(PUERTA_X, 0, PUERTA_ANCHO + 70, PUERTA_ARRANQUE, PUERTA_ALTO + 46), 0.04)
    s.detalle(arco_apuntado(PUERTA_X, 0, PUERTA_ANCHO + 28, PUERTA_ARRANQUE, PUERTA_ALTO + 18), -0.05)
    s.detalle(arco_apuntado(PUERTA_X, 0, PUERTA_ANCHO, PUERTA_ARRANQUE, PUERTA_ALTO), -0.2)
    # escalon
    s.forma(rect(PUERTA_X - 150, PUERTA_X + 150, -6, 16), piedra_fina, prof=1.0, sombra=0.03)

    # ---- 11. Farol junto a la puerta ----
    # Colgado de un brazo de hierro a la izquierda: Magnus pasa por debajo al
    # llegar. Es la luz mas cercana a camara, asi que va algo mas grande.
    fx, fh = PUERTA_X - 196, 470
    s.forma(rect(fx - 6, fx + 82, fh + 6, fh + 13), None, prof=0.98, sombra=0, borde=0.03)
    s.forma([(fx + 70, Y(fh + 6)), (fx + 77, Y(fh + 6)), (fx + 7, Y(fh - 52)), (fx, Y(fh - 52))], None,
            prof=0.98, sombra=0, borde=0)
    s.forma(elipse(fx + 40, Y(fh + 22), 10, 10, 20), None, prof=0.98, sombra=0, borde=0)
    s.forma(elipse(fx + 40, Y(fh + 22), 6, 6, 20), None, prof=0.98, sombra=0, borde=0)
    lx = fx + 72
    s.forma(rect(lx - 1.8, lx + 1.8, fh - 36, fh + 8), None, prof=0.98, sombra=0, borde=0)
    s.forma(elipse(lx, Y(fh - 36), 5, 5, 12), None, prof=0.98, sombra=0, borde=0)
    s.forma([(lx - 24, Y(fh - 58)), (lx + 24, Y(fh - 58)), (lx + 5, Y(fh - 38)), (lx - 5, Y(fh - 38))], None,
            prof=0.98, sombra=0, borde=0)
    s.forma([(lx - 20, Y(fh - 58)), (lx + 20, Y(fh - 58)), (lx + 16, Y(fh - 118)), (lx - 16, Y(fh - 118))], None,
            prof=0.98, sombra=0, borde=0)
    s.forma([(lx - 22, Y(fh - 118)), (lx + 22, Y(fh - 118)), (lx + 10, Y(fh - 128)), (lx - 10, Y(fh - 128))], None,
            prof=0.98, sombra=0, borde=0)
    s.forma(rect(lx - 2, lx + 2, fh - 140, fh - 126), None, prof=0.98, sombra=0, borde=0)
    V.append(Ventana(lx, fh - 114, 30, 54, 'farol', 'vertical', 0.9, nombre='farol'))

    # nada de la casa baja del suelo (la torre inclinada gira sobre su pie)
    corte = int((SUELO + 3) * SS)
    s.A[corte:] = 0
    s.P[corte:] = 0

    # ---- 12. Matorral y hierba al pie: la casa esta metida en la espesura ----
    mat = pc.Lienzo(W, H)
    rr = random.Random(7)
    # Lejos de los bordes de la textura: una rama cortada en seco por el borde
    # de la imagen se ve enseguida.
    zonas = [(70, 150, 130), (300, 420, 90), (1150, 1250, 120), (1650, 1740, 110), (1960, 2200, 150),
             (2480, 2530, 120), (940, 1060, 60), (500, 640, 70)]
    for (a, b, alto) in zonas:
        for _ in range(int((b - a) / 26)):
            x = rr.uniform(a, b)
            estilo = pc.EstiloArbol(niveles=4, ramas=(2, 3), angulo=0.75, decaimiento=0.7, curvatura=0.22,
                                    tronco_frac=0.1, subir=0.2)
            ramas = pc.generar_arbol(x, SUELO + 6, alto * rr.uniform(0.35, 1.0), rr.uniform(3.0, 6.0), estilo, rr)
            pc.pintar_ramas(mat.draw, ramas, 255)
    for x in range(34, W - 34, 9):
        if PUERTA_X - 170 < x < PUERTA_X + 170:
            continue
        if rr.random() < 0.75:
            pc.pintar_hierba(mat.draw, x + rr.uniform(-4, 4), SUELO + 4, rr.uniform(14, 40), rr, 255)
    m = np.asarray(mat.img, np.float32) / 255.0      # ya esta a SS=2 del final
    assert pc.SS == SS
    val = 0.9 + (s.ruido_g - 0.5) * 0.06
    s.P = s.P * (1 - m) + val * m
    s.A = s.A * (1 - m) + m
    # algunas ramitas del matorral crecen hacia abajo: se funden con el suelo
    # en 4 px en vez de asomar por debajo de la linea de suelo
    fy = (np.arange(H * SS, dtype=np.float32)[:, None] / SS - SUELO)
    funde = np.clip((7.0 - fy) / 4.0, 0, 1)
    s.P *= funde
    s.A *= funde

    return s, V, chimeneas


# --------------------------------------------------------------------------
# Capas de luz
# --------------------------------------------------------------------------

LUZ_CALIDA = np.array(pc.hex_a_rgb('#ffb35a'), np.float32)
LUZ_CLARA = np.array(pc.hex_a_rgb('#ffd89a'), np.float32)
LUZ_HALO = np.array(pc.hex_a_rgb('#ff9f4f'), np.float32)


def mascara_final(items):
    """Cobertura a tamano final de un conjunto de poligonos (lista de (poly, relleno))."""
    x0, y0, cov = rasterizar(items)
    full = np.zeros((H, W), np.float32)
    if cov.size == 0:
        return full
    ax, ay = x0 % SS, y0 % SS
    cov = np.pad(cov, ((ay, (-(cov.shape[0] + ay)) % SS), (ax, (-(cov.shape[1] + ax)) % SS)))
    h, w = cov.shape[0] // SS, cov.shape[1] // SS
    small = cov.reshape(h, SS, w, SS).mean(axis=(1, 3))
    fx, fy = (x0 - ax) // SS, (y0 - ay) // SS
    small = small[:H - fy, :W - fx]
    full[fy:fy + small.shape[0], fx:fx + small.shape[1]] = small
    return full


def capa_ventanas(V, s: Silueta):
    """Cristales encendidos con su vela dentro y un halo blando alrededor.
    Devuelve (rgb, alfa): se suma con blend_add, asi que la contribucion es
    rgb * alfa."""
    luz = np.zeros((H, W), np.float32)       # intensidad
    calor = np.zeros((H, W), np.float32)     # 0 = naranja del borde, 1 = el claro de la llama
    halo = np.zeros((H, W), np.float32)
    rs = random.Random(3)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    for v in V:
        cont = v.contorno()
        items = [(cont, 1)] + [(b, 0) for b in v.barrotes()]
        # en la silueta: cristal oscuro y alfeizar un pelin claro
        s.detalle(cont, -0.16)
        pts = np.asarray(cont)
        x0, y0 = pts.min(axis=0)
        x1, y1 = pts.max(axis=0)
        s.detalle(rect(x0 - 4, x1 + 4, SUELO - y1 - 7, SUELO - y1 + 1) if not v.giro else
                  rotar(rect(v.cx - v.ancho / 2 - 4, v.cx + v.ancho / 2 + 4, v.h0 - 7, v.h0 + 1), *v.giro), 0.06)
        if v.luz <= 0:
            continue
        m = mascara_final(items)
        cx, cy = (x0 + x1) / 2, y0 + (y1 - y0) * 0.68
        sx, sy = max((x1 - x0) * 0.45, 6), max((y1 - y0) * 0.38, 8)
        llama = np.exp(-(((xx - cx) / sx) ** 2 + ((yy - cy) / sy) ** 2))
        k = v.luz
        # cada vela a su aire: unas ventanas algo mas vivas que otras
        vidrio = 0.9 + 0.1 * rs.random()
        # arriba del hueco queda el techo de la habitacion, en sombra; los
        # bordes del cristal los tapa el derrame del muro
        vert = np.clip((yy - y0) / max(y1 - y0, 1), 0, 1)
        borde_c = ndimage.gaussian_filter(m, max(1.2, (x1 - x0) * 0.06))
        inten = m * k * (0.42 + 0.3 * vert + 0.4 * llama) * (0.65 + 0.35 * borde_c) * vidrio
        if v.cortina:
            # cortina medio corrida: tapa un lado y deja pasar algo de luz
            lado = (xx - x0) / max(x1 - x0, 1)
            if v.cortina == 'der':
                lado = 1 - lado
            tela = np.clip((0.38 - lado) / 0.12, 0, 1) * (1 - 0.25 * np.clip((yy - y0) / max(y1 - y0, 1), 0, 1))
            inten *= 1 - 0.62 * tela
        luz = np.maximum(luz, inten)
        calor = np.maximum(calor, m * llama ** 2 * (0.25 + 0.6 * k))
        halo += m * k
    # halo en dos escalas: uno ceñido (luz que empapa el marco) y otro ancho
    # (la niebla). Aditivo y flojo: si se pasa, parece una bombilla.
    h1 = ndimage.gaussian_filter(halo, 6)
    h2 = ndimage.gaussian_filter(halo, 30)
    h3 = ndimage.gaussian_filter(halo, 95)
    suma = h1 * 0.45 + h2 * 1.1 + h3 * 2.2
    halo_i = 0.34 * (1 - np.exp(-suma * 2.2))
    alfa = np.clip(luz + halo_i * (1 - luz), 0, 1)
    t = np.clip(calor, 0, 1)[..., None]
    rgb_cristal = LUZ_CALIDA * (1 - t) + LUZ_CLARA * t
    w_c = (luz / np.maximum(alfa, 1e-4))[..., None]
    rgb = rgb_cristal * w_c + LUZ_HALO * (1 - w_c)
    return rgb, alfa


def vano_interior():
    """Lo que se ve por la puerta abierta: la pared del fondo iluminada por el
    fuego (mas clara abajo y hacia la derecha, donde estaria la caldera), el
    canto de la mesa donde sorbe la sopa y el palo del pendulo, quieto en mitad
    del arco. Va en la capa de ventanas, DEBAJO de la hoja: solo se ve cuando
    la hoja se aparta. Todo en contraluz y flojo: son sugerencias, no atrezo."""
    items = [(arco_apuntado(PUERTA_X, 0, PUERTA_ANCHO, PUERTA_ARRANQUE, PUERTA_ALTO), 1)]
    m = mascara_final(items)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    hy = SUELO - yy
    fuego = np.exp(-(((xx - (PUERTA_X + 60)) / 150) ** 2 + ((hy - 70) / 190) ** 2))
    inten = 0.44 + 0.38 * fuego
    sombra = np.zeros((H, W), np.float32)
    # suelo de tablas: franja baja algo mas oscura, con el filo difuso
    sombra = np.maximum(sombra, 0.25 * np.clip((30 - hy) / 12, 0, 1))
    # mesa: tablero y una pata, a la derecha
    mesa = mascara_final([(rect(PUERTA_X + 6, PUERTA_X + 140, 136, 150), 1),
                          (rect(PUERTA_X + 18, PUERTA_X + 28, 0, 138), 1),
                          (rect(PUERTA_X + 96, PUERTA_X + 106, 0, 138), 1),
                          # el cuenco de la sopa
                          ([(PUERTA_X + 44, SUELO - 150), (PUERTA_X + 76, SUELO - 150), (PUERTA_X + 70, SUELO - 164),
                            (PUERTA_X + 50, SUELO - 164)], 1)])
    sombra = np.maximum(sombra, 0.5 * mesa)
    # pendulo: palo largo inclinado que baja de arriba y un incensario al final
    p0, p1 = (PUERTA_X - 60, SUELO - 420), (PUERTA_X - 18, SUELO - 190)
    palo = mascara_final([([(p0[0] - 2.5, p0[1]), (p0[0] + 2.5, p0[1]), (p1[0] + 2.5, p1[1]), (p1[0] - 2.5, p1[1])], 1)])
    cx, cy = p1[0] + 1, p1[1] + 16
    incensario = mascara_final([(elipse(cx, cy, 13, 16, 24), 1),
                                ([(cx - 8, cy - 14), (cx + 8, cy - 14), (cx + 3, cy - 24), (cx - 3, cy - 24)], 1)])
    sombra = np.maximum(sombra, 0.42 * np.maximum(palo, incensario))
    # el humo blanco del incensario: una estela algo mas clara siguiendo el arco
    estela = np.exp(-(((yy - (cy - 4 + (xx - cx) * 0.18)) / 10) ** 2)) * np.clip((cx - xx) / 90, 0, 1)         * np.clip((xx - (cx - 140)) / 40, 0, 1)
    inten = inten * (1 - sombra) + 0.12 * ndimage.gaussian_filter(estela, 3)
    calor = fuego
    return m, inten, calor


def hoja_puerta():
    """La hoja: tablones verticales, tres pletinas con bisagras largas que
    nacen del lado de las bisagras (izquierda) y una argolla. Mascara blanca;
    la tine Godot como la casa."""
    w, h = PUERTA_ANCHO, PUERTA_ALTO
    k = 4
    img = Image.new('L', (w * k, h * k), 0)
    d = ImageDraw.Draw(img)
    # vano apuntado en coordenadas locales (0,0 arriba-izquierda)
    cont = [(x - (PUERTA_X - w / 2), y - (SUELO - h)) for x, y in
            arco_apuntado(PUERTA_X, 0, w, PUERTA_ARRANQUE, PUERTA_ALTO)]
    d.polygon([(x * k, y * k) for x, y in cont], fill=255)
    alfa = np.asarray(img.resize((w, h), Image.BOX), np.float32) / 255.0
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    val = mat_madera(44.0)(xx + 12, yy, 0.93)
    # pletinas y bisagras (mas claras: hierro que coge algo de luz)
    herr = Image.new('L', (w * k, h * k), 0)
    dh = ImageDraw.Draw(herr)
    for hy in (60, 190, 300):
        yb = h - hy
        dh.rectangle((0, (yb - 7) * k, (w * 0.78) * k, (yb + 7) * k), fill=255)
        # remate en voluta
        ex = w * 0.78
        dh.ellipse(((ex - 4) * k, (yb - 14) * k, (ex + 22) * k, (yb + 14) * k), outline=255, width=5 * k)
        for cx in range(14, int(w * 0.76), 30):
            dh.ellipse(((cx - 3.5) * k, (yb - 3.5) * k, (cx + 3.5) * k, (yb + 3.5) * k), fill=150)
    # argolla
    ax, ay = w * 0.8, h - 246
    dh.ellipse(((ax - 13) * k, (ay - 13) * k, (ax + 13) * k, (ay + 13) * k), fill=200)
    dh.ellipse(((ax - 17) * k, (ay + 2) * k, (ax + 17) * k, (ay + 38) * k), outline=255, width=4 * k)
    hm = np.asarray(herr.resize((w, h), Image.BOX), np.float32) / 255.0
    val = val * (1 - hm) + (0.99 - 0.05 * (hm < 0.7)) * hm
    # canto del lado que se abre algo mas claro (luz de dentro)
    val += 0.04 * np.clip((xx - (w - 8)) / 8, 0, 1)
    # sombra del arco sobre la parte alta
    val -= 0.05 * np.clip((140 - yy) / 140, 0, 1)
    val = np.clip(val, 0.78, 1.0)
    return alfa, val


def luz_puerta():
    """Halo del vano + abanico en el suelo. Imagen de 760 x 760: el punto del
    suelo en el centro de la puerta cae en (380, 470)."""
    w, h = 760, 760
    ox, oy = 380, 470
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    rel_x, rel_y = xx - ox, yy - oy
    # halo alrededor del vano (por encima del suelo)
    vano = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(vano)
    cont = [(x - PUERTA_X + ox, y - SUELO + oy) for x, y in arco_apuntado(PUERTA_X, 0, PUERTA_ANCHO, PUERTA_ARRANQUE,
                                                                             PUERTA_ALTO)]
    d.polygon(cont, fill=255)
    v = np.asarray(vano, np.float32) / 255.0
    # Mas flojo en el centro que en las jambas: dentro del vano ya esta la luz
    # del interior (capa de ventanas) y si se suman las dos el hueco se quema a
    # blanco. Pero SIN recortar el vano: el script estrecha este sprite hacia la
    # rendija cuando la puerta esta entornada, y un hueco recortado se convertia
    # en una lengua oscura con forma de arco al lado de la rendija. Un perfil
    # suave en x sigue viendose bien estrechado.
    halo = ndimage.gaussian_filter(v, 26) * 0.38 + ndimage.gaussian_filter(v, 80) * 0.42
    perfil = 0.4 + 0.6 * np.clip((np.abs(rel_x) - 50) / 70, 0, 1) ** 2 * (3 - 2 * np.clip((np.abs(rel_x) - 50) / 70, 0, 1))
    halo *= perfil * np.clip((4 - rel_y) / 8, 0, 1)
    # abanico en el suelo: trapecio que se abre hacia delante y se apaga
    t = np.clip(rel_y / 250.0, 0, 1)
    semi = PUERTA_ANCHO / 2 - 10 + t * 150
    lado = np.clip((semi - np.abs(rel_x)) / (30 + t * 130), 0, 1)
    caida = (1 - t) ** 2.2 * (rel_y >= 0)
    abanico = lado * caida * 0.42
    abanico = ndimage.gaussian_filter(abanico, 9)
    # el umbral, justo al pie, mas vivo
    umbral = np.exp(-((rel_x / 115) ** 2 + ((rel_y - 2) / 9) ** 2)) * 0.3
    a = np.clip(halo + abanico + umbral, 0, 1)
    tt = np.clip(1 - t * 1.2, 0, 1)[..., None] * (rel_y[..., None] >= 0) + (rel_y[..., None] < 0) * 0.6
    rgb = LUZ_HALO * (1 - tt) + LUZ_CALIDA * tt
    return rgb, a, (ox, oy)


def humo_textura():
    """Bocanada: tres manchas gaussianas y ruido, blanca con alfa."""
    n = 128
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32) / n - 0.5
    r = np.sqrt(xx ** 2 + yy ** 2)
    base = np.clip(1 - r / 0.5, 0, 1) ** 1.8
    rn = pc.ruido_valor(n, n, 28, 3, 5, False)
    a = np.clip(base * (0.55 + 0.9 * (rn - 0.5) + 0.45), 0, 1) * base
    a = ndimage.gaussian_filter(a, 2.0)
    return a / a.max()


# --------------------------------------------------------------------------
# Guardar
# --------------------------------------------------------------------------

def luces_shader(V):
    """Una entrada por fuente de luz: cada ventana encendida y el vano de la
    puerta. El shader pesa el temblor de cada una con una gaussiana alrededor
    de su centro, asi el halo tiembla con su ventana y no hay costuras."""
    out = []
    rs = random.Random(9)
    fuentes = [(v.contorno(), max(v.ancho, v.alto)) for v in V if v.luz > 0]
    fuentes.append((arco_apuntado(PUERTA_X, 0, PUERTA_ANCHO, PUERTA_ARRANQUE, PUERTA_ALTO), PUERTA_ALTO))
    for cont, tam in fuentes:
        c = np.asarray(cont).mean(axis=0)
        out.append([round(float(c[0] / W), 5), round(float(c[1] / H), 5), round(float((tam * 0.9 + 60) / W), 5),
                    round(rs.random(), 3)])
    return out


def guardar_rgba(rgb, a, ruta):
    out = np.zeros(a.shape + (4,), np.uint8)
    out[..., :3] = (np.clip(rgb, 0, 1) * 255 + 0.5).astype(np.uint8)
    out[..., 3] = (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(out, 'RGBA').save(ruta, optimize=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('salida', nargs='?', default=str(Path(__file__).resolve().parents[2] /
                                                     'assets/world/casa_exterior'))
    ap.add_argument('--preview', default=None, help='carpeta donde dejar una vista previa compuesta')
    args = ap.parse_args()
    out = Path(args.salida)
    out.mkdir(parents=True, exist_ok=True)

    rnd = random.Random(1)
    s, V, chimeneas = construir(rnd)

    # Vano de la puerta en la capa de luz
    rgb_v, a_v = capa_ventanas(V, s)
    m, inten, calor = vano_interior()
    rgb_vano = LUZ_CALIDA * (1 - calor[..., None]) + LUZ_CLARA * calor[..., None]
    a_vano = m * inten
    a_tot = a_vano + a_v * (1 - a_vano)
    w_vano = (a_vano / np.maximum(a_tot, 1e-4))[..., None]
    rgb_tot = rgb_vano * w_vano + rgb_v * (1 - w_vano)

    alfa, valor = s.final()
    # niebla baja: lo que esta cerca del suelo se aclara un poco
    hy = SUELO - np.arange(H, dtype=np.float32)[:, None]
    valor = valor + 0.05 * np.clip(1 - hy / 240.0, 0, 1)
    valor = valor + pc.grano(W, H, 21, 0.012)
    valor = np.clip(valor, 0.8, 1.0)
    pc.a_png_blanco(alfa, str(out / 'casa_silueta.png'), valor)
    guardar_rgba(rgb_tot, a_tot, str(out / 'casa_ventanas.png'))

    ha, hv = hoja_puerta()
    pc.a_png_blanco(ha, str(out / 'puerta.png'), hv)

    rgb_l, a_l, (lox, loy) = luz_puerta()
    guardar_rgba(rgb_l, a_l, str(out / 'luz_puerta.png'))

    hm = humo_textura()
    pc.a_png_blanco(hm, str(out / 'humo.png'))

    meta = {
        'nota': 'Coordenadas de ESCENA: origen = suelo en el centro de la puerta; y hacia abajo. '
                'Rects = [x, y, ancho, alto].',
        'imagen': {'ancho': W, 'alto': H, 'origen_en_imagen': [PUERTA_X, SUELO],
                   'offset_sprite': [-PUERTA_X, -SUELO]},
        'puerta': {'rect': [-PUERTA_ANCHO / 2, -PUERTA_ALTO, PUERTA_ANCHO, PUERTA_ALTO],
                   'bisagra': [-PUERTA_ANCHO / 2, 0], 'arranque_arco': -PUERTA_ARRANQUE},
        'luz_puerta': {'origen_en_imagen': [lox, loy]},
        'ventanas': [{'nombre': v.nombre, 'rect': v.rect_escena(), 'encendida': v.luz > 0,
                      'luz': round(v.luz, 2)} for v in V],
        'chimeneas': [[round(x - PUERTA_X, 1), round(y - SUELO, 1)] for x, y in chimeneas],
        # Para el shader de temblor (parametro 'luces' del material de Ventanas):
        # centro en UV, radio de influencia en UV de x, semilla.
        'luces_shader': luces_shader(V),
    }
    # lo mismo listo para pegar en el .tscn (shader_parameter/luces y n_luces)
    meta['luces_shader_tscn'] = 'PackedVector4Array(%s)' % ', '.join(
        f'{v:g}' for luz in meta['luces_shader'] for v in luz)
    meta['n_luces'] = len(meta['luces_shader'])
    (out / 'casa_meta.json').write_text(json.dumps(meta, indent=1, ensure_ascii=False), encoding='utf-8')
    print('ok', out)

    if args.preview:
        previsualizar(out, Path(args.preview), alfa, valor, rgb_tot, a_tot, ha, hv, rgb_l, a_l, (lox, loy))


def previsualizar(out, carpeta, alfa, valor, rgb_w, a_w, ha, hv, rgb_l, a_l, lo):
    """Composicion rapida en Python: cielo de noche, unos arboles, la casa
    tintada, la luz sumada y la hoja entornada. Solo para iterar deprisa; la
    buena es la captura de Godot."""
    carpeta.mkdir(parents=True, exist_ok=True)
    SW, SH = 2912, 1632
    ox = 1456 - 500       # la casa centrada: su centro esta ~500 px a la derecha de la puerta
    top = np.array(pc.hex_a_rgb('#16213d'), np.float32)
    hor = np.array(pc.hex_a_rgb('#4a6a9a'), np.float32)
    t = np.clip(np.arange(SH, dtype=np.float32) / 1200.0, 0, 1)[:, None, None] ** 1.3
    fondo = np.broadcast_to(top * (1 - t) + hor * t, (SH, SW, 3)).copy()
    # arboles lejanos y cercanos
    rr = random.Random(5)
    for capa, (col, n, alto) in enumerate((('#46618f', 9, 900), ('#2a3a5e', 7, 1100))):
        L = pc.Lienzo(SW, SH)
        for i in range(n):
            x = rr.uniform(0, SW)
            ramas = pc.generar_arbol(x, 1205, alto * rr.uniform(0.7, 1.1), 16 + capa * 8, pc.EstiloArbol(), rr)
            pc.pintar_ramas(L.draw, ramas, 255)
        componer(fondo, pc.tintar(L.final(), pc.hex_a_rgb(col)))
    fondo[1200:] = np.array(pc.hex_a_rgb('#0e1322'))
    casa = pc.tintar(alfa, pc.hex_a_rgb('#1a2138'), valor)
    componer(fondo, casa, ox - PUERTA_X, 1200 - SUELO)
    # luz aditiva
    x0, y0 = ox - PUERTA_X, 1200 - SUELO
    sub = fondo[max(y0, 0):y0 + H, max(x0, 0):x0 + W]
    cy0, cx0 = max(-y0, 0), max(-x0, 0)
    sub += (rgb_w * a_w[..., None])[cy0:cy0 + sub.shape[0], cx0:cx0 + sub.shape[1]]
    # hoja entornada: escala 0.88 desde la bisagra
    hw = int(PUERTA_ANCHO * 0.88)
    hoja = Image.fromarray((np.dstack([hv, hv, hv, ha]) * 255).astype(np.uint8), 'RGBA').resize((hw, PUERTA_ALTO))
    hoja = np.asarray(hoja, np.float32) / 255.0
    tin = np.array(pc.hex_a_rgb('#1a2138'))
    capa = np.dstack([hoja[..., :3] * tin, hoja[..., 3]])
    componer(fondo, capa, ox - PUERTA_ANCHO // 2, 1200 - PUERTA_ALTO)
    lx, ly = ox - lo[0], 1200 - lo[1]
    k = 0.35
    fondo[ly:ly + a_l.shape[0], lx:lx + a_l.shape[1]] += rgb_l * a_l[..., None] * k
    # Magnus para la escala
    try:
        mg = Image.open(Path(__file__).resolve().parents[2] /
                        'assets/characters/magnus/magnus_respirando.png').crop((0, 0, 292, 360))
        mg = np.asarray(mg.convert('RGBA'), np.float32) / 255.0
        componer(fondo, mg, ox - 60 - 146, 1200 - 345)
    except Exception as e:  # noqa: BLE001
        print('sin magnus', e)
    img = Image.fromarray((np.clip(fondo, 0, 1) * 255).astype(np.uint8))
    img.save(carpeta / 'py_preview.png')
    img.resize((1456, 816), Image.LANCZOS).save(carpeta / 'py_preview_s.png')


def componer(fondo, capa, x=0, y=0):
    pc.componer(fondo, capa, x, y)


if __name__ == '__main__':
    main()

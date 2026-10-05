"""Pincel: utilidades para pintar por codigo el mundo de The Master Mason.

El estilo sale de las referencias del bosque (capas de arboles desnudos en
niebla, cielo degradado, grano de acuarela): SILUETAS. Cada capa se genera como
una mascara en blanco con alfa, y el color se lo pone Godot con `modulate`
segun la hora del dia y la profundidad. Asi una misma hoja sirve para el
atardecer y para la noche, y la memoria de video es la de una sola imagen.

Todo se pinta a SS veces el tamano final y se reduce con Lanczos: es el
antialias. Las funciones trabajan sobre arrays float32 de 0..1 (alfa) salvo
donde se diga.
"""
from __future__ import annotations

import math
import random
from dataclasses import dataclass

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SS = 2  # sobremuestreo


# --------------------------------------------------------------------------
# Ruido
# --------------------------------------------------------------------------

def ruido_valor(w: int, h: int, escala: float, octavas: int = 4, semilla: int = 0,
                periodico_x: bool = True) -> np.ndarray:
    """Ruido de valor fractal 0..1. Con periodico_x la costura izquierda-derecha
    no se nota, para hojas que se repiten en horizontal."""
    rs = np.random.default_rng(semilla)
    total = np.zeros((h, w), np.float32)
    amp, norm = 1.0, 0.0
    for o in range(octavas):
        cw = max(2, int(round(w / escala * (2 ** o))))
        ch = max(2, int(round(h / escala * (2 ** o))))
        rejilla = rs.random((ch + 1, cw + (0 if periodico_x else 1))).astype(np.float32)
        if periodico_x:
            rejilla = np.concatenate([rejilla, rejilla[:, :1]], axis=1)
        img = Image.fromarray((rejilla * 255).astype(np.uint8), 'L')
        img = img.resize((w, h), Image.BICUBIC)
        total += np.asarray(img, np.float32) / 255.0 * amp
        norm += amp
        amp *= 0.5
    return total / norm


def grano(w: int, h: int, semilla: int = 0, fuerza: float = 1.0) -> np.ndarray:
    """Grano fino de papel, centrado en 0 (-1..1 aprox.)."""
    rs = np.random.default_rng(semilla)
    g = rs.normal(0, 1, (h, w)).astype(np.float32)
    g = np.asarray(Image.fromarray(np.clip(g * 40 + 128, 0, 255).astype(np.uint8), 'L')
                   .filter(ImageFilter.GaussianBlur(0.6)), np.float32) / 128.0 - 1.0
    return g * fuerza


# --------------------------------------------------------------------------
# Arboles desnudos
# --------------------------------------------------------------------------

@dataclass
class Rama:
    x0: float
    y0: float
    x1: float
    y1: float
    w0: float
    w1: float


@dataclass
class EstiloArbol:
    """Parametros del arbol. Los valores por defecto dan el arbol alto y ramoso
    de las referencias; 'retorcido' sube la curvatura y baja el orden."""
    niveles: int = 7
    ramas: tuple[int, int] = (2, 3)
    angulo: float = 0.55          # radianes de apertura media
    angulo_var: float = 0.25
    decaimiento: float = 0.74     # longitud de la hija respecto a la madre
    grosor_decae: float = 0.66
    curvatura: float = 0.12       # desvio por segmento
    segmentos: int = 4
    subir: float = 0.35           # cuanto tiran las ramas hacia arriba (fototropismo)
    tronco_frac: float = 0.34     # parte del alto que es tronco limpio
    copa_estrecha: float = 1.0    # <1 recoge las ramas hacia el eje (alamo)


def generar_arbol(x: float, y_suelo: float, alto: float, grosor: float,
                  estilo: EstiloArbol, rnd: random.Random) -> list[Rama]:
    """Arbol con guia: el tronco sigue hacia arriba adelgazando y va soltando
    ramas laterales (alternas) desde tronco_frac; cada rama hace lo mismo con un
    nivel menos, y al final de cada guia hay una horquilla corta. Asi sale la
    copa de ramitas finas de las referencias en vez de horquillas en Y."""
    ramas: list[Rama] = []
    paso = max(alto / 28.0, 6.0)          # largo de segmento del tronco
    max_nivel = estilo.niveles

    def crecer(x0, y0, ang, largo, w0, nivel, inicio_ramas):
        n = max(2, int(largo / (paso * (0.72 ** nivel))))
        px, py, a = x0, y0, ang
        w_fin = max(w0 * 0.18, 0.35)
        lado = rnd.choice((-1, 1))
        for i in range(n):
            t0, t1 = i / n, (i + 1) / n
            a += rnd.gauss(0, estilo.curvatura * (1.0 + nivel * 0.35))
            a += (-math.pi / 2 - a) * estilo.subir * 0.08   # fototropismo
            l = largo / n
            nx, ny = px + math.cos(a) * l, py + math.sin(a) * l
            wa, wb = w0 + (w_fin - w0) * t0, w0 + (w_fin - w0) * t1
            ramas.append(Rama(px, py, nx, ny, wa, wb))
            px, py = nx, ny
            if nivel < max_nivel and t1 > inicio_ramas and t1 < 0.97:
                prob = 0.55 if nivel == 0 else 0.42
                if rnd.random() < prob:
                    lado = -lado
                    apertura = (estilo.angulo + abs(rnd.gauss(0, estilo.angulo_var))) * estilo.copa_estrecha
                    hija = largo * (1.0 - t1) * rnd.uniform(0.55, 0.95) * (0.9 if nivel == 0 else 0.8)
                    hija = max(hija, largo * 0.12)
                    crecer(px, py, a + lado * apertura, hija, max(wb * rnd.uniform(0.45, 0.7), 0.35),
                           nivel + 1, 0.12)
        # Horquilla final: la guia se abre en dos o tres ramitas.
        if nivel < max_nivel:
            k = rnd.randint(*estilo.ramas)
            for j in range(k):
                off = ((j / max(k - 1, 1)) - 0.5) * estilo.angulo * 1.2 + rnd.gauss(0, 0.15)
                crecer(px, py, a + off, largo * estilo.decaimiento * 0.35, max(w_fin * 0.9, 0.35),
                       nivel + 2, 0.2)

    a0 = -math.pi / 2 + rnd.gauss(0, 0.035)
    crecer(x, y_suelo, a0, alto, grosor, 0, estilo.tronco_frac)
    return ramas


def pintar_ramas(draw: ImageDraw.ImageDraw, ramas: list[Rama], valor: int = 255,
                 dx: float = 0.0, s: float = SS) -> None:
    """Cada rama como un trapecio con sus extremos redondeados."""
    for r in ramas:
        x0, y0, x1, y1 = (r.x0 + dx) * s, r.y0 * s, (r.x1 + dx) * s, r.y1 * s
        w0, w1 = max(r.w0 * s, 0.6), max(r.w1 * s, 0.5)
        ang = math.atan2(y1 - y0, x1 - x0)
        nx, ny = -math.sin(ang), math.cos(ang)
        poly = [(x0 + nx * w0 / 2, y0 + ny * w0 / 2), (x1 + nx * w1 / 2, y1 + ny * w1 / 2),
                (x1 - nx * w1 / 2, y1 - ny * w1 / 2), (x0 - nx * w0 / 2, y0 - ny * w0 / 2)]
        draw.polygon(poly, fill=valor)
        if w0 > 1.5:
            draw.ellipse((x0 - w0 / 2, y0 - w0 / 2, x0 + w0 / 2, y0 + w0 / 2), fill=valor)


# --------------------------------------------------------------------------
# Suelo, hierba
# --------------------------------------------------------------------------

def perfil_colinas(w: int, base: float, amplitud: float, semilla: int, suave: float = 380.0,
                   periodico: bool = True) -> np.ndarray:
    """Alto del suelo en cada columna (y en px). Periodico para repetir."""
    n = ruido_valor(w, 1, suave, 3, semilla, periodico).ravel() if periodico else \
        ruido_valor(w, 1, suave, 3, semilla, False).ravel()
    return base - (n - 0.5) * 2 * amplitud


def pintar_hierba(draw: ImageDraw.ImageDraw, x: float, y: float, alto: float,
                  rnd: random.Random, valor: int = 255, s: float = SS) -> None:
    """Una mata de hierba: briznas curvas finas."""
    for _ in range(rnd.randint(3, 9)):
        h = alto * rnd.uniform(0.4, 1.0)
        inc = rnd.gauss(0, 0.35)
        pts = []
        for k in range(6):
            t = k / 5
            pts.append(((x + inc * h * t * t + rnd.gauss(0, 0.3)) * s, (y - h * t) * s))
        for k in range(5):
            w = max((1 - k / 5) * 2.2 * s, 0.6)
            draw.line([pts[k], pts[k + 1]], fill=valor, width=int(round(w)))


def pintar_planta_flor(draw: ImageDraw.ImageDraw, x: float, y: float, alto: float,
                       rnd: random.Random, valor: int = 255, s: float = SS) -> list[tuple[float, float]]:
    """Tallo fino con capullos en las puntas (las plantitas de las referencias).
    Devuelve donde han quedado los capullos por si se quieren encender."""
    estilo = EstiloArbol(niveles=3, ramas=(1, 2), angulo=0.6, decaimiento=0.7,
                         grosor_decae=0.7, curvatura=0.18, segmentos=3, tronco_frac=0.45)
    ramas = generar_arbol(x, y, alto, 2.2, estilo, rnd)
    pintar_ramas(draw, ramas, valor, s=s)
    puntas = []
    finales = {(round(r.x1, 1), round(r.y1, 1)) for r in ramas}
    iniciales = {(round(r.x0, 1), round(r.y0, 1)) for r in ramas}
    for (px, py) in finales - iniciales:
        rr = rnd.uniform(2.0, 4.5)
        draw.ellipse(((px - rr) * s, (py - rr * 1.3) * s, (px + rr) * s, (py + rr * 0.7) * s), fill=valor)
        puntas.append((px, py))
    return puntas


# --------------------------------------------------------------------------
# Lienzos
# --------------------------------------------------------------------------

class Lienzo:
    """Mascara en L a SS veces el tamano final."""

    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.img = Image.new('L', (w * SS, h * SS), 0)
        self.draw = ImageDraw.Draw(self.img)

    def final(self) -> np.ndarray:
        return np.asarray(self.img.resize((self.w, self.h), Image.LANCZOS), np.float32) / 255.0


def a_png_blanco(alfa: np.ndarray, ruta: str, valor: np.ndarray | None = None) -> None:
    """Guarda una mascara como PNG RGBA blanco (o gris 'valor') con alfa. El
    color lo pone Godot con modulate."""
    h, w = alfa.shape
    v = np.ones((h, w), np.float32) if valor is None else np.clip(valor, 0, 1)
    rgba = np.zeros((h, w, 4), np.uint8)
    rgba[..., 0] = rgba[..., 1] = rgba[..., 2] = (v * 255).astype(np.uint8)
    rgba[..., 3] = (np.clip(alfa, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(rgba, 'RGBA').save(ruta, optimize=True)


def tintar(alfa: np.ndarray, color: tuple[float, float, float], valor: np.ndarray | None = None) -> np.ndarray:
    """Para previsualizar: mascara -> RGBA float con el color de Godot."""
    h, w = alfa.shape
    v = np.ones((h, w), np.float32) if valor is None else valor
    out = np.zeros((h, w, 4), np.float32)
    for i in range(3):
        out[..., i] = color[i] * v
    out[..., 3] = alfa
    return out


def componer(fondo: np.ndarray, capa: np.ndarray, x: int = 0, y: int = 0) -> None:
    """Alfa 'over' in situ. fondo RGB float, capa RGBA float."""
    h, w = capa.shape[:2]
    H, W = fondo.shape[:2]
    x0, y0, x1, y1 = max(x, 0), max(y, 0), min(x + w, W), min(y + h, H)
    if x1 <= x0 or y1 <= y0:
        return
    c = capa[y0 - y:y1 - y, x0 - x:x1 - x]
    a = c[..., 3:4]
    fondo[y0:y1, x0:x1] = fondo[y0:y1, x0:x1] * (1 - a) + c[..., :3] * a


def hex_a_rgb(h: str) -> tuple[float, float, float]:
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))

"""Genera las hojas del bosque de The Master Mason.

    python bosque.py                 # todas
    python bosque.py capa2 suelo     # solo esas
    python bosque.py --preview       # ademas, una composicion de prueba por hora

Salida: assets/world/bosque/ (del proyecto). Todas las capas son
mascaras BLANCAS con alfa (el valor interior varia un poco, para que no sea
papel recortado): el color lo pone bosque.gd con modulate, segun la hora del
dia y la profundidad. Las capas se repiten en horizontal sin costura.

Coordenadas: el suelo de Magnus esta en y = 1200 del mundo. Cada capa lleva en
bosque_meta.json su 'y_arriba' (y del mundo de su borde superior) y su escala
de dibujo (las lejanas se pintan a media resolucion y se estiran x2: estan en
niebla y no se nota, y cuestan la cuarta parte).
"""
from __future__ import annotations

import json
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
from pincel import (SS, EstiloArbol, Lienzo, a_png_blanco, componer, generar_arbol,  # noqa: E402
                    grano, hex_a_rgb, pintar_hierba, pintar_planta_flor, pintar_ramas,
                    ruido_valor, tintar)

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', '..'))  # el proyecto
SALIDA = os.path.join(REPO, 'assets', 'world', 'bosque')
SUELO = 1200
ANCHO = 4096            # ancho de repeticion de todas las capas, en px del mundo (de la capa)

meta: dict = {}


def guardar(nombre: str, alfa: np.ndarray, valor: np.ndarray | None = None, **info) -> None:
    os.makedirs(SALIDA, exist_ok=True)
    ruta = os.path.join(SALIDA, nombre + '.png')
    a_png_blanco(alfa, ruta, valor)
    meta[nombre] = dict(ancho=int(alfa.shape[1]), alto=int(alfa.shape[0]), **info)
    print(f'  {nombre}: {alfa.shape[1]}x{alfa.shape[0]}')


# --------------------------------------------------------------------------
# Estilos de arbol del bosque
# --------------------------------------------------------------------------

# El bosque del cuento es "regular", "aburrido": pocos tipos que se repiten.
# Alto y recto (el de la niebla), ancho de copa redonda, y retorcido (el de la
# noche azul de la referencia).
ESTILOS = {
    'alto': EstiloArbol(niveles=4, angulo=0.55, curvatura=0.07, tronco_frac=0.22, copa_estrecha=0.75),
    'redondo': EstiloArbol(niveles=4, angulo=0.85, curvatura=0.10, tronco_frac=0.38),
    'retorcido': EstiloArbol(niveles=4, angulo=0.8, curvatura=0.2, tronco_frac=0.33, subir=0.12),
    'joven': EstiloArbol(niveles=3, angulo=0.6, curvatura=0.09, tronco_frac=0.3),
}


def pintar_arbol_envuelto(lz: Lienzo, x: float, base: float, alto: float, grosor: float,
                          estilo: EstiloArbol, rnd: random.Random, ancho: int, valor: int = 255) -> list:
    """Un arbol, repetido a un lado y al otro para que la hoja cierre sin costura."""
    ramas = generar_arbol(x, base, alto, grosor, estilo, rnd)
    minx = min(min(r.x0, r.x1) for r in ramas)
    maxx = max(max(r.x0, r.x1) for r in ramas)
    for dx in (-ancho, 0, ancho):
        if maxx + dx >= 0 and minx + dx <= ancho:
            pintar_ramas(lz.draw, ramas, valor, dx=dx)
    return ramas


def raices(lz: Lienzo, x: float, base: float, grosor: float, rnd: random.Random, ancho: int) -> None:
    """Ensanche del pie del tronco: la corteza se abre en campana justo antes de
    hundirse en la tierra, con dos o tres lomos de raiz. Nada de triangulos."""
    alto = grosor * 1.3
    for dx in (-ancho, 0, ancho):
        if not (-grosor * 4 < x + dx < ancho + grosor * 4):
            continue
        izq, der = [], []
        n = 16
        for k in range(n + 1):
            t = k / n                      # 0 en el suelo, 1 arriba
            semi = grosor / 2 * (0.9 + 1.2 * math.exp(-t * 3.5))
            y = base + 3 - t * alto
            izq.append(((x + dx - semi) * SS, y * SS))
            der.append(((x + dx + semi) * SS, y * SS))
        lz.draw.polygon(izq + der[::-1], fill=255)


# --------------------------------------------------------------------------
# Capas de arboles
# --------------------------------------------------------------------------

CAPAS = {
    # nombre: (escala de dibujo, y_arriba, alto de hoja (mundo), arboles: (alto, grosor, separacion),
    #          suelo propio (base, amplitud), niebla al pie, semilla, mezcla de estilos)
    'capa0': dict(escala=0.5, y_arriba=-40, alto=1300, arbol=(900, 16, 190), base=SUELO - 90, amp=40,
                  niebla=0.55, semilla=101, estilos=('alto', 'alto', 'redondo', 'joven')),
    'capa1': dict(escala=0.5, y_arriba=-80, alto=1340, arbol=(1100, 22, 300), base=SUELO - 50, amp=30,
                  niebla=0.45, semilla=202, estilos=('alto', 'redondo', 'alto', 'retorcido')),
    'capa2': dict(escala=1.0, y_arriba=-120, alto=1370, arbol=(1300, 30, 520), base=SUELO - 15, amp=18,
                  niebla=0.3, semilla=303, estilos=('alto', 'retorcido', 'redondo', 'alto', 'joven')),
    'capa3': dict(escala=1.0, y_arriba=-200, alto=1450, arbol=(1500, 40, 820), base=SUELO + 5, amp=10,
                  niebla=0.12, semilla=404, estilos=('retorcido', 'alto', 'redondo', 'retorcido')),
}


def capa_arboles(nombre: str) -> None:
    c = CAPAS[nombre]
    e = c['escala']
    w, h = int(ANCHO * e), int(c['alto'] * e)
    rnd = random.Random(c['semilla'])
    lz = Lienzo(w, h)
    alto, grosor, sep = c['arbol']
    base = (c['base'] - c['y_arriba']) * e
    # Arboles pequenos detras, grandes delante dentro de la misma capa.
    posiciones = []
    x = rnd.uniform(0, sep)
    while x < ANCHO:
        posiciones.append(x)
        x += sep * rnd.uniform(0.65, 1.35)
    arboles = []
    for x in posiciones:
        nombre_estilo = rnd.choice(c['estilos'])
        a = alto * rnd.uniform(0.7, 1.12) * (0.75 if nombre_estilo == 'joven' else 1.0)
        g = grosor * rnd.uniform(0.75, 1.25) * (0.6 if nombre_estilo == 'joven' else 1.0)
        arboles.append((a, x, g, nombre_estilo))
    arboles.sort()
    for a, x, g, nombre_estilo in arboles:
        b = base + rnd.uniform(-6, 10) * e
        pintar_arbol_envuelto(lz, x * e, b, a * e, g * e, ESTILOS[nombre_estilo], rnd, w)
        raices(lz, x * e, b, g * e, rnd, w)
    # Suelo propio de la capa: una loma suave que tapa el pie de los troncos.
    perfil = base + 12 * e - (ruido_valor(w, 1, 700 * e, 3, c['semilla'] + 7).ravel() - 0.5) * 2 * c['amp'] * e
    for cx in range(0, w, 1):
        lz.draw.rectangle((cx * SS, perfil[cx] * SS, (cx + 1) * SS, h * SS), fill=255)
    alfa = lz.final()
    # Niebla al pie: el alfa baja cerca del suelo en las capas lejanas.
    yy = np.arange(h, dtype=np.float32)[:, None]
    subida = np.clip((yy - (base - 420 * e)) / (420 * e), 0, 1) ** 1.5
    alfa *= 1.0 - c['niebla'] * subida
    # Valor interior: grano de corteza muy suave, mas en las cercanas.
    fuerza = 0.05 if e < 1 else 0.12
    valor = 1.0 - fuerza + fuerza * ruido_valor(w, h, 50 * e, 3, c['semilla'] + 11)
    guardar(nombre, alfa, valor, escala=e, y_arriba=c['y_arriba'], repetir=ANCHO)


# --------------------------------------------------------------------------
# Suelo del jugador y lo que va delante
# --------------------------------------------------------------------------

def perfil_suelo(w: int, semilla: int, base: float, amp: float, suave: float) -> np.ndarray:
    return base - (ruido_valor(w, 1, suave, 3, semilla).ravel() - 0.5) * 2 * amp


def suelo() -> None:
    """Tierra del camino (y 1150..1632+). El borde superior va un poco por
    encima de 1200 para que la hierba tape el canto; los pies pisan en 1200."""
    y0, alto = 1110, 560
    w, h = ANCHO, alto
    rnd = random.Random(55)
    lz = Lienzo(w, h)
    perfil = perfil_suelo(w, 56, SUELO - y0 - 2, 5, 600)
    for cx in range(w):
        lz.draw.rectangle((cx * SS, perfil[cx] * SS, (cx + 1) * SS, h * SS), fill=255)
    for _ in range(420):
        x = rnd.uniform(0, w)
        for dx in (-w, 0, w):
            if -80 < x + dx < w + 80:
                pintar_hierba(lz.draw, x + dx, perfil[int(x) % w] + 5, rnd.uniform(18, 62), rnd)
    bulbos = []
    for _ in range(14):
        x = rnd.uniform(60, w - 60)
        puntas = pintar_planta_flor(lz.draw, x, perfil[int(x)] + 5, rnd.uniform(110, 280), rnd)
        bulbos += [(round(px, 1), round(py + y0, 1)) for (px, py) in puntas]
    # piedras y ramas caidas sueltas
    for _ in range(18):
        x = rnd.uniform(0, w)
        r = rnd.uniform(6, 16)
        y = perfil[int(x) % w] + rnd.uniform(4, 30)
        lz.draw.ellipse(((x - r * 1.6) * SS, (y - r) * SS, (x + r * 1.6) * SS, (y + r * 0.6) * SS), fill=255)
    alfa = lz.final()
    # La tierra no es un bloque plano: la hierba y las plantas (por encima de la
    # linea) van a valor 1, como silueta contra el cielo; la tierra baja de 0,9
    # junto a la linea -- el camino que se aleja, en la bruma -- a 0,42 abajo, y
    # lleva hojarasca en manchas de poco contraste.
    yy = np.arange(h, dtype=np.float32)[:, None]
    linea = perfil[None, :].astype(np.float32)
    bajo = np.clip((yy - linea - 4) / 330.0, 0, 1)
    valor = np.where(yy < linea + 4, 1.0, 0.9 - 0.48 * bajo ** 0.8)
    valor = valor * (0.9 + 0.1 * ruido_valor(w, h, 26, 4, 57)) * (0.96 + 0.04 * ruido_valor(w, h, 6, 2, 58))
    guardar('suelo', alfa, valor, escala=1.0, y_arriba=y0, repetir=ANCHO)
    meta['suelo']['bulbos'] = bulbos


def suelo_frente() -> None:
    """Flequillo de hierba que va DELANTE de Magnus, a la misma velocidad que el
    suelo: le tapa unos pocos px de los pies y lo asienta en la tierra."""
    y0, alto = 1150, 90
    w = ANCHO
    rnd = random.Random(66)
    lz = Lienzo(w, alto)
    for _ in range(900):
        x = rnd.uniform(0, w)
        for dx in (-w, 0, w):
            if -40 < x + dx < w + 40:
                pintar_hierba(lz.draw, x + dx, SUELO - y0 + rnd.uniform(2, 14), rnd.uniform(8, 22), rnd)
    alfa = lz.final()
    guardar('suelo_frente', alfa, None, escala=1.0, y_arriba=y0, repetir=ANCHO)


def primer_plano() -> None:
    """Matas altas y oscuras en primerisimo termino (paralaje > 1), abajo."""
    y0, alto = 1330, 420
    w = ANCHO
    rnd = random.Random(77)
    lz = Lienzo(w, alto)
    perfil = perfil_suelo(w, 78, 170, 40, 500)
    for cx in range(w):
        lz.draw.rectangle((cx * SS, perfil[cx] * SS, (cx + 1) * SS, alto * SS), fill=255)
    # matas: grupos, no un cesped continuo
    x = 0.0
    while x < w:
        x += rnd.uniform(160, 520)
        for _ in range(rnd.randint(4, 12)):
            xx = x + rnd.gauss(0, 50)
            for dx in (-w, 0, w):
                if -150 < xx + dx < w + 150:
                    pintar_hierba(lz.draw, xx + dx, perfil[int(xx) % w] + 8, rnd.uniform(60, 190), rnd)
        if rnd.random() < 0.3:
            pintar_planta_flor(lz.draw, x, perfil[int(x) % w] + 8, rnd.uniform(150, 280), rnd)
    alfa = np.asarray(Image.fromarray((lz.final() * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.6)),
                      np.float32) / 255.0   # un pelo desenfocado: esta muy cerca
    guardar('primer_plano', alfa, None, escala=1.0, y_arriba=y0, repetir=ANCHO)


# --------------------------------------------------------------------------
# Piezas unicas
# --------------------------------------------------------------------------

def valle() -> None:
    """El valle del principio: lomas que bajan y, a lo lejos, una ciudad sin
    nombre con torres y una catedral (Santiago, que el anciano no sabe nombrar).
    Pieza unica, sin repetir; el humo va aparte. El valor de la mascara separa
    los planos (1 = lo mas lejano, se tinta del color claro del horizonte; los
    planos cercanos bajan de valor y salen mas oscuros), y la hoja llega hasta
    por debajo del suelo del jugador para que en el claro no asome cielo."""
    w, h = 4400, 1000
    rnd = random.Random(88)
    horizonte = 560
    xs = np.arange(w)
    capas_valor = []   # (mascara, valor) de lejos a cerca

    def plano(base, amp, sem, suave, hondo, valor):
        lz = Lienzo(w, h)
        perfil = base - (ruido_valor(w, 1, suave, 3, 800 + sem, False).ravel() - 0.5) * 2 * amp
        perfil += hondo * np.exp(-((xs - w * 0.42) / (w * 0.24)) ** 2)   # la hondonada del valle
        for cx in range(w):
            lz.draw.rectangle((cx * SS, perfil[cx] * SS, (cx + 1) * SS, h * SS), fill=255)
        return lz, perfil

    # 1. sierras del fondo
    lz, _ = plano(horizonte - 60, 80, 1, 900, 40, 0.95)
    capas_valor.append((lz.final(), 0.95))
    # 2. la ciudad en la hondonada, sobre una loma baja
    lz, perfil = plano(horizonte + 10, 30, 2, 700, 80, 0.93)
    cx0 = w * 0.40
    suelo_c = float(perfil[int(cx0)]) + 6
    x = cx0 - 360
    while x < cx0 + 380:
        bw = rnd.uniform(14, 34)
        bh = rnd.uniform(16, 44)
        top = suelo_c - bh
        lz.draw.rectangle((x * SS, top * SS, (x + bw) * SS, (suelo_c + 30) * SS), fill=255)
        lz.draw.polygon([(x * SS, top * SS), ((x + bw / 2) * SS, (top - bw * 0.5) * SS), ((x + bw) * SS, top * SS)], fill=255)
        x += bw * rnd.uniform(0.7, 1.05)

    def torre(x, ancho, alto, aguja):
        top = suelo_c - alto
        lz.draw.rectangle(((x - ancho / 2) * SS, top * SS, (x + ancho / 2) * SS, suelo_c * SS), fill=255)
        lz.draw.polygon([((x - ancho / 2 - 2) * SS, top * SS), (x * SS, (top - aguja) * SS),
                         ((x + ancho / 2 + 2) * SS, top * SS)], fill=255)
    cat = cx0 + 40
    lz.draw.rectangle(((cat - 60) * SS, (suelo_c - 70) * SS, (cat + 60) * SS, suelo_c * SS), fill=255)
    torre(cat - 48, 22, 150, 40)
    torre(cat + 48, 22, 150, 40)
    torre(cat, 30, 105, 26)
    for xt in (cx0 - 250, cx0 - 150, cx0 + 190, cx0 + 300):
        torre(xt, rnd.uniform(10, 16), rnd.uniform(70, 110), rnd.uniform(18, 34))
    capas_valor.append((lz.final(), 0.87))
    # 3. lomas intermedias con arbolitos
    lz, perfil = plano(horizonte + 150, 55, 3, 800, 60, 0.78)
    for _ in range(70):
        x = rnd.uniform(0, w)
        if abs(x - cx0) < 380 and rnd.random() < 0.8:
            continue
        ramas = generar_arbol(x, float(perfil[int(x)]) + 4, rnd.uniform(50, 110), 3.5, ESTILOS['redondo'], rnd)
        pintar_ramas(lz.draw, ramas, 255)
    capas_valor.append((lz.final(), 0.66))
    # 4. la ladera cercana, donde acaba el claro (baja hacia el valle)
    lz, perfil = plano(horizonte + 320, 40, 4, 600, -10, 0.6)
    for _ in range(26):
        x = rnd.uniform(0, w)
        ramas = generar_arbol(x, float(perfil[int(x)]) + 6, rnd.uniform(120, 240), 6, ESTILOS['alto'], rnd)
        pintar_ramas(lz.draw, ramas, 255)
    capas_valor.append((lz.final(), 0.45))

    alfa = np.zeros((h, w), np.float32)
    valor = np.ones((h, w), np.float32)
    for a, v in capas_valor:
        valor = valor * (1 - a) + v * a
        alfa = alfa * (1 - a) + a
    valor = np.where(alfa > 0.01, valor, 1.0)
    # el borde derecho se funde: ahi ya empieza el bosque y no debe verse el corte
    xs_f = np.arange(w, dtype=np.float32)[None, :]
    alfa *= np.clip((w - xs_f) / 900.0, 0, 1) ** 1.5
    guardar('valle', alfa, valor, escala=1.0, y_arriba=SUELO - 380 - horizonte, ciudad_x=cx0, ciudad_y=suelo_c)


def humo() -> None:
    """Columna de humo de chimenea lejana: sale fina y recta y, al subir, el
    viento la tumba hacia la derecha y la deshilacha. El shader la hace
    ondular y respirar muy despacio."""
    w, h = 420, 900
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    t = 1 - yy / h                 # 0 en el pie (abajo), 1 arriba
    centro = 60 + (t ** 1.7) * (w - 150)
    ancho = 6 + 70 * t ** 1.2
    n = ruido_valor(w, h, 45, 4, 91, False)
    a = np.exp(-((xx - centro - (n - 0.5) * 40 * t) / ancho) ** 2 * 1.8)
    a *= np.clip(t * 12, 0, 1) * np.clip((1 - t) * 1.6, 0, 1) ** 1.3
    a *= 0.35 + 0.65 * ruido_valor(w, h, 70, 4, 92, False)
    a = np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3)),
                   np.float32) / 255.0
    guardar('humo', a, None, escala=1.0)


def luna() -> None:
    w = 320
    yy, xx = np.mgrid[0:w, 0:w].astype(np.float32)
    r = np.sqrt((xx - w / 2) ** 2 + (yy - w / 2) ** 2)
    disco = np.clip((w * 0.3 - r) / 2.0, 0, 1)
    halo = np.exp(-(np.maximum(r - w * 0.3, 0) / (w * 0.12)) ** 2) * 0.35
    mares = ruido_valor(w, w, 90, 4, 93, False)
    valor = np.where(disco > 0, 0.86 + 0.14 * mares, 1.0)
    alfa = np.clip(disco + halo, 0, 1)
    guardar('luna', alfa, valor, escala=1.0)


def pajaro() -> None:
    """Cuatro poses de aleteo en tira (128x64 cada una)."""
    fw, fh, n = 128, 64, 4
    lz = Lienzo(fw * n, fh)
    for i in range(n):
        cx, cy = fw * i + fw / 2, fh / 2 + 6
        ala = math.sin(i / n * math.tau) * 22          # altura de la punta
        cuerpo = [(cx - 16, cy), (cx + 18, cy - 2), (cx + 24, cy - 5), (cx + 20, cy + 1), (cx - 10, cy + 5)]
        lz.draw.polygon([(x * SS, y * SS) for x, y in cuerpo], fill=255)
        for lado in (-1, 1):
            punta = (cx + lado * 52, cy - ala - 4)
            medio = (cx + lado * 26, cy - ala * 0.6 - 8)
            pts = [(cx - 6, cy - 1), medio, punta, (cx + lado * 30, cy - ala * 0.3 + 1), (cx + 6, cy + 1)]
            lz.draw.polygon([(x * SS, y * SS) for x, y in pts], fill=255)
    guardar('pajaro', lz.final(), None, escala=1.0, fotogramas=n)


def hoja() -> None:
    w = 48
    lz = Lienzo(w, w)
    pts = []
    for k in range(24):
        a = k / 24 * math.tau
        r = 18 * (0.55 + 0.45 * abs(math.sin(a * 2.5))) * (1.0 if math.sin(a) < 0.3 else 0.8)
        pts.append(((w / 2 + math.cos(a) * r * 0.6) * SS, (w / 2 + math.sin(a) * r) * SS))
    lz.draw.polygon(pts, fill=255)
    lz.draw.line([(w / 2 * SS, 6 * SS), (w / 2 * SS, (w - 4) * SS)], fill=150, width=SS)
    alfa = lz.final()
    valor = np.asarray(lz.img.resize((w, w), Image.LANCZOS), np.float32) / 255.0
    valor = np.where(alfa > 0.02, np.clip(valor / np.maximum(alfa, 0.02), 0.6, 1.0), 1.0)
    guardar('hoja', alfa, valor, escala=1.0)


def gargola() -> None:
    """Roble grueso con una gargola de piedra que asoma del tronco hacia la
    izquierda (de donde viene Magnus). Los ojos van aparte: dos brillos que lo
    siguen; aqui solo se dejan las cuencas."""
    w, h = 1600, 1500
    rnd = random.Random(99)
    lz = Lienzo(w, h)
    base = h - 30
    cx = w * 0.42
    est = EstiloArbol(niveles=5, angulo=1.0, curvatura=0.09, tronco_frac=0.46, subir=0.35, ramas=(2, 3))
    ramas = generar_arbol(cx, base, 1400, 135, est, rnd)
    pintar_ramas(lz.draw, ramas)
    raices(lz, cx, base, 135, rnd, 10 ** 6)
    # donde esta el tronco a la altura de la gargola: el segmento de la guia
    gy = base - 560
    guia = [r for r in ramas if r.w0 > 80]
    seg = min(guia, key=lambda r: abs((r.y0 + r.y1) / 2 - gy))
    gx = (seg.x0 + seg.x1) / 2 - seg.w0 * 0.35
    cab = [(gx + 40, gy - 60), (gx - 10, gy - 75), (gx - 55, gy - 55), (gx - 95, gy - 30), (gx - 120, gy - 5),
           (gx - 110, gy + 12), (gx - 80, gy + 20), (gx - 95, gy + 40), (gx - 60, gy + 45), (gx - 30, gy + 60),
           (gx + 40, gy + 70)]
    lz.draw.polygon([(x * SS, y * SS) for x, y in cab], fill=255)
    for dx in (0, 34):
        lz.draw.polygon([((gx - 20 + dx) * SS, (gy - 66) * SS), ((gx - 44 + dx) * SS, (gy - 122) * SS),
                         ((gx - 4 + dx) * SS, (gy - 70) * SS)], fill=255)
    ojos = [(gx - 64, gy - 28), (gx - 32, gy - 34)]
    for (ox, oy) in ojos:
        lz.draw.ellipse(((ox - 7) * SS, (oy - 5) * SS, (ox + 7) * SS, (oy + 5) * SS), fill=40)
    alfa = lz.final()
    valor = 0.84 + 0.16 * ruido_valor(w, h, 40, 4, 98, False)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    piedra = np.exp(-(((xx - (gx - 40)) / 110) ** 2 + ((yy - gy) / 90) ** 2))
    valor = np.clip(valor + 0.25 * piedra, 0, 1)
    guardar('gargola', alfa, valor, escala=1.0, y_arriba=SUELO - base, origen_x=cx,
            ojos=[[x - cx, y - base] for x, y in ojos])


def estructura() -> None:
    """Los artilugios de Dominus que asoman cerca de la casa: una torre de tubos
    como un arbol mecanico (el quinto panel de la referencia)."""
    w, h = 420, 1150
    rnd = random.Random(111)
    lz = Lienzo(w, h)
    base = h - 10
    cx = w / 2
    # tubos verticales de alturas distintas con remates
    for i in range(9):
        x = cx + (i - 4) * 26 + rnd.uniform(-5, 5)
        top = base - rnd.uniform(420, 1080)
        g = rnd.uniform(4, 9)
        lz.draw.rectangle(((x - g / 2) * SS, top * SS, (x + g / 2) * SS, base * SS), fill=255)
        r = rnd.uniform(6, 13)
        if rnd.random() < 0.6:
            lz.draw.ellipse(((x - r) * SS, (top - r) * SS, (x + r) * SS, (top + r) * SS), fill=255)
        else:
            lz.draw.polygon([((x - r) * SS, top * SS), (x * SS, (top - r * 2.5) * SS), ((x + r) * SS, top * SS)], fill=255)
    # travesanos y un par de ramitas de alambre
    for _ in range(7):
        y = base - rnd.uniform(200, 900)
        x0 = cx + rnd.uniform(-110, -20)
        x1 = cx + rnd.uniform(20, 110)
        lz.draw.line([(x0 * SS, y * SS), (x1 * SS, (y + rnd.uniform(-8, 8)) * SS)], fill=255, width=3 * SS)
    lz.draw.polygon([((cx - 60) * SS, base * SS), ((cx - 40) * SS, (base - 90) * SS), ((cx + 40) * SS, (base - 90) * SS),
                     ((cx + 60) * SS, base * SS)], fill=255)
    guardar('estructura', lz.final(), None, escala=1.0, y_arriba=SUELO - base)


def manchas_cielo() -> None:
    """Textura de acuarela para el cielo (se repite en los dos ejes)."""
    w = 1024
    n = ruido_valor(w, w, 260, 5, 121)
    # periodica tambien en vertical: mezcla con su propia vuelta
    n = 0.5 * n + 0.5 * np.roll(n[::-1], w // 2, axis=0)
    n = (n - n.min()) / (n.max() - n.min())
    os.makedirs(SALIDA, exist_ok=True)
    Image.fromarray((n * 255).astype(np.uint8), 'L').save(os.path.join(SALIDA, 'cielo_manchas.png'))
    meta['cielo_manchas'] = dict(ancho=w, alto=w)
    print('  cielo_manchas')


TODAS = {
    'capa0': lambda: capa_arboles('capa0'), 'capa1': lambda: capa_arboles('capa1'),
    'capa2': lambda: capa_arboles('capa2'), 'capa3': lambda: capa_arboles('capa3'),
    'suelo': suelo, 'suelo_frente': suelo_frente, 'primer_plano': primer_plano,
    'valle': valle, 'humo': humo, 'luna': luna, 'pajaro': pajaro, 'hoja': hoja,
    'gargola': gargola, 'estructura': estructura, 'cielo_manchas': manchas_cielo,
}


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    ruta_meta = os.path.join(SALIDA, 'bosque_meta.json')
    if os.path.exists(ruta_meta):
        meta.update(json.load(open(ruta_meta, encoding='utf-8')))
    for nombre in (args or TODAS):
        print(nombre)
        TODAS[nombre]()
    meta['_nota'] = 'Generado por tools/mundo/bosque.py. y_arriba = y del mundo del borde superior; escala = resolucion de dibujo.'
    with open(ruta_meta, 'w', encoding='utf-8') as f:
        json.dump(meta, f, indent=1, ensure_ascii=False, default=float)


if __name__ == '__main__':
    main()

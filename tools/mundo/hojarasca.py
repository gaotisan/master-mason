"""Hojarasca: las hojas de la escena en que Magnus cae del cielo (el cuento empieza
con el anciano levantandose y sacudiendose "la hojarasca que se habia quedado
adherida a sus ropas", en un atardecer de otono).

La forma y la paleta vienen de la imagen de titulo de Midjourney
(Descargas: gaotisan_extend_--ar_9151_--v_7_c23dc988-....png):
hojas lanceoladas, estrechas y en punta, doradas y ambar a contraluz. Recortarlas
de la imagen no sale limpio (detras hay niebla brillante), asi que se pintan por
codigo con esa forma y esa luz, a SS veces el tamano final.

Salida en assets/world/hojarasca/:
  hojas.png       atlas COLS x FILAS de hojas sueltas, punta arriba y rabillo
                  abajo en el centro de cada casilla. Son las hojas de verdad
                  del juego (scripts/game/hojas_voladoras.gd): las apiladas a la
                  altura de Magnus y las que vuelan.
  lecho.png       el suelo pintado, lejos y cerca (2912 x ALTO_LECHO, empieza en
                  Y_LECHO). En la franja por donde anda Magnus queda oscuro: ahi
                  la hojarasca son hojas de verdad, y al apartarlas asoma tierra
                  en sombra, no mas dibujo de hojas que no se mueven.
  follaje_izq.png / follaje_der.png  (solo con el argumento `follaje`) ramas con
                  hojas para las esquinas de arriba; fuera de la escena de momento.
  mota.png        punto blando para el polvo y las motas del haz.

    python tools/mundo/hojarasca.py
"""
from __future__ import annotations

import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__))))
SALIDA = os.path.join(RAIZ, "assets", "world", "hojarasca")

SS = 4                  # sobremuestreo de cada hoja
CELDA = (64, 128)       # casilla del atlas (ancho, alto): hoja de ~118 px de largo
COLS, FILAS = 8, 4
W_PANTALLA = 2912
Y_SUELO = 1200          # linea de suelo de Magnus (pies en 1192)
Y_LECHO = 1150          # el lecho empieza aqui (puntas de hojas que asoman)
ALTO_LECHO = 1632 - Y_LECHO
X_CAIDA = 1456          # donde cae Magnus: ahi esta el monton y el haz de luz
BRUMA = (0.42, 0.28, 0.16)  # color de la bruma del fondo (la del haz, apagada)

# Paleta sacada de la imagen (RGB 0..1): del oro claro al pardo.
PALETA = np.array([
    (0.98, 0.78, 0.36),  # oro claro, a contraluz
    (0.93, 0.64, 0.22),  # oro
    (0.84, 0.52, 0.16),  # ambar
    (0.72, 0.42, 0.13),  # ocre
    (0.60, 0.31, 0.10),  # oxido
    (0.44, 0.24, 0.09),  # pardo
], np.float32)


def _ruido(rng, w, h, escala):
    """Ruido suave 0..1 de una rejilla pequena ampliada (bicubico)."""
    gw, gh = max(2, int(w / escala) + 2), max(2, int(h / escala) + 2)
    g = (rng.random((gh, gw)) * 255).astype(np.uint8)
    return np.asarray(Image.fromarray(g).resize((w, h), Image.BICUBIC), np.float32) / 255.0


def pintar_hoja(rng, color, largo=118, ancho_rel=None, curva=None, forma=None):
    """Una hoja RGBA de CELDA, punta arriba, rabillo abajo en el centro.

    forma: 'lanceolada' (la de la imagen), 'eliptica' o 'sauce' (muy estrecha).
    """
    forma = forma or rng.choice(["lanceolada"] * 5 + ["eliptica"] * 2 + ["sauce"] * 2)
    cw, ch = CELDA[0] * SS, CELDA[1] * SS
    L = largo * SS
    if ancho_rel is None:
        ancho_rel = {"lanceolada": rng.uniform(0.095, 0.125),
                     "eliptica": rng.uniform(0.13, 0.16),
                     "sauce": rng.uniform(0.065, 0.08)}[forma]
    W = L * ancho_rel                       # semiancho maximo
    curva = rng.uniform(-1, 1) if curva is None else curva
    asim = rng.uniform(0.85, 1.12)          # un lado algo mas ancho que el otro
    pico = {"lanceolada": 0.30, "eliptica": 0.42, "sauce": 0.26}[forma]
    rabillo = L * rng.uniform(0.05, 0.08)

    yy, xx = np.mgrid[0:ch, 0:cw].astype(np.float32)
    base_y = ch - (ch - L - rabillo) / 2 - rabillo   # donde nace el limbo
    v = (base_y - yy) / L                            # 0 base .. 1 punta
    # El nervio se arquea: casi ninguna hoja de la imagen es recta.
    cx = cw / 2 + curva * L * 0.15 * np.clip(v, 0, 1) ** 1.6
    dx = xx - cx
    # Perfil del limbo: ancho maximo en `pico`, base redondeada, punta afilada.
    vc = np.clip(v, 0.0, 1.0)
    sube = np.sin(0.5 * np.pi * np.clip(vc / pico, 0, 1)) ** 0.6
    # Punta acuminada: el ancho cae en curva concava hasta un pico largo.
    baja = np.sin(0.5 * np.pi * np.clip((1 - vc) / (1 - pico), 0, 1)) ** 1.7
    perfil = np.where(vc < pico, sube, baja)
    # Borde algo irregular (mordiscos, secado) y mas en hojas viejas.
    irregular = 1 + 0.035 * np.sin(vc * rng.uniform(40, 70) + rng.uniform(0, 6)) \
        + 0.05 * (_ruido(rng, cw, ch, 22 * SS) - 0.5)
    hw = W * perfil * irregular * np.where(dx < 0, 1.0, asim)
    s = dx / np.maximum(hw, 1e-3)                    # -1..1 de borde a borde
    dentro = (v > 0) & (v < 1) & (np.abs(s) < 1)

    # Rabillo: un trazo fino que sigue la curva hacia abajo.
    vr = (base_y - yy) / rabillo
    rab = (vr <= 0.02) & (vr > -1) & (np.abs(xx - cw / 2) < SS * 1.4 * (1 + 0.3 * vr))

    # --- Color ---
    c = np.array(color, np.float32)
    lado_luz = rng.choice([-1, 1])
    # Plegado por el nervio: una mitad recibe mas luz que la otra.
    # Plegado por el nervio con arista marcada: cada mitad casi plana, como una
    # faceta. Asi la hoja habla el mismo idioma que Magnus (facetado) y no el
    # de una foto; con el pliegue suave de antes chocaban los dos estilos.
    plegado = 0.84 + 0.2 * np.tanh(14.0 * s * lado_luz)
    # Abombado: el centro de cada mitad mas claro, el borde algo mas oscuro.
    abombado = 1.0 - 0.12 * np.abs(s) ** 2.5
    # Contraluz: algunas hojas tienen el borde encendido, como en la imagen.
    contraluz = rng.random() < 0.45
    borde_luz = (1 + 0.28 * np.clip((np.abs(s) - 0.72) / 0.28, 0, 1) ** 2) if contraluz else 1.0
    # A lo largo: la punta y la base algo mas apagadas.
    largo_f = 0.9 + 0.12 * np.sin(np.pi * vc)
    luz = plegado * abombado * borde_luz * largo_f
    # Nervio central y secundarios (oblicuos hacia la punta).
    nervio = np.exp(-(dx / (SS * 0.9 + 0.04 * W)) ** 2) * (vc < 0.97)
    n_sec = rng.uniform(7, 11)
    fase = (vc * n_sec - np.abs(s) * n_sec * 0.38) % 1.0
    sec = np.exp(-((fase - 0.5) / 0.045) ** 2) * (np.abs(s) < 0.92) * (np.abs(s) > 0.06)
    nervio_claro = rng.random() < 0.6
    luz = luz * (1 + (0.18 if nervio_claro else -0.2) * nervio) * (1 - 0.05 * sec)
    # Moteado y manchas de hoja vieja.
    mot = 0.95 + 0.1 * _ruido(rng, cw, ch, 14 * SS)
    rgb = c[None, None, :] * (luz * mot)[..., None]
    # Bordes secos: hacia pardo.
    seco = np.clip((np.abs(s) - rng.uniform(0.7, 0.92)) / 0.15, 0, 1)[..., None] * rng.uniform(0.2, 0.7)
    rgb = rgb * (1 - seco) + PALETA[5][None, None, :] * 0.8 * seco
    for _ in range(rng.integers(0, 4)):
        my, mx = rng.uniform(0.15, 0.85), rng.uniform(-0.6, 0.6)
        r = rng.uniform(0.04, 0.09)
        d = np.sqrt(((vc - my) / r) ** 2 + ((s - mx) / (r * L / W / 2)) ** 2)
        m = np.clip(1 - d, 0, 1)[..., None] ** 0.7 * rng.uniform(0.3, 0.6)
        rgb = rgb * (1 - m) + PALETA[5][None, None, :] * 0.6 * m
    rgb = np.where(rab[..., None] & ~dentro[..., None], PALETA[4][None, None, :] * 0.8, rgb)
    alfa = (dentro | rab).astype(np.float32)
    img = np.dstack([np.clip(rgb, 0, 1), alfa])
    # Premultiplicado para reducir sin halos oscuros en el borde.
    img[..., :3] *= img[..., 3:4]
    peq = Image.fromarray((img * 255).astype(np.uint8), "RGBA").resize(CELDA, Image.LANCZOS)
    a = np.asarray(peq, np.float32) / 255.0
    a[..., :3] = np.where(a[..., 3:4] > 1e-3, a[..., :3] / np.maximum(a[..., 3:4], 1e-3), 0)
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "RGBA")


def color_aleatorio(rng):
    """Mezcla dos tonos vecinos de la paleta, sesgado hacia el oro."""
    i = min(int(rng.beta(1.6, 2.6) * (len(PALETA) - 1)), len(PALETA) - 2)
    t = rng.random()
    return PALETA[i] * (1 - t) + PALETA[i + 1] * t


def generar_atlas(rng):
    atlas = Image.new("RGBA", (CELDA[0] * COLS, CELDA[1] * FILAS))
    hojas = []
    for i in range(COLS * FILAS):
        h = pintar_hoja(rng, color_aleatorio(rng), largo=rng.uniform(104, 120))
        hojas.append(h)
        atlas.paste(h, ((i % COLS) * CELDA[0], (i // COLS) * CELDA[1]))
    return atlas, hojas


def _pegar_rapido(lienzo: Image.Image, hoja: Image.Image, x, y):
    """alpha_composite con recorte, sin crear un lienzo entero por hoja."""
    x0, y0 = int(x), int(y)
    sx0, sy0 = max(0, -x0), max(0, -y0)
    sx1, sy1 = min(hoja.width, lienzo.width - x0), min(hoja.height, lienzo.height - y0)
    if sx1 <= sx0 or sy1 <= sy0:
        return
    trozo = hoja.crop((sx0, sy0, sx1, sy1))
    lienzo.alpha_composite(trozo, (x0 + sx0, y0 + sy0))


def _hoja_puesta(hoja, escala, ang, brillo, aplanar):
    w, h = hoja.size
    hj = hoja.resize((max(2, int(w * escala)), max(2, int(h * escala))), Image.LANCZOS)
    a = np.asarray(hj, np.float32)
    a[..., :3] *= brillo
    hj = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
    hj = hj.rotate(ang, Image.BICUBIC, expand=True)
    if aplanar != 1.0:
        hj = hj.resize((hj.width, max(2, int(hj.height * aplanar))), Image.LANCZOS)
    return hj


def luz_en(x, y):
    """Luz del haz que baja sobre el sitio de la caida (0.25..1.15)."""
    dx = (x - X_CAIDA) / 1050.0
    dy = (y - Y_SUELO) / 520.0
    return 0.28 + 0.87 * math.exp(-(dx * dx + 0.6 * dy * dy) * 1.6)


def altura_monton(x):
    """Cuanto sube el monton de hojas sobre el suelo en x (px)."""
    return 30.0 * math.exp(-((x - X_CAIDA) / 260.0) ** 2) + 8.0 * math.exp(-((x - X_CAIDA - 520) / 200.0) ** 2) \
        + 6.0 * math.exp(-((x - X_CAIDA + 700) / 240.0) ** 2)


def generar_lecho(rng, hojas):
    """El suelo, de atras (arriba) hacia delante (abajo): cuanto mas abajo, mas
    cerca, mas grandes y mas aplastadas por la perspectiva se ven menos. Las que
    se pintan antes quedan debajo y mas oscuras (oclusion)."""
    lecho = Image.new("RGBA", (W_PANTALLA, ALTO_LECHO))
    # Fondo del suelo: tierra muy oscura que funde con el negro abajo.
    tierra = np.zeros((ALTO_LECHO, W_PANTALLA, 4), np.float32)
    yy = np.arange(ALTO_LECHO, dtype=np.float32)[:, None] + Y_LECHO
    xx = np.arange(W_PANTALLA, dtype=np.float32)[None, :]
    cubre = np.clip((yy - (Y_SUELO - 4)) / 30.0, 0, 1)
    luz = 0.28 + 0.87 * np.exp(-(((xx - X_CAIDA) / 1050.0) ** 2 + 0.6 * ((yy - Y_SUELO) / 520.0) ** 2) * 1.6)
    tierra[..., 0] = 0.20 * luz
    tierra[..., 1] = 0.11 * luz
    tierra[..., 2] = 0.045 * luz
    tierra[..., 3] = cubre
    lecho.alpha_composite(Image.fromarray((np.clip(tierra, 0, 1) * 255).astype(np.uint8), "RGBA"))

    n_capas = 7
    for capa in range(n_capas):
        prof = capa / (n_capas - 1)               # 0 = la de debajo
        n = int(2300 * (0.7 + 0.6 * (1 - prof)))
        for _ in range(n):
            x = rng.uniform(-40, W_PANTALLA + 40)
            # Mas hojas cerca del suelo de Magnus; hacia abajo, menos y mas grandes.
            yr = rng.beta(1.25, 3.2)
            y = Y_SUELO - altura_monton(x) * rng.uniform(0.3, 1.0) * (1 - yr) + yr * (ALTO_LECHO - 30)
            cerca = (y - Y_SUELO) / (1632 - Y_SUELO)
            escala = rng.uniform(0.24, 0.34) * (1 + 0.9 * max(cerca, 0))
            aplanar = 0.45 + 0.25 * rng.random()
            ang = rng.uniform(0, 360)
            brillo = luz_en(x, y) * (0.55 + 0.45 * prof) * rng.uniform(0.85, 1.12) * (1 - 0.55 * max(cerca, 0) ** 1.4)
            hj = _hoja_puesta(hojas[rng.integers(len(hojas))], escala, ang, brillo, aplanar)
            _pegar_rapido(lecho, hj, x - hj.width / 2, y - Y_LECHO - hj.height / 2)
        # Sombra de contacto entre capas: oscurece lo de debajo un poco.
        if capa < n_capas - 1:
            a = np.asarray(lecho, np.float32)
            a[..., :3] *= 0.93
            lecho = Image.fromarray(a.astype(np.uint8), "RGBA")
    # Algunas de pie, asomando por encima del suelo (dan el borde irregular).
    for _ in range(260):
        x = rng.uniform(0, W_PANTALLA)
        y = Y_SUELO - altura_monton(x) * rng.uniform(0.5, 1.0) + rng.uniform(-2, 10)
        hj = _hoja_puesta(hojas[rng.integers(len(hojas))], rng.uniform(0.22, 0.3),
                          rng.choice([-1, 1]) * rng.uniform(45, 85),
                          luz_en(x, y) * rng.uniform(0.8, 1.05), rng.uniform(0.6, 0.9))
        _pegar_rapido(lecho, hj, x - hj.width / 2, y - Y_LECHO - hj.height * 0.75)
    # Funde a negro hacia abajo y en los lados, como la imagen.
    a = np.asarray(lecho, np.float32)
    yy = np.arange(ALTO_LECHO, dtype=np.float32)[:, None]
    xx = np.arange(W_PANTALLA, dtype=np.float32)[None, :]
    viñeta = (1 - 0.75 * np.clip((yy - 180) / (ALTO_LECHO - 180), 0, 1) ** 1.3) \
        * (1 - 0.55 * (np.abs(xx - X_CAIDA) / 1500.0) ** 2)
    # Manchas de sombra (ramas de arriba, huecos del monton): sin ellas el
    # lecho parece una alfombra.
    manchas = 0.62 + 0.5 * _ruido(rng, W_PANTALLA, ALTO_LECHO, 150) ** 1.3
    a[..., :3] *= (viñeta * np.clip(manchas, 0, 1.08))[..., None]
    img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
    # Profundidad de campo: enfocado donde pisa Magnus, cada vez mas borroso
    # hacia delante (abajo). Lejos (el borde de atras) algo blando y con bruma.
    yy = np.arange(ALTO_LECHO, dtype=np.float32) + Y_LECHO
    radio = np.where(yy > Y_SUELO + 40, 6.0 * np.clip((yy - Y_SUELO - 40) / 330.0, 0, 1) ** 1.2,
                     1.2 * np.clip((Y_SUELO - yy) / 40.0, 0, 1))
    img = desenfoque_por_filas(img, radio)
    a = np.asarray(img, np.float32)
    # La franja de Magnus (hojas de verdad encima): tierra en sombra.
    franja = 1 - 0.62 * np.exp(-((yy - (Y_SUELO + 4)) / 20.0) ** 2)
    a[..., :3] *= franja[:, None, None]
    # El borde de atras no corta a regla: se funde con la oscuridad.
    a[..., 3] *= np.clip((yy - Y_LECHO) / 34.0, 0, 1)[:, None] ** 1.5
    bruma = np.clip((Y_SUELO + 10 - yy) / 60.0, 0, 1)[:, None, None] * 0.35
    a[..., :3] = a[..., :3] * (1 - bruma) + np.array(BRUMA, np.float32) * 255 * bruma * (a[..., 3:4] / 255)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def desenfoque_por_filas(img: Image.Image, radio: np.ndarray) -> Image.Image:
    """Desenfoque gaussiano cuyo radio cambia con la fila (radio[y] en px):
    mezcla entre copias desenfocadas a radios fijos. En premultiplicado, para
    que los bordes no se oscurezcan."""
    a = np.asarray(img, np.float32) / 255.0
    pm = a.copy()
    pm[..., :3] *= pm[..., 3:4]
    base = Image.fromarray((pm * 255).astype(np.uint8), "RGBA")
    radios = [0.0, 1.5, 3.0, 4.5, 6.0]
    capas = [pm] + [np.asarray(base.filter(ImageFilter.GaussianBlur(r)), np.float32) / 255.0 for r in radios[1:]]
    out = np.zeros_like(pm)
    for y in range(pm.shape[0]):
        r = float(np.clip(radio[y], 0, radios[-1]))
        i = min(int(np.searchsorted(radios, r, side="right")) - 1, len(radios) - 2)
        t = (r - radios[i]) / (radios[i + 1] - radios[i])
        out[y] = capas[i][y] * (1 - t) + capas[i + 1][y] * t
    out[..., :3] = np.where(out[..., 3:4] > 1e-4, out[..., :3] / np.maximum(out[..., 3:4], 1e-4), 0)
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "RGBA")


def _rama(draw, rng, x, y, ang, largo, grosor, nivel, puntas):
    """Rama recursiva; guarda las puntas y los puntos de las ramitas para las
    hojas. Coordenadas a SS_F veces."""
    pasos = max(3, int(largo / 18))
    px, py = x, y
    for i in range(pasos):
        t = (i + 1) / pasos
        ang += rng.normal(0, 0.10)
        nx, ny = px + math.cos(ang) * largo / pasos, py + math.sin(ang) * largo / pasos
        g = max(1.0, grosor * (1 - 0.6 * t))
        draw.line([(px, py), (nx, ny)], fill=(255, 255, 255, 255), width=int(g))
        if nivel <= 1 or rng.random() < 0.55:
            puntas.append((nx, ny, ang, nivel))
        px, py = nx, ny
    if nivel > 0:
        for _ in range(rng.integers(2, 4)):
            _rama(draw, rng, px - math.cos(ang) * largo * rng.uniform(0, 0.5),
                  py - math.sin(ang) * largo * rng.uniform(0, 0.5),
                  ang + rng.choice([-1, 1]) * rng.uniform(0.35, 0.9),
                  largo * rng.uniform(0.55, 0.75), grosor * 0.6, nivel - 1, puntas)


def generar_follaje(rng, hojas, lado: int):
    """Ramas con hojas desde una esquina de arriba (lado -1 izq, 1 der), lit
    por el haz: mas claras las que se acercan al centro. 1150 x 1000."""
    W, H = 1150, 1000
    ramas = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(ramas)
    puntas = []
    for _ in range(4):
        x0 = rng.uniform(-60, 40)
        y0 = rng.uniform(-80, 420)
        ang = rng.uniform(-0.25, 0.55)
        _rama(d, rng, x0, y0, ang, rng.uniform(380, 640), rng.uniform(10, 16), 3, puntas)
    # Las ramas se ven en silueta, casi negras con un filo calido.
    a = np.asarray(ramas, np.float32)
    a[..., 0], a[..., 1], a[..., 2] = 52, 30, 14
    ramas = Image.fromarray(a.astype(np.uint8), "RGBA")
    follaje = Image.new("RGBA", (W, H))
    follaje.alpha_composite(ramas)
    # Hojas que nacen de las ramitas, alternas, abiertas 35-70 grados respecto a
    # la ramita y algo caidas por su peso. Primero las de detras (mas oscuras):
    # da el fondo del follaje en sombra y las puntas encendidas, como la imagen.
    for capa in range(3):
        for (px, py, ang, nivel) in puntas:
            if nivel > 1 or rng.random() < 0.35:
                continue
            for k in range(rng.integers(1, 3)):
                lado_h = 1 if (k + capa) % 2 else -1
                dir_h = ang + lado_h * math.radians(rng.uniform(35, 70))
                # Caida: se mezcla con "hacia abajo" (pi/2 en pantalla).
                caida = rng.uniform(0.15, 0.4)
                dx, dy = math.cos(dir_h) * (1 - caida), math.sin(dir_h) * (1 - caida) + caida
                dir_h = math.atan2(dy, dx)
                escala = rng.uniform(0.42, 0.62)
                largo = 118 * escala
                hx = px + math.cos(dir_h) * largo * 0.5
                hy = py + math.sin(dir_h) * largo * 0.5
                # Hacia el centro de la pantalla (x alta en el lienzo) y abajo, mas luz.
                luz = 0.18 + 1.0 * min(max(hx / W, 0.0), 1.0) ** 1.4 * (0.6 + 0.4 * min(1.0, max(hy / H, 0.0) + 0.3))
                luz *= (0.45 + 0.3 * capa) * rng.uniform(0.8, 1.2)
                hj = _hoja_puesta(hojas[rng.integers(len(hojas))], escala,
                                  -90 - math.degrees(dir_h), luz, rng.uniform(0.7, 1.0))
                _pegar_rapido(follaje, hj, hx - hj.width / 2, hy - hj.height / 2)
    # Se apaga hacia la esquina (lejos del haz) y por los bordes del lienzo.
    a = np.asarray(follaje, np.float32)
    yy = np.arange(H, dtype=np.float32)[:, None] / H
    xx = np.arange(W, dtype=np.float32)[None, :] / W
    a[..., 3] *= np.clip((1 - xx) / 0.12, 0, 1) ** 0.8 * np.clip((1 - yy) / 0.35, 0, 1) ** 1.5
    img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
    return img if lado < 0 else img.transpose(Image.FLIP_LEFT_RIGHT)


def main():
    os.makedirs(SALIDA, exist_ok=True)
    rng = np.random.default_rng(1851)
    atlas, hojas = generar_atlas(rng)
    atlas.save(os.path.join(SALIDA, "hojas.png"))
    print("hojas.png", atlas.size)
    generar_lecho(rng, hojas).save(os.path.join(SALIDA, "lecho.png"))
    print("lecho.png  y0 =", Y_LECHO)
    # Las ramas de las esquinas se quitaron de la escena (no gustaron, aunque la
    # forma del arbol si); se pueden sacar con `python hojarasca.py follaje`.
    if "follaje" in sys.argv[1:]:
        generar_follaje(rng, hojas, -1).save(os.path.join(SALIDA, "follaje_izq.png"))
        generar_follaje(np.random.default_rng(77), hojas, 1).save(os.path.join(SALIDA, "follaje_der.png"))
        print("follaje")
    # Mota blanda para el polvo del golpe y las motas del haz (la tinta Godot).
    r = np.hypot(*np.mgrid[-32:32, -32:32].astype(np.float32) + 0.5) / 32
    m = np.clip(1 - r, 0, 1) ** 2.2
    Image.fromarray((np.dstack([np.ones_like(m)] * 3 + [m]) * 255).astype(np.uint8), "RGBA") \
        .save(os.path.join(SALIDA, "mota.png"))


if __name__ == "__main__":
    main()

"""Prueba de estilo: una pantalla del bosque compuesta como la vera Godot, para
decidir colores y densidades antes de generar las hojas de verdad."""
import random
import sys

import numpy as np
from PIL import Image, ImageFilter

from pincel import (EstiloArbol, Lienzo, componer, generar_arbol, grano, hex_a_rgb,
                    perfil_colinas, pintar_hierba, pintar_planta_flor, pintar_ramas,
                    ruido_valor, tintar, SS)

W, H = 2912, 1632
SUELO = 1200
salida = sys.argv[1] if len(sys.argv) > 1 else 'prueba.png'
hora = sys.argv[2] if len(sys.argv) > 2 else 'atardecer'

PALETAS = {
    # cielo arriba, horizonte, capas de lejos a cerca, niebla
    'atardecer': dict(cielo=('#5b6f95', '#e9b89a'), capas=['#c9cfe0', '#9aa6c4', '#6f7ea4', '#3f4a6c', '#1c2035'],
                      niebla='#f0c9ae', suelo='#15171f', brillo='#ffb27a'),
    'noche': dict(cielo=('#16213d', '#4a6a9a'), capas=['#6e86b0', '#50668f', '#384b71', '#232f4c', '#0e1322'],
                  niebla='#7e9ccc', suelo='#07090f', brillo='#9fd0ff'),
}
p = PALETAS[hora]

# Cielo: degradado vertical + manchas de acuarela
y = np.linspace(0, 1, H, dtype=np.float32)[:, None]
arriba, horiz = np.array(hex_a_rgb(p['cielo'][0])), np.array(hex_a_rgb(p['cielo'][1]))
t = np.clip(y / 0.78, 0, 1) ** 1.6
fondo = (arriba[None, None, :] * (1 - t[..., None]) + horiz[None, None, :] * t[..., None]) * np.ones((H, W, 1), np.float32)
manchas = ruido_valor(W, H, 500, 5, 3)
fondo *= (0.9 + 0.2 * manchas)[..., None]
# Resplandor del sol bajo, a la derecha del centro
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
d = np.sqrt(((xx - W * 0.55) / 900) ** 2 + ((yy - SUELO * 0.95) / 520) ** 2)
glow = np.exp(-d * d * 1.6)[..., None]
fondo = fondo * (1 - glow * 0.35) + np.array(hex_a_rgb(p['brillo']))[None, None, :] * glow * 0.35

rnd = random.Random(7)

# Capas de arboles, de lejos a cerca
capas = [
    # (alto medio, grosor, separacion, base y, estilo)
    (1250, 26, 330, SUELO - 40, EstiloArbol(niveles=7, copa_estrecha=0.8)),
    (1350, 30, 420, SUELO - 10, EstiloArbol(niveles=7, copa_estrecha=0.9)),
    (1450, 36, 560, SUELO + 10, EstiloArbol(niveles=8, angulo=0.6)),
    (1600, 44, 780, SUELO + 40, EstiloArbol(niveles=8, angulo=0.7, curvatura=0.16)),
]
for i, (alto, grosor, sep, base, estilo) in enumerate(capas):
    lz = Lienzo(W, H)
    x = rnd.uniform(0, sep)
    while x < W + sep:
        a = alto * rnd.uniform(0.75, 1.1)
        ramas = generar_arbol(x, base, a, grosor * rnd.uniform(0.8, 1.2), estilo, rnd)
        pintar_ramas(lz.draw, ramas)
        x += sep * rnd.uniform(0.7, 1.3)
    # suelo de la capa
    perfil = perfil_colinas(W, base + 20, 25 + i * 10, 11 + i)
    for cx in range(0, W, 2):
        lz.draw.rectangle((cx * SS, perfil[cx] * SS, (cx + 2) * SS, H * SS), fill=255)
    alfa = lz.final()
    # textura interior: ruido suave en el valor
    valor = 0.85 + 0.15 * ruido_valor(W, H, 60, 3, 20 + i)
    componer(fondo, tintar(alfa, hex_a_rgb(p['capas'][i]), valor))
    # niebla entre capas: franja horizontal clara hacia el suelo
    niebla = np.clip(1 - np.abs(yy - (SUELO - 120)) / 520, 0, 1) ** 2 * (0.18 + 0.14 * ruido_valor(W, H, 700, 3, 40 + i))
    fondo = fondo * (1 - niebla[..., None]) + np.array(hex_a_rgb(p['niebla']))[None, None, :] * niebla[..., None]

# Primer termino: suelo del jugador con hierba y plantitas
lz = Lienzo(W, H)
perfil = perfil_colinas(W, SUELO + 6, 6, 99, suave=900)
for cx in range(0, W, 2):
    lz.draw.rectangle((cx * SS, perfil[cx] * SS, (cx + 2) * SS, H * SS), fill=255)
for _ in range(260):
    x = rnd.uniform(0, W)
    pintar_hierba(lz.draw, x, perfil[int(x) % W] + 4, rnd.uniform(20, 70), rnd)
puntas = []
for _ in range(9):
    x = rnd.uniform(0, W)
    puntas += pintar_planta_flor(lz.draw, x, perfil[int(x) % W] + 4, rnd.uniform(120, 260), rnd)
alfa = lz.final()
componer(fondo, tintar(alfa, hex_a_rgb(p['suelo'])))

# Capullos encendidos (las luces azules de la referencia), solo de noche
if hora == 'noche':
    luz = np.zeros((H, W), np.float32)
    for (px, py) in puntas:
        if rnd.random() < 0.6:
            d2 = ((xx - px) ** 2 + (yy - py) ** 2)
            luz += np.exp(-d2 / (2 * 14 ** 2)) * 0.9 + np.exp(-d2 / (2 * 5 ** 2))
    fondo = fondo + np.array(hex_a_rgb('#8fd8ff'))[None, None, :] * np.clip(luz, 0, 1.2)[..., None]

# Grano y vineta
fondo *= (1 + 0.035 * grano(W, H, 5))[..., None]
v = np.clip(1 - (((xx - W / 2) / (W * 0.62)) ** 2 + ((yy - H / 2) / (H * 0.75)) ** 2), 0, 1) ** 0.5
fondo *= (0.55 + 0.45 * v)[..., None]

Image.fromarray((np.clip(fondo, 0, 1) * 255).astype(np.uint8), 'RGB').save(salida)
print('ok', salida)

"""Referencias 1920x1080 para los VIDEOS PUENTE entre el peregrino de perfil y el
de frente/espaldas (Flow, fotogramas a video; prompt_puente_perfil_frontal.txt).

Por que (2026-10-16): en la boca del camino de la hojarasca (caida_hojarasca.gd:
_entrar_al_camino, _al_perfil) se pasa de la toma de perfil a la frontal y al
reves cortando entre fotogramas de videos distintos, y no casan (otra tunica,
otra capucha, el baculo en otro sitio). Con un video que empiece en el sprite de
un lado y acabe en el del otro, los dos extremos casan por construccion.

Seis videos, cada uno con inicio y fin (los dos con el baculo igual):
  1 perfil -> espaldas        (la ida: entra en el camino)
  2 espaldas -> perfil        (la vuelta, de espaldas en la boca)
  3 frente -> perfil          (la vuelta, llegando de frente a la boca)
en dos modos: _mano (baculo en la mano) y _guardado (a la espalda, en la correa).

Fuentes = lo que pinta el juego en ese momento:
  perfil mano      baston_ref_en_mano_1080.png  (el reposo con el baculo en la mano)
  perfil guardado  baston_ref_guardado_1080.png (el reposo con el baculo a la espalda)
  espaldas mano    peregrino_secuencia_frontal reposo_espalda_cb_000
  frente mano      peregrino_secuencia_frontal reposo_frente_cb_000
  espaldas guard.  peregrino_guardar_baston_espalda_a, ultimo (= la escena con la capa)
  frente guardado  peregrino_guardar_baston_frente, ultimo
Escala: los masters del perfil 1:1 (capucha-pies 628) y los del frontal a 0,98
(salida_escala de la hojarasca, medida para que casen en el juego). Pies en la
fila 1040. En x: el centro de la casilla del perfil en 960 (se busca en las de
1080 casando la silueta del bajo de la tunica con peregrino_respirando c_01) y el
frontal 4 px por delante (salida_dx). Croma #24D732, sin bola en la garra (la
pone el juego).

  python referencias_puente_perfil_frontal.py [carpeta; por defecto esta y la de Descargas]"""
import glob
import os
import sys

import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
ANIM = os.path.dirname(AQUI)
VERDE = (36, 215, 50, 255)
DESCARGAS = os.path.join(os.path.expanduser('~'), 'Downloads', 'referencias_puente_perfil_frontal')
SALIDAS = [sys.argv[1]] if len(sys.argv) > 1 else [AQUI, DESCARGAS]
PIE_Y = 1040
CENTRO_X = 960
ESCALA_FRONTAL = 0.98
DX_FRONTAL = 4


def alfa_de_croma(im):
    """Alfa de una referencia sobre verde (1 = personaje)."""
    a = np.asarray(im.convert('RGB')).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return ~((g > r + 60) & (g > b + 60))


def perfil(nombre):
    """La referencia de perfil de 1080, movida para que el centro de su casilla
    quede en CENTRO_X y la planta en PIE_Y."""
    ref = Image.open(os.path.join(AQUI, nombre)).convert('RGBA')
    m = alfa_de_croma(ref)
    rep = Image.open(os.path.join(ANIM, 'peregrino_respirando', '04_limpios', 'c_01.png')).convert('RGBA')
    mr = np.asarray(rep)[..., 3] > 128
    pie_r = np.where(mr.any(1))[0].max()
    pie = np.where(m.any(1))[0].max()
    # el bajo de la tunica (sin baculo: el palo es fino, pesa poco) de 420 a 560 px
    # por encima de la planta
    tr = mr[pie_r - 160:pie_r - 20]
    t = m[pie - 160:pie - 20]
    mejor, dx_mejor = -1, 0
    for dx in range(0, 1920 - rep.width):
        v = (t[:, dx:dx + rep.width] & tr).sum() - (t[:, dx:dx + rep.width] ^ tr).sum()
        if v > mejor:
            mejor, dx_mejor = v, dx
    centro = dx_mejor + rep.width / 2
    sale = Image.new('RGBA', (1920, 1080), VERDE)
    personaje = ref.copy()
    personaje.putalpha(Image.fromarray((m * 255).astype(np.uint8)))
    sale.alpha_composite(personaje, (round(CENTRO_X - centro), PIE_Y - pie))
    return sale


def frontal(ruta):
    """Un master del frontal (casilla centrada en el eje) a ESCALA_FRONTAL, con la
    planta en PIE_Y y el centro de la casilla DX_FRONTAL por delante."""
    im = Image.open(ruta).convert('RGBA')
    pie = np.where((np.asarray(im)[..., 3] > 128).any(1))[0].max()
    w, h = round(im.width * ESCALA_FRONTAL), round(im.height * ESCALA_FRONTAL)
    im = im.resize((w, h), Image.LANCZOS)
    sale = Image.new('RGBA', (1920, 1080), VERDE)
    sale.alpha_composite(im, (round(CENTRO_X + DX_FRONTAL - w / 2), round(PIE_Y - pie * ESCALA_FRONTAL)))
    return sale


def ultimo(job):
    return sorted(glob.glob(os.path.join(ANIM, job, '04_limpios', '*.png')))[-1]


def guardar(im, nombre):
    for carpeta in SALIDAS:
        os.makedirs(carpeta, exist_ok=True)
        im.convert('RGB').save(os.path.join(carpeta, nombre))
    print(nombre)


VISTAS = {
    'mano': {
        'perfil': lambda: perfil('baston_ref_en_mano_1080.png'),
        'espaldas': lambda: frontal(os.path.join(ANIM, 'peregrino_secuencia_frontal', '04_limpios', 'reposo_espalda_cb_000.png')),
        'frente': lambda: frontal(os.path.join(ANIM, 'peregrino_secuencia_frontal', '04_limpios', 'reposo_frente_cb_000.png')),
    },
    'guardado': {
        'perfil': lambda: perfil('baston_ref_guardado_1080.png'),
        'espaldas': lambda: frontal(ultimo('peregrino_guardar_baston_espalda_a')),
        'frente': lambda: frontal(ultimo('peregrino_guardar_baston_frente')),
    },
}

for modo, vistas in VISTAS.items():
    v = {k: f() for k, f in vistas.items()}
    for n, (a, b) in enumerate([('perfil', 'espaldas'), ('espaldas', 'perfil'), ('frente', 'perfil')], 1):
        guardar(v[a], 'puente%d_%s_a_%s_%s_inicio.png' % (n, a, b, modo))
        guardar(v[b], 'puente%d_%s_a_%s_%s_fin.png' % (n, a, b, modo))

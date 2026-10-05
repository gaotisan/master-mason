# Quita el croma verde de las fuentes de Magnus/Iram y deja referencias limpias para --oref de Midjourney.
import numpy as np
from PIL import Image
from pathlib import Path

FUENTES = Path(__file__).resolve().parents[2] / "anim" / "_fuentes"
SALIDA = Path(__file__).resolve().parent
FONDO = (232, 228, 220)  # gris calido neutro

def sin_croma(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    verde = g - np.maximum(r, b)
    alfa = np.clip(1 - (verde - 25) / 50, 0, 1)
    a[..., 1] = np.minimum(g, np.maximum(r, b) + 8)  # quitar el verde que salpica los bordes
    return a, alfa

def figuras(alfa, min_ancho=60):
    cols = (alfa > 0.5).sum(0) > 4
    tramos, ini = [], None
    for x, v in enumerate(list(cols) + [False]):
        if v and ini is None: ini = x
        if not v and ini is not None:
            if x - ini >= min_ancho: tramos.append((ini, x))
            ini = None
    return tramos

def guardar(a, alfa, x0, x1, nombre, alto=1536, ratio=2/3):
    sub = alfa[:, x0:x1]
    filas = np.where((sub > 0.5).sum(1) > 2)[0]
    y0, y1 = filas[0], filas[-1] + 1
    rgb = a[y0:y1, x0:x1]; al = alfa[y0:y1, x0:x1, None]
    fondo = np.array(FONDO, np.float32)
    comp = rgb * al + fondo * (1 - al)
    fig = Image.fromarray(comp.clip(0, 255).astype(np.uint8))
    h_fig = int(alto * 0.84)
    fig = fig.resize((int(fig.width * h_fig / fig.height), h_fig), Image.LANCZOS)
    lienzo = Image.new("RGB", (int(alto * ratio), alto), FONDO)
    lienzo.paste(fig, ((lienzo.width - fig.width) // 2, int(alto * 0.08)))
    lienzo.save(SALIDA / nombre)
    print(nombre, lienzo.size)

a, al = sin_croma(FUENTES / "giro360.jpeg")
t = figuras(al); print("giro360", t)
for (x0, x1), n in zip(t, ["iram_perfil.png", "iram_tres_cuartos_lado.png", "iram_tres_cuartos.png", "iram_casi_frente.png", "iram_frente.png"]):
    guardar(a, al, max(0, x0 - 10), x1 + 10, n)

a, al = sin_croma(FUENTES / "baston_lamina_poses.png")
t = figuras(al); print("baston", t)
for (x0, x1), n in zip(t, ["iram_baston_pie.png", "iram_baston_agachado.png", "iram_baston_andando.png", "iram_baston_paso.png"]):
    guardar(a, al, max(0, x0 - 6), x1 + 6, n)

# hoja de giro completa sobre fondo neutro (para la hoja de personaje)
a, al = sin_croma(FUENTES / "giro360.jpeg")
comp = a * al[..., None] + np.array(FONDO, np.float32) * (1 - al[..., None])
Image.fromarray(comp.clip(0, 255).astype(np.uint8)).save(SALIDA / "iram_hoja_giro.png")
print("iram_hoja_giro.png")

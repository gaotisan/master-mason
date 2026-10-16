# Reconstruye el baculo de Magnus/Iram entero y sin bola para usarlo de referencia en Midjourney.
# En baston_lamina_poses.png el baculo siempre queda detras del cuerpo: solo se ve la garra
# de la punta. Se recorta esa garra (pose agachada, la mas limpia) y se le pinta debajo una
# vara con el color y el sombreado de su propio tallo, estrechandose hacia el pie.
import numpy as np
from PIL import Image, ImageFilter
from pathlib import Path

FUENTE = Path(__file__).resolve().parents[2] / "anim" / "_fuentes" / "baston_lamina_poses.png"
SALIDA = Path(__file__).resolve().parent
FONDO = np.array((232, 228, 220), np.float32)
ESC = 6          # la lamina es pequeña: se trabaja a 6x
CAJA = (293, 70, 356, 161)  # garra de la pose agachada, por encima de la correa


def alfa_croma(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    verde = g - np.maximum(r, b)
    al = np.clip(1 - (verde - 8) / 28, 0, 1)
    a = a.copy()
    # la madera siempre tiene mas rojo que verde: lo que pase de ahi es halo del croma
    a[..., 1] = np.minimum(g, r * 0.82)
    return a, al


src = np.asarray(Image.open(FUENTE).convert("RGB")).astype(np.float32)
rgb, al = alfa_croma(src[CAJA[1]:CAJA[3], CAJA[0]:CAJA[2]])

# quitar lo que no es baculo (el borde de la capucha y del hombro, a la derecha y abajo)
h, w = al.shape
ys, xs = np.mgrid[0:h, 0:w]
al[(xs > w - 12) & (ys > h - 30)] = 0
gris = (np.abs(rgb[..., 0] - rgb[..., 2]) < 18) & (rgb[..., 0] > 90)
al[gris] = 0

# escalar premultiplicado para que el verde del fondo no tiña los bordes
def subir(canal):
    return np.asarray(Image.fromarray(canal.astype(np.float32), "F").resize((w * ESC, h * ESC), Image.BICUBIC))
al = np.where(al > 0.5, np.minimum(1, al * 1.15), al * 0.6)
pre = [subir(rgb[..., c] * al) for c in range(3)]
al_g = np.clip(subir(al), 0, 1)
al_g = np.asarray(Image.fromarray((al_g * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0)), np.float32) / 255
col = np.dstack([c / np.maximum(np.clip(subir(al), 1e-3, 1), 1e-3) for c in pre])
cab = np.dstack([col.clip(0, 255), al_g])

# ancho y posicion del tallo justo encima de la correa: de ahi sale la vara
fila = cab[-ESC * 4:-ESC, :, :]
cols = np.where(fila[..., 3].mean(0) > 0.5)[0]
x0, x1 = cols.min(), cols.max() + 1
ancho_tallo = x1 - x0
centro_tallo = (x0 + x1) / 2
# tres tonos sacados de la madera limpia de la garra (luz a la izquierda, como en la lamina)
madera = cab[..., :3][cab[..., 3] > 0.97]
lum = madera.mean(1)
claro, medio, oscuro = (madera[(lum >= np.percentile(lum, a)) & (lum <= np.percentile(lum, b))].mean(0)
                        for a, b in ((75, 95), (40, 60), (5, 22)))
u_ = np.linspace(0, 1, 64)[:, None]
perfil = np.where(u_ < 0.18, medio + (claro - medio) * (u_ / 0.18),
         np.where(u_ < 0.45, claro + (medio - claro) * ((u_ - 0.18) / 0.27),
                  medio + (oscuro - medio) * ((u_ - 0.45) / 0.55)))

# vara: larga, estrechandose, con una ondulacion suave de madera y nudos discretos
LARGO = int(cab.shape[0] * 3.3)
CW = max(cab.shape[1], ancho_tallo * 4)
vara = np.zeros((LARGO, CW, 4), np.float32)
rng = np.random.default_rng(7)
fase = rng.uniform(0, 6.28, 3)
for y in range(LARGO):
    t = y / LARGO
    ancho = ancho_tallo * 0.92 * (1 - 0.3 * t) * (1 + 0.07 * np.sin(t * 23 + fase[2]))
    cx = CW / 2 + 6.0 * np.sin(t * 4.3 + fase[0]) + 2.5 * np.sin(t * 11 + fase[1])
    xs_ = np.arange(CW)
    u = (xs_ - (cx - ancho / 2)) / ancho
    dentro = (u >= 0) & (u <= 1)
    idx = np.clip((u * (len(perfil) - 1)).round().astype(int), 0, len(perfil) - 1)
    color = perfil[idx]
    # facetas: bandas diagonales algo mas oscuras, como en la capa
    banda = ((y * 0.35 + xs_ * 1.0) / (ESC * 14) + fase[2]) % 1
    color = color * (0.95 + 0.08 * np.sin(banda * 6.283))[:, None]
    vara[y, :, :3] = color
    borde = np.clip(np.minimum(u, 1 - u) * ancho / 1.5, 0, 1)
    vara[y, :, 3] = np.where(dentro, borde, 0)
# nudos
# vetas: luz y sombra largas y suaves a lo largo de la vara
veta = np.asarray(Image.fromarray((rng.random((LARGO // 40 + 2, CW)) * 255).astype(np.uint8)).resize((CW, LARGO), Image.BICUBIC), np.float32) / 255
vara[..., :3] *= (0.9 + 0.18 * veta)[..., None]
# remate del pie
pie = int(ESC * 2)
for i in range(pie):
    vara[LARGO - pie + i, :, 3] *= 1 - i / pie

# montar: cabeza encima, vara debajo alineada con el tallo
ancho_total = max(cab.shape[1], CW)
alto_total = cab.shape[0] + LARGO - ESC * 9
lienzo = np.zeros((alto_total, ancho_total, 4), np.float32)
off_v = int(centro_tallo - CW / 2 + (ancho_total - cab.shape[1]) / 2)
y_v = cab.shape[0] - ESC * 9
seg = lienzo[y_v:y_v + LARGO, max(0, off_v):off_v + CW]
v = vara[:, max(0, -off_v):max(0, -off_v) + seg.shape[1]]
seg[:] = v
# la garra se funde con la vara en sus ultimas filas, sin corte recto
fundido = ESC * 6
cab[-fundido:, :, 3] *= np.linspace(1, 0, fundido)[:, None]
xc = (ancho_total - cab.shape[1]) // 2
zona = lienzo[:cab.shape[0], xc:xc + cab.shape[1]]
a_c = cab[..., 3:4]
zona[..., :3] = cab[..., :3] * a_c + zona[..., :3] * (1 - a_c)
zona[..., 3:4] = np.maximum(zona[..., 3:4], a_c)

# rellenar filas sueltas con hueco de alfa donde se cruzan los dos fundidos
for _ in range(3):
    al_ = lienzo[..., 3]
    vecinas = np.minimum(np.roll(al_, 1, 0), np.roll(al_, -1, 0))
    lienzo[..., 3] = np.maximum(al_, vecinas)

# devolver algo del ocre anaranjado de la lamina
lum = lienzo[..., :3].mean(2, keepdims=True)
lienzo[..., :3] = lum + (lienzo[..., :3] - lum) * 1.25
lienzo[..., 0] *= 1.04
lienzo[..., 2] *= 0.94

# recortar al contenido
m = lienzo[..., 3] > 0.05
yy, xx = np.where(m)
lienzo = lienzo[yy.min():yy.max() + 1, xx.min():xx.max() + 1]

transp = Image.fromarray(np.dstack([lienzo[..., :3].clip(0, 255), lienzo[..., 3:] * 255]).astype(np.uint8), "RGBA")
transp.save(SALIDA / "baculo_transparente.png")


def en_lienzo(img, nombre, ancho, alto, ocupa):
    esc = alto * ocupa / img.height
    img = img.resize((max(1, int(img.width * esc)), int(img.height * esc)), Image.LANCZOS)
    fondo = Image.new("RGBA", (ancho, alto), tuple(int(c) for c in FONDO) + (255,))
    fondo.alpha_composite(img, ((ancho - img.width) // 2, (alto - img.height) // 2))
    fondo.convert("RGB").save(SALIDA / nombre)
    print(nombre, fondo.size)


en_lienzo(transp, "baculo_entero.png", 1024, 1536, 0.9)
cabeza = Image.fromarray(np.dstack([cab[..., :3].clip(0, 255), cab[..., 3:] * 255]).astype(np.uint8), "RGBA")
en_lienzo(cabeza, "baculo_punta.png", 1024, 1024, 0.8)

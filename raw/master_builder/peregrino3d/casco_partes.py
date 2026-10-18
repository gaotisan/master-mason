"""Paso 1: cascos de voxeles por piezas (cuerpo, manos, piernas) esculpidos
con las siluetas de la hoja de giro. Ver LEEME.txt."""
import numpy as np, json
from PIL import Image
from scipy import ndimage
hoja = np.asarray(Image.open('../anim/_fuentes/giro360.jpeg').convert('RGB')).astype(int)
M = np.asarray(Image.open('mascara_giro.png')) > 0
H, W = M.shape
S = 4
ys = np.arange(140, 1625, S)
VISTAS = [(90, 260, 0), (52, 713, 10), (33, 1172, 10), (-29, 1665, 10), (0, 2194, 0)]
CAJAS = [(42,479),(504,933),(951,1412),(1425,1887),(1903,2487)]
DOBLADILLO = [1441, 1480, 1479, 1478, 1485]
R = 300
g = np.arange(-R, R+1, S)
X, Z = np.meshgrid(g, g, indexing='ij')
FIL = np.arange(H)[:, None]; COL = np.arange(W)[None, :]
def caja(k):
    a, b = CAJAS[k]; return (COL >= a-12) & (COL <= b+12)
r, gg, b = hoja[..., 0], hoja[..., 1], hoja[..., 2]
PIEL = (r > 105) & (r - b > 30) & (gg - b > 8) & (r - gg < 80) & M

# Piernas: lo que queda bajo la capa, alargado hacia arriba hasta la cadera.
def piernas(k, r0, c0, c1):
    m = M & caja(k) & (FIL >= r0) & (COL >= c0) & (COL <= c1 + 120)
    cols = M[r0 + 15] & (COL[0] >= c0) & (COL[0] <= c1)
    m |= (FIL >= 1150) & (FIL < r0) & cols[None, :]
    return m
PIERNAS = {0: piernas(0, 1450, 240, 305), 4: piernas(4, 1485, 2100, 2260)}
# Cuerpo: sin las piernas (por debajo del borde de la capa).
def cuerpo(k):
    m = M & caja(k) & (FIL < DOBLADILLO[k])
    if k == 0: m &= ~((FIL >= 1385) & (COL >= 240) & (COL <= 305))
    if k == 4: m &= ~((FIL >= 1330) & (COL >= 2135) & (COL <= 2255))
    return m
# Manos: piel en la franja de las mangas.
from PIL import ImageDraw
def poligonos(lista):
    z = Image.new('L', (W, H), 0); d = ImageDraw.Draw(z)
    for p in lista: d.polygon(p, fill=255)
    return np.asarray(z) > 0
MANOS = {
    0: poligonos([[(222,1045),(268,1030),(292,1050),(294,1105),(280,1110),(272,1080),(262,1160),(250,1162),(232,1100),(225,1080)]]),
    4: poligonos([[(1945,1030),(2005,1025),(2010,1060),(2002,1150),(1985,1150),(1975,1100),(1962,1100),(1950,1060)],
                  [(2375,1030),(2440,1025),(2440,1110),(2428,1110),(2415,1150),(2398,1150),(2385,1100),(2378,1060)]]),
}
def manos(k):
    return MANOS[k]


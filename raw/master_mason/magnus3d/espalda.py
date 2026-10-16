"""Vista de espalda inventada a partir del frente (la hoja no la tiene): el
hueco de la capucha pasa a gris de capucha y la barba a parches de capa."""
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
im = np.asarray(Image.open('../anim/_fuentes/giro360.jpeg').convert('RGB')).astype(float)
A = 1880
def poli(pts):
    z = Image.new('L', (im.shape[1], im.shape[0]), 0)
    ImageDraw.Draw(z).polygon([(x + A, y) for x, y in pts], fill=255)
    return np.asarray(z) > 0
hueco = poli([(150,392),(230,322),(315,285),(405,318),(478,388),(425,428),(330,452),(250,452),(185,425)])
barba = poli([(250,330),(365,330),(378,450),(365,565),(318,700),(282,565),(248,450)]) & ~hueco
f = im.copy()
mx, mn = im.max(2), im.min(2)
gris = ((mx - mn) < 30) & (mx > 100) & (mx < 215)
cap = gris & ~hueco & ~barba
cap[:, :A] = False; cap[460:] = False
idx = ndimage.distance_transform_edt(~cap, return_distances=False, return_indices=True)
f[hueco] = im[idx[0], idx[1]][hueco]
ys, xs = np.nonzero(barba)
f[ys, xs] = im[ys, xs - 125]
suave = ndimage.gaussian_filter(f, (2, 2, 0))
borde = ndimage.binary_dilation(hueco | barba, iterations=3) & ~ndimage.binary_erosion(hueco | barba, iterations=3)
f[borde] = suave[borde]
Image.fromarray(f.astype(np.uint8)).save('hoja_con_espalda.png')
Image.fromarray(f[100:1650, A:A+630].astype(np.uint8)).resize((315, 775)).save('espalda_prev.png')

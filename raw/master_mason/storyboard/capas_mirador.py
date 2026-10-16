"""Separa la imagen del mirador en capas para el prototipo de storyboard:
fondo (sin la figura pintada y sin lo de delante), delante (ladera, arboles
y pinos con alfa) y marco (el borde sucio, fijo). Salida en
assets/pruebas_storyboard/."""
import numpy as np, os
from PIL import Image, ImageDraw
from scipy import ndimage
SAL = '../../../assets/pruebas_storyboard'
os.makedirs(SAL, exist_ok=True)
im = np.asarray(Image.open('mirador_original.png').convert('RGB')).astype(float)
H, W, _ = im.shape
lum = im @ [0.3, 0.59, 0.11]
def poli(pts):
    z = Image.new('L', (W, H), 0); ImageDraw.Draw(z).polygon(pts, fill=255)
    return np.asarray(z).astype(float) / 255

def rellenar(img, hueco, sigma):
    """Rellena el hueco con lo que lo rodea (convolucion normalizada)."""
    w = 1 - hueco
    num = np.stack([ndimage.gaussian_filter(img[..., k] * w, sigma) for k in range(3)], -1)
    den = ndimage.gaussian_filter(w, sigma)[..., None]
    lleno = num / np.maximum(den, 1e-4)
    return img * (1 - hueco[..., None]) + lleno * hueco[..., None]

# 1. La figura pintada en la punta: fuera.
caja = np.zeros((H, W)); caja[566:642, 505:545] = 1
figura = (caja > 0) & (lum < 95)
figura = ndimage.binary_dilation(figura, iterations=3).astype(float)
base = im.copy()
for s in (2, 4, 8):
    base = rellenar(base, figura, s) * figura[..., None] + im * (1 - figura[..., None]) if s == 2 else rellenar(base, figura, s) * figura[..., None] + base * (1 - figura[..., None])

# 2. Delante: ladera con el camino, arboles de la izquierda y pinos.
ladera = poli([(0, 330), (60, 420), (150, 470), (250, 520), (330, 560), (420, 598), (470, 622), (505, 640),
               (560, 648), (600, 668), (640, 720), (700, 780), (730, 816), (0, 816)])
zona_arboles = poli([(0, 0), (560, 0), (560, 110), (450, 160), (360, 300), (300, 330), (260, 520), (0, 520)])
arboles = zona_arboles * np.clip((112 - lum) / 32, 0, 1)
zona_pinos = poli([(1285, 195), (1425, 195), (1456, 816), (1115, 816), (1115, 560), (1175, 440), (1285, 440)])
pinos = zona_pinos * np.clip((118 - lum) / 34, 0, 1)
alfa = np.clip(ndimage.gaussian_filter(ladera, 1.2), 0, 1)

# 3. Marco: el borde sucio, que no se mueve.
yy, xx = np.mgrid[0:H, 0:W]
dist = np.minimum.reduce([xx, yy, W - 1 - xx, H - 1 - yy]).astype(float)
marco = np.clip((90 - lum) / 50, 0, 1) * np.clip((48 - dist) / 20, 0, 1)
marco = np.maximum(marco, (dist < 6).astype(float))

# El fondo sin la ladera: se rellena con la niebla de encima (sin coger el
# borde sucio), para que al moverse la ladera no se vea el camino doble.
hueco = ndimage.binary_dilation(alfa > 0.05, iterations=8).astype(float)
valido = (1 - hueco) * (dist > 55)
fondo = base.copy()
for sg in (6, 14, 30, 60):
    num = np.stack([ndimage.gaussian_filter(base[..., k] * valido, sg) for k in range(3)], -1)
    den = ndimage.gaussian_filter(valido, sg)[..., None]
    capa = num / np.maximum(den, 1e-4)
    falta = (den[..., 0] > 0.02) & (hueco > 0) & (valido < 0.5)
    fondo[falta] = capa[falta]
    valido = np.maximum(valido, falta.astype(float))
def guardar(rgb, a, nombre):
    out = np.dstack([np.clip(rgb, 0, 255), np.clip(a * 255, 0, 255)]).astype(np.uint8) if a is not None \
        else np.clip(rgb, 0, 255).astype(np.uint8)
    Image.fromarray(out).save(os.path.join(SAL, nombre))
guardar(fondo, None, 'mirador_fondo.png')
guardar(base, alfa, 'mirador_delante.png')
guardar(np.zeros_like(im) + [8, 6, 6], marco, 'mirador_marco.png')
prev = np.concatenate([fondo, base * alfa[..., None] + 255 * (1 - alfa[..., None])], 1)
Image.fromarray(prev.astype(np.uint8)).resize((1456, 408)).save('capas_prev.png')
print('ok')

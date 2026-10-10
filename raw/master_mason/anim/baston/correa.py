"""La correa de cuero con dos presillas que lleva el baston a la espalda (2026-10-10).

El usuario: la funda de tubo (funda_cuero.py) de espaldas quedaba "como un
pegote". Pidio a Gemini tres composiciones sobre nuestra referencia de espaldas
y eligio la 3: una correa en diagonal (del hombro derecho a la cadera
izquierda) con dos presillas con hebilla. Original:
_fuentes/baston_correa_gemini.jpeg (Gemini_Generated_Image_jziqimjziqimjziq,
2752x1536, croma verde, el personaje con el baston en la mano: la correa vacia).

Se aisla de esa imagen (Gemini redibuja el resto, asi que no vale restar con la
nuestra):
  1. GrabCut con la forma como guia: banda recta a lo largo de la correa y dos
     rectangulos en las presillas (el color solo no basta: el cuero y los
     parches ocres de la tunica son del mismo tono).
  2. Los dos bordes de la correa, rectas paralelas ajustadas fila a fila (fuera
     de las presillas): eje y ancho (unos 18 px a esa resolucion, 12,4 grados).
  3. Se endereza (el eje vertical) y se parte en dos capas, como la funda:
       correa_atras.png    la correa (detras del baston)
       correa_delante.png  las presillas (delante del baston: pasa por dentro)
  correa.json: tamano, eje (x del eje y centro en la textura), escala (px de
  hoja por px de textura: la de Gemini a master por la altura del personaje,
  a la mitad) y donde van las presillas a lo largo (fracciones de la correa).
La escena la pone a lo largo del baston (el mismo modelo: giro, vuelta,
delante / detras, de canto de perfil).
    python correa.py
"""
import json, os, shutil
import numpy as np, cv2
from PIL import Image, ImageDraw
from scipy.ndimage import binary_opening, label

AQUI = os.path.dirname(os.path.realpath(__file__))
PROY = os.path.abspath(os.path.join(AQUI, '..', '..', '..', '..'))
FUENTE = os.path.join(PROY, 'raw', 'master_mason', 'anim', '_fuentes', 'baston_correa_gemini.jpeg')
DST = os.path.join(PROY, 'assets', 'characters', 'baston')
REPOSO = os.path.join(PROY, 'raw', 'master_mason', 'anim', 'magnus_secuencia_frontal', '04_limpios', 'reposo_espalda_cb_000.png')
# a mano, sobre la imagen (px del original): la correa de punta a punta y las presillas
P0, P1 = (1465.0, 482.0), (1288.0, 1182.0)
PRESILLAS = [(1420, 615, 70, 30), (1350, 945, 70, 28)]      # centro x, y, ancho, alto

g = np.asarray(Image.open(FUENTE).convert('RGB'))
x0, y0, x1, y1 = 1200, 420, 1600, 1260
c = np.ascontiguousarray(g[y0:y1, x0:x1]); H, W = c.shape[:2]
p0, p1 = np.array(P0) - (x0, y0), np.array(P1) - (x0, y0)


def banda(media):
    m = Image.new('L', (W, H), 0)
    v = p1 - p0; n = np.array([v[1], -v[0]]) / np.hypot(*v)
    ImageDraw.Draw(m).polygon([tuple(p0 + n * media), tuple(p1 + n * media), tuple(p1 - n * media), tuple(p0 - n * media)], fill=255)
    return np.asarray(m) > 0


# 1. GrabCut
mask = np.full((H, W), cv2.GC_PR_BGD, np.uint8)
mask[banda(22)] = cv2.GC_PR_FGD
mask[banda(5)] = cv2.GC_FGD
for cx, cy, w, h in PRESILLAS:
    sl = (slice(cy - y0 - h // 2, cy - y0 + h // 2), slice(cx - x0 - w // 2 - 10, cx - x0 + w // 2 + 10))
    sub = mask[sl]; sub[sub != cv2.GC_FGD] = cv2.GC_PR_FGD
    mask[cy - y0 - h // 4:cy - y0 + h // 4, cx - x0 - w // 3:cx - x0 + w // 3] = cv2.GC_FGD
mask[~banda(70)] = cv2.GC_BGD
for cx, cy, w, h in PRESILLAS:
    sub = mask[cy - y0 - h:cy - y0 + h, cx - x0 - w:cx - x0 + w]; sub[sub == cv2.GC_BGD] = cv2.GC_PR_BGD
bgd = np.zeros((1, 65), np.float64); fgd = np.zeros((1, 65), np.float64)
cv2.grabCut(c, mask, None, bgd, fgd, 8, cv2.GC_INIT_WITH_MASK)
fg = (mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD)

# 2. bordes de la correa
izq, der, filas = [], [], []
for y in range(int(P0[1]) + 18, int(P1[1]) - 12, 2):
    if any(abs(y - cy) <= h for _, cy, _, h in PRESILLAS):
        continue
    t = (y - P0[1]) / (P1[1] - P0[1]); xc = P0[0] + t * (P1[0] - P0[0])
    xs = np.nonzero(fg[y - y0])[0] + x0
    if not len(xs):
        continue
    k = np.argmin(np.abs(xs - xc)); i = j = k
    while i > 0 and xs[i - 1] == xs[i] - 1:
        i -= 1
    while j < len(xs) - 1 and xs[j + 1] == xs[j] + 1:
        j += 1
    if abs(xs[k] - xc) > 8 or xs[j] - xs[i] > 45:
        continue
    izq.append(xs[i]); der.append(xs[j] + 1); filas.append(y)
filas, izq, der = np.array(filas), np.array(izq, float), np.array(der, float)
ok = np.abs((der - izq) - np.median(der - izq)) < 6
a1, a2 = np.polyfit(filas[ok], izq[ok], 1), np.polyfit(filas[ok], der[ok], 1)
eje = (a1 + a2) / 2
ancho = float(np.polyval(a2, 800) - np.polyval(a1, 800))
ang = float(np.degrees(np.arctan(-eje[0])))
on = [y for y in range(int(P0[1]) - 40, int(P1[1]) + 40)
      if 0 <= y - y0 < H and fg[y - y0, int(round(np.polyval(eje, y))) - x0 - 3:int(round(np.polyval(eje, y))) - x0 + 4].mean() > 0.5]
ya, yb = min(on), max(on)
print('correa: %.1f px de ancho, %.2f grados, de y=%d a y=%d' % (ancho, ang, ya, yb))

# 3. enderezar (eje vertical) alrededor del centro de la correa
ym = (ya + yb) / 2; xm = float(np.polyval(eje, ym))
R = cv2.getRotationMatrix2D((xm - x0, ym - y0), ang, 1.0)     # positivo: el eje queda vertical
rgb = cv2.warpAffine(c, R, (W, H), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REFLECT)
fgr = cv2.warpAffine(fg.astype(np.float32), R, (W, H), flags=cv2.INTER_LINEAR) > 0.5
ex = xm - x0                                    # el eje queda en x = ex
largo = (yb - ya) / np.cos(np.radians(ang))
ta, tb = ym - y0 - largo / 2, ym - y0 + largo / 2
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
# la correa: entre los dos bordes (rectos), con 1 px de suavizado, y sus puntas rectas
a_correa = np.clip(ancho / 2 + 0.5 - np.abs(xx + 0.5 - ex), 0, 1) * np.clip(yy - ta + 0.5, 0, 1) * np.clip(tb - yy + 0.5, 0, 1)
# las presillas: lo de GrabCut en sus filas (giradas con la imagen), hasta 45 px del eje
a_pres = np.zeros((H, W), np.float32)
pres_t = []
for cx, cy, w, h in PRESILLAS:
    q = R @ np.array([cx - x0, cy - y0, 1.0])
    pres_t.append(float((q[1] - ta) / (tb - ta)))
    zona = (np.abs(yy - q[1]) <= h / 2 + 4) & (np.abs(xx - ex) <= w / 2 + 8)
    # fuera lo gris claro (el panel gris de la tunica se colaba en la de abajo);
    # los remaches, oscuros, se quedan
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV).astype(np.float32)
    gris = (hsv[..., 1] < 0.2 * 255) & (hsv[..., 2] > 0.32 * 255)
    m = fgr & zona & ~gris
    lab, n = label(m)
    if n:
        m = lab == (np.bincount(lab.ravel())[1:].argmax() + 1)
    a_pres = np.maximum(a_pres, cv2.GaussianBlur(m.astype(np.float32), (0, 0), 0.6))
a_pres = np.clip(a_pres * 1.15, 0, 1)

# recorte comun a las dos capas
todo = (a_correa > 0.01) | (a_pres > 0.01)
ys, xs = np.nonzero(todo)
cx0, cy0, cx1, cy1 = xs.min() - 2, ys.min() - 2, xs.max() + 3, ys.max() + 3
os.makedirs(DST, exist_ok=True)
for nombre, a in (('atras', a_correa), ('delante', a_pres)):
    im = np.dstack([rgb, (a * 255).round()]).astype(np.uint8)[cy0:cy1, cx0:cx1]
    Image.fromarray(im, 'RGBA').save(os.path.join(DST, 'correa_%s.png' % nombre))

# escala: el personaje de Gemini a master por la altura (capucha-pies), y a la mitad (hoja)
def alto(a, ancho_apertura):
    d = a[..., 1].astype(int) - np.maximum(a[..., 0], a[..., 2]).astype(int) if a.shape[-1] == 3 else None
    m = (d < 60) if d is not None else (a[..., 3] > 128)
    m = binary_opening(m, structure=np.ones((1, ancho_apertura)))
    lab, _ = label(m); m = lab == (np.bincount(lab.ravel())[1:].argmax() + 1)
    ys = np.nonzero(m.any(1))[0]
    return ys.max() - ys.min()
h_gem = alto(g, 30)
h_master = alto(np.asarray(Image.open(REPOSO).convert('RGBA')), 15)
escala = h_master / h_gem / 2
datos = {'tamano': [int(cx1 - cx0), int(cy1 - cy0)], 'eje': [round(float(ex - cx0), 2), round(float((ta + tb) / 2 - cy0), 2)],
         'escala': round(float(escala), 5), 'largo': round(float(largo), 1), 'presillas': [round(t, 3) for t in pres_t],
         'angulo_gemini': round(ang, 2)}
json.dump(datos, open(os.path.join(DST, 'correa.json'), 'w'))
print('correa_atras/delante.png', datos, ' (alto personaje: gemini %d px, master %d px)' % (h_gem, h_master))

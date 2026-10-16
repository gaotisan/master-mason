"""Renders del modelo (sin luz, solo textura) desde los angulos de la hoja,
al lado del original, para comparar."""
import numpy as np, json, sys
from PIL import Image
from rasteriza import rasterizar
d = np.load('malla.npz'); V, T, UV = d['V'], d['T'], d['UV']
P = np.stack([V[:, 0], -V[:, 2], -V[:, 1]], 1)
tex = np.asarray(Image.open(sys.argv[1] if len(sys.argv) > 1 else 'magnus_textura.png').convert('RGB')).astype(float)
TEX = tex.shape[0]
hoja = np.pad(np.asarray(Image.open('../anim/_fuentes/giro360.jpeg').convert('RGB')), ((0,0),(400,400),(0,0)), constant_values=34)
cajas = [(42,479),(504,933),(951,1412),(1425,1887),(1903,2487)]
cfg = json.load(open('casco.json'))
angs = [(th, c) for th, c, _ in cfg['vistas']] + [(180, 2194), (135, 2194), (-90, 2194)]
filas = []
Pc = P[T].reshape(-1, 3); uvc = UV.reshape(-1, 2); tris3 = np.arange(len(Pc)).reshape(-1, 3)
def render(th, w=640, h=1560, x0=None):
    t = np.radians(th)
    u = Pc[:, 0] * np.cos(t) + Pc[:, 2] * np.sin(t) + w / 2
    v = Pc[:, 1] - 100
    dp = -Pc[:, 0] * np.sin(t) + Pc[:, 2] * np.cos(t)
    zb, ab, ib = rasterizar(np.stack([u, v], 1), dp, uvc, tris3, w, h)
    img = np.full((h, w, 3), 34.0)
    m = ib >= 0
    tu = np.clip((ab[..., 0] * TEX).astype(int), 0, TEX - 1); tv = np.clip(((1 - ab[..., 1]) * TEX).astype(int), 0, TEX - 1)
    img[m] = tex[tv[m], tu[m]]
    return img
out = []
for k, (th, c) in enumerate(angs):
    r = render(th)
    if k < 5:
        o = hoja[100:1660, int(c) + 80:int(c) + 720].astype(float)
        out.append(np.concatenate([o, r], 0))
    else:
        out.append(np.concatenate([np.full_like(r, 34.0), r], 0))
img = np.concatenate(out, 1).astype(np.uint8)
Image.fromarray(img).resize((img.shape[1] // 3, img.shape[0] // 3)).save(sys.argv[2] if len(sys.argv) > 2 else 'comparacion.png')

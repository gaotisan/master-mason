"""Paso 3: textura proyectando la pintura de la hoja sobre cada pieza, con
prueba de visibilidad. Cuerpo: todas las vistas, con las manos borradas de la
pintura. Manos y piernas: solo frente, perfil (y espejos) y espalda."""
import numpy as np, json, sys
from PIL import Image
from scipy import ndimage
from rasteriza import rasterizar
import casco_partes as cp
TEX = 2048
POT = float(sys.argv[1]) if len(sys.argv) > 1 else 24.0
d = np.load('malla.npz'); V, T, UV, PZ = d['V'], d['T'], d['UV'], d['pieza']
P = np.stack([V[:, 0], -V[:, 2], -V[:, 1]], 1)   # X, y, Z en pixeles de la hoja
def cargar(n):
    im = np.asarray(Image.open(n).convert('RGB')).astype(float)
    im[..., 1] = np.minimum(im[..., 1], np.maximum(im[..., 0], im[..., 2]) + 8)
    return im
hoja = cargar('../anim/_fuentes/giro360.jpeg'); esp = cargar('hoja_con_espalda.png')
M = cp.M; Me = ndimage.binary_erosion(M, iterations=3)
H, W = M.shape
# Pintura sin manos para el cuerpo.
manos = ndimage.binary_dilation(cp.MANOS[0] | cp.MANOS[4], iterations=5)
def sin_manos(im):
    fuente = M & ~manos
    idx = ndimage.distance_transform_edt(~fuente, return_distances=False, return_indices=True)
    out = im.copy(); out[manos] = im[idx[0], idx[1]][manos]
    return out
hoja_c, esp_c = sin_manos(hoja), sin_manos(esp)
FIL = np.arange(H)[:, None] * np.ones((1, W), bool)
banda_manos = (FIL >= 985) & (FIL <= 1185)
cfg = json.load(open('casco.json'))
# (theta, centro, imagen por pieza, peso, espejo, piezas)
VISTAS = []
for th, c, _ in cfg['vistas']:
    peso = 1.5 if th in (0, 90) else 1.0
    for espejo in ([False] if th == 0 else [False, True]):
        VISTAS.append((th, c, {0: hoja_c, 1: hoja, 2: hoja}, peso, espejo, {0, 1, 2} if th in (0, 90) else {0}))
VISTAS.append((180, 2194, {0: esp_c, 1: esp, 2: esp}, 0.8, False, {0, 1, 2}))

def proy(Q, th, c):
    t = np.radians(th)
    return c + Q[:, 0] * np.cos(t) + Q[:, 2] * np.sin(t), Q[:, 1], -Q[:, 0] * np.sin(t) + Q[:, 2] * np.cos(t)
A, B, C = P[T[:, 0]], P[T[:, 1]], P[T[:, 2]]
N = np.cross(B - A, C - A); N /= np.linalg.norm(N, axis=1, keepdims=True) + 1e-12
cen = (A + B + C) / 3
for p in range(3):  # orientar hacia fuera, pieza a pieza
    s = PZ == p
    ref = cen[s].copy(); ref[:, 1] = 0
    if p == 2: ref[:, 0] = cen[s][:, 0] - np.sign(cen[s][:, 0]) * 230; ref[:, 2] = cen[s][:, 2] - np.median(cen[s][:, 2])
    if np.mean(np.sum(N[s] * (cen[s] - (cen[s] - ref)), 1)) < 0: N[s] = -N[s]
uvpix = np.stack([UV[..., 0] * TEX, (1 - UV[..., 1]) * TEX], -1).reshape(-1, 2)
tris3 = np.arange(len(T) * 3).reshape(-1, 3)
_, pos, cara = rasterizar(uvpix, np.zeros(len(uvpix)), P[T].reshape(-1, 3), tris3, TEX, TEX)
ok = cara >= 0
Q = pos[ok]; Nq = N[cara[ok]]; Pq = PZ[cara[ok]]
acum = np.zeros((len(Q), 3)); wsum = np.zeros(len(Q))
for th, c, ims, peso, espejo, piezas in VISTAS:
    f = np.array([-1, 1, 1]) if espejo else np.ones(3)
    Pv, Qv, Nv = P * f, Q * f, Nq * f
    u, v, dp = proy(Pv, th, c)
    zb, _, _ = rasterizar(np.stack([u, v], 1), dp, np.zeros((len(u), 1)), T, W, H)
    uq, vq, dq = proy(Qv, th, c)
    t = np.radians(th)
    dn = -Nv[:, 0] * np.sin(t) + Nv[:, 2] * np.cos(t)
    w = (np.clip(dn, 0, 1) ** POT + 0.003 * np.clip(dn + 0.35, 0, 1)) * peso
    ui = np.clip(np.round(uq).astype(int), 0, W - 1); vi = np.clip(np.round(vq).astype(int), 0, H - 1)
    w *= (dq >= zb[vi, ui] - 8) * Me[vi, ui] * np.isin(Pq, list(piezas))
    if th not in (0, 90, 180):
        w *= ~banda_manos[vi, ui]
    w[(Pq == 2) & ~manos[vi, ui]] *= 0.05 if th in (0, 90) else 1
    for p in range(3):
        s = (Pq == p) & (w > 0)
        if not s.any(): continue
        im = ims[p]
        col = np.stack([ndimage.map_coordinates(im[..., k], [vq[s], uq[s]], order=1) for k in range(3)], 1)
        acum[s] += col * w[s, None]; wsum[s] += w[s]
    print('vista', th, 'espejo' if espejo else '')
col = acum / np.maximum(wsum, 1e-6)[:, None]
# Caras que miran hacia abajo (bajos de la capa, dobladillo por dentro): el
# interior oscuro de la capa, que ninguna vista ve.
abajo = np.clip((Nq[:, 1] - 0.6) / 0.2, 0, 1) * (Pq == 0) * (Q[:, 1] > 1250)
col = col * (1 - abajo[:, None]) + np.array([46, 34, 34]) * abajo[:, None]
wsum = np.where(abajo > 0, 1, wsum)
sin = wsum < 1e-5
print('texeles sin color %.3f' % sin.mean())
tex = np.zeros((TEX, TEX, 3)); lleno = np.zeros((TEX, TEX), bool)
yy, xx = np.nonzero(ok)
tex[yy[~sin], xx[~sin]] = col[~sin]; lleno[yy[~sin], xx[~sin]] = True
idx = ndimage.distance_transform_edt(~lleno, return_distances=False, return_indices=True)
tex = tex[idx[0], idx[1]]
Image.fromarray(np.clip(tex, 0, 255).astype(np.uint8)).save('peregrino_textura.png')
print('textura ok')

# Same half-res metric for both videos: premultiplied, blurred, crop around the body.
import os, cv2, numpy as np
NEW = r'C:\Users\santiago.ochoa\godot\projects\master_mason\raw\master_mason\anim\magnus_arrastrarse_v2\01_frames_mitad'
OLD = r'C:\Users\santiago.ochoa\godot\projects\master_mason\raw\master_mason\anim\magnus_tumbarse\01_frames'
BGN = np.array([67, 209, 50], np.float32); BGO = np.array([65, 208, 46], np.float32)
def prem(f, bg):
    f = f.astype(np.float32)
    a = np.clip((np.abs(f - bg).max(-1) - 40) / 50.0, 0, 1)
    return cv2.GaussianBlur(np.dstack([f * a[..., None], a * 255]), (0, 0), 1.0)
def new(i, crop=(190, 365, 60, 540)):
    f = cv2.imread(os.path.join(NEW, 'f_%04d.png' % i))
    y0, y1, x0, x1 = crop
    return prem(f[y0:y1, x0:x1], BGN)
def old(i, crop=(190, 365, 60, 540)):
    f = cv2.resize(cv2.imread(os.path.join(OLD, 'f_%04d.png' % i)), (640, 360), interpolation=cv2.INTER_AREA)
    y0, y1, x0, x1 = crop
    return prem(f[y0:y1, x0:x1], BGO)
def dist(a, b): return float(np.abs(a - b).mean())
def sh(x, dx, dy): return np.roll(np.roll(x, dy, 0), dx, 1)
def best(A, B, dxs, dys=(-1, 0, 1)):
    b = (1e9, 0, 0)
    for dy in dys:
        Ay = np.roll(A, dy, 0)
        for dx in dxs:
            v = dist(np.roll(Ay, dx, 1), B)
            if v < b[0]: b = (v, dx, dy)
    return b
def ciclo(load, i, j, dxs):
    P = {k: load(k) for k in range(i - 2, j + 3)}
    st = {k: dist(P[k], P[k + 1]) for k in range(i - 2, j + 2)}
    d, dx, dy = best(P[i], P[j], dxs)
    seam = dist(P[j - 1], sh(P[i], dx, dy))
    cyc = [st[k] for k in range(i, j - 1)]
    med = float(np.median(cyc))
    return dict(i=i, j=j, n=j - i, costura_med=seam / med, costura_local=seam / ((st[j - 2] + st[i]) / 2),
                costura_max=seam / max(cyc), d_ij=d / med, avance_mitad=dx, dy=dy,
                pasos_extremos=[round(st[j - 3] / med, 2), round(st[j - 2] / med, 2), 'COSTURA', round(st[i] / med, 2), round(st[i + 1] / med, 2)],
                pasos=[round(st[k] / med, 2) for k in range(i, j - 1)])
